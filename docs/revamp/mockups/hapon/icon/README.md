# The Salapify app icon

## Where this landed: the founder's own artwork, recoloured

Founder direction, 2026-09-13, verbatim: **"use the same icon just change the
color. make it the same do not change anything but the colot to fit the theme"**.

So that is what this is. The geometry is untouched, pixel for pixel: the ribbon
S, the peso coin at the letter's waist, the three bar chart in the corner. Only
the colour changed.

![The recolour](icon-recolour-sheet.png)

| The reference | Salapify dark | Salapify light |
|---|---|---|
| ![Reference](salapify-icon-reference.png) | ![Dark](salapify-icon-dark.png) | ![Light](salapify-icon-light.png) |

Both are 512 square, sRGB, and well under Play's 1024KB, so either can go
straight to the store listing.

## How the colour was mapped, and why not a hue rotation

The obvious move is to spin the hue from blue to orange. It does not work here,
and the reason is worth writing down.

The reference separates its three elements **by hue**: deep blue ground, mint
echo, white ribbon. Salapify's palette is monochromatic warm and separates
**by value**: ink at 0.01 relative luminance, accent at 0.45, cream at 0.74, all
at roughly the same hue. Rotating blue to orange sends the mint to pink, which
is not in the theme.

So each element is classified and mapped to its Salapify counterpart, with
anti-aliased pixels blended rather than snapped so no edges fringe:

| Reference | Salapify dark | Salapify light |
|---|---|---|
| deep blue ground | `#14100D` to `#6B2E06`, Gabi's page | `#FB9C52` to `#FEC078`, the hero ramp |
| white ribbon | `#FFD9B0` cream | `#2A1207` ink |
| mint echo | `#FF9A52` accent | `#FFD9B0` cream |

Every one of those is already a token in `app/lib/design/tokens.dart`. No new
colour was invented. `recolour.py` in this folder reproduces both files.

## What the size tests say, honestly

- **48px, the app drawer.** All three, the reference included, are busy at this
  size. The S and the coin still read; the bar chart becomes a smudge and the
  peso becomes a dot. That is the reference's own composition rather than
  anything the recolour did, and it is the one thing worth knowing before this
  ships.
- **The circle mask**, the harshest launcher crop: both survive, and the chart
  in the bottom right is the part that gets clipped.
- **The home screen grid**, against measured competitor colours: the dark tile
  is clearly distinct from everything in the row. The light tile is closer to
  MariBank and Shopee in hue but far apart in value, so it still separates. That
  value gap is the real asset: Salapify's deepest ramp stop has a relative
  luminance of 0.449 against MariBank's 0.258 and Shopee's 0.237.

## One thing to decide before it ships

The peso glyph is the most documented visual cue of the Philippine quick cash
lending category, and Salapify must never be filed under that. The founder's
reference has one, and it is kept here because the direction was explicit. It is
flagged, not argued: worth a second look before the store listing goes live, and
easy to drop later since it is one element.

## Production notes for when this becomes a real asset

- These are rasters. The real launcher asset should be rebuilt as vector so it
  can carry an adaptive icon's separate background and foreground layers.
- **Android 16 QPR2 forces themed icons and apps cannot opt out.** Where an app
  ships no monochrome layer the system generates one from the artwork, so a
  monochrome layer has to be authored by hand or it will be a surprise on the
  founder's phone.
- Play masks the listing icon at **30 percent** and adds its own drop shadow, so
  the asset is submitted as a full square with no rounded corners of its own.
  That is why the corners here are filled rather than left transparent.

## The four rounds before this

Kept short, because the direction above supersedes all of them.

1. Six flat symbols centred on plain tiles. All rejected: one idea, six times.
2. Eleven references, eight compositional devices. Rejected with "make it
   related to Salapify or Pan atleast".
3. Seven directions from Salapify's own material. The founder picked **Buto**, a
   coffee bean whose crease is an S. This round also found what Pan actually is
   (a panda cradling a cup of **kapeng Barako**), which is why the palette is
   warm: the theme system is named after coffee.
4. Five refinements of Buto, answering "the S is too hidden". Green and
   delivered, and superseded by the reference above.

Two findings from those rounds still bind and are kept here because they cost
real time to learn:

- **Never clear a shape with `BlendMode.clear` in single layer icon artwork.**
  It does not reveal what is underneath, it punches a hole through the whole
  tile, so the shape takes the wallpaper's colour: near black on a dark home
  screen, white on a light one. Round three shipped that defect through every
  render and nobody saw it until the two home screens were compared.
- **A contrast ratio is about two flat colours meeting, and a Play tile is not
  two flat colours meeting.** Orange measures 1.61 against Play's white listing
  page, and three rounds concluded from that number that an orange tile loses
  that surface. It does not: Play adds its own drop shadow and the shadow
  supplies the edge the colour does not. Only a near black tile genuinely loses
  a surface, and it is the dark one it loses.

## The vector harness

`app/test/shots/icon_preview.dart` still renders vector candidates at review
size, at 48px, under the circle mask, in both home screen grids and in a Play
search result on both of Play's surfaces:

    cd app
    flutter test test/shots/icon_preview.dart --update-goldens
