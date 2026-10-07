# Take back a payment

Branch `claude/review-build`, PRs #478 and #479, into `claude/flutter-final`.
Written 2026-10-02.

## Scope

Recovering from a recorded payment, and everything that had to be true first.
Four pieces, delivered as two merges:

1. Two live data-loss paths closed (#478)
2. Debt figures and account balances moved to whole centavos
3. A stored payment register (#479)
4. Take-back itself, reading that register

It began as "build delete a payment" and turned into something larger, because
scoping it found defects that made the feature impossible to build honestly.

## What was live and losing data

Both were reachable in two or three taps from the Debt screen with no
confirmation on any of them, and neither needed new code to reach.

### ₱4,650, permanent

"Mark settled" then "Not settled after all":

```
start        : paid 7,350.00 of 12,000.00
Mark settled : paid 12,000.00
Not settled  : paid 12,000.00, and 7,350.00 is gone
```

A debt keeps no payment history and the app had no edit or delete for one, so
money nobody paid was recorded as paid with no route back short of wiping the
phone. "Not settled after all" is precisely the button somebody taps believing
it IS the way back.

The old behaviour was not careless, which is why it survived review: its
comment defended leaving the figure alone, and for a debt settled by REAL
PAYMENTS that is right. One function was serving two cases that need opposite
answers. `Debt.paidBeforeSettle` separates them, and null is a meaningful
value rather than a missing one.

### ₱1,500, unaccountable

Reports, Check, "possible double entries", mark a debt payment as a duplicate:
the account gets its money back, the debt still claims it was paid.
`setTransactionStatus` reverses the account and cannot touch the debt, because
a `Transaction` carries no `debtId`.

### "₱0.00 remaining" and "not settled", together

```
debt total 78,510.57, paid 70,662.84 then 7,847.73
accumulated to 78,510.56999999999, so paid >= total is FALSE
```

Not a rounding policy problem, so no rounding policy could fix it.

## Why the feature could not be built as asked

A payment's principal and interest split is computed and thrown away by both
instalment engines. Re-deriving it is wrong in a way that every conservation
check passes:

```
prepay 6,000 against 5,600 principal and 991.20 interest
true split : 5,600 / 400
re-derived : 6,000 / 0
balance, account, net worth : all correct
principal  : overstated by 400, permanently
```

A scheduled instalment loses more. `paidInstallments` is a counter rather than
a set of events and the collected amount is capped at the balance, so a stub
left by a prepayment cannot afterwards be told from a full instalment that
landed on zero. Re-deriving one credited 1,647.80 against a ledger row holding
591.20.

So the register stores what was applied, and reversal reads a fact.

## The design

**LIFO only.** `paidAmount` is one running figure, so a row's "before" is only
the right answer when nothing landed after it. On a plan it is sharper: a
prepayment shortens the plan, so every instalment after it collected a
different amount. Both kinds interleave in one ordered list and only its last
entry can be removed.

**Absent, not disabled**, when there is nothing to take back. That is every
debt and plan from a restored backup, permanently, and every payment made
before the register existed. A dead control on a money screen reads as a
broken app.

**Offered on settled debts and paid-off plans too.** A payment that closed
something by mistake is exactly the one somebody needs back.

**Nothing is back-filled.** Two debts to the same person are indistinguishable
on every field the ledger stores, so matching on person and amount would
un-pay the wrong one.

## Defects introduced and caught during the work

Recorded because the pattern is the useful part.

- **`accountToJson` wrote the Money object itself**, which stopped the app
  saving at all. The journeys caught it; `stored_shape_test`, whose whole job
  is the file format, did not, because it only covered transactions. The gap
  is the finding, not the typo; that file now covers accounts, debts, plans
  and the register.
- **A cleared field was resurrected from the unknown-key sidecar.**
  `debtKeys` tells the decoder which keys this build models, and the merge is
  `{...kept, ...own}`. A cleared field has no own value to win with, so
  `paidBeforeSettle` came back after an un-settle. The exact loss the field
  exists to prevent, by the back door.
- **Two backslashes leaked from a patch script into Dart strings**, so the
  credit card drew the literal text `-$balance`. Caught by the test written
  because a card debt once rendered identically to savings.
- **A raw stored date on screen**, `2026-09-18` rather than "today". Found by
  looking at the render, not by any test.

## Three compiler blind spots, in order of nastiness

1. `expect()` takes `dynamic`, so comparing a centavo value to a plain number
   compiles cleanly and fails only at run time. Roughly 110 of these.
2. `(a.balance as double)` type checks, so it was invisible to the analyzer
   AND to both automated fixers, surfacing only as a runtime crash.
3. A compiler-driven fixer that starts producing plausible wrong edits. Two of
   its 72 were wrong and the next analyze rejected both, which is the argument
   for letting a compiler drive rather than the eye.

## A test that failed to fail

Breaking `applyToBalances` back to decimal arithmetic left all three balance
round-trip tests green. Re-quantising happens at every hop, so one trip through
a double leaves no residue; the defect needed the stored FIELD to be a double.
That is a property of the type, so no line can be broken to reproduce it.

Rather than shrug, the file gained the case that IS falsifiable, pinning what
the other three rest on. Recorded here because the working rules call this the
most informative result the procedure can give, and because the temptation is
to break something else until something goes red.

## Validation

- `flutter analyze`: no issues, on the 3.47.4 CI pin
- `flutter test`: 1,546 pass, 0 fail
- Stored format unchanged, asserted in both directions
- A cold-restart test, because a field that encodes and does not decode loses
  the feature on the next launch with the figures already moved
- 51 tolerances removed: every `closeTo` on a balance is now exact
- Visual: `app/test/shots/out/debt_settle_confirm.png` and
  `debt_take_back.png`, rendered and reviewed

Every guard was proven able to fail, with the failure line in its commit.

## Founder decision outstanding

**Should the ledger row be kept and marked rather than removed?**

Take-back currently removes the entry. Keeping it and marking it "taken back"
would read better in a ledger, and no existing status means that: `excluded`
means the app is right that it happened and wrong that it is yours, and
`corrected` COUNTS toward every total. Making it not count would change what
every figure on Reports means.

For somebody who keeps books the kept-and-marked version is probably right.
It needs a design first, not a patch.

## Deferred

- `FinancialPosition`'s own fields and `varianceOf` are still doubles, with
  the centavo figure unwrapped at the call site. Summing happens in centavos
  first, so the residue is gone; only the finished total crosses over.
- 15 names remain on the migration guard list.
- Two engines ignore entry status (`financial_truth.dart`'s drift alert and
  `safe_to_spend.dart`'s burn rate), so they would keep counting a reversed
  payment if the row were kept rather than removed. A prerequisite for the
  kept-and-marked design, not for the current one.
- Adding a debt is still irreversible: there is no delete for one.
