# Branding entegrasyon raporu

Tarih: 2026-08-07

## Launcher icon

- Kaynak: `assets/branding/app_icon.png` (1024×1024, final marka)
- Üretim: `dart run flutter_launcher_icons`
- Çıktı: `mipmap-*/ic_launcher.png` + adaptive XML
- Durum: **OK** — final Kira Asistanı ikonu uygulandı

## Adaptive icon

- Background: `#1F4E3D` (`ic_launcher_background`)
- Foreground: `assets/branding/app_icon_fg.png` (safe zone) + XML `inset="16%"`
- Mask önizleme: `store/assets/previews/adaptive_mask_{circle,squircle,rounded_rect}.png`
- Durum: **OK** — daire / squircle / rounded maskelerde logo kesilmiyor

## Splash / launch

- Zemin: `#FCF9F8` (`splash_background` = `AppColors.background` krem)
- Logo: `@drawable/splash_logo` (marka ikonu, ortalanmış)
- Dosyalar: `drawable/launch_background.xml`, `drawable-v21/…`, `values-night/styles.xml`
- Durum: **OK** — koyu orman yeşili + krem ailesiyle uyumlu; uygulama UI’ı değiştirilmedi

## Store assets (Play Console; AAB’de yok)

| Asset | Yol | Boyut | Durum |
|-------|-----|-------|--------|
| App icon | `store/assets/app_icon_512x512.png` | 512×512 | OK |
| Kaynak ikon | `store/assets/app_icon_source_1024x1024.png` | 1024×1024 | OK |
| Feature graphic | `store/assets/feature_graphic_1024x500.png` | 1024×500 | OK |
| Screenshot 01–05 | `store/assets/screenshots/01_…` … `05_…` | 1080×1920 | OK |

- `pubspec.yaml` assets listesinde `store/` **yok**
- Release AAB içinde marketing screenshot / feature graphic **yok**

## Build / test

- `flutter test` → **78/78 passed**
- `flutter build appbundle --release` → `build/app/outputs/bundle/release/app-release.aab`
