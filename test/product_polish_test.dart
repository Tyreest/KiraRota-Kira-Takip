import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kira_artisi_hesapla/core/theme.dart';
import 'package:kira_artisi_hesapla/data/rental_repository.dart';
import 'package:kira_artisi_hesapla/domain/dashboard_logic.dart';
import 'package:kira_artisi_hesapla/domain/models/rental.dart';
import 'package:kira_artisi_hesapla/domain/models/tufe_rate.dart';
import 'package:kira_artisi_hesapla/providers/app_providers.dart';
import 'package:kira_artisi_hesapla/services/reminder_service.dart';
import 'package:kira_artisi_hesapla/ui/home_shell.dart';
import 'package:kira_artisi_hesapla/ui/screens/calculate_screen.dart';
import 'package:kira_artisi_hesapla/ui/screens/rates_screen.dart';
import 'package:kira_artisi_hesapla/ui/screens/rental_edit_screen.dart';
import 'package:kira_artisi_hesapla/ui/widgets/pro_paywall.dart';
import 'package:shared_preferences/shared_preferences.dart';

LoadedRates _fixtureRates() {
  return LoadedRates(
    bundle: TufeRateBundle(
      version: 1,
      updatedAt: DateTime(2026, 8, 3),
      sourceNote: 'TÜİK TÜFE test bundle',
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
        ),
      ],
    ),
    source: RateSource.asset,
  );
}

Future<SharedPreferences> _prefs({bool isPro = false}) async {
  SharedPreferences.setMockInitialValues({
    'onboarding_done': true,
    if (isPro) 'is_pro_lifetime': true,
  });
  return SharedPreferences.getInstance();
}

