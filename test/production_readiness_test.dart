import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kira_artisi_hesapla/core/constants.dart';
import 'package:kira_artisi_hesapla/core/theme.dart';
import 'package:kira_artisi_hesapla/data/rental_repository.dart';
import 'package:kira_artisi_hesapla/domain/models/rental.dart';
import 'package:kira_artisi_hesapla/domain/models/tufe_rate.dart';
import 'package:kira_artisi_hesapla/providers/app_providers.dart';
import 'package:kira_artisi_hesapla/services/ads_service.dart';
import 'package:kira_artisi_hesapla/services/reminder_service.dart';
import 'package:kira_artisi_hesapla/ui/home_shell.dart';
import 'package:kira_artisi_hesapla/ui/screens/onboarding_screen.dart';
import 'package:kira_artisi_hesapla/ui/screens/reminder_screen.dart';
import 'package:kira_artisi_hesapla/ui/screens/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

LoadedRates _rates() => LoadedRates(
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  AdsService.skipSdk = true;

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await initializeDateFormatting('tr_TR');
  });

  tearDown(() {
    AdsService.skipSdk = true;
    AdsService.setAdsEnabled(true);
    AdsService.discardPreloadedInterstitial();
  });

  group('Backup / data', () {
    test(
      'Pro flag backup kanıtı değil — Prefs ayrı; Billing doğrular (doküman sözleşmesi)',
      () {
        // ProRepository anahtarı sabit; ownership IapService’te.
        expect(AppConstants.iapProductId, 'kira_pro_lifetime');
      },
    );

    test('kira serialization round-trip', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = RentalRepository(prefs);
      final now = DateTime(2026, 8, 1);
      await repo.add(
        Rental(
          id: '1',
          role: RentalRole.tenant,
          displayName: 'Evim',
          currentRent: 10000,
          contractStartDate: DateTime(2024, 1, 1),
          increaseDate: DateTime(2026, 8, 1),
          createdAt: now,
          updatedAt: now,
        ),
        isPro: true,
      );
      final loaded = RentalRepository(prefs).loadAll();
      expect(loaded, hasLength(1));
      expect(loaded.first.currentRent, 10000);
      expect(loaded.first.displayName, 'Evim');
    });

    test(
      'reminder prefs restore → legacy temizlenir (notifications kapalı)',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final cfg = ReminderConfig(
          renewalDate: DateTime(2027, 3, 15),
          notify30: true,
          notify7: false,
          notify0: true,
        );
        await cfg.save(prefs);
        final svc = ReminderService(prefs, enableNotifications: false);
        await svc.init();
        await svc.rescheduleSavedIfPossible();
        expect(ReminderConfig.load(prefs), isNull);
      },
    );
  });

  group('AdMob debug/release ID yönlendirme', () {
    test('debug test ortamında Google test unit ID kullanılır', () {
      // flutter test → kDebugMode true
      expect(AdMobIds.useTestIds, isTrue);
      expect(AdMobIds.adsConfigured, isTrue);
      expect(AdMobIds.bannerUnitId, AppConstants.admobTestBannerUnitId);
      expect(
        AdMobIds.interstitialUnitId,
        AppConstants.admobTestInterstitialUnitId,
      );
      expect(AdMobIds.bannerUnitId, contains('3940256099942544'));
      expect(AdMobIds.interstitialUnitId, contains('3940256099942544'));
    });

    test('Pro/features kapalıysa interstitial gate false', () {
      expect(
        AdsService.shouldShowInterstitialFor(
          successCountAfterIncrement: 3,
          now: DateTime(2026, 8, 7),
          isPro: true,
        ),
        isFalse,
      );
    });

    test(
      'show callback sonrası gecikmeli dismiss → timeout/failure yok',
      () async {
        final gate = AdsService.createPresentationGate(
          loadShowTimeout: const Duration(milliseconds: 80),
        );
        gate.armTimeout();

        // Reklam gösterildi (kullanıcı hâlâ izliyor).
        gate.markShowed();
        expect(gate.didShow, isTrue);
        expect(await gate.result, isTrue);

        // Timeout süresi + ekstra bekleme; dismiss gecikse bile success bozulmaz.
        await Future<void>.delayed(const Duration(milliseconds: 150));
        gate.markDismissedWithoutShow(); // no-op after showed
        expect(gate.didShow, isTrue);
        expect(await gate.result, isTrue);
        expect(gate.isCompleted, isTrue);
      },
    );

    test('show sonrası failedToShow ikinci sonuç üretmez', () async {
      final gate = AdsService.createPresentationGate(
        loadShowTimeout: const Duration(seconds: 1),
      );
      gate.armTimeout();
      gate.markShowed();
      gate.markFailedToShow();
      expect(await gate.result, isTrue);
    });

    test('show olmadan timeout → failure', () async {
      final gate = AdsService.createPresentationGate(
        loadShowTimeout: const Duration(milliseconds: 40),
      );
      gate.armTimeout();
      expect(await gate.result, isFalse);
      expect(gate.didShow, isFalse);
    });
  });

  group('Interstitial gate (saf mantık)', () {
    final now = DateTime(2026, 8, 7, 12);

    test('1. ve 2. başarılı hesap → yok', () {
      expect(
        AdsService.shouldShowInterstitialFor(
          successCountAfterIncrement: 1,
          now: now,
          isPro: false,
        ),
        isFalse,
      );
      expect(
        AdsService.shouldShowInterstitialFor(
          successCountAfterIncrement: 2,
          now: now,
          isPro: false,
        ),
        isFalse,
      );
    });

    test('3. başarılı + cooldown yok → var', () {
      expect(
        AdsService.shouldShowInterstitialFor(
          successCountAfterIncrement: 3,
          now: now,
          isPro: false,
        ),
        isTrue,
      );
    });

    test('3. ama cooldown dolmamış → yok', () {
      expect(
        AdsService.shouldShowInterstitialFor(
          successCountAfterIncrement: 3,
          now: now,
          lastShown: now.subtract(const Duration(minutes: 5)),
          isPro: false,
        ),
        isFalse,
      );
    });

    test('6. + cooldown dolmuş → var', () {
      expect(
        AdsService.shouldShowInterstitialFor(
          successCountAfterIncrement: 6,
          now: now,
          lastShown: now.subtract(const Duration(minutes: 11)),
          isPro: false,
        ),
        isTrue,
      );
    });

    test('Pro → asla yok', () {
      expect(
        AdsService.shouldShowInterstitialFor(
          successCountAfterIncrement: 3,
          now: now,
          isPro: true,
        ),
        isFalse,
      );
    });

    test('free success count artar; Pro artmaz', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await AdsService.onSuccessfulCalculation(
        prefs: prefs,
        isPro: false,
        onContinue: () {},
      );
      expect(AdsService.successCalcCount(prefs), 1);

      SharedPreferences.setMockInitialValues({});
      final prefs2 = await SharedPreferences.getInstance();
      await AdsService.onSuccessfulCalculation(
        prefs: prefs2,
        isPro: true,
        onContinue: () {},
      );
      expect(AdsService.successCalcCount(prefs2), 0);
    });
  });

  group('Notification UX widgets', () {
    testWidgets('startup HomeShell notification dialog yok', (tester) async {
      SharedPreferences.setMockInitialValues({'onboarding_done': true});
      final prefs = await SharedPreferences.getInstance();
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            ratesProvider.overrideWith((ref) async => _rates()),
            reminderServiceProvider.overrideWithValue(
              ReminderService(prefs, enableNotifications: false),
            ),
          ],
          child: MaterialApp(theme: AppTheme.light(), home: const HomeShell()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Bildirim izni gerekli'), findsNothing);
      expect(find.text('Ana'), findsOneWidget);
      expect(find.text('Kiranı takip etmeye başla'), findsOneWidget);
    });

    testWidgets('saved reminder yoksa Kaldır yok; varsa var', (tester) async {
      SharedPreferences.setMockInitialValues({
        'onboarding_done': true,
        'is_pro_lifetime': true,
      });
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime(2026, 1, 1);
      await RentalRepository(prefs).add(
        Rental(
          id: 'r1',
          role: RentalRole.tenant,
          displayName: 'Evim',
          currentRent: 25000,
          contractStartDate: DateTime(2024, 1, 1),
          increaseDate: DateTime(2027, 1, 15),
          createdAt: now,
          updatedAt: now,
        ),
        isPro: true,
      );
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);

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
            home: const ReminderScreen(rentalId: 'r1'),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Hatırlatmaları Kaydet'), findsOneWidget);
      expect(find.text('Hatırlatmaları Kaldır'), findsNothing);

      final existing = RentalRepository(prefs).findById('r1')!;
      await RentalRepository(prefs).update(
        existing.copyWith(reminder: const RentalReminderPrefs(enabled: true)),
      );

      await tester.pumpWidget(
        ProviderScope(
          key: const ValueKey('with-saved'),
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            reminderServiceProvider.overrideWithValue(
              ReminderService(prefs, enableNotifications: false),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const ReminderScreen(rentalId: 'r1'),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Hatırlatmaları Kaldır'), findsOneWidget);
    });

    testWidgets('onboarding AdBanner yok', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: OnboardingScreen(onDone: () {}),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(AdBanner), findsNothing);
    });

    testWidgets('ayarlar sekmesinde AdBanner yok', (tester) async {
      SharedPreferences.setMockInitialValues({'onboarding_done': true});
      final prefs = await SharedPreferences.getInstance();
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            ratesProvider.overrideWith((ref) async => _rates()),
            reminderServiceProvider.overrideWithValue(
              ReminderService(prefs, enableNotifications: false),
            ),
          ],
          child: MaterialApp(theme: AppTheme.light(), home: const HomeShell()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(find.text('Ayarlar'));
      await tester.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(find.byType(AdBanner), findsNothing);
    });

    testWidgets('Pro → AdBanner yok', (tester) async {
      SharedPreferences.setMockInitialValues({
        'onboarding_done': true,
        'is_pro_lifetime': true,
      });
      final prefs = await SharedPreferences.getInstance();
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            ratesProvider.overrideWith((ref) async => _rates()),
            reminderServiceProvider.overrideWithValue(
              ReminderService(prefs, enableNotifications: false),
            ),
          ],
          child: MaterialApp(theme: AppTheme.light(), home: const HomeShell()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byType(AdBanner), findsNothing);
    });
  });

  group('AdMob config guards', () {
    test('debug test IDs Google resmi', () {
      expect(AppConstants.admobTestBannerUnitId, contains('3940256099942544'));
      expect(
        AppConstants.admobTestInterstitialUnitId,
        contains('3940256099942544'),
      );
    });

    test('production boşken sahte ID yok; test leak guard', () {
      expect(AppConstants.admobProductionBannerUnitId, isEmpty);
      expect(AppConstants.admobProductionInterstitialUnitId, isEmpty);
      expect(AdMobIds.releaseUsesTestIdsLeak, isFalse);
    });
  });
}
