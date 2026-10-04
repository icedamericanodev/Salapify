# Sweldo Runway: the design

2026-10-04. Written before any code, per the brainstorming gate. Every claim
below was checked against `app/lib` or the archive, and two of the ideation
pass's claims were corrected on the way.

## The question it answers

Every other figure in Salapify is an AMOUNT. This one is a DATE.

> Tightest day: Friday 12 Oct, short ₱1,840.

That is the first thing in this app a person can act on today: move the Meralco
bill to the 17th, or bring ₱2,000 back from the account you set aside, because
on the 12th you run out.

## Why it is hard to copy

The window is TWO PAYDAYS, not thirty days and not a calendar month. A kinsenas
and katapusan earner asks "does the sweldo about to land cover what is due
before the one after it". A global app either projects from a bank feed, which
needs a server and a regulated aggregator and would break the "nothing leaves
your phone" claim the privacy sheet and the store listing both rest on, or it
does not project at all.

## What exists already, verified

- **No dated projection anywhere in `app/`.** `computeUpcomingTotals` sums
  unpaid items into two numbers and a count. The Safe to Spend runway is a
  burn-rate division, not a calendar. Confirmed by reading
  `core/money/plan.dart` and `core/money/safe_to_spend.dart`.
- **Salapify 2 built this and it was never ported.** `timeline.dart`,
  `cashflow_calendar.dart` and `phcalendar.dart` are all in
  `archive/salapify-2-flutter/lib/money/`. The last is 95 lines, computes
  Easter rather than tabling it, and encodes the rule that a due date landing
  on a weekend or holiday moves to the next banking day.
- **The v3 mockup is already drawn** and is roadmap step 6, unbuilt.

## The constraint that shapes the first increment

**Due dates are free text, not dates.** `BillItem.dueDate` and
`UpcomingItem.dueDate` are `String`, holding things like "Today", "Sunday" or
"Sep 18". Verified at `models.dart:904` and `:1008`.

`daysUntil` in `core/money/reminders.dart:159` already parses four shapes: ISO
(`2026-09-21`, and single-digit months), `today`, `tomorrow`, and a day of the
month however somebody wrote it (`15`, `15th`, `every 10th`, `10th of the
month`). Anything else returns null.

Turning those into real dates with a recurrence rule is a schema change and a
founder gate. **The first increment does not need it.** It projects the items
whose dates already parse, and says plainly that it is not counting the rest.
That is not a workaround, it is the correct behaviour: an app that silently
drops an undated bill from a cash projection is worse than one that says it
left it out.

---

## Increment 1, the scope I am building now

**A pure engine and nothing else.** No screen, no stored change, no migration.

```dart
DailyProjection projectDailyCash({
  required List<Account> accounts,
  required List<BillItem> bills,
  required List<UpcomingItem> upcoming,
  required List<InstallmentPlan> installments,
  required PaydayCycle payday,
  required DateTime now,
  int horizonDays,
})
```

Returning, for each day: what comes in, what goes out, the balance after, and
the named events that moved it. Plus three summary facts: the **lowest day**,
the **first day the balance goes negative** if there is one, and the total
value of everything it **could not date**.

Rules, each of which is a decision rather than an accident:

1. **It starts from SPENDABLE cash**, not total. Money set aside is not
   available to cover Friday's bill, which is the whole point of P2.3. This
   makes the runway consistent with Safe to Spend rather than a second opinion
   about the same money.
2. **Only unpaid items**, and only ones whose date parses.
3. **Debt minimums ride on their own due dates** where a debt has one, falling
   back to not-dated otherwise. P2.4 just made these real figures.
4. **A due date on a weekend or a Philippine holiday moves to the next banking
   day**, ported deliberately from the archive, because that is when the money
   actually leaves.
5. **It does not invent income.** Only payday, from the stored rule, and
   upcoming items already marked as income.
6. **Nothing it cannot date is silently dropped.** The total is returned so a
   screen must choose to show or hide it.

## What this increment does NOT do

- No screen. The figures go to you in chat first.
- No "what if I move this bill" simulation.
- No calendar. That is increment 3 and it is the mockup already drawn.
- No schema change, no new stored field, no migration.
- `computeSafeToSpend` is untouched. This is a different question over a
  different window, and the two must never be merged. A journey test will
  assert that every bill Home names appears in the timeline on the same date
  for the same peso, which is the only way two engines over one ledger stay
  honest.

## How it is tested

1. Golden-style vectors over the seed, with the clock pinned.
2. One test per rule above, including the one that counts nothing undated.
3. The banking-day shift, including Easter-derived holidays, against the
   archive's own cases.
4. An invariant: the sum of every day's in and out, applied to the opening
   balance, equals the closing balance. A projection that does not foot is not
   a projection.
5. Break-then-prove on each.

## The question for you, when the engine is done

Where the sentence goes, and whether it replaces anything. That is a hierarchy
decision on the one screen that matters, so it is yours, and I will show you
the real figures from your own sample ledger before asking.
