# Test cases for the money batch, with navigation

2026-10-03. For testing by hand on the Android emulator, after
`claude/review-build` reaches `claude/flutter-final`.

Everything in this batch is meant to change NOTHING you can see. That is the
test. A type migration that moves a figure has failed, so most of these cases
are "open it and check the number is the same".

Two labels, and the second one caused real confusion on its first outing, so
read this before the cases.

**EXPECT** is the pass condition. This is what you should see.

**FAILS IF** is the DEFECT. It is what would mean something is wrong, and not
seeing it is the point. The first version of this page called it "WATCH FOR",
which reads as an instruction to go and find the thing, so the founder
correctly reported being unable to find a `0%` that was never supposed to be
there. Not seeing a FAILS IF is a pass.

---

## Before you start

Nothing here needs a fresh install. If your emulator is on the sample data,
you are ready. If it is empty, open Settings, Sample data, and put the
examples back, or the figures below will not match.

Do case 8 LAST. It erases everything.

---

## 0. Why this page does not quote a spending total

Written after the first run of case 1 reported a "wrong" figure that was
correct. The first version of that case quoted ₱25,425.25 left to spend,
copied from the golden vectors. It is the right figure IN THE TESTS, which pin
the clock to 18 September, and it is wrong on a real phone on almost every
other day.

The sample entries are dated RELATIVE TO TODAY: one day ago, three days ago,
fourteen days ago. Budgets are a THIS MONTH limit. So on the 3rd of a month,
only the entries from the last two days are inside the window and most
categories correctly read zero. On the 20th, nearly all of them are inside it.
The figure moves every day, by design, and no number written on this page can
survive that.

So every case below checks an INVARIANT, something that cannot be false
whatever the date, or a figure that genuinely does not depend on one. A test
instruction that rots is worse than no test instruction, because it sends
somebody to look for a defect that is not there.

## 1. Budgets add up, whatever today is

1. Open the **Plan** tab.
2. Tap **Budgets**.

Three checks, all true on any date:

**1a. The limits never move.** Each row says "left of ₱X". Those should read
₱9,000, ₱3,500, ₱6,500, ₱8,000, ₱4,000, ₱5,000 and ₱6,000, one per category.

**1b. The parts sum to the whole.** Add up every row's "left of" figure. It
must equal the headline, **Left to spend this month**, to the centavo.

**1c. Each row is self-consistent.** For any row with spending, the big figure
on the right plus the "left" figure must equal that row's limit exactly.

FAILS IF: a sum that is a centavo or two off the headline. That is precisely
what adding money up as decimals used to risk, and precisely what this change
removes, so it is the most informative failure on this page.

NOT A DEFECT: a category reading ₱0.00 with 0 entries. That means its sample
entries fall in a previous month. Early in a month most of them will.

## 2. Changing a budget limit moves the row AND the headline

1. **Plan**, then **Budgets**.
2. WRITE DOWN the headline figure before you touch anything.
3. Tap **Food & Dining**.
4. Clear the box and type `12000`.
5. Before saving, read the line under the box. It should say what the new
   limit would leave you.
6. Tap **Save limit**.

EXPECT: the Food & Dining row now reads `left of ₱12,000`, and the headline
has risen by EXACTLY 3,000 from the figure you wrote down. The change is
3,000 whatever the starting figure was, because the limit went up by 3,000 and
nothing was spent.

FAILS IF: the row changing while the headline does not, or a headline that
moves by 2,999.99 or 3,000.01. The first means the two are no longer reading
the same figure; the second is the drift this change removes.

7. Set it back to `9000` when you are done.

## 3. A budget limit with centavos

The whole point of the change is that centavos cannot drift.

1. **Plan**, **Budgets**, tap **Transport & Commute**.
2. Type `3500.55` and save.
3. Tap it again.

EXPECT: the box reads `3500.55`, not `3500.54`, `3500.56` or `3500.5`.

4. Set it back to `3500`.

## 4. Bills and payables

1. **Plan**, then **Bills and payables**.

These figures ARE safe to quote, unlike the budget totals above, and the
difference is worth knowing: bills are "what is due next", with no month
window on them at all, so nothing here drops out as the calendar moves. Only
the DUE LABELS change ("Due Today", "Due Sunday"), never the amounts.

