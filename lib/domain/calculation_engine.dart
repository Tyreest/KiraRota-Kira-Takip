import '../core/money.dart';
import 'models/calculation.dart';
import 'models/tufe_rate.dart';

/// Saf hesap motoru — UI ve ağ bilmez.
class CalculationEngine {
  const CalculationEngine();

  /// Kullanıcı tahmini oranı için üst sınır (anlamsız girişleri reddet).
  static const double maxUserForecastRatePercent = 1000;

  /// Yenileme ayının günü ile sözleşme başlangıcı arasında ≥ 5 yıl mı?
  static bool isFiveYearsOrMore({
    required DateTime contractStart,
    required DateTime renewalDate,
  }) {
    final start = DateTime(
      contractStart.year,
      contractStart.month,
      contractStart.day,
    );
    final renewal = DateTime(
      renewalDate.year,
      renewalDate.month,
      renewalDate.day,
    );
    // Leap-safe: 29 Şubat +5 yıl taşarsa ayın son günü.
    var fifthAnniversary = DateTime(start.year + 5, start.month, start.day);
    if (fifthAnniversary.month != start.month) {
      fifthAnniversary = DateTime(start.year + 5, start.month + 1, 0);
    }
    return !renewal.isBefore(fifthAnniversary);
  }

  /// [forecastBasis] yalnızca yenileme ayı için resmî oran **yokken** kullanılır.
  /// Resmî oran varsa her zaman `RateBasisKind.official` üretilir; forecast yok sayılır.
  ///
  /// Desteklenmeyen tarihsel konut dönemi forecast ile bypass edilemez.
  CalculationOutcome calculate({
    required CalculationInput input,
    required TufeRateBundle bundle,
    required String rateSourceLabel,
    RateBasisKind? forecastBasis,
    double? userForecastRatePercent,
  }) {
    if (!input.currentRent.isFinite || input.currentRent <= 0) {
      return CalculationInvalidInput('Kira tutarı 0’dan büyük olmalıdır.');
    }
    if (input.renewalMonth < 1 || input.renewalMonth > 12) {
      return CalculationInvalidInput('Yenileme ayı geçersiz.');
    }
    if (input.contractIncreasePercent != null) {
      final c = input.contractIncreasePercent!;
      if (!c.isFinite || c < 0) {
        return CalculationInvalidInput('Sözleşme artış oranı negatif olamaz.');
      }
    }

    // Konut + geçici %25 dönemi: yanlış TÜFE sonucu üretme — hesap kapalı.
    // Forecast bu yolu ASLA bypass etmez.
    if (input.propertyType == PropertyType.residential &&
        ResidentialRentCapWindow.contains(input.renewalDate)) {
      return CalculationUnsupportedPeriod(
        '11 Haziran 2022 – 30 Haziran 2024 tarihleri arasındaki konut kira '
        'yenilemelerinde geçici yasal artış sınırı uygulanmıştır. '
        'Bu dönem için uygulama TÜFE hesabı üretmez; resmi kaynaklara ve '
        'gerekirse uzmana başvurun. Çatılı işyeri seçiliyse TÜFE hesabı '
        'denenebilir.',
      );
    }

    final official = bundle.findByRenewalMonth(input.renewalMonthKey);
    if (official != null) {
      return _buildSuccess(
        input: input,
        bundle: bundle,
        tufeMax: official.ratePercent,
        rateSourceLabel: rateSourceLabel,
        tuikReleaseDate: official.tuikReleaseDate,
        tuikSourceUrl: official.sourceUrl,
        rateBasis: RateBasisKind.official,
        estimateSourceMonthKey: null,
      );
    }

    // Resmî oran yok — forecast istenmediyse eksik dön.
    final basis = forecastBasis;
    if (basis == null || basis == RateBasisKind.official) {
      return CalculationRateMissing(
        requestedMonth: input.renewalMonthKey,
        latestAvailableMonth: bundle.latest?.renewalMonth,
      );
    }

    if (basis == RateBasisKind.estimatedLatestOfficial) {
      final latest = bundle.latest;
      if (latest == null) {
        return CalculationRateMissing(
          requestedMonth: input.renewalMonthKey,
          latestAvailableMonth: null,
        );
      }
      return _buildSuccess(
        input: input,
        bundle: bundle,
        tufeMax: latest.ratePercent,
        rateSourceLabel: 'Tahmini · son açıklanan oran',
        tuikReleaseDate: latest.tuikReleaseDate,
        tuikSourceUrl: latest.sourceUrl,
        rateBasis: RateBasisKind.estimatedLatestOfficial,
        estimateSourceMonthKey: latest.renewalMonth,
      );
    }

    // estimatedUserProvided
    final userRate = userForecastRatePercent;
    if (userRate == null || !userRate.isFinite || userRate < 0) {
      return CalculationInvalidInput(
        'Tahmini oran 0 veya daha büyük bir sayı olmalıdır.',
      );
    }
    if (userRate > maxUserForecastRatePercent) {
      return CalculationInvalidInput(
        'Tahmini oran çok yüksek (en fazla %$maxUserForecastRatePercent).',
      );
    }
    return _buildSuccess(
      input: input,
      bundle: bundle,
      tufeMax: userRate,
      rateSourceLabel: 'Tahmini · kullanıcı oranı',
      tuikReleaseDate: bundle.updatedAt,
      tuikSourceUrl: null,
      rateBasis: RateBasisKind.estimatedUserProvided,
      estimateSourceMonthKey: null,
    );
  }

  CalculationSuccess _buildSuccess({
    required CalculationInput input,
    required TufeRateBundle bundle,
    required double tufeMax,
    required String rateSourceLabel,
    required DateTime tuikReleaseDate,
    required String? tuikSourceUrl,
    required RateBasisKind rateBasis,
    required String? estimateSourceMonthKey,
  }) {
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

    final current = roundMoney(input.currentRent);
    final calculated = roundMoney(current * (1 + applicable / 100.0));
    final increase = roundMoney(calculated - current);
    final fivePlus = isFiveYearsOrMore(
      contractStart: input.contractStart,
      renewalDate: input.renewalDate,
    );

    return CalculationSuccess(
      CalculationResult(
        input: CalculationInput(
          currentRent: current,
          renewalYear: input.renewalYear,
          renewalMonth: input.renewalMonth,
          renewalDay: input.renewalDay,
          contractStart: input.contractStart,
          contractIncreasePercent: contract,
          propertyType: input.propertyType,
        ),
        tufeMaxRatePercent: tufeMax,
        applicableRatePercent: applicable,
        calculatedRent: calculated,
        increaseAmount: increase,
        contractCompare: compare,
        isFiveYearsOrMore: fivePlus,
        tuikReleaseDate: tuikReleaseDate,
        datasetUpdatedAt: bundle.updatedAt,
        rateSourceLabel: rateSourceLabel,
        tuikSourceUrl: tuikSourceUrl,
        rateBasis: rateBasis,
        estimateSourceMonthKey: estimateSourceMonthKey,
      ),
    );
  }
}
