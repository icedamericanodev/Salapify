# Roadmap Recommendations

Sprint 0 engineering audit, 2026-07-10. The prioritized roadmap synthesized
from all audit documents. Grouped as requested: Quick Wins, Foundation, UX,
Security, Performance, Architecture, AI, and Future Features. Every item
carries expected impact, estimated effort (S under 1 day, M 1 to 3 days, L 1
to 2 weeks, XL more than 2 weeks), priority (P0 do first, P1 soon, P2
planned, P3 someday), and dependencies.

A cross cutting constraint shapes the ordering: items marked REBUILD require
an EAS APK build and a runtime version bump, so they should be batched
together rather than done one at a time. Everything else ships over the air.

## Quick Wins (all P0, all S, do these first)

1. Run the mobile test suite in CI and gate OTA publishes on it.
   Impact: the 313 existing tests start protecting real users; the single
   highest leverage change in this audit. Effort: S. Priority: P0.
   Dependencies: none. (TD-1)
2. Hard size guard in saveData with a blocking export modal near the 2MB
   wall. Impact: converts a permanent lockout cliff into a recoverable
   warning. Effort: S. Priority: P0. Dependencies: none. (TD-2, DB-1)
3. Fix the Play data safety form and the nothing is uploaded listing line.
   Impact: removes a store takedown risk before the next submission.
   Effort: S. Priority: P0. Dependencies: none. (SEC-2)
4. Pin eas-cli and action SHAs; scope and rotate EXPO_TOKEN; protect the
   publishing branch. Impact: closes the cheapest supply chain holes.
   Effort: S. Priority: P0. Dependencies: none. (SEC-1 partial)
5. Gate the FX fetch behind actual currency feature use. Impact: makes the
   privacy policy literally true. Effort: S. Priority: P0. Dependencies:
   none. (SEC-5)
6. Move setCurrencySymbol from render into an effect. Impact: removes the
   one true concurrency landmine. Effort: S. Priority: P0. Dependencies:
   none. (TD-11)
7. TalkBack batch one on the logging flow: modal focus containment, chip
   selected states, error and toast live regions. Impact: the core loop
   becomes usable for blind users; three Critical findings closed in one
   pass. Effort: S each, about 2 to 3 days total. Priority: P0.
   Dependencies: none. (A11Y-1, A11Y-2, A11Y-3)
8. Sample data banner while sample IDs remain, with one tap clear.
   Impact: protects the first real net worth number, the key trust moment.
   Effort: S. Priority: P0. Dependencies: none. (UX-8)
9. Retire or harden the legacy PWA at the Pages root (retiring is S: stop
   deploying index.html and sw.js, keep the privacy policy and /app).
   Impact: removes XSS and CDN risk from the trust origin. Effort: S.
   Priority: P0. Dependencies: a decision on v1 users' import path
   messaging. (SEC-3, TD-10)

## Foundation (the platform beneath everything else)

1. ESLint (eslint-config-expo) wired into the new CI job.
   Impact: catches whole bug classes pre merge. Effort: S. Priority: P1.
   Dependencies: Quick Win 1. (TD-9)
2. mobile/README.md: architecture sketch, run instructions, OTA versus
   rebuild rules, data invariants. Impact: onboarding and diligence.
   Effort: S. Priority: P1. Dependencies: none; this docs/ set feeds it.
   (TD-12)
3. Tests for the untested money code: lib/loan.js, lib/soa.js,
   lib/thirteenth.js, split rounding, the notes math parser, lib/search.js,
   receipt-parse.js. Impact: every calculator the app stakes its trust on
   gets regression protection. Effort: M spread across batches.
   Priority: P1. Dependencies: Quick Win 1 makes them count. (TD-13)
4. Extract the recurring posting engine from AppData.js into a pure, tested
   lib/recurring.js. Impact: the last untested money engine gets coverage;
   AppData shrinks. Effort: M. Priority: P1. Dependencies: none. (TD-11)
5. Widget math parity: import lib/analytics.js in the widget handler plus a
   parity test. Impact: the home screen can never disagree with the app.
   Effort: S. Priority: P1. Dependencies: none. (TD-6, CMP-6)
