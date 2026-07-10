# Product Backlog

Sprint 1, 2026-07-10. The epic level backlog for the next 6 to 12 months.
Priorities: P0 (first), P1 (soon), P2 (planned), P3 (later). Complexity: S,
M, L, XL as elsewhere. Week by week sequencing lives in Sprint_Plan.md.

Standing definition of done, inherited by every epic unless extended: code
compiles under the Expo Babel preset; the jest suite passes locally and in
CI; a QA pass ran on the changed code with every must fix fixed and
rechecked; accessibility rules from Design_System.md section 16 met on new
or touched UI; the update stamp bumped on every push touching mobile/;
docs/ updated where the change affects a documented contract (schema,
tokens, metrics); merge per CLAUDE.md rules.

## Epic 1: Engineering Foundation

Business goal: releases that cannot silently break users, and a codebase a
second engineer could join.
User problem: users receive OTA updates gated by nothing; a money math
regression reaches their phone in minutes; heavy users march toward a
storage cliff that permanently locks them out.
Expected outcome: CI runs the mobile suite on every PR and blocks OTA
publishes; the storage wall is guarded; landmines defused
(setCurrencySymbol, widget math, runtime version); untested money code
tested; ESLint and a README exist.
Dependencies: none; this epic unblocks everything else.
Priority: P0. Complexity: L (many small items).
Acceptance criteria:
- eas-update.yml runs jest before eas update; ci.yml runs the mobile suite
  on PRs; a red suite blocks both.
- saveData refuses or loudly interrupts past a hard size threshold; a
  blocking modal demands an export; a test covers the guard.
- Widget output equals lib/analytics.js output on a fixture blob, by test.
- lib/loan.js, lib/soa.js, lib/thirteenth.js, split rounding, notes math
  parser, lib/search.js, receipt-parse.js each have a dedicated suite; the
  recurring engine lives in lib/ as a pure function with tests.
- ESLint green in CI; mobile/README.md exists covering architecture,
  invariants, and OTA versus rebuild.
Definition of done: standing definition plus: no new console warnings
introduced; the founder can read the README and correctly answer how a
change ships.

## Epic 2: Security Hardening

Business goal: the privacy brand is verifiably true, and no single leaked
credential can compromise every install.
User problem: users were told nothing leaves the phone while a fetch
disagrees; a supply chain compromise would reach a finance app silently.
Expected outcome: policy and code agree everywhere; the OTA chain is
pinned, scoped, and eventually signed; the legacy page no longer endangers
the trust origin; at rest encryption designed into the SQLite migration.
Dependencies: Epic 1 (CI gate) for the workflow changes; rebuild batch 1
for signing and secure store; Epic 10 timing for the billing rebuild.
Priority: P0 for the compliance and pinning items; P2 for encryption.
Complexity: M (near term items) plus the encryption share of the SQLite
epic.
Acceptance criteria:
- Play data safety form and listing copy match observed network behavior;
  FX fetch fires only after a currency feature is used.
- eas-cli pinned to an exact version; actions pinned to SHAs; EXPO_TOKEN
  scoped and rotated; the publishing branch protected.
- The legacy PWA is retired from the Pages root (or fully escaped and SRI
  pinned); privacy.html and /app unaffected.
- EAS Update code signing enabled before the production channel opens.
- App lock no longer silently self disables; re enroll prompt designed.
Definition of done: standing definition plus: a network capture on a
physical build shows only the documented endpoints; Security_Audit.md
updated to reflect closed findings.

## Epic 3: Design System

Business goal: a premium, coherent product feel that compounds instead of
drifting, and audit findings fixed once in components instead of six times
in screens.
User problem: chips are too small to tap and silent to screen readers;
sheets bury their buttons; the debts screen shames; screens feel like
different apps.
Expected outcome: the token additions, Chip, Button, Sheet, Input and
Field, ListRow, and Toast from Design_System.md exist and the drifted
screens are migrated; the palette contrast test guards every pairing.
Dependencies: Epic 1 (CI) so migrations are gated; feeds Epics 4 and 5.
Priority: P1. Complexity: L.
Acceptance criteria:
- Chip ships with 44pt targets, selected state announcements, and replaces
  all 12 hand rolled sites; Button replaces the 14 save and cancel sites.
- Sheet provides the pinned footer and modal focus containment; LogSheet,
  the salary modal, and the debt editor run on it.
- The palette test (every text token against every surface, both modes,
  all 8 palettes) runs in CI and passes after the faint retune.
- debts.js uses Card, SectionHeader, ListRow, and body colored balances
  (warning only for true warning states).
- Tab bar survives font scale 2.0 without clipping.
Definition of done: standing definition plus: zero raw elevation or shadow
properties outside theme.js; no new hardcoded font sizes; before and after
screenshots recorded for the founder.

## Epic 4: Dashboard Experience

