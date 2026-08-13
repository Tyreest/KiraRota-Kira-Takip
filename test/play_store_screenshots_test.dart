@Skip('Asset generator — toImage hangs in suite; emulator capture kullan')
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kira_artisi_hesapla/core/theme.dart';
import 'package:kira_artisi_hesapla/data/rental_repository.dart';
import 'package:kira_artisi_hesapla/domain/models/rental.dart';
import 'package:kira_artisi_hesapla/domain/models/tufe_rate.dart';
import 'package:kira_artisi_hesapla/providers/app_providers.dart';
import 'package:kira_artisi_hesapla/services/ads_service.dart';
import 'package:kira_artisi_hesapla/services/reminder_service.dart';
import 'package:kira_artisi_hesapla/ui/screens/calculate_screen.dart';
import 'package:kira_artisi_hesapla/ui/screens/rates_screen.dart';
import 'package:kira_artisi_hesapla/ui/screens/reminder_screen.dart';
import 'package:kira_artisi_hesapla/ui/screens/rental_detail_screen.dart';
import 'package:kira_artisi_hesapla/ui/screens/rentals_screen.dart';
import 'package:kira_artisi_hesapla/ui/screens/settings_screen.dart';
import 'package:kira_artisi_hesapla/ui/widgets/pdf_export_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Play Store ham PNG — gerçek Flutter UI, 1080x2400, demo veri.
///
/// Çalıştır (Skip kaldırarak):
/// `flutter test test/play_store_screenshots_test.dart`

const _outRel = 'store_assets/raw_screenshots';

LoadedRates _rates() => LoadedRates(
  bundle: TufeRateBundle(
    version: 1,
    updatedAt: DateTime(2026, 8, 3),
    sourceNote: 'TÜİK',
    rates: [
      TufeRate(
        renewalMonth: '2026-08',
        ratePercent: 31.90,
        tuikReleaseDate: DateTime(2026, 8, 3),
      ),
      TufeRate(
        renewalMonth: '2026-07',
        ratePercent: 32.03,
        tuikReleaseDate: DateTime(2026, 7, 3),
      ),
      TufeRate(
        renewalMonth: '2026-06',
        ratePercent: 32.24,
        tuikReleaseDate: DateTime(2026, 6, 3),
      ),
      TufeRate(
        renewalMonth: '2026-05',
        ratePercent: 32.43,
        tuikReleaseDate: DateTime(2026, 5, 3),
      ),
      TufeRate(
        renewalMonth: '2026-04',
        ratePercent: 32.82,
        tuikReleaseDate: DateTime(2026, 4, 3),
      ),
      TufeRate(
        renewalMonth: '2026-03',
        ratePercent: 33.39,
        tuikReleaseDate: DateTime(2026, 3, 3),
      ),
      TufeRate(
        renewalMonth: '2026-02',
        ratePercent: 33.98,
        tuikReleaseDate: DateTime(2026, 2, 3),
      ),
    ],
  ),
  source: RateSource.asset,
);

Rental _demoRental() {
  final snap = RentalCalculationSnapshot(
    id: 'snap-demo-1',
    calculatedAt: DateTime(2026, 8, 8, 9, 30),
    oldRent: 38000,
    calculatedRent: 50122,
    tufeRatePercent: 31.9,
    applicableRatePercent: 31.9,
    tufeReferenceMonth: '2026-08',
    increaseDate: DateTime(2026, 8, 15),
  );
  return Rental(
    id: 'demo-ev-1',
    role: RentalRole.tenant,
    displayName: 'Ev',
    currentRent: 38000,
    contractStartDate: DateTime(2024, 8, 1),
    increaseDate: DateTime(2026, 8, 15),
    createdAt: DateTime(2026, 8, 1, 10),
    updatedAt: DateTime(2026, 8, 8, 10),
    reminder: const RentalReminderPrefs(
      enabled: true,
      notify30: true,
      notify7: true,
      notify0: true,
    ),
    history: [snap],
  );
}

Future<SharedPreferences> _seedPrefs() async {
  SharedPreferences.setMockInitialValues({
    'onboarding_done': true,
    'is_pro_lifetime': true,
    'review_access_enabled': true,
  });
  final prefs = await SharedPreferences.getInstance();
  final repo = RentalRepository(prefs);
  await repo.add(_demoRental(), isPro: true);
  return prefs;
}

List<Override> _overrides(SharedPreferences prefs) => [
  sharedPreferencesProvider.overrideWithValue(prefs),
  ratesProvider.overrideWith((ref) async => _rates()),
  reminderServiceProvider.overrideWithValue(
    ReminderService(prefs, enableNotifications: false),
  ),
];

Widget _wrap(SharedPreferences prefs, Widget home) {
  return ProviderScope(
    overrides: _overrides(prefs),
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      locale: const Locale('tr', 'TR'),
      home: RepaintBoundary(key: const ValueKey('shot_root'), child: home),
    ),
  );
}

Finder _hesaplaBtn() => find.ancestor(
  of: find.text('Hesapla'),
  matching: find.byType(FilledButton),
);

