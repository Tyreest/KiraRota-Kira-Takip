import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:kira_artisi_hesapla/core/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Debug = Google test IDs. Release = production (boşsa reklam isteği yok).
class AdMobIds {
  AdMobIds._();

  static bool get useTestIds => kDebugMode;

  static String get bannerUnitId {
    if (useTestIds) return AppConstants.admobTestBannerUnitId;
    return AppConstants.admobProductionBannerUnitId;
  }

  static String get interstitialUnitId {
    if (useTestIds) return AppConstants.admobTestInterstitialUnitId;
    return AppConstants.admobProductionInterstitialUnitId;
  }

  static bool get adsConfigured {
    if (useTestIds) return true;
    return AppConstants.admobProductionBannerUnitId.isNotEmpty &&
        AppConstants.admobProductionInterstitialUnitId.isNotEmpty;
  }

  /// Release AAB'de test ID sızmasın.
  static bool get releaseUsesTestIdsLeak {
    if (kDebugMode) return false;
    final banner = AppConstants.admobProductionBannerUnitId;
    final interstitial = AppConstants.admobProductionInterstitialUnitId;
    if (banner.isEmpty && interstitial.isEmpty) return false;
    return banner.contains('3940256099942544') ||
        interstitial.contains('3940256099942544') ||
        AppConstants.admobProductionAppId.contains('3940256099942544');
  }
}

class AdsService {
  AdsService._();

  static bool _initialized = false;
  static bool _adsEnabled = true;
  static bool _consentAllowsAds = false;
  static bool _privacyOptionsRequired = false;
  static int _initInvocationCount = 0;
  static InterstitialAd? _preloaded;
  static bool _loadingInterstitial = false;

  /// Stale async callback / show iptali için monoton sayaç.
  static int _requestGeneration = 0;

  /// Consent / Pro / adsEnabled değişince banner yeniden denesin.
  static final ValueNotifier<int> eligibilityEpoch = ValueNotifier<int>(0);

  /// Widget/unit testlerde gerçek AdMob SDK çağrısını atla.
  @visibleForTesting
  static bool skipSdk = false;

  static const _successCountKey = 'ads_success_calc_count';
  static const _lastInterstitialMsKey = 'ads_last_interstitial_ms';

  static void _bumpEligibility() {
    eligibilityEpoch.value++;
  }

  static void invalidatePendingAdRequests() {
    _requestGeneration++;
    discardPreloadedInterstitial();
  }

  /// UMP [canRequestAds] sonucu (veya skipSdk).
  static bool get consentAllowsAds => skipSdk || _consentAllowsAds;

  static bool get privacyOptionsRequired => _privacyOptionsRequired;

  /// Aynı launch'ta MobileAds.initialize kaç kez denendi (test).
  @visibleForTesting
  static int get initInvocationCount => _initInvocationCount;

  @visibleForTesting
  static bool get isSdkInitialized => _initialized;

  @visibleForTesting
  static int get requestGeneration => _requestGeneration;

  /// UMP coordinator sonucu.
  static void applyConsentCanRequestAds(bool value) {
    _consentAllowsAds = value;
    _log('consent canRequestAds=$value');
    _bumpEligibility();
  }

  static void setPrivacyOptionsRequired(bool value) {
    _privacyOptionsRequired = value;
  }

  @visibleForTesting
  static void resetConsentAndInitStateForTest() {
    _initialized = false;
    _consentAllowsAds = false;
    _privacyOptionsRequired = false;
    _initInvocationCount = 0;
    _loadingInterstitial = false;
    _adsEnabled = true;
    _requestGeneration++;
    discardPreloadedInterstitial();
    _bumpEligibility();
  }

  /// Yalnızca debug — release kullanıcıya log göstermez.
  static void _log(String message) {
    if (kDebugMode) {
      debugPrint('[Ads] $message');
    }
  }

  static String _tailId(String id) {
    if (id.isEmpty) return '(empty)';
    if (id.length <= 8) return id;
    return '…${id.substring(id.length - 8)}';
  }

  /// Banner / interstitial yüklemeden önce: consent + ads-off kapısı.
  static bool get mayRequestAds =>
      consentAllowsAds && _adsEnabled && AdMobIds.adsConfigured;

