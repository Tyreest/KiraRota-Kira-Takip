# Manuel test turu (hepsini bitince)

Otomatik suite: `flutter test` → **tüm testler geçti** (app_flow + pro_flow + unit).
Emulator smoke: `flutter run -d emulator-5554` → APK + AdMob test banner OK.

Uygulamayı tam restart ile aç: `flutter run`

## 1. Onboarding
- [x] İlk açılışta onboarding görünür *(widget)*
- [x] Başla sonrası tekrar gelmez *(widget)*

## 2. Hesapla
- [x] Konut / işyeri seçimi *(widget)*
- [x] Temmuz 2026 + 25000 → sonuç ekranı (oranlı) *(widget)*
- [x] Soft etiketler: azami oran / buna göre hesaplanan kira *(widget)*
- [x] Sözleşme %40 → bilgilendirme uyarısı *(widget)*
- [x] Sözleşme başlangıcı 5+ yıl → 5 yıl notu *(widget)*
- [x] Eylül 2026 (oran yok) → uyarı, Hesapla disabled *(widget; Ağustos %31,90 eklendi)*
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

## 7. Mağaza / Billing
- [x] Localized fiyat UI (hardcode yok) — `test/iap_billing_test.dart`
- [x] purchase / pending / cancel / already-owned / restore — unit
- [ ] Gerçek Play IAP — **Internal/Closed track zorunlu** → `store/BILLING_TEST.md`
- [ ] AAB closed track — `store/signing.md`

Gizlilik: https://tyreest.github.io/kira-artisi-hesapla/privacy-policy.html  
Kurulum: `store/PRIVACY_POLICY_SETUP.md` · `store/iap_setup.md`

### Emulator’da Pro
Debug Pro toggle **kaldırıldı** (release’de de yok). Pro yalnızca Play Billing / test prefs ile.

Billing checklist: `store/INTERNAL_TESTING.md` · imza: `store/signing.md`
