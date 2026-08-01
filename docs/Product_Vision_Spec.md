# Salapify Product Vision Spec

Written 2026-08-01, in answer to the founder's full product brief (the
"money coach in your pocket" brief: cloud backend, AI coach, social
challenges, shared wallets, PH-first growth). One document, six parts,
usable as the foundation for roadmap decisions, later build sessions,
design work, and Play Store listing preparation.

## Part 0. How to read this document

### The founder's decision that frames everything here

The brief assumed a Supabase (PostgreSQL) cloud backend with user accounts,
plus Firebase for analytics, crash reporting, push, and deep links. The live
app was built the opposite way, on purpose: there is no backend, no account,
and data never leaves the phone. That promise is shipped as a feature (the
Privacy receipt, flutter/lib/screens/privacy_receipt.dart) and it is the
app's main trust differentiator.

The founder decided on 2026-08-01: this spec is a vision document only. The
live app and its privacy promise stay untouched. Ideas that need the cloud
are designed here so the option is real and priced, but nothing cloud ships
without a separate founder decision made with the tradeoffs in Part 2 read
first.

### The four labels

Every idea in this document carries exactly one label:

- **[LIVE]**: already shipped in the offline app. The label always names the
  screen or module, so the claim can be checked against the code.
- **[OFFLINE-NOW]**: buildable now, ships over the air as a Shorebird patch,
  breaks no shipped promise. This is the default home for new work.
- **[OFFLINE-PLUS]**: stays fully on-device, but needs a new native package,
  which means a new base APK and a manual install for every tester. Flagged
  loudly, per the working rules.
- **[CLOUD]**: requires the Supabase/Firebase pivot: accounts, sync, a
  rewritten Privacy receipt and privacy policy, Philippine Data Privacy Act
  obligations, and a new base APK. Cannot ship without a separate founder
  decision.

### Which document wins on conflict

This spec joins an existing strategy suite and does not replace it:

- Priorities and sequencing: docs/Product_Backlog.md (the 10 epics) wins.
- Pricing and the standing promises: docs/Monetization.md wins. The promises
  are fixed: core features free forever, data portability never paywalled,
  early users keep Pro free. Lifetime Pro at PHP 249 (launch PHP 199) per
  Epic 10.
- Target-state AI architecture: docs/AI_Strategy.md and docs/AI_Readiness.md
  are the deeper documents; Part 3 here builds on them.
- Competitive framing: docs/Product_Strategy.md.
- Measuring without a server: docs/Analytics.md.
- The cloud-versus-offline triage of the founder's brief: THIS document wins.
  That triage is what this spec adds that no other document holds.

### What already exists (the ground truth inventory)

The spec's [LIVE] claims trace to these, verified against the code on
2026-08-01:

- **Tracking**: log sheet, quick adds, edit sheet, history with undo delete,
  global search, unified accounts with transfers, CSV import with column
  mapping, notes with an inline calculator.
- **Budget**: monthly limit with carry-over (money/budget.dart), Spoken-For
  Sweldo commitment load (money/commitmentload.dart), surplus router "where
  your next peso should go" (money/surplus.dart).
- **Debts and utang**: full debt engine with Snowball versus Avalanche
  (money/debts.dart, money/debtmath.dart), receivables with per-person aging
  (money/receivables.dart, money/utang.dart), per-person Statement of
  Account and reminder drafts (money/statement.dart), loan and BNPL true
  cost calculators, split-a-bill into collectible utang (money/splits.dart),
  paluwagan group records (money/paluwagan.dart).
- **Forecasting**: month-bounded cash flow calendar
  (money/cashflow_calendar.dart), safe to spend and upcoming dues
  (money/commitments.dart), Your Number per payday cycle (money/cycle.dart),
  payday math with 15/31 default (money/schedule.dart), month-end forecast
  and goal pace (money/analytics.dart), debt-free projection and card
  forecast (money/debtmath.dart), the afford stress test (money/afford.dart),
  windfall and surplus planners, steady pay weekly self-salary
  (money/steadypay.dart).
- **Habit layer**: the 7-day logging chain that never resets
  (money/chain.dart), earn-your-treats temptation bundling
  (money/treats.dart), milestones with branded share cards
  (money/milestones.dart, screens/milestone_share.dart), confetti
  celebrations, ranked coach nudges (money/coach.dart), Pan mascot moods, 22
  lessons that each end in one real in-app action (content/lessons.dart),
  the monthly recap share card (screens/recap_share.dart).
- **Pan, the assistant**: rule based and fully offline, no model, no
  network. Pipeline: normalize, detect intent, resolve against the real
  money engine, phrase. Understands Tagalog and Taglish input through a
  synonym table (utang, sweldo, gastos, ipon, magkano, kelan). Has 18
  intents, 5 guardrail refusals (investing, lending, tax advice, legal,
  insurance), typed CTAs into app screens, and a copyable utang reminder
  draft. No memory across conversations. Files: screens/pan.dart,
  money/pan/.
- **PH tools**: gross-to-net salary (money/phtax.dart), 8 percent versus
  graduated for self-employed, SSS/PhilHealth/Pag-IBIG contributions, 13th
  month with the 90,000 ceiling, year-end refund-or-owe, BIR deadlines, PH
  banking calendar (money/phcalendar.dart).
- **Reminders**: a pure planner (money/reminders.dart) behind per-kind
  toggles: nightly log nudge, payday, bills due, money to collect, monthly
  backup, and the comeback ladder (day 2, 4, 7, 14 after the last open,
  shipped f3.14).
- **Privacy and trust**: the Privacy receipt lists every connection the app
  can make, exactly two: a currency-rate fetch carrying only a currency
  code, and the Shorebird update check. Shipped copy: no account, no cloud,
  no analytics, no trackers, no ads. Standing rule in that file: any new
  network dependency is added to the receipt or it does not ship. Backups
  excluded from Google auto-backup, FLAG_SECURE under App lock, generic
  lock-screen reminders, a durable encrypted store (ADR 0001), New Phone Day
  handoff, local Diagnostics.
- **Monetization state**: settings pro is a free self-served toggle. Three
  gates exist (recurring cap of 5, category monthly caps, a PRO label on the
  Reports debt-free plan). No billing code of any kind yet.

What does NOT exist, and matters for this brief: voice input, photo or
receipt capture, any LLM, any rolling multi-week balance timeline past the
current month, multi-scenario what-if modeling, XP, levels, badges,
leaderboards, friend challenges, any multi-user feature, any server.

## Part 1. Enhanced product spec: the ten areas

Each area: what is live, the honest gap, then enhancements. Every
enhancement is labeled and mapped to a backlog epic.

### Area 1. No-Bank-Link First Mode

**Live**: the entire app is no-bank-link; that is its identity, not a mode.
Manual logging is fast (log sheet, one-tap quick adds), and CSV import
(screens/csv_import.dart) covers bank and GCash exports without any linking.

**Gap versus the brief**: no quick text grammar ("lunch 180 GCash"), no
voice input, no receipt or screenshot photo extraction.

**Enhancements**:
1. **Fast-log line parser** [OFFLINE-NOW, Epic 5 Transaction Experience].
   One text field that accepts "lunch 180 gcash" or "grab 250 kahapon" and
   pre-fills the log sheet: amount, label, account guess, date words (today,
   kahapon). Reuses Pan's normalize layer and synonym table
   (money/pan/normalize.dart) so Taglish works on day one. Pure Dart, high
   leverage, small.
