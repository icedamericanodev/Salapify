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

## D7. Typography: two families, each with a place. ANSWERED 2026-09-12

Fraunces for the hero amount and the cycle title only; Plus Jakarta Sans
for everything else, including every row amount (tabular figures). No
handwriting font: the panel found a script face reads as a template, and
the stamp works in Jakarta. Both families are already licensed and
bundled. Recorded from the five-reviewer panel and the founder's
direction to pick one theme.

## D8. Accent: terracotta. ANSWERED 2026-09-12

#A8390F on paper, #EE7A45 on ink. Not the green every finance app uses,
not Tarsi-adjacent, and continuous with the orange Salapify wordmark. The
only accent; the full palette is in 03-design-system.md. The contrast test
is the judge of the exact values.

## D9. Charts by hand, not a library

Recommendation: draw the four launch charts with CustomPainter under one
grammar (ink and accent) and drop fl_chart. Fewer dependencies, and every
chart looks like the same app.

Needed before: Phase 2.

## D10. One theme, light primary, dark optional. ANSWERED 2026-09-12

Founder direction: Papel (light) is the primary and reference look; Tinta
(dark) is an option in Settings, derived from the same tokens. No theme
picker. The old four themes are retired and may return in Phase 5 if
missed. 01-vision principle 4 was rewritten to match.

Consequence for the founder: they use dark today. Phase 1 renders every
screen in Papel first, then Tinta, and the founder should look at both,
because they will likely live in Tinta while the design is judged in
Papel.

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
allowed, Papel as reference with Tinta derived, one way to render a peso
amount, ledger-row physics, the stamp as the only celebration, no cards on
the main screens, the tab bar shape. The two-week test in 03 is the check.

Needed before: end of Phase 1.
