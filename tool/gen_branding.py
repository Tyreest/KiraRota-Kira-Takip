from PIL import Image, ImageDraw
import os

os.makedirs("assets/branding", exist_ok=True)
os.makedirs("store", exist_ok=True)


def make_icon(path: str, size: int) -> None:
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    pad = int(size * 0.06)
    d.rounded_rectangle(
        [pad, pad, size - pad, size - pad],
        radius=int(size * 0.22),
        fill=(31, 78, 61, 255),
    )
    m = int(size * 0.18)
    d.ellipse([m, m, size - m, size - m], fill=(252, 249, 248, 255))
    green = (2, 55, 39, 255)
    base_y = int(size * 0.72)
    bars = [(0.28, 0.42), (0.42, 0.50), (0.56, 0.58), (0.70, 0.66)]
    bw = int(size * 0.08)
    for cx, h in bars:
        x = int(size * cx) - bw // 2
        top = base_y - int(size * (h - 0.28))
        d.rounded_rectangle([x, top, x + bw, base_y], radius=max(2, bw // 3), fill=green)
    pts = [
        (int(size * 0.26), int(size * 0.58)),
        (int(size * 0.40), int(size * 0.52)),
        (int(size * 0.54), int(size * 0.44)),
        (int(size * 0.72), int(size * 0.34)),
    ]
    d.line(pts, fill=(240, 180, 41, 255), width=max(3, size // 48))
    for p in pts:
        r = max(4, size // 64)
        d.ellipse([p[0] - r, p[1] - r, p[0] + r, p[1] + r], fill=(240, 180, 41, 255))
    img.save(path)


make_icon("assets/branding/app_icon.png", 1024)
make_icon("assets/branding/app_icon_fg.png", 1024)

fg = Image.new("RGB", (1024, 500), (252, 249, 248))
d = ImageDraw.Draw(fg)
d.rounded_rectangle([40, 40, 984, 460], radius=40, fill=(31, 78, 61))
d.rounded_rectangle([80, 160, 480, 340], radius=24, fill=(252, 249, 248))
d.rounded_rectangle([560, 120, 920, 380], radius=24, fill=(232, 237, 232))
base_y = 340
for i, h in enumerate([60, 90, 120, 150]):
    x = 620 + i * 70
    d.rounded_rectangle([x, base_y - h, x + 40, base_y], radius=8, fill=(31, 78, 61))
d.line([(640, 300), (710, 270), (780, 230), (850, 190)], fill=(240, 180, 41), width=6)
fg.save("store/feature_graphic.png")
print("branding assets written")
