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

AMENDED 2026-10-08 by D30 for ONE item: Pan the CHARACTER is kept. The Pan
chat and every streak or gamification item stay cut.

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

## D17. The app icon: Buto, a coffee bean whose crease is an S. Variant OPEN

Salapify has never had an icon. Both the shipped app and `app/` carry the stock
Flutter logo.

Four rounds. Rounds one and two were rejected wholesale, and the founder's note
on the second was the one both deserved: "make it related to Salapify or Pan
atleast." Round three answered it by reading
`flutter/lib/widgets/pan_mascot.dart`, which describes Pan as a chibi panda who
"cradles his cup of kapeng Barako, with a peso sign rising in the steam and a
coffee-cherry sprout on his head". That is why the palette is warm: the theme
system is named Barako, after Philippine coffee. The colour was never
arbitrary.

The founder picked **Buto**, a coffee bean whose centre crease is an S, so one
shape does two jobs, Barako and the initial of Salapify. Their note was that the
S was too hidden, and round four is that note: five refinements plus two
controls in `docs/revamp/mockups/hapon/icon/README.md`.

Settled by this decision:

1. The direction is Buto. Not the cup, not the cherry, not the panda.
2. **Icon only. Pan stays cut**, so D2 is untouched. The icon inherits Pan's
   object, not his face. That also sidesteps a real trap: this rebuild exists
   because of "it looks like we copy the Tarsi", and an animal mascot on the
   icon beside a competitor named after an animal invites the comparison.
3. The S is **painted**, never cleared. A cleared crease is a hole through the
   whole tile, so the S takes the wallpaper's colour: near black on a dark home
   screen, white on a light one. Round three shipped that defect in every render
   and nobody had seen it until the two home screens were compared side by side.

Still OPEN, and it is the founder's call: which of the five. The recommendation
is **Buto Jakarta**, whose crease is the real Plus Jakarta Sans ExtraBold letter
S, because it is the cleanest letterform, it keeps the bean reading as a bean
rather than a badge, and the icon's S is then literally the wordmark's S.

Nothing is built until they choose. Building means five mipmap densities, a real
adaptive icon with background, foreground and monochrome layers, the 512 store
icon, and a guard test that every density exists.

## D18. The app icon is the founder's own artwork, recoloured. ANSWERED 2026-09-14

Five rounds of proposals were rejected or superseded. The founder then sent a
reference image and said: "use the same icon just change the color. make it the
same do not change anything but the colot to fit the theme". Then, shown a dark
and a light recolour: "Light".

So the icon is that artwork, geometry untouched pixel for pixel, in Hapon's
palette: the hero ramp as the ground, the ribbons and the peso in ink, the echo
in cream. Every colour is an existing token; none was invented.

Not a hue rotation, and the reason generalises. The reference separates its
elements by HUE (blue ground, mint echo, white ribbon). Salapify's palette is
monochromatic warm and separates by VALUE (ink 0.01, accent 0.45, cream 0.74
relative luminance, all at roughly one hue). Spinning blue to orange sends the
mint to pink. Any future recolour into this palette has the same problem and
needs the same answer: map by role, not by hue.

Built, not just chosen: five mipmap densities, a real adaptive icon with
background, foreground and monochrome layers, and the 512 store asset.
`app/tool/build_icons.py` builds them and
`app/test/design/icon_assets_test.dart` guards them.

Two things flagged rather than hidden:

1. **The peso glyph.** It is the most documented visual cue of the Philippine
   quick cash lending category, and Salapify must never be filed under that. It
   is in the artwork because the direction was explicit. Worth one more look
   before the store listing goes live; it is one element and easy to drop.
2. **At 48px the tile is busy.** The S and the coin read; the bar chart becomes
   a small cluster. That is the reference's own composition rather than anything
   the recolour did, and the same is true of the original.

Superseded: D17, which recorded Buto (a coffee bean whose crease is an S) as the
direction. Buto's four rounds are summarised in
docs/revamp/mockups/hapon/icon/README.md and the vector harness still carries
the candidates, because two findings from them still bind: never clear a shape
with BlendMode.clear in single layer icon artwork, and a contrast ratio is about
two flat colours meeting while a Play tile is not two flat colours meeting.

## D19. Salapify 3 is built for the public, not for the founder alone. ANSWERED 2026-09-14

Founder direction, verbatim: "We can add feature do not think that this is for
my personal use only. Lets build it in the way it will usw by the public".

This overrides the sentence in CLAUDE.md that made the founder's own daily use
the sole near-term audience, and it is a real change of constraint rather than
a change of tone. Under the old framing a screen only had to work for one
person whose data and habits were known. Under this one, every screen has to
work for somebody who installed it ten seconds ago, has no accounts, no payday
set, and no reason to trust it yet.

What it settles immediately:

**Per category budget limits are FREE, and they are a core feature.** This was
flagged open when the Budget screen shipped, because the live RN app gates
`monthlyCap` behind `settings.pro`. Salapify's standing promise is that core
features are free forever, and a budget app whose budgets sit behind a wall
fails that promise at the first screen a stranger opens. Pro has to earn its
money somewhere else: history and trends, forecasting, multi currency, export.
The engine's own Pro rule in `whereItWent` is untouched, because that file is
byte identical to the shipped app's; the v3 screen simply does not consult it.

Two things this decision does NOT do, so nobody reads more into it later:

1. It does not paywall anything that is currently free, now or later. Moving a
   feature behind a wall after people have it is the one thing the monetization
   promises rule out.
2. It does not change the ORDER of the roadmap. The screens still come first
   (Upcoming, Debt, Goals, Insights), and public readiness lands after them as
   its own phase, when there is a whole app to make ready rather than half of
   one. Founder's call, same conversation.

What it adds to the plan, deferred but now written down rather than assumed
away: first run and onboarding for an empty ledger, the privacy policy and the
Play data safety answers, app lock, backup and restore, and the legal, policy
and store readiness reviews. None of those were needed for an audience of one.

## D20. The differentiator is RECONCILE, and what is defensible is its SHAPE. ANSWERED 2026-09-14, corrected the same day

Founder direction: "Lets build the best money/finace tracker mobile app with
CPA and Tech Risk touch". The founder is a CISA holder and a senior IT auditor,
so that is domain expertise to build ON rather than a slogan to put in the
marketing.

Four candidates were put to them. Reconcile won, and it is the right one.

**What it is.** Pick an account, type the balance your bank or GCash app
actually shows, and Salapify tells you the gap and offers to record it as an
adjustment with a reason. That is a bank reconciliation, the most ordinary
control in accounting and the one every consumer tracker skips.