  static Future<void> init() async {
    if (_initialized) return;
    if (skipSdk) {
      _initInvocationCount++;
      _initialized = true;
      _consentAllowsAds = true;
      _log('init skipped (skipSdk / test)');
      return;
    }
    if (!_consentAllowsAds) {
      _log('init blocked: canRequestAds=false');
      // _initialized false kalsın — consent sonrası tekrar denenebilir.
      return;
    }
    _initInvocationCount++;
    if (!AdMobIds.adsConfigured) {
      _log('production IDs yok — reklam isteği yapılmayacak.');
      _initialized = true;
      return;
    }
    _log(
      'init MobileAds '
      'mode=${AdMobIds.useTestIds ? 'DEBUG_TEST_IDS' : 'RELEASE_PRODUCTION'} '
      'banner=${_tailId(AdMobIds.bannerUnitId)} '
      'interstitial=${_tailId(AdMobIds.interstitialUnitId)}',
    );
    await MobileAds.instance.initialize();
    _initialized = true;
    _log('MobileAds.initialize complete');
  }

  /// Pro / review-access → tüm reklamlar kapalı.
  static void setAdsEnabled(bool enabled) {
    if (_adsEnabled != enabled) {
      _log(enabled ? 'ads enabled' : 'ads disabled (Pro/features or off)');
    }
    _adsEnabled = enabled;
    if (!enabled) {
      invalidatePendingAdRequests();
    }
    _bumpEligibility();
  }

  static bool get adsEnabled => _adsEnabled && AdMobIds.adsConfigured;

  static void discardPreloadedInterstitial() {
    if (_preloaded != null) {
      _log('discard preloaded interstitial');
    }
    _preloaded?.dispose();
    _preloaded = null;
  }

  static int successCalcCount(SharedPreferences prefs) =>
      prefs.getInt(_successCountKey) ?? 0;

  static DateTime? lastInterstitialAt(SharedPreferences prefs) {
    final ms = prefs.getInt(_lastInterstitialMsKey);
    if (ms == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  /// Başarılı hesaplama sonrası: count++, gerekirse interstitial, sonra [onContinue].
  /// Reklam yüklenemezse sonucu engellemez.
  static Future<void> onSuccessfulCalculation({
    required SharedPreferences prefs,
    required bool isPro,
    required VoidCallback onContinue,
  }) async {
    if (isPro) {
      _log('interstitial skipped: Pro/hasProFeatures');
      setAdsEnabled(false);
      discardPreloadedInterstitial();
      onContinue();
      return;
    }

    if (!_adsEnabled) {
      _log('interstitial skipped: adsEnabled=false');
      onContinue();
      return;
    }

    final next = successCalcCount(prefs) + 1;
    await prefs.setInt(_successCountKey, next);
    _log('success calc count=$next');

    if (!_shouldShowInterstitial(prefs, countAfterIncrement: next)) {
      _log(
        'interstitial not shown: gate '
        '(every=${AppConstants.interstitialEveryNSuccess}, '
        'cooldown=${AppConstants.interstitialCooldown.inMinutes}m)',
      );
      onContinue();
      return;
    }

    _log('interstitial show attempt');
    final shown = await _showInterstitialNow(prefs);
    _log(
      shown ? 'interstitial shown' : 'interstitial not shown (load/show fail)',
    );
    onContinue();
  }

  static bool _shouldShowInterstitial(
    SharedPreferences prefs, {
    required int countAfterIncrement,
  }) {
    if (!adsEnabled) return false;
    if (countAfterIncrement % AppConstants.interstitialEveryNSuccess != 0) {
      return false;
    }
    final last = lastInterstitialAt(prefs);
    if (last != null) {
      final elapsed = DateTime.now().difference(last);
      if (elapsed < AppConstants.interstitialCooldown) return false;
    }
    return true;
  }

  /// Test edilebilir saf mantık (prefs yazmadan).
  static bool shouldShowInterstitialFor({
    required int successCountAfterIncrement,
    required DateTime now,
    DateTime? lastShown,
    required bool isPro,
    bool adsEnabled = true,
  }) {
    if (isPro || !adsEnabled) return false;
    if (successCountAfterIncrement % AppConstants.interstitialEveryNSuccess !=
        0) {
      return false;
    }
    if (lastShown != null &&
        now.difference(lastShown) < AppConstants.interstitialCooldown) {
      return false;
    }
    return true;
  }

  /// Interstitial load + show-başlangıcı kapısı.
  ///
  /// Kullanıcının reklamı izleme süresi bu timeout’a dahil değildir.
  /// [markShowed] çağrılınca başarı sabittir; sonraki dismiss timeout üretmez.
  @visibleForTesting
  static InterstitialPresentationGate createPresentationGate({
    Duration loadShowTimeout = const Duration(seconds: 8),
  }) {
    return InterstitialPresentationGate(loadShowTimeout: loadShowTimeout);
  }

  static Future<bool> _showInterstitialNow(SharedPreferences prefs) async {
    if (skipSdk || !adsEnabled || !consentAllowsAds) {
      if (!consentAllowsAds) _log('interstitial skipped: canRequestAds=false');
      return false;
    }
    final generation = _requestGeneration;
    try {
      await init();
      if (!_isShowStillValid(generation)) return false;

      final gate = createPresentationGate();

      Future<void> present(InterstitialAd ad) async {
        if (!_isShowStillValid(generation)) {
          ad.dispose();
          gate.markLoadFailed();
          return;
        }
        ad.fullScreenContentCallback = FullScreenContentCallback(
          onAdShowedFullScreenContent: (ad) async {
            if (gate.markShowed()) {
              _log('interstitial showed (fullscreen)');
              await prefs.setInt(
                _lastInterstitialMsKey,
                DateTime.now().millisecondsSinceEpoch,
              );
            } else {
              _log('interstitial showed ignored (gate already settled)');
            }
          },
          onAdDismissedFullScreenContent: (ad) {
            ad.dispose();
            _log('interstitial dismissed');
            gate.markDismissedWithoutShow();
          },
          onAdFailedToShowFullScreenContent: (ad, error) {
            ad.dispose();
            _log(
              'interstitial show failure '
              'code=${error.code} message=${error.message}',
            );
            gate.markFailedToShow();
          },
        );
        if (!_isShowStillValid(generation)) {
          ad.dispose();
          gate.markLoadFailed();
          return;
        }
        _log('interstitial show()');
        await ad.show();
      }

      if (_preloaded != null) {
        final ad = _preloaded!;
        _preloaded = null;
        _log('using preloaded interstitial');
        gate.armTimeout(() => _log('interstitial load/show timeout'));
        await present(ad);
        return gate.result;
      }

      if (_loadingInterstitial) {
        _log('interstitial already loading');
        return false;
      }
      _loadingInterstitial = true;

      _log(
        'interstitial load start id=${_tailId(AdMobIds.interstitialUnitId)}',
      );
      gate.armTimeout(() => _log('interstitial load/show timeout'));

      await InterstitialAd.load(
        adUnitId: AdMobIds.interstitialUnitId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) async {
            _loadingInterstitial = false;
            _log('interstitial load success');
            if (!_isShowStillValid(generation)) {
              ad.dispose();
              gate.markLoadFailed();
              return;
            }
            await present(ad);
          },
          onAdFailedToLoad: (error) {
            _loadingInterstitial = false;
            _log(
              'interstitial load failure '
              'code=${error.code} message=${error.message}',
            );
            gate.markLoadFailed();
          },
        ),
      );

      return gate.result;
    } catch (e) {
      _loadingInterstitial = false;
      _log('interstitial skipped exception: $e');
      return false;
    }
  }

