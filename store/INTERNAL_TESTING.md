# Google Play Internal Testing — adım adım checklist

Bu doküman **hiçbir mağaza işlemini başarılı varsaymaz**.  
Kod/unit test ile kanıtlananlar ile **cihaz + Play Console** doğrulaması gerekenler ayrılmıştır.

Paket: `com.tyreest.kiraartisi`  
Ürün: `kira_pro_lifetime` (non-consumable / one-time lifetime)

---

## A) Otomatik / lokal (bu repoda)

```powershell
flutter test
flutter build appbundle --release
```

| Madde | Kanıt |
|-------|--------|
| Hardcoded ₺199 yok; fiyat `ProductDetails.price` | `test/iap_billing_test.dart` |
| purchase / pending / cancel / already-owned (simüle) | unit |
| restore owned → Pro | unit |
| store fail / timeout → local Pro korunur | unit |
| store OK + not owned → local Pro revoke | unit |
| Debug Pro toggle release’de yok | Settings UI’dan kaldırıldı; `unlockDebugOnly` yok |
| Release debug imza kullanmaz | `build.gradle.kts` key.properties zorunlu |
| Minify + resource shrink | release buildType |
| Signed AAB üretimi | `store/signing.md` + lokal AAB |

---

## B) Play Console — Internal Testing öncesi kurulum

Sıra önemli; atlama.

### B1. Uygulama + imza
- [ ] Play Console’da uygulama `com.tyreest.kiraartisi` oluştu
- [ ] Upload keystore yedeklendi (`store/signing.md`)
- [ ] İlk AAB yüklendi (Internal track taslağı yeterli olabilir)
- [ ] Play App Signing durumu not edildi

### B2. In-app product
- [ ] Monetize → In-app products → Create
- [ ] Product ID tam olarak: **`kira_pro_lifetime`**
- [ ] Type: **Managed product / One-time** (subscription değil)
- [ ] Name/description TR dolduruldu
- [ ] Fiyat (hedef ülke TRY) ayarlandı — uygulama bunu UI’ya hardcode etmez
- [ ] Status: **Active**
- [ ] Ürün, Internal track’teki uygulamayla eşleşiyor

### B3. License testers
- [ ] Settings → License testing → Gmail eklendi
- [ ] Test cihazında **aynı Google hesabı** oturum açık
- [ ] Hesap Internal testing’e davetli / opted-in

### B4. Internal track release
- [ ] Release → Testing → Internal testing → yeni release
- [ ] Signed `app-release.aab` yüklendi
- [ ] Release notları (opsiyonel)
- [ ] Rollout / Review tamam; tester linki alındı
- [ ] Telefona **Play Store Internal link** ile kuruldu (sideload/debug APK ile Billing doğrulanmaz)

---

## C) Fiziksel cihaz — mağaza doğrulaması (zorunlu ayrı liste)

> Emülatör / `flutter run` debug APK sonuçları **geçersiz sayılır** (Billing/fiyat).

Cihaz: ________  
Hesap (license tester): ________  
Tarih: ________  
AAB versionCode: ________

| # | Senaryo | Nasıl | Beklenen | Sonuç |
|---|---------|-------|----------|-------|
| 1 | Canlı localized fiyat | Ayarlar / paywall | Play ülke fiyatı (örn. ₺x,xx); “Mağazadan alın” değil | [ ] |
| 2 | Purchase | Şimdi Al → Billing sheet tamamla | Pro aktif; snack OK | [ ] |
| 3 | Cancel | Sheet’te vazgeç | Pro yok; iptal mesajı | [ ] |
| 4 | Pending | Varsa test kartı / banka onayı gecikmesi | “Ödeme onay bekliyor…”; grant sonra | [ ] N/A veya [ ] |
| 5 | Already-owned | Pro’luyken tekrar Al | Owned / restore; Pro kalır | [ ] |
| 6 | Restore butonu | Clear data sonrası veya ikinci cihaz | “Geri yükle” → Pro | [ ] |
| 7 | Uninstall/reinstall | Kaldır → Internal’dan kur → açılış | Restore ile Pro geri | [ ] |
| 8 | Refund/revoke | Play iade veya license test revoke sonrası uygulama aç/sync | Local Pro kapanır | [ ] |
| 9 | Pro’da reklamlar | Purchase sonrası ana ekran | Banner yok | [ ] |
| 10 | Free’de reklam | Pro’suz hesap | Test/gerçek banner politikasına göre görünür | [ ] |
| 11 | Bildirim smoke | Pro → hatırlatma 30/7/0 kaydet | Android izinleri; schedule; (mümkünse kısa tarihle) tetik | [ ] |
| 12 | Bildirim izin reddi | İzni reddet → kaydet | Çökme yok; tercihler saklanır / anlamlı mesaj | [ ] |

### Refund/revoke notu
Play’de gerçek iade dakikalar–saat sürebilir. License tester ile “test purchase” iadesi Console’dan yapılabilir.  
Uygulama: mağaza ownership sorgusu **başarılı ve empty** ise local Pro’yu kapatır; sorgu fail ise **korur**.

---

## D) Bilinçli olarak “başarılı varsayılmayanlar”

Aşağıdakiler yeşil unit test olsa bile **Internal Testing tablosu (C) işaretlenmeden release’e hazır sayma**:

1. Canlı localized fiyatın UI’da görünmesi  
2. Gerçek purchase / cancel / pending / already-owned  
3. Restore ve uninstall/reinstall  
4. Refund/revoke sonrası Pro’nun kapanması  
5. Pro’da reklamların gerçekten kaybolması (AdMob production ID’ler ayrı konu)  
6. Fiziksel cihazda bildirim schedule + izin reddi UX  
7. Crash-free release smoke (minify açık AAB)

---

## E) Production ID’ler (ayrı iş)

- [x] AdMob App ID + Banner + Interstitial → production (`store/ADMOB.md`)
- [ ] Internal Testing’de production reklam (test device; reklama tıklama)  
- [ ] Data safety / gizlilik formu Play Console  
- [ ] Closed → Production rollout kararı  
