# KiraRota

Kira takibi ve TÜFE 12 aylık ortalama esaslı azami kira artışı hesabı.

| | |
|---|---|
| Uygulama adı | **KiraRota** |
| Sürüm (release adayı) | **1.1.1+21** |
| applicationId | `com.tyreest.kiraartisi` |
| Pro ürün | `kira_pro_lifetime` (lifetime, non-consumable) |
| Oranlar | `assets/data/tufe_rates.json` + remote fallback |
| Remote JSON | `https://raw.githubusercontent.com/Tyreest/KiraRota-Kira-Takip/main/hosted/tufe_rates.json` |
| Repo klasörü | `KiraRota–KiraTakip` (pub package adı: `kira_artisi_hesapla`) |

Fiyat Play Billing `ProductDetails.price` ile gelir; uygulamada sabit ₺ fiyat yoktur.

## Çalıştırma

```bash
cd C:\Users\yigit\Desktop\Projeler\KiraRota–KiraTakip
flutter pub get
flutter test
flutter run
```

Tam yeniden başlatma (plugin’ler için): uygulamayı durdurup tekrar `flutter run`.

## Pro özellikler

| Özellik | Durum |
|---------|--------|
| Reklamsız | Hazır — Pro / review-access’te reklam kapalı |
| PDF özet | Hazır |
| Yenileme hatırlatması 30/7/0 | Hazır (bildirim izni gerekir) |
| Sınırsız geçmiş / ek kira | Hazır (Free: 1 kira, geçmiş UI limiti 5) |
| Play Billing | Hazır — Console’da ürün + license tester gerekir |

## AdMob (debug vs release)

- **Debug:** Google resmi test App/Banner/Interstitial ID’leri (`AppConstants` + Gradle debug placeholder).
- **Release:** Production ID zorunlu. `android/admob.properties` (veya `ADMOB_*` env) yoksa / boşsa veya Google test publisher (`3940256099942544`) içeriyorsa **release build FAIL** (`android/app/build.gradle.kts`).
- Test publisher / test unit ID’leri release AAB’ye **girmez**.

Ayrıntılı checklist: [`store/RELEASE_CHECKLIST.md`](store/RELEASE_CHECKLIST.md).

## Release imza

`android/key.properties` yoksa release AAB üretilmez (debug imza ile release yok). Adımlar: [`store/signing.md`](store/signing.md).

## Play Console notları

1. Managed product: `kira_pro_lifetime` (tek seferlik lifetime)
2. AdMob: release için production App ID + banner + interstitial (`admob.properties` / env)
3. Data Safety formunu gerçek davranışla insan doğrula (reklam, lokal kira verisi, backup, billing) — bkz. release checklist
4. İnceleme erişimi: production build’de `REVIEW_ACCESS_CODE_SHA256` dart-define ile yapılandırılır; hash yoksa review bayrağı açılışta kapatılır. Plaintext kodu repoya / README’ye yazma. Reviewer notes için bkz. checklist.

## Remote oran

Host edilen dosya: `hosted/tufe_rates.json`  
Uygulama sabiti: `AppConstants.remoteRatesUrl`  
Remote başarısız / eski ise **asset** (`assets/data/tufe_rates.json`) fallback.

Release öncesi: remote erişilebilir mi, hosted + asset güncel mi → [`store/RELEASE_CHECKLIST.md`](store/RELEASE_CHECKLIST.md).

## Test

```bash
flutter analyze
flutter test
flutter test test/iap_service_test.dart
```

IAP birim testleri `BillingGateway` fake’i kullanır; gerçek Play’e bağlanmaz.
