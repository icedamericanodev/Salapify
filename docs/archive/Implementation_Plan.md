# Implementation Plan

Sprint 1, 2026-07-10. The execution blueprint converting the Sprint 0 audit
into 6 to 12 months of development. Documentation only; implementation begins
after founder approval. Companion documents: Product_Backlog.md (epics),
Sprint_Plan.md (week by week), Design_System.md, AI_Strategy.md,
Product_Strategy.md, Analytics.md, Monetization.md.

## 1. Executive summary

Sprint 0 found a well engineered offline first finance app whose risks
cluster in four places: ungated releases, a storage cliff, trust surface
gaps, and a core loop that is slower and less accessible than the
engineering deserves. This plan sequences the fixes and the growth work into
four phases over roughly 9 months: Stabilize (weeks 1 to 4), Sharpen the
core loop (weeks 5 to 10), Monetize and rebuild (weeks 11 to 18), and
Intelligence (months 5 to 9). The ordering principle: nothing user visible
ships on an ungated pipeline, nothing paid ships before billing exists, and
nothing AI ships before observability and a proxy exist.

Reviewing the Sprint 0 roadmap against user value and risk changed four
priorities, documented with reasons in section 4 below: free tier durability
moved up, monetization infrastructure moved from someday to a scheduled
phase (it gates AI), the unified Debts and Utang tab moved from pending
decision to committed (the product strategy work confirms utang is the
differentiator), and a simpler interim alternative to the SQLite migration
was evaluated and rejected with reasoning.

## 2. Guiding principles

1. The ledger is sacred. No change ships that can lose, corrupt, or
   misstate user money data. Migration and money math changes always pass
   the data-migration-reviewer gate and carry tests.
2. Calm is the brand. Features, colors, copy, and notifications reduce
   financial anxiety, never weaponize it. Warning color only for true
   warning states. The app never shames.
3. Offline first is a promise, not a phase. Every feature works with zero
   connectivity; network only ever makes things nicer. AI will follow the
   same rule (rules brain offline, LLM brain online).
4. Privacy is a feature. Financial data never leaves the device without an
   explicit user action. Any telemetry is opt in, anonymous, and disclosed.
   Policy documents and code must never contradict each other.
5. Small tested steps. Every slice compiles, passes the suite, and ships
   OTA behind the CI gate. Rebuilds are batched deliberately, never
   accidental.
6. Fast where it counts. The daily log must stay under 5 seconds and 60fps
   on a mid range Android. Performance budgets are acceptance criteria, not
   aspirations.
7. Accessible by default. New UI meets the design system's accessibility
   rules (44pt targets, AA contrast on every token pair, announced states)
   at review time, not in a later pass.
8. Free users are future Pro users. Core tracking, data portability, and
   data durability are never paywalled. Pro sells depth (intelligence,
   automation, foresight), not safety.

## 3. Success metrics

Full definitions and instrumentation constraints in Analytics.md. The plan
level targets, measured from the start of implementation:

- Release safety: 100 percent of OTA publishes pass the test gate; zero
  bad bundle incidents requiring emergency republish; crash free session
  rate visible and above 99.5 percent once Sentry lands.
- Core loop speed: logging a custom expense in 5 seconds or fewer, measured
  as taps (3 or fewer to reach Add for a preset amount flow) and frame
  timing on a reference mid range device.
- Accessibility: TalkBack end to end pass on the log, debt payment, and
  restore flows; automated contrast test green across all palette and
  surface pairs.
- Activation (post telemetry, opt in): a defined aha metric of first real
  log within day 1 and 5 logs plus one insight view within week 1 for 40
  percent of new installs.
- Retention: week 4 logging retention (users who logged at least 3 days in
  week 4) above 25 percent of activated users.
- Monetization (once billing ships): 3 to 5 percent of monthly active
  loggers on paid Pro within 90 days of launch, with early access cohort
  grandfathered per the standing promise.
- Data safety: zero storage wall lockouts (guard modal ships week 1); auto
  backup adoption above 50 percent of Android actives once free.

## 4. Roadmap review: what changed from Sprint 0 and why

Every Sprint 0 recommendation was re-challenged for priority, user value,
risk reduction, simpler alternatives, dependencies, and hidden assumptions.

Confirmed unchanged:
- The nine quick wins remain the first work. Re-tested against is there a
  simpler solution and none of them shrink further; they are already
  minimal. The CI gate remains the very first change because every later
  item assumes a gated pipeline.
