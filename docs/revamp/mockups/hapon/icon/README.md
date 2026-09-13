# The Salapify app icon

## Start here: there isn't one

Verified 2026-09-13. Both the shipped app and the rebuild carry the **stock
Flutter logo**, byte for byte identical across all five mipmap densities.
Neither has an adaptive icon, so Android shrinks that logo inside a white blob.

## Round one was rejected, and the reason was compositional

Six candidates went out (a drawn peso, an S monogram, two opposing arrows, each
loud and quiet) and the founder rejected all of them.

The honest diagnosis is not that the palette or the constraints were wrong.
**All six were the same idea**: one flat symbol, centred, on a plain square
tile. Three subjects explored once each in one composition, presented as three
directions.

Part of that was imagination and part was the harness: a mark could only be
drawn ON a ground, so negative space, layering and overlap were not rejected,
they were unavailable. A tool that can express one composition produces one
composition every time, and it looks like taste.

An exploration pass then looked at eleven real references and named the
compositional **device** in each, because the device is the transferable part,
not the subject.

## Three measurements that changed the brief

**1. A one-value tile cannot hold an edge on both Play surfaces. A split tile
can.**

| Tile value | vs Play's white listing | vs Play's dark surface |
|---|---|---|
| `#FB9C52` loud | 2.10 | 8.90 |
| `#2A1207` quiet | 17.68 | 1.06 |
| A tile carrying **both** | 2.10 from one half | 8.90 from the other |

Round one treated loud versus quiet as taste. It is arithmetic, and no
single-value tile wins twice.

**2. Two hero-ramp tones cannot be told apart.** `#FFD9B0` against `#FB9C52`
measures **1.58**, under the 3.0 bar. So any layering direction needs a
deliberately chosen dark tone at the overlap, never a blend mode: a true
multiply of those two lands 1.18 from one of them.

**3. The 48px floor, once, as a number.** 108 units render at 0.667px each, so
**nothing thinner than 6 units and no gap under 6 units**. Round one's peso had
7-unit bars with an 8-unit gap, which is exactly why its write-up admitted they
softened.

## The eight directions

![The candidates](icon-sheet.png)

| Light home screen | Dark home screen |
|---|---|
| ![Light](icon-home-light.png) | ![Dark](icon-home-dark.png) |

## What the renders say, honestly

**Hapon** is the standout. A disc astride a horizon, inverting where it
crosses. It says "two directions" without drawing an arrow, which is what the
Beam failed to do, and it is the only direction whose TILE is measurably strong
on both Play surfaces. Simplest silhouette in the set, so it cannot break at
48px. Its stated risk is real: it could be read as a moon or a brightness
toggle.

**Capiz** is better than anyone predicted on paper. A cropped shell window with
late afternoon light through it, Filipino by substance rather than by flag or
jeepney. The grid-ambiguity risk is also real at 48px.

**Dalawa did not survive execution, and that is a finding rather than a
failure.** On paper it was two overlapping planes with the overlap as a third
colour. Rendered, the eight degree rotations do not read, the two planes are
1.58 apart and blend into one shape, and the dark overlap dominates so the tile
reads as a blob with a stripe. It is in the sheet because the founder should
see what was tried, not because it works.

**Overshoot** is unbreakable at any size and says nothing about money; it reads
as a landscape. **Piso Buo** is bold but busy. **Sobre** is clean and is openly
Monzo's device. **Resibo** is the safest and the least memorable, exactly as
predicted. **Counterweight** reads well but is 1.06 against Play's dark
surface.

## The references, and the device taken from each

Nothing was copied. Each was studied for its compositional move only.

| Reference | The device |
|---|---|
| [Pentagram, Slack](https://www.pentagram.com/work/slack/story) | Built around a hole, so the emptiness is the recognisable part |
| [Basic Apple Guy, Boardy](https://basicappleguy.com/basicappleblog/boardy) | A horizontal seam so the tile reads as two halves |
| [Flighty](https://apps.apple.com/us/app/flighty-live-flight-tracker/id1358823008) | One object at extreme scale, tilted, nothing else in frame |
| [Threads](https://apps.apple.com/us/app/threads/id6446901002) | A typographic counter blown so far past reading size it becomes a shape |
| [Nike Run Club](https://apps.apple.com/us/app/nike-run-club/id387771637) | Mark drawn bigger than the tile, running off two edges |
| [Todoist](https://apps.apple.com/us/app/todoist-to-do-list-planner/id572688855) | Bars of unequal length exiting an edge; length does the work |
| [Monzo](https://apps.apple.com/us/app/monzo-mobile-banking/id1052238659) | The tile itself is the mark, a single diagonal split, no glyph |
| [Halide Mark II](https://apps.apple.com/us/app/halide-mark-ii-pro-camera/id885697368) | Depth from flat facets meeting at hard edges, not a gradient |
| [Pentagram, Mastercard](https://www.pentagram.com/work/mastercard/story) | Two shapes overlapping, the overlap a third colour |
| [Capiz shell window](https://en.wikipedia.org/wiki/Capiz_shell_window) | A physical object: a grid of translucent panes diffusing tropical sun |

## Two colours that are NOT tokens

`#FFF3E6` (Capiz only, the hero ramp continued one step so the light has a
peak) and `#8A2F07` (Dalawa only, the one tone clearing 3.0 against both planes
at once, at 6.35 and 4.01). Both are icon-only and must never enter
`tokens.dart`.

## The verified Play spec

From Google's own current documentation, because two commonly quoted numbers
are out of date: 512 square, 32-bit PNG, sRGB, under 1024KB, submitted as a
**full square** because "radius will be equivalent to **30%** of icon size" and
"Google Play will dynamically add a drop shadow around the final icon once
uploaded". So no rounded corners and no baked shadow.

The launcher icon is a **separate asset**: adaptive, 108dp, mark inside the
66dp safe circle, plus a **monochrome layer** or Android's themed icons derive
a featureless blob from a full-bleed tile.

## How these are made

    cd app
    flutter test test/shots/icon_preview.dart --update-goldens
