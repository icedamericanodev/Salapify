# Current Features

Sprint 0 engineering audit, 2026-07-10. A factual inventory of every user
facing feature, its entry point, maturity, and test coverage.

Test coverage baseline: 17 test suites exist in mobile/__tests__/ (313 tests,
all passing as verified during this audit, jest-expo). All tests target pure
lib/ modules. There are zero tests for screens, components, context, hooks,
or widgets.

Maturity scale: polished (edge cases handled, a11y or animation work
present), functional (works, rough edges), rough, stub.

## Core money features

| Feature | Entry point | What it does | Maturity | Tests |
| --- | --- | --- | --- | --- |
| Home dashboard | app/(tabs)/index.js (922 lines) | Daily open screen: greeting with Pan mascot moods, safe to spend per day with cycle bar, net worth hero with peak tracking pill, a 48 hour post payday Sweldo Plan flow (log salary, allocate savings, check budget), weekly coach check in, receivables and payables summaries, upcoming bills with running balance, days to payday. | Polished | Screen: none. Math via analytics, allocation, and coach test suites |
| Budget and logging | app/(tabs)/budget.js (459 lines) | Monthly limit bar with optional carry over, top category breakdown with Pro caps, week chain, quick add buttons with remembered account and category, custom entry via the shared LogSheet, recent list with receipt viewer, per row delete with undo toast. | Polished | Screen: none. analytics.test.js covers carry over math |
| Global entry sheet | components/LogSheet.js (735 lines) | The one add entry sheet opened from the FAB on every tab: expense or income, quick adds, two level category chips, backdating, per transaction foreign currency with live FX prefill, receipt photo attach with OCR prefill, undo, haptics. | Polished | None directly; fxrates.test.js covers the rate math |
| Debts | app/(tabs)/debts.js (779 lines) | Debt tracker with snowball versus avalanche toggle, focus debt, short and long term grouping, credit card fields (statement day, grace days, limit), a payment engine that splits interest and principal, debits the chosen account, writes payment plus transaction records, SOA forecast and share, payoff celebration. | Polished | Payment split via analytics.test.js; lib/soa.js forecasts untested |
| Payables (people I owe) | app/payables.js (748 lines) | Utang ledger grouped by person: add and edit with an optional borrowed into account cash leg, partial payments, mark paid posts a real expense or transfer, payment removal and delete reverse posted transactions, celebration on payoff. | Polished; heavy duplication with receivables | None |
| Receivables (owed to me) | app/receivables.js (769 lines) | Mirror of payables plus bilingual (English and Tagalog) share reminders, the split a bill entry point, a lending cash leg, and collect posting income or transfer in with reversible txnId links. | Polished | None |
| Person detail | app/person.js (365 lines) | Per person utang view: still owed total, contact card, cross utang payment history, edit person, share reminder or a plain text statement of account. | Polished | statement.test.js |
| Split a bill | app/split.js (447 lines) | Barkada bill splitting: friends with ledger suggestions, per share adjustment with the payer absorbing rounding, confirm writes one expense, an optional debt record row, and one receivable per friend (find or create person). | Polished; centavo rounding math is correctness sensitive | None (flagged gap) |
| Accounts | app/accounts.js (807 lines) | Accounts (cash, savings, checking, ewallet with 16 PH bank brand badges) and an assets manager; balance edit posts a recorded adjustment or offers to log the difference as an expense; transfers between accounts as non spending records; deletion cleans dependent settings. | Polished | None (reconciliation flow untested) |
| Categories | app/categories.js plus lib/categories.js | Two level category tree with per month spend and Pro monthly cap bars; the delete flow reassigns or uncategorizes tagged entries atomically and promotes children. | Polished | categories.test.js |
| History | app/history.js (493 lines) | Virtualized full transaction list with period selector and text search (prefillable from global search); edit reverses the old balance effect and applies the new; record rows read only; tailored delete confirms; receipt viewer. | Polished | Indirect via format.test.js |
| Global search | app/search.js plus lib/search.js | Deferred value search across transactions, utang, debts, goals, notes, and accounts; AND token matching, amount matching in raw, rounded, and formatted forms, grouped results routing to owning screens. | Polished | lib/search.js has no test (flagged gap) |
| Goals | app/goals.js (261 lines) | Savings goals with progress, a save per month pacing line, Filipino templates (emergency, Pasko, travel, health). Does not move money (disclosed). | Functional to polished (no completion celebration; invalid date input coerced silently) | goalPace via analytics.test.js |
| Treats | app/treats.js plus lib/treats.js and components/TreatCard.js | Temptation bundling habit tracker: up to 3 treat and action pairs, rolling window check ins, lifetime counter, templates. Stored in settings.treats. | Polished | treats.test.js |
| Recurring | app/recurring.js plus the posting engine in context/AppData.js | Recurring bills and income posting one transaction per month with double post protection (lastPosted month key); optional account link moves balances; free limit of 5 then a Pro wall. | Polished | The posting engine itself has no dedicated test (it lives in AppData.js, untested) |
| Notes | app/notes.js (461 lines) | Money notepad with a built in no eval math engine (tokenizer plus recursive descent parser, percent, parens, currency stripping) showing live calculations per note. | Polished | evaluateMath is exported but has no test (flagged gap for a hand rolled parser) |
| Insights | app/(tabs)/insights.js (917 lines) | Free: ranked Do Next card, honest win, income versus spend bars, spend composition, net worth trend snapshots, committed and free split, runway, utang aging, goal pace. Pro: health score, 6 month trend, forecast, movers, weekday pattern. | Polished | analytics, coach, and chartgeom test suites cover the math |
| Reports | app/reports.js plus lib/statements.js | Balance sheet (identity checked), income statement, cash flow (operating, investing, financing, with a reconcile flag), plus a Pro debt free projection comparing avalanche versus snowball. | Polished | statements.test.js, analytics.test.js |