- Memoization before any context split. The split stays deferred until
  measurement proves memoization insufficient.
- The TalkBack logging batch stays P0: it is small, and the audit's verdict
  (a blind user cannot log money at all) makes it an inclusion defect, not
  polish.

Changed, with reasons:

1. Free tier durability: raised from P1 mid pack to the Stabilize phase,
   immediately after the quick wins. Re-examining user value: silent total
   data loss on a lost phone is the single worst user outcome the product
   can cause, it disproportionately hits the target market (mid range
   Androids, high device turnover), and the fix is mostly a gating change
   that ships OTA. The Sprint 0 ordering underweighted it because it was
   framed as a product decision; this plan makes the decision explicit
   (make daily auto backup free, keep rotation depth and multi folder as
   Pro) and schedules it. The allowBackup revisit stays in the rebuild
   batch.
2. Monetization infrastructure: moved from P2 when the business says so to
   a scheduled phase (weeks 11 to 18). Reason: the AI strategy makes paid
   AI features structurally dependent on billing and entitlements, and
   billing needs a rebuild plus Play Console lead time. Waiting until AI is
   ready would serialize two long poles; scheduling billing now
   parallelizes them. Assumption surfaced: Sprint 0 assumed monetization
   timing was purely a business call; it is actually a technical dependency
   of the AI roadmap.
3. Unified Debts and Utang tab: moved from pending founder alignment to
   committed in the Sharpen phase. Reason: the product strategy work
   (Product_Strategy.md) confirms utang plus split is the differentiator
   and the acquisition story; leaving the differentiator buried while
   polishing everything else maximizes effort, not value. The cheap
   instrumentation first step (local screen open counters) still precedes
   the tab swap so the decision is data informed, but the default is now to
   do it, not to study it.
4. SQLite migration: evaluated a simpler alternative and kept SQLite, but
   moved the design doc earlier (Sharpen phase) and the implementation into
   the rebuild era (months 4 to 6). The simpler alternative considered:
   sharding the blob across multiple AsyncStorage keys (transactions per
   year, collections separate), which ships OTA with no native module and
   removes the single row cliff. Rejected because it multiplies the
   consistency surface (multi key atomicity does not exist in
   AsyncStorage), complicates the snapshot and restore invariants that are
   currently the codebase's crown jewels, and still leaves the 6MB total
   database cap and the plaintext at rest finding unfixed. One well tested
   native migration beats two risky migrations. The write guard (quick win)
   plus memoization buys the runway to do it once, correctly.
5. Design system: Sprint 0 scheduled a Chip component and a debts tone
   pass as isolated items. This plan groups them under a design system
   foundation epic (tokens are already good; the gap is component level
   consistency) so the premium feel work lands as a system, not as
   scattered patches. Explicitly not a big bang redesign: the Design
   System document governs new and touched surfaces; wholesale reskinning
   is out of scope for this horizon.
6. Notification refill strategy: raised from future features to the
   Sharpen phase. Re-examining user value: the one shot reminder windows
   running dry silently disables the retention system for exactly the
   lapsed users who need it most, and the behavior work
   (Product_Strategy.md) identifies the lapsed comeback moment as the
   churn decider. Cheap (M) relative to its retention leverage.

Assumptions this plan makes explicit:
- The founder wants a Play production launch within this horizon; the
  release strategy below assumes closed testing now, production within the
  Monetize phase. If launch is later, only the compliance items shift.
- One development stream (founder plus AI agents) with occasional
  specialist agent passes; sprints are sized for that, not for a team.
- No backend exists until the AI proxy; every earlier phase must require
  zero servers.
- Early access users keep Pro free forever (standing promise); monetization
  modeling accounts for that cohort.

## 5. Engineering priorities

1. Gate the pipeline (CI runs mobile tests; OTA publish blocked on green).
2. Guard the storage wall (hard cap plus blocking export modal).
3. Observability (Sentry in the rebuild batch; interim opt in crash share
   from the ErrorBoundary).
4. Kill the known landmines (setCurrencySymbol in render, manual
   runtimeVersion, widget math duplication).
5. Test the untested money code (loan, SOA, thirteenth, recurring engine,
   split rounding, notes parser, search, receipt parse) and extract the
   recurring engine to a pure lib.
