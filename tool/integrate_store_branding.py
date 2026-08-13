from PIL import Image, ImageDraw
from pathlib import Path

root = Path('.')
src_dir = root / 'store' / 'assets' / 'screenshots'
out_assets = root / 'store' / 'assets'
branding = root / 'assets' / 'branding'
previews = out_assets / 'previews'
branding.mkdir(parents=True, exist_ok=True)
previews.mkdir(parents=True, exist_ok=True)
out_assets.mkdir(parents=True, exist_ok=True)

icon512 = Image.open(src_dir / 'app_icon_512x512.png').convert('RGBA')
feat = Image.open(src_dir / 'feature_graphic_1024x500.png').convert('RGB')

icon512.save(out_assets / 'app_icon_512x512.png')
feat.save(out_assets / 'feature_graphic_1024x500.png')

icon1024 = icon512.resize((1024, 1024), Image.Resampling.LANCZOS)
icon1024.save(out_assets / 'app_icon_source_1024x1024.png')
icon1024.save(branding / 'app_icon_source.png')
icon1024.save(branding / 'app_icon.png')

# Adaptive foreground: content in ~66% safe zone
FG = 1024
SAFE = int(FG * 0.66)
fg = Image.new('RGBA', (FG, FG), (0, 0, 0, 0))
scaled = icon1024.resize((SAFE, SAFE), Image.Resampling.LANCZOS)
offset = (FG - SAFE) // 2
fg.paste(scaled, (offset, offset), scaled)
fg.save(branding / 'app_icon_fg.png')

# Splash mark
SPLASH = 512
splash = Image.new('RGBA', (SPLASH, SPLASH), (0, 0, 0, 0))
mark = icon1024.resize((360, 360), Image.Resampling.LANCZOS)
splash.paste(mark, ((SPLASH - 360) // 2, (SPLASH - 360) // 2), mark)
splash.save(branding / 'splash_logo.png')

bg = (0x1F, 0x4E, 0x3D, 255)


def preview(mask_name, mask_fn):
    canvas = Image.new('RGBA', (FG, FG), bg)
    canvas.alpha_composite(fg)
    mask = Image.new('L', (FG, FG), 0)
    d = ImageDraw.Draw(mask)
    mask_fn(d)
    out = Image.new('RGBA', (FG, FG), (0, 0, 0, 0))
    out.paste(canvas, (0, 0))
    out.putalpha(mask)
    out.save(previews / f'adaptive_mask_{mask_name}.png')


preview('circle', lambda d: d.ellipse((0, 0, FG - 1, FG - 1), fill=255))
preview(
    'squircle',
    lambda d: d.rounded_rectangle((0, 0, FG - 1, FG - 1), radius=FG // 4, fill=255),
)
preview(
    'rounded_rect',
    lambda d: d.rounded_rectangle(
        (40, 40, FG - 41, FG - 41), radius=FG // 5, fill=255
    ),
)

for name in ['app_icon_512x512.png', 'feature_graphic_1024x500.png']:
    p = src_dir / name
    if p.exists():
        p.unlink()

feat.save(root / 'store' / 'feature_graphic.png')

print('OK')
for p in [
    out_assets / 'app_icon_512x512.png',
    out_assets / 'app_icon_source_1024x1024.png',
    out_assets / 'feature_graphic_1024x500.png',
    branding / 'app_icon.png',
    branding / 'app_icon_fg.png',
    branding / 'splash_logo.png',
]:
    im = Image.open(p)
    print(p.as_posix(), im.size, im.mode)
print('screenshots:', sorted(x.name for x in src_dir.glob('*.png')))
