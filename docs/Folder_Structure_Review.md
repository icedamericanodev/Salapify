# Folder Structure Review

Sprint 0 engineering audit, 2026-07-10.

## The tree as it stands

```
Salapify/
  index.html            Legacy v1 web app (Peso Smart), about 300KB, single file
  sw.js                 Service worker for the legacy PWA
  404.html, manifest.json, privacy.html, robots.txt, icons
  package.json          Root package: htmlhint + jsdom, lints and smoke tests the legacy page
  tests/smoke.test.js   Legacy page smoke test
  CLAUDE.md             Working rules for the AI development workflow
  docs/                 Documentation (this audit, play-store-listing.md)
  .github/workflows/    ci.yml (legacy page), eas-update.yml (OTA), build-apk.yml, pages.yml
  .claude/agents/       22 specialist agent definitions for the AI assisted workflow
  mobile/               The real product: Expo SDK 54 React Native app
    app/                expo-router file based routes
      _layout.js        Root: ErrorBoundary > Theme > AppData > Motion > LockGate > Onboarding > Stack
      (tabs)/           6 tabs: index (home), budget, debts, insights, tools, more
      27 stack screens  goals, history, search, accounts, categories, recurring,
                        receivables, payables, person, split, notes, reports, learn,
                        mindset, pan (chat), treats, appearance, preferences,
                        notifications, data, currency-converter, plus 7 calculators
                        (tax, year-end-tax, salary, thirteenth, loan, bnpl,
                        contribution) and tax-deadlines
    components/         21 shared components + motion/ (3 animation primitives)
    context/            AppData.js (all data), Theme.js, Motion.js
    hooks/              useFxRates.js, useHaptic.js
    lib/                35 modules: pure logic (money math, tax, loans, backup,
                        analytics, search, coach) + pan/ (5 module chat engine)
    widgets/            Android home screen widgets (10 widgets, 2 files)
    __tests__/          17 Jest suites, 313 tests, all passing (verified this audit)
    assets/             icons, splash, mascot art
    *.bat               Windows helper scripts for the founder (start-app, start-web,
                        start-lan, start-usb, auto-pull)
```

## What is good

- The mobile app layout follows the standard, current Expo convention
  (file based routing, app/ for screens, colocated (tabs) group). A React
  Native developer can orient in minutes; screens are where the router says
  they are and the URL path equals the file path.
- lib/ versus app/ discipline is real and consistently enforced: money math,
  tax tables, parsing, and backup logic are pure modules with no React
  imports, which is exactly why 313 unit tests exist and pass without any
  component mocking. This is the single most valuable structural property of
  the codebase.
- context/ contains exactly three providers with a clear ownership story: all
  persistent data flows through AppData.js, all theming through Theme.js,
  motion preferences through Motion.js. There is no hidden fourth state
  system.
- pan/ shows the codebase knows how to grow a subsystem into its own folder
  when it earns one (5 modules, single responsibility each).
- Tests live in one place with a consistent naming convention matching the
  lib module they cover.

## Issues

### FS-1: Two products share one repository root, and the legacy one owns it

Severity: Medium
Business impact: confusing to any new engineer or investor doing diligence;
the repo's root package.json describes the deprecated product, and CI (ci.yml)
tests only the legacy page on PRs to main while the actual product's 313
tests do not run in CI.
Technical impact: root tooling (htmlhint, jsdom) is dead weight for the real
product; the 300KB index.html dominates repo browsing; two package.json and
two test systems must be explained to every newcomer.
User impact: none directly, but CI not running mobile tests means a broken
money calculation can merge without any automated gate (the gate exists but
watches the wrong app).
Recommendation: keep the legacy page (it serves v1 users and hosts the privacy
policy) but demote it into a legacy-web/ folder, point GitHub Pages at that
subfolder or a dedicated branch, and make the root CI run the mobile Jest
suite on every PR. Effort: M (Pages source change is the delicate part).

### FS-2: The stack screen directory is flat with 27 siblings

Severity: Low
Business impact: slows feature location slightly as the app grows.
Technical impact: mobile/app/ mixes core flows (goals, history), settings
pages (appearance, preferences, notifications, data), and 8 calculator tools
at one level. expo-router supports route groups without URL impact, for
example (settings)/ and (calculators)/.
User impact: none (routes unchanged).
Recommendation: adopt route groups the next time a batch of screens is
touched; not worth a dedicated churn PR since renames create noisy diffs and
every mobile/ push costs a publish job. Effort: S.

### FS-3: components/ is flat and mixes tiers

Severity: Low
Business impact: minor.
Technical impact: 21 files mix design system primitives (Card, Bar,
SectionHeader, EmptyState), feature components (LogSheet at 735 lines,
WeekRecap, TreatCard), three mascot implementations (MascotSkia, MascotClay,
MascotFallback plus Mascot.js), and infrastructure (ErrorBoundary, LockGate).
User impact: none.
Recommendation: when a design system pass happens (see Roadmap), split into
components/ui/ (primitives), components/mascot/, and keep feature components
at the top level. Effort: S, bundle with other churn.

### FS-4: Founder helper .bat scripts live inside mobile/

Severity: Low
Business impact: none.
Technical impact: Windows only scripts (start-app.bat, auto-pull.bat, etc.)
sit next to product code and ship in the repo checkout; harmless but they are
developer tooling, not app code.
User impact: none.
Recommendation: move to a scripts/ folder alongside mobile/ whenever
convenient; document them in a README. Effort: S.

### FS-5: docs/ existed with a single marketing file and no engineering docs

Severity: Medium (addressed by this audit)
Business impact: onboarding anyone, human or AI, relied on CLAUDE.md plus
reading code; no architecture or data model documentation existed.
Technical impact: the data schema (version 12, migration framework in
lib/backup.js) was documented only in code comments.
User impact: none.
Recommendation: this audit seeds docs/; keep Database_Review.md's schema
section updated on every SCHEMA_VERSION bump as a standing rule. Effort: done
plus ongoing.

## Verdict

The structure inside mobile/ is genuinely good for a codebase this size:
conventional, testable, with real separation between pure logic and UI. The
structural debt is at the repository level, where the deprecated v1 product
still owns the root, the CI gate, and the deploy pipeline mindshare.
