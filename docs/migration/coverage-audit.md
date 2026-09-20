# Prototype to Flutter coverage audit

Founder direction, 2026-09-18: "check everything, make sure we migrate
everything from the prototype google ai studio to the current build. Lets
complete first the features and content, then we can redesign the look after."

This file is the answer. It is the authoritative list of what has crossed from
`src/` into `app/` and what has not, file by file, with the evidence. The
migration table in `README.md` says which TAB is done; this says which
FEATURE and which piece of CONTENT is done, which is a different and harsher
question.

## Why this exists

The Academy shipped with six courses I invented instead of the prototype's
real thirty two. Every test passed, because I wrote the tests against my own
invention. The root cause was not carelessness about the feature. It was
method: I read `src/components/AcademyView.tsx`, saw it render a list, built a
list, and never opened `src/data/academyData.ts`, where the actual curriculum
lived.

So this audit reads all three directories, not just the component tree:

- `src/components/` (51 files), what the user can see and tap
- `src/utils/` (16 files), the engines behind those screens
- `src/data/` (6 files), the CONTENT, which is where the Academy was hiding
- `src/context/FinancialContext.tsx` (3,074 lines), every write the app can do

Totals, for scale. The prototype is 41,484 lines across those directories plus
`types.ts` and `App.tsx`. `app/lib` is 20,331 lines. That ratio is not the
completion percentage, because Dart is more verbose than TSX and because some
prototype code is dead, but it is the right order of magnitude to hold in mind:
roughly half the product exists.

## How to re-run this audit

