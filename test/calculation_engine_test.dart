import 'package:flutter_test/flutter_test.dart';
import 'package:kira_artisi_hesapla/domain/calculation_engine.dart';
import 'package:kira_artisi_hesapla/domain/models/calculation.dart';
import 'package:kira_artisi_hesapla/domain/models/tufe_rate.dart';

/// Sabit tarihsel oranlar — güncel oranla güncellenmez.
TufeRateBundle _fixtureBundle() {
  return TufeRateBundle(
    version: 1,
    updatedAt: DateTime(2025, 8, 1),
    sourceNote: 'test',
    rates: [
      TufeRate(
        renewalMonth: '2025-07',
        ratePercent: 40.09,
        tuikReleaseDate: DateTime(2025, 7, 3),
      ),
    ],
  );
}

CalculationInput _input({
  double rent = 50000,
  int year = 2025,
  int month = 7,
  DateTime? start,
  double? contract,
}) {
  return CalculationInput(
    currentRent: rent,
    renewalYear: year,
    renewalMonth: month,
    contractStart: start ?? DateTime(2024, 7, 1),
    contractIncreasePercent: contract,
  );
}

void main() {
  const engine = CalculationEngine();

  test('sabit oran: 50000 × %40.09', () {
    final outcome = engine.calculate(
      input: _input(),
      bundle: _fixtureBundle(),
      rateSourceLabel: 'test',
    );
    expect(outcome, isA<CalculationSuccess>());
    final r = (outcome as CalculationSuccess).result;
    expect(r.tufeMaxRatePercent, 40.09);
    expect(r.applicableRatePercent, 40.09);
    expect(r.calculatedRent, closeTo(50000 * 1.4009, 0.01));
    expect(r.increaseAmount, closeTo(50000 * 0.4009, 0.01));
    expect(r.isFiveYearsOrMore, isFalse);
  });

  test('sözleşme oranı düşükse sözleşme uygulanır', () {
    final outcome = engine.calculate(
      input: _input(contract: 20),
      bundle: _fixtureBundle(),
      rateSourceLabel: 'test',
    );
    final r = (outcome as CalculationSuccess).result;
    expect(r.applicableRatePercent, 20);
    expect(r.contractCompare, ContractCompareKind.contractLower);
    expect(r.calculatedRent, closeTo(60000, 0.01));
  });

  test('sözleşme oranı yüksekse TÜFE azami uygulanır', () {
    final outcome = engine.calculate(
      input: _input(contract: 55),
      bundle: _fixtureBundle(),
      rateSourceLabel: 'test',
    );
    final r = (outcome as CalculationSuccess).result;
    expect(r.applicableRatePercent, 40.09);
    expect(r.contractCompare, ContractCompareKind.contractHigher);
  });

  test('eksik ay sessizce taşınmaz', () {
    final outcome = engine.calculate(
      input: _input(year: 2025, month: 8),
      bundle: _fixtureBundle(),
      rateSourceLabel: 'test',
    );
    expect(outcome, isA<CalculationRateMissing>());
    final m = outcome as CalculationRateMissing;
    expect(m.requestedMonth, '2025-08');
    expect(m.latestAvailableMonth, '2025-07');
  });

  test('5+ yıl uyarısı bayrağı', () {
    final outcome = engine.calculate(
      input: _input(
        start: DateTime(2019, 7, 1),
        year: 2025,
        month: 7,
      ),
      bundle: _fixtureBundle(),
      rateSourceLabel: 'test',
    );
    final r = (outcome as CalculationSuccess).result;
    expect(r.isFiveYearsOrMore, isTrue);
  });

  test('geçersiz kira', () {
    final outcome = engine.calculate(
      input: _input(rent: 0),
      bundle: _fixtureBundle(),
      rateSourceLabel: 'test',
    );
    expect(outcome, isA<CalculationInvalidInput>());
  });

  test('isFiveYearsOrMore sınır günü', () {
    expect(
      CalculationEngine.isFiveYearsOrMore(
        contractStart: DateTime(2020, 6, 15),
        renewalDate: DateTime(2025, 6, 15),
      ),
      isTrue,
    );
    expect(
      CalculationEngine.isFiveYearsOrMore(
        contractStart: DateTime(2020, 6, 15),
        renewalDate: DateTime(2025, 6, 14),
      ),
      isFalse,
    );
  });
}
