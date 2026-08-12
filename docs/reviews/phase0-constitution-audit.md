# Phase 0 Audit, Salapify Flutter Master Constitution v2

Date: 2026-08-12. Read only. No production code was changed.

This document is the Phase 0 deliverable mandated by the Salapify Flutter
Master Constitution v2 (sections 56, 60, 61). The constitution's one required
first action is a discovery, preservation, and audit pass, followed by a hard
stop: "STOP AFTER THE AUDIT. Do not make production changes during Phase 0."
This is that audit. It ends by naming the founder decisions and asking for a
phase direction. Nothing in the app was modified.

## Part 0. How to read this

### The app is already mature, so Phase 0 is a fit check, not a starting line

The constitution reads as if the Flutter app were about to begin. It is not.
The Flutter rebuild is shipping at f4.04, patch 95, with the constitution's
Phases 1 through 7 already substantially built and phases the repo called 3
through 6 already delivered. So this audit is not "what should we build first."
It is "how does the app that exists today measure against the constitution, what
must be preserved, what should be improved, and what genuinely needs a founder
decision before anyone touches it."

### The existing audit corpus, and why this one is new

The repo already holds a large audit set under docs/ (Current_Architecture.md,
Current_Features.md, Security_Audit.md, Design_System.md, Database_Review.md,
Dependencies_Review.md, Executive_Summary.md, and more). That set is the
Sprint 0 due diligence pass dated 2026-07-10, and it audits the React Native
app in mobile/. It predates the Flutter rebuild decision (2026-07-13). It is
still useful history, and this document cites it where it still holds, but it
does not describe the current Flutter app. There are also newer, subsystem
scoped Flutter audits (UI design foundation, insights v2, money courses). None
of them is a whole app, constitution structured Phase 0 audit of the Flutter
app. This document is that.

### The standing founder decision that frames the biggest questions

A founder decision from 2026-08-01 (docs/Product_Vision_Spec.md) already
governs the constitution's most consequential territory. The app is
deliberately offline, with no backend, no account, and data that never leaves
the phone. That promise ships as a feature (the Privacy receipt) and is the
app's main trust differentiator. Cloud, Supabase, and Firebase are vision only
and cannot ship without a separate founder decision. The constitution's own
decision hierarchy (section 40) puts Founder Direction above everything else,
and it marks cloud, new data processors, external cost, and architecture
changes as Tier 2 (section 42). So there is no conflict to resolve here: both
the constitution and the founder say the cloud, sync, investment, and
market data sections are founder gated. This audit treats them that way.

### The evidence standard

Every claim below is grounded in the actual code with file references. Feature
verdicts use the constitution's own vocabulary: KEEP, IMPROVE, CONSOLIDATE,
MIGRATE, REPLACE, DEFER, REMOVE. Nothing is marked for removal without evidence,
per section 60.

---

## The headline verdict

This is an unusually disciplined codebase. Three facts stand out.

1. The money layer is pure and golden locked. All 77 files in lib/money import
   zero Flutter UI packages and, in fact, zero package dependencies at all,
   only Dart core. The math is deterministic, takes an injected reference date,
   and is verified to the centavo against roughly 33 golden vector suites drawn
   from the React Native app. Net worth has a genuine single source of truth
   (statements.dart netWorthParts, called by every screen that shows it).

2. The design system is centralized and real. One token layer (theme.dart,
   typography.dart) drives 16 palettes, a typographic scale with weight
   discipline, spacing, radii, motion, and haptics, wired into the Material
   theme so a bare widget is already on brand. The icon system correctly
   separates Salapify authored glyphs (Material icons in the accent) from user
   picked emoji (kept as data).

3. The safety and delivery engineering is ahead of the product's stage.
   Encryption at rest via SQLCipher with a Keystore held key, a layered storage
   fallback that guarantees startup never dies on disk problems, a privacy
   scrubbed diagnostics path, secure window screenshot blocking, and a CI and
   delivery discipline (stamp uniqueness guard, verify-shipped guard, delivery
   log as source of truth, deterministic layout metric tests) that is codified
   as tests, not good intentions.

The gaps are equally clear and none of them is a rewrite. They are consolidation
debt (a few duplicated calculations and a lot of local style overrides that
bypass the design tokens), two connection gaps the constitution explicitly asks
for (education to action, calculators to the engine), one dead chart stack, two
dead dependencies, and one genuine permanent data loss lever that needs a
founder decision before anyone touches it.

