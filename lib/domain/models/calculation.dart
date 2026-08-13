enum PropertyType { residential, commercial }

class CalculationInput {
  const CalculationInput({
    required this.currentRent,
    required this.renewalYear,
    required this.renewalMonth,
    required this.contractStart,
    this.renewalDay = 1,
    this.contractIncreasePercent,
    this.propertyType = PropertyType.residential,
  });

  final double currentRent;
  final int renewalYear;
  final int renewalMonth; // 1-12
  /// Yenileme günü (5+ yıl eşiği için; oran eşlemesi aya göredir).
  final int renewalDay;
  final DateTime contractStart;
  final double? contractIncreasePercent;
  final PropertyType propertyType;

  String get renewalMonthKey {
    final m = renewalMonth.toString().padLeft(2, '0');
    return '$renewalYear-$m';
  }

  DateTime get renewalDate =>
      DateTime(renewalYear, renewalMonth, renewalDay.clamp(1, 31));
}

enum ContractCompareKind { none, contractLower, contractHigher, contractEqual }

class CalculationResult {
  const CalculationResult({
    required this.input,
    required this.tufeMaxRatePercent,
    required this.applicableRatePercent,
    required this.calculatedRent,
    required this.increaseAmount,
    required this.contractCompare,
    required this.isFiveYearsOrMore,
    required this.tuikReleaseDate,
    required this.datasetUpdatedAt,
    required this.rateSourceLabel,
    this.tuikSourceUrl,
  });

  final CalculationInput input;
  final double tufeMaxRatePercent;
  final double applicableRatePercent;
  final double calculatedRent;
  final double increaseAmount;
  final ContractCompareKind contractCompare;
  final bool isFiveYearsOrMore;
  final DateTime tuikReleaseDate;
  final DateTime datasetUpdatedAt;
  final String rateSourceLabel;

  /// Kullanılan oranın doğrulanmış bülten URL’si (yoksa UI genel portal’a düşer).
  final String? tuikSourceUrl;
}

sealed class CalculationOutcome {}

class CalculationSuccess extends CalculationOutcome {
  CalculationSuccess(this.result);
  final CalculationResult result;
}

class CalculationRateMissing extends CalculationOutcome {
  CalculationRateMissing({
    required this.requestedMonth,
    this.latestAvailableMonth,
  });
  final String requestedMonth;
  final String? latestAvailableMonth;
}

class CalculationInvalidInput extends CalculationOutcome {
  CalculationInvalidInput(this.message);
  final String message;
}
