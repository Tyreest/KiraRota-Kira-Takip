/// Resmî TÜİK kaynak URL’leri — tek merkez.
///
/// Yalnız `*.tuik.gov.tr` host’ları. Sahte / üçüncü taraf kaynak yok.
abstract final class TuikUrls {
  /// Genel resmî veri portalı (fallback).
  static const String dataPortal = 'https://veriportali.tuik.gov.tr/tr';

  /// Temmuz 2026 TÜFE bülteni (Ağustos 2026 uygulama dönemi) — doğrulanmış.
  static const String bulletinTemmuz2026 =
      'https://data.tuik.gov.tr/Bulten/Index?p=Tuketici-Fiyat-Endeksi-Temmuz-2026-58297';

  /// Ağustos 2026 TÜFE bülteni (Eylül 2026 uygulama dönemi).
  static const String bulletinAgustos2026 =
      'https://data.tuik.gov.tr/Bulten/Index?p=Tuketici-Fiyat-Endeksi-Agustos-2026';

  /// [sourceUrl] doluysa onu, değilse [dataPortal] döner.
  static String resolve([String? sourceUrl]) {
    final u = sourceUrl?.trim();
    if (u != null && u.isNotEmpty) return u;
    return dataPortal;
  }

  static bool isAllowedOfficialHost(Uri uri) {
    if (uri.scheme != 'https' && uri.scheme != 'http') return false;
    final host = uri.host.toLowerCase();
    return host == 'tuik.gov.tr' || host.endsWith('.tuik.gov.tr');
  }
}
