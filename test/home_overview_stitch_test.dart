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
import 'package:kira_artisi_hesapla/ui/screens/home_dashboard_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

LoadedRates _fixtureRates() {
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

Future<SharedPreferences> _prefsWithRentals(List<Rental> rentals) async {
  SharedPreferences.setMockInitialValues({'onboarding_done': true});
  final prefs = await SharedPreferences.getInstance();
  final repo = RentalRepository(prefs);
  for (final r in rentals) {
    await repo.add(r, isPro: true);
  }
  return prefs;
}

Rental _farRental() {
  return Rental(
    id: 'ev1',
    role: RentalRole.tenant,
    displayName: 'Ev',
    currentRent: 39000,
    contractStartDate: DateTime(2024, 7, 1),
    increaseDate: DateTime(2027, 7, 1),
    lastRenewalDate: DateTime(2026, 7, 1),
    renewalResolved: true,
    createdAt: DateTime(2026, 8, 14),
    updatedAt: DateTime(2026, 8, 14),
  );
}

Widget _app(SharedPreferences prefs) {
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      ratesProvider.overrideWith((ref) async => _fixtureRates()),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      locale: const Locale('tr', 'TR'),
      supportedLocales: const [Locale('tr', 'TR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const Scaffold(body: HomeDashboardScreen()),
    ),
  );
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    GoogleFonts.config.allowRuntimeFetching = false;
    await initializeDateFormatting('tr_TR');
  });

  testWidgets('populated Özet: hero + metrics + actions', (tester) async {
    final prefs = await _prefsWithRentals([_farRental()]);
    await tester.pumpWidget(_app(prefs));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('dashboard_page_title')), findsOneWidget);
    expect(find.text('SIRADAKİ YENİLEME'), findsOneWidget);
    expect(find.text('Ev'), findsWidgets);
    expect(find.textContaining('gün kaldı'), findsOneWidget);
    expect(find.textContaining('Sonraki yenileme:'), findsOneWidget);
    expect(find.text('Mevcut kira'), findsOneWidget);
    expect(find.text('Yeni dönemi hesapla'), findsOneWidget);
    expect(find.text('Aktif Kiralar'), findsOneWidget);
    expect(find.text('Yaklaşan'), findsOneWidget);
    expect(find.text('Bu Ay'), findsOneWidget);
    expect(find.text('Son İşlemler'), findsOneWidget);
    await tester.drag(find.byType(ListView).first, const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(find.text('Manuel Hesaplama'), findsOneWidget);
    expect(find.text('Kira ekle'), findsOneWidget);
    expect(find.text('Yenileme geçti'), findsNothing);
  });

  testWidgets('empty Özet: CTA’lar korunur', (tester) async {
    final prefs = await _prefsWithRentals([]);
    await tester.pumpWidget(_app(prefs));
    await tester.pumpAndSettle();

    expect(find.text('Kiranı takip etmeye başla'), findsOneWidget);
    expect(find.text('Kira ekle'), findsOneWidget);
    expect(find.text('Manuel kira artışı hesapla'), findsOneWidget);
    expect(find.text('SIRADAKİ YENİLEME'), findsNothing);
  });

  testWidgets('textScale 1.3 overflow yok', (tester) async {
    final prefs = await _prefsWithRentals([_farRental()]);
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
        child: _app(prefs),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Yeni dönemi hesapla'), findsOneWidget);
  });
}
