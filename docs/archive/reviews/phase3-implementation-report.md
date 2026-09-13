# Salapify UI/UX Overhaul, Phase 3: Implementation Report

Navigation, Overview and the core app experience. Date: 2026-08-08.
Status: implemented, reviewed, tested, documented, DELIVERED. Per the brief's
stop condition, Phase 4 has not been started and no screen outside the Phase 3
scope was redesigned.

Phase 3 shipped as eight over-the-air patches, each merged through the full
merge discipline (QA row, Flutter check green, merge commit, delivery row
confirmed):

| Stamp | Patch | Batch |
|---|---|---|
| f3.76 | 69 | Phase 3 opening: one rhythm everywhere (tail de-bordered, sparkline domain fix, NavBand Menu) |
| f3.77 | 70 | Batch 1, the feel pass (tab haptics, Motion.of adoption, FAB dip, nav de-styling) |
| f3.78 | 71 | Batch 2, the alignment pass (gutter and inset tokens, the Activity 8dp fix) |
| f3.79 | 72 | Batch 3a, the words pass (SAFE TO SPEND, CASH AHEAD, ACCOUNTS, Calculators, Payday schedule, EXTRAS) |
| f3.80 | 73 | Batch 3b, the calmer Home trio (bills fold, quiet all-good check-in, one pulse per screen) |
| f3.81 | 74 | Batch 3c, the lighter Home tail (payday receipt, conditional treats, denser chain, accounts preview) |
| f3.82 | 75 | Batch 4, one face for money on Home (AmountText adoption) |
| f3.83 | 76* | Batch 5, the polish pass (shared chips everywhere, budget row keys, sparkline draw-in, tail press dips, HeaderTier) |

*The f3.83 row is written by the publisher; if this report merged before that
run finished, the delivery log is the authority, as always.

## 1. Before vs After

Before Phase 3, Home was a wall of equally loud bordered cards speaking five
amount dialects. The payday card spent about 170dp repeating what the hero
already said, the treat card spent about 140dp every day regardless of
progress, every account the user owned was listed on Home, five or more bills
listed without a fold, and the all-good check-in put the full Pan card on
screen to say nothing was wrong. Tab changes were silent, re-taps buzzed,
chips were hand-styled per screen, and the hero, THIS MONTH, and NET WORTH
each carried private weight and tabular decisions.

After Phase 3, Home reads top to bottom as: the one number (SAFE TO SPEND),
what threatens it (bills before payday, folded past four), the one thing to do
about it (the check-in, one quiet row when all is well), then the habit layer,
then the month, then the whole picture. Money renders through one ladder.
Selection clicks once, on change only. Everything above the fold is a decision
or a number the founder asked for; everything below it earns its height.

## 2. Overview Architecture

Order on a lived-in phone, from the top:

1. Pinned wordmark row (peso mark, SALAPIFY, Search and Menu keys). Only the
   48dp key row pins; the greeting scrolls.
2. Payday ritual card, ONLY while today is payday and the salary is unlogged
   (logging it changes every number below, so the task outranks the number).
3. An URGENT check-in (crunch), if any, above the hero.
4. SAFE TO SPEND hero: per-day figure (AmountText.styleFor(xl) in a span with
   "a day"), the payday sentence, Committed and Free to spend rows, and a pace
   line that stays quiet while the calm check-in row is showing (one pulse per
   screen; the over-pace warning is never suppressed).
5. BILLS BEFORE PAYDAY, at most four rows, then a tappable "and N more before
   payday" that opens Cash flow. The total is an engine value, never a sum of
   visible rows.
6. The payday RECEIPT (one row: "Salary logged. Your cycle is set." plus
   Savings first) once the salary is logged and the fresh number shows; the
   full card stays only when the number is hidden, where its explanation is
   the only truth on screen.
7. MONEY CHECK-IN: the full Pan card when he has something to say (watch,
   nudge, urgent), one quiet row with a check when all is well, still a tap
   through to Ask Pan with the Semantics hint pinned by test.
8. CASH AHEAD with the sparkline (fixed domain, draw-in on arrival).
9. The habit layer: LOGGING CHAIN (densified) and the treat, full card only
   when earned or one check-in away, one quiet line mid-journey.
