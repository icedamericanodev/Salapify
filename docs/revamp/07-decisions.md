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
(b) five tabs with Debt as a tab; (c) Debt inside Plan.

Recommendation: (a), with Debt as the first section on Home and its own
screen (see D11). Four labels fit a phone without shrinking text. The names
avoid Tarsi's set (Home, Wallet, Plan, History); "Ledger" is Salapify's own
word.

The Log control is a labelled pill at the RIGHT END of the bar, not a round
button in the centre. The centre FAB is a named signature of the apps this
must not read as.

Wallet is not a synonym here, and 2026-09-13 proved the clause above earns
its place. The first Home render labelled the fourth tab "Wallets", which is
Tarsi's word, in a rebuild that exists because of the sentence "It looks like
we copy the Tarsi". Nobody noticed for a day. The render was corrected to
Accounts.

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

## D7. Typography: one family, Plus Jakarta Sans. ANSWERED 2026-09-13

One family everywhere, with tabular figures on every number so a column of
amounts never jiggles. No second display face.

This revises the two-family answer below, and the reason is worth keeping.
The two-family rule existed to give the hero amount character. A MEASURED
hero size did the same job with one less thing to get wrong: Plus Jakarta
Sans draws a lining figure at 0.750 of its font size, so 47 pt gives a cap
height that is 8.62 percent of a 412 pt screen, inside the 7.6 to 8.8 percent
band the reference apps sit in. Character came from the size, not the face.

No serif and no handwriting font anywhere: the founder rejected both in the
Papel and Kwaderno round, and that part has never changed.

Superseded answers, kept so nobody re-proposes one: Fraunces plus Plus
Jakarta Sans (2026-09-12 morning, from the five-reviewer panel, withdrawn
when the founder rejected that theme), then Bricolage Grotesque plus DM Sans
(2026-09-12, from the moodboard round, withdrawn with the Sinag theme).

## D8. Accent: orange. ANSWERED 2026-09-13

#B03C09 in light, #FF9A52 in dark. One accent, used for the Log pill, links,
and the "you owe" half of the debt beam, and nothing else. Positive green is
the only other strong colour and it means money coming to you.

Founder direction drove this: "you can add color to it. Like light orange or
graduent orange or something like that", then "the background is kinda
orangey too can you do something like that but very light". So the page is
warm as well as the accent.

The value carries a rule with it. The accent was #C2410C until it measured
4.57 to 1 on the warm page, which clears the 4.5 body bar by 0.07. **Nothing
ships that thin.** #B03C09 is the brightest orange in the same family that
reaches 5.30. When a measurement lands within 0.2 of a bar, treat it as
failing. The full palette and every measured ratio are in
03-design-system.md.

Superseded: terracotta #A8390F on paper (with the rejected Papel theme), then
coral #BE3A1B with a darker edge under primary buttons (with the rejected
Sinag theme). The chunky button edge went with it; it was borrowed from
Duolingo and was one of two borrowed shapes on the screen.

### The moodboard keep-or-kill list (history, and what survived)

This round produced the Sinag theme, which the founder then rejected. It is
kept because three of its keeps outlived it and are in Hapon today: the thin
rule between rows, the rail, and one strong warm accent on a light ground.
Two did not: the amount pill and the chunky button edge, both now explicitly
banned in D12.

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
sentence under a chart, all redrawn. The debt beam is Salapify's own.

## D9. Charts by hand, not a library

Recommendation: draw the four launch charts with CustomPainter under one
grammar (ink and accent) and drop fl_chart. Fewer dependencies, and every
chart looks like the same app.

Needed before: Phase 2.

## D10. One theme, light primary, dark optional. ANSWERED 2026-09-12 (theme named 2026-09-13)

Founder direction: light is the primary and reference look; dark is an
option in Settings, derived from the same tokens. The one theme is **Hapon**
in light and **Gabi** in dark (03-design-system.md). No theme picker. The old
four themes are retired and may return in Phase 5 if missed. 01-vision
principle 4 was rewritten to match.

Gabi is not a second design. Both render from identical layout code, so the
only thing that differs between the light and dark pictures is colour;
anything else that differs is a bug.

The named theme here was Sinag until 2026-09-13. The founder rejected it,
along with two further rounds, and then delegated the choice ("I'll let the
expert agent choose"). The agent chose Hapon on measurement over two warmer
rivals, and the full comparison table is in 03-design-system.md so the
experiment is not rerun.

Consequence for the founder: they use dark today. Phase 1 renders every
screen in light first, then dark, and the founder should look at both,
because they will likely live in dark while the design is judged in light.

## D11. Where debt lives

Options: (a) first section on Home plus its own screen, reached from Home
and Accounts; (b) its own tab, replacing Plan or Accounts in the bar.

Recommendation: (a) for the first two weeks of daily use. The ledger row
for debt is the one element no other app has, and the panel's working
parent wanted it above bills, so it leads Home. If the founder opens the
Debt screen more than Plan in those two weeks, it takes Plan's tab.

Needed before: Phase 1 finishes the Home mockup (it is drawn as (a)).

## D12. The theme lock. ACTIVE from 2026-09-13

The founder approved the Hapon and Gabi Home renders on 2026-09-13 ("i think
thats good to go"). The list below is now live, not pending: changing any of
it takes a founder decision, not a good argument.

Locked: the accent, the one type family, light as reference with dark
derived, one way to render a peso amount, the hero panel, the rail and the
beam, no borders and no shadows, the clear as the only celebration, and the
tab bar shape with the Log pill at its right end. The two-week test in 03 is
the check on whether the lock was right.

Two things this list used to name are deliberately gone: the amount pill,
which reads as decoration once a list is long, and the chunky bottom edge on
primary buttons, which was borrowed. Do not reintroduce either.

The lock covers the LOOK, not the screens. Log, Ledger, Plan, Accounts and
Debt still have to be drawn, and drawing them will raise real questions about
layout and hierarchy. Those are open. What is not open is answering one of
them by adding a second accent, a card border, or a new signature device.

## D13. The app says Debt, not Utang. ANSWERED 2026-09-13

Founder direction, verbatim: "amend the Utang to Debt to make english
consistent in the entire app".

So every user-facing "Utang" becomes "Debt": the Home section label, the
screen title, the tab if it ever gets one, the quick action, and every
sentence. The feature is unchanged. It is still both directions in one
place, still the thing no other app does well, and the beam that shows both
at once keeps its shape. Only the word changes.

Scope, so this is not ambiguous later:
- App UI copy: Debt, everywhere, no exceptions.
- Code: the feature folder is app/lib/features/debt/, not utang/.
- These docs: renamed throughout on 2026-09-13.
- Marketing and ads: NOT changed by this decision, and still governed by
  CLAUDE.md, which allows Filipino words as product identity flavour. If the
  founder wants the ads to match the app, that is a separate call.
- The frozen apps in flutter/ and mobile/ are not touched. They are frozen.

This supersedes the part of CLAUDE.md's writing style rule that let "utang"
stand as a title with an English gloss beside it. That rule was written on
2026-07-23 and is now narrower: identity nouns may appear in marketing, not
in the app.

One word is deliberately left alone: "sweldo". The app already says payday
everywhere the user reads, and sweldo survives only in internal names like
the Sweldo Timeline. If the founder wants that gone too, say so and it is a
five minute change.
