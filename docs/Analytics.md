# Analytics Strategy

Sprint 1, 2026-07-10. How Salapify measures success without betraying its
privacy stance. The constraint is real and welcome: there is no server,
the privacy policy says nothing leaves the phone, and that promise is a
competitive advantage. The strategy is therefore staged: on device
counters first, opt in anonymized telemetry later, and crash reporting as
the one disclosed exception in between.

## 1. The privacy safe analytics architecture

Stage 1 (now, no policy change needed): local counters. Small integers and
booleans computed from data already on the device (transactions carry
dates; add only installDate and a few event counters under a dedicated
AsyncStorage key, never the main blob). Surfaced two ways: a local
diagnostics view the founder and testers can read, and aggregate lines a
user can choose to include when sending feedback. Nothing transmits
automatically.

Stage 2 (rebuild batch 1): crash reporting via Sentry, disclosed in the
privacy policy and the data safety form the same day it ships. Crash
payloads carry stack traces and device model, never ledger content;
breadcrumbs are configured to exclude user data.

Stage 3 (with or after billing): opt in telemetry. A single clear switch
(help improve Salapify), off by default, sending only anonymized booleans
and small bucketed integers: activation reached yes or no, weekly logger
yes or no, feature used bits, funnel step counters. Never amounts, labels,
names, dates of transactions, or any PII. The event dictionary below is
written so every event already satisfies this constraint.

Standing rules: code and policy never diverge (the Sprint 0 lesson); every
new event is reviewed against the never list; the opt in state itself is
respected in code, not just in copy.

## 2. Activation metrics

The aha moment, defined and testable: 3 real logs (income or expense, non
sample) on 3 distinct days within the first 7 days after onboarding, AND
one insight viewed (day one recap shown, Insights opened, or the home safe
to spend rendered from fully real data).

Why this definition: three distinct days is where a chain starts feeling
real (the app already animates this at 3 dots); the insight view is the
value half, because logging without seeing what the logs buy is chore
without reward; and the fully real data clause makes the sample data
cleanup measurable, since an insight rendered over sample rows does not
count.

Supporting activation measures:
- Time to first real log (target: within day 1).
- Onboarding completion rate and path chosen (clean slate versus sample).
- Sample data cleared by day 7 (its absence is a churn indicator).
- Nudge permission grant rate and chosen nudge time (once the
  implementation intention question ships).
- First payday captured: an income log or sweldo plan step within 48
  hours of the first scheduled payday after install.

## 3. Retention metrics

- Primary: Weekly Active Logger (WAL): a user with 3 or more distinct real
  log days in a calendar week (Monday keyed, matching the coach's week
  definition). App opens are vanity here; a user who opens daily and logs
  nothing is pre churn, not retained. Reported as W1, W4, and W12 logger
  retention curves.
- Payday capture rate: the share of a user's paydays where a real income
  log or sweldo plan step happens within 48 hours. The ritual health
  metric; it predicts WAL a week ahead.
- Comeback rate: the share of 7 plus day lapses that end in a new WAL week
  within 14 days of return. Directly measures the comeback experience the
  product strategy commits to.
- Plan level targets (from Implementation_Plan.md): 40 percent of installs
  activated; W4 logger retention above 25 percent of activated.

## 4. North Star metric

Weekly Honest Loggers: the count of users meeting the WAL threshold each
week.

Reasoning: it is the behavior everything else compounds from, it is
countable on device with a boolean, it cannot be gamed by engagement
tricks (a log is a deliberate act about real money), and it respects the
ethical line: nothing tempts the team to inflate opens.

Alternatives considered:
1. Monthly decision actions (coach card actions taken, debt payments
   logged, utang collected, sweldo plans completed). Closer to financial
   outcomes but low volume, noisy, and it tempts pushing cards to farm
   actions, which burns notification trust.
2. Positive kept rate months (the share of active users whose monthly
   recap kept rate is positive). Closest to the mission but lags a month,
   punishes low income users for math they cannot control, and optimizing
   it directly risks shame mechanics. Used as the outcome check on the
   North Star, not the North Star.

## 5. Feature adoption

