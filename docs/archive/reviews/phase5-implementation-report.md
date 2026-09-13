# Salapify UI/UX Overhaul, Phase 5: Implementation Report

Intelligence: Insights, Reports, financial visualizations, and Pan. Date:
2026-08-08. Status: implemented, tested, visually validated, documented. Per
the stop condition, no Phase 6 work (Money Courses, Tools, Tax redesign) was
started. Ships as stamp f3.90.

The audit of record remains docs/full_app_ui_ux_design_system_audit.md; this
phase also ran three fresh independent audits of the Phase 4 build before any
code was written: a product-design pass over Insights (full element
inventory with KEEP / IMPROVE / MOVE / MERGE / REMOVE classification), a
product-manager pass over Reports (what analytical question each section
answers, the Reports-vs-Insights boundary, ranking and deep-link models),
and a data-visualization plus accessibility pass over every chart in the
intelligence surfaces. The three audits converged, and their findings are
what shipped.

## The boundary: Reports answers "what happened", Insights answers "what does this mean for me"

Documented here as the standing rule the screens now embody:

- Insights owns interpretation: the pulse (one read of the month), paced
  category shifts with drivers, the forecast pace line, ranked coach
  decisions, positive progress, tendencies, and every "what can I do" hook.
- Reports owns facts and exploration: the three statements, full trend and
  polarity charts, the complete category breakdown with drilldown, and
  historical navigation. Its current-month read is now factual only; the
  month-end projection lives on Insights alone, because two formulas
  forecasting the same month disagreed on the same day.
- Each side doors into the other: Insights carries one NavBand row into
  Reports ("See the full month in Reports"); Reports keeps its category
  drilldown into Activity. Insights duplicates no Reports chart.

## Insights Before vs After

Before, the tab held twenty near-equal cards, and its two "bigger picture"
charts were Reports content wearing Insights kickers: a six-month trend
that stated no conclusion, printed no per-month figure, had no semantics
and no interaction, and a category list that re-ran the same engine as
Reports' WHERE IT WENT with a weaker over-usual rule (1.2x, no absolute
floor, no regularity check), so the same category could read as a problem
on one screen and fine on the other on the same day.

After, the story order is: DO NEXT (unchanged coach ranking), the safe to
spend hero, Steady Pay, the next-peso plan, then THIS MONTH (pulse line,
the one dominant chart, WHAT CHANGED, the promoted win, the weekday
tendency, the Reports door), then THE BIGGER PICTURE (spoken-for, health
with its new "biggest lift" sentence, runway), with TOOLS closing the
screen instead of interrupting it. The duplicated category list and the
mute trend card are gone.

## Final Insights architecture