## Calculators (Tools tab, app/(tabs)/tools.js, all 9 wired)

| Calculator | Entry point | What it does | Maturity | Tests |
| --- | --- | --- | --- | --- |
| Income tax (8 percent versus graduated) | app/tax-calculator.js plus lib/phtax.js | Self employed comparison of the flat 8 percent versus graduated plus 3 percent percentage tax, OSD versus itemized, VAT threshold warning, BIR form guidance. | Polished | phtax.test.js |
| Year end tax check | app/year-end-tax.js | Employee annualization: refund versus shortfall verdict, effective rate, the 90k bonus ceiling. | Polished | phtax.test.js |
| Take home pay | app/salary-calculator.js | Net pay from monthly gross: SSS, PhilHealth, Pag-IBIG, withholding, marginal rate, per cutoff, month, or year toggle. | Polished | phtax.test.js |
| 13th month | app/thirteenth-calculator.js plus lib/thirteenth.js | PD 851 prorated 13th month with the tax free and taxable split at the 90k ceiling. | Polished | Only the ceiling constant is asserted; lib/thirteenth.js math has no dedicated test (gap) |
| Contribution checker | app/contribution-calculator.js | SSS, PhilHealth, and Pag-IBIG employee versus employer table for any salary. | Polished | phtax.test.js |
| Loan calculator | app/loan-calculator.js plus lib/loan.js | Amortization, add on versus diminishing, quoted versus effective annual rate (bisection solver), full schedule, early payoff savings. | Polished | lib/loan.js has no dedicated test (gap); indirectly exercised by bnpl.test.js |
| BNPL true cost | app/bnpl-calculator.js plus lib/bnpl.js | Unmasks zero interest installments: total paid, extra over cash, the real annual rate on net credit including upfront fees. | Polished | bnpl.test.js |
| Currency converter | app/currency-converter.js plus lib/currencies.js, lib/fxrates.js, hooks/useFxRates.js | Reference converter over 20 currencies with cached live rates (12 hour cache, silent offline fallback). Note: the UI attributes exchangerate-api.com while the code calls open.er-api.com. | Polished | fxrates.test.js |
| BIR filing dates | app/tax-deadlines.js plus lib/taxdeadlines.js | The next 6 self employed BIR deadlines with days away and an 8 percent option toggle. Does not apply weekend or holiday shifting even though lib/holidays.js exists. | Polished | taxdeadlines.test.js |

