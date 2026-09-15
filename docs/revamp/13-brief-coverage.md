# Does the roadmap cover the Financial OS brief?

Founder question, 2026-09-15: "wanted to check if every feature in this file is
considered in the roadmap? i checked the roadmap it includes limited details".

**Short answer: no, and the founder is right to notice.**

Every feature in the brief was AUDITED in `12-financial-os-audit.md`. Almost
none of it was SCHEDULED. Those are different things, and the gap between them
is this document.

---

## 1. Why the roadmap looks thin

`05-roadmap.md` is a **rebuild** plan, not a **product** plan. Its five phases
answer one question: how do we get Salapify 3 onto the founder's phone without
losing anything. Phases 0 to 4 are documentation, design, foundation, screens
and cutover. They are nearly done.

Phase 5 is one paragraph, and it is an empty bucket:

> "The list is whatever the founder missed in Phase 3's week plus whatever they
> want next, ranked by 'would I use it tomorrow'."

That is where the entire brief lives. It was deliberate when written, because
ranking a 40-feature product roadmap before the app could edit a transaction
would have been planning in the dark. It is no longer adequate, because the app
is nearly at cutover and the bucket is still empty.

---

## 2. The number that reframes everything

`app/lib/core/money` holds **67 pure money engines**, byte-identical to the
shipped app's and verified against 34 golden fixtures. That IS the "central
financial engine" the brief's section 5 asks for. It is not a plan. It is done
and locked.

Measured on 2026-09-15:

| | count |
|---|---|
| Money engines ported, tested, golden locked | **67** |
| Consulted by a screen or by `FinancialState` | **18** |
| Consulted by nothing on any screen | **49** |
| Reachable by nothing at all, not even another engine | **33** |

So the distance between Salapify today and large parts of the brief is mostly
**wiring and screens**, not financial architecture. The arithmetic for "Can I
afford this", the BNPL simulator, the cash-flow calendar, the 13th month
allocator and the monthly autopsy is already written, tested and locked. None
of it is reachable by a user.

The 33 unreachable engines, by name:

```
account_currency   account_flow      accounts_breakdown  afford
bnpl               card_products     cashflow_calendar   categories
chartgeom          coach             debt_statement      expansion_progress
goals_calc         greeting          insight_feed        notecalc
paluwagan          payoff_compare    period              plan
quick_adds         recurring         reminders           search
spending_breakdown splits            statement           steadypay
surplus            taxdeadlines      thirteenth          widget_tile
windfall
```

---

## 3. The coverage matrix

Legend: **E** = engine exists and is golden locked. **S** = a screen a user can
reach. **R** = named in `05-roadmap.md`.

### Brief P0, Financial Foundation

| Feature | E | S | R | Note |
|---|---|---|---|---|
| Accounts | yes | yes | yes | |
| Transactions | yes | yes | yes | |
| Categories | yes | **no** | **no** | `categories.dart` unreachable. No category editor exists: a user cannot rename, add or delete one. |
| Income | yes | yes | yes | Logged as a transaction type. |
| Bills | yes | yes | yes | Read-only. See Recurring. |
| Recurring transactions | yes | **no** | **no** | `recurring.dart` unreachable. **No way to add a recurring bill.** 04-screens.md asks for a "+ Recurring" action on Plan; it was never built. Bills can only arrive from a restored backup. |
| Budgets | yes | yes | yes | |
| Goals | yes | yes | yes | Shipped 2026-09-15. |
| Debt | yes | yes | yes | |
| Credit cards | yes | partial | partial | Utilisation bar and minimum-due only. `debt_statement`, `card_products`, `credit_utilization` unreachable: no statement balance, no due-date screen, no installments. |
| Assets | yes | partial | yes | Listed in Accounts. No asset editor. |
| Liabilities | yes | yes | yes | |
| Net worth | yes | yes | yes | Plus the 12-month chart, shipped with Insights. |
| Balance sheet | yes | **no** | **no** | `statement.dart` unreachable. |
| Central financial engine | yes | yes | yes | 67 engines, golden locked. |
| Financial state | yes | yes | yes | `FinancialState` facade. |

### Brief P1, Core Intelligence

| Feature | E | S | R | Note |
|---|---|---|---|---|
| Cash-flow forecast | yes | partial | partial | Plan > Upcoming is the sweldo timeline. `cashflow_calendar.dart` unreachable. |
| Safe-to-spend | yes | yes | yes | |
| Payday budgeting | yes | partial | partial | The cycle exists; the "what does this paycheck need to cover" allocation view does not. |
| Financial calendar | yes | **no** | **no** | |
| Financial health score | yes | **no** | **no** | `healthScore` has no caller. The audit's section 3.6 argues against shipping it as a composite number. **Open decision.** |
| Goal forecasting | yes | partial | yes | The row shows the required monthly amount. `goalWhatIf` unreachable. |
| Debt calculations | yes | yes | yes | |
| Credit-card intelligence | yes | **no** | **no** | "What if I only pay the minimum" is written and unreachable. |
| Basic risk engine | **no** | no | no | No engine exists. |
| Basic insight engine | yes | **no** | **no** | `insight_feed.dart` and `coach.dart` unreachable. |

### Brief P2, Decision Support

