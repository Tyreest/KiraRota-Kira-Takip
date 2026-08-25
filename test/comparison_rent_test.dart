import 'package:flutter_test/flutter_test.dart';
import 'package:kira_artisi_hesapla/core/format.dart';
import 'package:kira_artisi_hesapla/domain/dashboard_logic.dart';

void main() {
  group('RequestedRentCompare', () {
    const current = 35000.0;
    const calculated = 46165.0;
    const appliedRate = 31.9;

    RequestedRentCompare cmp(double comparison) => RequestedRentCompare(
      calculatedRent: calculated,
      requestedRent: comparison,
      currentRent: current,
      calculatedIncreaseRatePercent: appliedRate,
    );

    test('canonical: 59000 → ~%68.6 and ~36.7 puan yüksek', () {
      final c = cmp(59000);
      expect(c.difference, closeTo(12835, 0.01));
      expect(c.comparisonIncreasePercent, closeTo(68.571428, 0.001));
      expect(c.percentagePointDifference, closeTo(36.671428, 0.001));
      expect(c.rateInsightLabel, contains('puan yüksek'));
      expect(c.rateInsightLabel.toLowerCase(), isNot(contains('tüfe')));
      expect(formatSignedPercent(c.comparisonIncreasePercent!), '+%68,6');
      expect(formatDecimal(c.percentagePointDifference!.abs()), '36,7');
    });

    test('comparison > calculated rate', () {
      final c = cmp(59000);
      expect(c.percentagePointDifference! > 0, isTrue);
      expect(c.rateInsightLabel, startsWith('Hesaplanan artış oranından'));
      expect(c.rateInsightLabel, endsWith('puan yüksek'));
    });

    test('comparison < calculated rate', () {
      // calculated 46165 ≈ +31.9%; lower comparison e.g. 40000 ≈ +14.3%
      final c = cmp(40000);
      expect(c.comparisonIncreasePercent, closeTo(14.285714, 0.001));
      expect(c.percentagePointDifference! < 0, isTrue);
      expect(c.rateInsightLabel, endsWith('puan düşük'));
    });

    test('comparison == calculated rent → aynı oran insight', () {
      final c = cmp(calculated);
      expect(c.difference, 0);
      expect(c.comparisonIncreasePercent, closeTo(appliedRate, 0.05));
      expect(c.rateInsightLabel, 'Hesaplanan artış oranıyla aynı');
    });

    test('zero difference money', () {
      final c = cmp(calculated);
      expect(c.difference.abs(), 0);
    });

    test('negative comparison change vs current', () {
      final c = cmp(30000);
      expect(c.comparisonIncreasePercent, closeTo(-14.285714, 0.001));
      expect(formatSignedPercent(c.comparisonIncreasePercent!), '-%14,3');
    });

    test('comparison == current → %0', () {
      final c = cmp(current);
      expect(c.comparisonIncreasePercent, 0);
      expect(formatSignedPercent(0), '%0');
    });

    test('does not mutate calculated result fields', () {
      final c = cmp(59000);
      expect(c.calculatedRent, 46165);
      expect(c.calculatedIncreaseRatePercent, 31.9);
      // constructing compare never writes back
      expect(c.comparisonRent, 59000);
      expect(c.requestedRent, isNot(c.calculatedRent));
    });

    test('currentRent <= 0 → null percent, no NaN', () {
      final c = RequestedRentCompare(
        calculatedRent: 100,
        requestedRent: 120,
        currentRent: 0,
        calculatedIncreaseRatePercent: 10,
      );
      expect(c.comparisonIncreasePercent, isNull);
      expect(c.percentagePointDifference, isNull);
      expect(c.rateInsightLabel, isEmpty);
    });

    test('percentage-point formatting uses puan not percent-high wording', () {
      final c = cmp(59000);
      expect(c.rateInsightLabel.contains('%'), isFalse);
      expect(c.rateInsightLabel.contains('puan'), isTrue);
    });
  });
}
