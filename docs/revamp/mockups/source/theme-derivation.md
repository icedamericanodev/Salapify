# Salapify 3 theme: Sinag (sunlight)

## 1. Name

Sinag. Filipino for a ray of sunlight. Light mode is the sun; dark mode is the same room at night.

## 2. The idea in one sentence

A warm white screen with one coral accent, where money sits in soft coloured pills (small rounded chips behind a number) on a payday rail (a horizontal line that runs from last payday to next), so the app reads as friendly and modern, like a health or habit app, never like a bank.

## 3. Keep or kill, images 1 to 12

1. Things 3: calm. Taken: the word calm, and thin rules between rows instead of boxes. The blue accent is not taken.
2. Bear: coral. Taken: the coral accent on a clean white ground. The note-taking layout is not taken.
3. Craft: kill. Beige paper and serif body is the Papel look the founder already rejected.
4. Headspace: keep. Warm off-white ground, one strong orange, pill buttons, big bold sans headline, friendly without being childish. The illustration is not taken.
5. Duolingo: chunky. Taken: the thick bottom edge on the one primary button (the Log button) so it looks pressable. Nothing else; tiles and mascots are out.
6. Structured: rail. Taken: a vertical or horizontal timeline rail with coloured dots. Becomes the payday rail. The pastel pink is not taken.
7. Gentler Streak: keep. A chart that states its conclusion in a sentence, and a soft green band. Every Salapify chart gets a sentence.
8. Notion: kill. Dense monochrome list is exactly the boring the founder named.
9. Monarch: kill. Serif over cream plus a hero chart on top; known parent for two rejected variants.
10. YNAB: keep. Amounts inside soft coloured pills, playful and clear. The gradient background and the blue are not taken.
11. Spendee: kill. Generic icon grid on lavender; could be any finance app.
12. Ivy Wallet: kill. Dark cards with a teal income card and a black expense card; this is the rejected first draft.

Keeps: 4, 7, 10. Words taken: 1 calm, 2 coral, 5 chunky, 6 rail. Killed: 3, 8, 9, 11, 12.

The moodboard is private inspiration only. Nothing on it is copied into Salapify; what carries over is a colour feeling, a rail, a pill, and a sentence under a chart, all redrawn.

## 4. Light palette (Sinag)

Contrast ratios computed with contrast.py in this folder (WCAG formula). Body text needs 4.5, large text 3.0.

| Token | Hex | Used for | Contrast checks |
|---|---|---|---|
| bg | #F6F4F0 | the page, a warm light grey that reads white | text on bg 15.92 |
| surface | #FFFFFF | tiles, sheets, inputs, the rail track | text on surface 17.49 |
| surfaceRaised | #FFFFFF with a 1 px border | the open Log sheet only | same as surface |
| border | #E4DFD7 | hairlines between rows, tile outlines | decorative, 1.21 on bg (not text) |
| text | #1C1917 | labels, amounts, body | 15.92 on bg, 17.49 on surface |
| textSecondary | #5C5751 | captions, dates, kickers | 6.51 on bg, 7.15 on surface |
| textMuted | #8A847C | placeholders and disabled only, never body | 3.37 on bg, 3.70 on surface (large or non-text only) |
| accent | #BE3A1B | coral: the Log button, links, the today marker, amounts due within 7 days | 5.02 on bg, 5.51 on surface |
| onAccent | #FFFFFF | text on accent | 5.51 on accent |
| accentSoft | #FCE8E1 | the pill behind an accent amount, selected chip | accent on it 4.66, text on it 14.6 |
| positive | #1B7A47 | money in, owed to you, under budget, payday | 4.88 on bg, 5.36 on surface |
| positiveSoft | #DCF3E4 | pill behind a positive amount | positive on it 4.59 |
| negative | #B91F2E | overdue, over budget, real risk only | 5.80 on bg, 6.37 on surface |
| negativeSoft | #FBE1E2 | pill behind a negative amount | negative on it 5.15 |
| warning | #8F5600 | due soon, near limit | 5.46 on bg, 6.00 on surface |
| warningSoft | #FBEAC9 | pill behind a warning amount | warning on it 5.06 |
| overlay | #1C1917 at 40 percent | behind sheets | not text |

No second accent. Positive green is the only other strong colour and it means money coming to you.

## 5. Dark option (Sinag at night)

Derived by keeping every hue and flipping the ground to a warm dark brown-grey, not black, and no charcoal card grid.

| Token | Hex | Contrast checks |
|---|---|---|
| bg | #1A1815 | text on bg 15.75 |
| surface | #25221E | text on surface 14.07 |
| surfaceRaised | #25221E with a 1 px border | same |
| border | #38332D | decorative |
| text | #F5F1EB | 15.75 on bg |
| textSecondary | #B7B0A6 | 8.25 on bg, 7.37 on surface |
| textMuted | #847D74 | 4.36 on bg, 3.90 on surface |
| accent | #FF8A6A | 7.67 on bg, 6.86 on surface |
| onAccent | #2B0F07 | 7.75 on accent |
| accentSoft | #43261E | accent on it 5.93 |
| positive | #62D394 | 9.50 on bg |
| positiveSoft | #1F3B2C | positive on it 6.55 |
| negative | #FF8085 | 7.32 on bg |
| negativeSoft | #43272A | negative on it 5.55 |
| warning | #F3BC55 | 10.24 on bg |
| warningSoft | #3F3117 | warning on it 7.30 |
| overlay | #000000 at 60 percent | not text |

What flips: bg, surface, border, the text ramp, the accent and status shades and their soft tints. What never flips: type scale, radii, spacing, the rail, the pill shape, where the peso sign sits.

