import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kira_artisi_hesapla/core/theme.dart';
import 'package:kira_artisi_hesapla/data/rental_repository.dart';
import 'package:kira_artisi_hesapla/domain/models/calculation.dart';
import 'package:kira_artisi_hesapla/domain/models/rental.dart';
import 'package:kira_artisi_hesapla/domain/models/tufe_rate.dart';
import 'package:kira_artisi_hesapla/providers/app_providers.dart';
import 'package:kira_artisi_hesapla/services/ads_service.dart';
import 'package:kira_artisi_hesapla/services/pdf_report_service.dart';
import 'package:kira_artisi_hesapla/services/reminder_service.dart';
import 'package:kira_artisi_hesapla/ui/home_shell.dart';
import 'package:kira_artisi_hesapla/ui/screens/calculate_screen.dart';
import 'package:kira_artisi_hesapla/ui/screens/reminder_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<Rental> _seedRental(SharedPreferences prefs, {String id = 'r1'}) async {
  final now = DateTime(2026, 1, 1);
  final rental = Rental(
    id: id,
    role: RentalRole.tenant,
    displayName: 'Evim',
    currentRent: 25000,
    contractStartDate: DateTime(2024, 1, 1),
    increaseDate: DateTime(2027, 3, 15),
    createdAt: now,
    updatedAt: now,
  );
  await RentalRepository(prefs).add(rental, isPro: true);
  return rental;
}

LoadedRates _fixtureRates() {
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
      ],
    ),
    source: RateSource.asset,
  );
}

class _FakePdf extends PdfReportService {
  int shareCalls = 0;
  int saveCalls = 0;
  CalculationResult? last;

  @override
  Future<void> shareCalculation(
    CalculationResult result, {
    String? rentalName,
  }) async {
    shareCalls++;
    last = result;
  }

  @override
  Future<PdfSaveResult> saveCalculationToDevice(
    CalculationResult result, {
    String? rentalName,
  }) async {
    saveCalls++;
    last = result;
    return const PdfSaveResult(PdfSaveOutcome.saved, path: '/tmp/test.pdf');
  }
}

Finder _hesaplaButton() => find.ancestor(
  of: find.text('Hesapla'),
  matching: find.byType(FilledButton),
);

