import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kira_artisi_hesapla/core/constants.dart';
import 'package:kira_artisi_hesapla/core/theme.dart';
import 'package:kira_artisi_hesapla/data/local_store.dart';
import 'package:kira_artisi_hesapla/domain/models/tufe_rate.dart';
import 'package:kira_artisi_hesapla/providers/app_providers.dart';
import 'package:kira_artisi_hesapla/ui/home_shell.dart';
import 'package:kira_artisi_hesapla/ui/screens/calculate_screen.dart';
import 'package:kira_artisi_hesapla/ui/screens/history_screen.dart';
import 'package:kira_artisi_hesapla/ui/screens/legal_document_screen.dart';
import 'package:kira_artisi_hesapla/ui/screens/rates_screen.dart';
import 'package:kira_artisi_hesapla/ui/screens/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

LoadedRates _fixtureRates() {
  return LoadedRates(
    bundle: TufeRateBundle(
      version: 1,
      updatedAt: DateTime(2026, 8, 3),
      sourceNote: 'test',
      rates: [
        TufeRate(
          renewalMonth: '2026-06',
          ratePercent: 32.24,
          tuikReleaseDate: DateTime(2026, 6, 3),
        ),
        TufeRate(
          renewalMonth: '2026-07',
          ratePercent: 32.03,
          tuikReleaseDate: DateTime(2026, 7, 3),
        ),
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

Future<SharedPreferences> _prefs({
  bool onboardingDone = true,
  bool isPro = false,
}) async {
  SharedPreferences.setMockInitialValues({
    if (onboardingDone) 'onboarding_done': true,
    if (isPro) 'is_pro_lifetime': true,
  });
  return SharedPreferences.getInstance();
}

List<Override> _overrides(SharedPreferences prefs) => [
      sharedPreferencesProvider.overrideWithValue(prefs),
      ratesProvider.overrideWith((ref) async => _fixtureRates()),
    ];

Widget _app(SharedPreferences prefs, {Widget? home}) {
  return ProviderScope(
    overrides: _overrides(prefs),
    child: MaterialApp(
      theme: AppTheme.light(),
      locale: const Locale('tr', 'TR'),
      home: home ?? const HomeShell(),
    ),
  );
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
  final texts = find
      .byType(Text)
      .evaluate()
      .map((e) => (e.widget as Text).data)
      .whereType<String>()
      .take(30)
      .join(' | ');
  fail('Widget bulunamadı: $finder\nEkranda: $texts');
}

Future<void> _pumpApp(
  WidgetTester tester, {
  bool onboardingDone = true,
  bool isPro = false,
  Widget? home,
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final prefs = await _prefs(onboardingDone: onboardingDone, isPro: isPro);
  await tester.pumpWidget(_app(prefs, home: home));
  await tester.pump();
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    GoogleFonts.config.allowRuntimeFetching = false;
    await initializeDateFormatting('tr_TR');
  });

  testWidgets('1. onboarding Başla sonrası tekrar gelmez', (tester) async {
    await _pumpApp(tester, onboardingDone: false);
    await _waitFor(tester, find.text('Başla'));
    expect(find.textContaining('Ne yapar?'), findsOneWidget);

    await tester.ensureVisible(find.text('Başla'));
    await tester.tap(find.text('Başla'));
    await tester.pumpAndSettle();

    expect(find.text('Başla'), findsNothing);
    expect(find.text('Konut'), findsOneWidget);

    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(_app(prefs));
    await tester.pumpAndSettle();
    expect(find.text('Başla'), findsNothing);
    expect(find.text('Konut'), findsOneWidget);
  });

  Widget calculateHome({
    DateTime? renewal,
    DateTime? contractStart,
    String rent = '25000',
  }) {
    return Scaffold(
      body: CalculateScreen(
        initialRenewal: renewal ?? DateTime(2026, 7, 15),
        initialContractStart: contractStart ?? DateTime(2023, 7, 15),
        initialRentText: rent,
      ),
    );
  }

  testWidgets('2. Temmuz 2026 + 25000 sonuç ve soft etiketler', (tester) async {
    await _pumpApp(tester, home: calculateHome());
    await _waitFor(tester, find.text('Konut'));
    expect(find.text('Çatılı işyeri'), findsOneWidget);

    await tester.ensureVisible(_hesaplaButton());
    await tester.tap(_hesaplaButton());
    await tester.pumpAndSettle();

    expect(find.text('BU ORANA GÖRE HESAPLANAN KIRA'), findsOneWidget);
    expect(find.text('TÜFE esaslı azami artış oranı'), findsOneWidget);
    expect(find.textContaining('%32,03'), findsWidgets);
    expect(find.textContaining('33.007,50'), findsOneWidget);
  });

  testWidgets('2b. sözleşme %40 → bilgilendirme uyarısı', (tester) async {
    await _pumpApp(tester, home: calculateHome());
    await _waitFor(tester, find.text('Konut'));

    await tester.enterText(find.byType(TextField).at(1), '40');
    await tester.tap(_hesaplaButton());
    await tester.pumpAndSettle();

    expect(find.text('Artış Oranı Bilgilendirmesi'), findsOneWidget);
    expect(find.textContaining('azami orana göre gösterildi'), findsOneWidget);
  });

  testWidgets('2c. 5+ yıl → 5 Yıl Notu', (tester) async {
    await _pumpApp(
      tester,
      home: calculateHome(contractStart: DateTime(2019, 7, 15)),
    );
    await _waitFor(tester, find.text('Konut'));
    await tester.tap(_hesaplaButton());
    await tester.pumpAndSettle();

    expect(find.text('5 Yıl Notu'), findsOneWidget);
  });

  testWidgets('2d. Eylül 2026 oran yok → Hesapla disabled', (tester) async {
    await _pumpApp(
      tester,
      home: calculateHome(renewal: DateTime(2026, 9, 15)),
    );
    await _waitFor(tester, find.textContaining('için oran henüz yok'));

    final btn = tester.widget<FilledButton>(_hesaplaButton());
    expect(btn.onPressed, isNull);
  });

  testWidgets('2e. Kopyala / Paylaş butonları sonuçta görünür', (tester) async {
    await _pumpApp(tester, home: calculateHome());
    await _waitFor(tester, find.text('Konut'));
    await tester.tap(_hesaplaButton());
    await tester.pumpAndSettle();

    expect(find.widgetWithText(OutlinedButton, 'Kopyala'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Paylaş'), findsOneWidget);
  });

  testWidgets('3. Free PDF → paywall', (tester) async {
    await _pumpApp(tester, home: calculateHome());
    await _waitFor(tester, find.text('Konut'));
    await tester.tap(_hesaplaButton());
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('PDF Raporu Al'));
    await tester.tap(find.text('PDF Raporu Al'));
    await tester.pumpAndSettle();

    expect(find.text(AppConstants.proPriceLabel), findsWidgets);
    expect(find.text('Şimdi Al'), findsOneWidget);
  });

  testWidgets('4. Free hatırlatma → paywall (Ayarlar)', (tester) async {
    await _pumpApp(tester);
    await _waitFor(tester, find.text('Konut'));

    await tester.tap(find.text('Ayarlar'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Yenileme Hatırlatması'));
    await tester.tap(find.text('Yenileme Hatırlatması'));
    await tester.pumpAndSettle();

    expect(find.text('Şimdi Al'), findsOneWidget);
    expect(find.text(AppConstants.proPriceLabel), findsWidgets);
  });

  testWidgets('5. Geçmiş boş + 6 hesapta free limit 5', (tester) async {
    final prefs = await _prefs();
    await tester.pumpWidget(
      ProviderScope(
        overrides: _overrides(prefs),
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: HistoryScreen(onNewCalculation: () {}),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Henüz hesaplama yok'), findsOneWidget);

    final repo = HistoryRepository(prefs);
    for (var i = 0; i < 6; i++) {
      await repo.add(
        HistoryEntry(
          id: '$i',
          createdAt: DateTime(2026, 1, 1, i),
          currentRent: 25000,
          renewalMonthKey: '2026-07',
          applicableRatePercent: 32.03,
          calculatedRent: 33007.5,
          isFiveYearsOrMore: false,
        ),
        isPro: false,
      );
    }
    expect(repo.loadAll().length, 5);
  });

  testWidgets('5b. Geçmiş Pro yükselt kartı', (tester) async {
    final prefs = await _prefs();
    final repo = HistoryRepository(prefs);
    await repo.add(
      HistoryEntry(
        id: '1',
        createdAt: DateTime.now(),
        currentRent: 25000,
        renewalMonthKey: '2026-07',
        applicableRatePercent: 32.03,
        calculatedRent: 33007.5,
        isFiveYearsOrMore: false,
      ),
      isPro: false,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: _overrides(prefs),
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: HistoryScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Yükselt'), findsOneWidget);
    expect(find.textContaining('Ücretsiz: son 5 kayıt'), findsOneWidget);
  });

  testWidgets('6. Oranlar listesi + YENİ', (tester) async {
    await _pumpApp(
      tester,
      home: const Scaffold(body: RatesScreen()),
    );
    await _waitFor(tester, find.text('Temmuz 2026'));
    expect(find.text('YENİ'), findsOneWidget);
  });

  testWidgets('6b. Yasal metinler açılır', (tester) async {
    await _pumpApp(
      tester,
      home: const Scaffold(body: SettingsScreen()),
    );
    await _waitFor(tester, find.text('Gizlilik'));

    await tester.tap(find.text('Gizlilik'));
    await tester.pumpAndSettle();
    expect(find.byType(LegalDocumentScreen), findsOneWidget);
    expect(find.text('Gizlilik Politikası'), findsOneWidget);
  });

  testWidgets('Pro aktif görünümü Ayarlar', (tester) async {
    await _pumpApp(
      tester,
      isPro: true,
      home: const Scaffold(body: SettingsScreen()),
    );
    await _waitFor(tester, find.textContaining('Pro aktif'));
  });
}
