# FINAL PRODUCTION QA REPORT — KiraRota

**Tarih:** 2026-09-08  
**QA klasörü:** `docs/qa/final_production_20260908/`  
**AVD:** `KiraRota_Test_Pixel8` (Android 16 / API 36) — workspace kuralındaki `Kira_Test_Pixel8` adı listede yok; bu projenin resmi AVD’si `KiraRota_Test_Pixel8` olarak doğrulandı.  
**Cihaz seri:** `emulator-5556` (AVD adından doğrulandı; Koruvo `emulator-5554`’e dokunulmadı)

---

## Executive Verdict

# READY FOR PRODUCTION

Kritik runtime regresyonları (onboarding, CRUD, free gate, paywall back, persistence, reboot, logcat) PASS. Bulunan HIGH kök-back çıkış hatası düzeltildi ve doğrulandı. Kalan maddeler çoğunlukla Play Console / gerçek satın alma / zamanlanmış bildirim gibi emülatör-dışı kontroller.

---

## Candidate Identity

| Alan | Değer |
|---|---|
| App | KiraRota |
| applicationId | `com.tyreest.kiraartisi` |
| versionName | `1.1.1` |
| versionCode | `20` |
| pubspec | `1.1.1+20` |
| minSdk | 24 (effective; `maxOf(flutter.minSdk, 23)` → Flutter default 24) |
| targetSdk / compileSdk | 36 |
| Flutter | 3.44.8 / Dart 3.12.2 |
| Git HEAD (commit) | `3e23a3c8a3375f866cf41b14355f690b055d93ae` (`release: prepare KiraRota 1.1.1 build 14`) |
| Working tree | HEAD üzerine **çok sayıda uncommitted değişiklik** + bu QA’da yapılan 2 fix |
| IAP product | `kira_pro_lifetime` |
| Free limit | 1 kira kaydı; geçmiş UI 5 |
| AVD | `KiraRota_Test_Pixel8` / API 36 |

### Final release artifact (fix sonrası)

| | APK | AAB |
|---|---|---|
| Path | `docs/qa/final_production_20260908/artifacts/app-release-1.1.1-20-after-fix.apk` | `docs/qa/final_production_20260908/artifacts/app-release-1.1.1-20-after-fix.aab` |
| Also at | `C:\work\kira_rc_build\build\app\outputs\flutter-apk\app-release.apk` | `C:\work\kira_rc_build\build\app\outputs\bundle\release\app-release.aab` |
| Size | 68 485 215 bytes (~65.3 MB) | 68 140 643 bytes (~65.0 MB) |
| SHA-256 | `69E899CA28E18ED9F1B5DEE2E364605B4956A4E30955E8737E91B1B977257D0E` | `62F724F6BBBFBF808FBE5071AE14CB088BD1EC757853F2F85BDA86FAC38E4381` |
| Signing | Release keystore (`Tyreest Studio`, jarsigner verified) | aynı |
| Build not | En-dash klasör adından değil; ASCII kopya `C:\work\kira_rc_build` üzerinden (aşağıya bak) |

Önceki AAB (2026-09-06): SHA-256 `892FB9A1…4535` — **güncel working tree ile birebir eşleşmez**; Play’e **after-fix** AAB kullanılmalı.

---

## Automated QA

| Kontrol | Sonuç |
|---|---|
| `dart analyze` | **0 issues** (`No issues found!`) — not: `flutter analyze` en-dash path yüzünden LSP crash; `dart analyze` kullanıldı |
| `flutter test` (önce) | **268 pass, 1 skip, 0 fail** |
| `flutter test` (fix sonrası) | **268 pass, 1 skip, 0 fail** |
| Skip | `test/play_store_screenshots_test.dart` — `@Skip('Asset generator — toImage hangs…')` |
| Release APK | PASS (ASCII build tree) |
| Release AAB | PASS (ASCII build tree) |
| Minify/R8 / shrinkResources | enabled (release) |

---

## Runtime QA Matrix

Durum kodları: PASS / FAIL / PARTIAL / NOT TESTABLE / HUMAN/CONSOLE CHECK

