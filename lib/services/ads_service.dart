import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:kira_artisi_hesapla/core/constants.dart';

class AdsService {
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    await MobileAds.instance.initialize();
    _initialized = true;
  }
}

class AdBanner extends StatefulWidget {
  const AdBanner({super.key});

  @override
  State<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends State<AdBanner> {
  BannerAd? _ad;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      await AdsService.init();
      final ad = BannerAd(
        size: AdSize.banner,
        adUnitId: AppConstants.admobBannerUnitId,
        listener: BannerAdListener(
          onAdLoaded: (_) {
            if (mounted) setState(() => _loaded = true);
          },
          onAdFailedToLoad: (ad, error) {
            ad.dispose();
            debugPrint('Banner load failed: $error');
          },
        ),
        request: const AdRequest(),
      );
      await ad.load();
      if (mounted) {
        setState(() => _ad = ad);
      }
    } catch (e) {
      debugPrint('Banner init/load skipped: $e');
    }
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || _ad == null) return const SizedBox.shrink();
    return SizedBox(
      width: _ad!.size.width.toDouble(),
      height: _ad!.size.height.toDouble(),
      child: AdWidget(ad: _ad!),
    );
  }
}
