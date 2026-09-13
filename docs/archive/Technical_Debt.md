# Technical Debt

Sprint 0 engineering audit, 2026-07-10. Ranked by what would worry an acquirer
or investor most, with severity, impact, and effort per item. Effort scale: S
under 1 day, M 1 to 3 days, L 1 to 2 weeks, XL more than 2 weeks. "Ships OTA"
means the fix reaches phones without an APK rebuild.

## The three headline items

1. The 17 file mobile test suite (313 passing tests, verified during this
   audit) never runs in CI. CI tests the dead legacy web app instead.
2. The single blob storage design has a hard, known ceiling (the roughly 2MB
   Android AsyncStorage row read wall, about 10k to 13k transactions), and
   nothing stops a write from crossing it. Crossing it permanently locks the
   user out of their own data.
3. Free users have zero durability story: allowBackup false plus Pro only
   auto backup means a lost phone is a lost financial history unless the user
   manually exported.

None of these are expensive to close relative to the value at risk.

## Findings

### TD-1: CI never runs the mobile tests, and OTA ships ungated

Severity: Critical (process, not code) | Effort: S | Ships OTA: yes (workflow only)
Where: .github/workflows/ci.yml runs npm ci, lint, and test at the repo root.
The root package.json lint is htmlhint for the legacy page and its test is a
node smoke test for the dead v1 PWA. The 17 suites in mobile/__tests__/
(backup sanitize, analytics, tax math, migrations) are configured under
jest-expo but no workflow executes them. Meanwhile eas-update.yml publishes to
the preview channel on every push touching mobile/, before any automated
check.
Business impact: the tests that guard money math are decorative. A regression
in sanitizeData or debt payoff ships to real phones over the air with zero
automated gate. For due diligence purposes, we have tests is currently false
in the only sense that matters.
Technical impact: the QA pass rules in CLAUDE.md are the only gate, and they
are human discipline gates.
User impact: a broken bundle reaches preview devices minutes after a bad push.
Recommendation: add a mobile-test job to ci.yml (working directory mobile,
npm ci, npx jest) and make eas-update.yml run the jest suite as a step before
eas update.

### TD-2: No hard ceiling before the 2MB read wall

Severity: Critical (a slow burn but permanent data loss path) | Effort: S for
the guard; structural fix is TD-4 | Ships OTA: yes
Where: saveData in mobile/lib/storage.js measures size but never refuses a
write. The only user facing guard is a banner inside the Backup and data
screen, which a heavy logger may never open. Android's CursorWindow refuses to
read rows near 2MB but happily writes them, so the failure is: save succeeds
today, every launch after that hits loadFailed forever, with no recovery
beyond a backup the user may not have. The snapshot key doubles the footprint
inside the same SQLite database, which also has a 6MB default total cap on
Android.
Business impact: the single worst review a finance app can get, it locked me
out of years of my data. Unrecoverable trust damage.
Technical impact: the wall is a cliff, not a slope; the thresholds only
inform, they do not protect.
User impact: at roughly 160 bytes per transaction, a 10 entry per day user
hits SIZE_WARN in about 2.5 years and the wall not long after.
Recommendation: in saveData, when size exceeds a hard cap (about 1.8MB),
still write but fire a blocking app wide modal demanding an export, and
consider refusing writes above 1.95MB with an explicit error state. Pair with
TD-4 structurally.

### TD-3: Free users have no durability story

Severity: High | Effort: M (mostly a product decision; changing allowBackup
is an app.json change and requires an APK rebuild)
Where: app.json sets android.allowBackup false, so device to device transfer
and Google One backup skip the data. The automatic folder backup is Pro only
and Android only. Free users have manual export only.
Business impact: the target market (Filipino Gen Z on mid range Androids)
breaks and loses phones. Every lost phone for a free user is a churned user
who tells friends the app lost their money history. It also caps the value of
the product being converted to.
Technical impact: none, this is a policy choice.
User impact: total, silent loss of financial history on device loss or a
botched phone migration.
Recommendation: make the daily auto backup free (keep folder rotation and
multi file retention as the Pro extra), or revisit allowBackup with an
exclusion ruleset. Data portability is already framed as never paywalled in
autobackup.js; durability deserves the same principle.

### TD-4: Single blob architecture is the scaling ceiling

Severity: High (time bomb, not a today problem) | Effort: XL | Rebuild: yes
(expo-sqlite is a native module, so APK plus runtime version bump)
Where: lib/storage.js (whole blob read and write), AppData.js (every change
rewrites everything; startup parses and deep rebuilds every collection).
See Performance_Audit.md for the 1k, 10k, and 50k transaction math.
Business impact: the best users (daily loggers, exactly who converts to Pro)
are the ones who hit this.
Recommendation: the AppData.js header comment already names the plan (swap in
SQLite later without changing any screen) and the storage seam plus the no
direct storage access rule make it genuinely feasible. Put an expo-sqlite
migration on the 6 to 12 month roadmap: a transactions table plus a small KV
blob for settings and small collections, keeping the existing migration and
snapshot discipline.