0. THE FINANCIAL PULSE, one raised hero that leads the screen: the single
   interpreted read of the month, toned good / steady / attention, carrying
   its confidence cue in words ("This month so far" for a fact, "From your
   logged history" for a trend) and, on an attention read, the magnitude in
   the sentence plus one Ask Pan door. This is the first thing seen, above
   DO NEXT, so the screen opens on what the month means before what to do
   next.
1. DO NEXT, ranked coach decisions, max 3 (engine unchanged)
2. SAFE TO SPEND UNTIL PAYDAY hero (unchanged)
3. Steady Pay (unchanged)
4. WHERE YOUR NEXT PESO SHOULD GO (unchanged)
5. THIS MONTH
   - INCOME VS SPENDING: the dominant chart, tap or scrub a month for its
     In / Out / Kept readout
   - WHAT CHANGED: up to three paced shifts, driver sentences, tap to
     History, Ask Pan on the biggest rise
   - GOING WELL: the coach win as a positive InsightCard
   - Weekday tendency as one quiet caption line
   - See the full month in Reports (NavBand row)
6. THE BIGGER PICTURE: spoken-for, Money Health (now names its biggest
   lift), emergency runway
7. TOOLS: the four collapsed launchers, moved to the end

The pulse hero is the hardening this phase added over the first draft, where
three independent design reviewers and the Pan reviewer all flagged the same
three P0s: the fact / trend confidence was computed in the engine and then
discarded on screen, the attention read carried no number ("spending is
running ahead of income" with no figure), and the pulse sat mid-screen inside
THIS MONTH rather than leading as a raised hero. The hero fixes all three: it
shows the confidence cue, the attention read now states the magnitude ("about
N% more has gone out than has come in"), and it is the raised, tone-colored
card at the top. phase5_pulse_test.dart pins all three (the engine states the
magnitude as a fact, the screen renders the cue and the numbered headline, and
the hero's headline sits above DO NEXT).

## Reports Before vs After

- SPENDING TREND and SAVED OR SPENT adopted ChartFrame (which previously
  had zero production adopters) with contextLine and a styled footer read.
- Tapping any bar in either chart steps the page to that month with a
  selection tick; the stepper stays the accessible control.
- The weekday chart was removed: it answered no decision on a what-happened
  screen. Its one honest sentence moved to Insights as a gated tendency
  line (only when the peak is at least twice the lightest day).
- The current-month trend read is factual (spent so far vs usual);
  the run-rate projection moved to Insights, one owner per forecast.
- Position stopped repeating the net worth hero 400px below the lead card;
  its statement now leads with the liquidity answer ("₱X clear of short
  debts"), and net worth still closes the statement as its total line.
- The debt-free plan renders on the Position tab only (it used to trail all
  three tabs).
- The "Cash flow" tab is renamed "Money flow": the Cash Flow screen is the
  forward Sweldo Timeline, and two surfaces sharing one name for opposite
  time directions confused every reader who touched both.
- Both 8.5px "so far" labels raised to the 10px painter floor.

## Visualizations

| Visualization | Question | Type | Interaction | Low-data fallback |
|---|---|---|---|---|
| Insights INCOME VS SPENDING | Am I spending more than I earn? | dual-line, income filled solid, spending dashed | tap or scrub a month for In/Out/Kept readout, selection ticks | "One month logged so far"; empty months read "No entries this month yet" |
| Insights WHAT CHANGED bars | Which habit moved? | paired bars, this month vs last month paced to the day | row taps into History filtered to category and month | refuses to compare before 34% of the month or without a prior logged month, and says why |
| Insights spoken-for bar | How much of my salary is committed? | stacked proportion | none | unchanged honest states |
| Reports trend bars | Is this month normal for me? | monthly bars plus usual line | tap a bar to step to that month | "not enough history" read unchanged |
| Reports diverging bars | Which months did I end ahead? | diverging around zero | tap a bar to step to that month | hidden with no active months |
| Cash flow balance chart | When does cash get tight? | line, band, payday dots | NEW: scrub with per-day ticks, date and balance readout | unchanged |

## Removed content

- Insights: the LAST 6 MONTHS mute chart (replaced by the interpreted,
  interactive version), the WHERE YOUR MONEY WENT category list (Reports
  owns the breakdown), the standalone win row (promoted to an InsightCard),
  and the weaker 1.2x over-pace flag with it.
- Reports: the WHEN YOU SPEND weekday card, the run-rate projection
  sentence, the duplicate Position net worth hero, and the debt plan's
  presence on two of its three tabs.

## Insight ranking

The DO NEXT ranking stays the coach engine's (unchanged). Within the new
feed, priority is deterministic arithmetic: the pulse picks the single
strongest claim by a fixed decision order (no income named plainly past
mid-month, overspend, best-month, more/less/same vs last month, first
month), category shifts rank by absolute peso movement with a ₱500 floor
and cap at three, and every claim carries an honesty gate rather than a
score: nothing compares against history that does not exist, nothing
projects before 34% of the month, a best-month claim needs three prior
income months and half the month passed, and a weekday claim needs a
two-to-one gap. Confidence is expressed in the words (a fact states, a
tendency "tends"), per the audit's fact / trend / possible-pattern rule.

## Derived metrics added (money/insight_feed.dart, all unit-tested)

- monthPulse: savings share now vs last month vs the 6-month window;
  guards: null and non-finite income, junk amounts clamp at 999%, silent
  branches for early months. 23 unit tests in insight_feed_test.dart cover
  the family.
- whatChanged and CategoryShift: this month vs last month paced by
  monthFraction; ₱500 floor shared with Reports' flag; stable sort.
- changeDriver: dominant note-group (at least half the category, two or
  more rows) or dominant single entry (60%), else null, never a weak claim.
- trendConclusion: ahead months over active months, null with no activity.
- weekdayLine: composes the golden-locked weekdayPattern and weekdayPeak.
- No schema change, no storage write, no existing calculation touched; all
  new reads compose golden-locked engines.

## Pan integration

PanScreen gained initialQuestion: a question asked FOR the user on arrival,
rendered as an ordinary user bubble and answered by the same golden-locked
brain as a typed one (nothing bypasses ask(), no reply shape changed, no
data leaves the device). Exactly two Insights entry points, both
contextual, neither omnipresent: an attention pulse offers "Ask Pan about
this month" (How was my month?), and the biggest rising category offers
"Ask Pan about <category>" (Am I overspending on <category>?). Both
questions map to intents the brain demonstrably answers.

## Card reduction

The populated tab went from roughly ten stacked interpretation cards plus
two Reports-shaped chart cards to: the same four decision/plan surfaces,
ONE dominant chart card, one WHAT CHANGED card, at most one win card, two
plain-text lines that deliberately are not cards (pulse, weekday), one
NavBand row, and the three bigger-picture cards. Net: two full chart cards
removed, one row promoted into an existing primitive, zero new card shapes
minted; InsightCard, ChartFrame, Metric, and NavBand are all Phase 2/3
primitives finally adopted on the screen they were built for, and the
duplicate _legendDot copy died.

## Fable review (rendered and looked at, dark first)

States inspected via the render harness: Insights populated (lived-in
fixture), Insights month-story at a fixed Jul 20 clock (paced shifts,
driver, Ask Pan, win), Insights low-data (three entries), Insights empty
and error (unchanged baselines), Reports all three tabs on the lived-in
fixture (never rendered by the harness before this phase), and the Cash
flow timeline. Defects caught by looking and fixed before merge: an empty
selected month printed "In ₱0 Out ₱0 Kept ₱0" (now says "No entries this
month yet" in words), the new chart caption hedged "about" over a
centavo-precise figure (caught by the about-rounding scan), and the scrub
hint row overflowed a narrow phone at 1.5x text (now expanded and
wrapping).

## Accessibility

- The Insights chart carries a Semantics container whose label is the
  conclusion sentence; the canvas is ExcludeSemantics; the readout and
  caption are real text.
- The two trend series differ by fill and dash, not hue alone; shift rows
  carry direction three ways (glyph, sign, then color).
- Painter labels now scale with the system font (clamped at 1.6x so labels
  cannot eat the plot); the 9px and both 8.5px labels are gone, and the
  type ratchet retired 8.5, 9, 10.5, and 11.5 from the legacy set
  entirely.
- The readout row is a Wrap, so 200% text stacks instead of clipping; the
  readability sweep (1x and 1.5x) is green over the new band.
- Chart taps are shortcuts; the month stepper and the printed sentences
  remain the accessible path. All new motion is static; scrub and tap
  selection are state changes, not animations, so reduced motion needs no
  new gating and Motion tokens remain honored where animation exists.

## Performance

No new per-frame work: the interpretation feed computes once per build
from already-loaded data (same pattern as every existing engine call), the
painters repaint only when selection or scale changes (shouldRepaint
extended), and scrubbing repaints one CustomPaint. No list virtualization
changes, no new timers, no async work added.

## Test results

flutter analyze: 0 issues. Full local suite green (2,800+ tests including
the 23 new insight-feed units, the 3 new pulse-hero pins in
phase5_pulse_test.dart, the WHAT CHANGED widget pin at a fixed clock, the
Pan initialQuestion pin, low-data honesty pins, and updated
Reports/Insights screen tests); the 96-shot render harness green; the
deterministic pixel baseline gained insights-month-story (fixed clock,
fixed fixture), possible only because InsightsScreen now takes an
injectable clock. Break-then-prove: deleting the early-month gate turned
"early month refuses to compare even with history" red (Expected: false,
Actual: true) before the gate was restored; the pulse pins were each proven
by reverting the corresponding fix (drop the magnitude, drop the cue, move
the hero back down) and watching the guard go red first.

One base-branch repair rode along, because a red suite blocks delivery for
everyone: three Phase 4 mindset win-edit widget tests
(mindset_screen_test.dart) were failing on clean origin/main, not from this
phase (mindset.dart is byte-identical to main and imports none of the
changed files). The cause was a test-harness fragility, not an app bug:
scrollUntilVisible built the win row into the tree but left it below the
600px test viewport, so tap() derived an off-screen offset (the framework's
own "would not hit test" warning), missed, and the edit sheet never opened.
The fix adds ensureVisible before each tap, the same pattern the
insights screen tests already use; no app code changed. Red-to-green proven
by running the three named tests before and after. The Flutter check on the
branch is the runner-side proof, per the standing local-vs-runner rule.

## Deferred to Phases 6-8

- Merging Reports' avalanche-vs-snowball comparison into the Insights debt
  what-if card (both still exist; the duplication is now scoped to one tab).
- A ranked "insight tier" presentation (needs-attention / important /
  positive / opportunity / FYI) as visible grouping; the arithmetic exists
  in the feed's gates and ordering, the visual tiering was deliberately not
  minted as new card shapes in this phase.
- Extending the readability sweep to the modal sheets (Phase 7 scope).
- Net worth over time: Salapify does not retain historical balance
  snapshots, so no trend chart was fabricated; if the founder wants it, it
  needs a persistence decision first (documented data gap, per the brief).
- Spending heatmap: evaluated and not built; weekday tendency covers the
  honest signal at current transaction densities.
