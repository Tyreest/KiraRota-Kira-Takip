/// Uygulama sabitleri.
class AppConstants {
  static const String appName = 'Kira Artışı Hesapla';
  static const String brandName = 'Kira Asistanı';
  static const String packageId = 'com.tyreest.kiraartisi';

  /// Ücretsiz geçmiş kayıt limiti.
  static const int freeHistoryLimit = 5;

  /// Play Console managed product ID (non-consumable / one-time lifetime).
  /// Fiyat Play Billing `ProductDetails.price` ile gelir; UI’da hardcode yok.
  static const String iapProductId = 'kira_pro_lifetime';

  // --- AdMob: Google resmi test ID'leri (yalnızca debug) ---
  static const String admobTestAppId =
      'ca-app-pub-3940256099942544~3347511713';
  static const String admobTestBannerUnitId =
      'ca-app-pub-3940256099942544/6300978111';
  static const String admobTestInterstitialUnitId =
      'ca-app-pub-3940256099942544/1033173712';

  /// Production AdMob — dart-define veya boş (sahte ID uydurulmaz).
  /// Örnek: --dart-define=ADMOB_BANNER_ID=ca-app-pub-xxx/yyy
  static const String admobProductionAppId =
      String.fromEnvironment('ADMOB_APP_ID', defaultValue: '');
  static const String admobProductionBannerUnitId =
      String.fromEnvironment('ADMOB_BANNER_ID', defaultValue: '');
  static const String admobProductionInterstitialUnitId =
      String.fromEnvironment('ADMOB_INTERSTITIAL_ID', defaultValue: '');

  /// Interstitial: her N. başarılı hesaplama.
  static const int interstitialEveryNSuccess = 3;

  /// Interstitial global cooldown.
  static const Duration interstitialCooldown = Duration(minutes: 10);

  /// Uzaktan oran JSON (GitHub raw). Başarısızsa asset fallback.
  static const String remoteRatesUrl =
      'https://raw.githubusercontent.com/Tyreest/kira-artisi-hesapla/main/hosted/tufe_rates.json';

  static const String privacyUrl =
      'https://tyreest.github.io/kira-artisi-hesapla/privacy-policy.html';
  static const String termsUrl =
      'https://tyreest.github.io/kira-artisi-hesapla/terms.html';

  static const String disclaimerShort =
      'Hesaplamalar tahmindir; hukuki tavsiye değildir. Resmi TÜİK uygulaması değildir.';

  static const String fiveYearWarning =
      'Kira ilişkiniz 5 yılı doldurmuş görünüyor. Bu hesap TÜFE esaslı azami artış '
      'oranına göredir. 5+ yıllık ilişkilerde emsal kira ve hâkim değerlendirmesi '
      'ayrı bir süreç olabilir.';
}
