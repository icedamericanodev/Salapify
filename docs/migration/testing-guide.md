# Testing the sheets on the emulator

Written for the founder, 2026-09-18. Every expected figure below was produced
by running the app's own engines, not worked out by hand, so if your screen
disagrees with this page that is a real defect and worth telling Claude about.

## Before you start

    cd ~/Documents/Codex/Salapify
    git pull origin claude/flutter-final

dev-sync restarts the app by itself. If it does not, press `R` (capital R, a
full restart) in the terminal running the app.

One thing to know before you type anything: **nothing you enter is saved yet.**
There is no storage in the app at all so far. Add a debt and it shows up
immediately, then disappears when the app is closed and reopened. That is
expected, not a bug, and the app says so when you save. Local storage arrives
with the Activity tab.

Every figure below assumes today is Sep 18. Anything that counts days to
payday moves with the real date, so a day or two of drift there is fine.

---

## 1. The Philippine Toolkit

**Tap:** the sparkle icon, top left of the five round buttons under the date.

**Expect:** a sheet slides up from the bottom titled "Philippine Toolkit",
covering most of the screen, with Home dimmed behind it. Three rows:

| Row | Tapping it opens |
|---|---|
| Tax Calculator | The tax sheet, section 4 below |
| Business Tax Simulator | The business sheet, section 5 |
| Categories | The category list, section 6 |

Tapping one **closes the toolkit** and opens that tool. That is deliberate, so
you do not end up with sheets stacked on sheets.

**Close it** with the X at the top right, or swipe down, or tap the dimmed
Home behind it.

---

## 2. Safe to Spend, and how to reach Audit & Math

**Tap:** the word **DETAILS** on the big orange card. (The small circled `i`
next to "SAFE TO SPEND" opens the same sheet. Both go to the same place on
purpose: the explanation *is* the breakdown.)

**Expect:** a sheet titled "Safe to Spend Details". Under the title there is a
sentence explaining the current scenario and a two-way toggle,
**Conservative | Optimistic**.

Below that toggle is a **row of three tab names**:

    Outputs & Runway     Income Streams     Audit & Math

**Audit & Math is the third one, at the right end of that row. Tap the words
themselves.** The selected tab is orange with an orange underline. If the row
is cut off on your screen, drag it sideways with one finger, it scrolls.

### What each tab should show

**Outputs & Runway** (opens first): four cards in a 2x2 grid, then Cash Runway,
then "What is being held back".

| Card | Expect roughly |
|---|---|
| Safe to Spend Today | ₱9,604.00 |
| Until Next Payday | ₱38,414.00 |
| Safe to Save | ₱6,779.00 |
| Must Remain Reserved | ₱65,528.00 |

"What is being held back" adds up to the same ₱65,528.00 as the Must Remain
Reserved card. **Check that those two agree.** If they ever disagree, that is
the single most important bug you can find in this sheet.

**Income Streams**: one row per income source, each saying what it is worth and,
in the conservative scenario, how much was trimmed off it for not being
guaranteed.

**Audit & Math**: eight numbered steps, in order, from your total cash down to
the final Safe to Spend figure. This is the tab that answers "where did
₱38,414 come from". Read it top to bottom; step 8 should land on the same
number as the big orange card on Home.

### Worth trying while you are here

Tap **Optimistic** on the toggle. The figures do NOT all move the same way, and
that is the point of the scenario:

| Card | Conservative | Optimistic |
|---|---|---|
| Safe to Spend Today | ₱9,604.00 | ₱12,752.00 |
| Until Next Payday | ₱38,414.00 | ₱51,007.00 |
| Safe to Save | ₱6,779.00 | ₱9,001.00 |
| Must Remain Reserved | ₱65,528.00 | **₱50,712.00**, it falls |
| Cash Runway | 256 days | 256 days, unchanged |

The three spending figures rise because optimistic counts income that
conservative discounts. Reserved **falls** for the same reason. Runway does not
move at all, because it measures cash against spending and neither changed.

Tap back to Conservative and the first column should return exactly.

---

## 3. Add a debt, and how to see the payoff schedule

**Tap:** the **Debt** button in the row of four round buttons (Log, Debt,
Bills, Move), under the Budget Pulse card.

**Expect:** a sheet titled "Add a debt".

Do this in order:

1. **Which way does it go** is a toggle: `I owe them | They owe me`. Leave it on
   **I owe them**.
