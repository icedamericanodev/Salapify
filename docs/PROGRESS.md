# Build sprint progress

Branch `claude/review-build`, cut from `claude/flutter-final` at `e22979b`.

Driven by `docs/reviews/2026-10-expert-review.md` (reviewed commit e527a16)
and the founder's sprint prompt.

## Baseline, before any sprint work

| Measure | At `e22979b` |
|---|---|
| `flutter analyze` | No issues found |
| `flutter test` | 1,385 pass, 0 fail |
| Test files | 112 |
| Sheets | counted in P4.3 |

The review graded commit e527a16. Three things changed between that commit and
this branch point, so the review is slightly out of date where it says:

- **"Fresh install opens on sample data"** is still true, but the sample dates
  no longer rot: the ledger is built from offsets and dates itself from today
  (`e22979b`). The onboarding half of that finding is untouched and is P3.2.
- The suite is 1,385 rather than the 105 test files the review counted.

## Phase summaries

### Phase 1, in progress

Shipped so far: P1.1.

---

## Phase 1: trust fixes and quick wins

| ID | Task | Status | Commit |
|---|---|---|---|
| P1.1 | Wire the Home dead ends | DONE | see below |
| P1.2 | Duplicate status balance bug (F10) | todo | |
| P1.3 | Remove always-on sample Netflix data | todo | |
| P1.4 | Tax sheet mixed income | todo | |
| P1.5 | Freelancer comparison consistency | todo | |
| P1.6 | Small BIR fixes | todo | |
| P1.7 | One debt-to-income rule (F8), one health check (F9) | todo | |

### P1.1 notes

The review called this "about ten minutes of work". It was, and the ten
minutes bought a guarantee rather than four edits.

Four controls called a helper named `_soon`, which showed "The Plan tab is not
migrated yet." Three now open their real destination: Budget Pulse opens Plan,
Latest opens Activity, and Coming Up's add opens the Bills sheet built
yesterday.

The fourth, the Log fallback, was never reachable in the app: the shell always
passes `onOpenLog`, and the shell owns the store write and the tab switch that
follow it, so Home duplicating that would fork a money path. Instead
`onOpenLog`, `onOpenDebt` and `onOpenTab` became REQUIRED, which turns a
forgotten wire into a compile error rather than a runtime apology.

The analyzer then reported `_soon` itself as unreferenced. That is the machine
stating there is no dead end left on Home, which is stronger than any test, so
the helper is deleted.

`test/widgets/home_links_test.dart` covers the half a compiler cannot: that
each link opens the RIGHT place. The Latest test asserts Activity opened AND
Accounts did not, because an off-by-one in a tab index lands somewhere
plausible.

## Phase 2 to 7

Not started. Tracked in the sprint prompt; this table grows as each phase
begins.

## Packages added

None so far.