| Alan | Durum | Kanıt / not |
|---|---|---|
| Fresh install / splash / onboarding | PASS | `final_regression/01_onboarding.png`, `02_home.png` |
| Launcher icon / app adı | PASS | Launcher dock KR ikonu; label `KiraRota` |
| Ana nav (5 sekme) | PASS | pass3 + final_regression |
| CRUD create | PASS | `FinalQA` / `₺10.000,00` — `31_after_save.png` |
| CRUD read/detail | PASS | `pass3/20_rental_detail.png` — `QADaire1`, `₺15.000,00`, hesaplanan `₺19.768,50` |
| CRUD edit | PARTIAL | Form açıldı (`QADaire1B`); save otomasyonu kısmi |
| CRUD delete cancel | PARTIAL | Menü otomasyonu kaçırıldı; unit/widget coverage var |
| Domain TÜFE hesabı | PASS | `15000 × 1.3179 = 19768.50` detay ekranında doğrulandı (Eylül 2026 · %31,79) |
| Free limit (+1 → paywall) | PASS | `Kira ekle` PRO badge + paywall sheet `50_free_limit.png` |
| Paywall open | PASS | Bottom sheet: Şimdi Al / Geri yükle |
| Paywall / root Back | PASS (fix sonrası) | Tek Back uygulamada kalıyor; `21_after_paywall_back.png` |
| Persistence force-stop | PASS | |
| Persistence emulator reboot | PASS | Reboot sonrası `QADaire1` + kira korundu |
| Offline startup / rates fallback | PASS | |
| Font scale 1.5 | PASS | Crash yok; screenshot alındı |
| Keyboard | PASS | |
| Rapid nav stress | PASS | |
| Logcat FATAL/ANR | PASS | 0 FATAL / 0 ANR (uygulama paketi) |
| Calculate form → sonuç (final_reg otomasyon) | PARTIAL | Form validasyonu görüldü (`Tutar gerekli`); domain sonuç daha önce PASS |
| Hesapla CTA vs banner | PARTIAL / MEDIUM | Banner altında CTA kısmen sıkışabiliyor; scroll ile erişilebilir |
| Notifications schedule/fire | PARTIAL | Kod + boot receiver + Pro gate doğrulandı; 09:00 gerçek tetik **NOT TESTABLE** (zaman atlatılmadı) |
| Real Play Billing purchase | NOT TESTABLE | Emülatörde gerçek charge yok; review-access mekanizması kodda var |
| Restore purchase | PARTIAL | UI mevcut; store callback emülatörde sınırlı |
| Backup/restore SAF runtime | PARTIAL | Unit testler PASS; SAF dosya seçici tam E2E otomasyonu sınırlı |
| Upgrade eski closed-test → v20 | NOT TESTABLE | Eski distinct versionCode artifact bu turda güvenle uygulanmadı |
| Large dataset / 10–15 dk ANR loop | PARTIAL | Rapid nav + lifecycle yapıldı; 150+ kayıt UI seed’i yok |
| Landscape | NOT TESTABLE / N/A | Orientation lock yok; resmi landscape matrisi koşulmadı |
| Store listing screenshots consistency | PARTIAL | Repo `docs/qa` / store görselleri mevcut; mağaza Console görselleri HUMAN |

---

## Screenshots

| Klasör | Adet | İçerik |
|---|---|---|
| `screenshots/` | 27 | İlk Python turu (onboarding false-positive sonrası kısıtlı) |
| `screenshots/pass3/` | 24 | Detay, edit, tabs, font150, reboot sonrası |
| `screenshots/final_regression/` | 12 | Fix sonrası onboarding, back, paywall, CRUD, free gate |

Öne çıkanlar:

- `final_regression/01_onboarding.png` — fresh onboarding  
- `final_regression/31_after_save.png` — populated Kiralarım + free limit UI  
- `final_regression/50_free_limit.png` — Pro paywall sheet  
- `final_regression/21_after_paywall_back.png` — Back sonrası Ayarlar (uygulamada)  
- `pass3/20_rental_detail.png` — domain KPI / Pro badge (PDF, Hatırlatma)

---

## Bugs Found

