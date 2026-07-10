# Component Review

Sprint 0 engineering audit, 2026-07-10. Covers component organization,
reusability, duplication, naming, and the developer experience of working in
this codebase (Phase 8).

## Inventory

mobile/components/ holds 21 components plus a motion/ subfolder:

- Design system primitives: Card, SectionHeader, EmptyState, Bar,
  PeriodSelector, BankBadge, Placeholder (unused scaffold).
- Motion primitives: motion/PressableScale, motion/AnimatedNumber,
  motion/Celebration.
- Feature components: LogSheet (735 lines, the global add entry sheet),
  WeekRecap, WeekChain, RecapShare, TreatCard, Onboarding.
- Mascot family: Mascot, MascotClay, MascotFallback, MascotSkia (dead code).
- Infrastructure: ErrorBoundary, LockGate.

Screens live in mobile/app/ (6 tabs plus 27 stack screens), context providers
in mobile/context/, pure logic in mobile/lib/ (35 modules), hooks in
mobile/hooks/ (2).

## What is good

- The pure logic extraction is exemplary: screens contain layout and event
  wiring, money math lives in lib/ where 313 tests cover it. This is the
  single strongest developer experience property in the repo.
- The primitives that exist (Card, SectionHeader, EmptyState, Bar,
  PeriodSelector) are genuinely reused across screens and carry the theme
  discipline; EmptyState gives every list a consistent, intentional empty
  experience.
- PeriodSelector is the best behaved interactive component in the app:
  correct accessibility state, hit slop, disabled handling. It should be the
  template for the Chip extraction below.
- The motion primitives respect the reduced motion context and centralize
  animation feel.
- Naming is consistent and boring in the good way: files are what they say
  (TreatCard renders a treat card), lib modules match their test files, and
  comment density is high and explains failure modes rather than syntax.
- history.js demonstrates the correct scalable list pattern (virtualized
  FlatList, memoized rows) ready to copy elsewhere.

## Findings

### CMP-1: The chip pattern is copy pasted across at least six files with no shared component

