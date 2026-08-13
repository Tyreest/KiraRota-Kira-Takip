import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ads_service.dart';

/// UMP / Google Mobile Ads consent köprüsü — testlerde sahte implementasyon.
abstract class UmpConsentBridge {
  Future<void> requestConsentInfoUpdate(ConsentRequestParameters params);

  Future<FormError?> loadAndShowConsentFormIfRequired();

  Future<bool> canRequestAds();

  Future<PrivacyOptionsRequirementStatus> getPrivacyOptionsRequirementStatus();

  Future<FormError?> showPrivacyOptionsForm();
}

/// Gerçek [ConsentInformation] / [ConsentForm] çağrıları.
class RealUmpConsentBridge implements UmpConsentBridge {
  @override
  Future<void> requestConsentInfoUpdate(ConsentRequestParameters params) {
    final completer = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      params,
      () {
        if (!completer.isCompleted) completer.complete();
      },
      (FormError error) {
        if (!completer.isCompleted) {
          completer.completeError(error);
        }
      },
    );
    return completer.future;
  }

  @override
  Future<FormError?> loadAndShowConsentFormIfRequired() async {
    FormError? error;
    await ConsentForm.loadAndShowConsentFormIfRequired((e) {
      error = e;
    });
    return error;
  }

  @override
  Future<bool> canRequestAds() => ConsentInformation.instance.canRequestAds();

  @override
  Future<PrivacyOptionsRequirementStatus>
  getPrivacyOptionsRequirementStatus() =>
      ConsentInformation.instance.getPrivacyOptionsRequirementStatus();

  @override
  Future<FormError?> showPrivacyOptionsForm() async {
    FormError? error;
    await ConsentForm.showPrivacyOptionsForm((e) {
      error = e;
    });
    return error;
  }
}

/// Debug-only UMP test ayarları. Release'te her zaman null.
///
/// Örnek (yalnız debug run):
/// `--dart-define=UMP_DEBUG_GEOGRAPHY=eea`
/// `--dart-define=UMP_DEBUG_TEST_DEVICE_IDS=HASH1,HASH2`
class UmpDebugConfig {
  UmpDebugConfig._();

  /// [isDebugMode] false ise env ne olursa olsun null (release sızıntısı yok).
  static ConsentDebugSettings? build({
    required bool isDebugMode,
    String geographyEnv = const String.fromEnvironment(
      'UMP_DEBUG_GEOGRAPHY',
      defaultValue: '',
    ),
    String testDeviceIdsEnv = const String.fromEnvironment(
      'UMP_DEBUG_TEST_DEVICE_IDS',
      defaultValue: '',
    ),
  }) {
    if (!isDebugMode) return null;

    DebugGeography? geography;
    switch (geographyEnv.trim().toLowerCase()) {
      case 'eea':
        geography = DebugGeography.debugGeographyEea;
      case 'other':
        geography = DebugGeography.debugGeographyOther;
      case 'disabled':
        geography = DebugGeography.debugGeographyDisabled;
      case 'us':
      case 'regulated_us':
        geography = DebugGeography.debugGeographyRegulatedUsState;
      case '':
      default:
        geography = null;
    }

    final devices = testDeviceIdsEnv
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    if (geography == null && devices.isEmpty) return null;

    return ConsentDebugSettings(
      debugGeography: geography,
      testIdentifiers: devices.isEmpty ? null : devices,
    );
  }

  /// Release binary'de forced geography/test config uygulanmaz.
  static bool wouldApplyInRelease({
    String geographyEnv = 'eea',
    String testDeviceIdsEnv = 'TEST_DEVICE',
  }) {
    return build(
          isDebugMode: false,
          geographyEnv: geographyEnv,
          testDeviceIdsEnv: testDeviceIdsEnv,
        ) !=
        null;
  }
}

class UmpConsentResult {
  const UmpConsentResult({
    required this.canRequestAds,
    required this.privacyOptionsRequired,
    required this.adsInitAttempted,
  });

  final bool canRequestAds;
  final bool privacyOptionsRequired;
  final bool adsInitAttempted;
}

/// Consent toplama + (izin varsa) tek seferlik ads init.
class UmpConsentCoordinator {
  UmpConsentCoordinator({
    required this.bridge,
    required this.initializeAds,
    this.isDebugMode = kDebugMode,
    this.debugSettingsBuilder = UmpDebugConfig.build,
  });

  final UmpConsentBridge bridge;
  final Future<void> Function() initializeAds;
  final bool isDebugMode;
  final ConsentDebugSettings? Function({
    required bool isDebugMode,
    String geographyEnv,
    String testDeviceIdsEnv,
  })
  debugSettingsBuilder;

  Future<UmpConsentResult>? _inFlight;

  /// Aynı launch'ta ikinci çağrı ilk Future'ı paylaşır (çift init yok).
  Future<UmpConsentResult> gatherConsentThenInitAds() {
    return _inFlight ??= _run();
  }

  Future<UmpConsentResult> _run() async {
    var canRequest = false;
    var privacyRequired = false;

    final debugSettings = debugSettingsBuilder(isDebugMode: isDebugMode);
    final params = ConsentRequestParameters(
      tagForUnderAgeOfConsent: false,
      consentDebugSettings: debugSettings,
    );

    try {
      await bridge.requestConsentInfoUpdate(params);
      await bridge.loadAndShowConsentFormIfRequired();
    } catch (e, st) {
      // Consent update hatası uygulamayı bloke etmez; önceki oturum
      // consent'i canRequestAds ile kontrol edilir.
      if (kDebugMode) {
        debugPrint('[UMP] consent update/form error: $e\n$st');
      }
    }

    try {
      canRequest = await bridge.canRequestAds();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[UMP] canRequestAds error: $e');
      }
      canRequest = false;
    }

    try {
      final status = await bridge.getPrivacyOptionsRequirementStatus();
      privacyRequired = status == PrivacyOptionsRequirementStatus.required;
    } catch (_) {
      privacyRequired = false;
    }

    AdsService.applyConsentCanRequestAds(canRequest);
    AdsService.setPrivacyOptionsRequired(privacyRequired);

    var initAttempted = false;
    if (canRequest) {
      initAttempted = true;
      await initializeAds();
    }

    return UmpConsentResult(
      canRequestAds: canRequest,
      privacyOptionsRequired: privacyRequired,
      adsInitAttempted: initAttempted,
    );
  }

  @visibleForTesting
  void resetInFlightForTest() {
    _inFlight = null;
  }
}

/// Uygulama genelinde tek coordinator.
class UmpConsentService {
  UmpConsentService._();

  static UmpConsentBridge bridge = RealUmpConsentBridge();

  static UmpConsentCoordinator? _coordinator;

  static UmpConsentCoordinator get coordinator {
    return _coordinator ??= UmpConsentCoordinator(
      bridge: bridge,
      initializeAds: AdsService.init,
    );
  }

  /// Her app launch: consent → gerekirse form → canRequestAds ise ads init.
  static Future<UmpConsentResult> gatherConsentThenInitAds() {
    return coordinator.gatherConsentThenInitAds();
  }

  static Future<FormError?> showPrivacyOptionsForm() =>
      bridge.showPrivacyOptionsForm();

  @visibleForTesting
  static void resetForTest({UmpConsentBridge? testBridge}) {
    bridge = testBridge ?? RealUmpConsentBridge();
    _coordinator = null;
  }
}