Future<void> _settle(WidgetTester tester, [int frames = 20]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _capture(WidgetTester tester, String fileName) async {
  await tester.pump(const Duration(milliseconds: 100));
  final element = tester.element(find.byKey(const ValueKey('shot_root')));
  final boundary = element.renderObject! as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: 2.75);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  expect(bytes, isNotNull);
  final dir = Directory(_outRel);
  if (!dir.existsSync()) dir.createSync(recursive: true);
  final file = File('$_outRel/$fileName');
  await file.writeAsBytes(bytes!.buffer.asUint8List());
  // ignore: avoid_print
  print(
    'WROTE ${file.path} (${file.lengthSync()} bytes '
    '${image.width}x${image.height})',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  AdsService.skipSdk = true;
  GoogleFonts.config.allowRuntimeFetching = false;

  setUpAll(() async {
    await initializeDateFormatting('tr_TR');
  });

  setUp(() {
    AdsService.skipSdk = true;
    AdsService.setAdsEnabled(false);
    AdsService.resetConsentAndInitStateForTest();
    AdsService.applyConsentCanRequestAds(true);
  });

  testWidgets('Play Store raw screenshots', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final prefs = await _seedPrefs();
    AdsService.setAdsEnabled(false); // Pro

    // ---- 01 Hesapla dolu ----
    await tester.pumpWidget(
      _wrap(
        prefs,
        Scaffold(
          body: SafeArea(
            child: CalculateScreen(
              initialRentText: '38000',
              initialRenewal: DateTime(2026, 8, 15),
              initialContractStart: DateTime(2024, 8, 1),
              rentalId: 'demo-ev-1',
            ),
          ),
        ),
      ),
    );
    await _settle(tester);
    expect(find.textContaining('38000'), findsWidgets);
    await _capture(tester, '01_hesapla.png');

    // ---- 02 Sonuc ----
    await tester.ensureVisible(_hesaplaBtn());
    await tester.tap(_hesaplaBtn());
    await _settle(tester, 60);
    expect(find.textContaining('50'), findsWidgets);
    // Scroll so action buttons visible
    for (var i = 0; i < 6; i++) {
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -280));
      await _settle(tester);
      if (find.text('PDF Raporu Al').evaluate().isNotEmpty &&
          find.text('Paylaş').evaluate().isNotEmpty) {
        break;
      }
    }
    await _capture(tester, '02_sonuc.png');

    // ---- 03 Oranlar ----
    await tester.pumpWidget(
      _wrap(prefs, const Scaffold(body: SafeArea(child: RatesScreen()))),
    );
    await _settle(tester);
    await _capture(tester, '03_oranlar.png');

    // ---- 04 Kiralarım ----
    await tester.pumpWidget(
      _wrap(prefs, const Scaffold(body: SafeArea(child: RentalsScreen()))),
    );
    await _settle(tester);
    expect(find.text('Ev'), findsOneWidget);
    await _capture(tester, '04_kiralarim.png');

    // ---- 05 + 06 Detay ----
    await tester.pumpWidget(
      _wrap(
        prefs,
        const Scaffold(
          body: SafeArea(child: RentalDetailScreen(rentalId: 'demo-ev-1')),
        ),
      ),
    );
    await _settle(tester);
    await _capture(tester, '05_kira_detayi.png');
    expect(find.text('PDF'), findsOneWidget);
    await _capture(tester, '06_kira_detayi_pdf.png');

    // ---- 07 Hatırlatma ----
    await tester.pumpWidget(
      _wrap(
        prefs,
        const Scaffold(
          body: SafeArea(child: ReminderScreen(rentalId: 'demo-ev-1')),
        ),
      ),
    );
    await _settle(tester);
    expect(find.textContaining('30'), findsWidgets);
    await _capture(tester, '07_hatirlatma.png');

    // ---- 08 Ayarlar Pro ----
    await tester.pumpWidget(
      _wrap(prefs, const Scaffold(body: SafeArea(child: SettingsScreen()))),
    );
    await _settle(tester);
    expect(find.textContaining('Pro aktif'), findsOneWidget);
    await _capture(tester, '08_ayarlar_pro.png');

    // ---- 09 PDF sheet ----
    await tester.pumpWidget(
      _wrap(
        prefs,
        Builder(
          builder: (context) {
            return Scaffold(
              body: SafeArea(child: RentalDetailScreen(rentalId: 'demo-ev-1')),
              floatingActionButton: FloatingActionButton(
                onPressed: () {
                  showPdfExportSheet(
                    context,
                    onSaveToDevice: () async {},
                    onShare: () async {},
                  );
                },
                child: const Icon(Icons.picture_as_pdf),
              ),
            );
          },
        ),
      ),
    );
    await _settle(tester);
    await tester.tap(find.byType(FloatingActionButton));
    await _settle(tester);
    expect(find.text('Cihaza Kaydet'), findsOneWidget);
    expect(find.text('Paylaş'), findsOneWidget);
    await _capture(tester, '09_pdf_sheet.png');

    // ---- 10 başarı snackbar ----
    await tester.pumpWidget(
      _wrap(
        prefs,
        Builder(
          builder: (context) {
            return Scaffold(
              body: SafeArea(
                child: Center(
                  child: FilledButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('PDF cihazınıza kaydedildi'),
                        ),
                      );
                    },
                    child: const Text('Kaydet'),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
    await _settle(tester);
    // Show detail underneath success for context
    await tester.pumpWidget(
      _wrap(
        prefs,
        Builder(
          builder: (context) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('PDF cihazınıza kaydedildi')),
              );
            });
            return const Scaffold(
              body: SafeArea(child: RentalDetailScreen(rentalId: 'demo-ev-1')),
            );
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    await _capture(tester, '10_pdf_success_or_share.png');
  });
}
