# KiraRota — IAP Test & Release Doc Hardening Report

**Tarih:** 2026-09-09  
**Release adayı:** `1.1.1+21` (`com.tyreest.kiraartisi`)  
**Kapsam:** IAP otomatik test suite + README / release dokümantasyonu güçlendirme  
**Git:** commit / push / tag **yapılmadı** (istendiği gibi)

---

## Executive Summary

Bu turda production IAP / entitlement / ads / calculation davranışına **dokunulmadı**.  
Mevcut `BillingGateway` soyutlaması üzerinden deterministik `FakeBillingGateway` + **22** yeni `IapService` birim testi eklendi.  
README drift giderildi; `store/RELEASE_CHECKLIST.md` oluşturuldu; `store/signing.md` klasör yolu güncellendi.

| Soru | Cevap |
|------|--------|
| Production behavior değişti mi? | **Hayır** |
| Teknik blocker var mı? | **Hayır** |
| `flutter test` | **290 passed, 1 skipped** |
| `dart analyze` (paket) | **No issues found** |
| Final verdict | **PASS — SAFE TO KEEP CURRENT RELEASE CANDIDATE** |

---

## Files Changed

| Dosya | Değişiklik | Neden |
|-------|------------|--------|
| `test/fakes/fake_billing_gateway.dart` | **Yeni** — fake gateway + `ProductDetails` / `PurchaseDetails` yardımcıları | Gerçek Play’e bağlanmadan IAP senaryoları |
| `test/iap_service_test.dart` | **Yeni** — 22 birim test | Owned / notOwned / timeout / exception / restore / catalog / purchase / idempotency |
| `README.md` | Marka, sürüm, path, AdMob/imza/remote/IAP notları | Eski “Kira Artışı Hesapla” / sabit ₺199 / test-banner drift |
| `store/RELEASE_CHECKLIST.md` | **Yeni** checklist | AdMob gate, signing, TÜFE remote, IAP smoke, review access, Data Safety doğrulama |
| `store/signing.md` | Klasör path `KiraRota–KiraTakip` | Eski `kira-artisi-hesapla` path drift |
| `docs/qa/_iap_hardening_*.txt` | Analyze/test log çıktıları | Bu turun QA kanıtı (rapor yardımcıları) |

**Production kod (`lib/`, `android/` uygulama mantığı):** değiştirilmedi.

---

## IAP Test Coverage

Fake: `test/fakes/fake_billing_gateway.dart`  
Suite: `test/iap_service_test.dart` (22 test, hepsi PASS)

| Scenario | Test | Result |
|----------|------|--------|
| Owned | `gateway owned → Pro aktif + persist + revoke yok`; `local Free iken owned restore → Pro grant` | **PASS** |
| Not owned | `başarılı notOwned + local Pro → revoke / Free`; `notOwned + zaten Free → revoke callback yok` | **PASS** |
| Timeout | `timeout → local Pro korunur, revoke yok` (+ restore timeout) | **PASS** |
| Exception | `restore exception → local Pro korunur`; `purchaseStream error → probe fail → Pro korunur` | **PASS** |
| Restore | owned / timeout / notOwned / exception | **PASS** |
| Product unavailable | boş katalog + sessiz restore → fiyat yok, Pro korunur; `queryProductDetails` exception | **PASS** |
| Billing unavailable | `available=false` → Pro korunur, buy=`storeUnavailable`, restore dinlenmez | **PASS** |
| Purchase success | stream `purchased` → Pro + `completePurchase` | **PASS** |
| Purchase cancel | `canceled` → Pro verilmez | **PASS** |
| Purchase pending | `pending` → flag, Pro verilmez | **PASS** |
| Purchase error | `error` → Pro verilmez | **PASS** |
| alreadyOwned buy path | buy throws alreadyOwned → sync owned → `BuyLaunchResult.alreadyOwned` | **PASS** |
| Idempotency | çift `init` → tek `purchaseStream` listen; eşzamanlı `syncOwnership` → tek in-flight | **PASS** |

### Desteklenmeyen / bilinçli sınırlar

| Konu | Not |
|------|-----|
| Gerçek Google Play / network | Bilinçli olarak yok — unit fake |
| UI paywall widget smoke | Bu turda yok (birim seviye) |
| Çift `init`’in `_onProChanged` overwrite | Mevcut davranış; dinleyici tek (`_sub ??=`); yeniden tasarlanmadı |
| Integration / `integration_test` | Eklenmedi (istenmedi) |