10. The lesson offer (2 MIN LESSON), when one applies.
11. THIS MONTH (signed AmountText lg, Money in / Money out StatPair), tappable
    through to Activity.
12. ACCOUNTS preview: top three by balance (foreign balances rank by converted
    value through the engines' resolveRate and convertAmount, and keep their
    own currency symbol), then "and N more accounts"; the card opens Accounts.
13. NET WORTH footer (AmountText lg, plain ink when negative on purpose) with
    Total assets and Total owed.

## 3. Removed or Moved Content

- The payday card's three-sentence done state collapsed into the one-row
  receipt (moved: the "savings first" action is kept as a compact button).
- The treat card's dots-and-button layout is shown only when earned or one
  away; mid-journey it is one line. Nothing was deleted; the full Treats
  screen is one tap away.
- Accounts past the top three moved behind the fold caption; every account
  remains on the Accounts screen the card opens.
- Bills past four moved behind the fold row that opens Cash flow.
- Insights' subtitle was removed (the first card is the introduction);
  headers follow the hero-introduction rule.
- Menu renames moved no content: Tools became Calculators and Payday became
  Payday schedule, with the destination screen titles renamed in the same
  commit so the label stays a promise the screen keeps.

## 4. Navigation Changes

- The shell owns the one Scaffold, the six destinations, the nav bar, and the
  Log FAB (available on every destination, canWrite-gated).
- Tab changes click (Haptics.select) on CHANGE only; re-tap scrolls to top
  silently through Motion.of.
- One name per destination: the Home card kicker ACCOUNTS matches the Menu
  row and the screen both open; SAFE TO SPEND matches what the hero shows.
- The nav bar sheds inline styling onto the theme; selected labels are w700
  (heavy stays reserved for money and titles).
- The FAB carries the house press dip and theme-owned styling.

## 5. Components Used

Phase 1 and 2 components adopted across the Phase 3 surface: AmountText (and
AmountText.styleFor for spans and foreign rows), SalapifyChoiceChip (the last
four hand-styled chip groups converted in f3.83), PressableScale (FAB, every
tappable Home card including the tail via one gate in _tailCard), Segmented,
NavBand and NavTile (Menu), Kicker, ScreenHeader plus the new HeaderTier enum
(tab and cover faces; the Learn lesson cover adopted it), EmptyState,
SalapifyProgressBar, the Gap/Insets/Radii/Motion/Haptics token sets, and
salapifyIcon for every Salapify-authored glyph.

## 6. Card Reduction

- Payday done state: about 170dp to one row.
- Treat card mid-journey: about 140dp to one line.
- Logging chain: about 140dp toward about 110dp (smaller dots, tighter gaps,
  nothing dropped).
- Home tail: bordered cards de-bordered onto quiet wash surfaces (f3.76);
  accounts list capped at three rows plus a caption.
- The all-good check-in: full Pan card to one row.

## 7. Typography Drift

- The type ratchet TIGHTENED four times across the phase: overview 12 to 11,
  learn 6 to 5, period_selector 2 to 1 (plus overview 13 to 12 in f3.76).
  The ratchet only goes down; freed slack cannot be respent.
- amountRow's strict rule (never resize, never reweight, tint only) is now
  machine-enforced for the cleaned files by test/amount_face_test.dart; the
  account rows' w6-at-16 and the bills row's w8 forks died in f3.82. Roughly
  twenty amountRow forks remain on screens outside Phase 3 scope; the guard's
  list grows as they convert.
- Big amounts snapped from w700 to the ladder's heavy w800 on AmountText
  adoption, the component's documented ruling, rendered and reviewed.
- The Learn cover's off-ladder 27 became TypeScale.big through HeaderTier.

## 8. Fable Review