2. **Who you owe**: type `Home Credit`.
3. **Amount**: type `85000`.
   - As soon as there is an amount, a strip appears near the bottom saying
     **"₱85,000.00 will be added to what you owe."**
   - The **Save debt** button at the bottom turns orange. Before this it is grey
     and does nothing, on purpose: a debt with no name or no amount can never be
     matched to anything later.
4. **How it gets paid** is a second toggle: `Flexible | Installments`.
   **Tap Installments.** This is the step you were missing.
5. Two new fields appear side by side: **Number of months** (pre-filled `6`) and
   **Interest % a year** (pre-filled `0`).
6. The **payoff schedule appears underneath them, immediately**, and updates as
   you type.

### Expected figures, exactly

With `85000`, `6` months, `0` interest:

| Where | Expect |
|---|---|
| Monthly payment | ₱14,166.67 |
| Total interest | ₱0.00 |
| Rows in the schedule | 6 |
| Row 1 | Interest ₱0 - Principal ₱14,167 - ₱14,167 |
| Row 1 "Balance after" | ₱70,833 |
| Row 6 "Balance after" | ₱0 |

The thin bar under each row is the split between interest and principal. At 0%
interest it should be **entirely green**, with no red at all. (It used to draw a
red sliver here even at 0%, which was a small lie the screenshots caught.)

Now change **Interest % a year** to `12` and watch it recompute:

| Where | Expect |
|---|---|
| Monthly payment | ₱14,666.61 |
| Total interest | ₱2,999.67 |
| Row 1 | Interest ₱850 - Principal ₱13,817 |
| Row 1 "Balance after" | ₱71,183 |
| Row 6 "Balance after" | ₱0 |

Each row's bar should now show a red portion that **shrinks** as you go down the
list, because early payments are mostly interest and later ones mostly
principal. That shrinking is the whole point of showing the bar.

One more worth trying, because it is where a table gets unwieldy: amount
`250000`, `24` months, `8` interest. Monthly ₱11,306.82, total interest
₱21,363.75. The schedule shows the **first 12 rows only**, with a control to
expand to all 24, so a two year loan does not bury the Note field.

### Then actually save it

Tap **Save debt**. Expect:

- The sheet closes.
- A message appears at the bottom: *"Added. Debts are not saved to the phone
  yet, so this clears when the app is closed."*
- Scroll down Home to the **Debts (Both ways)** card. **"You owe" should have
  gone up by exactly ₱85,000.** It reads ₱17,350.00 before you start, so expect
  **₱102,350.00** after.

That last check is the one that matters most. The money moving in the app's
memory and the money shown on the card are two different things, and a payment
that was correct in one and invisible in the other is exactly the bug that got
through on the old app.

---

## 4. Tax Calculator

**Reach it:** sparkle icon, then "Tax Calculator".

Three tabs: **Take-home Pay | 13th Month | Freelance**, tapped the same way as
the Safe to Spend tabs.

**Take-home Pay** opens pre-filled with ₱32,500 paid on the 15th and 30th.

| Where | Expect |
|---|---|
| Take home | ₱54,252.00 |
| Per cutoff | ₱27,126.00 |
| Gross monthly | ₱65,000.00 |
| SSS | ₱1,350.00 |
| PhilHealth | ₱1,625.00 |
| Pag-IBIG | ₱200.00 |
| Withholding tax | ₱7,573.33 |

The salary field says **"per payout"** because ₱32,500 twice a month is the
₱65,000 gross. Tap **Monthly** on the frequency bar without changing the
number, and the whole screen should recompute: gross monthly ₱32,500 and take
home **₱28,741.00**. Same salary figure typed, half the actual pay, so every
deduction shrinks.

**13th Month**: enter a basic salary and months worked. Under ₱90,000 the
result should say it is completely tax free; above it, only the excess is taxed.

**Freelance**: enter a yearly gross and the sheet names which option is cheaper
for you, the 8% flat rate or the graduated table. It should say which, not make
you compare two numbers yourself.

---

## 5. Business Tax Simulator

**Reach it:** sparkle icon, then "Business Tax Simulator".

Pre-filled with ₱3,000,000 revenue, ₱1,200,000 cost of goods, ₱600,000
operating expenses, sole proprietor, non-VAT.

Expect a green banner saying the selected regime is the cheapest, then all four
side by side:

| Regime | Expect |
|---|---|
| 8% flat | ₱220,000, badged CHEAPEST |
| OSD 40% | ₱442,500 |
| Itemized | ₱270,000 |
| RCIT | ₱270,000 |

Now tap **Partnership** on the Business type toggle. Every figure changes, and
not all in the same direction:

