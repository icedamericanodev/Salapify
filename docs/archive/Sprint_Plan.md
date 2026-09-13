# Sprint Plan

Sprint 1, 2026-07-10. Weekly sprints for the first 18 weeks (phases 1 to
3 of Implementation_Plan.md), then a phase level plan for months 5 to 9.
Sized for one development stream (founder plus AI agents): each sprint
carries at most one significant item plus small items, optimizing for
sustainable pace over throughput. Sprint numbering continues from this
planning sprint.

Standing definition of done for every sprint: compile check passes on
every changed file; the jest suite is green locally and in CI; a QA pass
ran with must fixes fixed and rechecked; the update stamp bumped on any
push touching mobile/; merges follow CLAUDE.md rules; docs updated when a
documented contract changes. Sprint specific additions listed per sprint.

## Phase 1: Stabilize (Sprints 2 to 5)

### Sprint 2 (week 1): Close the Critical findings

Objectives: the pipeline is gated, the cliff is guarded, compliance is
true.
Deliverables:
- ci.yml runs the mobile jest suite on PRs; eas-update.yml runs it before
  publishing.
- saveData hard size guard plus the blocking export modal.
- Play data safety form and listing line corrected; FX fetch gated behind
  currency feature use.
- eas-cli pinned, actions SHA pinned, EXPO_TOKEN scoped and rotated,
  branch protection on.
- setCurrencySymbol moved to an effect.
- Legacy PWA retirement decision executed (stop deploying index.html and
  sw.js; privacy.html and /app untouched).
Acceptance criteria: a deliberately broken test blocks both workflows; a
1.9MB fixture blob triggers the modal; a network capture shows no FX call
before a currency feature is touched; the Pages origin serves no
executable legacy app.
Risk: the Pages change breaks the privacy policy URL (mitigate: verify
the URL before and after; it is Play listed).
Definition of done: standing plus Security_Audit.md findings SEC-2 and
SEC-5 marked closed.

### Sprint 3 (week 2): Free durability and the TalkBack logging batch

Objectives: free users stop losing histories; blind users can log money.
Deliverables:
- Daily auto backup available to free users (rotation depth stays Pro);
  backup prompts updated.
- LogSheet TalkBack batch: modal focus containment, chip selected states,
  error and toast live regions, labeled backdrop.
- Sample data banner with one tap clear (removes only SAMPLE_TX_IDS
  rows).
Acceptance criteria: a fresh free install can enable auto backup and a
dated file appears; TalkBack walkthrough of the full log flow passes (per
Epic 5 criteria); the banner shows while sample rows exist and the clear
removes only them.
Risk: the auto backup gating change touches the Pro seam; regression
test the Pro flag paths.
Definition of done: standing plus the accessibility-specialist agent (or
equivalent QA) re verifies the batch.

### Sprint 4 (week 3): Test the money code

Objectives: every money engine has a regression net.
Deliverables:
- Dedicated suites for lib/loan.js, lib/soa.js, lib/thirteenth.js,
  split.js rounding, the notes math parser, lib/search.js,
  lib/receipt-parse.js.
- The recurring posting engine extracted to lib/recurring.js (pure,
  tested); AppData delegates to it.
- Widget math parity: the task handler imports lib/analytics.js; a
  parity test on a fixture blob.
Acceptance criteria: suite count grows by 8 or more files; the recurring
extraction changes zero behavior (fixture comparison before and after);
widget figures equal analytics figures by test.
Risk: the recurring extraction touches posting logic (money math);
data-migration-reviewer style scrutiny even though the stored shape is
unchanged.
Definition of done: standing plus bank-officer verification on the loan
suite expectations.

### Sprint 5 (week 4): Performance and hygiene

Objectives: logging stays smooth as data grows; the repo reads like one
product.
Deliverables:
- Provider value memoized; heavy derivations in home, budget, and
  insights under useMemo.
- ESLint (eslint-config-expo) green and wired into CI; Dependabot
  security alerts on.
- mobile/README.md written; dead code deleted (MascotSkia, Placeholder);
  FX fetch timeout.
Acceptance criteria: a render count probe on the three hot screens shows
no re-render on unrelated data changes; lint passes; the README covers
architecture, invariants, and OTA versus rebuild.
Risk: memoization can mask stale closures; keep the callbacks stable via
refs per the existing dataRef pattern.
Definition of done: standing plus Performance_Audit.md PERF-1 marked
mitigated.

## Phase 2: Sharpen (Sprints 6 to 11)

### Sprint 6 (week 5): Design system tokens and Chip

