# Salapify Design Foundation, Phase 1 Audit

UI / UX Design Foundation, Phase 1, Read-only audit.

## Salapify already has a design system. It needs finishing, not founding.

A comprehensive read of the Flutter app (57 screens, 31 widgets, about 52,500
lines) found an unusually mature, self-documenting design system that is
**mid-consolidation**. The tokens, the type ladder, the sixteen AA-verified
palettes, and a real shared-widget library are already built and sound. The
work of a cohesive Salapify is to **complete adoption** of what exists and
formalize it, not to restart from a blank canvas.

- **Scope:** flutter/lib, theme + typography + widgets + screens
- **Method:** direct code read plus three specialist passes (UI craft,
  competitor benchmark, motion)
- **Constraint:** analysis only, no code or Figma edits

### The one thing to take away

Salapify does not have a design problem in the usual sense. It has a token
layer (`Gap`, `Radii`, `Motion`, `Haptics`, `IconSizes`), a full type ladder
(`TypeScale`, `TypeWeight`, `AppText`), a getter-based palette engine across
eight themes and two brightnesses, a semantic icon layer, and shared widgets
(`AmountText`, `Kicker`, `StatPair`, `Segmented`, `ScreenHeader`,
`PrimaryButton`, `EmptyState`). Each is documented with the reason it exists.

What it does not yet have is **full adoption**. Roughly 40 percent of screens
still hand-roll around the very primitives built to unify them. The gap between
the system and the screens is countable, and closing it is the fastest path to
a cohesive, premium, recognizably Salapify product.

### Adoption drift, counted

- **6** screens use `AmountText`, versus 150-plus raw `formatMoney()` calls
  inside hand-styled Text on the money screens.
- **70** private input-decoration blocks across 37 screens, despite a complete
  `inputDecorationTheme`.
- **55** legacy `Radii` alias references still live across 18 files, scheduled
  for deletion.
- **187** raw `FontWeight` literals across 45 screens, bypassing the
  `TypeWeight` roles.
- **42** hand-rolled `AppBar`s across 38 files, each re-setting the trio the
  theme already owns.
- **0 / 1**: `InsightCard` is adopted nowhere; `ErrorState` is adopted in
  exactly one screen.

---

## A. Current UI assessment

Where the app stands today, as a whole, before the itemized findings.

**The foundation: a rare, disciplined token layer.** `theme.dart` defines a
spacing ladder, semantic radii, an opacity ladder, a five-duration motion set
with a reduce-motion gate, a three-word haptic vocabulary, and an explicit
surface model (background, then card with a border, then one raised hero,
borders over shadows). `typography.dart` anchors an eight-rung scale to the
React Native app with four real Jakarta weights. This is more rigor than most
shipping consumer finance apps carry.

**The identity: warm, coffee-toned, dark-first.** The signature palette is warm
brown-black (background `#1A130E`) with a roasted-orange accent and a
theme-invariant gold reserved for wins. That warmth reads as premium and is
genuinely distinctive against the cool graphite or pure black every competitor
defaults to. All sixteen palettes pass WCAG AA by an enforced test. This is a
competitive asset to protect, not restyle.

**The strongest surface: analytics that prescribe, not just describe.**
Insights and Reports lead with an interpreted read of the month, ranked next
actions, a safe-to-spend number, a "where your next peso should go" rail, and a
money-health score out of 100 with component bars. Every chart states its own
conclusion in a caption. This is ahead of Copilot Money, whose insights are
mostly descriptive.

**The soft spot: hierarchy and adoption, not aesthetics.** The two most
important screens (Home and Insights) stack 30-plus near-equal bordered cards,
so triage falls entirely on kicker text. And the shared primitives that would
unify the money screens are bypassed on exactly those screens. Neither is a
taste problem; both are finishing problems, and both are already half-solved in
code.

> **Read the code comments.** This system documents its own unfinished work.
> Files literally say "Phase 2 deletes them," "Deliberately NOT adopted anywhere
> yet," and "legacy aliases, kept so the migration can move screen by screen."
> The audit is not discovering hidden debt; it is inventorying debt the team
> already named. That is the healthiest possible starting point.

---

## B. Design inconsistencies

The specific, counted drift. Each item is a place the system was built to unify
but has not yet reached.

