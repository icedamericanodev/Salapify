"""Render what the launcher will actually show, from the shipped layer files.

Run:  python3 tool/preview_icons.py   (from app/)

This composes the SAME files the APK carries: it reads
mipmap-xxxhdpi/ic_launcher_foreground.png and ic_launcher_monochrome.png off
disk and draws the background from the same three stops the vector background
declares. A preview made from the source artwork instead would prove nothing
about what shipped, which is the whole reason this file exists.
"""

import os

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
APP = os.path.dirname(HERE)
REPO = os.path.dirname(APP)
RES = f"{APP}/android/app/src/main/res"
OUT = f"{REPO}/docs/revamp/mockups/hapon/icon"
BOLD = f"{APP}/assets/fonts/PlusJakartaSans-ExtraBold.ttf"
FONT = f"{APP}/assets/fonts/PlusJakartaSans-SemiBold.ttf"

RAMP = [(0xFF, 0xD9, 0xB0), (0xFE, 0xC0, 0x78), (0xFB, 0x9C, 0x52)]


def mix(a, b, t):
    t = max(0.0, min(1.0, t))
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))


def ramp_at(t):
    t = max(0.0, min(1.0, t))
    return mix(RAMP[0], RAMP[1], t / 0.5) if t < 0.5 else mix(RAMP[1], RAMP[2], (t - 0.5) / 0.5)


def background(size):
    im = Image.new("RGB", (size, size))
    p = im.load()
    for y in range(size):
        for x in range(size):
            p[x, y] = ramp_at((x + y) / (2 * (size - 1)))
    return im.convert("RGBA")


FG = Image.open(f"{RES}/mipmap-xxxhdpi/ic_launcher_foreground.png").convert("RGBA")
MONO = Image.open(f"{RES}/mipmap-xxxhdpi/ic_launcher_monochrome.png").convert("RGBA")
LEGACY = Image.open(f"{RES}/mipmap-xxxhdpi/ic_launcher.png").convert("RGBA")


def adaptive(size):
    """Background plus foreground, exactly as the launcher composes them."""
    im = background(size)
    im.alpha_composite(FG.resize((size, size), Image.LANCZOS))
    return im


def themed(size, ink, paper):
    """What Android 16 draws when the user turns on themed icons."""
    im = Image.new("RGBA", (size, size), paper)
    m = MONO.resize((size, size), Image.LANCZOS)
    tint = Image.new("RGBA", (size, size), ink)
    tint.putalpha(m.getchannel("A"))
    im.alpha_composite(tint)
    return im


def mask(im, size, factor):
    im = im.resize((size, size), Image.LANCZOS).convert("RGBA")
    m = Image.new("L", (size, size), 0)
    ImageDraw.Draw(m).rounded_rectangle(
        [0, 0, size - 1, size - 1], radius=int(size * factor), fill=255
    )
    im.putalpha(m)
    return im


W, H = 1120, 740
sheet = Image.new("RGB", (W, H), "#0B0A09")
d = ImageDraw.Draw(sheet)
t = ImageFont.truetype(BOLD, 28)
hd = ImageFont.truetype(BOLD, 16)
sm = ImageFont.truetype(FONT, 12)

d.text((32, 26), "What the phone will actually show", font=t, fill="#F6EFE8")
d.text(
    (32, 66),
    "Composed from the shipped layer files in android/.../mipmap-xxxhdpi, not from the source artwork.",
    font=sm,
    fill="#AC9E92",
)

cols = [
    (adaptive(432), 0.225, "Adaptive, squircle", "Most launchers."),
    (adaptive(432), 0.5, "Adaptive, circle", "The harshest mask."),
    (LEGACY, 0.225, "Legacy", "Android 7 and below."),
    (themed(432, (0xF6, 0xEF, 0xE8, 255), (0x2A, 0x12, 0x07, 255)), 0.225, "Themed, dark", "Android 16 QPR2."),
    (themed(432, (0x2A, 0x12, 0x07, 255), (0xFF, 0xEE, 0xDF, 255)), 0.225, "Themed, light", "Same layer, tinted."),
]

x = 32
for img, factor, name, note in cols:
    big = mask(img, 170, factor)
    sheet.paste(big, (x, 110), big)
    d.text((x, 292), name, font=hd, fill="#F6EFE8")
    d.text((x, 314), note, font=sm, fill="#AC9E92")
    small = mask(img, 48, factor)
    sheet.paste(small, (x, 344), small)
    d.text((x, 398), "48px", font=sm, fill="#8A7F75")
    x += 210

# Every density, side by side at its true pixel size, so a wrong export shows.
d.text((32, 440), "Every density, at its real pixel size", font=hd, fill="#F6EFE8")
x = 32
for name, px in [("mdpi", 48), ("hdpi", 72), ("xhdpi", 96), ("xxhdpi", 144), ("xxxhdpi", 192)]:
    im = Image.open(f"{RES}/mipmap-{name}/ic_launcher.png").convert("RGBA")
    tile = mask(im, px, 0.225)
    sheet.paste(tile, (x, 490 + (192 - px) // 2), tile)
    d.text((x, 700), f"{name} {px}px", font=sm, fill="#8A7F75")
    x += px + 26

sheet.save(f"{OUT}/icon-shipped-layers.png")
print("wrote", f"{OUT}/icon-shipped-layers.png")