  static bool _isShowStillValid(int generation) {
    if (generation != _requestGeneration) {
      _log('interstitial aborted: stale generation');
      return false;
    }
    if (!adsEnabled || !consentAllowsAds || !_initialized) {
      _log('interstitial aborted: eligibility changed');
      return false;
    }
    return true;
  }

  /// İsteğe bağlı preload (sonuç göstermeyi bloklamaz).
  static Future<void> preloadInterstitialIfNeeded({
    required SharedPreferences prefs,
    required bool isPro,
  }) async {
    if (isPro ||
        !adsEnabled ||
        !consentAllowsAds ||
        _preloaded != null ||
        _loadingInterstitial) {
      return;
    }
    final next = successCalcCount(prefs) + 1;
    if (!_shouldShowInterstitial(prefs, countAfterIncrement: next)) return;

    try {
      await init();
      if (!_initialized || !consentAllowsAds) return;
      _loadingInterstitial = true;
      _log('interstitial preload start');
      await InterstitialAd.load(
        adUnitId: AdMobIds.interstitialUnitId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            _loadingInterstitial = false;
            if (!_adsEnabled) {
              ad.dispose();
              _log('interstitial preload discarded (ads off)');
              return;
            }
            _preloaded = ad;
            _log('interstitial preload success');
          },
          onAdFailedToLoad: (error) {
            _loadingInterstitial = false;
            _log(
              'interstitial preload failure '
              'code=${error.code} message=${error.message}',
            );
          },
        ),
      );
    } catch (e) {
      _loadingInterstitial = false;
      _log('interstitial preload skipped: $e');
    }
  }
}

/// Load + show-başlangıcı için tek sonuç üreten kapı.
///
/// [markShowed] sonrası [result] true kalır; gecikmeli dismiss timeout/failure
/// üretmez. Aynı reklam için ikinci complete yok sayılır.
@visibleForTesting
class InterstitialPresentationGate {
  InterstitialPresentationGate({
    this.loadShowTimeout = const Duration(seconds: 8),
  });