---

## A. Current architecture

Layering is real and enforced, not aspirational. The dependency direction runs
cleanly top to bottom: lib/money (pure) is consumed by lib/data (persistence),
lib/services, then lib/widgets and lib/screens, then main.

- lib/money (77 files): pure Dart, zero UI and zero package imports. The
  keystone. Sub package lib/money/pan isolates the assistant logic.
- lib/data (15 files): UI free. Only flutter/foundation (ChangeNotifier) and
  flutter/services (platform channels). Persistence is a strategy pattern behind
  one interface, LedgerRepository (ledger_repository.dart:39), with six
  implementations wired by storage_bootstrap.dart:35 so startup never fails on
  storage.
- lib/screens (57 files, about 41k lines): the UI. Screens receive the store by
  constructor injection and call the money engines directly from build paths.
- State management is one hand rolled ChangeNotifier store (store.dart, about
  2,983 lines) constructed once in main.dart:52 and threaded down by
  constructor injection. The whole tree rebuilds under one ListenableBuilder
  (main.dart:145). There is no state library, no InheritedWidget or Provider for
  the store.
- base_currency_scope.dart is not an InheritedWidget despite the name. It is a
  pure module, and base currency plus the active palette (Barako.current) are
  process wide statics reset at the top of each rebuild, before any figure or
  color is read.

Strength to preserve: the pure money layer and the clean repository interface.
Structural risk: global static app state set on every rebuild couples
correctness to ordering (set before read), and it has broken before.

## B. Existing strengths (preserve)

- Pure, dependency free lib/money (77 files, 0 UI imports).
- Genuine single source of truth for net worth (statements.dart:71).
- Clean LedgerRepository interface with a layered encrypted to plaintext
  fallback (storage_bootstrap.dart:35).
- Centralized design tokens and the surface model (theme.dart, typography.dart).
- Icon system with meaning to glyph mapping and user emoji preserved as data
  (salapify_icon.dart:14-19).
- Deterministic test gates: palette_contrast_test, screen_readability_test
  (38 screens, repeated at 1.5x font), the screens_shot render harness, and the
  golden vector money suites.
- CI and delivery discipline codified as tests (stamp guard, verify-shipped,
  delivery log, publisher guard).

## C. Existing financial management (inventory)

Every core financial capability the constitution lists exists today and is
engine backed.

| Capability | Engine (lib/money) | Screen |
|---|---|---|
| Accounts and balances | ledger.dart, accounts_calc.dart, account_taxonomy.dart | accounts.dart, account_detail.dart, add_account_flow.dart |
| Transactions (income, expense, transfer) | ledger.dart, transfers.dart, quickadd.dart | log_sheet.dart, edit_sheet.dart, history.dart |
| Categories | categories.dart | categories.dart |
| Budgets | budget.dart | budget.dart |
| Goals | goal_plan.dart, goals_calc.dart, analytics.goalPace | goals.dart, goal_create.dart, goal_detail.dart |
| Assets, liabilities, net worth | statements.dart netWorthParts (single source), balanceSheet | reports.dart, overview.dart |
| Cash flow | statements.cashFlowStatement, cashflow_calendar.dart, timeline.dart | cashflow.dart, overview.dart |
| Debts and utang | debtmath.dart, debts.dart, receivables.dart, statements SOA | debts.dart, utang.dart |
| Recurring | recurring.dart | recurring.dart |
| Savings rate | analytics.savingsRate and reports_calc.savingsRatePct (two paths) | reports.dart, insights.dart, coach.dart, pan |
| Financial health, forecasts | analytics.healthScore, forecastMonthEnd, emergencyRunway | insights.dart, overview.dart |
| Safe to spend, afford | commitments.safeToSpend, afford.dart, surplus.dart | overview.dart, afford_card.dart |
| Tax, salary, 13th month, contributions | phtax.dart, thirteenth.dart, taxdeadlines.dart | tax/salary/contribution/13th calculators, year_end_tax.dart |
| Loans and BNPL | loan.dart, bnpl.dart, card_products.dart | loan_calculator.dart, bnpl_calculator.dart |
| FX and multi currency | fx_totals.dart, fxrates.dart, currencies.dart, base_currency_scope.dart | throughout via store.fxTable |
| Paluwagan, splits, treats, windfall, cycle | paluwagan.dart, splits.dart, treats.dart, windfall.dart, cycle.dart | respective screens |