**Why it is the strongest of the four.** Every tracker eventually fails the same
question: why does your app say a different number from my bank? The usual
answer is a shrug and a slow loss of trust as drift accumulates, because nothing
in the app ever asks. Reconcile makes the drift visible on purpose, names it,
and closes it with a recorded entry rather than a silent edit.

### CORRECTION, same day. This heading used to say "the CPA control no tracker has"

That was false, written by Claude and caught by a competitor review within the
hour. A reviewer or a rival would have found the counterexample in five minutes,
and a claim like that in marketing would have been indefensible:

- **YNAB has full reconciliation.** You enter the cleared balance the bank
  shows, it computes the difference and writes a transaction named
  "Reconciliation Balance Adjustment", then locks the reconciled rows. This is
  close prior art for exactly what D20 described.
- **Money Lover ships "Adjust Balance"** in an overflow menu: type the real
  amount, it adds or subtracts the difference. It exists, it works, and it
  records no reason and keeps no history.
- **Copilot lets you tap a manual account's balance and overwrite it.** Silent,
  no adjustment record. That is the behaviour this decision calls harmful, and
  it ships in the most premium app in the category.
- **Monarch has no reconciliation at all**, by their own documentation.

**So the FEATURE is not defensible.** It is about a week of work and any of the
five PH local trackers could add an "adjust balance" button next quarter.

**The SHAPE is defensible, and it is where the auditor's instinct is actually
load bearing rather than decorative:**

1. A **reason code**, not a free text note: forgot to log, cash spent offline,
   bank fee, interest posted, duplicate, unknown. Nobody does this, and it turns
   adjustments into data. An "unknown" bucket that grows is itself a finding.
2. A **reconciled as of date** on the account row and on the net worth figure. A
   net worth that says when it was last checked against reality is a claim no
   competitor makes, and it costs them nothing to be unable to make.
3. **Drift over time**: "your GCash has drifted ₱1,240 across four checks,
   mostly cash spent offline." A conclusion with a number, which is principle 6,
   and only possible because the reason was recorded.
4. A **cadence tied to payday**, one prompt per cycle on the rail Home already
   draws, never a nag.
5. The commitment that **no balance is ever silently overwritten anywhere in the
   app.** This is the part a competitor structurally cannot copy, because they
   already ship an editable balance field and cannot take it away from existing
   users. Salapify simply never adds one.

The pitch is therefore NOT "we do reconciliation", which invites "so does YNAB".
It is **"the only tracker that tells you how wrong it is, and keeps the
receipt"**. That is a claim only an auditor would think to make, it is true, it
is checkable, and it sits at the opposite end of the trust spectrum from a
predatory lending app.

### And the word "reconcile" never appears in the UI

Second correction, from the financial coach review. As written, D20 describes a
mechanism and never states a benefit. A normal person does not have a drift
problem, they have a forgot to log problem, and their honest reaction to a ₱340
variance is "whatever".

The user facing question is **"did I miss anything?"** The gap is not an error to
classify, it is a recovered memory: "GCash says ₱2,340, Salapify says ₱2,890,
₱550 went somewhere since Tuesday." Then do the useful thing and GUESS, from the
user's own history and from recurring bills whose date has passed. Getting one
right is a small magic trick; filing an unexplained adjustment is a chore.

It is a moment, not a screen. Nobody opens a reconcile tab. Trigger it where the
real balance is already in front of them, and once per sweldo cycle.

**And the sharpest version for this market is CASH, not the bank account.**
Nobody can link a wallet of hundred peso bills, cash is where drift is worst,
and "count your cash, tell me the number" needs no explaining to any Filipino
user.

### Sequencing, which this review changed

Reconcile writes `adjustment` rows into a ledger that currently has no way to
open, inspect or fix an entry. Shipping it first would give the founder an audit
trail nobody can read. The transaction detail and edit path comes FIRST.

**The data model is already there.** `adjustment` is an existing transaction
type in the golden locked engine, excluded from day totals for exactly the right
reason: it reconciles a balance to reality rather than recording money going
anywhere. Nothing new has to be invented in the money layer.

**It is also the Tech Risk half.** An adjustment is evidence. It says what the
app thought, what reality was, when the difference was found and why, and it
stays in the ledger. The alternative, letting somebody quietly retype a balance,
destroys the audit trail of the one number the app exists to be right about.

The other three stay on the table and are not rejected, only later: an audit
trail of edits and deletes, proper net worth and cash flow statements, and a
data transparency screen (which doubles as the evidence for the Play Data Safety
questionnaire before launch).

Order: Upcoming (roadmap step 6) first, because it is already the next step and
nearly built, then Reconcile.

---

## D21: a budget editor explains, it never refuses

**Founder question, 2026-09-14, from the emulator:** "there is a limit 20,000
for the whole month but when i input 50,000 to load it proceed. Shall we input
to the categories within the whole month limit only?"

They were right that something was wrong, and it was worse than they thought.

### The bug underneath the question

`budget_editor.dart` already had a warning for this. It could never be seen. The
save path set the message with `setState` and then saved and closed the sheet in
the same frame, so the control existed in the source and nowhere a human could
read it. The app did not merely allow a 50,000 cap inside a 20,000 month, it
allowed it in silence, which is worse than either allowing it loudly or refusing
it.

### The decision

**Nothing in the budget editor refuses a plan.** Feedback moves to as-you-type
and the save is unconditional.

The financial coach was asked to rule and did, and the reasoning matters more
than the verdict:

**A refusal is right when the app cannot read the input, and wrong when the app
disagrees with the plan.** The two existing `_read` refusals stay, because there
the app is reporting its own inability ("that amount cannot be read"), not
judging anyone. Refusing a plan traps somebody mid edit behind an order of entry
rule they cannot see: raise a cap first and the limit second, and a blocking
editor stops you between the two. The first stranger who hits that concludes the
app thinks it knows their money better than they do, ten seconds after install,
and there is no recovering from that.

### Two different facts, two different messages

**The SUM of caps may exceed the monthly limit, and that is not even a warning.**
The earlier code comment gave the wrong reason for this, saying people
deliberately leave headroom on categories they will not all max out. That is a
behavioural excuse, and if caps were slices of one pot it would be a defect
rather than a feature. The real reason is structural and it is in the engine:
`budgetSummary` counts EVERY peso, including spending with no category at all,
which no cap can ever cover. The caps were never a partition of the limit, so
the two figures were never meant to reconcile. A running total now sits above
the Save button in plain grey and says so.

