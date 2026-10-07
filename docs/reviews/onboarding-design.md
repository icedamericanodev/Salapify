# Onboarding, the design before the build (P3.2)

2026-10-03. Written before any code, per the brainstorming gate in CLAUDE.md.
Two specialist passes were run and every load-bearing claim in both was
verified against the code by reading it, not by trusting the report.

## What happens today

A fresh install goes straight to the Home tab on SAMPLE data. A 48,500
payroll, a housing loan, a GCash wallet, a debt to a person called Sarah.
Nothing on Home says any of it is fake. (`main.dart:102`,
`financial_state.dart:85`.)

Three things make this worse than it first looks.

**The payday is fabricated too.** `SeedData.payday` seeds `cycleType: 15_30`,
`nextPayday: Sep 15`, `daysToPayday: 4`, `expectedIncome: 32500`
(`seed_data.dart:952`), and the hero draws a cycle progress bar off it. So the
app does not merely lack a payday on a fresh install, it displays somebody
else's and counts down to it. The honest line "Set your payday to see a daily
figure" only appears after the sweep clears it (`financial_state.dart:2449`).

**The harm is already measured and written down, twice, in the repository's
own comments.** `financial_state.dart:119-129` records a brand new user with
one real 50,000 peso account seeing a Safe to Spend of 0.00, because 41,184
of demo bills and 6,348 of demo instalments were reserved against obligations
they had never entered, and no screen in the app listed those bills.
`financial_state.dart:2452-2466` records the mirror: after a sweep, Home still
read 38,414 safe to spend on an app with no accounts, no transactions and no
payday, because the demo income stream survived. Mixing real and demo data is
a defect class this codebase has already been bitten by, not a hypothesis.

**The apology is written and hidden.** `sample_data_sheet.dart:133-136`
already says it plainly: "Salapify added these when you first opened the app,
so no screen was blank. Those accounts hold X of savings and Y of debts, and
none of it is yours." That sentence is two taps and a scroll behind a gear
icon.

## What the user panel found

The worst moment is NOT the first ten seconds. All three archetypes converged
on the same one: **the first real entry landing in the fake data.** A 200 peso
debt from a neighbour lining up under "Sarah (Office lunch)". Up to that
point the fake figures are noise you scroll past; at that moment your life
merges with a stranger's and every total is wrong by an amount you cannot
work out.

Three people, three different wrong theories about what they were seeing: a
demo, a data breach, and their own mistake. The third is the dangerous one.
The sari-sari store archetype said 7,450 owed to her is a believable week and
she might have believed it for a day, and her reaction to finding "Sarah" was
embarrassment rather than suspicion, which makes her put the phone down rather
than go looking in Settings.

The header chip reads "On this phone", which is TRUE. Against money the person
never entered it reads as a lie, and it discredits the one honest claim on the
screen.

## Three approaches

**A. Start empty.** Honest, and it is also eleven cards of zero and a first
action that is the hardest one in the app. Intimidation is a real cost but it
is paid once and it is recoverable by guiding somebody through twenty seconds
of work.

**B. Keep the demo, label it on Home.** One glance from disaster. A label at
the top of Home does not travel with the 48,500 figure into Reports, Plan or
the Safe to Spend sheet, and the founder removed standing banners on
2026-09-19, so the label has nowhere honest to live permanently. It also
leaves the transition undefined: nothing in B decides WHEN somebody stops
browsing and starts entering, and that transition is the only event in the
first session that matters.

**C. Ask once, two taps, no typing. RECOMMENDED.** The question costs one tap
and asks nothing about the person, so its quit risk is near zero: quit risk
scales with effort and self disclosure, not with the existence of a screen.
What it buys is a declared intent. Somebody who chose "look around with
example data" cannot be confused by the figures, because they authored the
fiction. Somebody who chose "start with my own money" gets an app that can be
unambiguous about every number it shows. C contains B's safeguard rather than
replacing it: the demo branch still carries a permanent one line exit on Home.

C also sidesteps a bet nobody here can win from a desk. All three personas
said they preferred empty, which is suspiciously unanimous, and the usual
industry finding runs the other way (seeded demos raise comprehension and
lower first-entry rates). C does not need that question answered.

**Which failure is worse, stated plainly.** An intimidating empty app loses
somebody who understood the app. A fake-looking app produces somebody who logs
a real 320 peso fare into a ledger holding 48,500 of a stranger's payroll,
reads a Safe to Spend computed across both, and acts on it. That is not
confusion, it is wrong financial advice with a peso sign in front of it. And
the damage is retroactive: when they work it out, every number the app ever
showed them becomes suspect, including their own. There is no server copy, no
support channel and no account to appeal to. In an offline app, the
believability of its own arithmetic is the entire asset.

## The design

### The welcome, one screen

The Salapify mark, one line with no figures in it, "Offline. No account, no
sign up. Everything stays on this phone", and two buttons:

- Start with my own money
- Look around with example data first

Nothing else. No carousel, no skip, no tour.

### The real path: one account, one balance, nothing else

NO SEED AT ALL on this path. Not the accounts, not the bills, not the income
stream, and above all not the payday.

