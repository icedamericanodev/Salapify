# How to test what just shipped

Written for the founder, testing by hand on an emulator. Each recipe says what
to do, what you should see, and what it would mean if you saw something else.

The last line of each one matters most. A test you cannot fail is not a test, so
every recipe names the wrong answer as well as the right one.

## Before anything: get the latest code

In the VS Code Terminal, in the `Salapify` folder (not `app`):

    git pull

Then either press `R` in the Terminal running the app, or use the sync script
below and never think about it again.

## The loop itself

    bash tools/dev-sync.sh

Starts the app and watches GitHub every fifteen seconds. When work is pushed it
pulls and restarts the app on its own. Ctrl-C stops it.

**Right:** it prints the commit messages of whatever it pulled, then the app
restarts and the change is on screen.
**Wrong:** it says "Could not fast forward". That means the local folder has
edits of its own. Nothing is lost; say so and it gets sorted out.

---

## 1. Sample data

**Do:** on a fresh install, on Home, tap **Load sample data** under the big
button.

**Right:** the app fills with three accounts, a credit card, debts in both
directions, a month of entries and three budget limits. Home shows a safe to
spend figure, Accounts shows a net worth, Plan shows a budget.

**Wrong, and worth reporting:**
- The link is missing on a genuinely empty app. It is meant to be there in
  development.
- It appears when you already have entries. It must not: it is hidden whenever
  there is anything it could overwrite.
- The dates look like last year. It should be dated around today.

**To get back to empty:** long press the app icon, App info, Storage, Clear
storage. There is deliberately no wipe button inside the app.

## 2. The parser, and what happens when it does not know a word

**Do:** tap **+ Log** and type these one at a time, watching the "Got it" line
before you save.

    jollibee 250          expense, Food
    pamasahe 45           expense, Transport
    kain 120              expense, Food
    meryenda 60           expense, Food
    sweldo 25000          INCOME, green
    250 jollibee          same as the first one, order does not matter
    zorbtronic 450        expense, NO category

**Right:** the "Got it" line names the type, the amount and the label, and the
matching category chip is already selected. On the last one no chip is selected
and the heading reads **"Category, tap one"**.

**Wrong, and worth reporting:**
- A category that is confidently WRONG. That is the expensive kind: a category
  you tap yourself costs one tap, a wrong one you never notice quietly poisons
  every budget that reads it.
- The heading says "Category, tap one" when a chip IS selected, or stays a plain
  "Category" when none is.
- The "Got it" line says one thing and the saved row in the Ledger says another.

**The point of the last line:** no word list covers how everybody writes, so the
app not knowing a word is a permanent state of the feature, not an edge of it.
Try your own words. Anything with no category is a word worth adding, but the
prompt is what has to work.

## 3. Home, and the figures on it

**Do:** with sample data loaded, read Home top to bottom.

**Right:** every figure reconciles.

    safe to spend = cash and e-wallets, minus bills due before payday
    the savings account is NOT in it, deliberately
    the rail runs from last payday to next
    the sentence under the figure names a weekday only if payday is this week

**Wrong, and worth reporting:**
- Savings counted in safe to spend. That would be the app telling you to spend
  your emergency fund.
- A weekday named for a payday more than a week out.
- "Latest" missing the entry you just logged, or showing it out of order.
- A caption under an entry that just repeats the title.

## 4. First run, which is what a stranger sees

**Do:** clear storage, reopen the app, and go through every tab without logging
anything.

**Right:** each empty screen explains what will be there and how to start. The
safe to spend hero does NOT claim a payday, because you have not set one.

**Wrong, and worth reporting:** any screen that names a place to go that does
not exist yet, any figure invented out of nothing, or any screen that just looks
broken rather than empty. One of these shipped and was caught exactly this way:
Home said "Set your payday in Plan" when nothing in the app could set a payday.

## 5. Plan, the budget

**Do:** with sample data, open **Plan**.

**Right:** the hero shows what is left of the monthly limit, and the category
rows are ordered with the one closest to its limit on top. Food reads "over by
₱50" in red, Groceries is accent with a nearly full bar, Transport is green,
and the two with no limit have no bar at all.

**Wrong, and worth reporting:** a row ordered alphabetically rather than by
urgency, a bar drawn past its own track, or an "over" row that does not say by
how much.

---

## What to send back

A screenshot beats a description, and the Terminal output beats both when
something errors. Say what you typed, what you expected, and what you got.

"This feels wrong" is a completely valid report. You are the only person seeing
this at real size in a real hand, and how it FEELS is the half no test can
reach.