Business goal: the daily open answers the daily question instantly, which
is the retention promise.
User problem: safe to spend can sit below the fold for 48 hours after
payday; zero value utang cards and duplicate quick links pad the scroll;
sample data can silently fake the first net worth.
Expected outcome: safe to spend always first; conditional cards collapse
when done or empty; the sample data banner with one tap clear protects the
first real number; the comeback card welcomes lapsed users back.
Dependencies: Epic 3 components for any touched surfaces; the comeback
card depends on the coach engine only.
Priority: P1. Complexity: M.
Acceptance criteria:
- Safe to spend is the first card in every state; the sweldo plan
  collapses to a banner once step one is done; zero balance utang cards
  hide or merge.
- A persistent, dismissible banner shows while SAMPLE_TX_IDS rows remain,
  with a one tap clear removing only sample rows; headline numbers
  rendered over sample data are visually marked.
- The comeback card fires exactly once on first open after a 7 plus day
  real log gap, offers the single catch up entry, never shows the gap
  length, and routes into the sweldo plan when within 48 hours of a
  payday.
Definition of done: standing definition plus: the activation and comeback
local counters (Analytics.md) record the relevant events.

## Epic 5: Transaction Experience

Business goal: logging stays under 5 seconds forever; the habit loop's
friction ceiling is removed.
User problem: a custom expense is 4 to 6 taps plus a scroll; backdating
needs a typed ISO date; TalkBack users cannot log money at all; two income
UIs behave differently.
Expected outcome: the reordered LogSheet (amount first, autofocus,
secondary fields collapsed, pinned footer) on the shared Sheet; date chips
for the last 14 days; the TalkBack batch (focus containment, chip states,
live regions) done; the salary modal merged into LogSheet income mode.
Dependencies: Epic 3 (Sheet, Chip, Button); the TalkBack batch can start
first since it touches the same file.
Priority: P0 for the TalkBack batch, P1 for the rest. Complexity: L.
Acceptance criteria:
- A custom expense with a preset category is 3 taps plus the amount, with
  Add reachable without scrolling, keyboard up, on a 6.1 inch screen.
- TalkBack end to end: open the sheet, hear the title, pick a category
  (selection announced), enter an amount, hear validation errors, hear
  the success toast with Undo, never focus anything behind the sheet.
- Backdating within 14 days requires no typing; goal target dates
  validate on save.
- One income flow exists; payday logging gets the same celebration as an
  expense log.
Definition of done: standing definition plus: a component test covers
LogSheet validation and submit wiring; tap count and TalkBack walkthrough
recorded in QA notes.

## Epic 6: Financial Intelligence

Business goal: the app stays trustworthy as an advisor (the calculators
are the acquisition surface and the insights are the Pro surface).
User problem: statutory rates go stale silently; deadline dates ignore
weekends; forecasts and projections carry no year versioning; utang and
debts split across surfaces confuses the money owed mental model.
Expected outcome: per year rate versioning with a stale year warning; tax
deadline weekend and holiday shifting; the unified Debts and Utang tab
with Split promoted; the debt detail screen with Log payment as the
primary action; the calculator to ledger bridge.
Dependencies: Epic 3 components; local usage counters (Epic 9) inform the
tab swap; founder sign off on the tab change (significant navigation
change).
Priority: P1 for rates and bridge, P2 for the tab and detail screen.
Complexity: L.
Acceptance criteria:
- phtax.js exposes rates keyed by year; tools warn when the device year
  has no table; tests cover the boundary.
- BIR deadline dates shift for weekends and PH holidays via
  lib/holidays.js, tested.
- The Debts tab presents loans and cards, owed to me, and I owe as
  segments; Split is reachable in one tap from the tab; existing routes
  keep working.
- Every calculator result screen offers one contextual bridge action
  (start a goal, log it, set the budget), dismissible and never gating
  the result.
Definition of done: standing definition plus: bank officer or tax
professional agent verification on any changed money math before merge.

## Epic 7: AI Platform

Business goal: the infrastructure that lets Pan use an LLM without
breaking a single product promise (offline, private, honest numbers).
User problem: Pan is brittle to phrasing; users ask questions the keyword
matcher misses; but AI must not leak the ledger or invent numbers.
Expected outcome: the PanBrain abstraction with RulesBrain extracted; the
proxy backend deployed (keys, quotas, logging, kill switch); prompt
registry and evaluation harness; streaming contract in place. No user
facing LLM yet at this epic's close; that is Epic 8.
Dependencies: Sentry (rebuild batch 1); billing entitlements (Epic 10)
for the paid tier; the AI guardrail rules in CLAUDE.md first.
Priority: P2. Complexity: XL.
Acceptance criteria:
- RulesBrain passes the existing behavior unchanged (snapshot tests over
  intents and responses).
- The proxy serves a staging environment with per install quotas, cost
  logging, and a remote kill switch the app respects.
