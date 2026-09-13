# Coffee theme lock (f4.06)

Date: 2026-08-12. Founder directed. Presentation only. No money, data, or
schema change.

## Scope

The founder set the primary theme direction with a full design spec (light and
dark, a named color palette, typography, icon style, coffee illustrations) and
asked to lock ONE consistent primary theme now, with extra themes deprioritized.
This change retunes the primary Barako palette (light and dark) to that spec. It
is the "main theme and color" lock, not a full visual-system rebuild.

## What changed

Only `flutter/lib/theme.dart` (`_barakoLight`, `_barakoDark`) and the stamp.

Light:
- background cream `#FFF8F0`, cards white `#FFFFFF`, warm borders `#EDE1D0`
- brand `#6F4E37` (espresso) for buttons and small accents (passes AA on cream)
- text near-black warm `#241C15`, secondary warm taupe `#7A6A5C`
- positive surface latte `#F4E9D8`

Dark:
- ground near-black `#0F0F0F`, card mocha `#1C1A17`, raised cocoa `#2A231D`
- brand accent dopamine orange `#FF7A45` with a dark `onPrimary` `#241708` so a
  filled button label passes AA (white on this orange would not)
- text cream `#F5EDE1`

## What did NOT change

- No money math, sign, currency, precision, rounding, schema, or stored data.
- No screen logic, no navigation, no component behavior.
- The other 7 themes are untouched.
- The theme-invariant win gold (`celebrate`) is untouched, so the reward
  signature still reads identically across every theme.
- Pan's fixed signature orange (`#FF8A3D`) is untouched (a separate constant).
- Fonts unchanged (Plus Jakarta Sans + Fraunces). SF Pro from the spec is
  Apple-proprietary and cannot ship on Android; Jakarta is the close licensable
  equivalent already in use.

## Validation

- `palette_contrast_test`: all 16 palettes, both brightnesses, pass WCAG AA.
- `widget_contrast_test` (home tile), `pan_signature_test`, `update_stamp_test`:
  green.
- Full local suite green.
- Rendered every tab dark and light on the lived-in fixture, looked, and sent to
  the founder (dark first).

## Defect the gate caught

The cream background against a warm-white card measured 1.027 to 1, under the
1.03 surface-separation floor, meaning cards would have melted into the page.
Nothing an eye reliably catches; the deterministic sweep did. Fixed to white
cards (1.05 separation), which also matches the mockup's cards.

## Deferred follow-ups (scoped, noted to the founder)

- Map the dopamine data colors (green `#22C55E`, teal `#14B8A6`, blue
  `#60A5FA`) into the chart and category visualization palette, so Insights and
  Reports charts speak the same color language as the spec. This pairs with the
  fl_chart evaluation.
- Align Pan's signature orange to the dopamine orange if desired (touches Pan
  artwork and `pan_signature_test`); currently left as the established brand
  orange.
- Deeper surface and component polish toward the mockup (rounded line-icon
  treatment, illustration accents) as a later experience-system pass.
