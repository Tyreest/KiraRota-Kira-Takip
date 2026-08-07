# Manuel test turu (hepsini bitince)

Otomatik suite: `flutter test` → **tüm testler geçti** (app_flow + pro_flow + unit).
Emulator smoke: `flutter run -d emulator-5554` → APK + AdMob test banner OK.

Uygulamayı tam restart ile aç: `flutter run`

## 1. Onboarding
- [x] İlk açılışta onboarding görünür *(widget)*
- [x] Başla sonrası tekrar gelmez *(widget)*

## 2. Hesapla
- [x] Konut / çatılı işyeri seçimi *(widget)*
- [x] Temmuz 2026 + 25000 → sonuç ekranı (oranlı) *(widget)*
- [x] Soft etiketler: azami oran / buna göre hesaplanan kira *(widget)*
- [x] Sözleşme %40 → bilgilendirme uyarısı *(widget)*
- [x] Sözleşme başlangıcı 5+ yıl → 5 yıl notu *(widget)*
- [x] Ağustos 2026 (oran yok) → uyarı, Hesapla disabled/engelli *(widget)*
- [x] Kopyala / Paylaş butonları sonuçta görünür *(widget; gerçek share cihaz)*

## 3. Pro / PDF / reklam
- [x] Free’de altta test banner (yüklenirse) *(emulator screenshot)*
- [x] Pro açılınca banner kaybolur *(widget)*
- [x] Free PDF → paywall *(widget)*
- [x] Pro PDF → shareCalculation çağrılır *(widget; gerçek share sheet cihaz)*

## 4. Hatırlatma
- [x] Free → paywall *(widget)*
- [x] Pro → 30/7/0 kaydet *(widget; bildirim plugin’i testte kapalı)*
- [x] Kaldır çalışır *(widget)*

## 5. Geçmiş
- [x] Boş durum + Yeni hesaplama *(widget)*
- [x] 6. hesap sonrası free’de 5 kayıt kalır *(unit + widget)*
- [x] Pro yükselt kartı *(widget)*

## 6. Oranlar / yasal
- [x] Oran listesi + YENİ rozeti *(widget)*
- [x] Gizlilik / Kullanım / Yasal metinleri açılır *(widget: Gizlilik)*

## 7. Mağaza (sıradaki)
- [x] Gizlilik HTTPS URL — https://tyreest.github.io/kira-artisi-hesapla/
- [ ] IAP lisans testi — rehber: `store/iap_setup.md`
- [ ] AAB closed track — rehber: `store/signing.md` + `tool/create_upload_keystore.ps1`

### Emulator’da Pro hızlı deneme
Debug build → **Ayarlar** → en altta **Geliştirme: Pro’yu aç**

### Test sırasında düzeltilen UI
- Onboarding / paywall scroll
- SoftCard + ListTile Material
- AdBanner init hatalarında crash yok
- ReminderService `enableNotifications` (widget test)