Local counters per surface, bucketed (0, 1 to 5, 6 plus): quick add versus
custom log ratio, utang ledger users (any receivable or payable), split
used, calculator sessions per tool and the bridge conversion (calculator
session followed by a log within 48 hours), widget installed count, goals
active, treats active, recurring active, Pan conversations, backup
configured, search used.

Two decisions these counters exist to inform: the Tools tab versus unified
Debts and Utang tab swap (screen open counters gate the decision, per the
Implementation Plan), and the Pro feature mix at billing launch (which Pro
surfaces free users touch the teaser of most).

## 6. AI usage (when Pan AI ships)

Proxy side (see AI_Strategy.md section 8): requests per user distribution,
token cost per user, brain fallback rate, guardrail hit rate, thumbs up
and down ratio, latency percentiles, quota exhaustion events. On device:
exchanges used this month (shown to the user honestly), offline fallback
count. KPI: thumbs ratio above 85 percent positive and median cost per
active AI user under PHP 10 before widening rollout.

## 7. Funnels

- Install to activation: install, onboarding complete, first real log, 3
  logs 3 days, first insight view. Each step a local boolean with a
  timestamp bucket.
- Calculator bridge: calculator opened, result computed, bridge CTA
  tapped, log or goal created within 48 hours.
- Utang loop: receivable created, reminder shared, payment recorded,
  person paid off (and: split created, receivables generated per split).
- Monetization (post billing): Pro teaser viewed, paywall viewed, purchase
  started, purchase completed, refund. Play Console provides the purchase
  side natively without custom telemetry.
- Backup safety: backup prompt shown, backup completed (manual or auto),
  days since last backup bucket. This funnel exists because durability is
  a retention feature.

## 8. Crash monitoring

Sentry (rebuild batch 1): crash free session rate (target above 99.5
percent), ANR rate, top crash groups, release health per OTA update (the
update stamp or git SHA becomes the release tag so a bad publish is
attributable within hours). Play Console vitals (ANR and crash) watched in
parallel since they gate store ranking. Interim before Sentry: the
ErrorBoundary's opt in send crash log share action plus tester reports.

## 9. Performance monitoring

- CI level: bundle size trend per publish; jest suite duration.
- Device level (local, no transmission): cold start to interactive
  timestamp, save duration, and blob size (already measured as
  storageSize), logged to the local diagnostics view. Blob size
  distribution matters: it is the early warning for the storage wall.
- Sentry performance tracing (sampled) once crash reporting is stable:
  cold start, log sheet open to save, tab switch.
- Budgets as regressions: cold start under 2 seconds on the reference mid
  range device; log sheet open under 300ms; save under 100ms at typical
  blob sizes.

## 10. Success KPIs (the dashboard that matters)

| Area | KPI | Target |
| --- | --- | --- |
| North Star | Weekly Honest Loggers | growing week over week |
| Activation | percent of installs activated (7 day definition) | 40 percent |
| Retention | W4 logger retention of activated | above 25 percent |
| Ritual | payday capture rate | above 60 percent of scheduled paydays |
| Comeback | lapse to WAL recovery within 14 days | above 20 percent |
| Trust | notification opt out rate after grant | under 10 percent |
| Safety | users with a backup under 7 days old | above 50 percent of Android actives |
| Stability | crash free sessions | above 99.5 percent |
| Store | Play rating | 4.5 or higher |
| Revenue (post billing) | paid Pro share of monthly active loggers | 3 to 5 percent within 90 days |
| AI (post launch) | thumbs positive ratio | above 85 percent |

## 11. Leading indicators of churn (each with an intervention owner)

1. Log gap of 3 plus days after a previously active week. Intervene with
   the day 7 comeback notification, never more daily pings.
2. Payday passed with no log within 48 hours for a user with a schedule
   set: the ritual broke before the habit did.
3. Sample data still present at day 7: their numbers are fiction; churn
   follows the first wrong net worth.
4. Notifications toggled off in settings (distinct from never granted):
   trust was spent; audit which notification fired last before the
   toggle.
5. Zero quick add usage with 5 plus manual logs: paying full friction per
   log; surface quick add education or seed their top label as a preset.
6. Safe to spend at or below zero for two consecutive cycles: financial
   pain triggers the ostrich effect; this user gets the crunch card's
   calm tone, never a warning stack.