Nothing here was judged by eye. Each row below can be rechecked:

    # every prototype component, by size
    ls src/components/*.tsx | xargs wc -l | sort -rn

    # is a feature present in the Flutter app at all
    grep -rli "<FeatureName>" app/lib/

    # what a prototype screen actually says on it
    grep -oE "(>|')[A-Z][A-Za-z0-9 ,&%.'-]{5,46}(<|')" src/components/X.tsx | sort -u

    # the same for the Flutter screen, then diff the two lists
    grep -ohE "'[A-Z][A-Za-z0-9 ,&%.-]{5,46}'" app/lib/screens/x/*.dart | sort -u

The last pair is the one that catches an Academy. A screen can be "ported" and
still be missing half of what it says.

## 1. The five tabs

**Sections 1 to 4 are a snapshot taken on 2026-09-18 and are now out of date
in places.** They are left as written, because the point of the audit was to
record what was true when it was run, and quietly editing a finding into
agreement with today is how an audit stops being one. The current state is in
"Progress against that order" below, which is dated and supersedes anything
above it. Where a row here says something is missing, check there first.

| # | Tab | Prototype | Flutter | Verdict |
|---|-----|-----------|---------|---------|
| 1 | Home | `Header`, `HeroPanel`, `BudgetPulseCard`, `QuickActions`, `DebtBeamCard`, `ComingUpCard`, `LatestTransactions` | `lib/screens/home/` | Cards all present. Four of its buttons open a "coming soon" note (see 4) |
| 2 | Activity | `LedgerScreen`, `LogSheet`, `TransactionDetailModal` | `lib/screens/activity/`, `lib/features/log/` | Reading and logging done. The correction write path is missing (see 3) |
| 3 | Reports | `ReportsScreen` (1,954 lines) | `lib/screens/reports/` (958) | 3 of 4 tabs. Reconciliation missing entirely, plus several Performance and Cash flow views (see 3) |
| 4 | Plan | `PlanScreen` + `AcademyView` + 3 trackers | `lib/screens/plan/` | All 8 segments present. Academy carries the real 32 courses. The 3 long-form guides are missing (see 3) |
| 5 | Accounts | `AccountsScreen`, `BankCard`, `InvestmentsView` | none | Not started. The tab shows a placeholder |

## 2. Not started at all

These have no Flutter equivalent of any kind. Sorted by prototype size, which
is a rough proxy for how much is in them.

### Screens and major views

| Prototype file | Lines | What it is |
|---|---|---|
| `CollaborationHub.tsx` | 1,548 | Shared spaces, members, roles, approvals, expense splits, audit log |
| `PHBusinessStartupGuide.tsx` | 1,488 | Academy long-form guide: entities, roadmap, checklist, experts |
| ~~`DebtCalculatorsView.tsx`~~ | 1,339 | PORTED 2026-09-18, all nine calculators |
| `InvestmentsView.tsx` | 1,114 | Holdings, allocation, market data adapters, PH principles |
| ~~`AccountsScreen.tsx`~~ | 986 | PORTED 2026-09-18, less the holdings tracker |
| `RemindersModal.tsx` | 932 | Reminder settings, notification list, simulated triggers |
| `SaaSAppStoreGuide.tsx` | 926 | Academy long-form guide, nested inside the startup guide |
| `DigitalProductLaunchChecklist.tsx` | 833 | Academy long-form guide, nested inside the SaaS guide |
| `PhilippineFeaturesModal.tsx` | 807 | Remittance, 13th month planner, payday routines, household ambag, cash count |
| `BillsModal.tsx` | 747 | Bill list, add, edit, mark paid |
| `YourSetupModal.tsx` | 594 | Profile, payday, starter packs, category manager entry |
| ~~`InstallmentsView.tsx`~~ | 565 | PORTED 2026-09-18, less the amortisation table |
| `SettingsModal.tsx` | 528 | Theme, profile, data, reset |
| `PanChatModal.tsx` | 500 | The AI mascot's chat |
| `SplitBillModal.tsx` | 493 | Split a bill between people, settle it |
| ~~`DebtScreen.tsx`~~ | 427 | PORTED 2026-09-18, with the payment write path |
| `OnboardingFlow.tsx` | 370 | First run: name, payday, starter pack |
| `HealthCheckModal.tsx` | 352 | Health insights against the user's numbers |
| `SavingsInvestmentModal.tsx` | 317 | Savings and investment planner (5th calculator) |
| `OfflineRegistryModal.tsx` | 267 | Offline institution registry |
| `TransferModal.tsx` | 257 | Move money between own accounts |
| `NotificationToast.tsx` | 175 | In-app toast for reminders |
| `BankAmortizationTable.tsx` | 691 | Full amortization table (the app has a 190 line version) |
| `ErrorBoundary.tsx` | 63 | Catches a render crash instead of a white screen |

### Engines

| Prototype file | Lines | Status |
|---|---|---|
| `panAiEngine.ts` | 1,101 | Not ported. Query parsing, health score, response generation |
| `healthCheckEngine.ts` | 505 | Not ported. `generateHealthCheckInsights` |
| `notificationEngine.ts` | 456 | Not ported. Reminder evaluation, defaults, chime |
| `printStatement.ts` | 388 | Not ported. Statement and amortization printing |
| `panKnowledgeRepository.ts` | 376 | Not ported. App feature knowledge, system limitations |
| `collaborationEngine.ts` | 316 | Not ported. Access checks, roles, split shares, debt simplification |
| `investmentProviders.ts` | 269 | Not ported. Market data adapters, portfolio summary |
| `currencies.ts` | 60 | Not ported. `toPhp()` in `reports.dart` is the seam left for it |
| `logos.ts` | 39 | Not ported. Institution logo URLs |

Partially ported engines, meaning the file exists in `app/lib/core/money/` but
does not cover everything its prototype counterpart does:

| Prototype | Flutter | Missing |
|---|---|---|
| `philippineFinances.ts` | `ph_tax.dart` | `estimateRemittanceFee`, `calculateCashTotal`, `generateTaglishReminderMessage`, and the `REMITTANCE_CHANNELS`, `INITIAL_REMITTANCES`, `INITIAL_PAYDAY_TEMPLATES`, `INITIAL_HOUSEHOLD_AMBAG` content |
| `loanCalculators.ts` | `loan.dart`, `loan_products.dart`, `debt_strategy.dart` | `generateInstallmentAmortization` |
| `financialTruthEngine.ts` | `financial_truth.dart` | `analyzeScamRisk`, `buildFinancialTruthMetadata` |

### Content

| Prototype file | Lines | Status |
|---|---|---|
| `data/initialCollaborationData.ts` | 332 | Not ported. Spaces, members, splits, audit entries |
| `data/initialInvestments.ts` | 240 | Not ported. Seed holdings |
| `data/categoryPacks.ts` | 59 | Not ported. The four starter packs (employee, freelancer, student, OFW) that onboarding applies |
| `data/academyData.ts` | 1,501 | PORTED, 2026-09-18, all 32 courses |
| `data/categories.ts` | 273 | PORTED, all 21 categories with subcategories |
| `data/initialData.ts` | 923 | PORTED except `INITIAL_RECONCILIATION_HISTORY` (1 record), which needs a `ReconciliationRecord` model that does not exist yet |

Seed counts verified one by one, prototype against `app/lib/data/seed_data.dart`:
accounts 11 = 11, debts 5 = 5, budgets 7 = 7, upcoming 4 = 4, goals 3 = 3,
bills 10 = 10, installments 3 = 3, income streams 4 = 4, categories 21 = 21.
Transactions are 13 in the prototype and 16 in Flutter: three rows were added
deliberately so the Activity screen can be reviewed rather than merely
rendered, and the reason is written in `seed_data.dart`.

## 3. Missing INSIDE screens that are called done

This is the section the Academy failure exists to produce. A tab marked built
can still be missing content, and only a label by label comparison finds it.

### Reports

Verified by extracting every section label from `ReportsScreen.tsx` and from
`reports_screen.dart` and diffing the two lists.

- **Reconciliation, the whole fourth tab** (`ReportsScreen.tsx` line 1633 to
  the end). Statement balance alignment, duplicate detection, the
  reconciliation history log, "Confirm and record reconciled", and the
  traceable adjustment entry that posts the variance as "Adjustments and found
  cash" or "Adjustments and write-offs" rather than silently editing an
  account. This is the only Reports tab that WRITES, which is why it was
  deliberately deferred, and it is the single largest hole in a screen we call
  finished.
- **Performance and cash flow comparison modes** (line 808). The prototype
  offers "Previous Period" and "Actual vs Forecast" against a budget target.
  Flutter has neither.
- **Business and side hustle performance** (line 1097), a separate section on
  the Performance tab.
- **Net worth trend bars** (line 914), Q1, Q2, Q3 and current, on Position.
- **Cash flow by account and by entity** (lines 1509 and 1556). Flutter has the
  category view only.
- **Export breakdown** (line 1142).

### Activity

- **The correction write path.** The prototype's insight rows offer "Review and
  adjust" and "Apply correction", which write an adjustment. Flutter reads and
  filters, and its only write is logging a new entry.
- **Consolidated books header.** The prototype names the view "Consolidated
  Books" when the profile filter is "all", so a person can tell at a glance
  they are looking across every entity.

### Plan

- **The three long-form Academy guides**, 3,247 lines between them. The Academy
  segment currently shows a roadmap card where the startup guide belongs.
- **The savings and investment planner** (`SavingsInvestmentModal.tsx`:
  emergency fund, goals, retirement, inflation impact). Both calculator lists
  have four entries, so this looks complete and is not: Flutter dropped the
  planner and put Safe to spend in its place. Safe to spend is a genuinely
  useful entry and should stay. The planner is simply missing.

### Home

Four header and hero buttons exist, are tappable, and open a "coming soon"
note: Collaboration, Reminders, Settings, Health Check. They are counted here
rather than in section 2 because the ENTRY POINT is built and only the
destination is missing.

## 4. The two structural gaps

These are not screens. They are conditions that affect everything above, and
both are founder decisions rather than routine engineering.

### Nothing persists

`app/lib/state/financial_state.dart` holds everything in memory. There is no
`shared_preferences`, no file storage, no AsyncStorage equivalent, and no
backup format. Every write in the app says so on screen today. Close the app
and every logged entry, budget change, goal contribution and new income stream
is gone.

This is STOP condition 2 in `CLAUDE.md` (data and migration) and it needs a
founder decision on the storage shape before it is built, because the choice
of format is the thing that is expensive to change later.

### The write surface is 11 actions out of roughly 90

`FinancialContext.tsx` exposes about 90 members. `FinancialState` has 11
mutations: `toggleTheme`, `setScenario`, `setActiveProfile`,
`setMovementFilter`, `addDebt`, `logTransaction`, `setBudgetLimit`, `addGoal`,
`contributeToGoal`, `addIncomeStream`, `markUpcomingPaid`.

Missing whole families, each one gating several screens above:

- transactions: update, delete, change status, create adjustment
- accounts: add, update, delete
- bills: add, update, delete, mark paid
- installments: add, update, delete, record payment, record extra payment
- debts: record payment, toggle settled
- budgets: add, delete
- categories: add and delete main, add and delete subcategory
- goals and upcoming: add upcoming, delete upcoming
- payday, onboarding, starter packs, reset to sample data
- reminders, notifications, investments, collaboration, splits, audit log

## 5. Recommended order

Features and content first, look afterwards, per the direction. Each step is
sized to be one batch with its own render and its own tests.

1. **Tab 5, Accounts.** It is the last unbuilt tab and the only one still
   showing a placeholder. `AccountsScreen` plus `BankCard`. `InvestmentsView`
   rides with it or splits out, depending on how big it gets.
2. **The account write paths** that Accounts needs: add, update, delete, plus
   transfer between own accounts. This is where `TransferModal` lands.
3. **The Debt screen.** `DebtScreen`, `DebtCalculatorsView`, `InstallmentsView`.
   The engines are already ported and vector locked, so this is mostly screen
   work against maths that is already proven.
4. **Reports reconciliation**, and with it the Activity correction path, since
   both write the same adjustment.
5. **Bills, installments and reminders**, which are one workflow across
   `BillsModal`, `RemindersModal` and `notificationEngine`.
6. **Storage.** Founder decision first. Everything above is more valuable once
   it survives closing the app, and doing it after the shapes settle means one
   migration instead of six.
7. **Onboarding, starter packs and Your Setup**, which is what makes the app
   usable by somebody who installed it ten seconds ago.
8. **Pan**, the mascot, engine and chat.
9. **Health Check**, **Philippine features**, **Settings**, **Collaboration**,
   **the three Academy guides**, in whatever order the founder prefers. None of
   these blocks another.

Steps 1 to 5 are the ones that finish the product as the prototype defines it.
Steps 6 onward are the ones that make it a real app somebody else can install.

### Progress against that order, 2026-09-20

Steps 1 to 6 and step 8 are done, and the two sentences that used to stand
here saying otherwise were three days out of date. Accounts and its write
paths, the debt register with its payment path, all nine loan calculators,
instalment plans, Reports' Reconciliation tab with Activity's correction
path, bills, instalments and reminders, storage, and Pan.

**Storage is built**, which the previous version of this note said was
waiting on a founder decision. One file on the device in the prototype's own
backup format, written atomically with a previous generation kept.

**Step 7, onboarding and starter packs, is the largest unbuilt piece**, and
CLAUDE.md's reading of D19 puts it in the public readiness phase that lands
after the screens rather than before them. Starter packs additionally need
the founder first, because the prototype's version REPLACES every budget
limit with no confirmation.

**Step 9 is what is left otherwise**: Health Check, Philippine features, the
three Academy guides. Collaboration is deliberately not being built and the
reason is recorded in `home_header.dart`.

#### Health Check, and why it is not a simple port

Its engine (`src/utils/healthCheckEngine.ts`, 505 lines, 12 insights) cannot
cross over in its current shape, and the reasons are worth writing down
rather than rediscovering:

- **Four of the twelve are computed off an invented spending rate.** Line 61
  reads `Math.max(10000, totalExpenses30d > 5000 ? totalExpenses30d : 28000)`,
  so anybody who has spent under 5,000 in the last thirty days, which is
  every new install, gets a 28,000 a month burn they never had. It feeds cash
  runway, the emergency fund gap, the savings rate and the payday crunch.
- **A salary is invented too.** Line 131, `(payday.expectedIncome || 32500) * 2`,
  produces a 65,000 monthly income for somebody who has set no payday. D19
  says no payday set is the ordinary state of a new user, not an edge case.
- **One insight is entirely hardcoded.** `forecast_reliability` reports "89%
  Accuracy" and "your predictions are 89% accurate based on your past payment
  history" with nothing computed at all, on an empty ledger included.
- **Two more constants have no source**: an 8 percent minimum payment on
  every debt (line 130), and "half your liquid cash is an emergency fund"
  when no emergency goal exists (line 176).
- **The advice names products and quotes returns.** Insight 12 tells the
  reader to move their emergency cash to named digital banks "at 4.5% to 5%
  p.a." and prices the gap at `traditionalCash * 0.045`. That is the same
  content four Pan tests already fail the build over, and it would arrive on
  a different screen where `pan_bans.dart` does not reach. That filter is
  scoped to Pan's output, which is a guard until the content moves.
- **Every insight carries a confidence percentage** between 86 and 96, mostly
  hardcoded. A "94% confident" label beside an invented figure is worse than
  the figure on its own.

This is not a list of things to fix quietly while porting. Several are
founder calls about what the app is willing to claim, so Health Check waits
on that rather than on effort.

## What this audit does NOT claim

It checked presence and content, not correctness. A row marked ported means the
feature and its content exist in `app/`, not that every number matches the
prototype to the centavo. That guarantee comes from the golden vectors in
`app/test/core/money/`, and it exists only for the engines that have them.

### And a blind spot it had, found on 2026-09-18

**It compared RECORD COUNTS, not FIELDS**, and that hid a real gap. The
instalment seed is listed above as ported, three records against three, which
was true and almost useless: `InstallmentPlan` in `app/` held four of its
twenty two fields. Three stubs count the same as three plans. The provider,
the principal, the rate, how the rate is quoted, the term, the maturity date,
the running balance, the principal and interest split and the extra payment
history were all absent while this file said the data had crossed over.

That happened because the class had only ever been read by Safe to Spend,
which needs a monthly amount and nothing else, so nothing was broken and
nothing complained. It surfaced only when a screen was built that needed the
rest.

The lesson generalises past this one class: a count is the weakest possible
check on a port. Anywhere this file says a data file is ported on the strength
of a matching number of records, treat that as "the rows exist" and not as
"the rows are complete". The remaining unported data files
(`initialCollaborationData.ts`, `initialInvestments.ts`, `categoryPacks.ts`)
carry no such risk, because they are absent rather than partial, but the
models behind any FUTURE port should be diffed field by field against
`src/types.ts` before the port is called done.

It also did not judge the look of anything, deliberately, because the founder
asked for features and content first and a redesign after.
