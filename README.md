# Kira Artışı Hesapla

TÜFE 12 aylık ortalama esaslı azami artış oranı ve buna göre hesaplanan kira.

- Paket: `com.tyreest.kiraartisi`
- Pro lifetime: ₺199 — product ID: `kira_pro_lifetime`
- Oranlar: `assets/data/tufe_rates.json` + opsiyonel remote (`AppConstants.remoteRatesUrl`)
- Remote şablon: `hosted/tufe_rates.json`

## Çalıştırma

```bash
cd Desktop/Projeler/kira-artisi-hesapla
flutter pub get
flutter test
flutter run
```

Tam yeniden başlatma (plugin’ler için): uygulamayı durdurup tekrar `flutter run`.

## Pro özellikler

| Özellik | Durum |
|---------|--------|
| Reklamsız (AdMob test banner) | Hazır — Pro’da kapalı |
| PDF özet | Hazır |
| Yenileme hatırlatması 30/7/0 | Hazır (bildirim izni gerekir) |
| Sınırsız geçmiş | Hazır |
| Play Billing | Kod hazır — Console’da ürün + lisans testi gerekir |

## Play Console notları

1. Managed product: `kira_pro_lifetime` (tek seferlik, ₺199)
2. AdMob App ID / banner unit’i `AppConstants` ve `AndroidManifest` içinde test ID’lerden gerçek ID’ye çevir
3. Data Safety: AdMob + (ileride Analytics) beyanı

## Remote oran

`hosted/tufe_rates.json` dosyasını host edip:

```dart
static const String? remoteRatesUrl = 'https://.../tufe_rates.json';
```
