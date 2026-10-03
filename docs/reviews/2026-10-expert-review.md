# Salapify Expert Review, Oct 2026

Oct 1, 2026 · @Chopper

> Recorded into the repository on 2026-10-01 so the build sprint has the
> source it cites. The sprint prompt
> (`SALAPIFY_BUILD_PROMPT.md`) names this file as required reading and it did
> not exist here; the founder supplied the text. Reproduced as delivered.
>
> It reviews commit e527a16 on claude/flutter-final. Three of its findings
> were already fixed between that commit and the start of the sprint, and
> `docs/PROGRESS.md` says which.

The money engine is genuinely good and genuinely Filipino, but the app today is a careful spreadsheet, not a partner. Four expert lenses (mobile engineering, finance coaching, UI/UX, and a Gen Z and millennial user panel) reviewed the live app/ build on claude/flutter-final at commit e527a16. Every finding below cites code that was checked.

## Scorecard

All four lenses agree on the same three uninstall triggers: a stranger's sample money on first open, no way to fix a wrong entry, and no reason to come back tomorrow.

| Lens | Grade | One-line verdict |
|---|---|---|
| Mobile engineering | B- | Crash-safe saving and 105 test files, but no edit or delete, no auto backup, plaintext storage, and saves that will lag at scale. |
| Finance coaching | B | Tax and contribution rules are current and honest. Safe to Spend counts savings as spendable and treats Tita's utang like a credit card. |
| UI/UX design | C+ | The Hapon look is distinctive. The app re-grew the features the revamp cut: 5 tabs, 27 sheets, 4 spend numbers on Home, no onboarding. |
| Gen Z / millennial users | C | They love "₱/day until sweldo" and utang both ways. Most would churn by day 2 to 10 on sample data, dead links, or a wrong balance. |

## What is already strong

Protect these. They are the reasons a user would pick Salapify over GCash's own tools or Money Lover.

- Safe to Spend explains itself. The Audit & Math tab shows every step behind the number (features/safe_to_spend/safe_to_spend_sheet.dart).
- Current PH rules. SSS 15% on the ₱5k to ₱35k salary credit, PhilHealth 5%, Pag-IBIG ₱200 cap, TRAIN brackets, 8% option blocked above ₱3M, EOPT registration fee removed (core/money/ph_tax.dart, business_tax.dart).
- Debt both ways. Split bill, record a collection, mark settled, with calm "pay when you can" copy.
- Taglish parser. fast_log.dart understands "padala kay nanay 8000 palawan" and admits when it is guessing.
- Crash-safe saving. Temp file, flush, rename, plus a pre-import copy (data/store.dart).
- Honest privacy. No account, one disclosed network call for FX, on-device receipt OCR, and a privacy sheet that does not overclaim.
- Filipino Academy content. Ambag line, utang na loob, remittance markups, SEC licence checks, OTP safety.
- Health check that refuses to guess. Shows "not measured yet" instead of a fake score (core/money/health_check.dart).

## Fix before launch

Ten trust breakers. In a money app, one wrong or lost number ends the relationship, so these come before any new feature.

| # | Issue | Why users leave | Evidence | Effort |
|---|---|---|---|---|
| 1 | Fresh install opens on sample data (₱48,500 payroll, a housing loan) with no onboarding. Home never says it is fake. | "Kanino 'tong pera?" Day 0 confusion, then distrust. | financial_state.dart _seed(); main.dart goes straight to AppShell | M |
| 2 | An entry cannot be edited or deleted after the 5 second undo. | One typo skews the balance forever. | transaction_detail_sheet.dart: "Nothing here can be changed yet" | M |
| 3 | Dead ends on Home: See all, Budget Pulse and add upcoming say "not migrated yet" while those tabs exist. | Feels broken. Bea churns here on day 2. | home_screen.dart lines 112, 118, 155, 160 | S |
| 4 | Marking an entry duplicate drops it from totals but leaves the account balance unchanged. | Balance silently disagrees with reality. | ledger.dart 258 to 275; reconciliation_view.dart 546 | S |
| 5 | No automatic backup. Export is manual; if sharing fails the ledger goes to the clipboard. | Lost phone means lost history. | settings_sheet.dart 228 to 250 | M |
| 6 | Data is plaintext JSON. Docs still say SQLCipher encrypted. No app lock. | Jen hands her phone to a colleague and leaves. | store.dart; no local_auth in pubspec | M |
| 7 | Safe to Spend counts emergency savings as spendable and reserves 8% of all debt, including family utang with no minimum. | The daily number is visibly wrong, so the app is "mali". | models.dart liquidKinds; safe_to_spend.dart line 48 | M |
| 8 | Every tap rewrites the whole indented JSON file on the UI thread and replans all reminders. | Lag after a few months of entries. | financial_state.dart 268 to 319; notification_gateway.dart 138 to 175 | M |
| 9 | Release builds use the debug signing key; CI only builds debug. Version 1.0.0+1, description "A new Flutter project." | Cannot ship to Play as is. | build.gradle.kts; app-check.yml; pubspec.yaml | M |
| 10 | Money stored as double in 1,039 places, against your own rule. Net worth uses a hardcoded USD 58.50 while the converter uses live rates. | Two screens disagree on the same peso. | models.dart; currencies.dart 69 to 81 | L |

