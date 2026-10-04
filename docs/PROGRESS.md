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

### Phase 1, complete

Shipped: P1.1, P1.2, P1.3, P1.4, P1.5, P1.6, P1.7. **Phase 1 complete.**

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
| P1.7 | One debt-to-income rule (F8), one health check (F9) | DONE | see below |

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

### P1.7 notes

Two decisions, F8 and F9, and both are the same defect: the app held more than
one answer to a question somebody would ask it once.

**F8, the debt share.** The review counted FOUR rules. The health check called
25% comfortable and 40% tight, on take-home. `calculateDsr` called under 30%
healthy and over 40% stretched, while separately recommending a ceiling of 35%
of GROSS. The debt calculator screen repeated the 30 and 40 as its own copy.
The Academy twice said to stay under 15% of take-home. Each was defensible
alone, which is exactly why nothing was wrong enough to notice.

`core/money/debt_ratio.dart` now states it once: 30% comfortable, 40%
stretched, with the fraction DERIVED rather than typed a second time, because
a `0.30` beside a `30` is how two constants drift apart.

The 35% was the one that moved, and the moved golden vector was hand-computed
before the test was changed rather than after. The model reproduced the OLD
`2,002,607` exactly at 0.35, which is what makes the new `1,557,583` at 0.30
trustworthy: two independent routes to the same arithmetic, the second one
only believed because the first reproduced a number already locked.

`one_debt_rule_test.dart` reads the source and fails when any file outside
`debt_ratio.dart` declares a rival constant. Declaring one makes it fail:

    Expected: ['lib/core/money/debt_ratio.dart']
      Actual: ['lib/core/money/health_check.dart', 'lib/core/money/debt_ratio.dart']

**F9, the health check.** Pan ran its own engine, `pan_health.dart`, scoring
four weighted parts out of a hundred, while the Health Check sheet ran the
five-question engine in `health_check.dart`. Somebody who opened the sheet and
then asked Pan the same question got two readings of their own money.

Pan now calls the five-question engine, and `pan_health.dart` is deleted. The
SCORE went rather than the sheet, which is the right way round: a zero to one
hundred compresses five separate questions into one number and hides the one
that matters, and an 85 sat directly above "you owe more than you hold" on a
real ledger for a whole release. Pan leads with the tightest question instead,
by the sheet's own priority order, and the only figure it shows is "Questions
answered, 3 of 5", which is the one thing a single number here can truthfully
report.

Pan also gained a `healthCheck` action, so the button beside that answer opens
the screen the figures came from. Sending somebody to Reports for a health
answer is part of what two engines looked like from the outside.

Three readings left with the old engine. Cover and What you owe are still
answerable elsewhere in Pan; CARD USE is not, and it is the one genuine loss.
Deliberately not replaced: the founder settled on five questions on 2026-09-20
because twelve destroyed the signal, and quietly making it six inside a
consolidation task would undo that decision without anybody deciding anything.
Written up for the founder in `docs/DEFERRED.md`.

Both halves of the new alarm are proven, which is the half that gets skipped.
Dropping the tightest-first rule fails it:

    Expected: 'Needs attention'
      Actual: 'Nothing tight'

and always naming a tightest question fails the silent half:

    Expected: a string starting with 'Nothing tight on the'
      Actual: 'Will I make it to payday? Covered for the next 10 days, on the pace you are on.'

The source guard is proven too. Putting a second `runHealthCheck` back next
door fails it:

    Expected: ['lib/core/money/health_check.dart']
      Actual: ['lib/core/money/pan/pan_health.dart', 'lib/core/money/health_check.dart']

## Phase 2: money foundation

