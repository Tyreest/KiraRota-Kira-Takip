# Production readiness raporu — Backup / Bildirim / Reklam

Tarih: 2026-08-07  
`flutter test`: **78/78 geçti**

## 1. Değiştirilen / eklenen dosyalar

| Dosya | Değişiklik |
|-------|------------|
| `android/app/src/main/AndroidManifest.xml` | Auto Backup, AdMob placeholder, exact alarm izni kaldırıldı |
| `android/app/src/main/res/xml/backup_rules.xml` | Yeni |
| `android/app/src/main/res/xml/data_extraction_rules.xml` | Yeni |
| `android/app/build.gradle.kts` | Debug/release AdMob App ID placeholder |
| `android/admob.properties.example` | Yeni |
| `lib/core/constants.dart` | Test/production AdMob ayrımı, interstitial sabitleri |
| `lib/services/ads_service.dart` | Adaptive banner + interstitial gate |
| `lib/services/reminder_service.dart` | İzin yok açılışta; inexact schedule; reschedule |
| `lib/ui/screens/reminder_screen.dart` | Permission UX, Kaldır koşullu |
| `lib/ui/home_shell.dart` | Banner yalnızca Hesapla/Oranlar/Geçmiş |
| `lib/ui/screens/calculate_screen.dart` | Interstitial hook (sonuç engellenmez) |
| `lib/main.dart` | Reschedule + Pro→ads kapatma |
| `lib/data/local_store.dart` | Pro backup kanıt değil notu |
| `pubspec.yaml` | `permission_handler` |
| `store/BACKUP.md` | Yeni |
| `test/production_readiness_test.dart` | Yeni |
| `test/audit_checklist_test.dart` | AdMob sabit güncellemesi |

Hesap motoru / TÜFE remote / Billing purchase-restore-revoke **değiştirilmedi**.

## 2–3. Android backup

- `allowBackup=true` + `fullBackupContent` + `dataExtractionRules`
- Yedeklenen: geçmiş, onboarding, hatırlatma tercihleri, interstitial sayaç, Pro **önbellek** (kanıt değil)
- Yedeklenmeyen: keystore, `key.properties`, `admob.properties`
- Detay: `store/BACKUP.md`

## 4. Notification permission akışı

1. Açılış / onboarding / Pro satın alma → **izin yok**
2. Hatırlatmayı Kaydet → açıklama sheet → sistem dialog
3. Granted → schedule (inexact)
4. Denied → tercihler saklanır; “Bildirimler kapalı” + Ayarları Aç
5. Permanently denied → sheet yok, Ayarları Aç

## 5. Reminder reschedule

- `init()` permission istemez
- `rescheduleSavedIfPossible()`: açılış + `AppLifecycleState.resumed`
- Boot receiver (mevcut plugin) duruyor
- `AndroidScheduleMode.inexactAllowWhileIdle` (exact alarm yok)

## 6–7. Banner

**Gösterilir (Free):** Hesapla form/sonuç (shell), Oranlar, Geçmiş  
**Gösterilmez:** Onboarding, Ayarlar, Reminder route, Paywall (sheet), Pro kullanıcı

Layout: CONTENT → Divider → Ad area → spacing → BottomNav

## 8. Interstitial

- Yalnızca başarılı hesapta count++
- `count % 3 == 0` **ve** son gösterim ≥ 10 dk
- 1–2: yok; 3: aday; cooldown dolmamışsa yok; 6+cooldown: aday
- Load fail → doğrudan sonuç
- Pro / preload discard → gösterilmez

## 9. Debug / release AdMob

| | Debug | Release |
|--|-------|---------|
| Dart unit ID | Google test | `admob.properties` → `--dart-define` (`tool/build_release_aab.ps1`) |
| Manifest App ID | Google test | `android/admob.properties` / `ADMOB_APP_ID` |

Production ID’ler `android/admob.properties` içinde (gitignore). Eksikse veya Google test publisher sızmışsa release **FAIL**.  
Ayrıntı + cihaz checklist: `store/ADMOB.md`.

## 10. Pro → reklam kapanması

`isProProvider` listener + `AdsService.setAdsEnabled(false)` + `discardPreloadedInterstitial()`; HomeShell banner koşulu `!isPro`.

## 11. Testler

`test/production_readiness_test.dart`: backup/serialization, interstitial gate, permission dialog yok, Kaldır görünürlüğü, onboarding/ayarlar/Pro’da banner yok, AdMob guard.

## 12–13. Build

- `flutter test`
- Release AAB: `powershell -File tool/build_release_aab.ps1` (AdMob dart-define + doğrulama)

## 14. Fiziksel cihaz

- Auto Backup / yeni telefon restore
- Bildirim izni sheet → sistem dialog → schedule
- Permanently denied → Ayarları Aç
- Reboot sonrası reschedule
- Adaptive banner gerçek yükleme
- Interstitial 3. hesap + 10 dk cooldown
- Pro sonrası banner/interstitial kaybolması

## 15. Play Internal Testing

- Billing purchase/restore/revoke (önceki checklist)
- Production AdMob: `store/ADMOB.md` (test device; production reklama tıklama)
- License tester + Internal AAB
