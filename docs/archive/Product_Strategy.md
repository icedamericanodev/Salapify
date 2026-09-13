# Product Strategy

Sprint 1, 2026-07-10. Grounded in the Sprint 0 audit, the actual codebase,
the Philippine competitive set, and a behavioral science review of the
existing habit mechanics.

## 1. Why will users install Salapify?

Acquisition hooks and the retention core are different things, and the
strategy is to stop confusing them.

Acquisition hooks (get the install; seasonal, searchable, shareable):
- The 9 PH calculators. 13th month pay spikes November to December; tax and
  take home pay spike January to April and on every job offer year round.
  Search driven, zero trust required, instant payoff. The BNPL true cost
  calculator is the sleeper: nobody else honestly unmasks zero percent
  installments, and it is screenshot bait.
- The utang keyword. Utang tracker is a low competition, high intent Play
  search the title already owns. People searching it have a specific pain
  today.
- The privacy stance. No account, offline, nothing uploaded is a real
  install reason in a market burned by lending apps scraping contacts.

Retention core (why they stay; none of it is why they install): safe to
spend per day, the sweldo plan, the utang ledger, debt payoff, quick add
logging.

Strategic implication: the calculator user and the ledger user are
different people on day one. The bridge is the conversion: after a 13th
month result, one line, want a plan for where this goes, into Goals or the
sweldo plan. After a take home pay result, track where it actually goes,
into the budget. A calculator session that ends at the answer is a wasted
install. The bridge is an invitation, never a gate on the answer.

## 2. Why will users return daily?

One question, answered above the fold: can I spend today, and how much.
Safe to spend per day is the daily heartbeat, which makes UX-2 (it can sit
below two cards for 48 hours after payday) a strategy bug, not polish.

The habit loop, in behavior terms:
- Cue: the widgets and the chosen time nudge externally; the low grade
  where did my money go feeling internally. The goal is migrating from
  external to internal cue by week 3.
- Action: one log. Quick add at 2 taps is the right floor. UX-1 (custom
  entry at 4 to 6 taps plus a scroll) is a habit problem, not just a UX
  problem: the action must be easier than the motivation is strong at 9pm
  on a tired Tuesday.
- Reward: the week chain dot springing, the toast, the day one recap at the
  third log. Variable enough (the coach win rotates by data) to avoid
  habituation.
- Investment: every log makes safe to spend, forecasts, and the coach
  smarter, which raises tomorrow's reward. This stored value flywheel is
  the honest reason to return.

Stacked rituals: the Monday weekly check in (mini fresh start), and above
all the payday ritual. Sweldo is the strongest natural fresh start
Filipinos have twice a month; the 48 hour sweldo plan (log it, move savings
first, then set the budget) is a textbook implementation intention chain.
Owning the first hour after sweldo lands is the franchise. Protect this
window above everything else.

What the behavior review says to keep untouched: the week chain never
resets (streaks that die teach quitting), treats use temptation bundling
with no loss framing, the coach never nags fresh installs and never
suggests cutting essentials, the nudge skips when already logged, and recap
verdicts celebrate honesty over outcome.

What is missing, ranked by retention leverage:
1. Sample data purity at the first real net worth (activation; the first
   true number is the aha moment and it must not be part fiction).
2. LogSheet speed (the daily loop's friction ceiling).
3. A designed comeback for the 7 plus day lapsed user: one coach card,
   fired once on first open after the gap. Welcome back, walang reset
   dito, your lifetime days are all still yours. Offer a single catch up
   entry (one honest estimated total for the silent stretch) instead of
   asking them to reconstruct the gap, show what changed (bills due, next
   payday) as facts with no verdicts, never show the gap length, and end
   the session on the today dot springing (peak end rule). If the return
   lands within 48 hours of a payday, route straight into the sweldo plan.
4. Nudge time as an implementation intention: ask when do you usually wind
   down at onboarding with three time chips, instead of a hardcoded 8pm.
   When it is 9pm, I log beats remember to log.
5. Notification decay for the lapsed: full cadence days 1 to 3 of silence,
   a day 7 comeback message, then stop until the app opens again. Silence
   after that is respect, and it saves the trust budget for the one
   message that matters.
6. A quiet lifetime counter (214 days logged since March) somewhere calm:
   endowed progress that can never be lost is the anchor a lapsed user
   comes back to.

## 3. Why will they recommend it?

Ranked by structural shareability:
1. Split a bill. The strongest loop in the app because the counterparty is
   structurally involved: the person you split with receives a share
   amount and hears the app name. Today it is buried three levels deep
   (UX-3). Promoting it is a growth decision disguised as a navigation
   fix.
2. The utang reminder in Tagalog or English. A message that lands in
   someone else's Messenger, solves hiya (the app is the polite one, not
   you), and advertises by existing. Same for the per person SOA.
3. The recap share card. 7 of 7 days logged is barkada flex material; the
   hide amounts toggle is what makes it safe to post, keep it front and
   center.
4. Calculators in season, forwarded through office group chats every
   November and on every job offer.

Add a quiet via Salapify attribution line to shared reminders and
statements, with a visible opt out. Attributed and beautiful, never
spammy. No incentivized referral program: paid virality on a money app
reads as desperation and erodes trust.

## 4. What is our competitive advantage?

Against the actual Philippine set:
- GCash's spend tracker sees only GCash; cash, the bank apps, the sari
  sari tab, and the utang to your tita are invisible. And its incentive is
  to feed GLoan and GGives. Salapify's incentive is the user. That
  sentence is the positioning.
- Lista is the cautionary tale: it won utang tracking, then pivoted toward
  credit products, requires an account, lives online. Every ex Lista user
  who felt that shift is our best early adopter. We win by being what
  Lista stopped being, without naming them in copy.
