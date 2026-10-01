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

Shipped so far: P1.1, P1.2, P1.3, P1.4, P1.5, P1.6.

---

## Phase 1: trust fixes and quick wins

| ID | Task | Status | Commit |
|---|---|---|---|
| P1.1 | Wire the Home dead ends | DONE | see below |
| P1.2 | Duplicate status balance bug (F10) | DONE | see below |
| P1.3 | Remove always-on sample Netflix data | DONE | see below |
| P1.4 | Tax sheet mixed income | DONE | see below |
| P1.5 | Freelancer comparison consistency | DONE | see below |
| P1.6 | Small BIR fixes | DONE | see below |
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

### P1.2 notes

Fix-before-launch 4, and founder decision F10.

`countsTowardTotals` is false for `excluded` and `duplicate`, and
`applyToBalances` returns the accounts untouched for exactly those two. So the
moment a status crossed that line, the money the entry once moved was
stranded: the totals stopped counting it and the account still carried it.

NOT new money math. Both halves already existed and are locked to vectors
generated from the prototype, `applyToBalances` and its mirror
`reverseFromBalances`. The fix decides WHEN to call them and never how much,
and takes its direction from whether the entry crossed the counting line
rather than from the status names, so a future third non-counting status needs
no change there.

Nine round-trip tests. Every one does the thing and undoes it, because a
one-way check passes when the reverse is wrong in the same direction as the
apply, which is the easy mistake when writing a mirror by hand. Four cover
shapes that are easy to get wrong: income reverses the other way, a transfer
reverses BOTH ends, duplicate to excluded must move nothing because neither
counts, and an already-excluded entry must not be paid out when touched.

Removing the balance move fails them with the real gap:

    Expected: a numeric value within <0.0001> of <14299.0>
      Actual: <12400.0>

### P1.3 notes

Habits and Subscriptions were read as compile-time constants straight off
`SeedData`, so "Delete the sample data" cleared eleven accounts, a housing loan
and a whole ledger, and left Netflix and a gym streak sitting there. Somebody
who has just wiped a stranger's money off their phone and still sees a
stranger's Netflix bill has every reason to think the wipe did not work, which
is the worst thing a wipe can do.

Gated on `hasSampleData`, the single rule the rest of the app already uses. It
is derived from the `isSample` flag on real stored records, so this screen
invents no second convention, and it is right after a restart because the
restored file carries no sample records.

Neither model gets its own `isSample` flag, deliberately. Neither is persisted
and neither screen can add, edit or tick one, so there is no user data here to
protect: they are illustrations of a feature that is not built. The empty
states say exactly that, rather than "no habits yet", which would imply an add
button that does not exist anywhere in the app.

Ignoring the gate fails the screen test with the defect itself:

    Expected: no matching candidates
      Actual: Found 1 widget with text containing Netflix

### P1.4 notes

Money copy error 1, confirmed in code. `calculateFreelanceTax` was called with
NEITHER `compensationIncome` nor `vatRegistered`, so everybody using the sheet
was treated as a pure freelancer who had never registered for VAT.

**The engine was right the whole time.** It has always handled both. The sheet
never asked, and the two defaults it fell back to are the expensive ones:
`compensationIncome: 0` hands the 250,000 zero-rated allowance to somebody with
a salary who is not entitled to it, and `vatRegistered: false` offers an
election a VAT-registered taxpayer may not make at any income.

Two inputs added: a salary field, and a VAT toggle whose caption says what
ticking it does, because somebody who watches their cheaper option vanish
deserves to be told why on the same screen.

**A hollow test of my own, caught by the deliberate break.** The first version
asserted the words "Mixed income" appeared. Dropping the two parameters from
the engine call PASSED it, because that caption is driven by the widget reading
its own text field: it was right while the tax underneath it was wrong. Rewritten
onto the peso figures, the same break fails:

    Expected: at least one matching candidate
      Actual: Found 0 widgets with text "₱0.00"

The figures, on the sheet's default 1,200,000 gross: no salary gives a 250,000
allowance and 76,000 of tax; a 600,000 salary gives no allowance and 96,000,
which is the 20,000 a year the review measured.

### P1.5 notes

Money copy error 2. The Side by side card contradicted itself three ways, and
P1.4 had just made the first one worse:

1. **"8% of gross above ₱250,000"** is wrong for a mixed income taxpayer, who
   gets no allowance at all. P1.4 made that case reachable, so the label had to
   follow or it would be confidently wrong on the exact screen that had just
   started asking the question.
2. **"Graduated brackets on the full gross"** is wrong for everybody: the
   engine applies the 40% Optional Standard Deduction first, so the brackets
   see 60% of gross plus any salary.
3. **The rows showed `estimatedTaxDue`**, income tax alone, while the verdict
   above them compares `totalTaxDue`, which also carries the 3% percentage tax.
   The card named one winner and showed the figures of a different comparison.

Both rows now show `totalTaxDue`, the figure the verdict actually reads, with
one caption saying so. The detail card's "Tax due for the year" became "Income
tax for the year" and gained a total, because a line calling itself the year's
tax while a percentage tax row sits above it is the same contradiction one card
down.

Restoring the old label and figure fails both halves:

    Expected: at least one matching candidate
      Actual: Found 0 widgets with text "₱122,500.00"
    Expected: no matching candidates
      Actual: Found 1 widget with text containing full gross

### P1.6 notes

Three BIR fixes, and the first one was not what the review said it was.

**The withholding constants were not typos.** The review reported ₱8,541.67
where the table says ₱8,541.80, and the sprint prompt repeated it as three
constants to change. Changing only them would have made the function WRONG.

The old constants were coherent with the old bracket EDGES, which were the
prototype's decimals: `1,875 + (66,666.67 - 33,333.33) x 0.20` is 8,541.67
exactly. The published 8,541.80 is what the table's own INTEGER edges give:
`1,875 + (66,667 - 33,333) x 0.20`. Each pair is internally consistent; mixing
them double counts a sliver of a bracket at the boundary. Both moved together,
and the whole function now matches one published source rather than two
conventions averaged.

Verified against [BIR Annex E of RR 11-2018](https://bir-cdn.bir.gov.ph/local/pdf/Annex%20E%20RR%2011-2018.pdf),
effective 1 January 2023 and still in force, rather than taken on the review's
word. Every corrected figure was then computed BY HAND from the printed
brackets before the tests were run, and all seven of the engine's new outputs
matched those hand figures exactly. That is the cross-check: two independent
routes to the same number.

This is the third place a tax figure is corrected against current law rather
than against the prototype, after the SSS schedule and the 8% election, and it
is flagged for the same reason.

`bir_withholding_table_test.dart` states the table on its own, because the
existing vectors tangle a withholding figure with SSS, PhilHealth and Pag-IBIG,
and when the table moved, seven of them moved with it with nothing saying what
the table itself is. It includes a coherence check asserting each constant is
what the band below ends at, which is the property the mixed convention broke.

**The 32% comment**, which claimed the graduated table tops out at 32 where
the code correctly uses 35. Comment only; no behaviour.

**13th month and de minimis**, which the Academy conflated into one ₱90,000
exemption. They are separate: 13th month and other benefits share the ₱90,000,
and de minimis benefits are exempt in their own right under their own ceilings,
with only the excess joining that bucket. The info sheet already said this
correctly and was left alone.

## Phase 2 to 7

Not started. Tracked in the sprint prompt; this table grows as each phase
begins.

## Packages added

None so far.