Timeout testleri kısa `ownershipSyncTimeout` (40 ms) + `silenceRestore` ile deterministik; flaky wall-clock yok.

---

## QA

### Analyze

| Komut | Sonuç |
|-------|--------|
| `dart analyze` (tüm paket) | **No issues found** (exit 0) |
| `dart analyze` (IAP dosyaları) | **No issues found** (exit 0) |
| `flutter analyze` | **Araç hatası** — analysis server, proje path’teki en-dash (`KiraRota–KiraTakip` → `%E2%80%93`) yüzünden `FormatException: Unexpected end of input`. Kod sorunu değil; `dart analyze` ile doğrulandı. |

### Test

| Komut | Sonuç |
|-------|--------|
| `flutter test test/iap_service_test.dart` | **22 passed** |
| `flutter test` (full) | **290 passed, 1 skipped** |

**Yeni test sayısı:** **22** (`iap_service_test.dart`) + 1 fake helper dosyası.

**Skip:** Asset generator / `toImage` suite hang — önceden var olan skip (`Skip: Asset generator — toImage hangs in suite…`). Bu turla ilgili değil.

**Fail:** yok.

Loglar:

- `docs/qa/_iap_hardening_iap_test.txt`
- `docs/qa/_iap_hardening_flutter_test.txt`
- `docs/qa/_iap_hardening_dart_analyze_full.txt`

---

## Documentation Hardening

### README.md

- Marka: **KiraRota**, sürüm **1.1.1+21**
- Çalıştırma path: `KiraRota–KiraTakip`
- Sabit “₺199” fiyat iddiası kaldırıldı (fiyat Play’den)
- Debug test ads vs release production AdMob gate açıklandı
- Signing + checklist linkleri
- Remote TÜFE URL (repodan doğrulanmış) + asset fallback
- Review access: hash dart-define, plaintext yok; checklist’e yönlendirme
- IAP unit test komutu

### store/RELEASE_CHECKLIST.md (yeni)

- Kimlik / imza / AdMob gate
- TÜFE remote + hosted + asset maddeleri
- Gerçek cihaz / license tester IAP smoke
- Review access (7-tap, hash, production’da hash yoksa kapanma) — secret yok
- Data Safety insan doğrulama (AD_ID/ads, lokal kira verisi, backup, billing) — hukuki metin uydurulmadı

### store/signing.md

- Eski klasör path → `KiraRota–KiraTakip`

---

## Production Code Changes

**NONE**

`iap_service.dart`, provider’lar, Free/Pro limitleri, AdMob frequency, calculation, UI ekranları, versionCode/Name değiştirilmedi.  
Kanıtlanmış IAP bug bulunmadığı için production düzeltmesi yapılmadı.

---

## Remaining Risks

| # | Başlık | Etiket | Not |
|---|--------|--------|-----|
| 1 | Play closed-test / production access | **HIGH** | Teknik blocker yok; opt-in / engagement / track süreci |
| 2 | Data Safety + gerçek cihaz billing smoke | **HIGH** | Checklist eklendi; Console + license tester hâlâ insan işi |
| 3 | CalculateScreen refactor | **MEDIUM** | Bilinçli ertelendi; davranış riski değil bakım riski |
| 4 | Diğer büyük UI ekranları | **MEDIUM** | Aynı — bu turda dokunulmadı |
| 5 | Remote TÜFE operasyonu | **LOW** | Checklist maddesi var; runtime fallback zaten kodda |
| 6 | Review access documentation | **DONE** | README + checklist (secret’sız) |
| 7 | Crashlytics / observability | **LOW** | Bilinçli minimal stack; production access şartı değil |
| 8 | IAP otomatik test boşluğu | **DONE** | 22 senaryo fake gateway ile kapatıldı |
| 9 | README / release doc drift | **DONE** | Bu turda giderildi |

---

## Final Verdict

### PASS — SAFE TO KEEP CURRENT RELEASE CANDIDATE

`1.1.1+21` release adayı için bu tur:

- production davranışını değiştirmedi,
- IAP entitlement sözleşmesini otomatik testlerle güvenceye aldı,
- release/bakım dokümantasyonunu güncelledi,
- blocker üretmedi.

**Takip (kod dışı):** closed-test engagement + Data Safety formu + fiziksel cihaz IAP smoke (`store/RELEASE_CHECKLIST.md`).
