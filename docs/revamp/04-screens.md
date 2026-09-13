# 04. Screens

Read 03-design-system.md first: the hero panel, the sweldo rail, the debt
beam, the section head, the group, the row and the settled row are the whole
vocabulary, and no screen adds a device of its own. Home is rendered in
mockups/hapon/, light and dark, at three transactions and at fourteen. Every
other screen here is words waiting for a render.

One naming note, unresolved: the Home render labels the fourth tab "Wallets"
and this document says "Accounts". Both readings are defensible and it is a
one-word change either way. Founder to pick under D3; the docs use Accounts
until then.

## Information architecture

Four tabs and a Log button at the right end of the bar:

    [ Home ]  [ Ledger ]  [ Plan ]  [ Accounts ]   ( + Log )

- Home answers "am I okay" and puts debt and what is coming right under
  the one number.
- Ledger is every transaction, grouped by day, searchable. (Named Ledger,
  not Activity or History, on purpose: it is the app's word.)
- Log is a sheet, not a tab. It opens over any screen from the accent pill
  at the right end of the bar, and from the first quick action on Home.
- Plan holds Budget, Upcoming and Goals as three segments in one screen.
- Accounts holds every account with net worth on top, and the debt
  totals as a section.

Debt has its own screen, reached from the Debt section on Home and from
Accounts. Whether it deserves a tab of its own is decision D11; the
recommendation is section-plus-screen for the first two weeks, then decide
from use.

Everything else (Insights, Settings, details, editors) is pushed over the
shell.

## The hero panel and the sweldo rail

The rail is not a separate tile. It lives INSIDE the hero panel, under the
amount, and that is the change the built design made: the rail and the number
it constrains are one object rather than two stacked ones.

The panel is the light gradient block with dark ink. It carries the kicker
("SAFE TO SPEND"), the amount, one sentence, the rail, and the two end labels
("4 days to payday" on the left, "Sep 1 to 15" on the right). The rail track
is 5 dp, filled to today in the quiet ink. The payday setting drives it. Plan
gets the same panel with its own number. Ledger gets it too unless the
two-week test says it is noise there.

## Home

This screen is rendered. Look at mockups/hapon/ before changing anything
here.

First viewport, no scroll:

1. The date and a notifications bell, quiet, one line.
2. The hero panel: "SAFE TO SPEND", ₱6,240.00 in the measured hero size, then
   one sentence, "₱1,560 a day until payday on Monday." One phrasing, not
   three. Then the rail and its two end labels.
3. Four quick actions in one row, disc and label: Log, Debt, Bills, Move.
   Four is the ceiling and it is never a grid. That is the GCash convention
   with the GCash mistake removed.
4. Section head "Debt, both ways" with "See all", then the debt beam card:
   "Owed to you" in green on the left, "You owe" in the accent on the right,
   the split bar under them, and the next payment as one line ("Home Credit,
   next Sep 18" with its amount).
5. Section head "Coming up" with "See all", then a card of rows with a date
   caption: Meralco today, Spotify Sunday, Payday Monday with a plus sign in
   green. "See all" opens Plan > Upcoming.

Below the fold:

6. Section head "Latest", the recent transactions as rows in one card, each
   with a caption of category and account. Ordinary amounts sit bare in text
   colour; only money coming in is green. "See all" opens Ledger.
7. One insight sentence with a number, no card. Tap for Insights.

No net worth on Home. Two of three panel users read a big net worth as
"somebody else's phone". It lives on Accounts.

The Latest list is the reason the dense render exists. At three rows any
design looks calm. At fourteen the hairlines, the single icon tint and the
uncoloured amounts are what keep it calm, and all three were added only after
the dense fixture showed the screen without them.

## Log sheet

A white sheet glides up in 250 ms over the dimmed screen, card radius on
its top corners, drag handle, "Log" title with Cancel. From top:

1. Fast-log field, focused, keyboard up: "jollibee 250" or "salary 42000"
   or "paid mom 2000". The parser fills type, amount, label and a
   suggested category live under the field, in one line: "Got it: Expense
   · ₱250.00 · Jollibee · Food", the parsed parts in accent.
2. Type segmented: Expense, Income, Transfer.
3. The amount, centred, in the hero size.
4. Category chips, most used first, one tap. Required for expenses. The
   selected chip is the accent with its own text colour on it.
5. Account chips (defaults to last used).
6. Date (defaults to today) and an optional note, side by side.
7. Save entry, the accent pill button. Toast with
   Undo. Haptic. The sheet closes and the new row appears in Latest with a
   250 ms insert.

Edit is the same sheet, prefilled. There is exactly one form.

## Ledger

- Title row, with a month or cycle switcher (swipe or arrows), then the
  rail.
- Totals line in body: "In ₱42,000.00 · Out ₱18,450.00".
- Search field and filter chips (type, account, category).
- A section label per day ("Thu, Sep 11" with the day total on the right),
  then rows. Swipe left to delete with Undo, tap to edit.

## Plan

Title "Plan" with "+ Recurring", then segmented: Budget · Upcoming · Goals,
then a compact rail.

Budget:
- Hero: "Left to spend this cycle", one sentence with days left and how
  many categories need a look.
- One row per category: emoji and name on the left, remaining on the
  right ("₱1,250.00 left"), a ThinBar under the label. Under 25 percent
  left turns the bar accent; over budget shows the caption "over by
  ₱320.00" in bad with a bad bar; fully set aside says "set aside" in green.
- Tap a row to change its limit.
- Under the list, one small bar chart, "Spent so far, last six cycles",
  the current cycle's bar in the accent, and a sentence with a number under it.

Upcoming:
- Rows from today to the payday after next, with date captions; payday
  rows with their amount in green and "about ₱12,400.00 carries over" in the
  caption. This is the Sweldo Timeline as a list, the rail as a drawing.
- Add a recurring item from the top-right action.

Goals:
- One row per goal: name, saved of target on the right, ThinBar under the
  label, caption "₱X a month to make it by <date>". A reached goal clears
  like a settled debt.

## Accounts

- Title "Accounts" with "+ Add".
- Hero: Net worth, sentence "Assets ₱164,300.00 · Debts ₱12,000.00".
- Section labels per kind: Cash and e-wallets, Bank, Credit. Rows with
  the institution monogram as the only decoration (the monogram system
  from the old app is kept, it is trademark-safe and earned). Credit rows
  show utilisation as a ThinBar with "10% of ₱40,000.00 limit · due Oct 3"
  in the caption.
- Section head "Debt" with "Open", two rows: "You owe" in the accent
  and "Owed to you" in green, tap for the Debt screen.
- Add account from the top-right action. Tap a row for its detail.

## Debt

- Title "Debt" with "+ Add", one line under it: "Both ways: what you owe,
  and what is owed to you."
- The debt beam card.
- Segmented: I owe · Owed to me.
- Section "Open": rows per person or lender: monogram, name, the amount
  due in the accent when a payment is within seven days, caption with
  what is left, "3 of 6" and the next date, a ThinBar for scheduled ones.
  A debt with no schedule shows its amount bare and "pay when you can".
  Tap for detail: payment history, schedule, edit, mark settled.
- Section "Settled": settled rows tinted green with the name struck
  through, "Settled Sep 3, all paid" in green, and a check.
- Two buttons at the bottom: "Pay <next due>" (primary) and "Record a
  payment" (secondary).
- Settling one turns the row fully green, holds 1.2 s, then it slides
  down into Settled. This is the one moment the app celebrates.

## Insights

Three to five charts, each drawn in border, positive and accent under one
grammar, each with a sentence under it that contains a number. No cards; a
section label per chart. Candidates for launch:

1. Spending by category this cycle (horizontal bars).
2. In versus out, last six cycles (paired bars).
3. Net worth, last twelve months (line).
4. Daily spending this cycle against the safe-to-spend line.

## Settings

Plain list without amounts: Appearance (Light, Dark, System), Payday cycle,
Categories, Recurring, Backup and restore, App lock, Notifications, Privacy
receipt, Diagnostics, About.

## Onboarding

Three pages at most, and the first offers "Restore a backup":

1. Welcome, one sentence, two buttons: Start fresh (primary), Restore a
   backup (secondary).
2. First account and its balance.
3. Payday cycle (15th and 30th, monthly, weekly). The rail appears here
   for the first time, filled to today.

Then Home, with an empty ledger that says one sentence and points at the
Log button.
