# Reports: the two ratio fixes, what they exposed, and one decision for the founder

Date: 2026-10-06
Branch: claude/review-build, merged into claude/flutter-final
Scope: Reports tab (Position, Performance, Cash flow) and the explainer sheets
behind it.

## Why this exists

The founder asked for two money fixes ("fix the MP2 savings rate and
repayments as income") and, separately, for insights and graphs on Reports.
Building the first surfaced a defect I had introduced one layer up, a
contradiction between a card and its own explainer, an unreachable explainer
topic, a latent double count in the cash flow engine, and one genuine product
fork. This file records all of it so the chat message can stay short.

## What changed

### Money, and only where the founder authorised it

Nothing in this batch changes a money figure beyond the two ratio changes the
founder approved. `totalIncome`, `totalExpenses`, `netSurplus`, the balance
sheet and the cash flow engine are untouched.

`earnedIncome` is now a field on `FinancialPerformance`. It was already
computed and discarded; exposing it changes no arithmetic.

### The defect I introduced, and fixed

Moving both ratios to divide by earned income left the dash gate behind.
`_ratioText` still asked `totalIncome > 0`, and a repayment counts there. So a
period whose only inflow was somebody paying you back had income above zero
and nothing earned: the engine correctly returned 0 for both ratios for want
of a denominator, and the screen printed that 0 as "0.0%".

Somebody who paid 5,000 of loans in such a period was told their debt
servicing was 0.0%. That is exactly the misreading the dash was written to
prevent, slipping through the guard built for it.

A third instance of the same wrong gate sat on the debt row's `valueColor`. It
judged an unmeasured zero against the comfort bands. It happened to land on
`textPrimary`, so it was wrong without ever looking wrong.

Proved by test before fixing: `reports_test.dart`, "a period whose only income
was a repayment dashes, not 0.0%", failed on the live screen with
`a rate of zero over nothing earned is not a measurement`.

### The denominator is now visible

Both ratios divide by earned income while the only income figure on the screen
was "Money in". With a repayment in the period, dividing the visible
`Debt payments` row by the visible "Money in" gave a different answer from the
printed one. The card already showed its numerator for this exact reason.

An `Earned` row now appears, and ONLY when it differs from "Money in", because
a row restating a figure already on screen is the clutter the house rule is
about. Both halves are tested.

### The explainer contradicted the card it opens

The ratios card deliberately removed a 20 percent savings pass mark, and the
comment explaining why claimed that number "appeared nowhere else in lib/". It
was in `info_sheet.dart`, on the sheet that same card's dot opens, still
teaching 20 percent as the target. The debt row removed a bare 35 sourced to
what lenders commonly want; the sheet still said "about a third", sourced the
same way, and not the canonical 30.

So one tap apart, over one ledger, Salapify gave two answers twice. The sheet
now reads `debtShareComfortable` and `debtShareStretched` directly, and the
false comment is corrected in place rather than quietly deleted.

### An explainer nobody could reach

`InfoTopic.performance` was defined and opened by no screen. Three
explanations existed and could not be read. It now hangs off the "You kept"
card, whose hero figure is the topic's own formula. Content nobody can reach
cannot be reviewed and rots, which is how the 20 percent above survived.

### Cash flow called a good month a bad one

Put money into MP2 and overpay a loan, which is what this app teaches, and the
Net change in cash hero turns red at hero size. The sections below explain it;
nobody reads downward past a red headline about their own money.

A line now appears when operating is positive and the total is not, naming
what day to day living actually did. It stays silent when the month really was
overspending, and that half is tested, because an alarm that cries wolf gets
its battery taken out.

### Position

The coach proposed a line under Total assets naming the receivable. I did not
build it: the "Owed to you" row already sits three rows above Total assets in
the same card, visibly summing into it, so the figure is not hidden. What is
nowhere is that Salapify carries a receivable at FULL value and does not
discount it. That is teaching, so it went behind the net worth dot.

## What I found and did NOT change, because it is the founder's call

### 1. A latent double count in computeCashFlow

The three outflow buckets do not use the same membership test:

| bucket | tests |
| --- | --- |
| operatingOutflows | CATEGORY only (not debt, not investment) |
| investingOutflows | category OR SUBcategory (mp2) |
| financingOutflows | category OR SUBcategory (loan) |

An expense whose category names neither debt nor investment, but whose
sub-category names mp2 or a loan, is claimed by operating AND by one of the
other two. `netCashChange` sums all three, so that peso is subtracted twice.

Measured: 50,000 in and 6,000 into MP2 filed under a category called Savings.
Cash really rose 44,000; `netCashChange` reported 38,000. A 10,000 car loan
payment under Bills: 40,000 real, 30,000 reported.

NOT REACHABLE TODAY. All thirteen shipped expense categories were checked and
none collides, the seed ledger does not collide, the app has no way to create
a category, and the two tabs currently agree to the centavo on the seed. The
clause that would fire, `_has(t.subcategory, 'loan')`, exists precisely to
catch a loan filed under another category, so it is dead code and a trap at
once.

Fixing it is a money-meaning change. Instead
`cash_flow_no_double_count_test.dart` makes the trap impossible to spring by
accident: add a colliding category and the build goes red naming it. Proved
able to fail by planting "Bills & Utilities" / "Car Loan Monthly", which it
caught by name.

### 2. THE DECISION. No shipped category can reach the investing bucket

This is the one that matters and it changes what the MP2 fix is worth.

`investingOutflows` claims an expense whose category names "investment" or
whose sub-category names "mp2". Not one of the thirteen shipped expense
categories does either. There is no Savings and Investments category: the list
is food, groceries, transport, bills, housing, health, shopping, debt
servicing, family support, business ops, entertainment, adjustments, other.

So for anybody using the app's own picker, the Investing OUT side of Cash flow
is permanently zero, and so is the `investedOutflows` figure the savings rate
was just changed to credit. The arithmetic is right and nothing can feed it.

There are three paths and they disagree:

1. **Transfer into the MP2 account.** Pag-IBIG MP2 is an
   `AccountKind.investment` account and a contribution is a transfer into it.
   Transfers are excluded from money in and money out, so on this path the
   savings rate was never harmed and there was nothing to fix.
2. **Expense under some category.** Lowers the savings rate, and no category
   routes it to investing, so the new credit never applies.
3. **What the SEED actually does.** `tx_mp2_contribution` is an expense under
   "Debt & Loan Servicing". The demo therefore counts a contribution to
   savings as debt repayment and reports it inside the debt servicing ratio.

Path 3 is wrong on its face and is visible in the demo data today. Correcting
it properly needs a category that routes to investing, which does not exist,
so the taxonomy decision comes first.

The founder's question, in one line: **how should somebody record putting
money into savings or MP2 - as a transfer into an investment account, or as an
expense under a new "Savings and Investments" category?** Either is defensible
and they produce different reports.

### 3. The run rate extrapolates one-off money

"If the rest of the month looks like this" straight-lines everything,
including a one-off repayment and a one-off MP2 contribution. 58,000 over 18
days projects 96,666.67 as though a cousin pays you back every 18 days. This
is the prototype's behaviour, the card says "if", and its explainer already
says to treat it as a direction. Arguably the same defect family as the
repayment fix, one card lower. Not touched.

### 4. The 13th month split, still unresolved

`ph_tax.dart` recommends five shares (35/25/20/10/10) and
`bonus_allocator.dart` recommends three. Removing the Plan card left exactly
one reachable, which ends the on-screen contradiction without deciding which
advice is better. `bonus_allocator.dart` and its tests are deliberately still
in place.

## Graphs

A separate review covered the founder's graph question. Its ranked answer,
verified where it touched this batch:

1. The strongest chart in the app is NOT on Reports. `DailyProjection` already
   returns forty five days of `balanceAfter` on every Home build and the
   runway row throws the curve away to print two dates. Drawing it needs no
   engine change, no money decision and no founder gate.
2. Six month money in versus money out on Performance is the only chart that
   earns its place on Reports. It needs a new engine function with vectors,
   plus one founder answer: calendar month or payday cycle.
3. The "Where it went" rails already are the pie chart, and are the better
   version. No pie.
4. Refuse a line through the run rate card: it would draw an assumption with
   the authority of measured data.
5. Net worth over time needs stored balance history, which is STOP condition 2
   and founder-gated before any work starts.

Recommendation on implementation: hand-roll with `CustomPainter` rather than
add a charting package. fl_chart 1.2.0 is compatible with the pinned SDK, but
it brings a second theming vocabulary that `palette_contrast_test.dart` cannot
see into, for what is two or three simple shapes.

None of this was built. It is the next decision, not this batch.

## Validation

- `flutter analyze`: no issues.
- Full suite: 2,119 pass, up from 2,111 by exactly the eight added.
- Shot harness: all shots render, including two new Performance renders built
  on a fixture that can actually reach the two new lines, because the seed
  fixture reaches neither and the existing renders therefore showed neither.
- Every new guard proved able to fail before being trusted, with the failure
  line recorded in its commit message.

## Deviations and deferred

- The Position receivables line was proposed and deliberately not built, with
  the reason above. The teaching went behind the dot instead.
- The shot fixture uses a category pair no user can produce. It proves the
  code path, not a reachable screen, and says so in the file.
- Four pre-existing em dashes remain in `docs/revamp/07-decisions.md` lines
  589 to 614, untouched and noted previously.

## Nothing merged to main. PR 473 remains open and untouched, per standing
founder instruction.
