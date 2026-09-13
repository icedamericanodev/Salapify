# The Salapify app icon

## Start here: there isn't one

Verified 2026-09-13. Both the shipped app in `flutter/` and the rebuild in
`app/` carry the **stock Flutter logo**, byte for byte identical across all five
mipmap densities. The blue Flutter F is what sits on the founder's phone right
now under the name Salapify.

Neither app has an **adaptive icon** either, so Android 8 and later cannot fill
the launcher's own shape and instead shrink that legacy PNG inside a white blob.

## Two expert passes, and they agreed

Run in parallel with deliberately different lenses, because this artefact is
both a brand mark and a storefront asset.

The store pass predicted the brand pass would disagree with it. **It did not.**
Both independently landed on the same two things:

1. **Loud, not quiet.** A full-colour tile, not a cream or warm-black one.
2. **Peso-derived, and DRAWN rather than typed.** Not the keyboard character.

That convergence from two different starting points is the strongest signal in
this whole exercise.

### Why loud won, measured rather than argued

| Tile | vs Play's white listing page | vs Play's dark surface |
|---|---|---|
| Quiet cream `#FFEEDF` | **1.13:1** | 16.55:1 |
| Quiet warm black `#14100D` | 18.92:1 | **1.01:1** |
| Loud hero ramp, lightest stop | 1.33:1 | 8.90:1 |
| Loud deep ramp, lightest stop | 1.61:1 | 6.06:1 |

A quiet tile forfeits its own edge on one of Play's two surfaces by physics.
Cream is invisible on the white listing page; warm black is a hole on the dark
one. The founder asked to see both and both are rendered below, but this is a
measurement, not a preference.

### Why the peso is drawn and not typed

Plus Jakarta Sans has a peso glyph, but it is tuned for a 15 point line of
text: thin bars, small counter, delicate joints, all of which turn to mush at
icon size. So the mark is redrawn at icon weight, with the relationship to the
family kept honest by ratio instead. Stem 8 over cap height 44 is 0.18, which
is exactly where Jakarta ExtraBold sits, so mark and wordmark read as the same
weight in a lockup.

There is also a commercial reason, and it is the sharper one. In the Philippine
market a bare typed peso sign on a hot tile is the visual signature of the
quick-cash lending category. It would pull install intent from people looking
for a loan rather than a tracker, and those installs churn in a day and leave
one-star reviews. A custom mark reads as a brand; a typed symbol reads as a
utility.

## Where the two passes DID disagree, and how it was settled

The store pass wanted a deeper, more saturated tile so it keeps an edge on the
Play listing. The brand pass wanted the app's own hero panel, which is lighter.

The store pass proposed cream ink on a deep orange ramp as its fix. **That fix
was measured and it fails**: cream `#FFEEDF` on `#FF9A52` is **1.86:1**, far
under the 3:1 bar for a non-text mark. It would have shipped a glyph that
disappears at the light end of its own gradient.

The brand pass had already measured the mirror-image trap: the accent orange
`#B03C09` on the darkest hero stop is **2.85:1**, also failing. Orange on
orange is tempting in a mockup and measurably illegible.

So both obvious fixes fail, and the ink has to stay near black. **Piso deep**
below is the resolution: the hero ramp shifted one step deeper, which improves
the tile edge from 1.33 to 1.61 while holding the ink at **5.72:1** worst case.
It is the only option tested that satisfies both arguments.

## The candidates

Each row: the tile at review size, at **48px** (the app drawer, where fine
detail dies), and with the Android safe zones drawn over it. The cyan circle is
the only area guaranteed visible on every launcher shape.

![The candidates](icon-sheet.png)

## On a home screen, beside what it competes with

"Does it stand out" is unanswerable for an icon on its own and obvious in a
grid. The neighbour tiles are plain colours with one letter: colour
placeholders for a private review, not reproductions of anyone's logo.

**Orange is the open lane.** Blue is closed (the banks and the big wallets),
green is second-most crowded, purple is filling fast, and amber sits next to
the cash-lending category. Nobody owns warm red-orange in Philippine personal
finance.

| Light home screen | Dark home screen |
|---|---|
| ![Light](icon-home-light.png) | ![Dark](icon-home-dark.png) |

## What the pictures caught that the specs did not

- **The S was rendering as a squiggle.** SVG's sweep flag and Flutter's
  `clockwise` are the same idea with opposite spellings, and the first build
  had both backwards. Invisible to the analyzer, obvious the moment the sheet
  was looked at.
- **The Beam is the weakest of the three at icon size.** Its own designer said
  so in writing (two opposing arrows is the international sign for transfer,
  sync and swap, so it is the most meaningful and the least ownable) and the
  render agrees: at 48px it reads as two blobs rather than as arrows.
- **The peso's two crossbars soften at 48 physical pixels.** This is the honest
  cost of the recommended direction. It is a softening, not a failure, and it
  only bites on old mdpi hardware and shrunk thumbnails. The fix if it ever
  matters is small and does not change the design: thicken the bars to 8 and
  open the gap to 9.

## The verified Play spec

From Google's own current documentation, because two numbers commonly repeated
are out of date:

- 512 x 512, 32-bit PNG, sRGB, under 1024KB
- Submit a **full square**: "radius will be equivalent to **30%** of icon size",
  not the 20% still widely quoted
- "Google Play will dynamically add a drop shadow around the final icon once
  uploaded", so **do not bake one in**
- Launcher icon is a **separate asset**: adaptive, 108dp canvas, mark inside the
  66dp safe circle
- A **monochrome layer** is needed too, or Android's themed icons derive one
  automatically from a full-bleed tile and it comes out as a featureless blob

## How these are made

    cd app
    flutter test test/shots/icon_preview.dart --update-goldens

Drawn in Flutter against `lib/design/tokens.dart`, so the candidates read the
same hex values the app ships and an approved icon cannot drift from the
palette by a digit nobody would catch.
