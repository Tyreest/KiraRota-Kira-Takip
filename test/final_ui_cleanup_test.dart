import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kira_artisi_hesapla/core/theme.dart';
import 'package:kira_artisi_hesapla/core/tuik_urls.dart';
import 'package:kira_artisi_hesapla/domain/models/tufe_rate.dart';
import 'package:kira_artisi_hesapla/providers/app_providers.dart';
import 'package:kira_artisi_hesapla/ui/screens/calculate_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

LoadedRates _testRates() {
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
          sourceUrl: TuikUrls.bulletinTemmuz2026,
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
  });

  Future<void> pumpTestApp(
    WidgetTester tester, {
    required Widget child,
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({
      'onboarding_done': true,
      'is_pro_lifetime': true,
    });
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          ratesProvider.overrideWith((ref) async => _testRates()),
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

  group('Final UI Cleanup — Result Screens', () {
    testWidgets(
      'Forecast: compact "Tahmini sonuç kiraya uygulanamaz" exists and opens sheet; old duplicate card removed',
      (tester) async {
        await pumpTestApp(
          tester,
          child: CalculateScreen(
            initialRenewal: DateTime(2027, 9, 1),
            initialContractStart: DateTime(2024, 9, 1),
            initialRentText: '20000',
          ),
        );

        // Select forecast option
        await tester.tap(find.textContaining('Son açıklanan oranla tahmin et'));
        await tester.pumpAndSettle();

        // Tap calculate
        await tester.tap(
          find.ancestor(
            of: find.text('Tahmini hesapla'),
            matching: find.byType(FilledButton),
          ),
        );
        await tester.pumpAndSettle();

        // Check compact single-line row exists
        expect(find.text('Tahmini sonuç kiraya uygulanamaz'), findsOneWidget);

        // Old large duplicate warning message must NOT be rendered on main screen
        expect(
          find.textContaining('Tahmini sonuç mevcut kirayı veya yenileme tarihini değiştirmez.'),
          findsNothing,
        );

        // Save/apply primary CTA buttons must NOT be rendered in forecast
        expect(find.text('Kiralarıma kaydet'), findsNothing);
        expect(find.text('Yeni dönemi kiraya uygula'), findsNothing);

        // Tap compact row -> opens bottom sheet
        await tester.tap(find.text('Tahmini sonuç kiraya uygulanamaz'));
        await tester.pumpAndSettle();

        // Sheet content assertions
        expect(find.text('Tahmini Sonuç Bilgisi'), findsOneWidget);
        expect(
          find.textContaining('resmî TÜFE kira artış oranı henüz TÜİK tarafından açıklanmamıştır'),
          findsOneWidget,
        );
        expect(
          find.textContaining('gerçek kira sözleşmesine veya kira kaydına uygulanamaz'),
          findsOneWidget,
        );

        // Dismiss sheet
        await tester.tap(find.text('Anladım'));
        await tester.pumpAndSettle();
        expect(find.text('Tahmini Sonuç Bilgisi'), findsNothing);
      },
    );

    testWidgets(
      'Forecast: PDF button is completely hidden; toolbar has only Paylaş and Kopyala',
      (tester) async {
        await pumpTestApp(
          tester,
          child: CalculateScreen(
            initialRenewal: DateTime(2027, 9, 1),
            initialContractStart: DateTime(2024, 9, 1),
            initialRentText: '20000',
          ),
        );

        await tester.tap(find.textContaining('Son açıklanan oranla tahmin et'));
        await tester.pumpAndSettle();
        await tester.tap(
          find.ancestor(
            of: find.text('Tahmini hesapla'),
            matching: find.byType(FilledButton),
          ),
        );
        await tester.pumpAndSettle();

        // Verify PDF action is completely hidden in forecast
        expect(find.widgetWithText(OutlinedButton, 'PDF'), findsNothing);
        expect(find.text('PDF raporu al'), findsNothing);
        expect(find.text('Paylaş'), findsOneWidget);
        expect(find.text('Kopyala'), findsOneWidget);
      },
    );

    testWidgets(
      'Official: compact "Hesaplama bilgileri ve TÜİK kaynağı" row opens detail sheet & PDF button present',
      (tester) async {
        await pumpTestApp(
          tester,
          child: CalculateScreen(
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

        // Verify PDF button with short label is present
        expect(find.widgetWithText(OutlinedButton, 'PDF'), findsOneWidget);

        // Verify compact line exists
        expect(find.text('Hesaplama bilgileri ve TÜİK kaynağı'), findsOneWidget);

        // Scattered texts must not be directly on the main screen
        expect(find.text('12 Aylık TÜFE Nedir?'), findsNothing);

        // Tap compact line to open sheet
        await tester.tap(find.text('Hesaplama bilgileri ve TÜİK kaynağı'));
        await tester.pumpAndSettle();

        // Verify bottom sheet contents
        expect(find.text('Hesaplama Bilgileri ve Kaynak'), findsOneWidget);
        expect(find.text('Kullanılan oran'), findsOneWidget);
        expect(find.text('Oran dönemi'), findsOneWidget);
        expect(find.text('TÜİK açıklama tarihi'), findsOneWidget);
        expect(find.text('Veri güncelleme tarihi'), findsOneWidget);
        expect(find.text('12 Aylık Ortalamalara Göre TÜFE Nedir?'), findsOneWidget);
        expect(find.text('Kaynak: TÜİK — Resmî kaynağı görüntüle'), findsOneWidget);
        expect(find.textContaining('hukuki tavsiye değildir'), findsOneWidget);

        // Close sheet
        await tester.tap(find.text('Kapat'));
        await tester.pumpAndSettle();
        expect(find.text('Hesaplama Bilgileri ve Kaynak'), findsNothing);
      },
    );
  });
}
