# P2.3, protected accounts: the design

2026-10-04. Written before any code, per the brainstorming gate.

Two specialist passes have now reported, a money one (financial-coach) and a
screen one (flutter-ux-craftsman). **Every claim either of them made that
changes this design was re-read out of `app/lib` before it was written down
here**, because an agent's finding is a lead and a lead is confirmed by reading
the code. Two of their claims corrected ME, and both corrections are marked
below.

## The defect, in one paragraph

Whether an account counts as spendable cash is decided purely by its KIND.
`liquidKinds` in `app/lib/models/models.dart:27` is `{cash, gcash, maya, bank,
debit}`, and `Account.isLiquid` (line 149) is nothing more than
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

A 74 percent drop in the headline from a 36 percent exclusion, because the
reserves barely move and the spendable figure is what is left over. That is the
correct number becoming visible, not a regression, and it is also the single
strongest argument that this change cannot be made silently on somebody's real
ledger.

---

## The thing the spec did not mention, corrected twice

`isLiquid` is not doing one job. My first draft said two. **The money
specialist found a third, and it found three more call sites I had missed.**
Verified: eleven places in `app/lib` ask some version of this question, and
three of them do not call `isLiquid` at all.

**Job one, what counts as money you can spend today.** This is the only job
P2.3 is about.

| Site | What it drives |
|---|---|
| `core/money/safe_to_spend.dart:32` | the headline, the buffer, the runway |
| `state/financial_state.dart:2199` (`totalLiquidCash`) | Pan's "you can reach X today" |
| `core/money/health_check.dart:215` | the "will I make it to payday" indicator |
| `core/money/financial_truth.dart:208` | **its own hand-rolled copy** |

That last row is the find of the whole pass. `financial_truth.dart` does not
call `isLiquid`; it types the kinds out again (and deliberately leaves out
debit, a difference inherited from the prototype). It drives the **Cash
Shortfall Risk** alert, which is the loudest alarm the app has, and the debt
pressure ratio under it. Verified by reading lines 205 to 258. If that file is
left out of the fix, the bug survives in the one place that shouts.

**Job two, which accounts you can pay FROM.** `log_sheet.dart:64`,
`payment_sheet.dart:65` and `:87`, `installment_sheet.dart:70` and `:161`,
`scan_receipt_sheet.dart:481`, and the history filter at
`activity_screen.dart:265`.

**Job three, what is cash on a balance sheet.** `reports.dart:395`
(`cashEquivalents`) and `accounts.dart:267` (`summarize`). Verified: both key
off `assetKinds` and `cashEquivalentKinds` and never touch `isLiquid`, so
protected money changes nothing here by construction. It should not. GSave is a
cash equivalent whatever you intend to do with it.

So the change is NOT "protected accounts are not liquid". It is: **a new
question, "does this count as spendable today", asked only by job one.**
`isLiquid` keeps its exact meaning everywhere else, which means seven of the
eleven sites provably cannot change behaviour and nobody has to re-reason about
them.

```dart
bool get isSpendable => isLiquid && purpose != AccountPurpose.protected;
```

---

## The shape

One field on `Account`:

```dart
enum AccountPurpose { spendable, protected }
```

Additive and nullable on the wire, defaulting on read. `accountKeys` in
`json_codec.dart:303` is a flat key set, and `purpose` would be written only
when protected, copying the `if (a.isSample) 'isSample': true` pattern at line
340. Verified: `merged()` in `snapshot.dart` keeps unknown per-record keys, so
an older build opens a newer file and writes the flag back untouched, and a
newer build opens an older file with the key absent and reads the default.
**NO MIGRATION. No schema bump. Nothing in P2.2 has to land first.**

Nothing stored changes retroactively, and this is worth stating plainly because
the 74 percent above looks alarming. `safeToSpendAnalysis` is a getter
(`financial_state.dart:2219`) that recomputes on every read; no derived money
figure is in `Snapshot`'s collection keys at all. Marking an account protected
moves today's figure and rewrites no history.

### One finer split inside Safe to Spend

The money specialist caught something I would have got wrong. Protected money
must leave `uncommittedCash` and the `emergencyBuffer`, and must **stay in the
cash runway** (`safe_to_spend.dart:145`). Runway asks "if my income stopped,
how long would I last", and the emergency fund is precisely the money that
answers that question. Taking it out would cut a saver's runway from about 4.0
months to 2.5 and punish them for doing the right thing. That is correct and I
am adopting it.

---

## What the two specialists settled, so you do not have to

These were design calls, so they went to the specialists rather than to you.
Recorded here for the record, not for a decision.

- **Two states, not three.** Paluwagan money you hold for the group is not
  protected, it is not yours, and it belongs in the debt model in the "I owe"
  direction (calling it protected would leave it inside your net worth). A
  GCash balance that is part spending and part ipon is a partial amount, which
  no label can express; the real answer is a second account and a transfer,
  which is also what GSave actually is.
- **The control, on the account sheet.** A Spendable / Protected segmented
  picker, pre-set to Spendable, labelled "What this money is for", hidden
  entirely for credit, loan, mortgage, investment and receivable where the flag
  would be inert. Caption: "Money set aside still counts in your net worth, but
  it stops counting as Safe to Spend."
- **"Set aside", not "Savings"**, as the option word, because a payroll account
  in a product called Savings would be mis-ticked by half the audience.
- **Protected accounts stay in every pay-from picker**, which I had
  recommended, but the real reason is harder than mine: `log_sheet.dart:64`
  builds ONE list and uses it for the from list and the transfer-to list, so
  hiding protected accounts would make it impossible to move money INTO your
  emergency fund from the log sheet. Verified at lines 63 to 75. Making saving
  harder than spending, in this app, would be the joke of the year.