6. SQLite plus at rest encryption as one designed migration (design doc in
   Sharpen, implementation months 4 to 6, data-migration-reviewer gated).
7. Repo hygiene (legacy PWA retirement, README, ESLint, dead code removal).

## 6. Product priorities

1. Make the daily log effortless (LogSheet reorder, amount first, pinned
   actions; date chips for backdating).
2. Put the differentiator on the tab bar (unified Debts and Utang tab,
   split promoted, person ledgers one tap closer).
3. Protect the first session (sample data banner and one tap clear, safe
   to spend above the fold, home hierarchy).
4. Payday as ritual (sweldo plan consolidation into LogSheet, celebration
   parity for income).
5. Keep the calculators as acquisition hooks (per year statutory rate
   versioning so they stay trustworthy; deadline weekend shifting).
6. Free durability (auto backup free tier) as a retention and trust
   feature.
7. Monetization launch per Monetization.md (billing, entitlements, Pro
   repositioning around intelligence and automation).

## 7. Security priorities

Ordered from Security_Audit.md with two adjustments: the data safety form
fix and FX fetch alignment ship in week 1 (store compliance is binary), and
at rest encryption is explicitly coupled to the SQLite migration so there
is exactly one migration event.

1. Week 1: data safety form corrected, FX fetch gated behind currency use,
   eas-cli and action pinning, EXPO_TOKEN scoped and rotated, branch
   protection, legacy PWA retired from the trust origin.
2. Rebuild batch: EAS Update code signing, fingerprint runtimeVersion,
   expo-secure-store introduced.
3. SQLite era: SQLCipher or Keystore wrapped encryption at rest for blob
   and receipts; app lock hardening (sticky setting, re enroll prompt) in
   the same arc so the lock guards ciphertext, not pixels.
4. Continuous: no secrets in the client ever (AI keys live in the proxy);
   ML Kit network behavior verified on a physical build; encrypted backup
   option after core encryption lands.

## 8. UX priorities

Per UX_Audit.md fix order, unchanged: LogSheet speed, home hierarchy, utang
navigation, debt detail screen, then dates, tone, chips, income merge, and
polish. The Design System document now governs how these land (shared Chip,
sheet pattern, pinned footers) so each fix also pays down drift. The Tools
tab decision is deferred until local usage counters exist; no screen is
deleted in this horizon.

## 9. Accessibility priorities

1. Batch one (with the LogSheet work, same files): modal focus containment,
   chip selected states, error and toast live regions.
2. Batch two: faint token contrast retune plus the automated contrast test;
   dynamic type fixes (tab bar height, toast wrapping).
3. Batch three: pressable role sweep, chart and week chain spoken
   summaries, legacy Animated reduce motion, emoji out of announced
   strings.
4. Standing rule: the Design System accessibility section is acceptance
   criteria for every new component; the contrast test runs in CI.

## 10. AI priorities

Full architecture in AI_Strategy.md. Sequenced: guardrail rules written
into CLAUDE.md now (no keys in the client, no chat history in the main
blob, models phrase and resolvers compute); PanBrain abstraction as a pure
refactor; proxy backend design and deployment; LlmBrain with tool use
generated from the intent registry; memory, streaming, and evaluation
after. Nothing AI ships before Sentry, billing, and the proxy exist. AI is
the last phase deliberately: it is the highest leverage differentiator but
every prerequisite (observability, entitlements, a backend) is also needed
by something earlier, so the prerequisites are never built for AI alone.

## 11. Performance priorities

1. Memoize the provider value and the heavy screen derivations (home,
   budget, insights).
2. Performance budget in CI review checklist: no unmemoized full array
   passes in render paths on the three hot screens.
3. FX fetch timeout; widget read path through the storage seam.
4. SQLite migration as the structural fix; context split only if
   measurement demands it after memoization.

## 12. Developer experience priorities

1. mobile/README.md (architecture, invariants, OTA versus rebuild rules).
2. ESLint in CI; Dependabot security alerts.
3. Component test seed (LogSheet validation, restore confirm) so UI wiring
   gains a regression net.
4. Update stamp automated from the git SHA at publish time.
5. Docs upkeep rule: Database_Review.md schema section updates with every
   SCHEMA_VERSION bump; the design system doc updates with every new
   component.

## 13. Release strategy

