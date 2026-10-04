# P2.3, protected accounts: the design

2026-10-04. Written before any code, per the brainstorming gate. Every claim
below was read out of `app/lib` or measured by running the engine. Two
specialist passes were commissioned and had not reported when this was
written; where their answer could change a recommendation, it says so.

## The defect, in one paragraph

Whether an account counts as spendable cash is decided purely by its KIND.
`liquidKinds` in `app/lib/core/money/accounts.dart` is `{cash, gcash, maya,
bank, debit}`, and `Account.isLiquid` is nothing more than
`liquidKinds.contains(kind)`. A huge share of this audience keeps savings
inside a wallet or a digital bank: GSave inside GCash, Maya Savings, SeaBank,
Tonik, a second BPI account nobody touches. Added once as an e-wallet or a
bank, an emergency fund is silently counted as this fortnight's pocket money,
and Safe to Spend tells the person they may spend it.

## It is already in the sample data

Not hypothetical. Two of the eleven seeded accounts are literally named
Savings and are counted today as spendable:

| Account | Kind | Balance |
|---|---|---|
| Maya Savings | `maya` | 15,300.00 |
| MariBank Digital Savings | `bank` | 24,250.00 |

That is 39,550.00 of the 110,720.50 the app calls spendable, 36 percent of it,
sitting in accounts whose own names say otherwise.

## What it would do to the headline, measured

Run with those two excluded, conservative scenario, clock pinned to the
vectors' own instant. These figures came out of `computeSafeToSpend`, not out
of my arithmetic:

| Figure | Today | If both were protected |
|---|---|---|
| Liquid cash | 110,721 | 71,171 |
| Safe to spend until payday | **38,414** | **9,838** |
| Safe to spend today | 9,604 | 2,460 |
| Must remain reserved | 65,528 | 59,596 |

A 74 percent drop in the headline. That is the correct number becoming
visible, not a regression, and it is also the single strongest argument that
this change cannot be made silently on somebody's real ledger.

## The thing the spec did not mention

`isLiquid` is doing TWO unrelated jobs, and P2.3 is only about one of them.

**Job one, what counts as money you can spend.** Three call sites:
`safe_to_spend.dart:32`, `financial_state.dart:2200` (both feed
`totalLiquidCash`), and `health_check.dart:216`.

**Job two, which accounts you can pay FROM.** Five call sites:
`log_sheet.dart:64`, `payment_sheet.dart:65` and `:87`,
`installment_sheet.dart:70` and `:161`, `scan_receipt_sheet.dart:481`, and the
account filter at `activity_screen.dart:265`.

These must now separate. A protected emergency fund should stop inflating
Safe to Spend, and must still be payable from, because a person genuinely can
spend their emergency fund in an emergency and an app that hides the account
is lying about their money.

So the change is NOT "protected accounts are not liquid". It is: a new
question, "does this count as spendable", asked only by job one. `isLiquid`
keeps its meaning for job two.

---

## The shape

One field on `Account`:

```dart
enum AccountPurpose { spendable, protected }
```

Additive and nullable on the wire, defaulting on read. `accountKeys` in
`json_codec.dart` is a flat key set, so a new `purpose` key means an older
build opens a newer file (it lands in the unknown-key sidecar and is written
back untouched) and a newer build opens an older file (absent reads as the
default). NO MIGRATION, and nothing in P2.2 is needed first.

Nothing stored changes retroactively, and this is worth stating plainly
because the 74 percent above looks alarming. `safeToSpendAnalysis` is a
getter that calls `computeSafeToSpend` on every read; the result is never
written to the file, and `snapshot.dart` and `json_codec.dart` contain no
reference to it. Marking an account protected changes today's figure and
rewrites no history.

---

## The three decisions that are the founder's

### D1. What is the default for accounts that already exist?

**Recommended: everything stays spendable, and nothing moves until the person
says so.**

The alternative is inferring protection from the name or the kind, which fixes
the defect on day one without being asked. I am against it, and the measured
figure above is why: inferring wrongly on a real ledger takes somebody's
headline from 38,414 to 9,838 overnight, with no action of theirs to explain
it, and the first thing they will conclude is that the app lost their money.
A silent fix that looks exactly like a bug is not a fix.

The cost of recommending this is real and should be said: the defect persists
for every existing user until they go and set it. That is what D3 exists to
answer.

For the SAMPLE data the answer is different and I would set the two Savings
accounts protected in the seed. The sample ledger is a teaching fixture, not
somebody's money, and a demo that shows the feature working is worth more than
a demo that reproduces the bug.

### D2. Does a protected account still appear in the "pay from" pickers?

**Recommended: yes, unchanged.** This follows from the two-jobs split above.
Pending the financial-coach pass, which was asked to confirm or correct it.

### D3. How does anybody find out this exists?

The defect is silent by nature, and a control nobody opens fixes nothing. The
honest options, with no recommendation yet because this is the one I most want
the specialist pass on:

1. Nothing. The field exists for people who look. Cheapest, and leaves the
   defect in place for everybody else.
2. A one-time prompt when an account's NAME suggests savings (contains
   "savings", "ipon", "emergency", "GSave") and it is still marked spendable.
   Targeted, but it is a guess about somebody's money presented as a question.
3. A line in the Safe to Spend explainer sheet, which is where somebody
   already goes when the headline looks wrong.

Option 3 is the one I lean toward: it costs nothing, it cannot misfire, and it
reaches the person at the exact moment they are questioning the figure.

---

## What does NOT change

- No stored figure, and no money math. The engine is untouched; it asks a
  different question of the account list and computes identically.
- Every golden vector holds, because the seeded accounts keep their current
  purpose unless D1's sample-data recommendation is accepted, in which case
  the Safe to Spend vectors move DELIBERATELY and are regenerated with the
  reason recorded.
- Net worth, assets, liabilities and the Accounts screen totals. A protected
  account is still money the person has.
- `isLiquid` keeps its name and meaning for the pay-from pickers.

## How it is tested

1. A unit test that a protected account leaves `totalLiquidCash` and stays in
   the pay-from list, which is the whole two-jobs split in one assertion.
2. A codec round trip: purpose survives a save and a reload, an absent key
   reads as spendable, and an unknown value is refused rather than guessed.
3. A journey: mark an account protected, watch the Home headline fall by the
   amount that account holds minus its share of the buffer, then pay a debt
   from it to prove it is still reachable.
4. Break-then-prove on each, per the usual rule.

## The open question I cannot answer alone

If the sample data changes (D1's second half), the Safe to Spend golden
vectors move. Those vectors came out of the prototype's own TypeScript and the
rule is that if a figure disagrees with the prototype, the port is wrong. Here
the INPUT would be deliberately different, which is a legitimate reason for a
vector to change, but it is the first time in this migration that any of them
has. It needs saying out loud rather than quietly regenerating them.