- **"Emergency buffer" has to be renamed** on the Safe to Spend sheet
  (`safe_to_spend_sheet.dart:228`). Once a person has a real protected
  emergency fund, the app is calling two different things by the same name. The
  label becomes "surprise buffer"; the golden-locked field name does not move.
- **Step 1 of the Safe to Spend audit must name the figures.** It currently
  reads "Cash, GCash, Maya, banks and debit", verified at line 385, which
  becomes false the day this ships. It gains the second figure: spendable, and
  protected and left out.

---

## The three decisions that are yours

### D1. Do existing accounts stay spendable until the person says otherwise?

**Recommended: yes. Nothing moves on anybody's ledger without them doing it.**

Both specialists landed here independently, and the alternative is worse than I
first thought. Inferring from the NAME is unsafe in both directions: "Maya
Savings" is the literal product name of a wallet millions spend from daily, and
GSave lives inside GCash so the account may be named "GCash" with both pots
mixed. Inferring from the KIND is worse, since all five liquid kinds are used
both ways.

And the measured figure is the argument: a wrong guess takes somebody's
headline from 38,414 to 9,838 overnight with no action of theirs to explain it,
and the first thing they conclude is that the app lost their money. A silent fix
that looks exactly like a bug is not a fix.

The cost of this is real and should be said out loud: **the defect persists for
every existing user until they go and set it.** That is what D3 answers.

### D2. The sample data: one account or two?

**Recommended: mark Maya Savings protected in the seed, leave MariBank
spendable.** This is a change from my first draft, which said both, and the
specialist's reason is better than mine. One account teaches the idea at a 29
percent reduction (9,604 to 6,840 a day). Two produce the 74 percent collapse
in the table above, which to somebody who installed the app ten seconds ago
reads as a broken app, not as a lesson. Leaving MariBank spendable is also a
deliberate live example that Salapify did not guess for you.

This is yours and not the specialists' because it moves a golden vector. The
Safe to Spend vectors came out of the prototype's own TypeScript, and the
standing rule is that if a figure disagrees with the prototype the port is
wrong. Here the INPUT would be deliberately different, which is a legitimate
reason, and it is the first time in this migration that any vector has moved.
It needs saying out loud rather than quietly regenerating. The good news:
`purpose: protected` is arithmetically identical to deleting that account from
the fixture, so the new vector can still be generated from the untouched
TypeScript engine and the golden lock does not have to be re-based.

### D3. How does anybody find out this exists?

The defect is silent by nature, and a control nobody opens fixes nothing. The
two specialists disagreed here, which is why it is coming to you.

1. **Nothing.** The field exists for people who look. Cheapest, leaves the
   defect in place for everybody else.
2. **A one-time review prompt** for existing accounts. The money specialist
   wants this. The screen specialist says DO NOT BUILD IT and instead make step
   1 of the Safe to Spend audit name the accounts, because that is where
   somebody already goes when the headline looks wrong.
3. **Both**, which is what I lean toward: the audit line always, because it
   costs nothing and cannot misfire, and the prompt only if you want the
   existing-user defect closed rather than left to be discovered.

My recommendation is **3, with the prompt kept to a single non-blocking card
that can be dismissed forever**, and never a guess about which account is
which. It lists your liquid accounts and asks which ones are set aside. It does
not pre-tick any of them.

### And one thing that is not a decision, it just has to be built

When somebody marks an account protected, the app **tells them what just
happened, with both numbers**:

> 15,300 is now protected, so Safe to Spend today goes from 9,604 to 6,840.
> Your net worth has not changed and you can still pay from this account.

A 29 percent drop in the one figure a person reads first, landing at the exact
moment they did something good, is otherwise indistinguishable from the app
losing their money.

---

## What does NOT change

- No stored figure, and no money math. The engine is untouched; it asks a
  different question of the account list and computes identically.
- Every existing golden vector holds, except the Safe to Spend ones if D2 is
  approved, which move DELIBERATELY and are regenerated with the reason
  recorded.
- Net worth, assets, liabilities, cash equivalents and the Accounts screen
  totals. Verified above: they key off `assetKinds`, not `isLiquid`. A
  protected account is still money the person has, in full.
- `isLiquid` keeps its name and meaning for the pay-from pickers and the
  history filter.

## How it is tested

1. A unit test that a protected account leaves `totalLiquidCash` and stays in
   the pay-from list, which is the whole split in one assertion.
2. A unit test that the cash runway does NOT move when an account is
   protected, which is the finer split above and the one easiest to get wrong.
3. A codec round trip: purpose survives a save and a reload, an absent key
   reads as spendable, and an unknown value is refused rather than guessed.
4. A journey: mark an account protected, watch the Home headline fall, then pay
   a debt from that same account to prove it is still reachable, then transfer
   INTO it from the log sheet.
5. Break-then-prove on each, per the usual rule.

## One separate defect found while reading, not part of this change

`financial_state.dart:2201` sums `a.balance.pesos`, the raw balance, where
`health_check.dart:217` correctly sums `a.balanceInPhp.pesos`. Verified, and
`accounts.dart:39` states the rule in its own words: "Never sum `balance`
directly across accounts". For somebody with a USD payroll account,
`totalLiquidCash` adds dollars to pesos, and that figure is what Pan reads out
loud as "you can reach X today". `safe_to_spend.dart:33` has the same line, but
there it is deliberate parity with a prototype that has no currency field.
`financial_state.dart` has no such excuse. Logged for its own ticket, not fixed
here.
