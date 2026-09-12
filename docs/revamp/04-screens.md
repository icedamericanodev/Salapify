# 04. Screens

Every screen is a page of the ledger. Read 03-design-system.md first: the
cycle header, the serif hero, section rules, ledger rows, and the stamp are
the whole vocabulary, and no screen adds a device of its own.

## Information architecture

Four tabs and a Log button:

    [ Home ]  [ Ledger ]  ( Log )  [ Plan ]  [ Accounts ]

- Home answers "am I okay" and puts utang and what is coming right under
  the one number.
- Ledger is every transaction, grouped by day, searchable. (Named Ledger,
  not Activity or History, on purpose: it is the app's word.)
- Log is a sheet, not a tab. It opens over any screen.
- Plan holds Budget, Upcoming and Goals as three segments in one screen.
- Accounts holds every account with net worth on top, and the utang
  totals as a section.

Utang has its own screen, reached from the Utang section on Home and from
Accounts. Whether it deserves a tab of its own is decision D11; the
recommendation is section-plus-screen for the first two weeks, then decide
from use.

Everything else (Insights, Settings, details, editors) is pushed over the
shell.

## The cycle header

Every main screen starts with the same header row: the cycle title in
Fraunces italic ("Sept, 2nd half") and, right-aligned in caption, "4 days
to payday". It is the app's clock. The payday setting drives it.

## Home

First viewport, no scroll:

1. Cycle header.
2. Kicker "Safe to spend", then the display hero: the terracotta peso sign
   and "6,240" in Fraunces, then one sentence in body: "about ₱1,560 a day
   until the 15th, bills already set aside." One phrasing, not three.
3. Section rule "Utang · both ways", then ledger rows: "Kuya Jun owes
   me ... 3,500", "I owe Home Credit ... 12,000" (amount in accent when the
   next payment is within seven days, with the date in the caption). The
   working parent on the panel wanted this above bills; she was right,
   because it is the section no other app has.

Below the fold:

4. Section rule "Coming up · this cycle", then ledger rows with a date
   caption: Meralco Sep 13, Spotify Sep 14, Payday Sep 15 in positive
   and bold, Home Credit Sep 20. "See all" opens Plan > Upcoming.
5. Section rule "Latest", the last five transactions as ledger rows with a
   caption of category and account. "See all" opens Ledger.
6. One insight sentence with a number, in body, no card. Tap for Insights.

No net worth on Home. Two of three panel users read a big net worth as
"somebody else's phone". It lives on Accounts.

## Log sheet

Surface-coloured paper slides up in 250 ms. From top:

1. Fast-log field, focused, keyboard up: "jollibee 250" or "salary 42000"
   or "paid mom 2000". The parser fills type, amount, label and a
   suggested category live under the field, in one line: "Got it: Expense
   · ₱250 · Jollibee · Food".
2. Type segmented: Expense, Income, Transfer.
3. The amount, large, Jakarta tabular (a sheet never uses the serif hero).
4. Category chips, most used first, one tap. Required for expenses.
5. Account chips (defaults to last used).
6. Date (defaults to today) and an optional note.
7. Save, a terracotta primary button. Toast with Undo. Haptic. The sheet
   closes and the new row appears in Latest with a 250 ms insert.

Edit is the same sheet, prefilled. There is exactly one form.

## Ledger

- Cycle header, with a month or cycle switcher (swipe or arrows).
- Totals line in body: "In ₱42,000 · Out ₱18,450".
- Search field and filter chips (type, account, category).
- A section rule per day ("Thu, Sep 11 ... 430" with the day total on the
  rule line), then ledger rows. Swipe left to delete with Undo, tap to
  edit.

## Plan

Cycle header, then segmented: Budget · Upcoming · Goals.

Budget:
- Hero: "Left to spend this cycle", one sentence with days left.
- One ledger row per category: emoji chip, name, remaining on the right,
  a ThinBar under the label. Over budget shows the remaining in negative
  and the words "over".
- Tap a row to change its limit.

Upcoming:
- Ledger rows from today to the payday after next, with date captions;
  payday rows in positive and bold with "about ₱12,400 carries over" in
  the caption. This is the Sweldo Timeline as a list, not a drawing.
- Add a recurring item from the top-right action.

Goals:
- One ledger row per goal: name, saved of target on the right, ThinBar
  under the label, caption "₱X a month to make it by <date>". The stamp
  fires when a goal is reached.

## Accounts

- Hero: Net worth, sentence "Assets ₱X · Debts ₱Y".
- Section rules per kind: Cash and e-wallets, Bank, Credit. Ledger rows
  with the institution monogram as the only decoration (the monogram
  system from the old app is kept, it is trademark-safe and earned).
  Credit rows show utilisation as a ThinBar.
- Section rule "Utang", two rows: "You owe" and "Owed to you", tap for
  the Utang screen.
- Add account from the top-right action. Tap a row for its detail.

## Utang

- Segmented: I owe · Owed to me.
- Ledger rows per person or lender: name, remaining on the right, caption
  with next due and "3 of 6". Tap for detail: payment history, schedule,
  Pay or Record button, edit, mark settled.
- Settling one strikes the row through in muted ink, fires the stamp,
  and after 1.2 s the row moves to a "Settled" section at the bottom.
  This is the one moment the app celebrates.

## Insights

Three to five charts, each drawn in ink and accent under one grammar,
each with a caption sentence that contains a number. No cards; a section
rule per chart. Candidates for launch:

1. Spending by category this cycle (horizontal bars).
2. In versus out, last six cycles (paired bars).
3. Net worth, last twelve months (line).
4. Daily spending this cycle against the safe-to-spend line.

## Settings

Plain ledger-style list without amounts: Appearance (Papel, Tinta,
System), Payday cycle, Categories, Recurring, Backup and restore, App lock,
Notifications, Privacy receipt, Diagnostics, About.

## Onboarding

Three pages at most, on paper, and the first offers "Restore a backup":

1. Welcome, one sentence, two buttons: Start fresh, Restore a backup.
2. First account and its balance.
3. Payday cycle (15th and 30th, monthly, weekly).

Then Home, with an empty ledger that says one sentence and points at the
Log button.