EXPECT: `GOING OUT ₱5,529.00` over `3 bills`, and `COMING IN ₱32,500.00`.
Meralco ₱2,840.00, Spotify ₱239.00, Home Credit ₱2,450.00, Sweldo Payday
₱32,500.00.

2. Check the invariant as well as the figures: the three bill amounts must add
   up to GOING OUT exactly.

3. Scroll down and add a bill: name it `Test centavos`, amount `1234.56`.

EXPECT: it appears at ₱1,234.56, and GOING OUT rises to ₱6,763.56.

FAILS IF: ₱1,234.55 or ₱1,234.57, or a going-out total that is a centavo off
the sum of the rows.

4. Delete the test bill afterwards.

## 5. A credit card with no limit says so, rather than claiming zero

This is the one I nearly broke, so it is worth your time.

1. Open the **Accounts** tab.
2. Scroll down past your cash and savings to the cards. Tap
   **BPI Rewards Card**.
3. The limit box should be pre-filled with `40000`. Clear it, leave it
   completely empty.
4. Save.

EXPECT: the card now invites you to add the limit, something like "Add this
card's limit". It must NOT show a used percentage.

FAILS IF: the card showing `0%` used, or a "Credit used" bar. That would mean
an empty box was stored as a limit of zero, which is a claim nobody made.

5. Put `40000` back.

## 6. Expected income survives being typed and read back

1. On **Home**, find the payday prompt and open it. (If you have already set a
   payday, open it the same way to edit it.)
2. Set the days and type an expected income of `20000.50`.
3. Save.
4. Close the app completely and reopen it.
5. Open the payday prompt again.

EXPECT: the box reads `20000.50`.

FAILS IF: `20000`, `20001` or `20000.5`. Any of those means the centavos did
not survive the trip to storage and back.

## 7. The privacy receipt tells the truth about spare copies

This wording changed, so read it rather than skim it.

1. Tap the **On this phone** chip at the very top of any screen. (Or
   **Settings**, then **What stays on this phone**.)
2. Read the second entry, the one with the folder icon.

EXPECT: it is headed "Your figures live in this phone's own storage" and says
Salapify keeps **up to two spare copies**, naming what each one holds, and
that Delete everything removes all of them.

FAILS IF: the old wording, "Your figures live in one file here". That was
false and is what this fixed.

## 8. Delete everything names the Pan conversation. DO THIS LAST.

This really does erase your test data.

1. **Settings**, then **Delete everything on this phone**.
2. Read the warning. It should say Salapify normally keeps two spare copies.
3. Tap **Delete everything**.
4. Tap **Yes, erase it**.

EXPECT: the "Gone" screen lists what went, and the list now includes **your
conversation with Pan** alongside your ledger, the spare copies and the saved
exchange rates.

FAILS IF: the Pan conversation missing from that list. The app genuinely
deletes that file, and the screen used not to say so, which matters most to
somebody wiping before handing their phone to a repair shop.

5. You should land back on the welcome. Tap **Look around with example data
   first** to get your test data back.

---

## Not testable by hand, and why

Two things shipped in this batch that you cannot reach from the screens. They
are covered by tests instead, and both were broken on purpose first to prove
the tests catch them.

**A budget limit of zero used to crash Home.** The percentage divided by the
limit with no check, and dividing by zero takes the screen down. You cannot
type a zero limit, because the app refuses one, so the only way in is a
backup file carrying one. The test loads such a file.

**A backup from the older Salapify is refused with an honest sentence.** You
would need a Salapify 2 backup file on the emulator to see it. If you want to
try it, export a backup from Salapify 2 on your own phone, move the file over,
and restore it from Settings. It should say the backup is from the older
Salapify and that nothing on this phone has been changed. It must NOT tell you
to update the app.

---

## What a failure means

If any figure above is out by a centavo, stop and say which one. That is the
exact defect this whole phase exists to prevent, and a single wrong centavo is
more informative than everything else on this page.

---

## Results, 2026-10-03, founder on the emulator

**Case 1, budgets: PASS.** Reported first as a failure, 39,216 against the
25,425.25 this page quoted, and the page was wrong rather than the app. See
case 0, which was written because of it. The screen was internally exact: the
seven "left of" figures summed to the headline to the centavo, and all three
categories with current-month entries matched the golden vectors exactly.

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
apart. On a money field that is a poor placeholder, and it is exactly what
made the screenshot ambiguous enough to need a second question. Worth changing
to something no card would really hold, or to the currency alone.
