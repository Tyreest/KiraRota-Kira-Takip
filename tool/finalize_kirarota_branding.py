# -*- coding: utf-8 -*-
"""Finalize KiraRota branding from Logo/ source masters.

SOURCE OF TRUTH (do not redesign geometry):
  Logo/KiraIconLogoDuzen.png  — dark green rounded plate + cream KR
  Logo/KiraLogo.png           — transparent dark-green KR

Outputs masters under assets/branding/kirarota/ and Android launcher/splash
resources. Does not invent new logo forms.
"""
from __future__ import annotations

import shutil
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SRC_ICON = ROOT / "Logo" / "KiraIconLogoDuzen.png"
SRC_SYMBOL = ROOT / "Logo" / "KiraLogo.png"
BRAND = ROOT / "assets" / "branding" / "kirarota"
COMPAT = ROOT / "assets" / "branding"
STORE = ROOT / "store" / "assets"
RES = ROOT / "android" / "app" / "src" / "main" / "res"

# Fallback when temporary Logo/ is removed after import.
MASTER_ICON = BRAND / "app_icon_master.png"
MASTER_SYMBOL = BRAND / "symbol_green_transparent.png"

# Sampled from Logo masters (median plate / cream / symbol).
GREEN_BG = (0x18, 0x2E, 0x1D, 255)  # #182E1D adaptive + legacy plate fill
CREAM = (0xF4, 0xE5, 0xBC, 255)  # #F4E5BC
SYMBOL_GREEN = (0x18, 0x33, 0x20, 255)  # #183320 (from KiraLogo median)

FG_SIZES = {
    "drawable-mdpi": 108,
    "drawable-hdpi": 162,
    "drawable-xhdpi": 216,
    "drawable-xxhdpi": 324,
    "drawable-xxxhdpi": 432,
}
LEGACY_SIZES = {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192,
}


def copy_master(src: Path, dest: Path) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dest)
    print(f"master copy {src.name} -> {dest.relative_to(ROOT)}")


def content_bbox(im: Image.Image) -> tuple[int, int, int, int]:
    return im.split()[-1].getbbox() or (0, 0, im.width, im.height)


def recolor_keep_alpha(src: Image.Image, rgb: tuple[int, int, int]) -> Image.Image:
    im = src.convert("RGBA")
    px = im.load()
    w, h = im.size
    r0, g0, b0 = rgb
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a <= 0:
                px[x, y] = (0, 0, 0, 0)
            else:
                px[x, y] = (r0, g0, b0, a)
    return im


def place_in_canvas(
    symbol: Image.Image,
    canvas: int,
    fill_ratio: float,
) -> Image.Image:
    bbox = content_bbox(symbol)
    cropped = symbol.crop(bbox)
    out = Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
    target = max(1, int(canvas * fill_ratio))
    cw, ch = cropped.size
    scale = min(target / cw, target / ch)
    nw, nh = max(1, int(cw * scale)), max(1, int(ch * scale))
    resized = cropped.resize((nw, nh), Image.Resampling.LANCZOS)
    ox = (canvas - nw) // 2
    oy = (canvas - nh) // 2
    out.alpha_composite(resized, (ox, oy))
    return out


def write_colors() -> None:
    colors = RES / "values" / "colors.xml"
    colors.write_text(
        """<?xml version="1.0" encoding="utf-8"?>
<resources>
    <!-- Sampled from Logo/KiraIconLogoDuzen plate (median dark forest green) -->
    <color name="ic_launcher_background">#182E1D</color>
    <!-- Warm cream splash — AppColors.background ile uyumlu -->
    <color name="splash_background">#FCF9F8</color>
</resources>
""",
        encoding="utf-8",
    )
    print("wrote values/colors.xml")


def write_adaptive_xml() -> None:
    anydpi = RES / "mipmap-anydpi-v26"
    anydpi.mkdir(parents=True, exist_ok=True)
    xml = """<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background"/>
    <foreground android:drawable="@drawable/ic_launcher_foreground"/>
    <monochrome android:drawable="@drawable/ic_launcher_monochrome"/>
</adaptive-icon>
"""
    (anydpi / "ic_launcher.xml").write_text(xml, encoding="utf-8")
    (anydpi / "ic_launcher_round.xml").write_text(xml, encoding="utf-8")
    print("wrote mipmap-anydpi-v26 adaptive XMLs")


def assert_transparent_corners(im: Image.Image, label: str) -> None:
    w, h = im.size
    for pt in ((0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)):
        a = im.getpixel(pt)[3]
        assert a == 0, f"{label} corner {pt} not transparent: {im.getpixel(pt)}"


