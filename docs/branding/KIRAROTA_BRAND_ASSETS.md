# KiraRota Brand Assets

Final branding pack. **Do not redesign** the KR monogram geometry.

Source masters were imported from temporary `Logo/` into this tree.

## Final colors (from source masters)

| Token | Hex | Notes |
|---|---|---|
| Dark forest green (plate / adaptive BG) | `#182E1D` | Median plate sample from `app_icon_master.png` |
| Symbol green (transparent KR) | `#183320` | Median opaque pixels from green symbol |
| Warm cream (KR on icon) | `#F4E5BC` | Median cream sample from app icon |
| Splash / app cream surface | `#FCF9F8` | Existing `AppColors.background` / `splash_background` |

App UI design tokens (`AppColors.primary` etc.) were **not** globally retuned; logo assets keep source tones.

## Master files

| Asset | Path | Use |
|---|---|---|
| App icon master | `assets/branding/kirarota/app_icon_master.png` | Play Store 512, legacy mipmap source (dark green rounded plate + cream KR) |
| Transparent green KR | `assets/branding/kirarota/symbol_green_transparent.png` | Splash / dark-on-cream brand mark |
| Transparent cream KR | `assets/branding/kirarota/symbol_cream_transparent.png` | Dark surfaces; adaptive FG source geometry |
| Monochrome KR | `assets/branding/kirarota/symbol_monochrome.png` | Android themed icon mask (white + alpha) |
| Splash symbol | `assets/branding/kirarota/splash_symbol.png` | Green KR centered on transparent canvas |

## Compat / build helpers

| Asset | Path | Use |
|---|---|---|
| Legacy image_path copy | `assets/branding/app_icon.png` | Same as master (flutter_launcher_icons / tools) |
| Adaptive FG 1024 | `assets/branding/app_icon_fg.png` | Cream KR in ~62% safe zone (no plate) |
| Splash drawable source | `assets/branding/splash_logo.png` | Copied into `android/.../drawable/splash_logo.png` |

These are **not** listed in Flutter `pubspec.yaml` `assets:` — they are Android / store tooling only (no duplicate runtime bundle).

## Android adaptive icon

- **Background:** solid `@color/ic_launcher_background` = `#182E1D`
- **Foreground:** `@drawable/ic_launcher_foreground` = cream transparent KR (safe zone)
- **Monochrome:** `@drawable/ic_launcher_monochrome` = white KR mask
- XML: `mipmap-anydpi-v26/ic_launcher.xml` + `ic_launcher_round.xml`
- Manifest: `android:icon` + `android:roundIcon`

**Rule:** never put the pre-rounded full plate into adaptive foreground (avoids double-frame).

## Play Store icon

Use `assets/branding/kirarota/app_icon_master.png` (also mirrored to `store/assets/app_icon_512x512.png`).

## Splash

- Background: `#FCF9F8`
- Icon: `@drawable/splash_logo` = transparent green KR (no wordmark, no plate)
- Themes: `values/styles.xml`, `values-night/styles.xml`, `values-v31/styles.xml`
- Legacy window: `drawable/launch_background.xml` (96dp centered mark)

## Wordmark

Horizontal wordmark is **compositional**, not a shipped PNG:

`[cream/green KR]  KiraRota`

- Use existing Inter / app text styles for “KiraRota”
- Do not invent a new display font file
- Runtime header remains text-only where the product UI already specifies that

## Regenerate

```bash
python tool/finalize_kirarota_branding.py
```

Requires masters under `assets/branding/kirarota/` (or temporary `Logo/` sources if re-importing).

## QA screenshots

See `docs/qa/branding/` when captured from emulator.
