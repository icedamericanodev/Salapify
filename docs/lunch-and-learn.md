# Lunch and learn

A short, blameless retrospective after every patch check, so the same mistake
never ships twice. Newest session first. Facilitated by the lunch-and-learn
agent (.claude/agents/lunch-and-learn.md).

The one rule: ground truth is the Update stamp ON THE PHONE. Everything else
(a green local test run, a merged pull request, a passing action) is a belief
about delivery, and beliefs are what these sessions audit.

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