Future<void> _waitFor(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 50; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) return;
  }
  fail('Widget bulunamadı: $finder');
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    GoogleFonts.config.allowRuntimeFetching = false;
    await initializeDateFormatting('tr_TR');
  });

  Future<ProviderContainer> pumpHome(
    WidgetTester tester, {
    required bool isPro,
    _FakePdf? pdf,
    SharedPreferences? prefsOverride,
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    late final SharedPreferences prefs;
    if (prefsOverride != null) {
      prefs = prefsOverride;
    } else {
      SharedPreferences.setMockInitialValues({
        'onboarding_done': true,
        if (isPro) 'is_pro_lifetime': true,
      });
      prefs = await SharedPreferences.getInstance();
    }
    final fakePdf = pdf ?? _FakePdf();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          ratesProvider.overrideWith((ref) async => _fixtureRates()),
          reminderServiceProvider.overrideWithValue(
            ReminderService(prefs, enableNotifications: false),
          ),
          pdfReportServiceProvider.overrideWithValue(fakePdf),
        ],
        child: MaterialApp(theme: AppTheme.light(), home: const HomeShell()),
      ),
    );
    await tester.pump();
    await _waitFor(tester, find.text('Özet'));
    return ProviderScope.containerOf(tester.element(find.byType(HomeShell)));
  }

  testWidgets('3b. Pro iken AdBanner yok', (tester) async {
    await pumpHome(tester, isPro: true);
    expect(find.byType(AdBanner), findsNothing);

    // Free karşılaştırması
    await pumpHome(tester, isPro: false);
    // Banner widget tree’de (yüklenmese bile AdBanner state vardır)
    expect(find.byType(AdBanner), findsOneWidget);
  });

  testWidgets('3c. Pro PDF → action sheet → Paylaş shareCalculation', (
    tester,
  ) async {
    final pdf = _FakePdf();
    SharedPreferences.setMockInitialValues({
      'onboarding_done': true,
      'is_pro_lifetime': true,
    });
    final prefs = await SharedPreferences.getInstance();

    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          ratesProvider.overrideWith((ref) async => _fixtureRates()),
          pdfReportServiceProvider.overrideWithValue(pdf),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: CalculateScreen(
              initialRenewal: DateTime(2026, 7, 15),
              initialContractStart: DateTime(2023, 7, 15),
              initialRentText: '25000',
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await _waitFor(tester, find.text('Konut'));

    await tester.tap(_hesaplaButton());
    await tester.pumpAndSettle();

    final pdfBtn = find.widgetWithText(OutlinedButton, 'PDF');
    await tester.ensureVisible(pdfBtn);
    await tester.tap(pdfBtn);
    await tester.pumpAndSettle();

    expect(find.text('Cihaza Kaydet'), findsOneWidget);
    expect(find.text('Paylaş'), findsWidgets);

    await tester.tap(find.widgetWithText(ListTile, 'Paylaş'));
    await tester.pumpAndSettle();

    expect(pdf.shareCalls, 1);
    expect(pdf.saveCalls, 0);
    expect(pdf.last, isNotNull);
    expect(find.text('Şimdi Al'), findsNothing);
  });

  testWidgets('3d. Pro PDF → action sheet → Cihaza Kaydet', (tester) async {
    final pdf = _FakePdf();
    SharedPreferences.setMockInitialValues({
      'onboarding_done': true,
      'is_pro_lifetime': true,
    });
    final prefs = await SharedPreferences.getInstance();

    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          ratesProvider.overrideWith((ref) async => _fixtureRates()),
          pdfReportServiceProvider.overrideWithValue(pdf),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: CalculateScreen(
              initialRenewal: DateTime(2026, 7, 15),
              initialContractStart: DateTime(2023, 7, 15),
              initialRentText: '25000',
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await _waitFor(tester, find.text('Konut'));

    await tester.tap(_hesaplaButton());
    await tester.pumpAndSettle();

    final pdfBtn2 = find.widgetWithText(OutlinedButton, 'PDF');
    await tester.ensureVisible(pdfBtn2);
    await tester.tap(pdfBtn2);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cihaza Kaydet'));
    await tester.pumpAndSettle();

    expect(pdf.saveCalls, 1);
    expect(pdf.shareCalls, 0);
    expect(find.text('PDF cihazınıza kaydedildi'), findsOneWidget);
  });

  testWidgets('4b. Pro hatırlatma kaydet + kaldır', (tester) async {
    SharedPreferences.setMockInitialValues({
      'onboarding_done': true,
      'is_pro_lifetime': true,
    });
    final prefs = await SharedPreferences.getInstance();
    await _seedRental(prefs);
    final reminders = ReminderService(prefs, enableNotifications: false);

    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          reminderServiceProvider.overrideWithValue(reminders),
          ratesProvider.overrideWith((ref) async => _fixtureRates()),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const ReminderScreen(rentalId: 'r1'),
                      ),
                    );
                  },
                  child: const Text('Aç'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aç'));
    await tester.pumpAndSettle();

    expect(find.text('30 gün önce'), findsOneWidget);
    expect(find.text('7 gün önce'), findsOneWidget);
    expect(find.text('Yenileme günü'), findsOneWidget);

    await tester.tap(find.text('Hatırlatmaları Kaydet'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(RentalRepository(prefs).findById('r1')!.reminder.enabled, isTrue);
    expect(find.text('Hatırlatmalar kaydedildi'), findsOneWidget);

    await tester.pumpAndSettle();
    await tester.tap(find.text('Aç'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Hatırlatmaları Kaldır'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(RentalRepository(prefs).findById('r1')!.reminder.enabled, isFalse);
    await tester.pumpAndSettle();
    expect(find.text('Aç'), findsOneWidget);
  });

  testWidgets('4c. Pro iken Ayarlar → hatırlatma ekranı (paywall değil)', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'onboarding_done': true,
      'is_pro_lifetime': true,
    });
    final prefs = await SharedPreferences.getInstance();
    await _seedRental(prefs);
    await pumpHome(tester, isPro: true, prefsOverride: prefs);
    await tester.tap(find.text('Ayarlar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yenileme Hatırlatması'));
    await tester.pumpAndSettle();

    expect(find.byType(ReminderScreen), findsOneWidget);
    expect(find.text('Hatırlatmaları Kaydet'), findsOneWidget);
    expect(find.text('Şimdi Al'), findsNothing);
  });

  test('ReminderConfig prefs round-trip', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final cfg = ReminderConfig(
      renewalDate: DateTime(2027, 1, 10),
      notify30: true,
      notify7: false,
      notify0: true,
    );
    await cfg.save(prefs);
    final loaded = ReminderConfig.load(prefs)!;
    expect(loaded.notify30, isTrue);
    expect(loaded.notify7, isFalse);
    expect(loaded.notify0, isTrue);
    await ReminderConfig.clear(prefs);
    expect(ReminderConfig.load(prefs), isNull);
  });
}
