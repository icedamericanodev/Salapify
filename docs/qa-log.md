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
| f2.73 | qa-tester | 3 MUST FIX and 4 SHOULD FIX fixed and re-checked before merge; 4 lower findings deferred and named below | Utang person depth. MUST: two people sharing a name were merged, so the statement sent to one billed her for the other's ₱7,000; the SETTLED row printed what was LEFT (and ₱0 for a string amount) while calling it paid; huge amounts saturated at the int64 ceiling and printed a credible wrong peso figure into a friend's chat app. SHOULD: whole peso rounding made the document visibly fail to add up; the same payment showed two different amounts in the history and the statement; every payment was listed twice; a failed share did nothing at all, silently. DEFERRED: nameOf and utangAging are still two rules that can disagree on whitespace-only or duplicate-id people; the sheet is O(R×P) per rebuild; an imported overpaid row can make Remind and the statement disagree; a year past 9999 loses the As of date (RN parity). |
