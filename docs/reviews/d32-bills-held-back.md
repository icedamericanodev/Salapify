# D32.1: Safe to Spend holds back the bills a person adds

Founder decision D32 (2026-10-09): "Yes, hold back added bills".

## Scope

A bill added on the Bills screen (the UpcomingItem register) was held back by
nothing. Safe to Spend only ever saw the built-in BillItem register.

## What changed

- `app/lib/core/money/bills_to_reserve.dart` (new) merges the two registers
  into one list for the locked engine. The engine itself is not edited.
- `FinancialState.billsHeldBack` is that list, read by Safe to Spend, the
  health check (dot and sheet) and Pan, so all three answer from one list.
- Which added bills count: unpaid, outgoing, due on or before payday (30 days
  when no payday is set). Overdue and unreadable dates count.
- An added bill is NOT held back again when it is the same payment as an
  unpaid built-in bill, a debt's monthly minimum, or a plan's instalment.
  "The same" is `sameObligation` in `duplicate_obligations.dart`, the
  "Counted twice" notice's own rule: exact amount, a shared word, within
  seven days when both dates can be read.
- The Health check sheet now reads the store's report instead of running its
  own copy of the check.

## What did NOT change

The Safe to Spend engine and its golden vectors. Stored data: nothing new is
saved, `billsHeldBack` is computed on every read. Reminders still read the two
registers apart, since each already has its own reminder.

## Money effect on the example ledger

D32 alone: 24,332 becomes 24,108. The seed's unpaid Spotify on the Bills screen, 239 due
Sunday, padded to 262.90 by the careful scenario, 85 percent of which is 224.

## Validation

- Analyze clean, full suite 2,299 pass after D33.
- Break-then-prove, each guard watched failing before restore: the wiring
  ("the new bill was not held back"), the twin rule, the debt and plan match,
  the seven-day rule, the "Debt" row with no debt, and the health sheet.
- Journey: a bill typed on the Bills screen moves the Home figure and the
  Safe to Spend breakdown, and removing it gives the money back.
- Independent review: ledger-reconciler, 8 findings. 1, 3, 4 and 5 fixed here,
  8 did not hold up.

## Founder answers, D33 (2026-10-10), built

1. Only bills due by payday are held back, from either list. The example's
   8,500 tuition due October 5 now waits for the next cycle.
2. When a bill is on both lists, the date on the Bills screen wins. The
   example's Meralco reads Today, so the health check's "due before payday"
   rises from 20,100 to 22,940.

Example figure after D33: 32,056. Renders and how the figures tie:
docs/reviews/d32/README.md.

## Deferred, routine

3. DONE 2026-10-10. `daysUntil` could not read weekday names ("Sunday"), so such a bill was held
   back by Safe to Spend but left out of the health check's dated total.
   A weekday branch in `reminders.dart` fixes every reader at once, and also
   starts reminders for those bills.