**ONE cap larger than the whole month is a different fact and gets a note.** It
is not headroom, it is arithmetic that cannot happen. `needsALook` fires at
`remaining <= cap * 0.25`, so a 50,000 cap inside a 20,000 month first warns at
37,500 of spending, which is 17,500 past the point the entire month is gone. The
control cannot fire inside the range it monitors: a disabled control that
presents as an armed one, strictly worse than the honest "No limit set" because
it consumes assurance without providing any.

It also makes two screens contradict each other. At 19,000 spent, the hero says
1,000 left of 20,000 while the row below says 31,000 left of 50,000 in calm grey
with a green bar 38 percent full. Two numbers, one ledger, one moment, that can
never agree. `plan_screen.dart` already carries a long note about exactly that
defect class, from the pacing bug that had to be fixed once before, so letting
it back in through the cap field would regress a lesson the file has written
down.

### Things deliberately NOT done

- **No hard block, no "are you sure" confirmation.** A modal on top of a modal
  sheet turns a fact into a scold, and it is the shape that makes people stop
  setting caps at all.
- **No one tap "raise your monthly limit to match".** This looks like the
  friendliest option and is the worst: its effect is to delete the only whole
  month control in the app, and a new user taps whatever makes the orange text
  go away. Never offer a fix whose effect is to remove the control.
- **No auto clamp.** Silently rewriting a number somebody typed is the fastest
  way to lose a finance app's credibility and is indistinguishable from a bug.
- **No requirement that caps total the limit.** Envelope budgeting is a real
  method and this is not it. Forcing the sum to equal the limit would guarantee
  the screen lies about the first uncategorised jeepney fare.
- **Neither message uses `skin.bad`.** Red means you did something wrong, and
  neither case is wrong.

### The guard

`editors_test.dart` asserts that a cap above the monthly limit **still
persists**, so a later session cannot read the new note as permission to start
blocking. The test records the decision as a decision. It also proves both
halves of the alarm: that the note fires, and that it stays silent while the
monthly field is being typed into, because "20000" passes through 2, 20, 200 and
2000 and at 2 every cap on the screen is above the limit.

No engine change, no stored change. `budget_rows.dart` and `core/money/` are
untouched.

---

## OPEN, for the founder: an account can be created but never changed

Found by the QA pass on the c6 batch, deferred rather than fixed because half
of it is a money-meaning question and those are founder-gated.

**The gap.** `showAccountEditor` is called from two places and neither passes
`existing`, and the account detail screen has no edit and no delete. The whole
edit branch inside the sheet is unreachable code. Concretely: type `1500000`
when you meant `15000`, tap "Add account", and your net worth is permanently
wrong with no screen in the app that can correct it. Add an account twice by
accident and it is there forever.

This is the same "instruction nobody can follow" shape the account editor was
built to fix, one step later in the flow.

**Why it is not just wired up.** The dead branch writes `balance` DIRECTLY. An
edited balance would move with no ledger entry explaining it, which contradicts
the rule at the top of `entry_detail_screen.dart` and destroys the audit trail
of the one number the app exists to be right about. That is exactly the argument
D20 makes for Reconcile: a correction should be an `adjustment` row, which is an
existing transaction type in the golden locked engine, excluded from day totals
for precisely this reason.

**The question for the founder,** and it is a real fork rather than a detail:

1. Editing an account's NAME and KIND is safe and could ship immediately.
2. Editing its BALANCE should probably not be a text field at all. It should be
   the Reconcile flow from D20: "count your cash, tell me the number", and the
   difference is written as an `adjustment` the ledger can show.
3. Deleting an account raises its own question, because transactions point at
   it. Refuse while it has history, hide it, or delete and orphan them.

Nothing is built for any of this yet. Named here so it is a decision rather than
an oversight.

---

## D22, hidden accounts are three states across two numbers, 2026-09-15

Founder direction, verbatim: "Lets have a hidden account where users can opted
to use. Use experts to make the rules about it. For me i think 2 rules when the
account is hidden first it hidden account does not include in the total account,
or the hiddent account amount can still be included in the total amount. Adjust
whatever i the appropriate thing."

**The decision.** Those are not two settings for one switch. They are two
different NUMBERS, and each of the founder's two rules is correct about one of
them:

- **Net worth is what you OWN.** A fact about ownership. Hiding a row from a
  list does not change who owns the money, so hidden money stays counted.
- **Safe to spend is what you can TOUCH this fortnight.** A decision about
  availability. Money deliberately put out of sight leaves it.

The asymmetry is what settles it rather than taste: a safe-to-spend figure that
is too high makes people overspend, and one that is too low only makes them
slightly cautious.

**Three states, two flags, no schema change.** Both stored flags already exist
in the v12 shape and already mean this, which is why no field was added:

| Stored | Meaning | Net worth | Safe to spend | Everyday list |
|---|---|---|---|---|
| `isArchived: true` | Hide from my lists | counted | excluded | Hidden section |
| `includeInNetWorth: false` | Not mine | excluded | excluded | shown, marked |
| both | Closed | excluded | excluded | Hidden section |

`isArchived` is not a reinterpretation of the founder's real data. The shipped
RN app's own button says "Hide account" and writes exactly this flag, and its
net worth has always kept counting the row. This is finally doing what that
button implied.

**Why not `countsInNetWorth`.** That helper is in the golden locked engine
(`account_taxonomy.dart`) and returns false for EITHER flag. Its name says net
worth and its only real use is deciding which rows belong in the default LIST,
which is a different question. It is left alone, nothing calls it, and the two
questions genuinely have different answers.

**How the rule reaches a money figure.** By REMOVING ROWS and asking the golden
locked engine the same question, never by subtracting from its answer.
`core/state/visibility.dart` exposes `ownedOnly` and `spendableOnly`, which
return a shallow filtered view of the ledger for reading. `netWorthParts` and
`safeToSpend` then do every sum, sign, rounding and currency check exactly where
they already live. No screen and no state file does arithmetic on money.

`spendableOnly` filters `accounts` and deliberately NOT `debts`: a bill you hid
from a list is still due on the same day, and forgiving it would push safe to
spend up, which is the one failure mode this whole design was built around.

**Two invariants, enforced by tests.**

1. Hiding an account cannot change net worth. If it ever does, the app is
   telling somebody they got poorer by tidying their screen.
2. Nothing is both invisible and unreachable. A hidden account appears under a
   Hidden heading at the bottom of Accounts, because an account nobody can find
   again is an account nobody can un-hide.

