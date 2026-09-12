# 03. Design system: Sinag

One theme. Light is the primary look and the reference; dark is an option
the user can switch to, derived from the same tokens. No theme picker. The
old app's four themes are retired; they can return in Phase 5 if the
founder misses them.

Decided 2026-09-12 by the design-director agent, from a moodboard, not from
words. The founder rejected the first draft (a Tarsi-style dark template),
then the Papel and Kwaderno notebook look, then four more text-driven
variants, and asked for an agent to own the design. The agent put twelve
real light-mode screens on the founder's Figma moodboard, the founder
delegated the keep-or-kill round ("I'll let the expert agent decide then
I'll review"), and Sinag is what the keeps add up to. The full derivation,
with what each choice came from, is in 07-decisions.md, D7 to D12, and the
keep-or-kill list is reproduced there.

Sinag is Filipino for a ray of sunlight. Light mode is the sun; dark mode is
the same room at night.

## The idea in one sentence

A warm white screen with one coral accent, where money sits in soft coloured
pills (small rounded chips behind a number) on a payday rail (a line that
runs from last payday to next), so the app reads as friendly and modern,
like a health or habit app, never like a bank.

## What makes it unmistakable

Three devices, and only three. Everything else in the app is plain.

1. **The payday rail.** A horizontal track at the top of Home, Plan and
   Ledger, running from last payday to next. Filled in positive green up to
   today, grey after, with a coral dot for today and small dots for the
   bills still to come. Under it, in the display face, "4 days to payday",
   and in caption "Sep 1 to Sep 15". It is the app's clock and the payday
   cycle's home. No other money app has a rail for a sweldo cycle.
2. **The utang beam.** One horizontal bar split in two: the left part in
   positiveSoft carrying the amount owed to you, the right part in
   accentSoft carrying the amount you owe, widths proportional to the
   amounts, labels above, and one sentence under it: "Net, you owe
   ₱8,500.00". Utang both ways in one glance, never two stat boxes.
3. **The amount pill.** Any amount that carries a state sits in a soft
   tinted pill: green for money in, coral for due within seven days, amber
   for near a limit, red for over. Plain amounts sit bare in text colour.
   Cropped to two rows, the pills alone say Salapify.

Why this is not a known parent: Tarsi, Copilot and Ivy are dark with cards;
Monarch is serif and cream; Revolut and Cash App are hero card and grid;
YNAB has pills but on a blue gradient. Nothing has a payday rail or a
two-way utang beam.

What was deliberately left out, and must stay out: paper or beige
backgrounds, serif type anywhere, handwriting fonts, rubber stamps, dotted
leaders, charcoal cards on near-black, a hero card with a sparkline, a
two-column stat grid, a round button in the middle of the tab bar (the Log
button is a pill at the right end of the bar), gradients, confetti,
mascots, illustrations, icon grids for categories, neon accents, a second
accent, a theme picker.

## Colour

Semantic tokens only; no screen ever names a hex. The contrast test is the
judge; the values below were measured with the WCAG formula (body text
needs 4.5, large text 3.0) and change if the test says so.

Sinag (light, the reference):

| Token | Value | Used for | Contrast |
|---|---|---|---|
| bg | #F6F4F0 | the page, a warm light grey that reads white | text on it 15.9 |
| surface | #FFFFFF | the three tiles, sheets, inputs, the rail track | text on it 17.5 |
| border | #E4DFD7 | hairlines between rows, tile outlines where two white things touch | decorative |
| text | #1C1917 | labels, amounts, body | |
| textSecondary | #5C5751 | captions, dates, section labels | 6.5 on bg |
| textMuted | #8A847C | placeholders and disabled only, never body | 3.4 on bg, large text only |
| accent | #BE3A1B | coral: the Log button, links, the today dot, amounts due within seven days | 5.0 on bg |
| accentEdge | #8F2A12 | the 3 dp bottom edge on the two primary buttons | decorative |
| onAccent | #FFFFFF | text on accent | 5.5 |
| accentSoft | #FCE8E1 | the pill behind an accent amount, the selected chip | accent on it 4.7 |
| positive | #1B7A47 | money in, owed to you, under budget, payday | 4.9 on bg |
| positiveSoft | #DCF3E4 | the pill behind a positive amount, a settled row | positive on it 4.6 |
| negative | #B91F2E | overdue, over budget, real risk only | 5.8 on bg |
| negativeSoft | #FBE1E2 | the pill behind a negative amount | negative on it 5.2 |
| warning | #8F5600 | due soon, near a limit | 5.5 on bg |
| warningSoft | #FBEAC9 | the pill behind a warning amount | warning on it 5.1 |
| overlay | #1C1917 at 40% | behind sheets | |

Sinag at night (dark, the option): every hue kept, the ground flipped to a
warm dark brown-grey, not black, and no charcoal card grid.

| Token | Value | Contrast |
|---|---|---|
| bg | #1A1815 | text on it 15.8 |
| surface | #25221E | text on it 14.1 |
| border | #38332D | decorative |
| text | #F5F1EB | |
| textSecondary | #B7B0A6 | 8.3 on bg |
| textMuted | #847D74 | 4.4 on bg |
| accent | #FF8A6A | 7.7 on bg |
| accentEdge | #C2532F | decorative |
| onAccent | #2B0F07 | 7.8 |
| accentSoft | #43261E | accent on it 5.9 |
| positive | #62D394 | 9.5 on bg |
| positiveSoft | #1F3B2C | positive on it 6.6 |
| negative | #FF8085 | 7.3 on bg |
| negativeSoft | #43272A | negative on it 5.6 |
| warning | #F3BC55 | 10.2 on bg |
| warningSoft | #3F3117 | warning on it 7.3 |
| overlay | #000000 at 60% | |

Rules:
- Coral is the only accent. Accent means "press me", "today", or "due
  soon". Never a background wash, never body text.
- An ordinary expense is text colour, bare. Negative is for risk. If
  everything is red, nothing is.
- Positive green is the only other strong colour and it means money coming
  to you: income, payday, owed to you, settled.
- Category colours do not exist. Categories are the user's emoji, in chips.
- What flips between light and dark: bg, surface, border, the text ramp,
  the accent and status shades and their soft tints. What never flips: the
  type scale, radii, spacing, the rail, the pill shape, where the peso sign
  sits.

## Typography

Two families, both on Google Fonts and both present in the Figma file:
Bricolage Grotesque (a bold sans with character, the display face) and DM
Sans (a clean geometric sans with tabular figures, the body face). Tabular
figures means every digit is the same width, so a column of amounts never
jiggles.

Bricolage appears in exactly three places: the hero amount, the screen
title, and the payday rail label. DM Sans is everything else, including
every row amount and every number inside a pill.

| Role | Family | Size / line | Weight | Notes |
|---|---|---|---|---|
| display | Bricolage | 56 / 60 | 800 | the hero amount on Home; the centavos at 32 |
| hero | Bricolage | 40 / 44 | 800 | hero amount on other screens and in the Log sheet |
| title | Bricolage | 26 / 32 | 700 | screen title, sheet title |
| railLabel | Bricolage | 18 / 24 | 600 | "4 days to payday" |
| section | DM Sans | 12 / 16 | 700 | uppercase, letter spacing 1.2, the section labels |
| body | DM Sans | 16 / 22 | 400 | sentences, row labels |
| amountRow | DM Sans | 16 / 22 | 600 tabular | every row amount, every pill amount |
| label | DM Sans | 14 / 20 | 600 | buttons, chips, tabs |
| caption | DM Sans | 13 / 18 | 400 | dates, secondary detail |

Rules:
- The peso sign on a hero is DM Sans 700, accent, about half the digit
  height, raised to the cap line. On rows and in pills it is set in the
  same face and colour as the digits.
- Centavos always show, on rows and on heroes (₱1,250.00, ₱6,240.00).
- No raw TextStyle in features/. The type discipline test fails on one.

## Spacing and shape

A 4-point grid: 4, 8, 12, 16, 20, 24, 32, 40. Screen gutter 20. Row height
56. Between sections 24.

| Token | Radius | Used for |
|---|---|---|
| pill | 999 | amount pills, chips, buttons, the segmented control, the Log button |
| tile | 20 | the three white tiles: the rail, the utang beam, the sheet (top corners) |
| input | 14 | text and amount fields |
| tiny | 8 | the ThinBar ends |

Borders, never shadows. A white tile on the warm grey page separates itself
by tone alone; a 1 dp border in border colour is added only where two white
things touch, and in dark mode on every tile. One soft shadow exists in the
whole app, under the open Log sheet.

Rows are separated by a 1 dp hairline, never boxed. Only three things are
ever a white tile: the payday rail, the utang beam, and the Log sheet.
Everything else sits directly on the page.

The chunky edge: the Log button and the Save button carry a 3 dp solid
bottom edge in accentEdge so they look pressable. No other element has it,
so the app never reads as Duolingo.

## Motion

Five verbs, one curve (ease out cubic).

| Verb | Where | Duration |
|---|---|---|
| settle | any press | 150 ms, scale to 0.97, light haptic |
| glide | sheets, tab switches, row insert and remove | 250 ms |
| roll | any amount that changes while visible | 400 ms, digits roll in tabular columns |
| fill | the rail and every ThinBar, on first appearance | 400 ms, from the left |
| clear | a settled utang row | turns fully positiveSoft, holds 1.2 s, then slides out; medium haptic; the one celebration |

Reduce-motion turns every duration to zero. No ambient loops, no shimmer,
no confetti.

## Iconography

Salapify's own icons are Material Symbols Rounded, weight 400, size 22, in
the tab bar, on top-right actions, and inside sheets. Rows carry a monogram
circle (the account's or person's initials on surface with a border) as
their only decoration. Category icons remain the user's emoji in chips only,
because they are user data.

## Components

| Component | What it is |
|---|---|
| AppScaffold | page background, safe area, the screen title row with an optional trailing action, the tab bar |
| PaydayRail | the white tile with the rail label, the caption, the track, today, the bill dots and the two end labels |
| UtangBeam | the white tile with the two-part bar, its labels, and the net sentence |
| HeroAmount | Bricolage amount with the accent peso sign, one sentence under it, no card |
| SectionLabel | the uppercase DM Sans label, optional trailing "See all" |
| Row | monogram (optional), label, caption, amount or pill; 56 tall; hairline below; the only list row |
| AmountPill | a tinted pill around an amount in one of four states |
| AmountText | every peso figure: sign, tabular, centavos, rolling |
| ThinBar | a 4 dp bar that fills, for budgets, credit limits and utang progress |
| Chip | selectable pill, used in the Log sheet and filters |
| Segmented | two to four options in one pill-shaped control |
| PrimaryButton, SecondaryButton, TextButton | the three button kinds; primary is coral with the chunky edge |
| Input | text and amount fields; the amount field opens a numeric pad and formats live |
| Sheet | surface sliding up, tile radius on top, drag handle, overlay, the one shadow |
| Chart | bars or a line drawn with CustomPainter in border, positive and accent, always with a sentence under it that contains a number |
| SettledRow | a row on positiveSoft with a strikethrough label, a green caption and a check |
| EmptyState | one sentence, one action, no illustration |
| Toast | bottom strip with Undo, 4 seconds |

Every component renders in light and dark in app/test/shots/kit_shot.dart,
and that sheet of pictures is the first thing rendered in Phase 2.

## Where it lives outside the repo

The Figma file "Salapify 3 Design" holds the same decision in three pages:
the moodboard it came from, the tokens (two variable collections, Sinag
Light and Sinag Dark, with a swatch sheet and a type sheet beside them), and
the screens. The repo is the source of truth; when the two disagree the
markdown wins and Figma is updated to match.

## What is locked, and what stays open

Locked once Phase 1 approves the mockups: the accent, the two type
families and where each is allowed, light as the reference with dark
derived, exactly one way to render a peso amount, the rail, the beam and
the pill, the clear as the only celebration, no cards on the main screens
beyond the three tiles, and the tab bar shape.

Open: the icon glyphs, chart styling, dark tuning, spacing polish, copy,
and whether the rail appears on Ledger or only on Home and Plan.

## The two-week test

Build Home and Log only, in these tokens, and use them daily for fourteen
days. Zero edits to the token file and Home still feels like yours on day
fourteen means the theme was right. Three or more edits, or the urge to add
a second accent, means it was wrong, and the fix is to go back to the
moodboard, not to words.
