# Store assets — Kira Asistanı

Play Console’a yüklenecek marketing dosyaları. **Uygulama asset bundle’ına dahil edilmez** (`pubspec.yaml` → `store/` yok).

## Checklist

| Dosya | Boyut | Durum |
|-------|-------|--------|
| `app_icon_512x512.png` | 512×512 | Play Store ikonu |
| `app_icon_source_1024x1024.png` | 1024×1024 | Kaynak yüksek çözünürlük |
| `feature_graphic_1024x500.png` | 1024×500 | Feature graphic |
| `screenshots/01_hesapla_1080x1920.png` | 1080×1920 | Ekran görüntüsü 1 |
| `screenshots/02_sonuc_1080x1920.png` | 1080×1920 | Ekran görüntüsü 2 |
| `screenshots/03_tufe_oranlari_1080x1920.png` | 1080×1920 | Ekran görüntüsü 3 |
| `screenshots/04_yenileme_hatirlatmasi_1080x1920.png` | 1080×1920 | Ekran görüntüsü 4 |
| `screenshots/05_gecmis_pdf_1080x1920.png` | 1080×1920 | Ekran görüntüsü 5 |

## Uygulama içi branding (bundle’da)

| Kaynak | Kullanım |
|--------|----------|
| `assets/branding/app_icon.png` | Legacy / tam launcher kaynağı |
| `assets/branding/app_icon_fg.png` | Adaptive foreground (safe zone) |
| `assets/branding/splash_logo.png` | Android splash bitmap |

## Renk ailesi

- Orman yeşili (adaptive bg / marka): `#1F4E3D`
- Krem (splash / `AppColors.background`): `#FCF9F8`

## Adaptive mask önizleme

`previews/` altında circle / squircle mask kontrolleri. Logo safe zone içinde; kenar kesilmemeli.
