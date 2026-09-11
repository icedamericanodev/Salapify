# 04. Screens

## Information architecture

Four tabs and a Log button:

    [ Home ]  [ Activity ]  ( Log )  [ Plan ]  [ Accounts ]

- Home answers "am I okay" and summarises the rest.
- Activity is every transaction, searchable.
- Log is a sheet, not a tab. It opens over any screen.
- Plan holds Budget, Upcoming and Goals as three segments in one screen.
- Accounts holds every account, with net worth on top, and Utang as a
  section that opens its own screen.

Everything else (Insights, Settings, details, editors) is pushed over the
shell. Utang reachable from Home and Accounts; Insights reachable from Home
and from the Activity month header. This is a founder decision (see
07-decisions.md) because the current app made Utang a tab and later a
pushed screen; the recommendation is the section-plus-screen shape above.

## Home

First viewport, no scroll:

1. Greeting line, small: the date and "payday in 9 days".
2. HeroCard: **Safe to spend** as the display amount, one sentence under it
   ("₱1,240 a day until the 30th, after bills"). This is the one number.
3. Two half-width cards: Net worth (hero amount, sparkline of 30 days) and
   Spent this month (amount, thin bar against budget).

Below the fold:

4. Upcoming: the next three bills or due dates as MoneyRows, "See all" to
   Plan > Upcoming.
5. Utang: "You owe ₱X · Owed to you ₱Y", one row each for the nearest due.
6. Recent: the last five transactions, "See all" to Activity.
7. A single Insight card: one sentence with a number ("Food is 38% of
   spending this month, up from 29%"), tap to Insights.

No mascot, no tips, no courses, no wins.

## Log sheet

Opens from the centre button in 250 ms. From top:

1. Fast-log field, focused, keyboard up: "jollibee 250" or "salary 42000"
   or "paid mom 2000". The parser (kept from Pan) fills type, amount,
   label and a suggested category live under the field.
2. Type segmented: Expense, Income, Transfer.
3. Amount field (prefilled by the parser, editable, numeric pad).
4. Category chips, most used first, horizontal scroll, one tap. Required
   for expenses.
5. Account chip row (defaults to the last used).
6. Date (defaults to today, tap to change) and an optional note.
7. Save. Toast with Undo. Haptic. Sheet closes.

Edit uses the same sheet with the same fields prefilled. There is exactly
one form.

## Activity

- Month header with the month's in and out totals, swipe or arrows to
  change month, tap the totals for Insights.
- Search field and filter chips (type, account, category).
- Transactions grouped by day, MoneyRows, day subtotal on the right of the
  day label.
- Swipe left to delete (with Undo), tap to open the edit sheet.

## Plan

Segmented at the top: Budget · Upcoming · Goals.

Budget:
- HeroCard: Left to spend this month, sentence with days left.
- One MoneyRow per category: emoji, name, spent of limit, thin ProgressBar,
  remaining on the right. Over budget rows use negative for the remaining
  number only.
- Set or change a limit by tapping the row.

Upcoming (the Sweldo Timeline, simplified):
- A vertical timeline from today to the payday after next: bills,
  subscriptions, debt due dates, and payday markers, each a MoneyRow with
  the date as caption.
- Running balance shown at each payday marker ("₱12,400 after these").
- Add a recurring item from the top-right action.

Goals:
- One Card per goal: name, saved of target, ProgressBar, "₱X a month to
  make it by <date>".
- Add money to a goal from the card.

## Accounts

- HeroCard: Net worth (hero amount), sentence "Assets ₱X · Debts ₱Y",
  30-day sparkline.
- Sections: Cash, Bank, E-wallet, Credit. Each account is a MoneyRow, or
  the existing bank card for bank and credit accounts (those are kept, they
  are already good). Credit cards show utilisation as a thin bar.
- Utang section: "I owe" total and "Owed to me" total on one Card, tap to
  the Utang screen.
- Add account from the top-right action. Tap an account for its detail
  (balance history, its transactions, edit, archive).

## Utang

- Segmented: I owe · Owed to me.
- Each item a Card: person or lender, remaining of original, next due,
  ProgressBar, one Pay or Record button.
- Detail screen: payment history, schedule, edit, mark settled. Clearing
  one is the earned celebration.

## Insights

Three to five charts, each a Card with a caption sentence that contains a
number. Candidates for launch:

1. Spending by category this month (breakdown bar, not a donut; the
   caption names the top category and its share).
2. In versus out, last six months (paired bars, caption names the best and
   worst month).
3. Net worth, last twelve months (line, caption names the change).
4. Daily spending this month against the safe-to-spend line.

No card without a sentence. No more than five cards.

## Settings

Plain list: Appearance (Dark, Light, System), Payday cycle, Categories,
Recurring, Backup and restore, App lock, Notifications, Privacy receipt,
Diagnostics, About. Same behaviours as today under the new skin.

## Onboarding

Three screens at most, and the first one offers "Restore a backup" for the
founder:

1. Welcome, one sentence, two buttons: Start fresh, Restore a backup.
2. First account and its balance.
3. Payday cycle (twice a month on the 15th and 30th, monthly, weekly).

Then Home, with a sample-free empty state that points at the Log button.
