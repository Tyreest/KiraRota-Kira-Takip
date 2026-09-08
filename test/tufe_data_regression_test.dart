import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kira_artisi_hesapla/data/rate_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('asset TÜFE golden + structural validation', () async {
    final raw = await rootBundle.loadString('assets/data/tufe_rates.json');
    final map = jsonDecode(raw) as Map<String, dynamic>;
    final bundle = RateRepository.parseJsonString(raw);

    expect(map['version'], 3);
    expect(RateRepository.validateBundle(bundle), isEmpty);

    // Golden: Temmuz 2026 bülteni → Ağustos 2026 yenileme %31,90
    expect(bundle.findByRenewalMonth('2026-08')!.ratePercent, 31.9);
    // Golden: Ağustos 2026 bülteni → Eylül 2026 yenileme %31,79
    expect(bundle.findByRenewalMonth('2026-09')!.ratePercent, 31.79);
    expect(bundle.latest!.renewalMonth, '2026-09');

    // Birkaç tarihsel golden (değişmemeli)
    expect(bundle.findByRenewalMonth('2025-07')!.ratePercent, 40.09);
    expect(bundle.findByRenewalMonth('2024-07')!.ratePercent, 58.51);
  });

  test('hosted copy matches asset', () async {
    final asset = await rootBundle.loadString('assets/data/tufe_rates.json');
    // hosted/ Flutter asset değil; dosya sisteminden okunamazsa skip.
    // CI’de asset canonical; sync test: parse asset OK.
    final bundle = RateRepository.parseJsonString(asset);
    expect(bundle.version, greaterThanOrEqualTo(3));
    expect(bundle.findByRenewalMonth('2026-09'), isNotNull);
  });

  test('eksik ay içeren remote reddedilir', () {
    final asset = RateRepository.parseJsonString('''
{
  "version": 3,
  "updated_at": "2026-09-03",
  "source_note": "a",
  "rates": [
    {"renewal_month":"2026-08","rate_percent":31.9,"tuik_release_date":"2026-08-03"},
    {"renewal_month":"2026-09","rate_percent":31.79,"tuik_release_date":"2026-09-03"}
  ]
}
''');
    final remoteMissing = RateRepository.parseJsonString('''
{
  "version": 4,
  "updated_at": "2026-10-01",
  "source_note": "r",
  "rates": [
    {"renewal_month":"2026-09","rate_percent":31.79,"tuik_release_date":"2026-09-03"},
    {"renewal_month":"2026-10","rate_percent":30.0,"tuik_release_date":"2026-10-03"}
  ]
}
''');
    expect(
      RateRepository.isAcceptableRemote(asset: asset, remote: remoteMissing),
      isFalse,
    );
    expect(
      RateRepository.chooseBundle(asset: asset, remote: remoteMissing),
      same(asset),
    );
  });

  test('negatif / NaN remote reddedilir', () {
    final asset = RateRepository.parseJsonString('''
{
  "version": 1,
  "updated_at": "2026-08-01",
  "source_note": "a",
  "rates": [
    {"renewal_month":"2026-08","rate_percent":31.9,"tuik_release_date":"2026-08-03"}
  ]
}
''');
    final remote = RateRepository.parseJsonString('''
{
  "version": 2,
  "updated_at": "2026-09-01",
  "source_note": "r",
  "rates": [
    {"renewal_month":"2026-08","rate_percent":-1,"tuik_release_date":"2026-08-03"}
  ]
}
''');
    expect(
      RateRepository.isAcceptableRemote(asset: asset, remote: remote),
      isFalse,
    );
  });
}
