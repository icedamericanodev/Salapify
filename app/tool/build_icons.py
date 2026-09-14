"""Build every Salapify launcher and store icon from one source.

Run:  python3 tool/build_icons.py   (from app/)

Writes, and nothing else:
    android/app/src/main/res/mipmap-*/ic_launcher.png             legacy, 5 densities
    android/app/src/main/res/mipmap-*/ic_launcher_foreground.png  adaptive foreground
    android/app/src/main/res/mipmap-*/ic_launcher_monochrome.png  themed icon layer
    ../docs/revamp/mockups/hapon/icon/play-store-icon.png         512 for the listing

The background layer is NOT generated here. It is a vector gradient in
res/drawable/ic_launcher_background.xml, because a gradient drawn by the
system is sharp at every density and a bitmap of one is not.

WHY THE SOURCE IS THE ORIGINAL REFERENCE AND NOT THE RECOLOURED PNG.
An adaptive icon needs the MARK on its own, with the ground transparent, so
the launcher can move the two layers independently. In the recoloured light
version the mark is ink and the ground is the hero ramp, but the cream echo
and the light ground are close enough in value that no threshold separates
them cleanly. In the ORIGINAL they are different hues, so the mask is exact.
The recolour is therefore applied after masking, not before.

THE MONOCHROME LAYER IS AUTHORED, NOT LEFT TO THE SYSTEM. Android 16 QPR2
forces themed icons and apps cannot opt out; where no monochrome layer is
supplied the system generates one from the artwork, and what it produces is
not predictable. So it is drawn here and rendered like everything else.
"""

import colorsys
import os

from PIL import Image, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
APP = os.path.dirname(HERE)
REPO = os.path.dirname(APP)
ICONS = f"{REPO}/docs/revamp/mockups/hapon/icon"
RES = f"{APP}/android/app/src/main/res"

SRC = f"{ICONS}/salapify-icon-reference.png"

# Salapify tokens, all from app/lib/design/tokens.dart.
INK = (0x2A, 0x12, 0x07)  # onHero
CREAM = (0xFF, 0xD9, 0xB0)  # hero stop 0
RAMP = [(0xFF, 0xD9, 0xB0), (0xFE, 0xC0, 0x78), (0xFB, 0x9C, 0x52)]

# mdpi, hdpi, xhdpi, xxhdpi, xxxhdpi. Legacy icon then adaptive layer, both in
# px, and the adaptive one is always 108/48 of the legacy one by definition.
DENSITIES = [
    ("mdpi", 48, 108),
    ("hdpi", 72, 162),
    ("xhdpi", 96, 216),
    ("xxhdpi", 144, 324),
    ("xxxhdpi", 192, 432),
]


def mix(a, b, t):
    t = max(0.0, min(1.0, t))
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))


def ramp_at(t):
    """The hero gradient, sampled at 0..1 along its three stops."""
    t = max(0.0, min(1.0, t))
    if t < 0.5:
        return mix(RAMP[0], RAMP[1], t / 0.5)
    return mix(RAMP[1], RAMP[2], (t - 0.5) / 0.5)


def white_alpha(r, g, b):
    """How much of this pixel is white RIBBON. Desaturated and bright."""
    _, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
    return max(0.0, min(1.0, (0.30 - s) / 0.22)) * max(0.0, min(1.0, (v - 0.55) / 0.25))


def mint_alpha(r, g, b):
    """How much of this pixel is the MINT ECHO.

    Colour alone cannot answer this. The reference's own backdrop glow bleeds
    inside the tile at the top right and measures #8BE7D9, which is pixel for
    pixel the same as the mint echo, so any hue or saturation threshold that
    keeps the echo also keeps the glow. It did, and the first build put a dark
    ink cloud in the corner. The echo is separated by POSITION instead: it only
    ever runs alongside a ribbon, and the glow never does. See build_mark.
    """
    h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
    hue = h * 360
    return max(0.0, min(1.0, (196 - hue) / 22.0)) * max(0.0, min(1.0, (v - 0.45) / 0.25))


