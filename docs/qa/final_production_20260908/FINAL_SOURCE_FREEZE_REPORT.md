# KiraRota Final Source Freeze

**Tarih:** 2026-09-08  
**Rapor:** `docs/qa/final_production_20260908/FINAL_SOURCE_FREEZE_REPORT.md`

## Candidate

* App: KiraRota
* applicationId: `com.tyreest.kiraartisi`
* version: `1.1.1+20`
* targetSdk: 36
* Final AAB: `docs/qa/final_production_20260908/artifacts/app-release-1.1.1-20-after-fix.aab`

## AVD Rule

| | |
|---|---|
| Before | `Kira_Test_Pixel8` (yanlış) |
| After | `KiraRota_Test_Pixel8` (Pixel 8 · Android 16 / API 36) |
| Rule file | `.cursor/rules/kira-test-device.mdc` |
| Official AVD | `KiraRota_Test_Pixel8` |
| Serial notu | `emulator-5556` QA’da doğrulandı; kalıcı kimlik değildir |

Tarihsel QA raporu (`FINAL_PRODUCTION_QA_REPORT.md`) değiştirilmedi.

Working tree’de rule fix **hazır**; commit oluşmadığı için henüz Git history’de değil.

## Git Snapshot

| | |
|---|---|
| Previous HEAD | `3e23a3c8a3375f866cf41b14355f690b055d93ae` (`release: prepare KiraRota 1.1.1 build 14`) |
| New release commit | **NOT CREATED** |
| Commit message | *(planlanan)* `release: freeze KiraRota 1.1.1+20 production candidate` |
| Local tag | **NOT CREATED** (`kira-v1.1.1+20-production` mevcut değildi) |
| Tag message | *(planlanan)* `KiraRota 1.1.1+20 production candidate — final QA 2026-09-08` |

### Blocker

Repository’de `user.name` / `user.email` yapılandırması yok (local/global).  
Talimat gereği global config değiştirilmedi ve kimlik uydurulmadı → **commit/tag yapılamadı**.

## Working-tree classification (commit öncesi inceleme)

### A — Final candidate source (AAB’yi üreten ağaç; commit’e alınması gerekenler)

Modified tracked:

* `android/app/.../MainActivity.kt`, `android/gradle.properties`
* `assets/data/tufe_rates.json`, `assets/legal/yasal_uyari.md`, `hosted/tufe_rates.json`, `store/legal/yasal_uyari.md`
* `lib/**` (tüm listed modified UI/domain/services + `home_shell.dart` Back fix, `onboarding_screen.dart` text fix)
* `pubspec.yaml` (`1.1.1+14` → `1.1.1+20`)
* related `test/**` updates
* `tool/build_release_aab.ps1`
* delete: `tool/_inspect_ui.py`

Untracked source (build’e dahil / candidate ile ilişkili):

* `lib/core/money.dart`
* `lib/ui/widgets/calculation_info_sheet.dart`
* new hardening/polish tests under `test/`

### B — QA sırasındaki iki fix

* `lib/ui/home_shell.dart` — PopScope double-back
* `lib/ui/screens/onboarding_screen.dart` — `Politikası’nı`

### C — Bu görev AVD rule

* `.cursor/rules/kira-test-device.mdc`

### D — QA raporları (metin; binary hariç önerilen)

* `docs/qa/final_production_20260908/FINAL_PRODUCTION_QA_REPORT.md`
* `docs/qa/final_production_20260908/reports/*` (md/json)
* Bu freeze raporu

### E — Hariç bırakılacaklar (binary / junk / scratch)

* `docs/qa/**/artifacts/*.aab`, `*.apk`
* Büyük screenshot/log setleri (`docs/qa/ad_*`, `banner_*`, `final_prod` PNG/XML/log, `visual_*` PNG, zip)
* `s.png`, `scratch/**`
* Geçici QA scriptleri (`tool/final_production_20260908_qa*.py/ps1`, `tool/capture_clean_qa.ps1`) — isteğe bağlı; AAB kaynağı değil
* `KIRA_GOOGLE_PLAY_PRODUCTION_ACCESS_AUDIT.md` — ayrı audit WIP
* `C:\work\kira_rc_build` (repo dışı)

### F — Mixed WIP notu

Candidate source değişiklikleri büyük ölçüde release tree’nin kendisi (QA AAB bu working tree’den ASCII kopya ile üretildi). Exact binary/screenshot vs source ayrımı **güvenle yapılabilir**; source freeze engeli kimlik eksikliği, mixed WIP değil.

## Included Files

Commit oluşmadığı için dahil edilen dosya listesi yok.  
Yukarıdaki **A + B + C (+ opsiyonel D metin raporları)** stage edilmeliydi.

## Excluded / Remaining WIP

Commit dışında (working tree’de kaldı):

* Tüm modified/untracked candidate source (commit yok)
* Tüm QA screenshot/log/binary ağaçları
* `scratch/`, `s.png`
* Access audit md
* Secrets (gitignore’da; tracked değil)

## Secret Safety

| Dosya | Durum |
|---|---|
| `android/key.properties` | gitignore (`android/.gitignore`) — **tracked değil** |
| `android/admob.properties` | gitignore (kök `.gitignore`) — **tracked değil** |
| `*.jks` / `*.keystore` | gitignore — **tracked değil** |
| `.env` / credentials | commit adayında görülmedi |

History rewrite / secret cleanup yapılmadı.

## Artifact Verification

* Path: `docs/qa/final_production_20260908/artifacts/app-release-1.1.1-20-after-fix.aab`
* SHA-256 (yeniden hesap): `62F724F6BBBFBF808FBE5071AE14CB088BD1EC757853F2F85BDA86FAC38E4381`
* Beklenen ile: **birebir eşleşti**

**FINAL AAB HASH VERIFIED**

## Diff safety spot-checks (değişiklik yapılmadan)

* package: `com.tyreest.kiraartisi` — OK
* version: `1.1.1+20` — OK
* IAP: `kira_pro_lifetime` — OK
* Production AdMob: `String.fromEnvironment` + test publisher guard — OK
* `android.overridePathCheck=true` (en-dash path) — mevcut WIP, dokunulmadı
* Back fix + onboarding fix — working tree’de mevcut

## Remote Status

**NO PUSH PERFORMED**

## Final Result

# SOURCE FREEZE BLOCKED

**Neden:** Git `user.name` / `user.email` yok; commit/tag oluşturulamadı.  
**Tamamlanan:** AVD rule düzeltmesi (working tree), AAB SHA-256 doğrulama, sınıflandırma.  
**Sonraki adım (kullanıcı):** Local-only kimlik ayarla (`git config user.name` / `user.email` — global zorunlu değil), ardından freeze commit/tag’in tamamlanmasını iste.