- **Money presentation (the priority theme).** `AmountText` (with
  scale-down-never-truncate protection) is used in 6 files, while the heaviest
  money screens render figures raw: reports 32, mindset 28, insights 21, utang
  20, goal_detail 19, overview 14, cashflow 13, debts 12, budget 11, accounts
  11. The widget built to stop money drift is absent on the golden-locked money
  screens, where a 7-digit peso figure beside a label can overflow at 320dp.
- **Typography.** Off-ladder sizes survive despite the file claiming they were
  eliminated: `fontSize: 12.5` in 14 places, plus 14.5, 13.5, 19, 9, and 187
  raw `FontWeight` literals across 45 screens. goal_detail is the worst, with 12
  raw fontSize sites including `AppText.title.copyWith(fontSize: 20)`, which is
  exactly the `lg` rung.
- **Spacing.** Paddings off the `Gap` ladder (2/4/8/12/16/20/24/32) are common:
  literal 14 used about 69 times, 6 about 40, 10 about 35, 18 about 23. Even the
  shared EmptyState and ErrorState use `EdgeInsets.all(20)` instead of the
  `Insets.hero` token.
- **Headers and app bars.** `ScreenHeader` unifies the five tabs, but 42 pushed
  screens hand-roll an `AppBar` and re-set background, foreground, and title
  weight, which `appBarTheme` already owns. Reports and mindset also bypass the
  `Kicker` widget entirely and hand-roll uppercase labels.
- **Inputs.** 70 private input-decoration blocks across 37 screens re-declare
  hint and label styling that `inputDecorationTheme` already provides. mindset
  alone has 10; the six calculators each declare their own, so the tools drawer
  reads as several slightly different mini-apps.
- **Surfaces and radius.** 100-plus hand-rolled `BoxDecoration` surfaces each
  re-pick a radius, border, and fill outside `Radii.card` and the card theme.
  Legacy `Radii` aliases (`sm`, `md`, `lg`, `xl`) still point at the same
  numbers as the semantic rungs, which is the exact drift the class exists to
  prevent.
- **Dialogs and sheets.** 26 `showDialog` sites, no shared confirm dialog, so
  destructive-action styling is per-site. 32 bottom sheets, of which 13 pass a
  transparent background and draw their own container, so the sheet "doorway"
  radius is not yet uniform.
- **Motion and haptics.** No shared-element transitions anywhere (every
  list-to-detail is a plain platform slide). The hero balance is static text.
  Charts paint their final state with no entry animation. About 15 sites call
  `HapticFeedback` raw instead of the `Haptics` vocabulary, so they cannot be
  centrally retuned.

---

## C. Components to keep

The locked foundation. These are genuinely excellent and should be treated as
the fixed base of the design system, protected by their existing tests.

- **Token layer (`theme.dart`).** `Gap`, `Radii`, `Insets`, `BarakoAlpha`,
  `Motion` (with the `Motion.of` reduce-motion gate), `Haptics`, `IconSizes`,
  and the surface model. Every rung is documented with why it exists.
- **Palette engine (`theme.dart`).** The `Barako` getter palette and the
  eight-theme registry with per-palette AA-tuned hex, plus the theme-invariant
  celebrate gold. The warm dark identity is the brand.
- **Type ladder (`typography.dart`).** `TypeScale`, `TypeWeight` (four real
  weights, w500 banished), `AppText` roles, and the `.w7 / .tint / .tabular`
  modifier extension. The "amountRow is strict, never resize" rule is correct.
- **AmountText (`widgets/amount_text.dart`).** The correct money primitive:
  role-based sizing with scale-down-to-fit so a peso figure shrinks rather than
  truncating into a different-looking amount. Keep the design, fix the adoption.
- **Section primitives (`widgets/section.dart`).** `Kicker`, `SectionHeader`,
  `StatPair` (the two-column headline breakdown that stacks at 1.5x text scale),
  and `CollapsibleCard` with proper expanded semantics.
- **Segmented (`widgets/segmented.dart`).** The standout accessibility widget:
  measures the longest label in the real font and stacks vertically when it will
  not fit, 48dp floor, a check-glyph shape cue rather than color alone.
- **PressableScale and FlipBankCard (`widgets/`).** A press-dip that never
  steals scroll (uses a Listener, releases past touch slop), and Revolut-grade
  3D card physics with a mid-flip tap guard and a reduce-motion crossfade.
