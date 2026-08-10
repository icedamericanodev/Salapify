# Phase 2 Implementation Report

Design system adoption and consolidation. Not a redesign: the goal was "the
same Salapify, more consistent and more resilient." Every change is
behavior-preserving and guarded, and the app looks the same to a user.

This PR delivers the three lowest-risk, code-comment-sanctioned foundation
workstreams in full, each with a proven-to-fail guard, and sequences the
higher-touch workstreams (money presentation, typography, inputs, surfaces,
sheets, states) as the next reviewed batches. That split is deliberate and
follows the founder's own rules: "small tested steps," "do not make one giant
mechanical sweep across 57 screens without verification," and the stop
conditions around money meaning and hierarchy.

Stamp: f3.96. `flutter analyze` clean; 2852 tests pass (the only red is the
QA-log gate, satisfied by this batch's row); 126 screenshots rendered and the
touched surfaces reviewed dark-first.

---

## 1. Files changed

54 files under `flutter/lib`, net -290 lines (144 insertions, 434 deletions):
pure redundancy removal, nothing added to a screen.

**Workstream 3 (Spacing and Radii) — legacy `Radii` aliases**
- `lib/theme.dart`: deleted the four legacy aliases (`sm`, `md`, `lg`, `xl`)
  from the `Radii` class; replaced the block with a note pointing at the guard.
- 18 files converted their 55 alias call sites to semantic rungs
  (`control`/`field`/`card`/`hero`): `screens/account_detail.dart`,
  `accounts.dart`, `appearance.dart`, `categories.dart`, `goal_create.dart`,
  `goal_detail.dart`, `goals.dart`, `learn.dart`, `menu.dart`, `onboarding.dart`,
  `overview.dart`, `tax_deadlines.dart`, `year_end_tax.dart`, and widgets
  `bills_before_payday.dart`, `screen_header.dart`, `segmented.dart`,
  `treat_card.dart`, `week_chain.dart`.

**Workstream 9 (Haptics) — the vocabulary is now the only path**
- 13 files routed 20 raw `HapticFeedback.*` calls through `Haptics.*`:
  `screens/reports.dart`, `learn.dart`, `insights.dart`, `split_expense.dart`,
  `afford_card.dart`, `recurring.dart`, `cashflow.dart`, `appearance.dart`,
  `treats.dart`, `paluwagan.dart`, and widgets `celebration.dart`,
  `paged_lesson_reader.dart`, `expansion_lesson_reader.dart`.
- 9 of those files had their now-orphaned `flutter/services.dart` import
  removed; the 4 that also use text-input formatters kept theirs.

**Workstream 4 (App bars) — the theme owns the chrome**
- 41 pushed screens dropped the inline `backgroundColor` / `foregroundColor` /
  title `TextStyle` from their `AppBar`, so `appBarTheme` owns them. `AppBar`s
  now carry just a title (and any real actions).

**Guards (test)**
- `test/design_foundation_test.dart`: three new source-scanning guards (legacy
  Radii aliases gone, every haptic through the vocabulary, no AppBar re-setting
  theme-owned chrome). Each was proven to fail on its intended path and then
  restored.

**Stamp**
- `lib/main.dart`: `updateStamp` bumped to f3.96 (bumped first, before the
  work).

Also committed: `docs/salapify-ui-design-foundation-audit.md`, the Phase 1
audit that scoped this work (it was untracked).

---

## 2. Adoption metrics (before / after)

| Metric | Before | After | Note |
| --- | --- | --- | --- |
| Legacy `Radii` alias references | 55 | **0** | aliases deleted; a guard keeps them gone |
| Raw `HapticFeedback` calls (outside `theme.dart`) | 20 | **0** | one vocabulary, centrally retunable |
| AppBars re-setting theme-owned chrome | 41 | **0** | a theme change now reaches every pushed screen |
| `AmountText` adoption (files) | 8 | 8 | deferred (Workstream 1, see below) |
| Raw `formatMoney()` presentation in screens | 153 | 153 | deferred (Workstream 1) |
| Raw `FontWeight` literals (screens+widgets) | 174 | 174 | deferred (Workstream 2) |
| Off-ladder font sizes (12.5/13.5/14.5/19/9) | 21 | 21 | deferred (Workstream 2) |
| Private `InputDecoration(` blocks | 73 | 73 | deferred (Workstream 5) |
| `EmptyState` adoption (screen files) | 8 | 8 | deferred (Workstream 10) |
| `ErrorState` adoption (screen files) | 1 | 1 | deferred (Workstream 10) |
| `InsightCard` adoption (screen files) | 1 | 1 | out of Phase 2 scope (hierarchy work) |

Zero was not chased where it would have been unsafe in one sitting: the
money-screen and typography sweeps touch golden-locked surfaces and hierarchy,
which the audit itself sequences behind the money vectors and per-screen
review. They are queued below, not skipped.

---

## 3. Intentional exceptions

- **Two confirm-dialog titles keep an explicit heavy weight**
  (`goal_detail.dart` "Delete this goal?", `pan.dart` "Drop the plan?").
  These are `AlertDialog` titles, which do not inherit `appBarTheme`, and
  `dialogTheme` sets no `titleTextStyle`. The independent review caught that
  the AppBar strip had also removed their inline `w800` (they matched the
  AppBar-title string exactly), which would have dropped them to Material's
  w400. Restored to their original style, because dialog-title styling is
  genuinely unsettled across the app (some titles are w400 color-pinned, some
  `.w8` heavy) and unifying it belongs to the deferred shared-`ConfirmDialog`
  work, not to this adoption pass. Net result: zero user-visible change.
- **`Radii.sm` (10) snapped up to `control` (12), not preserved.** The eight
  sites were all control-role (tap ripples, one celebrate badge, the theme
  preview swatch, the segmented selected pill). The alias' own doc always said
  it "snaps up on conversion," and on the segmented control the snap tightens
  the pill's nesting inside its 14 track. Classified A (accidental drift on a
  legacy alias), not B/C. Verified visually.