One question, keypad already up: where your money is (prefilled GCash, with
Bank and Cash beside it) and the balance it shows right now. An `i` dot on the
balance field explains, only if asked, that this is the same check Reconcile
will run later.

That is the only typed ask in the whole of onboarding. It is the one
irreducible datum: without an account, net worth is zero, Safe to Spend
cannot compute, Reconcile has no account to select, and a first logged entry
has nowhere to land. It is also the cheapest number in the person's life to
produce, because they read it off their GCash home screen, and it pays back
instantly with a figure that is theirs.

### Then Home, with their own number

The hero is their 5,140, not anyone else's 48,500. The Safe to Spend slot
reads "Set your payday to see a daily figure" and no invented number appears
anywhere. Absence with a door next to it beats a plausible wrong number, every
time, because a wrong number gets acted on.

Directly under the hero, one row: "Today: nothing logged yet." Tapping it
opens the Log sheet with the account preselected, today's date set and the
keypad up. On save, one line naming the consequence in their own money:
"Logged. GCash is 4,820 now." No confetti over 120 pesos and no praise for the
size or virtue of the spend. The habit being built is logging.

This is the only action in the first session that changes a figure the person
recognises as theirs, which is why it is the one that produces a second
session. Every other screen is a report on data that does not exist yet.

### The notification permission, attached to the first real entry

The save confirmation carries exactly one control: "Remind me to log at 9pm",
with "Not now" beside it. Tapping the first is what fires the Android dialog.

Two conditions decide permission conversion and this placement satisfies both:
the person has just performed the behaviour the notification supports, so the
benefit is concrete rather than promised, and they asked for it, so the system
dialog reads as confirmation of their own choice.

Never at install. Never off a demo entry, because a permission earned by fake
data is one you will be asked to justify later. On "Not now", do not ask again
in session one, and re-offer exactly once later framed by their own behaviour:
"You logged on 3 of the last 5 days. Want a nudge at 9pm?" A refusal at install
is near permanent and the only route back is a settings screen nobody finds,
which `reminders.dart:65-72` already states.

### The payday, asked at first income

Not at install, and never fabricated. A real-money install starts at
`PaydayCycle.unset`.

Ask when payday is salient, which is when the person logs their first income
entry. One sheet, prefilled with the common Philippine cycle, answerable with
a single yes: "Paid on the 15th and 30th?" with "Yes" and "Different days".
That is an inference confirmed, not a form filled, and it arrives on the day
they were thinking about their sweldo.

### The demo path

Keeps the demo, and Home carries a permanent one line exit, which is the panel's
single ask: the honest sentence already written in `sample_data_sheet.dart`
moves to where it is needed. It is the one banner that earns its place under
the 2026-09-19 rule, because it is not a standing nag, it ends the moment the
person taps it.

The moment a first real entry lands on the demo path, offer to clear the demo.
That closes the panel's "distant second" ask: their 200 pesos is never in the
same list as Sarah's lunch.

### Cut, deliberately

The value proposition carousel, and its relatives: coach marks, spotlight
overlays, a quick tour button. It is the purest violation of the house rule on
screens, all teaching and zero figures, at the one moment the person has no
context to attach the teaching to. The app already owns the correct machine
for this, the `i` dot and the topic keyed explainer, which delivers the same
sentences at the moment somebody is looking at the figure they explain and has
actually asked. A tour is teaching pushed; an `i` dot is teaching pulled.

Also cut: any "set your budget limits" step. A limit set before any spending is
logged is a number pulled from the air, and the first week of data will
contradict it, which teaches the person the app's numbers are soft.

Also not asked: name, currency, categories, goals, app lock. Each is a question
whose answer changes nothing in the first session.

## Ranked by expected impact

1. Removing demo data from the real-money path, including the seeded payday.
   Protects the only asset the app has and removes a documented wrong-number
   class.
2. The post-first-entry log reminder with the permission ask attached. The
   single lever on second-session rate.
3. One account plus balance as the only typed ask. Decides whether the first
   session produces any real data at all.
4. Payday asked at first income rather than at install. Decides whether the
   payday window features ever get a chance to fire.
5. Cutting the carousel. Pure time returned, no downside.

## Founder decisions, because these are gated

**1. Does the demo survive a fresh install?** Under this design it survives
only for somebody who asks for it. Today it is unavoidable. This is the
biggest behavioural change in the proposal and it is a product fork, so it is
the founder's call rather than mine.

**2. One new saved field.** The app has to remember that it has introduced
itself and which path was chosen, or the welcome returns on every launch. One
nullable string beside the existing `sampleDataRemovedAt` in the snapshot's
top level keys. Additive and nullable, so an old backup loads unchanged and
reads as "never onboarded", which is the correct answer for a file written
before this existed. Stored data is founder-gated under STOP condition 2.

## Honest uncertainty

The panel's unanimity on "empty is better" is stated preference from a
simulation, not behaviour from real strangers, and stated preference gets this
exact question wrong routinely. Plan C is recommended partly because it does
not require that bet to be won. If the founder ever wants the question settled
properly it needs moderated sessions with real first-run users, counting how
many add a real entry before noticing the money is not theirs.

## Not designed here

Privacy policy text, Play data safety answers, app lock and backup and restore.
Those are the rest of the public-readiness phase and they are their own work.
