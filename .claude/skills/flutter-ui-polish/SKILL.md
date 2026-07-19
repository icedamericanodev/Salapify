---
name: flutter-ui-polish
description: Use when building or refining any Flutter screen, card, button, chip, list, or sheet in Salapify and you want it to feel premium, not just functional. Triggers on "polish", "make it feel premium", "micro-interaction", "spacing", "radius", "shadow", "motion", "typography", "hierarchy", or designing a new screen.
---

# Flutter UI polish: the compound of small details

Design-engineering principles adapted for Salapify's Flutter app from
jakubkrehel/skills (better-ui, better-typography, better-colors, MIT,
interfaces.dev). The source is written for CSS/React; the PRINCIPLES carry
over, the syntax does not, so everything here is Flutter and Barako concrete.
Polish is the sum of many small correct details, not one big effect.

## Layout, depth, motion

- Concentric radius. A widget nested in a card must use inner radius = outer
  radius minus its padding. Barako cards are radius 20; a tile inside with 16
  padding wants roughly a 4 to 8 radius, not another 20. Mismatched radii are
  the most common thing that makes a screen feel off.
- Depth by shadow, not hard borders. Prefer the card elevation or a soft
  low-opacity BoxShadow over a solid 1px border. Reserve borders for the
  subtle chip outline.
- Scale on press. Give primary tappables tactile feedback: a press scale of
  0.96 (AnimatedScale or Transform.scale on tap down and up), never below
  0.95. HapticFeedback.selectionClick() on meaningful taps (chips, toggles),
  already used on the what-if cards.
- Animate specific properties, short and interruptible. 120 to 200ms with a
  real curve on the exact thing changing (AnimatedOpacity, AnimatedContainer,
  AnimatedSwitcher), never a blanket animate-everything. Stagger a section's
  children about 80 to 120ms apart for entrances. Exits are a small fade plus
  an 8 to 12px slide, not a full-height sweep.
- Icon state changes cross-fade (AnimatedSwitcher with a small scale plus
  fade), they do not pop.
- Every tappable is at least a 44 by 44 target (already the house rule).
- Optical over geometric. Nudge a chevron or play glyph a pixel or two so it
  looks centered, do not trust geometric center alone.

## Typography

- Line height: tight headings (Fraunces heroes about 1.05 to 1.1), comfortable
  body (1.4 to 1.5). Do not ship a hero at the default 1.2 plus.
- Tracking: slightly negative on large display headings; slightly positive on
  small uppercase labels (Barako.kickerStyle already sets letterSpacing 2).
- Tabular figures on every peso amount and numeric column
  (FontFeature.tabularFigures), so digits do not jitter when values change.
- Two fonts only, Fraunces for display and Plus Jakarta Sans for the rest.
  Never add a third.
- Sizes: body 14 to 16, captions 12 to 13, never smaller for real content.
- Cap long paragraph width on wide screens (a max width around 600 to 680) so
  a line never runs the full tablet width.

## Color

- WCAG AA is the floor: 4.5:1 for normal text, 3:1 for large. Verify Latte,
  Barako, and Milk Tea. Adjust LIGHTNESS to fix contrast, not chroma.
- Meaning never rides on color alone; pair warning and celebrate with an icon
  or word. Reserve those tokens for their real meaning, never as a fourth
  accent.
- Dark moods derive from the light one by flipping lightness, which is how the
  three Barako moods already relate. Keep hue steady across a ramp.

## House rules (these win over any external guidance)

- NEVER const on a color-bearing widget: const freezes the palette and breaks
  mood switching. Read Barako.x getters live.
- Pure Dart only for a polish pass, no new fonts or image assets, so it ships
  over the air with no APK rebuild.
- No em dashes or en dashes anywhere.

## Quick reference

press scale 0.96 · anim 120-200ms specific+interruptible · stagger ~100ms ·
concentric radius = outer - padding · hero line-height ~1.1 · tabular figures
on pesos · AA 4.5:1 fixed by lightness · no const on colored widgets.