The multi-agent design panel (product designer, product manager, design
systems engineer, interaction designer, UX writer) reviewed the Phase 3 plan
before implementation; their findings drove the batch list. Highlights that
became shipped code: the check-in clock seam fix (a DateTime.now() inside the
one-clock build), the one-pulse rule, the bills fold, the calm check-in row,
the tail preview, the chip conversions, and the copy renames. The founder's
veto window on LOGGING CHAIN was honored (kept, the writer's call defensible).
A real currency defect was found DURING implementation (a dollar balance
wearing a peso sign on Home's tail) and fixed in the same batch with both
halves proven by breaks.

## 9. Accessibility

- Selection is never color alone: the shared chip's check mark, the segmented
  control's glyph.
- Screen-reader destinations pinned by test: the calm check-in row carries
  "Opens Ask Pan"; the lesson row announces one spoken sentence; the tail
  cards are Semantics buttons with named destinations.
- Reduce-motion honored everywhere motion was added: Pan's bob, the sparkline
  draw-in, PressableScale, Segmented, scroll-to-top, all through Motion.of,
  each proven by a break in both directions (fires when it should, still when
  it should).
- Haptics: change-only clicks; no buzz on failures or no-ops (two real no-op
  buzzes killed in f3.83).
- The validation matrix (below) covers 120 and 200 percent text and a 320dp
  compact phone.

## 10. Screenshots and Goldens

- Every batch's touched screens were rendered dark on the lived-in fixture
  and sent to the founder in the conversation at the time of the change
  (founder rule, 2026-08-01), including the 42pt hero side-by-side that
  remains the founder's open call.
- The 93-shot render harness passes end to end on the final tree.
- The committed pixel baseline (test/golden/baseline, fourteen screens) is
  untouched: none of its screens include the Phase 3 surfaces, verified by
  its screen list.
- Shot files for the phase's states: batch3c_shot.dart, batch4_shot.dart,
  batch5_shot.dart (deliberately not *_test.dart, documented in each).

## 11. Test Results

- Full suite on the final tree: 2805 tests, all green, flutter analyze zero
  issues, whole tree, warnings fatal on the runner.
- New guard suites this phase: shell_feel_test (4), calmer_home_test (4),
  lighter_home_test (6), amount_face_test (1), polish_pass_test (3), plus
  overview_tail_test and sparkline_domain_test from f3.76. EVERY new guard
  was proven by a deliberate break with the failure line recorded in the
  commit or QA row, restored only after the run reported.
- The validation matrix, machine half (test/validation_sweep.dart, run for
  this report): every main tab at 1.2x and 2.0x text on a 390dp phone and at
  1.0x and 1.3x on a 320dp compact phone, zero layout exceptions in all four
  cells. The permanent gates already sweep 1.0x and 1.5x on every main screen
  each push (screen_readability_test) and 2.0x at 320dp for the wrapping
  controls (segmented_test, the f3.75 chip fix).
- Business logic safety: no financial formula, persistence path, backup
  format, schema, or calculation changed in any Phase 3 batch; every figure
  on every touched screen still comes from the same engine call. The money
  golden-vector suites stayed green throughout.

## 12. Deferred Issues

Carried forward, named, none blocking, in rough priority order:

1. The 42pt hero promotion: rendered side-by-side, founder's call, one line
   to ship.
2. About twenty amountRow forks on screens outside Phase 3 scope (reports,
   cashflow, recurring, notes, search, utang, tax and salary calculators,
   section.dart, bank_card.dart); convert with their screens, growing
   amount_face_test's list each time.
3. The period selector's four mode chips wrap to two lines at 390dp on the
   shared chip's larger tap target; accepted, revisit if the founder minds.
4. Menu's SETTINGS and PRIVACY sections still speak the old bordered-row
   dialect (pre-existing, noted in f3.76).
5. pageTransitionsTheme pin, SafeArea hoist, FAB hide on keyboard, StatPair
   numeric API (design systems engineer deferrals).
6. Kai's remaining motion items: tab-content fade, check-in AnimatedSwitcher.
7. CycleStatus could expose a committed field so the hero legend reads it
   directly; typography.dart:118 doc comment rot.
8. sparkDomain still throws on an empty list (guarded at its one call site);
   _niceCeil on non-finite input unreachable through real data.
9. NavTile.detail is a documented parameter no call site passes.
10. The chain STREAK rename (founder call, default keep); hero centavos
    question; the Pan-hole-in-check-in investigation; transfer-in-log-sheet.
11. Permanent harness entries for overview-empty and large-text states.
12. The chevron size-18 literal repeats where IconSizes exists.

Per the brief: Phase 3 ends here. No Phase 4 work has been started.
