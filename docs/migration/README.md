# Prototype to Flutter migration

The Google AI Studio prototype in `src/` is the source of truth. This folder
tracks what has crossed over into the Flutter app in `app/`, with a picture of
every screen so it can be reviewed without a phone.

Founder direction, 2026-09-18: rebuild `app/` from zero against the prototype,
and migrate the tabs in the prototype's own order.

**`coverage-audit.md` in this folder is the authoritative gap list**, written
2026-09-18 on founder direction ("check everything, make sure we migrate
everything"). The table below says which TAB is done. That file says which
FEATURE and which piece of CONTENT is done, file by file across
`src/components`, `src/utils` and `src/data`, and it is the one to read before
picking up the next batch. It exists because the Academy shipped with six
courses I invented while the prototype's real thirty two sat unread in
`src/data/academyData.ts`.

## Migration order

The prototype's tab order, finished one tab at a time including its modals.

| # | Tab | Prototype source | Status |
|---|-----|------------------|--------|
| 1 | Home | `Header`, `HeroPanel`, `BudgetPulseCard`, `QuickActions`, reminders banner, `DebtBeamCard`, `ComingUpCard`, `LatestTransactions`, `PanFloatingButton` | Built to match the prototype |
| 1b | Home's sheets | `SafeToSpendModal`, `AddDebtModal`, `BankAmortizationTable`, `TaxCalculatorModal`, `BusinessTaxSimulatorModal`, the category manager | Built and reachable from Home |
| 2 | Activity (Ledger) | `LedgerScreen`, `LogSheet`, `TransactionDetailModal` | Done. List, detail and the Log write path, with quick parse and a date picker |
| 3 | Reports | `ReportsScreen` | Position, Performance and Cash flow built. Reconciliation, the one that writes, is its own step |
| 4 | Plan | `PlanScreen`, `AcademyView`, `CalculatorLibrary`, trackers | All eight segments built, Academy carrying the real 32-course curriculum. The three long-form startup guides get their own pass |
| 5 | Accounts | `AccountsScreen`, `BankCard`, `InvestmentsView` | Not started |

"Built" in the column above means the tab's own screens exist and read the real
engines. It does NOT mean every section of the prototype's screen crossed over.
Reports is missing its Reconciliation tab and five smaller views, Activity is
missing the correction write path, and Plan is missing the three long-form
Academy guides. `coverage-audit.md` section 3 lists each one with the prototype
line number, so a batch can be picked up without re-deriving the gap.

Screens that hang off several tabs (Safe to Spend, Health Check, Pan chat,
Collaboration, the business guides) migrate with the tab that opens them.

## Screens

Dark first, because that is what the founder uses.

### Home

Rebuilt against the founder's own prototype screenshots, 2026-09-18. The card
order is App.tsx's: hero, budget pulse, quick actions, reminders, debts,
coming up, latest.

Full page, the whole scroll in one image:

| Gabi (dark) | Hapon (light) |
|---|---|
| ![Home full, Gabi](screens/home-gabi-full.png) | ![Home full, Hapon](screens/home-hapon-full.png) |

Phone sized, what actually fits on a 390dp screen:

| Gabi (dark) | Hapon (light) |
|---|---|
| ![Home, Gabi](screens/home-gabi.png) | ![Home, Hapon](screens/home-hapon.png) |

### Activity

The entries half of tab 2, built 2026-09-18. Search, status and account
filters, the summary card, the type tabs, and the list grouped by day.

| Gabi (dark) | Hapon (light) |
|---|---|
| ![Activity, Gabi](screens/activity-gabi.png) | ![Activity, Hapon](screens/activity-hapon.png) |

Three rows were added to the fixture so this screen can be REVIEWED rather than
merely rendered: a pending card authorisation, a transfer, and a duplicate
Meralco charge marked excluded. Without them every entry is a plain confirmed
expense and the status chips, the struck-through amount and the rule that keeps
excluded money out of the totals are all invisible in a screenshot.

Look at Sep 15 in the render. Two identical Meralco rows, one struck through
and badged EXCLUDED, and the day header says `Out: ₱2,840.00`, counting one of
them. That is the rule doing its job where a person can see it.

Every figure on the card was checked independently of the code that drew it:

| On screen | Adds up to |
|---|---|
| Out ₱14,874.75, 7 entries | 180 + 1,899 + 285 + 420 + 6,000 + 2,840 + 3,250.75, with the excluded 2,840 left out |
| In ₱51,000.00 | 32,500 + 18,500 |
| Kept ₱36,125.25 | 51,000 less 14,874.75 |
| 29% out, 71% kept | 14,874.75 / 51,000 |

Tapping any row opens its detail. The render below deliberately opens the
EXCLUDED one, because that is the state most likely to confuse somebody
reconciling against a bank statement: the amount is struck through, and a
sentence underneath says in plain words why it is not in the totals. The date
appears twice, friendly and as the stored ISO value, because "Yesterday" stops
being useful the moment you are comparing against a statement.

| Transaction detail (Gabi) |
|---|
| ![Transaction detail](screens/transaction-detail.png) |

The detail is the VIEW half only. The prototype's modal also edits an entry and
carries a collaboration thread: comments, mentions, approvals and receipt
attachments. Those need a collaboration system and a storage layer that `app/`
does not have, and a comment box that cannot save a comment is worse than no
comment box. The sheet says so at the bottom rather than implying otherwise.

### Logging an entry

The write path, reachable from the Log button in the tab bar and the Log quick
action on Home.

| Log sheet (Gabi) |
|---|
| ![Log sheet](screens/log-sheet.png) |

Saving MOVES MONEY: the account balance changes, exactly as the prototype's
`addTransaction` does, and a transfer debits one account and credits the other
so net worth is unchanged. The balance arithmetic lives in `applyToBalances`
and is locked to vectors generated from the prototype's own code.

**Type it in one line.** Founder request, 2026-09-18. The line at the top of
the sheet takes "Jollibee 500 gcash" and works out that this is a 500 peso
expense at Jollibee, out of the GCash wallet, filed under Food & Dining. It is
the prototype's own parser from `src/utils/fastlog.ts`, 145 keywords, ported
with vectors, and it understands Taglish because that is how people write a
note to themselves: "padala kay nanay 8000 palawan" becomes an 8,000
remittance to Nanay under Family Support & Remittance.

It reads five things out of one line: the amount (250, 250.50, 2,500), the
account (gcash, maya, cash, a bank, a card), the person ("kay nanay", "ni
kuya"), the type (sweldo and client mean money coming in, lipat means a
transfer), and the category.

It FILLS THE FORM rather than saving. A parser is a good guess, and a guess
about money should be visible before it is committed, so it reads back what it
understood and everything lands in the controls below where it can be
corrected. Save is the same button it always was.

**And it says when it does not know.** Founder finding on the emulator,
2026-09-18: typing "Electricity" selected Food & Dining. The prototype's
parser falls back to `'Food & Dining'` for any word it has never seen, so it
answers confidently instead of not answering. Measured before fixing: 37 of 60
common English money words did this, including `hospital`, `pharmacy`,
`mortgage` and `groceries`.

| The parser admitting it does not know |
|---|
| ![Unknown category](screens/log-sheet-unknown-category.png) |

Two changes, and the split between them is deliberate:

1. **The engine** now reports whether anything actually DECIDED the category,
   alongside the category itself. It still computes exactly what the prototype
   computes, so every ported vector is untouched.
2. **The sheet** applies the category only when something decided it, and the
   read-back says "category not recognized, so pick one below" instead of
   naming the fallback. An unrecognised line now leaves the picker exactly
   where the person left it.

The keyword map also gained the plain English words an English-first app needs.
That block is kept separate from the prototype's own 145 and labelled as ours,
so a future re-extraction of the prototype's list cannot silently delete it.

Seven words are left out ON PURPOSE, because guessing is the defect being
fixed and these cannot be read without context: `bill` (a restaurant bill and
an electricity bill are both "the bill"), `payment`, `credit` (already an
account hint), `phone` (the monthly bill, or the handset), `power` (the
utility, or a power bank), `game`, and `refund`. Each falls through to "not
recognized", which is the honest answer.

**When it happened.** Founder request, 2026-09-18. The When row defaults to
today and says so in words, and Change opens the calendar. A day that is not
today is drawn in the accent so it cannot be missed, and the sheet adds one
sentence: "The balance changes now, even though the entry is dated earlier."

| Backdated to Sep 15 | The picker |
|---|---|
| ![Log sheet backdated](screens/log-sheet-backdated.png) | ![Date picker](screens/date-picker.png) |

The future is deliberately not offered, and the greyed-out days after the 18th
in that picture are that rule. Logging moves the balance IMMEDIATELY, so a
future dated expense would take the money out today and file the entry under a
day that has not happened; the account and the ledger would then disagree until
it arrived. The prototype allows it. This is a named divergence rather than an
oversight, and it is the one place the two differ on dates.

Backdating also changed the confirmation AFTER saving. The Activity list groups
by day, newest first, so a backdated entry is not at the top: you land on a
screen whose first rows are today's, which reads exactly like it did not save.
The snackbar now says which day it went under, and only when that is not today.

Three things this sheet does deliberately:

1. **It says what it is about to do before you do it.** With an amount and an
   account chosen it reads "₱250.00 leaves Cash on Hand (Pitaka)." A transfer
   adds "Your net worth does not change."
2. **It says out loud that nothing is saved to the phone yet**, at the moment
   you save, rather than letting you find out tomorrow. There is no storage
   layer in `app/` yet.
3. **Saving lands you on Activity**, where the entry now is. Being left on a
   screen that does not show what you just saved is how somebody concludes it
   did not save.

**A quirk preserved and then made unreachable.** The prototype's
`addTransaction` debits the source of a transfer and credits the destination.
If the destination id matches no account, it debits and credits nobody, so
money disappears from net worth. The engine reproduces that faithfully, because
changing a number nobody decided to change is the worse error, and a vector
locks it. The defence is in the UI: the destination is picked from a list that
excludes the source, and Save refuses a destination that is not a real account.

Not migrated with it, named rather than implied: the foreign currency
converter, the cash denomination counter, receipt attachment, and quick-add for
categories. Each needs something `app/` does not have yet (an FX rate source, a
camera, a writable category store).

### Reports

The third tab, from `src/components/ReportsScreen.tsx`. Three sub-tabs, each
answering one question, and each shown here in both themes.

| Position, Gabi | Position, Hapon |
|---|---|
| ![Position dark](screens/reports-position-gabi.png) | ![Position light](screens/reports-position-hapon.png) |

| Performance, Gabi | Performance, Hapon |
|---|---|
| ![Performance dark](screens/reports-performance-gabi.png) | ![Performance light](screens/reports-performance-hapon.png) |

| Cash flow, Gabi | Cash flow, Hapon |
|---|---|
| ![Cash flow dark](screens/reports-cash-flow-gabi.png) | ![Cash flow light](screens/reports-cash-flow-hapon.png) |

**POSITION** is the balance sheet: what you own, what you owe, and the
difference. It takes no period on purpose, and the period picker is hidden
there rather than shown and ignored. A balance sheet is what you hold NOW;
offering "this week" beside it would promise last week's net worth, which needs
history the app does not keep.

**PERFORMANCE** is the income statement over a period, plus two ratios and a
month-end run rate. The run rate appears on the monthly view only, because the
prototype divides by the day of the MONTH whatever period is selected, so on
"this year" it would project a year's income onto a month and print a confident
nonsense figure.

**CASH FLOW** sorts the same money into operating, investing and financing.
Transfers are counted and then deliberately left out of the total, and the
screen says so: moving your own money between your own accounts is not cash
entering or leaving anything you own, and a 5,000 transfer that changes no
total reads like money the report lost.

**RECONCILIATION, the prototype's fourth tab, is not here yet**, and the screen
says so rather than leaving a gap somebody has to guess about. It is the only
one of the four that WRITES: it creates an adjustment transaction to force the
app's balance to match a real bank balance, and it changes a transaction's
status. A write path needs both halves tested, so it lands as its own step.

**The screens carry figures, the dot carries the explanation.** Founder
direction on reviewing the first build of this tab: "it seems too wordy,
instead we can put the explanation in the 'i' icon so the screens are still
neat looking". Every card that has something to teach now has a circled "i" in
its header, costing no vertical space, and the teaching lives there.

| The explainer behind a dot |
|---|
| ![Info sheet](screens/info-sheet.png) |

The rule, now recorded in `CLAUDE.md` so it governs Plan and Accounts too: a
figure and the one short line needed to READ it stay on the screen, everything
that TEACHES goes behind the dot. The exception is anything a person needs to
avoid a wrong conclusion. Two lines survived the cut on that test: "A housing
loan alone can do this." under a net worth of minus two hundred thousand, and
"Not counted above, on purpose." under a transfer that moves no total.

The mechanism is ported from the prototype's own `SectionInfoModal.tsx`. It
also filled a gap: two dots on Home showed a "coming soon" toast, which is
worse than no dot because it costs a tap and teaches that the dots do nothing.
Both now open real explainers.

Two defects this screen found, both worth recording because of HOW they were
found:

1. **A negative net worth rendered identically to a positive one.**
   `formatPeso` returns the absolute value by design, leaving the sign to the
   caller, and this screen was not adding it. A debt of 217,229.50 and savings
   of 217,229.50 were the same characters, separated only by colour, which
   fails for roughly one man in twelve and for any screenshot or printout.
   Caught by a widget test written before the screen was looked at.
2. **The period picker stacked into six full-width rows**, eating a third of
   the screen. A `Container` given an `alignment` and no width expands to its
   maximum constraint. Every test passed the whole time: the labels were
   present, the taps worked, the figures were right. **Caught only by looking
   at the render**, which is the entire reason that rule exists. There is now a
   test that measures whether the first two pills share a row.

Also not ported with it: CSV export (nothing in `app/` can write a file yet)
and the comparison toggle (previous period, budget, forecast), which needs
period-over-period history the app does not keep.

### Plan

The fourth tab, from `src/components/PlanScreen.tsx`. A HUB rather than a
screen: eight segments reached from a grid of tiles, which is the prototype's
own shape and the right one, because the eight have little to do with each
other beyond all being about the future.

| The hub | Budgets |
|---|---|
| ![Plan hub](screens/plan-hub.png) | ![Budgets](screens/plan-budgets.png) |

| Goals | Bills and payables |
|---|---|
| ![Goals](screens/plan-goals.png) | ![Bills](screens/plan-bills.png) |

**All eight segments are built**, at founder direction: Budgets, Bills and
payables, Goals, Decisions, Trackers, Calculators and Learn, plus the hub. Each
tile carries a live figure rather than being one of eight identical doors.

**Four write paths**, each of which says what it is about to do before it does
it: change a budget limit, add a goal, contribute to a goal, add an income
stream.

#### Two money changes, decided by the founder rather than taken quietly

Both were put to the founder with the actual figures before anything was
built.

**1. Budgets count THIS MONTH and ignore excluded entries.** The prototype
sums every matching expense ever logged, whatever its status. With the current
data that put Bills & Utilities at ₱5,680 of ₱6,500 and into "watch closely",
because it counted the duplicate Meralco charge marked *"charged twice, this
one is not mine to pay"*. It now reads ₱2,840, which is the truth. The second
half matters more over time: a limit that never resets is not a limit.

**2. Payday is not a bill.** The prototype's headline sums every upcoming row
under the label "Total Scheduled Bills", so the ₱32,500 payday is counted as
a bill and the figure reads ₱38,029 when the bills come to ₱5,529. Both
figures are now shown, side by side, and nothing stored changed.

#### Three defects found while building it

1. **A false claim in my own copy, caught by a test written to prove it.** The
   Add income stream sheet said the stream raises your Safe to Spend. It does
   not: `computeSafeToSpend` works out expected inflow and then never uses it,
   deriving the headline from liquid cash less reserves alone. That is the
   prototype's behaviour and the engine is vector-locked to it, so the copy was
   corrected rather than the arithmetic changed. **Whether expected income
   SHOULD raise Safe to Spend is an open question for the founder.**
2. **Safe to Spend read the frozen seed list.** A new income stream would have
   been stored, listed on Plan, and invisible to the one figure it feeds. Found
   while wiring the write path, before it could ship.
3. **A hardcoded subscription total that does not add up.** The prototype
   prints ₱3,288 beside a list that comes to ₱5,236.17 a month once an annual
   plan is divided by twelve. Computed here instead.

#### Salapify Academy

| Academy |
|---|
| ![Academy](screens/plan-academy.png) |

**Two things were wrong here on the first pass, and the founder caught both
from a screenshot of their own prototype.**

It was renamed to "Learn". That was not mine to do: "Salapify Academy" is the
product's own name for this, it is on the screen in the prototype, and a
rename nobody asked for is a change to the brand dressed up as tidying.

Worse, it shipped with **six courses I wrote myself**, because I never looked
in `src/data/` where the prototype's **thirty-two** actually live. That is a
straight breach of the rule this whole migration runs on: `src/` is the source
of truth, and content gets ported, not invented.

It now carries the real curriculum: **32 courses, 96 lesson sections, 24
knowledge checks, 9 categories**, extracted from `src/data/academyData.ts` by
`app/tool/extract_academy.ts` and generated into Dart by
`app/tool/gen_academy_dart.py`. Nothing was retyped, for the same reason the
fast-log keyword map was not: a hand-copied list that long is a list with a
typo in it.

`test/data/academy_integrity_test.dart` now asserts the counts, that no course
is a stub, that every quiz points at an option that exists, and that every icon
name resolves to a real glyph. Proved by dropping a course and watching it
report `Expected: <32> / Actual: <31>`.

The screen matches the prototype's: the progress track, the educational-only
notice, the startup guide roadmap card, the search box, and the nine category
chips. The disclaimer is deliberately NOT behind an info dot, which is the
exception the dot rule names: somebody who takes a lesson on investing for
licensed advice has drawn a wrong conclusion, and a wrong conclusion never goes
one tap away.

Still to come: the three long-form guides behind that roadmap card (Philippine
business registration, the SaaS and app store guide, the digital product
checklist), about 3,200 lines of written guidance between them. The card says
so rather than offering a button that opens nothing.

### Sheets

Ported from `src/components/`, 2026-09-18. Every one is opened through its real
route, so what is pictured is the modal as it actually appears over Home: same
grab handle, same 92% height, same dimmed app behind it. Dark only, which is
what the founder uses.

The tiny grey squares beside a category name are emoji. The render sandbox has
no emoji font; they draw correctly on the phone and are deliberately not
"fixed", because category icons are the user's own choice.

| Philippine Toolkit | Safe to Spend Details |
|---|---|
| ![Toolkit](screens/sheet-toolkit.png) | ![Safe to Spend](screens/sheet-safe-to-spend.png) |

| Add a debt | Add a debt, with the schedule |
|---|---|
| ![Add debt](screens/sheet-add-debt.png) | ![Add debt schedule](screens/sheet-add-debt-schedule.png) |

| Tax Calculator | Business Tax Simulator |
|---|---|
| ![Tax calculator](screens/sheet-tax-calculator.png) | ![Business tax](screens/sheet-business-tax.png) |

| Categories | |
|---|---|
| ![Categories](screens/sheet-categories.png) | |

**A saved debt does not survive a restart yet.** There is no storage layer in
`app/` at all: the store is seeded in memory and every write on it, the debt
included, is gone on the next cold start. The sheet says so in plain words when
it saves rather than letting somebody find out the next morning. Local storage
is its own migration step and lands with the Activity tab.

Where each one hangs off Home:

| Control on Home | Opens |
|---|---|
| The sparkle in the header | Philippine Toolkit, and the three tools behind it |
| DETAILS, or the info dot, on the Safe to Spend hero | Safe to Spend Details |
| The Debt quick action | Add a debt |

Rendered by `app/test/shots/screens_shot.dart`. To regenerate:

    cd app
    flutter test test/shots/screens_shot.dart --update-goldens

## How the money math is verified

Every ported calculation is locked to vectors produced by running the
prototype's OWN TypeScript, not by working the numbers out by hand:

    bun run <a script that imports src/utils/<engine>.ts>

Those figures become expectations in `app/test/engine/`. If a Dart figure ever
disagrees with the prototype, the port is wrong and the vector stands.

Covered so far: `safeToSpendEngine.ts`, locked by
`app/test/engine/safe_to_spend_golden_test.dart` across three vectors
(conservative, optimistic, and with recent spending).

## Money engines

Ported into `app/lib/core/money/`, locked by vectors in `app/test/core/money/`.

Every vector was produced by RUNNING the prototype's own TypeScript under bun
against the prototype's own inputs, never by working the formula out by hand
and never by reading the Dart back. If a Dart figure ever disagrees with the
prototype, the port is wrong and the vector stands.

| Prototype source | Dart | Covers | Tests |
|---|---|---|---|
| `safeToSpendEngine.ts` | `safe_to_spend.dart` | Safe to Spend, reserves, buffer, cash runway, payday cadence | 11 |
| `philippineFinances.ts` | `ph_tax.dart` | SSS, PhilHealth, Pag-IBIG, TRAIN withholding, 13th month and its 90k exemption, freelance 8% vs graduated | 24 |
| `businessTaxes.ts` | `business_tax.dart` | Sole prop and partnership, 8% / OSD / itemized / RCIT, VAT vs percentage tax, BIR form list | 14 |
| `loanCalculators.ts` | `loan.dart` | Diminishing and flat add-on amortization, extra payments, balloons, DSR against the BSP bands | 18 |
| `loanCalculators.ts` | `loan_products.dart` | Pag-IBIG, bank housing with its repricing stress test, car, salary, personal, business, debt consolidation | 16 |
| `loanCalculators.ts` | `debt_strategy.dart` | The credit card minimum payment trap under the BSP 3% cap, snowball against avalanche | 12 |
| `financialTruthEngine.ts` | `financial_truth.dart` | The control centre alerts, and the digital twin across eight shocks | 18 |

### Not ported yet, and named rather than implied

- `financialTruthEngine.ts`: `analyzeScamRisk` and
  `buildFinancialTruthMetadata`. Scam risk is keyword analysis over message
  TEXT rather than money math, so it has no vectors to lock and nothing to
  disagree with the ledger about. It migrates with the Health Check screen.
- `philippineFinances.ts` helpers: remittance fee estimation, cash
  denomination counting, and the Taglish reminder text.
- `generateInstallmentAmortization`: a two-line adapter that turns a stored
  installment plan into a schedule. It needs the InstallmentPlan model the
  Plan tab will bring, and `calculateAmortization` underneath it is already
  locked.

### Quirks preserved on purpose

Three places where the prototype does something surprising and the port keeps
it, because changing a number nobody decided to change is the worse error:

1. A **balloon payment overruns the stated term.** 900,000 at 8% over 36
   months with a 200,000 balloon runs 45 months, because the schedule keeps
   amortising to zero instead of stopping and charging the balloon.
2. **VAT contributes nothing.** A VAT registered business shows zero business
   tax, because the engine treats VAT as pure pass-through. That is a
   cash-flow view, not a filing figure.
3. **The 13th month gross is rounded in one function and not the other.**
   `calculateEmployeeTaxDeductions` rounds it, `calculate13thMonthPay` does
   not. Making them agree would move a figure on a screen.
4. **Job loss makes the runway look BETTER.** Survival mode cuts spending by a
   quarter, and the runway only reads cash against spending, so it rises from
   3.95 months to 5.27. The damage is in the buffer impact and net worth. Any
   screen showing this scenario must not lead with the runway, or it will tell
   somebody who just lost their job that things improved.
5. **The credit card payoff schedule is thinned after month 36**, keeping every
   sixth month, and `monthsToPayoff` is read off the last row KEPT. Once
   thinning starts it can under-report by up to five months, so a screen should
   say "about".
6. **Consolidation compares against a flat 18 month estimate** of the existing
   debts' interest, not a real payoff simulation, which flatters consolidation
   whenever those debts would have cleared sooner.

## Brand mark

The founder supplied the logo on 2026-09-18: a ribbon "S" wrapped around a peso
coin, with a small bar chart, on a teal and navy plate. The artwork is theirs
and is unchanged. Only the COLOUR was brought onto the Salapify palette, since
teal sits on the opposite side of the wheel from Hapon and Gabi.

Recoloured by mapping LUMINANCE onto real palette colours rather than tinting.
The mark has three tonal layers (dark plate, mid ghost strokes, near-white
ribbons) and a tint flattens them into mud; a ramp keeps every offset stroke,
every anti-aliased edge, and the plate's own diagonal gradient.

| | |
|---|---|
| Original, then rust, Gabi and hero variants | ![variants](screens/logo-variants.png) |
| The shipped icon on both theme backgrounds | ![on both themes](screens/logo-on-both-themes.png) |

**Rust ships.** It carries Hapon's accent `#B03C09`, and it holds the most
contrast between plate and ribbon, which is what decides whether an icon still
reads at 48dp. The Gabi variant is the closest runner-up. The hero variant is
the weakest: cream ribbons on amber lose contrast at small sizes.

Where it is used:

    android/.../mipmap-*/ic_launcher.png     the launcher icon, five densities
    android/.../drawable-*/launch_image.png  the launch screen, five densities
    app/assets/brand/salapify_logo.png       in app, currently the Home header

The launch screen also stopped being white. It now uses Salapify's own
background, resolved per theme through `values/colors.xml` and
`values-night/colors.xml`, so opening the app at night no longer starts with a
white flash.
