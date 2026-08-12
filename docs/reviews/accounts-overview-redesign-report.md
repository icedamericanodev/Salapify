# Accounts redesign, increments 1-2 (stamps f4.02-f4.03)

Increment 1 (f4.02): the net worth card and quick actions, below.
Increment 2 (f4.03): collapsible account groups, at the end of this file.

---

## Increment 1 (f4.02): net worth card + quick actions

Part of the Accounts experience redesign (coffee-inspired, premium personal
finance UX). This is increment 1 of a larger, phased effort. Founder direction
for this session: prioritise the light coffee aesthetic (light acceptable as
default, dark to follow), keep a touch of coffee, and start with the Accounts
overview (net worth card + quick actions).

## Scope

Phases 2 and 3 of the redesign spec, on the existing Accounts screen
(`flutter/lib/screens/accounts.dart`):

- The net worth summary card, enhanced with an owned-versus-owed ratio bar.
- A compact quick-actions row (Transfer / Add / Pay / More) directly under it.

Everything else on the screen (Cash on hand, the card carousel, the grouped
own/owe sections, the transfer sheet, add/edit flows, account detail) is
unchanged in behaviour.

## What changed

- `_summary` now renders, in order: the NET WORTH hero, the Total assets /
  Total owed split, and a new **ownership ratio bar** with `% owned / % owed`
  labels. The bar is two token-coloured segments (assets in the brand accent,
  owed in the warning ink, matching the mini-stats). It is hidden when there is
  nothing on the book.
- New `_ownershipBar` helper. The split is spelled out in words and wrapped in
  a `Semantics` label ("N percent owned, M percent owed"), so meaning never
  rides on colour alone. Labels scale down within a `Flexible` so they never
  overflow at large system font.
- New **quick-actions row** (`_quickActions`, `_quickActionButton`, and a small
  top-level `_QuickAction` view model): Transfer, Add, Pay, More, each a caramel
  icon disc plus a short word, `PressableScale` press feedback, a `Semantics`
  button label, and a 44+ touch target.
- Wiring, honest only: Transfer opens the existing move-money sheet (guards
  writes-off and the single-account case with a plain-language snackbar); Add
  opens the existing add flow; Pay routes to the Utang "I owe" payables
  (`onOpenPayables`) or explains where payments live; More opens a labelled
  action sheet listing only flows that exist.
- Removed the old two text buttons (`+ Add an account`, `Move money between
  accounts`) and the `_addButton` helper; those affordances now live in the
  quick-actions row. The empty state gained its own `Add an account` action, so
  a fresh install still has a way forward.

## What did NOT change

- **No money math.** Every peso figure still comes from `netWorthParts`
  (`money/statements.dart`). The owned/owed ratio is derived purely for the bar
  and labels; it feeds no total, no stored value, and no calculation.
- **No stored data, schema, migration, sign, currency, precision, or rounding.**
- **No product/IA change to the account list, groups, cards, or transfer/add
  logic.** The transfer sheet and add flow are reached the same way, just from
  a new control.
- Golden-locked engines (`transfers.dart`, `netWorthParts`) untouched.

## Visual evidence

Rendered the Accounts overview on the lived-in fixture, light first (the coffee
aesthetic) then dark, via the shot harness
(`test/screens_shot.dart` -> `shots/accounts-overview-light.png` and
`accounts-overview-dark.png`). Both were looked at and sent to the founder.

Looking caught a real defect no test would have: the ratio bar was invisible
because a childless `ColoredBox` collapses to zero height inside a `Row`. Fixed
with `CrossAxisAlignment.stretch` and re-rendered; the bar now reads clearly in
both brightnesses.

## Validation

- `flutter analyze`: 0 issues.
- Full local suite: 2869 pass; the only red before the QA-log row was
  `qa_record_test` (the missing f4.02 row, by design).
- New `test/accounts_overview_test.dart` (9 tests): the owned/owed split in
  words, the underwater (negative assets) case reading 0% owned, the tiny-real
  side never rounding to 0%, the hidden bar on an empty book, the four quick
  actions, the single-account transfer explanation, the two-account transfer
  opening the sheet, More opening the actions sheet, and Pay routing to
  payables.
- Break-then-prove: the ownership-percentage test was proven to fail by
  inverting the owned numerator to liabilities (saw "17%" where "83%" was
  expected), then restored only after the run reported.
- Updated the tests that referenced the removed controls: `accounts_screen_test`,
  `transfer_screen_test`, `add_account_flow_test`, `journeys_test`,
  `screens_shot`, and `golden/ui_golden`.
- Sweeps green: `screen_readability_test`, `palette_contrast_test`,
  `design_foundation_test`, `accounts_own_owe_test`.
- Independent QA (qa-tester agent): 0 must-fix. One should-fix applied (the
  underwater clamp), one nice-to-have applied (the 1% rounding floor), one
  nice-to-have declined (EmptyState wording, kept as the founder-approved
  single-add-button framing).

