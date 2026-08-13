# -*- coding: utf-8 -*-
"""Android adaptive launcher icon double-frame düzeltmesi.

Play Store 512 / splash / app_icon.png dokunulmaz.
Yalnızca adaptive foreground (şeffaf sembol) + Android res mipmap/drawable.
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SRC_ICON = ROOT / "assets" / "branding" / "app_icon.png"
FG_OUT = ROOT / "assets" / "branding" / "app_icon_fg.png"
RES = ROOT / "android" / "app" / "src" / "main" / "res"

BG = (0x1F, 0x4E, 0x3D, 255)

# Adaptive foreground densities (108dp)
FG_SIZES = {
    "drawable-mdpi": 108,
    "drawable-hdpi": 162,
    "drawable-xhdpi": 216,
    "drawable-xxhdpi": 324,
    "drawable-xxxhdpi": 432,
}

# Legacy launcher densities (48dp)
LEGACY_SIZES = {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192,
}


def is_symbol_pixel(r: int, g: int, b: int, a: int) -> bool:
    """Krem ev + sage yüzde/grafik — true ise korunur."""
    if a < 12:
        return False
    # Cream / off-white house stroke
    if r >= 180 and g >= 180 and b >= 150:
        return True
    # Sage / mint interior glyphs
    if 90 <= r <= 210 and 120 <= g <= 230 and 80 <= b <= 200 and g >= r and g >= b - 10:
        # Exclude dark plate greens that are also g>r
        if r < 60 and g < 110:
            return False
        return True
    return False


def extract_symbol(src: Image.Image) -> Image.Image:
    """Koyu yeşil rounded plate'i sil; krem ev + sage sembol kalsın."""
    im = src.convert("RGBA")
    px = im.load()
    w, h = im.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if is_symbol_pixel(r, g, b, a):
                continue
            px[x, y] = (0, 0, 0, 0)
    return im


def content_bbox(im: Image.Image) -> tuple[int, int, int, int]:
    alpha = im.split()[-1]
    return alpha.getbbox() or (0, 0, im.width, im.height)


def place_in_safe_zone(symbol: Image.Image, canvas: int = 1024, safe_ratio: float = 0.66) -> Image.Image:
    """Sembolü adaptive safe zone (merkez ~66%) içine ortala."""
    bbox = content_bbox(symbol)
    cropped = symbol.crop(bbox)
    out = Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
    safe = int(canvas * safe_ratio)
    # Fit cropped content into safe box preserving aspect
    cw, ch = cropped.size
    scale = min(safe / cw, safe / ch)
    nw, nh = max(1, int(cw * scale)), max(1, int(ch * scale))
    resized = cropped.resize((nw, nh), Image.Resampling.LANCZOS)
    ox = (canvas - nw) // 2
    oy = (canvas - nh) // 2
    out.alpha_composite(resized, (ox, oy))
    return out


def to_monochrome(fg: Image.Image) -> Image.Image:
    """Themed icon: tek renk (beyaz) + mevcut alpha."""
    im = fg.convert("RGBA")
    px = im.load()
    w, h = im.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a < 8:
                px[x, y] = (0, 0, 0, 0)
            else:
                # Keep alpha shape; solid white glyph
                px[x, y] = (255, 255, 255, a)
    return im


def compose_legacy(fg: Image.Image, size: int) -> Image.Image:
    bg = Image.new("RGBA", (size, size), BG)
    layer = fg.resize((size, size), Image.Resampling.LANCZOS)
    bg.alpha_composite(layer)
    return bg.convert("RGBA")


def write_xml() -> None:
    anydpi = RES / "mipmap-anydpi-v26"
    anydpi.mkdir(parents=True, exist_ok=True)

    launcher = """<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background"/>
    <foreground android:drawable="@drawable/ic_launcher_foreground"/>
    <monochrome android:drawable="@drawable/ic_launcher_monochrome"/>
</adaptive-icon>
"""
    (anydpi / "ic_launcher.xml").write_text(launcher, encoding="utf-8")
    (anydpi / "ic_launcher_round.xml").write_text(launcher, encoding="utf-8")


def main() -> None:
    src = Image.open(SRC_ICON)
    symbol = extract_symbol(src)
    fg1024 = place_in_safe_zone(symbol, canvas=1024, safe_ratio=0.66)
    FG_OUT.parent.mkdir(parents=True, exist_ok=True)
    fg1024.save(FG_OUT, "PNG")
    print(f"wrote {FG_OUT.relative_to(ROOT)}")

    mono1024 = to_monochrome(fg1024)

    for folder, size in FG_SIZES.items():
        d = RES / folder
        d.mkdir(parents=True, exist_ok=True)
        fg = fg1024.resize((size, size), Image.Resampling.LANCZOS)
        fg.save(d / "ic_launcher_foreground.png", "PNG")
        mono = mono1024.resize((size, size), Image.Resampling.LANCZOS)
        mono.save(d / "ic_launcher_monochrome.png", "PNG")
        print(f"  {folder}/ic_launcher_foreground.png + monochrome ({size}px)")

    for folder, size in LEGACY_SIZES.items():
        d = RES / folder
        d.mkdir(parents=True, exist_ok=True)
        legacy = compose_legacy(fg1024, size)
        legacy.save(d / "ic_launcher.png", "PNG")
        legacy.save(d / "ic_launcher_round.png", "PNG")
        print(f"  {folder}/ic_launcher.png + round ({size}px)")

    write_xml()
    print("wrote mipmap-anydpi-v26/ic_launcher.xml + ic_launcher_round.xml")

    # Sanity: corners transparent; symbol has opaque pixels
    sample = fg1024.getpixel((20, 20))
    assert sample[3] == 0, f"FG corner should be transparent, got {sample}"
    opaque = sum(1 for p in fg1024.getdata() if p[3] > 20)
    assert opaque > 5000, f"FG symbol too empty ({opaque} opaque px)"
    print(f"sanity OK: transparent corners, opaque_px={opaque}")


if __name__ == "__main__":
    main()
