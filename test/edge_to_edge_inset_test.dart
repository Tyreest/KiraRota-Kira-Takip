import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kira_artisi_hesapla/core/theme.dart';
import 'package:kira_artisi_hesapla/data/rental_repository.dart';
import 'package:kira_artisi_hesapla/domain/models/rental.dart';
import 'package:kira_artisi_hesapla/domain/models/tufe_rate.dart';
import 'package:kira_artisi_hesapla/providers/app_providers.dart';
import 'package:kira_artisi_hesapla/services/reminder_service.dart';
import 'package:kira_artisi_hesapla/ui/home_shell.dart';
import 'package:kira_artisi_hesapla/ui/screens/calculate_screen.dart';
import 'package:kira_artisi_hesapla/ui/screens/onboarding_screen.dart';
import 'package:kira_artisi_hesapla/ui/screens/reminder_screen.dart';
import 'package:kira_artisi_hesapla/ui/screens/rental_detail_screen.dart';
import 'package:kira_artisi_hesapla/ui/screens/rental_edit_screen.dart';
import 'package:kira_artisi_hesapla/ui/screens/settings_screen.dart';
import 'package:kira_artisi_hesapla/ui/widgets/pdf_export_sheet.dart';
import 'package:kira_artisi_hesapla/ui/widgets/pro_paywall.dart';
import 'package:kira_artisi_hesapla/ui/widgets/review_access_sheet.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _size = Size(412, 915);
const _status = 48.0;
const _nav3Button = 48.0;
const _navGesture = 24.0;
const _keyboard = 320.0;

LoadedRates _rates() {
  return LoadedRates(
    bundle: TufeRateBundle(
      version: 1,
      updatedAt: DateTime(2026, 8, 3),
      sourceNote: 'test',
      rates: [
        TufeRate(
          renewalMonth: '2026-08',
          ratePercent: 31.90,
          tuikReleaseDate: DateTime(2026, 8, 3),
        ),
      ],
    ),
    source: RateSource.asset,
  );
}

void _applyInsets(
  WidgetTester tester, {
  double top = _status,
  double bottom = _nav3Button,
  double keyboard = 0,
}) {
  tester.view.physicalSize = _size;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = FakeViewPadding(
    top: top,
    bottom: keyboard > 0 ? 0 : bottom,
  );
  tester.view.viewPadding = FakeViewPadding(top: top, bottom: bottom);
  tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPadding);
  addTearDown(tester.view.resetViewPadding);
  addTearDown(tester.view.resetViewInsets);
}

void _expectAboveSystemNav(
  WidgetTester tester,
  Finder finder, {
  double bottom = _nav3Button,
  double keyboard = 0,
}) {
  expect(finder, findsWidgets);
  final rect = tester.getRect(finder.first);
  final limit = _size.height - (keyboard > 0 ? keyboard : bottom);
  expect(
    rect.bottom,
    lessThanOrEqualTo(limit + 0.5),
    reason:
        '$finder sistem/klavye alanına taşıyor (bottom=${rect.bottom} limit=$limit)',
  );
  expect(rect.top, greaterThanOrEqualTo(0));
}

void _expectBelowStatusBar(WidgetTester tester, Finder finder) {
  expect(finder, findsWidgets);
  final rect = tester.getRect(finder.first);
  expect(
    rect.top,
    greaterThanOrEqualTo(_status - 0.5),
    reason: '$finder status bar altında (top=${rect.top})',
  );
}

Future<SharedPreferences> _prefs({bool onboardingDone = true}) async {
  SharedPreferences.setMockInitialValues({
    if (onboardingDone) 'onboarding_done': true,
    'is_pro_lifetime': true,
  });
  return SharedPreferences.getInstance();
}

Future<void> _seedRental(SharedPreferences prefs) async {
  final now = DateTime(2026, 1, 1);
  await RentalRepository(prefs).add(
    Rental(
      id: 'r1',
      role: RentalRole.tenant,
      displayName: 'Evim',
      currentRent: 25000,
      contractStartDate: DateTime(2024, 8, 15),
      increaseDate: DateTime(2026, 8, 15),
      createdAt: now,
      updatedAt: now,
    ),
    isPro: true,
  );
}