- **Pan mood system (`money/pan_mood.dart`).** The mascot is event-driven, not
  random: it reacts to the top coach item and to what the user just did, with a
  6-second override that expires. A genuine, ownable identity mechanic.
- **Empty and error shells (`widgets/`).** One reassuring, non-shaming
  card-and-column shape. The copy rule ("reassuring, never scolding") is applied
  everywhere it is used.
- **State and reward discipline.** Celebration reserved for earned moments only,
  the haptic vocabulary, tabular figures on all amounts, and the fully
  eradicated `withOpacity`. Keep enforcing all of it.

---

## D. Components to refine

Right in concept, in need of tightening. No rebuilds here, only adjustments that
make an existing thing land better.

- **Home hierarchy (`screens/overview.dart`).** 32 cards and 56 spacers of
  near-equal weight. The instinct is already right (the tail cards were
  de-bordered into a "quiet band"); extend it so the top third reads as
  decisions and the rest reads as reference. This is the single most important
  screen to re-rank.
- **Insights density (`screens/insights.dart`).** A wall of near-identical cards
  where observation, meaning, and action run together as prose. The fix is to
  adopt the `InsightCard` three-slot shape (observation, meaning, way forward)
  that already exists for exactly this.
- **Negative-money color.** Money owed is `warningStrong` in some places and
  `warning` in others. Pick one token for "owed or negative" and document it.
  `warningStrong` is the AA-tuned small-text one, so it is the better default
  for row subtotals.
- **The hero number (`widgets/amount_text.dart`).** The biggest,
  highest-attention number in the app is static text. Give `AmountRole.hero` a
  roll-up tween on change, in one place, so every hero number in the app
  inherits it. Reduce-motion gated.
- **Goal progress (`screens/goals.dart`).** Strong plan-first content, but
  progress is a flat bar with no emotional payoff. Spend the celebrate gold,
  milestone haptic, and reserved celebrate duration (all already shipping) on 25
  / 50 / 75 percent crossings.
- **Charts (insights, reports, cashflow).** Every chart paints its final state
  with no draw-on. Give the painters a 0-to-1 progress field driven by the same
  tween primitive the progress bar already uses. Bars grow, the sparkline draws
  on.
- **Off-ladder type and spacing.** Snap the surviving 12.5 / 14.5 / 13.5 sizes
  and the 14 / 6 / 10 / 18 paddings to the nearest rung. Mechanical, guarded by
  the readability sweep, invisible to the user.
- **const-freeze gap.** Several private, color-reading screen widgets declare
  `const` constructors. No active freeze today (call sites omit const), but a
  stricter lint would freeze their palette after a theme switch. Add the same
  opt-out the shared widgets carry.

---

## E. Components to consolidate

Duplicated patterns to route through one shared path. Highest return on
investment in the whole audit, because the shared widgets already exist and the
work is adoption.

- **AmountText everywhere.** Force adoption on the money screens (reports,
  insights, cashflow, debts, utang, accounts). Replace private helpers like
  `_heroAmount()` with the role API so the tabular-figures and overflow
  protection are guaranteed, not per-site.
- **Kicker and SectionHeader.** Reports and mindset use zero shared kickers and
  hand-roll uppercase labels, including a second off-ladder overline at
  `fontSize: 10`. Route them through the one widget.
- **Input decoration.** Delete the 70 private decoration blocks and the named
  helpers; a bare `TextField` is already correct by theme. This is explicitly
  the "Phase 2 deletes them" work the theme comment names.
- **App bars.** The 42 hand-rolled app bars should drop their inline background,
  foreground, and title style and let `appBarTheme` own them, so a theme change
  reaches every screen's chrome.
- **Legacy Radii aliases.** Convert the 55 `Radii.sm/md/lg/xl` references to the
  semantic rungs and delete the aliases, so one number no longer has two names.
- **Chips and segmented.** `SalapifyChoiceChip` and `Segmented` exist but are
  not the only path yet (Utang still hand-rolls its owe/owed toggle). Make the
  shared widget the single path.
- **Bottom sheets.** The 13 sheets that draw their own container should adopt
  the theme sheet surface and radius, so every sheet shares one doorway.
- **Raw haptics.** Route the roughly 15 raw `HapticFeedback` calls through the
  `Haptics` vocabulary, so the "one grep audits every haptic" promise actually
  holds.

