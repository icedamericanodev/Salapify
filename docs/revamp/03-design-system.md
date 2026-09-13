# 03. Design system: Hapon and Gabi

One theme. Hapon is the primary light look and the reference; Gabi is the
dark option, derived from the same hues rather than drawn a second time. No
theme picker. The old app's four themes are retired; they can return in
Phase 5 if the founder misses them.

Hapon is Filipino for late afternoon, the hour the light goes warm. Gabi is
night. They are one design at two times of day, and the renders prove it:
both come out of identical layout code, so the only thing that differs
between the two pictures is colour. Anything else that differs is a bug.

### Why not Umaga

The founder asked this on 2026-09-13 and the answer is settled, so it does
not need asking again. Umaga (morning) is the tidier opposite of Gabi, and
Hapon and Gabi are adjacent times rather than poles, which is a fair
objection. It loses anyway on the thing that matters more: the palette is
peach, apricot and amber, which is golden hour light. Morning light reads
cool and blue, so Umaga would name one thing and show another. Araw and
Liwanag were both offered as alternatives. The founder kept Hapon and Gabi:
being honest about the colour beats being tidy about the pairing.

## How it was chosen, so nobody reruns the experiment

Decided 2026-09-13 by the design-director agent, after the founder delegated
the choice ("I'll let the expert agent choose"). This is the fourth round.
What the first three taught, in order:

1. A dark card template was rejected: "It looks like we copy the Tarsi."
2. A paper-and-serif look and four more text-driven variants were rejected.
   The lesson recorded then still holds: design from pictures the founder
   reacted to, never from adjectives.
3. A minimalist round was rejected for the opposite reason, and this is the
   correction that mattered most: "you dont need to empty the screen to make
   it minimalist." Minimalist here means calm and ordered, not sparse. A
   screen with fourteen transactions on it can be minimalist. A screen with
   three is just empty.
