import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kira_artisi_hesapla/core/theme.dart';
import 'package:kira_artisi_hesapla/domain/models/tufe_rate.dart';
import 'package:kira_artisi_hesapla/providers/app_providers.dart';
import 'package:kira_artisi_hesapla/ui/home_shell.dart';
import 'package:kira_artisi_hesapla/ui/screens/calculate_screen.dart';
import 'package:kira_artisi_hesapla/ui/screens/legal_document_screen.dart';
import 'package:kira_artisi_hesapla/ui/screens/rates_screen.dart';
import 'package:kira_artisi_hesapla/ui/screens/rentals_screen.dart';
import 'package:kira_artisi_hesapla/ui/screens/settings_screen.dart';
import 'package:kira_artisi_hesapla/data/rental_repository.dart';
import 'package:kira_artisi_hesapla/domain/models/rental.dart';
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
      supportedLocales: const [Locale('tr', 'TR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
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
    expect(find.text('KiraRota'), findsOneWidget);
    expect(find.textContaining('Kiralarını takip et'), findsOneWidget);

    await tester.ensureVisible(find.text('Başla'));
    await tester.tap(find.text('Başla'));
    await tester.pumpAndSettle();

    expect(find.text('Başla'), findsNothing);
    expect(find.text('Kiranı takip etmeye başla'), findsOneWidget);
    expect(find.byKey(const Key('dashboard_page_title')), findsOneWidget);
    expect(
      (tester.widget<Text>(find.byKey(const Key('dashboard_page_title')))).data,
      'KiraRota',
    );
    expect(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Özet'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Kiralarım'),
      ),
      findsOneWidget,
    );

    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(_app(prefs));
    await tester.pumpAndSettle();
    expect(find.text('Başla'), findsNothing);
    expect(find.text('Kiranı takip etmeye başla'), findsOneWidget);
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
    expect(find.text('İşyeri'), findsOneWidget);

    await tester.ensureVisible(_hesaplaButton());
    await tester.tap(_hesaplaButton());
    await tester.pumpAndSettle();

    expect(find.text('Hesaplanan Yeni Kira'), findsOneWidget);
    expect(find.text('TÜFE oranı'), findsOneWidget);
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
    await _pumpApp(tester, home: calculateHome(renewal: DateTime(2026, 9, 15)));
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

    expect(find.text('Şimdi Al'), findsOneWidget);
    // Fiyat Play’den gelir; test ortamında katalog yok → fallback
    expect(
      find.textContaining('Mağazadan alın').evaluate().isNotEmpty ||
          find.textContaining('Fiyat yükleniyor').evaluate().isNotEmpty ||
          find
              .textContaining('Fiyat şu anda alınamadı')
              .evaluate()
              .isNotEmpty ||
          find.textContaining('₺').evaluate().isNotEmpty,
      isTrue,
    );
  });

  testWidgets('4. Free hatırlatma → paywall (Ayarlar)', (tester) async {
    await _pumpApp(tester);
    await _waitFor(tester, find.text('Kiranı takip etmeye başla'));

    await tester.tap(find.text('Ayarlar'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Yenileme Hatırlatması'));
    await tester.tap(find.text('Yenileme Hatırlatması'));
    await tester.pumpAndSettle();

    expect(find.text('Şimdi Al'), findsOneWidget);
  });

  testWidgets('sekme başlıkları: 5-tab + Özet dashboard', (tester) async {
    await _pumpApp(tester);
    await _waitFor(tester, find.text('Kiranı takip etmeye başla'));

    expect(find.text('Özet'), findsOneWidget);
    expect(find.text('Ana'), findsNothing);
    expect(find.text('Kiralarım'), findsOneWidget);
    expect(find.text('Hesapla'), findsOneWidget);
    expect(find.text('Oranlar'), findsOneWidget);
    expect(find.text('Ayarlar'), findsOneWidget);
    expect(find.text('Kira Ekle'), findsOneWidget);
    expect(find.text('Manuel kira artışı hesapla'), findsOneWidget);
    expect(find.text('Kira Artışı Hesapla'), findsNothing);
    expect(find.text('Kira Asistanı'), findsNothing);

    await tester.tap(find.text('Oranlar'));
    await tester.pumpAndSettle();
    expect(find.text('TÜFE Oranları'), findsOneWidget);

    await tester.tap(find.text('Kiralarım'));
    await tester.pumpAndSettle();
    expect(find.text('Kiralarım'), findsWidgets);
    expect(
      find.textContaining('TÜFE hesaplamalarınızı tek yerden takip edin.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Ayarlar'));
    await tester.pumpAndSettle();
    expect(find.text('Ayarlar'), findsWidgets);

    // Navigation regression: Hesapla (tab index 2)
    await tester.tap(find.text('Hesapla'));
    await tester.pumpAndSettle();
    expect(find.text('Konut'), findsOneWidget);
  });

  testWidgets('5. Kiralarım boş + free 1 kira limiti', (tester) async {
    final prefs = await _prefs();
    await tester.pumpWidget(
      ProviderScope(
        overrides: _overrides(prefs),
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: RentalsScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Kiralarım'), findsOneWidget);
    expect(find.text('Kira Asistanı'), findsNothing);
    expect(
      find.textContaining('TÜFE hesaplamalarınızı tek yerden takip edin.'),
      findsOneWidget,
    );
    expect(find.text('Henüz kayıtlı kiranız yok'), findsOneWidget);

    final repo = RentalRepository(prefs);
    final now = DateTime(2026, 1, 1);
    expect(
      await repo.add(
        Rental(
          id: '1',
          role: RentalRole.tenant,
          displayName: 'Evim',
          currentRent: 25000,
          contractStartDate: DateTime(2024, 1, 1),
          increaseDate: DateTime(2026, 8, 8),
          createdAt: now,
          updatedAt: now,
        ),
        isPro: false,
      ),
      isTrue,
    );
    expect(
      await repo.add(
        Rental(
          id: '2',
          role: RentalRole.landlord,
          displayName: 'Dükkan',
          currentRent: 10000,
          contractStartDate: DateTime(2024, 1, 1),
          increaseDate: DateTime(2026, 8, 8),
          createdAt: now,
          updatedAt: now,
        ),
        isPro: false,
      ),
      isFalse,
    );
    expect(repo.loadAll().length, 1);
  });

  testWidgets('5b. Kiralarım Pro yükselt kartı', (tester) async {
    final prefs = await _prefs();
    final repo = RentalRepository(prefs);
    final now = DateTime.now();
    await repo.add(
      Rental(
        id: '1',
        role: RentalRole.tenant,
        displayName: 'Evim',
        currentRent: 25000,
        contractStartDate: DateTime(2024, 1, 1),
        increaseDate: DateTime(2026, 8, 8),
        createdAt: now,
        updatedAt: now,
      ),
      isPro: false,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: _overrides(prefs),
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: RentalsScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Sınırsız kira takibi'), findsOneWidget);
    expect(find.textContaining('Ücretsiz: 1 kayıtlı kira'), findsOneWidget);
  });

  testWidgets('6. Oranlar listesi + YENİ', (tester) async {
    await _pumpApp(tester, home: const Scaffold(body: RatesScreen()));
    await _waitFor(tester, find.text('Temmuz 2026'));
    expect(find.text('YENİ'), findsOneWidget);
  });

  testWidgets('6b. Yasal metinler açılır', (tester) async {
    await _pumpApp(tester, home: const Scaffold(body: SettingsScreen()));
    await _waitFor(tester, find.text('Gizlilik'));

    await tester.tap(find.text('Gizlilik'));
    await tester.pumpAndSettle();
    expect(find.byType(LegalDocumentScreen), findsOneWidget);
    expect(find.text('Gizlilik Politikası'), findsWidgets);
    expect(find.textContaining('#'), findsNothing);
    expect(find.textContaining('**'), findsNothing);
  });

  testWidgets('Review Access İptal — controller dispose crash yok', (
    tester,
  ) async {
    await _pumpApp(tester, home: const Scaffold(body: SettingsScreen()));
    await _waitFor(tester, find.textContaining('Tyreest Studio'));

    final version = find.textContaining('Tyreest Studio');
    for (var i = 0; i < 7; i++) {
      await tester.tap(version);
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pumpAndSettle();
    expect(find.text('İnceleme erişimi'), findsOneWidget);
    expect(find.text('İptal'), findsOneWidget);

    await tester.tap(find.text('İptal'));
    await tester.pumpAndSettle();
    expect(find.text('İnceleme erişimi'), findsNothing);
    expect(tester.takeException(), isNull);
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
