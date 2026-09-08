import 'package:flutter_test/flutter_test.dart';
import 'package:kira_artisi_hesapla/data/rental_repository.dart';
import 'package:kira_artisi_hesapla/domain/calculation_engine.dart';
import 'package:kira_artisi_hesapla/domain/models/calculation.dart';
import 'package:kira_artisi_hesapla/domain/models/rental.dart';
import 'package:kira_artisi_hesapla/domain/models/tufe_rate.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

CalculationInput _input({
  double rent = 10000,
  int year = 2027,
  int month = 9,
  double? contract,
  PropertyType type = PropertyType.residential,
}) {
  return CalculationInput(
    currentRent: rent,
    renewalYear: year,
    renewalMonth: month,
    renewalDay: 1,
    contractStart: DateTime(2024, 9, 1),
    contractIncreasePercent: contract,
    propertyType: type,
  );
}

void main() {
  const engine = CalculationEngine();

  group('forecast / estimate calculation', () {
    test('1. official rate exists → normal official result', () {
      final out = engine.calculate(
        input: _input(year: 2026, month: 9),
        bundle: _bundle(),
        rateSourceLabel: 't',
        forecastBasis: RateBasisKind.estimatedLatestOfficial,
      );
      final r = (out as CalculationSuccess).result;
      expect(r.rateBasis, RateBasisKind.official);
      expect(r.isEstimated, isFalse);
      expect(r.tufeMaxRatePercent, 31.79);
      expect(r.estimateSourceMonthKey, isNull);
    });

    test('2. official missing without forecast → RateMissing', () {
      final out = engine.calculate(
        input: _input(year: 2027, month: 9),
        bundle: _bundle(),
        rateSourceLabel: 't',
      );
      expect(out, isA<CalculationRateMissing>());
      final m = out as CalculationRateMissing;
      expect(m.requestedMonth, '2027-09');
      expect(m.latestAvailableMonth, '2026-09');
    });

    test('3–4. latest official estimate enabled from repository latest', () {
      final out = engine.calculate(
        input: _input(year: 2027, month: 9),
        bundle: _bundle(),
        rateSourceLabel: 't',
        forecastBasis: RateBasisKind.estimatedLatestOfficial,
      );
      final r = (out as CalculationSuccess).result;
      expect(r.isEstimated, isTrue);
      expect(r.rateBasis, RateBasisKind.estimatedLatestOfficial);
      expect(r.tufeMaxRatePercent, 31.79);
      expect(r.estimateSourceMonthKey, '2026-09');
      expect(r.calculatedRent, 13179);
    });

    test('5. user estimate enables calculation', () {
      final out = engine.calculate(
        input: _input(year: 2027, month: 9),
        bundle: _bundle(),
        rateSourceLabel: 't',
        forecastBasis: RateBasisKind.estimatedUserProvided,
        userForecastRatePercent: 25,
      );
      final r = (out as CalculationSuccess).result;
      expect(r.rateBasis, RateBasisKind.estimatedUserProvided);
      expect(r.tufeMaxRatePercent, 25);
      expect(r.estimateSourceMonthKey, isNull);
      expect(r.calculatedRent, 12500);
    });

    test('6. invalid user estimate rejected', () {
      expect(
        engine.calculate(
          input: _input(),
          bundle: _bundle(),
          rateSourceLabel: 't',
          forecastBasis: RateBasisKind.estimatedUserProvided,
          userForecastRatePercent: null,
        ),
        isA<CalculationInvalidInput>(),
      );
      expect(
        engine.calculate(
          input: _input(),
          bundle: _bundle(),
          rateSourceLabel: 't',
          forecastBasis: RateBasisKind.estimatedUserProvided,
          userForecastRatePercent: -1,
        ),
        isA<CalculationInvalidInput>(),
      );
      expect(
        engine.calculate(
          input: _input(),
          bundle: _bundle(),
          rateSourceLabel: 't',
          forecastBasis: RateBasisKind.estimatedUserProvided,
          userForecastRatePercent: double.nan,
        ),
        isA<CalculationInvalidInput>(),
      );
      expect(
        engine.calculate(
          input: _input(),
          bundle: _bundle(),
          rateSourceLabel: 't',
          forecastBasis: RateBasisKind.estimatedUserProvided,
          userForecastRatePercent: 1001,
        ),
        isA<CalculationInvalidInput>(),
      );
    });

    test('7. contract lower than estimated → contract used', () {
      final out = engine.calculate(
        input: _input(contract: 20),
        bundle: _bundle(),
        rateSourceLabel: 't',
        forecastBasis: RateBasisKind.estimatedLatestOfficial,
      );
      final r = (out as CalculationSuccess).result;
      expect(r.applicableRatePercent, 20);
      expect(r.contractCompare, ContractCompareKind.contractLower);
      expect(r.isEstimated, isTrue);
    });

    test('8. estimated lower than contract → estimate ceiling used', () {
      final out = engine.calculate(
        input: _input(contract: 30),
        bundle: _bundle(),
        rateSourceLabel: 't',
        forecastBasis: RateBasisKind.estimatedUserProvided,
        userForecastRatePercent: 20,
      );
      final r = (out as CalculationSuccess).result;
      expect(r.tufeMaxRatePercent, 20);
      expect(r.applicableRatePercent, 20);
      expect(r.contractCompare, ContractCompareKind.contractHigher);
    });

    test('9–12. result metadata for estimated vs official', () {
      final official =
          (engine.calculate(
                    input: _input(year: 2026, month: 9),
                    bundle: _bundle(),
                    rateSourceLabel: 'official-src',
                  )
                  as CalculationSuccess)
              .result;
      expect(official.isEstimated, isFalse);
      expect(official.rateBasis, RateBasisKind.official);

      final latest =
          (engine.calculate(
                    input: _input(year: 2027, month: 9),
                    bundle: _bundle(),
                    rateSourceLabel: 't',
                    forecastBasis: RateBasisKind.estimatedLatestOfficial,
                  )
                  as CalculationSuccess)
              .result;
      expect(latest.isEstimated, isTrue);
      expect(latest.estimateSourceMonthKey, '2026-09');
      expect(latest.rateSourceLabel, contains('Tahmini'));

      final user =
          (engine.calculate(
                    input: _input(year: 2027, month: 9),
                    bundle: _bundle(),
                    rateSourceLabel: 't',
                    forecastBasis: RateBasisKind.estimatedUserProvided,
                    userForecastRatePercent: 25,
                  )
                  as CalculationSuccess)
              .result;
      expect(user.rateBasis, RateBasisKind.estimatedUserProvided);
      expect(user.tuikSourceUrl, isNull);
    });

    test('13–14. estimated cannot apply or mutate rental/history', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = RentalRepository(prefs);
      await repo.add(
        Rental(
          id: 'r1',
          role: RentalRole.tenant,
          displayName: 'Ev',
          currentRent: 10000,
          contractStartDate: DateTime(2024, 9, 1),
          increaseDate: DateTime(2027, 9, 1),
          renewalResolved: true,
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        ),
        isPro: true,
      );

      final estimated =
          (engine.calculate(
                    input: _input(year: 2027, month: 9),
                    bundle: _bundle(),
                    rateSourceLabel: 't',
                    forecastBasis: RateBasisKind.estimatedLatestOfficial,
                  )
                  as CalculationSuccess)
              .result;

      final applied = await repo.applyCalculation(
        rentalId: 'r1',
        result: estimated,
      );
      expect(applied, isNull);

      final after = repo.findById('r1')!;
      expect(after.currentRent, 10000);
      expect(after.history, isEmpty);
      expect(after.nextRenewalDate, DateTime(2027, 9, 1));

      final created = await repo.createFromCalculation(
        displayName: 'Senaryo',
        role: RentalRole.tenant,
        result: estimated,
        isPro: true,
      );
      expect(created, isNull);
      expect(repo.loadAll().length, 1);
    });

    test('15. unsupported historical residential stays blocked (no forecast)', () {
      final out = engine.calculate(
        input: CalculationInput(
          currentRent: 10000,
          renewalYear: 2023,
          renewalMonth: 6,
          renewalDay: 15,
          contractStart: DateTime(2020, 1, 1),
          propertyType: PropertyType.residential,
        ),
        bundle: _bundle(),
        rateSourceLabel: 't',
        forecastBasis: RateBasisKind.estimatedLatestOfficial,
        userForecastRatePercent: 25,
      );
      expect(out, isA<CalculationUnsupportedPeriod>());
    });

    test('16. estimate does not write into TÜFE bundle', () {
      final bundle = _bundle();
      final before = bundle.rates.length;
      engine.calculate(
        input: _input(year: 2027, month: 9),
        bundle: bundle,
        rateSourceLabel: 't',
        forecastBasis: RateBasisKind.estimatedUserProvided,
        userForecastRatePercent: 22,
      );
      expect(bundle.rates.length, before);
      expect(bundle.findByRenewalMonth('2027-09'), isNull);
      expect(bundle.latest!.renewalMonth, '2026-09');
    });

    test('17. share text must mention tahmini for estimates', () {
      final r =
          (engine.calculate(
                    input: _input(year: 2027, month: 9),
                    bundle: _bundle(),
                    rateSourceLabel: 't',
                    forecastBasis: RateBasisKind.estimatedLatestOfficial,
                  )
                  as CalculationSuccess)
              .result;
      expect(r.isEstimated, isTrue);
      // UI share builder is in CalculateScreen; assert metadata used by it.
      expect(r.rateSourceLabel.toLowerCase(), contains('tahmini'));
    });

    test('18. PDF path: estimated results stay non-official', () {
      final r =
          (engine.calculate(
                    input: _input(year: 2027, month: 9),
                    bundle: _bundle(),
                    rateSourceLabel: 't',
                    forecastBasis: RateBasisKind.estimatedUserProvided,
                    userForecastRatePercent: 25,
                  )
                  as CalculationSuccess)
              .result;
      expect(r.isEstimated, isTrue);
      expect(r.rateBasis, isNot(RateBasisKind.official));
      // UI disables PDF when isEstimated; repository also blocks persist.
    });

    test('dynamic latest: newer month becomes estimate proxy', () {
      final richer = TufeRateBundle(
        version: 4,
        updatedAt: DateTime(2026, 10, 3),
        sourceNote: 't',
        rates: [
          ..._bundle().rates,
          TufeRate(
            renewalMonth: '2026-10',
            ratePercent: 30.5,
            tuikReleaseDate: DateTime(2026, 10, 3),
          ),
        ],
      );
      final r =
          (engine.calculate(
                    input: _input(year: 2027, month: 9),
                    bundle: richer,
                    rateSourceLabel: 't',
                    forecastBasis: RateBasisKind.estimatedLatestOfficial,
                  )
                  as CalculationSuccess)
              .result;
      expect(r.tufeMaxRatePercent, 30.5);
      expect(r.estimateSourceMonthKey, '2026-10');
    });
  });
}
