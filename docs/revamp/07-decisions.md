# 07. Founder decisions

Each needs an answer before the phase that depends on it. Each has a
recommendation so the founder can answer "yes to the recommendation" in one
word. Answered decisions carry the date.

## D1. Stack: Flutter again, in a new folder app/

Options: (a) new Flutter app in app/, reusing the engine and store as
library code; (b) rebuild in place inside flutter/; (c) new native Android
app generated with Google AI Studio (Kotlin and Compose).

Recommendation: (a). Reasons in 02-architecture.md. (c) throws away the
tested money engine and the working encrypted store, and loses iOS.

Needed before: Phase 2.

## D2. The cut list

Vision 01 cuts Courses, Mindset, Pan, the calculators, treats and wins,
paluwagan, splits, notes, the extra themes, PDF statements. Everything
stays in git history and can return in Phase 5.

Recommendation: cut all of it for v3. The founder can name any item they
use weekly today and it moves to "kept".

Needed before: Phase 1, because it decides which screens get designed.

## D3. Tabs

Options: (a) four tabs, Home · Ledger · Plan · Accounts, Log in the centre;
(b) five tabs with Utang as a tab; (c) Utang inside Plan.

Recommendation: (a), with Utang as the first section on Home and its own
screen (see D11). Four labels fit a phone without shrinking text. The names
avoid Tarsi's set (Home, Wallet, Plan, History); "Ledger" is Salapify's own
word.

Needed before: Phase 1.

## D4. Same applicationId and signing key

Recommendation: yes. The new APK then installs over the old one and finds
the founder's data in place. The alternative, a second app id, means two
Salapify icons and a manual export and import.

Needed before: Phase 2.

## D5. Delete flutter/ and mobile/ after cutover

Recommendation: yes, at the end of Phase 4, once the delivery-log row for
v3 exists and the founder has used v3 for a week. Git history keeps both.
Until then both folders are frozen: no feature work, only a fix the
founder needs on the phone they use daily.

Needed before: Phase 4.

## D6. Archive the old docs now

08-docs-inventory.md marks each doc keep, archive, or superseded. Archiving
is a git move to docs/archive, reversible. The constitution stays where it
is because a test reads it; the test goes away with flutter/ in Phase 4.

Recommendation: yes, do the move as the first PR after this one.

Needed before: end of Phase 0.

## D7. Typography: two families, each with a place. ANSWERED 2026-09-12 (revised the same day)

Bricolage Grotesque for the hero amount, the screen title and the payday
rail label only; DM Sans for everything else, including every row amount
(tabular figures). Both are on Google Fonts and load in Figma. No serif and
no handwriting font anywhere: the founder rejected both in the Papel and
Kwaderno round. The first answer (Fraunces plus Plus Jakarta Sans) was
recorded from the five-reviewer panel in the morning and withdrawn when the
founder rejected that theme; this answer comes from the moodboard round.

## D8. Accent: coral. ANSWERED 2026-09-12 (revised the same day)

#BE3A1B in light, #FF8A6A in dark, with a darker #8F2A12 edge under the two
primary buttons. Taken from image 2 on the moodboard (Bear, "coral") and
image 4 (Headspace, one strong warm accent on off-white), then darkened
until white text on it passed 4.5:1. Not the green every finance app uses,
not Tarsi-adjacent. The only accent; positive green is the only other strong
colour and it means money coming to you. The full palette and every
contrast ratio are in 03-design-system.md. The first answer (terracotta
#A8390F on paper) went with the rejected Papel theme.

### How the theme was chosen (the keep-or-kill list)

Twelve real light-mode screens on the Figma moodboard, decided by the
design-director agent after the founder delegated the round:

1. Things 3: calm. Taken: thin rules between rows instead of boxes.
2. Bear: coral. Taken: the coral accent on a clean white ground.
3. Craft: kill. Beige paper and serif body, the rejected Papel look.
4. Headspace: keep. Warm off-white ground, one strong warm accent, pill
   buttons, bold sans headline, friendly without being childish.
5. Duolingo: chunky. Taken: the thick bottom edge on the primary button,
   limited to two buttons so the app never reads as Duolingo.
6. Structured: rail. Taken: a timeline rail with dots; became the payday
   rail.
7. Gentler Streak: keep. A chart that states its conclusion in a sentence,
   and a soft green band.
8. Notion: kill. Dense monochrome, the boring the founder named.
9. Monarch: kill. Serif over cream plus a hero chart; parent of two
   rejected variants.
10. YNAB: keep. Amounts inside soft coloured pills.
11. Spendee: kill. Generic icon grid on lavender.
12. Ivy Wallet: kill. Dark cards, teal and black; the rejected first draft.

The moodboard is private inspiration. Nothing on it is copied into
Salapify; what carries over is a colour feeling, a rail, a pill, and a
sentence under a chart, all redrawn. The utang beam is Salapify's own.

## D9. Charts by hand, not a library

Recommendation: draw the four launch charts with CustomPainter under one
grammar (ink and accent) and drop fl_chart. Fewer dependencies, and every
chart looks like the same app.

Needed before: Phase 2.

## D10. One theme, light primary, dark optional. ANSWERED 2026-09-12

Founder direction: light is the primary and reference look; dark is an
option in Settings, derived from the same tokens. The one theme is Sinag
(03-design-system.md). No theme picker. The old four themes are retired and
may return in Phase 5 if missed. 01-vision principle 4 was rewritten to
match.

Consequence for the founder: they use dark today. Phase 1 renders every
screen in light first, then dark, and the founder should look at both,
because they will likely live in dark while the design is judged in light.

## D11. Where utang lives

Options: (a) first section on Home plus its own screen, reached from Home
and Accounts; (b) its own tab, replacing Plan or Accounts in the bar.

Recommendation: (a) for the first two weeks of daily use. The ledger row
for utang is the one element no other app has, and the panel's working
parent wanted it above bills, so it leads Home. If the founder opens the
Utang screen more than Plan in those two weeks, it takes Plan's tab.

Needed before: Phase 1 finishes the Home mockup (it is drawn as (a)).

## D12. The theme lock

Once the Phase 1 mockups are approved, these do not change without a
founder decision: the accent, the two type families and where each is
allowed, light as reference with dark derived, one way to render a peso
amount, the rail, the beam and the pill, the clear as the only celebration,
no cards on the main screens beyond the three tiles, the tab bar shape. The
two-week test in 03 is the check.

Needed before: end of Phase 1.