- **Four files kept `flutter/services.dart`** (reports, split_expense,
  recurring, paluwagan): they use `FilteringTextInputFormatter` /
  `TextInputFormatter`, so the import is still load-bearing.
- **`history.dart` AppBar keeps `AppText.title`** rather than dropping to a
  bare title: it is already on the type ladder, not a hand-rolled `TextStyle`,
  so it was left as the cleaner of the two correct forms.

---

## 4. Shared-row assessment

**Recommendation: implement in Phase 3, and scope it to the flat-row family
only. Do not build a four-way god-widget.** This phase produced the assessment
only, no row code, exactly as the brief asked.

Inspecting the five row surfaces, they are **less uniform than they look** and
split into two families:

- **Genuinely flat leading-title/subtitle-trailing rows:** Accounts
  (`_accountRow` -> `_row` at `accounts.dart:842`) and the Home account
  previews (inline loop in `overview.dart`). Accounts **already ships the
  primitive** a `SalapifyRow` would be: `_row` is a keyword-arg row with
  `leading / name / sub / amount / progress / onTap / highlight / rowKey`.
  History transaction rows (`history.dart:427`) are adaptable but carry
  bespoke split-hint, record-line and per-type Semantics logic.
- **Actually cards, not rows:** Goals (`_goalCard`, a full vertical panel with
  a glyph header, an inline money line rather than a trailing amount, a
  full-width progress bar, a pace line, and a focus variant) and Debts
  (`_debtCard`, a bordered Card that opens a sheet). Paluwagan has no people
  rows at all (status cards only), so there is nothing to unify there.

The shared surface across all five is really just `{name, subtitle?, onTap}`;
everything else (leading kind, amount treatment, progress size, highlight,
card-vs-flat, nav target) diverges. A single `SalapifyRow` with an
`AccountRow / TransactionRow / DebtRow / GoalRow` union would collapse two
different layout families and net out as a many-nullable widget, which the
brief explicitly warns against.

**Proposed Phase 3 model** (not built here):
- Promote the existing Accounts `_row` to a shared `SalapifyRow` (the flat
  family only), and delete the hand-inlined Overview preview loop, which even
  re-hand-rolls a foreign-currency `FittedBox` that `_row` already handles.
  Real duplication removed, near-identical anatomy, low risk.
- Adopt `SalapifyRow` on Accounts + Overview first; History as a fast follow
  once it grows a signed/tinted `AmountText` trailing slot.
- Leave `_goalCard` and `_debtCard` out. If they want unification, it is a
  separate `SalapifyCard` abstraction, not this one.

This lands cleanly behind the money vectors alongside the Workstream 1 money
pipe, which is why it belongs in Phase 3, not this adoption pass.

---

## 5. Visual regression results

Rendered the full shot harness (`flutter test test/screens_shot.dart
--update-goldens`, 126 PNGs, dark-first). The only *visible* change in this PR
is the 10->12 radius snap on eight control-role elements; everything else
(haptics, AppBar chrome) is invisible by construction because the theme already
rendered those values.

Reviewed and confirmed unchanged in intent:
- **Appearance (dark):** the segmented System/Light/Dark pill nests correctly
  in its track at the new radius; theme-preview swatches read fine.
- **Activity (dark):** period and filter chips, signed tabular money figures
  (+P28,000, -P1,250) all intact.
