# Sweldo Runway: the two decisions, and one recommendation each

2026-10-04. Written after the engine was built, the specialist passes ran, and
every claim in them was checked against the real code by running it. The
design document is `sweldo-runway-design.md`; this one only covers what is
left for the founder.

Everything the reviews found that was a plain defect has already been fixed
and is in PR #506, with the failure line from each deliberate break in the
commit message. What is below is not a defect. It is two places where
Salapify has to take a position, and reasonable people would take different
ones.

---

## Decision 1. When two registers describe the same payment

### What was measured

The sample ledger holds the Home Credit phone plan **twice**:

- `debt_homecredit`, a Debt: 14,700 total, 7,350 paid, 3 of 6 instalments
  left, which `monthlyMinimum` reads as 2,450 a month;
- `up_homecredit`, an UpcomingItem: "Home Credit Installment", 2,450, due the
  same day.

The projection places both, so **4,900 leaves the account on 18 September
when the real figure is 2,450.** Run against the seed, with the clock pinned
to 18 September 2026:

```
2026-09-18  Manila Water -480, Meralco -2,840,
            Home Credit Installment -2,450,     <- the upcoming item
            Inverter Refrigerator -2,409.17,
            Home Credit (Phone) -2,450          <- the same money, as a debt
```

This is not a bug in the engine. The engine is reading what the ledger says,
and the ledger says it twice.

### Why it cannot be settled in code

Salapify cannot know whether two rows of 2,450 on the same day are one
obligation entered twice or two genuine payments that happen to match. People
really do have two Home Credit plans. Guessing either way moves a real figure
on a real screen, and the two wrong answers cost differently:

- **Suppress one and be wrong**: the projection understates what is leaving.
  That is the direction that bounces a payment, which is the exact failure
  this whole feature exists to prevent.
- **Count both and be wrong**: the projection overstates what is leaving. The
  person is told they are tighter than they are. Annoying, never costly.

### The options

**A. The Debt register wins.** Any upcoming item that matches a live debt is
dropped from the projection. Matching has to be done on name and amount,
because nothing links them. Cheapest, and silently wrong the day somebody has
two plans with the same provider.

**B. Link them properly.** An UpcomingItem gains a `debtId`. This is a stored
field and a backup-format change, so it is a founder gate on its own and it
needs a migration and a way for a person to set the link.

**C. Count both, say nothing.** What happens today.

**D. Count both, and SAY SO.** The engine already returns everything it
placed. It would also return a short list of suspected duplicates: same day,
same amount, two registers. The screen shows one line, "Home Credit appears
twice on 18 Sep, as a debt and as an upcoming bill", with a tap to open
either one.

### Recommendation: D

It is the only option that is never silently wrong. It needs no stored change
and no migration, it keeps the projection on the safe side of the error, and
it hands the person the one thing they can actually do about it, which is
look at the two rows and delete one. It also costs nothing when there are no
duplicates, which is most ledgers.

B is the right long-term answer and should follow once there is a reason to
open the stored shape anyway. A is the one to avoid: it is the cheapest to
build and the only one that can quietly take money off the screen.

**Separately, and whatever is chosen: the seed's own duplicate is a defect in
the sample data and should be removed.** A demo ledger that contradicts
itself teaches a new user that the app double counts.

---

## Decision 2. What the one sentence says

### What was measured, on the seed

```
opening (spendable)  95,420.50
closing  (45 days)   73,081.86
tightest day         26 October, at 73,081.86
runs short           no
already overdue      42,987.80 across 4 items
could not be dated      239.00 across 1 item
```

The person never runs short. That is the ordinary case, and it is the case
the headline has to survive.

### The options

**A. "The day you run short."** The design document's own line: *Tightest day:
Monday 12 Oct, short 1,840.* Direct, and the first figure in Salapify a person
can act on. It has nothing to say on the seed, and nothing to say for anyone
whose money is fine, which is most people most of the time. A card that is
blank or says "you are fine" nine visits out of ten is a card people stop
reading, and then it is not there on the tenth.

