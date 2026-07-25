# Lunch and learn

A short, blameless retrospective after every patch check, so the same mistake
never ships twice. Newest session first. Facilitated by the lunch-and-learn
agent (.claude/agents/lunch-and-learn.md).

The one rule: ground truth is the Update stamp ON THE PHONE. Everything else
(a green local test run, a merged pull request, a passing action) is a belief
about delivery, and beliefs are what these sessions audit.

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
