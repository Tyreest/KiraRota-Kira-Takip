# Android Auto Backup / telefon değişimi

## Ne yedeklenir (Android Auto Backup / cihaz transferi)

SharedPreferences ve uygulama dosyaları (`backup_rules.xml` / `data_extraction_rules.xml`):

| Veri | Anahtar / alan |
|------|----------------|
| Hesaplama geçmişi | `history_v1` |
| Onboarding tamamlandı | `onboarding_done` |
| Hatırlatma tarihi / 30-7-0 tercihleri | `reminder_renewal_ms`, `reminder_d30`, `reminder_d7`, `reminder_d0` |
| Interstitial sayaç / cooldown | `ads_success_calc_count`, `ads_last_interstitial_ms` |
| Pro local önbellek (kanıt değil) | `is_pro_lifetime`, `pro_purchase_id` |

`android:allowBackup="true"` + cloud / device-transfer kuralları aktif.

## Ne yedeklenmez / yedeklenmemeli

| Madde | Not |
|-------|-----|
| Upload keystore / `key.properties` | App data dışında; XML’de de exclude |
| AdMob production secret dosyası | `android/admob.properties` (git ignore) |
| Debug-only değerler | Kaynak kodda |
| Planlı OS alarmları | Sistem alarmları backup ile gelmez — uygulama yeniden schedule eder |

## Pro entitlement

- Backup içindeki `is_pro_lifetime` **satın alma kanıtı değildir**.
- Açılışta `IapService.syncOwnershipFromStore()` Play ownership’i doğrular.
- Mağaza sorgusu başarısız → local önbellek korunur (offline).
- Mağaza başarılı + owned değil → local Pro kapatılır (refund/revoke).
- Pro, Google Play hesabından restore edilir (`restorePurchases` / ownership).

## Restore sonrası hatırlatmalar

1. Tercihler SharedPreferences’tan gelir.
2. `ReminderService.rescheduleSavedIfPossible()` açılışta ve `AppLifecycleState.resumed`’da çalışır.
3. Bildirim izni yoksa sessizce atlanır (crash yok).
4. Schedule: **inexact** (`inexactAllowWhileIdle`) — exact alarm izni yok.

## Garanti edilmeyen durumlar

- Kullanıcı Google / cihaz yedeğini kapatmış olabilir.
- Yeni telefonda restore kullanıcı onayı / hesap eşlemesine bağlıdır.
- Factory reset sonrası yedek bulutu yoksa veri gelmez.
- Emülatör / sideload APK backup davranışını doğrulamaz.

## Fiziksel cihazda doğrulanacaklar

- Google One / cihaz yedeği açıkken uninstall → reinstall veya yeni cihaz
- Hatırlatma tercihlerinin gelmesi + izin sonrası yeniden schedule
- Pro’nun Play hesabından geri gelmesi (local flag’e güvenilmeden)