Preservation recommendation for the financial management layer as a whole: KEEP.
It is the strongest part of the app and the constitution's preservation priority
(section 15). Improvements below are additive or consolidation, never removal.

## D. Architecture gaps (what should change, and why)

1. Duplicated month aggregation for income and savings rate. analytics.savingsRate
   (analytics.dart:352-364) and statements.incomeStatement (statements.dart:206-215)
   run the same income and expense classification in separate loops. Reports uses
   one path, Insights and Pan use the other, so a change to income classification
   must be made in both or the two screens can silently disagree. This is the one
   duplication that can actually cause the "two screens disagree about money"
   failure the working rules worry about.
2. Rounding helper copied 7+ times. _jsRound / round2 (JS Math.round parity) is
   duplicated across accounts_calc.dart:7, analytics.dart:20, debtmath.dart:18,
   budget.dart:12, recap.dart:35, search.dart:52, and a differently spelled
   variant in thirteenth.dart:15. No shared money rounding utility.
3. "Is this month" reimplemented three times (budget.dart:15, statements.dart:24,
   analytics.dart:22).
4. Display rounding diverges from engine rounding. format.dart uses Dart's
   .round() (half away from zero) while the engines use half up. Engine values
   are pre rounded so this is usually invisible, but it is an inconsistency in
   the one file that renders every peso figure.
5. Untyped domain model. There are no entity classes. Every entity is a bare
   Map<String,dynamic> with string keys, so a key typo coerces to 0 silently
   rather than failing to compile.
6. lib/money is a catch all. About 40 of 77 files are not money (lessons,
   courses, Pan, mindset). This dilutes the money boundary. Cosmetic, low
   priority.

## E. Design audit (Figma vs Flutter)

No Figma file was provided for this audit, so this is a code side reading of the
design system rather than a Figma to Flutter comparison. The constitution names
Figma as the design authority (section 4); when frames are provided, the
Figma to Flutter to visual QA loop (section 5) applies. The existing token system
gives that loop a strong target to map into.

## F. Design system audit

One centralized, mature system. Verdict KEEP.

- Color: theme.dart. BarakoPalette is const color data; Barako exposes every
  color as a getter over the active palette, so a theme switch repaints the tree.
  8 themes by light and dark equals 16 palettes.
- Typography: typography.dart. A 16 rung scale anchored to the RN scale, only the
  four real Jakarta weights (w500 deliberately banned), semantic AppText styles.
- Spacing, shape, elevation: Gap, Insets, Radii, and an explicit surface model
  (borders over shadows, the only shadow is the FAB).
- Also tokenized: opacity ladder, motion durations with a reduce motion gate,
  haptics vocabulary, icon sizes.

