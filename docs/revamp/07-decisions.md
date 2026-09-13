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

## D4. applicationId: a SEPARATE one. ANSWERED 2026-09-13

Salapify 3 installs BESIDE the founder's daily app, not over it.
`dev.icedamericano.salapify3`, launcher label "Salapify 3", versionCode
restarting at 1.

The recommendation in this slot used to be the opposite, and the founder
overruled it, correctly. Its argument was convenience: the same id means the
new APK installs over the old one and finds the data already in place, with no
export and import. What that argument leaves out is that the founder is a
beginner with one phone, and the app it would replace is the one they use to
run their actual money. "Install over it" means the working app is gone the
moment they try the half-built one, with nothing to fall back to but a file.
Two icons is a small cost against that.

Three consequences, written here because each is easy to forget and expensive
to remember late:

1. **v3 always starts EMPTY.** Android sandboxes storage per application id, so
   v3 cannot read the old store even though both apps sit on the same device.
   There is no clever way around this and there should not be one.
2. **Restore is now on the critical path**, not a Phase 4 safety net. Backup
   then Restore is the ONLY bridge for the founder's real data, so it has to
   work before v3 is worth opening twice. B2's peso-level round-trip test was
   already the right thing to have built first; this makes it load-bearing.
3. **versionCode restarts at 1.** The +21 existed only to out-rank the shipped
   app's +20 under the old plan. The two version lines are now unrelated.

At cutover (Phase 4) the founder uninstalls the old app when they are ready,
which is now their decision on their own timing rather than a side effect of an
install. Whether v3 ever takes over the original applicationId on Play is a
separate question and is not answered here.

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

## D14. The skin is a ThemeExtension, not a global. ANSWERED 2026-09-13

The preview that produced the approved renders held the palette in a mutable
global, `Skin skin = hapon;`, which is fine for a preview: it draws one screen
at a time, has no user, and nothing ever changes brightness while it is
running. A real app has to follow the phone's own light or dark setting, and
`ThemeExtension` is what Flutter provides for exactly that.

So `Skin` hangs off `ThemeData`. `MaterialApp` gets `theme: salapifyTheme(hapon)`
and `darkTheme: salapifyTheme(gabi)` with `themeMode: ThemeMode.system`, and a
widget reads `context.skin.accent`.

Three things this buys that the global could not:

1. The phone's setting decides, with no code in the app to read it.
2. The two palettes CROSS-FADE, through the extension's own `lerp`, rather than
   snapping mid-frame.
3. A widget cannot accidentally name a skin. Naming `hapon` or `gabi` inside a
   screen produces a widget that ignores the setting, and the type discipline
   guard treats reaching past the tokens as a breach.

The cost is a `copyWith` and a `lerp` over twenty fields, written out once in
`app/lib/design/tokens.dart`. Nothing in the app patches a single token, so
`copyWith` is never called, but it is implemented properly rather than stubbed:
a copyWith that silently ignores its arguments is a trap for whoever needs it.

The alternative considered was a plain `InheritedWidget`, six lines against
forty. It was rejected because following the phone's setting would then need a
second mechanism bolted beside it (a `MaterialApp.builder` reading
`Theme.of(context).brightness` and picking a skin), which is two things doing
one job and gives no cross-fade.

## D15. No update stamp in app/ until Phase D. ANSWERED 2026-09-13

`02-architecture.md` reserves `s3.01` for the stamp row in `app/lib/main.dart`.
It is deliberately NOT there yet.

The stamp only means anything next to the machinery that keeps it honest: the
uniqueness guard that reddens a PR reusing a delivered value, the delivery-log
row the publisher writes, and the phone showing the same number back. `app/`
has no publisher, so none of that exists, and a stamp with no guard behind it
is exactly the failure this repository has hit three times (sessions 25, 32 and
33 in docs/lunch-and-learn.md), each time by a stamp being stale while
everything looked green.

It arrives in Phase D, with the publisher, the guard and the log row together.
`.github/workflows/app-check.yml` says the same thing at the top of the file so
nobody adds it early out of tidiness.

## D16. Over budget is a SHAPE, not a colour. Founder call still open on one part

The founder looked at the B3 component sheet, saw the "over budget" bar sitting
very close to the accent, and asked for an expert opinion rather than picking a
colour. The right answer turned out not to be a colour at all.

Measured facts first, so nobody reruns this:

