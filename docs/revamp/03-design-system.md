# 03. Design system: Papel

One theme. Light is the primary look and the reference; dark ("Tinta") is
an option the user can switch to, derived from the same tokens. No theme
picker. The old app's four themes are retired; they can return in Phase 5
if the founder misses them.

Decided 2026-09-12 after the first draft was rejected as a Tarsi copy and a
five-reviewer panel (Flutter UX, user panel, product, brand, competitor
benchmark) converged on the same mix. The reasoning is in
07-decisions.md, D7 to D11.

## The idea in one sentence

Salapify is your utang notebook, typeset: the ledger you would keep by
hand if you were good at it.

Two sources, one result. The kwaderno (the sari-sari store listahan) gives
the feeling: cream paper, ink, rows that read name, dots, amount, and a
stamp when something is settled. Editorial typesetting gives the
discipline: one serif number per screen, rules instead of cards, nothing
decorative. Every finance app has cards on a dark grid. Nobody has a ledger.

## What makes it unmistakable

Three devices, and only three. Everything else in the app is plain.

1. **The ledger row.** Label on the left, a dotted leader, the amount on
   the right, a hairline below. Every list of money in the app is this row.
   No cards around rows, no icons in front of them. Recognisable from a
   two-row crop.
2. **The serif hero.** One display amount per screen, set in Fraunces, with
   a small terracotta peso sign. No card behind it. A hero never carries a
   minus; "over by ₱720" is written out instead.
3. **The stamp.** A tilted outlined "BAYAD NA · paid" in the accent, over a
   settled utang or a reached goal. It appears once, on the moment of
   settling, then the row leaves the list. Never on ordinary rows, splash
   screens, empty states, or more than once in an ad. Its rarity is its
   value.

What was deliberately left out, and must stay out: ruled lines across the
page (they fight real line heights and cut contrast), a red margin line
(20 dp gone on a small phone), a handwriting font (reads as a template),
ring gauges, sparklines in cards, a mascot, gradients, confetti. The
notebook is a feeling, not a costume. The kit test asserts at most one
stamp per rendered screen.

## Colour

Semantic tokens only; no screen ever names a hex. The contrast test is the
judge; the values below are the starting point and change if it fails.

Papel (light, the reference):

| Token | Value | Used for |
|---|---|---|
| bg | #F5EEE3 | the page, paper cream |
| surface | #FCF8F1 | sheets, inputs, the few raised things |
| border | #E3D8C8 | hairlines between rows |
| rule | #221A14 | the 2 dp rule above a section |
| text | #221A14 | ink: labels, amounts, body |
| textSecondary | #6B5D51 | captions, dates, kickers |
| textMuted | #9A8C7E | placeholders, disabled |
| accent | #A8390F | terracotta: the peso sign on a hero, the Log button, links, the stamp, the active tab |
| onAccent | #FFFFFF | text on accent |
| positive | #1F6B3F | money in, under budget, settled |
| negative | #A31D3A | genuine risk only: overdue, over limit |
| warning | #8A5A00 | due soon, near limit |
| overlay | #221A14 at 40% | behind sheets |

Tinta (dark, the option): the same page as an ink page.

| Token | Value |
|---|---|
| bg | #15100C |
| surface | #1F1813 |
| border | #2E251E |
| rule | #F3EBDD |
| text | #F3EBDD |
| textSecondary | #B3A595 |
| textMuted | #7D7062 |
| accent | #EE7A45 |
| onAccent | #1A0C05 |
| positive | #5BCB86 |
| negative | #FF6F7D |
| warning | #FFC24D |
| overlay | #000000 at 60% |

Rules:
- Terracotta is the only accent and it is not the green every finance app
  uses. Accent means "press me" or "the one number". Never a background
  wash, never body text.
- An ordinary expense is ink with a minus sign. Negative is for risk. If
  everything is red, nothing is.
- Positive is money in and a settled debt. Not decoration.
- Category colours are a fixed set of eight hues in a colour-blind-safe
  order, assigned by slot, shown only in chips and the spending breakdown.
- What flips between Papel and Tinta: bg, surface, border, rule, the text
  ramp, the accent shade, the positive and negative shades. What never
  flips: type scale, rule thicknesses, dot leaders, spacing, row height,
  the stamp shape, where the peso sign sits.

## Typography

Two families, both already licensed and bundled: Fraunces (serif) and Plus
Jakarta Sans. Fraunces appears in exactly two places: the hero amount and
the cycle title ("Sept, 2nd half"). Jakarta is everything else, including
every row amount, because Fraunces has no tabular figures and a ledger
must not jiggle.