Objectives: the token layer lands; the worst duplication dies.
Deliverables: theme.js additions (type with line heights, moneyText,
kicker, inputSurface, warningSurface pair, spacing.xxxl, elevation.glow);
the palette contrast test (all tokens on all surfaces, both modes, 8
palettes) with the faint retune to make it pass; the Chip component;
first 6 of 12 chip sites migrated.
Acceptance criteria: the contrast test runs in CI and passes; migrated
chips measure 44pt and announce selection; zero visual regressions on
migrated screens (screenshot pass).
Risk: the faint retune shifts every palette subtly; the founder eyeballs
all 8 before merge.
Definition of done: standing plus Design_System.md updated with as built
token values.

### Sprint 7 (week 6): Chip completion, Button, tab bar

Objectives: the component layer covers every high frequency tap.
Deliverables: remaining chip sites migrated; the Button component with
the 14 save and cancel sites migrated; the tab bar font scale fix and
label token; PeriodSelector folded onto useTheme and Chip.
Acceptance criteria: font scale 2.0 shows no clipped tab labels; every
migrated button meets 44pt and announces disabled and busy states.
Risk: broad shallow diffs invite regressions; migrate screen by screen
with the suite green between each.
Definition of done: standing plus a full app click through QA pass.

### Sprint 8 (week 7): The Sheet and LogSheet speed

Objectives: the heartbeat flow gets fast and contained.
Deliverables: the Sheet component (pinned footer, modal accessibility,
grab handle, radius.xl); LogSheet migrated and reordered (amount first
with autofocus, category second, the rest behind More options); date
chips for the last 14 days; the shared Toast extracted (Reanimated,
two line).
Acceptance criteria: Epic 5's tap count test passes (3 taps plus amount,
Add reachable with keyboard up); the TalkBack pass from Sprint 3 still
holds on the new structure; backdating needs no typing.
Risk: LogSheet is the most important file in the app; the component test
from Epic 5 lands BEFORE the reorder, and the old sheet stays one revert
away.
Definition of done: standing plus a before and after logging speed video
for the founder.

### Sprint 9 (week 8): Home hierarchy and income unification

Objectives: the daily answer above the fold; one income flow.
Deliverables: safe to spend always first; sweldo plan collapses to a
banner after step one; zero balance utang cards hidden or merged;
duplicate quick links cut; the salary modal replaced by LogSheet income
mode with celebration parity; goal date validation.
Acceptance criteria: Epic 4 criteria for card order and collapsing; the
income flow carries the date row and toast; a garbage goal date is
rejected with copy.
Risk: home is the brand surface; the founder reviews the new order on
device before merge.
Definition of done: standing plus the ux-designer agent (or equivalent)
re reviews the home flow.

### Sprint 10 (week 9): Debts experience

Objectives: the debt persona stops being shamed and starts paying in one
tap.
Deliverables: debts.js migrated onto Card, SectionHeader, ListRow;
warning color only for true warning states; the debt detail screen with
Log payment as the primary action and edit behind it; remaining
accessibility roles on debt rows.
Acceptance criteria: Epic 6 and UX-4 and UX-6 criteria; the payment flow
is reachable in 2 taps from the tab; the payment math is untouched
(fixture test).
Risk: moving the payment UI must not touch splitDebtPayment; the money
math files are read only this sprint.
Definition of done: standing plus qa-tester pass focused on payment
edge cases.

### Sprint 11 (week 10): Retention mechanics and the SQLite design doc

Objectives: the comeback moment is designed in; the storage future is
designed on paper.
Deliverables: the comeback coach card with the catch up entry; the
lapsed notification decay (days 1 to 3, day 7, silence); the nudge time
question in onboarding (implementation intention chips); local usage
counters with the diagnostics view (Analytics stage 1); the SQLite plus
encryption migration design doc (schema, migration steps, rollback,
widget seam, test plan).
Acceptance criteria: the comeback card fires once per lapse and never
shows the gap length; notification schedules verified by test; counters
record screen opens locally with zero transmission; the design doc
reviewed by the data-migration-reviewer agent.
Risk: notification changes are easy to get subtly wrong across
timezones; extend the existing scheduling tests first.
Definition of done: standing plus the behavior principles (red as event,
notifications name actions) checked against every new surface.

## Phase 3: Monetize and rebuild (Sprints 12 to 19, weeks 11 to 18)

### Sprint 12 (week 11): Rebuild batch 1 preparation