| Regime | Sole proprietor | Partnership |
|---|---|---|
| 8% flat | ₱220,000 | **₱240,000** |
| OSD 40% | ₱442,500 | ₱306,000 |
| Itemized | ₱270,000 | ₱312,000 |
| RCIT | ₱270,000 | ₱312,000 |

8% still wins, but it costs ₱20,000 more, because the ₱250,000 personal
exemption is a sole proprietor's and a partnership does not get it. OSD gets
dramatically cheaper. If your screen shows 8% simply disappearing for a
partnership, that is a bug, it should still be listed and still be cheapest.

Then set the regime to **Itemized** and tap **VAT registered**. The figure
should fall from ₱270,000 to **₱202,500**, because the ₱90,000 percentage tax
drops away. Do the same on the 8% regime and **nothing changes**, because the
8% rate already replaced that percentage tax. Both are deliberate: the app
treats VAT as money you collect and pass on rather than a cost of your own.
That is a cash flow view, not your BIR filing figure.

---

## 6. Categories

**Reach it:** sparkle icon, then "Categories".

Expect 18 categories. Try:

- Typing in the search box, e.g. `gro`, and watching the list narrow.
- The filter bar: `All | Spending | Income | Both`.
- Tapping the chevron `v` on the right of a row to open it. The
  sub-categories appear, and a delete control sits at the bottom of the opened
  panel.
- That delete control is **always there**, which is the interesting part. On a
  category nothing is tagged with, it is red and says "Delete this category".
  On one that is in use, it is grey with a padlock and a sentence naming the
  count, and it is not tappable.

  Three worth opening, because they should each look different:

  | Category | Expect |
  |---|---|
  | Food & Dining | Locked. *"2 entries are tagged with this, so deleting it would leave them with no category."* |
  | Groceries | Locked, and the sentence reads **"One entry"**, not "1 entries" |
  | Housing & Rent | Red and live, "Delete this category" |

  A hidden button would leave you wondering where the option went. A button
  that explains itself answers the question in place.

---

## 7. Logging an entry, one line and a date

**Reach it:** the orange **Log** pill at the far right of the tab bar, or the
Log quick action on Home. Both open the same sheet.

### Type it in one line

The box at the top of the sheet. Type a line, then tap **Fill the form with
this**. Every row below is what the parser really returns, printed by running
it, so a difference on your screen is a defect worth reporting.

| Type this | Expect the form to fill with |
|---|---|
| `Jollibee 500 gcash` | Spent, ₱500, Where "Jollibee", GCash Wallet, Food & Dining |
| `grab 420` | Spent, ₱420, Where "Grab", Transport & Commute, account unchanged |
| `Puregold 1250` | Spent, ₱1250, Where "Puregold", Groceries |
| `sweldo 25000` | **Received**, ₱25000, Salary & Compensation |
| `padala kay nanay 8000 palawan` | Spent, ₱8000, Family Support & Remittance, and Nanay in the person field under "Add a person, tags or a note" |
| `lipat 1000 maya` | **Moved**, ₱1000, destination Maya Savings |

### When it does not know the word

Your "Electricity" finding, fixed on 2026-09-18. Try these:

| Type this | Expect |
|---|---|
| `Electricity 1500` | Bills & Utilities. It knows the plain English word now, not just `meralco` and `kuryente`. |
| `Pharmacy 340` | Health & Medical |
| `Groceries 2200` | Groceries, not Food & Dining. The plural was missing while the singular worked. |
| `Mortgage 18000` | Housing & Rent |
| `Xylophone lessons 1500` | **"category not recognized, so pick one below"** and the category picker does not move |

That last row is the important one. Before the fix, an unknown word did not
produce "I do not know", it produced **Food & Dining** with full confidence,
because that is the parser's fallback. Worth testing directly: pick a category
by hand first, say Transport & Commute, then type an unknown line and fill it.
Your choice should survive.

Seven words are deliberately still unrecognized, because they genuinely cannot
be read without context: `bill`, `payment`, `credit`, `phone`, `power`, `game`,
`refund`. A restaurant bill and an electricity bill are both "the bill". If one
of those matters to you in practice, say so and we will decide where it goes
rather than guessing.

Two deliberate details worth poking at:

- It **fills the form, it does not save**. Nothing moves until you tap Save
  entry, and everything it guessed is sitting in a control you can correct.
- A line with **no amount**, e.g. `Jollibee`, offers nothing at all. The Fill
  button does not appear. A parser that guesses an amount is worse than one
  that admits it does not know.