def build_mark():
    """The mark alone, on transparent, cropped to its bounds.

    Two colours, matching what the light recolour actually shows: the ribbons
    and the peso in ink, the echo beside them in cream.
    """
    src = Image.open(SRC).convert("RGB")
    px = src.load()
    w, h = src.size

    # Ignore everything outside the reference tile's own rounded corners.
    r = 0.20 * w

    def inside(x, y):
        cx = min(max(x, r), w - r)
        cy = min(max(y, r), h - r)
        return ((x - cx) ** 2 + (y - cy) ** 2) ** 0.5 <= r - 2.0

    white = Image.new("L", (w, h), 0)
    wp = white.load()
    mint = Image.new("L", (w, h), 0)
    mp = mint.load()
    for y in range(h):
        for x in range(w):
            if not inside(x, y):
                continue
            p = px[x, y]
            wp[x, y] = round(white_alpha(*p) * 255)
            mp[x, y] = round(mint_alpha(*p) * 255)

    # The gate. Dilating the ribbon mask by roughly six pixels gives the
    # band the echo lives in; the corner glow falls outside it and drops out.
    near_ribbon = white.filter(ImageFilter.MaxFilter(13))
    ngp = near_ribbon.load()

    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    op = out.load()
    for y in range(h):
        for x in range(w):
            wa = wp[x, y] / 255
            ma = (mp[x, y] / 255) * (1.0 if ngp[x, y] > 8 else 0.0)
            if wa <= 0.004 and ma <= 0.004:
                continue
            # Ribbon wins where both apply; the echo only fills what is left.
            a = max(wa, ma)
            colour = mix(CREAM, INK, wa / a) if a > 0 else INK
            op[x, y] = colour + (round(a * 255),)
    return out.crop(out.getbbox())


def place(mark, canvas, fraction):
    """Centre the mark on a square canvas, scaled to `fraction` of its width."""
    target = canvas * fraction
    mw, mh = mark.size
    k = target / max(mw, mh)
    m = mark.resize((max(1, round(mw * k)), max(1, round(mh * k))), Image.LANCZOS)
    out = Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
    out.paste(m, ((canvas - m.size[0]) // 2, (canvas - m.size[1]) // 2), m)
    return out


def ground(size):
    """The hero ramp across the diagonal, as a square bitmap."""
    im = Image.new("RGB", (size, size))
    p = im.load()
    for y in range(size):
        for x in range(size):
            p[x, y] = ramp_at((x + y) / (2 * (size - 1)))
    return im


def main():
    mark = build_mark()
    print("mark bounds", mark.size)

    for name, legacy, adaptive in DENSITIES:
        d = f"{RES}/mipmap-{name}"
        os.makedirs(d, exist_ok=True)

        # Legacy icon: ground plus mark, full bleed, no transparency. Used on
        # Android 7 and below and as the Play Console fallback.
        tile = ground(legacy).convert("RGBA")
        m = place(mark, legacy, 0.78)
        tile.alpha_composite(m)
        tile.convert("RGB").save(f"{d}/ic_launcher.png")

        # Adaptive foreground: mark only, inside the 66 of 108 safe circle.
        #
        # 0.61 is the exact limit rather than a comfortable guess. The mark is
        # taller than it is wide, so its extreme points are top and bottom
        # centre, not the corners. At xxxhdpi that is 432 * 0.61 / 2 = 132 from
        # centre, and the guaranteed circle's radius is 33/108 * 432 = 132. The
        # first build used 0.58 and the preview showed why not to: the mark sat
        # in a lake of empty ramp.
        place(mark, adaptive, 0.61).save(f"{d}/ic_launcher_foreground.png")

        # Themed icon: the same silhouette, pure white. Android tints it.
        mono = place(mark, adaptive, 0.61)
        white = Image.new("RGBA", mono.size, (255, 255, 255, 0))
        white.putalpha(mono.getchannel("A"))
        white.save(f"{d}/ic_launcher_monochrome.png")

        print(f"mipmap-{name:8s} legacy {legacy:3d}  adaptive {adaptive:3d}")

    # The Play listing asset: 512 square, flat, full bleed, no rounding and no
    # shadow of its own, because Play masks at 30 percent and adds a shadow.
    store = ground(512).convert("RGBA")
    store.alpha_composite(place(mark, 512, 0.78))
    store.convert("RGB").save(f"{ICONS}/play-store-icon.png")
    print("play-store-icon.png 512")


if __name__ == "__main__":
    main()
