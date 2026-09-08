import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kira_artisi_hesapla/data/rental_repository.dart';
import 'package:kira_artisi_hesapla/domain/dashboard_logic.dart';
import 'package:kira_artisi_hesapla/domain/models/calculation.dart';
import 'package:kira_artisi_hesapla/domain/models/rental.dart';
import 'package:kira_artisi_hesapla/services/rental_backup_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

Rental _rental({
  required String id,
  required DateTime increase,
  DateTime? last,
  bool? resolved,
  double rent = 39000,
  List<RentalCalculationSnapshot> history = const [],
}) {
  final now = DateTime(2026, 8, 1);
  return Rental(
    id: id,
    role: RentalRole.tenant,
    displayName: 'Ev',
    currentRent: rent,
    contractStartDate: DateTime(2024, 7, 1),
    increaseDate: increase,
    lastRenewalDate: last,
    renewalResolved: resolved,
    createdAt: now,
    updatedAt: now,
    history: history,
  );
}

void main() {
  final today = DateTime(2026, 8, 13);

  group('date utils', () {
    test('normal +1 yıl', () {
      expect(
        nextIncreaseAnniversary(DateTime(2026, 7, 1)),
        DateTime(2027, 7, 1),
      );
    });

    test('29 Şubat leap → 28 Şubat', () {
      expect(
        nextIncreaseAnniversary(DateTime(2024, 2, 29)),
        DateTime(2025, 2, 28),
      );
    });

    test('dateOnly timezone kayması yok', () {
      final d = DateTime(2026, 7, 1, 23, 30);
      expect(dateOnly(d), DateTime(2026, 7, 1));
    });
  });

  group('scenario A — completed past renewal', () {
    test('Evet yenilendi → last + next year, overdue yok', () {
      final last = DateTime(2026, 7, 1);
      final next = nextIncreaseAnniversary(last);
      final r = _rental(id: 'a', increase: next, last: last, resolved: true);
      final status = renewalStatusOf(r, now: today);
      expect(status.isOverdue, isFalse);
      expect(status.shortLabel, isNot(contains('geçti')));
      expect(r.lastRenewalDate, DateTime(2026, 7, 1));
      expect(r.nextRenewalDate, DateTime(2027, 7, 1));

      final summary = DashboardLogic.summarize([r], now: today);
      expect(summary.upcomingCount, 0);
      expect(summary.thisMonthCount, 0);
    });
  });

  group('scenario B — actual overdue', () {
    test('Hayır bekliyor → Yenileme geçti', () {
      final r = _rental(
        id: 'b',
        increase: DateTime(2026, 7, 1),
        resolved: true,
      );
      final status = renewalStatusOf(r, now: today);
      expect(status.isOverdue, isTrue);
      expect(status.shortLabel, 'Yenileme geçti');
    });
  });

  group('scenario C — future', () {
    test('kalan gün doğru', () {
      final r = _rental(
        id: 'c',
        increase: DateTime(2026, 9, 15),
        resolved: true,
      );
      final status = renewalStatusOf(r, now: today);
      expect(status.urgency, RenewalUrgency.ok);
      expect(status.daysUntil, 33);
      expect(status.shortLabel, '33 gün kaldı');
    });
  });

  group('migration', () {
    test('future legacy → next, resolved', () {
      final legacy = _rental(id: 'f', increase: DateTime(2026, 10, 1));
      expect(legacy.renewalResolved, isNull);
      final m = migrateRentalRenewal(legacy, now: today);
      expect(m.renewalResolved, isTrue);
      expect(m.nextRenewalDate, DateTime(2026, 10, 1));
      expect(m.lastRenewalDate, isNull);
    });

    test('past + snapshot → auto last/next', () {
      final legacy = _rental(
        id: 'h',
        increase: DateTime(2026, 7, 1),
        history: [
          RentalCalculationSnapshot(
            id: 's',
            calculatedAt: DateTime(2026, 7, 2),
            oldRent: 30000,
            calculatedRent: 39000,
            tufeRatePercent: 30,
            applicableRatePercent: 30,
            tufeReferenceMonth: '2026-07',
            increaseDate: DateTime(2026, 7, 1),
          ),
        ],
      );
      final m = migrateRentalRenewal(legacy, now: today);
      expect(m.renewalResolved, isTrue);
      expect(dateOnly(m.lastRenewalDate!), DateTime(2026, 7, 1));
      expect(dateOnly(m.nextRenewalDate), DateTime(2027, 7, 1));
      expect(renewalStatusOf(m, now: today).isOverdue, isFalse);
    });

    test('past ambiguous → needs confirmation, not overdue', () {
      final legacy = _rental(id: 'u', increase: DateTime(2026, 7, 1));
      final m = migrateRentalRenewal(legacy, now: today);
      expect(m.renewalResolved, isFalse);
      final status = renewalStatusOf(m, now: today);
      expect(status.needsConfirmation, isTrue);
      expect(status.shortLabel, 'Tarihi doğrula');
      expect(status.isOverdue, isFalse);
    });

    test('migration idempotent', () {
      final legacy = _rental(id: 'i', increase: DateTime(2026, 7, 1));
      final once = migrateRentalRenewal(legacy, now: today);
      final twice = migrateRentalRenewal(once, now: today);
      expect(twice.renewalResolved, once.renewalResolved);
      expect(twice.nextRenewalDate, once.nextRenewalDate);
      expect(twice.lastRenewalDate, once.lastRenewalDate);
    });

    test('repository migrateRenewalsIfNeeded persists', () async {
      SharedPreferences.setMockInitialValues({
        RentalRepository.storageKey: jsonEncode([
          _rental(id: '1', increase: DateTime(2026, 7, 1)).toJson()
            ..remove('renewalResolved'),
        ]),
      });
      // Ensure raw JSON has no renewalResolved
      final prefs = await SharedPreferences.getInstance();
      final rawMap =
          jsonDecode(prefs.getString(RentalRepository.storageKey)!) as List;
      (rawMap.first as Map).remove('renewalResolved');
      await prefs.setString(RentalRepository.storageKey, jsonEncode(rawMap));

      final repo = RentalRepository(prefs);
      final changed = await repo.migrateRenewalsIfNeeded(now: today);
      expect(changed, isTrue);
      final loaded = repo.loadAll().single;
      expect(loaded.renewalResolved, isFalse);
      final again = await repo.migrateRenewalsIfNeeded(now: today);
      expect(again, isFalse);
    });
  });

  group('applyCalculation advances last/next', () {
    test('completed period → last + next year', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = RentalRepository(prefs);
      final rental = _rental(
        id: 'p',
        increase: DateTime(2026, 8, 1),
        resolved: true,
        rent: 25000,
      );
      await repo.add(rental, isPro: true);
      final result = CalculationResult(
        input: CalculationInput(
          currentRent: 25000,
          renewalYear: 2026,
          renewalMonth: 8,
          renewalDay: 1,
          contractStart: DateTime(2024, 8, 1),
        ),
        tufeMaxRatePercent: 31.9,
        applicableRatePercent: 31.9,
        calculatedRent: 32975,
        increaseAmount: 7975,
        contractCompare: ContractCompareKind.none,
        isFiveYearsOrMore: false,
        tuikReleaseDate: DateTime(2026, 8, 3),
        datasetUpdatedAt: DateTime(2026, 8, 3),
        rateSourceLabel: 'test',
      );
      final updated = await repo.applyCalculation(
        rentalId: 'p',
        result: result,
      );
      expect(updated, isNotNull);
      expect(dateOnly(updated!.lastRenewalDate!), DateTime(2026, 8, 1));
      expect(dateOnly(updated.nextRenewalDate), DateTime(2027, 8, 1));
      expect(updated.history, hasLength(1));
    });
  });

  group('backup roundtrip', () {
    test('last/next korunur', () {
      final service = RentalBackupService();
      final rental = _rental(
        id: 'bk',
        increase: DateTime(2027, 7, 1),
        last: DateTime(2026, 7, 1),
        resolved: true,
      );
      final bytes = service.encodePayload(service.buildPayload([rental]));
      final decoded = service.decodeBackupBytes(bytes, isPro: true);
      expect(decoded.isValid, isTrue);
      final r = decoded.rentals!.single;
      expect(dateOnly(r.lastRenewalDate!), DateTime(2026, 7, 1));
      expect(dateOnly(r.nextRenewalDate), DateTime(2027, 7, 1));
      expect(r.renewalResolved, isTrue);
    });
  });

  group('manual calculation date not auto-rolled', () {
    test('createFromCalculation keeps input renewalDate', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = RentalRepository(prefs);
      final result = CalculationResult(
        input: CalculationInput(
          currentRent: 39000,
          renewalYear: 2026,
          renewalMonth: 7,
          renewalDay: 1,
          contractStart: DateTime(2024, 7, 1),
        ),
        tufeMaxRatePercent: 30,
        applicableRatePercent: 30,
        calculatedRent: 50700,
        increaseAmount: 11700,
        contractCompare: ContractCompareKind.none,
        isFiveYearsOrMore: false,
        tuikReleaseDate: DateTime(2026, 7, 3),
        datasetUpdatedAt: DateTime(2026, 7, 3),
        rateSourceLabel: 'test',
      );
      final created = await repo.createFromCalculation(
        displayName: 'Ev',
        role: RentalRole.tenant,
        result: result,
        isPro: true,
        includeSnapshot: false,
      );
      expect(dateOnly(created!.nextRenewalDate), DateTime(2026, 7, 1));
      // Manuel kayıt form confirmation'ı yok; tarih olduğu gibi next kalır.
      expect(created.lastRenewalDate, isNull);
    });
  });
}