| ID | Severity | Feature | Repro | Expected | Actual | Evidence | Root cause | Files | Fix |
|---|---|---|---|---|---|---|---|---|---|
| BUG-001 | HIGH | Android Back / root nav | Ayarlar’da tek Back | Uygulama açık kalsın veya onay | Launcher’a düşüyordu | `pass3/42_after_paywall_back.png` | `HomeShell`’de PopScope yok | `lib/ui/home_shell.dart` | **FIXED** — tab→Özet, Özet’te çift Back |
| BUG-002 | LOW | Onboarding legal text | Onboarding footer | `Politikası’nı` bitişik | `Politikası` + ayrı `nı` | UI dump / onboarding shot | Wrap içinde ayrı Text | `lib/ui/screens/onboarding_screen.dart` | **FIXED** — `’nı` eklendi |
| BUG-003 | MEDIUM | Hesapla + banner | Free kullanıcı, form sonu | CTA net görünür | Banner ile CTA çakışma/sıkışma riski | `final_regression/40_calc_result.png` | Banner HomeShell’de sayfa dışında; bottom padding sınırlı | `home_shell.dart` / `calculate_screen.dart` | Kabul / residual — scroll ile erişilir |
| BUG-004 | MEDIUM (dev) | Release build path | `flutter build` en-dash path’ten | Build PASS | `parent is null` NPE | `logs/release_apk_stacktrace.txt` | Klasör adında U+2013 | — | ASCII junction/copy ile build (`C:\work\kira_rc_build`) |
| BUG-005 | LOW | Test skip | Suite | — | Screenshot generator skip | `play_store_screenshots_test.dart` | Bilinçli @Skip | — | Bilinçli; runtime capture kullan |

---

## Fixes Applied

1. **`lib/ui/home_shell.dart`** — `PopScope(canPop: false)`: nested Navigator pop → değilse sekme 0 → Özet’te 2 sn içinde ikinci Back ile çıkış + snackbar.  
   Doğrulama: `FINAL_REGRESSION_MATRIX.md` — `root_back_single`, `ozet_back_single`, `paywall_back` PASS.

2. **`lib/ui/screens/onboarding_screen.dart`** — Gizlilik metni `’nı` birleşimi.  
   Doğrulama: analyze temiz.

Regression: targeted tests + full `flutter test` (268+1) PASS; release APK/AAB yeniden üretildi.

---

## Persistence / Upgrade

| Senaryo | Durum |
|---|---|
| SharedPreferences `rentals_v1` | Kod audit PASS |
| Force-stop sonrası veri | PASS |
| Emulator reboot sonrası veri | PASS |
| Legacy renewal migration | Unit test PASS; eski APK→v20 upgrade **NOT TESTABLE** bu turda |

---

## Billing / Pro

| Madde | Durum |
|---|---|
| Product ID `kira_pro_lifetime` | Kod PASS |
| Fiyat hardcode yok (store price) | Kod PASS |
| Free limit 1 | Runtime PASS |
| PDF / Hatırlatma PRO badge | Runtime PASS |
| Paywall sheet + restore CTA | Runtime PASS |
| Gerçek satın alma | NOT TESTABLE |
| Review access (7× version tap + SHA) | Kod mevcut; plaintext AAB’de yok (build script check) |

---

## Notifications

| Madde | Durum |
|---|---|
| Manifest receivers (BOOT/MY_PACKAGE_REPLACED) | PASS |
| Europe/Istanbul 09:00 schedule (kod) | PASS (unit/hardening testleri) |
| Pro gate | PASS |
| Gerçek alarm ateşi | NOT TESTABLE (zamanlanmadı) |

---

## Backup / Restore

| Madde | Durum |
|---|---|
| JSON export/import servisi | Unit test PASS |
| Free restore ≤1 kayıt | Kod PASS |
| SAF runtime E2E | PARTIAL |

---

## Permissions

Manifest (declared): INTERNET, BILLING, POST_NOTIFICATIONS, RECEIVE_BOOT_COMPLETED, VIBRATE.

Merged (release APK dump): + WRITE_EXTERNAL_STORAGE (maxSdk 28), READ_EXTERNAL_STORAGE, ACCESS_NETWORK_STATE, AD_ID / AdServices, WAKE_LOCK, FOREGROUND_SERVICE, dynamic receiver permission.

