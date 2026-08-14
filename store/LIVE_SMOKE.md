# Canlı smoke (emulator) — 2026-08-07

Cihaz: `emulator-5554` (Android 16) · paket: `com.tyreest.kiraartisi` · debug run

## Sonuç özeti

| Alan | Sonuç | Not |
|------|--------|-----|
| Onboarding / marka | PASS | Kira Asistanı onboarding görüldü |
| Ana ekran | PASS | Konut / tarihler / Hesapla |
| Hesaplama | PASS | ₺25.000 → **₺32.975** (%31,9), kaynak **Uzaktan güncel** |
| Soft etiketler | PASS | Azami oran + buna göre hesaplanan kira |
| Oranlar | PASS | Ağustos 2026 YENİ %31,9; uzak TÜFE |
| Geçmiş | PASS | Kayıt oluştu; free 5 limit + Pro yükselt |
| Ayarlar | PASS | Pro kartı, hatırlatma PRO, yasal linkler; **banner yok** |
| Free PDF → paywall | PASS | Kira Asistanı Pro sheet (Şimdi Al / Geri yükle / Sonra) |
| Adaptive banner | PASS | Google **test** banner (Hesapla/Oranlar/Geçmiş) |
| Interstitial | PASS | Test interstitial (hesaplama sonrası) görüldü |
| Startup bildirim izni | PASS | Açılışta dialog yok |
| Launcher ikonu (APK) | PASS | Final orman yeşili + ev ikonu pakette |
| Launcher etiketi | PASS | Drawer: **Kira Artışı Hesapla** |
| Crash | PASS | Fatal yok |
| Play Billing | EXPECTED-FAIL | Emulator: Billing API desteklenmiyor → Internal Testing |

## Emulator’da doğrulanamayan (yayın öncesi cihaz/track)

- Gerçek Play Billing fiyat / satın alma / restore
- Production AdMob birim ID’leri (debug’da test ID)
- Fiziksel cihazda bildirim izni → hatırlatma zamanlaması
- Release AAB’nin Internal Testing yüklemesi

Ekran görüntüleri: `store/live_smoke/`