6. Free tier durability decision: make daily auto backup free (folder
   rotation stays Pro), or revisit allowBackup. Impact: lost phones stop
   meaning lost histories for the whole free tier. Effort: M (policy plus
   gating; allowBackup change is REBUILD). Priority: P1. Dependencies:
   founder decision; batch any allowBackup change with the rebuild batch.
   (TD-3)
7. Per year versioning for statutory rates in phtax.js plus a stale year
   warning in the tax tools. Impact: the tax suite stops being a silent
   annual time bomb. Effort: M. Priority: P1. Dependencies: none. (TD-13)
8. Component test seed: LogSheet validation and submit, restore confirm
   flow. Impact: first UI regression net around the two highest stakes
   surfaces. Effort: M. Priority: P2. Dependencies: Quick Win 1. (CMP-8)

## UX (review Phase 4 follow through; no redesign until approved)

1. LogSheet speed pass: amount first with autofocus, secondary fields behind
   More options, pinned action bar. Impact: the daily habit gets under 5
   seconds; the highest UX leverage in the app. Effort: M. Priority: P1.
   Dependencies: do the TalkBack batch first or together (same file).
   (UX-1)
2. Home hierarchy: Safe to spend always first, collapse conditional cards,
   hide zero utang cards, cut duplicate quick links. Impact: the daily
   answer is above the fold every open. Effort: M. Priority: P1.
   Dependencies: none. (UX-2, UX-9)
3. Unified Debts and Utang tab (three segments: loans and cards, owed to me,
   I owe) with Split promoted. Impact: the differentiator becomes
   discoverable; navigation matches the mental model. Effort: L.
   Priority: P2. Dependencies: founder alignment on tab strategy (UX-13).
   (UX-3)
4. Debt detail screen with Log payment as the primary action, edit behind
   it. Impact: the monthly retention loop for the debt persona stops living
   inside a mega form. Effort: M. Priority: P2. Dependencies: none. (UX-4)
5. Date picking chips (last 14 days) in LogSheet and goal date validation.
   Impact: backdating becomes practical, goals stop accepting garbage
   dates. Effort: M. Priority: P2. Dependencies: none. (UX-5)
6. Debts tab tone pass: warning color only for true warning states; adopt
   shared Card and SectionHeader. Impact: the core persona stops being
   shamed by default. Effort: S. Priority: P2. Dependencies: none. (UX-6)
7. Shared Chip component with 44 point targets and accessibility state,
   migrated screen by screen. Impact: fixes UX-7, A11Y-2 residue, and style
   drift in one primitive. Effort: M. Priority: P1. Dependencies: pairs
   with the TalkBack batch. (CMP-1)
8. Merge the salary modal into LogSheet income mode. Impact: one income
   flow, consistent reward moment. Effort: S. Priority: P2. Dependencies:
   LogSheet speed pass lands first. (UX-10)
9. Remaining accessibility passes: faint contrast retune plus a contrast
   regression test (M), dynamic type fixes on the tab bar and toasts (S),
   pressable role sweep (S to M), WeekChain and weekday chart summaries (S),
   legacy Animated reduce motion (S). Priority: P1 for contrast and dynamic
   type, P2 for the rest. Dependencies: none. (A11Y-4 to A11Y-9)

## Security

1. EAS Update code signing before the production channel goes live.
   Impact: a stolen Expo token alone can no longer ship code. Effort: M.
   Priority: P1. Dependencies: Quick Win 4 first. (SEC-1)
2. App lock hardening: sticky setting with a re enroll prompt instead of
   silent auto disable; document the lock honestly. Effort: M. Priority:
   P2. Dependencies: none. (SEC-6)
3. At rest encryption for the data blob and receipts, keyed via Keystore.
   Impact: the lock becomes a real boundary; rooted and seized device
   scenarios covered. Effort: L. REBUILD. Priority: P2. Dependencies: do
   inside the SQLite migration so there is one migration path. (SEC-4)
4. Optional passphrase encrypted backup format. Effort: M. Priority: P3.
   Dependencies: none. (SEC-7)
5. Verify ML Kit makes no network calls on a real build. Effort: S.
   Priority: P2. Dependencies: a physical build to capture. (SEC-9)

## Performance

1. Memoize the AppData provider value and the heavy screen derivations
   (budget, insights, home). Impact: logging stays smooth as history grows;
   buys years of headroom before the structural fix. Effort: M.
   Priority: P1. Dependencies: none. (PERF-1)