Severity: High (it multiplies three audits' findings) | Effort: M
Where: selection chips are re-implemented in LogSheet.js, debts.js, index.js,
receivables.js, payables.js, and preferences.js with the same style recipe
(paddingVertical 8, 13 point text) and the same three defects everywhere:
about 32 point tap targets (UX-7), no accessibilityRole or selected state
(A11Y-2), and inconsistent minor styling.
Business impact: the top accessibility and usability defects in the app exist
in six places instead of one, and every future chip repeats them.
Technical impact: one shared Chip component (label, selected, onPress,
optional icon) fixes tap target, screen reader state, and visual consistency
in a single place, and turns three audit findings into one fix.
User impact: chips are the highest frequency tap surface after the FAB.
Recommendation: extract components/ui/Chip.js modeled on PeriodSelector's
accessibility handling; migrate call sites screen by screen in normal
batches.

### CMP-2: receivables.js and payables.js are near twin 750 line screens

Severity: Medium | Effort: M
Where: app/receivables.js (769 lines) and app/payables.js (748 lines); a
plain diff is only 549 lines, so most of both files is shared structure
(person grouping, quick dates, the payment modal, row cards, styles).
Business impact: every utang bug gets fixed once and shipped half fixed.
Recommendation: extract the shared pieces into components taking a direction
prop, keep the real behavioral differences (remind and split exist only on
receivables) explicit. Do not force a full merge. Same as Technical_Debt.md
TD-7.

### CMP-3: LogSheet is a 735 line monolith carrying the app's most important flow

Severity: Medium | Effort: M (bundle with the UX-1 reorder)
Where: components/LogSheet.js contains the sheet chrome, form state, currency
handling, FX prefill, OCR prefill, receipt attach, validation, the toast, and
the styles in one file.
Business impact: the file everyone must touch for the most valuable flow is
the one hardest to touch safely, and it has no tests.
Technical impact: internal sections (CurrencyRow, CategoryChips, ReceiptRow)
are separable with no behavior change.
User impact: indirect, via slowed iteration on the heartbeat flow.
Recommendation: when UX-1 (reordering the sheet) is implemented, split the
sections into subcomponents in the same folder and add the first component
test around validation behavior. Do not refactor it as a standalone project;
ride along with the UX work.

### CMP-4: The salary modal duplicates LogSheet's income mode

Severity: Low | Effort: S
Where: app/(tabs)/index.js lines 676 to 729 implement a bespoke income form
(chips, validation, no date row, no celebration) parallel to LogSheet's
income mode. Same as UX-10.
Recommendation: open LogSheet preset to income from the sweldo plan and
delete the bespoke modal.

### CMP-5: Dead and stray components

Severity: Low | Effort: S
Where: MascotSkia.js is complete but imported nowhere (MascotClay plus
MascotFallback are the live pair); Placeholder.js appears unused by any live
route.
Business impact: dead code misleads new contributors and pads review surface.
Recommendation: delete both (git history preserves them), or move MascotSkia
behind an explicit experiment flag if it is planned to return.

### CMP-6: Widget components duplicate app math instead of importing it

Severity: Medium | Effort: S
Where: widgets/widget-task-handler.js reimplements net worth and monthly
aggregation logic that exists in lib/analytics.js. Same finding as
Technical_Debt.md TD-6; recorded here because it is fundamentally a
reusability failure: the pure lib was built to be imported everywhere,
including headless contexts, and the widget bypassed it.
Recommendation: import lib/analytics.js helpers in the task handler and add a
parity test.

### CMP-7: Small shared utilities are re-declared per screen

Severity: Low | Effort: S, opportunistic
Where: MONTHS name arrays, date formatting snippets, and find or create
person logic appear in multiple screens (split.js, receivables.js, person.js
among them); lib/format.js is the natural home and already exports most date
helpers.
Recommendation: move stragglers into lib/format.js (or lib/people.js for the
person resolution) the next time each screen is touched; not worth a
dedicated churn PR given the OTA publish cost per push.

### CMP-8: No component tests at all

Severity: Medium | Effort: M to seed, ongoing after
Where: mobile/__tests__/ covers lib/ only. Zero tests mount a component, so
regressions in validation wiring, chip selection, or the toast and undo flows
are invisible to the suite that CI (after TD-1) will run.
Business impact: the money math is protected but the UI that feeds it numbers
is not; a broken amount parser wiring in LogSheet would pass every existing
test.
Recommendation: seed component testing with the two highest value targets:
LogSheet validation and submit wiring, and the restore confirm flow in
data.js. React Native Testing Library runs under the existing jest-expo
preset with no native build required.

## Developer experience summary (Phase 8)

- Folder organization: conventional and predictable; see
  Folder_Structure_Review.md for the repo level issues.
- Naming: consistent, descriptive, and stable across lib, tests, and screens.
- Reusability: excellent at the logic layer, mixed at the UI layer (CMP-1,
  CMP-2, CMP-4).
- Code duplication: concentrated and known (the twins, the chips, the widget
  math); nothing systemic.
- Documentation: no README (TD-12); CLAUDE.md documents process; inline
  comments are exceptional and explain invariants and failure modes, which
  partially substitutes for architecture docs.
- Testing: strong pure logic coverage (313 tests), zero UI coverage (CMP-8),
  and none of it ran in CI until this audit flagged it (TD-1).
- Maintainability: high for a codebase this age, held up by the sanitize
  boundary, the storage seam, and comment quality; the risks are the god
  module growth in AppData.js (TD-11) and the untested UI layer.
- Onboarding a new developer: realistic estimate is one day to productive on
  screens, two to three days to trusted on the data layer, provided the
  README from TD-12 gets written; today the data layer knowledge lives in
  comments and in this docs/ set.