**Hiding is not security, and the sheet says so.** People will reach for "hide"
to keep a balance off the screen when somebody else can see their phone. The
account is still in the Hidden list, its entries are still in the Ledger, and
the backup file contains all of it in plain text. Saying that plainly is the
difference between a view preference and a false sense of safety.

Screens: `docs/revamp/mockups/hapon/c10/README.md`.

---

## D23. Where Insights lives. ANSWERED 2026-09-15

Founder question, 2026-09-15: "do you think its worthwhile to have a separate
insights tab or it could be included like in a menu/tools tab or whatsoever is
appropriate".

Two expert passes ran (a competitor benchmark and a Flutter UX craftsman).
They converged on one answer and split on another.

### SETTLED, and it is measured rather than argued: NOT a fifth tab

The craftsman claimed a fifth tab breaks the bar. It was re-measured
independently with the real font (`test/design/navbar_width_probe.dart`),
because a layout claim made in the default test font is a claim about a font
nobody sees:

| width | 4 tabs, 1.0x | 5 tabs, 1.0x | 4 tabs, 1.3x | 5 tabs, 1.3x |
|---|---|---|---|---|
| 320dp | Accounts wraps | Accounts, Insights wrap | Ledger, Accounts wrap | 4 of 5 wrap |
| 360dp | clean | Accounts wraps | Accounts wraps | 3 of 5 wrap |
| 412dp | clean | clean | clean | Accounts wraps |

A fifth tab also takes each column to **36.1dp**, under the 44dp touch floor.

It is a defect, not a cost, so the question of whether Insights "deserves" a
tab does not arise. Four tabs and the Log pill stay.

### The shipping bug this turned up, fixed in the same change

The table above says it: **"Accounts" already wrapped at 320dp with FOUR tabs,
today, on main.** Rendered, it read "Account" over a lone "s", and the wrap
pushed that tab's icon out of line with the other three.

Invisible to every existing check for one reason: the shot harness and the
founder's emulator are both 412dp, where nothing wraps. **A screen reviewed
only at the width it was designed for is not reviewed.** Fixed with a
`FittedBox(scaleDown)` and guarded at three widths and two text scales by
`test/design/navbar_test.dart`, break-proved at
`Expected: <17.0> / Actual: <30.0>`.

### The current entry point is not discoverable, and that is agreed

Insights is reached today by one tappable sentence at the very bottom of Home,
after the hero, the excluded-money line, four quick actions, the debt beam,
Coming up and five Latest rows. Measured on the lived-in fixture at 320x640 it
becomes visible only after scrolling 752 of 752 pixels: it is the literal last
line on the page. That is a hidden feature, not a weak affordance.

### ANSWERED: Insights is the Ledger tab's second segment

Founder direction, 2026-09-15: "go with the ledger segment". Built the same
day, and `04-screens.md` amended. The two options are kept below because the
reasoning is what makes the choice checkable later rather than just recorded.

**What shipped.** `[ Entries ] [ Insights ]` on the Ledger tab, with the
header and the segment control built BEFORE anything branches on the data, so
an empty ledger still reaches the charts. That ordering is the whole shape of
the build rather than a detail: the old screen returned its empty state early,
and a segment added after that return would have meant a person who has logged
nothing has no route to Insights at all. It is exactly the defect the Accounts
screen shipped, where the empty branch swallowed the Settings action and the
backup and restore behind it. Break-proved: restoring the early return printed
`Found 0 widgets with text "Insights"`.

The edit hint moved out of the screen subtitle into the Entries segment, since
"tap any entry to edit or delete it" is false of a chart, and the subtitle now
has to cover both sides of the control it sits above. Plan learned the same
lesson when its subtitle described Upcoming alone.

`/insights` stays a real pushed route with its own back arrow, so Home's
closing sentence and any future deep link still work. Two doors, one room.

**One test was found wrong by this change rather than broken by it.** A journey
asserted `findsNWidgets(2)` for a label that appears on two different days.
That passed only while the whole Ledger happened to fit the 600pt test
viewport; `Screen` is a lazy ListView, so once the list grew past one screen NO
scroll position can have both rows built at once. It now counts from
`groupByDay`, which is what the screen itself reads, and still asserts by
tapping that a person can SEE what they just logged.

**Option A, the Revolut pattern.** A chart icon in Home's header, top right,
beside the bell. Zero nav cost, permanently visible from cold launch. The
competitor pass found Revolut does exactly this with a full analytics
dashboard behind it, and that Salapify's nearest competitor by positioning,
BunnyWise, had five tab slots and spent the fifth on Investments rather than
analytics.

**Option B, Insights as Ledger's second segment**, `[Entries] [Insights]`.
The craftsman's argument is an IA one and it is a good one: Home is now, Plan
is the future, Accounts is the stock, and **Ledger is the past. Insights IS
the past, shaped.** The `Segmented` widget already ships and measures clean at
320dp at 2.0x. The tab bar itself becomes the entry point, so discovery costs
no new chrome at all.

**The recommendation is B**, because a labelled segment at the top of a tab
somebody already taps beats an unlabelled icon in a header, and because the
IA reason is principled rather than convenient. Option A's icon has to teach
the user what it means; Option B's segment says "Insights".

