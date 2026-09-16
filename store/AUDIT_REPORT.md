# Denetim raporu — 7 Ağustos 2026

Otomatik suite: `flutter test` → **50 test geçti** (audit + app_flow + pro_flow + unit).

| Madde | Sonuç | Not |
|-------|--------|-----|
| Hesap motoru: doğru ay → doğru TÜFE | **GEÇTİ** | Temmuz %32.03, Ağustos %31.90; asset ile doğrulandı |
| Sözleşme düşük/yüksek | **GEÇTİ** | min(sözleşme, azami) + compare kind |
| 5+ yıl uyarısı zamanı | **GEÇTİ** | `renewalDay` ile 15 Temmuz eşiği doğru |
| Remote internet / hata → asset | **GEÇTİ** | MockClient 500 → asset; stale remote reddi |
| Remote daha yeni seçimi | **GEÇTİ** | MockClient |
| Oran yok → sessiz fallback yok | **GEÇTİ** | `CalculationRateMissing` (Eylül 2026) |
| 15 Temmuz 2026 günü | **GEÇTİ** | `renewalDay: 15` korunuyor |
| Geçmiş kapat-aç | **GEÇTİ** | SharedPreferences yeniden yükleme |
| Free limit 5 / Pro sınırsız | **GEÇTİ** | |
| Hatırlatma prefs kaydı | **GEÇTİ** | İzin olmasa da kayıt saklanır (try/catch) |
| Hatırlatma gerçek Android schedule | **CİHAZ** | Emülatörde izin + exact alarm elle doğrula |
| Pro Play Billing gerçek ürün | **BLOKE** | Console’da `kira_pro_lifetime` yok; Billing API emülatörde zayıf |
| Satın alma restore | **BLOKE** | Gerçek ürün + lisans hesabı lazım |
| Fiyat UI hardcode mi? | **KISMEN** | `AppConstants.proPriceLabel = ₺199` gösterim; Play fiyatı Billing’den gelmiyor (bilinçli v1) |
| AdMob test ID | **GEÇTİ (test)** | Google test ID; yayın öncesi değiştir |
| Pro → reklam kaybolur | **GEÇTİ** | Widget: Pro’da `AdBanner` yok |
| PDF Türkçe / ₺ | **DÜZELTİLDİ+GEÇTİ** | Bundled Noto Sans; offline Helvetica düşüşü giderildi |
| Analytics kira sızıntısı | **GEÇTİ** | Firebase/Analytics yok; kira event’i yok |
| Signed AAB / keystore | **EKSİK** | `key.properties` yok → release debug imza |
| minify / ProGuard | **EKSİK** | Release’de minify kapalı (şimdilik OK; yayın sertleştirmesi) |
| Crash-free gerçek cihaz | **CİHAZ** | Fiziksel telefonda smoke gerekli |

## Bu turda bulunan ve düzeltilen gerçek bug
PDF, ağ yokken Google Fonts indiremezse Helvetica’ya düşüp **ı/ş/ğ/₺** çizemiyordu.  
Çözüm: `assets/fonts/NotoSans-*.ttf` gömülü.

## Bilinçli kalanlar (Play / hesap)
1. AdMob gerçek ID  
2. Upload keystore + imzalı AAB  
3. IAP ürün + lisans testi  
4. Emülatör/cihazda 30/7/0 bildirim smoke  
5. (İsteğe bağlı) Play fiyatını Billing `ProductDetails.price` ile göstermek  

## Nasıl tekrar koşulur
```powershell
cd C:\Users\yigit\Desktop\Projeler\KiraRota–KiraTakip
flutter test
```
