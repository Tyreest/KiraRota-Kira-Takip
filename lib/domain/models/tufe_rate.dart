class TufeRate {
  const TufeRate({
    required this.renewalMonth,
    required this.ratePercent,
    required this.tuikReleaseDate,
  });

  /// `YYYY-MM` — bu yenileme ayında uygulanacak oran satırı.
  final String renewalMonth;
  final double ratePercent;
  final DateTime tuikReleaseDate;

  factory TufeRate.fromJson(Map<String, dynamic> json) {
    return TufeRate(
      renewalMonth: json['renewal_month'] as String,
      ratePercent: (json['rate_percent'] as num).toDouble(),
      tuikReleaseDate: DateTime.parse(json['tuik_release_date'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'renewal_month': renewalMonth,
        'rate_percent': ratePercent,
        'tuik_release_date': tuikReleaseDate.toIso8601String().split('T').first,
      };
}

class TufeRateBundle {
  const TufeRateBundle({
    required this.version,
    required this.updatedAt,
    required this.sourceNote,
    required this.rates,
  });

  final int version;
  final DateTime updatedAt;
  final String sourceNote;
  final List<TufeRate> rates;

  factory TufeRateBundle.fromJson(Map<String, dynamic> json) {
    final rates = (json['rates'] as List<dynamic>)
        .map((e) => TufeRate.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.renewalMonth.compareTo(b.renewalMonth));
    return TufeRateBundle(
      version: json['version'] as int,
      updatedAt: DateTime.parse(json['updated_at'] as String),
      sourceNote: json['source_note'] as String? ?? '',
      rates: rates,
    );
  }

  TufeRate? findByRenewalMonth(String yyyyMm) {
    for (final r in rates) {
      if (r.renewalMonth == yyyyMm) return r;
    }
    return null;
  }

  TufeRate? get latest => rates.isEmpty ? null : rates.last;
}

enum RateSource { asset, remote }

class LoadedRates {
  const LoadedRates({
    required this.bundle,
    required this.source,
  });

  final TufeRateBundle bundle;
  final RateSource source;
}
