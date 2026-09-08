import '../../core/money.dart';

enum PropertyType { residential, commercial }

/// Konut geçici %25 üst sınırı dönemi (bilgilendirme / hesap kapatma için).
///
/// Yenileme tarihi [start]–[endInclusive] aralığındaysa konut için bu uygulama
/// TÜFE hesabı üretmez; yanlış sonuç göstermemek için kapatır.
abstract final class ResidentialRentCapWindow {
  /// Kanunî geçici sınırın başlangıcı (dahil).
  static final DateTime start = DateTime(2022, 6, 11);

  /// 1 Temmuz 2024’ten itibaren genel TÜFE rejimine dönüş — bu gün **hariç**.
  static final DateTime endExclusive = DateTime(2024, 7, 1);

  static bool contains(DateTime renewalDate) {
    final day = DateTime(renewalDate.year, renewalDate.month, renewalDate.day);
    return !day.isBefore(start) && day.isBefore(endExclusive);
  }
}

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

  /// Ayın geçerli son gününe clamp eder (31 Şubat taşması yok).
  DateTime get renewalDate {
    final lastDay = DateTime(renewalYear, renewalMonth + 1, 0).day;
    final day = renewalDay.clamp(1, lastDay);
    return DateTime(renewalYear, renewalMonth, day);
  }
}

enum ContractCompareKind { none, contractLower, contractHigher, contractEqual }

/// Hesapta kullanılan oran tavanının kaynağı.
///
/// Resmî TÜFE satırı ile tahmin (son açıklanan / kullanıcı) birbirine karışmaz.
enum RateBasisKind {
  /// Yenileme ayı için bundle’da resmî TÜFE oranı var.
  official,

  /// Yenileme ayı için resmî oran yok; son açıklanan resmî oran proxy olarak kullanıldı.
  estimatedLatestOfficial,

  /// Yenileme ayı için resmî oran yok; kullanıcı senaryo oranı girdi.
  estimatedUserProvided,
}

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
    this.rateBasis = RateBasisKind.official,
    this.estimateSourceMonthKey,
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

  /// Oran tavanının kaynağı — tahmin sonuçları kiraya uygulanmaz.
  final RateBasisKind rateBasis;

  /// [RateBasisKind.estimatedLatestOfficial] için proxy resmî dönemin `YYYY-MM` anahtarı.
  final String? estimateSourceMonthKey;

  bool get isEstimated => rateBasis != RateBasisKind.official;
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

/// Desteklenmeyen tarih / mülk tipi kombinasyonu — yanlış hukuk motoru yok.
class CalculationUnsupportedPeriod extends CalculationOutcome {
  CalculationUnsupportedPeriod(this.message);
  final String message;
}

/// Uygulanan dönem için idempotency anahtarı.
String calculationApplyFingerprint(CalculationResult r) {
  final rent = roundMoney(r.calculatedRent).toStringAsFixed(2);
  final old = roundMoney(r.input.currentRent).toStringAsFixed(2);
  return '${r.input.renewalMonthKey}|$old|$rent';
}
