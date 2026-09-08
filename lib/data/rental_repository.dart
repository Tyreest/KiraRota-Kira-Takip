import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants.dart';
import '../core/money.dart';
import '../domain/models/calculation.dart';
import '../domain/models/rental.dart';

class RentalLoadResult {
  const RentalLoadResult({
    required this.rentals,
    this.skippedCorruptCount = 0,
  });

  final List<Rental> rentals;
  final int skippedCorruptCount;
}

class RentalRepository {
  RentalRepository(this._prefs);

  final SharedPreferences _prefs;

  /// Production öncesi; global history migration yok.
  static const storageKey = 'rentals_v1';

  List<Rental> loadAll() => loadAllResilient().rentals;

  /// Tek bozuk kayıt tüm listeyi düşürmesin; corrupt sayacı raporlanır.
  RentalLoadResult loadAllResilient() {
    final raw = _prefs.getString(storageKey);
    if (raw == null || raw.isEmpty) {
      return RentalLoadResult(rentals: <Rental>[]);
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        debugPrint('RentalRepository: storage root is not a List');
        return RentalLoadResult(rentals: <Rental>[], skippedCorruptCount: 1);
      }
      final rentals = <Rental>[];
      var skipped = 0;
      for (final e in decoded) {
        try {
          if (e is! Map) {
            skipped++;
            continue;
          }
          final rental = Rental.fromJson(Map<String, dynamic>.from(e));
          if (!_isSaneRental(rental)) {
            skipped++;
            continue;
          }
          rentals.add(rental);
        } catch (err) {
          skipped++;
          debugPrint('RentalRepository: skipped corrupt rental: $err');
        }
      }
      rentals.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return RentalLoadResult(rentals: rentals, skippedCorruptCount: skipped);
    } catch (e) {
      debugPrint('RentalRepository: failed to parse storage: $e');
      return RentalLoadResult(rentals: <Rental>[], skippedCorruptCount: 1);
    }
  }

  static bool _isSaneRental(Rental r) {
    if (r.id.trim().isEmpty) return false;
    if (!r.currentRent.isFinite || r.currentRent < 0) return false;
    if (r.currentRent > moneyMaxAbs) return false;
    return true;
  }

  /// Legacy yenileme alanlarını bir kez çözümler ve gerekirse kaydeder.
  Future<bool> migrateRenewalsIfNeeded({DateTime? now}) async {
    final loaded = loadAllResilient();
    if (loaded.rentals.isEmpty) return false;
    final n = now ?? DateTime.now();
    var dirty = false;
    final migrated = <Rental>[];
    for (final r in loaded.rentals) {
      final m = migrateRentalRenewal(r, now: n);
      if (m.renewalResolved != r.renewalResolved ||
          m.lastRenewalDate != r.lastRenewalDate ||
          dateOnly(m.increaseDate) != dateOnly(r.increaseDate)) {
        dirty = true;
      }
      migrated.add(m);
    }
    // Corrupt kayıt atlandıysa da temiz listeyi yaz (sessiz wipe değil —
    // kurtarılanlar korunur).
    if (dirty || loaded.skippedCorruptCount > 0) {
      await _saveAll(migrated);
      return true;
    }
    return false;
  }

  Rental? findById(String id) {
    for (final r in loadAll()) {
      if (r.id == id) return r;
    }
    return null;
  }

  Future<void> _saveAll(List<Rental> items) async {
    await _prefs.setString(
      storageKey,
      jsonEncode(items.map((e) => e.toJson()).toList()),
    );
  }

  /// Free: en fazla [AppConstants.freeRentalLimit] kayıt.
  /// Pro: sınırsız. Limit doluysa `false` döner (yazılmaz).
  Future<bool> add(Rental rental, {required bool isPro}) async {
    final items = loadAll();
    if (!isPro && items.length >= AppConstants.freeRentalLimit) {
      return false;
    }
    items.insert(0, rental);
    await _saveAll(items);
    return true;
  }

  Future<void> update(Rental rental) async {
    final items = loadAll();
    final i = items.indexWhere((e) => e.id == rental.id);
    if (i < 0) return;
    items[i] = rental;
    await _saveAll(items);
  }

  Future<void> delete(String id) async {
    final items = loadAll()..removeWhere((e) => e.id == id);
    await _saveAll(items);
  }

  /// Hesaplamayı kayda işler: snapshot + currentRent + sonraki artış tarihi.
  ///
  /// History Free/Pro’da fiziksel silinmez; Free yalnızca UI’da sınırlı gösterilir.
  /// [result.input.renewalDate] dönem tarihi olarak kullanılır.
  Future<Rental?> applyCalculation({
    required String rentalId,
    required CalculationResult result,
  }) async {
    // Tahmini / senaryo sonuçları kirayı veya history’yi değiştiremez.
    if (result.isEstimated) return null;

    final items = loadAll();
    final i = items.indexWhere((e) => e.id == rentalId);
    if (i < 0) return null;

    final current = items[i];
    if (wouldDuplicateApply(rentalId: rentalId, result: result)) {
      return current;
    }

    final snapshot = RentalCalculationSnapshot.fromResult(result);
    final history = [snapshot, ...current.history];

    final appliedRenewal = dateOnly(result.input.renewalDate);
    final updated = current.copyWith(
      currentRent: roundMoney(result.calculatedRent),
      lastRenewalDate: appliedRenewal,
      increaseDate: nextIncreaseAnniversary(appliedRenewal),
      renewalResolved: true,
      updatedAt: DateTime.now(),
      history: history,
    );
    items[i] = updated;
    await _saveAll(items);
    return updated;
  }

  /// Hızlı hesaplamadan yeni kira oluşturur.
  ///
  /// Varsayılan: snapshot **eklenmez** — “kayda bağlandı” ≠ “yeni dönem uygulandı”.
  /// currentRent hesaplanan girdi (mevcut) kirasıdır.
  Future<Rental?> createFromCalculation({
    required String displayName,
    required RentalRole role,
    required CalculationResult result,
    required bool isPro,
    bool includeSnapshot = false,
    String? tenantName,
    String? ownerName,
    String? address,
    String? notes,
  }) async {
    // Tahmini sonuçtan “gerçekleşmiş kira” kaydı oluşturma.
    if (result.isEstimated) return null;

    final items = loadAll();
    if (!isPro && items.length >= AppConstants.freeRentalLimit) {
      return null;
    }

    final now = DateTime.now();
    final input = result.input;
    final history = <RentalCalculationSnapshot>[];
    if (includeSnapshot) {
      history.add(RentalCalculationSnapshot.fromResult(result));
    }

    final rental = Rental(
      id: now.microsecondsSinceEpoch.toString(),
      role: role,
      displayName: displayName.trim(),
      currentRent: roundMoney(input.currentRent),
      contractStartDate: input.contractStart,
      increaseDate: input.renewalDate,
      renewalResolved: true,
      contractIncreaseRate: input.contractIncreasePercent,
      tenantName: tenantName,
      ownerName: ownerName,
      address: address,
      notes: notes,
      createdAt: now,
      updatedAt: now,
      history: history,
    );
    items.insert(0, rental);
    await _saveAll(items);
    return rental;
  }

  /// Aynı dönem için tekrar uygulama engeli.
  bool wouldDuplicateApply({
    required String rentalId,
    required CalculationResult result,
  }) {
    final current = findById(rentalId);
    if (current == null) return false;
    final latest = current.latestCalculation;
    if (latest == null) return false;
    final fp = calculationApplyFingerprint(result);
    final latestFp =
        '${latest.tufeReferenceMonth}|'
        '${roundMoney(latest.oldRent).toStringAsFixed(2)}|'
        '${roundMoney(latest.calculatedRent).toStringAsFixed(2)}';
    return fp == latestFp;
  }

  Future<void> clear() => _prefs.remove(storageKey);

  /// Yedekten tüm kayıtları yazar (mevcut listeyi değiştirir).
  Future<void> replaceAll(List<Rental> items) => _saveAll(List.of(items));
}
