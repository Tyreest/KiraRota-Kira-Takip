/// Uygulama sabitleri.
class AppConstants {
  static const String appName = 'KiraRota';
  static const String brandName = 'KiraRota';
  static const String packageId = 'com.tyreest.kiraartisi';

  /// Play Store kısa başlık önerisi (UI dışı dokümantasyon).
  static const String playTitleSuggestion = 'KiraRota – Kira Takip';

  /// Ücretsiz: kira kaydı başına geçmiş hesaplama limiti.
  static const int freeHistoryLimit = 5;

  /// Ücretsiz: kayıtlı kira üst sınırı.
  static const int freeRentalLimit = 1;

  /// Play Console managed product ID (non-consumable / one-time lifetime).
  /// Fiyat Play Billing `ProductDetails.price` ile gelir; UI’da hardcode yok.
  static const String iapProductId = 'kira_pro_lifetime';

  // --- AdMob: Google resmi test ID'leri (yalnızca debug) ---
  static const String admobTestAppId = 'ca-app-pub-3940256099942544~3347511713';
  static const String admobTestBannerUnitId =
      'ca-app-pub-3940256099942544/6300978111';
  static const String admobTestInterstitialUnitId =
      'ca-app-pub-3940256099942544/1033173712';

  /// Production AdMob — dart-define veya boş (sahte ID uydurulmaz).
  static const String admobProductionAppId = String.fromEnvironment(
    'ADMOB_APP_ID',
    defaultValue: '',
  );
  static const String admobProductionBannerUnitId = String.fromEnvironment(
    'ADMOB_BANNER_ID',
    defaultValue: '',
  );
  static const String admobProductionInterstitialUnitId =
      String.fromEnvironment('ADMOB_INTERSTITIAL_ID', defaultValue: '');

  /// Interstitial: her N. başarılı hesaplama.
  static const int interstitialEveryNSuccess = 3;

  /// Interstitial global cooldown.
  static const Duration interstitialCooldown = Duration(minutes: 10);

  /// Debug/screenshot seed — release’de false kalmalı.
  static const bool screenshotSeed = bool.fromEnvironment(
    'SCREENSHOT_SEED',
    defaultValue: false,
  );

  /// `empty` | `seed` | `` — boş dashboard / seeded QA. Release’de boş.
  static const String screenshotMode = String.fromEnvironment(
    'SCREENSHOT_MODE',
    defaultValue: '',
  );

  /// Uzaktan oran JSON (GitHub raw). Başarısızsa asset fallback.
  static const String remoteRatesUrl =
      'https://raw.githubusercontent.com/Tyreest/KiraRota-Kira-Takip/main/hosted/tufe_rates.json';

  static const String privacyUrl =
      'https://tyreest.github.io/KiraRota-Kira-Takip/privacy-policy.html';
  static const String termsUrl =
      'https://tyreest.github.io/KiraRota-Kira-Takip/terms.html';

  static const String disclaimerShort =
      'Hesaplamalar tahmindir; hukuki tavsiye değildir. Resmî TÜİK uygulaması değildir.';

  /// Play / kullanıcı görünürlüğü — resmî kurum uygulaması olmadığı.
  static const String notOfficialDisclaimer =
      'KiraRota, TÜİK’in veya herhangi bir kamu kurumunun '
      'resmî uygulaması değildir.';

  static const String fiveYearWarning =
      'Kira ilişkiniz 5 yılı doldurmuş görünüyor. Bu hesap TÜFE esaslı azami artış '
      'oranına göredir. 5+ yıllık ilişkilerde emsal kira ve hâkim değerlendirmesi '
      'ayrı bir süreç olabilir.';
}