def main() -> None:
    BRAND.mkdir(parents=True, exist_ok=True)

    src_icon = SRC_ICON if SRC_ICON.is_file() else MASTER_ICON
    src_symbol = SRC_SYMBOL if SRC_SYMBOL.is_file() else MASTER_SYMBOL
    if not src_icon.is_file() or not src_symbol.is_file():
        raise SystemExit(
            "Missing branding sources (Logo/ or assets/branding/kirarota masters)"
        )

    # --- Masters (byte-copy when importing from Logo/; otherwise keep masters) ---
    app_icon_master = BRAND / "app_icon_master.png"
    symbol_green = BRAND / "symbol_green_transparent.png"
    if src_icon.resolve() != app_icon_master.resolve():
        copy_master(src_icon, app_icon_master)
    else:
        print(f"using existing {app_icon_master.relative_to(ROOT)}")
    if src_symbol.resolve() != symbol_green.resolve():
        copy_master(src_symbol, symbol_green)
    else:
        print(f"using existing {symbol_green.relative_to(ROOT)}")

    green = Image.open(symbol_green).convert("RGBA")
    assert_transparent_corners(green, "symbol_green")
    opaque = sum(1 for p in green.getdata() if p[3] > 20)
    assert opaque > 1000, f"green symbol empty ({opaque})"

    # Cream / monochrome share green geometry + alpha
    cream = recolor_keep_alpha(green, CREAM[:3])
    cream_path = BRAND / "symbol_cream_transparent.png"
    cream.save(cream_path, "PNG")
    print(f"wrote {cream_path.relative_to(ROOT)}")

    mono = recolor_keep_alpha(green, (255, 255, 255))
    mono_path = BRAND / "symbol_monochrome.png"
    mono.save(mono_path, "PNG")
    print(f"wrote {mono_path.relative_to(ROOT)}")

    # Splash: green KR, medium size, transparent canvas (no plate)
    splash = place_in_canvas(green, 1024, 0.42)
    splash_path = BRAND / "splash_symbol.png"
    splash.save(splash_path, "PNG")
    print(f"wrote {splash_path.relative_to(ROOT)}")

    # Adaptive FG: cream KR in ~66% safe zone (no rounded plate)
    fg1024 = place_in_canvas(cream, 1024, 0.62)
    assert_transparent_corners(fg1024, "adaptive_fg")
    mono1024 = place_in_canvas(mono, 1024, 0.62)

    # Compat paths for flutter_launcher_icons / older refs
    COMPAT.mkdir(parents=True, exist_ok=True)
    shutil.copy2(app_icon_master, COMPAT / "app_icon.png")
    fg1024.save(COMPAT / "app_icon_fg.png", "PNG")
    splash.save(COMPAT / "splash_logo.png", "PNG")
    # Replace obsolete house-icon source with master reference
    shutil.copy2(app_icon_master, COMPAT / "app_icon_source.png")
    print("updated assets/branding compat copies")

    # Android density drawables
    for folder, size in FG_SIZES.items():
        d = RES / folder
        d.mkdir(parents=True, exist_ok=True)
        fg1024.resize((size, size), Image.Resampling.LANCZOS).save(
            d / "ic_launcher_foreground.png", "PNG"
        )
        mono1024.resize((size, size), Image.Resampling.LANCZOS).save(
            d / "ic_launcher_monochrome.png", "PNG"
        )
        print(f"  {folder}/ foreground+monochrome {size}px")

    # Legacy full plate icon (Play/legacy look)
    master = Image.open(app_icon_master).convert("RGBA")
    for folder, size in LEGACY_SIZES.items():
        d = RES / folder
        d.mkdir(parents=True, exist_ok=True)
        legacy = master.resize((size, size), Image.Resampling.LANCZOS)
        legacy.save(d / "ic_launcher.png", "PNG")
        legacy.save(d / "ic_launcher_round.png", "PNG")
        print(f"  {folder}/ ic_launcher(+round) {size}px")

    write_adaptive_xml()
    write_colors()

    # Splash drawable (nodpi-ish single bitmap)
    splash_drawable = RES / "drawable" / "splash_logo.png"
    splash.resize((512, 512), Image.Resampling.LANCZOS).save(splash_drawable, "PNG")
    print(f"wrote {splash_drawable.relative_to(ROOT)}")

    # Play Store assets
    STORE.mkdir(parents=True, exist_ok=True)
    shutil.copy2(app_icon_master, STORE / "app_icon_512x512.png")
    # Upscale master only for 1024 source archive (LANCZOS once)
    master.resize((1024, 1024), Image.Resampling.LANCZOS).save(
        STORE / "app_icon_source_1024x1024.png", "PNG"
    )
    print("updated store/assets Play icon masters")

    # Adaptive preview helpers (mask simulation)
    preview_dir = STORE / "previews"
    preview_dir.mkdir(parents=True, exist_ok=True)

    def compose_preview(mask: str, size: int = 512) -> Image.Image:
        bg = Image.new("RGBA", (size, size), GREEN_BG)
        fg = fg1024.resize((size, size), Image.Resampling.LANCZOS)
        bg.alpha_composite(fg)
        # soft circular / rounded crop visualization
        mask_im = Image.new("L", (size, size), 0)
        from PIL import ImageDraw

        draw = ImageDraw.Draw(mask_im)
        if mask == "circle":
            draw.ellipse((0, 0, size - 1, size - 1), fill=255)
        elif mask == "squircle":
            draw.rounded_rectangle((0, 0, size - 1, size - 1), radius=size // 4, fill=255)
        else:
            draw.rounded_rectangle((0, 0, size - 1, size - 1), radius=size // 6, fill=255)
        out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        out.paste(bg, mask=mask_im)
        return out

    for name in ("circle", "squircle", "rounded_rect"):
        p = preview_dir / f"adaptive_mask_{name}.png"
        compose_preview(name).save(p, "PNG")
        print(f"preview {p.relative_to(ROOT)}")

    print("DONE finalize_kirarota_branding")


if __name__ == "__main__":
    main()