## Deviations from the spec

- No "this month" net-worth change line. Phase 2 allows it only if the data
  supports it; there is no stored net-worth history, and the spec forbids
  fabricating one. Deferred to the Net Worth trend work (which needs a history
  abstraction reconstructed from the ledger).
- Visible quick-action labels are short single words (Transfer / Add / Pay /
  More) for a clean four-across row on a 320dp phone; the More sheet carries the
  fuller "Add account / Move money / Record payment" phrasing.

## Deferred (later increments)

- Collapsible account groups (Phase 4).
- Card carousel and flip polish (Phases 5-7).
- Account detail rework (Phase 8).
- Assets vs Liabilities donut view (Phase 9).
- Net Worth trend chart + history abstraction (Phase 10).
- Transfer form/success polish (Phases 11-12).
- Import statement and Account categories actions (Phase 13) are intentionally
  absent from the More sheet because no such flow exists yet; adding them would
  fake a capability.

## Risks

Low. Presentation-and-routing only, no money or data path touched. The one
behavioural change worth noting: Transfer and Pay are now always visible (they
were conditionally hidden before) but each explains, in plain words, when it
cannot proceed rather than leading to a dead end, and the writes-off safety was
preserved.

## Unresolved founder decisions

- Whether to flip the app-wide default appearance to light. The founder said
  light-as-default is acceptable; this increment builds token-based so it looks
  like coffee in Barako light and still works in every theme, but does NOT
  change the global default appearance (that is an app-wide behaviour change
  worth its own scoped step, not bundled into an Accounts-overview PR).

---

## Increment 2 (f4.03): collapsible account groups (Phase 4)

### Scope

The taxonomy sections in the account list became collapsible groups, so a long
repetitive list becomes scannable. The WHAT YOU OWN / WHAT YOU OWE class
kickers, the subtotals, the rows, and the "manage debts" note are unchanged.

### What changed

- `_section(title, subtotal, children)` became `_accountGroup({id, label, count,
  subtotal, children})`, plus a `_categoryGlyph(id)` helper mapping each
  category to a themed Material glyph (wallet, growth, house, card, document,
  calendar).
- Each group now has a tappable header: an icon disc, the title-case group name,
  an "N accounts" count, the group total, and a chevron that rotates on
  toggle. Tapping collapses or expands the rows with an `AnimatedSize`
  (reduced-motion aware via `Motion.of`) and a light selection haptic.
- New in-memory state `_collapsedGroups` (a set of collapsed category ids).

### Behaviour and the never-regress rule

- **Every group opens EXPANDED by default.** Collapsing is a scan aid the user
  opts into; nothing they already see is hidden behind a wall on open.
- **The group total stays in the header when collapsed**, so collapsing hides
  detail but never the money summary. No figure the totals count is hidden.
- Collapse state is in-memory only (resets on a fresh open). No settings key,
  no stored-data or backup change. Persistence is a possible later enhancement.

### What did NOT change

- No money math, schema, stored data, or classification. The subtotal is the
  same FX-aware `_countedAmount` fold as before, and rows keep their tap/edit
  behaviour and semantics.

### Visual evidence

Rendered on the lived-in fixture: `shots/account-groups-light.png` (expanded),
`shots/account-groups-collapsed-light.png` (Investments collapsed, total still
shown), and `shots/account-groups-dark.png`. Looked at and sent to the founder.

### Validation

- `flutter analyze`: 0 issues.
- New tests in `accounts_overview_test.dart`: a group collapses and expands its
  rows (with the total staying visible when collapsed), and a header names its
  account count (singular/plural). The collapse test was proven to fail
  (forced `expanded` always true, watched the row stay visible, restored).
- Regression set green: own/owe, accounts screen, focus-scroll (the searched
  row still builds inside the expanded group), readability, palette, design
  foundation, transfer.
- Independent QA (qa-tester): 0 must-fix, two should-fix APPLIED: (1) the header
  could overflow at a narrow width + large font + wide subtotal, now the
  subtotal is capped at half the row (LayoutBuilder) and scales within a
  FittedBox, so it never overflows and the longest name stays whole at normal
  sizes; (2) a stale `_revealFocus` comment overstated the row-tree guarantee
  and was corrected to name the lazy ListView and the collapsed-group caveat.

### Deferred

Card carousel/flip polish (Phases 5-7), account detail (Phase 8), assets-vs
-liabilities donut (Phase 9), net worth trend (Phase 10), transfer polish
(Phases 11-12), and group-collapse persistence. Two QA nice-to-haves are
deferred (nothing hidden either way): pruning a collapsed-group id when its
category empties and refills in one session, and the header count including an
unpriced foreign row the subtotal omits (consistent with net worth excluding
unpriced currencies).