| | accent | bad | hue gap | lightness ratio |
|---|---|---|---|---|
| Hapon | #B03C09, lum 0.125 | #9E2C1B, lum 0.092 | 10.5 deg | 1.37 to 1 |
| Gabi | #FF9A52, lum 0.450 | #FF8A6E, lum 0.405 | 13.4 deg | **1.10 to 1** |

### Why no hex value fixes this

The two colours are pinned into the same small box BY THE RULES, not by a
mistake. D8 forces both to clear 4.7 to 1 against the same page and the same
card, which pins their lightness. The warm-family rule pins their hue. Two
colours squeezed into one small box look like siblings; that is arithmetic.

Gabi is the worse of the two at 1.10 to 1, and Gabi is the skin the founder
actually uses.

Separating them by lightness instead is closed off by our own contrast floor:
carrying the signal on lightness alone needs roughly 3 to 1 between the fills,
which in Hapon drives `bad` to a near-black maroon around 16 to 1 on the page,
turning every outgoing peso figure in the app into heavy black ink.

Separating them by hue buys nothing where it matters. Both colours live at the
long-wavelength end, so under deuteranopia they converge to nearly the same
ochre and under protanopia the over-budget bar reads as slightly DIMMER, which
is noise rather than a warning. And the element is 5dp tall: chromatic
discrimination collapses on a sliver that thin, so everyone is partly
colour-blind here. Hue was never going to carry this.

### The real defect is geometry

`ThinBar` clamps `fraction` to 0..1, so a category at exactly 100 percent and
one at 300 percent draw the IDENTICAL picture. "Exactly on budget" and "triple
over" differ by ten degrees of hue and nothing else. That is the actual bug and
it would still be a bug if `bad` were bright blue. A widget that silently
discards the most important number on the screen is the root cause.

### And the render misled the founder

The component sheet stacks the two bars 14dp apart inside one panel with
generic labels. That is the ONLY surface in the product where these two colours
sit adjacent with the words stripped out; the real Plan screen carries a
right-hand figure and a caption on every row, so the state is spoken before
colour gets a vote. The glance test was run against a review artifact
engineered to fail it. The sheet is fixed to carry the real figures and
captions, because a review surface that hides the cues carrying the meaning
cannot tell anyone whether the meaning arrives.

### A spec and code contradiction this turned up

04-screens.md says "under 25 percent left turns the bar accent". `ThinBar`'s
DEFAULT fill is already the accent. So the near-limit warning is a silent
no-op today, and a Plan screen with six categories would glow accent on every
row: the app shouting while nothing is wrong. There is currently no way to say
"heads up" before "too late".

### Decided, and requiring no new colour

No new colours, no changed hex values, nothing added to the palette.

1. An over-budget bar rescales so the full width is the SPEND, fills in `bad`,
   and cuts a 2dp notch in the card colour where the limit sits. The eye reads
   "the fill went past the line" in greyscale, at any colour vision, and it is
   quantitative. The notch clamps to 15..88 percent of the width so a 1 percent
   overshoot still shows a tail and a 400 percent overshoot still shows a head.
2. Words lead and colour follows: the right-hand figure changes its WORDING,
   "P1,250.00 left" becoming "P320.00 over", not just its colour.
3. A fill-versus-track contrast group joins palette_contrast_test, asserting
   every bar fill clears WCAG's 3.0 non-text bar against `line`. Measured and
   already passing: Hapon 4.68 / 4.64 / 5.74 / 5.55, Gabi 4.96 / 6.16 / 5.61 /
   6.42 for calm, near-limit, over and set-aside.

### The one part that is the founder's, and is NOT decided

Giving the bar four states means the CALM state stops being the accent and
becomes `text3`, with the accent reserved for "under 25 percent left". The
sentence becomes: the fill answers "is anything needed from me?"

| State | Fill |
|---|---|
| In budget, calm | `text3` |
| Under 25 percent left | `accent` |
| Over budget | `bad`, full width, plus the limit notch |
| Fully set aside | `good` |

Goals stay the exception and keep the accent all the way up, because a goal
filling IS the win.

That changes the default appearance of a surface the founder has already
approved across 24 renders, so it is a product decision and not a routine one.
Nothing is built until they say. It is not urgent: Budget is step 5 of 10 in
Phase 3, so the question can be answered against a real screen with real
numbers rather than against a sample bar.