2. **Receipt photo capture with on-device OCR** [OFFLINE-PLUS, Epic 5].
   Google ML Kit text recognition runs on the device; no image ever leaves
   the phone, so the Privacy receipt stays true with one new line about the
   camera permission. Heuristics pull the total, date, and merchant line.
   Needs a new native package, so a new base APK: batch it with other
   native-level work.
3. **Voice logging** [OFFLINE-PLUS, Epic 5]. On-device speech recognition
   feeding the same fast-log parser, so voice is just a faster keyboard.
   Same base-APK batching note.
4. **LLM-grade extraction** of arbitrary screenshots and statements
   [CLOUD, Epic 7 AI Platform]. Only worth it after the pivot decision;
   the offline OCR path above captures most of the value first.

### Area 2. Forward-Looking Cash Flow Engine

**Live**: the strongest foundation in the app. Day-by-day running balance to
the end of the current month (money/cashflow_calendar.dart, deliberately
conservative: recurring plus minimums only), safe to spend until payday,
Your Number per cycle, month-end forecast from pace, debt-free projection
with an extra-payment what-if, the afford stress test for one purchase.

**Gap versus the brief**: the calendar stops at month end; there is no
7/14/30-day rolling view that crosses the boundary, no low-point flag tied
to the payday cycle, no side-by-side scenario modeling, no estimate of
variable spending, and no proactive alert from the projection.

**Enhancements** (this cluster is Breakthrough 1, deep dive in Part 5):
1. **Rolling timeline** [OFFLINE-NOW, Epic 6 Financial Intelligence]:
   extend the calendar to a rolling 30/60/90 days across month boundaries,
   built from the payday schedule, recurring items, debt minimums, and goal
   contributions. Flag projected low points before each payday.
2. **Scenario sandbox** [OFFLINE-NOW, Epic 6]: up to three saved what-ifs
   overlaid on the timeline: an income change, a category cut, an extra
   debt payment, a planned big purchase. Deterministic math, no AI.
3. **Variable-spend band** [OFFLINE-NOW, Epic 6]: a conservative estimate of
   ordinary spending from trailing category totals (money/analytics.dart),
   drawn as a band, clearly labeled an estimate, never mixed into the
   conservative line.
4. **Projection alerts** [OFFLINE-NOW, Epic 6]: one new reminder kind in the
   pure planner (money/reminders.dart): "a tight stretch is coming before
   payday", following the same prove-it-fires-and-stays-silent discipline as
   the comeback ladder.

### Area 3. AI Money Coach

**Live**: Pan. Rule based, offline, Taglish-understanding, 18 intents wired
to the real money engine, guardrails that refuse investment, lending, tax,
legal, and insurance advice, CTAs into the right screen, and a copyable
utang reminder draft. Every number Pan says is computed by the money layer,
never generated.

**Gap versus the brief**: no memory across conversations, no open-ended
Q and A, no coach modes, no LLM.

**Enhancements**:
1. **Pan memory** [OFFLINE-NOW, Epic 8 AI Companion] (Breakthrough 3
   candidate, Part 5): persist the conversation and one "active plan" object
   in the data blob (for example a debt payoff plan with a target date). Pan
   opens the next conversation aware of the plan and reports progress
   against it. Still rule based, still zero network.
2. **Timeline-aware answers** [OFFLINE-NOW, Epic 8]: once Area 2 ships, "can
   I afford a 3,000 concert this month" resolves against the projected
   timeline, not just current balances. New intents stay in the existing
   resolver pattern.
3. **Coach tones** [OFFLINE-NOW, Epic 8]: supportive and direct as phrasing
   packs in money/pan/respond.dart, which is already the phrasing-only
   layer. The brief's "roast" mode is deliberately excluded: shame is the
   failure mode the whole habit layer is designed against (see Area 5).
4. **LLM tier** [CLOUD, Epic 7]: conversational Q and A through a thin
   server layer, designed in Part 3. Data minimization is the rule: derived
   aggregates go to the model, the raw ledger does not.

### Area 4. Filipino-First Localization

**Live**: this is the app's home ground. PHP default with multi-currency and
a base-currency rule that never mixes currencies in a total
(money/base_currency_scope.dart), payday cycles including kinsenas and
katapusan (money/schedule.dart), 13th month with the tax ceiling, utang as a
first-class ledger with per-person statements, paluwagan, the PH banking
calendar shifting due dates off weekends and holidays, the full PH tax and
contribution calculator set, and Pan understanding Tagalog input. UI copy is
English first by founder decision (2026-07-23); Filipino identity nouns stay
as titles and flavor.

**Gap versus the brief**: the brief asks for a Taglish UX option, which the
founder already decided against for the global launch; understanding stays,
replies stay English. Remaining real gaps: starter category packs and
OFW-specific flows.

**Enhancements**:
1. **PH starter category pack** [OFFLINE-NOW, Epic 5]: prebuilt optional
   categories on first run: load and data, transport, groceries, family
   allowance or padala, sari-sari, church and giving, remittance fees. One
   tap to adopt, fully editable, never forced.
2. **OFW remittance flow** [OFFLINE-NOW, Epic 6]: a transfer between a
   foreign-currency account and a PHP account that records the fee and the
   effective rate, so the padala's true cost is visible over time.
3. **Bill calendar presets** [OFFLINE-NOW, Epic 5]: common PH billers as
   recurring-item templates (Meralco, water, internet, HOA) with typical due
   windows, feeding the existing bills-before-payday view.

### Area 5. Habit and Gamification Layer

**Live**: a deliberate philosophy, not an absence. The 7-day logging chain
never resets (money/chain.dart says it plainly: a gap in the dots, never a
zeroed counter). Treats bundle temptation instead of forbidding it.
Milestones celebrate real money wins with shareable cards. Coach nudges
rank what matters now. Lessons end in one real action. There is no XP, no
levels, no badges, no leaderboards, and that was a choice.

**Behavioral review** (behavior-scientist, this spec). The keep-out list is
binding on every gamification idea in this document:

**Keep out, as explicit non-goals**:
- **Leaderboards and any social comparison of money.** Income variance in
  the PH audience is enormous, so a money leaderboard is either a salary
  comparison in a costume or a logging-volume contest that invites junk
  entries. Upward comparison produces shame, shame produces avoidance, and
  avoidance is the number one killer of finance apps. The no-backend design
  makes this impossible anyway; the spec states plainly that this is a
  behavioral feature, not a limitation.