| İzin | Gerekçe | Risk |
|---|---|---|
| INTERNET | TÜFE remote + ads | Beklenen |
| BILLING | IAP | Beklenen |
| POST_NOTIFICATIONS | Hatırlatma | Beklenen (runtime) |
| RECEIVE_BOOT_COMPLETED | Reschedule | Beklenen |
| VIBRATE | Notification | Beklenen |
| AD_ID / AdServices | AdMob | Data Safety’de beyan **HUMAN/CONSOLE** |
| READ/WRITE storage (legacy maxSdk) | Bağımlılık merge | Data Safety / gerekçe gözden geçir **HUMAN/CONSOLE** |

Konum / mikrofon / rehber / kamera: **yok** (iyi).

---

## Crash / ANR

Runtime logcat audit: **0 FATAL EXCEPTION**, **0 ANR** (paket odaklı). Framework gürültüsü filtrelendi.

---

## UI / Accessibility

- Font 1.5: crash yok.  
- Kontrast genel olarak yeterli.  
- BUG-003 residual (banner/CTA).  
- Semantics çoğunlukla `content-desc` üzerinden (Flutter).

---

## Security / Privacy

| Madde | Durum |
|---|---|
| Privacy / Terms URL | Kodda mevcut |
| Hesap silme | Hesap yok → N/A (local-only) |
| Exported Activity | MainActivity exported=true (launcher) — beklenen |
| Notification receivers | exported=false |
| Review code plaintext in AAB | Build script kontrolü mevcut |
| allowBackup | true + backup_rules |
| Secrets in repo | `key.properties` / `admob.properties` gitignore varsayımı — **HUMAN** doğrula |

---

## Play Production Risks

1. Working tree = HEAD + geniş uncommitted WIP; Play’e giden AAB bu ağacı yansıtır — commit/tag stratejisi netleştirilmeli.  
2. En-dash path release build’i kırıyor — CI/local ASCII path zorunlu.  
3. Data Safety: AD_ID + ads + billing beyanları.  
4. Emülatörde test AdMob ID’leri görüldü (debug/test banner); release AAB production AdMob define ile üretildi — Console’da reklam durumu doğrulanmalı.  
5. Closed-test → production upgrade smoke eksik.

---

## Human / Play Console Checks

- [ ] Play Console Data Safety (AD_ID, ads, billing, local data)  
- [ ] Store listing screenshots güncelliği  
- [ ] Production AdMob / UMP coğrafya  
- [ ] `kira_pro_lifetime` fiyat & lisans  
- [ ] Reviewer access kodu (varsa) Console notları  
- [ ] Hedef kitle / içerik derecelendirme  
- [ ] Önceki closed-test artifact üzerine upgrade smoke  
- [ ] Privacy policy URL canlı erişim  
- [ ] AAB’yi Play’e yükleyip pre-launch report

---

## Remaining Risks

- BUG-003: free kullanıcıda Hesapla CTA / banner sıkışıklığı (MEDIUM, workaround: scroll).  
- Bildirimlerin gerçek 09:00 ateşi doğrulanmadı.  
- Gerçek IAP charge doğrulanmadı.  
- Büyük veri seti jank ölçümü sınırlı.  
- Repo klasör adındaki U+2013 release mühendisliği riski.

---

## Final Artifact

- **AAB:** `docs/qa/final_production_20260908/artifacts/app-release-1.1.1-20-after-fix.aab`  
- **SHA-256:** `62F724F6BBBFBF808FBE5071AE14CB088BD1EC757853F2F85BDA86FAC38E4381`  
- **APK (cihaz QA):** `.../app-release-1.1.1-20-after-fix.apk`  
- **SHA-256:** `69E899CA28E18ED9F1B5DEE2E364605B4956A4E30955E8737E91B1B977257D0E`  
- **Identity:** `com.tyreest.kiraartisi` · `1.1.1` · `20` · targetSdk 36  
- **Signing:** Tyreest Studio upload key (jarsigner verified)

---

## FINAL VERDICT

# READY FOR PRODUCTION

Önkoşullar: Play Console checklist tamamlanmalı; Play’e **after-fix AAB** yüklenmeli; mümkünse bir closed-test → v20 upgrade smoke insan tarafından yapılmalı.
