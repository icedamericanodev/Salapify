# 04. Screens

Read 03-design-system.md first: the payday rail, the utang beam, the amount
pill, the hero, the section label, the row and the settled row are the
whole vocabulary, and no screen adds a device of its own. The pictures
these words describe are in mockups/ (sinag-*.png) and on page "3 Screens"
of the Figma file.

## Information architecture

Four tabs and a Log button at the right end of the bar:

    [ Home ]  [ Ledger ]  [ Plan ]  [ Accounts ]   ( + Log )

- Home answers "am I okay" and puts utang and what is coming right under
  the one number.
- Ledger is every transaction, grouped by day, searchable. (Named Ledger,
  not Activity or History, on purpose: it is the app's word.)
- Log is a sheet, not a tab. It opens over any screen from the coral pill.
- Plan holds Budget, Upcoming and Goals as three segments in one screen.
- Accounts holds every account with net worth on top, and the utang
  totals as a section.

Utang has its own screen, reached from the Utang section on Home and from
Accounts. Whether it deserves a tab of its own is decision D11; the
recommendation is section-plus-screen for the first two weeks, then decide
from use.

Everything else (Insights, Settings, details, editors) is pushed over the
shell.

## The payday rail

Home and Plan start with the rail tile: "4 days to payday" in the display
face, "Sep 1 to Sep 15" in caption, the track filled in green up to today
with a coral today dot and a small dot per bill still to come, and the two
end labels ("Sep 1, last payday" and "Payday Sep 15" in positive). It is
the app's clock. The payday setting drives it. Ledger shows it too unless
the two-week test says it is noise there.

## Home

First viewport, no scroll:

1. The payday rail.
2. Section label "Safe to spend", then the display hero: the coral peso
   sign and "6,240.00" in Bricolage, then one sentence in body: "About
   ₱1,560.00 a day until the 15th, bills already set aside." One phrasing,
   not three.
3. Section label "Utang, both ways" with "See all", then the utang beam
   tile (owed to you in green on the left, you owe in coral on the right,
   the net sentence under it), then one row per open utang: monogram,
   name, caption ("You owe · 3 of 6 · due Sep 18"), and the amount in a
   pill: coral when a payment is due within seven days, green when it is
   owed to you.
4. Section label "Coming up, this cycle" with "See all", then rows with a
   date caption: Meralco Sep 13 and Spotify Sep 14 in coral pills, Payday
   Sep 15 in a green pill with a plus sign. "See all" opens Plan >
   Upcoming.

Below the fold:

5. Section label "Latest", the last five transactions as rows with a
   caption of category, account and day. Ordinary amounts sit bare in text
   colour. "See all" opens Ledger.
6. One insight sentence with a number, in body, no card. Tap for Insights.

No net worth on Home. Two of three panel users read a big net worth as
"somebody else's phone". It lives on Accounts.

## Log sheet

A white sheet glides up in 250 ms over the dimmed screen, tile radius on
its top corners, drag handle, "Log" title with Cancel. From top:

1. Fast-log field, focused, keyboard up: "jollibee 250" or "salary 42000"
   or "paid mom 2000". The parser fills type, amount, label and a
   suggested category live under the field, in one line: "Got it: Expense
   · ₱250.00 · Jollibee · Food", the parsed parts in accent.
2. Type segmented: Expense, Income, Transfer.
3. The amount, centred, in the hero size.
4. Category chips, most used first, one tap. Required for expenses. The
   selected chip is accentSoft with an accent border.
5. Account chips (defaults to last used).
6. Date (defaults to today) and an optional note, side by side.
7. Save entry, the coral primary button with the chunky edge. Toast with
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
  left turns the bar amber; over budget shows a red pill "over by
  ₱320.00" and a red bar; fully set aside shows a green pill "set aside".
- Tap a row to change its limit.
- Under the list, one small bar chart, "Spent so far, last six cycles",
  the current cycle's bar in coral, and a sentence with a number under it.

Upcoming:
- Rows from today to the payday after next, with date captions; payday
  rows in a green pill with "about ₱12,400.00 carries over" in the
  caption. This is the Sweldo Timeline as a list, the rail as a drawing.
- Add a recurring item from the top-right action.

Goals:
- One row per goal: name, saved of target on the right, ThinBar under the
  label, caption "₱X a month to make it by <date>". A reached goal clears
  like a settled utang.

## Accounts

- Title "Accounts" with "+ Add".
- Hero: Net worth, sentence "Assets ₱164,300.00 · Debts ₱12,000.00".
- Section labels per kind: Cash and e-wallets, Bank, Credit. Rows with
  the institution monogram as the only decoration (the monogram system
  from the old app is kept, it is trademark-safe and earned). Credit rows
  show utilisation as a ThinBar with "10% of ₱40,000.00 limit · due Oct 3"
  in the caption.
- Section label "Utang" with "Open", two rows: "You owe" in a coral pill
  and "Owed to you" in a green pill, tap for the Utang screen.
- Add account from the top-right action. Tap a row for its detail.

## Utang

- Title "Utang" with "+ Add", one line under it: "Both ways: what you owe,
  and what is owed to you."
- The utang beam tile.
- Segmented: I owe · Owed to me.
- Section "Open": rows per person or lender: monogram, name, the amount
  due in a coral pill when a payment is within seven days, caption with
  what is left, "3 of 6" and the next date, a ThinBar for scheduled ones.
  A debt with no schedule shows its amount bare and "pay when you can".
  Tap for detail: payment history, schedule, edit, mark settled.
- Section "Settled": settled rows on positiveSoft with the name struck
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
