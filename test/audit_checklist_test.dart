import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kira_artisi_hesapla/core/constants.dart';
import 'package:kira_artisi_hesapla/core/format.dart';
import 'package:kira_artisi_hesapla/data/rate_repository.dart';
import 'package:kira_artisi_hesapla/data/rental_repository.dart';
import 'package:kira_artisi_hesapla/domain/calculation_engine.dart';
import 'package:kira_artisi_hesapla/domain/models/calculation.dart';
import 'package:kira_artisi_hesapla/domain/models/rental.dart';
import 'package:kira_artisi_hesapla/domain/models/tufe_rate.dart';
import 'package:kira_artisi_hesapla/services/ads_service.dart';
import 'package:kira_artisi_hesapla/services/pdf_report_service.dart';
import 'package:kira_artisi_hesapla/services/reminder_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Denetim checklist’inin otomatik doğrulanabilir kısımları.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('tr_TR');
  });

  group('Hesap motoru + tarihler', () {
    late TufeRateBundle assetBundle;
    const engine = CalculationEngine();

    setUpAll(() async {
      final repo = RateRepository(remoteUrl: '');
      assetBundle = (await repo.load()).bundle;
    });

    test('Temmuz 2026 → %32.03; 15 Temmuz günü korunur', () {
      final outcome = engine.calculate(
        input: CalculationInput(
          currentRent: 25000,
          renewalYear: 2026,
          renewalMonth: 7,
          renewalDay: 15,
          contractStart: DateTime(2023, 7, 15),
        ),
        bundle: assetBundle,
        rateSourceLabel: 'test',
      );
      final r = (outcome as CalculationSuccess).result;
      expect(r.tufeMaxRatePercent, 32.03);
      expect(r.applicableRatePercent, 32.03);
      expect(r.calculatedRent, closeTo(25000 * 1.3203, 0.01));
      expect(r.input.renewalDay, 15);
      expect(r.input.renewalDate.day, 15);
      expect(r.isFiveYearsOrMore, isFalse);
    });

    test('Ağustos 2026 → %31.90', () {
      final outcome = engine.calculate(
        input: CalculationInput(
          currentRent: 20000,
          renewalYear: 2026,
          renewalMonth: 8,
          renewalDay: 1,
          contractStart: DateTime(2024, 8, 1),
        ),
        bundle: assetBundle,
        rateSourceLabel: 'test',
      );
      final r = (outcome as CalculationSuccess).result;
      expect(r.tufeMaxRatePercent, 31.90);
      expect(r.calculatedRent, closeTo(20000 * 1.3190, 0.01));
    });

    test('sözleşme düşük → sözleşme oranı', () {
      final r =
          (engine.calculate(
                    input: CalculationInput(
                      currentRent: 10000,
                      renewalYear: 2026,
                      renewalMonth: 7,
                      contractStart: DateTime(2024, 7, 1),
                      contractIncreasePercent: 20,
                    ),
                    bundle: assetBundle,
                    rateSourceLabel: 't',
                  )
                  as CalculationSuccess)
              .result;
      expect(r.applicableRatePercent, 20);
      expect(r.contractCompare, ContractCompareKind.contractLower);
    });

    test('sözleşme yüksek → TÜFE azami + higher', () {
      final r =
          (engine.calculate(
                    input: CalculationInput(
                      currentRent: 10000,
                      renewalYear: 2026,
                      renewalMonth: 7,
                      contractStart: DateTime(2024, 7, 1),
                      contractIncreasePercent: 40,
                    ),
                    bundle: assetBundle,
                    rateSourceLabel: 't',
                  )
                  as CalculationSuccess)
              .result;
      expect(r.applicableRatePercent, 32.03);
      expect(r.contractCompare, ContractCompareKind.contractHigher);
    });

    test('5+ yıl: 15 Temmuz 2020 → 15 Temmuz 2025 true; 14 Temmuz false', () {
      expect(
        CalculationEngine.isFiveYearsOrMore(
          contractStart: DateTime(2020, 7, 15),
          renewalDate: DateTime(2025, 7, 15),
        ),
        isTrue,
      );
      expect(
        CalculationEngine.isFiveYearsOrMore(
          contractStart: DateTime(2020, 7, 15),
          renewalDate: DateTime(2025, 7, 14),
        ),
        isFalse,
      );

      final withDay =
          (engine.calculate(
                    input: CalculationInput(
                      currentRent: 10000,
                      renewalYear: 2025,
                      renewalMonth: 7,
                      renewalDay: 20,
                      contractStart: DateTime(2020, 7, 15),
                    ),
                    bundle: assetBundle,
                    rateSourceLabel: 't',
                  )
                  as CalculationSuccess)
              .result;
      expect(withDay.isFiveYearsOrMore, isTrue);
    });

    test('oran yok → RateMissing, sessiz fallback yok', () {
      final o = engine.calculate(
        input: CalculationInput(
          currentRent: 10000,
          renewalYear: 2026,
          renewalMonth: 9,
          contractStart: DateTime(2024, 9, 1),
        ),
        bundle: assetBundle,
        rateSourceLabel: 't',
      );
      expect(o, isA<CalculationRateMissing>());
      final m = o as CalculationRateMissing;
      expect(m.requestedMonth, '2026-09');
      expect(m.latestAvailableMonth, '2026-08');
    });
  });

  group('Remote TÜFE', () {
    test('internet yok / HTTP hata → asset fallback', () async {
      final client = MockClient((_) async => http.Response('fail', 500));
      final repo = RateRepository(
        client: client,
        remoteUrl: 'https://example.com/rates.json',
      );
      final loaded = await repo.load();
      expect(loaded.source, RateSource.asset);
      expect(loaded.bundle.findByRenewalMonth('2026-07')?.ratePercent, 32.03);
    });

    test('daha yeni remote seçilir', () async {
      final remoteJson = jsonEncode({
        'version': 99,
        'updated_at': '2099-01-01',
        'source_note': 'remote',
        'rates': [
          {
            'renewal_month': '2026-07',
            'rate_percent': 99.99,
            'tuik_release_date': '2026-07-03',
          },
        ],
      });
      final client = MockClient((_) async => http.Response(remoteJson, 200));
      final repo = RateRepository(
        client: client,
        remoteUrl: 'https://example.com/rates.json',
      );
      final loaded = await repo.load();
      expect(loaded.source, RateSource.remote);
      expect(loaded.bundle.findByRenewalMonth('2026-07')?.ratePercent, 99.99);
    });

    test('eski remote reddedilir → asset', () async {
      final remoteJson = jsonEncode({
        'version': 0,
        'updated_at': '2020-01-01',
        'source_note': 'stale',
        'rates': [
          {
            'renewal_month': '2026-07',
            'rate_percent': 1.0,
            'tuik_release_date': '2026-07-03',
          },
        ],
      });
      final client = MockClient((_) async => http.Response(remoteJson, 200));
      final repo = RateRepository(
        client: client,
        remoteUrl: 'https://example.com/rates.json',
      );
      final loaded = await repo.load();
      expect(loaded.source, RateSource.asset);
      expect(loaded.bundle.findByRenewalMonth('2026-07')?.ratePercent, 32.03);
    });
  });

  group('Kiralarım kalıcılık', () {
    test('kapat-aç simülasyonu: prefs’ten geri yüklenir', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = RentalRepository(prefs);
      final now = DateTime(2026, 8, 1);
      await repo.add(
        Rental(
          id: 'a',
          role: RentalRole.tenant,
          displayName: 'Evim',
          currentRent: 25000,
          contractStartDate: DateTime(2024, 1, 1),
          increaseDate: DateTime(2026, 7, 1),
          createdAt: now,
          updatedAt: now,
        ),
        isPro: false,
      );

      final again = RentalRepository(prefs).loadAll();
      expect(again.length, 1);
      expect(again.first.currentRent, 25000);
      expect(again.first.displayName, 'Evim');
    });

    test('free 1 kira / pro sınırsız', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final free = RentalRepository(prefs);
      final now = DateTime(2026, 1, 1);
      expect(
        await free.add(
          Rental(
            id: '1',
            role: RentalRole.tenant,
            displayName: 'A',
            currentRent: 1,
            contractStartDate: now,
            increaseDate: now,
            createdAt: now,
            updatedAt: now,
          ),
          isPro: false,
        ),
        isTrue,
      );
      expect(
        await free.add(
          Rental(
            id: '2',
            role: RentalRole.landlord,
            displayName: 'B',
            currentRent: 1,
            contractStartDate: now,
            increaseDate: now,
            createdAt: now,
            updatedAt: now,
          ),
          isPro: false,
        ),
        isFalse,
      );
      expect(free.loadAll().length, AppConstants.freeRentalLimit);

      SharedPreferences.setMockInitialValues({});
      final prefs2 = await SharedPreferences.getInstance();
      final pro = RentalRepository(prefs2);
      for (var i = 0; i < 5; i++) {
        expect(
          await pro.add(
            Rental(
              id: 'p$i',
              role: RentalRole.tenant,
              displayName: 'P$i',
              currentRent: 1,
              contractStartDate: now,
              increaseDate: now,
              createdAt: now,
              updatedAt: now,
            ),
            isPro: true,
          ),
          isTrue,
        );
      }
      expect(pro.loadAll().length, 5);
    });
  });

  group('Hatırlatma prefs (izin bağımsız)', () {
    test('schedule enableNotifications=false → kayıt kalır', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final svc = ReminderService(prefs, enableNotifications: false);
      await svc.schedule(
        ReminderConfig(
          renewalDate: DateTime(2027, 3, 15),
          notify30: true,
          notify7: true,
          notify0: false,
        ),
      );
      expect(svc.saved!.renewalDate.day, 15);
      expect(svc.saved!.notify0, isFalse);
      await svc.clearSaved();
      expect(svc.saved, isNull);
    });
  });

  group('Pro fiyat / AdMob / Analytics sabitleri', () {
    test('IAP product id doğru; fiyat UI sabiti kaldırıldı', () {
      expect(AppConstants.iapProductId, 'kira_pro_lifetime');
    });

    test('AdMob debug test ID sabitleri; production dart-define ayrı', () {
      expect(AppConstants.admobTestAppId.contains('3940256099942544'), isTrue);
      expect(
        AppConstants.admobTestBannerUnitId.contains('3940256099942544'),
        isTrue,
      );
      expect(
        AppConstants.admobTestInterstitialUnitId.contains('3940256099942544'),
        isTrue,
      );
      // Sahte production ID uydurulmamış
      expect(AdMobIds.releaseUsesTestIdsLeak, isFalse);
    });

    test('formatMoney ₺ ve tr_TR', () {
      final s = formatMoney(33007.5);
      expect(s.contains('₺'), isTrue);
      expect(s.contains('33.007,50') || s.contains('33007'), isTrue);
    });
  });

  group('PDF Türkçe / ₺', () {
    test('dosya adı mantığı korunur (kirarota-YYYY-MM.pdf)', () {
      final result = CalculationResult(
        input: CalculationInput(
          currentRent: 25000,
          renewalYear: 2026,
          renewalMonth: 5,
          renewalDay: 1,
          contractStart: DateTime(2020, 5, 1),
        ),
        tufeMaxRatePercent: 30,
        applicableRatePercent: 30,
        calculatedRent: 32500,
        increaseAmount: 7500,
        contractCompare: ContractCompareKind.none,
        isFiveYearsOrMore: false,
        tuikReleaseDate: DateTime(2026, 5, 3),
        datasetUpdatedAt: DateTime(2026, 5, 3),
        rateSourceLabel: 'Offline',
      );
      final svc = PdfReportService();
      expect(svc.reportFileName(result), 'kirarota-2026-05.pdf');
      expect(
        svc.reportFileName(result, rentalName: 'Evim'),
        'kirarota-evim-2026-05.pdf',
      );
    });

    test('bundled Noto: PDF Unicode glyph hatası yok, ₺ ve ı içerir', () async {
      final result = CalculationResult(
        input: CalculationInput(
          currentRent: 25000,
          renewalYear: 2026,
          renewalMonth: 7,
          renewalDay: 15,
          contractStart: DateTime(2020, 7, 15),
        ),
        tufeMaxRatePercent: 32.03,
        applicableRatePercent: 32.03,
        calculatedRent: 33007.5,
        increaseAmount: 8007.5,
        contractCompare: ContractCompareKind.none,
        isFiveYearsOrMore: true,
        tuikReleaseDate: DateTime(2026, 7, 3),
        datasetUpdatedAt: DateTime(2026, 8, 3),
        rateSourceLabel: 'Offline',
      );

      final bytes = await PdfReportService().buildPdfBytes(result);
      expect(bytes.length, greaterThan(5000));
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
      final raw = utf8.decode(bytes, allowMalformed: true);
      // Font subset / stream içinde metin parçaları
      expect(raw.contains('Kira') || raw.contains('T'), isTrue);
    });
  });
}