**What B costs, named:** it contradicts `04-screens.md:37` ("Everything else,
Insights, Settings, details, editors, is pushed over the shell"), which needs
amending rather than ignoring. `InsightsScreen`'s own chrome is extracted as
an `InsightsBody`, the `/insights` route becomes a redirect so deep links
still resolve, and `ledger_screen.dart`'s empty state returns BEFORE any
header today, so the segment must move above that early return or a fresh
install has no reachable Insights at all. That is the same defect class as the
Accounts empty branch that swallowed Settings and the backup with it.

### OPEN: where the tool-shaped surfaces go

Roughly ten golden-locked engines are tool-shaped and reachable by nothing:
`afford`, `bnpl`, `payoff_compare`, `surplus`, `loan`, `thirteenth`,
`windfall`, `paluwagan`, `steadypay`, `taxdeadlines`. Both passes agree a
"More" tab is the graveyard slot and reject it.

Not settled, and a third option neither pass raised:

**Home has four quick actions and TWO OF THEM ARE DEAD.** `Bills` and `Move`
are wired to null (`home_screen.dart`), announced as disabled, sitting in the
first viewport with no scroll. The brief calls "Can I afford this?" the
signature feature (section 10.4). There is a free, prominent slot for it
already on the screen, and putting the signature feature behind a title-row
action on Plan buries the thing the product is supposed to be known for.

So: a pushed Tools index for the long tail, and the ONE signature tool
promoted to a Home quick action. That is a proposal, not a decision.

### Chart packages, since the founder asked

`fl_chart` was checked against its current docs rather than from memory. D9's
recommendation holds and the three shipped charts are hand-drawn: the app has
six dependencies, the charts are simple (horizontal bars, paired bars, one
line), and fl_chart's own theming surface is large enough that matching Hapon
and Gabi through it is more work than the ~150 lines of `CustomPainter` and
kit widgets it would replace. Revisit only if a chart needs real interaction
(touch tooltips, pan and zoom), which none of the three does.

## D24. app/ restarts from the AI Studio prototype. ANSWERED 2026-09-18

Founder direction: "we will build free the Salapify final version. Forget
everything we made. I have already created a prototype in Google AI studio and
we will migrate it to Flutter."

Three things this settles, each asked and answered directly:

1. **`src/` is the source of truth for every calculation**, not the shipped
   app and not the old `app/`. Where a ported figure and the prototype
   disagree, the port is wrong.
2. **`app/` starts from zero.** The previous contents were deleted rather than
   built on. They are not lost: they remain on `main` and in history. The
   founder was offered keeping the money engine and storage and chose the
   clean restart.
3. **The tabs migrate in the prototype's own order**, one tab finished at a
   time including its modals: Home, Activity, Reports, Plan, Accounts.

Work happens on `claude/flutter-final`, which stays open until the migration
is complete. The `claude/` prefix is load-bearing rather than cosmetic:
`app-check.yml` only triggers on `claude/**`, so a differently named branch
gets no CI at all.

### What this retires

`check-engine-identical.sh` no longer guards `app/`. Its premise was that
`app/`'s money engine is a byte-for-byte port of `flutter/`, which is now
false by design. The step was REMOVED from `app-check.yml` rather than left to
skip silently, because the script self-exits 0 when `app/lib/core/money` is
absent and a step that compares nothing reads exactly like a passing check.

What replaces it is stronger, because it compares against the thing that is
now authoritative: vectors generated by running the prototype's own TypeScript
under bun, locked in `app/test/engine/`. `safeToSpendEngine.ts` is done this
way; every engine ported after it gets the same treatment.

`.githooks/pre-push` still calls the script. It self-skips and is local only,
so it is harmless, but it now guards nothing.

## D25. The red Flutter check is accepted, not fixed. ANSWERED 2026-09-18

Commit `319ac21` ("refactor: remove categories feature and related logic"), one
of the Google AI Studio sync commits, deleted 393 files under `flutter/`,
including `flutter/pubspec.lock` and most of the test suite. `flutter/test/`
went from roughly 400 files to 25, and the survivors import helpers that went
with the deletion, so `flutter analyze` reports 14 errors and `flutter-check.yml`
is red on every branch.

It landed unnoticed because `flutter-check.yml` triggers on `claude/**` pushes
and PRs to `main`, never on a push to `main` itself, and AI Studio syncs
straight to `main`.

The founder was offered four options: restore the files, narrow the workflow,
delete `flutter/` and `mobile/` outright, or leave it. **They chose to leave
it.** `flutter/` is legacy being replaced by the rebuild, so a red check on it
is expected noise until it is retired, and the cost of restoring 393 files to
the app currently on their phone is not worth paying for a folder on its way
out.

So, for anyone reading a red "Analyze and test" on a migration PR: check WHICH
workflow. `app-check.yml` covers `app/` and must be green. `flutter-check.yml`
covers frozen `flutter/` and is knowingly red. The two jobs share a name,
which is the whole reason this note exists.

The wider lesson is the one worth keeping: **AI Studio's sync writes outside
`src/`.** It edited a folder `CLAUDE.md` calls frozen. Do not assume a sync
commit only touches the prototype.

## D26. The sample payday cycle gets the rule it already claims. ANSWERED 2026-10-04

Founder answer: **A**, give the sample ledger `paydayDays: [15, 30]`.

The frozen cycle was never the neutral option. `SeedData.payday` stored
`cycleType: '15_30'` and no `paydayDays`, and `paydayDays` is only ever
written when somebody sets their payday inside the app
(`financial_state.dart:515`), so the sample data never had one. With no rule
the cycle cannot recompute, so it claimed four days to a payday on 15
September while anchored to 18 September, three days PAST it, and said that on
every date forever.

That reached people. Since 2026-10-03 the welcome offers "Look around with
example data" to everybody on first launch, so a wrong payday date was a first
impression for a public app on most days of the year.

It also made the new cash projection place exactly ONE payday in a forty-five
day window instead of three, so the demo showed Salapify at its most
pessimistic. That is the correct answer to a ledger that never said when
payday is, and it is the state every new user is in before they answer.

ACCEPTED COST, stated before the decision rather than discovered after: Safe
to Spend is derived from the payday cycle, so the demo's headline money figure
moves and the test files holding pinned figures move with it. No real person's
stored money changes. Only example data does.

Option B, asking for the payday rule during first run, was not rejected. It is
deferred to its own piece of work, because it puts a question in front of
somebody ten seconds into the app and that is a first-run design decision
rather than a data fix.

## D27. Income that two registers describe is counted ONCE. ANSWERED 2026-10-04

Founder answer: **A**, count it once and say so on the card.

Measured before the decision: one salary of 32,500 held both in the payday
rule and as an income `UpcomingItem` places 65,000 on a single day, and a
closing balance of 97,500 for somebody who earns 32,500 on the 15th.

THE ASYMMETRY IS THE WHOLE DECISION, and it is why this rule differs from the
one for money going out. Counting a BILL twice is safe: the person is told
they are tighter than they are, and nobody bounces a payment because Salapify
was too careful. Counting a SALARY twice tells somebody they have cash that is
not coming, which is the exact failure a cash runway exists to prevent. So
outflows are counted twice and flagged, and income is counted once and
flagged. Two rules, one stated reason.

A warning alone was rejected for income. Disclosure is enough when the error
makes somebody cautious; it is not enough when the error hands them money that
does not exist, because the figure on the screen is still too big and the
person who skips one line of small print is exactly who this protects.

THE RISK, and it is real: somebody with a genuine second income of the same
amount in the same month has it quietly dropped. The line on the card is what
keeps that from being silent, so that line is not optional polish, it is the
other half of this decision.

NOTE THE INTERACTION WITH D26. The sample ledger escapes this today only by
accident: its payday item sits in the past and its cycle is the frozen one.
Answering D26 with A is what starts this happening in the demo, which is also
what teaches people to record a sweldo as an Upcoming item in the first place.
The two decisions were taken together for that reason.

## D28. The sample ledger KEEPS its Home Credit duplicate. ANSWERED 2026-10-04

Founder answer: keep it, so the notice shows.

The question arose because two specialists pointed opposite ways. The
controller pass recommended removing the sample ledger's three duplicate pairs,
on the ground that a demo contradicting itself in three places teaches the
double count to every new user. The UX pass then pointed out that the Home
Credit pair is the only proof case the feature has: remove it and nobody who
taps "Look around with example data" ever sees the notice work.

The founder kept it. The reasoning that makes this right rather than merely
convenient: the duplicate is no longer SILENT. Once the card names it, the
sample ledger stops teaching "Salapify double counts" and starts teaching
"Salapify notices when you write one payment down twice", which is the more
useful lesson and the one a new user cannot otherwise discover.

WHAT MAKES THE PAIR A GOOD FIXTURE, and it is worth keeping on purpose:

  Debt `debt_homecredit`, person "Home Credit (Phone)", monthlyMinimum 2,450
  Upcoming `up_homecredit`, name "Home Credit Installment", 2,450

The LABELS DIFFER. An exact name match would miss the founder's own duplicate,
so the fixture forces the detector to be built on a loose name overlap rather
than on string equality. A fixture that passed trivially would have hidden
that.

STILL OPEN, and not covered by this answer: the Meralco pair (a Bill, an
Upcoming item three days apart, AND a confirmed Transaction already inside the
opening balance) and the BPI gadget loan pair (a liability Account and a Debt).
Those are a different shape from Home Credit and were not what the founder
ruled on.

THE RISK, stated rather than left implied: a demo that contains a duplicate on
purpose is one keystroke from teaching that recording something twice is
normal. The notice is what keeps that from happening, so the notice is not
optional polish on this decision, it is the half that makes it safe. If the
notice is ever removed or hidden, this decision has to be revisited in the
same change.

### BUILT, 2026-10-05

`app/lib/core/money/duplicate_obligations.dart`. A pure function the daily
projection calls, returning every pair that looks like one obligation written
into two registers. The Home Credit pair this decision preserved is its proof
case and is asserted by name in
`app/test/core/money/duplicate_obligations_test.dart`.

Four clauses, all required, and the fourth is the one that earns its keep:
different registers; the same amount to the centavo; within seven days AS
WRITTEN, never as placed, because the seed's Meralco pair is three days apart
written and eight apart placed; and a shared identifying word of three
characters or more, minus a stop list of words that name a KIND of thing
("bill", "loan", "premium", "electric").

THE FOURTH CLAUSE IS NOT A REFINEMENT. Matching on amount and date alone finds
three pairs on this ledger and one of them is wrong: a Pru Life VUL premium of
2,500 against a BPI personal loan amortisation of 2,500, both due the same day.
That is the round-figure collision a Philippine ledger produces constantly,
because lenders and insurers quote whole pesos, and it is one in three here.
The test asserts the collision is genuinely live before asserting the silence,
so the silence cannot pass for the wrong reason.

NOTHING IS DROPPED. Both copies stay in the figure, the card names them, and
the person decides which row is real. That is the opposite of what the engine
does to duplicated income under D27, and the asymmetry is the whole point: an
over-counted bill makes somebody cautious, an over-counted salary hands them
cash that is not coming.

WHAT THIS DOES NOT COVER, stated rather than left implied:

1. The BPI gadget loan pair, a liability Account against a Debt. Liability
   accounts are deliberately not a register here, because the projection does
   not read them at all: it takes accounts only for the opening balance and
   places nothing from them. Saying a payment is "counted twice" when one of
   the two is not counted once would be false. Making the projection see
   liability accounts is a money-meaning change and a founder decision.
2. The third leg of the Meralco case. Beyond the Bill and the Upcoming item,
   there is a confirmed Transaction already inside the opening balance. The
   detector finds the two future rows and says nothing about the past one, so
   the card reports 2,840 counted twice where the fuller truth may be three
   times. Reconciling a projected obligation against an already-settled
   transaction is a different question from this one and is still open.

### AMENDED, 2026-10-05: the label, not the line

Founder direction after testing on their own ledger: the fine print "feels
like too much on mine". A user panel then recommended cutting this line
outright, on the ground that all three archetypes misread it and its content
already sits behind the "i" dot word for word.

THE FOUNDER KEPT THE LINE AND FIXED THE LABEL. That is the right call and the
reason is written above, in this decision, four paragraphs up: the line is
"not optional polish, it is the other half of this decision". Deleting it
would make the rare case silent, and the rare case is somebody genuinely paid
the same amount twice in one month who then has one of the two dropped with
nothing on screen to tell them.

WHAT THE PANEL ACTUALLY FOUND, which is why the label was the real problem.
Three archetypes read "Counted once:" three different ways and NOT ONE of them
read it as reassurance:

    "Why is a non-problem on my home screen?"
    "The app is taking credit for doing its job."
    "Counted once sounds like it did not finish counting. So what happened to
     the other one?"

The third is the one that bites. There is no other one, and the label never
said so. It now reads "Counted once, not twice:", which answers that question
inside the label, keeps the pairing with the "Counted twice" line below it,
and matches the explainer behind the dot word for word, where the sentence
already read "is counted once, not twice".

Measured at 320dp with the system font at 1.5x, the longer label takes a line
the body was going to use anyway: the notice block is nine lines before and
nine lines after. The wording cost nothing.

`runway_row_test.dart` pins the label with `startsWith`, so the bare "Counted
once" cannot come back quietly.

WHAT IS STILL OPEN, and the founder has not ruled on it: whether three
notices on one card is too many in total. This amendment changes one label.
It does not answer the question that prompted it.

## D29. Salapify 3 ships BESIDE Salapify 2, not over it. ANSWERED 2026-10-05

Founder answer: B, "do as you recommended".

The question had to be asked because the roadmap's Phase 2 promised something
that never happened. It said the new Flutter project would carry the SAME
applicationId as the old app and a versionCode one higher, so it would install
over the top. Measured from the files on 2026-10-05, neither half is true:

| | applicationId | version |
|---|---|---|
| Salapify 1, `archive/salapify-1-react-native/` | `com.icedamericanodev.salapify` | React Native |
| Salapify 2, `archive/salapify-2-flutter/` | `dev.icedamericano.salapify` | 0.9.5+20 |
| Salapify 3, `app/` | `dev.icedamericano.salapify3` | 1.0.0+1 |

Android isolates stored data BY applicationId. There is no permission that
grants an app access to another applicationId's sandbox and no way to ask for
one. So the roadmap's Phase 4 exit, "data found in place", was never reachable
from where the code actually stood.

THE TWO WAYS OUT, and why the founder took the second.

Option A, take over the old app: change `app/` to `dev.icedamericano.salapify`
and set the version to `1.0.0+21`. One install, which replaces Salapify 2 in
place, and Salapify 3 then finds Salapify 2's files inside its own sandbox.

Option B, ship beside it: keep `dev.icedamericano.salapify3`. Both apps sit on
the phone with different icons. Data moves by EXPORT from Salapify 2 and
IMPORT into Salapify 3.

THE REASON FOR B IS NARROW AND IT IS THE WHOLE REASON. Option A's safety rests
on one assumption: that Salapify 3 can READ what Salapify 2 left behind, in
place, byte for byte. NOTHING HAS EVER TESTED THAT. They are different apps
with different schema histories, and the day the old app is replaced is the
wrong day to discover the answer. Option A puts an irreversible step first and
finds out afterwards. Option B reaches the same destination through a file the
founder can see, keep, and import again if it goes wrong.

WHAT B COSTS, stated so nobody is surprised later: two Salapify icons on the
phone at once until the founder uninstalls the old one; a manual export and
import rather than an automatic carry-over; and the home screen widget has to
be re-pointed deliberately instead of inheriting.

WHAT MAKES B CHEAP TO ADOPT, which is worth recording because it inverts the
usual direction of risk: B IS ALREADY THE STATE OF THE CODE.
`app/android/app/build.gradle.kts` line 25 already reads
`applicationId = "dev.icedamericano.salapify3"`. Choosing B changes nothing and
breaks nothing. Choosing A would have been the edit, and the edit would have
been the irreversible one.

A IS STILL AVAILABLE LATER, and the asymmetry is the point. Going from B to A
is one reinstall. Going from A back to B, after a migration that ate the
ledger, is a restore from a backup that may not exist.

OPEN, NOT DECIDED HERE. The `namespace` in the same file, line 8, is still
`dev.icedamericano.salapify`, the OLD app's id, while the applicationId beside
it is `salapify3`. That is legal, because namespace only names the generated
`BuildConfig` and `R` classes and has nothing to do with install identity, so
it changes nothing about this decision. It is recorded because a reader
comparing the two lines would reasonably think the app had two identities.

WHAT THIS UNBLOCKS: the publisher and the cutover, both designed in
`docs/reviews/publisher-and-cutover-design.md`, which said in as many words
that nothing below part 1 was to be built until this was answered.

### AMENDED the same day, 2026-10-05: there was never a fork here

Founder, on being shown the two options: "why we do need to post Salapify 2,
we are building the sALAPIFY FROM SCRATCH RIGHT using the google ai studio
prototype why you mix it up to Salapify 2???"

They are right, and the decision above is sound in its conclusion and wrong in
its framing. Both halves matter, so both are recorded.

SOUND: `app/` keeps `dev.icedamericano.salapify3`. Nothing changes in the code.

WRONG: it was presented as a CHOICE between taking over Salapify 2 and
shipping beside it, with a cutover to follow. There was no choice. D24,
2026-09-18, made `app/` a rebuild from the AI Studio prototype, and Salapify 2
was archived the same day. A rebuilt app does not take over its predecessor's
install and does not inherit its data. Salapify 3 keeps its own applicationId
because that is what a new app has, not because an option won.

WHERE THE ERROR CAME FROM, written down because it was inherited rather than
invented. `docs/revamp/05-roadmap.md` Phase 4 was titled "Cutover" and said
"Base APK installed by the founder over the old app; data found in place". That
document was adopted 2026-09-11, a WEEK before D24, and was never rewritten
when D24 landed. A session read it as current and designed a migration on top
of it. The roadmap's Phase 4 is now rewritten, which is the actual fix: the
stale sentence was the defect, not the reading of it.

WHAT THE EPISODE PRODUCED THAT IS WORTH KEEPING. The review commissioned to
check the migration found two things that have nothing to do with Salapify 2
and would have bitten anyway:

1. `app/android/app/build.gradle.kts` signs RELEASE builds with the DEBUG key.
   A debug keystore is generated per machine, so two base APKs built on two CI
   runs carry different signatures and Android refuses the second install in
   place. The only route out is uninstall, which deletes everything. It is
   invisible on the first install and bites on the first native change. This
   must be fixed before any installable build reaches a phone, and it is in the
   rewritten Phase 4 as its own numbered step.
2. `checkImportFile` told anyone feeding it an older Salapify export that their
   file "is not a Salapify backup". Nothing was written either way, so no tap
   could lose data, but that sentence invites somebody to delete a file. Fixed:
   it now names the app the file came from and says to keep it. Still correct
   under the new framing, because Salapify 1 had testers and Salapify 3 is
   public, so an old export can still arrive at that screen.

WHAT IS WITHDRAWN: part 3 of `docs/reviews/publisher-and-cutover-design.md`, the
seven step cutover, in full. Nothing in it is to be executed. It is kept
unedited as the record.

## D30. Pan returns as a CHARACTER, static first, then animated. ANSWERED 2026-10-08

Founder direction, 2026-10-08, verbatim: "I am bringing Pan back into
Salapify 3 as a CHARACTER, static first and then animated. This amends D2 for
that one item. The Pan chat and all streaks or gamification stay cut. The new
Pan is not an animal, so D17's Tarsi concern is answered."

The briefs are `docs/revamp/pan-handoff.md` (phase 1) and
`docs/revamp/pan-motion.md` (phase 2). The art is the 19 images in
`app/assets/pan/`, and the target look is `docs/revamp/mockups/pan/`.

WHAT IT CHANGES

1. **D2 is amended for ONE item.** Pan the character moves from "cut" to
   "kept". Everything else on the D2 cut list stays cut.
2. **Phase 1, static:** Pan replaces the icon on the empty states that greet a
   person, one mood per screen, at 96 x 96 at most until hi-res art arrives.
   Every screen draws him through one widget, `PanArt`, so new art is a folder
   swap with the same file names and no code change.
3. **Phase 2, motion is in scope.** Pan animates INSIDE `PanArt` only: an
   entrance, a per-mood idle with its effects, a tap squash with a light
   buzz, and a drawn shadow replacing the one baked into the PNGs. Flutter's
   own animation tools, no new packages. Idle runs `panIdleCycles = 3` cycles
   and then rests; changing that number is a one-line founder decision.
   Reduce motion shows Pan still.

WHAT IT DOES NOT CHANGE

1. **No chat, no AI, no gamification.** No streaks, week chains, wins or
   milestones. Pan reacts to what is on the screen; he does not keep score.
2. **D17 still holds.** The app icon stays Buto. The old Pan was a panda and
   the new one is not an animal, which answers the Tarsi comparison D17 was
   worried about.
3. **Pan never judges spending.** The annoyed, tear and crying moods are not
   used. Tear may return only for the wipe-all-data confirmation, and only by
   a later founder decision.
4. **Pan is decorative to a screen reader.** The empty state's title already
   says what matters.
5. No money, stored data, navigation or copy changes in either phase.

ONE FACT RECORDED SO NOBODY IS SURPRISED BY IT. The briefs and mockups were
drawn from main's older `app/` (the c1 design, with `kit.dart`, a "Ledger"
tab and "Insights"). The live `app/` restarted from the AI Studio prototype
under D24 and has neither file nor names. The moods were therefore mapped by
MEANING onto the live app's own empty states: Ledger is Activity and Insights
is Reports. That same prototype rebuild brought a rule-based "Ask Pan" card to
Home, which reads the ledger with no AI and no network. D30 neither adds nor
removes it; whether it stays is a separate question for the founder.