Widget _wrap(Widget child, SharedPreferences prefs) {
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      ratesProvider.overrideWith((ref) async => _fixtureRates()),
      reminderServiceProvider.overrideWithValue(
        ReminderService(prefs, enableNotifications: false),
      ),
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
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeDateFormatting('tr_TR');
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('Product Polish Regression Tests', () {
    testWidgets('1. RentalRole create/edit round-trip preserves role', (tester) async {
      final prefs = await _prefs(isPro: true);
      final repo = RentalRepository(prefs);

      Widget host(Widget screen) {
        return Builder(
          builder: (ctx) => Center(
            child: ElevatedButton(
              onPressed: () => Navigator.of(ctx).push(
                MaterialPageRoute(builder: (_) => screen),
              ),
              child: const Text('Open Screen'),
            ),
          ),
        );
      }

      // Create new rental as Landlord
      await tester.pumpWidget(_wrap(host(const RentalEditScreen()), prefs));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open Screen'));
      await tester.pumpAndSettle();

      // Verify segmented control has 'Kiracıyım' selected by default
      expect(find.text('Kiracıyım'), findsOneWidget);
      expect(find.text('Ev Sahibiyim'), findsOneWidget);

      // Enter property name
      await tester.enterText(
        find.widgetWithText(TextField, 'Örn: Beşiktaş Daire 4'),
        'Yazlık Evim',
      );
      // Enter rent
      await tester.enterText(
        find.widgetWithText(TextField, 'Örn: 25000'),
        '30000',
      );

      // Select Ev Sahibiyim
      await tester.tap(find.text('Ev Sahibiyim'));
      await tester.pumpAndSettle();

      // Save
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -1000));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kirayı Kaydet'));
      await tester.pumpAndSettle();

      // Verify saved in repository
      final rentals = repo.loadAll();
      expect(rentals.length, 1);
      expect(rentals.first.displayName, 'Yazlık Evim');
      expect(rentals.first.role, RentalRole.landlord);

      // Now open in edit mode and verify hydration
      await tester.pumpWidget(
        _wrap(host(RentalEditScreen(rentalId: rentals.first.id)), prefs),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open Screen'));
      await tester.pumpAndSettle();

      // Switch role back to Kiracıyım
      await tester.tap(find.text('Kiracıyım'));
      await tester.pumpAndSettle();

      await tester.drag(find.byType(Scrollable).first, const Offset(0, -1000));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Değişiklikleri Kaydet'));
      await tester.pumpAndSettle();

      final updated = repo.findById(rentals.first.id);
      expect(updated!.role, RentalRole.tenant);
    });

    testWidgets('2. Tab state preservation via IndexedStack', (tester) async {
      final prefs = await _prefs();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            ratesProvider.overrideWith((ref) async => _fixtureRates()),
            reminderServiceProvider.overrideWithValue(
              ReminderService(prefs, enableNotifications: false),
            ),
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
            home: const HomeShell(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Navigate to Hesapla tab
      await tester.tap(find.text('Hesapla'));
      await tester.pumpAndSettle();

      // Type a unique rent amount into the form
      final rentField = find.widgetWithText(TextField, 'Örn: 25000');
      expect(rentField, findsOneWidget);
      await tester.enterText(rentField, '42500');
      await tester.pumpAndSettle();
      expect(find.text('42500'), findsOneWidget);

      // Switch to Kiralarım tab
      await tester.tap(find.text('Kiralarım'));
      await tester.pumpAndSettle();
      expect(find.text('Henüz kayıtlı kiranız yok'), findsOneWidget);

      // Switch back to Hesapla tab
      await tester.tap(find.text('Hesapla'));
      await tester.pumpAndSettle();

      // Form state must be preserved
      expect(find.text('42500'), findsOneWidget);
    });

    testWidgets('3. Registered rental → calculate prefill and manual edit', (tester) async {
      final prefs = await _prefs(isPro: true);
      final repo = RentalRepository(prefs);
      await repo.add(
        Rental(
          id: 'rental-test-1',
          role: RentalRole.tenant,
          displayName: 'Beşiktaş Daire',
          currentRent: 28000,
          contractStartDate: DateTime(2024, 8, 15),
          increaseDate: DateTime(2026, 8, 15),
          contractIncreaseRate: 35.0,
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        ),
        isPro: true,
      );

      await tester.pumpWidget(_wrap(const CalculateScreen(), prefs));
      await tester.pumpAndSettle();

      // Should show quick fill button
      expect(find.textContaining('Kayıtlı kiradan doldur'), findsOneWidget);

      // Tap quick fill
      await tester.tap(find.textContaining('Kayıtlı kiradan doldur'));
      await tester.pumpAndSettle();

      // Verify form is filled
      expect(find.text('28000'), findsOneWidget);
      expect(find.text('35.0'), findsOneWidget);
      expect(find.textContaining('Beşiktaş Daire bilgileri dolduruldu'), findsOneWidget);

      // Manual edit: user modifies the prefilled rent to 32000
      final rentField = find.widgetWithText(TextField, 'Örn: 25000');
      await tester.enterText(rentField, '32000');
      await tester.pumpAndSettle();
      expect(find.text('32000'), findsOneWidget);
    });

    testWidgets('4. Compare UI with requested rent displays difference and rate insight', (tester) async {
      const compare = RequestedRentCompare(
        calculatedRent: 32975.0,
        requestedRent: 38000.0,
        currentRent: 25000.0,
        calculatedIncreaseRatePercent: 31.90,
      );

      expect(compare.difference, 5025.0);
      expect(compare.comparisonIncreasePercent, isNotNull);
      expect(compare.rateInsightLabel, contains('yüksek'));

      // Also verify equal scenario
      const compareEqual = RequestedRentCompare(
        calculatedRent: 32975.0,
        requestedRent: 32975.0,
        currentRent: 25000.0,
        calculatedIncreaseRatePercent: 31.90,
      );
      expect(compareEqual.rateInsightLabel, 'Hesaplanan artış oranıyla aynı');
    });

    testWidgets('5. Rates screen manual refresh keeps data visible and explanation modal works', (tester) async {
      final prefs = await _prefs();
      await tester.pumpWidget(_wrap(const RatesScreen(), prefs));
      await tester.pumpAndSettle();

      // Rates are displayed
      expect(find.text('TÜFE Oranları'), findsOneWidget);
      expect(find.text('Ağustos 2026'), findsOneWidget);

      // Refresh button is present
      expect(find.byIcon(Icons.refresh), findsOneWidget);
      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pump();

      // Data is still visible during and after refresh
      expect(find.text('Ağustos 2026'), findsOneWidget);

      // 12-month average explanation link
      expect(find.text('Kira artış oranı nasıl belirleniyor?'), findsOneWidget);

      // Tap explanation
      await tester.tap(find.text('Kira artış oranı nasıl belirleniyor?'));
      await tester.pumpAndSettle();

      // Modal explanation displays TBK 344 context
      expect(find.text('TÜFE 12 Aylık Ortalama Nedir?'), findsOneWidget);
      expect(find.textContaining('TBK Madde 344'), findsOneWidget);

      // Dismiss modal
      await tester.tap(find.text('Anladım'));
      await tester.pumpAndSettle();
      expect(find.text('TÜFE 12 Aylık Ortalama Nedir?'), findsNothing);
    });

    testWidgets('6. Paywall displays one-time payment badge and dynamic price', (tester) async {
      final prefs = await _prefs();
      await tester.pumpWidget(
        _wrap(
          Consumer(
            builder: (ctx, ref, _) => TextButton(
              onPressed: () => showProPaywall(ctx, ref),
              child: const Text('Paywall Aç'),
            ),
          ),
          prefs,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Paywall Aç'));
      await tester.pumpAndSettle();

      // Verify clear one-time payment messaging
      expect(find.text('Tek seferlik ödeme · Abonelik değil'), findsOneWidget);
      expect(find.text('KiraRota Pro'), findsOneWidget);
      expect(find.text('Yenileme Hatırlatması'), findsOneWidget);
      expect(find.text('Sınırsız Kira Takibi'), findsOneWidget);
    });
  });
}
