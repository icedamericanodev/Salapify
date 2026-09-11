# 01. Vision

## Who it is for

Salapify 3 is built for one user first: the founder. A working adult in the
Philippines who gets paid on a sweldo cycle, holds cash, a bank account, an
e-wallet and a credit card, has money owed in both directions, and wants to
open one app every day and know in five seconds whether they are fine.

Other users come later, and only once the founder has used it daily for a
month and still likes it. That ordering is the whole strategy: an app the
maker uses is honest in a way a roadmap cannot be. Tarsi grew the same way,
one developer fixing their own frustration, then word of mouth.

## The daily question

Every screen exists to answer one of five questions, and Home answers the
first one before the user scrolls:

1. Am I okay right now? (safe to spend until payday)
2. What do I own and owe? (net worth, accounts, utang both ways)
3. What happened? (activity, searchable)
4. What is coming? (bills, subscriptions, payday, due dates)
5. Where does it go? (budget and a few insights that state a conclusion)

A feature that does not serve one of these does not go in. That is Tarsi's
rule, and it is the right one: every feature must justify its complexity,
and if it slows down logging or adds confusion it stays out.

## Principles

1. Logging is the heartbeat. From any screen, one tap opens Log, and a
   typed line like "jollibee 250" is a saved expense with a category. Under
   three seconds from thumb to saved, measured, every release.
2. One screen, one decision. The first viewport of every screen carries one
   number that matters and one action. Everything else is below the fold or
   behind a tap.
3. One design hand. One accent colour, one type family, one card shape, one
   list physics. If two screens show a peso amount differently, that is a
   bug.
4. Dark first. The founder uses dark. Design every screen in dark, then
   derive light. Both ship, dark is the reference.
5. Calm by default, alive at moments. No ambient animation, no confetti for
   ordinary saves. Numbers roll when they change, sheets glide, a cleared
   debt gets one earned celebration.
6. Every chart states its own conclusion in a sentence with a number. A
   chart the user has to interpret is decoration.
7. Offline, private, no account. Unchanged from today and not negotiable.
8. Filipino by substance, English by copy. Payday cycles, utang both ways,
   13th month, e-wallets and bank names are first class. Sentences read in
   plain English; Filipino words appear as identity, with an English gloss
   beside them.
9. Small and finished beats large and half. Salapify 3 ships with fewer
   features than the app it replaces, every one of them polished.

## What is cut from the current app

Cut means not in Salapify 3 at launch, not deleted from history. Each item
can come back only if the founder misses it while using v3 daily. The
current app's code stays in git as reference for any that return.

| Cut | Why |
|---|---|
| Money Courses and lessons, Financial guides, Learn tab | A content product inside a tracker. Large, rarely opened daily, and the maintenance (source verification) is heavier than the whole rest of the app. |
| Money Mindset (decision score, what-if spectrum, waiting room, subscriptions compare, credit path) | Twenty-seven review reports of features stacked on a feature. Interesting, not daily. |
| Pan the mascot and the Pan chat | A second brand voice. The parsing behind Pan is kept (it powers the fast log field); the character and the chat screen are not. |
| Calculators as separate screens (tax, salary, 13th month, loan, BNPL, contribution, currency, year-end tax, tax deadlines) | Nine tools with nine screens. One or two may return as a single Tools sheet once the core is loved. |
| Treats, wins, milestones, recap share, milestone share, week chain | Gamification layered on before the core felt good. |
| Paluwagan, split expense, notes, CSV import, card skin studio, flip bank card | Each is a screen or two the founder does not open daily. CSV import may return under Settings. |
| Four colour themes and the appearance studio | One signature look in dark and light. Themes are a feature for other people, later. |
| Reports PDF statement, debt statement PDF | Later, under an account or debt's overflow menu, if wanted. |

## What is kept, and made much better

| Kept | The v3 version |
|---|---|
| Log sheet | A fast-log field on top (typed line or amount), category chips, account, date, note. One form language shared with Edit. |
| Home (Overview) | Safe to spend until payday, net worth, upcoming this week, utang summary. Four blocks, no scroll needed for the first two. |
| Accounts | All accounts on one screen with net worth on top. Cash, bank, e-wallet, credit. Bank cards stay (they are already good). |
| Activity (History) | One list physics, grouped by day, search, filter, swipe to edit or delete. |
| Budget | Monthly, per category, with remaining not just spent. Safe to spend is derived from it. |
| Cash flow and the Sweldo Timeline | Becomes Upcoming: bills, subscriptions, due dates, payday, on one timeline. |
| Utang and Debts | One place for both directions: I owe, owed to me. Payoff progress, next due, pay action. |
| Insights | Three to five charts, each with a caption sentence. No wall of cards. |
| Goals | Simple: target, saved so far, monthly needed. |
| Recurring | Lives inside Upcoming, not a separate destination. |
| Backup, restore, app lock, privacy receipt, diagnostics | Settings. Unchanged behaviour, new skin. |
| Home screen widget | Kept as is (native code, already shipped). |

## What success looks like

- The founder opens Salapify 3 every day for thirty days without going back
  to the old app.
- Logging a transaction takes under three seconds, measured with a stopwatch.
- Every core screen is rendered, looked at in dark and light, and approved
  by the founder before it is called done.
- A stranger shown Salapify 3 beside Tarsi cannot tell which one had a
  design team.
