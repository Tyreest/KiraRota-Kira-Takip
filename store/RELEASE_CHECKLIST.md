# KiraRota — Release checklist (1.1.1+21)

Kod davranışını değiştirmez; insan doğrulama listesidir. Secret / PIN / plaintext review kodu buraya yazılmaz.

## Kimlik

- [ ] `pubspec.yaml` version = `1.1.1+21`
- [ ] applicationId = `com.tyreest.kiraartisi` (Play listing ile aynı)
- [ ] Store başlık / marka: **KiraRota**

## İmza

- [ ] `android/key.properties` mevcut (git’te yok)
- [ ] Release, debug keystore ile üretilmiyor (`key.properties` yoksa Gradle **FAIL**)
- [ ] Adımlar: `store/signing.md`
- [ ] Keystore yedeği güvenli yerde (şifreleri buraya yazma)

## AdMob

- [ ] Debug build Google **test** ID kullanır
- [ ] `android/admob.properties` (veya `ADMOB_APP_ID` / `ADMOB_BANNER_ID` / `ADMOB_INTERSTITIAL_ID`) production değerlerle dolu
- [ ] Production ID’lerde Google test publisher `3940256099942544` **yok**
- [ ] Release gate: eksik veya test ID → Gradle **FAIL** (`android/app/build.gradle.kts`)
- [ ] Release AAB’de test ad unit sızması yok

## TÜFE / remote oran

Doğrulanmış URL (`AppConstants.remoteRatesUrl`):

`https://raw.githubusercontent.com/Tyreest/kira-artisi-hesapla/main/hosted/tufe_rates.json`

- [ ] Remote endpoint erişilebilir (HTTP 200, geçer JSON)
- [ ] `hosted/tufe_rates.json` güncel
- [ ] `assets/data/tufe_rates.json` (asset fallback) güncel / tutarlı
- [ ] Remote failure senaryosunda uygulamanın asset fallback’e düştüğü biliniyor (kod: `RateRepository`)

## IAP — gerçek cihaz / license tester smoke

Ürün ID: `kira_pro_lifetime`

- [ ] Paywall / Ayarlar’da fiyat Play’den geliyor (hardcoded ₺ yok)
- [ ] Satın alma tamamlanıyor → Pro açılıyor
- [ ] Uygulama kapat/aç → Pro korunuyor
- [ ] “Geri yükle” → owned hesapta Pro geri geliyor
- [ ] Pro’da banner / interstitial kapalı
- [ ] (Mümkünse) ownership: refund/notOwned sonrası davranış Console ile uyumlu
- [ ] Emülatör tek başına yeterli sayılmaz; license tester + fiziksel cihaz tercih

## Review access (inceleme)

Gerçek davranış (kod):

- Ayarlar’da sürüm satırına **7 tap** → review sheet
- Kod, yalnızca `--dart-define=REVIEW_ACCESS_CODE_SHA256=<hex>` hash’i ile doğrulanır
- Production’da hash **yapılandırılmamışsa** açılışta review bayrağı **kapatılır** (`main.dart`); Pro satın alma bayrağı silinmez
- `hasProFeatures` = gerçek Play Pro **veya** review access; billing UI gerçek Pro’ya bakar

Play Console **Notes for reviewers** (öneri — secret yazma):

- İnceleme erişiminin nasıl açılacağını (7 tap) belirt
- Gerekirse hash’li build’in nasıl üretildiğini dahili süreçte tut; plaintext kodu public note’a yapıştırma zorunlu değilse yapıştırma
- Bunun Play Billing bypass’ı değil, inceleme kolaylığı olduğunu kısaca belirt

## Data Safety (Play Console)

Formdaki beyanların **gerçek uygulama davranışıyla** eşleştiğini insan doğrula. Bu checklist hukuki metin üretmez.

Kontrol et:

- [ ] Advertising ID / ads (AdMob)
- [ ] Lokal finansal / kira verisi (SharedPreferences)
- [ ] Android Auto Backup (`allowBackup`)
- [ ] Billing (Play Billing / `kira_pro_lifetime`)

## Build / QA (özet)

- [ ] `flutter analyze` temiz
- [ ] `flutter test` geçiyor (IAP fake suite dahil)
- [ ] Signed `flutter build appbundle --release` (imza + AdMob gate açık)
- [ ] Closed testing opt-in / engagement (production access için operasyonel)

## Bilinçli olarak bu checklist’te yok

- CalculateScreen / büyük UI refactor
- Version bump (bu aday `1.1.1+21`)
- Firebase / Crashlytics zorunluluğu