- The evaluation harness runs the golden set and the property checks (no
  invented numbers, guardrail compliance) in CI for the proxy repo.
- No provider key exists anywhere in the app bundle (verified by grep in
  CI).
Definition of done: standing definition plus: AI_Strategy.md updated with
as built decisions; a cost dashboard exists before any user traffic.

## Epic 8: AI Companion

Business goal: the differentiating coach experience, priced as the Pan AI
add on (Monetization.md), that no PH competitor can match honestly.
User problem: users want to ask about their money in their own words and
get warm, correct, Taglish answers.
Expected outcome: LlmBrain live behind opt in consent for Pro users with
the add on; streaming replies in the existing chat UI; conversation
memory in its own capped store; thumbs feedback wired to evaluation;
offline and quota exhaustion degrade gracefully to RulesBrain.
Dependencies: Epic 7 entirely; Epic 10 for entitlements and pricing.
Priority: P3 (first user traffic in the Intelligence phase). Complexity:
XL.
Acceptance criteria:
- The consent screen shows the exact digest before the first message
  leaves the phone; declining loses nothing that existed before.
- Every number in a reply appears in the supplied facts (property check
  in production sampling, not just CI).
- Memory lives outside salapify_data_v2, capped, erased by erase
  everything.
- Thumbs ratio and cost per user visible on the dashboard; the kill
  switch tested in production once.
Definition of done: standing definition plus: data safety form and
privacy policy updated the same release; the legal compliance agent
reviews the consent copy; founder approves before rollout widens past
testers.

## Epic 9: Growth

Business goal: compounding organic acquisition without paid virality or
trust erosion.
User problem: the shareable moments exist but are buried; seasonal
calculator traffic bounces without a bridge; nobody can measure any of
it.
Expected outcome: local usage counters (privacy safe, per Analytics.md
stage 1); split promoted (rides Epic 6); via Salapify attribution with
opt out on shared reminders and statements; recap share polish; seasonal
store listing updates (13th month in November, tax in Q1); the
notification decay and comeback notification per Product_Strategy.md.
Dependencies: Epic 6 for split surfacing; Analytics stage 1 counters
first so effects are measurable.
Priority: P2. Complexity: M.
Acceptance criteria:
- Screen open and feature use counters exist locally with a diagnostics
  view; nothing transmits.
- Shared reminder and statement texts carry the attribution line with a
  visible setting to disable it.
- Lapsed notification cadence: normal days 1 to 3, one comeback message
  day 7, then silence until next open; tested against the scheduling
  logic.
- Store listing has seasonal variants prepared for November and Q1.
Definition of done: standing definition plus: the aso-marketer and
legal-compliance agents review listing copy changes; no new notification
fires without an entry in the notification inventory.

## Epic 10: Premium Features

Business goal: clean revenue that funds the roadmap, per Monetization.md:
lifetime Pro at PHP 249 (launch PHP 199), the AI add on later.
User problem: none today (Pro is free); the problem is business
sustainability, and users need the free tier to stay whole while paying
users get real depth.
Expected outcome: Play Billing integrated (rebuild batch 1); legacy
entitlement stamping for early users BEFORE billing activates; the
repositioned Pro set (caps, backup depth, projection, forecast, trend,
movers, unlimited recurring, palette pack); the health score either given
its explaining sentence or cut; paywall and restore flows; the free
durability move (basic auto backup free) ships ahead of all of this in
the Stabilize phase.
Dependencies: rebuild batch 1; Play Console setup lead time; Epic 1 CI;
founder pricing sign off; legal compliance review of paywall copy.
Priority: P1 for the free durability move, P2 for billing. Complexity:
XL.
Acceptance criteria:
- Every existing install at stamping time holds Pro forever, verified
  across reinstall via the restore flow where technically possible and
  documented honestly where not.
- Purchases, restores, and refunds work on a physical device through
  Play internal testing; entitlement is cached offline (an offline app
  must not lose Pro on a flight).
- The free tier after launch contains everything in the Monetization.md
  free list; no user loses anything they had.
- Listing copy reads Free core features, no ads.
Definition of done: standing definition plus: release manager pass on
the rebuild; the founder explicitly approves pricing and the launch
window; Monetization.md updated with final prices.

## Cross epic ordering constraints

1. Epic 1 precedes everything (the gate).
2. Epic 2 compliance items ride week 1; signing precedes production.
3. Epic 3 components precede the Epic 4, 5, 6 screen work that uses
   them.
4. Epic 10 free durability ships in Stabilize; billing rides rebuild
   batch 1; entitlement stamping precedes billing activation.
5. Epic 7 precedes Epic 8; both follow Sentry and billing.
6. The SQLite and encryption migration (tracked in Epic 1 and 2 scope,
   rebuild batch 2) precedes any feature that grows the blob further.