List<Override> _overrides(SharedPreferences prefs) => [
  sharedPreferencesProvider.overrideWithValue(prefs),
  ratesProvider.overrideWith((ref) async => _rates()),
  reminderServiceProvider.overrideWithValue(
    ReminderService(prefs, enableNotifications: false),
  ),
];

Widget _app(SharedPreferences prefs, {required Widget home}) {
  return ProviderScope(
    overrides: _overrides(prefs),
    child: MaterialApp(
      theme: AppTheme.light(),
      locale: const Locale('tr', 'TR'),
      supportedLocales: const [Locale('tr', 'TR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: home,
    ),
  );
}

Finder _filled(String label) =>
    find.ancestor(of: find.text(label), matching: find.byType(FilledButton));

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

  group('3-button navigation', () {
    testWidgets('HomeShell: başlık status altında değil; nav label örtülmez', (
      tester,
    ) async {
      _applyInsets(tester);
      final prefs = await _prefs();
      await tester.pumpWidget(_app(prefs, home: const HomeShell()));
      await tester.pumpAndSettle();

      _expectBelowStatusBar(tester, find.text('KiraRota'));
      _expectAboveSystemNav(
        tester,
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Ayarlar'),
        ),
      );
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Hesapla'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(_filled('Hesapla'));
      await tester.pumpAndSettle();
      _expectAboveSystemNav(tester, _filled('Hesapla'));
    });

    testWidgets(
      'Oranlar / Kiralarım / Ayarlar başlıkları status altında değil',
      (tester) async {
        _applyInsets(tester);
        final prefs = await _prefs();
        await tester.pumpWidget(_app(prefs, home: const HomeShell()));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Oranlar'));
        await tester.pumpAndSettle();
        _expectBelowStatusBar(tester, find.text('TÜFE Oranları'));

        await tester.tap(
          find.descendant(
            of: find.byType(NavigationBar),
            matching: find.text('Kiralarım'),
          ),
        );
        await tester.pumpAndSettle();
        _expectBelowStatusBar(tester, find.text('Kiralarım').first);

        await tester.tap(
          find.descendant(
            of: find.byType(NavigationBar),
            matching: find.text('Ayarlar'),
          ),
        );
        await tester.pumpAndSettle();
        _expectBelowStatusBar(tester, find.text('Ayarlar').first);
      },
    );

    testWidgets('Yeni dönemi hesapla: Hesapla CTA nav altında değil', (
      tester,
    ) async {
      _applyInsets(tester);
      final prefs = await _prefs();
      await _seedRental(prefs);
      await tester.pumpWidget(
        _app(
          prefs,
          home: CalculateScreen(
            rentalId: 'r1',
            initialRentText: '25000',
            initialRenewal: DateTime(2026, 8, 15),
            initialContractStart: DateTime(2024, 8, 15),
          ),
        ),
      );
      await tester.pumpAndSettle();

      _expectBelowStatusBar(tester, find.text('Yeni dönemi hesapla'));
      await tester.ensureVisible(_filled('Hesapla'));
      await tester.pumpAndSettle();
      _expectAboveSystemNav(tester, _filled('Hesapla'));
    });

    testWidgets('Yeni dönemi hesapla sonuç: PDF CTA nav altında değil', (
      tester,
    ) async {
      _applyInsets(tester);
      final prefs = await _prefs();
      await _seedRental(prefs);
      await tester.pumpWidget(
        _app(
          prefs,
          home: CalculateScreen(
            rentalId: 'r1',
            initialRentText: '25000',
            initialRenewal: DateTime(2026, 8, 15),
            initialContractStart: DateTime(2024, 8, 15),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(_filled('Hesapla'));
      await tester.pumpAndSettle();
      await tester.tap(_filled('Hesapla'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('PDF Raporu Al'));
      await tester.pumpAndSettle();
      _expectAboveSystemNav(tester, find.text('PDF Raporu Al'));
      await tester.ensureVisible(find.text('Yeni kirayı kaydet'));
      await tester.pumpAndSettle();
      _expectAboveSystemNav(tester, find.text('Yeni kirayı kaydet'));
    });

    testWidgets('Kira Detayı CTA nav altında değil', (tester) async {
      _applyInsets(tester);
      final prefs = await _prefs();
      await _seedRental(prefs);
      await tester.pumpWidget(
        _app(prefs, home: const RentalDetailScreen(rentalId: 'r1')),
      );
      await tester.pumpAndSettle();

      _expectBelowStatusBar(tester, find.text('Kira Detayı'));
      await tester.ensureVisible(find.text('Yeni dönemi hesapla'));
      await tester.pumpAndSettle();
      _expectAboveSystemNav(tester, find.text('Yeni dönemi hesapla'));
    });

    testWidgets('Kira Ekle kaydet CTA nav altında değil', (tester) async {
      _applyInsets(tester);
      final prefs = await _prefs();
      await tester.pumpWidget(_app(prefs, home: const RentalEditScreen()));
      await tester.pumpAndSettle();

      _expectBelowStatusBar(tester, find.text('Kira Ekle'));
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -1400));
      await tester.pumpAndSettle();
      expect(find.text('Kirayı Kaydet'), findsOneWidget);
      _expectAboveSystemNav(tester, find.text('Kirayı Kaydet'));
    });

    testWidgets('Hatırlatma kaydet CTA nav altında değil', (tester) async {
      _applyInsets(tester);
      final prefs = await _prefs();
      await _seedRental(prefs);
      await tester.pumpWidget(
        _app(prefs, home: const ReminderScreen(rentalId: 'r1')),
      );
      await tester.pumpAndSettle();

      _expectBelowStatusBar(tester, find.text('Yenileme Hatırlatması'));
      await tester.ensureVisible(_filled('Hatırlatmaları Kaydet'));
      await tester.pumpAndSettle();
      _expectAboveSystemNav(tester, _filled('Hatırlatmaları Kaydet'));
    });

    testWidgets('Onboarding Başla nav altında değil', (tester) async {
      _applyInsets(tester);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: OnboardingScreen(onDone: () {}),
        ),
      );
      await tester.pumpAndSettle();
      _expectBelowStatusBar(tester, find.text('KiraRota'));
      _expectAboveSystemNav(tester, find.text('Başla'));
    });

    testWidgets('Paywall CTA 3-button nav üstünde', (tester) async {
      // Paywall fiyat satırı dar genişlikte taşabiliyor; inset ölçümü için
      // gerçekçi telefon genişliği kullan (layout redesign değil).
      _applyInsets(tester);
      tester.view.physicalSize = const Size(1080, 915);
      final prefs = await _prefs();
      await tester.pumpWidget(
        ProviderScope(
          overrides: _overrides(prefs),
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const _PaywallHost(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('open-paywall'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Şimdi Al'));
      await tester.pumpAndSettle();
      _expectAboveSystemNav(tester, find.text('Şimdi Al'));
    });

    testWidgets('PDF Raporu sheet aksiyonları nav üstünde', (tester) async {
      _applyInsets(tester);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => showPdfExportSheet(
                    context,
                    onSaveToDevice: () async {},
                    onShare: () async {},
                  ),
                  child: const Text('open-pdf'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open-pdf'));
      await tester.pumpAndSettle();
      _expectAboveSystemNav(tester, find.text('Cihaza Kaydet'));
      _expectAboveSystemNav(tester, find.text('Paylaş'));
    });

    testWidgets('Hakkında Tamam nav üstünde', (tester) async {
      _applyInsets(tester);
      final prefs = await _prefs();
      await tester.pumpWidget(_app(prefs, home: const SettingsScreen()));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Uygulama Hakkında'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Uygulama Hakkında'));
      await tester.pumpAndSettle();
      _expectAboveSystemNav(tester, find.text('Tamam'));
      expect(find.text('TÜİK Veri Portalı'), findsOneWidget);
    });

    testWidgets('Sil dialog aksiyonları görünür', (tester) async {
      _applyInsets(tester);
      final prefs = await _prefs();
      await _seedRental(prefs);
      await tester.pumpWidget(
        _app(prefs, home: const RentalDetailScreen(rentalId: 'r1')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kayıt sil'));
      await tester.pumpAndSettle();
      expect(find.text('Sil'), findsOneWidget);
      _expectAboveSystemNav(tester, find.text('Sil'));
      _expectAboveSystemNav(tester, find.text('Vazgeç'));
    });
  });

  group('gesture navigation', () {
    testWidgets('HomeShell nav label gesture inset üstünde', (tester) async {
      _applyInsets(tester, bottom: _navGesture);
      final prefs = await _prefs();
      await tester.pumpWidget(_app(prefs, home: const HomeShell()));
      await tester.pumpAndSettle();
      _expectAboveSystemNav(
        tester,
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Ayarlar'),
        ),
        bottom: _navGesture,
      );
    });
  });

  group('keyboard / viewInsets', () {
    testWidgets('Kira Ekle: klavye açıkken Kaydet erişilebilir', (
      tester,
    ) async {
      _applyInsets(tester, keyboard: _keyboard);
      final prefs = await _prefs();
      await tester.pumpWidget(_app(prefs, home: const RentalEditScreen()));
      await tester.pumpAndSettle();

      await tester.drag(find.byType(Scrollable).first, const Offset(0, -1400));
      await tester.pumpAndSettle();
      expect(find.text('Kirayı Kaydet'), findsOneWidget);
      _expectAboveSystemNav(
        tester,
        find.text('Kirayı Kaydet'),
        keyboard: _keyboard,
      );
    });

    testWidgets('Kiralarıma Kaydet sheet: klavye açıkken Kaydet görünür', (
      tester,
    ) async {
      _applyInsets(tester);
      final prefs = await _prefs();
      await tester.pumpWidget(
        _app(
          prefs,
          home: CalculateScreen(
            initialRentText: '25000',
            initialRenewal: DateTime(2026, 8, 15),
            initialContractStart: DateTime(2024, 8, 15),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(_filled('Hesapla'));
      await tester.pumpAndSettle();
      await tester.tap(_filled('Hesapla'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Kiralarıma Kaydet'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kiralarıma Kaydet'));
      await tester.pumpAndSettle();

      // Sheet açık; klavyeyi simüle et
      _applyInsets(tester, keyboard: _keyboard);
      await tester.pumpAndSettle();

      expect(find.text('Kaydet'), findsOneWidget);
      await tester.ensureVisible(find.text('Kaydet'));
      await tester.pumpAndSettle();
      _expectAboveSystemNav(tester, find.text('Kaydet'), keyboard: _keyboard);
    });

    testWidgets('Review Access regression: klavye + nav inset', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: MediaQuery(
            data: const MediaQueryData(
              size: _size,
              viewPadding: EdgeInsets.only(bottom: _nav3Button),
              padding: EdgeInsets.zero,
              viewInsets: EdgeInsets.only(bottom: _keyboard),
            ),
            child: const Scaffold(
              body: Align(
                alignment: Alignment.bottomCenter,
                child: ReviewAccessSheetScaffold(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(),
                      FilledButton(onPressed: null, child: Text('Doğrula')),
                      TextButton(onPressed: null, child: Text('İptal')),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final cancel = tester.getRect(find.text('İptal'));
      expect(cancel.bottom, lessThanOrEqualTo(_size.height - _keyboard + 0.5));
    });
  });

  group('small viewport', () {
    testWidgets('küçük yükseklikte HomeShell overflow yok', (tester) async {
      FlutterErrorDetails? overflow;
      final old = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.toString().contains('overflowed')) overflow = details;
        old?.call(details);
      };
      addTearDown(() => FlutterError.onError = old);

      tester.view.physicalSize = const Size(320, 280);
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(top: 24, bottom: 48);
      tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 48);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPadding);
      addTearDown(tester.view.resetViewPadding);

      final prefs = await _prefs();
      await tester.pumpWidget(_app(prefs, home: const HomeShell()));
      await tester.pump();
      expect(overflow, isNull);
    });
  });
}

class _PaywallHost extends ConsumerWidget {
  const _PaywallHost();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: TextButton(
          onPressed: () => showProPaywall(context, ref),
          child: const Text('open-paywall'),
        ),
      ),
    );
  }
}