- On `padala kay nanay 8000 palawan` the Where box reads "Padala Kay Nanay
  Palawan", which looks untidy and is deliberate: it is exactly what the
  prototype produces, and the ported parser is locked to the prototype's own
  output. If you want it changed, that is a change to both.

### The date

Scroll to the **When** row. It reads **Today** with the date under it.

1. Tap **Change**. The calendar opens on today, circled in orange.
2. Everything **after** today is greyed out and will not accept a tap. That is
   on purpose: saving moves the balance immediately, so a future dated expense
   would take the money out today and file the entry under a day that has not
   happened yet, and the account and the ledger would disagree until it
   arrived. The prototype allows it; this is the one place they differ.
3. Pick a day a few back, say the 15th, and tap OK.
4. The When row turns orange and shows that day.
5. The confirmation at the bottom gains a second sentence: *"The balance
   changes now, even though the entry is dated earlier."* That is the honest
   version of what backdating does.
6. Save it. You land on Activity, and the confirmation says **"Logged under
   Tue, Sep 15, further down the list."** Scroll down and the entry is there,
   under that day's heading, not at the top.

Step 6 is the one to watch. Without that sentence you land on a list whose
first rows are today's, which reads exactly like the save failed.

---

## 8. Reports, the third tab

**Reach it:** the **Reports** icon in the bottom bar, third from the left.

It opens on **Position** and has three sub-tabs across the top. Every figure
below was produced by running the app's own engine, so a difference on your
screen is a real defect.

### Position, what you own and what you owe

| Expect | Figure |
|---|---|
| Net worth | **-₱217,229.50**, in red, with a visible minus sign |
| Assets | ₱181,970.50 across 8 accounts |
| Liabilities | ₱399,200.00 across 3 accounts |
| Cash and e-wallets | ₱110,720.50 |
| Investments | ₱65,000.00 |
| Owed to you | ₱6,250.00 |
| Credit cards | ₱4,200.00 |
| Loans and mortgage | ₱395,000.00 |

The minus sign matters. Check it is actually there, not just the red colour.
For most of building this screen it was missing, and a debt of 217,229.50
looked character for character like savings of 217,229.50.

Note there is **no period picker** on this tab, on purpose. A balance sheet is
what you hold right now.

### Performance, what came in and went out

Tap **Performance**. The six period pills should sit in **two tidy rows**, not
six stacked full-width bars. Leave it on **This month**.

| Expect | Figure |
|---|---|
| Money in | ₱51,000.00 |
| Money out | ₱24,274.75 |
| You kept | ₱26,725.25, and "52.4% of what came in" |
| Savings rate | 52.4% |
| Debt servicing | 9.7% |
| Business net profit | ₱15,351.00 |
| Income by month end | ₱85,000.00 |

Then scroll to **Where it went**. Nine categories, biggest first, starting with
Family Support & Remittance at ₱6,000.00 (24.7%). Debt & Loan Servicing is
second with two entries listed underneath it.

Now tap **Today**. Everything should change: one entry, ₱180.00 out, no income.
If the figures do not move, the period picker is not working.

### Cash flow, the same money sorted three ways

Tap **Cash flow**.

| Section | Expect |
|---|---|
| Net change in cash | ₱26,725.25 |
| Operating net | ₱31,675.25 |
| Investing net | ₱0.00, in grey, with "Nothing of this kind in this period" |
| Financing net | **-₱4,950.00**, with the minus sign |
| Your own transfers | 1 transfer, ₱5,000.00 |

The transfer line is worth reading. ₱5,000 moved and the total did not change,
because moving your own money between your own accounts is not money entering
or leaving. The screen says so rather than leaving you to wonder.

The three section nets add up to the headline: 31,675.25 + 0 + (-4,950) =
26,725.25.

### What is deliberately missing

At the bottom of every sub-tab there is a card reading **"Reconciliation comes
next"**. The prototype has a fourth tab there. It is the only one that changes
your data (it creates an adjustment entry to force the app to agree with your
real bank balance), so it lands as its own step with its own tests. Say if you
want it sooner.

---

## What to tell Claude afterwards

Most useful, in order:

1. Any figure on your screen that does not match this page.
2. Anything cut off, overlapping, or too small to tap comfortably.
3. Anything you had to think about before you knew what to tap. That one is a
   design problem even when nothing is broken.
4. Screenshots beat descriptions.

Cheapest to change now, while these are still new screens rather than
foundations other screens sit on.