2. FX fetch timeout via AbortController. Effort: S. Priority: P2.
   Dependencies: none. (API-2)
3. State and actions context split. Effort: M. Priority: P3. Dependencies:
   after memoization proves insufficient, not before. (PERF-1)

## Architecture

1. The rebuild batch (do together, one APK, one runtime bump): fingerprint
   runtimeVersion policy, any allowBackup change, Sentry crash reporting,
   expo-secure-store. Impact: closes TD-8, TD-3, DEP-1, DEP-2 in one
   release. Effort: M combined. Priority: P1. Dependencies: founder
   decisions on backup policy and the Sentry privacy disclosure.
2. SQLite migration design doc, then implementation: transactions table plus
   KV for settings, sanitize discipline kept at the boundary, widgets
   reading through the same seam, at rest encryption included. Impact:
   removes the 2MB ceiling, the write amplification, and the plaintext at
   rest finding in one program. Effort: XL (design M, implementation the
   rest). REBUILD. Priority: P2, start the design doc within a quarter.
   Dependencies: rebuild batch shipped first; data-migration-reviewer gate
   on every diff.
3. Repo restructure: legacy PWA into legacy/, Pages repointed, root CI
   repointed at mobile/, founder scripts into scripts/. Effort: M.
   Priority: P2. Dependencies: Quick Win 9 decision. (TD-10, FS-1)
4. receivables and payables shared component extraction. Effort: M.
   Priority: P2. Dependencies: none. (TD-7)
5. Delete dead code (MascotSkia, Placeholder). Effort: S. Priority: P2.
   Dependencies: none. (CMP-5)

## AI (sequence from AI_Readiness.md; nothing here ships before Foundation)

1. Write the AI guardrail rules into CLAUDE.md now: no provider keys in the
   app, no chat history in the main blob, models phrase and resolvers
   compute. Effort: S. Priority: P1. Dependencies: none. (AI-1, AI-3)
2. PanBrain abstraction: RulesBrain (today's engine) behind an interface
   with a streaming capable contract. Effort: M. Priority: P2.
   Dependencies: none; pure refactor of lib/pan.
3. Proxy backend (one serverless function: key custody, quotas, logging).
   Effort: L. Priority: P2. Dependencies: a hosting and privacy decision;
   blocks any real LLM feature.
4. LlmBrain with provider tool use generated from the intent registry;
   ledger never leaves the device, only resolver facts. Effort: L.
   Priority: P3. Dependencies: proxy backend, Sentry, prompt registry.
5. Conversation memory in its own capped store; observability on LLM calls
   through the proxy. Effort: M. Priority: P3. Dependencies: LlmBrain.
6. RAG over Learn content only if the library grows past about 50 lessons.
   Effort: M then. Priority: P3. Dependencies: content investment first.

## Future Features (flagged during audit, not committed)

1. Monetization infrastructure (react-native-purchases, Play Console
   products, entitlement checks). Impact: Pro becomes revenue instead of a
   free flag. Effort: XL. REBUILD. Priority: P2 when the business says so.
   Dependencies: rebuild batch pattern established; legal-compliance review.
2. Notification refill strategy (background task or refill on any app open)
   so one shot reminder windows stop running dry for lapsed users.
   Effort: M. Priority: P2. Dependencies: none. (R23)
3. Tax deadline weekend and holiday shifting using the existing
   lib/holidays.js. Effort: S. Priority: P2. Dependencies: none. (R31)
4. Optional encrypted cloud sync or multi device support. Effort: XL.
   Priority: P3. Dependencies: a backend, an auth story, and a major
   privacy posture decision; do not start before SQLite and monetization.
5. Local only usage counters surfaced through user initiated feedback, to
   inform the tab strategy decision (UX-13) without breaking the no
   tracking stance. Effort: S to M. Priority: P2. Dependencies: none.

## Suggested sequencing at a glance

- Week 1: all nine Quick Wins.
- Weeks 2 to 4: Foundation 1 to 5, UX 1 and 2 and 7, Performance 1,
  Security 1, AI 1.
- The first rebuild batch after that: Architecture 1 (fingerprint runtime,
  backup policy, Sentry, secure store).
- Quarter horizon: the SQLite design doc, the Debts and Utang tab decision,
  UX 3 to 6, the repo restructure, remaining accessibility passes.
- Beyond: SQLite implementation with encryption, monetization, then the AI
  track.
