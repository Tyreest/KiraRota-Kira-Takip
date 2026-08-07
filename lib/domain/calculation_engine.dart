import 'models/calculation.dart';
import 'models/tufe_rate.dart';

/// Saf hesap motoru — UI ve ağ bilmez.
class CalculationEngine {
  const CalculationEngine();

  /// Yenileme ayının 1. günü ile sözleşme başlangıcı arasında ≥ 5 yıl mı?
  static bool isFiveYearsOrMore({
    required DateTime contractStart,
    required DateTime renewalDate,
  }) {
    final start = DateTime(contractStart.year, contractStart.month, contractStart.day);
    final renewal = DateTime(renewalDate.year, renewalDate.month, renewalDate.day);
    final fifthAnniversary = DateTime(start.year + 5, start.month, start.day);
    return !renewal.isBefore(fifthAnniversary);
  }

  CalculationOutcome calculate({
    required CalculationInput input,
    required TufeRateBundle bundle,
    required String rateSourceLabel,
  }) {
    if (input.currentRent <= 0) {
      return CalculationInvalidInput('Kira tutarı 0’dan büyük olmalıdır.');
    }
    if (input.renewalMonth < 1 || input.renewalMonth > 12) {
      return CalculationInvalidInput('Yenileme ayı geçersiz.');
    }
    if (input.contractIncreasePercent != null &&
        input.contractIncreasePercent! < 0) {
      return CalculationInvalidInput('Sözleşme artış oranı negatif olamaz.');
    }

    final rate = bundle.findByRenewalMonth(input.renewalMonthKey);
    if (rate == null) {
      return CalculationRateMissing(
        requestedMonth: input.renewalMonthKey,
        latestAvailableMonth: bundle.latest?.renewalMonth,
      );
    }

    final tufeMax = rate.ratePercent;
    final contract = input.contractIncreasePercent;

    late final double applicable;
    late final ContractCompareKind compare;
    if (contract == null) {
      applicable = tufeMax;
      compare = ContractCompareKind.none;
    } else if (contract < tufeMax) {
      applicable = contract;
      compare = ContractCompareKind.contractLower;
    } else if (contract > tufeMax) {
      applicable = tufeMax;
      compare = ContractCompareKind.contractHigher;
    } else {
      applicable = tufeMax;
      compare = ContractCompareKind.contractEqual;
    }

    final calculated = input.currentRent * (1 + applicable / 100.0);
    final increase = calculated - input.currentRent;
    final fivePlus = isFiveYearsOrMore(
      contractStart: input.contractStart,
      renewalDate: input.renewalDate,
    );

    return CalculationSuccess(
      CalculationResult(
        input: input,
        tufeMaxRatePercent: tufeMax,
        applicableRatePercent: applicable,
        calculatedRent: calculated,
        increaseAmount: increase,
        contractCompare: compare,
        isFiveYearsOrMore: fivePlus,
        tuikReleaseDate: rate.tuikReleaseDate,
        datasetUpdatedAt: bundle.updatedAt,
        rateSourceLabel: rateSourceLabel,
      ),
    );
  }
}