- **Categories (dark):** the pushed-screen AppBar title now inherits the
  theme's heavy 22px and renders identically; the over-cap row highlight and
  `warningStrong` copy unchanged.

No golden baseline was force-updated to pass a test. The committed pixel
baseline is non-blocking by house rule; the per-push gate is the deterministic
layout-metric suite (readability, palette contrast, segmented), all green.

**Independent review pass.** A separate engineer review traced the whole diff
for semantic regressions and confirmed everything mechanical (haptics 1:1,
AppBar strips match the theme exactly, `services` imports safe to drop, the
`sm`->`control` snap improves the segmented pill's concentricity). It found the
one dialog-title issue in section 3, which was then fixed and re-verified. No
money-math, data-safety or correctness risk anywhere in the diff.

---

## 6. Accessibility results

No accessibility regression; several small wins from centralization.
- **Radius:** 10->12 is within control-role and does not affect tap targets or
  contrast. `screen_readability_test` (overflow / off-screen / ellipsis /
  raw-date sweep at 1.0x and 1.5x) green; `palette_contrast_test` (all 16
  palettes, WCAG AA) green; `segmented_test` (48dp floor, longest-label stack,
  shape-not-color selection) green.
- **Haptics:** unchanged behavior; now every buzz carries a documented meaning
  and none fires on a rejection (the vocabulary's rule), enforced by the new
  guard.
- **App bars:** titles keep the same size/weight/contrast; the theme owns them,
  so a future accessibility tuning of chrome is one edit, not 41.

---

## 7. Tests run

```
export PATH="$PATH:/opt/flutter/bin"; cd flutter
flutter pub get                                  # baseline resolve
flutter analyze                                  # No issues found (baseline and after each batch)
flutter test test/design_foundation_test.dart    # the 3 new guards + existing token contract, green
flutter test test/segmented_test.dart test/screen_readability_test.dart test/palette_contrast_test.dart  # green
flutter test                                     # 2852 pass; only qa_record_test red pending this batch's QA row
flutter test test/screens_shot.dart --update-goldens   # 126 PNGs rendered, reviewed dark-first
```

Break-then-prove, each restored after the run reported:
- Radii guard: re-added `static const double md = field;` to `Radii` -> red on
  "lib/theme.dart declares a legacy Radii alias (md)".
- Haptics guard: re-added a raw `HapticFeedback` call to afford_card -> red on
  "calls HapticFeedback directly".
- AppBar guard: re-added `backgroundColor: Barako.background` under goals'
  AppBar -> red on "re-sets an AppBar property the theme already owns".

---

## 8. Risks and deferred items

**Risk of this PR: low.** Behavior-preserving, guarded, net-negative lines, no
money math, no schema, no navigation, no hierarchy change. The one visible
delta (2px radius on eight control elements) is documented and verified.

**Deferred workstreams (queued as the next reviewed batches):**
- **W1 Money presentation (`AmountText`).** Route the ~153 raw `formatMoney`
  presentation sites on the money screens through `AmountText`. Golden-locked;
  the audit sequences it behind the money vectors and journey tests, one screen
  per batch. Highest value, highest care.
- **W2 Typography.** Snap the 21 off-ladder sizes and reclassify the 174 raw
  `FontWeight` literals to `TypeWeight`, keeping legitimate hierarchy. Mechanical
  but per-site classification; guarded by the readability sweep.
- **W5 Inputs.** Delete the 73 private `InputDecoration` blocks where a bare
  `TextField` already inherits the theme, preserving every validator, formatter,
  keyboard type and secure-input flag. "Phase 2 deletes them," per the theme
  comment; needs per-file inspection.
- **Dialogs.** 26 `showDialog` sites share no `ConfirmDialog` and style their
  titles inconsistently (w400 color-pinned vs `.w8` heavy). A shared confirm
  dialog and a `dialogTheme.titleTextStyle` would settle it in one place.
- **W6 Kickers, W7 Surfaces, W8 Sheets, W10 States.** Route duplicated
  overlines through `Kicker`/`SectionHeader`; adopt the theme card/sheet
  surfaces where equivalent; adopt `ErrorState` app-wide. All medium-touch,
  each its own batch.

---

## 9. Recommended Phase 3 scope

Per the audit's own phasing, Phase 3 is where materiality begins:
1. Finish W1/W2/W5 as small reviewed batches (they complete "the plumbing").
2. Build the controlled shared primitives the assessment in section 4
   recommends (list-row, summary, confirm dialog) behind the money vectors.
3. Then, and only then, the North Star hierarchy re-rank on Home and Insights
   (decisions-vs-reference weight split), rendered and shown to the founder
   dark-first before merge.

No `fl_chart`, no accounting-model change, no Insights+Reports merge, no new
product features in this track.
