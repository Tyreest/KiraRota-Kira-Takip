import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kira_artisi_hesapla/providers/app_providers.dart';
import 'package:kira_artisi_hesapla/services/ads_service.dart';
import 'package:kira_artisi_hesapla/services/ump_consent_service.dart';
import 'package:kira_artisi_hesapla/ui/screens/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeUmpBridge implements UmpConsentBridge {
  _FakeUmpBridge({
    this.canRequest = false,
    this.privacyStatus = PrivacyOptionsRequirementStatus.notRequired,
    this.updateError,
    this.formRequired = false,
  });

  bool canRequest;
  PrivacyOptionsRequirementStatus privacyStatus;
  FormError? updateError;
  bool formRequired;
  int requestUpdateCount = 0;
  int loadFormCount = 0;
  int canRequestAdsCount = 0;
  int privacyStatusCount = 0;
  int showPrivacyFormCount = 0;
  ConsentRequestParameters? lastParams;

  @override
  Future<void> requestConsentInfoUpdate(ConsentRequestParameters params) async {
    requestUpdateCount++;
    lastParams = params;
    if (updateError != null) {
      throw updateError!;
    }
  }

  @override
  Future<FormError?> loadAndShowConsentFormIfRequired() async {
    loadFormCount++;
    return null;
  }

  @override
  Future<bool> canRequestAds() async {
    canRequestAdsCount++;
    return canRequest;
  }

  @override
  Future<PrivacyOptionsRequirementStatus>
  getPrivacyOptionsRequirementStatus() async {
    privacyStatusCount++;
    return privacyStatus;
  }

  @override
  Future<FormError?> showPrivacyOptionsForm() async {
    showPrivacyFormCount++;
    return null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await initializeDateFormatting('tr_TR');
  });

  setUp(() {
    AdsService.skipSdk = false;
    AdsService.setAdsEnabled(true);
    AdsService.resetConsentAndInitStateForTest();
    UmpConsentService.resetForTest();
  });

  tearDown(() {
    AdsService.skipSdk = true;
    AdsService.setAdsEnabled(true);
    AdsService.resetConsentAndInitStateForTest();
    UmpConsentService.resetForTest();
  });

  group('UmpDebugConfig release sızıntısı', () {
    test(
      'release (isDebugMode=false) forced geography/test device uygulanmaz',
      () {
        expect(
          UmpDebugConfig.wouldApplyInRelease(
            geographyEnv: 'eea',
            testDeviceIdsEnv: 'ABCDEF',
          ),
          isFalse,
        );
        expect(
          UmpDebugConfig.build(
            isDebugMode: false,
            geographyEnv: 'eea',
            testDeviceIdsEnv: 'ABCDEF',
          ),
          isNull,
        );
      },
    );

    test('debug + UMP_DEBUG_GEOGRAPHY=eea → DebugGeography.eea', () {
      final s = UmpDebugConfig.build(
        isDebugMode: true,
        geographyEnv: 'eea',
        testDeviceIdsEnv: 'DEV1',
      );
      expect(s, isNotNull);
      expect(s!.debugGeography, DebugGeography.debugGeographyEea);
      expect(s.testIdentifiers, ['DEV1']);
    });

    test('debug + boş env → null (production consent reset yok)', () {
      expect(
        UmpDebugConfig.build(
          isDebugMode: true,
          geographyEnv: '',
          testDeviceIdsEnv: '',
        ),
        isNull,
      );
    });
  });

  group('UMP consent → ads gate', () {
    test('consent alınmadan ad request / init başlamaz', () async {
      final bridge = _FakeUmpBridge(canRequest: false);
      var initCalls = 0;
      final coord = UmpConsentCoordinator(
        bridge: bridge,
        isDebugMode: false,
        initializeAds: () async {
          initCalls++;
          AdsService.applyConsentCanRequestAds(true);
          await AdsService.init();
        },
      );

      // Consent öncesi doğrudan init denemesi
      await AdsService.init();
      expect(AdsService.isSdkInitialized, isFalse);
      expect(AdsService.initInvocationCount, 0);
      expect(AdsService.consentAllowsAds, isFalse);
      expect(AdsService.mayRequestAds, isFalse);

      final result = await coord.gatherConsentThenInitAds();
      expect(result.canRequestAds, isFalse);
      expect(result.adsInitAttempted, isFalse);
      expect(initCalls, 0);
      expect(AdsService.isSdkInitialized, isFalse);
    });

    test('canRequestAds=true sonrası ads init yalnız bir kez başlar', () async {
      final bridge = _FakeUmpBridge(canRequest: true);
      var initCalls = 0;
      final coord = UmpConsentCoordinator(
        bridge: bridge,
        isDebugMode: false,
        initializeAds: () async {
          initCalls++;
          await AdsService.init();
        },
      );

      AdsService.skipSdk = true; // gerçek MobileAds çağırma
      final r1 = await coord.gatherConsentThenInitAds();
      final r2 = await coord.gatherConsentThenInitAds();

      expect(r1.canRequestAds, isTrue);
      expect(r1.adsInitAttempted, isTrue);
      expect(identical(r1, r2) || r2.adsInitAttempted, isTrue);
      expect(initCalls, 1);
      expect(bridge.requestUpdateCount, 1);
      expect(AdsService.initInvocationCount, 1);
    });

    test('consent form gerekmediğinde normal devam eder', () async {
      final bridge = _FakeUmpBridge(
        canRequest: true,
        formRequired: false,
        privacyStatus: PrivacyOptionsRequirementStatus.notRequired,
      );
      final coord = UmpConsentCoordinator(
        bridge: bridge,
        isDebugMode: false,
        initializeAds: () async {
          AdsService.skipSdk = true;
          await AdsService.init();
        },
      );

      final result = await coord.gatherConsentThenInitAds();
      expect(bridge.loadFormCount, 1);
      expect(result.canRequestAds, isTrue);
      expect(result.privacyOptionsRequired, isFalse);
      expect(result.adsInitAttempted, isTrue);
      expect(AdsService.consentAllowsAds, isTrue);
    });

    test(
      'consent error + önceki geçerli consent varsa reklam akışı devam edebilir',
      () async {
        final bridge = _FakeUmpBridge(
          canRequest: true,
          updateError: FormError(errorCode: 1, message: 'network'),
        );
        final coord = UmpConsentCoordinator(
          bridge: bridge,
          isDebugMode: false,
          initializeAds: () async {
            AdsService.skipSdk = true;
            await AdsService.init();
          },
        );

        final result = await coord.gatherConsentThenInitAds();
        expect(result.canRequestAds, isTrue);
        expect(result.adsInitAttempted, isTrue);
        expect(AdsService.consentAllowsAds, isTrue);
        // Form hata sonrası yine de canRequestAds okunur
        expect(bridge.canRequestAdsCount, 1);
      },
    );

    test('Pro/Review Access hâlâ reklam göstermez', () async {
      final bridge = _FakeUmpBridge(canRequest: true);
      final coord = UmpConsentCoordinator(
        bridge: bridge,
        isDebugMode: false,
        initializeAds: () async {
          AdsService.skipSdk = true;
          await AdsService.init();
        },
      );
      await coord.gatherConsentThenInitAds();

      AdsService.setAdsEnabled(false); // Pro / Review Access
      expect(AdsService.consentAllowsAds, isTrue);
      expect(AdsService.adsEnabled, isFalse);
      expect(AdsService.mayRequestAds, isFalse);
      expect(
        AdsService.shouldShowInterstitialFor(
          successCountAfterIncrement: 3,
          now: DateTime(2026, 8, 8),
          isPro: true,
          adsEnabled: AdsService.adsEnabled,
        ),
        isFalse,
      );
    });
  });

  group('Ayarlar Gizlilik seçenekleri', () {
    Future<void> pumpSettings(
      WidgetTester tester, {
      required bool privacyRequired,
    }) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            privacyOptionsRequiredProvider.overrideWith(
              (ref) => privacyRequired,
            ),
          ],
          child: MaterialApp(home: Scaffold(body: const SettingsScreen())),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('privacy options required → aksiyon görünür', (tester) async {
      await pumpSettings(tester, privacyRequired: true);
      expect(find.text('Gizlilik seçenekleri'), findsOneWidget);
    });

    testWidgets('privacy options required değil → aksiyon yok', (tester) async {
      await pumpSettings(tester, privacyRequired: false);
      expect(find.text('Gizlilik seçenekleri'), findsNothing);
    });
  });
}
