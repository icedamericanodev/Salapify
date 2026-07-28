# Lunch and learn

A short, blameless retrospective after every patch check, so the same mistake
never ships twice. Newest session first. Facilitated by the lunch-and-learn
agent (.claude/agents/lunch-and-learn.md).

The one rule: ground truth is the Update stamp ON THE PHONE. Everything else
(a green local test run, a merged pull request, a passing action) is a belief
about delivery, and beliefs are what these sessions audit.

---

## 2026-07-28, session 10: the promise the port dropped and the copy kept

One delivery, one clean row, confirmed on the phone by the founder. There is
no delivery incident in this entry and none is manufactured.

What this session has instead is a defect shape this log has not named before,
and it is a shape that will keep happening for as long as the Flutter rebuild
continues: a port where the BEHAVIOUR was deliberately changed and the SENTENCE
describing that behaviour was carried across unchanged. The result was an app
that promised something it had already decided not to do, in two places at
once, one of which would have sat there being wrong forever.

It also has the strongest single piece of evidence a retrospective here can
produce. Two assertions had to be INVERTED before the fix could pass, and one
test's own NAME asserted the defect. Both were written six hours earlier, by
the same author, in the same sitting as the code.

And the standing CLAUDE.md fact check found a false factual claim that has been
sitting in the file since session 4's own commit, read with authority by five
consecutive sessions, every one of which ran this same check and reported the
file clean.

### What we believed / What was true

**Believed: f2.69 reached the phone. TRUE, and confirmed in person.** Read from
`git show origin/main:docs/delivery-log.md | tail -3`, the last row is:

    | 2026-07-28 06:41 UTC | f2.69 | 19 | patch | 0.6.2+11 | f1220f60 (run 30335017487) |

Mode `patch`, so nothing was stranded and no manual install is owed.
`git show origin/main:flutter/pubspec.yaml` still reads `version: 0.6.2+11`,
unchanged since session 5, so the installed base APK is still the right one.
The stamp in the tree, flutter/lib/main.dart:30, is
`'f2.69 · New users can say yes or no to one quiet 8pm nudge during the
welcome.'`, 78 characters, comfortably inside the 120 cap enforced at
flutter/test/update_stamp_test.dart:20. Stamp in the code, stamp in the log,
stamp on the phone: three for three. Merge at 06:30:06 UTC to row at 06:41:56
UTC is 11 minutes 50 seconds, inside the norm every session since 4 has
measured.

**Believed: the merge used a merge commit, not a squash. TRUE, verified rather
than assumed.** `git cat-file -p f1220f6` shows two parents, 9a846f22 and
fd43e256. CLAUDE.md's never-squash rule held.

**Believed: the nudge step's copy described what the nudge step does. FALSE, in
two places at once.** The step's paragraph, ported from the RN onboarding, read
"One quiet reminder at 8pm, plus a heads up on payday", and
`completeOnboarding` wrote `'payday': true` into settings.notifications. But
the Flutter reminder planner refuses to emit a payday reminder unless a real
payday schedule exists: flutter/lib/money/reminders.dart:124 gates on
`on['payday'] == true && hasExplicitPaydaySchedule(data)`, and a brand new user
has never set a schedule. So the sentence promised a notification that could
not fire, AND the Menu screen showed a switch reading ON that could never ring,
for as long as that user kept the app. The first untruth is read once. The
second one is furniture.

**Believed: the sample-data rule was fully honoured, because the comment said
three places and three places honoured it. FALSE. There were four readers in
Flutter, and the count in the comment was never about Flutter at all.** More
on this in root cause 2, including a live defect of the same shape still
sitting in the RN app the comment cites as its authority.

**Believed: 880 green tests plus a green Flutter check on a real runner meant
the batch was sound. FALSE, and the suite was not merely silent about the
payday promise. It was certifying it, by name.**

**Believed, as a standing fact since session 4: the shot harness renders a
lesson and the diagnostics dialog at both brightnesses. FALSE, and it was false
on the day that sentence was written into CLAUDE.md.** Details in Lesson 6.

**Believed: session 9's Open 16 (never restore with `git checkout`, reverse the
exact edit and assert the markers are back) is a practice with no home in any
file. TRUE, and it still has no home, which is why it cannot be closed even
though it worked perfectly this round.**

### Timeline (with evidence)

All times UTC, from `git log --format=%cI` and the publisher's own rows.

| Time | Event | Evidence |
|------|-------|----------|
| Jul 28 03:42 | f2.68 patch 18 delivered, session 9's ground truth | delivery row, 9a846f2 |
| 06:03:42 | a10041e Phase 3 batch 3, the nightly nudge step. 880 green, analyze clean. Carries the session 9 write-up | commit message |
| 06:03:42 | **Session 9's Open 15 strong tier lands in the same commit**: every frame in the onboarding walk now asserts what it is before it is photographed | screens_shot.dart:871, :880, :891, :902 |
| 06:22:56 | fd43e25 QA round. **The qa-tester pass finds three user-facing untruths and one race**, all fixed, each guard proven failing first. 884 green | commit message |
| 06:30:06 | Merge #226 (f1220f6), two parents | `git cat-file -p f1220f6` |
| 06:41:56 | f2.69 patch 19 delivered, 11m50s | delivery row, 9400ebe |
| after | **Founder confirms f2.69 on the phone** | founder |

Test counts, and the same honest note session 9 had to make. The commits record
880 green after the batch and 884 after the QA round, each with analyze clean.
This entry does NOT quote a suite run made while writing it, because another
task is editing flutter/ right now and a run would measure a half-edited tree.
That is now two sessions in a row without an independently re-run baseline. It
is a small debt, it is named here so it does not become invisible, and the next
session that has flutter/ to itself should run the suite and record the real
number rather than inheriting 884 on trust.

### Divergence point

There is no delivery divergence this round. The stamp built, shipped, was
logged, and matched the phone.

The belief divergence worth naming is **06:03:42 UTC, inside a10041e, at the
moment the nudge step's paragraph was copied over from the RN step.** Not the
moment the payday gate was written. The gate is old, deliberate, and correct,
and flutter/lib/money/schedule.dart:8 to :16 explains itself at the site:

    /// This distinction matters because the two uses are not equally forgiving.
    /// Guessing 15/31 for a FORECAST is harmless: it says "your next payday is
    /// probably around then". Guessing it for a CLAIM is not, because "it is
    /// payday today" is either true or a lie, and it was a lie for every user
    /// who never migrated a schedule from the old app.

The divergence is the instant a sentence crossed a boundary that the behaviour
had already been forbidden to cross. Both halves were written on purpose. The
split is that nothing connected them.

Name the shape, because it is new to this log and it will recur: **a port moves
two artifacts at two different speeds.** Code gets ported with judgement, one
function at a time, with a test vector at the end of it. Copy gets ported by
reading and retyping, and it feels like the cheapest part of the job. But copy
is a claim about behaviour, so copy carries the ORIGIN's behaviour into the
port. Every deliberate divergence in the Flutter rebuild is therefore a place
where the RN sentence is now a lie, and CLAUDE.md rule 4 (port order, money
logic first with matching vectors) governs the code half and says nothing about
the sentence half.

### Root cause

**1. The payday promise. RN keeps that promise only by doing the exact thing
Flutter was written to stop doing.** This is the part that makes it more than a
copy and paste slip. On RN, mobile/lib/notifications.js:115 calls
`upcomingPaydays(now, data.settings && data.settings.paydaySchedule, 6)`, and
`upcomingPaydays` (mobile/lib/format.js:220) runs the schedule through
`normalizeSchedule`, which quietly falls back to the 15/31 default when the
user never set one. So RN pushes a 9am "Sweldo day!" notification on a GUESSED
date. The promise is kept, and it is kept by asserting something the app does
not know. Flutter's `hasExplicitPaydaySchedule` exists precisely to refuse
that. So the ported sentence was true in RN only because RN has the defect
Flutter had already fixed. The copy did not just describe old behaviour, it
described a bug, and it imported the bug's marketing without the bug.

The root cause is not that someone forgot to reread the planner. It is that
this project has a checklist for porting a FUNCTION (matching test vectors, no
merge without them) and no checklist at all for porting a SENTENCE, even though
a sentence in this app is a promise the code has to keep.

**2. The count in the comment was a completeness receipt, and it was never a
statement about Flutter.** flutter/lib/money/sample_data.dart:13 to :15 reads:

    // The transaction ids keep the RN t1..t5 tail for the one contract that
    // matters: sample rows must never feed a habit feature. chain.dart excludes
    // exactly this set, the same three-place rule RN keeps.

and flutter/lib/money/chain.dart:67 repeats it inline: "Sample rows never feed
a habit feature, the RN three-place rule". Read literally, both sentences are
TRUE. RN really does exclude the sample ids in exactly three places:
mobile/components/WeekRecap.js:25, mobile/components/WeekChain.js:28, and
mobile/app/(tabs)/budget.js:78. The trouble is what the number DOES to a reader
who is standing in a Flutter file wondering whether their new code needs the
rule. A number reads as a total. A total reads as a job that is finished.

The Flutter readers, counted from the repository rather than from the comment,
are four files and five call sites: chain.dart:69, coach.dart:313,
quickadd.dart:28 and quickadd.dart:60, and now reminders.dart:112. The planner
was the fourth, and it was the one that missed.

The consequence was real and it was dated. sample_data.dart's `_day` helper
clamps every seeded date to today or earlier, so on any install day from the
1st to the 10th the seed contains a transaction dated TODAY. The planner's
daily branch skipped tonight's 8pm nudge whenever anything was logged today.
So a brand new user who said yes to the nightly nudge and then chose "explore
the sample data" had their very first night silently cancelled, by a
transaction they did not make, on the one night the habit is least established.

And there is a second layer that is worth writing down because it is not in the
commit message. **RN has the identical defect, in the identical place, right
now.** mobile/lib/notifications.js:100 reads:

    const loggedToday = (data.transactions || []).some((t) => t.date === todayISO());

No sample exclusion. RN seeds its sample data on first run rather than on
request, so RN's exposure is arguably wider than Flutter's was. The comment
cited "the three-place rule RN keeps" as its authority for completeness, and
the authority is itself incomplete in exactly the fourth place. A count copied
from another codebase inherits that codebase's blind spots along with its
number.

**3. The permission race, which nobody has a category for yet.** Tapping "Yes"
opened the OS permission dialog, an async call that takes a moment to appear,
and both answer buttons stayed live and tappable underneath it for that
moment. Tapping "No thanks" in that window and then having the granted answer
land afterwards turned an explicit no into a yes. On the one step in the whole
app whose stated design point is that a no must feel as fine as a yes,
overriding the no is the worst available outcome. The root cause is that an
async call to the OS has a duration and the UI treated it as instantaneous.
There is no unit test in this project that would ever have looked, because the
window only exists between two awaits.

**4. Why the tests did not help.** They did worse than not help, and the
evidence is in Lesson 5.

### Lessons and guards

**Lesson 1. Ported COPY makes a promise about the ORIGINAL's behaviour, and
this port diverges from the original on purpose in many places. A sentence
crossing that boundary needs the same scrutiny as a function crossing it.**

**Guard for the instance, SHIPPED, strongest tier, proven failing first.**
flutter/test/onboarding_test.dart:426, group 'the nudge QA round', test 'a yes
never switches on a payday reminder that cannot ring', with the failure it was
born catching quoted in fd43e25:

    Expected: not <true> / Actual: <true>
    reason: 'no schedule exists, so the switch must not claim it will ring'

Both halves of the alarm are proven, as CLAUDE.md requires: the silent half is
onboarding_test.dart:455, 'someone who already has a payday schedule does get
it', which asserts the restored-backup user DOES get `payday: true`. That
matters. A guard that only ever says no would have been satisfied by deleting
the feature.

**Guard for the class, NOT WRITTEN, and named here so it is not lost. NEW Open
17.** The generalisation is a real test and it is worth writing: for every key
`completeOnboarding` can write into settings.notifications, assert that
`plannedReminders` actually produces a reminder of that kind given the same
data. Then the next person who adds a key to the onboarding write cannot ship a
switch that cannot ring, whatever the copy says. Honest cost, checked in the
code rather than guessed: `PlannedReminder` (reminders.dart:25 to :30) carries
only title, body and when, with no kind field, so today the test would have to
match on the title strings ('Quick money check', 'Payday!'). That is a little
brittle. The tidier version adds a `kind` field to `PlannedReminder`, which is
a small change to lib and touches the plugin adapter. Either is a few minutes.
Neither is written, because flutter/ is being edited by another task as this is
written.

**Lesson 2. A counted list inside a comment is read as a receipt that the job
is finished, and the count is the part that rots first. This is the second
independent confirmation in four days, in a different file.**

CLAUDE.md already carries this exact meta-lesson, in the screenshot section:
"Numbers in prose rot. ... The directory listing is the count." That was
written about a stale shot count. It was true, it was general, and it did not
transfer, because it was filed under screenshots rather than under comments.

**Guard for the instance, SHIPPED, strongest tier, both halves proven.**
flutter/test/onboarding_test.dart:479, 'sample rows never cancel tonight's
nudge', failure quoted in fd43e25:

    Expected: true / Actual: <false>
    reason: 'the first night after saying yes must still be scheduled'

and the silent half at :516, 'a real log today still means no nudge tonight',
so the fix cannot be "never skip", which would nag someone who already logged.

**Guard for the class, NOT WRITTEN, and the honest assessment includes an
uncomfortable observation. NEW Open 18.** The fix added a THIRD counted comment
to the codebase. reminders.dart:103 now reads "This is the fourth reader of the
habit signal (chain, coach, quick-add are the others)". So the repository now
contains three prose counts of the same list, at sample_data.dart:15
(three, about RN), chain.dart:67 (three, about RN), and reminders.dart:103
(four, about Flutter), and all three go stale the moment a fifth reader
appears. Correcting a stale count by writing a fresher count is the same move
that failed, one iteration later.

Two things should happen and neither is done:

1. **Structural, medium strength, and ranked honestly as medium rather than
   strong.** Funnel the habit signal through one shared accessor in
   sample_data.dart, something like `Iterable<Map> habitRows(dynamic
   transactions)`, and have all four readers call it. That makes the correct
   path the default path, which is a real improvement over four independent
   remembering events. It is NOT strong, because nothing physically stops a
   fifth author reading `data['transactions']` directly, and an honest ranking
   has to say so. Cost, checked rather than assumed: three of the four call
   sites are a plain `continue` inside a loop and would collapse cleanly, but
   quickadd.dart:60 records `idx: i` as a stable-sort tie break into the
   ORIGINAL list, so a pre-filtered iterable changes what that index means.
   Relative order survives filtering, so the sort still behaves, but that needs
   checking rather than believing.
2. **Delete the numbers from all three comments** instead of updating them to
   four. "Sample rows never feed a habit feature" is the durable sentence. The
   count adds nothing except a false sense of completion.

The strongest complement, if someone wants an automated tier here, is a single
behavioural test over a store containing ONLY the seed, asserting that every
habit surface reports nothing logged: chain empty, coach still offering the
log-today nudge, quick-add chips empty, and tonight's reminder still scheduled.
That catches a regression in any of the four at once. It still says nothing
about a fifth reader nobody has written yet, and no test can.

**Lesson 3. The qa-tester merge gate found every defect in this round, twice in
a row now, against a fully green suite. This does not need a new guard. It
needs to be recorded as the rule working exactly as written.**

Evidence, and it is worth listing in full because "a QA pass ran" is the kind
of line that decays into ceremony if nobody ever writes down what it caught. On
PR #225 (session 9) it found the sample-account money trap. On PR #226 it found
all three user-facing untruths in this round plus the race:

- the payday promise the app could not keep,
- the cancelled first night,
- "No sounds" being false on Android, where the notification channel plays the
  default sound. Fixed by changing the sentence rather than the code, because
  silencing a channel properly is a native level change (Android locks channel
  settings after creation) and CLAUDE.md forbids claiming what cannot be
  backed,
- the permission race described in root cause 3.

880 tests were green at the time. Every one of those findings was invisible to
all 880.

**Guard: EXISTING, medium tier, and it FIRED.** The merge rules in CLAUDE.md
require a QA pass on the changed code with every must-fix finding fixed and
re-checked. Medium tier by this log's ranking, because it depends on someone
running it at the right moment. Two consecutive rounds in which the medium
guard caught what the strong guard missed is the argument for why the medium
tier is not decoration.

**Guard for the race instance, SHIPPED, strongest tier, both halves.**
flutter/lib/screens/onboarding.dart:82 to :89 adds an `asking` latch with the
reason at the site, both `_choice` calls pass null while it is set
(onboarding.dart:405 and :407), and onboarding_test.dart:555 drives it with a
`Completer` the test holds open, asserting 'the answers are inert until the
phone replies' and then that the yes still lands after the gate completes.

**Lesson 4. Tests that CHANGED this round, reported per the session 5
convention, and this time the answer is not "none". Two assertions were
defending the defect, and one test's NAME asserted it.**