Quick win: item 3 is about ten minutes of work. The onOpenTab callback already exists.

## Simplify

Go back to what your own revamp docs decided: four tabs and one number. The live app brought back most of what Salapify 3 cut, and that is the "assembled, not designed" feeling again.

### Navigation

- Four tabs, not five plus the Log pill. Your decision D23 already refused a fifth tab because tabs shrink to 36dp on small phones.
  - Home
  - Ledger (Entries, Insights, Reports as segments)
  - Plan (Budget, Upcoming, Goals)
  - Accounts
- Plan today is a 7 tile icon grid (plan_segments.dart), which your design system bans. Move Decisions, Trackers, Calculators and Academy out.
- Merge Toolkit, Tax, Business Tax, FX and Calculators into one Tools sheet. Fold Installment into Debt, and Health Check plus Safe to Spend details into one sheet behind the hero. Target about 14 sheets, down from 27.

### Home

- One spend number with one sentence. Today Home shows Safe to Spend, Total Remaining, ₱/day and "Lasts 188 days" plus a Conservative chip.
- One Pan entry point, not a floating button plus an inline card.
- After logging, stay on Home and roll the number down: "₱250 at Jollibee. Still ₱1,498 a day till payday." Today it jumps to Activity, so the user never sees why logging mattered.

### Logging (target: 3 seconds)

- Autofocus the parser field. There is no autofocus anywhere in lib/ today.
- Apply the parse as you type, and let Return save. No "Fill the form with this" step.
- Show 5 recent categories plus More, instead of 16 chips.

### Copy

Replace accountant words with plain Gen Z English or Taglish.

| Today | Better |
|---|---|
| Audit & Math | How we got this |
| Must remain reserved | Set aside |
| Liabilities and obligations | Bills and debts |
| Net worth, consolidated | Everything you have, minus what you owe |
| Destroying Debt | Paying it down |
| You overspent by | You went ₱X over. Next cycle is a fresh start. |

### Look and feel

- Accent and negative share one colour, so the Log button looks like an error. Give "over" its own muted shape.
- Pan uses the generic robot icon and opens with nine lines of disclaimer. Give Pan a two line warm hello and move the disclaimer behind the info dot.
- Add the motion your design system already defines: haptics, a number roll, and a "clear" moment when a debt hits zero. Today the only animation is the bank card.

## The first 7 days

The goal is a real number in 60 seconds, then one small reason to return each day until payday becomes the habit. Today nothing in the app is built to bring someone back: no streak on Home, no recap, no widget, and reminders are off.