Calculator wide risk: lib/phtax.js hardcodes RATES_YEAR 2026 with one flat
set of SSS, PhilHealth, Pag-IBIG, and TRAIN constants; no per year
versioning, so all five payroll and tax tools go silently stale the year any
statutory rate changes. lib/holidays.js covers Chinese New Year only 2026 to
2028.

## Assistant, intelligence, and content

| Feature | Entry point | What it does | Maturity | Tests |
| --- | --- | --- | --- | --- |
| Pan chat assistant | app/pan.js plus lib/pan/ (ask, intents, normalize, resolvers, respond) | Fully rule based on device Q and A, no LLM and no network. Taglish normalization, about 14 data intents plus 4 tool pointers scored by keywords with one edit fuzzy matching, 5 regulatory guardrails (investment, loan, tax, legal, insurance decline and redirect). Read only: resolvers call analytics, recap, and soa and return facts; it never writes data. Conversation is in memory only. | Polished architecture; brittle to unanticipated phrasing by nature | No tests for any pan module (flagged gap) |
| Coach (Do Next) | lib/coach.js, surfaced on Home and Insights | A priority ranked rule engine (cash crunch 100 down to lesson 45) with tone guardrails: never suggests cutting essentials, survival before goals, no nagging on new installs, one honest win gated on healthy logging. | Polished | coach.test.js |
| Week recap and chain | lib/recap.js, components/WeekChain.js, WeekRecap.js, RecapShare.js | A non resetting 7 day logging chain with comeback messaging; a monthly recap object and text; a shareable Skia drawn PNG recap card with a hide amounts privacy toggle and a text fallback, behind an error boundary. | Polished | recap.test.js; the share components are untested |
| Learn (lessons) | app/learn.js plus lib/lessons.js | 12 hardcoded PH specific financial literacy lessons, a lesson of the day rotation, read progress in settings.lessonsRead. | Polished; content embeds live rules that can date | None (content only) |
| Mindset | app/mindset.js | Daily lesson pointer, a 3 question impulse check, a small wins list (data.wins). | Functional to polished | None |

## Data capture and documents

| Feature | Entry point | What it does | Maturity | Tests |
| --- | --- | --- | --- | --- |
| Receipts and OCR | lib/ocr.js, lib/receipt-parse.js, lib/receipts.js; surfaced in LogSheet, history, budget | ML Kit native text recognition wrapped to never throw (a missing module degrades to manual entry); a pure heuristic parser extracts merchant, date, and total with ranked keyword detection and low confidence signaling; photos are copied into an app owned receipts folder with relative paths and orphan cleanup on delete and restore. Receipt photos are not included in backups (disclosed). | Polished | No tests for ocr, receipt-parse, or receipts (receipt-parse is pure and very testable) |
| Personal SOA (utang statement) | lib/statement.js | A shareable plain text statement or reminder per person, English or Tagalog, honoring paid flags. | Polished | statement.test.js |
| SOA forecast (cards and loans) | lib/soa.js plus lib/banks.js and lib/holidays.js | Forecasts statement cut, due date (weekend and PH holiday adjusted), minimum due, and late interest; shareable text. banks.js is a static list of about 16 PH banks and e-wallets with brand colors. No bank connectivity anywhere; all figures come from user entered data. | Polished | No test for soa.js or holidays.js (flagged gap: date and interest forecast math) |
| Financial statements engine | lib/statements.js | Balance sheet, income statement, and cash flow, all pure with reconciliation flags. | Polished | statements.test.js |

## Platform features

