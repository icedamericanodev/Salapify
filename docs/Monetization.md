# Monetization Strategy

Sprint 1, 2026-07-10. A sustainable monetization model for the Philippine
market, grounded in the actual feature set, PH price sensitivity, and the
standing promises: core features free forever, data portability never
paywalled, early users keep Pro free. Marketing copy is always English and
never promises free forever for the whole app.

## 1. The free versus Pro line

### Free forever, non negotiable

The core loop and everything trust or growth critical:
- Logging, quick adds, budget bar, safe to spend, accounts, history, search.
- The entire utang ledger: person pages, reminders, statements, split a
  bill. The differentiator and the viral loop must never sit behind a wall.
- All 9 calculators. Acquisition hooks earn nothing gated.
- Manual backup, restore, CSV export (portability is never paywalled), and
  per the roadmap change in Implementation_Plan.md, the basic daily
  automatic backup becomes free too: safety is never held hostage.
- Free insights tier (Do Next, honest win, composition, runway, utang
  aging), week chain, recap, widgets, app lock, Pan rule based assistant,
  goals, notes, treats up to 3, recurring up to 5.

### The current Pro set, evaluated honestly

- Category caps: keep Pro. Felt weekly, clearly additive (the overall
  budget stays free), drives a real decision.
- Automatic backup: the basic daily backup moves to free (durability is
  trust). Pro keeps the depth: rotation choices, longer retention, and any
  future multi destination or encrypted backup format. Copy must say
  exactly that: free keeps you safe, Pro means never think about it again.
- Debt free projection (avalanche versus snowball with a date): the
  strongest Pro feature in the app. It answers when am I free and which
  order gets me there faster. Lead marketing with it.
- Forecast and 6 month trend: keep Pro; both drive decisions.
- Movers (what changed versus last month): keep Pro.
- Health score: decoration risk. A score nobody can act on is trivia. Keep
  in Pro only if every score ships with the one sentence explaining what
  moved it and what to do; otherwise cut before launch rather than ship a
  horoscope.
- Weekday pattern: package filler, never a selling point.
- Recurring beyond 5 and treats beyond 3: keep Pro; power users pay.

### Target Pro set at billing launch

Category caps, backup depth (rotation and retention), debt free
projection, forecast, 6 month trend, movers, unlimited recurring, plus 6
of the 8 color palettes (2 free; cosmetics are honest Pro filler).

Positioning line: Pro answers next month; free handles today.

## 2. Subscription strategy for the PH market

Recommendation: Salapify Pro is a one time lifetime purchase, PHP 249,
launch priced PHP 199. No subscription for the base app.

Reasoning:
- Reference points: Spotify PHP 149 a month, Netflix mobile about PHP 149,
  YouTube Premium about PHP 159, game top ups PHP 50 to 500. Filipinos pay
  these, but subscription fatigue is real and sana one time payment is a
  constant Play review refrain in this category. An offline app with zero
  marginal cost charging monthly rent invites exactly the distrust the
  brand cannot afford; churned subscribers write angry reviews, lifetime
  buyers write grateful ones.
- PHP 199 to 249 sits at one delivery meal for permanent value, survives
  GCash and Maya buying power scrutiny, and maps to standard Play pricing
  tiers.
- Launch timing: turn billing on in November with 13th month traffic, the
  one month of the year with genuinely discretionary cash and the app's
  biggest organic spike. Launch window PHP 199 for 60 days with an honest
  countdown, then PHP 249. No fake urgency ever after.
- Early users keep Pro free, kept mechanically: before billing ships,
  existing installs are stamped with a legacy entitlement the billing code
  treats as purchased forever. Announce it proudly; a kept promise is
  marketing.
- Infrastructure reality: there is zero billing code today (Pro is a self
  unlock flag). Google Play Billing with a one time product, entitlement
  cached on device, restore via the Play library. This is a native change
  and a full APK rebuild; it rides rebuild batch 1 in the release
  strategy.

## 3. Future AI pricing (Pan with an LLM)

### Unit economics

Assume a mid tier model at current market prices, roughly USD 0.50 per
million input tokens and USD 2.50 per million output blended. A well built
exchange sends a compact digest generated on device, not raw data: about
2,500 input tokens (the system prompt mostly a cache hit, cutting its cost
about 90 percent) and about 350 output tokens. That is roughly USD 0.002
per exchange.

