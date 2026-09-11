# 03. Design system

One look, in dark and light. Dark is the reference because it is what the
founder uses. Every value here is a token in app/lib/design and the tests
in app/test/design are the judge of contrast and discipline, not this file.

Working name for the look: **Sweldo**. Calm, dark, one warm accent, big
tabular numbers. The name is internal; it never appears in the app.

## What was wrong with the current look, specifically

- Four themes and a lagoon-green default meant there was no signature. The
  wordmark is orange, the default theme was emerald. A person could not say
  what colour Salapify is.
- Three font families (Jakarta, Fraunces serif, IBM Plex for ledger rows).
  Serif display over sans body over a third face for amounts reads as three
  apps.
- Home was a column of cards each with an uppercase kicker, a title, a
  number, a sentence. Twelve identical rectangles is the "boring".
- Coffee names (Barako, caramel), a panda mascot, a lagoon palette and gold
  confetti pulled in four directions at once. That is the "weird".
- Charts drew shapes without numbers, so they decorated instead of told.

## Colour

One accent. Semantic tokens only; no screen ever names a hex.

Dark (reference):

| Token | Value | Used for |
|---|---|---|
| bg | #0D0D10 | screen background |
| surface | #16161B | cards, sheets |
| surfaceRaised | #1E1E25 | the one hero card per screen, inputs |
| border | #26262E | hairlines, dividers |
| text | #F5F4F0 | primary text and amounts |
| textSecondary | #A6A4AD | labels, captions |
| textMuted | #6E6C77 | placeholders, disabled |
| accent | #FF8A3D | the brand orange: primary buttons, the Log button, active tab, links, the peso sign on hero amounts |
| onAccent | #1A0E05 | text on accent |
| positive | #4ADE80 | income, money in, under budget, debt cleared |
| negative | #FF6B6B | overspent, overdue, credit utilisation danger |
| warning | #FFC94D | due soon, near limit |
| info | #6FA8FF | neutral highlights, transfers |
| overlay | #000000 at 60% | behind sheets |

Light:

| Token | Value |
|---|---|
| bg | #F7F6F3 |
| surface | #FFFFFF |
| surfaceRaised | #FFFFFF with the one soft shadow |
| border | #E8E6E1 |
| text | #17161A |
| textSecondary | #5F5D66 |
| textMuted | #8E8C95 |
| accent | #D9540E |
| onAccent | #FFFFFF |
| positive | #178A4E |
| negative | #D4372C |
| warning | #B8770A |
| info | #2F6FDB |

Rules:
- Red means risk, never "expense". An ordinary expense row is text colour
  with a minus sign. If everything is red, nothing is.
- Green means money in or a goal reached. Not decoration.
- Accent is for the things you can press and the one number that leads a
  screen. Never for body text, never as a background wash on cards.
- Category colours are a fixed set of eight hues in a colour-blind-safe
  order, assigned by slot, never generated. They appear only in category
  chips and the spending breakdown.
- Every text token must pass WCAG AA on bg, surface and surfaceRaised. The
  contrast test enforces it; a value that fails is changed, not excused.

## Typography

One family: Plus Jakarta Sans (already licensed and bundled). Every peso
figure uses tabular figures so digits line up and do not jiggle when they
roll.

| Role | Size / line | Weight | Notes |
|---|---|---|---|
| display | 40 / 44 | 800 | the one hero amount on Home |
| hero | 32 / 38 | 800 | hero amount on other screens |
| title | 24 / 30 | 700 | screen titles |
| heading | 18 / 24 | 600 | section headings, card titles |
| body | 16 / 22 | 400 | sentences, row labels |
| label | 14 / 20 | 600 | buttons, chips, row amounts |
| caption | 12 / 16 | 400 | dates, secondary detail |
| overline | 11 / 14 | 600 | uppercase, letter spacing 0.8, used rarely |

Rules:
- Amounts: weight 700 at every size, tabular, minus sign for money out, no
  plus sign for money in (the colour carries it). Centavos shown at label
  size and below, hidden on hero and display unless non-zero.
- The peso sign on a hero or display amount is set in accent, 60% of the
  digit size, aligned to the cap height. On row amounts it is text colour
  and full size.
- No raw TextStyle in features/. The type discipline test fails the build
  on one.

## Spacing

A 4-point grid: 4, 8, 12, 16, 20, 24, 32, 40, 48.

- Screen gutter 20.
- Inside a card 16.
- Between cards 12.
- Between a section heading and its first card 8.
- Between sections 24.
- List rows are 56 tall with a 12 gap between icon and text.

## Shape

| Token | Radius | Used for |
|---|---|---|
| control | 12 | buttons, inputs, chips |
| card | 20 | cards |
| sheet | 28 | bottom sheets, top corners only |
| pill | 999 | tab indicator, category dots, progress bars |

Hairline borders in dark (1 px border token), one soft shadow in light
(0 4 16 at 6% black). Never both.

## Elevation

Three tiers and nothing else: bg, surface, surfaceRaised. Exactly one
surfaceRaised element per screen, the hero. Sheets sit on surface over the
overlay.

## Motion

Three verbs, three durations, one curve.

| Verb | Where | Duration | Detail |
|---|---|---|---|
| settle | any press | 150 ms | scale to 0.97 and back, light haptic |
| move | sheets, tab switches, list insert and remove | 250 ms | ease out cubic |
| count | any amount that changes while visible | 400 ms | digits roll in tabular columns |

One earned celebration: clearing a debt or hitting a goal. Under two
seconds, accent and positive only, no confetti library. Reduce-motion turns
every duration to zero and replaces the celebration with a static state;
that contract is tested.

No ambient loops. No shimmer. No bouncing icons.

## Iconography

Material Symbols Rounded, one weight (400), one optical size (24). Icons are
textSecondary at rest, accent when they are the action, text when they are
the subject. Category icons are the user's emoji, as today, because they
are data the user chose.

## Components

The kit is small on purpose. A screen that needs a component not on this
list gets the component added to the kit first, with its test, then used.

| Component | What it is |
|---|---|
| AppScaffold | screen background, safe area, title row, optional trailing action |
| HeroCard | the one surfaceRaised card per screen: an overline, a display or hero amount, one sentence, optional action |
| Card | surface, card radius, 16 padding |
| SectionHeading | heading text with an optional "See all" on the right |
| AmountText | every peso figure in the app; handles sign, tabular, centavo rule, rolling |
| MoneyRow | icon or emoji, label, caption, amount on the right; 56 tall; the only list row |
| Chip | selectable pill for categories, accounts, filters |
| Segmented | two to four options in one control |
| PrimaryButton, SecondaryButton, TextButton | the three button kinds |
| Input | text and amount fields; the amount field opens a numeric pad and formats live |
| Sheet | bottom sheet with the sheet radius, drag handle, overlay |
| ProgressBar | pill, 6 tall, animated width |
| Sparkline | a tiny line for a card, no axes |
| Chart | bar, line, or breakdown, one grammar, always with a caption sentence |
| EmptyState | icon, one sentence, one action |
| Toast | bottom toast with Undo, 4 seconds |

Every component renders in dark and light in app/test/shots/kit_shot.dart,
and that sheet of pictures is the first thing rendered in Phase 2.