| Feature | Entry point | What it does | Maturity | Tests |
| --- | --- | --- | --- | --- |
| Notifications | lib/notifications.js, settings UI in app/notifications.js | Local only expo-notifications: a daily log nudge (14 one shots, skipped if already logged), payday (the next 6), bill reminders (3 days before plus the due morning, bank day adjusted), and utang collection follow ups. Full wipe and rebuild rescheduling with a stale run token. Risk: one shot windows run dry if the app is never opened. | Polished | No test (scheduling logic untested) |
| Android widgets | widgets/SalapifyWidgets.js and widget-task-handler.js, configured in app.json | Ten home screen widgets (Budget, Net Worth, Spent Month, Sweldo, Owed To You, You Owe, Saved Month, Top Category, Goal, Streak) rendered headlessly from a direct read of the salapify_data_v2 blob, every path guarded to safe zeros. Risk: the net worth and income math is duplicated from lib/analytics.js and can drift. | Functional to polished; Android only | No test |
| Onboarding | components/Onboarding.js | Welcome, currency chips plus budget, an optional nightly nudge with the OS permission, and a start choice (clean slate with a confirmed wipe versus explore sample data). Restore aware. | Polished | None |
| App lock | components/LockGate.js, toggle in app/notifications.js | Biometric only overlay via expo-local-authentication; no PIN, no stored secret; auto disables if no biometrics are enrolled (anti lockout); a 60 second background grace window. A soft privacy gate, not strong security. | Polished | None |
| Backup, restore, export | app/data.js (533 lines) plus lib/backup.js, lib/files.js, lib/storage.js | Manual JSON backup (share sheet or SAF save), restore, CSV export, Peso Smart v1 import, and a start fresh wipe; all destructive paths are double confirmed and preceded by a one deep snapshot. Web uses textarea and Blob paths. | Polished | backup.test.js (migrations and sanitize, the strictest suite) |
| Automatic backup (Pro) | lib/autobackup.js, lib/files.js, the runner in context/AppData.js | Android only: a once daily dated JSON file into a user picked SAF folder (which can be cloud synced), prefix safe rotation (keep 3, 7, or 14), a broken folder banner and reconnect. Runs only on app foreground and cold start, not a true background job. | Polished | autobackup.test.js |
| Theming and appearance | app/appearance.js, context/Theme.js, theme.js | Light, dark, or system plus 8 color palettes, persisted in separate AsyncStorage keys, a full design token file. | Polished | None |
| Preferences | app/preferences.js | Currency, monthly budget, carry over, payday schedule (semimonthly, monthly, weekly), quick add editor. | Polished | format.test.js covers schedule normalization |
| More hub | app/(tabs)/more.js | Navigation grid, OTA update check (expo-updates) with the founder facing Update stamp row, feedback mailto and share, About. | Polished | None |
| Crash shield | components/ErrorBoundary.js, root app/_layout.js | A render error boundary with a calm recovery UI (hardcoded colors so it survives a theme crash); the root layout gates load failure, onboarding, and lock states; provider unmount flushes pending saves. | Polished | None |
| FX rates cache | hooks/useFxRates.js, lib/fxrates.js | Cached public exchange rates, deliberately non load bearing (the user can always type a rate). | Polished | fxrates.test.js |

## Notable maturity findings across the app

- Nothing found at stub level except components/Placeholder.js, an
  intentional not built yet scaffold that appears unused by live routes.
- Dead code: components/MascotSkia.js is fully written but imported nowhere;
  the live mascot is MascotClay with MascotFallback.
- Pro is a free self unlock flag (updateSettings pro true) in insights.js,
  categories.js, and recurring.js. There is no purchase, billing, or
  entitlement infrastructure anywhere.
- lib/sampleData.js seeds first run data; SAMPLE_TX_IDS is exported so habit
  features exclude demo rows.
- Duplication risks: receivables versus payables (large near mirror files),
  widget math versus analytics.js, and MONTHS arrays plus find or create
  person logic repeated across screens.
- Biggest untested money code: lib/loan.js, lib/soa.js, lib/thirteenth.js,
  the recurring posting engine in context/AppData.js, split.js rounding math,
  the notes.js math parser, lib/search.js, all of lib/pan/, receipt parsing,
  and notification scheduling.