- Light user, 20 exchanges a month: about USD 0.04 (about PHP 2.30 at 58).
- Heavy user, 60 exchanges: about USD 0.12 (about PHP 7).
- With 2x overhead for retries and occasional bigger model escalation:
  PHP 5 to 15 per active AI month.

### Pricing design

AI is the one thing with real recurring cost, so it is the one thing
allowed to be a subscription, sold as an add on, never folded into
lifetime Pro (that would strap a perpetual cost to a one time payment).

- Pan AI add on: PHP 49 a month or PHP 399 a year, available only on top
  of Pro.
- Token budget and fair use cap: 300 exchanges a month, 5 to 10 times the
  expected 95th percentile. At the cap the worst case cost is about USD
  0.60 to 0.90 (PHP 35 to 52), so even a cap abuser is roughly break even,
  and the median subscriber costs about PHP 5 against PHP 49, a 90 percent
  margin. Responses capped near 400 tokens and the digest near 2,500,
  enforced in the proxy (see AI_Strategy.md section 10), and the budget
  holds.
- Reject metering (pay per message). A taxi meter on a money coach
  manufactures the exact anxiety the product exists to remove.
- Include a monthly taste in lifetime Pro: 10 AI exchanges, so the upgrade
  is felt, not imagined.
- Trust requirements, non negotiable: AI is opt in, the consent screen
  shows the exact digest that will be sent before the first message ever
  leaves the phone, and the offline stance stays truthful: everything
  stays on your phone, except what you choose to send to Pan AI, shown to
  you first. This requires the proxy backend, the first server in the
  product's life; flag it loudly when the time comes.

## 4. Cost estimation beyond tokens

- Proxy hosting: one serverless function; effectively free below tens of
  thousands of AI users (request volume is small and stateless).
- Expo: OTA update bandwidth becomes a paid Expo tier around 1,000 monthly
  active update users; budget for the paid plan from roughly 5k MAU.
- Play Console: one time USD 25.
- Sentry: free tier suffices until well past 10k MAU.
- The dominant cost line remains AI tokens, which is why the add on is the
  only subscription.

## 5. LTV considerations

Rough model per 10,000 installs: 30 percent reach month one, 15 percent
still active at month three (about 1,500 users). If 6 percent of retained
users buy Pro at PHP 249, that is about PHP 37,000 per 10k installs, plus
AI later at even 2 percent of retained on the annual plan adding roughly
PHP 12,000 a year recurring. Modest, but costs are near zero and every
peso is clean. The lever is not price, it is installs times retention,
which is why the free tier must stay genuinely great and why the
Product_Strategy.md retention work precedes billing in the plan.

Guardrails that protect LTV because they protect trust:
- Never use loan or lending vocabulary anywhere (Play policy risk and user
  distrust in one).
- Never paywall something a user already had; grandfather on every line
  move.
- Never promise free forever for the whole app; the truthful lines are
  core features free forever, free during early access, and early users
  keep Pro free.
- One consistency flag found during this review: the current Play listing
  draft says Free. No ads. without qualification; when billing ships that
  line becomes Free core features, no ads.

## 6. Referral opportunities

Organic loops only, ranked by build priority:
1. Split a bill: every split names the app to 2 to 5 friends. Surfacing
   split (the UX-3 navigation work) is the highest ROI growth work
   available.
2. Shared reminders and statements carry a quiet via Salapify attribution
   with a visible opt out. Attributed and beautiful, never spammy.
3. Recap cards for social; calculators for seasonal search and group chat
   forwarding (13th month in November, tax and take home in Q1).
4. No paid referrals, no invite bribes. On a money app, manufactured
   virality reads as a scheme.

## 7. Sequencing (mirrors Implementation_Plan.md)

1. Now: nothing gated changes; the free durability move ships in the
   Stabilize phase.
2. Monetize phase (weeks 11 to 18): rebuild batch 1 carries Play Billing;
   legacy entitlement stamping ships BEFORE billing activates; Pro
   repositioned per section 1; November launch window if the calendar
   aligns, otherwise the next seasonal spike.
3. AI phase (months 5 to 9): Pan AI add on ships only after the proxy,
   evaluation harness, and cost dashboards exist; pricing revisited
   against measured token costs before launch.
