import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kira_artisi_hesapla/core/constants.dart';
import 'package:kira_artisi_hesapla/core/theme.dart';
import 'package:kira_artisi_hesapla/core/tuik_urls.dart';
import 'package:kira_artisi_hesapla/data/rate_repository.dart';
import 'package:kira_artisi_hesapla/domain/calculation_engine.dart';
import 'package:kira_artisi_hesapla/domain/models/calculation.dart';
import 'package:kira_artisi_hesapla/domain/models/tufe_rate.dart';
import 'package:kira_artisi_hesapla/providers/app_providers.dart';
import 'package:kira_artisi_hesapla/services/external_link_service.dart';
import 'package:kira_artisi_hesapla/ui/screens/calculate_screen.dart';
import 'package:kira_artisi_hesapla/ui/screens/rates_screen.dart';
import 'package:kira_artisi_hesapla/ui/screens/settings_screen.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

LoadedRates _rates({String? augSourceUrl}) {
  return LoadedRates(
    bundle: TufeRateBundle(
      version: 1,
      updatedAt: DateTime(2026, 8, 3),
      sourceNote: 'test',
      rates: [
        TufeRate(
          renewalMonth: '2026-07',
          ratePercent: 32.03,
          tuikReleaseDate: DateTime(2026, 7, 3),
        ),
        TufeRate(
          renewalMonth: '2026-08',
          ratePercent: 31.90,
          tuikReleaseDate: DateTime(2026, 8, 3),
          sourceUrl: augSourceUrl,
        ),
      ],
    ),
    source: RateSource.asset,
  );
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    GoogleFonts.config.allowRuntimeFetching = false;
    await initializeDateFormatting('tr_TR');
    PackageInfo.setMockInitialValues(
      appName: 'KiraRota',
      packageName: 'com.tyreest.kiraartisi',
      version: '1.0.1',
      buildNumber: '9',
      buildSignature: '',
    );
  });

  tearDown(() {
    debugUrlLauncherOverride = null;
  });

  group('TuikUrls', () {
    test('sourceUrl varsa onu seçer', () {
      expect(
        TuikUrls.resolve(TuikUrls.bulletinTemmuz2026),
        TuikUrls.bulletinTemmuz2026,
      );
    });

    test('sourceUrl yoksa genel portal', () {
      expect(TuikUrls.resolve(null), TuikUrls.dataPortal);
      expect(TuikUrls.resolve(''), TuikUrls.dataPortal);
      expect(TuikUrls.resolve('  '), TuikUrls.dataPortal);
    });

    test('yalnız resmi tuik host’ları', () {
      expect(
        TuikUrls.isAllowedOfficialHost(Uri.parse(TuikUrls.dataPortal)),
        isTrue,
      );
      expect(
        TuikUrls.isAllowedOfficialHost(Uri.parse(TuikUrls.bulletinTemmuz2026)),
        isTrue,
      );
      expect(
        TuikUrls.isAllowedOfficialHost(Uri.parse('https://evil.example/x')),
        isFalse,
      );
    });
  });

  group('JSON source_url', () {
    test('fromJson optional source_url', () {
      final withUrl = TufeRate.fromJson({
        'renewal_month': '2026-08',
        'rate_percent': 31.9,
        'tuik_release_date': '2026-08-03',
        'source_url': TuikUrls.bulletinTemmuz2026,
      });
      expect(withUrl.sourceUrl, TuikUrls.bulletinTemmuz2026);

      final without = TufeRate.fromJson({
        'renewal_month': '2026-07',
        'rate_percent': 32.03,
        'tuik_release_date': '2026-07-03',
      });
      expect(without.sourceUrl, isNull);
    });

    test('bundled asset Ağustos 2026 source_url bülten', () async {
      final repo = RateRepository(remoteUrl: '');
      final loaded = await repo.load();
      final aug = loaded.bundle.findByRenewalMonth('2026-08');
      expect(aug, isNotNull);
      expect(aug!.sourceUrl, TuikUrls.bulletinTemmuz2026);
      expect(aug.ratePercent, 31.9);
    });

    test('hesap motoru sourceUrl’i sonuca taşır; oran aynı', () {
      const engine = CalculationEngine();
      final bundle = _rates(augSourceUrl: TuikUrls.bulletinTemmuz2026).bundle;
      final outcome = engine.calculate(
        input: CalculationInput(
          currentRent: 10000,
          renewalYear: 2026,
          renewalMonth: 8,
          contractStart: DateTime(2024, 8, 1),
        ),
        bundle: bundle,
        rateSourceLabel: 't',
      );
      final r = (outcome as CalculationSuccess).result;
      expect(r.applicableRatePercent, 31.9);
      expect(r.tuikSourceUrl, TuikUrls.bulletinTemmuz2026);

      final noUrl = engine.calculate(
        input: CalculationInput(
          currentRent: 10000,
          renewalYear: 2026,
          renewalMonth: 7,
          contractStart: DateTime(2024, 7, 1),
        ),
        bundle: bundle,
        rateSourceLabel: 't',
      );
      expect((noUrl as CalculationSuccess).result.tuikSourceUrl, isNull);
    });
  });

  group('UI kaynak linkleri', () {
    Future<void> pumpSized(WidgetTester tester, Widget child) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({'onboarding_done': true});
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            ratesProvider.overrideWith(
              (ref) async => _rates(augSourceUrl: TuikUrls.bulletinTemmuz2026),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            locale: const Locale('tr', 'TR'),
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: Scaffold(body: child),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('TÜFE Oranları — Resmî TÜİK kaynağını görüntüle', (
      tester,
    ) async {
      await pumpSized(tester, const RatesScreen());
      expect(find.text('Resmî TÜİK kaynağını görüntüle'), findsOneWidget);
      expect(find.text('TÜFE Oranları'), findsOneWidget);
    });

    testWidgets('Sonuç — Kaynak: TÜİK bağlantısı', (tester) async {
      await pumpSized(
        tester,
        CalculateScreen(
          initialRenewal: DateTime(2026, 8, 15),
          initialContractStart: DateTime(2024, 8, 15),
          initialRentText: '25000',
        ),
      );
      await tester.tap(
        find.ancestor(
          of: find.text('Hesapla'),
          matching: find.byType(FilledButton),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Hesaplama bilgileri ve TÜİK kaynağı'),
        findsOneWidget,
      );
      await tester.tap(find.text('Hesaplama bilgileri ve TÜİK kaynağı'));
      await tester.pumpAndSettle();
      expect(
        find.text('Kaynak: TÜİK — Resmî kaynağı görüntüle'),
        findsOneWidget,
      );
    });

    testWidgets('Hakkında — TÜİK Veri Portalı + disclaimer', (tester) async {
      await pumpSized(tester, const SettingsScreen());
      await tester.ensureVisible(find.text('Uygulama Hakkında'));
      await tester.tap(find.text('Uygulama Hakkında'));
      await tester.pumpAndSettle();
      expect(find.text('Resmî veri kaynağı'), findsOneWidget);
      expect(find.text('TÜİK Veri Portalı'), findsOneWidget);
      expect(find.text(AppConstants.notOfficialDisclaimer), findsOneWidget);
    });
  });

  group('URL launch', () {
    testWidgets('başarısız launch crash yok + snackbar', (tester) async {
      debugUrlLauncherOverride =
          (uri, {LaunchMode mode = LaunchMode.platformDefault}) async => false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return TextButton(
                  onPressed: () => openTuikSource(context),
                  child: const Text('open'),
                );
              },
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Resmî kaynak açılamadı.'), findsOneWidget);
    });

    testWidgets('sourceUrl ile doğru URI seçilir', (tester) async {
      Uri? launched;
      debugUrlLauncherOverride =
          (uri, {LaunchMode mode = LaunchMode.platformDefault}) async {
            launched = uri;
            return true;
          };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return TextButton(
                  onPressed: () => openTuikSource(
                    context,
                    sourceUrl: TuikUrls.bulletinTemmuz2026,
                  ),
                  child: const Text('open'),
                );
              },
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(launched.toString(), TuikUrls.bulletinTemmuz2026);
    });

    testWidgets('sourceUrl yoksa portal', (tester) async {
      Uri? launched;
      debugUrlLauncherOverride =
          (uri, {LaunchMode mode = LaunchMode.platformDefault}) async {
            launched = uri;
            return true;
          };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return TextButton(
                  onPressed: () => openTuikSource(context),
                  child: const Text('open'),
                );
              },
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(launched.toString(), TuikUrls.dataPortal);
    });
  });
}
