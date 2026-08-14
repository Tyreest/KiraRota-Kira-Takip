# Yenileme Tarihi Model Fix Raporu

**Tarih:** 13 Ağustos 2026  
**Sürüm:** `1.1.0+11` (`versionName` 1.1.0 / `versionCode` 11)  
**Paket:** `com.tyreest.kiraartisi`  
**Uygulama adı:** KiraRota  

---

## Root cause

Kayıtlı kira (Kira Ekle / Düzenle) formunda tek bir `increaseDate` / `renewalDate` alanı vardı. Kullanıcı **geçmiş bir son yenileme** tarihini (ör. 1 Temmuz 2026, bugün 13 Ağustos 2026) girdiğinde uygulama tarihi yalnızca “aksiyon tarihi” sanıp `days < 0` → **Yenileme geçti** gösteriyordu.

Gerçekte 39.000 TL gibi tutar o tarihte **zaten yenilenmiş mevcut kira** olabilir; bu durumda doğru model:

- `lastRenewalDate` = 1 Temmuz 2026  
- `nextRenewalDate` = 1 Temmuz 2027  

ve status **asla** “Yenileme geçti” olmamalıdır.

---

## Yeni domain model

`Rental` üzerinde:

| Alan | Anlam |
|------|--------|
| `increaseDate` / `nextRenewalDate` / `renewalDate` | Aksiyon alınacak **sonraki** yenileme (tek kaynak; getter alias’lar) |
| `lastRenewalDate` | Tamamlanmış son yenileme (opsiyonel) |
| `renewalResolved` | `null` = henüz migrate edilmemiş legacy; `true`/`false` = çözülmüş |

Backward compatibility: mevcut JSON anahtarları (`increaseDate`, `renewalDate`) korunur; yeni alanlar ek yazılır. Destructive rename yok.

Yıllık ileri taşıma: `nextIncreaseAnniversary` (date-only; 29 Şubat → 28 Şubat).

Status: `renewalStatusOf` yalnızca **nextRenewalDate** üzerinden:

- gelecek → `N gün kaldı`
- bugün → `Bugün` / `Bugün yenileniyor`
- geçmiş + resolved pending → **Yenileme geçti**
- `renewalResolved == false` → **Tarihi doğrula** (kırmızı overdue değil)

---

## Migration (idempotent)

`migrateRentalRenewal` / `RentalRepository.migrateRenewalsIfNeeded`:

1. `renewalResolved != null` → no-op  
2. Gelecek/bugün legacy `renewalDate` → `nextRenewalDate` olarak bırak, `renewalResolved = true`  
3. Geçmiş + history/snapshot o tarihi destekliyorsa → `last` + `next = +1 yıl`, resolved  
4. Belirsiz geçmiş → `renewalResolved = false` (**Tarihi doğrula**); kullanıcı confirmation ile bir kez çözer  

App açılışında migrate edilir; confirmation state resetlenmez.

---

## Past-date confirmation (yalnız saved rental)

Kira Ekle / Düzenle kaydında seçilen tarih bugünden önceyse sheet:

- Başlık: **Bu tarihte kira yenilendi mi?**  
- **Evet, yenilendi** → last + next year  
- **Hayır, yenileme bekliyor** → next = geçmiş tarih (overdue)  
- **Tarihi değiştir** → forma dön  

Manuel hesaplama ekranına uygulanmaz; tarih auto-roll yok.

Form helper: sonraki yenileme vurgusu + geçmişte kaydederken sorulacağı notu.

Belirsiz legacy kart/detayda aynı sheet açılır.

---

## Dashboard / Kiralarım / Detay

- Özet metrikler (Yaklaşan, Bu Ay), sıralama ve kart status → `nextRenewalDate`  
- Tamamlanmış `lastRenewalDate` upcoming/overdue’ya girmez  
- Gerçek overdue pending, Yaklaşan Yenilemeler listesinde **Yenileme geçti** ile görünür; Yaklaşan sayacı yalnızca gelecekteki next için artar  
- Detay / PDF-share: **Son yenileme** + **Sonraki yenileme**  

---

## Yeni dönem / reminder / backup

`applyCalculation`:

1. Eski next → `lastRenewalDate`  
2. `currentRent` güncellenir  
3. Immutable snapshot  
4. `next = last + 1 yıl`  
5. Reminder reschedule  

Reminder yalnızca `nextRenewalDate`; `renewalResolved == false` iken schedule edilmez. Notification ID stabil.

Backup/restore: rental `toJson` içinde `lastRenewalDate`, `nextRenewalDate`, `renewalResolved` taşınır; eski yedek restore + migrate doğru çalışır.

PRO arkasına alınmadı; Free de aynı correctness kullanır.

---

## Testler

- `flutter analyze` → **No issues found**  
- `flutter test` → **188 passed, 1 skipped**  
- Yeni regression: `test/renewal_date_model_test.dart` (A/B/C, migration, applyCalculation, backup roundtrip, leap day, manuel tarih roll yok)

---

## Emulator QA (`Kira_Test_Pixel8`)

Seed + UI dump (`tool/smoke_renewal_seed_qa.py`, `tool/smoke_renewal_bc_qa.py`):

| Senaryo | Sonuç |
|---------|--------|
| **A** completed past (last 1 Tem 2026 / next 1 Tem 2027) | `Yenileme geçti` yok; Yaklaşan=0 Bu Ay=0; 322 gün kaldı; detay Son/Sonraki doğru |
| **B** pending overdue (next 1 Tem 2026) | **Yenileme geçti** görünür |
| **C** future (15 Eyl 2026) | 33 gün kaldı; Yaklaşan=1 |

Ekran görüntüleri: `docs/qa/branding/renewal_scenario_{a,b,c}_*.png`

---

## Release artifacts

| Artifact | Path | SHA-256 |
|----------|------|---------|
| APK | `build/app/outputs/flutter-apk/app-release.apk` | `9AC8597BD16D0E9D11D2D64E9D5A544D6EAE9A8DF84C6FF36DAB309E5558E3B1` |
| AAB | `build/app/outputs/bundle/release/app-release.aab` | `7643208985CA7A2C05C558BC8D2F29E3E0ED35FA7EBB8F33756CAFD1DD2190B6` |

Doğrulama (aapt):

- package `com.tyreest.kiraartisi`  
- `versionName='1.1.0'` `versionCode='11'`  
- `targetSdkVersion='36'`  
- label `KiraRota`  

Play upload **yapılmadı**. Git push **yapılmadı**.

---

## FINAL GATE

Normal kullanıcı mevcut/zamlanmış kirasını geçmiş **son yenileme** tarihiyle ekleyip **Evet, yenilendi** seçtiğinde uygulama yanlışlıkla **Yenileme geçti** göstermez.

**Yenileme geçti** yalnızca gerçekten bekleyen ve tarihi geçmiş `nextRenewalDate` için kullanılır.
