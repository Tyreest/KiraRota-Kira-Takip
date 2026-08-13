# -*- coding: utf-8 -*-
"""Splash marka logosu — launcher plate'siz, krem zeminde okunaklı.

Kaynak: assets/branding/app_icon.png
Çıktı: assets/branding/splash_logo.png + android drawable/splash_logo.png

Dokunulmaz: Play 512, launcher adaptive assets, splash dışı UI.
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "assets" / "branding" / "app_icon.png"
OUT_ASSET = ROOT / "assets" / "branding" / "splash_logo.png"
OUT_DRAWABLE = ROOT / "android" / "app" / "src" / "main" / "res" / "drawable" / "splash_logo.png"

# AppColors.primary / secondary — krem (#FCF9F8) üzerinde kontrast
HOUSE = (0x1F, 0x4E, 0x3D, 255)  # primary
GLYPH = (0x4C, 0x64, 0x55, 255)  # secondary
CANVAS = 1024
# Android 12 circle + pre-12: görsel marka ~%40 (öncekinden küçük)
SYMBOL_RATIO = 0.40


def is_cream(r: int, g: int, b: int, a: int) -> bool:
    return a >= 12 and r >= 180 and g >= 170 and b >= 140


def is_sage(r: int, g: int, b: int, a: int) -> bool:
    if a < 12:
        return False
    if is_cream(r, g, b, a):
        return False
    if r < 60 and g < 110:
        return False
    return 90 <= r <= 210 and 120 <= g <= 230 and 80 <= b <= 200 and g >= r and g >= b - 10


def extract_and_recolor(src: Image.Image) -> Image.Image:
    im = src.convert("RGBA")
    px = im.load()
    w, h = im.size
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    opx = out.load()
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if is_cream(r, g, b, a):
                # Anti-alias: kaynak alpha'yı koru
                opx[x, y] = (HOUSE[0], HOUSE[1], HOUSE[2], a)
            elif is_sage(r, g, b, a):
                opx[x, y] = (GLYPH[0], GLYPH[1], GLYPH[2], a)
    return out


def content_bbox(im: Image.Image) -> tuple[int, int, int, int]:
    return im.split()[-1].getbbox() or (0, 0, im.width, im.height)


def place_centered(symbol: Image.Image, canvas: int, ratio: float) -> Image.Image:
    bbox = content_bbox(symbol)
    cropped = symbol.crop(bbox)
    out = Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
    target = int(canvas * ratio)
    cw, ch = cropped.size
    scale = min(target / cw, target / ch)
    nw, nh = max(1, int(cw * scale)), max(1, int(ch * scale))
    resized = cropped.resize((nw, nh), Image.Resampling.LANCZOS)
    ox = (canvas - nw) // 2
    oy = (canvas - nh) // 2
    out.alpha_composite(resized, (ox, oy))
    return out


def main() -> None:
    src = Image.open(SRC)
    symbol = extract_and_recolor(src)
    logo = place_centered(symbol, CANVAS, SYMBOL_RATIO)

    OUT_ASSET.parent.mkdir(parents=True, exist_ok=True)
    OUT_DRAWABLE.parent.mkdir(parents=True, exist_ok=True)
    # 1024 kaynak + 512 drawable (nodpi benzeri tek bitmap)
    logo.save(OUT_ASSET, "PNG")
    logo512 = logo.resize((512, 512), Image.Resampling.LANCZOS)
    logo512.save(OUT_DRAWABLE, "PNG")

    c = logo512.getpixel((20, 20))
    mid = logo512.getpixel((256, 200))
    print(f"wrote {OUT_ASSET.relative_to(ROOT)} (1024) + drawable/splash_logo.png (512)")
    print(f"corner={c} mid≈{mid} (corner must be transparent)")


if __name__ == "__main__":
    main()