| Role | Family | Size / line | Weight | Notes |
|---|---|---|---|---|
| display | Fraunces | 60 / 64 | 700 | the hero amount on Home |
| hero | Fraunces | 40 / 44 | 700 | hero amount on other screens |
| cycleTitle | Fraunces | 28 / 34 | 600 italic | the cycle name in a header |
| title | Jakarta | 24 / 30 | 700 | screen titles |
| heading | Jakarta | 18 / 24 | 600 | card and sheet titles |
| body | Jakarta | 16 / 22 | 400 | sentences, row labels |
| amountRow | Jakarta | 17 / 22 | 700 tabular | every row amount |
| label | Jakarta | 14 / 20 | 600 | buttons, chips |
| caption | Jakarta | 12 / 16 | 400 | dates, secondary detail |
| kicker | Jakarta | 11 / 14 | 700 | uppercase, letter spacing 1.6, the section names |

Rules:
- The peso sign on a hero is Jakarta 800, accent, 60% of the digit cap
  height, aligned to the baseline. On rows it is omitted; the column is
  pesos by definition, and the currency shows once in the section kicker
  when it is not pesos.
- Centavos show on rows below label size, hidden on heroes unless non-zero.
- No raw TextStyle in features/. The type discipline test fails on one.

## Spacing and shape

A 4-point grid: 4, 8, 12, 16, 20, 24, 32, 40, 48. Screen gutter 24 (paper
has margins). Section kicker to its rule 8. Rule to first row 4. Between
sections 28. Ledger rows are 48 tall.

Shapes are mostly none. Rules and hairlines do the work. Where a radius
exists:

| Token | Radius | Used for |
|---|---|---|
| control | 10 | inputs, chips, secondary buttons |
| sheet | 24 | bottom sheets, top corners only |
| pill | 999 | the Log button, the active tab, category dots |

No shadows in Papel except one soft shadow under the open Log sheet. None
in Tinta. No cards on Home, Ledger, Plan, or Accounts. A sheet is a piece
of surface-coloured paper sliding up over the page.

## Motion

Three verbs, one curve (ease out cubic), plus the stamp.

| Verb | Where | Duration |
|---|---|---|
| settle | any press | 150 ms, scale to 0.97, light haptic |
| move | sheets, tab switches, row insert and remove | 250 ms |
| count | any amount that changes while visible | 400 ms, digits roll in tabular columns |
| stamp | a debt cleared or goal reached | 400 ms, scale 1.3 to 1.0 with a medium haptic, then the row leaves after 1.2 s |

Reduce-motion turns every duration to zero and shows the stamp static;
that contract is tested. No ambient loops, no shimmer.

## Iconography

Almost none. The ledger does not use icons in front of rows. Icons appear
in the tab bar (Material Symbols Rounded, weight 400, size 24), on
top-right actions, and inside sheets. Category icons remain the user's
emoji in chips only, because they are user data.

## Components

| Component | What it is |
|---|---|
| AppScaffold | page background, safe area, the cycle header row ("Sept, 2nd half · 4 days to payday"), optional trailing action |
| HeroAmount | Fraunces amount with the accent peso sign, one sentence under it, no card |
| SectionRule | kicker text, then the 2 dp rule |
| LedgerRow | label, optional caption, dotted leader, tabular amount; 48 tall; hairline below; the only list row |
| Stamp | the tilted outlined BAYAD NA label, animated once |
| AmountText | every peso figure: sign, tabular, centavo rule, rolling |
| Chip | selectable pill, used only in the Log sheet and filters |
| Segmented | two to four options in one control |
| PrimaryButton, SecondaryButton, TextButton | the three button kinds; primary is terracotta |
| Input | text and amount fields; the amount field opens a numeric pad and formats live |
| Sheet | surface paper sliding up, sheet radius, drag handle, overlay |
| ThinBar | a 4 dp rule that fills, for budget categories only |
| Chart | bar, line or breakdown, drawn with CustomPainter in ink and accent, always with a caption sentence |
| EmptyState | one sentence, one action, no illustration |
| Toast | bottom strip with Undo, 4 seconds |

Every component renders in Papel and Tinta in app/test/shots/kit_shot.dart,
and that sheet of pictures is the first thing rendered in Phase 2.

## What is locked, and what stays open

Locked once Phase 1 approves the mockups: the accent, the two type
families and where each is allowed, Papel as the reference with Tinta
derived, exactly one way to render a peso amount, the ledger row physics,
the stamp as the only celebration, no cards on the main screens, and the
tab bar shape.

Open: the icon glyphs, chart styling, Tinta tuning, spacing polish, copy,
and whether the cycle header appears on every screen or only Home, Plan
and Ledger.

## The two-week test

Build Home and Log only, in these tokens, and use them daily for fourteen
days. Zero edits to the token file and Home still feels like yours on day
fourteen means the theme was right. Three or more edits, or the urge to
add a second accent, means it was wrong, and the fix is to drop the paper
and keep the typeset half.