  final Duration loadShowTimeout;
  final Completer<bool> _completer = Completer<bool>();
  Timer? _timeout;
  bool _settled = false;
  bool _showed = false;

  Future<bool> get result => _completer.future;

  bool get isCompleted => _settled;
  bool get didShow => _showed;

  void armTimeout([VoidCallback? onTimeout]) {
    _timeout?.cancel();
    _timeout = Timer(loadShowTimeout, () {
      if (_settled) return;
      onTimeout?.call();
      _complete(false);
    });
  }

  /// true → bu çağrı başarıyı kaydetti; false → kapı zaten settle.
  bool markShowed() {
    if (_settled) return _showed;
    _showed = true;
    _complete(true);
    return true;
  }

  void markLoadFailed() => _complete(false);

  void markFailedToShow() => _complete(false);

  /// Show callback gelmeden dismiss (nadir) — henüz settle olmadıysa fail.
  void markDismissedWithoutShow() {
    if (_showed) return;
    _complete(false);
  }

  void _complete(bool shown) {
    if (_settled) return;
    _settled = true;
    _timeout?.cancel();
    _timeout = null;
    if (!_completer.isCompleted) {
      _completer.complete(shown);
    }
  }
}

/// Anchored adaptive banner. Yüklenemezse boş alan bırakmaz.
class AdBanner extends StatefulWidget {
  const AdBanner({super.key});

  @override
  State<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends State<AdBanner> {
  BannerAd? _ad;
  bool _loaded = false;
  int _loadToken = 0;

  @override
  void initState() {
    super.initState();
    AdsService.eligibilityEpoch.addListener(_onEligibilityChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadAdaptive();
    });
  }

  void _onEligibilityChanged() {
    if (!mounted) return;
    if (!AdsService.mayRequestAds) {
      _ad?.dispose();
      setState(() {
        _ad = null;
        _loaded = false;
      });
      return;
    }
    if (!_loaded) {
      _loadAdaptive();
    }
  }

  Future<void> _loadAdaptive() async {
    if (!AdsService.adsEnabled || AdsService.skipSdk) {
      AdsService._log(
        'banner skip: adsEnabled=${AdsService.adsEnabled} '
        'skipSdk=${AdsService.skipSdk}',
      );
      return;
    }
    if (!AdsService.consentAllowsAds) {
      AdsService._log('banner skip: canRequestAds=false');
      return;
    }
    final token = ++_loadToken;
    try {
      await AdsService.init();
      if (!mounted || token != _loadToken) return;
      if (!AdsService.isSdkInitialized || !AdsService.consentAllowsAds) {
        AdsService._log('banner skip: SDK not ready after init');
        return;
      }

      final width = MediaQuery.sizeOf(context).width.truncate();
      // ignore: deprecated_member_use
      final size = await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(width);
      if (size == null) {
        AdsService._log('banner adaptive size null width=$width');
        return;
      }
      if (!mounted || token != _loadToken) return;

      await _ad?.dispose();
      _ad = null;
      _loaded = false;

      AdsService._log(
        'banner load start id=${AdsService._tailId(AdMobIds.bannerUnitId)} '
        'size=${size.width}x${size.height}',
      );

      final ad = BannerAd(
        size: size,
        adUnitId: AdMobIds.bannerUnitId,
        listener: BannerAdListener(
          onAdLoaded: (_) {
            AdsService._log('banner load success');
            if (mounted && token == _loadToken) {
              setState(() => _loaded = true);
            }
          },
          onAdFailedToLoad: (ad, error) {
            ad.dispose();
            AdsService._log(
              'banner load failure code=${error.code} '
              'message=${error.message}',
            );
            if (mounted && token == _loadToken) {
              setState(() {
                _ad = null;
                _loaded = false;
              });
            }
          },
        ),
        request: const AdRequest(),
      );
      await ad.load();
      if (!mounted || token != _loadToken) {
        ad.dispose();
        return;
      }
      setState(() => _ad = ad);
    } catch (e) {
      AdsService._log('banner init/load skipped: $e');
    }
  }

  @override
  void dispose() {
    AdsService.eligibilityEpoch.removeListener(_onEligibilityChanged);
    _loadToken++;
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!AdsService.adsEnabled || !_loaded || _ad == null) {
      return const SizedBox.shrink();
    }
    return ColoredBox(
      color: const Color(0x00000000),
      child: SizedBox(
        width: _ad!.size.width.toDouble(),
        height: _ad!.size.height.toDouble(),
        child: AdWidget(ad: _ad!),
      ),
    );
  }
}
