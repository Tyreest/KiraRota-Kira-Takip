import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:integration_test/integration_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kira_artisi_hesapla/core/theme.dart';
import 'package:kira_artisi_hesapla/providers/app_providers.dart';
import 'package:kira_artisi_hesapla/services/reminder_service.dart';
import 'package:kira_artisi_hesapla/ui/home_shell.dart';
import 'package:kira_artisi_hesapla/ui/screens/calculate_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Finder _hesaplaButton() => find.ancestor(
      of: find.text('Hesapla'),
      matching: find.byType(FilledButton),
    );

Future<void> _waitFor(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 60; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) return;
  }
  fail('Bulunamadı: $finder');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  setUpAll(() async {
    await initializeDateFormatting('tr_TR');
  });

  testWidgets('canlı smoke: hesapla sonucu', (tester) async {
    SharedPreferences.setMockInitialValues({'onboarding_done': true});
    final prefs = await SharedPreferences.getInstance();

    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          reminderServiceProvider.overrideWithValue(
            ReminderService(prefs, enableNotifications: false),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: CalculateScreen(
              initialRenewal: DateTime(2026, 8, 7),
              initialContractStart: DateTime(2024, 8, 7),
              initialRentText: '25000',
            ),
          ),
        ),
      ),
    );

    await _waitFor(tester, find.text('Konut'));
    await tester.ensureVisible(_hesaplaButton());
    await tester.tap(_hesaplaButton());
    await tester.pumpAndSettle(const Duration(seconds: 3));

    expect(find.text('BU ORANA GÖRE HESAPLANAN KIRA'), findsOneWidget);
    expect(find.text('TÜFE esaslı azami artış oranı'), findsOneWidget);
    // Ağustos 2026 %31.90 → UI formatı tr_TR ile %31,9 olabilir
    expect(
      find.textContaining('31,9').evaluate().isNotEmpty ||
          find.textContaining('31.9').evaluate().isNotEmpty,
      isTrue,
    );
    expect(
      find.textContaining('32.975').evaluate().isNotEmpty ||
          find.textContaining('32975').evaluate().isNotEmpty,
      isTrue,
    );
  });

  testWidgets('canlı smoke: sekmeler + paywall + debug toggle yok', (tester) async {
    SharedPreferences.setMockInitialValues({'onboarding_done': true});
    final prefs = await SharedPreferences.getInstance();

    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          reminderServiceProvider.overrideWithValue(
            ReminderService(prefs, enableNotifications: false),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const HomeShell(),
        ),
      ),
    );

    await _waitFor(tester, find.text('Konut'));

    await tester.tap(find.text('Oranlar'));
    await tester.pumpAndSettle();
    expect(find.textContaining('2026').evaluate().isNotEmpty, isTrue);

    await tester.tap(find.text('Geçmiş'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ayarlar'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Geliştirme: Pro'), findsNothing);

    final proBtn = find.textContaining('Pro’ya Geç');
    expect(proBtn, findsWidgets);
    await tester.ensureVisible(proBtn.first);
    await tester.tap(proBtn.first);
    await tester.pumpAndSettle();
    expect(find.text('Şimdi Al'), findsOneWidget);
    expect(find.textContaining('Geliştirme: Pro'), findsNothing);
  });
}