## D31. The four-lens review: what gets built next. ANSWERED 2026-10-09

THE QUESTION. Founder direction, 2026-10-09: "spin the product manager,
competitor lens, user lens, behaviour science lens, review critically the
current build. What features we can add and build free with no limitation.
Lets think about the compliance/privacy later on when we are done building
until im satisfied to what this app can offer". Four specialists reviewed
`app/`; every claim used below was checked against the code first.

THE ANSWERS, verbatim choices from the founder's question card:

1. **Stored data and money meaning, all four approved:**
   - Repeating bills: a paid bill rolls to next month instead of being done
     forever.
   - Lending moves real cash: an "owed to me" debt asks which account the
     money came from, so collecting it back does not leave that account
     higher than the real cash.
   - Edit an entry, rewriting balances correctly, instead of delete and
     retype.
   - Edit or delete goals and income streams, with undo.
2. **Debt stays off the tab bar and moves UP on Home**, right under Safe to
   Spend, and the Debt shortcut opens the list rather than a blank form. A
   sixth tab was offered and not chosen.
3. **Income rhythms: weekly and irregular are added** beside 15th and 30th
   and monthly, so Safe to Spend works for allowances and daily sales.
4. **Habit features approved:** collection reminders for money owed to you,
   a 48 hour "park it" list for impulse buys, and a backup reminder.
   **Not approved:** a no-spend day button and a "logged 5 of 7 days" count.