### TD-5: Every data change re-renders every mounted screen, and screens compute derived data unmemoized

Severity: High at 10k rows on mid range hardware; Medium today | Effort: M |
Ships OTA: yes
Where: one AppDataContext consumed by 32 files. The provider value object is
rebuilt every render with no useMemo, and all helper functions are recreated
(AppData.js lines 524 to 540). expo-router keeps the tabs mounted, so a
single logged expense re-renders Home, Budget, Debts, Insights, Tools, More,
and any stacked screen. Inside those renders: budget.js lines 106 to 112 sort
the entire transactions array unmemoized on every render; insights.js lines
65 to 112 filter and aggregate unmemoized; index.js lines 62 to 70 filter the
full list per render. Only history.js and pan.js use FlatList; the other
screens are ScrollView plus map (acceptable for small collections, and the
Recent list is correctly capped at 12).
Business impact: jank on logging, the app's single most repeated interaction,
on exactly the phones the target market owns.
Recommendation: three cheap moves in order: (1) wrap the provider value in
useMemo with stable callbacks, (2) useMemo the derived computations in
budget.js, insights.js, and index.js keyed on data.transactions (effective
because setData spreads preserve untouched collections), (3) later, split
into a state context and an actions context.

### TD-6: Widget handler duplicates the money math

Severity: Medium | Effort: S | Ships OTA: yes
Where: widgets/widget-task-handler.js lines 92 to 101 reimplement
netWorthParts (including the cashLeg utang rules), and lines 59 to 79
reimplement the income and spending filters, with a comment admitting it
matches the netWorth helper the app screens use. That is a manual promise,
not a code guarantee.
Business impact: a home screen widget showing a different net worth than the
app is a this app cannot do math one star review.
Recommendation: import the pure helpers from lib/analytics.js into the task
handler (it already imports from lib/format.js, so the pattern works
headless), and add a test asserting widget numbers equal netWorthParts output
on a fixture blob.

### TD-7: receivables and payables are 750 line near twins

Severity: Medium | Effort: M | Ships OTA: yes
Where: app/receivables.js (769 lines) and app/payables.js (748 lines); a
plain diff is only 549 lines, meaning the majority of both files is shared
structure (modals, quick dates, payment flows, styles).
Business impact: every utang bug gets fixed once and shipped half fixed.
Slows every feature touching utang.
Recommendation: extract the shared pieces (quickDates, the payment modal, the
row card) into components with a direction prop. Do not force a full merge;
the file header honestly documents real behavioral differences (no Remind, no
split on payables), keep those explicit.

### TD-8: Manual runtime version pinning

Severity: Medium | Effort: S | Rebuild: yes (the change itself needs one)
Where: app.json pins runtimeVersion 1.4.0 as a string while version is 1.4.1
and versionCode is 7. Correct only as long as a human remembers to bump it on
every native change. Forgetting means an OTA bundle referencing a missing
native module lands on old binaries (startup crash on every preview phone at
once).
Recommendation: switch to the fingerprint runtimeVersion policy so the
runtime hash is computed from the native project and mismatched updates are
impossible. If staying manual, add a checklist item to the build docs.

### TD-9: No lint, no type checking, no crash telemetry for the actual app

Severity: Medium | Effort: S (lint) to M (telemetry; Sentry is a native
module, APK rebuild, and a privacy posture decision)
Where: no ESLint, Prettier, or tsconfig anywhere under mobile/ (the only
linter in the repo is htmlhint for the legacy page).
ErrorBoundary.componentDidCatch logs to console only, so field crashes are
invisible; the offline first, no backend stance is deliberate, but right now
the crash rate is unknowable.
Business impact: quality regressions are discovered by users, not dashboards.
Recommendation: (a) eslint with eslint-config-expo wired into the new CI job.
(b) Decide consciously about Sentry; a lighter interim option is an opt in
send crash log share sheet from the ErrorBoundary using a ring buffer.
TypeScript migration is optional at this size; the comment discipline
partially substitutes.

### TD-10: The legacy root app is the loudest visible debt

Severity: Medium | Effort: S to M
Where: repo root: index.html is a 302,713 byte single file containing the
entire v1 Peso Smart PWA, plus sw.js (service worker caching Chart.js from a
CDN), 404.html, manifest.json, tests/smoke.test.js, and a root package.json
still describing the v1 product. Pages still deploys it as the landing page
and the Play required privacy URL host. CI tests it (TD-1). It also carries
the XSS and CDN issues in Security_Audit.md SEC-3.
Business impact: onboarding confusion (a new dev's first impression is a
300KB HTML file), CI pointed at the wrong product, an unmaintained but still
live PWA that old users may still have installed with real data in
localStorage.
Recommendation: do not delete it (the privacy URL and the v1 import path in
backup.js parseV1 still matter). Move it to a legacy/ folder, add an import
your data into the new app banner inside it, repoint pages.yml paths, and
repoint CI at mobile/ (TD-1).

