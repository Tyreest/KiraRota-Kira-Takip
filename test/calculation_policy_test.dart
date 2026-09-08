import 'package:flutter_test/flutter_test.dart';
import 'package:kira_artisi_hesapla/domain/calculation_engine.dart';
import 'package:kira_artisi_hesapla/domain/dashboard_logic.dart';
import 'package:kira_artisi_hesapla/domain/models/calculation.dart';
import 'package:kira_artisi_hesapla/domain/models/rental.dart';
import 'package:kira_artisi_hesapla/domain/models/tufe_rate.dart';

TufeRateBundle _bundle() => TufeRateBundle(
  version: 3,
  updatedAt: DateTime(2026, 9, 3),
  sourceNote: 't',
  rates: [
    TufeRate(
      renewalMonth: '2026-08',
      ratePercent: 31.9,
      tuikReleaseDate: DateTime(2026, 8, 3),
    ),
    TufeRate(
      renewalMonth: '2026-09',
      ratePercent: 31.79,
      tuikReleaseDate: DateTime(2026, 9, 3),
    ),
  ],
);

void main() {
  const engine = CalculationEngine();

  test('2 decimal rounding on calculated rent', () {
    final outcome = engine.calculate(
      input: CalculationInput(
        currentRent: 10000.1,
        renewalYear: 2026,
        renewalMonth: 9,
        contractStart: DateTime(2024, 9, 1),
      ),
      bundle: _bundle(),
      rateSourceLabel: 't',
    );
    final r = (outcome as CalculationSuccess).result;
    expect(r.calculatedRent, roundMoneyLike(r.calculatedRent));
    expect(
      r.calculatedRent,
      closeTo(10000.1 * 1.3179, 0.011),
    );
    // kuruş
    final s = r.calculatedRent.toStringAsFixed(2);
    expect(double.parse(s), r.calculatedRent);
  });

  test('dashboard estimate == engine for official month', () {
    final rental = Rental(
      id: '1',
      role: RentalRole.tenant,
      displayName: 'Ev',
      currentRent: 38000,
      contractStartDate: DateTime(2024, 9, 1),
      increaseDate: DateTime(2026, 9, 15),
      renewalResolved: true,
      contractIncreaseRate: null,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );
    final estimate = DashboardLogic.estimateNewRent(
      rental: rental,
      bundle: _bundle(),
    )!;
    final engineOut = engine.calculate(
      input: CalculationInput(
        currentRent: rental.currentRent,
        renewalYear: 2026,
        renewalMonth: 9,
        renewalDay: 15,
        contractStart: rental.contractStartDate,
      ),
      bundle: _bundle(),
      rateSourceLabel: 't',
    );
    final calc = (engineOut as CalculationSuccess).result;
    expect(estimate.amount, calc.calculatedRent);
    expect(estimate.ratePercent, calc.applicableRatePercent);
    expect(estimate.isOfficialForPeriod, isTrue);
  });

  test('dashboard respects contract rate like engine', () {
    final rental = Rental(
      id: '1',
      role: RentalRole.tenant,
      displayName: 'Ev',
      currentRent: 50000,
      contractStartDate: DateTime(2024, 8, 1),
      increaseDate: DateTime(2026, 8, 1),
      renewalResolved: true,
      contractIncreaseRate: 20,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );
    final estimate = DashboardLogic.estimateNewRent(
      rental: rental,
      bundle: _bundle(),
    )!;
    expect(estimate.ratePercent, 20);
    expect(estimate.amount, 60000);
  });

  group('residential cap window', () {
    test('konut cap döneminde unsupported', () {
      final o = engine.calculate(
        input: CalculationInput(
          currentRent: 10000,
          renewalYear: 2023,
          renewalMonth: 6,
          renewalDay: 15,
          contractStart: DateTime(2020, 6, 15),
          propertyType: PropertyType.residential,
        ),
        bundle: _bundle(),
        rateSourceLabel: 't',
      );
      expect(o, isA<CalculationUnsupportedPeriod>());
    });

    test('işyeri cap döneminde TÜFE dener (oran yoksa missing)', () {
      final o = engine.calculate(
        input: CalculationInput(
          currentRent: 10000,
          renewalYear: 2023,
          renewalMonth: 6,
          contractStart: DateTime(2020, 6, 15),
          propertyType: PropertyType.commercial,
        ),
        bundle: _bundle(),
        rateSourceLabel: 't',
      );
      expect(o, isA<CalculationRateMissing>());
    });

    test('boundary: 2024-06-30 konut kapalı, 2024-07-01 açık (oran yok)', () {
      expect(
        ResidentialRentCapWindow.contains(DateTime(2024, 6, 30)),
        isTrue,
      );
      expect(
        ResidentialRentCapWindow.contains(DateTime(2024, 7, 1)),
        isFalse,
      );
      expect(
        ResidentialRentCapWindow.contains(DateTime(2022, 6, 11)),
        isTrue,
      );
      expect(
        ResidentialRentCapWindow.contains(DateTime(2022, 6, 10)),
        isFalse,
      );
    });

    test('güncel konut dönem hesabı çalışır', () {
      final o = engine.calculate(
        input: CalculationInput(
          currentRent: 10000,
          renewalYear: 2026,
          renewalMonth: 9,
          contractStart: DateTime(2024, 9, 1),
          propertyType: PropertyType.residential,
        ),
        bundle: _bundle(),
        rateSourceLabel: 't',
      );
      expect(o, isA<CalculationSuccess>());
    });
  });
}

double roundMoneyLike(double v) => (v * 100).roundToDouble() / 100;