---

## F. Components genuinely missing

Not drift, but real gaps: primitives and data the system would benefit from and
does not have. Ordered by leverage.

**Structural: a shared list-row primitive.** Home account previews, the Accounts
rows, Utang people rows, and Activity transaction rows are each hand-rolled. One
`SalapifyRow` (leading, title, subtitle, trailing amount, optional progress,
optional highlight) is the biggest single unifier available. It is what makes a
row on Home, Accounts, and Activity read as the same app.

**Structural: a shared summary and confirm layer.** The net-worth summary is
hand-rolled three times (Home footer, Accounts, Reports lead). And 26 dialogs
share no `ConfirmDialog`, so destructive confirms are styled per-site. Two small
shared widgets remove a whole class of drift.

**Product data: net worth over time.** Every net-worth figure is a
point-in-time snapshot; the trajectory is never plotted, which is exactly what
turns net worth from a vanity number into motivation. Store a monthly snapshot
on ledger write, then surface one trend line on Accounts and in the Reports
Position tab. One data investment, two surfaces, and the clearest gap versus
Copilot and Monarch.

**Product data: category capture at log time.** The add-transaction sheet
captures amount, label, date, and account, but no category, so the excellent
"where it went" breakdown is starved of data. The form already reserves the API
slot. Adding an optional category chip row keeps the two-tap speed and feeds the
analytics that already exist.

**Motion: shared-element and chart-entry helpers.** No `Hero` transition wraps
any list-to-detail push, and no chart animates on entry. A small shared-element
helper (tag `card-<id>`) and a reusable 0-to-1 chart-progress driver would raise
the whole app to the Copilot and Cash App motion bar, reusing primitives already
in the tree.

**Intentional non-gaps: what to deliberately skip.** Skeleton loaders and
pull-to-refresh are correctly absent: the store is offline and synchronous, so
there is nothing to fetch and nothing to skeleton. Do not add them for their own
sake. The fixed brand colors in the share images are also correct, since those
render off-screen and cannot inherit the theme.

---

## Fintech clarity review

Does the UI make each money concept immediately understandable, without hiding
anything to look minimal? Verdicts below, with where each lives today.

| Concept | Where it lives | Read | Note |
| --- | --- | --- | --- |
| Available money | Home "Safe to spend a day" hero, Insights | Strong | The right hero. A forward, spendable number beats leading with net worth. |
| Net worth | Home footer, Accounts summary, Reports | Clear, static | Legible and correctly demoted on Home. Missing its trajectory over time. |
| Assets vs liabilities | StatPair, "What you own / owe" kickers | Strong | Structural own/owe split, not color alone. Subtotals cannot drift from the total. |
| Income vs expenses | Home "This month", Reports income statement | Strong | Net headline first, then the two parts. Reads plainly. |
| Cash flow | Sweldo Timeline, Cash Ahead sparkline, diverging bars | Differentiator | A payday-cycle forward projection no listed competitor ships. Protect it. |
| Savings | Goals, "money stays in your accounts" line | Strong | Kills the savings-account-vs-goal double-count confusion up front. |
| Debt | Utang tab, "What you owe", account rows | Strong | Neutral ink for on-schedule debt, red reserved for overdue. Humane and correct. |
| Goals | Goals list, focus goal, pace line | Strong, flat | Answers every question per goal. Lacks the emotional payoff of progress. |
| Financial health | Insights money-health score /100 with bars | Ahead of market | Prescriptive, component-broken, with a named biggest lift. A real edge. |

The two real gaps are both additive, never subtractive: net worth over time, and
category at log time. Neither requires hiding a single figure that is shown
today.

---

## G. Proposed design foundation

A direction that is finance-first, trustworthy, modern, approachable, and
information-rich without being crowded, built by formalizing Salapify's own
system rather than importing one. Working name: **Warm Ledger**.

- **Principle 01, one hero number, one action, per screen.** Each screen answers
  a single question above the fold and offers one clear next step. Everything
  else is reference and is visibly quieter. This is the altitude rule the
  tail-band work already started; make it the law.
- **Principle 02, decisions look different from reference.** Bordered cards for
  things to act on, borderless tinted panels for things to know. The eye should
  triage by shape and weight, not by reading every kicker. This directly answers
  the 30-card density on Home and Insights.
