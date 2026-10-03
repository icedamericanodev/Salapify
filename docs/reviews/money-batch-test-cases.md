# Test cases for the money batch, with navigation

2026-10-03. For testing by hand on the Android emulator. Every tap below was
checked against the code, not remembered, because the first version of this
page sent the founder looking for a figure that could not be there.

## How to read a case

**EXPECT** is the pass condition. This is what you should see.

**FAILS IF** is the DEFECT. It is what would mean something is wrong, and NOT
seeing it is the point. The first version called this "WATCH FOR", which reads
as an instruction to go and find the thing, so case 5 was reported as a
failure ("cannot see the 0%") when it had passed. Not seeing a FAILS IF is a
pass.

## The two things on screen you will keep using

**The bottom bar**, on every screen: Home, Activity, Reports, Plan, Accounts,
and the orange **+ Log** button.

**The header**, at the top of Home: the Salapify logo, the **On this phone**
chip beside it, the date, then a row of four round buttons. Left to right they
are the sparkle (toolkit), the bell (reminders), the sun or moon (light and
dark), and the **gear (Settings)**. The gear is the rightmost.

---

## Before you start

Nothing here needs a fresh install.

If your emulator is empty, put the examples back first or the figures will not
match: **gear icon** at the top of Home, then **Sample data** under "Your
data".

Put the card's credit limit back to `40000` if you cleared it in an earlier
run (case 5 tells you how).

**Do case 8 LAST. It erases everything.**

---

## 0. Why this page does not quote a spending total

Written because case 1 was first reported as a failure that was not one.

The first version quoted ₱25,425.25 left to spend, copied from the golden
vectors. That is the right figure IN THE TESTS, which pin the clock to 18
September, and wrong on a real phone on almost every other day.

The sample entries are dated RELATIVE TO TODAY: one day ago, three days ago,
fourteen days ago. Budgets is a THIS MONTH limit. So on the 3rd of a month
only the last two days of examples are inside the window and most categories
correctly read zero. On the 20th nearly all of them are inside it. The figure
moves every day, by design, and no number written on this page can survive it.

So the cases below check an INVARIANT, something that cannot be false whatever
the date, or a figure that genuinely does not depend on one. An instruction
that rots is worse than none, because it sends somebody hunting for a defect
that is not there.

---

## 1. Budgets add up, whatever today is

**Navigation**

1. Tap **Plan** in the bottom bar.
2. Tap the **Budgets** tile. It is the first of seven and its small grey line
   reads "Limits by category".
3. You are on a screen headed **Budgets / Limits by category**, with a card at
   the top reading **LEFT TO SPEND THIS MONTH** and a list of categories
   under it.

**Three checks, all true on any date**

**1a. The limits never move.** Each row's small grey line ends "left of ₱X".
Across the seven rows those X figures should be ₱9,000, ₱3,500, ₱6,500,
₱8,000, ₱4,000, ₱5,000 and ₱6,000, one per category.

**1b. The parts sum to the whole.** Add up the "left of" figure from every
row. Scroll to the bottom so you catch all seven. The total must equal the
big headline figure exactly, to the centavo.

**1c. Each row is self-consistent.** For any row showing spending, the large
figure on the right plus the "left" figure must equal that row's limit
exactly. For example a row reading ₱1,899.00 with "₱2,101.00 left of ₱4,000"
is correct, because 1,899 + 2,101 = 4,000.

FAILS IF: your 1b total is a centavo or two off the headline. That is exactly
what adding money up as decimals used to risk and exactly what this change
removes, so it is the most informative failure on this page.

NOT A DEFECT: a category reading ₱0.00 with "0 entries". Its sample entries
fall in a previous month. Early in a month most of them will.

## 2. Changing a budget limit moves the row AND the headline

**Navigation**

1. **Plan**, then the **Budgets** tile.
2. **Write down the headline figure** before you touch anything.
3. Tap the **Food & Dining** row.
4. A sheet opens titled **Food & Dining**, with "Monthly limit" under it and a
   field labelled **Limit for this month**.
5. Tap the field, clear it, type `12000`.
6. Read the line under the field BEFORE saving. It should say what the new
   limit would leave you.
7. Tap **Save limit** at the bottom.

EXPECT: the Food & Dining row now ends "left of ₱12,000", and the headline has
risen by EXACTLY 3,000 from what you wrote down. The change is 3,000 whatever
the starting figure was, because the limit rose by 3,000 and nothing was
spent.

