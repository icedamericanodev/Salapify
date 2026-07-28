# QA log

One row per shipped stamp, recording whether the QA pass CLAUDE.md requires
BEFORE a merge actually ran, and what it found.

`flutter/test/qa_record_test.dart` fails on the real runner when the current
`updateStamp` has no row here. That is the point: the check runs on every push
to a `claude/**` branch, so a stamp cannot reach main without someone having
had to look at this file and write in it.

What this guard can and cannot do, said plainly so nobody mistakes a green
check for more than it is:

- It CAN stop a QA pass being forgotten. That is the failure it was built for,
  and the failure that put a broken monthly cap on the founder's phone in
  f2.71 for two hours.
- It CANNOT stop a row being written for a pass that did not happen. Nothing
  automated can. What it does is turn an omission into a deliberate false
  sentence sitting in a diff, which is a different and much harder thing to do
  by accident.

A row of SKIPPED is a valid and expected entry. It is worth far more than a
missing row: it says what happened. Two of the rows below say exactly that,
backfilled honestly rather than left blank or quietly marked green.

| Stamp | Reviewer | Verdict | Notes |
| --- | --- | --- | --- |
| f2.68 | qa-tester | Findings fixed and re-checked before merge | Onboarding batch |
| f2.69 | qa-tester | Findings fixed and re-checked before merge | Notification opt-in step |
| f2.70 | qa-tester | 1 crash, 1 overstated balance, 1 dead sheet, all fixed before merge | Transfers batch |
| f2.71 | SKIPPED | No pass ran before the merge | Ran retroactively 2 hours after delivery; found the monthly cap counting only tagged entries, so a cap was inert for the app's main Log button. Fixed in f2.72. This row is why the guard exists. |
| f2.72 | qa-tester, tax-professional | Findings fixed and re-checked before merge | Tax deadlines and year-end estimate. The tax review found the app stating filing positions it could not know. |
| f2.73 | qa-tester | 3 MUST FIX and 4 SHOULD FIX fixed and re-checked before merge; 4 lower findings deferred and named below | Utang person depth. MUST: two people sharing a name were merged, so the statement sent to one billed her for the other's ₱7,000; the SETTLED row printed what was LEFT while calling it paid; huge amounts saturated at the int64 ceiling and printed a credible wrong peso figure into a friend's chat app. CORRECTED after session 14: this row first also claimed the settled row read a stored amount of "2400" as ₱0. It cannot. Every load runs through sanitizeData, so a screen never sees a string amount, and the two test assertions guarding that claim passed against the broken code. The other half of the finding, printing what was LEFT while calling it paid, was real and is fixed. SHOULD: whole peso rounding made the document visibly fail to add up; the same payment showed two different amounts in the history and the statement; every payment was listed twice; a failed share did nothing at all, silently. DEFERRED: nameOf and utangAging are still two rules that can disagree on whitespace-only or duplicate-id people; the sheet is O(R×P) per rebuild; an imported overpaid row can make Remind and the statement disagree; a year past 9999 loses the As of date (RN parity). |
| f2.74 | qa-tester | 3 MUST FIX and 5 SHOULD FIX fixed and re-checked before merge; 2 lower findings deferred and named below | Period selector on Activity. MUST: the Show all button left the period on, so an empty filtered list was a dead end while the sentence beside it said the entries were only hidden; the date picker asserted and crashed on any device clock before 1995, because firstDate was a constant while lastDate came from the clock; two of the new tests were going to start failing on 1 August 2026, four days out, and turn the branch check red on main (four more by January 2027; the commit message and the first version of this row both said three, corrected after session 14 re-proved the count in a pre-fix worktree), because the History-mounted selector fell back to the real clock while the fixtures were pinned to July. SHOULD: the clear X was a 16dp target sitting on a 48dp button that opens a full screen calendar when you miss it; a backwards custom range silently matched nothing; a future dated entry was unreachable in Month mode; Period.copyWith could not clear a bound and had no callers; the shift goldens never checked what a custom period preserves, proven by breaking it. Also fixed while open: Reports pushed Activity without the month the person had already chosen. DEFERRED: tapping the already selected Month chip is inert so there is no one tap return to today; the empty state does not name the active period as the thing hiding rows. |
| f2.75 | qa-tester | 2 MUST FIX and 4 SHOULD FIX fixed and re-checked before merge; 3 lower findings deferred and named below | Quick add editor. MUST: seeding the presets when the editor OPENED flipped hasData true on an empty app, which permanently replaced Menu's BRING YOUR DATA OVER card, the only in-app route to import from the old app, with a backup card, so every RN tester lost their migration prompt by looking at a settings sheet (fixed by seeding on the first real edit instead); neither write was wrapped, so a refused write froze the sheet on Saving... with no message and let the exception escape unhandled. SHOULD: a long label clipped the amount off the Budget chip so the button logged a figure never shown (24 character cap); an amount of 0.004 was accepted and drew as ₱0 while every tap filed a real expense (0.01 floor); a comma grouped amount got the wrong sentence when the app itself prints ₱1,500 everywhere (its own message now); the sheet had no safe area and no height cap, so past about 13 presets the grab handle sat under the status bar and Add and Done were below the fold. The two acceptance divergences from RN are recorded in the goldens on purpose rather than left to be discovered. DEFERRED: an RN backup where the person deleted every quick add still resurrects the four defaults, because no RN backup carries the edited flag; two Edit taps in one frame can stack two sheets (idempotent, no data harm); the amount field's only screen reader label is its hint. |
