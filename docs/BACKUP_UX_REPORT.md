# Yedekleme UX — Final Rapor

Tarih: 2026-08-13  
Sürüm: **1.1.0+10** (bump yok)  
Cihaz QA: `Kira_Test_Pixel8` (`emulator-5554`)

## Copy

| Eski | Yeni |
|---|---|
| Kira verilerini JSON olarak paylaş | **Yedek oluştur** |
| — | **Yedeği geri yükle** |
| Teknik JSON paylaşım açıklaması | Kira kayıtlarının cihazında saklayabileceğin bir yedeğini oluştur. |

Normal UI’da “JSON” kelimesi yok.

## Backup dosya formatı

- Dosya adı: `KiraRota-Yedek-YYYY-MM-DD.json`
- MIME: `application/json`
- Payload (mevcut şema, değişmedi):

```json
{
  "app": "KiraRota",
  "exportedAt": "<ISO-8601>",
  "rentals": [ /* Rental.toJson() */ ]
}
```

Geçici dosya: cache/temp altında üretilir; share/save sonrası dispose + eski `KiraRota-Yedek-*.json` temizliği.

## Save / Share / Restore

- **Cihaza Kaydet:** `FileSaver` SAF (`MimeType.json`) — konum kullanıcı seçer; iptal hata sayılmaz; başarı snackbar: `Yedek kaydedildi`
- **Paylaş:** `SharePlus` **dosya eki** (`XFile` + `application/json`); kısa metin yalnızca `KiraRota yedeği` — ham JSON body yok
- **Yedeği geri yükle:** native `ACTION_OPEN_DOCUMENT` (MethodChannel) → validate → onay diyaloğu → `replaceAll` + hatırlatma reschedule
- Geçersiz dosya: `Bu dosya geçerli bir KiraRota yedeği değil.`

## Test / QA

- `flutter analyze`: clean
- `flutter test`: **174 geçti** (+1 skip)
- Emulator: Ayarlar → Yedek oluştur → Yedek hazır sheet → Paylaş → share sheet’te ham JSON yok; `KiraRota` hedefi görünüyor

## Release (Play upload / push yok)

| Artefact | SHA-256 |
|---|---|
| `build/app/outputs/flutter-apk/app-release.apk` | `0A717356A616D6D067AC4F4FE7697E657214D4061FDC71C3D3E07F9ED0496655` |
| `build/app/outputs/bundle/release/app-release.aab` | `0751EC103C1D596075EFE7ABC723A40E947ED0A4FE202433DCFE0F83B4D288BF` |

## Ana dosyalar

- `lib/services/rental_backup_service.dart`
- `lib/ui/widgets/backup_ready_sheet.dart`
- `lib/ui/screens/settings_screen.dart`
- `lib/data/rental_repository.dart` (`replaceAll`)
- `lib/providers/app_providers.dart` (`restoreRentals`)
- `android/.../MainActivity.kt` (SAF pick channel)
- `test/rental_backup_test.dart`