FAILS IF: the row changes and the headline does not, which means the two are
no longer reading the same figure. Or the headline moves by 2,999.99 or
3,000.01, which is the drift this change removes.

8. Set it back to `9000` the same way.

## 3. A budget limit with centavos survives

The whole point of the change is that centavos cannot drift.

**Navigation**

1. **Plan**, then **Budgets**.
2. Tap the **Transport & Commute** row.
3. Clear the field, type `3500.55`, tap **Save limit**.
4. Tap the **Transport & Commute** row again.

EXPECT: the field reads `3500.55`.

FAILS IF: it reads `3500.54`, `3500.56`, `3500.5` or `3501`.

5. Set it back to `3500`.

## 4. Bills and payables

These figures ARE safe to quote, unlike the budget totals above, and the
difference is worth knowing: bills are "what is due next", with no month
window on them at all, so nothing drops out as the calendar moves. Only the
DUE LABELS change ("Due Today", "Due Sunday"), never the amounts.

**Navigation**

1. **Plan**, then the **Bills and payables** tile. Its grey line reads "What
   is due next".

EXPECT: a box reading **GOING OUT ₱5,529.00** over "3 bills", and beside it
**COMING IN ₱32,500.00**. Under **SCHEDULED**: Meralco Electric Bill
₱2,840.00, Spotify Premium Family ₱239.00, Home Credit Installment ₱2,450.00,
Sweldo Payday ₱32,500.00 in green.

2. Check the invariant too: 2,840 + 239 + 2,450 = 5,529, which must equal
   GOING OUT exactly.

**Adding one with centavos**

3. Scroll down to the **Schedule a bill** section.
4. In **What is it**, type `Test centavos`.
5. In **How much**, type `1234.56`.
6. Leave the date and kind alone.
7. Tap **Schedule it**.

EXPECT: the new row reads ₱1,234.56, and GOING OUT is now **₱6,763.56**.

FAILS IF: ₱1,234.55 or ₱1,234.57, or a GOING OUT total that is a centavo off
the sum of the four rows.

8. Remove the test bill: find its row and use **Remove**.

## 5. A credit card with no limit says so, rather than claiming zero

This is the one I nearly broke, so it is worth your time.

**Navigation**

1. Tap **Accounts** in the bottom bar.
2. Near the top is a row of pills: **All**, **Own**, **Owe**, **Invested**,
   each with a count. Tap **Owe** to show only what you owe. (You can also
   leave it on All and scroll to the "Liabilities and obligations" heading.)
3. Under **Credit Cards (1)**, tap the **BPI Rewards Card**. The card flips
   over.
4. Tap **Edit** on the flipped card.
5. A sheet opens headed **Edit account**. Scroll down to **Credit limit**.
6. Clear that field completely, leaving it empty.
7. Tap **Save changes**.

EXPECT: the card now reads **"Add this card's limit to see how much of it you
are using."** There is no percentage and no "Credit used" bar.

FAILS IF: the card shows `0%` used, or a "Credit used" bar. That would mean an
empty box was stored as a limit of ZERO, which is a claim nobody made and a
figure the app would then divide by.

**The second half, which is the stronger one**

8. Open the card's **Edit** sheet again and look at **Credit limit**.

EXPECT: the box is EMPTY. You will see a grey `40000` in it, and that is the
placeholder, not a value. Grey means empty; a real value is dark.

FAILS IF: the box holds a dark `0` or a dark `40000`. Either would mean the
cleared state did not survive being written to disk and read back.

9. Put `40000` back and save, so the rest of your sample data stays coherent.

## 6. Expected income survives being typed and read back

**Navigation**

1. Go to **Home**.
2. On the big card at the top, find the line that reads either **"Payday not
   set"** or **"N days to payday"**. That line is a button.
3. Tap it. The payday sheet opens.
4. Set the days if they are not already set.
5. In the expected income field, type `20000.50`.
6. Save.
7. **Close the app completely** (swipe it away from the Android recents), then
   reopen it.
8. Tap that same payday line on Home again.

EXPECT: the income field reads `20000.50`.

FAILS IF: `20000`, `20001` or `20000.5`. Any of those means the centavos did
not survive the trip to storage and back.

## 7. The privacy receipt tells the truth about spare copies

This wording changed, so read it rather than skim it.

**Navigation**

1. Go to **Home**.
2. Tap the **On this phone** chip at the top, beside the Salapify logo. (The
   gear icon, then **What stays on this phone**, gets you to the same place.)
3. It is the SECOND entry, the one with the folder icon.

