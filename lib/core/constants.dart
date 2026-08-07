/// Uygulama sabitleri.
class AppConstants {
  static const String appName = 'Kira Artışı Hesapla';
  static const String brandName = 'Kira Asistanı';
  static const String packageId = 'com.tyreest.kiraartisi';

  /// Ücretsiz geçmiş kayıt limiti.
  static const int freeHistoryLimit = 5;

  /// Lifetime Pro fiyatı (görüntüleme; gerçek fiyat Play Console'da).
  static const String proPriceLabel = '₺199';

  /// Play Console managed product ID (tek seferlik).
  static const String iapProductId = 'kira_pro_lifetime';

  /// Google test AdMob App ID (yayında kendi ID’nizle değiştirin).
  static const String admobAppId =
      'ca-app-pub-3940256099942544~3347511713';

  /// Google test banner (yayında kendi unit ID).
  static const String admobBannerUnitId =
      'ca-app-pub-3940256099942544/6300978111';

  /// Uzaktan oran JSON. null → yalnızca asset.
  /// Örnek: GitHub raw / Firebase Hosting URL.
  /// Dosya şablonu: `hosted/tufe_rates.json`
  static const String? remoteRatesUrl = null;

  static const String disclaimerShort =
      'Hesaplamalar tahmindir; hukuki tavsiye değildir. Resmi TÜİK uygulaması değildir.';

  static const String fiveYearWarning =
      'Kira ilişkiniz 5 yılı doldurmuş görünüyor. Bu hesap TÜFE esaslı azami artış '
      'oranına göredir. 5+ yıllık ilişkilerde emsal kira ve hâkim değerlendirmesi '
      'ayrı bir süreç olabilir.';
}