Adoption debt (CONSOLIDATE, not a redesign):
- Raw TextStyle( in 45 screens despite AppText being imported everywhere. Worst:
  goal_detail.dart (31), mindset.dart (23), debts.dart (23), utang.dart (21),
  accounts.dart (20).
- Inline InputDecoration( in 37 screens; the theme's own comment flags private
  _decor helpers awaiting deletion (theme.dart:1122) that were never removed.
- Ad hoc Container plus BoxDecoration cards in 33 screens, parallel to CardTheme.
- ErrorState is used in only 1 screen, EmptyState in 8. The primitives exist but
  are under adopted.

## G. Package audit

18 direct dependencies, Dart SDK ^3.12.2, app version 0.9.0+15.

- REQUIRED / KEEP (real use, evidenced): csv, excel, file_picker,
  flutter_local_notifications, flutter_secure_storage, home_widget, local_auth,
  path_provider, sqflite_sqlcipher, pdf, share_plus, shared_preferences,
  shorebird_code_push, timezone.
- REMOVE (dead, zero call sites outside their own wrapper file): animations
  (only wrapped by salapify_motion.dart, referenced nowhere) and flutter_spinkit
  (only wrapped by salapify_loading.dart, referenced nowhere). Native
  CircularProgressIndicator and built in transitions cover both.
- DECISION NEEDED: fl_chart. It is imported only by salapify_chart.dart, and the
  two widgets in that file (SalapifyLineChart, SalapifyDonutChart) are used
  nowhere. So fl_chart is effectively dead today. The real charts are hand rolled
  CustomPainters (see H and the chart note below). Either adopt the fl_chart
  wrapper across all charts, or drop fl_chart and formalize the CustomPainter set
  as the chart language. This is a design system call, recorded here, not made in
  Phase 0.

## H. Flutter capability audit

- The FX fetch already does the right thing: fx_service.dart uses Flutter native
  dart:io HttpClient for the single network call rather than pulling in http or
  dio. Good precedent for any future quote fetching.
- The native backed packages (SQLCipher, secure storage, local_auth, local
  notifications, home_widget, path_provider, share_plus, file_picker) genuinely
  need platform channels. No over packaging there.
- Charts are the one fragmented area. There is no single visualization language:
  _TrendPainter (insights.dart:2165), _BalancePainter (cashflow.dart:1258),
  _SparkPainter (timeline_sparkline.dart:91), plus bars in reports.dart, each
  divergent, alongside the dead fl_chart wrapper. CONSOLIDATE onto one language.

## I. Connector audit

- No runtime MCP or connector dependency. No Supabase, Firebase, GraphQL, http,
  or dio anywhere in lib. The supabase and http grep hits are all lesson prose,
  not code. Local first is confirmed.
- The constitution's connectors (Context7, Figma, GitHub, Supabase) remain
  development time only, which is exactly what the constitution requires
  (sections 13, 27: never make a connector a runtime dependency).
- Only network path: fx_service.dart to open.er-api.com, no API key, sends only
  the base currency code, degrades to manual rate entry offline, logged to the
  Privacy receipt.

## J. Financial engine audit

Strong. Pure, injected time, golden locked, with a genuine single source for net
worth. See C for the inventory and D for the gaps. The two engine level
consolidations that matter are the duplicated income and savings rate path (D1)
and the copied rounding helper (D2). Everything else in the engine is KEEP.

## K. Pan audit

Pan is a rules based, offline, deterministic intent matcher. No model, no network.

- Pipeline: normalize, detectIntent, guardrails, resolver, respond (pan/ask.dart:34-81).
- Facts come only from the golden locked engines. Resolvers are the only layer
  allowed to call the money engine (pan/resolvers.dart:1-4); the responder
  receives numbers it did not compute and cannot change (pan/respond.dart:1-4).
  Pan cannot invent a figure by construction.
- Guardrails redirect invest, loan, tax, legal, and insurance questions, with
  whole word matching so "taxi" does not trip the tax rail.
- English first, Tagalog understood but not spoken, per the working rules.

Verdict: KEEP. This already matches the constitution's Pan architecture
(section 20): AI bounded by the financial engine, never the source of truth.

## L. Financial education audit

Two parallel systems, one connected and one siloed.

- Core coaching (22 lessons, lessons.dart): behavior connected. Each lesson opens
  with a true line from the user's own data (lesson_insight.dart:69-172) and has
  an in app action route. coach.dart:387-416 surfaces behavior triggered nudges
  (year end to 13th month, has card to card interest, has BNPL, has receivables).
  This is exactly the education to action pattern the constitution wants
  (sections 21, 22).
- Expansion courses (71 lessons, typed MoneyLesson across 12 files, 3 published
  learning paths): excellent, governed content. 229 canonicalUrl citations, every
  one reviewStatus verified. But it is a content silo:
  expansion_recommendation.dart recommends the next course purely from lesson
  progress, blind to financial events. Nothing routes a new debt, a bonus, or a
  tax deadline to the relevant expansion course.

This is the single biggest disconnection gap in the app, and it is an IMPROVE,
not a defect: the core lessons already prove the pattern, the expansion set just
never got wired to it. Two lesson models (Map based core vs typed MoneyLesson
expansion) should eventually share one recommendation surface (CONSOLIDATE).

## M. Local first audit

Genuinely offline. The only outbound network in the whole data path is the FX
rate fetch (see I), which is non load bearing and degrades gracefully. Storage is
SQLCipher plus shared_preferences plus on device files. Backup imports the
existing Salapify backup JSON at schema v12, golden locked to the RN output.
Data loss protection is strong: import snapshots the raw on disk blob before
replacing and rolls back on write failure; load never saves over data it failed
to read.

## N. Native capability audit

Present and working: biometric app lock (local_auth), secure window / FLAG_SECURE
screenshot blocking (method channel), local notifications with timezone
(Asia/Manila, inexact alarms, boot re-registration), Android home screen widget
(home_widget, "Your Number"), CSV / XLSX / PDF export with share, and a strict
Android backup off privacy posture.

Missing (constitution lists, absent today), all would be a new base APK and a
manual install, so all are founder flagged native changes: receipt capture
(camera), OCR, proper deep links (App Links verification), and an iOS home
widget.

## O. Investment data audit

No investment tracking domain and no market data feed today. The "portfolio" and
"market" grep hits are educational illustrations and comments, not real holdings.
What exists is investment education content only. This is a Phase 8 gap, not a
defect, and it is founder gated because it implies external market data (external
cost and a new data processor, Tier 2). If it is ever built, the fx_service
dart:io pattern is the natural reuse.

## P. Security audit

Strong, and largely re confirming the 2026-07-10 Security_Audit.md for the
Flutter app.

- Encryption at rest: SQLCipher with a random 256 bit key held in the Android
  Keystore via flutter_secure_storage. Deliberately no biometric gate on the key,
  so a sensor reset never costs data.
- App lock: local_auth, biometric result never leaves the device.
- Secure window: refcounted FLAG_SECURE for reveals and QR sheets, tested.
- Diagnostics privacy: counts and shapes only, no amounts, names, notes, or
  categories, enforced by a test that fails if incriminating strings appear.
- Notifications: detail in the body is opt in, default is generic redacted text,
  SECRET vs PRIVATE lock screen channels.
- Android backup posture: allowBackup false plus both rule files, test guarded.
- QR vault: stores a filename ref, not bytes; path traversal safe.
- No secrets in the repo; the DB key is device generated at runtime.

One genuine risk, and it is a founder decision (see the decisions section):
the frozen plaintext fallback is retired after one confirmed encrypted read on a
later launch (encrypted_store_coordinator.dart:96-110), and the Keystore key is
not backed up. Once the plaintext copy is retired, if the Keystore key is ever
lost, the encrypted DB becomes permanently unopenable with only the user's
manual export as recovery. The current in flight state (plaintext still present)
is the safest window.

## Q. Performance audit

Mostly reassuring, with two concrete watch items.

- CustomPainters are correctly guarded (shouldRepaint compares specific fields,
  not blanket true). Lazy tab building is in place (IndexedStack plus a visited
  set) so Insights' engine calls do not run at cold start.
- Whole app rebuild on every store notify (main.dart:145) re runs the visible
  tab's engine calls and resets the global palette and base currency statics on
  any of 18 notifyListeners. With very large screens this is the rebuild cost
  pressure point.
- Eager list rendering is the clearest concrete flag: only 2 files use
  ListView.builder, while 43 screen files use plain ListView(children: [...]) and
  48 build children via .map or spread. For bounded lists this is fine; for lists
  that grow with transaction, history, or lesson count (history.dart, debts.dart,
  utang.dart, lesson lists) it materializes every row each build. This is the
  main performance item worth a targeted pass. Measure before optimizing, per
  section 34.

## R. Target architecture

The target architecture the constitution describes is, for the offline scope,
largely the architecture that already exists: a pure financial engine as the
single source of truth, a clean local first data layer behind one repository
interface, a centralized design system, deterministic tests, and a bounded
rules based Pan. The work is not to build this architecture. It is to finish
adopting it in the places that drifted (style tokens, chart language, the two
duplicated calculations) and to close the two connections the constitution asks
for (education to action, calculators to the engine). The cloud, sync,
investment, and market data layers in the constitution's end state diagram
remain founder gated and out of the offline scope until a separate decision.

## S. Preservation and migration plan

- Stays (KEEP): the pure money engine and net worth single source; the ledger and
  debt and tax and loan math; the repository interface and encrypted storage;
  the design token system and icon system; Pan; Insights and coach; the
  behavior connected core lessons; the engine connected tools (split_expense,
  paluwagan, notes, year_end_tax, tax_deadlines, currency_converter); the CI and
  delivery discipline; the deterministic test gates.
- Improves (IMPROVE, additive, no behavior change to money): adopt AppText and
  InputDecoration and CardTheme in the screens that override them; broaden
  EmptyState and ErrorState adoption; wire expansion courses to financial events;
  add an opt in "send this result to the engine" path from the six compute and
  forget calculators; convert data growing eager lists to .builder; add a typed
  accessor layer over the existing blob without changing schema v12.
- Consolidates (CONSOLIDATE): the two income and savings rate paths onto one
  aggregator; the 7+ rounding helpers into one utility; the three "is this month"
  helpers; the chart implementations into one language; the two lesson models
  onto one recommendation surface; the lesson content test sprawl.
- Removes (REMOVE, with evidence): the two dead dependencies (animations,
  flutter_spinkit) and the dead salapify_motion and salapify_loading wrappers;
  and either the dead fl_chart wrapper or fl_chart itself (decision in G).
- Defers (DEFER, founder gated): investments and market data (Phase 8); cloud and
  sync (Phase 10); receipt capture, OCR, deep links, and iOS widget (native, new
  base APK). Also the frozen plaintext retirement change (data loss lever).

Everything in Improves, Consolidates, and the dependency Removes is offline safe,
ships over the air as a Shorebird patch, and breaks no shipped promise. It is the
natural home for the next work.

## T. Prioritized roadmap

Ranked by value, dependency, risk, and preservation priority. All of block 1 is
offline, reversible, and preserves money behavior exactly.

Block 1, engine and correctness consolidation (highest value, lowest risk):
1. Single income and savings rate aggregator (closes the one real "two screens
   can disagree" gap).
2. One shared money rounding utility and one date window helper.
3. Align format.dart display rounding with the engine.

Block 2, design system adoption and cleanup (high value, low risk):
4. Adopt AppText, InputDecoration, and CardTheme in the drifted screens; broaden
   EmptyState and ErrorState.
5. Consolidate charts into one visualization language and resolve the fl_chart
   decision.
6. Remove the two dead dependencies and their wrappers.

Block 3, the constitution's connection asks (high product value, medium effort):
7. Wire expansion courses to financial events (education to action).
8. Add the opt in "send result to the engine" path from the calculators.

Block 4, targeted performance (medium value, do after measuring):
9. Convert data growing eager lists to .builder.

Block 5, structural hardening (medium value, larger, do incrementally):
10. Typed accessor layer over the existing blob (no schema change).
11. Break up the mega screens (accounts, mindset, insights, overview) as they are
    touched, not in one pass.

Founder gated, not scheduled here: investments and market data, cloud and sync,
the four missing native capabilities, and any change to the frozen plaintext
retirement or the money value type.

---

## Consolidated feature classification

| Item | Verdict | Reason (evidence) |
|---|---|---|
| Financial engine (ledger, net worth, debt, tax, loan, budgets, goals) | KEEP | Pure, golden locked, single net worth source (statements.dart:71) |
| Income / savings rate (two paths) | CONSOLIDATE | Same loop in analytics.dart:352 and statements.dart:206 |
| Rounding helpers (7+ copies) | CONSOLIDATE | accounts_calc.dart:7, analytics.dart:20, debtmath.dart:18, etc. |
| "Is this month" (3 copies) | CONSOLIDATE | budget.dart:15, statements.dart:24, analytics.dart:22 |
| Domain model (untyped map) | IMPROVE | No entity types; typed accessors over the same blob, no schema change |
| Money value type (double) | IMPROVE (founder gate) | Correctness rests on discipline + goldens; any change is a money change |
| format.dart display rounding | IMPROVE | Half away from zero vs engine half up (format.dart) |
| Repository layer + encrypted storage | KEEP | Clean interface, layered fallback (storage_bootstrap.dart:35) |
| Backup / restore (schema v12) | KEEP | Golden locked to RN, snapshot before replace |
| Frozen plaintext retirement + Keystore key | DEFER (founder gate) | Single permanent data loss path (encrypted_store_coordinator.dart:96) |
| Design token system | KEEP | Centralized, test enforced (theme.dart, typography.dart) |
| Icon system | KEEP | Meaning to glyph in accent, user emoji preserved (salapify_icon.dart:14) |
| Raw TextStyle in 45 screens | CONSOLIDATE | Bypasses AppText ladder |
| Inline InputDecoration (37) / ad hoc cards (33) | CONSOLIDATE | Theme already defines these |
| EmptyState / ErrorState adoption | IMPROVE | ErrorState in 1 screen, EmptyState in 8 |
| Chart stack (3 painters + dead fl_chart wrapper) | CONSOLIDATE / decision | No single language; fl_chart wrapper unused |
| animations, flutter_spinkit deps | REMOVE | Zero call sites outside their own wrapper |
| Pan | KEEP | Deterministic, bounded, cannot invent figures (pan/resolvers.dart:1) |
| Insights + coach | KEEP | Composes validated engine facts, single source (insight_feed.dart:1) |
| Education, core (22) | KEEP | Behavior aware openers and nudges (lesson_insight.dart:69, coach.dart:387) |
| Education, expansion (71) | IMPROVE | Governed content, but siloed from money events |
| Two lesson models | CONSOLIDATE | Map core vs typed MoneyLesson, one recommendation surface |
| Calculators (salary, 13th, contribution, tax, loan, BNPL) | IMPROVE | Correct but compute and forget; add opt in path to engine |
| Engine connected tools (split, paluwagan, notes, tax deadlines, year end, FX) | KEEP | Read and write real data |
| State management (single ChangeNotifier) | IMPROVE (do not migrate) | Sound; tighten whole tree rebuild and global statics |
| Eager lists (43 ListView children) | IMPROVE | Convert data growing lists to .builder |
| Test suite | KEEP + CONSOLIDATE | Strong money and metric gates; broaden journeys, trim lesson string sprawl |
| CI and delivery discipline | KEEP | Stamp guard, verify-shipped, delivery log as truth |
| Investments / market data | DEFER (founder gate) | None today; external data, external cost |
| Cloud / Supabase / sync | DEFER (founder gate) | Offline promise stands (Product_Vision_Spec 2026-08-01) |
| Native: receipt, OCR, deep links, iOS widget | DEFER (founder gate) | New base APK, manual install |

---

## Founder decisions required

These are the only items that need you before work proceeds. Everything else in
blocks 1 through 4 above is routine engineering under the constitution's Tier 1
autonomy and the app's own working rules.

### Decision 1. Which phase direction to run next

Decision: approve block 1 (engine and correctness consolidation) as the next
phase, or pick a different block from the roadmap.
Why it matters: Phase 0's stop exists so you set direction once, then the work
runs autonomously (section 61). Block 1 is the highest value, lowest risk, fully
offline, and it closes the one real gap where two screens can disagree about
money.
Recommended: block 1, then block 2.
Reversibility: easy. All over the air, all behavior preserving, all golden locked.

### Decision 2. The offline promise vs the constitution's cloud and investment sections

Decision: confirm the offline, no backend promise stands, and that cloud, sync,
investments, and market data remain vision only.
Why it matters: large parts of the constitution (sections 10, 25 through 28,
Phases 8 and 10) describe Supabase, cloud sync, and live market data. Your
2026-08-01 decision and the Privacy receipt say the opposite, on purpose, as the
app's main trust differentiator. The constitution's own hierarchy puts your
direction first and marks these as Tier 2.
Recommended: keep the offline promise. Treat cloud and investments as designed
but unscheduled, requiring a separate decision each with the tradeoffs read
first.
Reversibility: hard to reverse if built, easy to keep deferred.

### Decision 3. The permanent data loss lever (frozen plaintext retirement)

Decision: leave the frozen plaintext retirement trigger and the Keystore key
handling exactly as they are for now, and treat any change as founder gated.
Why it matters: this is the one place in the app where user data can be
permanently lost. After the plaintext fallback is retired (one confirmed
encrypted read on a later launch) a lost Keystore key means an unopenable DB with
only the user's manual export as recovery.
Recommended: do not touch it in the near term; if it is ever revisited, add a
safeguard (for example, keep the plaintext fallback longer, or add a key backup
path) and bring the design to you first.
Reversibility: the retirement itself is not reversible once it fires.

### Decision 4. fl_chart, adopt or drop

Decision: adopt the fl_chart wrapper across all charts, or drop fl_chart and make
the CustomPainter set the chart language.
Why it matters: fl_chart is a dependency whose only consumer is dead code, while
the real charts are three divergent hand rolled painters. This is a small design
system call, recorded so it is made deliberately rather than by default.
Recommended: formalize the CustomPainter set as the language and drop fl_chart,
unless you want the richer interaction fl_chart gives future investment charts,
in which case adopt the wrapper everywhere.
Reversibility: easy either way.

---

## Phase 0 stop

Per the constitution's Phase 0 stop condition (section 61), this audit stops
here. No production code was changed. Once you pick a phase direction
(Decision 1) and confirm the founder gated items (Decisions 2 through 4), the
approved block runs autonomously under the Tier 1 and Tier 2 model, with the
app's existing working rules (stamp discipline, golden locks, QA log, delivery
log, no em or en dashes) still binding.