Objectives: everything the rebuild needs, staged and tested.
Deliverables: Play Console products configured; billing library
integrated behind a flag; fingerprint runtimeVersion configured; Sentry
integrated behind the privacy disclosure; expo-secure-store added;
allowBackup decision implemented; legacy Pro entitlement stamping code
(ships and runs BEFORE billing activates).
Acceptance criteria: the branch builds an APK on EAS successfully; every
existing tester install receives the legacy entitlement; Sentry events
arrive from a test crash on the internal build.
Risk: the first rebuild in months; expect native surprises, budget the
whole sprint.
Definition of done: standing plus release-manager pass; the founder
told loudly this is a rebuild, not OTA.

### Sprint 13 (week 12): Rebuild batch 1 ships

Objectives: the new binary reaches testers cleanly.
Deliverables: the preview APK distributed; runtime bump verified (old
bundles do not load on the new runtime and vice versa); crash free rate
visible in Sentry; privacy policy and data safety form updated for
Sentry the same day.
Acceptance criteria: OTA publishes target the new runtime; a staged
test of update signing (if enabled this batch) passes; no Sentry crash
groups above threshold in the first 72 hours.
Risk: a bad runtime bump bricks preview phones; the fingerprint policy
plus a staged tester rollout mitigates.
Definition of done: standing plus 72 hours of stable telemetry before
the next sprint builds on it.

### Sprints 14 to 15 (weeks 13 to 14): Pro repositioning and paywall

Objectives: the Pro line matches Monetization.md and purchases work.
Deliverables: the target Pro set gated (caps, backup depth, projection,
forecast, trend, movers, unlimited recurring, palette pack); the health
score given its explaining sentence or cut; paywall, purchase, restore,
and refund flows through Play internal testing; free tier verified
whole.
Acceptance criteria: Epic 10 criteria; a purchase on a physical device
unlocks offline and survives reinstall via restore; no previously free
capability is lost by any existing user.
Risk: entitlement edge cases (refunds, multi device) are the classic
billing trap; test matrix written first.
Definition of done: standing plus legal-compliance review of paywall
copy and the founder's explicit pricing sign off.

### Sprints 16 to 17 (weeks 15 to 16): Financial intelligence hardening

Objectives: the advisor surfaces stay true through time.
Deliverables: per year statutory rate versioning with stale year
warnings; BIR deadline weekend and holiday shifting; the calculator to
ledger bridge on every calculator result; via Salapify attribution with
opt out on shared texts.
Acceptance criteria: Epic 6 criteria; the tax-professional and
compensation-benefits agents verify the versioned tables; bridge taps
recorded in local counters.
Risk: rate table refactors touch five tools; snapshot the current
outputs first.
Definition of done: standing plus seasonal listing variants drafted
(November window).

### Sprints 18 to 19 (weeks 17 to 18): Production launch window

Objectives: Salapify goes to Play production, monetized, observable.
Deliverables: production channel opened with update signing verified;
staged rollout to production; the November pricing window if the
calendar aligns; the unified Debts and Utang tab decision executed if
the counter data supports it (otherwise documented and deferred);
launch support macros prepared.
Acceptance criteria: release-manager pass or fail checklist green; Play
vitals clean through the staged rollout percentages; store listing
consistent with the monetization truth rules.
Risk: Play review timing is external; nothing else in the plan blocks
on it.
Definition of done: standing plus the founder's go decision recorded;
support-retention-lead macros ready.

## Phase 4: Intelligence (months 5 to 9, planned at phase level)

Sprint level planning happens at the phase boundary with the founder;
the committed shape:

- Months 5 to 6: rebuild batch 2, the SQLite plus at rest encryption
  migration per the Sprint 11 design doc. Gated by the
  data-migration-reviewer on every diff, a staged rollout, and the free
  auto backup adoption metric (users must have file backups before
  migration day). The single riskiest change in the plan; nothing else
  significant ships alongside it.
- Months 6 to 7: Epic 7 (AI platform): PanBrain extraction, the proxy
  with quotas and kill switch, the prompt registry and evaluation
  harness. No user facing LLM traffic yet.
- Months 8 to 9: Epic 8 (AI companion): LlmBrain behind consent for the
  Pan AI add on cohort, streaming, memory, thumbs feedback; widened only
  as the thumbs ratio and cost dashboards allow. Growth work (Epic 9
  remainder, seasonal Q1 tax campaign) rides alongside.

Exit criteria for the horizon: the North Star (Weekly Honest Loggers)
growing, W4 logger retention above 25 percent, crash free above 99.5
percent, paid Pro conversion in the 3 to 5 percent band, the storage
ceiling gone, and Pan AI economics inside the Monetization.md budget.