- Channels: preview (internal, current testers) stays the OTA target for
  all JS work. Production channel opens with the first rebuild batch.
- OTA cadence: batched pushes per finished feature slice (existing
  CLAUDE.md rule), now gated on the test suite. Update stamp bumps
  continue until automated.
- Rebuild batches (each one APK or AAB, one runtime bump, release manager
  pass, full QA):
  1. Rebuild batch 1 (Monetize phase start): fingerprint runtimeVersion,
     Sentry, expo-secure-store, allowBackup decision, billing library.
  2. Rebuild batch 2 (months 4 to 6): expo-sqlite plus encryption
     migration.
  Native changes never ride alone; anything needing a rebuild queues for
  the next batch.
- Play strategy: closed testing continues through Stabilize and Sharpen;
  production launch inside the Monetize phase after the compliance items
  (data safety form, policy alignment) are verifiably true and billing is
  live. Staged rollout percentages on production releases once available.
- Merge rules: unchanged from CLAUDE.md (QA pass, OTA check green, merge
  commits, significant changes announced, data loss risks escalated before
  merge).

## 14. Risks

Top risks to this plan specifically (full register in Risk_Register.md):

1. Single stream capacity: the plan is sized for one founder plus agents;
   any week with heavy non product demands slips a sprint. Mitigation:
   sprints carry at most one significant item plus small items; nothing is
   pipelined more than one phase ahead.
2. The SQLite migration is the riskiest single change in the plan (every
   user's data moves). Mitigation: design doc first, migration reviewer
   gate, the existing snapshot discipline, a staged rollout, and the
   auto backup free tier landing months earlier so every user has a file
   backup before migration day.
3. Billing and Play review timelines are outside our control. Mitigation:
   start Play Console setup at the beginning of the Monetize phase, not
   the end; keep the free product whole so a billing delay costs revenue,
   not users.
4. AI cost and quality uncertainty. Mitigation: the proxy design includes
   quotas and kill switches from day one; the rules brain remains the
   permanent fallback; evaluation harness before any user facing rollout.
5. Scope gravity: every phase has a temptation to pull in adjacent nice
   to haves. Mitigation: the backlog is the contract; anything not in the
   sprint plan waits for the next planning pass.

## 15. Dependencies

- CI gate precedes every other change (week 1, day 1).
- Design system Chip precedes the chip dependent UX and accessibility
  fixes; they land together in the Sharpen phase.
- Billing precedes any paid feature; entitlements precede AI monetization.
- Proxy backend precedes any LLM call; Sentry precedes the proxy going
  live to users.
- SQLite design doc precedes rebuild batch 2; auto backup free precedes
  the SQLite migration rollout (safety net in place).
- Local usage counters precede the Tools tab decision (and are themselves
  gated on the privacy stance documented in Analytics.md).
- Play production launch depends on: compliance quick wins done, billing
  live, crash reporting live, release manager pass.

## 16. Estimated timeline

Assumes one development stream; calendar dates are relative to approval.

- Phase 1, Stabilize: weeks 1 to 4. Quick wins, free durability, lint and
  README, money math test backfill, memoization, widget parity.
- Phase 2, Sharpen: weeks 5 to 10. Design system foundation (Chip, sheet
  pattern, tone pass), LogSheet speed and TalkBack batch, home hierarchy,
  unified Debts and Utang tab, debt detail screen, date chips,
  notification refill, contrast retune, SQLite design doc, local usage
  counters.
- Phase 3, Monetize and rebuild: weeks 11 to 18. Rebuild batch 1 (Sentry,
  fingerprint runtime, secure store, allowBackup, billing), Pro
  repositioning and pricing per Monetization.md, Play production launch,
  encrypted backup option, PanBrain refactor, AI proxy design.
- Phase 4, Intelligence: months 5 to 9. SQLite plus encryption migration
  (rebuild batch 2), AI proxy live, LlmBrain behind a flag for Pro,
  streaming chat, evaluation harness, memory. Growth work (referral loop
  polish, seasonal calculator campaigns) rides alongside.

Explicit non goals for this horizon: multi device sync, iOS launch, web
app revival, localization framework, full visual redesign.

## 17. Recommended sprint breakdown

Week by week detail with objectives, deliverables, acceptance criteria,
risks, and definitions of done lives in Sprint_Plan.md. Epic level scope,
priorities, and acceptance criteria live in Product_Backlog.md.
