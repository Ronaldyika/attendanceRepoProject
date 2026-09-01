from PIL import Image, ImageDraw, ImageFont
from pathlib import Path

root = Path(__file__).resolve().parents[1]
brand_dir = root / 'assets' / 'branding'
brand_dir.mkdir(parents=True, exist_ok=True)

# Premium icon design: deep blue / teal glass card with white check and C monogram.
size = 1024
icon = Image.new('RGBA', (size, size), (0, 0, 0, 0))
icon_draw = ImageDraw.Draw(icon)

# Deep blue gradient background
for y in range(size):
    t = y / size
    r = int(16 + (30 - 16) * t)
    g = int(61 + (79 - 61) * t)
    b = int(120 + (170 - 120) * t)
    icon_draw.line([(0, y), (size, y)], fill=(r, g, b, 255))

# teal glow accent
shade = Image.new('RGBA', (size, size), (0, 0, 0, 0))
shade_draw = ImageDraw.Draw(shade)
shade_draw.rounded_rectangle((260, 330, 980, 980), radius=200, fill=(0, 191, 165, 160))
icon = Image.alpha_composite(icon, shade)

# White rounded panel interior
panel = Image.new('RGBA', (size, size), (0, 0, 0, 0))
panel_draw = ImageDraw.Draw(panel)
panel_draw.rounded_rectangle((150, 150, 874, 874), radius=220, fill=(255, 255, 255, 255))
icon = Image.alpha_composite(icon, panel)

# Dark inset area for strong contrast
inner = Image.new('RGBA', (size, size), (0, 0, 0, 0))
inner_draw = ImageDraw.Draw(inner)
inner_draw.rounded_rectangle((250, 250, 774, 774), radius=180, fill=(15, 23, 42, 255))
icon = Image.alpha_composite(icon, inner)

# Check icon in cyan
check = Image.new('RGBA', (size, size), (0, 0, 0, 0))
check_draw = ImageDraw.Draw(check)
check_draw.line((380, 510, 470, 600), fill=(82, 208, 255, 255), width=42)
check_draw.line((470, 600, 660, 420), fill=(82, 208, 255, 255), width=42)
icon = Image.alpha_composite(icon, check)

# Large C monogram over the check for corporate identity
try:
    font = ImageFont.truetype('arial.ttf', 270)
except Exception:
    font = ImageFont.load_default()
letter = Image.new('RGBA', (size, size), (0, 0, 0, 0))
letter_draw = ImageDraw.Draw(letter)
letter_draw.text((248, 285), 'C', fill=(255, 255, 255, 180), font=font)
icon = Image.alpha_composite(icon, letter)
icon.save(brand_dir / 'civilsalt_app_icon.png')

# Splash image for iOS/Android start screen.
splash_size = (1242, 2688)
splash = Image.new('RGBA', splash_size, (15, 23, 42, 255))
splash_draw = ImageDraw.Draw(splash)
splash_draw.rounded_rectangle((150, 680, 1092, 1970), radius=180, fill=(31, 41, 59, 255))
icon_small = icon.resize((520, 520))
splash.paste(icon_small, (361, 760), icon_small)
try:
    title_font = ImageFont.truetype('arial.ttf', 122)
    subtitle_font = ImageFont.truetype('arial.ttf', 58)
except Exception:
    title_font = ImageFont.load_default()
    subtitle_font = ImageFont.load_default()

splash_draw.text((621, 1505), 'Civilsalt', fill=(255, 255, 255, 255), font=title_font, anchor='mm')
splash_draw.text((621, 1640), 'Attendance Manager', fill=(147, 197, 253, 255), font=subtitle_font, anchor='mm')
splash.save(brand_dir / 'civilsalt_splash.png')

print(f'Brand assets created at: {brand_dir}')