- Utang only apps have no budget context, so paying someone back never
  connects to whether you can afford to.
- The imported trackers (Money Manager, Spendee, Wallet class) have
  generic categories, subscription pressure, half working bank sync, and
  no concept of utang, kinsenas, or 13th month. They are apps localized to
  the PH; Salapify is native to PH money life.
- Spreadsheets lose on capture speed at the moment of spending. Paper is
  the honest market leader: fast, private, free. We must beat paper on
  speed (UX-1 again) and on what paper cannot do: totals, reminders,
  forecasts, statements, and never getting lost.

The durable advantage is the combination, not any single feature: utang
ledger plus budget plus PH payroll and tax literacy, in one offline
private app, from a brand whose business model never involves lending you
money.

## 5. What emotional problems are we solving?

- Utang shame, both directions. Asking a friend for money back violates
  hiya; owing money feels like moral failure. The scripted polite reminder
  and the calm ledger reframe both as bookkeeping, not character judgment.
  UX-6 (the all red Debts tab) actively fights this and must be fixed.
- Sweldo to sweldo anxiety. The scary question is not how much do I have,
  it is will I make it to the 15th. Safe to spend per day and runway
  convert a lump sum into a survivable daily number.
- Bill dread. The unknown is the fear: when does the statement cut, what
  is the minimum. The SOA forecast replaces dread with a date and a
  number.
- 13th month guilt. The pull between family expectations, Pasko, and
  saving. The calculator plus a Pasko goal template turns guilt into an
  allocation decision.

## 6. How do we reduce financial anxiety?

The research base: the ostrich effect shows people avoid financial
information precisely when acting matters most; shame (I am bad) drives
hiding while guilt (I did a bad thing) drives repair, so an app that
induces shame trains avoidance of the app itself; and in Filipino context
hiya makes debt a matter of face, so collection copy that damages a
relationship costs more than the peso amount. Apps reduce anxiety by
converting a diffuse threat into a specific, sized, next actionable item,
by making checking safe (no ambush of red on open), and by rewarding the
act of looking.

Five product principles, encoded as standing rules:

1. Red is an event, not a state. Warning color only for overdue, over
   limit, and interest not covered, exactly as theme.js promises. Never
   paint a balance red because it is a debt; a person carrying an on
   schedule loan is doing the right thing and the tab must look like it
   agrees. Chronic red is chronic threat; threat triggers avoidance;
   avoidance kills the check in habit.
2. Notifications name the next action, never the failure. Meralco is due
   in 3 days, pay at least 500 to avoid late fees: specific, timed to
   act. Never notify about overspending, a broken chain, or a missed day;
   negative verdicts live only inside the app where the user chose to
   look. The lock screen is public space and hiya applies there
   literally. Never put an amount the user owes on the lock screen
   without opt in.
3. Every negative number ships with its next step, sized small. Pair
   spending passed income with the fastest fix is easing the one category
   running hottest. An unactionable negative is pure anxiety; an
   actionable one is control. The existing guardrails stay absolute:
   never suggest cutting an essential, never suggest funding a goal when
   safe to spend is zero.
4. Reward the look, especially on bad days. The same dot spring, toast,
   and win eligibility for logging a blown budget day as a frugal one.
   Never gate a celebration on the money outcome. One top card on a bad
   week, the rest behind a tap.
5. Utang copy protects face first, money second. Collection framed as
   caring for the relationship; the borrower described neutrally (2 days
   overdue on 500, a fact); no character words, no debtor rankings, and
   on the payable side no moralizing (next sweldo covers it beats you owe
   people money). Hiya means the shameful path is silence on both sides;
   the app wins by making the face saving path the easy path.

## 7. How do we increase financial confidence?

Confidence is evidence of progress: the honest win (gated on real
logging), the net worth peak pill, the debt payoff celebration, the debt
free projection date (a date is hope in a way a balance never is), goal
pace (save X a month and you make Pasko). All exist; the near term job is
surfacing, not building. One addition worth building: a month one you
survived the month recap moment; the recap engine already exists.

Anti features to hold the line on: no doom charts without a sentence of
interpretation, no red as default, no fake precision (forecasts show their
assumption), no comparisons to other users.

## 8. How do we become indispensable?

- The ledger is the moat. Twelve months of transactions, per person utang
  history, receipts, and payment records cannot be reconstructed
  elsewhere. But a data moat you can lose to a broken phone is a trap:
  backup reliability IS the moat feature, which is why free durability
  moved up the roadmap. And data portability stays free forever; easy
  exit is what makes people comfortable going deep.
- The person ledger is a social record: what has Miko paid me since
  January exists nowhere else, not even in his memory.
- Widgets claim the home screen; the payday ritual claims the calendar,
  twice a month, forever.
- Seasonal compounding: in year two, your own logged income feeds the
  year end tax check and the 13th month estimate. The calculators stop
  being generic and start being about you. That is the moment a tool
  becomes an advisor, and it is the runway for Pan's LLM future: more
  history means better answers.

## Priorities this strategy implies

1. LogSheet speed (UX-1): the daily loop's ceiling.
2. Safe to spend above the fold (UX-2): the daily answer.
3. Unified Debts and Utang tab with Split promoted (UX-3): the
   differentiator and the growth loop, surfaced.
4. The calculator to ledger bridge: converting installs into loggers.
5. The comeback experience and notification decay: the churn moment.
6. De-redden the Debts tab (UX-6): small effort, direct hit on the core
   emotional promise.

These feed the epic priorities in Product_Backlog.md and the week by week
sequencing in Sprint_Plan.md.