5. Compliance and privacy work waits until the founder is satisfied with
   what the app offers. That does not loosen the STOP conditions or the
   privacy promise in 01-vision.md.

ALSO BUILT, needing no decision: a "send a reminder" message and an overdue
tag on money owed to you; the Log sheet saying what an entry changed, opening
with the keyboard up, category icons and last-used defaults; "usual" chips;
the payoff plan on the user's own debts; a daily amount per budget; Reports
drill-down and the previous month; a Sweldo Day card; and honesty fixes
(screens that said "not built yet" about things that are built, or showed
unfinished parts to the public).

NOT BUILT, and why: Pan celebrating a reached goal was suggested and is
left out, because D30 rules out "wins or milestones". Changing that is a
founder decision, not an inference from D31.

## D32. Three money truths found while designing D31. ANSWERED 2026-10-09

THE QUESTION. Designing the approved D31 changes, the ledger-reconciler
measured three places where the app's figures were not the truth. Each is a
money-meaning change, so each went to the founder; all three answers were
the recommended option.

1. **Safe to Spend holds back bills the person ADDS.** It reserved only the
   built-in BillItem list, never the bills on the Bills screen
   (UpcomingItem), so in the reviewer's fixture 15,500 of bills due before
   payday were reserved as 0 and the headline was 15,500 too high. Fixed
   with one shared reader of unpaid obligations, so nothing is counted
   twice.
