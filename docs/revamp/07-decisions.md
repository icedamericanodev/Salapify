# 07. Founder decisions

Each needs an answer before the phase that depends on it. Each has a
recommendation so the founder can answer "yes to the recommendation" in one
word. Answered decisions get a date and move to the bottom.

## D1. Stack: Flutter again, in a new folder app/

Options: (a) new Flutter app in app/, reusing the engine and store as
library code; (b) rebuild in place inside flutter/; (c) new native Android
app generated with Google AI Studio (Kotlin and Compose).

Recommendation: (a). Reasons in 02-architecture.md. (c) throws away the
tested money engine and the working encrypted store, and loses iOS.

Needed before: Phase 2.

## D2. The cut list

Vision 01 cuts Courses, Mindset, Pan, the calculators, treats and wins,
paluwagan, splits, notes, four themes, PDF statements. Everything stays in
git history and can return in Phase 5.

Recommendation: cut all of it for v3. The founder can name any item they
use weekly today and it moves to "kept".

Needed before: Phase 1, because it decides which screens get designed.

## D3. Tabs and where Utang lives

Options: (a) four tabs, Home · Activity · Plan · Accounts, Log in the
centre, Utang as a section on Accounts and Home with its own screen; (b)
five tabs with Utang as a tab; (c) Utang inside Plan.

Recommendation: (a). Utang is money owed, so it belongs with what you own
and owe, and it keeps the bar to four labels, which is what fits on a
phone without shrinking text.

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

## D7. Single font family

Recommendation: keep Plus Jakarta Sans as the only family; drop Fraunces
and IBM Plex. If the founder wants a more rounded feel like Tarsi's, the
one alternative worth trying in Stitch is Nunito Sans; decide by looking at
the Home mockup in both.

Needed before: Phase 1.

## D8. Accent colour

Recommendation: the warm orange (#FF8A3D dark, #D9540E light) because it
is already the wordmark and it is not the green every other finance app
uses. Stitch can show Home in orange, in a teal, and in a violet in one
prompt if the founder wants to see alternatives before committing.

Needed before: Phase 1.

## D9. Charts by hand, not a library

Recommendation: draw the four launch charts with CustomPainter under one
grammar and drop fl_chart. Fewer dependencies, and every chart looks like
the same app. If a chart in Phase 5 needs more than the grammar gives, that
is the moment to reconsider.

Needed before: Phase 2.

## Answered

(none yet)
