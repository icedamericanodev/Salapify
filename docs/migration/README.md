# Prototype to Flutter migration

The Google AI Studio prototype in `src/` is the source of truth. This folder
tracks what has crossed over into the Flutter app in `app/`, with a picture of
every screen so it can be reviewed without a phone.

Founder direction, 2026-09-18: rebuild `app/` from zero against the prototype,
and migrate the tabs in the prototype's own order.

## Migration order

The prototype's tab order, finished one tab at a time including its modals.

| # | Tab | Prototype source | Status |
|---|-----|------------------|--------|
| 1 | Home | `Header`, `HeroPanel`, `BudgetPulseCard`, `QuickActions`, reminders banner, `DebtBeamCard`, `ComingUpCard`, `LatestTransactions`, `PanFloatingButton` | Built to match the prototype |
| 1b | Home's sheets | `SafeToSpendModal`, `AddDebtModal`, `BankAmortizationTable`, `TaxCalculatorModal`, `BusinessTaxSimulatorModal`, the category manager | Built and reachable from Home |
| 2 | Activity (Ledger) | `LedgerScreen`, `LogSheet`, `TransactionDetailModal` | Entries list built. Detail and Log sheet next |
| 3 | Reports | `ReportsScreen` | Not started |
| 4 | Plan | `PlanScreen`, `AcademyView`, `CalculatorLibrary`, trackers | Not started |
| 5 | Accounts | `AccountsScreen`, `BankCard`, `InvestmentsView` | Not started |

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