- **XP and levels.** XP is a proxy metric and users optimize the proxy. The
  only awardable actions are logging events, so XP converges to "who taps
  most", decoupled from financial reality. Points also crowd out the
  identity reward the app already builds ("I am someone who tracks my
  money", the chain's actual message), and a level 47 of a budgeting app
  means nothing to anyone.
- **Streaks that reset.** Already correctly excluded; money/chain.dart's
  header is the position. A zeroed counter after one missed day teaches
  quitting.
- **Badges for amounts.** "Saved 100k" celebrates the amount, not the
  behavior, and ranks users by income.

**Adopt, where the current position leaves retention value on the table**:
1. **Behavior-earned records, not badges** [OFFLINE-NOW, Epic 6]. The
   milestone engine celebrates outcome moments that can take months; the
   first-two-weeks gap is where churn happens. Add a small set of
   achievement facts reachable early: first 7-for-7 week, first full payday
   cycle logged, first month with a positive savings rate, first "logged a
   rough day anyway". All derivable from the ledger, never resettable,
   phrased as facts about the user ("You have logged every day of a payday
   cycle"), never as tokens ("Bronze Logger unlocked").
2. **Lifetime counters that only grow** [OFFLINE-NOW, Epic 6]. Treats
   already keeps a lifetime count. Extend the pattern: total days ever
   logged, total debt pesos ever paid off, longest chain ever. Nothing to
   lose, everything is a personal record, and it gives the long-tenured
   user proof of distance traveled that a 7-day window cannot.
3. **Share cards for behavior milestones** [OFFLINE-NOW, Epic 9]. The share
   moment is the correct, ethical substitute for a leaderboard: the user
   chooses the comparison, the audience, and the moment. Extend the
   existing card pipeline to the records above.

### Area 6. Shared Finance Mode

**Live**: single-user tools that cover a surprising share of the need
without any server: split a fronted bill into per-person collectible utang
(money/splits.dart), per-person statements of account, paluwagan group
records, and the recap card a partner can be shown.

**Gap versus the brief**: true shared wallets, two people writing to one
ledger from two phones, is irreducibly [CLOUD]. No middle path makes
multi-device sync honest without a server or a peer channel.

**Enhancements**:
1. **Household space on one phone** [OFFLINE-NOW, Epic 6]: a "shared" tag
   surface: mark expenses as household, get a who-paid-what view and a
   monthly Money Date summary card (reuses the recap card pipeline). Covers
   couples who manage money on one phone, which is common.
2. **Statement handoff** [OFFLINE-NOW, Epic 6]: export a read-only monthly
   household summary (PDF exists in the dependency set already) to send to
   a partner or parent. Data leaves by the user's own share action only.
3. **Shared wallets with sync** [CLOUD, Epic 9 Growth adjacency]: designed
   in Part 2's schema (shared_wallets, members, permissions) so the option
   is real. Ships only after the pivot decision.

### Area 7. Freelancer and Side-Hustle Mode

**Live**: the 8 percent versus graduated tax calculator is the exact
freelancer decision tool, steady pay turns swing income into a weekly
self-salary (money/steadypay.dart), tax deadlines cover filing dates.

**Gap versus the brief**: no business-versus-personal separation, no
per-client or per-project income view, no simple P and L.

**Enhancements**:
1. **Work tags and P and L** [OFFLINE-NOW, Epic 6]: tag income and expenses
   as work, optionally with a client or project label; a simple monthly and
   quarterly P and L view derives from tags. No second ledger, no mode
   switch, so the money stays one truth.
2. **Set-aside autopilot** [OFFLINE-NOW, Epic 6]: when work income is
   logged, suggest the set-aside split (tax percent from the calculator's
   result, plus an emergency cut), one tap to move it to a goal. With clear
   disclaimers, consistent with Pan's no-tax-advice guardrail: the numbers
   come from the user's chosen rate, not from advice.
3. **Profit per project** [OFFLINE-NOW, Epic 6]: the same tags, grouped.

### Area 8. Emotion-Aware and Behavior-Focused Nudges

**Live**: the Mindset screen carries an impulse check and a running list of
small wins (screens/mindset.dart). The coach's tone across the app is
already deliberately non-judgmental; the comeback ladder shipped with
no-guilt copy as a design requirement.

**Behavioral review** (behavior-scientist, this spec):

**Avoid, named as pseudoscience**:
- Mood inference from spending data ("you seem stressed because you spent
  on X") is unfalsifiable cold reading; wrong once, trust gone.
- AI tone adjustment to a self-reported mood reads as manipulation the
  moment the user notices. The coach already has an honest tone ladder
  (urgent, watch, nudge, good in money/coach.dart) driven by money facts,
  the only tone signal that cannot be wrong.
- Daily stress check-ins as a standalone feature: a second habit with no
  payoff loop, survey fatigue in a week, and offline the data goes nowhere.

**Worth building, all [OFFLINE-NOW]**:
1. **State-aware softening** [Epic 6]: when the coach's crunch state is
   live, the app talks only about survival to payday: challenge prompts,
   goal nudges, and other optional asks soften or go silent, the way the
   goal nudge already says bills come first. Systematize that as a rule.
2. **Warm confirmation on heavy days** [Epic 5]: when a user logs a big
   spending day, the confirmation gets warmer, not colder ("Logged. Honest
   numbers are the whole game."). Keys on behavior, not inferred mood, and
   directly fights the avoidance spiral where people stop logging the weeks
   that matter most.
3. **Park it, the 24-hour parking lot** [Epic 6], the one
   pause-before-purchase mechanic worth shipping. The Mindset screen's
   impulse questions already ask "can I wait 24 hours"; Park it makes that
   an action at the moment of temptation. The user types the item and
   amount; the app answers with one engine-computed fact ("that is 18
   percent of what is left to payday"), then schedules exactly one
   notification 24 hours later: still want it, enjoy it, you thought it
   through; changed your mind, that amount is still yours, two taps moves
   it to a goal. Both outcomes are wins, buying after the pause is never
   judged, and a lifetime "parked and kept" total grows treats-style.
   Cooling-off periods reliably kill a large share of impulse intents, and
   this needs zero AI and zero network.

### Area 9. Social and Viral Features

**Live**: the monthly recap card (screens/recap_share.dart) is the brief's
"Money Stories" in working form: a branded, shareable summary with a
hide-amounts privacy toggle. Milestone cards celebrate debt-free, goal-hit,
and settled-utang moments. Both render on device and go out only through
the user's own share sheet.

**Gap versus the brief**: no challenges, no referral mechanics, no cohorts.

**Enhancements**:
1. **Local challenges with shareable cards** [OFFLINE-NOW, Epic 9]
   (Breakthrough 2, deep dive in Part 5): pick a challenge (no food
   delivery for 14 days, 500-a-week groceries, build a 10k emergency fund),
   the app tracks it from the ledger itself where possible, and the finish
   moment mints a branded card. No accounts, no leaderboards; the share IS
   the viral loop.
2. **Richer Money Stories** [OFFLINE-NOW, Epic 9]: seasonal recap variants
   (13th month special, year-end story) using the same card pipeline.
3. **Referral link kit** [OFFLINE-NOW in-app, Epic 9]: a share action with
   a UTM-tagged Play link on every card. Measurement is Play install
   referrer and Play Console, honest limits in Part 6. Server-side referral
   rewards are [CLOUD] and deferred.

### Area 10. Privacy and Trust as a Core Feature

**Live**: the Privacy receipt is the brief's "privacy dashboard", shipped:
every connection listed (exactly two), permissions explained, on-device
protections shown, a live fetch log, and the airplane-mode challenge.
Export and delete exist (backup, Start fresh). The standing rule in the
receipt's header binds every future feature: a new network dependency is
added to the receipt or it does not ship.

**Enhancements**:
1. **Receipt-first development** [OFFLINE-NOW, standing rule]: every
   [OFFLINE-PLUS] feature in this spec (OCR, voice) ships with its receipt
   row in the same change. This is process, priced at zero.
2. **Granular AI opt-in staging** [CLOUD-preparatory, Epic 7]: if the LLM
   tier ever ships, it is per-feature opt-in with a plain-English data
   card shown before the first use of each AI feature: what leaves the
   phone, what never does. Designed in Part 3, priced in Part 2.
3. **Trust marketing** [OFFLINE-NOW, Epic 9]: the no-bank-link and
   two-connections story leads the listing (Part 6). The receipt screen
   itself becomes a screenshot in the store listing.

### Three entirely new ideas (not in the brief, not common in finance apps)

1. **Utang Diplomat** [OFFLINE-NOW, Epic 6]. Collecting money from friends
   and family is the most awkward money act in PH life, and the app already
   holds the ledger, the per-person statement, and a reminder draft. The
   Diplomat turns that into a campaign: pick a person, get a sequence of
   escalating-warmth messages (gentle, then firmer, then a payment-plan
   offer), each one copyable into any chat app, optionally timed to known
   paydays. Nothing sends automatically; the user always presses send in
   their own messenger. Unique, deeply local, zero server.
2. **Bill Shock Forecaster** [OFFLINE-NOW, Epic 6]. The expenses that break
   budgets are the irregular ones: enrollment, Christmas, fiesta,
   birthdays, annual insurance. Detect yearly patterns from history and the
   PH calendar, then propose a sinking fund with a monthly amount, wired
   into the goals engine. The cash flow timeline (Area 2) draws these as
   future events, so December stops being a surprise.
3. **Money Time Capsule** [OFFLINE-NOW, Epic 8]. At a milestone or windfall,
   the app invites one sentence to future you ("why I started this fund").
   The note resurfaces at the linked moment: the next 13th month, the goal's
   finish, the debt's payoff. A commitment device with an emotional payoff,
   nearly free to build, and the resurfaced note plus its milestone card is
   a natural share moment.

## Part 2. Supabase + Firebase architecture (conditional on a pivot decision)

Everything in this part is design-ahead work. None of it ships, none of it
is set up, and the live app keeps its promise, unless and until the founder
separately decides to pivot after reading the cost list at the end of this
part.

### 2.1 What the brief gets right

Financial data is relational, and if Salapify ever runs a backend,
PostgreSQL through Supabase is the right shape for it: real constraints and
ACID transactions for money math, SQL for reporting, Row Level Security for
per-user and shared-wallet access, and migrations for schema evolution.
Firebase staying limited to analytics, crash reporting, push, and deep
links is also right: it keeps financial truth in one store.

### 2.2 High-level schema

Conventions: every table has id uuid primary key default gen_random_uuid(),
created_at, updated_at; client-generated uuids so offline writes are stable;
soft deletes via deleted_at where user data is involved.

Core identity and money:

- profiles: user_id (references auth.users), display_name, base_currency,
  payday_schedule jsonb, settings jsonb.
- wallets: owner_id, name, kind (cash, bank, ewallet, savings, credit),
  currency_code, target numeric, archived_at. A wallet is what the offline
  app calls an account.
- transactions: wallet_id, owner_id, type (expense, income, transfer),
  amount numeric(14,2), currency_code, label, category_id, occurred_on
  date, note, meta jsonb, client_id uuid unique (idempotent sync).
- categories: owner_id, name, parent_id, monthly_cap numeric, emoji text.
- budgets: owner_id, month date, limit_amount, carry_over boolean.
- goals: owner_id, name, target, saved, linked_wallet_id, due_on.
- debts: owner_id, name, principal, remaining, apr, min_payment,
  statement_day, grace_days.
- debt_payments: debt_id, amount, paid_on, from_wallet_id.
- persons: owner_id, name. Third-party names get their own table so
  privacy tooling (export, erasure) can address them directly.
- receivables: owner_id, person_id, amount, due_on, paid boolean.
- receivable_payments: receivable_id, amount, paid_on.
- recurring_items: owner_id, kind (bill, income), label, amount, day_rule
  jsonb, wallet_id, active boolean.

Sharing:

- shared_wallets: id, name, created_by.
- shared_wallet_members: shared_wallet_id, user_id, role (owner, editor,
  viewer), joined_at. Membership row is the access key RLS checks.
- shared_transactions: shared_wallet_id, author_id, amount, label,
  category, occurred_on, split_rule jsonb.
- transaction_comments: shared_transaction_id, author_id, body.

Engagement and AI:

- challenges: id, slug, title, rules jsonb, duration_days, is_public.
- user_challenges: user_id, challenge_id, started_on, state (active,
  finished, abandoned), progress jsonb.
- ai_conversations: user_id, mode, started_at.
- ai_messages: conversation_id, role, content, tokens int, created_at.
- insight_snapshots: user_id, kind (money_story, forecast), period,
  payload jsonb, generated_at. Cached AI and forecast outputs live here so
  they are computed once and reread cheaply.
- forecast_snapshots: user_id, as_of date, horizon_days, series jsonb.

Sync support:

- oplog: user_id, device_id, seq bigint, entity, entity_id, op (upsert,
  delete), payload jsonb, applied_at. The offline queue drains into this;
  see 2.4.

Rollups via Postgres, not the client: materialized views or trigger-kept
tables for monthly category totals, net worth series, and challenge
progress, refreshed on write through triggers or pg_cron. XP-style counters
are deliberately absent; see Area 5's keep-out list.

### 2.3 RLS examples

Enable RLS on every table. Owner-only tables share one pattern:

    create policy "own rows" on transactions
      for all using (owner_id = auth.uid())
      with check (owner_id = auth.uid());

Shared wallets check membership:

    create policy "member read" on shared_transactions
      for select using (exists (
        select 1 from shared_wallet_members m
        where m.shared_wallet_id = shared_transactions.shared_wallet_id
          and m.user_id = auth.uid()));

    create policy "editor write" on shared_transactions
      for insert with check (exists (
        select 1 from shared_wallet_members m
        where m.shared_wallet_id = shared_transactions.shared_wallet_id
          and m.user_id = auth.uid()
          and m.role in ('owner','editor')));

Persons and receivables carry third-party names; they stay owner-only and
are never readable through any shared policy.

### 2.4 Flutter architecture for the cloud variant

- **State management**: Riverpod. The offline app's pattern (one store, pure
  money modules) maps to providers wrapping the same pure functions; the
  money layer stays pure Dart and portable, which is the single most
  valuable property to preserve.
- **Local DB**: Drift (SQLite). The offline-first rule survives the pivot:
  the app always reads and writes locally first, sync is a background
  concern. The existing encrypted-store work (ADR 0001,
  data/sql_cipher_ledger_repository.dart) already points this direction.
- **Sync**: an outbox queue in Drift. Every mutation appends an op with a
  client uuid; a drainer pushes ops to Supabase when online (upsert on
  client_id makes retries idempotent). Pull is incremental on updated_at
  per entity. Conflicts: transactions and payments are append-only facts,
  so true conflicts are rare; last-write-wins on scalar edits with the
  server clock, field-level merge for settings, and a manual review sheet
  only when the same entity was EDITED on two devices offline. Deletes are
  tombstones.
- **Auth**: supabase_flutter, anonymous-first if possible: the app works
  before any sign-in (the offline mode IS the product), and an account is
  created only when the user turns on sync or joins a shared wallet.
- **Firebase**: firebase_core, firebase_analytics, firebase_crashlytics,
  firebase_messaging, all behind one thin services/telemetry.dart facade so
  every event name lives in one file. One non-negotiable from the legal
  review below: Analytics and Crashlytics must be OPT-IN or absent, never
  initialized by default, because default-on collection would make the
  shipped "no analytics, no trackers" promise false for every user,
  including users who never touch sync. Consent gates come before
  initialization, not after.
- **Folder shape**: keep the current one, it already scales: lib/money
  (pure), lib/data (stores, repositories, sync), lib/services (platform),
  lib/screens, lib/widgets, lib/content. Cloud adds lib/sync and
  lib/services/telemetry.dart, not a reorganization.
- **Local-only forever**: mood and impulse check-ins, Money Time Capsule
  notes, draft transactions, Pan conversations unless the user explicitly
  opts a conversation into the LLM tier. These never enter the oplog.

### 2.5 The honest cost of the pivot

**Legal review** (legal-compliance-counsel, this spec, sources checked
2026-08-01 against current NPC and Google Play rules). Three items are hard
blockers to design around BEFORE any backend code; the rest is real but
ordinary compliance work.

The hard blockers:

1. **The utang third-party problem** is the sharpest legal edge in the
   whole pivot. Today "Kuya Ben owes me 2,000" is a private note on a
   private phone, covered by the Data Privacy Act's personal and household
   exemption, which protects the USER, not the company. The moment that
   row syncs to a server, Salapify is processing Kuya Ben's personal
   financial information, and he never consented and does not know the app
   exists. He has full data-subject rights, including the right to
   complain to the NPC about a company he never dealt with. Consent is
   unobtainable, so the only defensible design is end-to-end encryption
   where the server stores ciphertext it cannot read. A plaintext utang
   table on a server is the single most dangerous artifact this pivot
   could create, legally and reputationally, in a market where a leak
   names real neighbors and real debts.
2. **Account deletion has two mandatory doors** under Google Play (enforced
   since April 2024): a discoverable in-app delete flow AND a web URL where
   a user can request account and data deletion without reinstalling, named
   in the Data safety form. That means a small web presence and a working
   server-side deletion endpoint on day one of accounts. Noncompliance is
   grounds for removal.
3. **Default-on Firebase Analytics or Crashlytics would make the shipped
   promise a lie in code.** They initialize at app start and collect
   identifiers from every user, including users who never opt into sync,
   which makes "no analytics, no trackers" false for the entire installed
   base regardless of any sync consent screen. They must be opt-in or
   absent. Also deceptive and off the table: quietly editing the receipt
   (people screenshot trust pages), consent buried in terms, pre-checked
   boxes, or uploading first and asking later. Deceptive product claims
   are actionable under the Consumer Act via DTI, invalid consent at the
   NPC, and a stale Data safety form at Google.

The ordinary but real work:

4. **Controller status attaches immediately**: the day the first row lands
   on a server, RA 10173 fully applies, even with hosting abroad. Formally
   designate a Data Protection Officer (the founder), run and document a
   Privacy Impact Assessment, publish a real privacy notice with a lawful
   basis per purpose, and implement security measures demonstrable to the
   NPC.
5. **NPC registration is likely required, not optional** (NPC Circular
   2022-04): processing sensitive personal information of 1,000 or more
   individuals, or risk-posing processing, triggers registration, and
   financial records of named individuals are exactly the risk the NPC
   means. Budget it as a real filing.
6. **Breach notification is 72 hours** to the NPC and affected users (NPC
   Circular 16-03), full report in 5 days, no delay allowed at 100 or more
   affected subjects. A processor's breach (Supabase, Google) is still the
   founder's notification duty. The incident response plan is written
   before the pivot, not after the breach.
7. **Data-subject rights become features**: access, correction, erasure,
   objection, portability, each needing a working mechanism (download my
   data, real deletion across Postgres and Firebase, a monitored contact
   channel). NPC fines can reach a share of gross income per infraction.
8. **Cross-border hosting is allowed but liability stays home**: sign the
   Supabase and Google data processing agreements, keep copies, align with
   the NPC's 2024 model contractual clauses advisory. If the processor
   leaks, the NPC comes to the founder.
9. **The Play Data safety form flips** from "no data collected" to a long
   honest confession: accounts, financial info, identifiers, diagnostics,
   sharing with Google, encryption in transit, deletion path. Google
   cross-checks the form against observed traffic; a mismatch is a removal
   offense. Form, policy page, and in-app receipt must change on the same
   day.
10. **Finance-app adjacency sharpens**: the Financial features declaration
    stays "none" (Salapify lends nothing), but a Finance-category app that
    suddenly has accounts, a server, push, and "utang" all over its listing
    invites a second look under the PH loan-app screening regime. The
    mitigation is the copy discipline already practiced. FCM marketing
    pushes need consent and opt-out; transactional reminders are fine.
11. **Retiring the shipped promise, the clean way**: sync ships strictly
    opt-in and off by default, offline stays the default forever, the
    receipt is rewritten in the same release that adds any connection (its
    own header rule), the opt-in screen says in plain words what leaves
    the phone and to whom with a working decline, and local data never
    migrates to the server without that explicit action. Users who never
    opt in must still pass the airplane-mode challenge for their money
    data. The default is the promise.

The lighter alternatives, priced:

- **(a) Encrypted export shared user to user, no server**: near-zero new
  exposure. The app never holds the data, the Data safety form stays "no
  collection" (a user sharing a file is user-initiated), the receipt stays
  true. The cheapest sync-like feature that exists.
- **(b) Opt-in crash reporting only**: small, real exposure. The form
  declares diagnostics and identifiers, the receipt gains a third
  connection, payloads must be provably scrubbed of amounts and names.
- **(c) Opt-in aggregated telemetry, no financial data**: like (b) but
  wider, and the burden is proving "no financial data" with tests. The
  founder-approved on-device counters design (ADR 0002: manual, previewed,
  opt-in sharing) already collects nothing automatically and needed no
  form change; (c) is only worth its cost if the counters prove
  insufficient.

**Business review** (finance-strategist, this spec):

The case for the pivot is weaker than it looks. The server bill itself is
trivial at this scale (Supabase's paid tier is roughly PHP 1,500 a month);
the real bills are the trust story rewrite that deletes the number one
stated install reason in a market specifically burned by data-scraping
lending apps, the Data safety form going from clean to complicated, a solo
founder becoming the on-call security custodian of Filipino financial
ledgers, and an auth support burden (lost passwords, "my utang list
disappeared") with no support staff, arriving from the segment least able
to self-serve. Today a bug report with no server logs is annoying;
tomorrow an account outage with an angry review is fatal to a trust-moat
product.

The revenue that would justify it does not exist in the current model.
Lifetime Pro funds zero recurring obligations by design. Sync and shared
wallets create perpetual per-user cost and liability, so under the
Monetization.md rules they would need their own subscription (the Pan AI
add-on precedent), and justifying the pivot's trust cost plus an
engineering year needs on the order of thousands of paying subscribers,
meaning hundreds of thousands of installs at plausible attach rates,
before the first line of backend code. The first server in the product's
life should be the stateless AI proxy with a subscription attached to its
cost from day one, not a ledger store.

The cheapest credible middle path is file-based and covers most of the
imagined value: one member acts as treasurer of record and shares an
encrypted snapshot or per-person statement through the channels Filipinos
already use. Statements, split-a-bill, and the share cards already do the
one-way half and advertise the app while doing it. The step beyond, if
ever needed, is an end-to-end encrypted blob in the user's own Google
Drive [OFFLINE-PLUS, new base APK], which keeps "your data never touches
our servers" literally true. Shared wallets stay [CLOUD], parked behind a
separate founder decision gated on proven willingness to pay monthly; the
middle path ships first and may make the pivot permanently unnecessary,
which would be the best outcome for both the user and the business.

Beyond legal and business:

- **The trust story rewrite**: the Privacy receipt's "no account, no cloud"
  is shipped marketing. Retiring it is a product event, not a settings
  change, and competitors will quote the old screenshots.
- **Operations**: a solo founder takes on uptime, backups, restore drills,
  abuse handling, and support with server logs (today "no server logs" is
  also the support story, per the support-retention playbook).
- **Money**: Supabase and Firebase costs are small at the start and grow
  with exactly the users who pay PHP 249 once, lifetime. The unit economics
  of lifetime pricing plus servers need Monetization.md revisited BEFORE
  the pivot, not after.
- **Migration**: every existing offline user needs a clean import path into
  their new account, and the reverse export must stay lossless, because
  data portability is never paywalled and never breaks.
- **Delivery**: supabase_flutter and firebase_* are native packages: a new
  base APK, a manual install for every tester, and a bigger app.

## Part 3. AI design and prompt strategy

Grounding: Pan today is rule based and computes every number in the money
layer. docs/AI_Strategy.md holds the deeper target-state architecture;
docs/AI_Readiness.md holds what must change first. This part triages the
brief's five AI workflows against the labels, and specifies the cloud
variants for the day they are wanted.

### 3.0 The design rule that binds all five workflows

Numbers are computed, never generated. Whatever the model writes, every
peso figure in a Salapify surface comes from the money engine. In cloud
variants the model receives derived aggregates and writes prose around
them; it never does arithmetic the app then displays. This is Pan's
existing contract (respond.dart phrases numbers it cannot change) extended
to any future model.

### 3.1 Transaction extraction (text, voice, photo)

- Offline today: none for photos; Area 1's fast-log parser covers text
  [OFFLINE-NOW], ML Kit OCR plus heuristics covers receipts
  [OFFLINE-PLUS]. Expected to capture the large majority of the value.
- Cloud variant [CLOUD]: an edge function accepts the OCR text (not the
  image, unless OCR confidence is low and the user consents), returns
  strict JSON: amount, date, merchant, channel, category guess, confidence.
  - System prompt sketch: "You extract one financial transaction from
    Philippine receipt text. Output only JSON matching the schema. Amounts
    are PHP unless another currency is explicit. If a field is not present,
    use null. Never invent values."
  - Kept local: the user's ledger, names, balances. Sent: the single
    receipt's text.
  - Cache: hash of the normalized OCR text, so a re-scan is free.
  - Learning loop: every user correction of an extracted field is stored
    locally as a labeled example; corrections feed heuristic improvements
    first, prompt tweaks second.

### 3.2 Cash flow forecasting

Deliberately NOT an LLM job. The forecast is deterministic math on the
device (Area 2). The only AI role is phrasing: an optional one-paragraph
narrative of an already-computed timeline. Offline, template phrasing does
this fine (the coach already ranks and phrases). A cloud narrative is a
luxury, priced accordingly, never a dependency of the feature.

### 3.3 Coach Q and A

- Offline today [LIVE plus OFFLINE-NOW]: 18 intents plus the Part 1
  additions (memory, timeline-aware answers, tone packs).
- Cloud variant [CLOUD]: the edge function receives a capability manifest
  rather than the ledger: current derived aggregates (safe to spend, debts
  summary, goal pace, the active plan object), the user's question, and the
  selected tone. The model may also request a named tool from a fixed list
  (the same resolvers Pan uses) through function calling; the app executes
  locally or the edge function against the user's rows under RLS.
  - System prompt sketch: "You are Pan, Salapify's money coach for Filipino
    users. Be concrete and kind. You may only cite numbers present in the
    provided data or returned by tools. Refuse investment, lending
    brokering, tax, legal, and insurance advice and point to the app's
    calculators instead." The five guardrails remain refusals at the
    application layer too, before the model is ever called.
  - Modes: supportive and direct only. No roast mode (Area 5 reasoning).
- Memory: the active-plan object (Part 1, Area 3) is the memory in both
  variants; the cloud tier reads the same object rather than inventing a
  parallel one.

### 3.4 Money Stories

- Offline today [LIVE]: the recap card computes and phrases a month from
  templates.
- Cloud variant [CLOUD]: a nightly or on-demand edge function turns the
  month's aggregates (never transaction rows) into a short narrative in the
  selected tone, cached in insight_snapshots per period, regenerated only
  when the period's data changes. Shared cards keep the hide-amounts toggle.

### 3.5 Challenge recommendations

- Offline [OFFLINE-NOW]: rules pick from the challenge catalog using
  existing analytics (category movers, overspend streaks): food delivery
  spiking suggests the 14-day pause; a thin buffer suggests the emergency
  starter. No model needed for a catalog of a dozen challenges.
- Cloud variant [CLOUD]: only worthwhile once the catalog is large and
  community-built; not before.

### 3.6 Quality, cost, and measurement

- Every AI surface gets thumbs up or down plus an optional "fix it" that
  stores the corrected output locally as a labeled pair.
- Cost control: cache by input hash (3.1), cache by period (3.4), aggregate
  inputs are tiny; token ceilings per call in the edge function; rate
  limits per user per day at the edge.
- Edge functions are the single door for every model call: prompts live
  server-side and versioned, privacy rules are enforced there (strip
  names, strip person tables), logs capture prompt version, latency,
  tokens, and outcome, never the payload.
- Firebase Analytics (only after the pivot, only with consent): events
  ai_extract_used, ai_coach_asked, ai_story_generated, ai_feedback with a
  helpful boolean and prompt_version, plus retention cohort comparison of
  AI-active versus non-AI users. Until any pivot, the honest measurement
  story is Part 6's.

## Part 4. Onboarding and key screens

### 4.1 Onboarding, current and enhanced

Current [LIVE] (screens/onboarding.dart): what Salapify is, currency and a
starting monthly budget, the nightly nudge ask (which also arms the
comeback ladder), optional sample data, then the first-log prompt in the
shell.

Enhanced flow, all [OFFLINE-NOW], target under five minutes, every step
skippable:

1. Welcome: the one-line promise, "your money stays on this phone", with
   the receipt one tap away. Trust is the first screen, not a settings page.
2. Currency and budget (exists today).
3. NEW Payday step: "when does money usually arrive?" writes the payday
   schedule (the payday screen exists; this moves the ask to first run).
   This single answer unlocks safe to spend, Your Number, payday reminders,
   and the future timeline, so it is the highest-value question the app
   can ask a new user.
4. NEW One bill: name one bill and its day (seeds recurring, unlocks
   bills-before-payday).
5. NEW One goal or one debt, whichever the user picks: seeds the emotional
   anchor feature.
6. Nudge ask (exists today, arms daily plus comeback).
7. First log within sixty seconds of finishing: the existing first-log
   prompt, now followed by the chain's first dot lighting up as the
   immediate reward.

The aha moment to protect: after steps 3 and 4, the Home screen already
shows a real safe-to-spend number. Value before any history exists.

### 4.2 Key screens

Existing screens map to the brief's list almost one to one:

- Home / Dashboard [LIVE]: screens/overview.dart, plus the coach's WHAT
  MATTERS NOW on Insights. Enhancement [OFFLINE-NOW]: a compact timeline
  sparkline (Area 2) with the next low point flagged.
- Log [LIVE]: log sheet plus quick adds. Enhancement: the fast-log field
  (Area 1) as the sheet's first row.
- Budget and safe to spend [LIVE]: Budget tab plus SAFE TO SPEND UNTIL
  PAYDAY on Insights.
- Coach chat [LIVE]: Pan, full screen with starter chips.
- Challenges [OFFLINE-NOW, new screen]: catalog, active challenge with
  progress from the ledger, finish moment minting the share card. Lives
  beside Treats in the habit cluster; NOT a new tab (the shell's typed
  Destination set stays as is; it is a pushed screen from Home and Menu).
- Utang / shared [LIVE]: the Money tab (I owe, owed to me), split-a-bill,
  per-person statements; the household space (Area 6) joins here.
- Menu, settings, privacy [LIVE]: Menu with the notifications card, App
  lock, the Privacy receipt, Diagnostics, backup and export.

### 4.3 Notifications and channels

- Local notifications [LIVE]: the pure planner covers daily, payday, bills,
  collect, backup, comeback; Area 2 adds the projection alert. This is the
  complete re-engagement story for the offline app; the comeback ladder is
  the FCM-replacement for lapsed users, shipped f3.14.
- FCM push [CLOUD only]: adds server-triggered moments (a shared-wallet
  comment, a challenge cohort update). Not needed for any single-user
  feature in this spec.
- Deep links [OFFLINE-NOW, limited]: plain https links to the Play listing
  with UTM parameters on every share card. Full deferred deep linking into
  app content is [CLOUD] plumbing, deferred.

## Part 5. Breakthrough feature deep dives

The picks were reviewed by the finance-strategist against retention,
engagement, virality, and solo-founder feasibility. Verdict: build the
timeline deepest (it is the only pure decision engine of the three and the
natural flagship of the Pro line "Pro answers next month, free handles
today"), center Pan's memory on a standing plan rather than chat
transcripts, and keep challenges third with the honest no-cohort framing:
"challenge your barkada" means "send them the card", and the app never
implies it connects anyone. The nearest contender, a payday allocation
autopilot, ships better as the payday entry point into the first two picks
than as its own feature.

**Free versus Pro mapping** (bound by the standing promises: nothing a user
already has moves behind the wall, sharing loops are never paywalled, data
portability is never paywalled):

- Timeline: the view to the NEXT payday is free (the anxiety reducer and
  habit loop); the 14/30-day rolling horizon is Pro.
- Scenarios: the two existing single-variable what-ifs stay free as they
  are today; multi-scenario compare and saved scenarios are Pro.
- Challenges: the entire loop is free (create, track, share); extra card
  styles and concurrent challenges are the cosmetic Pro filler, per the
  palette precedent.
- Freelancer P and L (Area 7): the basic monthly summary is free and CSV
  export stays free always; client and project tagging, quarterly views,
  and lean-month analysis are Pro. Pro sells the analysis, never the data.
- Money Stories and recap cards: free with the hide-amounts toggle
  prominent; extra themes only for Pro.
- Shared wallets, if the pivot ever happens, are never folded into
  lifetime Pro: they carry perpetual server cost, so under the
  Monetization.md rules they price like the AI add-on, as a subscription,
  and that is a separate founder decision.

### Breakthrough 1. The Sweldo Timeline (rolling cash flow with scenarios)

**The problem**: every budgeting app answers "what did I spend". Almost
none answer the question Filipino users actually ask twice a month: "hanggang
kailan aabot ang pera ko, at ano ang mangyayari kung...". Existing apps that
do forecast (Copilot, Rocket Money) do it from bank feeds, which requires
the exact linking Salapify's audience distrusts.

**Why Salapify wins here**: the payday schedule, recurring items, debt
minimums, goals, and a conservative calendar already exist as pure, tested
Dart. Extending them is home-turf math, not new infrastructure, and it
ships over the air.

**User flow**: Home shows a sparkline of the next 30 days with the lowest
point flagged ("tightest day: Aug 10"). Tapping opens the timeline: balance
line across month boundaries, event markers (sweldo, bills, dues), the
variable-spend band, and a scenario drawer. Add a scenario ("buy 12k phone
on the 15th", "extra 1k to the card monthly"), see a second line overlay
instantly. Pan answers afford questions from the same engine.

**Technical shape**: extend money/cashflow_calendar.dart to a horizon
parameter crossing months (payday events from money/schedule.dart);
scenarios are pure transforms over the event list, so an overlay is just
a second run with injected events; the low-point alert is one new kind in
money/reminders.dart with the fires-and-stays-silent proof. Golden vectors
for every projection, per the porting rules.

**Success measures** (honest, on-device or store-level): the timeline
screen's local open counter in Diagnostics, scenario saves, and whether
testers name it in feedback; store-level, retention movement after the
release that ships it.

### Breakthrough 2. Barkada Challenges (local challenges, shareable proof)

**The problem**: money challenges are everywhere on social media
("ipon challenge" envelopes are a genuine PH phenomenon), but apps
implement them with accounts, leaderboards, and comparison stress. The
paper version wins because it is private and physical. No app is the
digital version of the envelope on the wall.

**Why Salapify wins here**: the ledger can verify many challenges
automatically (no food delivery for 14 days is a category query; the 500-a
week groceries is a running total), the chain's no-reset philosophy removes
the shame mechanic that kills streak apps, and the share-card pipeline
already exists. No accounts needed: the share IS the social layer, and the
card is the proof on the wall.

**User flow**: pick from a curated catalog (or the rules engine suggests
one from spending patterns), see progress fill from real ledger data, get
the gentle no-guilt check-in, and at the finish the card mints with the
same celebration as a milestone. A missed day is a gap, never a reset.

**The five design rules** (behavior-scientist, binding on the build):
1. **Duration is one payday cycle**, default 15 days, aligned to start on
   the 15th or the 30th. "Sweldo to sweldo" is the natural unit of
   Filipino money life and the app already models it. Offer the challenge
   in the 48 hours after payday, the fresh-start moment at its strongest
   natural trigger; a challenge started mid-cycle waits, by default, for
   the next payday.
2. **Check-in is passive, from the ledger; the user's only job is
   logging.** Never a separate "did you resist?" tap. An abstain challenge
   reads categories, a cap challenge sums them, judged on the week's total
   in the treats rolling-window spirit, never on a single day. One habit
   loop, not two: the challenge becomes a reason to log.
3. **A slip costs one day, never the challenge.** Progress counts days
   kept, not days in a row: a slip on day 6 makes the result "13 of 15
   kept", never "failed, restart". Show the money kept so far beside the
   days, because pesos kept do not un-keep themselves. At setup, ask one
   implementation-intention question ("when the craving hits, I will...")
   with chips, because a pre-formed if-then plan roughly doubles
   follow-through.
4. **The end is a result screen, never a pass or fail verdict.** "You kept
   12 of 15 days and about 840 pesos stayed yours" is true at almost any
   outcome. The share card mints at 80 percent or better so it stays
   meaningful; every finish offers "run it again" and never says failed.
   The kept-amount is computed from the user's own prior-cycle baseline,
   engine-derived, never invented.
5. **One active challenge at a time**, from templates, with a no-penalty
   pause. People who change one behavior at a time succeed; five austerity
   rules declared on payday die together by the 20th. When the coach's
   crunch state fires, the challenge offers to pause, because a milk tea
   challenge is noise when the rent is short.

**Technical shape**: a challenges catalog in content/ (like lessons), a
progress evaluator in money/ reading the ledger (pure, golden-vectored),
persistence in the settings blob, the card via the milestone_share
pipeline, reminders through the existing planner.

**Success measures**: local counters (started, finished, abandoned,
shared), and card sightings (the founder will literally see them on
socials, which is the point).

### Breakthrough 3. Pan With a Plan (coach memory)

**The problem**: every finance chat assistant answers questions; almost
none hold the user's ongoing plan and follow up. The retention moment is
not the answer, it is being asked "kamusta ang plano natin?" a week later
by something that remembers.

**Why Salapify wins here**: Pan already computes real answers from real
data with guardrails. Memory is a data-shape problem, not an AI problem:
one active-plan object (kind, target, monthly amount, start date) written
into the blob, read by Pan, the coach, and the timeline.

**User flow**: the user asks "when will I be debt-free"; Pan answers and
offers "gawin nating plano?" One tap saves the plan. From then on Pan opens
with progress against it, the coach's DO NEXT ranks it, milestones fire on
its checkpoints, and the timeline draws its payments. Changing or dropping
the plan is one tap, no guilt copy.

**Technical shape**: a plan object in settings, a money/plan.dart evaluator
(pure), Pan resolvers gain plan-aware intents, coach.dart gains a plan
nudge kind, milestone engine gains plan checkpoints. All over the air.

**The trust rule**: rule-based Pan must never sound like it remembers more
than it stored. The plan is shown as an editable card the user can read,
change, and delete, so what "memory" means is exactly visible. It lives in
a small capped store, is erased by Start fresh with everything else, and
when the LLM tier ever arrives, the plan object is the digest the model
receives, not the conversation history.

**Success measures**: plans created, plans active after 30 days, the
follow-through delta between plan-holders and non-holders in local
Diagnostics counts.

## Part 6. Google Play growth plan, PH first

Built with the aso-marketer on top of docs/play-store-listing.md and
docs/Product_Strategy.md. One pre-submission fix surfaced during this
review and is recorded here so it is not lost: the current listing draft
uses "loans" and "loan calculator" in several lines; before submission
those become "credit cards, BNPL, and other debts" and "amortization
calculator", staying clear of Play's finance-app loan vocabulary. All copy
below already complies. The strategy doc's no-incentivized-referral rule
holds throughout: share links are attributed, never rewarded.

### 6.1 Five growth experiments

**E1. Recap and milestone cards with quiet attribution.**
Hypothesis: a card with amounts hidden by default is safe barkada flex, and
a quiet link on it converts viewers who already trust the poster.
In-app: hide-amounts on by default; a small "via Salapify" footer with a
Play link tagged utm_source=sharecard, with a visible opt-out.
External: the founder reposts the best user cards, with permission, twice
a week.
Metric: monthly installs from the sharecard UTM channel in Play Console;
target 50 in month one.

**E2. Seasonal calculator drops.**
Hypothesis: demand for 13th month and take-home answers spikes on a
calendar the founder can see coming (November to December, January to
April, every job offer), and an instant honest calculator converts the
spike.
In-app: the calculator-to-ledger bridge, plus a shareable result image
tagged utm_source=calc.
External: short-form posts and a one-page web version of each calculator,
published November 1 and January 15, linking to Play with the calc UTM.
Metric: calc-channel UTM installs during each seasonal window versus the
prior month.

**E3. Micro-creator early access.**
Hypothesis: PH creators in the 5k to 50k range will cover a privacy-first
utang tracker unpaid because it is native content, and per-creator links
make the winners obvious.
In-app: none needed; each creator gets a custom store listing reached by a
dedicated URL (Play supports up to 50), so their traffic lands on a listing
that opens with the same hook as their video.
External: pitch 15 creators with a one-page kit, an early access build,
and a personal tagged link; aim for 5 posts in launch month. Campus and
early-career audiences are reached through creator choice, not a separate
program.
Metric: installs per creator link; any creator above 100 installs earns a
round two.

**E4. BPO and startup HR payday brown bag.**
Hypothesis: HR teams will accept a free 20-minute payday-week session on
sweldo planning, and a captive room with employer-borrowed trust converts
far above cold traffic.
In-app: read the install referrer on first run (fully on-device), so
installs from the session QR open straight into the take-home calculator.
External: pitch 5 People or HR leads at BPOs and startups for a session in
the week of the 15th; one deck, one room QR with a per-company UTM.
Metric: at least 25 percent of attendees install via the session QR within
7 days.

**E5. The utang reminder loop.**
Hypothesis: every polite bilingual reminder that lands in a counterparty's
Messenger is an endorsed ad, because the recipient has utang pain by
definition.
In-app: one-tap copy of the reminder and the per-person statement, each
ending with an optional "sent via Salapify" line linking to a
utm_source=reminder Play link.
External: two short videos showing the exact message, framed as how to
follow up without the awkward.
Metric: reminder-channel UTM installs per month.

### 6.2 Listing angles

Title and short description pairs (Play limits: title 30 characters, short
description 80). Recommended: pair A at launch, then pair C as the first
store listing experiment, since it carries the exact primary keyword
"utang tracker".

- A (recommended). Title: "Salapify: Budget, Utang, Ipon". Short: "No bank
  link, no account. Track utang, budget your sweldo, all on your phone."
- B. Title: "Salapify: Budget & Utang". Short: "Utang tracker and sweldo
  budget. Offline, no account, data stays on your phone."
- C. Title: "Salapify: Utang Tracker". Short: "Track who owes you, split
  bills, budget by payday. No bank link, no sign up."

Five feature bullets:
1. Utang tracker with per-person balances, statements, and friendly
   reminders in English or Taglish
2. Budget by your real sweldo cycle: 15th and 30th cutoffs, 13th month,
   and what is safe to spend
3. Card statement forecasts that respect weekends and Philippine holidays
4. No bank linking, no account, no ads: everything stays on your phone,
   with a Privacy receipt to prove it
5. Ask Pan in plain Taglish, plus PH tax and take-home pay calculators
   built in

Eight-screenshot storyboard, trust story first:
1. Privacy receipt. "No bank linking. No account. Your money never leaves
   your phone."
2. Utang list. "Know exactly who owes you, per person, with due dates."
3. Reminder compose. "Send a friendly reminder in English or Taglish. The
   app is the polite one."
4. Safe to spend. "See what is safe to spend until your next sweldo."
5. SOA forecast. "Know your card statement dates, adjusted for Philippine
   holidays."
6. Hatian split. "Split the bill. Each share becomes utang you can
   collect."
7. Pan and calculators. "Ask money questions in plain words. Tax and
   take-home pay included."
8. Recap share card. "Milestone cards worth sharing, amounts hidden. Free
   during early access, early users keep Pro free."

### 6.3 Measurement, stated honestly

The live app has no server and no analytics, by promise. What the founder
can measure today without writing a line of backend: Play Console (store
listing impressions, listing conversion rate, installs and uninstalls by
country, acquisition split by search, browse, and tracked UTM channel),
store listing experiments (Play's built-in A/B on icon, screenshots, and
copy), custom store listings with per-channel analytics for the creator
and HR experiments, the install referrer readable on-device so the first
run can adapt to its channel, review mining, and the local Diagnostics
counters a tester can choose to share from their own phone. What is
honestly not measurable until a pivot plus consent: retention curves and
daily actives, feature-level usage, activation funnels, whether a specific
card led to a specific install, and per-user cohort economics; until then
the proxies are Play's retained-installer stats, uninstall rate, and what
reviews say people do with the app. Every experiment above is scored only
with the first list, so no experiment silently depends on a tracker the
app does not have.

## Closing note

The order this spec recommends, if the founder asks "what do we build next
from here": Breakthrough 1 (the Sweldo Timeline) as the spine, then
Breakthrough 3 (Pan With a Plan) as the coach layer on top of it, then
Breakthrough 2 (Barkada Challenges) as the growth layer beside it, with two
small ride-alongs early: the fast-log parser (Area 1) and Park it (Area 8),
both cheap and both new daily surfaces. All five are [OFFLINE-NOW] and
ship over the air. The cloud section stays a priced option, revisited only
when a feature that truly requires it (shared wallets across phones)
proves people will pay monthly for it; the file-based middle path ships
first and may make the pivot permanently unnecessary.