| ID | Task | Status | Notes |
|---|---|---|---|
| P2.1 | `Money` type in integer centavos (F1) | DONE | Every money field in lib/models/models.dart is whole centavos in an int. The guard list is empty and stays as a guard against a NEW double money field. Stored shape unchanged throughout: json_codec.dart writes pesos, so a backup crosses builds either way. |
| P2.2 | Schema version and migration on load (F2) | DEFERRED, founder decision 2026-10-04 | The two real defects are FIXED and shipped (an absent version read as current, a non-numeric version was waved through), with a tripwire that reddens the day a second version exists. The migration CHAIN is deliberately not built. Trigger to build it, both halves required: a change arrives that a tolerant reader provably cannot absorb (a semantic reinterpretation, or a record-identity change such as a Budget re-key), AND the app is already public. Rationale in docs/reviews/schema-migration-design.md. Not a gap to close later by accident: building it empty ships guards with nothing to run against. |
| P2.3 | Protected accounts (F3) | DONE | `Account.purpose`, spendable or protected. Additive on the wire, written only when protected, so no migration and no schema bump. A new `isSpendable` predicate is asked by the four sites that mean "should this fund today" (the engine, `totalLiquidCash`, the payday indicator, and `financial_truth`'s cash shortfall alarm, which hand-rolls its own liquid set and was nearly missed). The other seven stay on `isLiquid`, so every pay-from picker and the history filter provably cannot change. The cash runway deliberately keeps counting protected money. Seed ships `acc_maya` protected; vector D generated from the prototype's own TypeScript. Founder tested on the emulator: saved correctly, row label correct. One defect found by that test and fixed, a set-aside that could not move the figure confirmed nothing at all. |
| P2.4 | Debt types and minimums (F4) | todo | |
| P2.5 | Bills before payday only (F5) | todo | blocked behind the payday rule question in DEFERRED.md |
| P2.6 | Single FX source (F7) | todo | |
| P2.7 | Storage performance | todo | |
| P2.8 | Lazy lists everywhere entries are shown | todo | |

### P2.1 notes, increment 1 of several

**The size, stated honestly before starting.** P2.1 reads as one row and is the
largest change in the sprint: 28 money fields across the models, around 35
engine files in `core/money`, 11 golden vector locks, and roughly 1,400 tests
whose fixtures all pass pesos as doubles. It does not land in one sitting, and
the sprint prompt already says how to do it: module by module, tests green
after each.

**The decision that keeps it out of the founder-gated categories.**
`json_codec.dart` is the single boundary between the app and the file on disk.
Keeping the STORED shape as pesos, exactly as it is today, and converting at
that one boundary makes P2.1 purely internal: a backup written by this version
opens in the old one and the other way round, there is no migration, and
nothing can lose a record. The stored-format question belongs to P2.2, where it
is gated and where it will have a pre-migration backup behind it.

**What landed in this increment:** `core/money/money.dart`, the value type, and
nothing migrated yet. It holds centavos in an int, so two centavos plus two
centavos is four centavos on every machine and `==` means what it says.

Every rounding rule is the prototype's `Math.round` through `jsRound`, not
Dart's, so a figure that was right before is right after. The two differ only
on a negative half centavo, which is exactly the case no fixture has.

`money_test.dart` states each double failure first so the reason is on the
page rather than cited: `0.1 + 0.2 == 0.3` is false, `(1.005 * 100).round()` is
100 and not 101, and a thousand additions of a tenth miss by a sliver. The
split is tested as a PROPERTY over every amount from 1 to 2,000 centavos across
1 to 9 ways, asserting both that the shares sum back exactly and that no share
carries more than a centavo over any other. Dropping the remainder fails it:

    Expected: <1>
      Actual: <0>
    1 centavos over 2 did not sum back

and swapping `jsRound` for Dart's `round()` fails the negative half:

    Expected: <-2>
      Actual: <-3>

**The P2.1 check, usable from day one.** The prompt asks for a test that fails
if a money field is a `double`. Written as a flat ban it would be red on
purpose for the whole migration, and a test that is red on purpose gets
ignored. `money_migration_guard_test.dart` is a SHRINKING LIST instead: it
fails if a double field appears that is not accounted for, and equally if the
list claims work that is already finished, so the count cannot drift from the
code. Both halves proven. Planting a real field in the models:

    Expected: empty
      Actual: Set:['sneakyRolloverAmount']

and claiming a finished one:

    Expected: empty
      Actual: Set:['alreadyMigratedAmount']

Rates and durations are named separately as permanently double, with the
reason: an interest rate is a ratio and a cash runway is a count of months, and
forcing either into a centavo type is the same category error as holding a peso
in a double, pointing the other way.

### P2.1 notes, increment 2: Goal

**Why Goal first, and not the smallest thing.** Budget looked like the smallest
slice, one money field against fourteen construction sites. It is not
self-contained: a budget's percentage divides spending by the limit, and
spending comes from transaction amounts, which have not moved. Migrating it
first would mean writing conversions between migrated and unmigrated code that
get deleted later.

Goal is the one model whose money answers only to itself. Progress is current
against target, months to go is what is left over the monthly target, and
nothing in it derives from the ledger. That makes it a complete vertical slice,
model to codec to engine to screen, at the lowest possible cost.

**The blast radius was three test files.** Not the hundreds the raw grep
suggested, because most tests build goals from `SeedData` rather than by hand.
That is the argument for picking a module by how self-contained it is rather
than by how few call sites it has.

**Every golden vector held, to the peso.** `plan_golden_test.dart` still
asserts 71, 37 and 100 percent; 17,500, 47,000 and 0 remaining; 4, 11 and null
months. What changed is that `remaining` is now compared EXACTLY rather than
inside a tolerance. `closeTo` was there because a double could not be trusted
to land on 17,500.00. A centavo count can, so the tolerance is gone and the
test is stricter than it was.

**The stored file did not change, and that is now a test rather than a claim.**
`test/data/stored_shape_test.dart` asserts the written JSON holds plain peso
numbers, decodes a hand-written file in the OLD shape rather than
round-tripping the codec against itself, and refuses any figure that looks like
a centavo count. Writing centavos to disk fails it with the damage spelled out:

    Expected: <42500.75>
      Actual: <4250075>

    Expected: Money:<42500.75>
      Actual: Money:<4250075.00>

A goal multiplied by a hundred, silently, in somebody's file. That test is what
has to be changed deliberately when P2.2 moves the stored format, with the
founder's answer in hand and a pre-migration backup behind it.

**Two figures stayed double on purpose.** Months of cover and months to a goal
are COUNTS OF MONTHS, and a percentage is a ratio. Forcing either into a
centavo type is the same category error as holding a peso in a double, pointing
the other way. The guard file names rates and durations separately for exactly
this reason.

**The guard worked unprompted.** Migrating the three fields turned the
migration guard red by itself, because the shrinking list refused to go on
claiming finished work:

    Expected: empty
      Actual: Set:['currentAmount', 'monthlyTarget', 'targetAmount']

### P2.1 notes, increment 3: InstallmentPlan, and three money defects it uncovered

Seven money fields in one self-contained engine, and the conversion did what it
is supposed to do: it forced every rounding decision into the open, and three
of them turned out to be defects that existed in doubles long before centavos
were considered.

Two independent expert passes ruled first, a Philippine lending officer and a
new `rounding-controller` agent, and every claim was re-checked against the
arithmetic before anything was implemented.

**1. The schedule never footed.** The Home Credit sample plan billed
12 x 2,409.17 = 28,910.04 against a 28,910.00 contract. Four centavos, all of
it interest, collected on every plan whose term does not divide evenly.

**2. A prepayment was collected TWICE.** Measured end to end on the real
engine before touching it:

    after prepayment: balance 11864.19  settled false
      pay 10: entry 2409.17  balance 0.00  settled false
      pay 11: entry 2409.17  balance 0.00  settled false
      pay 12: entry 2409.17  balance 0.00  settled true
    total cash out: 33910.04   contract: 28910.00   OVERPAID BY: 5000.04

Settlement was driven by the COUNTER while a prepayment moved the BALANCE, so
the plan kept demanding full instalments against nothing owed, writing real
2,409.17 expenses to the ledger each time, and the final zeroing swallowed the
difference.

**3. The settlement sweep was guarded by nothing.** Two tests claimed to lock
it. Both ran the one seeded plan that divides evenly, and ALL 29 instalment
tests passed with the sweep deleted. Proven by deleting it.

### What changed

**Where the leftover centavo goes: the FINAL payment.** The two rulings
disagreed on exactly this and the disagreement is recorded rather than buried.
The controller preferred `Money.split`, which spreads the remainder over the
earliest shares so the app can never bill more than quoted. The lending officer
ruled for the final instalment, because every Philippine disclosure statement
shows one level figure with the last line adjusting. The lending officer wins
on the tie-break the controller itself named, which is what a person can
reconcile: the thing they hold next to this screen is their Home Credit bill,
and it charges 2,409.17 every month. So eleven at 2,409.17 and a twelfth at
2,409.13, summing to exactly 28,910.00.

**The payment is built from its parts.** `instalment = principalShare +
interestShare`, never `round(totalPayable / n)`. Those can differ by a centavo,
and when they do the row stops reconciling. This way "principal plus interest
equals the payment" is true by construction on every line.

**Principal and interest are TRACKED, the balance is DERIVED.** The old code
had it the other way round, and that let any arithmetic anywhere move the
contracted interest.

**Settlement is balance-driven and the sweep is gone.** The balances now reach
zero by subtraction. A non-zero balance at the end of the counter is a fact the
app can still see, which is the whole point of removing a sweep.

**Every payment is capped at what is left**, and the ledger entry records the
amount ACTUALLY collected rather than the quoted instalment. Those differ on
the adjusting final payment and on any stub after a prepayment, and writing the
quoted figure moved an account by one number while the plan recorded another.

**A prepayment is capped at the BALANCE, not the principal, and this is where
I departed from the lending ruling.** Capping at principal would have made
"paying the exact balance settles it" false, and somebody who hands over
everything owed is finished. So money beyond the principal pays the unearned
interest rather than being refused or forgiven. The invariant that catches the
original defect is not "interest never moves", it is that the balance falls by
exactly what was applied.

**Three seeded figures were wrong and are corrected**: Home Credit's balance,
principal and interest were computed from the rounded instalment rather than
from the contract, and the BPI plan recorded a 4,582.50 prepayment its own
balances ignored.

### The vectors that moved, and why

| Figure | Was | Now | Why |
|---|---|---|---|
| Home Credit balance | 16,864.19 | 16,864.15 | derived from the contract, not from seven rounded instalments |
| Home Credit principal left | 14,291.67 | 14,291.65 | same |
| Home Credit interest left | 2,572.52 | 2,572.50 | 4,410 x 7/12 divides exactly |
| Home Credit principal after one payment | 12,250.003333333334 | 12,249.98 | the carried third of a centavo is gone |
| BPI balance | 32,077.50 | 27,495.00 | its recorded prepayment is credited now |

The old test for that third-of-a-centavo asserted it with a tolerance and a
comment explaining that "nothing here rounds it away". That was the defect
written down as a feature.

### The invariants

`installment_schedule_test.dart`, thirteen tests, every one exact with no
tolerance anywhere, because a centavo count does not need one and a tolerance
is how the discrepancies hid. Each conservation invariant carries a directional
companion: the footing test is paired with an assertion that the shares are NOT
all equal, and the prepayment test with an assertion that the plan got SHORTER.
The settlement test runs the Home Credit plan specifically, because it is the
only seeded plan that can fail it.

### Increment 4: the true cost of credit

Founder direction, 2026-10-01: "build the true cost figure". The lending
officer's largest finding, deferred out of increment 3 as new feature work and
then approved.

`core/money/true_rate.dart` solves the rate at which the payments a person
actually hands over are worth, today, exactly what they borrowed. Bisection,
because the equation has no closed form and bisection cannot diverge: present
value falls monotonically as the rate rises, so the bracket always closes.

It needs no new stored field and cannot be gamed. It reads the principal, the
payments and the term, whatever the lender called the rate.

**Every figure was re-derived independently before a line was written**, rather
than taken from the review:

| Plan | Quoted | Shown before | True |
|---|---|---|---|
| Home Credit, 24,500 over 12 | 1.5% a month, 18.0% a year | 18.0% a year | 2.6% a month, 31.7% a year |
| SPayLater, 8,400 over 6 | 2.95% a month, 35.4% a year | 35.4% a year | 4.9% a month, 58.4% a year |
| BPI SIP, 54,990 over 24 | 0% | nothing | 0%, and no correction shown |

**The test that decides whether any of it is trustworthy** is the sanity one: a
loan that genuinely charges 1.5% a month on the diminishing balance must solve
back to 1.5%. It returns 1.500000%. Discounting without compounding fails it:

    Expected: a numeric value within <0.001> of <1.5>
      Actual: <1.582640554261161>

And a genuine 0% plan must land on exactly zero rather than drift, because
"this costs you nothing" is a real claim. Removing that guard fails it:

    Expected: <0>
      Actual: <3.637978807091713e-11>

**The annual figures are both multiplied by twelve, neither compounded.** The
quoted annual figure beside it is also a monthly rate times twelve, so
computing them the same way makes the comparison about the RATE rather than
about the arithmetic. Compounding one and not the other would inflate the gap
and start an argument about convention instead of about cost. Compounding makes
the honest figure higher still (36.8% rather than 31.7% on the Home Credit
plan), and that belongs in the explainer, not on the card.

**Three deliberate restraints:**

1. The quoted rate stays on screen. It is not wrong and nobody is hiding it.
2. The correction appears only when the real rate is materially above the
   quoted one. The interest-free BPI plan carries none: a line saying "really
   0%" about a lender who charged nothing reads as an accusation and teaches
   people to ignore the one that matters. A journey test asserts exactly two
   plans carry it.
3. No statute, circular or regulator is named anywhere. The reviewer marked
   every regulatory statement as unverified memory, and this repository already
   caught a fabricated government URL that a confident review had waved
   through. The explainer describes arithmetic in plain words and claims no
   official standing, the same line `loan.dart` draws when it refuses to call
   30% "the BSP safety threshold".

### P2.1 increment 5: the ledger

`Transaction.amount`, the root every other money figure in the app derives
from. Sixty files, and the single largest piece of the migration.

**How it was done, because the method is the transferable part.** Three
hand-written edits missed on whitespace before I stopped guessing and wrote a
fixer driven by the compiler's own `file:line:col` output. It made 45 edits
mechanically and printed every one. A second, failure-driven pass handled what
the analyzer cannot see: `expect()` takes `dynamic`, so comparing a `Money` to
a bare number compiles cleanly and only fails when the test runs. Several
sibling types still hold a double (receipt amounts, split shares, alert
amounts), so a blanket rewrite would have broken them; patching only the lines
the suite actually reported was the safe route.

**Every ledger golden vector held.** `ledger_golden_test.dart` passes
unchanged in substance: the port is still locked to the prototype's numbers.

**One test could no longer be written, and that is the improvement.** It built
a `Transaction` holding `double.nan`, a poisoned value from a corrupt backup,
and asserted the summary survived it. There is no NaN in an int, so that value
cannot enter a transaction at all. The defence moved from "survive the poison
downstream" to "the poison never gets in", which is the stronger of the two.

**A real behaviour change on the restore path, recorded rather than slipped
past.** Because `Money.fromDouble` refuses a non-finite value, a file carrying
one is now REFUSED rather than partly loaded. I traced it: `loadSnapshot`
catches it, the previous generation opens instead, saving is turned off, and
the person is told "Salapify could not make sense of its data file. It has not
overwritten anything while it cannot read it." So nothing is lost, and the
direction is safer: one bad amount used to poison every percentage computed
from it, silently. But it IS more drastic than before, and it is a change to
how restore behaves, so it is written here.

**A limitation of the migration guard, stated rather than hidden.** The guard
reads field NAMES out of `models.dart`, and `amount` is carried by four models.
Transaction's is now `Money`; `UpcomingItem`, `BillItem` and `SubscriptionItem`
still hold a double. So `amount` stays on the remaining-work list and the count
does not fall for this increment, even though the biggest single field in the
app moved. The count is honest about names, not about progress, and the three
remaining holders have to move together before it can drop.

**The stored file still does not change shape**, now guarded for the ledger
too. Writing centavos to disk fails it with the damage spelled out:

    Expected: <1053.5>
      Actual: <105350>

## Phase 3: P3.2, onboarding, done OUT OF ORDER

| ID | Task | Status | Notes |
|---|---|---|---|
| P3.2 | First run and onboarding for an empty ledger | DONE | founder direction, 2026-10-03 |

Taken ahead of the rest of Phase 2 on founder direction, after a review pass
on the founder's own emulator found the defect it closes. This table says so
rather than quietly renumbering, because a roadmap that hides its own
reordering stops being useful for working out what is actually left.

**What it closes.** A fresh install opened straight onto SAMPLE data: a 48,500
payroll, a housing loan, a GCash wallet, a debt to a person called Sarah, with
nothing anywhere saying it was fake. That was item 1 of the ten trust breakers
in `docs/reviews/2026-10-expert-review.md`.

**The design was agreed in writing first**, in `docs/reviews/onboarding-design.md`,
per the brainstorming gate. Two specialist passes were run and every
load-bearing claim in both was verified by reading the code.

**One of those verifications found something nobody had noticed.**
`SeedData.payday` is not merely absent on a fresh install, it is FABRICATED: a
15th and 30th cycle, a next payday, 32,500 of expected income, with the hero
drawing a countdown off it. Every untouched install was counting down to a
stranger's sweldo.

**What shipped**, across `2d03574` and `1d0453f`:

- A welcome that asks once, in two taps, with no typing and nothing personal.
- `startWithOwnMoney`, which seeds NOTHING, reusing the existing sweep rather
  than reimplementing it so the rules about `isSample`, the payday, the income
  streams and adopting a used demo account stay in one place.
- `startWithExampleData`, which keeps the demo and puts its one line exit on
  Home, under the shortcut row, where the honest sentence from
  `sample_data_sheet.dart` had been two taps and a scroll behind a gear.
- One stored field, `onboardedAt`, nullable and modelled on
  `sampleDataRemovedAt`, with a SECOND question (do real records exist) so a
  restored backup is never marched through a first run it finished elsewhere.
- `needsWelcome` false on an unreadable file, found while fixing test failures
  rather than designed up front, and a near miss worth recording: a cheerful
  first run over a ledger that merely could not be parsed, with saving already
  off, would have been a first run that silently discarded itself.
- The Today row under the hero, which is the only thing on Home that answers
  what has left since this morning, and the door into a first entry.
- The payday asked at the first income entry, as a yes or no.
- The daily nudge, and with it the Android notification permission, offered
  once on the first entry somebody ever made themselves.

**Two bugs the tests found, both in the offers.** One session latch was used
for two different questions, so the first entry spent it on the reminder and
the payday could never be asked at all. And a deliberate break FAILED TO FAIL:
removing `firstEver` left six tests green because the session latch covered for
it, and the branch it really protects is a second app run. A seventh test now
reaches that branch by pumping a second app over the file the first one wrote.

## Phase 3 to 7, the rest

Not started. Tracked in the sprint prompt; this table grows as each phase
begins.

## Packages added

None so far.