## 6. Type

Two families, both on Google Fonts and both present in Figma.

- Bricolage Grotesque (display face, a bold sans with character) is allowed in exactly three places: the hero amount, the screen title, and the payday rail label. Nowhere else.
- DM Sans (body face, a clean geometric sans with tabular figures, meaning every digit is the same width) is everything else, including every row amount and every number inside a pill.

| Role | Family | Size / line | Weight | Notes |
|---|---|---|---|---|
| display | Bricolage Grotesque | 56 / 60 | ExtraBold | the hero amount on Home; peso sign in DM Sans Bold 28, accent, on the baseline |
| hero | Bricolage Grotesque | 40 / 44 | ExtraBold | hero amount on other screens |
| title | Bricolage Grotesque | 26 / 32 | Bold | screen title, sheet title |
| railLabel | Bricolage Grotesque | 18 / 24 | SemiBold | "4 days to payday" |
| section | DM Sans | 12 / 16 | Bold, uppercase, letter spacing 1.2 | section labels |
| body | DM Sans | 16 / 22 | Regular | sentences, row labels |
| amountRow | DM Sans | 16 / 22 | SemiBold, tabular figures on | every row amount, every pill amount |
| label | DM Sans | 14 / 20 | SemiBold | buttons, chips, tabs |
| caption | DM Sans | 13 / 18 | Regular | dates, secondary detail |

Tabular figures are mandatory on amountRow, on the pill, and on the display amount. Centavos always show on rows (₱1,250.00) and on heroes.

## 7. Shape and spacing

- Spacing unit 4. Scale 4, 8, 12, 16, 20, 24, 32, 40. Screen gutter 20. Row height 56. Between sections 24.
- Radius scale: pill 999 (amount pills, chips, buttons, the Log button), tile 20 (the few white tiles: the rail card, the utang beam, the sheet), input 14, tiny 8 (the ThinBar ends).
- Border versus shadow: borders, never shadows. A white tile on the warm grey page separates itself by tone alone; a 1 px border in border colour is added only where two white things touch. One soft shadow exists in the whole app, under the open Log sheet.
- Card versus rule: rows are separated by a 1 px hairline, never boxed. Only three things are ever a white tile: the payday rail, the utang beam, and the Log sheet. Everything else sits directly on the page.
- The chunky edge: the Log button and the Save button carry a 3 px solid bottom edge in a darker coral (#8F2A12) so they look pressable. No other element has it.

## 8. The three signature devices

1. The payday rail. A horizontal track at the top of Home, Plan and Ledger, running from last payday to next. Filled in positive green up to today, grey after, with a coral dot for today and small dots for upcoming bills. Under it, in Bricolage, "4 days to payday" and in caption "Sep 1 to Sep 15". It is the app's clock and the payday cycle's home. No other money app has a rail for a sweldo cycle.
2. The utang beam. One horizontal bar split in two: the left part in positiveSoft with "Owed to you ₱3,500.00" and the right part in accentSoft with "You owe ₱12,000.00", widths proportional to the amounts, and one sentence under it, "Net, you owe ₱8,500.00". Utang both ways in one glance, never two stat boxes.
3. The amount pill. Any amount that carries a state sits in a soft tinted pill: green for in, coral for due within seven days, amber for near limit, red for over. Plain amounts sit bare in text colour. Cropped to two rows, the pills alone say Salapify.

Why this is not a known parent: Tarsi, Copilot and Ivy are dark with cards; Monarch is serif and cream; Revolut and Cash App are hero-card-and-grid; YNAB has pills but on a blue gradient with a mortgage list; nothing has a payday rail or a two-way utang beam.

## 9. Motion verbs

- settle: any press scales to 0.97 for 150 ms with a light haptic.
- glide: sheets and tab switches move in 250 ms, ease out.
- roll: a changed amount rolls its digits in tabular columns over 400 ms.
- fill: the rail and every ThinBar fill from left over 400 ms on first appearance.
- clear: a settled utang row turns fully green, holds 1.2 s, then slides out. The one celebration.

Reduce-motion sets every duration to zero.

## 10. Explicitly out

Paper or beige backgrounds. Serif type anywhere. Handwriting fonts. Rubber stamps. Dotted leaders. Dark charcoal cards on near-black. A hero card with a sparkline. A two-column stat grid. A round FAB in the middle of the tab bar (the Log button is a pill on the right of the bar). Gradients. Confetti. Mascots. Illustrations. Icon grids for categories. Neon accents. More than one accent. A theme picker.

## 11. Where each choice came from

- The warm off-white ground and the single strong warm accent came from image 4 (Headspace), kept.
- The coral hue itself came from image 2 (Bear), word taken: coral, then darkened until white text on it passed 4.5.
- The amount pill came from image 10 (YNAB), kept.
- The payday rail came from image 6 (Structured), word taken: rail, and from the founder's own Sweldo Timeline.
- Every chart stating a sentence came from image 7 (Gentler Streak), kept, and its soft green band became positiveSoft.
- Thin rules instead of boxed rows came from image 1 (Things 3), word taken: calm.
- The chunky bottom edge on the Log button came from image 5 (Duolingo), word taken: chunky, and it is limited to two buttons so the app does not read as Duolingo.
- The utang beam is Salapify's own, built to give utang both ways the room the vision asks for.
- Bricolage Grotesque was chosen because it is bold and characterful without being a serif or a poster face; DM Sans because it has tabular figures and reads quietly beside it.
- Dark values were derived by keeping hue and lifting lightness until each pair passed the same checks.