| Day | What the user experiences | Why it keeps them |
|---|---|---|
| 0 | Welcome: "Know what's safe to spend until sweldo." Enter one balance (GCash, cash or bank) and payday (weekly, kinsenas/katapusan, monthly, or irregular). Hero shows their real number. Pan: "Try typing your last purchase, like 'jollibee 250'." | First value in under 60 seconds, with their own money. |
| 1 | The nudge they chose at onboarding: "Anything since lunch? One line is enough." Log in 3 seconds. Streak shows 2 days. | Ask for notification permission here, after they have seen value. Your reason for keeping it off at install is right; the fix is asking at the right moment, not never. |
| 2 | After the third log: "Add a bill that repeats? Rent and Meralco make your number honest." | The number gets more accurate, so it gets more useful. |
| 3 | First insight from real data: "Food is 42% of what you've logged. Want a soft limit?" One tap sets it. | Teaching at the moment it matters, not in a library. |
| 4 | "Anyone owe you, or you owe them?" The split bar appears on Home. | Your differentiator, utang both ways, discovered early. |
| 5 | "See your number without opening the app." Add the home screen widget. | The strongest daily touchpoint for an offline app. |
| 6 | "6 days logged. Your number is now accurate." A missed day uses a free pass, never shame. | Progress you can feel. |
| 7 | Sunday recap: in, out, top category, days under pace, plus a shareable card with no amounts. "Payday is Monday. Plan the next cycle?" | The bridge into week 2, and a reason to post it. |

## Coaching features

The biggest shift: teach through the user's own money at the moment it happens, not through a 32 lesson library. Ranked by impact on literacy and retention.

| # | Feature | Why it matters for Filipino Gen Z and millennials | Effort |
|---|---|---|---|
| 1 | Sweldo Day ritual. On every kinsenas and katapusan, a 60 second flow: pay yourself first, fund sinking funds (tuition, Pamasko, renewals), set the ambag line, then see the new Safe to Spend. | Matches how Filipinos are paid. Creates a twice-monthly habit with a built-in reason to open the app. | M |
| 2 | Payoff plan on real debts. Snowball vs avalanche on the user's own balances with a debt-free date. Convert per-month add-on rates to true yearly cost for GLoan, SLoan, Atome, Billease, Home Credit. | E-wallet loans and BNPL are the biggest Gen Z drain. Today the comparison runs on three example debts. | M |
| 3 | Emergency fund ladder. ₱10k, then 1, 3, 6 months, held in accounts marked Protected so they leave Safe to Spend. | Turns abstract advice into visible progress. Today the fund is found by matching goal names, so "ipon" also matches a Japan trip. | S to M |
| 4 | Moment lessons. 30 second cards with one action, triggered by events: first card statement, a BNPL purchase, 13th month in November, an overspent category, a large transfer to a new recipient (scam check). | People learn when it is relevant. | M |
| 5 | Ambag and padala, done kindly. A capped family support envelope, a "Hindi kaya ngayon" script, and a paluwagan tracker that records your rotation position. | Panganay pressure is the most common reason Filipino savings plans fail. | S to M |
| 6 | Monthly money date. A 10 minute review after katapusan: net worth trend, savings up or down, one win, one next step. | No net worth history chart exists today. | M |
| 7 | Challenges. No-spend days, a 24-cutoff ipon challenge (52-week adapted to kinsenas), a coin jar, a quiet celebration when a debt hits zero. | Brings the TikTok ipon trend into a real tool. Treats in Toolkit do not even save today. | S |
| 8 | Utang singil helper. A friendly, shareable "you owe me" message and due-date nudges for money owed to you. | Removes the awkward GC moment. Three of four personas asked for it. | S |
| 9 | Gov benefits hub. Check that SSS, PhilHealth and Pag-IBIG contributions posted, voluntary member reminders, MP2 as a goal type with no rates quoted. | Unposted contributions are a real local problem. | M |
| 10 | Freelancer mode. USD entries converted at the day's rate inside Log, a tax set-aside % on each payout, 1701Q and 2551Q reminders, irregular-income Safe to Spend. | Log has no currency field today, so Paolo's totals drift on his first payout. | S to M |

### Guardrails

- Pan's ban list blocks every imperative. General habits ("cover bills before payday") are not regulated advice. Allow those, keep banning named products and quoted rates.
- Apply that same ban list to the Academy, which names MariBank, GoTyme and Maya and quotes "4% to 6% p.a." as fact.
- Pick one debt-to-income rule. The app currently states four (15%, 25/40, 30/40, 35).
- Keep one health check (the five-question one) and retire Pan's 0 to 100 score so they never disagree.
- Habits and Subscriptions always show sample Netflix data, even after sample data is removed (plan_segments.dart line 608).

## Money copy errors

