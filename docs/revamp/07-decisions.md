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