- **Principle 03, every peso through one pipe.** All amounts render through
  `AmountText` and format through the one formatter, so a figure can never
  disagree with itself across screens, and a long number scales down instead of
  truncating into a lie.
- **Principle 04, borders over shadows, warmth over gloss.** Three surface tiers
  (background, card with a hairline, one raised hero) carry hierarchy through
  contrast and spacing, so a screenshot reads as Salapify with shadows off. Keep
  the coffee-warm dark as the primary voice.
- **Principle 05, meaning is never color alone.** Direction carries a sign or a
  glyph, selection carries a shape, tone carries a word. Color reinforces, never
  sole-signals. Already a rule in the strong widgets; extend it to the ones
  being consolidated.
- **Principle 06, motion with intent, reward reserved.** Shared-element pushes, a
  rolling hero number, charts that draw on, all reduce-motion gated. The
  celebrate gold and milestone haptic stay rare and earned, and get spent on
  goal and debt wins, not routine logs.

> **Why not restart.** The code's design vocabulary is more mature than any
> greenfield Figma library would be on day one. Formalizing it (documenting the
> tokens, drawing the target screens, closing adoption) compounds four years of
> encoded decisions. Restarting throws them away and reintroduces the exact
> drift the system already fought down once.

---

## H. Five North Star screens

The reference targets. For each: the question it answers, what to keep exactly,
and the specific moves that raise it to best-in-class without hiding
information.

### H1. Home

*Decide in two seconds. Answers: how much can I safely spend, and what is the
one thing to do.*

- **Keep:** The Safe to spend a day raised hero, with net worth correctly
  demoted to a quiet footer. The spoken-for bar drawn from the same engine call,
  so it cannot disagree with the number. The payday-ritual sequencing and the
  Pan check-in.
- **Refine:** Re-rank into a short decisions stack, then a denser reference band;
  shrink the 32 near-equal cards. Give the hero number a roll-up on change. Pop
  today's week-chain dot when a log lands.

### H2. Accounts

*What I own and owe. Answers: what am I worth, made of which accounts.*

- **Keep:** The net-worth hero with own/owe mini-stats and the class kickers. The
  card carousel and the separate Cash on hand tile (cash is not an institution
  account). Subtotals that count by the same rule as the total.
- **Refine:** Add a net-worth sparkline to the summary from monthly snapshots.
  Adopt the shared list-row so account rows match Home and Activity. Lift the
  card monogram so two same-hue banks stay distinct.

### H3. Transactions (Activity)

*What happened, fast to add. Answers: what moved, and let me log the next thing
in two taps.*

- **Keep:** The grouped-day ledger (one card per day, hairline rows) and explicit
  signs, never tint alone. Swipe-to-delete with a 5-second undo and a
  money-written haptic on commit. Amount field autofocused, last account
  preselected, recent labels one tap away.
- **Refine:** Add the reserved category chip row at log time to feed the
  breakdowns. An in-sheet success beat so the confirmation is seen where the
  action happened. Shared-element row into the transaction detail.

### H4. Goals

*Plan, then progress. Answers: what am I saving for, at what pace, on track or
not.*

- **Keep:** The plan-first card: what it is, in, left, pace, status, next action,
  without opening anything. The focus goal suggestion and the one-tap deep link
  into add-money. The "money stays in your accounts, goals just earmark it"
  clarity.
- **Refine:** Spend the existing celebrate gold and milestone haptic on 25 / 50 /
  75 percent crossings. Route the goal card through the shared list-row and card
  tokens. Give the progress fill a draw-on animation.

### H5. Insights

*What it means, what to do. Answers: how is my money, and what should I change.*

- **Keep:** The interpreted pulse hero, ranked do-next decisions, and the
  money-health score with component bars. Every chart states its own conclusion
  in a caption. The "where your next peso should go" order rail.
- **Refine:** Adopt the InsightCard three-slot shape to break the wall-of-prose
  density. Route all figures through AmountText and the kicker widgets. Add a
  net-worth-over-time chart where the analytical reader already is.

---

## I. Recommended Figma workflow

Because the code's system is the most mature artifact in the room, run Figma
**code-first**: the code stays the source of truth for tokens, and Figma is
where the target screens and the shared component set are drawn and reviewed.