For an app that teaches, one wrong peso figure costs more credibility than a missing feature. Items 1 and 2 were confirmed in code; the rest need a check against current BIR and lender sources.

1. Mixed income ignored in the tax sheet. calculateFreelanceTax is called without compensationIncome or vatRegistered (tax_calculator_sheet.dart line 348). An employee with a sideline gets the ₱250k exemption on the 8% option, understating tax by ₱20,000.
2. Freelancer comparison contradicts itself. The label says graduated on full gross, but the engine applies the 40% standard deduction, and the verdict adds 3% percentage tax that the side by side row omits.
3. Digital lender rate understated. "2.5% a month is 30% a year" is the flat add-on rate. Over 12 months the effective rate is roughly 51% a year.
4. Safe to Spend labels. "Upcoming bills before payday" actually covers all unpaid bills. The Conservative scenario says it trims irregular income, but expected income never changes the figure.
5. Stale Academy rates quoted as fact. Digital banks "4% to 6% p.a." and MP2 "5.5% to 7.5%+". Remove rates or show an as-of date.
6. Possibly outdated after CMEPA (RA 12214, 2025). The MP2 withholding tax line and the long-term deposit tax exemption. Verify.
7. Small fixes. Withholding constants use ₱8,541.67 where the BIR table has ₱8,541.80 (and the same for 33,541 and 183,541). "13th month and other de minimis up to ₱90,000" mixes two separate exemptions. A comment in bir_claims.dart says the top bracket is 32% (code correctly uses 35%).

## Roadmap

Recommended order: trust first, then the daily habit, then the coaching that makes Salapify worth keeping. Tick items off as they land.

### Now: trust and first run (before any public tester)

- [ ] Wire the four "not migrated yet" dead ends on Home
- [ ] Fix the duplicate status balance bug, with a round-trip test
- [ ] Edit and delete entries that reverse balances exactly
- [ ] Onboarding: start empty, one balance, payday, first log. Sample data becomes an opt-in demo labelled on the hero
- [ ] Safe to Spend: Protected account flag, real debt types and minimums, only bills due before payday
- [ ] Fix the tax sheet mixed income call and the rate copy errors
- [ ] Correct the docs that claim encryption

### Next: the daily habit (closed beta)

- [ ] 3 second log: autofocus, parse as you type, Return saves, recent categories
- [ ] Stay on Home after logging and roll the number
- [ ] Cut to four tabs and about 14 sheets
- [ ] Ask for reminders on day 1, plan 30 to 60 days ahead, refresh on resume, phone-brand battery guide
- [ ] Logging streak with a free miss
- [ ] Daily snapshots plus auto export to a folder the user picks, "last backup" nudge
- [ ] App lock and encryption at rest
- [ ] Debounced, off-thread saves, lazy lists, a 10k entry performance test

### Later: the partner (public launch and beyond)

- [ ] Sweldo Day ritual
- [ ] Home screen widget: safe to spend and days to payday
- [ ] Sunday recap and shareable sweldo-to-sweldo card
- [ ] Payoff plan on real debts and emergency fund ladder
- [ ] Moment lessons, challenges, singil helper
- [ ] Freelancer mode and currency in Log
- [ ] Release pipeline: upload key, release AAB in CI, local crash log users can share
- [ ] Taglish and Filipino localization, then iOS

One caution: the money changes (Safe to Spend, debt types, double to centavos) touch stored data and money meaning, which your working rules mark as founder-gated. Each needs a decision from you and matching test vectors before it merges.

## Marketing hooks

Three lines that came out of the user panel, each tied to a feature that already works.

1. "Know your ₱/day until sweldo." Petsa de peligro, solved in one number. Made for TikTok and Threads, aimed at Migs and Bea.
2. "Utang, both ways." Track what you owe and who owes you. Split the bill without the awkward GC math.
3. "No sign-up. No bank login. Your money never leaves your phone." The privacy hook for Jen. For freelancers: "8% or graduated, in 10 seconds."

Where Salapify wins against what people use now: PH payday maths, debt both ways, BIR depth, and privacy. Where it loses: logging speed against Monefy, simplicity against Tarsi, and fun against ipon challenge TikToks. The Now and Next items above close those three gaps.
