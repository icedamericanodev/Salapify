# Everything waiting on you, on one page

2026-10-04. Four specialist passes ran today and every claim below was checked
by running the real code, not by trusting the report. Three of those checks
overturned something I had already told you.

There are **two decisions I genuinely need from you** and **three things I am
doing unless you say otherwise**. They are in that order.

---

# DECISION 1. The sample payday cycle is frozen, and it is wrong today

**This is the one worth answering first.** One answer unblocks three separate
pieces of work.

## What is actually stored

`SeedData.payday` in `app/lib/data/seed_data.dart:965`:

```dart
cycleType: '15_30',          // it SAYS 15th and 30th
lastPayday: 'Sep 1',
nextPayday: 'Sep 15',
daysToPayday: 4,
expectedIncome: Money.pesos(32500),
// paydayDays: NOT SET
```

The cycle type says "15th and 30th". The rule that would let the app work that
out, `paydayDays`, is empty. `paydayDays` is only ever written when somebody
sets their payday inside the app (`financial_state.dart:515`), and the sample
ledger never did.

## What that does, measured

**It contradicts itself right now.** It claims 4 days to a payday on 15
September, counting from an anchor of 18 September. That payday was three days
ago. The card cannot recompute, so it says this on every date forever.

**A new user sees a wrong date.** Anybody who taps "Look around with example
data" outside mid-September reads "4 days to payday" and "Sep 1 to Sep 15".
Since 2026-10-03 that path is offered to everybody on first launch, so it is a
first impression for a public app.

**The new runway sees one sweldo in six weeks instead of three.** With no rule
the projection places exactly one payday, so the demo shows Salapify at its
most pessimistic. That is the correct answer to a ledger that never said when
payday is. It is also the state every brand new user is in before they answer.

## Your options

**A. Give the sample ledger the rule it already claims to have**
(`paydayDays: [15, 30]`). The cycle recomputes itself on any date. The runway
fills in. The first impression stops being wrong.

*The cost, and it is why this is yours and not mine:* Safe to Spend is derived
from the payday cycle, so the demo's headline money figure moves, and about a
dozen test files hold pinned figures that move with it. No real person's money
changes. Only the example data does.

**B. Leave it frozen, and ask for the payday rule during first run instead.**
The demo stays as it is and the app asks a question before showing a figure it
cannot compute. Honest, and it puts a question in front of somebody who has
been in the app for ten seconds.

**C. Both.** Fix the sample ledger AND ask real users early.

## My recommendation: A, now, and C eventually

The frozen cycle is not neutral. It is already stating a wrong date to every
new user on most days of the year, so "leave it alone" is not the safe option,
it is the option that keeps a known defect. The figures that move are demo
figures. And it is the single cheapest unblock on the board: it frees the
"bills before payday" work, the runway card's new-install state, and the
empty-budgets first impression, all from one answer.

I would do B as its own piece of work later, once there is a reason to touch
the first-run flow again.

---

# DECISION 2. Salapify can count one sweldo twice, and that is the dangerous direction

## What was measured

One salary of 32,500, held both in the payday rule and as an income item in
Upcoming, produces this:

```
2026-09-15   IN 65,000.00   Sweldo Payday = 32,500 | Payday = 32,500
2026-09-30   IN 32,500.00   Payday = 32,500
closing 97,500.00, for somebody who earns 32,500 on the 15th
```

The sample ledger escapes it today only by accident: its payday item sits in
the past, and the payday rule is the frozen one from Decision 1. **Answer
Decision 1 with option A and this starts happening in the demo**, which is
also what teaches people to record a sweldo as an Upcoming item in the first
place.

## Why it is not the same as counting a bill twice

For money going OUT, counting the same thing twice is annoying but safe: you
are told you are tighter than you really are. Nobody bounces a payment because
Salapify was too careful.