4. The founder then released the gradient requirement ("even it is not
   graduent its okay you can explore. I just wanted to be clean and
   minimalist"), asked for orange ("Like light orange or graduent orange"),
   and asked for the page itself to be warm ("the background is kinda
   orangey too can you do something like that but very light").

Three candidates were built as real Flutter and measured. Hapon won on
numbers, not taste:

| Candidate | Page | Why it lost or won |
|---|---|---|
| Banaag | #FFF6EE | Warm but unnameable. A white card separates from it by only 1.068 to 1, so at forty transactions the list stops reading as grouped cards and turns into one white sheet. |
| Sikat | gradient #FFEBDA to #FFFCFA | The prettiest single screenshot and the worst daily screen. Its accent measures 4.48 to 1 on the warmest stop, which FAILS the 4.5 body bar, and the pale bottom gives a white card 1.022 to 1, which is invisible. Warm exactly where the hero already supplies colour, and colourless exactly where the lists live. |
| **Hapon** | **#FFEEDF** | **Flat, so every screen and every scroll position measures the same, and the best card separation of the three at 1.132 to 1.** |

The lesson worth keeping from that table: a page that changes colour as you
scroll changes every contrast ratio as you scroll, and one of Sikat's failed.

## The idea in one sentence

A warm peach page with white cards and one light apricot panel carrying dark
ink, so the app feels like late afternoon sun rather than a bank statement,
and stays readable at fourteen transactions.

## What makes it unmistakable

Three devices, and only three. Everything else is plain.

1. **The light hero panel.** A gradient block at the top of Home carrying
   DARK ink. Every fintech hero on the reference board is the other way
   round, a dark panel with white text, so this one device is what makes a
   cropped screenshot ours. It holds Safe to spend, the amount, one sentence,
   and the rail.
2. **The sweldo rail.** A 5 dp track inside the hero running from last payday
   to next, filled to today, with "4 days to payday" and "Sep 1 to 15" under
   it. It is the app's clock. No other money app has a rail for a Philippine
   payday cycle.
3. **The debt beam.** One 5 dp bar split in two on a white card: the left part
   in positive green carrying what is owed to you, the right in accent
   carrying what you owe, widths proportional, the two amounts above their
   own ends. Debt both ways in one glance, never two stat boxes.

What was deliberately left out, and must stay out: paper or beige grounds,
serif type, handwriting fonts, charcoal cards on near-black, a hero card with
a sparkline, a two-column stat grid, a round FAB in the middle of the tab bar
(the Log control is a labelled pill at the right end), confetti, mascots,
illustrations, icon grids for categories, neon accents, a second accent, a
theme picker, and black graphics of any kind.

That last one is specific and was learned late. The debt beam's "you owe"
half was originally solid near-black and became the loudest object on a page
that is supposed to feel energising. It is the accent now, and the app
contains no black graphics at all.

## Colour

Semantic tokens only; no screen ever names a hex. Every value below was
measured against WCAG BEFORE it was chosen, never after, and the ratio is
kept beside it in the token file so the next person does not have to trust
this table. Body text needs 4.5 to 1, large text 3.0, a meaningful non-text
element 3.0.

Hapon (light, the reference):

| Token | Value | Used for | Measured |
|---|---|---|---|
| bg | #FFEEDF | the page, flat, clearly orange rather than merely warm | text on it 16.48 |
| card | #FFFFFF | groups of rows, the debt beam | 1.132 separation from the page |
| line | #F3DFCD | the hairline between two rows inside a card | 1.293 on white, visible |
| text | #15120F | labels, amounts, body | 16.48 page, 18.66 card |
| text2 | #5A5148 | the date, quick-action labels, row icons | 6.86 page, 7.76 card |
| text3 | #6B6156 | captions and secondary detail, the ONE grey for them | 5.35 page, 6.05 card |
| accent | #B03C09 | the Log pill, links, the "you owe" half of the beam. Nothing else | 5.30 page, 6.01 card |
| onAccent | #FFFFFF | text on the accent | 6.01 |
| good | #16643F | money coming to you, and only that | 6.33 page, 7.17 card |
| bad | #9E2C1B | real risk only | 6.55 page, 7.42 card |
| discOnPage | #FFFFFF | the quick-action icon disc, which sits on the page | |
| discOnCard | #FFEEDF | the row icon disc, which sits on a card | |
| heroGradient | #FFD9B0 to #FEC078 to #FB9C52 | the hero panel, top left to bottom right | |
| onHero | #2A1207 | the hero amount | 13.30 / 10.96 / 8.40 across the stops |
| onHeroQuiet | #5E2C08 | everything else on the hero, and the rail fill | 8.59 / 7.08 / 5.42 |

Gabi (dark, the option). The page is the light page's own hue driven down to
near black, so the dark app is warm brown black and never blue black.

| Token | Value | Measured |
|---|---|---|
| bg | #14100D | text on it 16.61 |
| card | #27201A | 1.179 separation, matching the light feel |
| line | #383029 | |
| text | #F6EFE8 | 16.61 page, 14.09 card |
| text2 | #C6B8AC | 9.78 page, 8.30 card |
| text3 | #AC9E92 | 7.26 page, 6.16 card |
| accent | #FF9A52 | 9.01 page, 7.64 card |
| onAccent | #1E0E03 | 8.93 |
| good | #5FCB8E | 9.39 page, 7.97 card |
| bad | #FF8A6E | 8.21 page, 6.97 card |
| discOnPage | #27201A | |
| discOnCard | #14100D | |
| heroGradient | #EBB884 to #DE9A5B to #CE7D3C | one step deeper, so it is not a lamp at night |
| onHero | #1E0E03 | 10.47 / 7.93 / 5.92 |
| onHeroQuiet | #361701 | 9.16 / 6.94 / 5.17 |

Rules:
- **Text over a gradient is measured against the worst stop behind it, not
  the average.** onHeroQuiet is dark enough to survive the darkest stop at
  5.42, which is why the number looks over-cautious against the lightest.
- **A quiet tone is a measured second colour, never the ink at reduced
  opacity.** Dimming with alpha is exactly what breaks readability on a
  coloured field.
- Orange is the only accent. Accent means "press me" or "you owe". Never a
  background wash, never body text.
- An ordinary expense is text colour, bare. Colour on a row means DIRECTION.
  If every amount is coloured, colour means nothing.
- Positive green is the only other strong colour and it means money coming to
  you: income, payday, owed to you, a refund, a settled debt.
- Category colours do not exist. Categories are the user's own emoji, in
  chips, because they are user data.
- What flips between light and dark: the page, the card, the line, the text
  ramp, the accent, good and bad, the two discs, and the hero stops. What
  never flips: the type scale, the radii, the spacing, the rail, the beam,
  the layout, or where the peso sign sits.

### The headroom rule

The accent was #C2410C until it was measured at 4.57 on this page. That
clears the 4.5 bar by 0.07. **Nothing ships that thin**, because a value with
no headroom fails the moment anything near it moves. #B03C09 is the brightest
orange in the same family that reaches 5.30. When a measurement lands within
0.2 of a bar, treat it as failing and find the next value.

## Typography

**One family: Plus Jakarta Sans.** This replaces the two-family answer in D7
and the reason is worth keeping: the two-family rule existed to give the hero
character, and a measured hero size did the same job with one less thing to
get wrong. Every figure in the app is tabular, so a column of amounts never
jiggles.

| Role | Size / weight | Notes |
|---|---|---|
| hero amount | 47 / 700, tracking -1.7 | see the measurement below |
| hero peso sign and centavos | 23 and 20 / 500, quiet ink | never the full ink |
| hero kicker | 11.5 / 700, tracking 1.4, uppercase | "SAFE TO SPEND" |
| hero sentence | 14.5 / 400, quiet ink | states the conclusion |
| section head | 16 / 600, tracking -0.2 | "Debt, both ways" |
| section action | 13 / 500, accent | "See all" |
| row title | 15 / 500, one line, ellipsis | |
| row amount | 15.5 / 600, tracking -0.3 | text, or good when money comes in |
| beam amount | 21 / 600, tracking -0.5 | |
| caption | 12.5 to 13 / 400, text3 | dates, "Food, GCash" |
| tab label | 10.5 / 500 | |

**The hero size is measured, not guessed.** Plus Jakarta Sans draws a lining
figure at 0.750 of its font size, so 47 pt gives a 35.3 pt cap height, 8.6
percent of a 412 pt screen. Re-measured off the finished PNG, the drawn cap
is 35.5 pt, 8.62 percent. The money apps on the reference board sit between
7.6 and 8.8 percent. The first attempt at 54 pt came out at 9.83 percent and
read as a poster, not an app.

Other rules:
- Centavos always show on the hero (₱6,240.00). Row amounts round to the peso.
- No raw TextStyle in features/. Everything goes through the one type helper.

## Spacing and shape

Screen gutter 22. Between sections 34. Row vertical padding 13. Icon disc 46
on the page, 38 on a card.

| Token | Radius | Used for |
|---|---|---|
| hero | 26 | the gradient panel |
| card | 20 | any group of rows, the debt beam |
| pill | 999 | the Log pill, chips, bars |

**No borders and no shadows.** This is the discovery that made the theme
work: a warm page makes a white card separate on its own, by tone, so the
border-plus-shadow scaffolding every draft carried before it was simply
deleted. The one shadow that existed under the hero rendered as a visible
second card edge and was removed rather than tuned.

Rows inside a card are separated by a 1 dp hairline in `line`, inset 52 from
the left so it starts after the icon disc, and never after the last row.
Without it a fourteen-row list is one white slab, which three tidy demo rows
hid completely.

Icon discs are one size, one tint, one colour, so a long list of icons reads
as one texture instead of fourteen separate stickers.

## Motion

Five verbs, one curve (ease out cubic). Unchanged from the previous system,
because none of it was what the founder rejected.

| Verb | Where | Duration |
|---|---|---|
| settle | any press | 150 ms, scale to 0.97, light haptic |
| glide | sheets, tab switches, row insert and remove | 250 ms |
| roll | any amount that changes while visible | 400 ms, digits roll in tabular columns |
| fill | the rail and every bar, on first appearance | 400 ms, from the left |
| clear | a settled debt row | turns fully green-tinted, holds 1.2 s, slides out; medium haptic; the one celebration |

Reduce-motion turns every duration to zero. No ambient loops, no shimmer, no
confetti.

## Iconography

Salapify's own icons are Material outlined glyphs, drawn in text2 inside a
tinted disc. Category icons remain the user's emoji in chips only, because
they are user data and were never ours to replace. The rule in CLAUDE.md
governs: ours are themeable glyphs, the user's are emoji.

## Components

| Component | What it is |
|---|---|
| AppScaffold | page background, safe area, the tab bar, the fade strip above it |
| Hero | the gradient panel: kicker, amount, sentence, rail, two end labels |
| SweldoRail | the 5 dp track inside the hero, filled to today |
| DebtBeam | the white card with the two-part bar, its two amounts, and the next-due line |
| QuickActions | one row of exactly four disc-and-label actions, never a grid |
| SectionHead | the section title with an optional trailing action |
| Group | a card holding rows, hairlines between, none after the last |
| Row | icon disc, title, caption, amount; the only list row in the app |
| AmountText | every peso figure: sign, tabular, rounding, rolling |
| ThinBar | a 5 dp bar that fills, for budgets, credit limits and debt progress |
| Chip | selectable pill, used in the Log sheet and filters |
| Segmented | two to four options in one pill-shaped control |
| PrimaryButton, SecondaryButton, TextButton | primary is the accent pill |
| Input | text and amount fields; the amount field opens a numeric pad and formats live |
| Sheet | card colour sliding up, card radius on top, drag handle, overlay |
| Chart | bars or a line in CustomPainter, always with a sentence under it that contains a number |
| SettledRow | a row tinted green with a strikethrough label and a check |
| EmptyState | one sentence, one action, no illustration |
| Toast | bottom strip with Undo, 4 seconds |

The **amount pill** from the previous system is gone. Tinted pills behind
amounts read as decoration once a list is long, and the row already says
direction with colour and a sign.

The **chunky bottom edge** on primary buttons is gone too. It was borrowed
from Duolingo and it was the second borrowed shape on the screen; the first,
the round centre FAB, was replaced by the labelled "+ Log" pill.

Every component renders in light and dark in the shot harness, and that sheet
of pictures is the first thing rendered in Phase 2.

## Where it lives

`mockups/hapon/` holds the real Flutter renders and the four source files
that produce them, with a README explaining how to rebuild them. They are
renders, not drawings: 412 by 915 logical pixels, device pixel ratio 2, with
Plus Jakarta Sans and the Material icon font actually loaded. If it renders
there it renders on the phone.

The dense pair matters most and is the fixture rule in one line: **a design
that only works at three transactions is not a design.** The renders show
fourteen. Do not shrink that fixture; a tidy shot of an empty screen is
exactly what it replaced.

The Figma file "Salapify 3 Design" still holds the moodboard the direction
came from. Its token and screen pages describe the retired theme and are
stale. The repo is the source of truth; when the two disagree the markdown
wins.

## What is locked, and what stays open

Locked once Phase 1 approves the mockups: the accent, the one type family,
light as the reference with dark derived, exactly one way to render a peso
amount, the hero panel, the rail and the beam, no borders and no shadows, the
clear as the only celebration, and the tab bar shape with the Log pill at its
right end.

Open: the icon glyphs, chart styling, dark tuning, spacing polish, copy, and
whether the rail appears on Ledger or only on Home and Plan.

## The two-week test

Build Home and Log only, in these tokens, and use them daily for fourteen
days. Zero edits to the token file and Home still feels like yours on day
fourteen means the theme was right. Three or more edits, or the urge to add a
second accent, means it was wrong, and the fix is to go back to the
references, not to words.
