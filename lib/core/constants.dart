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

  /// Google test AdMob App ID (yayında kendi ID’nizle değiştirin).
  static const String admobAppId =
      'ca-app-pub-3940256099942544~3347511713';

  /// Google test banner (yayında kendi unit ID).
  static const String admobBannerUnitId =
      'ca-app-pub-3940256099942544/6300978111';

  /// Uzaktan oran JSON (GitHub raw). Başarısızsa asset fallback.
  static const String remoteRatesUrl =
      'https://raw.githubusercontent.com/Tyreest/kira-artisi-hesapla/main/hosted/tufe_rates.json';

  static const String privacyUrl =
      'https://tyreest.github.io/kira-artisi-hesapla/';
  static const String termsUrl =
      'https://tyreest.github.io/kira-artisi-hesapla/terms.html';

  static const String disclaimerShort =
      'Hesaplamalar tahmindir; hukuki tavsiye değildir. Resmi TÜİK uygulaması değildir.';

  static const String fiveYearWarning =
      'Kira ilişkiniz 5 yılı doldurmuş görünüyor. Bu hesap TÜFE esaslı azami artış '
      'oranına göredir. 5+ yıllık ilişkilerde emsal kira ve hâkim değerlendirmesi '
      'ayrı bir süreç olabilir.';
}