EXPECT: it is headed **"Your figures live in this phone's own storage"** and
says Salapify keeps **up to two spare copies**, names what each one holds, and
says Delete everything removes all of them.

FAILS IF: it still reads "Your figures live in one file here". That sentence
was false and is what this fixed.

## 8. Delete everything names the Pan conversation. DO THIS LAST.

This really does erase your test data.

**Navigation**

1. Go to **Home**.
2. Tap the **gear** icon, the rightmost of the four round buttons.
3. Scroll to the **Privacy** section at the bottom.
4. Tap **Delete everything on this phone**.
5. Read the red warning block headed "There is no undo". It should say
   Salapify normally keeps **two spare copies**.
6. Tap **Delete everything**.
7. A confirmation appears with **Keep my records** and **Yes, erase it**. Tap
   **Yes, erase it**.

EXPECT: a screen headed **Gone**. Its first sentence counts the files removed
and lists them, and that list now includes **your conversation with Pan**
alongside your ledger, the spare copies Salapify kept, and the saved exchange
rates.

FAILS IF: the Pan conversation is missing from that list. The app genuinely
deletes that file, and the screen used not to say so, which matters most to
somebody wiping before handing their phone to a repair shop.

8. Tap **Close**. You should land on the welcome screen.
9. Tap **Look around with example data first** to get your test data back.

---

## Not testable by hand, and why

Two things in this batch cannot be reached from the screens. They are covered
by tests instead, and both were broken on purpose first to prove the tests
catch them.

**A budget limit of zero used to crash Home.** The percentage divided by the
limit with no check, and dividing by zero takes the screen down. You cannot
type a zero limit, because the app refuses one, so the only way in is a backup
file carrying one. The test loads such a file.

**A backup from the older Salapify is refused with an honest sentence.** You
would need a Salapify 2 backup file on the emulator to see it. If you want to
try: export a backup from Salapify 2 on your own phone, move the file across,
then **gear icon**, **Restore from a backup**. It should say the backup is
from the older Salapify and that nothing on this phone has been changed. It
must NOT tell you to update the app.

---

## What a failure means

If any figure is out by a centavo, stop and say which one. That is the exact
defect this whole phase exists to prevent, and a single wrong centavo is more
informative than everything else on this page.

---

## Results, 2026-10-03, founder on the emulator

**Case 1, budgets: PASS.** Reported first as a failure, 39,216 against the
25,425.25 this page quoted, and the page was wrong rather than the app. Case 0
was written because of it. The screen was internally exact: the seven "left
of" figures summed to the headline to the centavo, and all three categories
with current-month entries matched the golden vectors exactly.

**Case 5, the credit card: PASS, on both halves.** Clearing the limit box left
the card reading "Add this card's limit to see how much of it you are using"
with no percentage, so an empty box stored NO LIMIT rather than a limit of
zero. Reopening the sheet then showed an empty box, which was not asked for
and is the stronger of the two: the null survived a write to disk and a read
back. That is the defect this batch nearly shipped.

Reported as "cannot see the 0%", which was the label's fault and not the
reader's. FAILS IF now says what WATCH FOR meant.

### One observation from case 5, not a defect

The credit limit box's placeholder is `40000`, which is also the sample card's
real limit (`account_sheet.dart`, `hint: '40000'`). So a cleared box and a box
holding 40,000 look nearly the same, and only the grey of the hint tells them
apart. On a money field that is a poor placeholder, and it is what made the
screenshot ambiguous enough to need a second question. Worth changing to a
figure no card would really hold, or to the currency alone.

### The full run, confirmed by the founder

All eight cases PASS on `claude/flutter-final` at `9a3195f`.

| Case | Result |
|---|---|
| 1. Budgets add up | PASS, after case 0 was written. The page was wrong, not the app |
| 2. Changing a limit moves the row and the headline | PASS |
| 3. A limit with centavos survives | FAILED, then PASS after the fix in `1999b23` |
| 4. Bills and payables | PASS |
| 5. A credit card with no limit says so | PASS, both halves |
| 6. Expected income survives a restart | PASS |
| 7. The privacy receipt | PASS |
| 8. Delete everything names Pan | PASS |

Case 3 is the one that earned this whole page. It is the only defect of the
eight, 1,678 tests passed over it, and no automated test in the repository
reopened an edit sheet to read what the box offers back. The fix and the guard
are in `1999b23`; whether that guard should cover every money input in the app
rather than budgets alone is a question for the retrospective, not for here.
