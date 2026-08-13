import 'package:flutter_test/flutter_test.dart';
import 'package:kira_artisi_hesapla/domain/dashboard_logic.dart';
import 'package:kira_artisi_hesapla/domain/models/rental.dart';
import 'package:kira_artisi_hesapla/domain/models/tufe_rate.dart';

Rental _rental({
  required String id,
  required DateTime increase,
  double rent = 10000,
  DateTime? created,
  DateTime? updated,
  List<RentalCalculationSnapshot> history = const [],
}) {
  final now = created ?? DateTime(2026, 1, 1);
  return Rental(
    id: id,
    role: RentalRole.tenant,
    displayName: 'Daire $id',
    currentRent: rent,
    contractStartDate: DateTime(2024, 1, 1),
    increaseDate: increase,
    createdAt: now,
    updatedAt: updated ?? now,
    history: history,
  );
}

void main() {
  group('DashboardLogic.summarize', () {
    test('aktif / yaklaşan / bu ay sayıları', () {
      final now = DateTime(2026, 8, 10);
      final rentals = [
        _rental(id: 'a', increase: DateTime(2026, 8, 20)), // bu ay + upcoming
        _rental(id: 'b', increase: DateTime(2026, 9, 15)), // upcoming (36 gün)
        _rental(id: 'c', increase: DateTime(2026, 11, 1)), // uzak
        _rental(id: 'd', increase: DateTime(2026, 7, 1)), // geçmiş
      ];

      final s = DashboardLogic.summarize(rentals, now: now);
      expect(s.activeCount, 4);
      expect(s.thisMonthCount, 1);
      expect(s.upcomingCount, 2);
    });
  });

  group('DashboardLogic.estimateNewRent', () {
    final bundle = TufeRateBundle(
      version: 1,
      updatedAt: DateTime(2026, 8, 3),
      sourceNote: 'test',
      rates: [
        TufeRate(
          renewalMonth: '2026-07',
          ratePercent: 32.03,
          tuikReleaseDate: DateTime(2026, 7, 3),
        ),
        TufeRate(
          renewalMonth: '2026-08',
          ratePercent: 31.90,
          tuikReleaseDate: DateTime(2026, 8, 3),
        ),
      ],
    );

    test('resmi dönem oranı ile tahmin', () {
      final rental = _rental(
        id: '1',
        increase: DateTime(2026, 8, 15),
        rent: 25000,
      );
      final est = DashboardLogic.estimateNewRent(
        rental: rental,
        bundle: bundle,
      );
      expect(est, isNotNull);
      expect(est!.isOfficialForPeriod, isTrue);
      expect(est.ratePercent, 31.90);
      expect(est.rateMonthKey, '2026-08');
      expect(est.amount, closeTo(25000 * 1.3190, 0.01));
    });

    test('oran yoksa latest fallback', () {
      final rental = _rental(
        id: '2',
        increase: DateTime(2026, 9, 1),
        rent: 10000,
      );
      final est = DashboardLogic.estimateNewRent(
        rental: rental,
        bundle: bundle,
      );
      expect(est, isNotNull);
      expect(est!.isOfficialForPeriod, isFalse);
      expect(est.rateMonthKey, '2026-08');
      expect(est.ratePercent, 31.90);
    });
  });

  group('RequestedRentCompare', () {
    test('fark = talep − hesaplanan', () {
      const c = RequestedRentCompare(
        calculatedRent: 30000,
        requestedRent: 35000,
      );
      expect(c.difference, 5000);

      const under = RequestedRentCompare(
        calculatedRent: 30000,
        requestedRent: 28000,
      );
      expect(under.difference, -2000);
    });
  });
}
