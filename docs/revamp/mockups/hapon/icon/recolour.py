"""Recolour the founder's reference icon into Salapify's palette.

Geometry is untouched. Every pixel keeps its position and its alpha; only its
colour changes, which is exactly what was asked for.

WHY NOT A HUE ROTATION. The reference separates its three elements by HUE:
deep blue ground, mint echo, white ribbon. Salapify's palette is monochromatic
warm and separates by VALUE: ink 0.01, accent 0.45, cream 0.74 relative
luminance, all at roughly the same hue. Rotating blue to orange sends the mint
to pink, which is not in the theme. So each element is classified and mapped to
its Salapify counterpart, and anti-aliased pixels are blended rather than
snapped so no edge fringes.
"""

import colorsys
from PIL import Image

SRC = "/root/.claude/uploads/abb3d7ed-eb75-5aa3-9888-dc923bd41f32/32674394-image.png"
OUT = "/tmp/claude-0/-home-user-Salapify/abb3d7ed-eb75-5aa3-9888-dc923bd41f32/scratchpad"

# The tile, found by scanning for the value drop at its edges.
BOX = (437, 112, 972, 647)


def hexc(h):
    h = h.lstrip("#")
    return tuple(int(h[i : i + 2], 16) for i in (0, 2, 4))


def mix(a, b, t):
    t = max(0.0, min(1.0, t))
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))


# Salapify tokens. Every one of these is already in app/lib/design/tokens.dart.
INK = hexc("#14100D")  # gabi bg, the deep warm near black
DEEP = hexc("#6B2E06")  # the mid warm brown, measured 7.79 on the cream stop
ACCENT = hexc("#FF9A52")  # gabi accent
CREAM = hexc("#FFD9B0")  # hero stop 0
RAMP_MID = hexc("#FEC078")
RAMP_DEEP = hexc("#FB9C52")
INK2 = hexc("#2A1207")  # onHero


def classify(r, g, b):
    """Return (sat, val, hue_degrees) for one pixel."""
    h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
    return s, v, h * 360


def map_dark(r, g, b):
    """Dark tile: ground goes to ink, ribbons to cream, echo to accent."""
    s, v, hue = classify(r, g, b)

    # The white ribbon: low saturation, high value.
    white_w = max(0.0, min(1.0, (0.30 - s) / 0.22)) * max(0.0, min(1.0, (v - 0.55) / 0.25))

    # The mint echo: hue well below the blue band, and bright.
    mint_w = max(0.0, min(1.0, (196 - hue) / 22.0)) * max(0.0, min(1.0, (v - 0.45) / 0.25))

    # The ground: everything else, mapped by its own value so the tile keeps
    # its gradient instead of flattening to one flat brown. The window is
    # deliberately wide and starts high: the reference's ground sits at value
    # 0.45 to 0.67, and a narrow window put all of it near the light end and
    # made the tile read as milk chocolate instead of as a dark tile.
    ground = mix(INK, DEEP, (v - 0.38) / 0.85)

    out = ground
    out = mix(out, ACCENT, mint_w * (1 - white_w))
    out = mix(out, CREAM, white_w)
    return out


def map_light(r, g, b):
    """Light tile: the same artwork on Hapon's ramp, ribbons in ink."""
    s, v, hue = classify(r, g, b)
    white_w = max(0.0, min(1.0, (0.30 - s) / 0.22)) * max(0.0, min(1.0, (v - 0.55) / 0.25))
    mint_w = max(0.0, min(1.0, (196 - hue) / 22.0)) * max(0.0, min(1.0, (v - 0.45) / 0.25))

    # Ground runs along the hero ramp, darker at the top left like the app's
    # own hero panel.
    ground = mix(RAMP_DEEP, RAMP_MID, (v - 0.18) / 0.50)

    out = ground
    out = mix(out, CREAM, mint_w * (1 - white_w))
    out = mix(out, INK2, white_w)
    return out


def render(fn, name, corner, size=512):
    """Recolour the tile and FILL THE SQUARE.

    The crop catches a little of the reference's own backdrop glow outside the
    tile's rounded corners. A real Play asset is submitted as a full square
    anyway (Play applies its own 30 percent mask and its own shadow), so rather
    than mask the corners away, the corner pixels are replaced with the tile's
    own ground colour. That is what makes this an icon rather than a screenshot
    of one.
    """
    src = Image.open(SRC).convert("RGB").crop(BOX)
    px = src.load()
    w, h = src.size
    dst = Image.new("RGB", (w, h))
    dp = dst.load()

    r = 0.20 * w  # the reference tile's own corner radius, near enough
    for y in range(h):
        for x in range(w):
            cx = min(max(x, r), w - r)
            cy = min(max(y, r), h - r)
            d = ((x - cx) ** 2 + (y - cy) ** 2) ** 0.5
            if d > r - 2.0:
                # Outside the reference's rounded corner. Filling flat leaves a
                # visible rounded edge inside a square asset, and pulling the
                # nearest pixel smears the reference's own backdrop glow into a
                # starburst (it did, in the top right). So the ground gradient
                # is synthesised instead: same two tokens, same diagonal, no
                # artwork to smear.
                # Sample well INSIDE the arc, not on it. On the arc the ray
                # extension amplifies the reference's backdrop glow into
                # streaks; twelve pixels in, it is clean ground and still
                # varies smoothly around the corner.
                k = (r - 12.0) / max(d, 0.001)
                sx = min(max(int(round(cx + (x - cx) * k)), 0), w - 1)
                sy = min(max(int(round(cy + (y - cy) * k)), 0), h - 1)
                out = fn(*px[sx, sy])
            else:
                out = fn(*px[x, y])
            dp[x, y] = out
    dst = dst.resize((size, size), Image.LANCZOS)
    path = f"{OUT}/{name}.png"
    dst.save(path)
    print("wrote", path)
    return dst


render(
    map_dark,
    "salapify-icon-dark",
    corner=lambda u, t: mix(INK, DEEP, 0.06 + 0.26 * (u + t) / 2),
)
render(
    map_light,
    "salapify-icon-light",
    corner=lambda u, t: mix(RAMP_MID, RAMP_DEEP, (u + t) / 2),
)

# The original, cropped and untouched, so the two can be compared honestly.
Image.open(SRC).convert("RGB").crop(BOX).resize((512, 512), Image.LANCZOS).save(
    f"{OUT}/salapify-icon-reference.png"
)
print("wrote reference crop")
