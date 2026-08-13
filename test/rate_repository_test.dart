import 'package:flutter_test/flutter_test.dart';
import 'package:kira_artisi_hesapla/data/rate_repository.dart';
import 'package:kira_artisi_hesapla/domain/models/tufe_rate.dart';

TufeRateBundle bundle({required int version, required DateTime updatedAt}) {
  return TufeRateBundle(
    version: version,
    updatedAt: updatedAt,
    sourceNote: 't',
    rates: [
      TufeRate(
        renewalMonth: '2025-07',
        ratePercent: 40.09,
        tuikReleaseDate: DateTime(2025, 7, 3),
      ),
    ],
  );
}

void main() {
  test('remote yoksa asset', () {
    final asset = bundle(version: 1, updatedAt: DateTime(2025, 8, 1));
    expect(
      RateRepository.chooseBundle(asset: asset, remote: null),
      same(asset),
    );
  });

  test('eski version remote reddedilir', () {
    final asset = bundle(version: 2, updatedAt: DateTime(2025, 8, 1));
    final remote = bundle(version: 1, updatedAt: DateTime(2025, 9, 1));
    expect(
      RateRepository.chooseBundle(asset: asset, remote: remote),
      same(asset),
    );
  });

  test('eski updated_at remote reddedilir', () {
    final asset = bundle(version: 1, updatedAt: DateTime(2025, 9, 1));
    final remote = bundle(version: 1, updatedAt: DateTime(2025, 8, 1));
    expect(
      RateRepository.chooseBundle(asset: asset, remote: remote),
      same(asset),
    );
  });

  test('daha yeni remote seçilir', () {
    final asset = bundle(version: 1, updatedAt: DateTime(2025, 8, 1));
    final remote = bundle(version: 1, updatedAt: DateTime(2025, 9, 1));
    expect(
      RateRepository.chooseBundle(asset: asset, remote: remote),
      same(remote),
    );
  });

  test('JSON parse', () {
    const raw = '''
{
  "version": 1,
  "updated_at": "2026-08-03",
  "source_note": "x",
  "rates": [
    {
      "renewal_month": "2026-07",
      "rate_percent": 32.03,
      "tuik_release_date": "2026-07-03"
    }
  ]
}
''';
    final b = RateRepository.parseJsonString(raw);
    expect(b.rates.single.ratePercent, 32.03);
    expect(b.findByRenewalMonth('2026-08'), isNull);
  });
}