**B. A margin.** *You have 4,200 of room before your next sweldo.* Always has
something to say, never urgent, and buries the one day that matters.

**C. One sentence that changes its verb.** Always about the same day, the
tightest one, with the number that matters on that day:

> **Tightest day: Monday 26 Oct.** You still have 73,081 then.

> **Tightest day: Monday 12 Oct.** You are 1,840 short that day.

### Recommendation: C, and it was OVERTURNED on the count

C is the right SHAPE and the wrong number of states. A UX review ran the
engine over the seed and found that my comfortable sentence is a fake
insight, which I confirmed by reading `tightestDay` at
`daily_projection.dart:144-152`:

```dart
if (d.balanceAfter < worst.balanceAfter) worst = d;
```

A STRICT less-than, so it returns the EARLIEST day at the minimum. On the
seed there is no income at all after 22 September, so the balance only ever
falls and then sits flat. 26 October is therefore not a trough; it is simply
the last day anything was scheduled, and the line is flat across the
remaining seven days of the window. "Tightest day: 26 Oct, you still have
73,081 then" is really saying "at the end of your projection you have
73,081", dressed up with a date that carries no information.

And it is not an accident of this ledger. Whenever a projection has no income
after its last outflow, the tightest day IS the end of the window, by
construction. That is every person who has not stored a payday rule, which is
the seed and every brand new install.

The discriminator needs no engine change and no new field:

```dart
final bool recovers = p.closingBalance > p.tightestDay!.balanceAfter;
```

When the balance climbs back after the low point, "tightest day" is a real
insight and C's sentence is exactly right. When it does not, the low point is
the end of the window and the sentence has to say so instead. So: C's shape,
confirmed. C's two states, overturned. **Six, with the guards in order and
first match wins:** brand new install (the row does not render), nothing
dated, short TODAY, runs short later, a real trough that recovers, and flat
or declining to the end.

### A correction to this document

Every earlier draft of the example sentence said "Friday 12 Oct". **12 October
2026 is a Monday**, and so are 26 October and 2 November. Checked by running
`DateTime.weekday`, not by counting. The wrong weekday came from
`sweldo-runway-design.md:11` and was copied forward twice without being
checked, which is exactly the shape of error that ends up pasted into code.

### One thing that must stay on the screen whatever is chosen

The seed carries **42,987.80 already overdue**, which is larger than anything
else the runway would show. Under the founder rule of 2026-09-18 a figure that
teaches goes behind the "i" dot, with one exception: anything a person needs
in order to avoid a wrong conclusion stays on the screen. Silence about 43,000
of overdue bills, next to a comfortable runway, is exactly that case. One
line, on the card.

---

## A third thing, not a decision, that the founder should know

The sample ledger declares `cycleType: '15_30'` and stores **no**
`paydayDays`. `paydayDays` is only ever written when somebody sets a payday
rule inside the app (`financial_state.dart:515`), so the demo ledger has a
cycle type and no rule, and the runway sees **one** sweldo in six weeks
instead of three.

That is not a wrong number, it is the correct answer to a ledger that never
said when payday is. But it means the demo shows the app at its most
pessimistic, and it is the same state every brand-new user is in before they
answer the payday question. Worth deciding deliberately rather than by
accident: either the seed gets `paydayDays: [15, 30]` to match what it already
claims, or the first-run experience needs to ask for the rule earlier than it
does.

---

## Not fixed, and why

In a timezone with daylight saving the engine is a day out, because
`Duration(days: n)` across a transition is 23 or 25 hours and `.inDays` on two
local midnights rounds down. Reproduced with `TZ=America/Los_Angeles`: a bill
due 9 March 2026 was placed on 8 March.

The Philippines has no DST, so this is clean for the home market. It is wrong
for an OFW with their phone on US or EU time, and it also skews the real
notification scheduling, which runs off the same `daysUntil`. The fix is date
arithmetic that steps calendar days rather than durations, across
`reminders.dart` as well as the projection, so it is its own piece of work
rather than a line in this batch.