For money coming IN it is the opposite. Counting a salary twice tells somebody
they have cash that is not coming. That is the exact failure this whole
feature exists to prevent.

## Your options

**A. Count income once.** When the payday rule and a recorded income item
describe the same money in the same month, only one is counted, and the card
says so in a line: "Your sweldo is in Upcoming and in your payday rule.
Counted once."

*The risk:* somebody who genuinely has a second income of the same amount in
the same month gets it quietly dropped. The line on the card is what stops
that being silent.

**B. Count both and warn.** Nothing is dropped, and a notice says the two look
like the same money.

*The risk:* the warning does not stop the overspend. The number on the screen
is still too big, and the person who ignores one line of small print is
exactly the person this matters most for.

## My recommendation: A

This is the one place I would suppress rather than just disclose, and the
reason is the asymmetry above. A warning is enough when the error makes you
cautious. It is not enough when the error hands you money that is not coming.

---

# THINGS I AM DOING UNLESS YOU SAY OTHERWISE

## 1. Counting a repeated BILL twice, and saying so

Your sample ledger describes the same obligation twice in three separate
places:

| What | Where it is twice | What it costs |
|---|---|---|
| Home Credit phone plan | a Debt and an Upcoming item, same day | 4,900 leaves where 2,450 does |
| Meralco electricity | a Bill, an Upcoming item, AND a confirmed transaction | one bill counted three times |
| BPI gadget loan | a liability Account and a Debt, same balance, same date | 10,000 counted twice |

I am going to count both and **name the pair on the card**, not suppress
either. Salapify genuinely cannot know whether two matching rows are one
payment entered twice or two real payments, and people do have two Home Credit
plans. Dropping one silently is the error that bounces a payment.

The rule is sharper than "two rows look alike". Three of these registers are
**entries** (somebody wrote a payment down) and two are **rules** (machinery
that generates payments from a balance or a cycle). I flag when a rule and an
entry disagree about a month, not when two entries resemble each other. That
survives the day you really do have two plans with the same provider.

**I will also remove the three duplicates from the sample ledger.** A demo that
contradicts itself in three places is teaching the double count to every new
user. This changes demo figures only.

## 2. The runway card gets six states, not two

You never see this one; it is the answer to a question I brought you earlier
and then had overturned. My "comfortable" sentence was a fake insight: on your
ledger the tightest day is simply the last day anything was scheduled, because
nothing comes in after it. The card now has a state for a real low point that
recovers, a state for a line that only ever falls, a state for already short
today, and three more. One row, same place, same size, loud by colour only.

## 3. Phases run two at a time, not three

You asked whether the remaining work can run in parallel worktrees. Measured
answer: disk is a non-issue, but the test suite uses nearly three of this
machine's four cores, so a third lane makes everybody slower.

The deeper reason is this page. **Four of the seven remaining items are waiting
on a decision from you before any code is written.** Parallel work upstream of
one person just grows the queue in front of them.

So: one lane continues the runway card, one lane starts lazy lists (the only
remaining item with no money, no stored data and no decision in it), and the
rest stays sequential.

---

# Where today's work actually got to

Nine real defects found and fixed, every one reproduced by running the code
before the fix and every guard broken again afterwards to prove it can fail.
Five of them were reachable on your phone: a monthly minimum bigger than the
debt, a negative minimum cancelling out other debts, a long number killing the
Save button, an unreadable figure saving as nothing in silence, and two date
branches reminding a day late.

**One correction to something I told you.** I said 42,987.80 was "already
overdue" on your ledger and that it had to stay on the card so you would never
read a comfortable balance and draw a wrong conclusion. **32,500 of that is
your sweldo**, money you had already been paid. The real overdue figure is
10,487.80. The cause was in the code I wrote yesterday: it asked "is this in
the past" before it asked "is this income". Fixed by renaming the fields so
every call site had to be re-read rather than quietly carrying the old
meaning.

Suite at 1814 passing. Nothing has gone to `main`.