2. **Split bill counts only the person's own share as spending.** A 900
   dinner for three logged 900 of spending while 600 of it is owed back;
   budgets, Reports and the burn rate were overstated by the friends'
   shares. Cash still falls by the full 900; the 600 becomes money lent.
3. **Borrowing is the mirror of lending.** With D31's "lending moves real
   cash", borrowing into an account moves money IN, the debt rises by the
   same amount, net worth is unchanged, and it is never counted as income.

## D33. Which bills Safe to Spend holds back, and on which date. ANSWERED 2026-10-10

THE QUESTION. Building D32's first answer, the ledger-reconciler found two
places where the built-in bill list and the Bills screen still followed
different rules. Both change a money figure, so both went to the founder;
both answers were the recommended option.

1. **Only bills due by payday are held back, from either list.** The engine
   reserved every unpaid built-in bill whatever its date, so the example's
   8,500 tuition due October 5 was held back in a cycle ending September 30,
   while a bill added on the Bills screen for the same date was not, and the
   Safe to Spend breakdown labelled the total "Upcoming bills before payday".
   Overdue bills and bills with a date nobody can read are still held back.
2. **When a bill is on both lists, the date on the Bills screen wins.** The
   example's Meralco was counted once but kept the built-in date, September
   15 and overdue, while the Bills screen says Today, so Pan and the health
   check left it out of "due before payday".

## D34. When a friend paid, your share is spending on the day you ate. ANSWERED 2026-10-10

THE QUESTION. Building D32's split-bill answer, the ledger-reconciler found
that when somebody ELSE paid, the split took the person's share out of
their account at once (the box is ticked by default) and also recorded that
they owed it, so paying the friend back took it out a second time: one 300
share, 600 out of the account. Removing the double charge is a bug fix. When
the share counts as spending is a money-meaning choice, so it went to the
founder.

THE ANSWER, the recommended option: **on the day of the meal, under its own
category.** The share shows in that day's Food budget. Cash leaves only when
the friend is actually paid back, and that payment is not counted as
spending a second time. This is D32.3's "borrowing mirrors lending" applied
to a split: the friend lent you your share, so the record is a borrowing,
and repaying a borrowing is not spending.

NOT CHOSEN: counting the share on the day it is paid back, under "Debt &
Loan Servicing", which was smaller to build but would have kept the dinner
out of the Food budget entirely.
