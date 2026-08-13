# AdMob production config

## Kaynaklar

| Ortam | App ID | Banner | Interstitial |
|-------|--------|--------|--------------|
| **Debug** | Google test (`394025…~3347…`) | Google test banner | Google test interstitial |
| **Release** | `android/admob.properties` → Manifest | `--dart-define=ADMOB_BANNER_ID` | `--dart-define=ADMOB_INTERSTITIAL_ID` |

- Şablon: `android/admob.properties.example`
- Gerçek dosya (gitignore): `android/admob.properties`
- Release build: `powershell -File tool/build_release_aab.ps1`
- ID eksikse veya Google test publisher sızmışsa **release Gradle FAIL**

## Reklam stratejisi (değişmedi)

- Free: Hesapla / Oranlar / Geçmiş → adaptive banner
- Pro: hiç reklam yok (preload discard dahil)
- Interstitial: her 3. başarılı hesaplama **ve** ≥ 10 dk cooldown
- Onboarding / Ayarlar / Reminder / Paywall: reklam yok

## Fiziksel cihaz / Internal Testing checklist

- [ ] Internal Testing AAB yüklendi (production AdMob dart-define ile)
- [ ] Cihaz AdMob’da **test device** olarak tanımlandı (veya test hesabı)
- [ ] **Production reklamlara tıklama** — kendi envanterine tıklamak politika ihlali / geçersiz trafik riski
- [ ] Free: Hesapla / Oranlar / Geçmiş’te banner yükleniyor
- [ ] Ayarlar / onboarding / paywall’da banner yok
- [ ] 3. başarılı hesapta interstitial (10 dk cooldown ile)
- [ ] Pro satın alınca banner + interstitial + preload kayboluyor
- [ ] Debug build hâlâ Google test ID kullanıyor (`flutter run`)