### TD-11: AppData.js is becoming the god module, and setCurrencySymbol is called during render

Severity: Medium | Effort: S plus M | Ships OTA: yes
Where: context/AppData.js (552 lines) contains persistence orchestration, the
recurring bill posting engine (lines 286 to 329), the auto backup runner
(lines 204 to 238), notification rescheduling, CRUD helpers, and balance
math. One true code smell: setCurrencySymbol is called during render
(AppData.js line 522), mutating a module level singleton in lib/format.js. It
works today; it is exactly the kind of thing React concurrent rendering
breaks silently.
Recommendation: move setCurrencySymbol into a useEffect keyed on the currency
(S, safe). Extract the recurring posting engine into a pure lib/recurring.js
function postDue(data, now) with tests; it is money math and currently
untestable without mounting React (M). Leave the rest; the file is well
organized and the comments carry it.

### TD-12: No README or human onboarding doc

Severity: Low to Medium | Effort: S
Where: no README at root or in mobile/. CLAUDE.md is the only process doc and
it is written for an AI agent, not a human hire. Counterweight: inline
comment quality is the best onboarding asset here, genuinely.
Recommendation: a one page mobile/README.md covering the architecture sketch
(screens read context, context calls the storage seam, pure libs, migration
rules), how to run, how OTA versus rebuild works, and the data invariants
(never write after a failed read, always bump SCHEMA_VERSION on shape
change). Half a day, large diligence and hiring payoff.

### TD-13: Untested money code, dead code, and smaller notes

Severity: Low to Medium individually | Effort: varies
- Biggest untested money code (all pure and cheaply testable): lib/loan.js
  (amortization and the effective rate bisection solver), lib/soa.js
  (statement date and interest forecasts), lib/thirteenth.js, the recurring
  posting engine in AppData.js, split.js centavo rounding, the notes.js hand
  rolled math parser, lib/search.js, all of lib/pan/, lib/receipt-parse.js,
  and notification scheduling. Effort: M spread across normal batches.
- lib/phtax.js hardcodes RATES_YEAR 2026 with one flat set of SSS, PhilHealth,
  Pag-IBIG, and TRAIN constants; no per year versioning, so all five payroll
  and tax tools go silently stale the year any statutory rate changes.
  lib/holidays.js covers Chinese New Year only 2026 to 2028. Effort: M.
- Dead code: components/MascotSkia.js is fully written but imported nowhere
  (the live mascot is MascotClay with MascotFallback); components/
  Placeholder.js appears unused by live routes. Effort: S.
- Pro is a free self unlock flag (updateSettings pro true) with no purchase,
  billing, or entitlement infrastructure anywhere. Fine for early access; a
  monetization workstream, not a bug. Effort: XL when monetization starts.
- The manual Update stamp in more.js depends on a human bumping a string per
  push; consider injecting the git short SHA at publish time via expo-updates
  runtime metadata. Effort: S.
- The tax deadlines tool does not apply weekend or holiday shifting even
  though lib/holidays.js exists. Effort: S.
- The currency converter UI attributes exchangerate-api.com while the code
  calls open.er-api.com; align the attribution. Effort: S.
- pages.yml continue-on-error on the web export can let a silently failing
  web build rot for weeks; add a notification step. Effort: S.
- No component or e2e tests (Maestro or Detox). Acceptable at this stage
  given the pure lib coverage; revisit before a Play production launch.
  Effort: L when the time comes.

## What is NOT debt (strengths worth keeping)

- The sanitizeData funnel: every load, restore, and import path passes
  through one security literate coercion function (receipt path regex blocks
  directory escape, flow only trusted on transfer and adjustment rows, strict
  booleans so a string cannot unlock Pro).
- Forward only migrations with version fences; hostile version values clamped
  so the migration loop can never hang.
- The load state machine: ok, empty, error, with saving disabled after a bad
  read. The single most important invariant in an offline money app, handled
  correctly.
- Balance integrity by construction in the transaction helpers.
- The save pipeline: debounce, background flush, unmount flush.
- Pure business logic in lib/ with 313 passing tests.
- Receipts stored outside the blob as relative paths, correctly handling iOS
  container path churn.
- Cost aware CI/CD with an injection safe OTA publish workflow.
- Guarded edges: ErrorBoundary with hardcoded colors so a theme crash still
  renders; a widget task handler that can never crash the launcher;
  history.js built right for scale (virtualized, memoized rows).