> **Seat check first.** The connected Figma workspace is a Starter tier with a
> View-only seat. Authoring variables, components, and frames needs at least one
> Editor seat. Resolve this before Phase-2 design work begins; everything below
> assumes an editor is available.

- **Step 01, tokens as Figma variables.** Mirror `Gap`, `Radii`, `TypeScale`,
  and the palette into a variable collection. Use variable modes for the eight
  themes across light and dark, so one component reflects any palette. Code
  remains the source; Figma imports it, never regenerates it.
- **Step 02, component library from the widgets.** Build components that map
  one-to-one to the real widgets: `AmountText` roles, `Kicker`, `StatPair`, the
  card tiers, `Segmented`, the buttons, the shared list-row, sheets, dialogs, and
  the empty and error shells. Name them exactly as the Dart widgets are named.
- **Step 03, draw the five North Star frames.** Compose the target Home,
  Accounts, Activity, Goals, and Insights from those components, in dark first
  (the founder's mode). Include a before-and-after for the Home and Insights
  re-rank, since hierarchy is the biggest visual change.
- **Step 04, Code Connect the loop.** Map each Figma component to its Dart widget
  with Code Connect, so a designer opening a component sees the real
  implementation and the two cannot silently drift. This keeps the code-first
  discipline honest over time.

Guardrail: never let Figma become a second, competing source of tokens. If a
value differs between the two, the code wins, because the code carries the AA
tests, the golden baseline, and four years of documented reasons.

---

## J. Proposed phased implementation plan

A real sequence, ordered so each phase de-risks the next and nothing a user
already has moves behind a wall. It aligns with the codebase's own named Phase 2
and Phase 3, and every phase keeps the existing guard tests green.

**Phase 1, Done. This audit.** Evidence gathered, foundation named, North Star
targets and the missing-component list agreed. No code touched.
Risk: none. Analysis only.

**Phase 2, Formalize. Finish token adoption.** Snap off-ladder type and spacing
to the nearest rung, convert and delete the legacy `Radii` aliases, drop the 42
hand-rolled app bars to the theme, and delete the 70 private input-decoration
blocks. Mechanical, screen by screen.
Risk: low. Guarded by the readability sweep and palette contrast tests; no
user-visible change. Enhance, never regress: old behavior stays, tests stay
green.

**Phase 3, Unify. Shared primitives and money pipe.** Build the shared list-row,
summary card, and confirm dialog. Force `AmountText` and the kicker widgets onto
the money screens (reports, insights, cashflow, debts, utang, accounts). Adopt
`InsightCard` on Insights and `ErrorState` app-wide.
Risk: medium. Touches golden-locked money screens, so it runs behind the money
vectors and the journey tests, one screen per batch.

**Phase 4, Re-rank. Hierarchy on Home and Insights.** Apply the
decisions-versus-reference weight split so the two densest screens answer one
question first. This is where the North Star Home and Insights frames land.
Risk: medium. Visible layout change; render every touched screen to a PNG and
show the founder in dark first before merge, per the house rule.

**Phase 5, Motion. Premium interaction pass.** Shared-element card-to-detail, the
rolling hero number, chart draw-on, the week-chain dot pop, carousel page
physics, and the in-sheet log success beat. Consolidate the raw haptics into the
vocabulary.
Risk: low to medium. All reduce-motion gated, all reusing primitives already in
the tree. No new dependency.

**Phase 6, Surface data. The two additive product gaps.** Store monthly
net-worth snapshots and plot the trend on Accounts and Reports. Add category
capture at log time to feed the breakdowns. Wire goal-milestone celebrations.
Risk: medium. Snapshots and category are data-shape changes; they run behind the
data-migration reviewer and the backup schema rules. Neither hides an existing
figure.

> **Constraints honored throughout.** Every phase respects the founder rules:
> enhance what exists rather than regress it, keep the tests that guard old
> behavior green, render and show the founder the screens that change (dark
> first), and no em dashes or en dashes in any copy. Delivery discipline (the
> update stamp, the QA row, the Flutter check on the branch) is unchanged; this
> plan produces PRs, not a rewrite.

---

**Salapify UI / UX Design Foundation.** Phase 1, read-only audit. Prepared from
a direct read of `flutter/lib` plus three specialist passes (UI craftsmanship,
competitor benchmark, motion and interaction). No Flutter code, Figma files, or
dependencies were changed. All counts are grep-confirmed against the current
tree.
