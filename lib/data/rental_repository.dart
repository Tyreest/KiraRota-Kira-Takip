import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants.dart';
import '../domain/models/calculation.dart';
import '../domain/models/rental.dart';

class RentalRepository {
  RentalRepository(this._prefs);

  final SharedPreferences _prefs;

  /// Production öncesi; global history migration yok.
  static const storageKey = 'rentals_v1';

  List<Rental> loadAll() {
    final raw = _prefs.getString(storageKey);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list.map((e) => Rental.fromJson(e as Map<String, dynamic>)).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  /// Legacy yenileme alanlarını bir kez çözümler ve gerekirse kaydeder.
  Future<bool> migrateRenewalsIfNeeded({DateTime? now}) async {
    final raw = _prefs.getString(storageKey);
    if (raw == null || raw.isEmpty) return false;
    final list = jsonDecode(raw) as List<dynamic>;
    final n = now ?? DateTime.now();
    var dirty = false;
    final migrated = <Rental>[];
    for (final e in list) {
      final r = Rental.fromJson(e as Map<String, dynamic>);
      final m = migrateRentalRenewal(r, now: n);
      if (m.renewalResolved != r.renewalResolved ||
          m.lastRenewalDate != r.lastRenewalDate ||
          dateOnly(m.increaseDate) != dateOnly(r.increaseDate)) {
        dirty = true;
      }
      migrated.add(m);
    }
    if (dirty) {
      await _saveAll(migrated);
    }
    return dirty;
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
  Future<Rental?> applyCalculation({
    required String rentalId,
    required CalculationResult result,
    required bool isPro,
  }) async {
    final items = loadAll();
    final i = items.indexWhere((e) => e.id == rentalId);
    if (i < 0) return null;

    final current = items[i];
    final snapshot = RentalCalculationSnapshot.fromResult(result);
    final history = [snapshot, ...current.history];
    if (!isPro && history.length > AppConstants.freeHistoryLimit) {
      history.removeRange(AppConstants.freeHistoryLimit, history.length);
    }

    final updated = current.copyWith(
      currentRent: result.calculatedRent,
      lastRenewalDate: dateOnly(current.increaseDate),
      increaseDate: nextIncreaseAnniversary(current.increaseDate),
      renewalResolved: true,
      updatedAt: DateTime.now(),
      history: history,
    );
    items[i] = updated;
    await _saveAll(items);
    return updated;
  }

  /// Hızlı hesaplamadan yeni kira oluşturur; isteğe bağlı ilk snapshot.
  Future<Rental?> createFromCalculation({
    required String displayName,
    required RentalRole role,
    required CalculationResult result,
    required bool isPro,
    bool includeSnapshot = true,
    String? tenantName,
    String? ownerName,
    String? address,
    String? notes,
  }) async {
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
      currentRent: input.currentRent,
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

  /// Aynı dönem için tekrar kayıt engeli: son snapshot aynı ay + aynı tutar.
  bool wouldDuplicateApply({
    required String rentalId,
    required CalculationResult result,
  }) {
    final current = findById(rentalId);
    if (current == null) return false;
    final latest = current.latestCalculation;
    if (latest == null) return false;
    return latest.tufeReferenceMonth == result.input.renewalMonthKey &&
        (latest.calculatedRent - result.calculatedRent).abs() < 0.005 &&
        (latest.oldRent - result.input.currentRent).abs() < 0.005;
  }

  Future<void> clear() => _prefs.remove(storageKey);

  /// Yedekten tüm kayıtları yazar (mevcut listeyi değiştirir).
  Future<void> replaceAll(List<Rental> items) => _saveAll(List.of(items));
}