| Feature | E | S | R | Note |
|---|---|---|---|---|
| Can I afford this? | yes | **no** | **no** | `afford.dart`. The brief calls this the signature feature. |
| What-if scenarios | partial | **no** | **no** | `sweldoTimeline` takes a `scenarios` argument no caller passes. |
| Purchase simulator | yes | **no** | **no** | Same engine as above. |
| Credit-card installment simulator | yes | **no** | **no** | `bnpl.dart`. |
| Debt versus savings | yes | **no** | **no** | `payoff_compare.dart`, `surplus.dart`. |
| Job-loss simulator | partial | **no** | **no** | `emergencyRunway` exists; the scenario shell does not. |
| Emergency mode | partial | **no** | **no** | |
| Financial leakage | **no** | no | no | |
| Lifestyle inflation | **no** | no | no | |
| What Changed? | yes | **no** | **no** | `categoryMovers`, `categoryVsAverage`. |
| Monthly financial autopsy | yes | **no** | **no** | `reports_calc.dart`. |

### Brief P3, Philippine Financial OS

| Feature | E | S | R | Note |
|---|---|---|---|---|
| MP2 planner | **no** | no | no | |
| 13th-month planner | yes | **no** | **no** | `thirteenth.dart` unreachable. Seasonal: worth having by November. |
| Philippine holiday logic | yes | yes | yes | `phcalendar` is used inside `commitments`, so bank-adjusted due dates already work. |
| Family support | **no** | no | no | |
| OFW / remittance | **no** | no | no | |
| SSS / PhilHealth / Pag-IBIG | partial | **no** | **no** | `phtax.dart` covers income tax. Contributions are not modelled. |
| HMO | **no** | no | no | |
| Paluwagan | yes | **no** | **no** | `paluwagan.dart` unreachable. |
| Tax deadlines | yes | **no** | **no** | `taxdeadlines.dart` unreachable. |

### Brief P4, Advanced Intelligence

| Feature | E | S | R | Note |
|---|---|---|---|---|
| Behavioural finance engine | partial | **no** | **no** | `weekdayPattern` exists. |
| Life-event simulator | **no** | no | no | |
| Proactive insights | partial | **no** | **no** | Needs notifications, which do not exist in `app/`. |
| Pan | **no** | no | no | **Founder-gated product fork.** See audit 3.5. |
| Financial document intelligence | **no** | no | no | |
| Benefits tracking | **no** | no | no | |
| Investment allocation visibility | partial | **no** | **no** | Assets are typed but not allocated. |
| Inflation planning | **no** | no | no | |
| Financial independence | **no** | no | no | |

### Brief cross-cutting principles

| Principle | Status |
|---|---|
| Offline-first (§33) | **Met.** No backend, no network in the engine. |
| Privacy, local-first, user-controlled export and deletion (§34) | **Mostly met.** Export, restore and undo shipped. Deletion of individual records is partial; no app lock yet. |
| Single source of financial truth (§5) | **Met, and it was a live defect.** `FinancialState` exists because Home and Plan genuinely stated two different daily paces. A second instance was found and fixed on 2026-09-15 when Plan projected from money Home had removed. |
| Deterministic arithmetic, no LLM (§5, §28) | **Met.** 67 engines, 34 golden fixtures. |
| Country rules layer (§11) | **Partially met.** PH logic sits inside the engines rather than behind a rules layer. Audit 3.4 flags it as a decision. |
| Progressive disclosure, simple interface (§35) | **Met so far,** and actively defended. |

---

## 4. The honest summary

Counting the brief's named features:

| | |
|---|---|
| Shipped and reachable | **about 20** |
| Engine written, locked, and unreachable | **about 20** |
| Neither engine nor screen | **about 25** |
| Named anywhere in `05-roadmap.md` | **about 20** |

So roughly **a third of the brief is built**, another **third is built but
unplugged**, and the final **third does not exist in any form**. The roadmap
names only the first third, because it was never meant to be a product plan.

The cheapest third is the middle one. Those features need a screen and a test,
not a financial architecture, because the arithmetic is already locked.

---

## 5. What this document does NOT do

It does not re-rank the roadmap. That is a founder decision and it needs three
answers the audit already asked for and has not received:

1. **The first milestone after cutover.** The audit proposed "wire what is
   already built" as P1 precisely because it is cheap. That is a
   recommendation, not a decision.
2. **Pan.** No network, opt-in cloud, or defer. This is a product fork, not a
   feature, and answering it late means building the intelligence layer twice.
3. **The composite health score.** The audit argues against it (3.6). The brief
   asks for it (10.10). One of them has to give.

Two things also have to be said plainly rather than buried in a table:

**There is no way to add a recurring bill.** Not "it is basic", it does not
exist. Every bill in the app arrived from a restored backup. A new user cannot
tell Salapify about their rent, and safe-to-spend is only honest if it knows
about rent. This is below the floor and it is not in any phase.

**There is no category editor.** A user cannot rename, add or delete a
category. The defaults are all they get.

Both belong in Phase 3 or immediately after it, ahead of anything in the
brief's P1 to P4, for the same reason the audit gave: an app with a forecast
engine and no way to fix a typo is not a system, it is a demo.
