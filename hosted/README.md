# Remote TÜFE oran dosyası

Bu dosyayı GitHub Pages / Firebase Hosting / kendi sunucunuza yükleyin.
Sonra `lib/core/constants.dart` içinde:

static const String? remoteRatesUrl = 'https://.../tufe_rates.json';

Kurallar: version/updated_at asset'ten eskiyse asset kullanılır; eksik ay sessiz taşınmaz.
