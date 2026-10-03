# Test cases for the money batch, with navigation

2026-10-03. For testing by hand on the Android emulator, after
`claude/review-build` reaches `claude/flutter-final`.

Everything in this batch is meant to change NOTHING you can see. That is the
test. A type migration that moves a figure has failed, so most of these cases
are "open it and check the number is the same".

Where a case says EXPECT, that is the pass condition. Where it says WATCH FOR,
that is the specific way it could be broken.

---

## Before you start

Nothing here needs a fresh install. If your emulator is on the sample data,
you are ready. If it is empty, open Settings, Sample data, and put the
examples back, or the figures below will not match.

Do case 8 LAST. It erases everything.

---

## 1. Budgets still add up

The figures below are locked by test vectors, so they are what the screen must
show to the centavo.

1. Open the **Plan** tab.
2. Tap **Budgets**.

EXPECT, exactly:

| Where | Figure |
|---|---|
| Left to spend this month | ₱25,425.25 |
| Under it | 1 over, 0 to watch |
| Debt & Loan Servicing | ₱6,450.00, and ₱450.00 over limit |
| Groceries | ₱3,250.75, 41%, ₱4,749.25 left of ₱8,000 |
| Food & Dining | ₱465.00, 5%, ₱8,535.00 left of ₱9,000 |

WATCH FOR: a figure a centavo out, or a percentage off by one. Those are the
only shapes this change could have broken.

## 2. Changing a budget limit moves the row AND the headline

1. **Plan**, then **Budgets**.
2. Tap **Food & Dining**.
3. Clear the box and type `12000`.
4. Before saving, read the line under the box. It should say what the new
   limit would leave you.
5. Tap **Save limit**.

EXPECT: Food & Dining now reads `₱8,535.00 left of ₱12,000`, and the headline
at the top has risen by exactly 3,000, from ₱25,425.25 to ₱28,425.25.

WATCH FOR: the row changing while the headline does not. That means the two
are no longer reading the same figure.

5. Set it back to `9000` when you are done.

## 3. A budget limit with centavos

The whole point of the change is that centavos cannot drift.

1. **Plan**, **Budgets**, tap **Transport & Commute**.
2. Type `3500.55` and save.
3. Tap it again.

EXPECT: the box reads `3500.55`, not `3500.54`, `3500.56` or `3500.5`.

4. Set it back to `3500`.

## 4. Bills and payables

1. **Plan**, then **Bills and payables**.

EXPECT: `GOING OUT ₱5,529.00` over `3 bills`, and `COMING IN ₱32,500.00`.
Meralco ₱2,840.00, Spotify ₱239.00, Home Credit ₱2,450.00, Sweldo Payday
₱32,500.00.

2. Scroll down and add a bill: name it `Test centavos`, amount `1234.56`.

EXPECT: it appears at ₱1,234.56, and GOING OUT rises to ₱6,763.56.

WATCH FOR: ₱1,234.55 or ₱1,234.57, or a going-out total that is a centavo off
the sum of the rows.

3. Delete the test bill afterwards.

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

WATCH FOR: the card showing `0%` used, or a "Credit used" bar. That would mean
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

WATCH FOR: `20000`, `20001` or `20000.5`. Any of those means the centavos did
not survive the trip to storage and back.

## 7. The privacy receipt tells the truth about spare copies

This wording changed, so read it rather than skim it.

1. Tap the **On this phone** chip at the very top of any screen. (Or
   **Settings**, then **What stays on this phone**.)
2. Read the second entry, the one with the folder icon.

EXPECT: it is headed "Your figures live in this phone's own storage" and says
Salapify keeps **up to two spare copies**, naming what each one holds, and
that Delete everything removes all of them.

WATCH FOR: the old wording, "Your figures live in one file here". That was
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

WATCH FOR: the Pan conversation missing from that list. The app genuinely
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
