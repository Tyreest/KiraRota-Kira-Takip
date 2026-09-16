# Play yayın / closed test checklist

## A) Teknik
- [x] `flutter test` yeşil
- [x] `flutter build appbundle` başarılı *(debug imza ile doğrulandı; upload keystore ayrı)*
- [ ] Release imzalama (upload keystore) ayarlı — `store/signing.md`
- [x] `applicationId` = `com.tyreest.kiraartisi`
- [ ] Sürüm: versionName / versionCode Play’de artıyor
- [ ] Pro IAP product ID: `kira_pro_lifetime` (managed / one-time)
- [x] AdMob: production App ID + banner + interstitial (`admob.properties` + release dart-define)
- [x] AndroidManifest release App ID production
- [ ] Internal Testing: test device kaydı; production reklama tıklama
- [ ] Bildirim izni (Android 13+) akışı denendi *(emulator diyalog görüldü; Allow ile tekrar dene)*
- [ ] Remote oran URL (opsiyonel) host edildi; `AppConstants.remoteRatesUrl` dolduruldu

## B) Data Safety (Play Console)
Toplanan / paylaşılan (reklamlı free sürüm):
- [ ] Device or other IDs — AdMob (reklam)
- [ ] App activity / reklam etkileşimi — AdMob
Beyan:
- [ ] Kira tutarı “cihazda işlenir / geliştiriciye gönderilmez”
- [ ] Veri şifreleme: transit (HTTPS AdMob)
- [ ] Kullanıcı istediğinde silebilir: uygulama verisini sil
- [ ] Çocuklara yönelik değil

## C) Mağaza varlığı
- [x] Gizlilik politikası **HTTPS URL** — https://tyreest.github.io/KiraRota-Kira-Takip/privacy-policy.html (`store/PRIVACY_POLICY_SETUP.md`)
- [ ] listing_tr.md metinleri yapıştırıldı
- [ ] İkon 512 + feature graphic 1024x500
- [ ] En az 2–4 telefon ekran görüntüsü
- [ ] İçerik derecelendirme anketi

## D) Closed testing
- [ ] Internal / closed track’e AAB yükle
- [ ] En az 1 lisans test hesabı ile Pro satın alma
- [ ] PDF paylaşımı
- [ ] Hatırlatma kaydı + bildirim izni
- [ ] Oran eksik ay uyarısı (örn. henüz açıklanmamış ay)
- [ ] Free geçmiş limiti 5

## E) Soft launch notları
- Oran güncellemesi: TÜİK sonrası ≤3 gün
- Destek kanalı (e-posta) hazır
- Maaşım stabilize olduktan sonra production’a alma tercihi