This is the single strongest piece of evidence a retrospective in this project
can produce, so it is quoted exactly. In a10041e, six hours before the fix,
flutter/test/onboarding_test.dart contained:

    testWidgets('a granted yes turns the daily and payday reminders on', (
      tester,
    ) async {
      ...
      expect(notifs?['daily'], true);
      expect(notifs?['payday'], true);

and, in the restored-backup test:

      expect(notifs?['bills'], true, reason: 'their own choice survives');
      expect(notifs?['daily'], true);
      expect(notifs?['payday'], true);

In fd43e25 both had to be inverted before the fix could pass:

      expect(notifs?['payday'], isNot(true));
      expect(notifs?['payday'], isNot(true), reason: 'no schedule, no claim');

and the test was renamed from 'a granted yes turns the daily and payday
reminders on' to 'a granted yes turns the nightly reminder on'.

Read that plainly. The suite did not merely fail to notice the false promise.
It stated the false promise as the expected behaviour, in a test title, and
then passed on a real GitHub runner via the Flutter check. Anyone reading that
file to find out what the app does would have been told the wrong thing with a
green tick next to it. This is the exact failure mode CLAUDE.md's
prove-it-can-fail section already describes ("a test written from the same
wrong mental model as the code passes for the wrong reason and reads as
proof"), and it is its second recorded occurrence.

**Guard: EXISTING and already correct, no new guard proposed.** The
prove-it-can-fail rule cannot help here, because the wrong test WOULD have
failed if the code were broken. It was a faithful test of a wrong belief. The
only thing that catches a wrong belief is a different reader, which is Lesson
3's gate, and it caught it. What is added here is the record, because the value
of this observation is entirely in it being written down: three sessions from
now, "the tests were green" will have to be read alongside "and once they were
green because they agreed with the bug."

**Lesson 5. Session 9's Open 16 paid off within hours, and the assert caught a
real no-op. It still cannot be closed, because it lives nowhere but in this
file.**

Session 9 opened item 16 after `git checkout <file>` deleted a QA round's
uncommitted fixes: the rule was to reverse the exact edit instead, and to end
every restore by asserting the markers are back. This round every break and
restore did exactly that, and one of them failed loudly rather than silently:
the replace-back on flutter/lib/money/reminders.dart threw an AssertionError
because `dart format` had rewrapped the target line between the break and the
restore, so the text being replaced no longer existed byte for byte. A silent
no-op became a visible error, which is precisely what the assert was for. The
formatter-wrapped shape is still visible in the file at reminders.dart:110 to
:112, where the `loggedToday` expression is broken across three lines.

**Can Open 16 be closed? No, and the check was run rather than assumed.**
`grep -n "restore\|git checkout\|replace-back\|commit the fix" CLAUDE.md
.claude/skills/*/SKILL.md` returns only two unrelated hits, both about backup
and restore as a product feature. CLAUDE.md's "Prove a new test can fail before
trusting it" section says to break the code, watch it fail, and paste the
failure line into the commit message, and it says nothing whatsoever about
putting the code back. .claude/skills/systematic-debugging/SKILL.md covers
reproducing and fixing, not this.

So the state is: **a practice that worked twice, documented only in a
retrospective log that nothing forces anyone to read before breaking a file.**
That is the weak tier by this log's own ranking, and it stays weak until the
rule is written where it is read at the right moment.

**Guard, PROPOSED, medium tier if written, and NOT written by this session.**
Three sentences appended to CLAUDE.md's prove-it-can-fail section: commit the
fix first so `git checkout` is a correct restore by construction; if a break
must happen over uncommitted work, reverse the exact edit rather than checking
out; end every restore by asserting the markers are back, because the formatter
can move the bytes underneath you. This session does not edit CLAUDE.md, on
purpose. A lunch and learn agent writes its own log, and a change to the
project's standing rules belongs to the founder or to a session with the
mandate for it. **Open 16 stays open, with the exact text now named so closing
it is a one paragraph edit.**

**Lesson 6. The standing CLAUDE.md fact check found a false claim that five
consecutive sessions missed, in the section about looking at screens.**

The mechanical half first, and it is boring, which is the correct outcome.
`git log a822666f..origin/main -- .github/workflows/ CLAUDE.md` returns
nothing, so neither CLAUDE.md nor any workflow changed since session 9's ground
truth. Re-verified by reading anyway:

- Every path CLAUDE.md names exists where it says: flutter/shorebird.yaml,
  flutter/test/update_stamp_test.dart, flutter/test/screens_shot.dart,
  flutter/lib/widgets/salapify_icon.dart, flutter/lib/main.dart,
  docs/delivery-log.md, mobile/app/(tabs)/more.js.
- All five skills exist in .claude/skills (brainstorming, flutter-ui-polish,
  porting-money-logic, systematic-debugging, writing-skills).
- mobile/lib/storage.js:9 still holds `salapify_data_v2`.
- The 120 character stamp cap is live at update_stamp_test.dart:20.
- flutter-check.yml triggers on `claude/**` with no paths filter;
  flutter-preview.yml triggers on `main` with paths `flutter/**` plus its own
  definition. Both match rule 1 word for word.
- The three delivery commands ran as written and returned f2.69 patch 19.

**The false claim. CLAUDE.md:62 to :63 says:**

    It renders every tab, a lesson, and the diagnostics dialog, at BOTH
    brightnesses. Look at the dark ones first; that is what the founder uses.

Every tab: TRUE. flutter/test/screens_shot.dart:228 loops seven screens over
`[Brightness.light, Brightness.dark]` and `shoot` writes `shots/$name-$suffix
.png` at :205.

A lesson: FALSE. The lesson shot is dark only, hardcoded at
screens_shot.dart:979 as `shots/lesson-dark.png`, preceded by an explicit
`Barako.current = Barako.currentTheme.resolve(Brightness.dark)` at :965.

The diagnostics dialog: FALSE. Same shape, `shots/diagnostics-dark.png` at
:663, dark forced at :644.

Counted from the file rather than from the sentence: 23 `expectLater` sites,
of which 14 are the tab sweep across both brightnesses, 2 are the onboarding
welcome across both, and the remaining 7 named shots plus the rest of the walk
are dark only.

**And it was false the day it was written.** `git log -S "at BOTH brightnesses"
-- CLAUDE.md` points at b949f2a, the session 4 write-up commit, and
`git show b949f2a:flutter/test/screens_shot.dart` already has
`shots/diagnostics-dark.png` at line 209 and `shots/lesson-dark.png` at line
241, both hardcoded. This was never a rule that went stale. It was wrong on
arrival, and it has been read with authority through sessions 5, 6, 7, 8 and 9,
every one of which ran this fact check and reported no false claim. Session 9
wrote "No new false claim found this session. That is the second session in a
row without one."

Why it matters, beyond the tally. Session 6's entire subject was a bug that
only light mode could see, live on the founder's phone for 92 minutes. The
sentence that tells the next person the harness covers both brightnesses is
the sentence that would stop them checking. For a lesson screen and for the
diagnostics dialog there is no light render to look at second, and the file
says there is.

Why no checker would have caught it: every noun in the sentence is real. There
IS a lesson shot. There IS a diagnostics shot. There ARE both brightnesses in
the file. This is the third consecutive false-claim finding of the same
character, after session 7's trigger rule and session 8's moved file. All three
named real things and got the relationship between them wrong.

**Guard: NOT WRITTEN, and the correction is one line. NEW Open 19.** The
truthful version is "It renders every tab at BOTH brightnesses, plus a lesson,
the diagnostics dialog, the sheets and the onboarding walk in dark." Better
still, and consistent with the paragraph three lines below it that already says
numbers in prose rot, name no coverage at all and point at the directory:
`ls flutter/test/shots/` is the coverage, the same way the directory listing is
already the count. This session does not edit CLAUDE.md, for the reason given
in Lesson 5.

### Open lessons carried forward

**Open 3, nothing compares the phone to main: STILL OPEN, by design.** The
founder confirmed f2.69 in person, which remains the only proof that counts and
the one thing only the founder can do.

**Open 6, the watchdog has never been observed running a scheduled pass: STILL
OPEN.** Run history is unreadable from this sandbox and `gh` is not installed
here. No spurious issue in evidence, and this round's gap was well inside the
2700 second grace.

**Open 7, the watchdog blind spot for merges that do not bump the stamp: STILL
OPEN.** Not exercised, the merge bumped the stamp.

**Open 8, split the publish step from the log scraping: STILL OPEN,**
re-verified by reading, the scrape is still inside the ship step with `|| true`
at flutter-preview.yml:127 and the comment at :112 explaining that its absence
once cost a whole delivery.

**Open 9, FAILED rows in docs/delivery-log.md: STILL OPEN.** No new
archaeology case this round.

**Open 10, nothing holds Pan's rendered size: STILL OPEN.**

**Open 11, nothing stops a sixth private kicker: STILL OPEN.**

**Open 13, the shot harness mounts screens through a private copy of the
shell's wiring: STILL OPEN.** The onboarding walk still builds its own
MaterialApp by hand at screens_shot.dart:866.

**Open 14, CLAUDE.md workflow item 4 versus the eas-update trigger: STILL
OPEN, untouched, re-verified.** eas-update.yml:18 still triggers only on
`claude/salapify-v2`, a branch retired in cf5c6a7. Harm today: none, and in the
safe direction. Harm the day RN work resumes: someone believes publishing is
automatic and it is not.

**Open 15, the walk-keying and frame-asserting rule: MATERIALLY ADVANCED, still
open, and the honest measurement is unflattering.** Session 9 named two tiers.
The STRONG one now exists: a10041e added an assertion before every shot in the
onboarding walk (screens_shot.dart:871, :880, :891, :902) with the reason
recorded at :887 to :889, "A shot named for one step that renders another is
the exact failure this walk already had once, and a name is not evidence."
Measured coverage: 4 of 23 `expectLater` sites assert what is in front of the
camera, and all four are in the one walk that already had the bug. The MEDIUM
tier is still not done: the screens_shot.dart header (lines 1 to 24) still
records exactly three hard-won harness rules, and neither keying repeated
pumps nor asserting the frame is one of them.

**Open 16, prove-it-fails says how to break the code and not how to restore it:
STILL OPEN, and see Lesson 5 for why the practice working perfectly is not the
same as the rule existing.** The exact three sentences that would close it are
now written down above.

**NEW Open 17: nothing generalises the payday guard.** A test asserting that
every notifications key onboarding can write is one `plannedReminders` can
actually act on. Needs either title matching or a `kind` field on
`PlannedReminder`. Minutes of work, not written because flutter/ is occupied.

**NEW Open 18: the habit signal has four independent remembering events and
three prose counts of itself.** One shared accessor in sample_data.dart plus
deleting the counts from sample_data.dart:15, chain.dart:67 and
reminders.dart:103. Medium strength when done, and it should be called medium.

**NEW Open 19: CLAUDE.md:62 to :63 claims a lesson and the diagnostics dialog
render at both brightnesses, and both are dark only.** False since b949f2a.
One line to correct, and the better correction removes the coverage claim
entirely in favour of the directory listing.

**NEW Open 20: mobile/lib/notifications.js:100 has the same sample-row defect
Flutter just fixed, and nothing guards it.** `loggedToday` there does not
exclude `SAMPLE_TX_IDS`, and RN seeds its sample data on first run rather than
on request. Not fixed here: mobile/ is the shippable app and this session's
scope was the Flutter round. Flagged because the comment that cited RN as the
authority for completeness is pointing at code that is incomplete in exactly
the place Flutter just repaired.

### Guard status re-check

Read, not assumed. `git log a822666f..origin/main -- .github/workflows/
CLAUDE.md` proves no workflow and no CLAUDE.md line changed since session 9, so
every line number that entry recorded still stands. Verified by reading anyway,
because a guard quietly routed around is the most valuable thing this section
can find:

- The duplicate stamp refusal: PRESENT, flutter-preview.yml:173 to :181,
  including the comment explaining why it fails AFTER the publish. Correctly
  silent, the stamp was distinct.
- The `|| true` scrape guard: PRESENT, flutter-preview.yml:127.
- The nothing-shipped failure issue: PRESENT, flutter-preview.yml:221 onward.
  Not fired, correctly.
- The release install shout: PRESENT, flutter-preview.yml:249. Correctly
  silent, the row reads mode `patch`.
- The publisher watching its own definition: PRESENT in the paths filter.
- The delivery watchdog's `--first-parent` and 2700 second grace: PRESENT,
  delivery-watchdog.yml:99 and :43, with the load-bearing comments intact.
- flutter-check.yml on `claude/**` with NO paths filter: PRESENT, with its
  header explaining that this exists because thirteen stamps of work once never
  reached the phone.
- The stamp cap: PRESENT, update_stamp_test.dart:20, and the live stamp is 78
  characters.
- Session 6 and 7 guards (a11y_test.dart, nav_ambiguity_test.dart, the injected
  clock, header_action_test.dart, app_harness.dart): PRESENT.
- Session 8's guards: PRESENT and untouched.
- Session 9's new guards: PRESENT. onboarding_test.dart's 'the QA round' group
  is still there at :565 onward with the sample-account funnel tests intact,
  and the keyed onboarding walk survives at screens_shot.dart:858, now with
  frame assertions added around it.
- New this round for the next session to re-check: onboarding_test.dart's 'the
  nudge QA round' group (:426 to :562, four tests, each proven failing first),
  the `asking` latch at onboarding.dart:82, and the sample exclusion at
  reminders.dart:112.

**Nothing was found deleted, disabled, or routed around.** One guard was found
to have been narrower than the documentation claimed from the day the
documentation was written, which is Open 19, and that is a documentation
failure rather than a routed-around guard.

### What it cost, and what it did not

Cost: three user-facing untruths and one race written into a branch, all caught
before the merge. One test suite that spent six hours certifying a false
promise by name. One restore that failed loudly and cost a minute. Two sessions
in a row without an independently re-run suite baseline. One CLAUDE.md sentence
that has been misleading readers since session 4 and was found only because
this check is run as a step rather than as a favour.

Did not cost: any delivery failure, any wrong number on the phone, any manual
install, any lost user data, any founder-found bug. One delivery, one row, one
confirmation, 11 minutes 50 seconds.

### For the founder, in plain English

f2.69 is on your phone and you confirmed it: new users now get asked, once,
whether they want one quiet 8pm reminder, and either answer is fine. Just under
twelve minutes from merge to arrival, which is the normal rhythm. Delivery went
perfectly and I am not going to invent a problem to make this write-up feel
earned.

Three things are worth your lunch.

**One: the app promised you something it had already decided not to do.** When
I rebuild a screen from the old app into the new one, I move two things: the
code, and the words on the screen. I move the code carefully, function by
function, and I check the numbers match. I move the words by reading them and
retyping them, and it feels like the easy part.

The old app's reminder screen said "one quiet reminder at 8pm, plus a heads up
on payday". I copied that sentence. But the new app has a deliberate rule the
old app does not have: it will never send you a "it is payday today" alert
unless you have actually told it when payday is. That rule exists because the
old app guesses, it assumes the 15th and the end of the month, and it sends
that alert on a guessed day to people who never told it anything. A push
notification claiming today is payday is either true or a lie, so we stopped
guessing.

So the sentence was true in the old app only because the old app has a fault we
fixed. A brand new user has never set a payday, which means the promise could
never be kept. Worse, the app also switched ON a "payday reminders" toggle in
Menu that could never ring. You would have seen a switch sitting on, doing
nothing, forever.

It is fixed. The sentence now promises the 8pm nudge and nothing else, the
toggle is only switched on for someone who genuinely has a payday saved, and
there is a test that fails loudly if either of those ever slips. The lesson I
have written down is bigger than this one sentence: **words on a screen are a
promise about behaviour, so when I change behaviour on purpose, the words that
came with it are now wrong.** I have a careful checklist for moving code and I
had none for moving words.

**Two: a comment counted to three, and there were four.** There is a rule in
this app that the demo data you can choose to explore must never be treated as
real activity. Otherwise the app congratulates you for a streak you did not
earn, or worse, thinks you already logged today when you have not.

A comment in the code recorded that rule and said it was honoured in three
places. That was accurate about the OLD app. In the new app there were four
places, and the fourth was the reminders. So a new user who said yes to the
nightly nudge and then tapped "explore the sample data" had their first night's
reminder silently cancelled, because the demo data contains an entry dated
today, and the app thought that was them. On the very first night, which is the
night the habit is most fragile. That happened on any install day from the 1st
to the 10th of the month.

Fixed, with a test on both sides: the first night is still scheduled, and a
real entry today still cancels it, because a reminder nagging you about
something you already did is its own kind of broken.

The interesting part is why the comment fooled anyone. The number three read
like a finished job. If it had just said "demo rows never count as real
activity" with no number, the next person would have gone and checked. **A
count in a comment is a receipt, and receipts go out of date.** I already had
that exact lesson written down about something else, filed in the wrong place,
so it did not help. It is now filed here too.

**Three: my own tests were on the bug's side.** This is the uncomfortable one
and it is the most useful thing in this write-up. When I built the reminder
step, I wrote tests for it. One of them was literally called "a granted yes
turns the daily and payday reminders on", and it checked that the payday
setting was switched on. It passed. It passed on a real build machine.

That test was wrong. It was a faithful, careful, correctly written test of a
false belief, because I wrote the test and the code in the same sitting from
the same understanding. To fix the bug I had to invert that check and rename
the test. Anyone reading that file to learn what the app does would have been
told the wrong thing with a green tick beside it.

Nothing about testing harder fixes that. The only thing that finds a wrong
belief is a second reader with a different one, and that is the quality review
pass we made a rule in July, where I go back over the changed code trying to
break it rather than trying to confirm it. That review found all three of these
problems plus a fourth I have not described (tapping "No thanks" at the exact
moment the phone's permission popup appeared could have flipped your no into a
yes). It found them while 880 tests were green. That is two rounds in a row
where the review caught everything and the tests caught nothing.

**One more, briefly, because it is about honesty rather than bugs.** Part of
every one of these sessions is re-reading the project's own rulebook and
checking its factual claims against the code. This time I found a sentence that
has been wrong since the day it was written, four days ago: it says my
screenshot tool photographs a lesson and the diagnostics screen in both light
and dark mode. It only ever did dark for those two. Five sessions ran this same
check and reported the rulebook clean. That matters because the whole reason we
take screenshots in both modes is that a real bug once shipped to your phone
that was invisible in dark mode and clearly broken in light. A sentence that
tells me a check is already covered is a sentence that stops me looking. I have
not edited the rulebook myself, deliberately, because standing rules are yours
to change. I have written down the exact one line correction.

**What it costs if these guards are removed.** Take out the payday test and the
app goes back to promising notifications it cannot send, which is the fastest
way to make someone stop trusting an app about money. Take out the demo data
test and new users lose their first night's reminder on the night it matters
most, silently, with everything green. Take out the quality review pass and you
are relying on tests written by the same mind that wrote the bug, which this
round proved does not work. And if the rulebook keeps a sentence claiming a
check exists when it does not, it is worse than saying nothing at all, because
it is read with authority.

---

## 2026-07-28, session 9: the welcome screen that was photographed on step two

Two deliveries, two clean rows, both confirmed on the phone by the founder.
There is no delivery incident in this entry and none is manufactured. What
this session has instead is the strongest thing a clean round can produce:
three defects that never reached the phone, each caught by a different kind
of check, and one of them was a defect in a checking tool itself.

### What we believed / What was true

**Believed: both patches reached the phone. TRUE, and confirmed in person,
twice.** Read from `git show origin/main:docs/delivery-log.md`: f2.67 patch
17 at 02:29 UTC (run 30322704978, merge 1a0c9930) and f2.68 patch 18 at 03:42
UTC (run 30326108991, merge a822666f). Both mode `patch`, both on 0.6.2+11,
and `git show origin/main:flutter/pubspec.yaml` still reads `version:
0.6.2+11`, so no base APK was stranded and no manual install is owed. Merge
to row: 11 minutes and 12 minutes, inside the norm every session since 4 has
measured. The founder read both stamps off the Update stamp row. Say it
plainly: the delivery pipeline was boring in both directions, which is the
only thing a delivery pipeline should ever be.

**Believed: merge #223 shipped nothing, and its absence from the log is the
system working. TRUE.** That merge (7744e08, 01:34 UTC) was the session 8
write-up, documentation only. The publisher's paths filter correctly stayed
silent, so there is no row between patch 16 and patch 17, and by session 5's
reading rule that gap is benign rather than an incident.

**Believed, by the render discipline: a shot named `onboarding-welcome-light`
photographed the welcome screen. FALSE. It photographed step 2.** The
onboarding walk in flutter/test/screens_shot.dart shoots dark first, taps
through all three steps, then loops to light and shoots the welcome again.
`pumpWidget` reuses the existing `State` object when the widget type and its
position in the tree both match, so the `step` field survived from the end of
the dark walk into the first light frame. The file named it welcome. The
image showed the currency and budget step. Nothing failed, nothing warned,
and 868 passing tests had no opinion, because a screen rendering a valid step
is a valid widget tree. It was caught by opening the PNG and looking at it.

**Believed: the designed happy path was safe because every new test passed.
FALSE, and this one was a money trap.** The onboarding flow's own recommended
route (explore the sample data, then the shell auto-opens the first log sheet)
preselected the sample account "BPI Savings", because `lastUsedAccountId`
derived the most recent account from the only transactions that existed at
that moment, the seeded ones. A brand new user's first REAL entries would
have been filed into a fictional account, and "Remove sample data" then
deleted that account from under them, silently losing the balance effect. All
fourteen new onboarding tests passed while this was live in the branch. It
was found by the qa-tester merge-gate pass, not by the suite.

**Believed, for about a minute: a restore had put the code back. FALSE, it
had thrown work away.** During the prove-it-fails run for the quick-add
guard, the restore step used `git checkout lib/money/quickadd.dart`. That
restores the last COMMIT, not the pre-break state, and the QA fixes were
still uncommitted, so it wiped them. It was caught immediately only because
the same command printed a `grep` count of the fix markers straight
afterwards, and the count came back 0.

### Timeline (with evidence)

All times UTC, from `git log --format=%cI` and the publisher's own rows.

| Time | Event | Evidence |
|------|-------|----------|
| Jul 28 01:16 | f2.66 patch 16 delivered, session 8's ground truth | delivery row |
| 01:34 | Merge #223 (7744e08), the session 8 write-up, docs only. No row, correctly | paths filter, no row in log |
| 02:10 | 634b8d5 Phase 3 batch 1, the currency setting. One resolved symbol read by every formatter, defaulting to the peso so all 848 prior tests see zero change. Guard proven failing first by severing the resolve | commit message |
| 02:17 | Merge #224 (1a0c9930) | git log |
| 02:29 | f2.67 patch 17 delivered, 11 minutes | delivery row |
| 02:46 | a9c152e Phase 3 batch 2, the onboarding flow. **The lying screenshot is found by looking, and fixed inside this same commit** | screens_shot.dart:850 to 857 |
| 03:23 | 63f5b19 QA round. **The sample account funnel found by qa-tester and fixed**, guard proven failing | commit message |
| 03:30 | Merge #225 (a822666f) | git log |
| 03:42 | f2.68 patch 18 delivered, 12 minutes | delivery row |
| after | **Founder confirms BOTH f2.67 patch 17 and f2.68 patch 18 on the phone** | founder |

Test counts, and an honest note about them. The commits record 854 green
after batch 1, 868 after batch 2, and 875 after the QA round, each with
analyze clean. Unlike every session since 6, this entry does NOT quote a
suite run made while writing it: another task is editing flutter/ at this
moment, so a run now would measure a half-edited tree and report a number
about nothing. Quoting the commits and saying why is better than running
something that cannot mean what it claims. The next session should re-run and
confirm 875 as its baseline.

### Divergence point

There is no delivery divergence to name this round, and that is the finding,
not a gap in the investigation. Both stamps built, both shipped, both rows
were written, both matched the phone.

The belief divergence worth naming is inside the branch: **02:46 UTC, in the
authoring of a9c152e**, the moment the onboarding walk was written as one
`testWidgets` loop over two brightnesses with a single `pumpWidget` per
iteration. From that moment the harness produced an image whose FILENAME and
CONTENT disagreed. It never reached main, because the divergence and its
closure are inside the same commit: the fix, the `ValueKey(b.name)` at
screens_shot.dart:857, is in the same diff as the bug.

Name the shape, because this is now its fourth consecutive appearance in this
log: **a checking tool that verifies a stand-in for the artifact.** Session 6,
a dark-first eye that structurally could not see light mode. Session 7, a shot
harness mounting less chrome than production. Session 8, a text replace that
performed a stand-in for the action and matched zero bytes. Session 9, a
camera that photographed leftover state while labelling it fresh. Three of
those four were only detectable by measuring or looking at the actual output.
The difference this time, and it is worth the sentence: the render caught the
render. The discipline turned on itself and won, before the merge.

### Root cause

**The lying screenshot.** Flutter's element tree reuses `State` when the
widget's runtime type and slot both match across a `pumpWidget`. That is not
a bug, it is the mechanism that makes hot reload and rebuilds cheap, and it
is documented. The harness's mental model was "each `pumpWidget` gives me a
fresh screen", which is true for every other shot in the file because every
other shot pumps a DIFFERENT widget type. The onboarding walk was the first
shot that pumps the SAME type twice in one test, so it was the first place
the assumption could be wrong, and it was wrong the first time it was used.
The root cause is not the reuse and it is not inattention. It is that the
harness names a file after a state it never asserts it is in. A shot
function that photographs whatever is on screen and trusts its own caller for
the label can only ever be as correct as the caller's mental model.

**The sample account funnel.** Every test in the onboarding batch was written
by the same author, at the same sitting, from the same mental model as the
code. That model contained the sentence "sample data is clearly marked and
removable", and it was true, so the tests proved it. The model did not
contain the sentence "the sample rows are the only rows, therefore they are
also the most RECENT rows, therefore every helper that means recent means
sample". `lastUsedAccountId` is a pure, correct, well-tested function; it did
exactly what it says. The defect lived in the composition of three correct
parts: seed sample data, auto-open the log sheet, preselect the last used
account. No unit test can see a composition, and no author who holds the
model can see its own gap. That is precisely what an adversarial reader with
a different frame is for, and it is why the qa-tester pass is a merge gate in
CLAUDE.md rather than an optional courtesy.

**The destructive restore.** `git checkout <file>` restores from the index or
the last commit. The prove-it-fails discipline in CLAUDE.md says to break the
code, watch it fail, and quote the failure, and it says nothing whatsoever
about how to put the code back. The break happened at a moment when the fix
was deliberately not yet committed, which is the normal state during a QA
round: fix, then prove the fix. So the safest-feeling restore command was
exactly the wrong one, and it was wrong for a reason that is invisible unless
you are thinking about the index at that second. The rule had a hole in the
half nobody wrote down.

### Lessons and guards

**Lesson 1. A shot harness that pumps the same widget type twice renders
leftover state while claiming a fresh screen, and only LOOKING at the image
catches it.**

**Guard, SHIPPED for the instance, MEDIUM.** The walk is now keyed per
brightness, `OnboardingScreen(key: ValueKey(b.name), store: store)` at
flutter/test/screens_shot.dart:857, with the reason recorded immediately
above it at lines 850 to 853:

    // Keyed per brightness. Without this the second pump reuses the first
    // iteration's State (same widget type, same slot), so the "welcome"
    // shot silently rendered whatever step the previous walk ended on.
    // The first light render proved it by photographing step 2.

That comment fixes this walk and explains itself at the site, which is the
right place for it. It is medium rather than strong because it guards one
loop, not the class.

**The class is NOT guarded, and the candidate rule is not where it would be
read. Checked, and reporting the result honestly:** the header comment of
screens_shot.dart (lines 1 to 24) records three hard-won harness rules, the
deliberate non-`_test` filename, the `tester.runAsync` font gotcha, and where
the output lands. It does NOT mention keying repeated pumps. So the next
person writing a walk-style shot reads the header, learns three lessons, and
does not learn this one. **New Open 15.**

**The strongest available version of this guard, which does not exist yet and
should:** the shot function asserts the frame it is about to photograph. One
line before each `expectLater`, for example `expect(find.text('Get started'),
findsOneWidget)` before the welcome shot, converts a mislabelled image from a
silent wrong picture into a hard failure. That is the automated tier, it
works while nobody is looking at the PNGs, and it is the direct answer to a
harness that names files after states it never checks. It is not written,
because flutter/ is being edited by another task as this is written. It
should be the first thing the next session does.

**Lesson 2. Every new test in a batch is written from the same mental model
as the code, so a clean suite is evidence about the model, not about the
product. Only a reader with a different frame sees a composition defect.**

**Guard, EXISTING, and it FIRED: the qa-tester merge gate in CLAUDE.md.** The
merge rules require a QA pass on changed code with every must-fix findings
fixed and re-checked. This round it earned its whole existence: it found a
must-fix that funnels a new user's first real money into an account the app
then deletes, plus two should-fixes (sample debt payments surviving removal
and feeding the month recap as real money forever, and `startFresh` leaving
`firstRun` alone so erasing everything only returned to onboarding after a
restart). It is a rule tied to a specific moment, the merge, which is the
medium tier by this log's ranking, and today is the argument for why the
medium tier is worth keeping: the strong tier, the tests, was fully green and
wrong.

**Guard for the finding itself, SHIPPED, strongest tier, proven failing
first.** flutter/test/onboarding_test.dart, group 'the QA round', asserts
`lastUsedAccountId` returns null both for a store containing only the seed
and for a store where a REAL transaction points at a sample account
(onboarding_test.dart:287 to 309). The failure it was born catching is quoted
in 63f5b19:

    Expected: null / Actual: 'sample_bpi'

Two layers, both guarded, and the second layer is the interesting one:
skipping sample ROWS alone would still have preselected a sample ACCOUNT once
a real transaction pointed at one, so the fix at
flutter/lib/money/quickadd.dart also refuses any sample account id outright,
with the reasoning at the line: "preselection is an invitation to keep going."

**Lesson 3. While uncommitted work exists, `git checkout <file>` is not a
restore, it is a delete, and the prove-it-fails rule never said how to put
the code back.**

**Guard, PRACTICE for now, and ranked weak, honestly.** Two halves, and the
first is structural enough to be worth doing:

1. Order of operations, which makes the hazard impossible rather than
   discouraged: COMMIT the fix, then break, then restore. If the fix is in
   the last commit, `git checkout <file>` is a correct restore by
   construction, and the whole class of mistake stops existing. This costs
   nothing, since the fix is going to be committed anyway.
2. If a break must happen over uncommitted work, reverse the exact edit
   (the python replace-back pattern used elsewhere in this project), never
   `git checkout`, and end every restore by asserting the fix markers are
   still present. The assertion is what actually saved the work this time,
   and it saved it by accident of habit rather than by rule.

This is weak tier because it lives in discipline, and it is weak for the same
reason session 8's Lesson 1 prevention half was: the break and restore are
done by session tooling, not by a committed script, so there is nothing to
put an assert inside. If prove-it-fails is ever committed as a script, both
halves go in it and get proven by breaking it. **New Open 16.** Recorded
without softening: the cost of this staying weak is that a QA round's worth
of uncommitted fixes is one command away from gone, and the only thing that
caught it was a `grep` count that happened to be in the same line.

**Lesson 4. The one-seam pattern paid out a third time, and it does not need
a new guard, it needs to be named so it keeps being chosen.**

The onboarding gate changed what an empty boot shows: with nothing stored,
the app now correctly lands on the welcome flow rather than the shell, which
broke every full-app test that booted with `SharedPreferences.
setMockInitialValues({})`. The fix was ONE helper, `onboardedEmptyStorage()`
at flutter/test/support/app_harness.dart:42, twenty lines including the
reason, plus a one-line fixture swap at each call site. Measured, not
estimated: 29 call sites across 26 test files, and `git show a9c152e
--numstat` shows twenty five of those files changed by exactly one or two
lines each. No assertion in any of them changed.

This is the same seam that absorbed Menu moving off the bottom bar in session
6 (`openMenu`, a two line change instead of edits across 24 files) and the
same shape whose ABSENCE cost session 7 its blind screenshots. Three data
points now: when a behaviour that every test depends on changes, the cost is
paid once at a seam or twenty five times at the call sites, and which one
happens is decided months earlier by whether the seam exists. No guard, this
is a design habit with an evidence trail.

**Lesson 5. Tests that changed this round, reported per the session 5
convention. None was defending a bug, and this was checked rather than
assumed.** The QA commit 63f5b19 deleted nothing at all from
onboarding_test.dart; it is 228 lines of pure addition. The batch commit
a9c152e's changes to twenty five existing test files are, without exception,
the single fixture line `SharedPreferences.setMockInitialValues({})` becoming
`SharedPreferences.setMockInitialValues(onboardedEmptyStorage())`, verified
by reading the diffs. No assertion was inverted, removed, or loosened, and
nothing had to change for a fix to pass. Saying so explicitly is the
convention, and it matters here because a batch that touches twenty five test
files is exactly the shape under which an inverted assertion would hide.

**Lesson 6. CLAUDE.md fact check, run as a step, with the result reported
even though the result is mostly boring.**

`git log c3d1032..origin/main -- .github/workflows/ CLAUDE.md` returns
nothing, so neither CLAUDE.md nor any workflow file changed since session 8's
ground truth. The check therefore reduces to re-verifying standing factual
claims against the repository, which was done by reading:

- Every path the file names exists where it says: flutter/shorebird.yaml,
  flutter/test/update_stamp_test.dart, flutter/test/screens_shot.dart,
  flutter/lib/widgets/salapify_icon.dart, flutter/lib/main.dart,
  docs/delivery-log.md, mobile/app/(tabs)/more.js.
- All five skills exist in .claude/skills (brainstorming, flutter-ui-polish,
  porting-money-logic, systematic-debugging, writing-skills).
- mobile/lib/storage.js:9 still holds `salapify_data_v2`.
- The 120 character stamp cap is enforced at update_stamp_test.dart:20, and
  the live stamp is comfortably inside it.
- flutter-check.yml triggers on `claude/**` with no paths filter, and
  flutter-preview.yml triggers on `main` with paths `flutter/**` plus its own
  definition. Both match what rule 1 claims, word for word.
- The three delivery commands ran as written and returned f2.68 patch 18.

**No new false claim found this session.** That is the second session in a
row without one, after the streak of five. The one known stale claim is
unchanged and stays **Open 14**: workflow item 4 says every push to the branch
touching mobile/ triggers the OTA publish, while eas-update.yml:18 still
triggers only on `claude/salapify-v2`, a branch that no longer exists. Harm
today: still none, still in the safe direction. Harm the day RN work resumes:
someone believes publishing is automatic and it is not.

### Open lessons carried forward

**Open 3, nothing compares the phone to main: STILL OPEN, by design.** The
founder confirmed both stamps in person, which is the only proof that counts
and the one thing only the founder can do.

**Open 6, the watchdog has never been observed running a scheduled pass:
STILL OPEN.** Run history remains unreadable from this sandbox. No spurious
issue in evidence, and both of this round's gaps were well inside the 2700
second grace.

**Open 7, the watchdog blind spot for merges that do not bump the stamp:
STILL OPEN.** Not exercised this round, both merges bumped the stamp.

**Open 8, split the publish step from the log scraping: STILL OPEN,**
re-verified by reading, the scrape still lives inside the ship step with
`|| true` intact at flutter-preview.yml:127 and its comment explaining that
its absence once cost a whole delivery.

**Open 9, FAILED rows in docs/delivery-log.md: STILL OPEN.** No new
archaeology case this round, but the patch 10 to 12 jump from session 8 is
now permanently in the file with no explanation inside the file itself.

**Open 10, nothing holds Pan's rendered size: STILL OPEN.**

**Open 11, nothing stops a sixth private kicker: STILL OPEN.**

**Open 13, the shot harness mounts screens through a private copy of the
shell's wiring: STILL OPEN, and this session is a second data point against
the copy.** The onboarding walk builds its own MaterialApp by hand, which is
exactly why the State reuse was possible and invisible. The harness keeps
producing correct-looking output from hand-assembled scaffolding, and the
automated version, mounting through the shell or asserting what is on screen,
still does not exist.

**Open 14, CLAUDE.md workflow item 4 versus the eas-update trigger: STILL
OPEN, untouched, re-verified this session.**

**NEW Open 15: the walk-keying rule is not in the screens_shot.dart header.**
The header records three harness rules learned the hard way; this is a
fourth, and it currently lives only as an inline comment on the one loop that
has it. Two tiers available and neither is done: the strong one is asserting
the expected frame before each shot, the medium one is a line in the header.
The strong one should be preferred, because a header comment only works on a
person who reads it before writing the bug.

**NEW Open 16: prove-it-fails says how to break the code and not how to
restore it.** Today that gap deleted a QA round's uncommitted fixes and was
caught by a habit rather than a rule. The cheap structural answer is to
commit the fix before breaking anything. Not written down anywhere yet.

### Guard status re-check

Read, not assumed, and this session's version is cheap and honest: `git log`
proves no workflow file and no CLAUDE.md line changed since session 8, so
every line number that session recorded still stands. Verified by reading
anyway, because a guard that was quietly routed around is the most valuable
thing this section can find:

- The duplicate stamp refusal: PRESENT, flutter-preview.yml:174 to 181,
  comment and all, including the sentence explaining why it fails AFTER the
  publish. Correctly silent this round, both stamps were distinct.
- The `|| true` scrape guard: PRESENT, flutter-preview.yml:127.
- The nothing-shipped failure issue: PRESENT, flutter-preview.yml:223 to 237,
  one issue commented on rather than duplicated. Not fired, correctly.
- The release install shout: PRESENT, flutter-preview.yml:239 onward.
  Correctly silent, both rows read mode `patch`.
- The publisher watching its own definition: PRESENT in the paths filter.
- Concurrency `cancel-in-progress: false`: PRESENT.
- The delivery watchdog's `--first-parent` and 2700 second grace: PRESENT,
  delivery-watchdog.yml:43 and :99, with the load-bearing comment intact.
- flutter-check.yml on `claude/**` with NO paths filter: PRESENT, with the
  comment explaining that a skipped check reads as approval at a glance.
- The stamp cap: PRESENT, update_stamp_test.dart:20.
- Session 6 and 7 guards (a11y_test.dart with the Menu sweep floor,
  nav_ambiguity_test.dart, the injected clock, header_action_test.dart,
  app_harness.dart): PRESENT. app_harness.dart absorbed this round's
  twenty five file change exactly as it was designed to, which is the third
  time that seam has paid.
- Session 8's guards: PRESENT and untouched.
- New this round for the next session to re-check:
  flutter/test/onboarding_test.dart (the 'QA round' group, seven new tests
  per 63f5b19, the sample account funnel proven failing first), flutter/test/currency_test.dart
  (the resolved symbol, proven failing by severing the resolve), and the
  keyed onboarding walk at screens_shot.dart:857.

**Nothing was found deleted, disabled, or routed around.**

### What it cost, and what it did not

Cost: one screenshot round spent looking at an image that was not what its
name said, which is cheap only because someone looked. One near miss on
uncommitted QA fixes, recovered in under a minute because a `grep` count
happened to be attached to the restore. One suite count in this entry that is
quoted rather than re-run, with the reason stated.

Did not cost: any delivery failure, any wrong number on the phone, any manual
install, any lost user data, any founder-found bug. Two deliveries, two rows,
two confirmations, eleven and twelve minutes. And the money trap that would
have been the expensive one, a new user's first real entries vanishing into a
deleted sample account, was caught before the merge by the gate that exists
for exactly that, on a path the design itself recommends, which is the path a
beginner is most likely to take.

### For the founder, in plain English

Both updates are on your phone and you confirmed both: f2.67, the currency
setting, and f2.68, the new welcome flow for first-time users. Eleven and
twelve minutes from merge to arrival, which is the normal rhythm. Nothing
went wrong with delivery this time, and I am not going to invent a problem to
make this write-up feel earned.

What is worth your time is three things that were caught before they reached
you.

**One: my camera photographed the wrong screen.** I take screenshots of every
screen before shipping it, and for the new welcome flow I take them twice,
once in dark mode and once in light. The picture labelled "welcome, light
mode" was actually a picture of the second step. The reason is a quirk of how
Flutter works: when you ask it to build the same kind of screen a second time,
it reuses the machinery from the first one to save effort, including the
memory of which step you were on. So the second run started where the first
run finished, and the file name was a claim nobody had checked. Nothing
failed. All 868 tests passed, because a real screen was on the screen; it was
just the wrong one. The only thing that caught it was opening the image and
looking at it. That is the second time in three days that looking at a picture
found something the tests could not, and this time the picture found a fault
in my own camera.

It is fixed for this flow. I have written down, honestly, that it is not fixed
for the NEXT flow anyone builds, and I have said what the real fix is: the
camera should check that the right screen is in front of it before it presses
the shutter, instead of trusting the label. That is a small piece of work and
it should be done next.

**Two: the friendliest path through the new welcome flow had a money trap in
it, and every test said it was fine.** If a new user chose "explore the sample
data first", the app opened a logging box for them straight away, helpfully
pre-filled with the account they had "last used". Except the only transactions
in existence at that moment were the fake sample ones, so it pre-filled a fake
account called BPI Savings. Their first REAL expense would go into a made-up
account, and when they later tapped "Remove sample data", that account
disappeared and took the effect on their balance with it. Quietly. No error,
no warning.

Every single test I wrote for that flow passed, and that is the lesson: I
wrote the tests from the same understanding that produced the code, so they
proved the things I already believed and were blind in exactly the same place.
What found it was the separate quality review pass, which reads the code
adversarially, as someone trying to break it rather than someone trying to
confirm it. That review is a rule we set in July, and this is the round where
it paid for its whole existence. There is now a test that fails loudly if a
sample account is ever pre-selected again, and I broke the code on purpose
first to watch it fail before trusting it.

**Three: I nearly deleted an hour of fixes with one command.** To prove a new
test really works, I break the code on purpose, watch the test fail, then put
the code back. This time "put the code back" used a command that restores from
the last saved version, and the fixes had not been saved yet, so it threw them
away instead. I caught it in seconds only because the same command prints a
count of the fixes right afterwards, and the count came back zero. Nothing was
lost. The written rule told me how to break the code and said nothing about
how to restore it, which is the actual hole. The fix is simple and I have
recorded it: save the work first, then break it, so restoring is safe by
definition.

**What it costs if a guard is removed.** Take out the sample account test and
the friendliest path through your welcome flow quietly starts eating new
users' first entries, and it will look perfect from every angle including the
tests. Take out the quality review pass and things like it stop being found at
all, because the tests are written by the same mind that wrote the bug. Take
out the screenshot habit and you go back to finding layout problems yourself,
on your phone, which is the most expensive place to find anything.

---

## 2026-07-28, session 8: the patch that shipped wearing the wrong name

UI Phase 2, seven batches, eight pull requests, and for the first time in
this log the instrument this whole file calls ground truth was itself briefly
wrong: for up to 25 minutes the phone's Update stamp row mislabeled a live
patch. The log never lied. The phone did. That asymmetry is the story, and it
was bought by a design decision made in session 3.

### What we believed / What was true

**Believed: every delivered stamp reached the phone under its own name. TRUE
for seven of eight merges, confirmed in person for the last.** Read from
`git show origin/main:docs/delivery-log.md`: f2.60 patch 9 (16:49 UTC Jul
27, run 30285603929), f2.61 patch 10 (17:11, run 30287281609), f2.62 patch
12 (17:37, run 30289242012), f2.63 patch 13 (00:16 Jul 28, run 30316235961),
f2.64 patch 14 (00:28, run 30316836160), f2.65 patch 15 (00:51, run
30318011428), f2.66 patch 16 (01:16, run 30319281517). All mode `patch` on
0.6.2+11, pubspec unchanged, no base APK stranded. Merge to row: 11, 11, 11,
11, 12, 11 and 10 minutes. The founder read f2.66 patch 16 off the phone.

**Believed: the batch 3 stamp bump script did its job. FALSE, and it failed
silently.** The script replaced text around the stamp's middle dot and
matched the literal dot character, while flutter/lib/main.dart spells it as
the escape sequence backslash u00b7. The two render identically to a human
and are different bytes to a replace. With no assert on the effect, the
script no-opped, reported nothing, and read as done. Batch 3 merged carrying
f2.61's stamp, the name of the PREVIOUS build.

**Believed, for about 25 minutes: patch 11 does not exist. FALSE, it
existed and was running on phones labeled f2.61.** Merge #216 (956b270,
17:12 UTC) triggered the publisher, Shorebird shipped batch 3 as patch 11,
and then the duplicate stamp refusal at flutter-preview.yml:178 did exactly
what its own comment promises: it failed the run AFTER the publish, wrote no
row, and refused to make the log lie. Its comment says refusing to record
would be the worse lie, and it is right, but note the precise cost: the
worse lie was avoided by accepting the smaller one, a phone that briefly
said f2.61 while running batch 3's code. There is no patch 11 row and there
never will be; the number is permanently orphaned in the log.

**Believed, during a container restart: batch 4's pull request was empty.
FALSE.** Its commit (1fba4e4) had landed before the restart. The belief came
from reconstructing memory of which commands had errored instead of reading
git, and it produced a duplicate-message commit (e4e1d78, 63 lines, shot
harness only) and one wrong statement to the founder, corrected in the PR
body and to the founder directly. No code harm; git absorbed the duplicate
cleanly.

**Believed, by the plan and held: the phase's scope.** The phase started as
docs/Flutter_UI_Phase2_Plan.md, written before any code, with the founder's
three scope decisions recorded: headers pin, the habit layer is in, the big
builds are parked for Phase 3. The plan was followed, and batch 4, the
money-adjacent one, waited roughly seven hours for the founder's explicit
sign-off before merging, exactly as the never-delegated gate requires.

### Timeline (with evidence)

All times UTC, from commit timestamps and the publisher's rows.

| Time | Event | Evidence |
|------|-------|----------|
| Jul 27 16:30 | 3c0d14e batch 1, receipts and one debts home | git log |
| 16:38 | Merge #214 (6061eb81) | git log |
| 16:49 | f2.60 patch 9 delivered, 11 minutes | delivery row |
| 16:52 | c150eff batch 2, pinned headers | git log |
| 16:59 | 1636fa5 batch 3. **The bump script no-ops here**, stamp stays f2.61 | git show 1636fa5:flutter/lib/main.dart |
| 17:00 | Merge #215 (e4b22cc7), batch 2 | git log |
| 17:11 | f2.61 patch 10 delivered, 11 minutes | delivery row |
| **17:12** | **Merge #216 (956b270), batch 3, carrying f2.61's stamp. DIVERGENCE** | git show 956b270:flutter/lib/main.dart is f2.61 |
| 17:18 | af1143c, the one-line stamp fix to f2.62, mechanism named in the message, written while the #216 run was still in flight | git log |
| 17:20 | 1fba4e4 batch 4, edit a logged entry | git log |
| ~17:23 | Patch 11 publishes labeled f2.61. The refusal fails the run after the publish, no row is written | flutter-preview.yml:178, af1143c message |
| 17:26 | Merge #217 (24da2a96), the stamp fix ALONE, batch 4 stays on the branch | git log 24da2a9..8e31409 |
| 17:37 | f2.62 patch 12 delivered, 11 minutes. **The phone converges on reopen** | delivery row |
| 17:48 | e4e1d78, the duplicate-message commit from the restart confusion, shot harness lines only | git show e4e1d78 --stat |
| 18:10 | e186dc4, the batch 4 QA round: one crash, three honesty gaps, all guarded | commit message |
| 18:10 | eede7ad batch 5, Insights in three bands | git log |
| Jul 28 00:05 | Merge #219 (8e31409f), batch 4 plus QA, **after the founder's sign-off** | git log |
| 00:16 | f2.63 patch 13 delivered, 11 minutes | delivery row |
| 00:16 | Merge #220 (63366e4a), batch 5 | git log |
| 00:28 | f2.64 patch 14 delivered, 12 minutes | delivery row |
| 00:32 | 76b6ee2 batch 6, list polish | git log |
| 00:40 | Merge #221 (b33fddbc) | git log |
| 00:51 | f2.65 patch 15 delivered, 11 minutes | delivery row |
| 00:58 | 987ebaf batch 7, the habit layer, both halves of the comeback line proven | commit message |
| 01:06 | Merge #222 (55e610ab) | git log |
| 01:16 | f2.66 patch 16 delivered, 10 minutes | delivery row |
| after | **Founder confirms f2.66 patch 16 on the phone, in person** | founder |

Verified on the checkout at the time of writing, run fresh: `flutter
analyze` reports "No issues found", `flutter test` reports **848 tests
passing**. The phase's arc: 775 at the start of Phase 1, 840 at the start of
this phase, 848 now.

### Divergence point

**16:59 UTC on Jul 27, commit 1636fa5**, the moment a mutating script did
nothing and said nothing. Everything after that was machinery behaving
correctly around a wrong input: the merge was clean, the publisher
published, the refusal refused, the failure was loud, and the fix took one
line and 25 minutes end to end.

Name the shape, because this is its third appearance in two days: **a tool
that silently does less than it claims, reading as done.** Session 6, eyes
that deprioritized light mode. Session 7, a shot harness mounting less
chrome than production. Session 8, a replace that matched zero occurrences
and exited clean. The first two verified a stand-in for the artifact; this
one performed a stand-in for the action. The counter-move is the same each
time and now has three data points behind it: a tool must measure or assert
its own effect, because "no error" and "no effect" look identical from
outside.

### Root cause

**The orphan stamp.** Two encodings of one character, indistinguishable on
screen, distinguishable to a byte-level replace, and no assertion that the
file actually changed. The root cause is not the encoding, it is the missing
assert: a replace that demands one match and fails on zero would have turned
a silent no-op into a loud stop before commit. Every later bump this session
asserted its effect and anchored on the escape sequence itself, which is
practice, not machinery, and is ranked accordingly below.

**Why the blast radius was one orphaned number and 25 minutes.** This
incident landed exactly in the blind spot Open 7 has described since session
4: main's stamp equaled the delivered stamp, so the watchdog's comparison
read "ok" throughout. And it was covered by exactly the compensating guard
session 4's Open 7 note predicted: the publisher's own refusal, which exits
1 after publishing and trips the failure notice. The prediction was written
fifteen days of stamps ago and cashed today. The refusal's after-the-publish
ordering meant docs/delivery-log.md stayed truthful the entire time, which
is why recovery needed no archaeology, one glance at the failed run's cause
named the missing bump.

**The duplicate commit.** After an interruption, the cheapest-feeling move
is to reconstruct what happened from memory of the error messages, and
memory of errors is exactly what an interruption corrupts. The state was in
git the whole time, one `git log` away. The reading-not-remembering rule has
existed for delivery state since session 3; nothing extended it to commit
state until it cost a duplicate commit and a wrong sentence to the founder.

### Lessons and guards

**Lesson 1. A mutating script without an assert on its own effect is a
silent no-op that reads as done.**

**Guard, detection half, EXISTING and it FIRED: the duplicate stamp refusal,
flutter-preview.yml:178.** This was its first real firing, and it performed
to its design: published, then refused to record a second build under a
delivered name, then failed loudly. Strongest tier, already committed,
proven in production today.

**Guard, prevention half, PRACTICE, medium at best and stated plainly.** The
bump is done by session tooling, not by a committed script, so the assert
lives in discipline: any text replace that must change a file asserts
exactly one replacement occurred, and stamp edits anchor on the escape
sequence as it is spelled in the source. If stamp bumping is ever committed
as a script, the assert goes in it and gets proven by breaking it, like any
guard. Until then the refusal is the net, and today measured the cost of
relying on the net alone: one orphaned patch number and up to 25 minutes of
a mislabeled phone.

**Lesson 2. The refusal's after-the-publish design bought exactly what
session 3 said it would, and today is the evidence.** The log never lied.
The phone lied for at most 25 minutes and only if reopened inside the
window. Recovery was one one-line commit (af1143c) merged alone as #217,
which was the right shape: nothing else rode along with the fix, so the
converging patch was minimal. No change requested to the mechanism. The
entry records the residue honestly: patch 11 has no row and never will, so
the patches column now skips a number, and this paragraph is the only place
that explains it. That is the second archaeology case for **Open 9**, which
would have made the gap self-explaining with a FAILED row.

**Lesson 3. After an interruption, reconstruct state by reading git, never
from memory of which commands errored.**

**Guard, MEDIUM, a rule tied to a moment.** Before any statement about what
landed, after any restart or interruption: `git log --oneline -5` and
`git status`, then speak. This extends the session 3 delivery rule (read the
log, never assume) from delivery state to commit state, and today's evidence
for the tier is honest in both directions: the delivery half of the rule was
followed all day and produced zero wrong statements about shipping; the
commit half did not exist and produced one wrong statement and one duplicate
commit. Same person, same day, the difference was which half had a written
rule.

**Lesson 4. The quality machinery earned its keep this phase, and a clean
finding is a valid outcome. Credited by name, no new guards needed:**

- The qa-tester pass on batch 4 found a real crash before it shipped:
  showDatePicker asserts initialDate on or after firstDate, and a restored
  RN backup can legally carry pre-2015 dates. Fixed by clamping both bounds
  around the row's own date, guarded in flutter/test/edit_entry_test.dart
  (the 2014-12-31 fixture), and the guard was proven with the exact
  predicted assertion quoted in e186dc4. Three honesty gaps fixed and
  guarded in the same round: a wrong explainer routing CSV and interest rows
  to an irrelevant tab, and two silent no-ops around deleted rows that now
  say what happened instead of implying success.
- The founder gate held: batch 4 touches money records, so it waited about
  seven hours for explicit sign-off, and the stamp fix was deliberately
  merged around it rather than with it.
- The porting order paid off precisely as CLAUDE.md rule 4 intended:
  batch 4's reverse-then-apply edit engine (ledger.updateTransaction) had
  been ported and golden-tested since Jul 17 (merge #111), ten days before
  the UI batch existed. The batch added a store method and a sheet, and the
  money math was already proven to the centavo.
- Prove-it-fails ran on every batch and, for once, caught nothing passing
  vacuously, which after session 6's three silent greens is itself a
  measurement. Both halves of the chain's comeback line were proven per the
  alarm rule, fires on the missed-yesterday fixture and stays silent once
  today is logged, failure lines quoted in 987ebaf.
- Session 7's seeded-shot lesson was applied proactively three times, log
  and utang sheets, banded Insights, and the Activity and Budget frames,
  when the empty-seed per-tab shots could not show the change.
- The copy adaptations were deliberate, not drift: English-first per the
  founder's 2026-07-23 rule, RN emoji removed from Salapify-authored chain
  copy per the icon rule, and the celebration overlay keeps the RN reduce
  motion contract, message and haptic survive, motion does not, guarded in
  flutter/test/habit_layer_test.dart.

**Lesson 5. CLAUDE.md fact check.** No edits to CLAUDE.md this phase, and
`git log` over the guard files since f2.59 confirms none of
flutter-preview.yml, flutter-check.yml, delivery-watchdog.yml, eas-update.yml
or CLAUDE.md changed, so the check reduces to spot-verifying standing claims:
the three delivery commands ran as written and returned f2.66 patch 16, the
named paths still exist, the stamp cap still holds (the suite is green and
includes it). No new false claim found. The one known stale claim, workflow
item 4 versus eas-update.yml's dead-branch trigger, is unchanged and remains
**Open 14**.

### Open lessons carried forward

**Open 3, nothing compares the phone to main: STILL OPEN, by design, with a
new nuance recorded.** The founder confirmed f2.66 patch 16 in person. But
today showed the phone half of the comparison can itself be briefly wrong:
during the orphan window the phone's stamp row was the mislabeled artifact.
The comparison the founder performs is only as good as the stamp discipline
feeding it, which is one more reason Lesson 1's prevention half matters.

**Open 6, the watchdog has never been observed running a scheduled pass:
STILL OPEN.** Run history is still unreadable from this sandbox. Today's
orphan was invisible to it by design (see Open 7), and no spurious issue is
in evidence.

**Open 7, the watchdog blind spot for merges that do not bump the stamp:
STILL OPEN, and today it stopped being theoretical.** Merge #216 was exactly
the predicted case, main's stamp equal to the delivered stamp with a patch
genuinely pending, and exactly the predicted compensating guard reported it,
the publisher's refusal plus failure notice. The prediction from session 4
held in every particular. The blind spot remains, and remains covered only
by that one guard.

**Open 8, split the publish step from the log scraping: STILL OPEN,
untouched this phase.**

**Open 9, FAILED rows in docs/delivery-log.md: STILL OPEN, and today added
its second archaeology case.** The patch 10 to patch 12 jump is explained
nowhere in the log itself. A FAILED row for the #216 run would have made the
gap self-documenting. This open item has now cost reading time twice.

**Open 10, nothing holds Pan's rendered size: STILL OPEN.**

**Open 11, nothing stops a sixth private kicker: STILL OPEN.**

**Open 12, the dead branch in CLAUDE.md and the publisher: STAYS CLOSED,**
re-verified trivially, no workflow or CLAUDE.md file changed this phase.

**Open 13, the shot harness mounts screens through a private copy of the
shell's wiring: STILL OPEN.** The class produced steady hand-work this
phase, three proactive seeded-shot additions, and the harness lines were
also the content of the duplicate commit, so the copy keeps costing small
amounts of attention. The automated version, mounting through the shell or
asserting chrome presence, is still not done.

**Open 14, CLAUDE.md workflow item 4 versus the eas-update trigger: STILL
OPEN, untouched.**

### Guard status re-check

Read, not assumed. The cheap and honest version this session: `git log`
proves none of the guard-bearing workflow files changed during the phase, so
their session 7 line numbers stand, and the fresh 848-green suite run covers
every committed test guard, including session 6's (a11y with the sweep
floor, nav_ambiguity, the clock seam) and session 7's (both header_action
tests). Three guards deserve individual mention:

- **The duplicate stamp refusal FIRED, correctly, first real firing.** It
  published, refused to record, failed loudly, and the log stayed truthful.
  flutter-preview.yml:178.
- The failure notice tied to it should have opened its issue; as in every
  session, that cannot be confirmed from this sandbox (API 403), stated
  rather than assumed. What is confirmed is its effect's absence of harm:
  the very next merge recovered.
- New guards from this phase, first listing for the next session to
  re-check: flutter/test/edit_entry_test.dart (the pre-2015 picker clamp
  with the predicted assertion, the deleted-row honesty pair),
  flutter/test/log_date_test.dart, flutter/test/habit_layer_test.dart (both
  halves of the comeback line, the reduce motion contract, celebration on
  real balance only), and lib/money/chain.dart's pinned-clock vector suite.

### What it cost, and what it did not

Cost: one patch number orphaned forever, up to 25 minutes of a mislabeled
phone, one failed run, and 25 minutes of wall clock from divergence to
convergence. One duplicate-message commit in permanent history and one wrong
sentence to the founder about batch 4, corrected the same hour. The patches
column now skips 11, which will puzzle every future reader who has not read
this entry.

Did not cost: any data, any wrong number, any manual install, any
undelivered batch, any founder-found bug. Seven deliveries at a metronomic
10 to 12 minutes. The one crash of the phase was caught by QA before it
shipped, on a fixture (a restored old backup) that no fresh install would
ever have shown. And the incident itself cost so little precisely because
two old decisions held: the refusal design from session 3, and one-stamp-
one-patch bookkeeping that made the wrong name detectable at all.

### For the founder, in plain English

Phase 2 is fully on your phone, you confirmed f2.66, patch 16, and all seven
updates arrived on the usual ten-minute rhythm. Receipts when you log,
headers that stay put, backdated logging with a calendar, editing a logged
entry without deleting it, Insights in three readable bands, the list
polish, and the seven-day chain with the confetti when a debt clears.

One thing went wrong in the middle, and I want to walk you through it
because you may one day notice a small oddity it left behind: your patch
numbers jump from 10 to 12. There is no patch 11 row, and there never will
be. Here is why.

Every update carries two labels: a patch number the robot assigns
automatically, and a stamp like f2.62 that I write by hand into the code, so
you can check what arrived. For batch 3 I used a small script to update that
stamp, and the script silently did nothing: the stamp contains a middle dot
character, and the code spells that dot in an escaped notation that looks
identical on screen but is different underneath. The script searched for the
lookalike, found nothing, replaced nothing, and reported no error. Doing
nothing without saying so is the worst way a tool can fail, because it looks
exactly like success. So batch 3 went out still wearing the previous
update's name, f2.61.

Our publishing robot has a rule written for exactly this: two different
builds must never share a name, because your stamp row is the one check
nobody can fake. It shipped the update, then refused to write the lying row
into the log, and stopped with a loud failure instead. That refusal is
deliberately AFTER shipping, because the update was already out, and
pretending otherwise in the log would be a worse lie. So for up to 25
minutes, if you reopened the app in that window, your phone said f2.61
while actually running batch 3. The log stayed honest the whole time, which
is why fixing it took one line, giving the build its real name f2.62, and
eleven minutes.

Separately, and this one is on me in a more ordinary way: my workspace
restarted mid-batch, and instead of checking the record of what had been
saved, I went from memory of the error messages and told you batch 4's pull
request was empty. It was not; the work had landed. I corrected it the same
hour. The new rule is written down: after any interruption, read the record
before saying anything about what happened. The same rule already existed
for deliveries and worked all day; it just had never been extended to this.

Some good news you should know about, because it is your own past decisions
paying out. The editing feature touches money records, so it went through
the extra QA pass and waited for your sign-off, and that QA found a real
crash before it ever reached you: old backups from the previous app can
contain dates before 2015, and the date picker choked on them. Fixed, with a
test. And the reason the editing feature was safe to build quickly is the
rule we set at the start, port the money math first: the engine that
recalculates balances when you edit an entry had already been ported and
tested to the centavo ten days ago, so this batch only added the screen.

What it costs if a guard is removed: take out the robot's refusal rule and
the next time a stamp goes stale, two different builds share a name and your
one reliable check, comparing the phone's row to the log, quietly starts
lying, with nothing to tell either of us. It stays.

---

## 2026-07-27, session 7: the screenshots were missing the button under review

Second sitting of the day, after session 6, and it has to open with an
uncomfortable sentence about session 6 itself: this morning's entry reported
"every changed screen rendered and looked at", and that was said in good
faith about renders that were missing the header chrome the founder sees
every time the app opens. Both sittings today are the same finding wearing
different clothes, and that is the headline.

### What we believed / What was true

**Believed: both stamps reached the phone. TRUE, and confirmed in person.**
Read from `git show origin/main:docs/delivery-log.md`, then confirmed by the
founder on the phone: f2.58 patch 7 at 14:18 UTC (run 30273557933, merge
2b24a761) and f2.59 patch 8 at 14:47 UTC (run 30275837111, merge b491c6d8).
Both mode `patch` on 0.6.2+11, pubspec unchanged, no base APK stranded.
Merge to row: 11 and 12 minutes, inside the norm. The founder read f2.59
patch 8 off the Update stamp row. Four clean deliveries today across two
sittings, zero delivery incidents. The gap between f2.57 and f2.58 in the
log is the session 6 write-up itself, merge #210 at 13:59, docs only, so the
publisher's paths filter correctly stayed silent and the absence of a row is
the system working.

**Believed, by the render discipline: the shot harness shows what the
founder sees. FALSE, for every per-tab render, since this morning's shell
refactor.** The harness mounts each tab screen with a hand-written
constructor call, and none of those calls passed `onMenu`, so every per-tab
shot rendered WITHOUT the header actions. The Menu key, the only door to 16
destinations, had never appeared in a single per-tab screenshot. The founder
was the first person to actually review it, and said it "looks a bit
awkward". The discipline ran exactly as written, on renders that were
structurally less than production.

**Believed: 814 green tests plus rendered screens meant the header was
right. FALSE three ways, none previously visible.** Making the key visible
(a raised 48 square instead of a bare glyph) exposed two latent defects a
bare glyph had hidden, found by a geometry probe measuring rects rather than
by eyes: the Menu key floated 19dp off the content edge on Budget while
sitting flush on Activity, because the header row had TWO flex children (a
loose Flexible title plus a Spacer) splitting the free space, so a short
title's unused share became dead space at the END of the row; and the
empty-state branch of Insights never passed `onMenu` at all, so a brand new
user had NO way into Menu from that tab. The probe found that one by
throwing "Bad state: No element" on an empty store.

**Believed since session 5, flagged as overdue in session 6: CLAUDE.md and
the publisher name a dead branch. NOW FIXED, on the Flutter path.** f2.58
was that fix, merged 19 minutes after session 6 called it overdue.

### Timeline (with evidence)

All times UTC.

| Time | Event | Evidence |
|------|-------|----------|
| 13:38 | f2.57 patch 6 delivered, session 6's ground truth | delivery row |
| 13:52 | 05c4ace, session 6 written | git log |
| 13:59 | Merge #210, docs only, publisher correctly silent | no row, paths filter |
| 14:00 | cf5c6a7, Open 12 fix: claude/salapify-v2 out of flutter-preview.yml's trigger, both CLAUDE.md sentences rewritten to the per-session claude/** reality. Stamp bumped to f2.58 ON PURPOSE for a housekeeping change, reasoning in the commit message | git show cf5c6a7 |
| 14:07 | Merge #211 (2b24a761) | git log |
| 14:18 | f2.58 patch 7 delivered, 11 minutes | delivery row |
| after | **Founder: the header Menu icon "looks a bit awkward"** | founder message |
| 14:27 | 880c41e, HeaderAction raised keys, the harness gets onMenu on every tab mount, the 19dp and empty-Insights bugs found and fixed, both guards proven failing first, failure lines quoted in the commit | git show 880c41e |
| 14:35 | Merge #212 (b491c6d8) | git log |
| 14:47 | f2.59 patch 8 delivered, 12 minutes | delivery row |
| after | **Founder confirms f2.59 patch 8 on the phone, in person** | founder |

Verified on the checkout at the time of writing, run fresh, not quoted:
`flutter analyze` reports "No issues found", `flutter test` reports **816
tests passing**.

### Divergence point

**11:50 UTC this morning, commit 6432323, the same commit as session 6's
divergence.** When Menu moved into the header, the shot harness's hand-written
mounts did not gain the new `onMenu` parameter, so from that moment every
per-tab render silently stopped matching production chrome. Session 6's
review, and session 6's own write-up, sat downstream of that gap without
knowing it. The gap was closed at 14:27 when the harness was wired to mount
tabs the way the shell mounts them.

Said plainly, because the coordinator asked and because it is true: **session
6 and session 7 are one shape.** In the morning, a human review with a
documented dark-first priority missed a light-only bug. In the afternoon, a
render harness with a hand-copied mounting missed the header entirely. Both
times the discipline ran as written and verified a STAND-IN for the artifact,
and both times the catch came from measurement, a contrast ratio in the
morning, a rect probe in the afternoon. This is session 5's root cause
sentence, "make the guard measure the artifact that ships, not the
declaration of it", landing twice in one day on the checking tools
themselves.

### Root cause

**The missing chrome in the shots.** The harness mounts screens through a
private copy of the shell's wiring, and a copy has no way to know when the
original changes, which is session 4's Lesson 5 verbatim, applied to the
harness instead of to CLAUDE.md. The shell gained `onMenu`; the copy did
not; nothing failed, because a screen without a header action is a perfectly
valid widget tree. The a11y suite, by contrast, boots the REAL app
(`SalapifyApp`) and measured the real header, which is why it caught the
contrast bug this morning while the shots showed nothing. The harnesses
differ in exactly the dimension that mattered.

**The 19dp drift.** Two flex children in one row means the layout DIVIDES
free space rather than assigning it, so alignment became a function of title
width. It shipped with the header rework and was invisible while the control
was a bare glyph, because nothing gave the eye an edge to compare against.
Making the control visible is what made the defect visible, which is worth a
sentence: a bordered control is itself a kind of guard, it turns misalignment
from a feeling into a measurable edge.

**The empty Insights tab.** Every widget test seeds data, because tests are
written to exercise features and features need data. So the empty state is
systematically the least-tested state, while being the FIRST state every new
user meets. The a11y suite already seeds rich data for the opposite reason,
recorded in its own header: empty screens have fewer controls to measure.
Both instincts are correct and each is blind to the other's defect class.
The emptiest account had the fewest ways out of the screen, and nothing
could have said so.

**The deliberate stamp bump on a housekeeping merge.** Editing
flutter-preview.yml triggers the publisher, because the publisher watches
its own definition (session 2's guard, still earning). So the Open 12 merge
was always going to ship a patch. An unbumped stamp would have hit the
duplicate stamp refusal at flutter-preview.yml:178, which fails AFTER
publishing, on purpose, so the run would have shipped patch 7 and then
written no row and opened a failure issue, reproducing session 5's
published-but-unrecorded shape by the guard's own design. Bumping to f2.58
was the correct move and the reasoning is in cf5c6a7's message.

### Lessons and guards

**Lesson 1. A render harness that mounts screens with less chrome than
production verifies a stand-in, and every review built on it inherits the
gap, including this log's own entries.**

**Guard, SHIPPED, medium, and honestly ranked.** The harness now wires
`onMenu` on every tab mount, including the two bespoke mounts, with the
omission recorded in a comment at flutter/test/screens_shot.dart:207. This
fixes the instance. It does not fix the class: the mounts are still a
hand-written copy of the shell's wiring, and the next constructor parameter
the shell gains can be omitted the same way, silently. The automated version
would be mounting per-tab shots through the shell itself, or asserting the
header chrome is present in each per-tab render. Neither exists yet. **New
Open 13.**

**Lesson 2. The header key sits on the content edge on every tab, and that
is now a measurement, not an impression.**

**Guard, SHIPPED, strongest tier, proven failing first.**
flutter/test/header_action_test.dart boots the real app and asserts the Menu
key's right edge lands at exactly 390 minus 20 on all five tabs, plus its 48
square size. The failure it was born catching is quoted in 880c41e:

    Expected: <370.0>  Actual: <351.0>

The fix is structural, one tight Expanded title instead of Flexible plus
Spacer, so free space has exactly one owner. Note what kind of bug this
guards against: title-width-DEPENDENT layout, the kind that passes on the
screen someone happens to look at.

**Lesson 3. The empty state is the least-tested state and the first one a
new user meets. Seed empty on purpose, at least once per screen with
chrome.**

**Guard, SHIPPED, strongest tier, proven failing first.** The second test in
header_action_test.dart boots an EMPTY store, goes to Insights, and asserts
the Menu tooltip exists, failure quoted in 880c41e: "Found 0 widgets". The
a11y suite's welcome-state test already covers Home's empty state for
guidelines; this adds the chrome-presence angle. The class rule, medium and
stated as such: when a screen has an empty branch, the empty branch renders
the same chrome as the full one, and a test seeds empty to prove it. One
screen is guarded; the rule is what covers the rest until it is needed
again.

**Lesson 4. When an infrastructure change forces a publish, the patch gets
its own name.** The duplicate stamp refusal already enforces this loudly and
after the fact, which is the expensive way to learn it. The cheap way is the
corollary now on record: CLAUDE.md rule 2 says bump the stamp on every push,
and "every push" includes pushes whose only Flutter-relevant content is the
publisher's own definition, because the publisher watches its own path.
**Guard: existing (the refusal at flutter-preview.yml:178) plus this
sentence. Medium for the prevention half, strong for the detection half, and
the detection half was designed in session 3 and did not need to fire today
because the prevention half was followed.**

**Lesson 5. Tests that changed this round, reported per the session 5
convention.** flutter/test/search_screen_test.dart stopped tapping
`find.byIcon(Icons.search)` and now taps `find.byTooltip('Search')`
(search_screen_test.dart:34). It changed because the glyph moved into the
salapify_icon map, not because an assertion was wrong: the finder was
coupled to the control's implementation instead of its meaning, the same
seam reasoning as openMenu in app_harness.dart, where the tooltip is also
the screen reader's name for the control, so this finder breaking would
signal a real regression. No assertion changed sides. Nothing was defending
a bug.

**Lesson 6. CLAUDE.md fact check, and this sitting found a new stale claim,
created by today's own fix.** What was checked and now matches: the two
rewritten branch sentences are true (CLAUDE.md:158 describes the retired
branch and the per-session claude/** reality; flutter-preview.yml triggers
on main only, with the retirement reasoning in a comment at lines 13 to 16).
The RN remnant is recorded as deliberate: build-apk.yml:14 and
eas-update.yml:18 still name claude/salapify-v2, left alone because the RN
track is frozen and its delivery path was out of scope for a Flutter
housekeeping pass.

**The new stale claim:** Development workflow item 4 says "every push to the
branch that touches mobile/ triggers the Publish OTA update GitHub Action".
When item 1 said the branch was claude/salapify-v2, that was true. Item 1
now says each session gets its own claude/** branch, and eas-update.yml
triggers ONLY on the dead branch, so a push to a session branch touching
mobile/ triggers nothing. One sentence was fixed and its neighbour went
false, which is a new instance of the exact shape sessions 2 through 5
documented. Harm today: none, and in the safe direction, nothing publishes
from a branch. Harm later: the first session that resumes RN work will
believe OTA publishing is automatic and it will not be. **Guard, MEDIUM,
open: reconcile item 4 and the eas-update trigger with the per-session
branch reality, deliberately, when RN work resumes or sooner. Folded into
the reopened half of Open 12 below as Open 14.** The pattern count, stated
honestly: the fact check has now found a false or stale factual claim in
five consecutive sittings, and today's was CREATED by a fix. Editing one
sentence of CLAUDE.md means re-reading its neighbours.

### Open lessons carried forward

**Open 3, nothing compares the phone to main: STILL OPEN, by design.** The
founder confirmed f2.59 patch 8 in person. The founder was also the detector
for the awkward-looking key, which is the acceptable cost of Open 13 having
existed: design judgement reached the founder because no render had shown
the control to anyone else first.

**Open 6, the watchdog has never been observed running a scheduled pass:
STILL OPEN.** API still unreadable from this sandbox, no spurious issues in
evidence, all four of today's gaps well inside grace.

**Open 7, the watchdog is a stall detector, not an audit trail: STILL
OPEN.**

**Open 8, split the publish step from the log scraping: STILL OPEN,
re-verified after today's workflow edit,** the scrape still lives inside the
ship step, `|| true` intact at flutter-preview.yml:127.

**Open 9, FAILED rows in the delivery log: STILL OPEN.**

**Open 10, nothing holds Pan's rendered size: STILL OPEN.**

**Open 11, nothing stops a sixth private kicker: STILL OPEN.** Today added a
point in the pattern's favour again: HeaderAction is one shared widget with
a named wrapper, not two hand-rolled call sites.

**Open 12, CLAUDE.md and the publisher name a dead branch: CLOSED for the
Flutter path, this session, 19 minutes after being called overdue.**
Verified by reading: the trigger is main only, both CLAUDE.md sentences are
rewritten and true. The RN-side remnant (build-apk.yml:14, eas-update.yml:18)
is deliberate and recorded so no future session rediscovers it as a finding.

**NEW Open 13: the shot harness mounts screens through a private copy of the
shell's wiring.** Today that copy omitted onMenu and every per-tab render
lost its header chrome without anything failing. The instance is fixed; the
class is not. Automated tier available: mount tab shots through the shell,
or assert chrome presence in the harness. Not done.

**NEW Open 14: CLAUDE.md workflow item 4 and eas-update.yml's trigger
describe a branch arrangement that no longer exists.** Safe direction today,
a trap the day RN work resumes. Medium tier. Not done.

### Guard status re-check

Read, not assumed, after a session that edited the publisher's own file.

- The `|| true` scrape guard: PRESENT, flutter-preview.yml:127 with its
  comment.
- The nothing-shipped failure issue: PRESENT, flutter-preview.yml:224.
- The release install shout: PRESENT, flutter-preview.yml:249, correctly
  silent today.
- The duplicate stamp refusal: PRESENT, flutter-preview.yml:178, and it
  shaped today's correct behaviour without firing, which is a guard's best
  day, see Lesson 4.
- The publisher watching its own path: PRESENT, and it earned its keep
  today, cf5c6a7 edited the workflow and the merge exercised the publisher.
- Concurrency `cancel-in-progress: false`: PRESENT, flutter-preview.yml:36.
- The delivery watchdog with `--first-parent` and 2700 grace: PRESENT,
  untouched today.
- flutter-check.yml on `claude/**`, screenshot harness step with
  `--update-goldens`, branch-stamp-versus-delivered step: PRESENT,
  untouched.
- The stamp cap, the Pan folder tests, pan_signature_test, the shared
  Kicker: PRESENT, untouched today, verified this morning.
- Session 6's new guards, first re-check: a11y_test.dart PRESENT and
  passing, including the Menu sweep floor; nav_ambiguity_test.dart PRESENT;
  the clock seam PRESENT at overview.dart:116; app_harness.dart PRESENT and
  it absorbed today's search finder change exactly as designed.
- New today: header_action_test.dart, two tests, both proven failing before
  trusted, both passing now. 816 tests green, analyze clean, run in this
  sitting.

### What it cost, and what it did not

Cost: one round of founder feedback spent on a control no screenshot had
ever shown, which is the render discipline's first known blind render since
it was built. A 19dp misalignment and a missing Menu door on empty Insights,
both shipped since this morning's batch 1, both invisible to 814 tests and
to every render. One stale CLAUDE.md sentence created while fixing another.

Did not cost: any delivery failure, any wrong number, any manual install,
any lost data. Four for four on deliveries today, all inside the normal
window, and the founder's phone matched the log on both reads. Open 12 went
from overdue to closed in 19 minutes. And the two real bugs the new key
exposed were caught by a probe and turned into proven tests inside the same
commit that found them.

### For the founder, in plain English

Second write-up today, and it is about the two small updates you confirmed
this afternoon, plus something I owe you about my screenshots.

**What happened.** The first patch was housekeeping: our instructions file
and the publishing robot both still mentioned an old work branch that no
longer exists, this morning's write-up called that overdue, and it is now
fixed. Because the publishing robot rebuilds whenever its own instructions
change, even that cleanup shipped as a patch, and it got its own stamp,
f2.58, so the row on your phone would name what it actually was.

The second patch came from you. You said the Menu icon looked a bit awkward,
and you were right. It was a bare symbol floating in space, and next to the
orange New button it nearly disappeared. It is now a proper raised key, a 48
pixel square with a fine border, the same look as the app's cards, and the
search button on Home matches it.

**The part I owe you.** Here is why that awkward icon reached you at all. My
screenshot tool builds each screen for the picture the way a stagehand
assembles a set, from its own copy of the instructions. When we moved Menu
into the header this morning, the app's real instructions changed and my
copy did not, so every screenshot of your tabs was quietly missing the
header buttons. I was looking at screens without the very control in
question, and this morning's write-up said "every screen was looked at"
believing it. That is the second time TODAY a checking tool of mine verified
something slightly different from what you actually see; this morning it was
my eyes preferring dark mode, this afternoon it was my camera missing a
button. The pattern is now written down in both entries: a check must look
at the real thing, not a copy of it. The screenshot tool now wires the
header buttons in everywhere, and there is an open item to make it
impossible to drift again rather than merely fixed.

**What making the button visible uncovered.** Two real bugs had been hiding
behind that bare icon. The Menu key was sitting 19 pixels off the edge that
everything else on the screen lines up to, but only on some tabs, because of
how leftover space was being split inside the header. And on the Insights
tab, a brand new user with no data yet had no Menu button at all, on the one
screen arrangement every new user starts with, and Menu is the only door to
sixteen other screens. Both are fixed, and both now have tests that I broke
on purpose first and watched fail, one saying the key was 19 pixels adrift,
the other saying the button was simply not there.

**What it costs if a guard is removed.** Delete those two header tests and
the key can drift off its edge tab by tab, and the next screen with an
empty state can quietly lose its way out, and no picture will show either,
because pictures are exactly what missed them the first time.

**One thing to be straight about.** While fixing the two outdated sentences
in our rules file, the fix made a nearby sentence wrong instead: the rules
still describe automatic publishing for the OLD React Native app from a
branch arrangement that no longer exists. It causes no harm now because
that app is frozen, and nothing can publish by accident, but it is written
down as an open item so the day we touch the old app again, nobody trusts a
sentence that stopped being true today.

---

## 2026-07-27, session 6: the bug only light mode could see

### What we believed / What was true

Six beliefs this round. Two were true, and the delivery pipeline was one of
them, twice.

**Believed: both batches reached the phone. TRUE, and confirmed in person.**
Read from `git show origin/main:docs/delivery-log.md`, then confirmed by the
founder on the phone, which is the only proof that counts: f2.53 patch 5 at
12:06 UTC (run 30263887813, merge 8e9fba0c) and f2.57 patch 6 at 13:38 UTC
(run 30270358216, merge 81a32e04). Both mode `patch` on 0.6.2+11,
flutter/pubspec.yaml still 0.6.2+11, so no base APK was stranded. Merge to
delivery row: 10 minutes and 11 minutes, inside the 9 to 11 minute norm
measured in session 4. The founder read f2.57 patch 6 off the Update stamp
row and it matched the last delivery row exactly. This entry is not about a
delivery failure. There were two deliveries today and both were boring, which
is what a delivery should be.

The gap in the log is benign by session 5's reading rule: f2.54, f2.55 and
f2.56 have no rows because they only ever existed on the working branch,
superseded inside pull request #209. None of them reached main. A missing
stamp is an incident only when it reached main, and none of these did.

**Believed: batch 1 was visually checked before merging, so what shipped
looked right. FALSE for light mode, and a real bug reached the phone.** When
Menu moved off the bottom bar it became a pushed route, and its Scaffold was
stripped along with the other destinations' Scaffolds during the shell
refactor. The five destinations render inside the SHELL's Scaffold. A pushed
route does not, so Menu rendered with no background surface at all. In dark
mode that happened to look almost right, and dark is what the founder uses
and what gets looked at first, per the standing rule. In light mode the Menu
title rendered at a contrast of 1.21 to 1, where 4.5 to 1 is the floor. It
was live from f2.53 until f2.57, about 92 minutes by the log. No eye caught
it. The new textContrastGuideline test caught it, by number, in batch 2
(commit 6b35e90; the fix and the measurement are quoted in
flutter/lib/screens/menu.dart:61).

**Believed, three separate times: the new accessibility suite's first green
was proof. FALSE all three times, and each false green looked identical to a
true one.** (a) The shared segmented control wrapped each segment in
`Semantics(button: true)` around `ExcludeSemantics`, which strips the
InkWell's tap ACTION along with its label, and Flutter's tap target guideline
skips any node with neither a tap nor a longPress action. So the control was
invisible to the exact test meant to measure it, and, worse, genuinely
unreachable by screen readers, a real bug that had already shipped inside
Appearance. (b) The guideline skips nodes touching the view edge, so a
full-bleed test harness exempted the whole control. (c) Guidelines measure
only BUILT widgets, a lazy ListView builds only the viewport, and certifying
the top and bottom of Menu skipped the entire middle band, where a control
deliberately shrunk to 40 pixels still passed. All three were found by the
prove-it-fails discipline, not by luck, and the failure lines are quoted in
commits 84e3f46 and 6b35e90.

**Believed: the committed-amount duplication test guarded its fix. TRUE only
on some calendar dates, which is FALSE.** Its widget half ran through the
live clock and excused itself with markTestSkipped whenever the fixture
produced no committed money, which was most days of the month, because
store.load() posts due recurring bills and stamps lastPosted, so the test and
the widget were examining different data. Three fixture rewrites failed
instructively before the real fix, a clock seam (commit 17532be, the three
failures written out in its message).

**Believed, in the plan: IndexedStack would make finders ambiguous across the
mounted tabs. FALSE, disproven with a test rather than argued away.** The
SDK's `_IndexedStackElement` overrides the onstage walk and visits only the
selected child, so inactive destinations never reach a default finder. The
proof test found 1, not 2. The plan doc was corrected and the behaviour is
now pinned in flutter/test/nav_ambiguity_test.dart, including a third test
that flips the index so the first two cannot pass by accident.

**Believed, briefly: a silent CI watcher meant a build still running. FALSE.**
The first watcher this session queried the GitHub API, got 403s (documented
as unreadable from this sandbox in sessions 4 and 5), and reported nothing,
and that silence read as progress. It was replaced with a watcher that reads
docs/delivery-log.md over git and explicitly reports BOTH outcomes, a
new-row line and a loud no-row-after-35-minutes line. This is session 5's
Lesson 8 recurring once and then being followed.

### Timeline (with evidence)

All times UTC, from `git show -s --format=%cI` and from the publisher's own
timestamps in docs/delivery-log.md.

| Time | Event | Evidence |
|------|-------|----------|
| 03:05 | 75eaf19, one navigation seam for the widget suite (test/support/app_harness.dart), and the IndexedStack assumption corrected with a proof test | git log; nav_ambiguity_test.dart |
| 06:13 | 84e3f46, the shared segmented control, and the first accessibility test found measuring nothing three ways, one of them a shipped screen reader bug | commit message, guideline source quoted |
| 06:44 | 8208cc8, one shell owns the navigation, tabs stop forgetting | git log |
| 11:50 | **Divergence.** 6432323, Menu moves to the top and becomes a pushed route with no Scaffold. From here the light mode Menu has no background surface, and nothing knows | git show 6432323; menu.dart:61 comment |
| 11:56 | Merge #208 (8e9fba0c), stamp f2.53 | git log |
| 12:06 | f2.53 patch 5 delivered, 10 minutes | delivery row |
| 12:06 to 13:38 | The contrast bug is live on the phone. Invisible in dark mode, which is what the founder uses | menu.dart:61 |
| 12:01 to 12:41 | 9766af7 one committed figure not two, a209653 Home leads with the number, 17532be the clock seam after three failed fixtures, a700de2 three presentation levels | git log |
| 12:54 | 6b35e90, the accessibility suite. textContrastGuideline samples the pushed Menu title at 1.21 to 1 and fails. Fixed in the same commit, with three more real findings | commit message, failure lines quoted |
| 13:20 | 23a405d, Utang and Debts merge into one tab, two segments, stamp f2.57 | git log |
| 13:27 | Merge #209 (81a32e04) | git log |
| 13:38 | f2.57 patch 6 delivered, 11 minutes | delivery row |
| after | **Founder confirms f2.57 patch 6 on the phone, in person** | founder |

Verified on the checkout at the time of writing: `flutter analyze` reports
"No issues found", `flutter test` reports **814 tests passing** (up from 775),
run in this session, not quoted from memory.

### Divergence point

**11:50 UTC, commit 6432323.** That is where "the screens were rendered and
looked at" stopped being the same fact as "the screens are right". The
render discipline was followed as written: every changed screen, both
brightnesses, dark first. The bug sat precisely in the discipline's stated
blind spot, because dark first is a priority order for HUMAN attention, and
the one brightness a human deprioritises is exactly where a surface bug can
live alone. The divergence closed at 12:54 when a numeric check that has no
brightness preference measured the title and said 1.21.

Worth stating the shape: this is the first session where the founder found
zero bugs and the tests found several, including one that was already on the
phone. The direction of detection reversed. That is what every guard in this
log has been trying to buy.

### Root cause

**The shipped contrast bug.** The shell refactor changed two things in one
move: the five destinations gave up their Scaffolds to the shell, and Menu
changed CATEGORY, from destination to pushed route, in the same batch. A
pushed route needs what the destinations no longer do, and nothing in the
type system or the suite distinguished "renders inside the shell's Scaffold"
from "renders alone". The human check then missed it for a structural reason,
not an attention reason: the rule says dark first because dark is what the
founder uses, and a missing Material surface in dark happened to sit on a
dark window anyway. A review order optimised for the common case is blind in
the uncommon one, by construction. The fix for that is not "look harder at
light mode", it is a check that does not have a favourite brightness.

**The three silent greens.** A new test's first green is a recording of its
author's mental model, not evidence, which is session 3's Lesson 3 wearing
accessibility clothes. What is new this round is HOW MANY silent-pass modes
one honest suite turned out to contain: skipped actionless nodes, skipped
edge-touching nodes, unmeasured unbuilt widgets. All three are documented
behaviours of the guideline machinery, none is a bug in Flutter, and every
one of them converts "passed" into "did not look". The only thing that
distinguished measuring from not measuring was breaking the app on purpose
and demanding the failure.

**The self-skipping test.** A test that conditions its own execution on the
live clock is an alarm that removes its own battery on most days, and it had
been proven-to-fail on one date, which hid that it checked nothing on the
others. Proving a test can fail on one input does not prove it RUNS on all of
them. The structural fix was a seam, not a cleverer fixture, because some
real dates genuinely have no committed money and the app is right about that.

**The silent watcher.** Same class as session 5's Lesson 8, an uncommitted
monitor whose failure mode is indistinguishable from good news. The standing
answer, read the delivery log instead of asking the API, already existed and
was applied on the second attempt. The cost of the rule not being in
CLAUDE.md was measured this round: one silent watcher, replaced within the
session.

### Lessons and guards

**Lesson 1. A dark-first eye has a light-mode blind spot, and the contrast
guideline does not care which brightness anyone prefers.**

The render discipline stays, and stays dark first, because it catches what
only eyes can catch, prose walls, missing ticks, a mascot dissolving into his
background. What it structurally cannot promise is the brightness the human
deprioritised, and this round produced the proof: a 1.21 to 1 title, live on
the phone, invisible to a dark-first review, caught by a number.

**Guard, SHIPPED, strongest tier.** flutter/test/a11y_test.dart runs
textContrastGuideline (plus both tap target guidelines and the label
guideline) over all five destinations, the Utang second segment, Menu
screenful by screenful, the log sheet, the Activity filter state, and the
welcome state, at test/a11y_test.dart:96. It runs in the Flutter check on
every branch push and in the preview publisher before anything ships. It
caught this exact bug before batch 2 merged, which is the guard demonstrating
its value in the same session it was written.

**Lesson 2. An accessibility suite can pass while measuring nothing, in at
least three distinct ways, and only a deliberate failure tells them apart.**

The three silent-pass modes, named so the next suite author can check them by
name: a node with no tap action is SKIPPED by the tap target guideline, so a
widget made semantically inert passes precisely because it is broken; a node
touching the view edge is skipped, so a full-bleed harness certifies nothing;
and guidelines measure only built widgets, so a lazy list is only certified
for the screenfuls actually scrolled through. Mode (a) was not just a test
gap, it was a shipped bug: the segmented control advertised "button,
selected" to screen readers with no way to activate it.

**Guards, SHIPPED, layered.** The widget fix gives the Semantics its own
onTap, with the reason written at flutter/lib/widgets/segmented.dart:80 so it
cannot be tidied away. The Menu sweep walks every screenful and then asserts
it covered at least three of them (test/a11y_test.dart:161), so the sweep
itself cannot silently shrink back into a top-and-bottom pair, a guard on the
guard, automated. And the proof-of-failure lines are quoted in the commits
that landed the suite, per the standing CLAUDE.md rule:

    expected tap target size of at least Size(48.0, 48.0), but found Size(318.0, 40.0)
    androidTapTargetGuideline on Menu, screenful 4

The standing rule needs no strengthening, it needs exactly what happened
here: application. Three silent-pass modes found in one suite in one day is
the strongest evidence yet that the rule is load bearing.

**Lesson 3. A test that can skip itself on most calendar dates is an alarm
with its battery out, and proving it fails on one date does not prove it runs
on the others.**

**Guard, SHIPPED, strongest tier.** OverviewScreen takes an injectable clock
defaulting to DateTime.now (flutter/lib/screens/overview.dart:116, with the
three failed fixture attempts recorded in the doc comment), the test pins
DateTime(2026, 7, 26) and drives its precondition through the store, and the
markTestSkipped escape hatch is gone, so the test now hard-fails instead of
abstaining.

**Guard for the class, MEDIUM, stated plainly.** The rule worth carrying: a
widget test may not gate its own execution on the live clock. If the scenario
depends on the date, the screen takes a clock and the test picks the date.
This is a rule, not a check, and it is recorded here rather than promoted to
CLAUDE.md because one instance is not yet a pattern; if a second self-skipping
test ever appears, promote it.

**Lesson 4. Per session 5's Lesson 10 convention, the tests that changed this
round are reported, and none was defending a bug.** The duplication test's
markTestSkipped was removed so it fails instead of abstaining, an assertion
was added, none inverted. The first a11y versions were replaced by versions
that measure MORE, with the old blind spots quoted in the commits. No
assertion changed sides. Nothing to quote as a defended defect, and saying so
plainly is the convention.

**Lesson 5. A disproven plan assumption should end as a pinning test, not as
a corrected sentence.** The IndexedStack ambiguity worry was reasonable,
predicted in the plan, and wrong. The correction is now held by
flutter/test/nav_ambiguity_test.dart, which quotes the SDK element it depends
on, explains that the assumption is imported from the SDK rather than owned
by this app, and fails first if a future Flutter release changes the onstage
walk, at which point dozens of tests would otherwise silently target the
wrong screen.

**Guard, SHIPPED, strong.** The pinning test, including the index-flip test
that keeps the other two honest. Related and worth recording as a pattern
that paid for itself: the single navigation seam
(flutter/test/support/app_harness.dart) meant moving Menu off the bottom bar
cost a 2 line change in one file instead of edits across 24 test files, and
its openMenu finder is byTooltip, so the finder breaking would itself signal
a real accessibility regression.

**Lesson 6. Existing tests caught a real navigation bug mid-refactor, and a
guard firing is the process working.** Three screens used a single pop()
before switching tabs, which stranded the user on the now-pushed Menu with
the tab changed silently behind it. Fixed with popUntil isFirst, reasons
written at the call sites (flutter/lib/screens/pan.dart:120,
search.dart:81, reports.dart:1348). No new guard, the suite already held.

**Lesson 7. CLAUDE.md fact check, run as a step of the session, not as a
favour.** What still matches, checked against the repository: every path the
file names exists where it says (flutter/shorebird.yaml,
flutter/test/update_stamp_test.dart, flutter/test/screens_shot.dart,
flutter/lib/widgets/salapify_icon.dart, docs/delivery-log.md); /opt/flutter
reports Flutter 3.44.6 stable; all five skills exist in .claude/skills; the
120 character stamp cap is enforced at update_stamp_test.dart:20;
flutter-check.yml triggers on `claude/**` at line 20; mobile/lib/storage.js
still holds salapify_data_v2; the three delivery commands ran as written and
returned f2.57 patch 6; and the screenshot harness still covers Menu and the
tabs after the restructure.

**No NEW false claim was found this session, which breaks a three session
streak. The OLD one is still there.** CLAUDE.md:17 and CLAUDE.md:157 still
name the branch claude/salapify-v2, which does not exist, and
flutter-preview.yml:13 still lists it as a publish trigger. That is session
5's Open 12, found, written down, and not yet fixed, now surviving its second
session as a known false sentence read with authority. It is a five minute
edit. It should not survive a third session, and if anyone ever recreates a
branch by that name, pushes to it begin publishing to the founder's phone
from a working branch. Still open, and now overdue rather than merely open.

### Open lessons carried forward

**Open 3, nothing compares the phone to main: STILL OPEN, by design, and this
round it cost zero.** The founder confirmed f2.57 patch 6 in person and it
matched the last delivery row exactly. The phone half of the comparison is
still a human, and this session that human had nothing to report, which is
the cheap case.

**Open 6, the watchdog has never been OBSERVED running a scheduled pass:
STILL OPEN.** The GitHub API still returns 403 from this sandbox, so run
history is unreadable, same limit as sessions 4 and 5. What the log shows is
that it did not fire spuriously today, and both merge-to-row gaps (10 and 11
minutes) were far inside its 2700 second grace. Closes on one observed run.

**Open 7, the watchdog is a stall detector, not an audit trail: STILL OPEN.**
Nothing changed. Open 9 remains the fix for the audit half.

**Open 8, split the publish step from the log scraping step: STILL OPEN,
verified.** The grep still runs inside the same step as the shorebird
commands (flutter-preview.yml, the ship step around line 100 to 125), so a
future failure in the reading half would again suppress the APK upload and
the delivery row. The `|| true` protects the one known shape only.

**Open 9, record failed publishes as FAILED rows in docs/delivery-log.md:
STILL OPEN, verified.** No FAILED mode exists in the workflow and no such row
exists in the log.

**Open 10, nothing holds Pan's rendered size: STILL OPEN, verified.** No ink
fraction test and no named margin constant exist; the three tuned numbers
from 830b021 are still unguarded.

**Open 11, nothing stops a sixth private kicker: STILL OPEN, with a note in
its favour.** No lib scanning test exists yet. This session did make the same
class of move again in the right direction, two hand-rolled segment controls
became one shared widget (flutter/lib/widgets/segmented.dart) for exactly the
five-kickers reason, so the pattern is being resisted by habit. Habit is the
weakest tier, which is why this stays open.

**Open 12, CLAUDE.md names a branch that does not exist: STILL OPEN and now
OVERDUE.** See Lesson 7. Two sentences in CLAUDE.md plus one dead trigger
entry in flutter-preview.yml:13. Second session in a row as a known false
claim.

### Guard status re-check

Read, not assumed. Nothing has been quietly deleted, disabled, or routed
around.

- The `|| true` on the ship log scrape: PRESENT with its sixteen line
  comment, flutter-preview.yml:124.
- The nothing-shipped failure issue: PRESENT, flutter-preview.yml:221.
- The release install shout: PRESENT, flutter-preview.yml:246, and correctly
  silent today, both rows were patches.
- The auto-close on recovery: PRESENT, flutter-preview.yml:263.
- The duplicate stamp refusal: PRESENT, flutter-preview.yml:176.
- The publisher watching its own path, and concurrency with
  `cancel-in-progress: false`: PRESENT, flutter-preview.yml:15 and :33.
- The delivery watchdog with `--first-parent` and the 2700 second grace:
  PRESENT, delivery-watchdog.yml:43 and :99.
- flutter-check.yml on `claude/**`, the screenshot harness step with
  `--update-goldens`, and the branch-stamp-versus-delivered step: PRESENT,
  lines 20, 80, 91.
- The stamp cap: PRESENT and passing, update_stamp_test.dart:20.
- The Pan folder sum and the nothing-but-Pan test: PRESENT,
  pan_asset_test.dart:94 and :120.
- pan_signature_test.dart: PRESENT.
- The shared Kicker widget: PRESENT, flutter/lib/widgets/section.dart:28.
- The whole suite: 814 tests green and analyze clean, run in this session.

New guards added this round, for the next session to re-check:
flutter/test/a11y_test.dart (four guidelines, the Menu sweep with its
three-screenful floor), flutter/test/nav_ambiguity_test.dart, the clock seam
at overview.dart:116, and test/support/app_harness.dart as the suite's single
navigation seam.

### What it cost, and what it did not

Cost: one light-mode-only contrast bug live on the phone for about 92
minutes, almost certainly never seen because the founder uses dark mode.
Three rounds of rewriting an accessibility suite before it measured anything,
which is labour that a naive first green would have skipped and regretted.
Three failed fixture rewrites before the clock seam. One silent throwaway
watcher, replaced within the hour.

Did not cost: any delivery failure, any wrong number, any manual install, any
founder-reported bug, any founder round spent as the detector. Both merges
delivered on the normal schedule, the founder's phone matched the log on the
first read, and every real bug found this round, the contrast surface, the
unreachable segmented control, the unlabeled switches, the stranded-on-Menu
pop, the duplicated committed figure, was found by a test or by the
prove-it-fails discipline before the founder could meet it.

### For the founder, in plain English

A few words first. **Contrast** is how strongly text stands out from what is
behind it, written as a ratio; 4.5 to 1 is the accepted floor for body text,
and 1.21 to 1 is barely darker than the background. A **screen reader** is
the phone feature that reads the screen aloud for people who cannot see it
well, and an **accessibility test** checks, with numbers, that buttons are
big enough to tap, labelled, and readable.

**What happened.** Both updates reached your phone and you confirmed the
second one yourself, f2.57, patch 6. The pipeline was boring twice, ten and
eleven minutes each, which is exactly what we want from it.

One real bug did ship in between, and I want to tell you about it even
though you almost certainly never saw it. When we moved Menu from the bottom
bar to the top right corner, Menu lost its background layer. In dark mode,
the mode you use, that accident happened to look nearly right. In light mode
the Menu title was almost the same shade as the empty space behind it, 1.21
to 1 where 4.5 to 1 is the floor. My habit is to look at the dark
screenshots first because dark is what you use, and that habit is exactly
why no eye caught this: the one mode a person deprioritises is the one mode
a bug like this can live in alone. It was live for about an hour and a half
and was fixed in the second batch.

What caught it was not a person. The second batch added a set of automated
accessibility checks that measure every screen with numbers: is every button
at least 48 pixels tall, does every control have a name a screen reader can
speak, does every piece of text clear the contrast floor. Numbers do not
have a favourite brightness. The contrast check measured the Menu title,
said 1.21, and failed, and that failure is the whole reason you never saw
this bug get worse.

**The part I most want you to understand.** When I first wrote those
accessibility checks, they all passed immediately, and that is exactly when
I trusted them least. We have a standing rule: before trusting a new test,
break the app on purpose and watch the test notice. Doing that revealed,
three separate times, that the checks were passing while measuring nothing.
The most serious case was also a real bug: the little two-way switch we use
on some screens had been built in a way that made it completely invisible to
screen readers, no name, no way to press it, and invisible to the checker
for the very same reason. A blind user could not have used it at all. It is
fixed, and the checker now genuinely measures it. A test that passes on its
first try has proven nothing yet. Breaking things on purpose is how a green
light earns the right to be believed.

Two smaller things from the round. Home briefly showed the same committed
amount twice, in two cards, because two correct changes met each other; that
is fixed, and the test that guards it now picks its own date on the
calendar, because it used to quietly excuse itself from running on most days
of the month, and a smoke alarm that takes its own battery out is not an
alarm. And an early version of my build-watching script failed silently, so
silence looked like a build still running; it now reads the delivery log
directly and says something loud in both directions, update arrived or
nothing after 35 minutes.

**What it costs if a guard is removed.** Delete the accessibility test file
and the next missing-background bug ships in whichever mode you do not use,
silently, and the next unlabelled control ships unusable to screen reader
users, which will matter at launch far beyond you and me. Shrink the Menu
part of that test and the middle of the Menu screen goes unmeasured; there is
an assertion that fails if the sweep ever covers less than three screenfuls,
specifically so that cannot happen quietly.

**One thing I owe you straight.** Last session I found that our own rules
file names a work branch that no longer exists, in two places. It is still
not fixed. It has caused no harm, and it is a five minute edit, but a rules
file that states something false gets read with authority, so I am flagging
that it is now overdue rather than letting it fade. Beyond that, this was
the round we have been building toward since session 1: two clean
deliveries, and every bug found by a test before it could reach you, instead
of by you after it did.

---

## 2026-07-26, session 5: the release that published and then threw its own APK away

### What we believed / What was true

Five beliefs. Two were true, three were not, and the most expensive one is the
one that looked most obviously true.

**Believed: every stamp shipped today reached the phone. TRUE.** Read from
`git show origin/main:docs/delivery-log.md`, not assumed: f2.40 patch 34 at
01:53 UTC, f2.41 patch 35 at 03:11, f2.44 release 0.6.1+10 at 04:42, f2.47
release 0.6.2+11 at 07:00, f2.49 patch 1 on 0.6.2+11 at 09:51.
`flutter/pubspec.yaml` is 0.6.2+11, which matches the last release, and f2.49
patched onto it cleanly. The founder installed both base APKs and confirmed on
the phone. The installed base is not stranded.

**Believed: the five missing stamps are all the same benign thing. FALSE for
one of them, and that one is this session.** f2.42, f2.43, f2.45, f2.46 and
f2.48 have no delivery row. Four are benign: 1a5a097 (f2.42) was superseded by
0bc35a4 (f2.43) inside pull request #199, 989e667 (f2.45) and d76080b (f2.46)
were superseded by 3a2a91c (f2.47) inside #203, and 830b021 (f2.48) was
superseded by 75c1b37 (f2.49) inside #204. None of those stamps ever existed on
main. f2.43 did. It was the stamp on merge commit 4697ef2, which landed on main
at 04:00 UTC and delivered nothing at all.

That gives a clean reading rule for the next person looking at a gap in the
log: **a missing stamp is benign when it only ever existed on a working branch,
and it is an incident when it reached main.** Establishing which of the two it
was today took reading four commits, and that is a finding in itself (Lesson 2).

**Believed: a successful Shorebird publish means the founder has something to
install. FALSE.** Release 0.6.0+9 published fine and the step then failed
anyway. From the log, quoted in 4d2fbba:

    Published Release 0.6.0+9!
    ##[error]Process completed with exit code 1.

**Believed: the Pan asset size guard measured what ships. FALSE.** It summed
four named files. `flutter/pubspec.yaml` declares `- assets/pan/`, a whole
directory, so the bundle is whatever sits in that folder.

**Believed: the typography refresh changed the kicker everywhere. FALSE.**
`_kicker` existed as five private copies. theme.dart and debts.dart moved to
12/w600/1.2. menu, overview, insights and privacy_receipt kept a hand rolled
11/w700/2. The same label rendered two different ways for an unknown length of
time with the whole suite green.

### Timeline (with evidence)

All times UTC. Merge commits carry +0800 committer times in git, converted
here. Delivery times are the publisher's own timestamps in docs/delivery-log.md.

| Time | Event | Evidence |
|------|-------|----------|
| 01:43 | Merge #197 (3ac59da), stamp f2.40 | git log |
| 01:53 | f2.40 patch 34 delivered, 10 minutes | delivery row |
| 03:01 | Merge #198 (a11ab83), stamp f2.41 | git log |
| 03:07 | 1a5a097 stamp f2.42, pubspec 0.5.0+8 to **0.6.0+9**. First native bump since 07-22 | git show 1a5a097:flutter/pubspec.yaml |
| 03:11 | f2.41 patch 35 delivered, 10 minutes. The last patch on 0.5.0+8 | delivery row |
| 03:18 | 0e66c38, "The screenshot harness was showing Pan by luck, not by loading" | git log |
| 03:39 | 0bc35a4 stamp f2.43, the per theme cup tint | git log |
| ~03:54 | **Asset near miss.** Eight intermediate PNGs written into assets/pan while working out the tint, then removed by memory alone | dbbae7e commit message; assets/pan directory mtime 03:54 |
| 03:56 | dbbae7e, the folder guard, proven to fail first | git show dbbae7e |
| **04:00** | **Merge #199 (4697ef2), stamp f2.43, release 0.6.0+9. DIVERGENCE.** Shorebird published, the step then exited 1, no APK was uploaded to the flutter-preview tag and no delivery row was written | no row between f2.41 and f2.44; failure quoted in 4d2fbba |
| ~04:0x | Claude tells the founder the APK is building. It had already failed. The founder asks for the link twice | session record |
| 04:24 | 4d2fbba, `\|\| true` on the grep, reproduced on both log shapes, pubspec 0.6.0+9 to **0.6.1+10** on purpose | git show 4d2fbba |
| 04:31 | Merge #201 (5e73391), stamp f2.44 | git log |
| 04:42 | f2.44 release 0.6.1+10 delivered, 11 minutes. **Manual install one** | delivery row |
| 05:14 | assets/pan/*.png replaced with the founder's Nano Banana renders | file mtimes |
| 05:20 | 989e667 stamp f2.45, pubspec 0.6.1+10 to **0.6.2+11** | git show 989e667:flutter/pubspec.yaml |
| 05:42 | d76080b stamp f2.46. pan_tint_test.dart deleted, pan_signature_test.dart added, guarding the opposite property | git show d76080b --stat |
| 06:09 | 3a2a91c stamp f2.47, Pan speaks in a bubble | git log |
| 06:49 | Merge #203 (c858b12) | git log |
| 07:00 | f2.47 release 0.6.2+11 delivered, 11 minutes. **Manual install two** | delivery row |
| after 07:00 | **Founder installs and reports Pan looks "super small"** | founder message |
| 07:36 | 830b021 stamp f2.48. Sizes 56 to 80, 56 to 76, 36 to 48. Fixed in Dart, not by re-cropping, so it patches | git show 830b021 |
| 09:34 | 75c1b37 stamp f2.49. Menu becomes a grid, five kickers become one | git show 75c1b37 --stat |
| 09:40 | Merge #204 (d0f3688) | git log |
| 09:51 | f2.49 patch 1 on 0.6.2+11 delivered, 11 minutes | delivery row |

Merge to delivery row, measured across five merges: 10, 10, **never**, 11, 11,
11. The pipeline is boringly consistent. The one that broke did not break
slowly, it broke completely, and it looked identical to the others for the
first ten minutes.

### Divergence points

**One, 04:00 UTC, merge 4697ef2.** The delivered stamp stopped matching the
built stamp. It was closed at 04:42, not by re-running the build but by bumping
to a fresh version, and that choice was correct: 0.6.0+9 already existed
server side, so a re-run would have taken the PATCH branch and patched a
release that was on nobody's phone. It cost the founder no extra install
because they had never received the first one.

**Two, invisible and much older.** The line
`PATCH=$(grep -oE 'Published Patch [0-9]+' ship.log | ...)` was correct for
every patch run and had succeeded 35 times. Its divergence point is not a date,
it is a SHAPE: the first release build after the line was added. Today was that
build. This is the classic form of a latent fault, a thing that is not wrong
until an input arrives that nobody thought about, and the input in this case
was the project's own most important event.

**Three, the typography refresh.** Whenever the kicker moved to 12/w600/1.2 in
theme.dart, four screens stopped agreeing with it and nothing said so. The
refresh believed it had changed "the kicker". It had changed one of five
definitions of the kicker.

### Root cause

Four of today's five technical faults are one fault wearing four costumes.
Each is a guard or a calculation that measured a STAND-IN for the thing that
matters, where the stand-in was simply the thing easiest to reach from where
the author was standing, and the stand-in agreed with reality right up until it
did not:

- `grep 'Published Patch'` measured the shape of a PATCH log as a stand-in for
  any ship log. Agreed 35 times.
- The size test summed four named files as a stand-in for the asset bundle.
  Agreed until a stray file existed.
- The typography refresh edited theme.dart as a stand-in for "the kicker".
  Agreed until the copies drifted.
- The widget size was used as a stand-in for how big Pan looks. Agreed while
  the artwork had no transparent margin, and the artwork has 22%.

The general counter move, and the thing to carry forward: **make the guard
measure the artifact that ships, not the declaration of it.** The folder sum
beats the file list. The bundle beats pubspec. The rendered ink beats the
widget box. One shared widget beats five agreeing copies.

There is a second, separate root cause, and it is session 4's returning
unchanged: **a channel that goes silent when it fails, where silence reads as
progress.** That covers the monitor with `except: pass` and it covers Claude
reporting "building" for a build that had already failed. Session 4 named this
exact shape after the 91 minute queue stall. It came back in a different place
within a day, which tells us the guard written for it (the delivery watchdog)
addressed the instance, not the class.

### Lessons and guards

**Lesson 1. A post publish step can undo a publish, and the publish step is the
one place where "the step failed" does not mean "nothing happened".**

The damage was not a red tick. The grep runs inside the same step as the
`shorebird release` command, after it, under `bash -e` with `pipefail`. grep
exits 1 when it matches nothing, and a failing command substitution kills the
step. So the step reported failure AFTER Shorebird had already published, and
both `if: success()` steps that matter were skipped: the APK upload to the
flutter-preview tag, and the delivery log row.

**Guard, SHIPPED, workflow change, strong for the instance.**
.github/workflows/flutter-preview.yml:124 now ends `... | tail -1 || true`,
with a sixteen line comment above it explaining what the two words cost.
Reproduced on both log shapes before fixing, quoted in 4d2fbba:

    release log -> exit=1     patch log -> PATCH=[35], exit=0

**Honest ranking: this fixes the instance, not the class.** The class is that
publishing and reading the log live in ONE step, so any future failure in the
reading half will again be reported as a failure of the publishing half and
will again suppress the APK upload and the row. See Open 8.

**Lesson 2. A run that publishes nothing leaves no trace in the repository, and
once the next merge lands the gap becomes unreadable.**

Anyone reading docs/delivery-log.md today sees f2.41 then f2.44 and cannot tell
whether f2.42 and f2.43 were branch only stamps or a failed delivery. It took
reading four commits and three pull requests to establish which. The delivery
log is explicitly the file the "three commands" check tells us to trust, and it
records only successes.

**Existing partial guard:** the `if: failure()` step at flutter-preview.yml:220
opens an issue titled "Preview build failed, nothing shipped to the phone". It
is loud at the moment of failure and it leaves nothing behind in the
repository, which is where the next session looks.

**Guard, OPEN, proposed, automated tier.** Have the failure step also append a
row to docs/delivery-log.md with mode `FAILED` and no patch number. The
publisher already has `contents: write` and already has a rebase and push loop
at flutter-preview.yml:206. See Open 9.

**Lesson 3. A guard that counts the files it already knows about cannot see the
file it does not.**

The near miss: working out the theme tint meant writing eight intermediate PNGs
into assets/pan, and they were cleaned up from memory alone. Had they survived,
all eight would have shipped (pubspec declares the directory), the size guard
would still have PASSED, and the first symptom would have arrived days later as
Shorebird refusing to patch against a changed asset bundle, in an error message
that says nothing about stray files.

**Guard, SHIPPED, test, strongest tier, and re-proven in this session.**
flutter/test/pan_asset_test.dart:88 now sums `Directory('assets/pan')`, and
flutter/test/pan_asset_test.dart:108 adds "nothing but Pan lives in the Pan
folder". Proven to fail before it was trusted, message quoted in dbbae7e. I did
not take that on trust: I copied one extra PNG into assets/pan and ran the
suite, which gave

    Unexpected file(s) in assets/pan: assets/pan/zz-stray-probe.png.
    00:00 +5 -1: Some tests failed.

then removed it and confirmed the folder is back to four faces. **Sufficient.**

**Lesson 4. A private copy of a style is invisible to every test.**

Five `_kicker` definitions, two of them updated by the typography refresh and
four not, 750 plus tests green throughout. Nothing failed because nothing could:
a private const inside a screen file is not reachable by any assertion.

**Guard, SHIPPED, partial.** One shared `Kicker` widget at
flutter/lib/widgets/section.dart, and all five call sites moved onto it. It is
deliberately NOT const, with a comment explaining that a const call site would
let `Element.updateChild` skip build and freeze the label in the previous
theme's colour. That removes today's divergence. **It does not stop the sixth
copy.**

**Guard, OPEN, proposed, automated tier.** A source scanning test that reads
`Directory('lib')` and fails on any `TextStyle` with `letterSpacing` at or
above 1.5 outside theme.dart, which is the signature of a hand rolled kicker.
Note there is no precedent for a lib scanning test in this suite yet, so it
needs proving by breaking it, like any other. See Open 11.

This lesson and Lesson 3 are the same lesson. Both measured the declaration
instead of the thing that ships.

**Lesson 5. Rendering the screen caught two real bugs, and it caught them
because it looks at the artifact rather than at a description of it.**

Two defects, neither of which any test would have found:

- A disposed `TextEditingController`. Disposing it as soon as `showDialog`
  returns looks right and throws "A TextEditingController was used after being
  disposed" every single time, because the exit animation still rebuilds the
  field. That is a crash, caught before the merge.
- Pan dissolving into his own background on the new Ask Pan banner. Pan is a
  fixed orange, the banner is filled with the accent, and on Barako those are
  the same orange. Invisible in the code, obvious in the shot. He now sits on a
  darker disc.

What made it work is specific and worth naming: it was run BEFORE the merge, on
the screens that changed, at both brightnesses, and someone actually looked at
the dark ones. The CLAUDE.md rule names that moment precisely, which is why it
fired.

**Guard: already in place and sufficient for what it can cover.**
.github/workflows/flutter-check.yml runs screens_shot.dart with
`--update-goldens`, which proves the harness still renders. It cannot prove
somebody looked, and no guard can.

**Lesson 6. A render shows you what is WRONG. It does not show you what is the
wrong SIZE, because a render has no reference beside it.**

Pan shipped at 56 logical pixels on Home. The artwork carries 22% transparent
margin inside its own canvas, so the cup actually drew 43 pixels there and 28
in the Ask Pan header. Every one of those renders was looked at and passed,
because 28 pixels of cup looks like a small character rather than like a bug.
The founder installed 0.6.2+11 and said Pan looks super small.

Root cause: the margin was inherited from matching the previous drawn cup's
framing exactly, which was the right call for visual consistency and quietly
capped how large Pan could ever appear. After that, nothing ever compared the
drawn cup against the box it sits in. **Widget size was a stand-in for cup
size, and it was wrong by 22% forever.**

The fix at 830b021 deserves credit for the part it got right: it changed the
SIZES rather than re-cropping the PNGs, specifically because assets cannot be
patched and re-cropping would have cost the founder a third manual install in
one day. Pure Dart ships over the air.

**Guard, OPEN, proposed, automated tier.** The fix is three numbers with no
test behind it, so the next person tuning a size can undo it silently. Either
a test that loads each face, finds the opaque bounding box, and asserts the ink
covers a minimum fraction of the canvas; or, cheaper and more honest, name the
margin as a constant in pan_mascot.dart so every call site is written in CUP
size and the widget box is computed from it. The second is a code change with
no test, so it is medium. See Open 10.

**Lesson 7. The rule "finished means delivered" existed, was correct, and did
not fire, because it forbids a narrower sentence than the one that was said.**

CLAUDE.md says: "Never tell the founder a stamp is live until a row for it
exists." Claude did not say live. Claude said the APK was building, which the
founder heard as "it is on its way", and it was not, it had already failed. The
founder then had to ask for the link twice.

Why no automated guard covered it, precisely:

- The `if: failure()` issue step at flutter-preview.yml:220 is designed to fire
  here. I cannot confirm from this sandbox that it did: the GitHub API returns
  403 through the proxy and there is no `gh` CLI, so I am stating what the
  workflow does, not what I observed. That limit is itself worth recording.
- The delivery watchdog did NOT fire, and that was CORRECT. f2.43 sat
  undelivered on main from 04:00 to 04:31, which is 31 minutes, inside the 45
  minute grace window set by `GRACE_SECONDS: '2700'`. So the watchdog stayed
  silent when it should stay silent, which is the exact half that was broken on
  its first version. Good news about the watchdog, and no help whatsoever here.
- Both of those report asynchronously, into GitHub Issues. The wrong sentence
  was said within minutes of the merge, in chat.

**Root cause, structural: nothing forces the delivery log to be READ in the
same turn as the sentence that describes a build.** Every automated signal is a
backstop measured in tens of minutes. The report to the founder happens in
seconds.

**Guard, MEDIUM, and I will not dress it up.** Broaden the CLAUDE.md ban from
"live" to any statement about a build's FATE, including "building", "on its
way", and "should land shortly", unless
`git show origin/main:docs/delivery-log.md | tail -1` was run in that same turn
and the result quoted. Medium because it depends on being read at the right
moment. The evidence that this tier is genuinely weaker is sitting in this very
lesson: a correct rule was present and did not bite, because it named a
narrower thing than the failure. **No test can stop a sentence, so this lesson
does not get a strong guard, and it should be re-checked every session until
it survives a real temptation.**

**Lesson 8. A monitor that swallows its errors is a monitor that reports
success.**

A monitoring loop written during this session used a bare `except: pass`, so a
total failure of the thing it watched would have looked exactly like "still
running". It was rewritten to report failure. It was never committed, and there
is no Python anywhere in the repository, which is itself the finding: **the
tool that was meant to detect the outage was throwaway, so its bug got no
review and its lesson has nowhere to live.**

**Guard: the standing rule already covers this exactly.** CLAUDE.md's alarm
rule says to prove both halves, that it fires when it should and stays silent
when it should, and that an alarm which cries wolf gets its battery taken out.
It was written for committed alarms and was simply not applied to a five line
script.

**Guard, MEDIUM to WEAK, proposed.** State in CLAUDE.md that the alarm rule
applies to throwaway tooling too, since throwaway tooling is the one kind that
gets no review. The genuinely strong version of this lesson is not a new guard
at all: **do not write ad hoc monitors, read docs/delivery-log.md**, which the
three commands already say and which needs no code.

**Lesson 9. Two manual installs in one day, both for the same feature, plus one
release nobody could install.**

pubspec went 0.5.0+8, then 0.6.0+9 at 03:07 (published to Shorebird, never
installable), then 0.6.1+10 at 04:24 (installed), then 0.6.2+11 at 05:20
(installed). Two hand installs five hours apart, both for Pan's face. Assets
cannot be patched, so the four PNGs forced a release; then the artwork was
replaced with a better set three hours later, which forced a second one.

**Guard for the DANGER, existing, sufficient, and it worked.** The
`mode == 'release'` step at flutter-preview.yml:245 opens an issue titled
"Install the new APK by hand, or the phone stops receiving updates". The
founder installed both, and f2.49 landed as patch 1 on 0.6.2+11, which proves
the phone is on the current release. Nobody was stranded.

**Guard for the COST, OPEN and honestly WEAK.** Nothing stops a second release
on the same day. The rule would be: settle the artwork before the release that
carries it, because every asset change costs the founder a manual install. That
is a habit, the weakest tier, and I am saying so out loud rather than promoting
it. It is worth writing down anyway because the counter example is already in
the log: at 07:36 the size fix was deliberately made in Dart rather than by
re-cropping, precisely to avoid a third install. The judgement is present. It
just is not enforceable.

**Lesson 10. A test was deleted and replaced by one asserting the opposite, and
this is NOT the usual case. Naming the difference is the point.**

flutter/test/pan_tint_test.dart was deleted at d76080b. It had asserted, among
eleven tests, that Pan MUST recolour per theme:

    test('a different theme really does recolour the cup', () {
      final m = panTintMatrix(...);
      expect(m, isNotNull, reason: 'Mint is nowhere near orange');
      ...
      reason: 'the matrix exists but leaves the cup orange');

Session 3's standing rule is that a test which had to change for a fix to pass
was asserting the bug. **That rule does not apply here, and saying so plainly
matters more than applying it reflexively.** This test was not defending a
defect. It correctly guarded a design decision that the founder reversed the
same day: Pan keeps one signature colour rather than following the wallpaper
(founder, 2026-07-26). The machinery was built, measured across all eight
palettes, rendered, and then removed on purpose.

The distinction to keep: **a test that changes because the CODE was wrong is
evidence of a defended bug. A test that changes because the DECISION changed is
evidence of a decision that is now held by something.** Both get quoted in the
entry. Only the first is a finding.

**Guard, SHIPPED, strong.** flutter/test/pan_signature_test.dart replaces it
and names the three realistic ways the old behaviour returns: wrapping the
artwork in a `ColorFiltered` again, giving `PanCupPainter`'s palette a live
Barako default again, or reading a Barako getter inside `PanMascot.build`. I
ran it in this session, four tests, all pass.

**Lesson 11. CLAUDE.md fact check: one false claim, third session in a row.**

Checked as a step of the session, not as a favour. What still matches:

- flutter/shorebird.yaml, flutter/test/update_stamp_test.dart,
  flutter/test/screens_shot.dart, flutter/lib/widgets/salapify_icon.dart and
  docs/delivery-log.md all exist exactly where they are named.
- /opt/flutter exists and reports "Flutter 3.44.6 stable", matching the version
  the rules name.
- All five skills named in the Skills section exist in .claude/skills.
- The 120 character stamp cap is real and enforced,
  flutter/test/update_stamp_test.dart:20, `lessThanOrEqualTo(120)`. Four tests,
  all pass.
- flutter-check.yml triggers on `'claude/**'`, exactly as rule 1 says.
- The three delivery commands run as written and returned f2.49 patch 1.
- mobile/ still holds salapify_data_v2 (mobile/lib/storage.js).
- The screenshot harness output goes to test/shots/ as documented, and the
  directory listing is the count, as the rule insists.

**FALSE: "Develop on the branch claude/salapify-v2 and open PRs to main"**
(Development workflow, item 1). That branch does not exist. `git branch -a`
returns only `main` and `claude/salapify-continuation-3i8jup`, and
`git ls-remote --heads origin` returns `main` alone. All of today's work
happened on claude/salapify-continuation-3i8jup.

**Stale in the same way:** Flutter rule 1 says pushes to "main or
claude/salapify-v2" that touch flutter/ run the preview publisher, and
.github/workflows/flutter-preview.yml:13 still lists `claude/salapify-v2` in
its branch trigger.

How bad is it today: **harmless, in the safe direction.** The working branch
does not match the publisher's trigger, so branch pushes published nothing,
which is exactly what rule 1 wants. The Flutter check did run on every branch
push, because `claude/**` matches. No delivery was affected.

Why it still matters: it is precisely the trap this session is instructed to
hunt. Both sentences name a real thing that has MOVED, so no checker can catch
them, and a beginner founder reading item 1 would push to a branch that is not
there. It is also a live trap in one direction: if anyone ever recreates a
branch called claude/salapify-v2, pushes to it would begin publishing to the
founder's phone from a working branch, which is the thing rule 1 exists to
prevent.

**Guard, MEDIUM.** Fix the two CLAUDE.md sentences to name the working branch
PATTERN (`claude/**`) rather than one branch name, and decide deliberately
whether flutter-preview.yml:13 keeps a dead branch in its trigger. See Open 12.

**The pattern, stated honestly: three consecutive sessions, three false factual
claims in CLAUDE.md, all the same kind, a name that was true when written. The
rate is not falling.** The only thing catching them is this fact check, which
means the fact check is now load bearing and must not be skipped when a session
is short.

### Open lessons carried forward

**Open 3, nothing compares the phone to main: STILL OPEN, by design.** The
repository half is watched every 30 minutes. The phone half was closed twice
today, once by the founder installing an APK and once by the founder reporting
Pan was small, and both times the founder was the detector. That is the
architecture, not a defect. It cost one round.

**Open 6, the watchdog is written but not yet OBSERVED running: STILL OPEN, and
I cannot close it from here.** The GitHub API returns 403 through this
sandbox's proxy and there is no `gh` CLI, so run history is unreadable. What I
can say from the delivery log is that it did not fire spuriously, and that its
grace window correctly covered the one 31 minute gap today. Closing this needs
one observed scheduled run.

**Open 7, a merge that touches flutter/ without bumping the stamp is invisible
to the watchdog: STILL OPEN, and today adds a second blind spot to it.** The
watchdog compares main's CURRENT stamp against the last delivered one. When
f2.43 failed and f2.44 replaced it 31 minutes later, the watchdog's answer
became "ok" and the failed delivery became invisible to it forever. **It is a
stall detector, not an audit trail.** Open 9 is the fix for that half.

**NEW Open 8: split the publish step from the log scraping step in
flutter-preview.yml,** so a failure while READING the log can never suppress
the APK upload or the delivery row. Automated tier. Not done.

**NEW Open 9: record failed publishes in docs/delivery-log.md** with mode
`FAILED`, so a gap in the log is self explaining instead of needing four
commits of archaeology. Automated tier. Not done.

**NEW Open 10: nothing holds Pan's rendered size.** Three tuned numbers, no
test. Automated tier available. Not done.

**NEW Open 11: nothing stops a sixth private kicker.** The five were merged
into one widget; the pattern that created them is untouched. Automated tier
available, with no precedent in this suite for scanning lib/. Not done.

**NEW Open 12: CLAUDE.md names a branch that does not exist,** in two places,
plus one dead entry in flutter-preview.yml's trigger. Medium tier. Not done.

### Guard status re-check

Read, not assumed. Nothing has been quietly deleted or routed around.

- flutter-check.yml on `'claude/**'`: PRESENT, and it covered today's branch
  even though that branch is not the one CLAUDE.md names.
  .github/workflows/flutter-check.yml:20.
- The nothing-shipped failure issue: PRESENT, flutter-preview.yml:220.
- The release install shout: PRESENT and it fired twice today by design,
  flutter-preview.yml:245.
- The auto-close on recovery: PRESENT, flutter-preview.yml:262.
- The duplicate stamp refusal: PRESENT, flutter-preview.yml:173.
- The publisher watching its own definition (session 2's finding): PRESENT,
  flutter-preview.yml:23. It earned its keep today: 4d2fbba edited only the
  workflow and a Dart file, and the workflow being in its own paths filter is
  what guarantees a publisher edit exercises the publisher.
- The concurrency group with `cancel-in-progress: false`: PRESENT,
  flutter-preview.yml:31.
- The delivery watchdog: PRESENT, .github/workflows/delivery-watchdog.yml,
  including the `--first-parent` fix and the 2700 second grace.
- The stamp cap: PRESENT and passing, four tests.
- The screenshot harness in CI with `--update-goldens`: PRESENT.
- pan_tint_test.dart: DELETED on purpose, replaced by pan_signature_test.dart
  guarding the opposite property. Lesson 10.

### What it cost, and what it did not

Cost: one merge that delivered nothing and had to be re-shipped under a new
version number, roughly 40 minutes plus one round of the founder asking twice
for a link that did not exist. Two manual APK installs in one day for one
feature. One round where the founder was the detector for a size problem. And
about three hours of build, measure and render work on Pan's per theme colour
that was deliberately deleted the same day, which is not waste, that is a
decision being made properly with the evidence in front of it.

Did not cost: any wrong number, any lost data, any stranded install, any real
stray asset shipped. Every stamp that reached the phone was the right one,
patch 1 landed cleanly on 0.6.2+11, and the near miss with the eight PNGs was
caught by the person who made it and turned into a test the same hour.

### For the founder, in plain English

Some words first, so the rest reads straight.

A **patch** is a small update the app downloads by itself when you reopen it.
A **release** is a whole new app file, an APK, that you have to install by
hand. Patches can only be applied on top of the exact release they were built
for, and anything involving pictures has to be a release, because patches
cannot carry pictures.

**What happened.** Five updates reached your phone today and all five were
correct. One did not, and you noticed before we told you, which is the part
worth fixing.

At 04:00 in the morning we merged the batch with Pan's real face. That one
needed a new app file, because it contains pictures. The publishing robot did
its job, made the release, and then tripped over its own shoelace on the very
last instruction. Here is the shoelace, and it is almost funny. After
publishing, the robot reads its own log to find out which patch number it just
shipped, so it can write that number down for you. On a normal update the log
says "Published Patch 35" and the robot finds it. On a NEW APP FILE the log
never says that, because there is no patch number, there is a version number.
The robot searched, found nothing, and the tool it searches with treats
"found nothing" as an error. So the robot declared failure, and everything
after that point was skipped: it never uploaded the app file for you to
download, and it never wrote the row that tells us something shipped.

The cruel part is the order. It failed AFTER succeeding. The release existed on
the server, so from every angle except your phone it looked done. And I told
you the APK was building. It was not building. It was already dead. You asked
for the link twice, and both times there was no link to give, because the file
had never been uploaded.

**Why it happened.** That one line had worked 35 times in a row. It only ever
sees normal updates, and normal updates always have the word it is looking for.
The first time it met a new app file, it broke. Nothing was rushed and nobody
was careless. A thing that had never been tested against a rare input met that
input for the first time, and the rare input happened to be the most important
event we have.

The same shape caused three other things today. A test that checked the size of
Pan's picture folder was actually only adding up four files by name, while the
app ships the whole folder, so eight leftover files I made while experimenting
would have shipped invisibly and broken future updates days later. A style used
across the app turned out to be written out five separate times, and two of
them had been updated and three had not, so the same little heading looked
different depending on the screen. And Pan looked tiny to you because his
picture has empty space built into its edges, 22% of it, so asking for 56
pixels of Pan gave you 43 pixels of actual cup.

All four are the same mistake: we measured something CLOSE to the real thing
instead of the real thing itself, and the close thing agreed with reality until
the day it did not.

**What now makes it impossible.**

The publishing robot no longer treats "found nothing" as an error, and there is
a long comment above that line explaining what it cost, so nobody tidies it
away.

The picture folder test now weighs the actual folder, and a second test fails
if there is anything in there that is not one of Pan's four faces. I did not
take that on trust: I put a fake stray file in the folder during this session
and watched the test go red with the file's name in the message, then removed
it.

The five copies of that heading style are now one.

**What it costs if a guard is removed.** Take the two words `|| true` out of
the publishing robot and the next new app file publishes to the server and
never reaches you, silently, exactly as it did this morning. Take the stray
file test out and the next stray picture ships, and the symptom arrives days
later as updates mysteriously refusing to install, in an error message that
mentions nothing about stray files.

**Three things I want to be straight with you about.**

First, the guard that failed today was not a piece of code, it was me. The rule
"never say it shipped until the log says it shipped" was already written down
and it was right. It says do not say "live". I said "building", which is not
the banned word but meant the same thing to you. I am tightening the rule to
cover any sentence about a build at all, and I want to be honest that a written
rule is a weaker guard than a test. A test works when nobody is watching. A
rule only works when it is read at the right moment, and this one was not.

Second, you had to install the app by hand twice in one day, five hours apart,
for the same feature. That is more than it should have been. The first install
was needed because pictures cannot be patched. The second was needed because we
replaced the pictures with better ones afterwards. Settling the artwork first
would have cost you one install instead of two. When you said Pan looked too
small, we deliberately fixed it by changing numbers in the code rather than
re-cropping the pictures, specifically so it could reach you over the air with
no third install. That part went right.

Third, and this is a small thing that will otherwise confuse you: your Update
stamp row now shows **patch 1**, after showing patch 35 this morning. That is
not a step backwards. The patch counter starts again at 1 for every new app
file, and you installed two new app files today. Patch 1 on version 0.6.2+11 is
newer than patch 35 on version 0.5.0+8.

One last note, since it is the sort of thing you should be told rather than
left to find. Our own rules file tells us to work on a branch called
`claude/salapify-v2`. That branch does not exist any more. It has not caused
any harm, and today's work still got checked properly, but it is the third time
in three of these sessions that our rules file has confidently stated something
that is no longer true. A wrong rule is worse than no rule, because it gets
read with authority. It is on the list to fix.

---

## 2026-07-25, session 4: the wall, the boxes, and ninety one minutes of nothing

### What we believed / What was true

Four beliefs this round. One of them was true, and it is the one that matters
most.

**Believed: all four stamps reached the phone. TRUE.** Read from
`git show origin/main:docs/delivery-log.md`, not assumed: f2.36 patch 30 at
07:21 UTC, f2.37 patch 31 at 08:01, f2.38 patch 32 at 10:36, f2.39 patch 33 at
11:57. All mode `patch`, all app version 0.5.0+8, `flutter/pubspec.yaml` still
`0.5.0+8` so no base APK was stranded. The founder confirmed on the phone that
the lesson ticks are back, which closes the f2.34 fix from session 3 with the
only evidence that counts. Delivery worked. This entry is not about a delivery
failure.

**Believed: the Update stamp was a row.** True: it was roughly forty lines. The
founder sent a screenshot of it filling the whole screen. Measured from git
rather than described: the stamp text was 424 characters at f2.34, 765 at
f2.35, 896 at f2.36, and 1264 at f2.37, which is what the founder photographed.
The number of version names inside it went 1, 2, 3, 4. Each build appended the
previous build's notes instead of replacing them, and the row it lived in was a
right-aligned `Text` with no line limit, so nothing pushed back. This was
self-inflicted, by Claude, over six consecutive builds, and the founder had to
be the one to notice.

**Believed: boxes in the screenshot render are a harmless sandbox artifact, and
CLAUDE.md said so in writing.** True: twice in one day the boxes were the
defect. First when icons became the thing being reviewed, second when the
diagnostics report used a monospace font the harness does not have, so the one
screen in the app that shows data leaving the phone rendered as solid boxes.
The note that excused boxes was accurate when it was written. That is what made
it dangerous.

**Believed: a merge to main publishes in about eleven minutes.** True, usually.
Measured across this round: 11 minutes, 11 minutes, 9 minutes, and once 102
minutes, because the run sat in GitHub's queue for 91 minutes waiting for a
free runner. Nothing in the repository was wrong. Nothing in the repository
said a word either.

### Timeline (with evidence)

All times UTC, from the commit dates and from the timestamps the publisher
wrote into docs/delivery-log.md. Stamp lengths measured by extracting the
`updateStamp` constant from each commit.

| Time | Event | Evidence |
|------|-------|----------|
| 06:24 (prev round) | **Wall divergence.** c68f750 writes f2.35 and, for the first time, appends the previous build's notes. 765 characters, two version names | git show c68f750:flutter/lib/main.dart |
| 07:04 | 8fa04b7, stamp f2.36, 896 characters, three version names | git log |
| 07:10 | Merge #192 (624af1b) | delivery row f2.36 patch 30 at 07:21 |
| 07:44 | 35024fc, one orange icon family. Stamp f2.37, 1264 characters, four version names | git log |
| 07:44 | The renderer is taught to load MaterialIcons from the running SDK, and to print a loud WARNING if it cannot find it | flutter/test/screens_shot.dart |
| 07:50 | Merge #193 (3f9c23f) | delivery row f2.37 patch 31 at 08:01 |
| after 08:01 | **Founder screenshot: the stamp row fills the screen** | founder message |
| 08:20 | 44f0237, the renderer draws dark as well as light | git log |
| 08:49 | 3de299e, stamp f2.38 cut to 82 characters. test/update_stamp_test.dart added. update_card.dart gains maxLines 4. Two false lines in CLAUDE.md corrected | git show 3de299e --stat |
| 08:54 | Merge #194 (8d71c91) | git log |
| 08:54 to 10:25 | **Queue divergence.** The publish run never starts. No runner. Zero runs in progress, all four workflows from the merge stuck identically. Not cancelled and not re-pushed, on purpose, because both add jobs to a queue that is not moving | session record |
| 10:25 | c55367f, the Copy diagnostics button. The render shows the report as solid boxes, monospace removed, three stacked button labels shortened. Stamp f2.39, 76 characters | commit message of c55367f |
| 10:36 | f2.38 finally publishes, 102 minutes after its merge | delivery row f2.38 patch 32 |
| 11:48 | Merge #195 (3a8b46a) | git log |
| 11:57 | f2.39 delivered, 9 minutes after merge | delivery row f2.39 patch 33 |
| 13:16 | 4fde57a, .github/workflows/delivery-watchdog.yml | git log |

Merge to delivery row, measured: 11, 11, 102, 9 minutes. The normal case is 9
to 11 minutes. That measurement is what justifies the watchdog's 45 minute
grace window, which is four times normal.

Verified on the checkout at the time of writing: `flutter analyze` reports "No
issues found", `flutter test` reports **693 tests passing**, and the screenshot
harness writes its shots in about eleven seconds.

Limitation, stated rather than hidden: the claim that zero runs were in
progress during the queue comes from the session record, not from a fresh
query. What does not need any API is the timing, and the timing alone proves
the anomaly: three merges in this round went from merge to delivery row in 9 to
11 minutes, and one took 102. That comparison comes entirely from git and from
docs/delivery-log.md.

### Divergence points

Three, because there were three separate splits between belief and reality, at
three different moments.

**The wall: 06:24 UTC on commit c68f750**, in the round session 3 wrote up. That
is the first push where the stamp stopped naming only itself. It was already
too long before that (326 to 496 characters at f2.30 through f2.34, four to
eight lines on a phone), but the appending is what turned "too long" into
"forty lines". Session 3 did not catch it. Worse, and this is the sharpest
single fact in this entry, session 3's own Lesson 6 **endorsed** it: "when
several stamps merge together, the delivered stamp's text must cover everything
since the last delivery row." That guard, written to stop a stamp's notes being
lost, is the mechanism that grew the wall. A guard aimed at one failure created
another.

**The monospace boxes: the moment the note became true.** There is no commit
for this one. The divergence is that a sentence in CLAUDE.md went from
describing an irrelevant artifact to excusing a real defect, without changing a
single character. Nothing can detect that transition, which is exactly why it
deserves the most attention here.

**The queue: 08:54 UTC**, the merge of #194. From that second until the founder
asked "what happened to f2.38", every signal in the system was consistent with
success, because a run that has not started looks precisely like a run about to
finish. The founder asked twice, once about f2.38 and once for "status now", so
the reporting failed even though no code did.

### Root cause

**The stamp wall.** The stamp had two jobs, and they fight. Job one, answer
"which build am I running", needs one short line. Job two, added by session 3,
carry forward everything since the last delivery row so no notes are lost,
grows without limit. Nothing arbitrated between them, and nothing measured the
result. The root cause is not carelessness in writing long stamps; it is that
one field was assigned two purposes with no bound, and the only place the
outcome was visible was the founder's screen. Note the shape: a rule with no
number in it drifts, and a rule with a number that nothing checks drifts just
as fast.

**The monospace boxes.** A documented known-artifact is a standing invitation to
dismiss a real defect, and the invitation is strongest exactly when the
artifact overlaps what is being reviewed. The note said boxes are a sandbox
artifact, never fix one of those. It was true for emoji. It was false for icons
the moment icons were the subject, and false again for monospace text a few
hours later. The root cause is not the note being wrong, because it was right.
The root cause is that the artifact was documented instead of eliminated, and a
documented exception trains the reviewer to filter out the exact pixels a
defect would hide in. Boxes were caught this time only because someone looked
at the harness output and refused to apply their own rule.

**The 91 minute queue.** Every alarm in this repository fires when something
FAILS. Nothing fires when something never runs. The publisher has an
`if: failure()` step that opens an issue, and it is a good guard, but a job
sitting in a queue has not failed, so nothing was there to speak. The root
cause is that the monitoring watched causes rather than the outcome, and the
outcome is the only thing the founder experiences.

**The bug in the watchdog.** The first version used
`git log -1 -- flutter/lib/main.dart`, which returns the BRANCH commit that
wrote the stamp, not the merge that put it on main. Verified by running both
forms against origin/main: without `--first-parent`, 10:25; with it, 11:48.
Eighty three minutes apart, on the very stamp in front of us. Any batch that
took longer than the 45 minute grace window would have fired a false alarm the
instant it merged, every single time. The root cause is that a new guard is
itself untested code, and it was written from a mental model of git rather than
from a measurement of git.

**CLAUDE.md going stale, third consecutive session.** Two lines had gone false:
that the render uses the light palette only, and that icons draw as boxes. Both
were corrected. The root cause is structural and worth naming precisely:
CLAUDE.md stores facts that live somewhere else. A sentence about what the
renderer draws is a copy of a fact owned by flutter/test/screens_shot.dart, and
a copy has no way to know when the original changes.

### Lessons and guards

**Lesson 1. A field with no limit and two jobs will grow until a human
complains.**
Guard, part one: `flutter/test/update_stamp_test.dart`, which caps the stamp at
120 characters and fails if it names more than one version, that second
assertion aimed at the precise mechanism that grew the wall.
Guard, part two: `maxLines: 4` with ellipsis overflow on the row itself, so
even a stamp that gets past the test cannot take the screen.
Strength: **strong**. Automated, fails loudly, two independent layers where
either alone would have failed here.
Verified with teeth rather than trusted. A deliberate 247 character wall naming
five versions was written in, and both assertions fired, each naming the
mechanism rather than just the number. Reverted immediately.

**Lesson 2. A documented known-artifact is a licence to dismiss a real defect,
and it is most dangerous when the artifact overlaps what is under review.**
This is the most important lesson in this session.
Guard, part one, and the only strong kind: **remove the artifact instead of
documenting it.** The harness now loads MaterialIcons from the running Flutter
SDK, so Salapify's own icons render for real, and it prints a loud warning
rather than quietly drawing boxes again. The monospace family in the
diagnostics report was deleted outright, since the report is lines and not
aligned columns, so monospace bought nothing and cost the reviewability of the
one screen that moves data off the phone.
Guard, part two: the CLAUDE.md note now states what it does NOT excuse, in the
same breath as the artifact.
Strength: **strong** for the part that removed the artifact, because a font
that loads cannot be misread. **Medium** for the residual, which is emoji, all
of it user data now, and genuinely cannot render in this sandbox.
The general rule: any note that tells a reviewer to ignore something must be
written as a fence around a narrow case, never as a class of pixels. "Emoji in
user data draw as boxes" is a fence. "Boxes are fine" is a blindfold.

**Lesson 3. Every alarm we had fired on failure. Nothing fired on absence.**
Guard: `.github/workflows/delivery-watchdog.yml`, on a 30 minute cron, which
reads the stamp main is built at, reads the last delivered stamp out of
docs/delivery-log.md, and if they disagree for more than 45 minutes opens ONE
issue, comments rather than duplicating, and closes it when they agree again.
Strength: **strong in design, and inert until merged.** GitHub only runs
scheduled workflows from the default branch. "The guard is written" and "the
guard is running" is the same one word gap as "merged" and "delivered".
**Is watching the symptom rather than the cause the right call? Yes, and it is
the whole reason this guard is worth having.** Causes multiply: a queued
runner, a cancelled run, a run that died before its own failure notice, a paths
filter that never triggered, a publish step that failed silently. Five causes
have already happened, and a watchdog written against any one of them would
have missed the next. There is exactly one symptom, nothing new reached the
phone, and it is the only thing the founder ever experiences. A symptom
watchdog also cannot rot the way a cause watchdog can, because it encodes no
assumption about how delivery works. The cost is that it cannot say why, which
is handled by the issue body listing the causes in the order they have actually
happened.
One hole, named rather than glossed: it reads main only, so work that is
finished but never merged is invisible to it. That was session 3's failure and
it stays covered by a rule plus the informational branch step.

**Lesson 4. A new guard is untested code, and a guard that cries wolf is worse
than no guard, because it teaches people to ignore alarms.**
The `--first-parent` bug would have made the watchdog fire falsely on every
batch longer than 45 minutes, which is most real batches. It was found by
measuring git, not by reading the watchdog again.
Guard: the reasoning is written into the workflow itself, naming the two real
timestamps so the next person to touch that line knows what removing it costs.
Strength: **medium**. A comment is a rule, not a check.
The transferable practice, now written into CLAUDE.md: **before trusting a new
alarm, prove both halves.** Prove it fires when it should, and prove it stays
SILENT when it should. Only the second half was ever in doubt here, and only
the second half was broken.

**Lesson 5. CLAUDE.md stores facts that live somewhere else, so it goes stale
by construction. Third consecutive session.**
Session 3 made re-reading CLAUDE.md's factual claims a step of every
retrospective, and that step caught both false lines this round, so **the guard
is working**. It is also working at the wrong end: it catches false claims
after they have already been read with authority for hours.
Two claims that went false are now self-maintaining: the harness names its own
output `-light` and `-dark`, so the dark mode claim is visible in a directory
listing, and it prints a warning if the icon font is missing, so the icon claim
announces its own falsity.
Drift found this session, and both fixed in this commit:
- CLAUDE.md said the renderer produces "fifteen shots in about eight seconds".
  It was stale within HOURS of being written, because two shots were added the
  same day. The numbers are now gone rather than corrected: numbers in prose
  rot, and the directory listing is the count.
- The new stamp rule said the detail belongs in the pull request and
  docs/delivery-log.md. That file has no notes column and is not meant to gain
  one; it records what shipped, not what changed. Half of the destination the
  rule named did not exist. Now it names the pull request only.

**Lesson 6. Session 3's Lesson 6 is superseded, and it caused this round's most
visible defect.**
Session 3 wrote that when several stamps merge together, the delivered stamp's
text must cover everything since the last delivery row. That rule is now void.
The stamp answers one question, which build am I running, and the founder said
so directly: high level only. This is recorded because a retrospective log that
silently keeps a superseded guard is a trap of exactly the kind Lesson 2 is
about. It will be read later, with authority, and it is wrong.
Guard: the 120 character test enforces the new rule mechanically, so the old
rule cannot be followed even by someone who reads it.
Strength: **strong**, and note what happened. A rule was replaced by a check,
which is the upgrade every entry in this log keeps asking for.

**Lesson 7. Proving a new test can fail is now a standing rule.**
Three guards were proven this way in one day, each in about three minutes: the
stamp cap rejected a deliberate wall, the icon test caught a renamed icon name
reaching the silent fallback, and the diagnostics privacy test caught a
plausible leak by name. So "no time" is not an objection.
Guard: written into CLAUDE.md, tied to a moment. When adding a test that guards
a lesson, break the code once, watch it fail, and paste the failure line into
the commit message.
Strength: **medium**, and that will not be dressed up. It is a rule and depends
on being followed. Two things make it more than an intention: the cost is
measured, and the artifact is visible, because a commit message either quotes a
real failure line or it does not.

**Lesson 8. Two tests changed this round, and both deserve naming even though
neither was defending a bug.**
This log treats a test that had to change for a fix to pass as the strongest
evidence that the suite was defending the defect, so honesty requires reporting
the changes and also reporting when they are innocent.
Four assertions in flutter/test/mindset_screen_test.dart lost an emoji prefix.
Honest read: not a bug being defended. It was decoration pinned into a data
assertion, so a purely visual change broke four tests that were never about
visuals. The smaller real lesson: an assertion should name the thing it is
about, because one that also captures styling will block a legitimate change
and be edited under pressure, which is the state in which a genuinely wrong
edit gets made.
The second change is the more dangerous kind. `test/goldens/lessons_goldens.json`
was regenerated, 44 lines, and a golden regeneration is precisely where an
unnoticed content change hides. The commit claimed the diff touches the icon
field and nothing else. That was verified independently rather than believed:
the number of changed lines in that file that are not an icon or emoji field is
**zero**.

### Open lessons carried forward

**Open 1, a Shorebird step failure is silent: CLOSED, re-verified.** The
`if: failure()` notice, the release warning, the auto-close, the delivery row
writer, and the self-watching path are all still present in
.github/workflows/flutter-preview.yml. Nothing has been quietly deleted or
routed around.

**Open 2, a pubspec version bump strands the installed app: CLOSED, still
verified.** pubspec is still 0.5.0+8, all four rows this round say `patch`, and
the `mode == 'release'` issue step is still present and still gated correctly.

**Open 3, nothing compares the phone to main: STILL OPEN, and the repository
half is now genuinely closed rather than half closed.** Read the halves
precisely. The repository half, does what main is built at match what the
publisher says it shipped, was answerable before but only by a human choosing
to read the log. With the watchdog merged, something reads it every 30 minutes
and speaks without being asked. The phone half is not closed and cannot be
closed by this watchdog, because a patch published is not a patch installed:
Shorebird delivers on reopen, so a green row proves what left the building,
never what arrived. The founder tapping check-for-update is still the only
proof.
What changed this round is that the phone half became cheap to report. The new
Copy diagnostics button prints the build and patch as TEXT, so a paste beats a
photograph and can be compared mechanically against the last delivery row.

**Open 4, the screenshot harness can rot: CLOSED, re-verified and now proven
useful.** The harness step is still in flutter-check.yml with
`--update-goldens`, and it is no longer theoretical: it caught two real defects
this round, the monospace boxes and three long button labels stacked into a
vertical column taking a third of a dialog.

**Open 5, there is nowhere to read what a build changed: CLOSED as not a
problem.** Capping the stamp was right, and the founder asked for high level
only. The pull request is the place for detail. The false half of the rule, the
sentence pointing at a delivery log with no notes column, is fixed in this
commit.

**New Open 6, the watchdog is written but not yet observed running.** It is
merged in this batch, but no scheduled run has been seen yet. This is the same
shape as session 3's unmerged pull request applied to a guard, which makes it
the more expensive version: an unmerged feature delivers nothing, an unmerged
guard delivers a false sense that a gap is covered. Closes when one scheduled
run has been observed doing its comparison.

**New Open 7, a merge that touches flutter/ without bumping the stamp is
invisible to the watchdog.** In that case main's stamp already equals the
delivered stamp, so the watchdog reports `ok` while a patch is genuinely
pending. Partially covered, and worth being precise about how: the publisher
refuses to record a stamp identical to the last delivered one and exits 1 after
publishing, which trips the failure notice. So the situation gets reported, by
a different guard, with a message about a duplicate stamp rather than about a
pending build.

### What it cost, and what it did not

Cost: one founder screenshot spent on a wall of text that Claude created over
six builds, 91 minutes of a delivered build sitting in a queue while the
founder asked twice for status, and one round where the founder had to be the
detector for a cosmetic defect a render would have shown at a glance.

Did not cost: any user data, any wrong number, any undelivered build, any
stranded APK. All four stamps reached the phone, and the founder confirmed the
ticks are back, which closes the one real data-shaped scare from session 3 with
evidence from the only source that counts.

Nearly cost, and worth recording: the diagnostics report is the one feature in
Salapify designed to move data off the phone. It shipped with a test that fails
by name on an amount, a merchant, an account, a person, a note, or a category,
and that test was proven to fail before it was trusted. That is the correct
order of operations for a privacy promise.

---

### For the founder, in plain English

**What happened.** All four builds reached your phone, and your ticks are back.
That part worked. Three things went wrong around it.

First, the Update stamp row, the line in Menu that tells you which build you
are running. It grew into about forty lines and filled your screen, and you
sent me the screenshot. This one was entirely my doing, over six builds: each
time I wrote a new stamp I pasted the previous build's notes in front of it, so
it got longer every time. I measured it, and it went from 424 characters to
1264. The row also had no limit on how many lines it could draw, so nothing
stopped it. Two things now stop it. A test refuses any stamp longer than 120
characters or that mentions more than one build, and the row itself refuses to
draw more than four lines even if something gets past the test. I proved both
work by deliberately writing a wall and watching them reject it.

Second, and this is the one I would most like you to take away, because it is
the subtlest mistake in this whole log. When I take a picture of a screen to
check it, some characters cannot draw in my sandbox and come out as empty
boxes. I had written that down as a known quirk to ignore. That note was
completely true. Then twice in one day the boxes WERE the problem. Once when
the icons were the exact thing I was reviewing, so a screenshot full of boxes
proved nothing at all. And once when the new diagnostics screen used a
typewriter style font my sandbox does not have, so the one screen in the app
that shows data leaving your phone came out as solid blocks. If I had followed
my own note, I would have shipped a screen I had never actually seen. The fix
was not a better note. It was to make the boxes go away: I load the real icon
font now, and the typewriter font is gone because it bought nothing. A written
excuse to ignore something is dangerous in a specific way. It is most tempting
exactly when the thing you are ignoring is the thing that is broken.

Third, f2.38 took 102 minutes to reach you instead of the usual 9 to 11.
Nothing was broken. GitHub, the company that runs the machines that build
Salapify, had no free machine, so the job waited in line for 91 minutes. Here
is the uncomfortable part: I had alarms for a build that FAILS and no alarm at
all for a build that never STARTS, and those look identical from outside. You
noticed before I did, and you asked twice. Even though no code was at fault,
the reporting was.

**Why it happened.** All three come from the same habit. Something was true,
nobody measured whether it was still true, and the only place the answer showed
up was your screen. The stamp had no number attached to "keep it short". The
box note had no expiry. And the delivery pipeline was watched for the ways it
had already broken rather than for the one thing you actually care about,
whether something new arrived.

**What now makes it impossible.**
- The stamp physically cannot be long again. That is a test, not a promise.
- The icons draw for real in my screenshots, and if the font is ever missing
  the run prints a loud warning instead of quietly drawing boxes.
- A new watchdog wakes up every 30 minutes, compares the build main is carrying
  against the last build the log says reached your phone, and if they disagree
  for 45 minutes it opens an issue. It does not care WHY nothing shipped, which
  is deliberate: five different causes have already happened, and a guard aimed
  at one would miss the next.
- The Copy diagnostics button closes the one gap I cannot close myself. When
  something looks wrong, tap it, read what it says, and paste it to me. It has
  counts and error messages only, never your amounts, names, notes, or the
  people you owe. There is a test that puts fake incriminating data in and
  fails by name if any of it escapes, and I broke the code on purpose to watch
  that test catch it before trusting it.

**One thing I found by testing my own new alarm.** The watchdog was wrong the
first time I wrote it. It looked up the wrong date, so any batch of work that
took more than 45 minutes would have set off a false alarm the moment it
merged. That matters because a smoke alarm that goes off while you cook gets
the battery taken out, and then it is not there during a fire. It is fixed, and
the reason is written into the file so nobody undoes it later.

**What it costs if a guard is ever removed.**
- Remove the stamp test, and the row goes back to eating your screen, one build
  at a time, and you will be the one who has to say so again.
- Remove the icon font from my screenshot harness, and every screenshot I show
  you becomes a picture I cannot actually read, while I tell you I checked it.
- Remove the watchdog, and a build that never starts goes back to looking
  exactly like a build about to finish, and you find out by asking.
- Remove the privacy test on diagnostics, and one harmless looking edit puts
  your amounts and the names of people you owe into text you paste into a chat.
  That is the guard whose removal I would consider most serious, because unlike
  a missed build it cannot be undone.

**Still true and still not fixed:** nothing on my side can see your phone. The
log tells me what left the building, never what arrived, because Salapify
downloads its update when you reopen it. You are still the last check in the
system, and your one tap is still the only real proof. That is acceptable while
you are the only user. It stops being acceptable at launch, because a stranger
will not tell us, they will just stop opening the app.

---

## 2026-07-25, session 3: the eyes we already had

### What we believed / What was true

Three beliefs this round, at three different moments.

Believed: f2.31 was on its way to the phone.
True: it was sitting in an open pull request (#188) for 41 minutes while the
founder tapped "check for update" and read f2.30 back. The founder reported it,
in those words: "theres no update when I clicked..It is still f2.30".

Believed: the lesson redesign that shipped in f2.30 and f2.31 read well,
because 673 tests were green.
True: two lessons were visibly broken on the phone. The Philippine tax lessons
rendered five paragraphs of reference prose as one wall of text, with three
sentences printed twice, and lessons the founder had already finished went back
to unfinished when reopened. Both were found in founder screenshots. Neither
was catchable by any test in the suite.

Believed: Claude had no way to look at a Flutter screen, so the founder was the
only pair of eyes.
True: the capability existed all along. It had been attempted, it appeared to
hang, and it was abandoned without the reason ever being written down.

Believed and TRUE, for once: the delivery pipeline itself. Every merge this
round produced exactly one row in docs/delivery-log.md, and the phone ended on
f2.35, patch 29, which is what the log says. Rows for f2.30 patch 25, f2.31
patch 26, f2.32 patch 27, f2.34 patch 28, f2.35 patch 29. All mode `patch`, all
app version 0.5.0+8. The stamp f2.33 has no row and never reached a phone,
which is correct and explained below.

### Timeline (with evidence)

All times UTC, from `git show -s --format=%ad` on each commit and from the
timestamps written by the publisher into docs/delivery-log.md.

| Time | Event | Evidence |
|------|-------|----------|
| 01:31 | Merge #187 (2ec1b5d) | delivery row f2.30, patch 25, run 30138654637 |
| 01:43 | f2.30 lands on the phone | docs/delivery-log.md |
| 02:08 | Commit 5f599dc pushed to the branch, stamp f2.31 | git log |
| 02:08 to 02:49 | **Divergence.** Built stamp f2.31, delivered stamp f2.30. Founder taps check for update, sees f2.30, reports it | founder message |
| 02:49 | Merge #188 (3d8d9b1) | delivery row f2.31, patch 26, 03:00 |
| 02:50 | "Finished means delivered" written into CLAUDE.md (ba889ac) | git log |
| 03:14 | Commit 197fe3a, stamp f2.32 | git log |
| 03:26 | Merge #189 (9043b3e) | delivery row f2.32, patch 27, 03:37 |
| 03:46 | Commit 282023e, stamp f2.33, the tax lesson fix | git log |
| 05:44 | Commit ac1a36e, stamp rewritten to f2.34, the disappearing ticks fix | git log |
| 05:51 | Merge #190 (b6b64ca), both stamps in one merge | delivery row f2.34, patch 28, 06:02 |
| 06:17 | Commit ea37949 puts the screenshot harness in flutter/tool/ | git log |
| 06:17 to 06:22 | **The branch check goes red.** flutter analyze fails: tool/ is production code to the analyzer, and SharedPreferences.setMockInitialValues is test only | commit message of 4875f41 |
| 06:22 | Commit 4875f41 moves it to flutter/test/screens_shot.dart, check green | git log |
| 06:24 | Commit c68f750, stamp f2.35 | git log |
| 06:30 | Merge #191 (26ff2cf) | delivery row f2.35, patch 29, 06:42 |

Verified on the checkout at the time of writing: `flutter analyze` reports "No
issues found", and `flutter test` reports 677 tests passing. The count being
677 and not higher independently confirms that flutter/test/screens_shot.dart
is not collected by the runner, because it does not end in `_test.dart`.

### Divergence point

02:08 UTC, commit 5f599dc. That is the first push in this round where the built
stamp stopped matching the delivered stamp, and the gap closed only when a
human merged the pull request 41 minutes later. Nothing in the system was
watching that gap. Every guard written in sessions 1 and 2 answers the question
"did the thing we merged reach the phone". None of them answers "did we merge",
and none of them answers "is what reached the phone any good". Those are exactly
the two gaps the founder's eyes filled this round.

### Root cause

One root cause per finding, and one shape they share.

**Finding 1, the unmerged pull request.** "Finished" was defined as "the code is
written, the tests pass, the pull request is open". Under that definition the
work genuinely was finished, and there was nothing left to prompt a merge. The
root cause is a definition, not an oversight. A definition that ends before the
merge produces work that ends before the merge, and it does so reliably, for
anyone, on a busy day.

**Finding 2, the wall of text.** flutter/lib/content/lessons.dart expanded the
`reference` field of the Philippine tax lessons into a single ProseBlock
carrying five long paragraphs. The suite has 90 test files and not one of them
asserts anything about how a block looks on screen, because no test can. The
root cause is that no step in the process ever put a rendered screen in front of
anything with eyes. Related: three coaching lines repeated sentences that the
prose said again a paragraph later, which is the same root cause seen from the
other side, nothing compared the text of one block against another.

**Finding 3, the disappearing ticks.** flutter/lib/money/lesson_progress.dart
holds two records of "done": the legacy `settings.lessonsRead` list and the
newer `settings.lessonProgress` map. `parseLessonProgress` wrote the legacy
entries first and then let any newer entry overwrite them. A lesson finished
under the old build lives ONLY in the legacy list, so reopening it recorded
`viewed`, which shadowed `completed`, and the tick vanished.

The sharp part is why 673 tests were green. Eight lines above the offending
line, the source comment said, in the file itself, that "taking away a completed
tick is a worse wrong than leaving one that was generously granted". And a test
asserted the opposite behaviour on purpose, the one removed in ac1a36e:

    test('a new entry wins over the legacy list for the same lesson', () {
      ...
      expect(p['see-it-first'], LessonState.viewed,
        reason: 'the finer-grained record is the truthful one');

The file argued with itself, the test took the wrong side, and from then on the
suite was actively defending the bug. The root cause is not the overwrite, it is
that a test was treated as evidence for a belief when it was only a recording of
that belief.

**Finding 4, the abandoned capability.** A screenshot harness was attempted
earlier, appeared to hang with no output, and was written off. The real cause of
the hang is that `testWidgets` installs a fake async zone, so awaiting real file
I/O to load the shipped fonts never completes. The root cause of the two rounds
without eyes is not the hang, it is that the write-off was never recorded
anywhere. An undocumented conclusion cannot be challenged, corrected, or
inherited, so it stands until someone happens to ask, which is what the founder
did: "is there a way that you can see the screen of the app? is there something
i need to install or implement?" The answer was that nothing needed installing.

**The shape they share.** Every one of these was a belief held with confidence
and never checked against something outside itself. That is the same shape as
sessions 1 and 2, applied to new subjects.

### The guard that fired, and what it saved

Commit ea37949 at 06:17 put the screenshot harness at
flutter/tool/screens_shot.dart. The Dart analyzer treats tool/ as production
code, so `SharedPreferences.setMockInitialValues`, a test only API, became a
hard `flutter analyze` failure. The "Flutter check" action went red on the
branch, before any merge, and it was fixed five minutes later.

This matters more than it looks. The preview publisher runs the same
`flutter analyze` with zero tolerance, with no `continue-on-error` and no
`if: always()`. If that commit had been merged as it was, the publish would have
died at the analyze step and shipped NOTHING, while pull request #191 sat there
looking clean and merged. That is the exact shape of session 1, thirteen stamps
and 21 hours of it.

It cost five minutes instead, because of the branch check written in session 1
specifically so that a runner failure shows up before the merge rather than
after. A guard firing is not a failure of the process, it is the process
working. This is the first time a lunch and learn has been able to record one of
its own guards paying for itself.

### Lessons and guards

**Lesson 1. Work that is finished but not merged is not finished.**
The founder should never be the one to discover that something is waiting.
Guard: the "Finished means delivered" section now in CLAUDE.md (commit ba889ac),
which redefines finished as merged plus a delivery row, and requires saying out
loud why any open pull request is waiting before starting anything new.
Strength: **medium**. It is a rule, so it depends on being read at the right
moment. It is written at the strongest available point, the top of the workflow
rather than the end.
Applied this session: a step in .github/workflows/flutter-check.yml prints the
branch stamp next to the last DELIVERED stamp from docs/delivery-log.md on every
branch run. Informational, never a gate, because unmerged work in progress is
normal and failing there would cry wolf on every push. It puts the true delivery
state in the same output at the exact moment someone is deciding whether a batch
is done. Call it what it is: a louder rule, not a gate.

**Lesson 2. Tests confirm behaviour. They say nothing about whether a screen is
worth reading.**
Guard: flutter/test/screens_shot.dart renders real screens to PNG in about a
second, plus the "Look at the screen before shipping a screen" section of
CLAUDE.md which ties it to a specific moment, every UI change, before the merge.
Strength: **medium**. It is a tool plus a rule, and a tool only helps when
someone runs it.
The harness was already protected against one kind of rot, because
`flutter analyze` covers test/, so a renamed screen constructor breaks the
branch check. What was NOT protected is that it still RUNS: it is deliberately
excluded from `flutter test`, so it could rot silently and be abandoned a second
time, which is precisely how the first two rounds without eyes happened.
Applied this session: a "The screenshot harness still renders" step in
flutter-check.yml, running it with `--update-goldens`. That flag is load-bearing
rather than a shortcut, because test/shots/ is gitignored, so without it a fresh
checkout compares against a file that does not exist and fails for a reason that
says nothing about the app. With it, the only way the step can fail is if the
harness genuinely stopped working. Closes new Open 4 the same day it opened.

**Lesson 3. A test that asserts a belief is not evidence for the belief.**
The removed test did not merely fail to catch the bug, it defended it, with a
reason string that sounded like a principle. Meanwhile the comment eight lines
above the code said the opposite in plain words.
Guard: four regression tests in flutter/test/lesson_progress_test.dart,
including 'opening a legacy-completed lesson does not demote it' and an end to
end store test that reproduces the founder's phone exactly by importing an old
backup and reopening the lesson.
Strength: **strong**. Automated, fails loudly, and written from the observed
symptom rather than from the model.
Confirmed by reading rather than assumed: the fix repairs already-damaged phones
on its own. flutter/lib/money/lesson_progress.dart takes the higher rank of the
legacy and new entries, and the legacy entry was only ever shadowed, never
deleted, so it reappears the moment the new code runs. The test 'an
already-stored lower state is repaired by the legacy entry' asserts exactly that
recovery. The founder does not need to re-read anything and nothing was lost.
What is NOT guarded: nothing mechanically detects a test that contradicts the
comment above the code it tests. That cannot be automated with anything we have.
The nearest real practice is to treat any test CHANGED by a bug fix as suspect,
because a test that had to change to let a fix through was asserting the bug.
Say that out loud rather than pretend it is covered.

**Lesson 4. A capability written off after one failed attempt stays written off,
because nothing records the write-off.**
Guard: the CLAUDE.md section records not just that the harness exists, but the
three things that make it fail, and specifically that real file I/O must run
inside `tester.runAsync` because testWidgets uses a fake clock. The next hang is
now diagnosed in seconds rather than abandoned.
Strength: **medium**, and this is the strongest form available. "Do not give up
too early" is a habit and would be worthless. Writing down the diagnosis is
structural, because it survives the person who worked it out.

**Lesson 5. The branch check earned its keep. No new guard.**
See the section above. The honest finding is that the existing guard worked as
designed, and the correct action is to change nothing.
Strength of existing guard: **strong**, and now proven twice, once on the fix
that ended session 1 and once here.

**Lesson 6. One stamp per push, one patch per merge. That is fine, and it needs
saying.**
f2.33 was built, checked on a runner, and never delivered, because it was merged
together with f2.34 and Shorebird publishes one patch per successful run on
main. There is no f2.33 row and there should not be one. docs/delivery-log.md
already answers the only question that matters, which stamps exist on a phone,
and it answers it correctly by the absence of a row.
The real risk is that a skipped stamp's notes get lost, so the founder never
learns what changed. That did not happen: flutter/lib/main.dart carries the
f2.33 tax lesson notes forward inside the f2.34 and f2.35 stamp text, by hand.
Guard: when several stamps merge together, the delivered stamp's text must cover
everything since the last delivery row. Strength: **medium**, a rule, and it is
honest to add that this half cannot be automated. No machine can verify that a
paragraph of prose describes a change.
The adjacent failure mode CAN be machine-checked, and now is. Applied this
session: the publisher refuses to record a stamp identical to the last delivered
one. Two different builds under one name would silently break the single
comparison the founder can make that nobody here can fake.

**Lesson 7. Our own rules file contradicted itself about where the harness
lives.**
CLAUDE.md gave the command as `flutter test test/screens_shot.dart` and, 17
lines later, said "The file lives in tool/, not test/, on purpose". The file is
at flutter/test/screens_shot.dart. That sentence was the reasoning from before
the move, left behind after the move made it false. Session 2 found the same
class of thing, a false trigger rule. Twice in a row is a pattern, not an
accident.
Guard: the sentence is fixed, and "re-read CLAUDE.md's factual claims against
the repository" is now an explicit step of every lunch and learn.
Strength: **medium**. Stated plainly: this one cannot be automated. The false
sentence named two directories that both exist, so no path checker would flag
it. A rule that is wrong is worse than no rule, because it is read with
authority.

### Open lessons carried forward

**Open 1 from sessions 1 and 2, a Shorebird step failure is silent: CLOSED.**
Verified by reading .github/workflows/flutter-preview.yml rather than by
trusting the write-up. A step runs `if: failure()` and opens, or comments on, a
single issue titled "Preview build failed, nothing shipped to the phone", and a
later step closes that issue on the next green run so it cannot rot into noise.
The workflow now also watches its own path, which was session 2's unapplied
recommendation, so editing the publisher exercises the publisher. And the
publisher writes docs/delivery-log.md itself, so the ABSENCE of a row is
positive evidence of non-delivery, readable with plain git and no API access.
Three guards where one was requested. Closed.

**Open 2, a pubspec version bump strands the installed app: CLOSED this
session.** flutter/pubspec.yaml is still 0.5.0+8 and all five rows this round
say mode `patch`, so the situation has not yet arisen. Until now the only
warning was a word in a table that a human had to notice and pass on, and if
that human did not, the founder would receive nothing forever while every build
stayed green. Applied this session: a step gated on
`steps.ship.outputs.mode == 'release'` opens a GitHub issue saying a new base
APK exists and must be installed by hand, with the link. Same proven pattern as
the failure notice, different condition. Strength: **strong**.

**Open 3, nothing compares the phone to main: STILL OPEN, now half closed.** The
repository-to-shipped half is automated, docs/delivery-log.md answers it without
guessing. The shipped-to-phone half is still a human looking at a screen, and
this round that human found both bugs that reached the phone and the pull
request that never merged. That is not a criticism of the setup, it is a
measurement of how much load is resting on one pair of eyes. It is acceptable
while the founder is the only user. It stops being acceptable at launch.

**New Open 4, the screenshot harness can rot without anyone noticing: CLOSED the
same session it opened.** See Lesson 2. CI now runs it with `--update-goldens`
on every branch push.

### What it cost, and what it did not

Cost: 41 minutes of a stamp sitting unmerged while the founder checked the
phone, two rounds where the founder was the only way to see a screen, one wall
of text and one set of vanished ticks that reached a real phone, and one round
of founder screenshots spent on a problem that a one second render would have
shown.

Did not cost: any user data, any wrong number, and any undelivered build. Every
merge this round delivered. The disappearing ticks looked like data loss and
were not; the legacy record was hidden, never deleted, and it comes back by
itself.

---

### For the founder, in plain English

**What happened.** Three things, and only one of them was a real bug in the way
you would think of it.

First, a batch of work was ready and I did not press the merge button. You
tapped "check for update", saw the old build, and told me. You were right. The
work was sitting in a pull request, which is a proposal to add code to the main
copy of the app. A proposal is not a delivery. Nothing on my side was watching
for proposals that never got accepted, so it just sat there.

Second, two things that reached your phone looked wrong on screen, and you found
both by sending me screenshots. The Philippine tax lesson dumped five long
paragraphs as one block of text, in the middle of a redesign whose whole point
was to stop doing that. And lessons you had already finished lost their tick
when you opened them again. That second one is fixed, and here is the part that
matters: nothing was deleted. The old record of "you finished this" was still
there the whole time, it was just being hidden by a newer, lower record. The fix
takes whichever record says you did more, so your ticks come back on their own
the moment the app opens. You do not have to re-read anything.

Third, and this is the one I would most like you to remember: you asked whether
there was a way for me to see the app's screen, and whether you needed to
install something. Nothing needed installing. I could always do it. I had tried
once, it seemed to freeze, and I gave up without writing down why. The reason it
froze is technical and boring, the testing tool uses a fake clock, and reading
real files under a fake clock never finishes. Two rounds went by with you as the
only pair of eyes on this app, because I never wrote down a dead end. It now
takes about one second to render a screen and look at it, and there is a rule in
my instructions file saying to do that before shipping any screen change.

**Why it happened.** A "test" is a small piece of code that checks another piece
of code still does what it should. There were 673 of them passing while both of
those bugs were live. That is not surprising once you see what a test really is:
it checks what somebody thought to check. Nobody thought to check whether a
paragraph looked like a wall. Worse, for the vanishing ticks, there was a test
that specifically insisted on the wrong behaviour, written earlier with a
confident sounding explanation. So the tests were not silent about that bug,
they were defending it. That is the most useful thing in this whole session: a
passing test is a record of what someone believed, not proof that the belief is
right.

**What now makes it impossible.**
- Work that is written but not merged now counts as unfinished, in writing, at
  the top of my instructions. If a pull request is open, I either merge it or
  tell you why it is waiting, before I do anything else. And every branch build
  now prints the stamp on your phone next to the stamp being built, so the gap
  is visible instead of assumed.
- I can render any screen to an image and look at it, in about a second, my
  instructions say to do that before every screen change ships, and the build
  now runs the renderer on every push so it cannot quietly stop working and be
  abandoned a second time.
- The vanishing ticks now have four tests, one of which recreates your exact
  phone, old backup and all. That one is genuinely automatic.
- Repeated sentences are now caught by a test, which names the lesson and quotes
  the sentence. That is half of the tax lesson bug. The other half, whether a
  block reads as a wall, needs eyes, which is what the renderer is for.
- If a build ever needs you to install a new APK by hand, it now opens an issue
  saying so. That was the most dangerous state this pipeline had, because it
  looks exactly like success from every angle except your phone.

**One piece of good news you paid for earlier.** Partway through this round I
made a mistake that would have quietly shipped nothing to your phone, the exact
failure that cost thirteen builds a few days ago. The automatic check we added
after that outage caught it before the merge and turned red. It cost five
minutes instead of a day. That check is not decorative. If it is ever removed or
skipped "just this once", the cost is not five minutes, it is you tapping "check
for update" for hours while everything on my side looks green.

**What it costs if a guard is removed.**
- Remove the branch check, and a broken build merges, the publish dies, nothing
  reaches your phone, and every pull request still looks perfect. That is the
  thirteen stamp outage, again.
- Remove the delivery log, and "did it ship" goes back to being a guess. The
  answer to a guess is usually yes, and usually wrong.
- Remove the "finished means delivered" rule, and finished work sits in a
  proposal nobody accepted, and you find out by tapping a button.
- Remove the screenshot step, and you go back to being the only pair of eyes on
  every screen in the app.

**Still true and still not fixed:** nothing automatically compares the build on
your phone against the build we think is out there. You are still the last check
in the system. That is fine while you are the only user. It will not be fine
when there are strangers using this app, because a stranger will not tell us,
they will just stop opening it.

---

## 2026-07-24, session 2: a clean patch, and an audit of session 1's guards

### What we believed / What was true

Believed: the fix would deliver every stranded stamp in one patch.

True: it did. The phone shows **f2.26, patch 22**, "You are on the newest build
already", and the Menu now has the "New phone day" row that shipped in f2.24
and had never been on a phone before. Repo and phone agree: `updateStamp` in
flutter/lib/main.dart line 22 is f2.26. Nothing to investigate. This entry is
therefore step 6 only: an independent re-check of the guards written in
session 1, done by reading the repo rather than trusting the write-up.

### Guard status

**Lesson 1 guard (forced-offline FX test): VERIFIED, still strong.**
flutter/test/fx_log_test.dart lines 111 to 126 wrap the call in
`HttpOverrides.runZoned`, throw `SocketException` from `createHttpClient`, and
assert `askedForAClient` is true. flutter/lib/data/fx_service.dart line 134
uses the bare `HttpClient()` constructor, which routes through
`HttpOverrides.current`, so the override intercepts the real code path and the
test never reaches the network on a runner. The self-check is not decorative:
`askedForAClient` would be false, and the test would fail, if a refactor ever
moved the fetch off `HttpClient()`. It passes here, which proves the zone
really applies.

**Whole-suite sweep for machine dependence (the session 1 bug class): clean.**
All 90 test files, 614 tests, checked for network, clock, time zone, locale,
and filesystem coupling.
- Network: exactly one call site in the suite, the forced one above.
- Image goldens: none. No `matchesGoldenFile` anywhere, so the classic
  renders-differently-on-another-machine failure cannot occur. The `goldens/`
  directory is JSON number vectors, read repo-relative, deterministic.
- Locale: no `DateFormat`, `NumberFormat`, or `intl` formatting in lib/.
- Platform channels and temp files: no `path_provider`, no `MethodChannel`
  mocks in tests.
- Clock: `DateTime.now()` appears in about 15 tests, always to anchor seed data
  to the run day rather than to assert a fixed answer. Weekday-anchored payday
  seeds, `_monthsAgo` built with `DateTime(y, m - n, d)` which rolls over the
  year correctly, and every literal day argument is 15 or lower, so no test can
  ask for February 30.
- One narrow residual: fx_log_test.dart lines 137 to 147 assert local
  wall-clock strings. In a time zone whose daylight-saving gap starts at
  midnight on 2 January 2026, `DateTime(2026, 1, 2, 0, 30)` normalizes forward
  and the assertion fails. Sandbox and runner are both UTC, so this is
  theoretical. Logged, not fixed.

**Lesson 2 guard (.github/workflows/flutter-check.yml): VERIFIED, strong, with
a named blind spot.** The branch filter `claude/**` does match the working
branch `claude/salapify-continuation-3i8jup`. The paths filter is where it
misses. It does not run on: a push touching no file under flutter/ (proven on
this branch, commit fcf6433 touched only .claude/, CLAUDE.md and docs/, so the
current HEAD has no Flutter check); a branch not prefixed `claude/`; or main.
A workflow skipped by a paths filter shows as no check at all, not a red X, so
absence can read as approval. Practical consequence: if a pull request's last
commit is docs-only, its head commit carries no Flutter check.

**Lesson 3 and 4 guards (CLAUDE.md): VERIFIED, present and actionable.**
CLAUDE.md lines 104 to 111 name the "Flutter check" action as the pre-merge
equivalent, forbid treating a green local `flutter test` as a substitute, and
state that after EVERY merge to main we confirm the "Flutter preview APK" run
went green and actually published a patch. That names the action, the moment,
and both things to confirm, which is specific enough to act on. Residual: the
generic waiver at lines 96 to 100 ("blocked by billing or infrastructure ...
that condition is waived") still sits above and is never explicitly scoped away
from the Flutter checks. The post-merge sentence is unconditional, so there is
little for the waiver to attach to, but the words are still generic.

Separately, CLAUDE.md line 14 says "Every push touching flutter/ triggers the
'Flutter preview APK' action". That is not true as written: the publisher's
branch filter is main and claude/salapify-v2 only, so a push touching flutter/
on the current working branch triggers nothing. This sentence describes the
belief that made the session 1 failure invisible, and it is still in the file.
Guard: correct the sentence to say the publisher runs on main, and the branch
check runs on claude/** before the merge. Strength: **medium** (a rule, but an
accurate one beats an inaccurate one).

### New finding: the publisher does not watch its own definition

.github/workflows/flutter-preview.yml has `paths: 'flutter/**'` and does not
list itself. flutter-check.yml does list itself. So a push that edits ONLY the
publisher workflow triggers neither workflow: no check, and no publish. The
publisher can be broken, or believed fixed, with zero signal until the next
push that happens to touch flutter/, at which point it fails and ships nothing
while the pull request looks clean. That is the exact shape of session 1.
Guard: add `.github/workflows/flutter-preview.yml` to that workflow's own
paths filter, one line, so editing the publisher exercises the publisher.
Strength: **strong** once applied. Not applied in this session; it changes
delivery infrastructure and belongs in a normal reviewed change.

### Confirmed: the twelve failed builds consumed no patch numbers

Checked in .github/workflows/flutter-preview.yml. Step order is Analyze (line
52), Test (line 55), setup-shorebird (line 58), Release or patch (line 65).
No `continue-on-error`, no `if: always()`. A failed Test step ends the job, so
Shorebird was never installed and no patch command ever ran. The counter
genuinely sat at 21 and patch 22 is the next one. That reasoning is sound.
Limitation, stated rather than hidden: GitHub API access is not enabled for
this session and there is no `gh` CLI, so run ids 200 to 213 come from session
1's record, not from a fresh query. The step-order argument stands on the
workflow file alone.

### Open lessons carried forward

**Open 1. A Shorebird step failure is still silent.** Still open, and now
slightly wider: the new finding above means the publisher can also fail to
trigger at all. Candidate guard unchanged, an `if: failure()` step that files
an issue saying plainly that nothing shipped, plus the one-line paths fix.

**Open 2. A pubspec version bump strands the installed app.** Still open.
flutter/pubspec.yaml is still `0.5.0+8` and the run took the patch path, which
is why one patch could carry thirteen stamps. Coverage remains a habit, weak.

**Open 3. Nothing compares the phone to main.** Still open. The prediction
matched reality this time, but it was still a human reading a screen that
closed the loop.

---

## 2026-07-24, session 1: thirteen stamps that never left the building

### What we believed / What was true

Believed: the app on the founder's phone was at f2.25. Twelve pull requests
had been built, QA reviewed, merged, and reported to the founder as shipped.

True: the phone was at **f2.12, patch 21**, and had been for about 21 hours.
The app even said "You are on the newest build already", which was correct:
patch 21 genuinely was the newest patch ever published. Thirteen stamps of
work (f2.13 through f2.25) existed only in the repository.

The founder found this, not Claude. That is the most important sentence in
this entry.

### Timeline

| Run | Result | Pull request | Note |
|-----|--------|--------------|------|
| 200 | success | #171 | Last patch that actually reached the phone (f2.12, patch 21) |
| 201 | failure | #172 | Privacy receipt. First silent failure. `527 tests passed, 1 failed` |
| 202 to 212 | failure | #173 to #183 | Eleven more, same single cause every time |
| 212 | failure | #183 | `613 tests passed, 1 failed`. Founder checks phone, still f2.12 |
| 213 | success | #184 | Fix merged. Patch path taken (base APK step skipped) |

Every failure was the same one test, from the first (527 tests) to the last
(613 tests):

    ❌ flutter/test/fx_log_test.dart: a real refresh records its attempt
       an offline failure lands in the log as ok=false (failed)
       Expected: null
         Actual: <Instance of 'FxRates'>

### Divergence point

Pull request #172, the Privacy receipt, added `flutter/test/fx_log_test.dart`.
One test there called the real `FxService.refresh` (flutter/lib/data/fx_service.dart,
`_attempt`, which uses a `dart:io` HttpClient) and asserted it returned null,
on the assumption that the machine running the test had no internet.

That assumption holds in the development sandbox, whose proxy blocks the rates
endpoint, so the suite was green locally on every single run. A GitHub runner
has real internet, so the fetch genuinely succeeded and returned rates. The
test was wrong, the app was correct, and the build died before the publish
step. A build that fails publishes nothing at all.

### Why it survived twelve merges

1. Why did nobody notice? Because every visible signal was green: local
   `flutter test` passed, the pull request looked clean, and the "CI" check on
   the pull request was green.
2. Why was CI green on a broken Flutter build? Because `.github/workflows/ci.yml`
   is the React Native app (`npm ci`, `npm run lint`, `npm test`). It says
   nothing whatsoever about the Flutter app, but its green check appears on
   Flutter pull requests and reads as approval.
3. Why did no Flutter check run before the merge? Because the only job that
   ever ran `flutter test` on a real machine was the publisher, and the
   publisher triggers only on `main` and `claude/salapify-v2`, never on the
   working branch. So the first real test run happened after the merge.
4. Why was the post-merge result never checked? Because CLAUDE.md's merge
   rules waive the publish check when it is "blocked by billing or
   infrastructure rather than by the code", and that waiver had been invoked
   for the whole Flutter track on the grounds that the publisher never runs on
   the working branch. The waiver was written for a mechanism that is broken;
   it got applied to a mechanism that was working fine and reporting real
   failures. That turned the one true delivery signal into noise to be
   ignored.
5. Why did a wrong test get written in the first place? Because the sandbox's
   lack of network was treated as a property of "the test environment" rather
   than as an accident of one machine.

### Root cause

Nothing ran the Flutter tests on an internet-connected machine before a merge,
and the one signal that did (the publisher, after the merge) had been formally
declared ignorable. Delivery was therefore verified by inference rather than
by observation, and the only real detector left in the system was the founder
looking at the phone.

Note what is NOT the root cause: "Claude did not check carefully enough". That
framing produces the fix "check harder", which fails the moment anyone is
busy. The useful framing is that a missing check was missing.

### Lessons and guards

**Lesson 1. A green local test run is not evidence about delivery.**
The sandbox has no outbound network; the runner does. Any test that reaches
the network passes locally for the wrong reason.
Guard: `flutter/test/fx_log_test.dart` now forces the offline condition with
`HttpOverrides` and asserts the forced client was actually the one used, so
it can never quietly go back to depending on the machine.
Strength: **strong** (automated, fails loudly, and self-checking).

**Lesson 2. The Flutter tests must run on a real machine before the merge.**
Guard: `.github/workflows/flutter-check.yml` runs analyze and test on
`claude/**` branches. No Shorebird, no secrets, nothing published.
Strength: **strong** (automated). Already proven: it ran and passed on the fix
commit.

**Lesson 3. A green pull request does not mean delivered. A red publisher
ships nothing while everything upstream still looks clean.**
Guard: CLAUDE.md merge rules now require confirming, after every merge to
main, that the "Flutter preview APK" run went green and actually published.
Strength: **medium** (a rule, so it depends on being read at the right
moment). This is the weakest link in the current setup and should be upgraded
to something automated when a cheap option exists.

**Lesson 4. A waiver written for a broken mechanism must not be applied to a
working one.**
The infrastructure waiver silenced a check that was correctly reporting twelve
real failures.
Guard: the Flutter paragraph in CLAUDE.md now names the specific check for
Flutter work, so the waiver has nothing to attach to.
Strength: **medium** (a rule).

### Open lessons carried forward

These are real gaps that the fixes above do NOT close. Carry them into the
next session and check whether they are still open.

**Open 1. A Shorebird step failure is still silent.** The new branch check
runs analyze and test but deliberately does not run Shorebird (that would need
secrets and would publish). So a failure in the publish step itself, after the
tests pass, still results in nothing reaching the phone while every branch
signal is green. Covered today only by the medium strength rule in Lesson 3.
Candidate guard: a step in the publisher that runs `if: failure()` and files
or updates a GitHub issue saying plainly that nothing shipped. Needs founder
approval, since it writes to the repository.

**Open 2. A pubspec version bump strands the installed app.** Shorebird keeps
one release per pubspec version. Bumping the version makes the workflow build
a NEW base APK, which the founder must install by hand. Until they do, every
build is green and the phone receives nothing, which looks exactly like the
failure in this entry from the founder's side. Covered today only by the
CLAUDE.md instruction to flag version bumps loudly.
Strength of that coverage: **weak** (a habit).

**Open 3. Nothing compares the phone to main.** There is no automated
comparison between the stamp the founder has and the stamp on main. The
founder remains the detector of last resort. That is acceptable only while
they are the only user; it stops being acceptable at launch, when silent
non-delivery would hit real users with no one to notice.

### What it cost

About 21 hours between the first silent failure and discovery. Twelve pull
requests reported as shipped that were not. No user data was at risk and no
app code was wrong, but every "this is live now" statement made during that
window was false, and the founder had to be the one to catch it.
