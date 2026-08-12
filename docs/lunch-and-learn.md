# Lunch and learn

A short, blameless retrospective after every patch check, so the same mistake
never ships twice. Newest session first. Facilitated by the lunch-and-learn
agent (.claude/agents/lunch-and-learn.md).

The one rule: ground truth is the Update stamp ON THE PHONE. Everything else
(a green local test run, a merged pull request, a passing action) is a belief
about delivery, and beliefs are what these sessions audit.

---

## 2026-08-12, session 39: f4.04 delivered clean and confirmed, but the delivery LOG had silently stalled at f4.01 (patch published, row never landed), and the two-launch Shorebird behaviour turned confirmation into a false "still old stamp"

**What we believed / What was true.**

The delivery that prompted this session is clean on the phone, and that half is
over fast. Three Accounts-redesign increments shipped in one pull request
(PR #389), merged to `main` as commit `606e557`, and delivered as a SINGLE
Shorebird patch. Shorebird is the tool that ships Dart changes over the air as
numbered patches on top of one installed base APK. The publisher wrote the row
on `origin/main`:

    | 2026-08-12 14:03 UTC | f4.04 | 95 | patch | 0.9.0+15 | 606e5577 |

The founder confirmed `f4.04`, patch 95, on the phone after a restart. Stamp on
the phone equals stamp in the log equals stamp in the code
(`flutter/lib/main.dart` at `606e557` reads `f4.04 . Accounts card carousel
focused emphasis. Same app.`). On this delivery, belief and reality match, and
no finding is invented to justify the session.

Two real gaps sit behind that clean row, and both are worth the blameless look.

The first belief that failed: "the log is complete, so f4.01 must have shipped
the same way every other stamp does." It did not have a row. The delivery log
on `origin/main` jumps straight from `f4.00 | patch 93` (2026-08-10 01:43 UTC)
to `f4.04 | patch 95` (2026-08-12 14:03 UTC). Stamp `f4.01` and patch number 94
appear NOWHERE in it. Yet `f4.01` was a real merge to main: PR #386, the
Insights v2 chart and motion foundation, merged as commit `cb4133d` on
2026-08-10, and that commit's `flutter/lib/main.dart` reads
`f4.01 . Insights chart and motion foundation. Same app.` (the stamp was bumped
in commit `869f240`, "Bump Flutter delivery stamp for Insights foundation").
That merge touched `flutter/`, so the publisher ran and consumed patch 94
(patch 93 was f4.00, patch 95 was f4.04, so 94 is the one f4.01 used). The
patch went out to Shorebird; the one artifact this whole project treats as
proof of delivery, the delivery-log row, never landed. So for about two days
there was no way to CONFIRM on the phone that the Insights work had shipped,
because the log said the newest delivery was still f4.00.

The second belief that failed belonged to the confirmation conversation, not
the code: "reopen the app once and you will see the new stamp." Shorebird boots
the patch that is ALREADY installed and downloads the new one in the
background, applying it only on the NEXT full restart. So the founder's first
reopen correctly showed the OLD stamp (f4.01), and it took a second full close
and reopen to reveal f4.04. Nothing was broken; the guidance was just missing a
sentence about how Shorebird updates arrive.

**Timeline, with evidence.**

- 2026-08-10 01:43 UTC. `f4.00`, patch 93, delivered and logged
  (`origin/main:docs/delivery-log.md`, last complete row before the gap;
  delivery commit `e07234a`).
- 2026-08-10, PR #386 (Insights v2) merges to main as `cb4133d`, carrying stamp
  `f4.01`. The publisher (`.github/workflows/flutter-preview.yml`) triggers on
  `flutter/**`, so it ran, and Shorebird consumed patch 94. NO `Delivery: f4.01`
  commit exists on main: `git log origin/main e07234a..523ee59 --grep=Delivery`
  returns only the f4.04 delivery commit and the f4.01 stamp bump, never an
  f4.01 delivery row.
- Between then and 2026-08-12, the repo's own machinery knew something was
  wrong: a "Preview build failed, nothing shipped to the phone" issue was OPEN.
  Today's f4.04 run's step "Close the nothing-shipped issue now that delivery
  works again" (`flutter-preview.yml` lines 356 to 366) ran and closed it, which
  only happens when such an issue was open to begin with.
- 2026-08-12 14:03 UTC. `f4.04`, patch 95, delivered AND logged (delivery
  commit `523ee59`, row above). Founder confirmed on the phone after a second
  restart.
- Note on evidence limits, stated rather than hidden: the `gh` CLI is not
  installed in this session, so the exact per-step conclusion of the f4.01 run
  and the precise moment the nothing-shipped issue opened could not be pulled
  from the Actions API. What is certain from the repository alone is the shape:
  patch 94 was consumed by an f4.01 merge that reached main, and no f4.01 row
  was ever committed. Whether the f4.01 run reported "success" with a swallowed
  push failure, or reported failure on one attempt and opened the issue, the
  same hole and the same guard apply, which is why the uncertainty does not
  change the conclusion.

**Root cause.**

Only one place writes a delivery-log row: the "Record what actually shipped"
step, `flutter-preview.yml` lines 201 to 260. It runs AFTER the patch is already
published. It builds the row, commits it locally, then pushes it to main through
a best-effort rebase loop (lines 257 to 260):

    for i in 1 2 3; do
      git pull --rebase origin main && git push origin HEAD:main && break
      sleep 5
    done

If the push loses its race three times (main moved while the build ran, or the
delivery-log rebase conflicts with a parallel delivery commit, or a transient
push rejection), `break` is never reached, and the LAST command actually
executed in the final iteration is `sleep 5`, which exits 0. So the loop exits
0, the step exits 0, and the run stays GREEN with the patch live on Shorebird
and no row on main. This is the exact "published something, recorded nothing"
shape.

The existing "Prove something actually shipped" guard
(`.github/scripts/verify-shipped.sh`, invoked at line 164) does not catch it,
and structurally cannot: it runs BEFORE the record step (line 164 is above line
201) and it only checks that Shorebird published a patch, not that the row
describing that patch ever reached main. It was built to close the opposite
hole, a green run that shipped NOTHING. The hole here is a green run that
shipped something and then failed to record it, and nothing asserts the record
landed.

"Claude should have run the three-command delivery check after the f4.01 merge"
is not the root cause, because the fix would be "check harder", which fails the
next busy day. The root cause is structural: the step that produces the one
proof-of-delivery artifact treats writing that artifact as best-effort and
reports success even when it fails. That has a machine fix.

**Lessons, each with its guard and the guard's strength.**

Lesson one: the publisher can publish a patch and then silently fail to write
its delivery-log row, staying green, so the log can fall behind the phone with
no signal.

- Guard (proposed, STRONGEST, automated and committed, not applied in this
  retro): make the record step FAIL when its push does not land. Track a
  success flag inside the loop and, after it, `exit 1` if all three attempts
  failed, or re-fetch `origin/main` and assert that a row for the current stamp
  now exists before the step is allowed to succeed. A non-zero exit here trips
  the workflow's existing `if: failure()` path ("Say plainly that nothing
  shipped", lines 314 to 328), which opens the nothing-shipped issue, so the
  founder is told immediately and the next green run auto-closes it. This turns
  today's silent two-day gap into a loud notification, reuses machinery already
  proven, and works while nobody is watching because CI runs it unconditionally.
  It should be proven the standard way before it is trusted: break the push so
  the row cannot land, watch the step redden and the issue open, then restore
  only after the run reports. Strength STRONGEST, and stated as PROPOSED because
  code was deliberately not changed in this retrospective.

Lesson two: Shorebird shows the currently-installed patch on the first reopen
and only applies the downloaded one on the NEXT full restart, so a single
reopen can correctly show the OLD stamp and read like a delivery failure when
delivery actually worked.

- Guard (GUIDANCE, MEDIUM, a rule and not a machine, honestly so): the
  founder-facing confirmation guidance must say upfront that the first reopen
  shows the previous patch while the new one downloads in the background, and
  that a SECOND full close and reopen (swipe the app away from recents, not just
  send it to the background) is what reveals the new stamp. This belongs in
  CLAUDE.md's delivery-check section, near "The delivery check, in three
  commands", so it is read at the moment a delivery is being confirmed. Strength
  MEDIUM and no pretence otherwise: it depends on the sentence being read at the
  right moment, and no test can read a sentence to a person. It is placed here
  rather than made a test because the thing that went wrong was a confirmation
  conversation, not code.

**Open lessons carried forward.**

Session 38's strong guard is still in place and still doing its job. Verified
today: `WidgetController.hitTestWarningShouldBeFatal = true` still sits in
`flutter/test/screens_shot.dart` (line 662), so any bare `tester.tap` that
misses an off-screen target in the render harness still throws loudly at the
tap on CI instead of failing illegibly downstream. Session 38's optional
pre-push complement was, as recorded, never added, and that remains a deliberate
smaller follow-up rather than a regression.

Session 39's own lesson-one guard is OPEN until it is implemented and proven: as
of this entry the record step can still exit 0 without landing its row. The
next delivery-touching session should implement it and paste the break-then-fail
line into the commit, per the "prove a new test can fail before trusting it"
rule.

CLAUDE.md factual re-check, done as a step and not a favor. Every delivery-path
claim this session touched still matches the repository: the publisher lives at
`.github/workflows/flutter-preview.yml` and triggers on `flutter/**` plus its
own file (lines 18 to 26); its record step is the only writer of
`docs/delivery-log.md` (lines 201 to 260); the "three commands" delivery check
reads the log's last row as the proof, which is exactly what caught this gap;
and every script and file CLAUDE.md names on the delivery path exists where it
says: `.github/scripts/check-stamp-unique.sh`, `.github/scripts/verify-shipped.sh`,
`.githooks/pre-push`, `flutter/lib/main.dart`, `flutter/test/qa_record_test.dart`,
and `flutter/shorebird.yaml` all present. One claim is worth flagging as
INCOMPLETE rather than false: CLAUDE.md rule 1 and the merge rules describe the
publisher's "nothing-shipped" issue as the backstop for a build that ships
nothing, and it is, but this session shows that backstop does not currently fire
for the "shipped but unrecorded" case, because the record step can swallow its
own push failure. That is the gap lesson-one's guard closes.

---

## 2026-08-07, session 38: f3.64 clean, f3.65 reddened CI on a harness tap that silently missed because a taller screen pushed the button below the fold

**What we believed / What was true.**

Two stamps shipped and both have a publisher-written row on `origin/main` in
`docs/delivery-log.md`:

    | 2026-08-07 05:27 UTC | f3.64 | 57 | patch | 0.9.0+15 | ac09822b |
    | 2026-08-07 07:41 UTC | f3.65 | 58 | patch | 0.9.0+15 | fd57b0ed |

Patches 57 and 58 are consecutive, both mode `patch` on the same base APK
`0.9.0+15`, so no manual install was needed and none was claimed. The founder
confirmed both on the phone. On delivery, belief and reality match for both.

f3.64, the interactive flip card (tap a savings, bank, e-wallet, or credit
card to flip it to a condensed back, the masked number revealed only behind
device auth, one card flipped at a time), delivered clean and first try. Full
suite and CI green, the QA pass found 0 must-fix and 4 minor hardening items
and all 4 were fixed and re-checked (`docs/qa-log.md` line 123). There is
nothing to dig into there, and this session does not invent one. A clean patch
is a real outcome.

f3.65, cash on hand redesigned from a bank-card look into a compact wallet tile
in its own section, is the one with a real gap between believed and true, and
it is a gap in the CI belief, not the phone belief. The belief that failed was
"the local full suite passed 2729 tests and `flutter analyze` is clean,
therefore CI will be green." It was not. The `Analyze and test` job went red.
Nothing false was ever said to the founder: the wording while this was open was
"waiting on CI", never "it shipped". So this cost a round trip through CI and
back, the same kind of waste sessions 32 and 33 recorded for the stamp
collisions, not a phone outage. CI is the backstop and it did exactly its job
(`.github/workflows/flutter-check.yml` lines 5 to 13 are the note that this job
exists precisely so a runner-only failure shows up before the merge).

**Timeline, with evidence.**

- `8301461` through `ff73e39` build the cash redesign. It restructures the
  Accounts screen `build()` so a new "Cash on hand" section sits ABOVE the card
  carousel (`flutter/lib/screens/accounts.dart`). This makes the scrolling
  Accounts list taller than it was.
- The redesign was pushed on a local belief of green: `flutter test` passed
  2729 tests and `flutter analyze` reported zero issues. Both are true, and
  both are the wrong evidence, for the reason in the root cause below.
- CI's `Analyze and test` job reddened on ONE step, `The screenshot harness
  still renders` (`.github/workflows/flutter-check.yml` line 191 to 192, which
  runs `flutter test test/screens_shot.dart --update-goldens`). The failing
  shot is the transfer sheet, dark, at `flutter/test/screens_shot.dart`. The
  shot drags the list, then at the old line taps
  `find.text('Move money between accounts')` with a bare `tester.tap(...)`,
  then asserts `expect(find.text('Move money'), findsOneWidget)`.
- The taller list pushed the "Move money between accounts" button below the
  fold of the harness's fixed viewport. A bare tap on an off-screen target does
  NOT fail at the tap. Flutter prints a hit-test warning (it is in the CI log,
  "a call to tap() derived an Offset that would not hit test") and moves on.
  The sheet never opened, so the assertion failed downstream with `Found 0
  widgets with text "Move money"`. The reported error named the wrong place:
  the cause was the tap, the message was about the title.
- Fixed in `e421062`: `await tester.ensureVisible(find.text('Move money
  between accounts'))` before the tap (`flutter/test/screens_shot.dart` lines
  2326 to 2327), so the button is on screen no matter how tall the list is.
  Verified locally with `flutter test test/screens_shot.dart --update-goldens`:
  93 shots pass, was 92 pass and 1 fail. f3.65 then merged and delivered as
  patch 58.

**Root cause.**

Two structural facts, not a lapse of attention:

1. `flutter/test/screens_shot.dart` has NO `_test` suffix, so a bare local
   `flutter test` never collects it. That is deliberate and documented in
   `CLAUDE.md` (so the harness can never fail a normal CI run on fonts), and CI
   runs it instead as a SEPARATE step. The consequence is that the render
   harness is a whole test category that the local suite does not exercise at
   all. A layout change to a shared screen like Accounts can pass every one of
   the 2729 collected tests locally and still break the harness on the runner.
   So "local suite green plus analyze clean" is simply not evidence about this
   category, and the belief that it was is the divergence point.
2. The harness taps interactive targets with a bare
   `tester.tap(find.text(...))`, which silently misses an off-screen target
   instead of failing at the tap. There are 38 bare `tester.tap` calls in the
   file and only 4 `ensureVisible` guards, so 34 taps carry the same latent
   behavior: any of them turns into a confusing downstream "0 widgets" failure
   the moment a screen it touches grows taller. "Claude did not run the
   harness" is not a root cause, because the fix would be "run it harder" and
   that fails the next busy day. "The local check does not exercise the
   harness, and the harness fails illegibly when a tap misses" is a root cause,
   because both halves have a machine fix.

**Lessons, each with its guard and the guard's strength.**

Lesson one: the render harness is a test category the local check does not run,
so local-green can be CI-red for any shared-screen layout change.

- Guard (recommended, MEDIUM): add the harness command to `.githooks/pre-push`,
  invoked exactly as CI does it, `cd flutter && flutter test
  test/screens_shot.dart --update-goldens`. It runs clean in the sandbox with
  no network, 93 shots, so it moves this class of failure one push earlier.
  Strength is MEDIUM and honestly so: `CLAUDE.md` and the hook's own header
  (`.githooks/pre-push` lines 10 to 17) are emphatic that a pre-push hook is
  not server-side and only protects a checkout that has run `git config
  core.hooksPath .githooks` once. It saves the round trip where the hook is
  enabled; it does not prevent an outage, because CI already prevents the
  outage. That is the whole of its value, stated plainly.

Lesson two: a bare `tester.tap` on an off-screen target misses silently and
reports the failure downstream, turning a one-line cause into a "0 widgets"
mystery in a different file.

- Guard (recommended, STRONGEST durable piece here): set
  `WidgetController.hitTestWarningShouldBeFatal = true` once at the top of
  `main()` in `flutter/test/screens_shot.dart`. Flutter already prints the
  hit-test warning; this makes it THROW at the tap site with the "would not hit
  test" message, for all 38 bare taps at once, instead of a downstream
  `findsOneWidget` failure. It is committed into the file, so it fires wherever
  the harness runs, and CI runs the harness unconditionally, so this protects
  every future push without anyone enabling anything. Prove it the standard
  way: revert the `ensureVisible` at line 2326, run the harness, and confirm it
  now fails at the tap (line 2328) with the hit-test message, not at the
  `expect` (line 2330) with "0 widgets"; then restore only after the run
  reports. Strength: automated and committed, strong where it runs. It does not
  by itself move detection before the push, that is guard one's job, but it
  removes the illegible-failure mode permanently.

Recommended smallest set is BOTH, with clear roles: the harness in the
pre-push hook moves detection one push earlier (medium, hook-gated), and
`hitTestWarningShouldBeFatal` makes any future miss loud and legible for the
whole class (strong, committed, unconditional on CI). A bespoke "assert every
tap target is on screen" test was considered and rejected: it reimplements by
hand what the framework gives for free through the second guard. The part that
stays a human rule is small and named: nothing forces a checkout to enable the
hook, so the pre-push idea depends on the one-time config, and CI stays the real
backstop, which already worked here.

UPDATE, same session (f3.66): the strong guard was implemented and proven, not
deferred. `WidgetController.hitTestWarningShouldBeFatal = true` now sits at the
top of `screens_shot.dart` main(), so CI enforces it on every push for all of
this file's taps at once. Break-then-prove: removing the `ensureVisible` that
fixed the transfer shot, so the tap misses the below-the-fold button again,
turned the run red AT THE TAP with `Finder specifies a widget that would not
receive pointer events ... Offset(195.0, 859.6) is outside the bounds of the
root of the render tree, Size(390.0, 844.0)`, exactly the loud, legible failure
this guard exists to produce in place of the downstream `Found 0 widgets with
text "Move money"`. Restored, and all 93 shots pass with the guard on, which
also proves no other bare tap in the file is currently missing. The pre-push
complement was NOT added and stays the smaller, optional follow-up.

**Open lessons carried forward.**

Session 37's open lesson is now CLOSED, and recording a confirmed close is
worth more than a new finding. That lesson was that 17 render-harness shots and
the only lesson-surface accessibility checks were aimed at
`ExpansionLessonReader`, a reader `learn.dart` no longer opens. Commit
`7810e7b`, "fix(courses): the lesson screenshots and tests now point at the
reader you open", shipped at f3.60 (patch 52, delivered 2026-08-06 17:29 UTC).
Verified today: `flutter/test/screens_shot.dart` now builds `PagedLessonReader`
(two references) and the only surviving `ExpansionLessonReader` token in the
file is a doc comment at line 613; `flutter/lib/screens/learn.dart` line 116
still constructs `PagedLessonReader`. The pictures and the checks now point at
the reader the founder can reach.

CLAUDE.md factual re-check, done as a step and not a favor. Every claim this
session touched still matches the repository: `screens_shot.dart` lives under
`test/` without a `_test` suffix (true, `flutter/test/screens_shot.dart`); CI
runs it separately with `--update-goldens` (true, `flutter-check.yml` line
192); the harness renders sheets in dark only (consistent, the shot is
`shots/transfer-sheet-dark.png` at line 2333); and the pre-push hook is not a
server-side check and only protects a checkout that enabled it (true,
`.githooks/pre-push` lines 10 to 17). Nothing read false today.

---

## 2026-08-06, session 37: f3.58 and f3.59 both shipped clean, two real defects found by two mechanisms that are not the test suite, and 17 of the render harness's lesson pictures point at a reader the app can no longer open

**What we believed / What was true.**

On delivery, belief and reality match, and this is a clean pair. Two stamps
shipped today and both have a publisher-written row:

    | 2026-08-06 12:10 UTC | f3.58 | 50 | patch | 0.9.0+15 | 30089f02 |
    | 2026-08-06 13:10 UTC | f3.59 | 51 | patch | 0.9.0+15 | 18c72dc9 |

Patches 49, 50 and 51 are consecutive with no gap, all mode `patch` on the
same base APK `0.9.0+15`, so no manual install was needed and none was
claimed. `flutter/lib/main.dart` line 34 on `origin/main` reads
`f3.59 · Buttons inside a lesson are wired for good now, and tested end to
end.`, which is the row the founder reads on the phone, and the founder
confirmed it. The delivery half of this session is over in one paragraph,
which is the correct outcome and not a failure to find problems.

The belief worth auditing is a different one, and nobody wrote it down
because nobody knew they held it: that the lesson surface is COVERED. It is
the belief behind two of this project's strongest habits, the render harness
and the reader test files. It is now partly false, and the evidence is not
subtle:

- `flutter/lib/screens/learn.dart` line 116 constructs `PagedLessonReader`.
  It is the only lesson reader any screen in `lib` constructs. `grep -rn
  "ExpansionLessonReader" lib` returns five hits and every one of them is
  inside `lib/widgets/expansion_lesson_reader.dart` itself, plus one comment
  in `learn.dart`. Nothing opens the scrolling reader.
- `flutter/test/screens_shot.dart` builds `ExpansionLessonReader` in 17 named
  shots (`stocks-bonds-verify-before-you-invest`, `crypto-volatility-total-
  loss`, `bir-tax-create-your-tax-money-system`, and 14 more) and
  `PagedLessonReader` in exactly one, `paged-lesson-first-screen`, at line
  593.
- Five test files construct the scrolling reader through their pump helpers
  (`expansion_lesson_reader_widget_test.dart`,
  `lesson_reference_footer_test.dart`, `lesson_finish_flow_test.dart` twice,
  `lessons_stocks_bonds_reader_widget_test.dart`,
  `lessons_deposits_pooled_funds_reader_widget_test.dart`), 35 `testWidgets`
  between those files.
- The only 1.5x overflow test and the only semantics-label test in the whole
  lesson surface live in `expansion_lesson_reader_widget_test.dart` lines 316
  to 342, in a group named `accessibility and layout`, and both pump the
  scrolling reader. `screen_readability_test.dart` sweeps at 1.0x and 1.5x
  but sweeps `lib/screens`, and a reader is a widget, so it never pumps
  either reader.

So the pictures that get looked at, and the accessibility checks that exist,
are aimed at a widget the founder cannot reach.

**Timeline, with evidence.**

- `67f7f60`, f3.57, patch 49, delivered 10:15 UTC. `git log -S
  "PagedLessonReader(" -- flutter/lib/screens/learn.dart` returns this commit
  and only this commit: it is the moment `learn.dart` flipped readers. The
  scrolling reader was kept on purpose, and the comment at `learn.dart` lines
  112 to 115 says why: "it stays until this has been confirmed on a real
  phone, so there is always a working reader to fall back to."
- `4eca67d`, f3.58, patch 50, delivered 12:10 UTC. 12 files, +894 and -165.
  New `flutter/lib/screens/path_screen.dart` (389 lines) holding `PathScreen`
  and `CourseScreen`; `learn.dart` loses 159 lines of inline accordion; new
  pure `courseProgress()` and `focusCourseId()` in
  `flutter/lib/money/lesson_flow.dart`; 11 new module tests (6 for
  `courseProgress`, 5 for `focusCourseId`, counted from the diff, matching
  the QA row exactly); `path_screen_test.dart` with 7 widget tests.
- Between those two, the render caught two defects the module tests could
  not, and this is the load-bearing fact of the whole session. Every course
  card carried a filled accent button, five identical orange slabs down one
  page. `CourseScreen` had no progress line at all, so walking one level in
  lost the figure. Neither is a wrong number. `focusCourseId` can be
  perfectly correct while the screen ignores it, which is what
  `path_screen_test.dart` says in its own header at lines 8 to 11.
- `ffc0846`, f3.59, patch 51, delivered 13:10 UTC. 4 files, +260 and -4. The
  fix for the defect session 36 found by DELETING wiring on shipped code and
  watching 2,623 tests stay green.
- Verified this session, not assumed: `git diff 4eca67d ffc0846 --
  flutter/lib/screens/learn.dart` returns EMPTY. The deliberate break used to
  prove the second guard was restored byte-identically to what f3.58 shipped.
- Verified this session: `flutter test` on current `origin/main` in this
  sandbox reports `04:22 +2647: All tests passed!`. The commit message's
  "full suite green at 2,647" is exact, not rounded.

**Root cause, and it is two layers deep.**

The shallow answer is that three real defects in two batches were found by a
rendered PNG and by a retrospective, and none by 2,647 tests. That is true
and it is not yet a cause.

The structural cause is that this suite is, almost entirely, a set of
POSITIVE assertions over a hand-typed list of named parts. It is extremely
good at "this named thing exists and holds this value". It is blind to three
shapes, and all three shipped this week:

1. A missing element nobody named. No test can fail for a progress line that
   was never written and never specified. `CourseScreen` without its figure
   is a perfectly consistent screen.
2. A property of the WHOLE rather than of a part. Five filled buttons are
   five individually valid buttons. The defect exists only in the
   relationship between them, and nothing in the suite held a sentence about
   the relationship.
3. An absent dependency whose absence DEGRADES rather than errors, which is
   f3.59's defect: `resolveSalapifyRoute ?? (_) => null` and `if (next !=
   null && onOpenLesson != null)`.

Shapes 1 and 3 are both ABSENCE. A suite of presence assertions cannot see
absence, by construction, and no amount of adding presence assertions fixes
it. That is why both mechanisms that DID find these look at the whole
artifact instead of a named part: a picture shows everything on the screen
including what is not there, and a deliberate deletion asks the suite to
prove it would have noticed.

The second layer, and the finding this session actually contributes: the two
mechanisms that can see absence are themselves ANCHORED BY HAND. The render
harness names a widget class in a literal map. The reader test files name a
widget class in a pump helper. Nothing anywhere checks that the class the
tests build is the class the app builds. So when `learn.dart` flipped readers
in `67f7f60`, 17 pictures and 35 widget tests silently changed meaning from
"this is what the founder sees" to "this is what the founder used to see",
and the count of green tests did not move by one. That is the same failure
shape CLAUDE.md already records about the empty-store fixture: the rule "look
at the screen" was followed faithfully against a fixture that could not show
the defect. It has now happened twice, with a different fixture, in the same
file.

The divergence point is `67f7f60`, not either of today's merges. Today's
batches are where it became visible.

**Lessons, each with its guard and the guard's strength.**

LESSON 1. Coverage anchored to a widget class by hand goes stale the moment a
screen switches implementations, and stays green while it does.
GUARD, not yet built, strongest tier when it exists: a test that reads
`test/screens_shot.dart`, extracts every widget class the shot map
constructs, and asserts each one is also constructed somewhere in `lib`
outside its own definition file, with a typed exemption map carrying a stated
reason per entry. The technique is already proven in this repository:
`screen_readability_test.dart` reads the `lib/screens` directory listing at
lines 655 to 680 and compares it against a typed list, with `extraFaces`
declaring the exceptions by name. This is that pattern pointed at the shot
map. It is deterministic, needs no network, cannot flake, and it would have
reddened `67f7f60` the moment the app stopped opening the scrolling reader.
Until it is built this lesson is OPEN.

LESSON 2. Emphasis is a whole-screen property and the suite only checks
parts.
GUARD, partly built, strongest tier for the one screen it covers:
`path_screen_test.dart` line 81, `exactly one course carries the filled
button`, proven to fail with `Found 5 widgets with type "FilledButton" /
Which: is too many`. That is exactly the right shape, a count over the whole
screen rather than an assertion about one widget. The gap is that it guards
one screen. The generalisation is to assert an emphasis budget inside the
existing `screen_readability_test.dart` sweep, which already pumps every
screen in `lib/screens` at two font scales, with a typed exemption map for
the screens that legitimately carry more than one primary action. OPEN as a
generalisation, CLOSED for `PathScreen`.

LESSON 3. A dependency that moves from default-on to default-off, whose
absent value is a degraded app rather than an error, is invisible by
construction.
GUARD, BUILT and verified this session, strongest tier: `PagedLessonReader`
now resolves routes itself (`paged_lesson_reader.dart` lines 245 to 250,
`widget.resolveSalapifyRoute ?? (route) => resolveExpansionActionRoute(...)`),
so the absent case is unrepresentable rather than merely tested, and passing
a resolver still overrides. The half that cannot be defaulted internally,
`onOpenLesson`, is guarded by `test/lesson_reader_wiring_test.dart`, both
tests proven to fail first. This is the strongest possible answer to session
36's lesson 1 and it landed one batch later.

LESSON 4. The one line the founder actually reads claims more than the tests
do, while every long document beside it is honest.
The stamp says "tested end to end". The commit message, the QA row and the
test file's own header all say plainly that the second test is a WIRING
check, not a click-through: it asserts `reader.onOpenLesson` is not null
after opening a lesson through the real hub, and it cannot tell you the Next
button looks right. That honesty is exemplary and it is in three places, none
of which is the phone.
GUARD: a rule, and weak, said out loud as weak. `update_stamp_test.dart`
enforces the 120 character cap and can never judge accuracy. The rule is that
the stamp describes what the founder can SEE, never the state of the test
suite, because "tested end to end" is a claim about us and "the buttons
inside a lesson work" is a claim about the phone.

LESSON 5. A test name can promise a tap the body never makes.
`path_screen_test.dart` line 193, `opening a lesson from a course card never
touches core progress`, never opens anything: `_pumpPath` supplies
`onOpenLesson: (_, _, _) {}`, the body marks an expansion lesson complete,
pumps, and asserts `store.lessonProgress` is empty. The ASSERTION is real and
load-bearing (a screen build that wrote into the core 22's store would be
caught). Only the name overreaches, and the QA row's own wording, "a path
screen never writes into the core 22's progress store", is more accurate than
the test's title.
GUARD: a rule, weak. Name a test after the assertion it makes, not the story
it belongs to. No machine can read intent out of a test name.

LESSON 6. A justification sentence can carry an unchecked "every".
`lesson_reader_wiring_test.dart` justifies its synthetic fixture with "every
real expansion lesson gates its actions step behind a required exercise".
Checked this session rather than accepted: a read-only scan of every
`lib/content/lessons_*.dart` containing a `SalapifyActionsBlock` found a
`requiredForCompletion: true` block earlier in the same `MoneyLesson` literal
in EVERY case, zero exceptions. The claim is true today. Nothing enforces it
tomorrow, and `expansion_content_policy.dart` has no rule about it.
GUARD: none, and deliberately none. A content test could assert it, but it
would guard a sentence in a test header rather than anything the founder
sees, and the fixture is defensible whether or not the sentence stays true.
Recorded as an accepted, stated limit.

**QA row audit, since I was asked to check rows I wrote myself.**

Both rows exist in `docs/qa-log.md`, lines 117 and 118, so
`qa_record_test.dart` had a row to find for each shipping stamp. Every
checkable claim in them was checked:
- "7 widget tests" in `path_screen_test.dart`: 7 `testWidgets`, exact.
- "5 new module tests for `focusCourseId`, 6 for `courseProgress`": 11 added
  in the diff, split 6 then 5 by group, exact.
- "the harness gained a second shot so BOTH new screens are looked at": true,
  `shots/learn-path-courses-dark.png` and `shots/learn-course-lessons-dark
  .png`, and the old `learn-recommendation-grouped-list-dark.png` assertion
  was replaced rather than duplicated.
- "37 pumped vs 36 claimed": matches the repaired code, which declares the
  extra face in `extraFaces` with a reason instead of loosening the
  comparison.
- "`ExpansionLessonReader` resolves routes inline at line 262": correct, the
  `resolveExpansionActionRoute` call is on line 262.
- "restored only after the run reported and `git diff` confirmed `learn.dart`
  came back byte-identical": independently confirmed here, the diff is empty.
- The one row claim that reads stronger than its own test is "the
  load-bearing check that a path screen never writes into the core 22's
  progress store", which is accurate for the body. It is the TEST NAME that
  overstates, not the row. See lesson 5.
No overstatement found in either row beyond that. Both rows describe what
actually shipped.

**CLAUDE.md factual re-check, done as a step.**

Every path CLAUDE.md names was tested for existence, not assumed: both
Flutter workflows, `eas-update.yml`, `.github/scripts/check-stamp-unique.sh`,
`.githooks/pre-push`, `.claude/hooks/guard-destructive-edits.sh`,
`.claude/settings.json`, `flutter/shorebird.yaml`, `screens_shot.dart`,
`palette_contrast_test.dart`, `screen_readability_test.dart`,
`golden/ui_golden.dart`, `golden/baseline/`, `segmented_test.dart`,
`journeys_test.dart`, `qa_record_test.dart`, `update_stamp_test.dart`,
`lib/widgets/salapify_icon.dart`, `lib/money/expansion_content_policy.dart`,
both agent files, `mobile/app/(tabs)/more.js`, `docs/Product_Vision_Spec.md`,
and `/opt/flutter/bin/flutter`. All present, none moved. Triggers were READ:
`flutter-check.yml` still fires on push to `claude/**` plus every pull request
to main, `flutter-preview.yml` still fires on push to `main` filtered on
`flutter/**` plus its own definition. `git config core.hooksPath` returns
`.githooks`, so the pre-push hook is live in this checkout. The "sixteen
palettes" figure was checked rather than trusted: `barakoThemes` in
`lib/theme.dart` line 479 holds 8 themes, each with a light and a dark
palette, so sixteen is right. `updateStamp` is at `main.dart` line 33.
No false factual claim found in CLAUDE.md this session.
THE SAME DRIFT, third session running: the sweep paragraph still says "ten of
the fifty files in lib/screens", and `lib/screens` now holds 56. Session 35
reported 55, session 36 reported 56. Session 36 said that if a third session
reported it the sentence should simply lose its figure. This is that third
session. This session's write scope was `docs/lunch-and-learn.md` only, so the
edit was not made here; it is now a standing recommendation and not a
discovery.
ONE STALE SOURCE COMMENT, outside CLAUDE.md but the same failure shape:
`learn.dart` lines 112 to 115 say the scrolling reader "stays until this has
been confirmed on a real phone, so there is always a working reader to fall
back to". It has now been confirmed on a real phone three times, f3.57, f3.58
and f3.59. The stated condition for removing the fallback is MET, and the
fallback is currently carrying 17 render shots and 5 test files with it,
including the lesson surface's only accessibility tests. The comment is not
false about the past; it is a decision whose trigger fired and that nobody
went back to.

**Open lessons carried forward.**

- From session 34, STILL OPEN, FOURTH session unchanged: the qa-log staleness
  check. Counted again this session rather than assumed:
  `flutter/test/qa_record_test.dart` contains exactly one test, `'the
  shipping stamp has a QA row in docs/qa-log.md'`, with no freshness or
  timestamp assertion. Both rows this batch are complete and were written at
  the time, so the batch again gave it no new evidence. Saying it plainly:
  four sessions of carrying an unbuilt guard is the point at which the
  honest options are to build it or to write down that we have decided not
  to.
- From session 36, lesson 1, CLOSED: the paged reader's wiring default was
  built in f3.59, structurally for routes and by test for `onOpenLesson`,
  both proven to fail first, `learn.dart` restored byte-identical.
- From session 36, lesson 2, PARTLY CLOSED: end-to-end tests exist now, but
  only one of the two is a real walk. Test 1 drives a synthetic lesson to the
  actions step and taps through to `GoalsScreen`. Test 2 stops at a non-null
  assertion. The file says so itself; recorded here so the partial is not
  read as complete.
- From session 36, lesson 3, STILL OPEN and now sharper: the paged reader has
  no 1.5x overflow test and no semantics test, and this session confirmed
  there is nowhere else they could be hiding. `screen_readability_test.dart`
  sweeps `lib/screens` at 1.0x and 1.5x and never pumps a reader; the only
  reader-level accessibility group in the repository is in
  `expansion_lesson_reader_widget_test.dart` and pumps the reader nobody can
  open. A paged version must tap through EVERY step, since
  `paged_lesson_reader.dart` line 207 uses `PageView.builder` with
  `NeverScrollableScrollPhysics`, so one page exists at a time and a copied
  test would measure one screen of nine and pass.
- The `screens_shot` list gap, carried forward with this session's addition:
  it is not only that the list is typed rather than derived, and not only
  that a paged shot covers one page of N. It is now also that 17 of its
  entries photograph a widget the app cannot open. See lesson 1.
- From session 33: the official-source re-search rule was NOT triggered by
  this pair, verified by grep and not assumed. `git show 4eca67d ffc0846`
  contains zero added or removed lines matching `canonicalUrl`,
  `LessonSource`, `reviewStatus` or `verifiedOn`. No lesson content file was
  touched by either commit.
- From session 31: the prove-fail marker-file sharpening, the stale
  `goals.dart` allowlist entry, the 320dp readability question and the
  fixture-through-the-writer shape test are untouched by this batch and
  carried forward unchanged.
- Note on evidence available this session: the GitHub API was not reachable
  from this sandbox, so the two workflow run ids in the delivery rows could
  not be opened. That is not a gap in the ground truth. The rows are written
  BY the run that shipped, which is why the three-command delivery check in
  CLAUDE.md deliberately needs no API.

**For the founder, over lunch.**

Two updates reached your phone today, f3.58 and f3.59, patches 50 and 51.
Both are really there, one after the other with nothing missing in between,
and both were small over the air updates, so you did not have to install
anything by hand. That part went exactly as it should, and there is nothing
to fix about it.

f3.58 gave the lessons a proper home. Before it, tapping "All lessons" on a
big track dumped about thirty rows into the middle of the page you were
already on, and there was no way to open a single course like "Crypto Without
the Hype" on its own. Now a track opens its own screen with its courses as
cards, and a course opens its own screen with its lessons. f3.59 fixed
something the last lunch and learn found: two buttons inside a lesson had
their wiring moved outside the lesson, where it could be deleted by accident
without anything going red. That wiring now lives back inside, where it
cannot be dropped.

Here is the part worth your attention, and it is about how we FIND problems
rather than about anything broken on your phone right now.

Three real problems came up across these two updates. Not one of them was
found by the 2,647 automatic tests. One was found by me looking at a picture
of the screen. One was found by the lunch and learn itself. The third was
found by deliberately breaking the code to see if anything complained.

That is not bad luck. Automatic tests are very good at "this number should be
1,250 pesos" and very bad at three specific things: something that is MISSING
that nobody thought to ask for (a course screen with no progress line),
something that is wrong only when you look at the whole screen at once (five
identical orange buttons, each perfectly fine on its own), and a wire that
has been unplugged in a way that makes a button quietly disappear instead of
making an error. Two of those three are about ABSENCE, and a test that checks
things are present cannot see absence. Adding more tests of the same kind
does not help.

So the pictures matter more than they look like they do. Which brings me to
what I found today, and I want to be straight that it is not currently
hurting you.

A few updates ago I switched the lessons over to the new page-by-page reader.
I kept the old scrolling one around as a safety net, which was sensible. What
I did not notice is that 17 of the screenshots I render before shipping, and
five of the test files about lessons, are all still pointed at the OLD
reader, the one you can no longer open. Including the only two checks in the
whole project that ask whether a lesson still fits on screen when someone
turns their phone text size up. So for the last three updates, when I said "I
looked at the lesson screens", I was looking at a photograph of a room nobody
lives in any more.

Nothing is broken because of it. The new reader was tested in other ways. But
the safety net has now done its job three phone confirmations over, and the
honest move is either to delete it or to point the pictures at the reader you
actually use.

The guard I want to build next is small and it prevents this exact class of
mistake forever: a check that compares the list of screens I photograph
against the list of screens the app can actually open, and turns the build
red when they disagree. Roughly forty lines, no new tools, and the pattern
already exists in this project for a different list. If it is ever deleted,
the cost is precisely what happened here: I keep taking careful pictures, I
keep showing them to you, and neither of us notices they stopped being
pictures of your app.

---

## 2026-08-06, session 36: f3.57 shipped clean, the previous session's guard was built in the same commit that recommended it, and the reader the founder now actually opens can silently lose two buttons with all 2,623 tests green

**What we believed / What was true.** They match. The founder confirmed patch 49
on the phone, and the delivery log's row for it says exactly that:
`| 2026-08-06 10:15 UTC | f3.57 | 49 | patch | 0.9.0+15 | [e8edff53](.../31091520991) |`
(docs/delivery-log.md on origin/main; content commit `67f7f60`, merge commit
`e8edff5` from PR #337, delivery commit `8e7eeef`). The stamp constant at that
merge, `flutter/lib/main.dart` line 33, reads `'f3.57 · Long lessons are now one
idea per screen, tap through instead of scrolling.'`, which is the row the
founder read. Mode is `patch`, base APK still `0.9.0+15`, so no manual install
was needed and none was claimed. Patch numbers ran 47, 48, 49 across f3.55,
f3.56 and f3.57 with nothing missing between them, and no row anywhere in the
file has mode `release`. Phone, delivery log, origin/main and the stamp constant
all agree.

Say the top line plainly: this was a clean delivery, the fourth consecutive one
from the Money Courses experience audit. Nothing below was manufactured to
justify the session, and the one substantial finding was produced by running an
experiment that could have come out the other way.

One piece of live state, recorded because it is true at the time of writing and
not acted on: `origin/main` has since moved to `30089f0` (PR #338, Phase 4,
stamp f3.58) and docs/delivery-log.md has NO row for f3.58 yet. Per the rule
written after session 25, the only safe statement about the phone until that row
exists is the plan, never the outcome. This session touched nothing in that work.

Four things were handed over to be checked rather than accepted. Three came back
confirmed. The fourth turned into the finding.

**Timeline (with evidence).**

- The batch is one commit, `67f7f60` at 09:51 on
  `claude/salapify-money-courses-audit-i3rrxi`, merged as PR #337 at `e8edff5`
  and published as patch 49 at 10:15. Eighteen files, 1,568 insertions, 16
  deletions. Three new production files (`flutter/lib/money/lesson_steps.dart`
  129 lines, `flutter/lib/widgets/paged_lesson_reader.dart` 443 lines,
  `flutter/lib/widgets/lesson_finish_card.dart` 140 lines), three new test files
  (`lesson_steps_test.dart` 13 tests, `paged_lesson_reader_test.dart` 5 tests,
  plus 42 lines added to `lesson_openings_test.dart`), one shot added to
  `test/screens_shot.dart`, one qa-log row, and the stamp.

- `git diff --diff-filter=D` across the batch returns nothing. Six existing test
  files were MODIFIED, which is the shape this repository checks by name, so
  every one was read. All six changes are the same edit: `expect(find.byType(
  ExpansionLessonReader), ...)` became `expect(find.byType(PagedLessonReader),
  ...)`, in tests that reach the reader THROUGH `LearnScreen`. No assertion was
  inverted, weakened or deleted, and the two `findsNothing` cases in
  `learn_screen_expansion_deeplink_test.dart` lines 50 and 65 stayed
  `findsNothing`. That is a widget type rename following a real behaviour
  change, not a suite being edited to accept a defect. The f3.57 qa-log row
  names these two deep-link failures as caught by the full suite before merge,
  and describes them correctly as "the tests noticing a genuine behaviour
  change".

- CHECK 1, THE f3.56 RETROSPECTIVE'S GUARD. Built, not deferred, and built in
  the SAME commit that carried the retrospective recommending it.
  `flutter/test/lesson_openings_test.dart` now opens with a group `'the sentence
  splitter itself'` holding five cases: a question mark, an exclamation mark, a
  full stop, a single sentence left whole, and an abbreviation. The first two
  pin the exact defect session 35 dissected. It is an ordinary `*_test.dart`
  file, so it runs on the Flutter check with everything else. Session 35 asked
  for "about ten lines"; 42 arrived, including the comment explaining why.
  Recommendation to shipped guard in one commit is the fastest this file has
  ever recorded, and it is worth saying so.
  ONE HONEST WRINKLE, small and deliberate. The fifth case is
  `expect(_sentences('Bring cash, e.g. coins.').length, 2)`, which asserts the
  WRONG behaviour on purpose, pinning a known limitation. The comment above it
  says so in full. That is the acceptable form of a shape this repository
  otherwise treats as an alarm: a test asserting a defect. It is acceptable here
  only because the reason is written beside it and the assertion is on length
  rather than on content. The cost to know about: the day someone fixes the
  splitter to handle `e.g.`, this test goes red and will read like a regression
  to whoever is holding the pager. That is the intended behaviour and it is
  cheap, but it should be recognised on sight rather than rediscovered.

- CHECK 2, WAS BREAK-THEN-PROVE ACTUALLY FOLLOWED, or claimed. Verified by
  reproduction rather than by reading the commit message. A detached worktree at
  `67f7f60` was created in the session scratchpad (the session 35 recipe:
  `git worktree add --detach <dir> <commit>`), the repository's own working tree
  never touched. Break 1 was reapplied by hand:
  `flutter/lib/money/lesson_steps.dart` line 77, `b.paragraphs.sublist(i, end)`
  changed to `b.paragraphs.sublist(i, i + 1)`. The run:

      00:00 +3 -1: prose splitting every paragraph survives the split, in order [E]
        Expected: ['p0', 'p1', 'p2', 'p3', 'p4', 'p5', 'p6']
          Actual: ['p0', 'p2', 'p4', 'p6']
         Which: at location [1] is 'p2' instead of 'p1'
        pagination must not lose a paragraph

  That is the commit message's quoted line, character for character in its
  abbreviated form, reproduced by someone who was not there. The discipline was
  followed, not claimed.
  A SECOND, UNASKED-FOR NUMBER FROM THE SAME RUN, worth recording. With half of
  every lesson's prose being silently dropped, 12 of the 13 tests in
  `lesson_steps_test.dart` still PASSED, including `'no prose step carries more
  than the cap'`, `'the longest crypto lesson becomes many screens, not one'`
  and `'every Grow lesson paginates and ends correctly'`. The last of those is
  the only test in the file that runs against real shipped content, and it
  asserts `steps.length > 1` and `steps.last is FinishStep` and nothing else, so
  losing half of all 29 lessons satisfies it comfortably. The guard held, on the
  strength of one synthetic seven paragraph fixture. That is a real guard doing
  real work and it is not being criticised; it is being measured, because the
  margin turned out to be one test wide.

- CHECK 3, THE DELIVERY LOG AND PATCH NUMBER. Match, quoted above. Nothing to add.

- CHECK 4, THE READABILITY SWEEP'S TYPED LIST. The answer is more specific than
  wider or narrower, and it is the thread that led to the finding.
  `flutter/test/screen_readability_test.dart` was NOT touched by this batch, so
  the list itself did not move. It could not have: the map at line 384 is keyed
  by SCREEN, its members are all classes from `lib/screens`, and its coverage
  self-check counts `lib/screens` (56 `.dart` files today). Both readers live in
  `lib/widgets`, so neither the old nor the new one has ever been inside that
  promise, before or after Phase 3. Nothing regressed there.
  What DID move is the effective coverage of the surface the founder actually
  reads. `expansion_lesson_reader_widget_test.dart` carries its own layout and
  accessibility pair, `'narrow phone, 1.5x system font: nothing runs off the
  side'` (line 316) and `'every interaction control exposes a semantic label'`
  (line 332). `paged_lesson_reader_test.dart` has neither, and no equivalent
  exists anywhere. So on the day the founder's reader changed, the measured
  overflow and semantics coverage of what they read went to zero, while every
  list, map and count in the repository stayed exactly as it was.
  There is a structural reason this will not fix itself, and it is new
  information rather than a restatement. The old reader is a scroll: every block
  of the lesson is in the widget tree after one pump, which is precisely why a
  single `_runsOffTheSide` sweep could measure a whole lesson. The new reader is
  a `PageView`: one page is built at a time. Any tree-walking check now sees one
  screen out of nine and reports clean. A future overflow test for the paged
  reader must TAP CONTINUE THROUGH EVERY STEP, and a copy of the old test's
  shape would pass while measuring almost nothing.

- CHECK 5, THE FINDING, and the only part of this session that was not on the
  handed-over list. It began as a question about `LessonFinishCard` and ended as
  two experiments.
  The two readers resolve a lesson's action button differently, and the
  difference is invisible in a diff. `ExpansionLessonReader` calls
  `resolveExpansionActionRoute(context, widget.store, route)` INSIDE itself
  (`lib/widgets/expansion_lesson_reader.dart` line 262), so every widget test
  that pumps it gets the real resolver for free.  `PagedLessonReader` takes it
  as an OPTIONAL constructor parameter instead (`lib/widgets/paged_lesson_reader
  .dart` lines 46 and 54), supplied by exactly one caller, `lib/screens/learn
  .dart` lines 120 and 121. `onOpenLesson`, which draws the "Next lesson" button
  on the finish card, is the same shape: optional, and supplied by the same
  single caller at lines 122 to 132.
  Absence of either is SILENT, not loud. `lib/widgets/interaction_block_views
  .dart` line 2165 reads `resolveRoute: resolveSalapifyRoute ?? (_) => null`,
  and the design intent (stated in `learn.dart`'s own comment) is that a null
  route means "hide the button rather than show a dead one". `lib/widgets/
  lesson_finish_card.dart` line 89 reads `if (next != null && onOpenLesson !=
  null)`. So a missing wiring does not crash, does not warn, and does not
  render. It just quietly removes a button.
  No test supplies either one. `paged_lesson_reader_test.dart`'s `_pump` helper
  (line 43) constructs `PagedLessonReader(pathId: _pathId, lesson: lesson,
  store: store)` and stops there. `git grep resolveSalapifyRoute origin/main --
  flutter/test` returns NOTHING, in the whole test tree, today.
  EXPERIMENT 1, in the scratchpad worktree at `67f7f60`: delete `learn.dart`
  lines 120 and 121, the route wiring, and run the entire suite.

      04:32 +2623: All tests passed!

  EXPERIMENT 2, same worktree, wiring restored, then delete the `onOpenLesson`
  block at lines 122 to 132 instead, and run all nine reader and Learn screen
  test files:

      00:15 +48: All tests passed!

  Both deletions are silent regressions on the phone. The first removes the call
  to action from every expansion lesson, which is the button that also marks the
  lesson applied. The second dead-ends the finish card, which is exactly the
  "Done. One useful thing." dead end that f3.54 shipped a whole finish card to
  fix. Both were re-checked against current `origin/main` (which already
  includes f3.58): still optional, still supplied only by `learn.dart`, still
  named by zero test files.

**Root cause.** Structural, and specifically not attention, because the author
was demonstrably paying attention to this exact risk. The commit message says,
in its own words, "the action-route resolver is promoted so both readers resolve
the identical closed set. Two readers with two route tables is how one of them
quietly grows a dead button." That reasoning is correct and the sharing was done
correctly. The refactor solved the DUPLICATION problem and created a WIRING
problem in the same motion, and the second one is invisible from inside the first.

The mechanism, stated so it can be recognised again: a dependency moved from
INSIDE a widget, where it is default-on and every widget test exercises it for
free, to the CALL SITE, where it is default-off and no widget test can see it.
Adding that seam is usually good design, and here it exists for a real reason,
to keep `lib/widgets` from importing `lib/screens`. The cost nobody priced is
that the seam's default value is a working, silent, degraded app. A parameter
whose absence produces a crash is self-guarding. A parameter whose absence
produces a slightly emptier screen is guarded by nothing, and a suite of 2,623
tests will tell you it is fine.

This is the same family as the last three sessions and it is worth naming as
such, because the family now has four members: f3.54's fallback guard that
passed with its guard deleted, f3.55's reading-time model that could not see
exercise text, f3.56's sentence splitter, and now f3.57's untested wiring. In
every case the CODE was fine and the thing that could not see the defect was the
apparatus around it. The difference this time is direction. The first three were
instruments reporting wrong numbers, which wastes work. This one is an
instrument pointed at the wrong object, at the old reader instead of the new
one, which reaches the phone.

**Lessons, each with its guard and the guard's strength.**

1. When a widget takes a behaviour as an optional constructor parameter and the
   absent value is a silent hide, the call site is unguarded by construction.
   GUARD, strongest available and it removes the class rather than the instance:
   give `PagedLessonReader` the same internal default `ExpansionLessonReader`
   already has, resolving `resolveExpansionActionRoute` itself when no override
   is supplied. The function is already public and already imported by
   `learn.dart`, so this is a small edit, and after it a deleted call-site
   wiring cannot change behaviour at all, because there is nothing left to
   delete. The same shape suits `onOpenLesson` less well, since only the screen
   knows how to push the next lesson, so for that one the guard is the second
   one below.
   STRENGTH: strongest tier, and stronger than a test, because it makes the
   defect unrepresentable rather than detectable.
   COST IF REMOVED: the exact two silent button losses proven above, invisible
   to the whole suite.

2. The founder's real path through the new reader is tested by nothing end to
   end.
   GUARD: two widget tests in `paged_lesson_reader_test.dart` that pump
   `LearnScreen` rather than the reader alone, open a lesson carrying a
   `SalapifyActionsBlock`, tap Continue through to it, assert the action button
   is present and that pressing it navigates; and a second that reaches the
   finish step and asserts the "Next" button by name. These are the paged
   equivalents of `expansion_lesson_reader_widget_test.dart`'s `'Continue opens
   the real screen and marks the lesson applied'` (line 252) and
   `lesson_finish_flow_test.dart`'s `'the next button actually moves to the next
   lesson'` (line 62), both of which exist only for the reader the founder no
   longer sees.
   Prove them by re-running the two experiments recorded above; both are exact,
   both are two-line deletions, and both currently produce green.
   STRENGTH: strongest tier, an automated check that fails loudly.
   COST: perhaps forty lines and a few seconds of runtime.

3. The paged reader has no overflow or semantics measurement at all, and copying
   the old one's shape would produce a test that passes while measuring one
   screen out of nine.
   GUARD: an overflow and semantics test for the paged reader that WALKS the
   steps, tapping Continue and running `_runsOffTheSide` and the semantics
   assertions on each page, at 1.5x system font on a narrow phone, matching
   `expansion_lesson_reader_widget_test.dart` lines 316 to 341. The step count
   is available from `stepsForLesson`, so the loop bound is derived rather than
   typed, which is the `palette_contrast_test.dart` shape.
   STRENGTH: strongest tier.
   COST IF REMOVED: a clipped sentence or an unlabeled control on the screen the
   founder now spends the most time on, with nothing to catch it. Note this is
   the ONE place where "look at the screen" also cannot help much: the render
   harness's new `paged-lesson-first-screen` shot renders page one, and pages
   two through nine are not merely unshot, they are not built.

4. `lesson_steps_test.dart` proves paragraph survival on a synthetic fixture and
   proves nothing about content survival on the 29 real lessons.
   GUARD: extend `'every Grow lesson paginates and ends correctly'` to assert
   that the concatenation of all paginated prose equals the concatenation of the
   lesson's own prose, for every real lesson. Pure, deterministic, no widget, and
   it turns the one-test margin measured above into two independent ones.
   STRENGTH: strongest tier, and genuinely cheap, roughly five lines inside a
   loop that already exists.
   HONEST LIMIT: this is a nice-to-have, not a hole. The existing guard caught
   the real break on the first try. This is about the margin, not the outcome.

5. A retrospective that states a fact about a DELIVERED tree must read that tree
   by ref, not read the working tree it happens to be sitting in.
   Session 35 listed `paged-lesson-first-screen` among six `screens_shot.dart`
   keys that rendered an f3.56 opening. That key did not exist at f3.56:
   `git show ce95c8e:flutter/test/screens_shot.dart | grep -c
   paged-lesson-first-screen` returns 0, and the key was ADDED by `67f7f60`, the
   f3.57 commit that the session 35 entry was itself written inside (that commit
   carries `docs/lunch-and-learn.md +417`). The correct figure is five, not six.
   The conclusion it supported is unchanged, "roughly a fifth", and the gap was
   correctly carried forward either way, so nothing downstream is wrong. The
   CAUSE is what matters and it will recur: a retrospective written inside a
   live working tree describes the tree it can see, not the tree that shipped.
   GUARD: a wording and method rule for this file, applied throughout this
   session. Every factual claim about a delivered batch is read with
   `git show <ref>:<path>` or from a detached worktree at that ref, never from
   the working tree, which in this repository routinely contains the NEXT
   batch's work. Today's session is the proof of the risk: the working tree at
   `HEAD` was already three commits and one stamp past f3.57.
   STRENGTH: medium. It is a rule, and it depends on being read at the right
   moment. It is not a machine, and it cannot be, because nothing in the
   repository can tell which tree a sentence in a document was derived from.
   Recorded as weak on purpose.

**What went well, credited honestly.** The `LessonFinishCard` extraction is
better than the commit message sells it. Because the finish moment now exists
once, the 21 tests still pointed at the old reader
(`expansion_lesson_reader_widget_test.dart` 9, `lesson_reference_footer_test
.dart` 7, `lesson_finish_flow_test.dart` 5) genuinely do guard shared code the
new reader runs. Only the WIRING escaped, not the card. Had the finish card been
copied instead of extracted, this session would be reporting a much larger hole.
The pure module split is the other good part: 13 of the 23 new tests are pure
Dart with no widget pumping, which is why break-then-prove could be reproduced
today in 13 seconds by a stranger.

**CLAUDE.md factual re-check (done as a step, not a favour).** Every path
CLAUDE.md names was checked for existence: both workflow files,
`.github/scripts/check-stamp-unique.sh`, `.githooks/pre-push`,
`.claude/hooks/guard-destructive-edits.sh`, `.claude/settings.json`,
`flutter/shorebird.yaml`, `flutter/test/screens_shot.dart`,
`palette_contrast_test.dart`, `screen_readability_test.dart`,
`golden/ui_golden.dart`, `golden/baseline/`, `segmented_test.dart`,
`journeys_test.dart`, `qa_record_test.dart`, `update_stamp_test.dart`,
`lib/widgets/salapify_icon.dart`, `lib/money/expansion_content_policy.dart`,
`.claude/agents/journey-tester.md`, `.claude/agents/lunch-and-learn.md`,
`mobile/app/(tabs)/more.js` and `docs/Product_Vision_Spec.md`. All present, none
moved. Triggers were READ, not assumed: `flutter-check.yml` line 17 onward still
triggers on `push` to `claude/**` plus every pull request to main, and
`flutter-preview.yml` still triggers on `push` to `main` filtered on `flutter/**`
(plus its own definition, deliberately), exactly as Flutter rule 1 describes.
`updateStamp` is still at `flutter/lib/main.dart` line 33.
`git config core.hooksPath` returns `.githooks`, so the pre-push hook is live in
this checkout and not merely present. No false factual claim was found in
CLAUDE.md this session.
ONE DRIFT, reported because this check is worthless if only failures are
reported: the sweep paragraph still says the screen list covered "ten of the
fifty files in lib/screens", and `lib/screens` now holds 56. Session 35 reported
55. The sentence is past tense and describes a past state, so it is not false and
is not being edited on that basis, but the number has now rotted by six and has
been reported twice. If a third session reports it, the sentence should simply
lose its figure, which is what the paragraph two down already advises.

**Open lessons carried forward.**
- From session 34, STILL OPEN and still not built: the qa-log staleness check.
  `flutter/test/qa_record_test.dart` contains exactly one test (counted this
  session, not assumed), `'the shipping stamp has a QA row in docs/qa-log.md'`,
  with no timestamp or freshness assertion. This batch gave it no new evidence:
  f3.57's row exists, is complete, and was written once. Third session carrying
  it unchanged.
- NEW and open until built: lessons 1, 2 and 3 above, the paged reader's wiring
  default, its end-to-end tests, and its overflow and semantics sweep. All three
  are specified precisely enough to build in one sitting, and lesson 2 comes with
  two reproducible experiments that currently produce green and must produce red.
- The `screens_shot` list gap, now with a wrinkle. The list WIDENED by one this
  batch, `paged-lesson-first-screen`, deliberately placed beside the scrolling
  shot so the two shapes can be compared. But a paged reader is not one picture,
  it is nine, and the harness renders the first. The gap is no longer only "the
  list is typed rather than derived"; it is now also "a shot of a paged surface
  covers one page of N". Carried forward with that addition.
- From session 33: the official-source re-search rule was NOT triggered by this
  batch, verified by grep rather than assumed: zero `canonicalUrl`,
  `LessonSource`, `reviewStatus` and `verifiedOn` lines were added or removed in
  `67f7f60` under `flutter/lib/content/`. `.githooks/pre-push` confirmed enabled.
- From session 31: the prove-fail marker-file sharpening, the stale `goals.dart`
  allowlist entry, the 320dp readability question and the
  fixture-through-the-writer shape test are untouched by this batch and carried
  forward unchanged.
- From session 35: the written-first re-proof recipe was USED this session, on a
  break-then-restore guard rather than a written-first one, and it worked
  identically. Worth recording, since it means the recipe is more general than
  the lesson that produced it: any deliberate break can be reproduced later by
  anyone, in a detached worktree, as long as the break is described precisely
  enough in the commit message. f3.57's message was.

**For the founder, over lunch.** f3.57, patch 49, is on your phone and it is
correct. Long lessons used to be one endless scroll; each one is now a short
run of screens with a Continue button, and the exercise you were meant to do can
no longer be scrolled past because it now sits alone on its own screen. Nothing
in the lessons was rewritten for this. It is the same words, cut into pages.

Two things I checked rather than assumed, and one thing I found.

The first check is about the last lunch and learn. Last time I recommended one
small automatic test, for the little piece of code that chops text into
sentences. It was not put on a list for later. It was built into this very same
update, five test cases, and it is running now. I mention it because a lesson
without a guard is just a regret, and this one turned into a guard within hours.

The second check is about honesty in the update notes. The notes claimed I had
deliberately broken the code three times to prove the new safety tests actually
work. I did not take my own word for that. I made a private copy of the app
exactly as it shipped, put one of those breaks back in by hand, and ran the
tests. The failure came out word for word as claimed. So that discipline was
really followed, and you can verify things like this without asking me, because
the evidence is permanent.

Now the thing I found, and I want to be straight that it is real but that
nothing is broken on your phone right now.

Lessons have two buttons that matter: a "do this now" button that jumps you into
the actual Salapify screen the lesson is teaching, and a "Next lesson" button on
the finish screen. In the old reader, those buttons were wired up inside the
reader itself, so every test of the reader tested them automatically. In the new
reader I moved that wiring outside, to the screen that opens it. That is normal
and often good practice. The problem is what happens if that wiring is ever
dropped: the buttons do not break, do not error, and do not turn red. They just
stop appearing. Silently.

So I ran the experiment. I deleted the wiring in a private copy and ran all 2,623
tests. Every single one passed. Then I deleted the other one and ran the reader
tests. All 48 passed. That means if a future change removes those two lines, your
lessons quietly lose their action button and their Next button, and every check
this project has will say everything is fine.

The fix I am recommending is not another test. It is to make the mistake
impossible: let the new reader wire itself up by default, the way the old one
does, so there is nothing left to delete. Then two tests on top, walking through
a lesson the way you would, tapping through to the buttons and checking they work
and that they go where they say. If those are ever removed, the cost is exactly
what I demonstrated: two buttons can vanish from your lessons and nothing will
tell either of us.

There is a smaller relative of this worth one sentence. There was a test checking
that nothing runs off the side of the screen at large text sizes in the old
reader. There is no such test for the new one, and the usual trick of copying it
across will not work, because a scroll has the whole lesson loaded at once while
a paged reader only has the page you are on. Any check has to tap through the
pages. Same for screenshots: the picture I rendered of the new reader shows page
one of nine. I would rather tell you that than let a screenshot imply I looked at
the whole thing.

One correction to the last lunch and learn, since it is my own record. I wrote
that six lesson screenshots showed the rewritten openings. It was five. The sixth
did not exist yet on the day I was describing; I was looking at my own
half-finished work while writing about what had already shipped. It changes
nothing about the conclusion, but it is exactly the kind of small drift that
makes a document harder to trust later, so it is corrected here and I have
written down the method that prevents it: when writing about what shipped, read
what shipped, not what is on my desk.

---

## 2026-08-06, session 35: f3.56 shipped clean, a measuring instrument wrong for the second time in three batches, and a "no fact was deleted" claim whose stated evidence was nearly vacuous while the claim itself held

**What we believed / What was true.** The founder confirmed the patch on the
phone. The delivery log's last row agrees:
`| 2026-08-06 08:30 UTC | f3.56 | 48 | patch | 0.9.0+15 | [ce95c8e5](.../31084213368) |`
(docs/delivery-log.md, last row on origin/main; content commit `10ca9e6`, merge
commit `ce95c8e` from PR #336, delivery commit `50dd738`).
`flutter/lib/main.dart` line 33 on origin/main carries `'f3.56 · Grow Your Money
lessons now open with your situation, not a definition.'`, which is the row the
founder read. Mode is `patch` and the base APK is still `0.9.0+15`, so no manual
install was needed and none was claimed. Patch numbers ran 46, 47, 48 across
f3.54, f3.55 and f3.56 with nothing between. Parsing the whole log's patch
column (108 rows, f2.30 patch 25 through f3.56 patch 48) shows six
discontinuities, five of which are pubspec version transitions where the patch
counter legitimately restarts, and the sixth is the f3.10 patch 5 hole already
recorded in session 25. No new gap, and no row in the entire file has mode
`release`, so nothing has ever silently stranded the installed base APK. Phone,
delivery log, origin/main and the stamp constant all agree.

Say the top line plainly: this was a clean delivery, the third in a row from the
Money Courses experience audit, and nothing in the evidence contradicts that.
Nothing below was manufactured to justify the session.

What makes this session worth the time is that four specific claims were handed
over to be checked rather than accepted. Three survived checking, one turned out
to be stronger than the person making it believed, and one is overstated in a way
worth correcting carefully. All four were re-derived from the repository this
session, twice by reconstructing the pre-f3.56 tree and running code against it.

**Timeline (with evidence).**

- The batch is one commit, `10ca9e6` at 08:07 on
  `claude/salapify-money-courses-audit-i3rrxi`, merged as PR #336 at `ce95c8e`
  and published as patch 48 at 08:30. Eight files: the five Grow Your Money
  content files, `flutter/lib/main.dart` (the stamp), `docs/qa-log.md` (one row),
  and one new file, `flutter/test/lesson_openings_test.dart` (155 lines, 6
  tests). 374 insertions, 190 deletions.

- `git diff --diff-filter=D` across the batch returns nothing, and no existing
  test file was modified. That matters for the standing trap this repository
  checks by name: no test had to CHANGE for this work to pass, so nothing here
  has the shape of a suite that was defending a defect.

- The content change: all 29 lessons in the Grow Your Money path opened with a
  block headed `'Why it matters'` whose first sentence was a definition. The
  audit's simulated user panel had two of three testers stopping at the first
  sentence of the crypto lesson. Every one of the 29 now opens on a recognisable
  moment in second person, with the definition landing immediately after, and
  the 29 identical headings became 29 distinct ones.

- THREAD 1, THE DEFECT IN THE GUARD'S OWN MEASUREMENT, verified by
  reconstruction rather than from the commit message. The fix is present:
  `flutter/test/lesson_openings_test.dart` lines 44 to 55 define `_sentences`
  splitting on `RegExp(r'(?<=[.?!])\s+')`, with the comment above it that names
  the failure ("Splitting on '. ' alone silently glued a question to whatever
  followed it, which made three openings measure as one 35 to 73 word sentence
  that nobody had written"). To check the claim rather than read it, both
  splitters were run over the shipped openings in a worktree at `ce95c8e5`. The
  buggy `split('. ')` reports exactly three offenders over 30 words,
  `invest-ready-goal-time-access: 35`, `sb-verify-before-you-invest: 39`,
  `gs-decision-plan: 73`. The fixed splitter reports ZERO. The three figures in
  the commit message are exactly right, and all three are artefacts. The shipped
  openings contain six sentences ending in a question mark, which is the whole
  mechanism.

- THREAD 2, THE PROOF METHOD, re-run rather than assessed on paper. The test file
  and the content changed in the same commit, so the commit message is the only
  contemporaneous evidence. It is not the only POSSIBLE evidence: the pre-f3.56
  content is still in git. A worktree at `10ca9e6^` with the shipped
  `lesson_openings_test.dart` copied onto it runs red, `00:00 +2 -4`, failing
  exactly `the first sentence speaks to them`, `no opening sentence is a wall`,
  `no lesson still uses the generic heading` and `the headings are distinct from
  each other`, and passing the scope self-check and the em dash check. That is 4
  of the 5 substantive assertions, precisely what the commit claims once the
  scope self-check is excluded from the denominator, which is the fair reading.
  The claim is accurate and, more importantly, it is REPRODUCIBLE by anyone,
  today or in a year.

- THREAD 3, "NO FACT WAS DELETED", checked structurally instead of by trusting
  the tests cited. Both trees were reconstructed and every block of all 29
  lessons was dumped EXCEPT the opening heading and first paragraph. The two
  dumps are byte-identical, 201 lines each, `diff` exit 0. So "every other block,
  every interaction, every source and every id is byte-identical" is proven, not
  asserted. Separately, `git show 10ca9e6 -- flutter/lib/content/` greps to 0
  changed lines for `canonicalUrl`, and equally 0 for `LessonSource`,
  `reviewStatus` and `verifiedOn`, so the official-source re-search rule genuinely
  was not triggered by this batch. On the openings themselves: every
  digit-bearing figure and every multiword proper noun present in an old opening
  still appears somewhere in the corresponding new lesson, across all 29, zero
  vanished. A looser content-word sweep finds 54 words dropped across 17 lessons;
  the two largest clusters were read in full. `sb-how-bonds-work` keeps
  principal, coupon, maturity, issuer and yield, with "payment" becoming
  "interest" and "bought" becoming "paid". `gs-coupon-yield-price-maturity` keeps
  face value, coupon, purchase price, yield and maturity, with the standalone
  maturity sentence compressed into a gloss ("scheduled to be paid back at
  maturity, its own end date"). One honest nuance the commit's phrasing does not
  quite carry: `crypto-scams-provider-verification`'s eleven scam patterns are
  now nine in the enumerated list plus two folded into the narrative hook
  ("Someone in your group chat posts profit screenshots and offers to pay you for
  every friend you bring in" carries recruitment-for-payment and
  screenshots-as-proof). No fact was deleted, and a reader skimming for a list
  now counts nine.

- THREAD 4, THE APPLIER. The script survives in the session scratchpad as
  `apply_openings.py`, 29 entries in an `EDITS` table. The refusal path is real
  and correctly shaped: every edit accumulates into an in-memory `changed` dict,
  any missing or ambiguous anchor appends to `problems` and continues, and after
  the loop `if problems:` prints `REFUSING TO WRITE, anchors failed:` and calls
  `sys.exit(1)` BEFORE the write loop runs. All or nothing by construction. It is
  the exact inverse of the failure shape CLAUDE.md's hook rule 1 bans, where an
  assert throws after some writes have already landed.

**Root cause.** For the one thing that actually went wrong, the splitter, the
answer is structural and not attention.

Measurement code that lives inside a test file is the only measurement code in
this repository with no tests of its own, and it has none purely because of
where it sits. In the batch immediately before this one, f3.55 added a
reading-time model and gave it `test/reading_time_test.dart` with 12 cases,
because it ships in `lib/`. `_sentences` is a hand-written parser with a
lookbehind assertion, no simpler than the reading-time model, and it got zero,
because it sits in `test/` and tests are not a thing this repository writes tests
for.

The repository's flagship rule does not reach this. "Prove a new test can fail
before trusting it" was FOLLOWED here, and it passed while the instrument was
broken: running the shipped test against the pre-f3.56 tree with the BUGGY
splitter yields 13 wall offenders, and with the FIXED splitter 12, so the wall
check reddens on the old content either way. The ritual watches the red or green
bit. A wrong number behind a correct colour is invisible to it.

That is why this is a pattern rather than two unrelated incidents. Across three
batches the instrument, not the code, was the thing that was wrong four times:
f3.54's fallback-guard test that passed with the guard deleted, f3.55's
reading-time model blind to exercise text, f3.55's drift guard asserting an
assumption rather than a requirement, and f3.56's splitter. All four were caught,
and in the two most recent cases the thing that caught them was the same
technique, which is not the pass or fail bit at all: make the instrument verbose
and READ its output. f3.56's splitter was pinned by dropping the threshold to 12
words and reading 115 quoted sentences. f3.55's reading-time model was pinned by
reading the estimate for the one lesson the fix existed for. The common cause is
that this repository has moved from measuring crisp properties, where the money
adds up or it does not, to measuring fuzzy ones: readability, prose shape,
minutes, engagement. A fuzzy measurement can be wrong and still return a
plausible number, and a plausible number survives every pass or fail check ever
written for it.

**Lessons, each with its guard and the guard's strength.**

1. A measuring helper inside a test file is untested by construction, and the
   break-then-prove rule provably cannot catch it.
   GUARD, and the only new machine this session recommends: give `_sentences` its
   own test cases in `flutter/test/lesson_openings_test.dart`, with a fixture
   containing a sentence ending in a question mark, one ending in an exclamation
   mark, and one abbreviation. The first two pin the bug that actually happened.
   The third pins a limitation that is real but currently harmless: the shipped
   openings contain no `e.g.`, no `i.e.`, no decimal figure and no
   terminator-then-quote, checked this session, so the fixed splitter is correct
   for today's content and would mis-split the day someone writes "e.g. a UITF".
   STRENGTH: strongest tier. It is an automated check that fails loudly, it is an
   ordinary `*_test.dart` file, so it runs on the Flutter check with everything
   else and works while nobody is watching.
   COST: about ten lines and no measurable runtime. The honest limit on its
   value is that it guards THIS splitter, not the class. The class-level version
   is a sentence in CLAUDE.md ("a helper in a test file that parses, counts or
   measures gets its own case, because prove-fail cannot see a wrong number
   behind a correct colour"), and that is medium strength, because it depends on
   someone reading it at the right moment.
   COST IF REMOVED, stated plainly rather than inflated: this defect class wastes
   work, it does not reach the phone. A broken measurement either flags prose
   that is fine, which is what happened and was caught, or fails to flag prose
   that is not, which is silent. Neither ships a defect to the founder. The
   expensive version of this class is the one where the instrument is a SHIPPED
   feature, which is exactly f3.55's reading-time model, and that one does reach
   the phone.

2. "Written first, watched red, then made green" is STRONGER than
   break-then-restore here, not weaker, and the reason is that it is re-runnable.
   The worry worth testing was that nothing re-proves it after the fact. That
   worry is false, and this session settled it by doing the re-run rather than
   reasoning about it: the old content is permanently in git at `10ca9e6^`, so
   copying the shipped test onto that tree reproduces the original red exactly, 4
   failures out of 5 substantive assertions, named above. Compare
   break-then-restore, where the deliberate break is by definition never
   committed and so can never be re-run by anyone later; its evidence is a quoted
   failure line in a commit message and nothing more. Written-first leaves the red
   state in the repository's history forever.
   The real weakness is a different one and should be named instead:
   written-first proves the guard detects the defect that EXISTED,
   break-then-restore proves it detects a defect someone INVENTS, and neither
   proves it detects a future regression of a shape nobody has thought of.
   Written-first also proved nothing at all about the splitter, since the wall
   check reddens on the old tree with the bug in place.
   GUARD: none new, deliberately. Nothing is broken. What is recorded instead is
   the recipe, so the next session does not have to rediscover it: to re-prove a
   written-first guard, `git worktree add --detach <dir> <commit>^`, copy the
   test file in, run it. STRENGTH: this is documentation, which is weak, and it
   is the right level, because the underlying method is sound and needs no
   enforcement.

3. The evidence CITED for "no fact was deleted" is close to vacuous, while the
   claim itself is true on evidence nobody had gathered until this session.
   The commit message and the f3.56 qa-log row both say the five per-course
   content tests and `lib/money/expansion_content_policy.dart` passing untouched
   is "the evidence that no fact or safety statement was lost". It is not, for
   three reasons visible in the test files. Those tests concatenate through a
   helper `_allText(l)` that walks EVERY block, so a fact deleted from the
   opening but present anywhere later still passes, and since every later block
   is byte-identical they could not have reddened for anything the opening lost.
   The overwhelming majority of their assertions are NEGATIVE, banned phrase,
   banned provider name, no percentage figure, no em dash, and deleting text can
   never fail a banned-phrase check, so the polarity is backwards for detecting
   deletion. The positive assertions that do exist target specific figures such
   as `'1,500 pesos'`, `'7,500 pesos'` and `'92,500 pesos'` in
   `lessons_deposits_pooled_funds_content_test.dart` lines 447 to 449, which live
   in later, unchanged blocks. Those suites passing untouched was very nearly
   guaranteed by construction.
   This matters because the sentence reads as proof and would be believed. The
   claim survives, on the structural diff and the token survival check described
   in the timeline, both run this session for the first time.
   GUARD: none new, and a machine is genuinely not warranted. A test cannot
   express "everything outside the opening is unchanged", because that is a
   statement about two versions of the repository, not about one. The durable
   change is free and is about what gets WRITTEN: when a content batch claims
   nothing was lost, cite the diff that proves it ("everything outside the
   opening heading and first paragraph is byte-identical across all 29 lessons")
   rather than a green suite whose assertions cannot fail on deletion.
   STRENGTH: weak, a wording habit, and said out loud as weak.

4. The applier refused correctly and never checked its own output, and the check
   that mattered was run for the first time this session, after delivery.
   `apply_openings.py` writes and prints `rewrote 29 openings across 5 files`. It
   never re-reads the files and never compares what Dart would parse against the
   drafted string. That comparison was run this session: all 29 drafted headings
   and all 29 drafted paragraphs appear byte-identical in the shipped,
   Dart-parsed content. The outcome was correct, and it was design rather than
   luck. `dart_literal` wraps at 62 characters into adjacent single-quoted Dart
   literals and places the trailing space on every non-final line
   (`trail = " " if i < len(lines) - 1 else ""`), which is the precise detail
   that would otherwise silently glue two words together across a line break,
   and Dart would compile it happily. Residual honesty: the script is not in the
   repository, only in the session scratchpad, so the mechanism that made 29
   founder-visible edits is not reviewable by anyone later.
   GUARD: none, and building one would be machinery for a thing that does not
   exist. A repo-level check for a throwaway script that will never run again is
   worse than nothing, because it adds a file someone has to maintain. The
   generalizable habit costs five lines AT THE TIME and is worthless afterwards:
   when a script applies N drafted edits, have it re-read and assert the applied
   text equals the drafted text before it exits. Noted, not built.
   STRENGTH: an intention, the weakest tier, accepted here only because the
   subject is ephemeral by nature.

**What went well, credited honestly.** The batch's own self-catch is the good
part and it should not be lost inside the correction above. The splitter defect
was found by the person who wrote it, before merge, by refusing to believe three
implausible numbers and going to look. Had it been trusted, three perfectly good
paragraphs would have been rewritten to satisfy a bug, and the repository would
now contain worse prose plus a guard quietly enforcing the wrong shape forever.
The scope self-check in the same file is the second good part: `_coveredPathIds`
is a named list asserted to contain exactly `grow_your_money`, with
`expect(_covered.length, 29)` beside it, so Protect Your Future and Build Your
Business opening the old way is a stated gap rather than an implied claim of
coverage. That is the `palette_contrast_test.dart` iterate-then-assert shape,
applied to scope rather than to a registry.

**CLAUDE.md factual re-check (done as a step, not a favour).** All 28 paths
CLAUDE.md names were checked for existence this session and every one exists
where it says, including both workflow files,
`.github/scripts/check-stamp-unique.sh`, `.githooks/pre-push`,
`.claude/hooks/guard-destructive-edits.sh`, `.claude/settings.json`,
`flutter/shorebird.yaml`, `test/screens_shot.dart`,
`test/palette_contrast_test.dart`, `test/screen_readability_test.dart`,
`test/golden/ui_golden.dart`, `test/golden/baseline/`, `test/segmented_test.dart`,
`test/journeys_test.dart`, `test/qa_record_test.dart`,
`test/update_stamp_test.dart`, `lib/widgets/salapify_icon.dart`,
`lib/money/expansion_content_policy.dart`, `.claude/agents/journey-tester.md`,
`mobile/app/(tabs)/more.js`, and `docs/Product_Vision_Spec.md`. Triggers were
read, not assumed: `.github/workflows/flutter-check.yml` still triggers on `push`
to `claude/**`, and `.github/workflows/flutter-preview.yml` still triggers on
`push` to `main` filtered on `flutter/**`, exactly as Flutter rule 1 describes.
`updateStamp` is still at `flutter/lib/main.dart` line 33. Two claims were
checked that earlier sessions had not: the render paragraph says
`test/palette_contrast_test.dart` measures "all sixteen palettes", and
`lib/theme.dart` line 479's `barakoThemes` holds 8 themes resolved at 2
brightnesses, so sixteen palettes is exactly right and the test asserts
`expect(seen, barakoThemes.length * 2)` to keep it that way. Commands were
checked as written: `.githooks/pre-push` does run the identical
`check-stamp-unique.sh` that CI runs at `flutter-check.yml` line 167, and
`git config core.hooksPath` in this checkout returns `.githooks`, so the hook is
actually live here and not merely present. CI does run the render harness with
`--update-goldens` (`flutter-check.yml` line 192) and does compare
`test/golden/ui_golden.dart` with `continue-on-error: true` (lines 209 to 210),
both exactly as described.
ONE MILD DRIFT, reported because the value of this check dies if it is only
reported when it fails: the sweep paragraph says the screen list covered "ten of
the fifty files in lib/screens", and `lib/screens` now holds 55 `.dart` files.
The sentence is past tense and describes a past state, so it is not a false
claim, and it is not being edited on that basis. It is worth naming that a number
in prose has rotted by five while sitting two paragraphs from the rule that says
numbers in prose rot. Nothing else was found stale, and no false factual claim
was found in CLAUDE.md this session.

**Open lessons carried forward.**
- From session 34, STILL OPEN and not built: the qa-log staleness check.
  `flutter/test/qa_record_test.dart` still contains exactly one test, `'the
  shipping stamp has a QA row in docs/qa-log.md'`, with no timestamp or
  freshness assertion. It remains specified precisely enough to build in one
  sitting. This batch gave it no new evidence either way, since f3.56's qa-log
  row was written once and the code did not move under it.
- From session 34, NOW CLOSED and closed the right way: audit finding H2, the
  Learn header counting only the core 22. The founder decided it, and f3.55
  shipped the headline counting the whole catalog. The four tests that blocked
  it in Batch 1 were REWRITTEN rather than deleted, verified this session rather
  than taken from the qa-log: `learn_screen_grow_path_test.dart`,
  `learn_screen_protect_path_test.dart` and `learn_screen_business_path_test.dart`
  now assert against `store.lessonProgress` directly instead of against a number
  on screen, and `git diff --diff-filter=D` across the f3.55 and f3.56 range
  shows no test file deleted. A screen can render the right number for the wrong
  reason; the store cannot.
- The `screens_shot` list gap: this batch does NOT add evidence for it, and the
  expectation going in was that it would. Six of the 29 rewritten openings are
  rendered at the top of a reader by `test/screens_shot.dart`
  (`grow-readiness-card`, `paged-lesson-first-screen`,
  `stocks-bonds-how-bonds-work`, `stocks-bonds-verify-before-you-invest`,
  `deposits-read-a-fact-sheet`, `crypto-volatility-total-loss`), so roughly a
  fifth of the changed surface was genuinely lookable, on a change that was
  uniform in shape. The gap is real and carried forward unchanged, but it did not
  bite here and saying it did would have been a manufactured finding.
- From session 33: `.githooks/pre-push` present and, this session, confirmed
  ENABLED in this checkout rather than merely present. The "each URL" re-search
  rule was not exercised, verified by grep rather than assumed: zero
  `canonicalUrl`, `LessonSource`, `reviewStatus` and `verifiedOn` lines were
  added or removed in `10ca9e6`.
- From session 31: the prove-fail marker-file sharpening, the stale `goals.dart`
  allowlist entry, the 320dp readability question and the
  fixture-through-the-writer shape test are all untouched by this batch and
  carried forward unchanged. Lesson 1 above is a cheaper and different sharpening
  of the same prove-fail rule, aimed at the case where the ritual passes while
  the instrument is wrong.

**For the founder, over lunch.** f3.56, patch 48, is on your phone and it is
correct. All 29 lessons in Grow Your Money used to start with a dictionary
definition under the same heading, "Why it matters", twenty nine times. When we
put the courses in front of a simulated panel of readers, two out of three quit
at the very first sentence of the crypto lesson and never got to the exercises
underneath, which are the good part. Every one of those 29 now starts with a
moment you would recognise, a teller sliding a brochure across the counter, a
cousin sending screenshots of daily payouts, an officemate calling bonds the
boring sensible option, and the definition arrives one sentence later, once you
already care. Nothing was thrown away: I reconstructed the old version of the app
this morning and compared it against the new one, and everything apart from that
opening paragraph is identical character for character, with every figure and
every named agency still present.

Two things worth two minutes each.

First, the thing that went wrong was my ruler, not the wall. I wrote a small
safety test that measures whether an opening sentence is too long. It counted
sentences by looking for a full stop, which means a sentence ending in a QUESTION
MARK got stuck onto the next one. It then told me three of my openings were
single sentences of 35, 39 and 73 words, which nobody had written. If I had
believed it, I would have rewritten three perfectly good paragraphs to please a
bug, and the app would now be slightly worse with a test permanently enforcing
the mistake. I did not believe it, because 73 words is not a thing a person
writes by accident, so I went and looked.

That is the second time in three updates that the measuring device was the broken
thing rather than the code, and the first time it happened the device was one you
can see: the "3 min" estimate on a lesson could not see the exercises, so it
under-counted. So this is a pattern and not bad luck. The reason is worth
knowing. This project has a strong house rule that a new safety test must be
watched actually failing before it is trusted, and that rule works extremely
well. It could not catch this one. The test DID fail on cue, exactly as the rule
demands. It just failed while reporting wrong numbers, and the rule only ever
looks at whether the light went red, never at what the number said.

So I am recommending one small automatic check, and only one: the little piece of
code that chops text into sentences should get a couple of tests of its own,
including one sentence that ends in a question mark. Ten lines, no noticeable
time, and it runs automatically on every change from then on. The reason it does
not already exist is a blind spot with a shape: this project writes tests for
everything in the app, and never writes tests for the small helpers that live
inside tests, purely because of which folder they sit in. If that check is ever
removed, the cost is wasted work rather than a broken app, and I want to be
straight about that rather than make it sound scarier than it is. A broken ruler
in a test either raises a false alarm, which is what happened and which was
caught, or stays quiet when it should not, which nobody notices. Neither one
sends a bug to your phone. The version that DOES reach your phone is when the
broken measurement is a number the app shows you, like that lesson time, and that
is exactly why the pattern is worth stopping now while it is still cheap.

Second, something that came out better than expected. I usually prove a safety
test works by deliberately breaking the app, watching the test go red, then
putting it back. This time I did it the other way round: I wrote the test first
and ran it against the OLD lessons, where it went red on four of its five checks,
and only then rewrote the content until it went green. The worry with doing it
that way is that once everything is green there is nothing left to re-check, so
you are just taking my word for it. That turns out to be wrong, and I checked
instead of assuming: the old lessons are still in the project's history, so I
rebuilt them this morning and ran the test against them again, and it went red on
exactly the four checks I said it did. That evidence stays there permanently.
When I break something on purpose and put it back, the break is gone forever and
you genuinely do have to take my word for it. So the unusual method was the
better one, and I have written down how to repeat it.

One correction to something I told you in the update notes, because it was
overstated. I said that five existing content tests passing unchanged was the
proof that no fact had been deleted. It was not proof. Those tests read the whole
lesson at once, and almost all of them check that bad things are ABSENT, banned
phrases, invented percentages, real company names. A test like that can never
fail because something was removed, only because something was added. They were
always going to pass. The claim is still true, but what makes it true is the line
by line comparison I described above, not those tests, and you should know which
of the two is actually holding it up.

---

## 2026-08-06, session 34: f3.54 shipped clean, a new test that passed with its own guard deleted and caught itself, and a suite that refused a change the audit had asked for

**What we believed / What was true.** The founder confirmed the Update stamp on
the phone reads "f3.54 patch 46". The delivery log's last row agrees:
`| 2026-08-06 03:26 UTC | f3.54 | 46 | patch | 0.9.0+15 | [35946207](.../31067688776) |`
(docs/delivery-log.md, last row on origin/main, PR #332, merge commit
`3594620`, delivery commit `6437d6c`). Mode is `patch`, base APK still
0.9.0+15, so no manual install was needed and none was claimed. The row before
it is f3.53 patch 45, so patch numbers ran 45 then 46 with nothing between and
no unrecorded patch slipped through. `flutter/lib/main.dart` line 33 carries
`'f3.54 · Lessons now celebrate, hand you the next one, and remember you
finished.'`, which is what the founder read on the phone. The phone, the
delivery log, origin/main and the stamp constant all agree.

Say the top line plainly, because it is the finding and not a warm-up: this was
a clean delivery. One stamp, one patch, one merge, no collision, no stranded
base APK, no version number spoken to the founder before its row existed.
Nothing in this session's evidence contradicts that, and nothing was
manufactured to make the session feel earned.

Underneath the clean line sit four things worth examining, and the interesting
part is that three of them are the repository's own guards WORKING, one of them
loudly and in a way that had not been documented here before. All four were
checked against git history and file contents this session rather than taken
from the task brief, per the standing rule that a handed-down claim is audited
exactly like any other.

**Timeline (with evidence).**

- The batch is four commits on `claude/salapify-money-courses-audit-i3rrxi`,
  all inside 43 minutes, all under one stamp: `50dce2b` at 02:06 (Phase 1 quick
  wins), `5ae7845` at 02:18 (render the finish card, fix the Next button),
  `d5ed304` at 02:43 (revert the header change), `e068897` at 02:49 (correct
  the qa-log row). Merged as PR #332, published as patch 46.

- `50dce2b` added `flutter/lib/money/lesson_flow.dart` (191 lines, pure) and
  `flutter/lib/content/course_sequences.dart` (75 lines), rewrote the end of
  both readers into a finish card, and fixed audit finding C6: a finished
  expansion lesson reopened showing "0 of N required interactions completed"
  over a disabled Finish button, because completion lived only in the reader's
  ephemeral `_completedBlockIds` and nothing ever read the stored `LessonState`
  back. Three new test files, 44 new tests. `git diff --name-status
  82d820d..e068897 -- flutter/test` shows three files ADDED and one MODIFIED
  (`screens_shot.dart`, the render harness), and `git diff --diff-filter=D`
  across the whole batch returns nothing. That matters for the standing trap:
  no existing test was changed or deleted anywhere in this batch, so nothing
  here has the shape of a suite that was defending a defect. The opposite
  happened, twice, below.

- THE SELF-CAUGHT TEST DEFECT, verified in the file rather than in prose. The
  fallback branch of `finishOutcome` (`lib/money/lesson_flow.dart` lines 151 to
  157) offers the first unfinished lesson anywhere when there is none after the
  finished one, and it carries a guard, `l.id != finishedId`, so a lesson whose
  completion write never landed is never re-offered as its own next step. The
  first version of the test for that guard finished lesson "a1" and expected
  the next lesson not to be "a1". It passed with the guard deleted. The reason
  is structural and is now written into the test itself
  (`flutter/test/lesson_flow_test.dart` lines 78 to 96): "It has to be the LAST
  lesson with everything before it done. Any earlier position and the forward
  scan finds a later unfinished lesson first, so the fallback never runs and
  the guard is never exercised. An earlier draft of this test used position
  one, passed with the guard deleted, and proved nothing." It was rewritten to
  finish "b1", the last lesson, with everything before it already done, and
  only then watched fail: `Expected: not 'b1' / Actual: 'b1'`, quoted in
  `50dce2b`'s own commit message alongside three other proven-fail lines. The
  only thing that found this was the repository's own "prove a new test can
  fail before trusting it" rule, actually being run.

- THE REVERT THE SUITE FORCED. The same batch changed the Learn hub header to
  count the whole 93-lesson catalog instead of the core 22, which is audit
  finding H2 (docs/money_courses_experience_audit.md lines 189 to 195: "the
  headline metric counts only the 22 core lessons... The header ignores 76
  percent of the catalog"). The full suite went red. This session counted the
  failures rather than repeating "four": exactly four test cases assert that
  figure, and all four break under a whole-catalog count.
  `learn_screen_grow_path_test.dart:111`,
  `learn_screen_protect_path_test.dart:125` and
  `learn_screen_business_path_test.dart:130` each finish an ENTIRE expansion
  path and then assert `find.text('0 of ${core.lessons.length} lessons')`, and
  `learn_screen_test.dart:15` asserts the same figure three times inside one
  case. The tests are not stale.
  `flutter/lib/content/learning_path.dart` lines 7 to 9 call the core four
  tracks "load-bearing for the 'X of 22 lessons' figure on the Learn screen",
  and those tests are how the two separate progress stores are proven isolated.
  `d5ed304` reverted the change, kept the two parts of it that conflict with
  nothing (the warm first-visit line, and no "about 43 min left" bill until
  something is finished, neither asserted by any test), and left H2 open in the
  audit for the founder, on the stated ground that changing what a headline
  number MEANS is a product decision with a documented rationale on the other
  side and not a quick win.

- THE FALSE SENTENCE THAT ALMOST SHIPPED IN THE QA LOG. The f3.54 row was
  written in `50dce2b` at 02:06, before the revert existed, and it claimed "the
  hub header now counts the WHOLE catalog (core plus every published path)
  instead of only the core 22". The production code that made that true was
  removed at 02:43. The row was corrected at 02:49 in `e068897`, whose diff
  (read this session) replaces that clause with an explicit "HONEST CORRECTION,
  recorded because the first version of this row claimed otherwise" naming the
  revert and the four tests. docs/qa-log.md's own header, lines 11 to 21, warns
  that the guard "CANNOT stop a row being written for a pass that did not
  happen. Nothing automated can." This was the reverse direction of exactly
  that: a row describing something that did not ship. It was caught because the
  author remembered, and by nothing else.

- THE LAYOUT FLAW ONLY THE PICTURE CAUGHT. `5ae7845` added the finish card's
  first render (`flutter/test/screens_shot.dart` line 2505, "the finish card,
  the moment a lesson ends", dark, real fonts, tapping through to the finished
  state for real) and its commit message records what looking at it caught:
  "Next: Needs, wants, and the 24-hour rule . 1 min" wrapped as one run and
  stranded "min" alone on the second line. The fix (visible in the diff at
  `lib/screens/learn.dart` around line 1560, mirrored in
  `expansion_lesson_reader.dart`) makes the label deliberately two lines, title
  then minutes, with the reason in a code comment. This was invisible in the
  diff and invisible to every one of the 2,560 tests that later ran green.

**Root cause.**

There are three, and they are different from each other, which is why they get
separate lessons.

For the test that passed for the wrong reason: the test and the code were
written from the same mental model in the same sitting, and that model was
wrong about ONE thing, which position in the sequence reaches the fallback
branch. A test built on a wrong model does not fail, it agrees. Nothing about
attention would have helped, because the author was paying attention and still
believed the input reached the branch. What separated belief from reality was
deleting the guard and watching the test not care.

Worth foreclosing precisely, because it sounds like the obvious machine: LINE
COVERAGE WOULD NOT HAVE CAUGHT THIS. The sibling test at
`lesson_flow_test.dart:67`, "sends a learner backwards to an earlier gap",
finishes "b1" with an unread "a2" and does reach the fallback loop, so the
guard line `l.id != finishedId` was executed by the suite either way. What was
never exercised was that condition evaluating to FALSE. `flutter test
--coverage` reports per-line hit counts, not per-condition outcomes, so that
line would have shown covered and green. Recorded here so a future session does
not spend a day building a coverage gate that this exact defect would have
walked straight through, in the same spirit as session 31 naming its proposed
pre-commit gate as theater.

For H2: the experience audit examined the SCREEN. It described the header
figure accurately, filed a fair complaint about it, and never looked at what
depended on that figure. Checked this session:
`grep -i "load-bearing\|isolat\|learning_path.dart"` across
docs/money_courses_experience_audit.md returns NOTHING. The invariant existed,
in writing, in `content/learning_path.dart`'s own header comment, and the audit
had no reason to be reading that file. The structural gap is that a
recommendation to change a displayed value was produced by reading the display,
while the reason not to change it lived in a file two layers away that the
recommendation never touched. The strong guard that caught it, the full suite
on a real runner before merge, worked exactly as designed. Its only cost was
ordering: it ran late in the batch, after the change had been written,
reviewed, and written up.

For the qa-log row: the row was written with the FIRST commit of a batch that
then kept changing, and nothing re-reads a row against the final diff. This is
not a discipline failure, it is a sequencing one. Writing the row early is good
practice for every other reason (it forces the QA thinking before the code is
frozen), and it is precisely what makes the row go stale when the batch
continues. The file's own header already says no machine can check a row is
TRUE. But this failure was not about truth in general, it was about a row going
stale under production code that changed after it, and THAT is mechanically
observable, which lesson 3 takes up.

**Lessons, each with its guard and the guard's strength.**

1. A test can pass because its input never reaches the code it names, and only
   deliberately breaking that code reveals it. GUARD, already in place and now
   with a second documented save: CLAUDE.md's "Prove a new test can fail before
   trusting it". Strength: MEDIUM, and honestly so, because it is a rule read
   at authoring time and nothing can observe whether it was run. It is,
   however, the ONLY thing that catches this class, which the coverage analysis
   above establishes rather than asserts. One real SHARPENING is available and
   is recommended: CLAUDE.md currently says break it, watch it fail, paste the
   failure line. It says nothing about the case where the break does NOT
   produce a failure, which is the case that just happened and the most
   informative outcome the procedure has. Add one sentence to that section: a
   prove-fail attempt that stays GREEN is itself a finding about the test, not
   a formality to redo quietly, and both the rewrite and what made the original
   shape unreachable belong in the test's own comment and in the qa-log row.
   This session did all of that voluntarily (`lesson_flow_test.dart` lines 84
   to 88, and the f3.54 qa-log row's verdict column), which is the argument
   that the sentence is writable rather than aspirational. Strength of the
   sharpening: MEDIUM, a documentation guard, and it is stated as such.

2. A recommendation produced by reading a screen can be blind to an invariant
   that lives two files away, and the full suite is the thing that finds it.
   GUARD, and this one was BUILT this session rather than recommended:
   `d5ed304` put the invariant at the exact site where the next person will
   make the same change, `lib/screens/learn.dart`'s `_header` doc comment
   (verified this session, lines 368 to 391), naming
   `content/learning_path.dart`'s "load-bearing" phrase, naming the three
   expansion-path tests that assert it, and naming H2 as an open product
   decision rather than an oversight. The comment's own count is precise, not
   sloppy: it says three tests assert that finishing an entire expansion path
   never moves the figure, which is exactly true; the fourth failing case is
   the core screen's own test, not an expansion one. Strength: MEDIUM, because
   a comment still has to be read, but it is the strongest form of medium
   available, sitting at the moment of the change rather than in a document.
   The STRONG guard here already existed and needs no work: the full suite on
   the branch check, which caught this unaided. The only improvement available
   is workflow, not machinery, so it is ranked WEAK and named honestly: run the
   focused test files for a screen as soon as that screen is changed, instead
   of meeting them in the full suite at the end of the batch. Nothing can
   enforce that, and it would have saved ordering cost only, not correctness.

3. A qa-log row written with the first commit of a batch describes a batch that
   has not finished happening yet. GUARD, buildable, mechanical, and
   RECOMMENDED rather than built this session: a branch-check script in the
   shape `.github/scripts/check-stamp-unique.sh` already establishes, asserting
   that on the branch, the last commit touching `docs/qa-log.md` is not OLDER
   than the last commit touching `flutter/lib/`. Checked against this exact
   history, it would have gone red at 02:18 and again at 02:43, and green only
   after 02:49 (`git log 82d820d..e068897 -- docs/qa-log.md` gives 02:06 and
   02:49; `git log 82d820d..e068897 -- flutter/lib` gives 02:06, 02:18, 02:43).
   Strength: STRONG, because it is a machine that runs on every push and needs
   no judgment, with one limit and one cost stated up front. The limit: it
   cannot verify a row is TRUE, only that nobody changed production code after
   writing it without re-reading it, which is exactly the shape that happened
   here and is not the general problem the file's header correctly calls
   unsolvable. The cost: it will fire on a trivial `lib/` tweak made after the
   row is written, and CLAUDE.md's own reasoning about the destructive-edit
   hook says a guard that fires on normal work gets switched off. The
   mitigation is that satisfying it is a one-word edit whose whole purpose is
   forcing the re-read, but the nag is real and should be a deliberate decision
   rather than a surprise. It belongs in
   `.github/workflows/flutter-check.yml` next to the stamp check, and could
   also ride in `.githooks/pre-push`.

4. Positive result, recorded as one, because it is evidence for a rule that
   costs time every batch and has to keep earning it. Looking at the picture
   caught a real layout flaw that the diff could not show and 2,560 tests did
   not notice. GUARD: CLAUDE.md's "Look at the screen before shipping a
   screen", already in place, and this is now the third named instance of it
   catching something (a lesson rendering prose as a wall of text, lessons
   losing their completed tick, and now the orphaned "min"). Strength: MEDIUM
   as written, because the render is opt-in and a picture nobody opens proves
   nothing. The honest gap this batch adds evidence for is NOT new: the finish
   card, the centre of the whole batch, had no render at all in `50dce2b` and
   only got one in the follow-up `5ae7845`. That is the known "the sweep's
   screen list is a LIST, not every screen" gap CLAUDE.md already names,
   hitting a brand new surface. No new guard is invented for it here; it is
   carried forward with this batch as fresh evidence, and the model for closing
   it properly is still `palette_contrast_test.dart`, which iterates a registry
   and then asserts it saw all of it.

**What went well, credited honestly.** Three separate guards fired in one
43-minute batch and all three fired BEFORE the phone, which is the whole design
intent: prove-fail caught a hollow test, the full suite refused a change that
would have broken a documented invariant, and the render caught a layout flaw
nothing else could see. None of the three was a near-miss that got lucky; each
is a mechanism doing the specific job it was written for. The revert is the
best of them, and belongs here as a positive rather than a problem: the code
was changed to obey the tests, not the tests changed to permit the code, and
`git diff --diff-filter=D` across the batch confirms no test was weakened or
deleted anywhere. The one thing with no mechanism behind it, the stale qa-log
sentence, is the one thing that came closest to shipping wrong, which is a
clean natural experiment on the value of machines over memory.

**CLAUDE.md factual re-check (done as a step, not a favour).** Every path
CLAUDE.md names was checked for existence this session and all 23 exist where
it says: `flutter/lib/main.dart`, both workflow files,
`.github/scripts/check-stamp-unique.sh`, `.githooks/pre-push`,
`flutter/test/screens_shot.dart`, `palette_contrast_test.dart`,
`screen_readability_test.dart`, `test/golden/ui_golden.dart`,
`test/golden/baseline/`, `segmented_test.dart`,
`.claude/hooks/guard-destructive-edits.sh`, `.claude/settings.json`,
`lib/widgets/salapify_icon.dart`, `test/journeys_test.dart`,
`.claude/agents/journey-tester.md`, `test/qa_record_test.dart`,
`test/update_stamp_test.dart`, `docs/Product_Vision_Spec.md`,
`mobile/app/(tabs)/more.js`, `flutter/shorebird.yaml`, `docs/qa-log.md`,
`docs/delivery-log.md`. Triggers were read, not assumed:
`.github/workflows/flutter-check.yml` still triggers on `push` to `claude/**`,
and `.github/workflows/flutter-preview.yml` still triggers on `push` to `main`
filtered on `flutter/**`, exactly as Flutter rule 1 describes. `updateStamp` is
still at `flutter/lib/main.dart` line 33. The render-harness paragraph's claim
that shots land in a gitignored folder holds: `.gitignore` line 7 is
`flutter/test/shots/`. No stale path and no false factual claim was found in
CLAUDE.md this session. Recorded as required even though the answer is that
everything matched, since two consecutive earlier sessions found a false claim
here and the value of the check is destroyed if it is only reported when it
fails.

**Open lessons carried forward.**
- From session 33: both of its recommendations were built the same day
  (`.githooks/pre-push`, confirmed present this session, and the "each URL"
  sentence in CLAUDE.md's Money Courses rule, confirmed present). Neither was
  exercised this batch, which touched no course content and no government
  source, so no new evidence either way.
- From session 31: the prove-fail marker-file sharpening is still open and this
  session declined to build it for the same reason session 31 gave, that the
  marker depends on being written and is therefore itself a rule. Lesson 1
  above is a different and cheaper sharpening of the same rule, aimed at the
  green-break case rather than at the restore-ordering case. The stale
  `goals.dart` allowlist entry, the 320dp readability question, and the
  fixture-through-the-writer shape test are all untouched by this batch and
  carried forward unchanged.
- The screens_shot list gap (lesson 4) is carried forward with new evidence: a
  brand new surface, the finish card, shipped its first commit with no render.
  Still not closed, still the same known shape, still buildable by the
  `palette_contrast_test.dart` iterate-then-assert pattern.
- NEW and open: audit finding H2 itself. The Learn header counts the core 22,
  so a learner who finishes all 18 Protect Your Future lessons still reads "0
  of 22 lessons". That is a genuine product problem, deliberately not fixed,
  now waiting on a founder decision. The reason it was not fixed is written at
  the site (`learn.dart`'s `_header` doc comment) so it cannot be mistaken for
  an oversight by whoever reads it next.
- NEW and open: lesson 3's qa-log staleness check, specified precisely enough
  to build in one sitting, verified against this batch's own commit
  timestamps, and not built this session.

**For the founder, over lunch.** f3.54, patch 46, is on your phone and it is
correct. Lessons now end with a real card: what to keep, how far you are
through the course, and a button straight into the next lesson instead of a
dead end and a back button. Finishing a whole course or a whole path sets off
the confetti; finishing one ordinary lesson does not, on purpose, because a
party for every one of 93 lessons stops meaning anything. It also fixes a real
bug you could have hit: a lesson you had already finished, reopened, used to
say "0 of N required interactions completed" over a greyed-out Finish button,
as if your progress had vanished. It had not, the screen just was not reading
it back. It reads it back now.

Three things went right underneath that, and one nearly went wrong. Worth two
minutes each.

First, a test caught itself lying. When we add a safety test here, the house
rule is to deliberately break the code first and check the test really turns
red, because a test written with the same wrong idea in it as the code will
happily agree with a bug. This time the break was made and the test stayed
green. It was testing a piece of code its example never actually reached, so it
was proving nothing while looking exactly like proof. It got rewritten until it
really did fail, and only then trusted. That rule costs about three minutes a
test and it just paid for itself again.

Second, our own test suite refused a change I made. The audit that started this
work pointed out, fairly, that the "0 of 22 lessons" figure at the top of Learn
ignores most of the catalog: you could finish all 18 Protect Your Future
lessons and it would still read zero. I changed it to count everything. Four
existing tests immediately went red, because those tests exist to prove the
core lessons and the newer path lessons keep completely separate progress, and
that number is how they prove it. So I put the change back and left the
question open for you, rather than quietly redefining what a number on your
screen means. That is a real decision for you to make, and it is written down
in the audit and in the code so it does not get lost. The important part: I
changed the code to obey the tests, never the other way round. Rewriting a test
so a change can pass is how a bug ends up protected by its own safety net.

Third, and this is the near miss. Every shipped version gets a written QA
record. I wrote f3.54's record early, at the first commit, and it said the
header now counts everything. Forty minutes later I undid exactly that, and the
record still said it. I caught it and corrected it, but only because I happened
to remember, and "I happened to remember" is not something you should have to
rely on. So I am recommending a small automatic check: if the code changes
after the QA record is written, the build goes red until someone reopens the
record and reads it again. I tested that idea against this batch's real
timestamps and it would have fired twice and then gone quiet at the right
moment. It cannot tell whether the record is TRUE, nothing can, but it can stop
a record going stale underneath work that kept moving.

Fourth, a small one that argues for a habit that costs time. A button ended up
reading "Next: Needs, wants, and the 24-hour rule . 1 min" with the word "min"
stranded alone on its own line, which just looks broken. Two thousand five
hundred and sixty automated tests did not see it and no code review could have.
Looking at an actual picture of the screen caught it in about one second. That
is the third time that habit has caught something a test could not.

What it costs if these ever go away. The break-it-first rule is the only thing
standing between us and tests that agree with bugs; without it a green suite
starts meaning less every month, and you would find out from your phone instead
of from a build. The four tests that blocked the header change are what keep
your core lesson progress and your path lesson progress from bleeding into each
other; if someone ever deletes them to make a change pass, the two counters can
silently start reporting each other's numbers and nothing will complain. And
the screenshot habit is the only check on whether a screen actually reads well,
as opposed to merely fitting; drop it and layout bugs reach you first.

---

## 2026-08-05, session 33: f3.51 shipped clean, a third pre-authored stamp collision this same day, and a review that caught three real bugs but missed a fourth of its own kind

**What we believed / What was true.** The founder confirmed the Update stamp
on the phone reads "f3.51 patch 43". The delivery log's last row agrees:
`| 2026-08-05 09:27 UTC | f3.51 | 43 | patch | 0.9.0+15 | [d592eaf2](.../30992325465) |`
(docs/delivery-log.md, last row, PR #328). Mode is `patch`, base APK still
0.9.0+15, no manual install needed. Patch numbers ran 39 through 43 across
this batch (Phase 12 government securities, Phase 13 "Start Your Business
Legally", Phase 14 "BIR Registration and Local Permits", "BIR Setup for New
Businesses", Phase 15 "Permits, People, and Compliance") with nothing
missing between them, so no unrecorded patch slipped through. That is the
good case at the top level, worth saying plainly: the phone, the delivery
log, and origin/main all agree, and Phase 15 shipped correctly. As with
session 32, that clean top line sits over two incidents that were both
caught and fixed before the phone ever saw them, which is exactly what these
sessions exist to check for, not to invent.

**Timeline (with evidence).**

- Phase 15's content, "Permits, People, and Compliance" (course id
  `business_permits_and_compliance`, six lessons, PR #328), was committed as
  `30fe8a7` at 08:15:48 UTC, already carrying a real
  legal-compliance-counsel review. That commit's own message names three
  confirmed blockers the review found and fixed before the commit landed: a
  Lesson 2 sequencing error (BIR registration was drafted before barangay
  clearance and the Business Permit; corrected to match how BIR commonly
  asks for the Permit as a supporting document) and two dropped source URLs
  a DILG "barangay clearance integration" circular and a Pag-IBIG employer
  checklist PDF, neither confirmable as real, live pages at those exact
  paths. `git show 30fe8a7 --stat` touches no file matching `main.dart`: the
  stamp was left at `f3.50`, the value Phase "BIR Setup for New Businesses"
  (`0e7549a`) had already delivered as patch 42. `check-stamp-unique.sh`
  correctly reddened the branch check for exactly the reason it exists.

- The fix landed as `f8b7799`, "fix(money-courses): bump stamp and
  re-verify Phase 15 sources", 48 minutes later. Its own message states the
  pattern by name: "the same recurring bug as Phase 11 and Phase 13." Bumped
  the stamp to `f3.51`, then, per this repository's own rule (CLAUDE.md,
  added session 32, "Money Courses official-source URLs need a real search,
  not just a cite"), independently re-searched all eight of the sources the
  original review had KEPT, not only the two it had already dropped. Seven
  confirmed exact-match by WebSearch (Philippine Business Hub, DTI BNRS FAQ,
  SSS employer guidance, PhilHealth employer registration, FDA, PCAB, DOT).
  The eighth, a DILG-hosted eBOSS circular PDF
  (`dilg.gov.ph/PDF_File/issuances/joint_circulars/dilg-joincircular-2021728_41c62cd45a.pdf`),
  could not be confirmed as a real, indexed page across four separate
  targeted searches, even though the underlying regulation it names (the
  ARTA-DTI-DILG-DICT Joint Memorandum Circular No. 01, Series of 2021,
  mandating an eBOSS in every city and municipality) is real and well
  documented elsewhere. Found and substituted a directly-confirmed
  alternative, the Anti-Red Tape Authority's own hosted copy of the matching
  Memorandum Circular No. 2021-02 at an indexed `arta.gov.ph` path,
  relabeling the agency from DILG to ARTA; the general, unremarkable fact
  that DILG is a party to the eBOSS mandate stays in the lessons' own prose,
  unchanged. Both rounds of this finding are written into the content
  file's own header comment
  (`flutter/lib/content/lessons_business_permits_compliance.dart`, the block
  beginning "Sources:"), so the record travels with the file, not only in
  this row. `docs/qa-log.md` line 110 (the f3.51 row) names exactly what was
  searched and what was found, in the shape this repository's own rule
  requires. Full suite (2503 tests) green, `flutter analyze` 0 issues,
  screenshot harness clean.

- The claim handed to this session was that this is the fourth occurrence of
  the same bug (Phase 11, Phase 13, a related Phase 14 occurrence, and this
  one). Checked against git history rather than repeated on trust, the same
  discipline session 32 applied to a similar handed-down claim about f3.44.
  `git show <commit> --stat | grep main.dart` on each course-authoring
  commit in this batch shows a real, sharper pattern: `ea653a3` (Phase 14,
  "BIR Registration and Local Permits") and `0e7549a` ("BIR Setup for New
  Businesses") each touch `flutter/lib/main.dart` in the SAME commit as
  their content and shipped clean, patches 41 and 42, no follow-up fix
  needed. `536ddd5` (Phase 13, "Start Your Business Legally") and `30fe8a7`
  (Phase 15) touch no file matching `main.dart` at all in their original
  commit, and both needed a same-session follow-up fix commit
  (`b715d3f`, then `f8b7799`) to bump the stamp before they could merge.
  Phase 11's `a2357b7` (session 32) shows the identical shape. So "four
  occurrences" overstates it as a blanket count across every course this
  batch shipped; the confirmed pattern is narrower and more useful than
  that: every commit this session's own turns wrote and pushed directly
  bumped the stamp correctly, every time, and every commit whose own message
  calls itself "pre-authored" (Phase 13's, per `b715d3f`'s own words: "The
  pre-authored Phase 13 content... shipped with the stamp still at f3.47")
  did not, three times now (Phase 11, Phase 13, Phase 15) across two
  calendar-day sessions. Recorded here precisely rather than passed along,
  because an unverified handed-down count is exactly the kind of claim this
  project has already been burned by repeating.

- Every one of those three confirmed instances was caught by
  `check-stamp-unique.sh` before merge and never reached the phone. Zero of
  three shipped a colliding stamp. The cost each time was identical and
  entirely a waste, not a risk: a review and a full test run computed
  against a tree that could never ship as pushed, then a same-session
  follow-up commit to re-earn the same claim against the tree that actually
  would ship.

**Root cause.**

For the stamp: CLAUDE.md's Flutter rebuild rule 2 already says, since
session 32, "Bump it FIRST, before writing the feature, not last after
testing is done." That instruction is written for a live turn to read and
follow WHILE authoring a commit. A commit that arrives already finished,
called "pre-authored" in its own later fix commit's message, was never
authored inside a turn that instruction could reach; there was no "first
step" for the rule to be the first step OF, because by the time this
session's turns saw the content it was already a complete, pushed commit.
This is not the rule failing to hold, it is the rule's honest ceiling
(named as such in session 32: "medium... because it depends on someone
reading it at the right moment") meeting a case where nobody was there to
read it at any moment before the push happened. What produces a
"pre-authored" commit is not documented anywhere in this repository, and
this session's tools cannot observe it directly, only its effect in git
history; that is stated plainly rather than guessed at.

What is NOT a gap: safety. `check-stamp-unique.sh` is a pure, three-input
function of the branch's stamp, the last delivered stamp, and whether the
branch touches `flutter/`, and it has now caught this exact shape of
mistake in one hundred percent of its three confirmed occurrences, with
zero of them reaching a merge, let alone the phone. The problem this session
adds evidence for is pure waste, a repeated round trip, not risk.

For the URL: the legal-compliance-counsel review here was not a rubber
stamp. It is a real, better case than Phase 11's, where the review's own
claimed "zero blockers found" was flatly false. Here the review found and
fixed three genuine problems, including two source URLs it correctly
identified as unconfirmable and dropped, in the same pass, using
apparently the same method (a real search per URL) that later caught the
DILG PDF. And it still let the DILG PDF through as one of the eight it
kept. CLAUDE.md's own rule text already says "independently WebSearch EACH
URL," which literally covers a kept source as much as a newly introduced
one, and it was still not applied with equal rigor to every one of the ten
original citations on the first pass. Nothing in `flutter test` can tell a
correctly-searched URL from an insufficiently-searched one; the only
signal this session has is that a second, independent pass over the SAME
eight sources found a different answer for one of them. That is a judgment
and completeness gap, not a missing rule: the rule already existed, in
writing, and covered this exact case in its own wording, and a real review
still did not apply it exhaustively to every kept source on the first
pass. No machine in this repository can observe whether a search was
actually run, how many queries it used, or whether its result was read
correctly; that has to be said plainly rather than answered with an
invented check.

**Lessons, each with its guard and the guard's strength.**

1. A commit that arrives "pre-authored," already finished and pushed
   before any of this session's own turns reach it, is structurally
   outside the reach of a CLAUDE.md rule written to be read and followed
   DURING authoring (rule 2's "bump it first"). That rule holds every time
   authoring happens inside a turn (`ea653a3`, `0e7549a`, both clean) and
   has now not held three times when it does not (`a2357b7`, `536ddd5`,
   `30fe8a7`). GUARD, already at its ceiling as a CLAUDE.md rule and
   correctly ranked medium in session 32; no stronger version of that same
   kind of guard exists, because the failure mode is specifically the
   absence of a moment for anyone to read it. The genuinely stronger,
   still-untried option: a repository-tracked git pre-push hook
   (`core.hooksPath` pointed at a committed `.githooks/` directory) running
   the same three-input comparison `check-stamp-unique.sh` already runs in
   CI, so a push touching `flutter/` with a colliding stamp is refused
   locally, before it ever reaches GitHub, regardless of how the commit was
   authored or by what process. This is offered as a real, buildable
   STRONG guard (it observes the same three inputs CI already does, just
   earlier), with one honest limit stated up front: git hooks are local to
   a checkout, GitHub does not run server-side pre-receive hooks on a
   standard repository, so this only fires if whatever process pushes these
   commits is using a checkout with the hook enabled, which this session
   cannot verify or control. It would reduce the round trip, not replace
   CI, which stays the unconditional backstop either way. Not built this
   session; named as a concrete, scoped recommendation.

2. `check-stamp-unique.sh` itself needs no new guard. It is not the gap.
   Three for three, it caught this exact mistake before merge, every time,
   with zero phone impact. Naming that plainly, the same way session 32
   named it sufficient for the safety half of this same lesson, so a future
   session does not spend effort strengthening the one piece of this that
   is already working.

3. A review that correctly finds and fixes several real problems in one
   pass can still leave one instance of the exact same problem class
   unfound in that same pass, even when the rule already in force ("each
   URL") literally covers it. This is a completeness gap in how a review
   pass decides it is done, not a missing instruction; CLAUDE.md's Money
   Courses URL rule already said "each URL" before this incident and that
   wording did not by itself make the first pass exhaustive. GUARD, stated
   honestly as a judgment gap first: no machine in this repository can
   observe whether a search was actually run for a given URL, or how
   carefully its result was read, so the strongest available guard here is
   NOT "add a check," it is the practice this session's own fix already
   performed and that CLAUDE.md should now name directly, a MEDIUM
   documentation guard: add one sentence to the existing Money Courses URL
   rule in CLAUDE.md, making explicit that when a course's source list is
   touched again for any reason (a fix, a follow-up, a later phase reusing
   a citation), the re-search covers every currently-kept source in that
   course, not only the one being changed, the same way f3.51's own fix
   re-searched all eight rather than only the two already known to have
   been dropped once before. A narrower, real machine idea was considered
   and is offered, not built, because it is a genuine (if partial) checkable
   fact: require the qa-log row for any stamp touching a Money Courses
   content file to state a coverage count in the "N of M sources" shape
   this session's own f3.51 row already used voluntarily, and have a test
   (extending `flutter/test/qa_record_test.dart`, or a sibling file) count
   the actual `canonicalUrl:` declarations in the touched content file and
   fail if the qa-log row's stated M does not match. This cannot verify a
   search was any good, only that a review's own account of its scope was
   not silently smaller than the source list it was reviewing; offered as a
   real but narrow guard, not a substitute for lesson 3's judgment gap.

**What went well, credited honestly.** The URL catch is a second real win
for the rule session 32 wrote down, not a new problem to be alarmed about:
a source that survived a genuine, largely-correct legal review still got
caught before it reached the phone, because this repository's own rule
required an independent second look and that second look was actually run.
And the stamp collision, again, cost nothing beyond a wasted cycle; the
safety guard that exists did its one job a third confirmed time.

**CLAUDE.md factual re-check (done as a step, not a favour).**
`flutter/lib/main.dart` line 33 still holds the `updateStamp` constant, as
CLAUDE.md rule 2 says. `.github/workflows/flutter-check.yml` line 167 still
invokes `.github/scripts/check-stamp-unique.sh "$BRANCH" "$DELIVERED"
"$TOUCHES"`, and the script's own logic (read this session) still matches
CLAUDE.md's description exactly: it exits 1 only when a branch touches
`flutter/` and its stamp equals the last delivered row. The Money Courses
URL rule ("independently WebSearch each URL... before governance.reviewStatus
is set to verified") still names a real field:
`flutter/lib/content/lesson_model.dart` line 139 declares `reviewStatus` on
every lesson. No stale path or false claim found in either section this
session touched.

**Open lessons carried forward.**
- From session 32: the deleted-branch recovery step is now written into
  CLAUDE.md's Development workflow rule 1 (confirmed present in the copy
  read this session), so that lesson is closed, not open. The "bump first"
  sentence in rule 2 is also present, confirmed this session, and lesson 1
  above is the finding that its ceiling is real, not a claim that it is
  missing.
- From session 31 and earlier (typography render diffs, the WIP-label
  habit, the 7 exempted calculator screens, the 320dp readability question,
  the stale `goals.dart` allowlist entry, the prove-fail marker-file
  sharpening, the fixture-through-the-writer shape test, the five Pan-plan
  follow-ups, the 60-day cashflow shot): untouched by this session's work,
  which was Money Courses content and the stamp guard, not typography,
  icons, or Pan. Carried forward without new evidence either way.
- New, narrow and explicit: whether a repository-tracked pre-push hook
  (lesson 1's stronger option) would actually be honored by whatever
  process produces a "pre-authored" course commit is unverifiable from
  this session's tools. A future session with visibility into that process
  could settle it; until then it is offered as a recommendation, not a
  built or proven guard.

**For the founder, over lunch.** f3.51, patch 43, is live on your phone,
and it is correct: "Permits, People, and Compliance," the fourth course
under Build Your Business. Two things happened underneath that clean
result, and neither one reached you wrong.

First, the same small bug happened a third time this same day: a course's
content arrived already fully written, but the little build number on your
phone (like f3.50) was not updated to a new one before it got pushed. Think
of that number as a receipt number again, two different receipts must never
share one. Our safety check, the same one from two sessions ago, caught it
before anything merged, every single time it has happened, three times now
with zero exceptions. Nothing wrong ever reached your phone from this. The
real cost is wasted effort: a whole review and test run has to happen twice
because the first one was against content that could never ship as pushed.
I looked closely at exactly which commits had this problem and found the
pattern is narrower than I was first told, it only happens to content that
arrives already finished rather than written turn by turn, which is a more
useful and more honest fact than a vague repeat count.

Second, and the better story: our legal review of this course found and
fixed three real problems on its own, including two wrong website links, a
genuinely good pass. And it still missed an eighth link, a government PDF
that could not actually be found anywhere when searched for real, even
though the law it describes is completely real. Our separate rule, the one
that requires an independent search of every source before we trust it,
caught that eighth one and I replaced it with a link that is directly
confirmed to exist. That rule has now caught a real problem twice in a row.

What makes each of these hard to repeat the same way. The build-number
problem has a strong, working machine behind it that catches it every
time before your phone ever sees it; if that check were ever removed, a
duplicate number could ship for real, which is the actual danger it
prevents, not the annoyance of catching it late. The missing-link problem
has no full machine behind it, because nothing in our sandbox can browse
the real internet to check a government link on its own; the defense is a
person, or an assistant acting like one, actually running the search
instead of trusting a citation, which is weaker and depends on someone
choosing to do it every time. I am recommending, not building today, one
new idea that could make the build-number problem catch itself even
earlier, before a push ever leaves the machine that made it, rather than
after; that is a suggestion for the next round of work, named clearly so
it does not get lost.

**Addendum, same day.** Both recommendations above were built the same
session this entry was written, right after it, not deferred: the one
CLAUDE.md sentence for lesson 3 (Money Courses URL rule now says explicitly
that "each URL" means every currently-kept source on any re-touch, not only
the one being changed) and lesson 1's pre-push hook
(`.githooks/pre-push`, enabled per checkout via
`git config core.hooksPath .githooks`). The hook was proven both ways before
being trusted, per this repository's own "prove a new test can fail" rule:
run directly against a deliberate, throwaway flutter/ change left at the
already-delivered stamp, it exited 1 and named the exact collision; bumped
to a new stamp, the same throwaway change made it exit 0. The honest limit
from lesson 1 stands unchanged: this only protects a checkout that has
opted in, and CI remains the real backstop for every other one, including
whatever process produces a "pre-authored" commit.

---

## 2026-08-05, session 32: f3.46 shipped clean, a stamp collision caught pre-merge exactly as designed, and a fabricated government URL caught by a review that was actually run

**What we believed / What was true.** The founder confirmed the Update stamp
on the phone reads "f3.46 patch 38". The delivery log's last row agrees:
`| 2026-08-05 01:36 UTC | f3.46 | 38 | patch | 0.9.0+15 | [32ccb5ca] |`
(docs/delivery-log.md, last row, PR #322, publisher run 30966134435). Mode is
`patch`, base APK still 0.9.0+15, no manual install needed or claimed. The
row before it, f3.45 patch 37, matches too
(`0dc8de7a`, PR #321). Patch numbers ran 36, 37, 38 with nothing between, so
no unrecorded patch slipped through this batch. This is the good case at the
top level: the phone, the delivery log, and origin/main all agree, and the
batch (two full Money Courses phases, Phase 10 "SSS & PhilHealth Essentials"
and Phase 11 "Pag-IBIG Savings & Housing") shipped correctly. That is worth
saying plainly before anything else, because a clean patch is a real outcome,
not a failure to find problems.

Underneath that clean top line sit two real incidents, both already resolved
before merge, and both worth examining precisely because neither reached the
phone wrong. Ground truth for each is git history on this repo (verified this
session with `git log`, `git show`, and direct file reads), not a chat
recollection.

**Timeline (with evidence).**

- Phase 9 "Insurance Decoded" shipped clean as f3.44 patch 36, PR #320,
  merge commit `0d208c3`. Its content commit `cb3941d` bumped the stamp
  (`f3.43` to `f3.44`) in the SAME commit as the content, with no follow-up
  fix commit anywhere in the merged history (`git log --oneline
  cb3941d~1..0d208c3` shows exactly one commit). This matters for the record:
  the task brief that opened this session characterized "the f3.44 Insurance
  Decoded stamp collision" as an earlier, already-caught instance of the same
  gap this session hit again on f3.46. This session checked that claim
  against `git show cb3941d -- flutter/lib/main.dart` and found no collision
  there: the stamp bump landed correctly on the first commit, same as Phase
  10 (`bc8547d`, `f3.44` to `f3.45`, also a single clean commit, PR #321,
  merge `0dc8de7`). No GitHub Actions run log was reachable this session (no
  network to the GitHub API in this sandbox: `curl` to
  `api.github.com/repos/.../pulls/320/commits` returned "GitHub access is not
  enabled for this session"), so a CI-only near-miss on f3.44 that never left
  a commit-history trace cannot be ruled out from here. What the evidence DOES
  support: f3.46 (below) is the one clearly documented stamp collision in this
  batch, and stating it as "the second time" overstated a claim this session
  could not verify. Recorded here rather than silently repeated, per the
  standing rule that an unverified claim is worse than an open question, and
  because that rule applies to a claim handed to this session exactly as much
  as to any other.

- Between Phase 9 finishing and Phase 10's shipping flow starting, this
  session's assigned branch, `claude/salapify-model-routing-es6yb4`, had
  already been merged to main via PR #320, and GitHub's post-merge branch
  cleanup had deleted the remote ref. `git fetch origin
  claude/salapify-model-routing-es6yb4` failed with "couldn't find remote
  ref". The recovery, `git checkout -B claude/salapify-model-routing-es6yb4
  origin/main`, preserved Phase 10's uncommitted working-tree changes
  cleanly, since origin/main was only the one delivery-log commit
  (`4e657e8`, "Delivery: f3.44, patch 36") ahead of the branch's last known
  commit. Confirmed this session: the branch is currently at `8094e36`, up to
  date with origin, working tree clean, and its history
  (`bc8547d` sitting directly on `4e657e8` sitting directly on `0d208c3`)
  matches exactly what that recovery would produce. No data was lost and
  nothing shipped twice. The cost was a diagnostic detour: several tool calls
  spent establishing the stale-ref state before the fix, which is itself
  already the documented fix, was applied.

- Phase 11 "Pag-IBIG Savings & Housing" content, file
  `flutter/lib/content/lessons_pagibig.dart` plus its test file and the
  `learning_paths.dart` registration, was committed as `a2357b7` at
  00:27:40 UTC on Aug 5, already pushed to the branch with PR #322 already
  open, before this session's active turn reached it. `git show a2357b7 --
  flutter/lib/main.dart` returns nothing: that commit touched no file under
  `flutter/lib/main.dart`'s stamp constant at all, and the stamp still read
  `f3.45`, the stamp f3.45 patch 37 had already delivered. The branch's own
  "Flutter check" CI run failed on `.github/scripts/check-stamp-unique.sh`,
  which compares the branch's own stamp against the last row in
  `docs/delivery-log.md` on origin/main and exits 1 on an exact match when
  the branch touches `flutter/`. This is the guard built after session 25
  (`docs/lunch-and-learn.md` session 25; the script's own header and its
  failure message both cite it by name) doing exactly the job it was built
  for: catching the collision on the PR, before merge, before the phone ever
  saw it.

- The fix landed as `8094e36`, "Phase 11 follow-up: fix two wrong Pag-IBIG
  source URLs, bump stamp to f3.46", 44 minutes after `a2357b7`. Its own
  commit message states plainly: "Bumped updateStamp to f3.46 (the branch
  previously shipped as-is would have collided with the already-delivered
  f3.45 stamp, caught by the stamp-uniqueness CI guard)." That fix commit
  also carried the two legal-compliance-counsel corrections (next item), and
  it required a genuinely fresh `flutter test` run, because the working-tree
  state that `a2357b7`'s own commit message implicitly stood behind
  (registration, isolation, and content tests, all green) was no longer the
  state being shipped once the stamp and the two URLs changed. The qa-log row
  for f3.46 (`docs/qa-log.md` line 105) records this directly: "the sole
  failure on first run was this exact QA row not existing yet, the guard
  working as designed; green after this row was added." Nothing shipped on
  an unverified claim; a second, real run backed the second, real commit.

- The review that caught the URLs. `a2357b7`'s own commit message says
  "Reviewed by the legal-compliance-counsel agent
  (investment-suitability-reviewer does not exist in this repo); zero
  blockers found". The qa-log row for the SAME content, written after the
  review that actually ran in this session, records "1 MUST FIX (a wrong
  official source URL) and 1 SHOULD FIX (an unconfirmed calculator URL)".
  Those two statements describe the same six lessons and cannot both be
  complete: the first draft's own claimed review missed a fabricated URL that
  a second, real pass caught. The MUST FIX: the Virtual Pag-IBIG source URL
  the first draft cited, `https://yourvirtualpagibig.pagibigfund.gov.ph/`
  (`lessons_pagibig.dart` line 96 in `a2357b7`), never appeared in any
  independent WebSearch result across six targeted searches, a strong signal
  it was fabricated or wrong rather than merely unindexed. The real portal,
  confirmed independently across a Philippine Information Agency feature, the
  Virtual Pag-IBIG Google Play and App Store listings, and several how-to
  guides, is `https://www.pagibigfundservices.com/virtualpagibig/`, an
  entirely different host. The SHOULD FIX, same pattern at smaller scale: the
  amortization calculator URL was corrected from
  `pagibigfund.gov.ph/amort/` to the confirmed
  `pagibigfund.gov.ph/AA/calc.aspx`, the same host, a different path. Both
  fixes and the reasoning behind them are written into the lesson file's own
  header comment (`lessons_pagibig.dart` lines 66-77 in `8094e36`), so the
  record of the correction travels with the content, not only in this row.

**Root cause.**

For the stale branch: structural, not a missed signal. GitHub deletes a
branch on merge by repository policy, and nothing in this session's tools
watches for that between turns; the first observable symptom of a branch
having been merged out from under a session is the next `git fetch` against
it failing. The recovery procedure that resolved it is real and correct (it
is effectively what this project's own onboarding for a per-session working
branch already implies: restart from origin/main, which is always at least as
new), but it lives in this session's own operating instructions, not in this
repository. `grep`ing CLAUDE.md for "already been merged", "restart your
designated branch", or "couldn't find remote ref" in
`/home/user/Salapify/CLAUDE.md` found nothing: CLAUDE.md's "Development
workflow" section (rule 1, line 335) says each session gets its own branch,
but nowhere names what to do when that branch is discovered already merged.
That is a silence, not a false claim, the same category session 25 found once
before.

For the stamp collision: the same structural fact CLAUDE.md rule 1 already
names in the Flutter rebuild section, "there is no path that merges flutter/
to main without shipping ... every merge to main that touches flutter/
therefore needs a unique updateStamp, with no exception." The rule is
correctly written. What went missing was not the rule but its ORDERING inside
the work: the stamp bump is written as the LAST step of a shipping flow (bump
stamp, then commit, then push), so a commit authored and pushed before that
last step is finished is a commit with an already-stale stamp by
construction, and a whole verification pass (format, analyze, the full suite)
attaches to a tree that is not the one that will actually ship. The guard
that exists (`check-stamp-unique.sh`) catches this at the border, pre-merge,
every time; it did here. What has no guard is the wasted cycle: a full
`flutter test` run whose result becomes stale the moment the stamp changes
underneath it, forcing a second full run to re-earn the claim the first one
already made once.

For the URL: the commit's own claimed review ("zero blockers found") was
either not run against these six lessons for real, or was run without
independent search verification of the cited URLs, since a subdomain that
"does not appear anywhere in independent search results" (the fixed file's
own header comment) is not something a real WebSearch-backed pass would wave
through silently. Structurally, this class of defect, a syntactically
well-formed but factually wrong government URL, cannot be caught by anything
in `flutter test`: `lessons_pagibig_content_test.dart` (lines 220-238)
asserts every source is a well-formed HTTPS URI with a non-empty agency and
title, `expect(uri != null && uri.scheme == 'https', isTrue)`, and its
later domain assertions (lines 276-281, 479) assert the URL equals whatever
the lesson file itself declares, which is tautological against a fabricated
value the file declares with full confidence. The only channel that can
verify a URL is REAL is a live network check, and this environment's own
`WebFetch` returns a uniform 403 on `pagibigfund.gov.ph` (confirmed in both
this row and the earlier f3.44 and f3.45 rows), so `WebSearch` cross-
verification is the only channel that currently exists at all, and it
depends entirely on a human or a reviewing agent choosing to run it for real.

**What went well, credited honestly.** The legal-compliance-counsel review of
the Pag-IBIG content is a genuine win and belongs named as one, not folded
into the incident list above. Content that had already passed its own
self-described verification, a claimed prior legal-compliance-counsel pass
with "zero blockers found", still carried a fabricated government URL that
only surfaced when the review was run for real in this session: six targeted
WebSearch queries, a clear absence-of-evidence conclusion, and independent
confirmation of the real address from four separate kinds of sources before
the fix was trusted. This is exactly the "prove before trusting" discipline
CLAUDE.md asks for elsewhere applied to a review finding rather than a test.
And the pre-merge stamp guard is a second genuine win: `check-stamp-unique.sh`
did not just exist, it fired on a real collision this session produced, gave
a clear message pointing straight at the fix ("Bump updateStamp in
flutter/lib/main.dart... See docs/lunch-and-learn.md session 25"), and the
collision never reached a merge, let alone the phone. Session 25 offered this
exact check as an "optional strengthening, not built" three weeks ago; it got
built, and it just did its one job under real conditions for the first time
this session can confirm with direct evidence.

**Lessons, each with its guard and the guard's strength.**

1. A session's assigned branch can be merged and deleted mid-session by a
   mechanism nothing in this repository watches, and the fix, restart from
   origin/main, exists but is not written down anywhere in this repository.
   GUARD, MEDIUM strength, not yet built: add one short paragraph to
   CLAUDE.md's "Development workflow" rule 1, right after "each session gets
   its own branch now": "If `git fetch origin <your branch>` ever fails with
   'couldn't find remote ref', that branch was already merged and GitHub
   deleted it on merge. Do not treat this as an error to work around: restart
   it with `git checkout -B <your branch> origin/main`, which is always safe
   because origin/main is never older than the branch's last delivered
   commit, and any uncommitted working-tree changes apply cleanly on top."
   This is medium, a documented procedure, not an automated check, because
   nothing in the repository can observe a branch's remote-deletion event
   between turns; naming it in writing turns a diagnostic detour into a
   known, one-line playbook the next time it happens, which is the honest
   ceiling available.

2. The stamp bump is written as the last step of a shipping flow, so a
   commit finished and pushed before that last step is a commit whose own
   verification claims are stale by construction, and the existing pre-merge
   guard (`check-stamp-unique.sh`) catches the SAFETY half of this (a
   collision never merges) but not the WASTE half (a full test run has to be
   repeated to re-earn a claim the first run already made once, against a
   tree that never shipped). GUARD, MEDIUM strength, not yet built: add one
   sentence to CLAUDE.md's Flutter rebuild rule 2, next to the existing "bump
   the updateStamp constant... on every push" instruction: "Bump it FIRST,
   before writing the feature, not last after testing is done; write the
   one-line stamp text as the opening move of any commit that touches
   flutter/, the same way the qa-log row is written as the closing move." A
   full automatic bump was considered and rejected as the strongest option:
   the stamp is a founder-facing sentence, not a version counter (CLAUDE.md
   rule 2 is explicit that the words matter and belong in the commit, not a
   generated string), so a machine cannot author it, only remind that it is
   due. The strong half of this lesson is not new: `check-stamp-unique.sh` is
   already the correct backstop and needs no further mechanism; it is named
   here only to say plainly that it is sufficient for safety and that no new
   guard is warranted on that half.

3. A syntactically well-formed government URL a lesson cites can still be
   fabricated, and nothing in `flutter test` can tell the difference, because
   every test that touches a source URL asserts against the lesson file's own
   declared constant (`lessons_pagibig_content_test.dart` lines 220-238,
   276-281, 479), never against the live internet, and the only channel that
   CAN check a URL is real, WebSearch, is blocked from being a `flutter test`
   assertion by the same sandboxed-network reality that blocks `WebFetch` to
   `pagibigfund.gov.ph` outright. GUARD, MEDIUM strength (a documented
   procedure, the honest ceiling given the network constraint): add to
   CLAUDE.md, near the legal-compliance-counsel guidance, that any Money
   Courses lesson introducing or changing an official-source `canonicalUrl`
   on a government domain requires the reviewing agent to independently
   WebSearch each URL, not merely cite or WebFetch it, and that the qa-log row
   must name what was searched and what confirmed or contradicted it, the way
   f3.46's row already does. This does not invent new process, it writes down
   what f3.46 already did well so the next content phase does it as a
   requirement rather than a good habit that happened to be followed. A
   narrower, partial automated idea was considered and is offered, not built:
   a test asserting every `canonicalUrl`'s host belongs to a small,
   previously-confirmed allowlist would have caught the Virtual Pag-IBIG fix
   (a genuine cross-host change, `pagibigfund.gov.ph` subdomain to
   `pagibigfundservices.com`) but would NOT have caught the amortization
   calculator fix (same host, different path), and it could only ever flag a
   REGRESSION to a previously-known-wrong host, not the first-time
   fabrication this session actually caught, since nobody would know to
   pre-populate `pagibigfundservices.com` into an allowlist before the first
   correct citation existed. Named honestly as weaker than it sounds, not
   built.

**CLAUDE.md factual re-check (done as a step, not a favour).** Checked this
session: `.github/scripts/check-stamp-unique.sh` exists exactly where
CLAUDE.md's Flutter rebuild rule 1 says it does, and its logic matches the
description (fails only when a branch touches `flutter/` and its stamp equals
the last delivered row); `flutter-preview.yml`'s "Record what actually
shipped" step (line 201, the "fails AFTER the publish on purpose" comment at
line 221, the exact collision message at line 227) still matches the
backstop CLAUDE.md and session 25 describe. `flutter/lib/main.dart` line 33
still holds the `updateStamp` constant. `docs/delivery-log.md` still opens
"What actually reached the phone, written by the publisher", no notes column,
matching CLAUDE.md's description exactly. The one gap found, not a false
claim but a silence exactly like the one session 25 found: CLAUDE.md's
"Development workflow" rule 1 says each session gets its own branch but names
no recovery step for a branch discovered already merged mid-session; lesson 1
above is that gap's guard.

**Open lessons carried forward.**
- From session 31: the same-environment before/after render diff for
  presentation refactors is still named, not built; the WIP-label-is-
  permanent rule is a standing habit, not a machine; the 7 calculator screens
  the typography migration touched are still exempted from the readability
  sweep rather than driven through it.
- From session 30 and earlier: the 320dp readability question, the stale
  goals.dart allowlist entry in icon_system_test.dart, and the prove-fail
  marker-file sharpening are all still open, untouched by this session's
  work (this batch was Money Courses content, not typography or icons).
- From session 29: the fixture-through-the-writer shape test is not built,
  the five Pan-plan follow-ups have no backlog home, and the 60-day cashflow
  shot still captures without asserting its view.
- New this session, narrow and explicit: whether a CI-only stamp near-miss
  ever happened on f3.44 (Phase 9, Insurance Decoded) cannot be settled from
  this session's tools, since no GitHub Actions log was reachable (no GitHub
  API access in this sandbox). If a future session gets that access, checking
  PR #320's check runs would close this rather than leave it as an
  uncorroborated claim either way.

**For the founder, over lunch.** Two new lessons shipped and you saw them:
f3.46, patch 38, Pag-IBIG Savings and Housing, following f3.45 for SSS and
PhilHealth. Both are live. Underneath that clean result, two things happened
that are worth knowing about because they show two of our safety checks doing
real work, not just sitting there.

First: partway through, my working branch, the copy of the code I was
actively editing, had already been merged into the main line by an earlier
piece of work and GitHub had cleaned up and deleted it, the way it always
does after a merge. My next command to fetch that branch failed. This is not
dangerous, it happens by design, and the fix is simple: start a fresh copy
from the main line, which is always caught up. That is exactly what I did,
and nothing was lost. The only cost was a few extra minutes figuring out what
had happened before applying a fix that was already known. I am writing that
fix down in our rules now so the next time this happens it takes no
figuring out at all.

Second, and more important: content for the Pag-IBIG lesson got written and
pushed with a "build name" (the short number like f3.46) that was already
used by the PREVIOUS lesson. Think of the build name like a receipt number,
two different receipts must never share one number, or you cannot tell them
apart later. Our safety check caught that duplicate number before anything
merged, the same kind of check that caught a similar problem once before,
back in July. It failed loudly, pointed at exactly what to fix, and nothing
reached your phone with the wrong number on it. I fixed it, gave the new
content its own correct number, f3.46, and re-ran every test before shipping
it for real.

Third, the best part: our legal review step read through the new Pag-IBIG
lesson and found that one of the website links it pointed to, the address for
the Virtual Pag-IBIG member portal, was wrong. Not a small typo, a completely
different web address than the real one. That link would have sent you, or
anyone reading the lesson, to a page that does not really belong to Pag-IBIG.
I ran a real search to confirm the correct address from four separate,
trustworthy places, fixed the link, and fixed a second, smaller wrong link
the same way, before any of it shipped. This is the review step working
exactly the way it is supposed to: catching a wrong fact before it reaches
you, not after.

What makes each of these hard to repeat differently. The branch problem now
has a written instruction, which is a reminder, not a machine, so it is only
as strong as someone reading it at the right moment; if it is ever deleted
from our rules, we go back to losing a few minutes rediscovering the same fix
each time it happens, which is a small, recoverable cost. The build-name
duplicate has a real machine behind it, the pre-merge check, which is strong
because it works whether or not anyone is watching; if that check were ever
removed, a duplicate build name could merge, and the guarantee that one
number always means one specific build would be gone, the exact danger a
safety check like this exists to prevent. The wrong web link has no machine
behind it at all, because nothing in this sandbox can reach the real
government website to check a link is genuine on its own; the only real
defense is a person, or an assistant acting like one, choosing to search and
verify before shipping, every time content cites an outside source. That is
the weakest kind of guard we have, a habit rather than a rule or a machine,
and I am saying so plainly rather than pretending it is stronger than it is.

---

## 2026-08-02, session 31: a clean typography patch, a QA review cut short, and a WIP label stranded in main

**What we believed / What was true.** We believed f3.18 shipped the typography
centralization as a Shorebird patch over the air, and for the first time in
three sessions the ground truth is the PHONE, not just the delivery row: the
founder confirmed the Update stamp reads "f3.18 patch 13". The delivery row
agrees:
`| 2026-08-02 05:22 UTC | f3.18 | 13 | patch | 0.9.0+15 | d471b448 |`
(docs/delivery-log.md, last row, publisher run 30733553981). Mode is `patch`,
base APK still 0.9.0+15, so no manual install was needed and none was claimed.
Patch numbers ran 12 then 13 with nothing between, so no unrecorded patch
slipped through. The stamp on origin/main (flutter/lib/main.dart line 33) is
f3.18, matching the row and the phone. This is the good case, and it is worth
saying plainly: the automated harness, the delivery log, and the phone all
told the same story, and no defect was reported. A clean patch is a real
outcome, not a failure to find problems.

For plain terms used below: a "Shorebird patch" is a Dart-only update the
installed app pulls over the air on reopen, no app-store install. A "semantic
type role" means naming text by its JOB (title, body, caption, a money amount)
in one file, so the whole app's type is changed from one place instead of at
739 scattered sites. "Prove-fail" is the standing rule that a new test must be
shown to go red against deliberately broken code before it is trusted.

**Timeline (with evidence).**
- The change. f3.18 centralized the Flutter app's typography into
  flutter/lib/typography.dart (263 new lines), mirroring the React Native
  scale in mobile/theme.js (caption 12, small 13, body 15, subtitle 17,
  title 22, big 28, huge 34, display 42, verified this session against
  mobile/theme.js lines 438 to 445) onto the shipped Plus Jakarta Sans face.
  About 739 hardcoded TextStyle sites across 63 files were migrated to
  semantic roles by nine parallel agents; the ten synthetic FontWeight.w500
  uses were fixed to real medium (w600), the weight Jakarta actually ships.
  The merge diff is 67 files, +1596 and -2986 (git show d471b448 --stat).
- The new guard, proven fail-first. flutter/test/typography_test.dart (171
  lines) pins the eight RN sizes, verifies every weight maps to a real Jakarta
  font file, and scans all of lib for synthetic weights. The qa-log records it
  "listed all ten w500 sites before the migration removed them", which is the
  fail-first proof done the right way: the test was watched going red against
  the real defect before it was trusted.
- The QA row, honest about a truncated review (docs/qa-log.md line 77, f3.18).
  Verdict Pass, 0 must-fix. The row states plainly that "a diff-level review
  of the migrated call sites was partially run (session limit)": a
  qa/diff-review agent launched to read the 739 migrated sites terminated on
  "You've hit your session limit", after capturing one partial finding (the
  Text.rich base-color cases are non-issues because child spans set their own
  color). The machine half of QA ran in full: flutter analyze clean, the full
  suite (reported 1526 green), the screen_readability sweep at 1.0x and 1.5x,
  and the render harness. Dark-first screenshots of Home, Insights, Utang, and
  Accounts were reviewed.
- A WIP checkpoint became permanent. Commit c9ee0d1 "WIP: centralize
  typography (migration in progress)" was pushed to the branch early for
  durability. At finalize time an amend plus force-with-lease was BLOCKED by
  the Claude Code auto-mode classifier, so the finish landed as a
  fast-forward commit on top (5b970ff, the QA row) instead of rewriting the
  WIP. Result, verified this session: `git merge-base --is-ancestor c9ee0d1
  origin/main` returns true. Main history now permanently carries a commit
  that says "migration in progress" for work that is complete and shipped.
- The task collided with a documented decision, and the collision was raised,
  not guessed. The brief said "match RN typography, use RN as source of truth,
  do not assume the font" while Flutter deliberately ships Jakarta and RN uses
  the system font (a founder decision recorded in CLAUDE.md). This was resolved
  by asking the founder up front (keep Jakarta, mirror RN's size and weight
  SCALE), not by silently picking one reading. That is the behaviour the rules
  ask for, and it is recorded here as a thing done right.
- Delivery clean. Merge d471b448 (PR #295, 13:07 +0800), publisher wrote the
  row itself, patch 13, and the founder then confirmed it on the phone.

**Root cause.** There is no delivery gap to root-cause; the patch behaved. Two
process items are worth the "why".

For the truncated QA review: the safety of a 739-site mechanical refactor was
argued as "renders preserved 1:1 by construction", and the check meant to
VERIFY that claim site by site was the human diff review, which an agent
session limit cut short.

This session's first draft of that finding was itself wrong, and worth
recording precisely because it repeats the failure mode named in
screen_readability_test.dart's own history (CLAUDE.md once said "every
screen" while the swept set held ten of fifty). The draft said the sweep
"imports 27 of 54 lib/screens files, so half the app has no automated
overflow net", framed as a silent, undiscovered gap. It is neither silent nor
undiscovered: screen_readability_test.dart already carries the
assert-you-saw-them-all guard the draft called "not yet built" (its own test,
"every screen file is either swept or exempted for a stated reason", iterates
lib/screens on disk and fails if any file is neither swept nor named in the
exempt map with a reason). Every one of the 27 non-swept files IS named there,
with a written, arguable reason (modal sheet opened mid-flow, input-driven
form that only shows something on a cold pump once typed into, first-run
screen needing an empty store, and so on), and the test was re-run this
session and passed clean: nothing in lib/screens is unaccounted for. The real,
narrower fact is that of those 27 reasoned exemptions, 7 are the calculators
this session's migration touched, and the file's own comment already names
driving them with typed input as "the next thing this file should grow". For
those 7 files specifically, the human diff review was this session's only
net, and it died. It did not bite, confirmed by the phone, but the exposure on
those 7 was real. Overstating that to "half the app, silently" would have
planted a false claim in this very file about the thing this file exists to
prevent.

For the stranded WIP label: in this environment force-push is blocked by the
auto-mode classifier, so a commit, once pushed, is effectively permanent. A
placeholder message written on the assumption it would be amended away never
got its amend, and there is no path to fix it now without rewriting shared
history.

**Lessons, each with its guard and the guard's strength.**

1. When a large mechanical refactor's whole safety case is "renders unchanged",
   the check that proves it must not be the one that can run out of session.
   The honest disclosure in the qa-log row is the RIGHT behaviour and strictly
   better than a false "fully reviewed", but disclosure is a NOTE, not a guard:
   it records that a check did not finish, it does not make the check finish.
   The assert-you-saw-them-all accounting in screen_readability_test.dart
   ALREADY EXISTS and already runs on every push (confirmed green this session
   after the migration), so the gap is not "which screens are unaccounted for"
   (none are); it is narrower: which reasoned exemptions this session's own
   changes touched. Ranking the real guards:
   - Concrete and NOT yet done: drive the 7 calculator screens (all touched by
     this session's typography migration) through the sweep with typed input,
     moving them from the exempt map to the swept set, exactly as
     screen_readability_test.dart's own comment already names as its next
     growth step. Bounded, and closes the one net this session's changes
     actually lacked.
   - Also available and NOT built: for a presentation-only refactor, a
     SAME-ENVIRONMENT before/after render diff of every touched screen. Run in
     one sandbox on one commit pair, it is deterministic, so it does NOT fall
     foul of the founder's standing ban on blocking CROSS-environment pixel
     checks (that ban was about flake between machines, which this does not
     have). It is the only thing that catches a subtle wrong-role mapping that
     still fits. Medium to strong. Named, not built.
   - Weakest, and what actually held this time on the 7 calculators: the eye
     plus a diff review. It worked here only because the phone came back
     clean, and it is exactly the layer that ran out of session. Do not rely
     on it as the primary net for a refactor this wide.
   Carried OPEN, narrowed to the calculators, with driving them through the
   sweep as the recommended first step.

2. In this environment every pushed commit is permanent, so write the message
   you would be content to see in main forever, on the FIRST push. Force-push
   is blocked by the auto-mode classifier, which is not a bug to route around
   but the standing reality; c9ee0d1 proves a "WIP: migration in progress"
   label now lives in main under shipped work. Guard: a rule, never push a
   checkpoint with a throwaway message (WIP, in progress, fixup, tmp) to a
   branch that reaches main; if you push for durability, push with the real
   message. Strength: weak to medium, a rule, because the harm is a misleading
   history line with no delivery impact, and no machine reads intent. A machine
   version is possible if it recurs (a pre-merge check that reddens when any
   commit in the merged range carries a WIP-shaped message, the same
   shape-matching the destructive-edits hook already does), named here but
   judged not yet worth the weight for a cosmetic cost.

3. When the literal task contradicts a documented decision, ask, do not pick.
   The typography brief said "use RN as source of truth, do not assume the
   font" while CLAUDE.md records Flutter ships Jakarta on purpose; asking the
   founder up front turned a contradiction into a clear instruction (mirror the
   scale, keep the font). Guard: this is already the ethos of the brainstorming
   skill and the "ask before guessing" rules, so no NEW guard is minted; it is
   recorded as a positive so the pattern stays visible. Strength: existing, a
   habit reinforced by example, honestly weak but correctly applied.

4. Positive result, recorded as one. The typography guard was proven fail-first
   before it was trusted, the machine harness (analyze, the full suite, the
   readability sweep at two font scales) agreed with the phone, and the ONE
   intentional visual change (synthetic w500 to real w600) is exactly what the
   qa-log documents. Guard: the standing gates, already enforced by the
   qa-log-row requirement (flutter/test/qa_record_test.dart) and the branch
   check on a real runner. Strength: strong, in place.

**Open lessons carried forward.**
- SETTLED: the f3.17 patch 12 phone confirmation owed from session 30 is now
  closed. The founder confirmed f3.18 patch 13, and because patches ran 12 then
  13 with no gap, a phone showing patch 13 confirms the chain through patch 12.
  Ground truth caught up to the delivery log.
- OPEN, NARROWED: the readability sweep's assert-you-saw-them-all accounting
  already exists and is enforced (confirmed green this session); the 27
  non-swept lib/screens files are each named with a reasoned exemption, not
  silently missing. The real open item is the 7 calculator screens this
  session's migration touched, still exempted as "input-driven; cold pump
  shows an empty form" per the test's own next-growth note (lesson 1).
  Recommended guard is driving those 7 through the sweep with typed input; not
  built.
- NEW and OPEN: the same-environment before/after render diff for presentation
  refactors (lesson 1), named, not built.
- NEW: the WIP-label-is-permanent rule (lesson 2), a rule not a machine.
- STILL OPEN from session 30: the 320dp readability question (nothing automated
  looks at 320dp today), and it now compounds with the coverage gap above,
  since half the screens are not swept at ANY width. The goals.dart allowlist
  entry in icon_system_test.dart is still stale (this session did not touch it;
  typography adds no emoji). The prove-fail marker-file sharpening is still
  named, not built.
- STILL OPEN from session 29: the fixture-through-the-writer shape test is not
  built, the five Pan-plan follow-ups have no backlog home, and the 60-day
  cashflow shot still captures without asserting its view.
- CLAUDE.md factual claims exercised this session all matched. Verified by
  reading the repo, not the rule: flutter-check.yml triggers on `claude/**`
  push and pull_request to main (analyze and test only), flutter-preview.yml
  triggers on push to main with paths `flutter/**` plus its own file (the
  publisher), exactly as rule 1 describes. The eight RN sizes the type work
  leans on match mobile/theme.js to the point. Every path checked exists:
  check-stamp-unique.sh, flutter/shorebird.yaml, update_stamp_test.dart,
  salapify_icon.dart, the destructive-edits hook, screens_shot.dart,
  journeys_test.dart, the journey-tester agent, palette_contrast_test.dart,
  screen_readability_test.dart, test/golden/ui_golden.dart, reports.dart and
  debts.dart, eas-update.yml, and mobile/app/(tabs)/more.js. The delivery
  three-command read produced the real f3.18 row. Not every claim was
  re-audited; the ones this batch exercised held.

---

## 2026-08-02, session 30: a committed break caught twice, and the second clause session 29's rule was missing

**What we believed / What was true.** We believed the Goals redesign plus the
app-wide icon system would ship as f3.17 in one merge, and the delivery log
says it did:
`| 2026-08-01 23:59 UTC | f3.17 | 12 | patch | 0.9.0+15 | e04759b9 |`,
patch 12, a Shorebird patch over the air on the 0.9.0+15 base APK, no manual
install. Honest caveat first, same as session 29's: the founder said
"proceed" right after the delivery report and has NOT confirmed the f3.17
stamp on the phone. Ground truth for this session is therefore the delivery
row, which only the publisher writes and only after shipping, the best
evidence short of the phone itself. The phone check is still owed and sits in
the open lessons. Patch numbers ran 11 then 12 with nothing between, so no
unrecorded patch slipped through. The stamp on origin/main
(flutter/lib/main.dart line 34) is f3.17, matching the row. Every delivery
guard held: unique stamp, qa-log row f3.17 present before the merge
(docs/qa-log.md line 76), merge commit e04759b (PR #292), Flutter check green
on a real runner, publisher wrote the row itself (run 30723951295).

There is no delivery gap. The session's material is pre-merge, and one item
is a genuine incident, not merely a catch: for twenty-nine minutes the BRANCH
carried a committed transfer that destroyed ten percent of every peso moved,
because a milestone commit was made while another actor's deliberate
prove-fail break was live in the shared working tree. It never reached main,
it was found twice independently, and it is exactly the near-miss session 29
wrote a rule about, one clause short.

Plain terms used below. "Prove-fail" is the standing rule that a new test
must be shown to go red against deliberately broken code before it is
trusted; while the red run is pending, the deliberate break sits live in the
working tree. A "milestone commit" is the main session banking a finished
slice of work into the branch. An "allowlist" is a short list of files a
scanning test deliberately skips, each with a written reason.

**Timeline (with evidence).**
- Phase 0, reading before writing. The founder's full spec (redesign Goals,
  establish one icon system) was inspected by three parallel read-only agents
  (goals feature map, app-wide icon audit, design tokens and harness map)
  before any code moved. No lesson, just the record that the work landed on
  what exists, per the enhance-never-regress direction.
- The icon migration, commit cdfc210 (16:29 UTC). 206 raw Icons.* constants
  across 51 files collapsed into the meaning map in
  lib/widgets/salapify_icon.dart via a scripted rewrite plus analyzer
  iterations; test/icon_system_test.dart now holds the perimeter with two
  derived scans, proven fail-first with a planted probe file that both scans
  reported line-exactly (quoted in the commit message). Two meaning
  collisions were surfaced by EXISTING tests, the appearance screen's
  exactly-one-badge test and the period stepper visual, and fixed by giving
  distinct meanings distinct names ('chosen', salapify_icon.dart line 111;
  'previous', line 99). Old guards catching a brand-new change set is those
  guards working.
- The engine and store first, ae026a9 (16:36) and 5d26662 (17:03):
  money/goal_plan.dart with edge-first vectors, prove-fail done on the
  quarter-milestone guard, then the screens.
- THE INCIDENT, 17:09. While the journey-tester agent was mid prove-fail,
  its deliberate 0.9 multiplier planted on transferGoalFunds' credit leg and
  its red run still pending, the main session committed milestone 6347a67.
  The commit captured the live break: git show 6347a67 shows
  flutter/lib/data/store.dart line 965 reading
  `'saved': base + moved * 0.9,`. The committed suite stayed GREEN, because
  the journey that catches the break existed only uncommitted in the working
  tree.
- Found twice, independently, between 17:09 and 17:38. The journey-tester's
  own report named the break and its restore, and the qa-tester, reading
  git show HEAD as part of its pass, found the committed tree destroying
  money with no knowledge of the agent's work. Two lenses converging on one
  defect from different directions is the reason there are two lenses.
- Fixed together, c59cd68 (17:38). The agent's exact restore, already
  sitting in the working tree, and the regression journey landed in one
  commit: store.dart back to the full-amount credit, plus 291 lines in
  journeys_test.dart including the goal-transfer journey with directional
  companions ("the source goal did not fall by exactly what was moved",
  journeys_test.dart near line 1413). The same commit fixed the no-op
  transfer leaving a zero history row; its own diff comment reads "A no-op
  transfer must leave no fingerprints."
- Why it could not have reached the phone even if nobody had noticed: the
  break and its catching journey travel in the same change set, so the NEXT
  push would have carried both and the branch check on a real runner would
  have gone red. The committed-and-uncaught window is exactly the gap
  between milestone commit and next push, and nothing publishes in that
  window.
- The three QA gates found disjoint real problems again (docs/qa-log.md,
  f3.17 row). qa-tester: the committed break, two junk-backup crash classes
  proven by probe, an empty-chip crash, the goals id-integrity gap, the
  no-op zero row, search rendering debt goals as 0 of 0.
  flutter-ux-craftsman: a year-less projection date breaking the trust rule,
  a receipt that could claim unmoved money, a controller wiped by
  StatefulBuilder rebuilds, a 320dp Row overflow, and one genuine
  enhance-never-regress violation, the redesign had quietly lost the old
  screen's downward saved correction, restored via the Adjust sheet.
  journey-tester: two cross-screen journeys, both proven fail-first, plus
  independently spotting the controller-wipe defect.
- A blanket `dart format lib test` reformatted about 122 untouched test
  files and surfaced one latent lint; the churn was reverse-patched out
  before review. Evidence it stayed out: the merged PR diff
  (7d146ef..e04759b) is 65 files, only 13 of them under flutter/test/.
- The sweep's blind spot. screen_readability_test.dart pumps at a fixed
  390dp, so the quarter row's overflow at 320dp was invisible to it; the
  reviewer caught it by arithmetic, not render, and the fix was a Wrap.
  Whether the sweep gains a 320dp pass is weighed below, not decided here.
- Delivery clean: one merge (23:45 UTC), one row (23:59 UTC), patch 12.

**Root cause.** For the incident: a shared working tree has exactly one
state, and a milestone commit snapshots ALL of it, indiscriminately,
including another actor's proof in flight. Nothing in the tree records that
an edit is a deliberate break awaiting its red run, so the commit had no way
to know it was capturing one, and the committed suite was green precisely
because the one test that knew better was not committed. Session 29's clause
("a break you did not make is not yours to fix") addressed the second actor
FIXING; this is the same root wearing the other costume, the second actor
COMMITTING. Rules written one stumble at a time are always one clause short;
the durable statement is about the tree, not the verb: while a prove-fail
break is live, the tree is not in a bankable state for anyone.

For the format churn: a command whose scope was the world, run for a change
whose scope was a feature. For the stale allowlist: an entry whose reason was
temporal ("pending redesign in this same change set") with nothing that
re-checks the reason once the condition resolves; the redesign landed in the
same PR and the entry stayed.

**Lessons, each with its guard and the guard's strength.**

1. Do not commit while any actor's prove-fail break is live in the tree.
   Weighing the three candidate guards honestly:
   - The rule: a milestone commit waits until no agent with lib-write access
     is mid prove-fail. This is now the second clause of session 29's lesson
     4, and it is a rule, weak to medium, for the same stated reason as the
     first clause: nothing in the repository can observe whose uncommitted
     edit a break is, or that a background run is pending.
   - The proposed machine, "before any commit run the full suite and refuse
     on red", is NOT real protection, and saying so matters more than having
     a machine to point at. Run against the committed tree it stays green,
     exactly as it did here, because the catching test is uncommitted by
     construction. Run against the working tree it goes red during every
     legitimate prove-fail window, which is most of them, so it blocks
     correct commits routinely and gets overridden, and an overridden gate
     is worse than no gate. Either variant is theater.
   - The defense that actually worked, and is the real protection:
     prove-fail breaks land TOGETHER with the test that reddens on them
     (c59cd68 carries the restore and the journey in one commit), so a
     captured break cannot travel one push without its own alarm riding
     along, and the branch check on a real runner goes red. Strength: the
     branch-check half is strong, a machine that runs on every push; the
     pairing half is the journey-tester's discipline, a rule, so the
     compound is medium-strong. The qa-tester's git show HEAD read is the
     independent second layer, and it is part of the standing gate.
   A possible strengthening is named but NOT built: an agent mid prove-fail
   could drop a marker file that the commit path checks. That converts the
   rule into something observable, but it depends on the marker being
   written, which is itself a rule. Recorded as an open sharpening, not
   claimed as protection.

2. Format the files you changed, not the world. A blanket
   `dart format lib test` cost a reverse-patch and would have buried a
   65-file review under 122 files of noise. Guard: a rule, stated here, weak
   to medium, and honestly hard to machine, because no checker can know
   which files a change INTENDED to touch. The containment that exists is
   review of the PR diff, which is what caught it.

3. An allowlist entry with a temporal reason needs a machine that notices
   when the reason expires. test/icon_system_test.dart lines 68 to 69 still
   allowlist lib/screens/goals.dart as "pending redesign in this same change
   set" while goals.dart contains zero emoji (verified by scan this
   session), so a future emoji added to goals.dart would pass the perimeter
   silently. Guard, named and buildable but NOT built: make the scan assert
   that every allowlisted file still CONTAINS at least one match, failing
   with "allowlist entry no longer needed, remove it", the same
   assert-you-saw-it-all pattern palette_contrast_test.dart uses. Until
   built: remove the stale goals.dart entry, and this stays an open item.

4. The readability sweep measures at one width, and this batch's one visible
   layout bug lived at another. 390dp is the fixture's width; the quarter
   row overflowed at 320dp and only arithmetic caught it. Open question,
   deliberately not decided in a retro: add a 320dp pass to
   screen_readability_test.dart, at the cost of roughly doubling that
   suite's runtime, or accept that 320dp remains an eye-and-arithmetic
   check. What is recorded is the honest current state: nothing automated
   looks at 320dp today, and one real overflow lived there.

5. Positive result, recorded as one: the three-lens gate found disjoint real
   defects for the third consecutive batch, the icon perimeter, the transfer
   guard, and the quarter-milestone guard were each proven fail-first, and
   two OLD tests (exactly-one-badge, the period stepper visual) caught
   meaning collisions inside a brand-new icon system. Guard: the standing
   gates themselves, already enforced by the qa-log row requirement
   (flutter/test/qa_record_test.dart). Strength: strong, in place.

**Open lessons carried forward.**
- SETTLED 2026-08-02: the founder confirmed patch 12 on the phone
  ("patch 12 already"), which closes the owed check below and confirms the
  chain through patch 11. The delivery row and the phone agree; a clean
  delivery, now with the only proof that counts.
- Superseded by the settle above, kept for the record: founder phone
  confirmation of f3.17 patch 12 was owed. It superseded the f3.16
  confirmation carried from session 29, because a phone showing f3.17
  patch 12 confirms the chain through patch 11.
- NEW: the stale goals.dart allowlist entry in icon_system_test.dart, and
  the self-checking allowlist that would retire the whole class (lesson 3).
- NEW: the 320dp question (lesson 4), open until weighed.
- NEW: the prove-fail marker-file sharpening (lesson 1), named, not built,
  not claimed as protection.
- From session 29, still open: the fixture-through-the-writer machine for
  goals and other user-data shapes is NOT built (no shape test exists;
  goal_store_test.dart builds through store.addGoal in places and hand maps
  elsewhere). The five unrecorded Pan-plan follow-ups did not move into the
  backlog or a test this batch; session 29's entry remains their only
  record. The 60-day cashflow shot still captures without asserting its
  view (screens_shot.dart lines 2168 to 2181: ensureVisible and tap, a
  comment naming the risk, no assertion); the pan-plan half stays done.
- Guards re-checked and standing: check-stamp-unique.sh and both Flutter
  workflows exist with the triggers CLAUDE.md claims, the destructive-edits
  hook is present, and qa_record_test.dart, palette_contrast_test.dart,
  screen_readability_test.dart, and test/golden/ui_golden.dart are all in
  place.
- CLAUDE.md factual claims exercised this batch all matched: every path
  checked exists (salapify_icon.dart, flutter/shorebird.yaml, the workflows
  and scripts, the agent files, docs/Product_Vision_Spec.md), the delivery
  three-command read produced the real f3.17 row, and the stamp in
  flutter/lib/main.dart line 34 is f3.17, matching it. The icons section's
  claim that a new icon needs a name in the map or the resolve test fails
  still matches the tool. Not every claim was re-audited; the exercised
  ones held.

---

## 2026-08-01, session 29: one clean delivery, three gates with disjoint catches, and a test that knew more than its own comment

**What we believed / What was true.** We believed Pan With a Plan would ship
as f3.16 in one merge, and the delivery log says it did:
`| 2026-08-01 12:00 UTC | f3.16 | 11 | patch | 0.9.0+15 | 2f5a81bc |`,
patch 11, a Shorebird patch over the air on the f3.06 base APK, no manual
install. One honest caveat before anything else: the founder asked for this
retrospective right after the delivery report and has NOT yet confirmed the
f3.16 stamp on the phone. This session's ground truth is therefore the
delivery row, which the publisher writes only after it actually ships, the
best available evidence short of the phone itself. The phone check is still
owed, and it stays in the open lessons below. Patch numbers ran 10 then 11
with nothing between, so no unrecorded patch slipped through. Every delivery
guard held: unique stamp, qa-log row f3.16 present before the merge
(docs/qa-log.md), Flutter check green on a real runner, merge commit 2f5a81b
(PR #290), publisher wrote the row itself. Earlier the same day PR #289 (the
session 28 retro plus the pipefail hook) merged touching only
.claude/hooks/guard-destructive-edits.sh, CLAUDE.md, and
docs/lunch-and-learn.md, no flutter/ path, so it correctly published nothing.
That is the session 25 lesson applied right: the "ships nothing" claim was
made from the merge's file paths, not from a belief.

There is no delivery gap to explain. The session's material is what happened
before the merge: one wrong test vector caught by its own red run, one
fixture that shared its author's wrong guess with the code it tested, one
finder satisfied by the wrong widget, one near-miss between two actors
proving failures in the same tree, and three parallel QA gates that each
found a real, disjoint bug.

Plain terms used below. A "fixture" is the pretend saved data a test builds
so a screen has something to show. A "finder" is the line in a widget test
that locates a piece of text or a control on the simulated screen. The
"resolver" is the routing table that decides which kind of question the Pan
chat was asked; its "discriminator" is the one field naming that kind.
"Prove-fail" is the standing rule that a new test must be shown to go red
against deliberately broken code before it is trusted.

**Timeline (with evidence).**
- The feature, engine first. Commit f7e14fd built money/plan.dart with
  sixteen edge-first vectors, the Jan 31 month-clamp vector FIRST per
  session 28's convention (flutter/test/plan_test.dart line 12), prove-fail
  done on the clamp. Then the Pan intent wiring with an empty any-list so no
  old routing was stolen (goldens replayed green), then the screen. Merged
  as 2f5a81b, shipped as patch 11.
- A vector was wrong on first write, and the test caught its own author. The
  "how is my plan" widget test first used startDate 2020-01-15 with 8000
  paid in, and its comment said "far past the pace". At 1000 a month, 79
  elapsed months means far BEHIND, the exact opposite. The comment carried a
  wrong mental model; the failing run corrected it, not any reading of the
  comment. Fixed with a relative date about three periods back, with the
  arithmetic stated where the belief used to be
  (flutter/test/plan_card_test.dart lines 199 to 207).
- qa-tester's catch one, a permanent data trap. A near-complete goal
  produced a "Make it a plan: P0 monthly" chip because the greater-than-zero
  bound ran before rounding, and accepting stored a plan the shape-checker
  rejects: no card, no Drop button, and the raw-getter offer guard then
  blocked every future offer, surviving backup export. Fixed by rounding
  before the bound and switching the guard to activePlanOf, proven
  fail-first (the disabled guard reddened exactly the zero-offer vector,
  amount 0.0 stored). Recorded in the qa-log f3.16 row.
- qa-tester's catch two, a dead branch defended by its own fixture. The goal
  offer read a field named dueDate. Goals never store that field; the
  writer, store.addGoal, writes targetDate (flutter/lib/data/store.dart
  line 829). The deadline branch was dead code, and it passed its test
  because the FIXTURE used the same wrong field name as the code, both
  copied from the same guess. This is the exact passing-for-the-wrong-reason
  failure mode CLAUDE.md warns about, in fixture form. Fixed by deriving
  from goalPace over targetDate, fixture corrected, month-only and
  behind-goal vectors added.
- flutter-ux-craftsman's catches. The plan card violated the feature's own
  trust rule: amount, cadence, and start date were invisible in every
  ongoing state, on a card whose entire premise is that Pan shows everything
  he remembers. Fixed with an always-visible facts line. The edit sheet's
  error SnackBar drew behind the modal barrier so Save looked dead; replaced
  with inline errorText. And Drop erased startDate and startLevel, which no
  remake restores, with no confirmation; now behind a one-line confirm.
- journey-tester's catch, a real routing bug the single-screen test had
  waved through. With a standing plan, "how is my plan" got the fallback
  reply, because the resolver spread planStatus last and its own kind (debt
  or goal) overwrote the 'plan' discriminator, so respond() missed its plan
  case. The single-screen test had passed because the CARD behind the chat
  carried the expected text and the finder accepted it in place of the
  REPLY. Failure line, quoted from commit 928a3e1: Found 1 widget with text
  "I did not catch that one." / "Pan answered 'how is my plan' with the
  fallback while a plan stands". Fixed by pinning kind after the spread; the
  tests now demand the engine's own planLine appear exactly TWICE, card and
  reply, assert the fallback absent BY NAME, and require the line to contain
  the paid amount so agreement on empty sentences cannot pass
  (flutter/test/journeys_test.dart lines 1160 to 1181,
  flutter/test/plan_card_test.dart line 231).
- The near-miss between two actors. While journey-tester was mid prove-fail,
  its deliberate multiply-by-0.9 break sitting in planStatus while it waited
  for its red run, the main session ran the FULL suite in the same tree and
  watched the journey fail. The main session recognized the break as the
  agent's and did not touch it; the agent restored it after its run
  reported, per the rule. But the rule as written speaks to ONE actor about
  its OWN break. It says nothing to a second actor who finds a break it did
  not make. A helpful "fix" of the 0.9 while the agent's run was still
  compiling would have made that run compile the fixed code and print a
  false pass, the exact outcome the rule exists to prevent, produced by
  following no rule at all.
- A Flutter mechanics bug on first write. Disposing the edit sheet's text
  controller right after the pop crashed the sheet's exit animation, because
  the framework builds the closing sheet one more time on the way out. Fixed
  by making the sheet a real StatefulWidget whose State owns and disposes
  the controller (flutter/lib/screens/pan.dart lines 794 to 819, with a
  comment naming why). The widget tests that pump the sheet closed now
  exercise that path on every run.
- The shot asserts its view. The new pan-plan shot asserts OUR PLAN is in
  frame before capturing (flutter/test/screens_shot.dart lines 1359 to
  1363), which closes session 28's open sharpening for this screen. The
  original 60-day cashflow shot still captures with no such assertion after
  its tap (lines 2073 to 2081), so that half stays open, now narrowed to one
  named shot.
- Follow-ups, verified rather than trusted. Of the follow-ups this session
  named, exactly ONE is written down: the pinned compact plan card, in the
  qa-log f3.16 row ("not silently dropped"). Five others existed only in
  conversation: goal-kind and repace-then-pay journeys, the plan-done
  milestone interplay, a coach plan nudge kind, milestone plan checkpoints,
  and horizon persistence. They are recorded here so this entry is now the
  record; a follow-up that lives in nobody's file is a follow-up that
  already happened to someone else.

**Root cause.** For the wrong vector and the wrong fixture, one cause
wearing two costumes: a hand-written belief (a comment's "far past the
pace", a fixture's dueDate) has no machine against it unless something
independent computes the truth. The vector was saved because the engine
disagreed with the comment's arithmetic and the run went red. The fixture
had no such savior, because the code under test shared the same belief, so
agreement was guaranteed; only reading the WRITER's code (store.addGoal)
broke the loop. For the finder, "find this text anywhere on screen" is
satisfied by any surface showing it, and the busier the screen the more
surfaces there are, so the assertion is weakest exactly when the screen is
fullest. For the near-miss, the prove-fail rule was scoped to one actor
because one actor is who it was written for, and nothing in a shared
working tree records whose uncommitted break is whose.

**Lessons, each with its guard and the guard's strength.**

1. A test's comment is a belief; only its red run is a fact. The vector
   whose comment said ahead while its data said behind was corrected by
   failing, not by being read, and the fix that lasts is making the
   assertion computed rather than transcribed. **Guard: the journey computes
   planLine from the engine over the live store and demands the screen match
   it, with a directional companion (the line must contain the paid amount)
   so two empty sentences cannot agree their way to green
   (journeys_test.dart lines 1145 to 1181); the widget vector now uses a
   relative date with its arithmetic shown (plan_card_test.dart lines 199 to
   207).** Strength: strong for these tests. The general convention, assert
   computed truth rather than transcribed truth, is medium, a sentence that
   depends on being read.

2. A fixture is a second implementation of the data schema, and one written
   from memory can share the code's wrong guess and then defend it forever.
   The dueDate fixture passed a dead branch precisely because fixture and
   code were wrong TOGETHER. **Guard: for plans this is already a machine,
   activePlanOf is the sole shape-checker and junk reads as no plan
   everywhere, so a malformed plan fixture cannot quietly pass. For goals
   and the other user-data shapes the guard is named but NOT built: build
   fixtures through the writer (store.addGoal and kin) instead of raw maps,
   or add a shape test that constructs one of each entity via its writer and
   asserts fixture keys against that canonical shape.** Strength: the plan
   half is strong; the general half is currently only this entry, which is
   to say weak, and it is listed under open lessons until a machine exists.

3. A finder that accepts the text anywhere passes hardest when the screen is
   busiest, because the more surfaces show related text, the more wrong
   widgets can satisfy it. The routing bug hid behind the card while the
   reply was broken. **Guard: the three-part pattern now in the tests: exact
   count (findsNWidgets(2), one per surface that must agree), the failure
   text asserted absent BY NAME (the fallback sentence, findsNothing), and a
   directional companion on the content. plan_card_test.dart line 231
   carries the comment naming the miss so the pattern explains itself to the
   next reader.** Strength: strong where written. As a general rule for
   future two-surface screens it is medium, and it belongs in the
   journey-tester agent's discipline; noted here for the next time that file
   is edited.

4. A deliberate break you did not make is not yours to fix. The prove-fail
   rule needs its second clause: in a shared tree, a red test may be another
   actor's proof in flight, so before fixing a surprising failure, check
   whether an agent is mid prove-fail and ask the actor, and keep the
   session 28 habit of disjoint file ownership per agent. **Guard: this
   clause, a rule.** Strength: weak to medium, stated honestly: nothing in
   the repository can observe whose uncommitted edit a break is, the same
   reason the original prove-fail ordering rule is a rule and not a machine.
   The near-miss cost nothing this time because the one actor who could have
   broken it happened to know; the clause exists so the next actor does not
   have to happen to know.

5. Three parallel gates finding three disjoint real bugs is the process
   WORKING, and it is recorded as a positive result. qa-tester found what
   only reading the engine against the data shapes could find (the trap and
   the dead branch), flutter-ux-craftsman found what only looking finds (the
   trust rule broken on screen, the buried SnackBar, the unguarded Drop),
   and journey-tester found what only crossing screens finds (the routing
   bug). None of the three could have made another's catch. **Guard: the
   standing three-lens gate itself, already enforced by the qa-log row
   requirement (flutter/test/qa_record_test.dart fails the runner when the
   stamp has no row).** Strength: strong, and already in place; this lesson
   is a confirmation, not a change.

**Open lessons carried forward.**
- NEW: founder phone confirmation of f3.16 is pending. If the phone shows
  anything other than f3.16 patch 11, that finding outranks everything
  above.
- NEW: the fixture-through-the-writer guard for goals and other user-data
  shapes (lesson 2), a machine not yet built; until it exists, hand fixtures
  for goals are checked only by review.
- NEW, small: the five unrecorded follow-ups are now recorded in the
  timeline above; the next session should check whether any moved from this
  entry into the backlog or a test.
- Narrowed from session 28: the shot-asserts-its-view sharpening is done for
  the pan-plan shot and still missing on the 60-day cashflow shot
  (screens_shot.dart lines 2073 to 2081).
- Guards from earlier sessions re-checked and standing: the pipefail hook
  rule 3 is present (.claude/hooks/guard-destructive-edits.sh lines 139 to
  159), the weekend-due vector holds in timeline_test.dart, _hasAnyData is
  shared by both reminder gates in reminders.dart, and
  check-stamp-unique.sh plus both Flutter workflows exist with the triggers
  CLAUDE.md claims (claude/** plus pull_request for the check; main with
  flutter/** paths for the publisher).
- CLAUDE.md factual claims exercised this batch all matched: every named
  path exists (qa_record_test.dart, update_stamp_test.dart,
  salapify_icon.dart, test/golden/ui_golden.dart, the five skills including
  writing-skills, the journey-tester and lunch-and-learn agent files), the
  delivery three-command read produced the real f3.16 row, and the stamp in
  flutter/lib/main.dart line 34 is f3.16, matching that row. Not every
  claim was re-audited; the exercised ones held.

---

## 2026-08-01, session 28: a clean delivery, three gates that earned their keep, and an exit code that lied

**What we believed / What was true.** We believed the Sweldo Timeline, the
biggest money-math change since the port, would ship as f3.15 on the first
try. What was true: it did. The founder confirmed it on the phone ("it
works"), and the delivery log's last row is
`| 2026-08-01 09:56 UTC | f3.15 | 10 | patch | 0.9.0+15 | d6d8fd17 |`,
patch 10, a Shorebird patch over the air on the f3.06 base APK, no manual
install. Every delivery guard held: unique stamp, qa-log row present before
the merge (docs/qa-log.md, the f3.15 row), Flutter check green on a real
runner, merge commit d6d8fd1, publisher wrote the row itself. There is no
delivery gap to explain. This session exists because the interesting part
all happened BEFORE the merge: one real engine bug that twenty-one passing
tests could not see, two visual defects only an eye caught, two old guards
that fired exactly as built, and one near-miss where a shell command
reported success over a failing test suite.

Plain terms used below. A "primitive" is a small shared function other code
builds on; here it is `bankDueDate`, the one function that answers "when is
this debt actually due", and its documented behavior is that a due date
landing on a weekend or holiday moves forward to the next banking day. A
"vector" is a test with hand-computed expected numbers. A "pipeline" is two
shell commands joined by `|`, the output of one feeding the other.

**Timeline (with evidence).**
- The feature. Commit dbe1504 built the Sweldo Timeline (a rolling day by
  day cash projection that crosses month boundaries, with what-if
  scenarios), merged as d6d8fd1 (PR #287), shipped as patch 10. The full
  gate record is the f3.15 row in docs/qa-log.md: three lenses, qa-tester,
  flutter-ux-craftsman, journey-tester, all pre-merge.
- The engine bug, caught by the qa-tester gate. The new debt-cycle loop in
  flutter/lib/money/timeline.dart composed `bankDueDate` without honoring
  its documented contract: the primitive keeps the previous raw due date in
  the running while its weekend-adjusted date is still ahead, so a cursor
  that stepped just past the raw due saw the same adjusted date twice, and
  the loop's duplicate check then broke out entirely, silently discarding
  every later cycle. Trigger condition: any due date that is weekend or
  holiday moved, which is roughly two of every seven due days. Effect: the
  "conservative" projection understated debt outflow, the one direction a
  conservative line must never err. The fix (commit f6faf64) steps past the
  adjusted date and continues; the loop comment in timeline.dart records
  the contract. Proven fail-first with a weekend-due vector before the fix
  was trusted: flutter/test/timeline_test.dart, "a weekend-moved due does
  NOT swallow the later cycles", dueDay 18, Jul 18 2026 is a Saturday, and
  the test demands all three cycles land
  (`['2026-07-20', '2026-08-18', '2026-09-18']`).
- Why twenty-one vectors missed it. Every hand vector used convenient
  dates: dueDay 10 lands on clean weekdays throughout the fixture window,
  so the weekend adjustment, the primitive's ONE documented edge, never
  fired in any test. The vectors were correct and complete about everything
  except the thing the primitive exists to handle.
- The eye caught what tests could not, twice, in one rendered shot. First:
  the initial render of the Pro 60-day view silently showed the WRONG view,
  because the "60 days" chip was off-screen and the tap landed on nothing.
  The harness printed a hit-test warning; it was in the output and
  initially unread. Fixed with an `ensureVisible` before the tap, with a
  comment naming the miss (flutter/test/screens_shot.dart). Second: two
  grey boxes floating in the chart turned out to be the dip label drawn in
  Ahem, the all-boxes test-default font, because a raw TextPainter inherits
  no theme font. The same missing fontFamily meant the PHONE would have
  drawn that label in Roboto instead of Jakarta, so the harness artifact
  was pointing at a real shipped-font defect. Fixed in
  flutter/lib/screens/cashflow.dart, and the first version of that fix used
  a literal font string, which font_choice_test correctly reddened;
  corrected to `Barako.bodyFont` (commit 15f7191). A grey box in a render
  is evidence, not noise.
- Two old guards fired exactly as designed. The full suite went red on two
  real integration regressions the change introduced: the new Home card
  displaced MONEY CHECK-IN out of the lazy list's first viewport
  (flutter/test/smoke_test.dart), and the new action-carrying snackbar did
  not state its persist behavior (flutter/test/snackbar_persist_test.dart).
  Both guards predate this change. Both fixed in commit 6440431: the
  check-in card kept its slot and the road-ahead card moved below it. This
  is the machinery working while nobody was watching, and it is recorded as
  such, not as a finding.
- The near-miss, and it is the sharpest lesson. The full-suite verification
  ran as `flutter test | tail -2` inside a background chain, and the chain
  reported exit 0 WHILE TWO TESTS WERE FAILING, because a pipeline's exit
  code is the LAST command's, and `tail` succeeded. It was caught only
  because the two kept lines happened to include the "Failing tests:"
  block; a tail that landed on passing-looking lines would have produced a
  confident, false "suite green" into the merge decision. The backstop
  held in principle: the Flutter check on the runner runs the same suite
  and would have reddened the PR before merge, so main was never actually
  at risk. What WAS at risk is the claim, a false green reported as fact.
- Concurrency, assessed and found acceptable. Three agents worked the same
  tree at once (qa-tester with a temporary probe test, journey-tester in
  journeys_test.dart, the builder in cashflow.dart). One Edit hit the
  tool's stale-read rejection and was redone against the fresh file; one
  intermediate file state briefly looked like a dropped condition and was
  fine on re-read; the probe file was cleaned up. No damage. The machine
  that prevented the only real hazard already exists inside the Edit tool
  itself, which refuses to write over a file it read stale. The practice
  worth keeping is disjoint file ownership per agent, and that is a habit,
  named honestly as the weakest kind of guard, acceptable here because the
  tool-level check is the real one.
- Also in the batch: the founder's standing direction became a CLAUDE.md
  rule, "Enhance what exists, never regress it" (commit 5e6d9c9, PR #288),
  and the vision spec merged earlier (PR #286, commit 850335e).

**Root cause.** For the engine bug: hand-computed vectors gravitate to
dates that are easy to hand-compute, and easy dates are exactly the dates
where a date primitive's edge never fires. Nothing required the first
vectors for a new consumer of `bankDueDate` to exercise the one behavior
`bankDueDate` exists to provide, so twenty-one correct tests built a
picture in which the adjustment never happened. For the near-miss: a
pipeline's exit code is defined by the shell to be the last command's, so
`anything | tail` structurally cannot report the test run's failure without
`pipefail`. Neither cause is anyone's attention; one is a missing
convention about which vector comes first, the other is a property of the
shell.

**Lessons, each with its guard and the guard's strength.**

1. When new code composes a locked primitive, the FIRST test vector must
   exercise that primitive's documented edge, because convenient test data
   and the edge are mutually exclusive by construction. **Guard: the
   weekend-due vector (timeline_test.dart), proven fail-first, which locks
   this bug out permanently, plus the convention itself.** Strength: the
   test is strong, an automated check that fails loudly and cannot be
   satisfied by the broken loop. The convention ("edge vector first for any
   new consumer of a date primitive") is medium, a sentence that depends on
   being read; it belongs beside the porting-money-logic skill's golden
   vector rule and is recorded here so the next engine gets it.

2. A screenshot must prove it shows what it claims to show, because a tap
   that misses is silent and the shot of the wrong view looks exactly like
   a shot of the right one. **Guard: the `ensureVisible` before the tap in
   screens_shot.dart, with the comment naming the first-render miss.**
   Strength: medium. It fixes the known miss, but nothing yet asserts the
   60-day view is actually on screen before the golden captures, so a
   renamed chip could miss silently again; the sharper form (assert
   something only the tapped view shows, before capturing) is carried
   forward as open. The other half, actually reading the harness's
   hit-test warning in the output, is a rule and is stated as one.

3. An artifact that only appears in the harness can still be a phone bug
   wearing a costume: the Ahem grey boxes were the render being honest
   about a TextPainter that named no font, which the phone would have
   rendered as the wrong font rather than as boxes. **Guard: for the
   literal-string half, font_choice_test, which fired on the first fix in
   this very batch and forced `Barako.bodyFont`; for the no-font-at-all
   half, the render itself, where Ahem boxes are unmissable.** Strength:
   the test is strong; the render half is medium because it requires an
   eye on the shot, which is exactly the standing look-before-shipping
   rule doing its job.

4. A pipeline reports the LAST command's exit code, so `flutter test |
   tail` saying 0 is a statement about tail, not about the tests. **Guard:
   BUILT IN THIS SAME CHANGE, not left open. Rule 3 in
   .claude/hooks/guard-destructive-edits.sh now refuses a `flutter test`
   invocation piped onward unless pipefail appears in the command, proven
   both halves before trusting it: it fired on the two bad shapes (a
   piped suite run, a piped run inside an && chain) and stayed silent on
   six good ones (pipefail present, no pipe, the shape merely MENTIONED in
   a commit message or heredoc, a piped analyze, ordinary commands).** The
   mention cases matter: rule 1's install-day lesson was that a guard that
   cannot tell an invocation from a mention blocks writing about the thing
   it guards, and this entry itself contains the banned shape several
   times. Strength: strong for the exact shape, honest about scope: it
   guards `flutter test` only, and the runner branch check remains the
   structural backstop that keeps main safe regardless. CLAUDE.md's hook
   section was updated in the same change so it does not claim "exactly
   two shapes" while the script enforces three.

**Open lessons carried forward.**
- NEW, small: the shot-asserts-its-view sharpening (lesson 2), an
  assertion before the golden capture that the tapped horizon is actually
  displayed.
- CLAUDE.md factual claims load-bearing to this batch were re-checked and
  held: .github/scripts/check-stamp-unique.sh, both Flutter workflows, the
  journey-tester agent file and journeys_test.dart all exist where named;
  the delivery three-command read produced the real f3.15 row; the new
  "Enhance what exists" section matches what PR #288 merged; the Sweldo
  Timeline is named in that section as the pattern to copy and now
  actually exists, so the sentence became true the day it shipped. Not
  every claim was re-audited; the exercised ones matched.
- From session 27: the shared `_hasAnyData` gate and its utang-only tests
  are in place and green; nothing to reopen.

---

## 2026-08-01, session 27: a clean patch, and a blind spot that was copied before it was ever tested

**What we believed / What was true.** We believed f3.14 would ship the
comeback notification cadence cleanly on the first try. What was true: it did.
The founder confirmed it on the phone, and the delivery log's last row is
`| 2026-08-01 04:43 UTC | f3.14 | 9 | patch | 0.9.0+15 |`, patch 9, a Shorebird
patch over the air on the f3.06 base APK with no manual install. Every prior
delivery guard held: a unique stamp, a qa-log row, the Flutter check green on a
real runner, a merge commit, and the publisher wrote the row itself. There is
no delivery gap to explain here. This session exists to record the one real
thing QA caught before the merge, and one small stale-doc residue, and to
confirm a guard proposed two sessions ago has since landed.

Plain terms used below. A "reminder gate" is the yes-or-no check the planner
runs before it schedules a reminder: only fire the monthly backup nudge, or the
new comeback ping, if there is data on the phone worth coming back to. An
"utang-only user" is someone who tracks only who owes whom (debts and
receivables) and has never opened a cash or bank account or logged a spend.
That user is not an edge case here; they are the core audience the app was
named for.

**Timeline (with evidence).**
- The feature. A new pure `comeback` kind in
  flutter/lib/money/reminders.dart arms a re-engagement ladder relative to
  "now": with the nightly nudge off it fires at now+2, +4, +7, +14 days at
  11:00; with the nightly nudge on it fires ONLY the day-14 catch, so it never
  double-pings the 20:00 daily nudge. It is silent for active users by
  construction, because the service wipes and rebuilds the whole schedule on
  every open (flutter/lib/services/notifications.dart, `cancelAll()` then a
  loop over `plannedReminders`), so every reopen cancels the old day-2 ping and
  re-arms it two days past the new open. Default on with the nightly nudge at
  onboarding (lib/data/store.dart, `'comeback': true`), toggle in Menu
  (lib/screens/menu.dart, the "Come back" row).
- The design deviation. The written roadmap acceptance criterion
  (docs/Product_Backlog.md) sketched "normal days 1 to 3, one comeback message
  day 7". The behavior-scientist persona retuned this before build to
  2, 4, 7, 14 (day 1 reads as clingy and drives opt-outs; day 14 is the last
  catch before a lapsed user goes permanently silent) and added the daily-gate
  to kill double-ping days. The shipped cadence therefore differs from the
  written line, on purpose.
- The QA finding, and it is the point of this session. The qa-tester found zero
  must-fix and one should-fix: the comeback data gate was COPIED from the
  monthly backup nudge, and that gate counted only accounts and transactions.
  So it silently skipped an utang-only user for BOTH the comeback ping AND the
  monthly backup nudge. The backup half was a pre-existing bug, latent and
  untested, that copying carried into the new feature.
- The fix. One shared helper, `_hasAnyData`
  (flutter/lib/money/reminders.dart), counts accounts, transactions, debts,
  OR receivables, and both the backup nudge and the comeback ladder now call
  it. Two new tests lock it in: "fires for an utang-only user" for backup and
  "FIRES for an utang-only user, no account or transaction" for comeback
  (flutter/test/reminders_test.dart).
- The alarm rule was followed on both halves. Silencing the comeback branch
  reddened the FIRES test while the two SILENT tests correctly stayed green,
  and removing the daily-gate reddened the "daily ON fires ONLY day 14" test
  while FIRES stayed green. Both breaks were restored only after the runs
  reported.
- Evidence trail: commit f3fce3a "Add notification comeback cadence (f3.14)",
  merged as cf0165f (PR #284), delivery row patch 9.

**Root cause.** For the utang-only skip: a gate copied by value carries its
untested blind spot with it. The backup nudge's accounts-or-transactions check
had never been exercised against an utang-only phone, so nothing in the suite
knew it was wrong, and copying it produced a second wrong gate rather than
exposing the first. This is worth stating precisely, because it is NOT the
"a test had to change, so the suite was defending the bug" trap: no test was
inverted or deleted for this fix. The suite was SILENT on the utang-only case,
not asserting against it. Silence is weaker evidence than an inverted
assertion, but it is the same structural fault, a check nobody thought to
write, and it let a bug sit latent in shipped code until a persona happened to
re-derive the gate's meaning from the audience.

**Lessons, each with its guard and the guard's strength.**

1. A reminder gate copied from another kind copies that kind's blind spot, and
   the backup gate's blind spot was the app's own core audience. **Guard: the
   shared `_hasAnyData` helper that both kinds now call, plus the two new
   utang-only tests.** Strength: strong, and structurally so. There is now ONE
   gate, not two copies that can drift, and it is pinned by a test that asserts
   the utang-only user gets both nudges. A future third kind that needs the same
   gate calls the same function and inherits the same coverage. The deeper
   lesson under the guard: when you copy a predicate, you copy what it was never
   tested against, so the copy should become a shared, tested function at the
   moment of the second use, not a paste.

2. A persona retuning a rough roadmap number into a researched cadence is the
   expected and healthy path, not a defect, and this session records it as such.
   The only durable residue was that docs/Product_Backlog.md still read
   "normal days 1 to 3, one comeback message day 7", a false factual claim
   about a shipped feature, the same stale-doc trap that has twice bitten
   CLAUDE.md. **Guard: the acceptance line was updated to the shipped 2/4/7/14
   cadence in this same change.** Strength: medium, because it is a sentence in
   a doc and depends on someone reading it at the right moment; no machine can
   catch a roadmap line that names a real feature but the wrong numbers. Stated
   plainly, not dressed up as strong. Unlike most doc lessons this one was
   closed in the same commit rather than carried forward.

**Open lessons carried forward.**
- From session 26, lesson 2 (the proposed data-level guard that the lived-in
  fixture spans at least three distinct spending weekdays, so the WHEN YOU SPEND
  card's precondition reddens on the DATA and not only when a screen render
  happens to fail): this has since LANDED. It is
  flutter/test/fixture_still_lived_in_test.dart, "spending spans at least
  three distinct weekdays in the last 8 weeks", whose failure message names "the
  session 26 rot" directly. It was bundled into f3.13 and is green. A proposed
  guard that actually got built is the good outcome; recording it here closes
  the loop so a later session does not re-propose it.
- The CLAUDE.md factual claims load-bearing to THIS batch held: the delivery
  three-command read produced a real row, the publisher wrote it, and the
  unique-stamp guard did not need to fire because the stamp was unique. Not
  every claim in CLAUDE.md was re-audited this pass; the ones this delivery
  exercised matched the repository.

---

## 2026-08-01, session 26: the calendar turned over and two tests went red, on a build that changed nothing

**What we believed / What was true.** We believed main was green and would stay
green until someone changed something. What was true: on 2026-08-01, with no code
change at all, the "Flutter check" branch check (the analyze-and-test action that
runs on every claude/** branch and on main) went red, 1383 passed and 2 failed.
The trigger was not a diff. It was the date rolling over to the first of the
month. The same red reproduced on a branch that carried zero flutter/ changes,
which is the proof it was a property of main and not of any diff. Ground truth
now: the founder confirmed "confirmed" on the phone, and the delivery log's last
row is `| 2026-08-01 01:03 UTC | f3.12 | 7 | patch | 0.9.0+15 | 4ba7a1f1 |`. The
app the founder is holding is byte-for-byte the same behaviour as f3.11; the only
thing that differs between the two builds is the stamp string
(flutter/lib/main.dart:34, `f3.12 ... Test fixture dates no longer rot at the
month start ... No app change.`). Nothing about the app was broken. Two tests
were, by a fixture that expressed dates in a way the calendar could collapse.

Plain terms used below. A "fixture" is fake but realistic data a test feeds the
app so a screen has something to draw. The "lived-in fixture" is the shared one
(flutter/test/screens_shot.dart, `livedInBlob`) that four separate machines read
so the screens under test look like a phone somebody actually uses. "Rot" means a
test that quietly stops testing what it was written to test, without anyone
touching it, because the world moved (here, the date).

**Timeline (with evidence).**
- The two failures, both on main, both date-driven, neither a code defect:
  - flutter/test/reports_screen_test.dart, "the new decision graphs render
    without overflow": the WHEN YOU SPEND weekday-pattern card did not render, so
    a `find` for the text "WHEN YOU SPEND" matched 0 widgets. That card is guarded
    in lib/screens/reports.dart:681, `if (peak.activeDays < 3 || peak.peakDay < 0)
    return const SizedBox.shrink();`. It needs at least three distinct active
    weekdays to draw anything.
  - flutter/test/fixture_still_lived_in_test.dart, "somebody is overdue AND
    somebody still has time to pay": Expected non-empty, Actual []. No receivable
    was dated before today, so the Overdue branch was unreachable.
- The mechanism. Before the fix, both fixtures dated entries as "the nth of the
  CURRENT month, capped at today". In screens_shot.dart the helper was
  `d(n) => DateTime(today.year, today.month, day <= today.day ? day : today.day)`;
  in reports_screen_test it was a bare `_thisMonth(day)` with no cap, which on the
  1st is a FUTURE date that the weekday pattern (counted only up to now) correctly
  ignores. On the 1st and 2nd of a month the cap collapses every date onto today:
  one active spending weekday instead of many, and nothing dated before today.
  One collapse hid the weekday card; the other emptied the overdue branch.
- What went well, and it is the point of this session. The overdue collapse was
  caught by a guard that exists for exactly this: fixture_still_lived_in_test.dart
  is a DATA-level self-check on the fixture, deliberately about the data and not
  about any screen, and its third test asserts the fixture presents both an
  overdue receivable and a not-yet-due one. It went red the instant the fixture
  stopped presenting the overdue half (`due.where((d) => d.isBefore(today))` was
  empty). The reports card collapse was caught by the screen render in
  reports_screen_test.dart. Neither shipped a bad screen. Both blocked the merge.
  That is the machinery working while nobody was watching.
- The fix, PR #280 (commit 08d1c0f, merged at 4ba7a1f, shipped as f3.12 patch 7).
  It dates entries RELATIVE to today. `ago(k) => iso(today.subtract(Duration(days:
  k)))`, so `ago(0)` is always today and therefore always in the current month,
  and a spread of k values lands on many weekdays across the last four weeks,
  crossing the month boundary exactly as a real phone's recent spending does.
  Receivables use `ago()` for overdue (`ago(20)`, `ago(6)`) and `ahead()` for
  still-has-time (`ahead(17)`), the single income is `ago(0)` so Reports and
  Insights always have this-month income, and the twelve expenses fan out from
  `ago(0)` to `ago(31)`. reports_screen_test got the same treatment via a new
  `_daysAgo(k)` helper. The full suite went 1385 green (up two, the two that had
  failed).

**Root cause.** A fixture that encoded dates as positions inside the current
month, so the meaning of every date depended on where in the month "today" sat.
On the first of the month there is no "earlier this week" inside the current
month, because earlier this week is last month, and a cap-to-today has no way to
say it. This is the THIRD rotation of one lesson. First the fixture was pinned to
a constant July 2026, which would have dropped every entry into last month on the
first of August (that is session 17 on a timer, and the old comment in
screens_shot.dart warned about exactly that collapse). Then it was changed to
`d(n)`, capped at today, to stop the future-dating. Now the cap itself rotted at
the month start. The structural fault common to all three: any date expressed as
a day-of-month is a value the calendar can reinterpret. The root cause is not
"we forgot to test on the 1st"; it is "the fixture did month arithmetic at all".

**Lessons, each with its guard and the guard's strength.**

1. Dates in a test fixture must be relative to today, never a day of the month,
   because a day-of-month is a value the calendar reinterprets and a Duration from
   today is not. **Guard: the relative-date model that already shipped in #280**
   (`ago(k)`, `ahead(k)` in screens_shot.dart and `_daysAgo(k)` in
   reports_screen_test.dart). Strength: strong, and this time structurally so, for
   a reason worth stating plainly. The new model does no month arithmetic. It
   never constructs `DateTime(year, month, day)`; it only subtracts a `Duration`
   from `today`. There is no day-of-month field to overflow (the old day-29-to-31
   clamp problem cannot arise) and no month index to roll. So the answer to "is it
   finally rot-proof" is yes for the month-boundary failure that has bitten three
   times: it cannot recur, because the arithmetic that caused it is gone.
   The one residual I can name honestly, and it is not the same class of bug:
   Dart's `subtract(Duration(days: k))` moves absolute time, not calendar days, so
   across a daylight-saving transition a result could land an hour early or late
   and shift a date by one day. That would never collapse the spread or move
   everything onto today (it is a one-day nudge on one entry at most), and it does
   not arise in practice because the runner clock is UTC, which has no DST, and the
   app's audience is the Philippines, which has none either. `ago(0)` in particular
   is exact, no subtraction, so the "always in the current month" guarantee holds
   with zero DST exposure. I am recording this as a named non-issue rather than a
   silent one, so a future session that sees a one-day wobble knows where it came
   from and does not mistake it for a return of the collapse.

2. The overdue half had a data-level self-check and was caught by it; the
   weekday-spending half did not, and was caught only because a screen render
   happened to fail. That asymmetry is the real gap. **Guard, proposed and NOT
   implemented this pass:** add a fourth assertion to
   fixture_still_lived_in_test.dart that mirrors the WHEN YOU SPEND guard at the
   DATA level, so the regression reddens on the data and not only when a picture is
   rendered. Precisely: collect the expense transactions in `livedInBlob`
   (`type == 'expense'`) whose date is within the last eight weeks (`!date.isBefore(
   today.subtract(const Duration(days: 56)))` and `!date.isAfter(today)`), map each
   to `DateTime.parse(date).weekday`, put those in a `Set<int>`, and
   `expect(set.length, greaterThanOrEqualTo(3), reason: ...)`. That is the same
   threshold reports.dart:681 uses (`peak.activeDays < 3`), so the day the fixture
   stops spanning three weekdays is a red DATA test, not a silent screen. Strength
   when built: strong (an automated assertion that fails loudly, independent of any
   render). Until it is built the lesson is partly open: the weekday card's fixture
   coverage still leans on a screen test rather than on the self-check whose whole
   job is to promise the fixture reaches the states it exists to reach.

**Open lessons carried forward.**
- NEW, open: the Reports "No income logged yet" empty state overflows at 1.5x
  system font. When there is no income in the current month but there is spending,
  reports.dart:304 renders the head "No income logged yet"
  (`income == 0 && expenses > 0`), and screen_readability_test.dart measured that
  head spanning from x=38.0 to x=474.8 on a 390-wide phone, so it runs off the
  right edge. This is a real latent LAYOUT bug in lib, pre-existing and independent
  of the fixture, found only because the old fixture briefly lost this-month income
  on the 1st. It was deliberately left for a later fix, and the fixture now always
  carries this-month income (`ago(0)`), so the sweep no longer walks through it.
  That is precisely the risk: the machine that catches it (screen_readability_test)
  only reaches it when the fixture has no this-month income, which is now never.
  The fix belongs in reports.dart's income==0-and-expenses>0 branch (wrap or size
  the "No income logged yet" head so it fits at 1.5x on a 390 phone). Recorded here
  so it is not lost; the readability sweep is the machine that will re-catch it the
  moment any fixture loses this-month income again.
- From session 25, now CLOSED and confirmed: the optional pre-merge
  stamp-versus-main branch check was built. .github/scripts/check-stamp-unique.sh
  exists and is wired into flutter-check.yml:167, so a flutter/-touching branch
  whose stamp still equals the delivered one reddens before the merge, in front of
  the publisher's existing backstop. The two-builds-one-stamp lesson now has a
  guard at both ends.
- From session 24, now confirmed: the segmented_test.dart "must stack" assertion
  was re-anchored to the shipped font rather than deleted. segmented_test.dart
  loads the real Plus Jakarta Sans via `loadRealFonts` (lines 236 and 272) before
  it measures, so the layout test judges what the phone draws. The real-font
  version is the one gating.

**CLAUDE.md factual re-check (done as a step, not a favour).** Every path this
session touched exists where CLAUDE.md says: flutter/test/screens_shot.dart is
under test/ and is not `*_test.dart` (so `flutter test` never collects it, as
claimed), flutter/test/screen_readability_test.dart and
flutter/test/palette_contrast_test.dart are ordinary `*_test.dart` files that run
on the branch check, and .github/scripts/check-stamp-unique.sh exists. The
publisher trigger CLAUDE.md describes still matches: flutter-preview.yml fires on
push to `main` with paths `flutter/**`. Nothing false found this pass.

**For the founder, over lunch.** Here is the whole story, plainly. Nothing about
your app broke, and nothing bad reached your phone. What happened is that our
tests use pretend data to fill the screens, and that pretend data described its
dates as "the 3rd of this month, the 8th of this month", and so on. When the
calendar rolled over to the 1st of August, "earlier this month" suddenly meant
nothing, because on the 1st there is no earlier this month yet. So two tests
looked at screens that had gone empty and correctly said "this is wrong", and the
build went red all on its own, with nobody having changed a single line. That is
not a failure, it is a smoke alarm doing its job: one of those two tests exists
for exactly this, and it went off the instant the pretend data stopped looking
like a real phone.

The fix was to describe the dates as "3 days ago, 8 days ago" instead of "the 3rd,
the 8th". "Days ago" means the same thing every day of the year, so it can never
collapse at the start of a month again. This is the third time this same kind of
date problem has bitten us, and this fix is the one that ends it, because the new
way does no month-and-day juggling at all, it just counts backwards from today.
The build you confirmed, f3.12, behaves exactly like f3.11 did; the only change is
the little version line and the test data behind the scenes.

Two honest notes so nothing is buried. First, one of the two tripwires (the one
for the weekday spending chart) only caught this because a screen picture happened
to fail; its proper data-level check does not exist yet. I have written down
exactly how to add it, so a future session can make that tripwire as reliable as
the other one. Second, while chasing this I found a separate, older cosmetic bug:
on the Reports screen, if you have spending but no income logged this month, the
words "No income logged yet" run off the edge of the phone at the largest text
size. I left it for later on purpose, but I have written it down here so it is not
forgotten. The cost if either of these notes is ignored: the weekday-chart
tripwire stays half-reliable, and that text-overflow bug can quietly reappear the
day our pretend data ever again has no income for the current month, because the
one check that spots it only runs into it in that exact situation.

---

## 2026-07-31, session 25: a test-only merge shipped anyway, and the guard caught it after the phone already had it

**What we believed / What was true.** We believed PR #276, a banked test and
docs change from the f3.10 retrospective, would reach the phone as NOTHING. The
plan, approved by the founder, was "bank now, ship with the next feature": no
stamp bump, on the stated belief that a test-only change "changes no app bytes,
so no over-the-air update, nothing on the phone." That belief was false. When
#276 merged to main (af16665), the publisher ran, Shorebird shipped "patch 5",
and it went live on the founder's phone still reading the OLD stamp f3.10, the
same stamp patch 4 already carried. The founder had been told nothing would
reach the phone; the merge commit title says so in writing: "Merge pull request
#276: theme-picker layout test judges the shipped font (banked, no OTA)". Two
different builds then existed under one name, which is the one thing the
delivery log exists to make impossible.

What was also true, and is the good news of this session: the publisher's
one-stamp-one-build guard fired at the exact instant of the collision, refused
to write a false record, and opened a tracking issue. Ground truth now: the
founder confirmed "stamp is 3.11" on the phone, and the delivery log's last row
is `| 2026-07-31 17:08 UTC | f3.11 | 6 | patch | 0.9.0+15 | af3f40bd |`. The
phone and the file agree again. This was NOT a clean patch. It was a
self-inflicted process error, caught by a machine that was doing its job while
nobody was watching, and recovered without a single wrong record ever being
written.

Plain-English note on the terms. "Over the air" (OTA) means the app updates
itself when reopened, with no new install. A "patch" is one such over-the-air
update; Shorebird, the tool that ships them, numbers them (patch 4, patch 5,
patch 6) against one installed base APK. A "stamp" is the short line the app
prints so the founder can read which build they are running. The publisher is
the "Flutter preview APK" GitHub Action (.github/workflows/flutter-preview.yml)
that builds and ships on every merge to main that touches flutter/.

**Timeline (with evidence).**
- PR #276 (a12a126, "Make the theme-picker layout test judge the shipped
  font") touched four files and NO app code: `git show --stat a12a126` lists
  CLAUDE.md, docs/lunch-and-learn.md, flutter/test/golden/ui_golden.dart, and
  flutter/test/segmented_test.dart. The change makes segmented_test.dart load
  the real Plus Jakarta Sans font (`+import 'screens_shot.dart' show
  loadRealFonts;` and `+ await loadRealFonts(tester);`) so the theme-picker
  layout test judges what the phone draws instead of Flutter's wider default
  test font. Nothing under flutter/lib/ changed.
- The trap is in the trigger. flutter-preview.yml:10-19 fires on push to main
  with paths flutter/**. flutter/test/ is under flutter/, so a test-only change
  to main runs the full publisher. There is no path that merges flutter/ to
  main WITHOUT shipping. The belief "no app code, so no ship" read the wrong
  boundary: the filter is flutter/**, not flutter/lib/.
- Shorebird ships on build BYTES, not on functional diffs. Even with the
  compiled app functionally identical to f3.10, the build differed and
  Shorebird published patch 5. So patch 5 went live, functionally the same as
  patch 4, but a distinct build.
- Patch 5 shipped under the UNCHANGED stamp f3.10. The publisher's "Record what
  actually shipped" step (flutter-preview.yml:201-230) computes STAMP from
  main.dart and PREV from the last delivery-log row, and at lines 226-230 does
  `if [ "$STAMP" = "$PREV" ]` then echoes "Stamp $STAMP was already delivered,
  and this is a different build." and exits 1. Both were f3.10, so the step
  exited 1.
- That failure is BY DESIGN and comes AFTER the publish. The step's own comment
  (lines 221-223): "This fails AFTER the publish on purpose. The patch is
  already out, so refusing to record it would be the worse lie. Fail loudly."
  Consequences: the run concluded failure; no delivery-log row was written for
  patch 5, so patch 5 was live but unrecorded; and the failure step opened
  issue #277 titled "Preview build failed, nothing shipped to the phone." That
  title is slightly misleading in this case: patch 5 DID ship; it was the
  recording that failed.
- The fix, PR #278 (c945051, "f3.11: record the already-live patch under a
  unique stamp"), changed exactly two files: `git show --stat c945051` lists
  docs/qa-log.md (+1) and flutter/lib/main.dart (2 changed). It bumped
  updateStamp to f3.11 (a genuinely distinct build, since the stamp string
  itself changed) and added the required qa-log row with the agent gate
  recorded as SKIPPED and its reason (no new app behavior to review). On merge
  (af3f40b) the publisher shipped patch 6 under f3.11, wrote the delivery-log
  row, and #277 auto-closed on the green run.
- Reverting #276 was explicitly NOT an option, and this is worth recording
  because it is counterintuitive: a revert is another flutter/ push to main,
  which would run the publisher again under the still-unchanged stamp f3.10 and
  fail the exact same guard. The only way out of a stamp collision is forward,
  with a new stamp.

**Root cause.** A human false belief, not a code defect: "a test-only change
under flutter/ changes no app bytes, so it ships nothing." Two facts break it,
and neither was stated plainly anywhere the plan would be read. First, the
publisher's trigger is flutter/**, so a test-only or docs-under-flutter merge
to main ships just like a lib/ change; there is no "merge flutter/ without
shipping" path. Second, Shorebird patches on build bytes, so "the compiled app
is functionally identical" does not mean "no patch is produced." The existing
rule to bump the stamp "on every push" was overridden by the belief that this
case was exempt, and nothing contradicted the exemption in words.

This is structural, not "someone should have checked harder." The fix that
survives a busy day is a sentence that removes the exemption from the mental
model, backed by the machine that already refuses the collision.

**What went well, credited honestly.** The publisher's one-stamp-one-build
guard is the hero of this session. It caught the collision the instant it
happened, refused to write a delivery row that would have lied (the phone would
have said f3.10 and so would the log, while the phone actually ran the later of
two different builds), and opened a self-closing issue that closed on the fix.
That guard was proven to fail on the branch check before it ever mattered
(flutter/test/publisher_guard_test.dart). This is exactly the kind of guard
this project is built to have: it works when no one is watching, and it worked.

**Lessons, each with its guard and the guard's strength.**

1. There is no "merge flutter/ without shipping" path, and no "functionally
   identical, so no patch" either. Every merge to main that touches flutter/,
   including test-only and docs-under-flutter changes, runs the publisher and
   ships a Shorebird patch, because the trigger is flutter/** and Shorebird
   patches on build bytes. So every such merge needs a unique stamp.
   - GUARD, primary, MEDIUM strength (a rule in CLAUDE.md tied to a specific
     moment). Add to CLAUDE.md's Flutter rebuild rule 1, after the sentence that
     ends "delivery happens at the merge to main, and is not real until that run
     is green", this exact wording:
     "There is no path that merges flutter/ to main without shipping. The
     publisher's trigger is flutter/**, so a test-only or docs-under-flutter
     merge ships exactly like a lib/ change, and Shorebird patches on build
     bytes, so a functionally identical build is still a NEW patch under a new
     patch number. Every merge to main that touches flutter/ therefore needs a
     unique updateStamp, with no exception for test-only, docs-only, or 'no app
     bytes changed' changes. Never plan a flutter/ merge on the belief that it
     ships nothing."
     It is honestly labeled a human lesson: the failure was a belief, and a rule
     is what corrects a belief. It is medium strength because it only works if
     read at the right moment.
   - GUARD, backstop, STRONG and ALREADY IN PLACE (an automated check that fails
     loudly): the one-stamp-one-build record step in flutter-preview.yml:226-230
     already refuses to write a false record and raises an issue. It did its job
     here. No new machine is required for correctness, because the worst
     outcome, a delivery record that silently lies, is already impossible.
   - GUARD, optional strengthening, STRONGEST if built, NOT built this pass and
     offered as a decision to the founder: a pre-merge branch-check step that
     fails the "Flutter check" when a PR touches flutter/ and its updateStamp
     equals origin/main's. That would catch the missing bump BEFORE the merge,
     so no unrecorded patch ever reaches the phone, upgrading the guard from
     "catch after the phone already has it" to "prevent." It is deterministic (a
     string compare against main), so it cannot flake. It is offered, not
     manufactured, because the existing backstop already prevents the only
     UNRECOVERABLE harm (a false record); this would only save the founder the
     scary issue #277 and a false "nothing shipped" message. If accepted, prove
     it fails then passes before trusting it, per the standing rule.

2. Do not tell the founder a delivery OUTCOME that depends on a mechanism not
   fully understood. "Nothing will reach your phone" turned out as wrong, and as
   expensive to a beginner, as a false "it shipped." The project already forbids
   saying a stamp is live before its row exists; this is the same coin's other
   face. Until a delivery row settles the matter, describe the plan ("this is a
   test-only change, banked for the next feature") without asserting the phone
   result.
   - GUARD, MEDIUM strength (a rule; a chat sentence cannot be read by a
     machine). Fold into the existing "never say a version number until its row
     exists" discipline in CLAUDE.md: the same caution applies to asserting
     nothing shipped. The delivery-log row is the only statement about the phone
     that is safe to make, in either direction.

**Residual integrity gap, decided in the open.** Patch 5 shipped and is
permanently absent from the delivery log: the log jumps f3.10 patch 4
(14d53c37) straight to f3.11 patch 6 (af3f40bd), and `git log origin/main`
confirms the two merges af16665 (#276) and af3f40b (#278) between them with no
patch-5 row. DECISION: leave the hole, and record the reason here rather than
backfill it. Reasoning, honestly: (1) patch 5 was functionally identical to
patch 4 and is now fully superseded by patch 6, which the founder confirmed on
the phone, so nothing live depends on it. (2) Patch 5 never carried a distinct
stamp; it shipped under f3.10, which already has its own row for patch 4. There
is nothing the founder could ever look up on the phone that would point at
patch 5, because the phone only ever showed f3.10 for it. (3) The delivery log
is written by the publisher itself and read by automation as ground truth; a
hand-written row would break the "written by the publisher" contract and could
confuse a future read, a worse risk than a one-number gap in Shorebird's patch
counter. The only visible symptom is that the patch numbers skip 5, and this
entry is where a future reader who notices it finds the answer. This retro IS
the backfill, placed where explanations belong.

**CLAUDE.md factual re-check (done as a step, not a favour).** Checked against
the repo this session: flutter-preview.yml does trigger on push to main with
paths flutter/** (lines 10-19), as CLAUDE.md's Flutter rule 1 describes;
.github/workflows/flutter-check.yml exists and runs the branch check;
flutter/test/update_stamp_test.dart and flutter/test/qa_record_test.dart both
exist where CLAUDE.md names them. Every factual claim inspected still matches
the repository. The one gap is not a false claim but a SILENCE: CLAUDE.md
nowhere stated plainly that a test-only or docs-under-flutter merge still ships,
which is what lesson 1's new sentence fills.

**Open lessons carried forward.**
- From session 24: the blocking segmented_test.dart "must stack" assertion at
  large text still measures against a font the phone does not draw. #276 was the
  banked fix for exactly this (it now loads the real font), and #276 is what
  triggered this session's incident. Confirm on a future retro that the
  real-font version is the one gating, and that the fragile "must stack"
  directional assertion was re-anchored to the shipped font rather than deleted.
- New, open until the founder decides: whether to build the pre-merge
  stamp-versus-main branch check (lesson 1's optional strengthening). Until then
  the standing guard is the CLAUDE.md rule plus the already-working publisher
  backstop.

**For the founder, over lunch.** Here is what happened, plainly. Last time we
"banked" a small change that only touched test files, and I told you it would
put nothing on your phone. That was wrong. Any change under the flutter/ folder
that merges into the main line gets shipped to your phone, even if it is just
test code, because the shipping robot watches the whole folder, not just the app
code, and the update tool makes a fresh update whenever the build is even
slightly different, whether or not the app behaves differently. So a build did
reach your phone, but it still carried the OLD name f3.10, the same name as the
one before it. Two different builds with one name is the exact thing our safety
check is built to stop.

And it stopped it. The publisher noticed the name had not changed, refused to
write a record it knew would be misleading, and raised a flag (issue #277). I
fixed it the only safe way, by moving forward: I bumped the name to f3.11 and
shipped once more, which is the f3.11 you just confirmed. Going backwards would
have shipped the same clashing name again and hit the same wall.

Why this is now hard to repeat: I am adding one clear sentence to our rules that
says there is no way to merge flutter/ without shipping, and every such merge
needs a fresh name, with no exception for "it's only tests." That sentence is a
reminder, so it is only as strong as me reading it at the right moment. The
strong part is the safety check that already exists and already caught this; it
does not rely on anyone remembering anything. If that safety check were ever
removed, we would go back to the old danger: your phone could quietly run a
different build than the log claims, and you would have no way to tell. So it
stays. One honest cost remains: there is a one-number gap in the update count
(it skips 5), because that in-between build was never recorded. It was identical
to the one before it and is now replaced by f3.11, so it is harmless, and this
write-up is where that gap is explained so no one is puzzled by it later.

---

## 2026-07-31, session 24: a clean f3.10 patch, and the blocking test that measures a font the phone does not use

**What we believed / What was true.** We believed the seven-issue UI,
accessibility, and visual-regression batch (PR #275, stamp f3.10) would reach
the phone as an over-the-air patch on the merge to main, with no new base APK
needed because the app version stayed 0.9.0+15. This time belief and truth
match. The founder opened the app and the Update stamp reads f3.10. That is the
only proof that counts, and the delivery log backs it exactly:
`| 2026-07-31 15:10 UTC | f3.10 | 4 | patch | 0.9.0+15 | 14d53c37 |`, the last
row of `origin/main:docs/delivery-log.md`. Mode is `patch`, so the installed
0.9.0+15 base APK updated itself on reopen with no manual install, which is what
happened. `git log origin/main` shows the merge commit `14d53c3` (a real merge
commit, PR #275) followed by `58349c1 Delivery: f3.10, patch 4 [skip ci]`. File
and phone agree. This was a clean patch delivery, and that is the finding: no
stamp was stranded, nothing shipped wrong, no divergence between what we
believed shipped and what did.

A clean delivery is a real outcome, not a failure to find problems, and this
session does not invent one. What is worth writing up is a real latent trap that
surfaced DURING development and did not reach the phone: a blocking test that
asserts a layout the phone does not actually produce, because the test renders a
different font than the phone. It caused a golden mismatch mid-build, was traced
correctly, and is still sitting in the suite as a fragile assertion. A near miss
inside the gate is exactly the kind of thing this session exists to name before
it becomes a shipped bug.

Plain-English note on the terms. A "golden" or "pixel baseline" is a saved
screenshot the build compares new renders against, pixel by pixel, so a visual
change reddens the run. A "layout-metric test" does not compare pixels; it reads
positions and sizes off the rendered widgets and asserts things like "these two
labels sit on the same row" or "this label did not clip". The "test font" is the
plain font Flutter loads by default in a widget test; the real app ships Plus
Jakarta Sans ("Jakarta"), which is a different, narrower shape. "Non-blocking"
means a CI step can fail without failing the whole run.

**Timeline (with evidence).**
- PR #275 landed seven fixes, A through F. A hardened the shared `Segmented`
  control so the theme-mode "System" label holds up at large text (a reserved
  check-icon slot on every segment, and `LayoutBuilder` plus `TextPainter`
  measuring fit and stacking vertically only when three labels cannot share two
  rows). B pinned the transfer sheet's Cancel and "Move it" buttons below a
  `Flexible` scroll view and changed the action `Row` to a `Wrap` that was
  overflowing 32 pixels at 1.5x text. C added a "WHAT MATTERS NOW" summary to
  Insights and a real `ErrorState` on `store.loadError`. D made the Income tax
  screen scannable with every BIR string and deadline byte-identical, verified by
  diff. E removed the debug ribbon from the render harnesses via a shared
  `goldenApp()` and `debugShowCheckedModeBanner: false`. F added a deterministic
  opt-in pixel-golden suite.
- Ground truth read, not assumed. The three-command delivery check ran as
  written: `git fetch origin main`, `git log origin/main --oneline`, and
  `git show origin/main:docs/delivery-log.md | tail`. The last row names f3.10 at
  0.9.0+15 against `14d53c37`, patch 4, mode `patch`. The stamp constant in
  `flutter/lib/main.dart:34` reads `f3.10` and is one line, under the 120-char
  cap. The phone reads f3.10. All three agree.
- The new pixel-golden suite is real and committed: `flutter/test/golden/`
  holds `ui_golden.dart`, twelve tracked baseline PNGs under `baseline/`
  (`git ls-files` confirms they are checked in, not ignored), and a scoped
  `flutter_test_config.dart` that installs a 0.5% tolerance comparator so
  sub-pixel anti-aliasing between the sandbox and the runner does not false-alarm
  while a real move (a shifted box, a wrong colour, changed copy) still fails
  loudly. The CI step that COMPARES these baselines is deliberately
  `continue-on-error: true` in `.github/workflows/flutter-check.yml:174-177`, so
  a pixel drift uploads a diff artifact but does not fail the PR. The real gate
  stays the deterministic layout-metric tests, which honours the standing
  anti-flake rule.
- The near miss. During development a golden mismatch on the system-mode
  selector was traced to real-versus-test fonts. The golden suite loads Jakarta
  (`flutter/test/font_compare.dart:24-31` is the same face list), which is
  narrower, so the three labels wrap onto two lines and fit. The blocking widget
  test in `test/segmented_test.dart` loads no real font, so the wider test font
  makes the same three labels STACK vertically instead. The two disagree about
  the layout, and both were "passing" against their own font.
- No inverted or deleted assertion shipped in this PR. The only test-file
  deletions in the diff were whitespace and reformatting. The one assertion that
  looked changed, `find.text('SAFE TO SPEND UNTIL PAYDAY')` in
  `test/insights_screen_test.dart`, was adapted from a top-level find to a
  scroll-to-each loop (see the comment at `insights_screen_test.dart:181-183`)
  because the new WHAT MATTERS NOW summary pushed that card below the test
  viewport fold. It still asserts the card renders. That is a legitimate
  adaptation to a moved layout, not a test rewritten to defend a bug.

**Root cause.** There is no defect on the phone to root-cause, because delivery
was clean and the founder confirmed f3.10. The structural point worth naming is
narrower than a delivery failure and lives entirely inside the test suite: the
gate that decides whether a big-text layout is acceptable measures a font the
phone never renders. Concretely, `test/segmented_test.dart:257-280` asserts that
at 2.0x on a 320dp phone the segments "should stack vertically", checking that
the "Dark" label centre sits more than 48 pixels below the "System" label
centre. That outcome is a property of the WIDE test font. On the phone, with the
narrower Jakarta, the labels wrap onto two lines and do not stack, so the real
render does something the blocking test does not describe. The one render that
uses the real font and would catch this divergence, the golden
`baseline/system-selector-large.png`, is in the non-blocking suite. So the phone
truth is checked by a step that cannot fail the build, and the step that fails
the build checks a font the phone does not use. That is the trap CLAUDE.md's
"prove a new test can fail" section warns about, arriving through the font door
rather than the mental-model door: a test that passes for a reason unrelated to
what the user sees.

Honest scope of the trap. The SIBLING assertions in the same group are safe, and
it is worth saying why so this is not read as wider than it is. The "no overflow
exception" and `didExceedMaxLines` is `false` checks (lines 227-244) are
conservative against the wide test font: a wider font clips sooner, so passing
those with the test font is a STRICTER promise than the phone needs, not a weaker
one. The single fragile assertion is the directional "must stack" one at lines
270-279, because it demands a specific font-dependent outcome that the narrower
real font may legitimately not produce. The fix is not to delete it; stacking at
some scale is genuinely wanted. The fix is to measure it against the font the
phone ships.

**Lessons.**

1. A blocking layout-metric test that asserts a specific font-dependent OUTCOME
   (stacks versus wraps, this label below that one by N pixels) can pass on the
   wide test font while the phone, on narrower Jakarta, lays out differently. The
   real-font render that would catch the split is the pixel golden, which is
   non-blocking by design. GUARD, proposed, NOT built this pass: make the
   directional assertion in `test/segmented_test.dart` (the "horizontal at normal
   scale, stacked at 2.0x" test, lines 257-280) load the real Jakarta faces
   before it measures. The mechanism already exists in the repo and can be copied
   verbatim: `test/font_compare.dart:35-55` loads
   `assets/fonts/PlusJakartaSans-Regular.ttf`, `-Bold.ttf`, and `-ExtraBold.ttf`
   through a `FontLoader` INSIDE `tester.runAsync` (real file reads never
   complete under the fake test clock, per the CLAUDE.md render note). Add that
   `_load(tester)` call at the top of the test, then the stack-versus-wrap
   assertion reflects phone metrics. Prove it fail-then-restore: with the real
   font loaded the assertion should describe what Jakarta actually does, so if the
   current "> 48 pixels" figure was tuned to the test font it will need
   correcting, and that correction is the proof the fonts differed. Strength:
   STRONGEST if built, because it is an automated check on the branch that then
   measures phone reality instead of test-font reality. Until it is built this
   lesson is OPEN, and the honest reason it is open is that the assertion still
   passes today, so nothing forces the work; that is exactly the condition under
   which latent traps survive.

2. When a task asks for a "stable pixel baseline" and CLAUDE.md's standing rule
   says cross-platform pixel goldens are flaky and shots are write-only, the two
   are not actually in conflict once separated, and this session separated them by
   an explicit founder decision (AskUserQuestion): a HYBRID, where the
   layout-metric tests remain the real per-push gate, the pixel baselines live in
   a separate opt-in suite with a documented tolerance, and the CI golden step is
   non-blocking. That decision is now embodied in code (`test/golden/`, the 0.5%
   tolerance comparator, the `continue-on-error` step) but it is NOT written down
   anywhere a future session would read before re-arguing it. GUARD, proposed: a
   short paragraph in CLAUDE.md's "Look at the screen" section stating the
   convention and the reason, tied to the moment "when asked to add or trust a
   pixel baseline". It should say: pixel goldens are allowed as a NON-BLOCKING
   visual reference with a low documented tolerance; they never become the gate;
   the gate stays the deterministic layout-metric tests; and the baseline PNGs
   under `test/golden/baseline/` are committed on purpose while the write-only
   `test/shots/` renders stay gitignored. Strength: MEDIUM, because a CLAUDE.md
   rule works only when someone reads it at the right moment, which is precisely
   the moment a new baseline request arrives. It is worth having anyway, because
   the alternative is re-litigating the anti-flake rule from scratch every time,
   and a re-argument is where a flaky gate slips back in.

**Discipline that held.** Each new guard added in this batch was proven
fail-then-restore before it was trusted, per the CLAUDE.md rule. That is the
discipline whose absence has defended real bugs here, so its holding on a clean
patch is worth recording rather than assuming.

**CLAUDE.md factual re-check (done as a step, not a favour).** The paths and
commands CLAUDE.md names still match the repo. `test/screens_shot.dart`,
`test/palette_contrast_test.dart`, `test/screen_readability_test.dart`, and
`test/journeys_test.dart` all exist where named. The stamp-cap discipline held:
`flutter/lib/main.dart` carries a single-line f3.10 stamp under the cap. The
three-command delivery check ran as written and produced the f3.10 row. No FALSE
factual claim was found in CLAUDE.md this session. One COVERAGE gap, not a false
claim: the "Look at the screen" section still describes only the write-only
`screens_shot.dart` harness and its `--update-goldens` CI run, and does not yet
mention the new committed opt-in pixel-golden suite under `test/golden/` or its
non-blocking CI step. That is the same posture as session 23's prod-flavor gap:
something real that CLAUDE.md does not yet describe, which is why lesson 2 above
proposes writing it down rather than leaving the next session to rediscover it.

**Open lessons carried forward.**
- Lesson 1 of this session is itself open: the font-divergence guard is
  described precisely but not built, and it will stay open until the blocking
  segmented assertion measures against Jakarta. Named here so it is not mistaken
  for done, and so the next session checks whether it was closed.
- From session 23, still open: nothing asserts that the verify-shipped path and
  the base-APK upload path in `flutter-preview.yml` stay EQUAL to each other, so a
  future rename that updates one and not the other could split them. This f3.10
  patch rode the existing paths cleanly, which is evidence they still agree today,
  not evidence the equality is enforced.
- From session 22, the general shape remains open: any Action step that only
  runs on the merge to main is untested by the branch check. f3.10 was a `patch`,
  the low-risk case, so it did not exercise that gap, but the gap is still there
  for the next release-mode ship.

---

## 2026-07-31, session 23: a clean f3.06 ship, and the two silent breaks the gate caught before they could hide

**What we believed / What was true.** We believed the Phase 1 PR2 base APK
(stamp f3.06, app version 0.9.0+15) would reach the phone when PR #271 merged
(merge commit `bd57a7f`) and the founder installed it by hand. This time belief
and truth match. The founder installed 0.9.0+15 and reported the Update stamp
reads f3.06. That install, on the real phone, is the only proof that counts. A
delivery-log row exists to back it:
`| 2026-07-31 05:52 UTC | f3.06 | none | release | 0.9.0+15 | bd57a7f0 |`.
This was a `release` (a new base APK, mode is not `patch`), so it required a
manual install; the founder did that install and confirmed. Contrast session 22,
where the previous base APK's first ship died silently at "Install Shorebird"
and no row was written. This ship wrote its row and the stamp agrees with it.

A clean delivery is a real outcome, not a failure to find problems. What makes
this session worth writing up is that the change was NATIVE (new Gradle flavors
and signing), and native changes only ever prove themselves on the merge to
main, which is the single moment the branch check cannot see. Two separate
breaks that would each have shipped nothing while everything looked green were
caught before the merge, one by the pre-merge audit gate and one during the
build. Both are recorded below with their evidence, because a near miss on the
delivery channel is exactly the shape that has cost real stamps here before.

Plain-English note on the terms. A "flavor" is a build variant: this app now
builds two, `preview` (the founder's over-the-air test channel) and `prod` (the
future Play Store build). "Shorebird" is the service that ships Dart changes as
over-the-air patches to one release per app version. An "app_id" is how
Shorebird knows which app a release belongs to. "OTA" means over the air, a
change that lands without reinstalling.

**Timeline (with evidence).**
- PR2 landed as seven commits `PR2 (1/n)` through the base APK commit `614f1dd`,
  merged as `bd57a7f` (a real merge commit, PR #271), then `fc4691b`
  "Delivery: f3.06, patch none [skip ci]" recorded the ship. `git log origin/main`
  shows all of them in order.
- The change split the Android build into `preview` and `prod` flavors and gave
  each its own signing identity. The preview flavor keeps the committed preview
  keystore so updates install in place; prod gets the real upload identity that
  never enters the repo.
- Near miss 1, caught by the pre-merge gate. The play-launch-auditor agent
  found a hard, delivery-blocking FAIL before merge. The publisher had wired
  `--flavor preview` into its `shorebird release android` and
  `shorebird patch android` commands, but `flutter/shorebird.yaml` had NO
  `flavors:` map. Shorebird needs a `flavors:` entry to resolve an app_id for a
  flavored app, so on the next merge to main `shorebird release android --flavor
  preview` would have been unable to find the app and delivery would have broken,
  on the founder's ONLY live channel, and it would have broken INVISIBLY,
  because the branch check installs Shorebird but never runs a real release. This
  is the SAME shape as session 22's setup-shorebird pin bug: a break only
  provable at the merge to main. The difference this time is that the gate caught
  it pre-merge instead of the phone catching it.
- The fix (`3f065bb`): map `preview` to the existing app_id in
  `flutter/shorebird.yaml`, the SAME id as before, so the existing Shorebird app
  and release history carry over unchanged. `prod` is intentionally absent,
  because the production build is a plain `flutter build appbundle` with no
  over-the-air updater by design; a prod entry would only be added if production
  OTA is ever wanted, with its own id.
- Near miss 2, caught during the build, not by the gate. A flavored build writes
  its APK to `app-preview-release.apk`, not `app-release.apk`. The
  verify-shipped check and the base-APK upload in `flutter-preview.yml` both
  still pointed at the old `app-release.apk`. On a release run that would have
  published to the Shorebird server while the founder's release page received no
  installable APK, which is the exact silent-release failure. Both paths were
  repointed to the flavored name.
- Security gate: the security-privacy-auditor returned CLEAN, 0 must-fix.
  Preview and prod identities are separated at the config, build, and artifact
  layers; no secret leaks; backup exclusion, FLAG_SECURE, and the generic
  lock-screen notification default are untouched. Its one cheap suggestion was
  folded in: the prod AAB preflight now checks all four `SALAPIFY_UPLOAD_*`
  secrets, not just the keystore.
- Ground truth read, not assumed. `origin/main:docs/delivery-log.md` last row
  names f3.06 at 0.9.0+15 against `bd57a7f0`. The founder's phone reads f3.06.
  File and phone agree.

**Root cause.** There is no defect on the phone to root-cause, because delivery
was clean. The structural point worth naming is why two delivery breaks got as
far as an open PR before anyone saw them: a NATIVE, flavored change exercises
code paths (`shorebird release --flavor`, the flavored APK output filename) that
the branch check, by design, never runs. Every "only provable at the merge to
main" gap is the same gap that stranded thirteen stamps once and one base APK
last session. The fix is not "audit harder"; it is to move each such check
earlier so it reddens the PR statically. One of the two was already covered by
that move; the other (the filename) is caught only by a human reading the diff,
and its durable guard is the open lesson below.

**Lessons.**

1. A flavor handed to a Shorebird command with no matching `flavors:` entry in
   `shorebird.yaml` breaks delivery invisibly, because the branch check never
   runs a real release. GUARD, already in place and proven: `flutter-check.yml`
   now has a step "Every Shorebird flavor is mapped in shorebird.yaml" (commit
   `3f065bb`) that greps every `--flavor` the publisher passes to a `shorebird
   release/patch` command, isolates the `flavors:` block in `shorebird.yaml`, and
   fails the PR if any flavor is unmapped. It was proven by deliberate break:
   with no map it reports "missing: preview"; with the map it passes. Strength:
   STRONGEST. It is an automated check that fails loudly on the branch, so it
   works when no one is watching, and it is the exact class of break that session
   22 could only catch on the phone.

2. A flavored build renames its output APK (`app-release.apk` becomes
   `app-preview-release.apk`), and any workflow path still pointing at the old
   name publishes server-side while leaving the founder's release page with no
   installable file. GUARD, already in place: both consumers in
   `flutter-preview.yml` (the verify-shipped check and the release upload) were
   repointed to the flavored name, and the verify-shipped script fails the run if
   the named artifact is missing, so a future rename that misses one path reddens
   the run rather than shipping a phantom release. Strength: STRONG for the
   specific file, because verify-shipped asserts the exact path exists before the
   row is written. Honest limit: nothing asserts that the upload path and the
   verify path stay EQUAL to each other, so a future rename that updates one and
   not the other could still split them. That equality check is not built; noting
   it here so it is not mistaken for done.

3. Because the APK filename changed, the OLD f3.05 asset (`app-release.apk`) was
   left orphaned on the fixed flutter-preview release page, sitting next to the
   new `app-preview-release.apk`. Both are about 87 MB, so size does not tell
   them apart. The founder had to send a screenshot asking WHICH file to install,
   and tapping the older one would have silently left them on f3.05 while
   everything looked done. That is precisely the silent delivery confusion the
   whole delivery-log discipline exists to prevent. GUARD, built this session
   (f3.07): after a successful build the publisher deletes every `.apk` asset on
   the flutter-preview release whose name is not the current base APK
   (`app-preview-release.apk`), so the page only ever shows one installable file.
   It runs on every successful publish (patch and release), continue-on-error so
   a cleanup hiccup can never block or false-alarm a real delivery, and the shell
   selection logic was proven against a mock asset list before trusting it (it
   deletes `app-release.apk`, keeps `app-preview-release.apk`). This f3.07 patch
   run is itself the first exercise of it, and it removes the current orphan.
   Honest recurrence note: the filename is stable going forward, so the orphan
   case only recurs on a FUTURE rename; the guard now handles that automatically.
   The keeper name is hard-coded to match the upload path a few lines above it in
   the same file, so a future rename must change both together.

**CLAUDE.md factual re-check (done as a step, not a favour).** The paths and
workflows CLAUDE.md names still match the repo. `flutter-check.yml`,
`flutter-preview.yml`, `verify-shipped.sh`, and `flutter/shorebird.yaml` all
exist where named. The delivery rule "one RELEASE exists per pubspec version,
later pushes PATCH it" held: f3.06 is a `release` at a new version 0.9.0+15 and
was correctly flagged to the founder as a manual install. The three-command
delivery check ran as written and produced the f3.06 row. Nothing false found in
CLAUDE.md this session. One thing CLAUDE.md does NOT yet describe is the new prod
flavor and the "production has no OTA by design" posture; that is a gap in
coverage, not a false claim, and it belongs in CLAUDE.md once Phase 1 lands
rather than being asserted mid-flight.

**Open lessons carried forward.**
- Lesson 2's honest limit: nothing asserts the verify-shipped path and the
  upload path in `flutter-preview.yml` stay EQUAL to each other. A future rename
  that updates one and not the other could still split them. Not built this
  session; named so it is not mistaken for done.
- From session 22, still holding: the setup-shorebird pin is at the known-good
  `4dd9d7d` (`@v1`, v1.0.1). This session's f3.06 release rode that same pin
  successfully, fresh evidence the fix is still in place. The deeper session-22
  lesson (any Action step that only runs on the merge to main is untested by the
  branch check) is exactly what lesson 1 above turned into a static guard for the
  flavor case; the general version of that gap remains open for any future
  merge-only step.

---

## 2026-07-31, session 22: the first ship failed silently, and the missing row is what told the truth

**What we believed / What was true.** We believed the Phase 1 privacy base APK shipped
the moment PR1 merged (PR #267, merge commit `2e04b41`). It did not. The "Flutter preview
APK" publisher ran, DIED at the "Install Shorebird" step, and shipped nothing, while the
pull request sat there merged and green. No delivery-log row was written, which is exactly
the signal that says "nothing reached the phone." Claude read that absence, found the failed
run had opened issue #268, and did NOT tell the founder anything was live. The fix (PR #269,
merge commit `efafe83`) re-ran the publisher and shipped the f3.05 base APK. The founder
installed `0.8.0+14` by hand and reported "it works now, stamp shows f3.05." That install,
on the real phone, is the only proof that counts, and belief and truth now match.

**Timeline (with evidence).**
- PR1 merged as `2e04b41` (`git show --no-patch --format=%P 2e04b41` gives `394eb9c ebc5cf5`,
  a real merge, not squashed). Seven deliverables, each a commit prefixed `PR1:`, each with a
  guard proven to fail then restored: backup exclusion (`7b02708`), native FLAG_SECURE window
  (`d5bba77`), generic lock-screen notifications (`f0375d8`), explicit targetSdk=36
  (`e83a828`), the merged-manifest allowlist plus SHA-pinned actions plus the PR-safe Flutter
  check (`630738f`), and the QA-gate fixes (`766b48c`).
- The base APK is a `release` in Shorebird terms, so it required a hand install. Prior base was
  f3.02 at `0.7.0+13`; this one is f3.05 at `0.8.0+14`.
- The FIRST preview run failed (run `30599031915`). Per the fix commit `0e28bc7`, it died at
  "Install Shorebird" with `sh: 13: Syntax error: "(" unexpected`, before building or publishing
  anything, and opened issue #268 ("Preview build failed, nothing shipped to the phone").
  Because the publish never completed, no row was written to `docs/delivery-log.md`, and that
  absence, not any alarm, is what said the ship failed.
- Root cause of the failed ship. When PR1 SHA-pinned the eight Actions, the pin for
  `shorebirdtech/setup-shorebird` was resolved by taking `tail -1` of a version-tag list, which
  is not sorted semantically. That picked v1.2.1 (`2950e8a`). But the moving `@v1` tag that
  every prior delivery f3.01 through f3.04 rode points to v1.0.1 (`4dd9d7d`), and the newer
  v1.2.x ships an install script that fails under the runner's `/bin/sh`. So the pin "upgraded"
  the installer to a version no prior ship had ever used, on the one action the branch check
  never ran.
- The fix (`0e28bc7`, merged as `efafe83`) re-pinned setup-shorebird to `4dd9d7d`, the exact
  commit `@v1` resolves to and the known-good version. It also re-checked all eight pins against
  their moving major tags; only setup-shorebird was wrong. `flutter-action` at `9a48871`
  (v2.9.1) had already passed both the branch check and the flutter-setup step of the failed
  preview run, so it was proven working. `flutter-preview.yml` line 79 now reads
  `shorebirdtech/setup-shorebird@4dd9d7d...  # v1 (v1.0.1)`. Re-merging shipped f3.05, run
  `30600383577`, and the row landed.
- Ground truth read, not assumed. `origin/main:docs/delivery-log.md` last row:
  `f3.05 | none | release | 0.8.0+14`. `flutter/lib/main.dart` prints
  `f3.05 · Privacy: backup fully off, lock-screen reminders generic by default, screenshots
  blocked when App Lock is on.` The founder's stamp reads f3.05. File and phone agree.

**Root cause.** A broken delivery-action pin was INVISIBLE to the branch check, because the
branch check (`flutter-check.yml`) never ran `setup-shorebird`. The only place that step ran
was the preview publisher, which only runs on a merge to main, which is the single most
expensive place to discover any failure. The pin was set by a process ("tail the tag list")
that does not equal "what was working" ("what the moving `@vMAJOR` tag points to"), and nothing
between the edit and the founder's phone could catch the difference.

**Lessons.**

1. **When SHA-pinning an action, pin the commit the moving `@vMAJOR` tag resolves to, the one
   already working, never `tail -1` of the patch-tag list.** The tag list is not sorted
   semantically and its last line is not what `@v1` points to. Guard: a rule in CLAUDE.md tied
   to the moment of pinning. Strength: **medium**, because it depends on someone reading it while
   pinning. It is not the primary guard; lesson 2 is.

2. **A broken delivery-action pin now reddens the PULL REQUEST, not the base-APK build on main,
   and that guard was built THIS session.** `flutter-check.yml` gained two steps. First, a
   "delivery-tooling smoke test" that runs `setup-shorebird` with the EXACT same
   pinned action the publisher uses; installing the Shorebird CLI needs no token and publishes
   nothing, so it is safe on every branch and PR, and it fails loudly pre-merge if the pinned
   installer cannot install. Second, a "Publisher and this check pin Shorebird identically" step
   that greps the `setup-shorebird` SHA out of BOTH `flutter-check.yml` and `flutter-preview.yml`
   and fails if they differ, so the pin the smoke test proves is always the exact pin that ships.
   Without the parity step the smoke test could bless a pin that main does not use. The parity
   check was proven both directions locally: matching pins pass, a drifted pin fails. Its
   real-world proof is the failed run `30599031915` (setup-shorebird v1.2.1 failing to install),
   the exact failure this now catches on the branch. Grade: **strong**, a real machine check,
   loud, cheap, token-free, and it runs when no one is watching. This closes the gap that shipped
   nothing on the first PR1 merge.

3. **"Merged is not delivered" worked exactly as designed, and that is the win to record.** The
   missing delivery-log row is what told the truth while the pull request looked clean and
   merged. Claude checked before speaking, found issue #268, and never told the founder f3.05
   was live. Guard: already in place, the delivery-log row as the sole proof of delivery, plus
   the CLAUDE.md rule "never say a version number to the founder until its row exists." Strength:
   the row check is **strong** (a machine writes it or it stays absent); the do-not-say-the-
   number rule is **medium** and held here.

4. **The merged-manifest check earned its keep on its very first real run.** It was built for
   one belief the founder flagged, "do not assume the source manifest equals the shipped
   manifest," and it caught a real gap four CI rounds running, each surfacing something the
   4-permission, 2-component SOURCE manifest never showed but the SHIPPED app actually contains.
   In order: a wrong-file bug where `find` matched a plugin's library manifest, fixed to search
   `flutter/build/app` only plus a guard that rejects any manifest with no `<application>`
   element (`8307a49`); then `USE_FINGERPRINT`, the legacy pre-API-28 biometric permission
   `local_auth` merges (`b1f4fc7`); then the app-scoped `...DYNAMIC_RECEIVER_NOT_EXPORTED_
   PERMISSION` that AndroidX Core auto-generates, plus a change to report ALL offenders at once
   rather than one per five-minute native build (`85d2526`); then four AndroidX framework
   exported components, WorkManager's `SystemJobService` and `DiagnosticsReceiver`, Glance's
   `GlanceRemoteViewsService`, and ProfileInstaller's `ProfileInstallReceiver` (`ebc5cf5`). The
   shipped app carries nine `android.permission.*` entries plus one app-scoped signature
   permission and six exported components; the source declares four permissions and two exported
   components. Each addition was vetted with a reason string in the allowlist. Guard: the check
   itself, `.github/scripts/check-merged-manifest.sh`, driven on the branch by
   `test/merged_manifest_guard_test.dart` and run after the native APK build. Strength:
   **strong**, and the allowlists are TYPED sets, so a new permission or a newly-exported
   component reddens CI until a human decides it belongs. It is a promise, not a guess.

5. **The pre-merge multi-agent gate caught two real issues before the ship.** Recorded in
   `766b48c`: the permission allowlist grep only inspected the `android.permission.*` namespace,
   so an OEM or custom permission (a vendor badge permission, a `${applicationId}.permission.*`)
   would slip through, defeating the guard; fixed to compare the FULL `android:name` and proven
   with a new case that fails on `com.sec.android.provider.badge.permission.WRITE`. And the
   detailed-notification channel used `VISIBILITY_PRIVATE` with copy promising "visible only
   after you unlock," but PRIVATE only redacts when the user has separately turned on "hide
   sensitive content," so on a show-everything phone the body would still show on the lock
   screen; fixed to `VISIBILITY_SECRET`, which Android keeps off the lock screen regardless of
   the user's setting. Both fixed and re-proven. Guard: the gate itself, recorded as a
   `docs/qa-log.md` row that `flutter/test/qa_record_test.dart` enforces. Strength: **medium**,
   because the gate is a process, but the qa-log row that proves it ran is machine-enforced.

6. **The old test that ENFORCED the leak was inverted, and that is the sharpest evidence in the
   arc.** Before f0375d8, `test/reminders_test.dart` asserted the peso amount, the person's
   name, and even a raw due date belonged in the notification title and body, with no visibility
   set, so they rendered on the lock screen. The diff shows the removed assertions on lines like
   `"$person's $amount is due tomorrow."` and `'$person owes you $amount and it is due today.'`.
   The suite was defending the defect, not merely missing it. The test now asserts the DEFAULT
   reminder names no debt and no amount, proven to fail then restored. Guard: the inverted test.
   Strength: **strong**.

7. **A one-off flake was investigated, not waved away.** A `tax_screens_test` parallel-timing
   flake was chased down, found to pass standalone and on re-run, and dismissed as a timing
   artifact rather than a real defect. No guard needed; recorded so a future session does not
   re-chase it.

**CLAUDE.md factual re-check (done as a step, not a favour).** The paths CLAUDE.md names all
resolve on `origin/main`: `.claude/hooks/guard-destructive-edits.sh`, `flutter/lib/main.dart`
(the `updateStamp` constant), `flutter/test/update_stamp_test.dart`, `flutter/shorebird.yaml`,
both workflow files, and the native `MainActivity.kt` under
`kotlin/dev/icedamericano/salapify/`. The delivery-check-in-three-commands still reads the file
the publisher writes. One thing changed and is worth flagging: `flutter-check.yml` now ALSO
carries a `pull_request` trigger with a shared concurrency group
(`flutter-check-${{ github.head_ref || github.ref_name }}`, cancel-in-progress) so push and PR
for the same commit do not double-run. CLAUDE.md's sentence "Pushes to a claude/** branch run
the Flutter check action" is still TRUE (the push trigger is intact), but it no longer tells the
whole story now that PRs trigger it too, and it does not yet mention the new delivery-tooling
smoke test or the pin-parity step. Not a falsehood, an omission worth a future edit.

**Open lessons carried forward.**
- **Open 4, nothing compares the phone to main: STILL OPEN.** It remains the one check only the
  founder can do. The f3.05 stamp the founder read off the installed base APK is exactly that
  check done by hand again, and this arc is a reminder of why it is irreplaceable: the machine
  said "merged," the founder's phone said "nothing," and only the founder could close that gap.
- **Open 7, guard sets are typed lists: ADVANCED this session.** The merged-manifest allowlists
  (`ALLOWED_PERMS`, `ALLOWED_EXPORTED_SHORT`, `ALLOWED_EXPORTED_FULL`) are typed sets that redden
  CI on any addition, which is a new promise in the strongest style. The remaining half is the
  screen sweep's screen list, still a derived-versus-typed gap. STILL HALF CLOSED.
- **Open 8, the edit-pattern hook: CONFIRMED STILL PRESENT.**
  `.claude/hooks/guard-destructive-edits.sh` resolves on main. A future session should still trip
  it deliberately rather than assume it bites.
- **Open 10, whether onboarding sample data survives launch: STILL OPEN.**
- **Open 11, the account focus-scroll cannot reach a row far below the fold: STILL OPEN.**
- **Open 13, no test asserts `allowBackup=false`: SUPERSEDED.** The narrow string assertion from
  session 21 is now subsumed by two broader guards shipped in this arc:
  `test/backup_posture_test.dart` checks the full backup posture (allowBackup=false plus the
  `res/xml/backup_rules.xml` and `res/xml/data_extraction_rules.xml` for Android 11 and 12+), and
  the merged-manifest check asserts `allowBackup="false"` in the actually-shipped manifest. The
  broader guards make the narrow one redundant, which is the right direction.
- **The delivery-action smoke-test guard (raised and CLOSED this session).** The gap that a
  broken delivery-action pin could only be found by shipping to main is now closed by the two
  new `flutter-check.yml` steps described in lesson 2 (the Shorebird install smoke test and the
  pin-parity check). Recorded here so a future audit knows to trip it deliberately, and to make
  sure neither step is ever quietly deleted or routed around, since a deleted guard is the most
  valuable thing a later session can find.

**For the founder, over lunch.** The privacy update reached your phone as f3.05, and you
installed it by hand because it is a new base app, not a small over-the-air patch. Here is the
honest version of what happened. When PR1 merged, the machine that builds and ships the app
tried to run and DIED at the very first step, installing a tool called Shorebird, so nothing
was sent to you. It looked fine from the outside: the pull request was merged and green. The
thing that told the truth was a small log file the shipper writes only when it actually ships,
and this time it wrote nothing. Claude saw that blank, found the failed build had already
filed a report (issue #268), and did not tell you anything was live. That is the system working:
merged is not delivered, and the blank row is what proves it.

Why did the shipper die? In PR1 we "pinned" each helper tool to an exact version so nobody can
swap it under us. For one tool the pinning picked the WRONG exact version, a newer one no
previous update had ever used, and that newer one has an install script that breaks on the build
machine. The fix was to pin it back to the exact version every earlier delivery had ridden
safely. Then the shipper ran clean and f3.05 went out.

What now makes this impossible to repeat quietly, and what it costs if removed. Two things were
built this session. The permission guard, the one that reads the app as actually built rather
than as written, earned its place on its first real run by catching four real differences
between the source and the shipped app, each vetted and written down, so the app now ships
exactly nine phone permissions and six system components and not one more without a human
agreeing first. And the exact failure that hid the ship, a bad Shorebird pin, is now caught on
the pull request BEFORE it can merge: the branch check installs that tool as a free dry run and
also confirms the shipper and the check point at the very same version, so a broken or drifted
pin turns the pull request red instead of silently shipping you nothing. If either of those
guards were ever deleted, we would be back to finding these problems the expensive way, on your
phone, a day late. Until any hand-install like this one, the safety net stays the same: nothing
is called delivered until the row exists and your phone shows the stamp.

## 2026-07-30, session 21: a separate mind found four ways to lose your money, on the change most likely to

**What we believed / What was true.** We believed the encrypted-at-rest store shipped
as f3.02, a new base APK the founder installed by hand, and that the encrypted database
actually opened and the old data moved into it on the founder's real device. The founder
sent a screenshot of the update card reading `Update stamp: f3.02` and
`Storage: Encrypted (moved this run)`, then after the f3.03 patch reported "yes it works"
on reopen. Belief and truth match, on the phone, both times. That is the proof that
matters: not a green runner, but the encrypted engine opening, the migration completing,
and the plaintext retirement landing on the actual device. Both f3.02 (encryption) and
f3.03 (plaintext retired) are confirmed on the founder's phone, so the whole
durable-encrypted-store phase is delivered AND phone-verified.

**Timeline (with evidence).**
- Merge commit `22f7352` (`git show --stat 22f7352` shows `Merge: 8f915b4 f5c2cd1`, a
  real merge, not squashed), "PR B2: encrypted-at-rest store (SQLCipher + Android
  Keystore), f3.02". Fourteen files: the native adapter
  `flutter/lib/data/sql_cipher_ledger_repository.dart`, the pure-Dart brain
  `flutter/lib/data/encrypted_store_coordinator.dart`, `frozen_plaintext_store.dart`,
  `storage_bootstrap.dart`, a `Storage` readout in `flutter/lib/screens/update_card.dart`,
  `flutter/android/app/src/main/AndroidManifest.xml`, `pubspec.yaml` (0.6.3+12 to
  0.7.0+13), and three test files.
- Delivery read, not assumed. `origin/main:docs/delivery-log.md`:
  `f3.02 | none | release | 0.7.0+13` (a base APK) and
  `f3.03 | 1 | patch | 0.7.0+13` (over the air). The founder's manual install of f3.02 is
  what the screenshot confirms.
- The engine is untestable on the runner: SQLCipher (an encrypted SQLite library) and the
  Android Keystore (the phone's hardware-backed key vault) need a real device and native
  libraries the headless runner does not have. So the discipline was thin-native,
  fat-pure-Dart: `sql_cipher_ledger_repository.dart` is a thin key-value adapter that makes
  no decisions, and ALL the migrate-versus-read-versus-fallback logic lives in
  `encrypted_store_coordinator.dart`, which is pure Dart and proven with fakes.
- A THREE-agent pre-merge gate ran as a real gate: security-privacy-auditor, qa-tester,
  and principal-engineer, recorded as the f3.02 row in `docs/qa-log.md`. On a change that
  had already passed `flutter analyze`, 1319 tests, and a break-first proof, the gate found
  FOUR must-fixes, all fixed and re-proven before merge.
- Finding 1, SECURITY (privacy-lens only). The manifest had no `allowBackup=false`, so the
  still-present plaintext ledger and the secure-storage prefs were eligible for Android Auto
  Backup to the user's Google Drive, which flatly contradicts encrypted-at-rest. Fixed:
  `android:allowBackup="false"`.
- Finding 2, DATA-LOSS. A stale B1-era undo snapshot leaked through the frozen fallback, so
  a healthy user could be offered, and tap, a revert to pre-upgrade data. Fixed by scoping
  `readUndoSnapshot` to the encrypted era only, proven by a new test.
- Finding 3, DATA-LOSS. If the encrypted store became unopenable later (Keystore key loss),
  the app silently served the stale plaintext WHILE WRITABLE, losing post-migration writes
  and flip-flopping. Fixed by making the store READ-ONLY when it serves the fallback because
  encrypted is unavailable (`store.dart`: `canWrite` is false when `storageDegraded`), and
  by `storage_bootstrap.dart` serving an `_UnavailableEncryptedStore` stand-in, not a
  writable plaintext store, when the DB exists but will not open. Proven by a store-level
  test.
- Finding 4, DATA-LOSS. `clearLedger` cleared encrypted THEN fallback, so an
  encrypted-clear failure left the plaintext full and the next launch migrated it back:
  erase-then-resurrect. Fixed by clearing the fallback FIRST. The existing SAFETY test could
  not catch this, because its mock never threw on clear, so it never exercised the failing
  order. A NEW test makes the clear throw, backed by a `failClears` flag on the fake that
  the old mock lacked.
- The build risk was largely closed BEFORE merge, not after. `flutter-check.yml` (the branch
  check) runs `flutter build apk --debug` when the diff touches `android/` or `pubspec.yaml`,
  so the Android build compiled the SQLCipher AAR and merged the manifest on the branch. That
  step being green was made the real pre-merge gate for this native PR; analyze-plus-test
  alone is not enough when native code changes.
- f3.03 (merge `0bdb02b`) retires the plaintext safety copy, self-gated. The coordinator
  deletes the fallback ONLY on a steady-state encrypted read, which by construction never
  runs on the migration launch and never when encrypted is unavailable. So the copy cannot be
  removed until encryption has survived a full app restart on the device. Proven by a
  deliberate break: adding the retire call to the migration branch failed the "migration run
  keeps the fallback" tests, then it was restored. The founder's "yes it works" on reopen is
  the phone confirmation.

**Root cause.** There is no failure to explain here, and the session does not manufacture
one: the delivered app is correct and confirmed on the phone. The real subject is the same
one session 20 raised, now reinforced on the highest-stakes change in the phase. Four genuine
data-loss-or-privacy defects survived `flutter analyze`, 1319 passing tests, AND a
break-first proof, and were caught only because a SEPARATE adversarial mind read the design
before merge. Tests written by the author of a change encode the author's mental model, so
they pass hardest exactly where the model is wrong. Finding 4 is that failure caught in the
act: a green SAFETY test was defending nothing, because its mock could not throw on clear.
And Finding 1 adds a dimension tests almost never carry at all: a privacy-lens reviewer
asked "where could this data leak OFF the device" and found Auto Backup, a question no
functional test was ever going to ask.

**Lessons, each with its guard.**

- **Lesson 1. The multi-agent pre-merge gate earned its keep again, on the change most able
  to hurt the founder. Run it before any storage, migration, or security change, without
  exception.** Guard: a RULE (the qa-log row is already enforced by `qa_record_test.dart`,
  but that enforces a row exists, not that three adversarial lenses were applied). Strength:
  MEDIUM, and honestly so. The gate is human judgement by construction; no test can assert
  "an adversary genuinely tried to break this design." What CAN be a machine is the single
  most mechanical thing the gate found, see Lesson 2.

- **Lesson 2. The `allowBackup=false` regression is now caught by a test, not by a reviewer
  remembering.** This is the one finding that is a fixed string in a file and therefore
  machine-checkable, and it was the highest-stakes finding of the arc: if that attribute is
  ever dropped, the whole ledger silently becomes Google-Drive-eligible again with every
  other check still green. Guard ADDED this session:
  `flutter/test/widget_manifest_test.dart` (which already reads `AndroidManifest.xml` off
  disk and runs on the branch check) now asserts the manifest contains
  `android:allowBackup="false"`. Strength: STRONG, it fails loudly when no one is watching.
  Proven by flipping the manifest to `allowBackup="true"`, watching the test redden, then
  restoring. This closes Open 13 in the same session it was raised.

- **Lesson 3. Thin-native, fat-pure-Dart is the pattern for anything the runner cannot
  execute.** The encrypted engine cannot run in CI, so its decisions were lifted into a pure
  coordinator that IS fully tested, leaving the native part a thin adapter with no logic to
  get wrong. Guard: a RULE, now demonstrated in code as the reference. Strength: MEDIUM, but
  the pattern is self-reinforcing because the pure half is where all the tests already are.

- **Lesson 4. A mock that cannot exhibit the failure is a test that proves nothing.** Finding
  4's old SAFETY test passed because its fake never threw on clear. The repo already teaches
  "prove a new test can fail"; this is the same rule pointed at the FAKES, not just the code
  under test. Guard: covered by the existing prove-it-fails discipline; the concrete fix
  (`failClears` on the fake) is now in the suite as the worked example. Strength: MEDIUM,
  unchanged rule, now with a second instance on record.

- **Note on delivery mechanics (they worked, recorded so a future reader is not confused).**
  A native change cannot ship over the air, so f3.02 was mode `release`, a fresh base APK the
  founder installed by hand. A pure-Dart change ships over the air, so f3.03 was mode `patch`
  on top of that base. The patch number RESET to 1 on f3.03 (f3.01 was patch 24) because
  Shorebird numbers patches per base version, and 0.7.0+13 is a new base: patch 1 of the new
  release, not a regression. Nothing went wrong here; the reset is expected.

**Open lessons carried forward.**
- **Open 4, nothing compares the phone to main: STILL OPEN.** It remains the one check only
  the founder can do, and the f3.02 screenshot plus the f3.03 "yes it works" are exactly that
  check done by hand.
- **Open 7, guard sets are typed lists: STILL HALF CLOSED.** Unchanged this session.
- **Open 8, the edit-pattern hook: CONFIRMED STILL PRESENT.** A future session should still
  trip it deliberately rather than assume it bites.
- **Open 10, whether onboarding sample data survives launch: STILL OPEN.**
- **Open 11, the account focus-scroll cannot reach a row far below the fold: STILL OPEN.**
- **Open 12, ADR 0001 lived only on an un-merged branch: CLOSED.** It landed on main in
  commit `ead5ac4`; `git show origin/main:docs/adr/0001-durable-encrypted-store.md` now
  returns the document.
- **Open 13 (new), no test asserts `allowBackup=false`: CLOSED this session.** The strongest
  single finding of this arc was a fixed string that nothing guarded. `widget_manifest_test
  .dart` now asserts `android:allowBackup="false"`, proven to fail against `allowBackup="true"`
  then restored. Raised and closed in the same session, which is the whole point of turning a
  lesson into a machine.

**For the founder, over lunch.** Your encryption is real and it is on your phone. The
screenshot you sent, "Encrypted, moved this run", and your "yes it works" after the follow-up,
are the proof: your old data was copied into an encrypted database, the app opened it on your
own device, and the leftover plain copy is now cleaned up. That is the whole phase, done and
seen on the phone, not just believed from the repo.

Here is the honest part. Before this shipped, three separate reviewers went looking for ways
it could lose or leak your money data, and they found FOUR, on a change that had already
passed every automatic check I have. One would have let your data get copied to Google Drive
in plain text. One could have offered you a button that quietly wiped your current data back
to an old version. Two more could have brought back money you had just erased. None of these
were in the app you are using, because they were caught and fixed first. What makes them
impossible from here: all four are now permanent tests that fail loudly if anyone ever
reintroduces them. The Google Drive leak was the last one without a test, so I added it this
session, a one line check that the backup-off setting stays off, and I proved it by turning
the setting back on and watching the test go red. So the single soft spot the review found is
now guarded by a machine, not by anyone remembering.

---

## 2026-07-30, session 20: every green check passed, and the design could still lose your money

**What we believed / What was true.** We believed f3.01 shipped as patch 24, over
the air, on the existing base APK 0.6.3+12. The founder confirmed the same stamp on
the phone: f3.01, patch 24, mode `patch`, base 0.6.3+12. Belief and truth match.
This is a CLEAN delivery, mechanically. No manual install is owed, nothing was
stranded, and the shipped code is safe. Said plainly so it is not buried: the app on
the phone is correct. This entry is about what the FIRST version of this batch nearly
did, and why the checks we normally trust could not see it.

**Timeline (with evidence).**
- Merge commit `f1e7cad`, "PR B1: durable crash-safe file store as a validated shadow
  (f3.01)", has two parents (`git show --stat f1e7cad` shows `Merge: 1ea0ae4
  8eb9330`), so it merged and was not squashed. Seven files, 704 insertions:
  `flutter/lib/data/file_ledger_repository.dart`,
  `flutter/lib/data/durable_ledger_repository.dart`, `flutter/lib/main.dart`, three
  test files, and the qa-log row.
- Delivery confirmed by reading, not assuming:
  `f3.01 | 24 | patch | 0.6.3+12`, the last line of `docs/delivery-log.md` on
  `origin/main`, run id 30556207033. The patch number in the file equals the number
  on the phone, which is the only real proof and the one the founder supplied.
- The FIRST design of B1 made the new file store AUTHORITATIVE and dual-wrote to
  SharedPreferences as a "revert mirror." It passed `flutter analyze`, the full suite
  of 1301 tests, and a deliberate-break proof, and the founder had approved the plan.
- A pre-merge GATE was run as an actual gate, per the founder's standing instruction:
  the qa-tester and principal-engineer agents reviewed the design INDEPENDENTLY. Both
  found the same root flaw and two concrete data-loss paths. Finding 1, silent loss:
  a file that was valid but OLDER than SharedPreferences (after a code rollback, or a
  session where the file store failed to open and only SharedPreferences advanced)
  was trusted over the newer copy and then overwrote it. Finding 2, resurrection: a
  "start fresh" interrupted partway left the file cleared and SharedPreferences
  intact, which the next launch misread as a first run and used to bring the
  just-erased ledger BACK.
- Both findings were REPRODUCED in a throwaway test before any change was made, so
  neither was a code-reading guess. This is prove-it-before-you-fix-it applied to a
  REVIEW finding, not just to our own tests.
- The response was a REDESIGN, not a patch. SharedPreferences stays the single source
  of truth and every read comes from it, exactly as before; the file store became a
  SHADOW, written alongside and never read back as truth in B1. Confirmed in
  `durable_ledger_repository.dart`: `source` is authoritative, `shadow` is "never read
  back as the source of truth in B1." Both findings are kept as regression tests
  (`durable_ledger_repository_test.dart` lines 124 and 135, "FINDING 1 regression" and
  "FINDING 2 regression"), proven to fail against the old shadow-wins behaviour, then
  restored.

**Root cause.** The two data-loss paths share one cause: two independently-writable
stores with no reliable which-is-newer signal. But the retrospective's real subject is
one level up. All four checks this project trusts (analyze, 1301 tests, a break-first
proof, and founder approval) test the code AS WRITTEN against futures the author
imagined. A data-loss DESIGN flaw lives in the futures the author did not imagine: a
rollback to an older file, a start-fresh interrupted halfway. A test written by the
same mind that wrote the flaw will not contain the adversarial future that exposes it,
because that mind already believed the future could not happen. That is the structural
reason the green checks were blind, and it is the same failure mode as "a test written
from the same wrong mental model as the code passes for the wrong reason," which this
repo has hit before. Green here did not mean safe. It meant consistent with one
person's imagination.

### Lesson 1. A separate adversarial mind, run as a real gate, caught what no automated check could. WIN, and the guard has two strong halves and one weak one.

**Evidence.** Two independent review agents each found the same root flaw and the same
two paths, on a design that had already gone green four ways. The catch worked for one
reason: the gate was actually RUN as a gate this time, not skipped. The qa-log row for
f3.01 records it: "THE GATE DID ITS JOB, and this row is mostly about that."

**Guard, honestly graded in three parts.**
- The bug CLASS was removed by design, not patched. For an over-the-air step we chose
  not to need a which-is-newer signal at all: keep the one existing source of truth and
  treat the file as a copy. A stale or half-cleared shadow now cannot override or
  resurrect anything, unconditionally. This is the strongest kind of fix, a structural
  one, because the whole family of bugs is gone rather than blocked.
- The two specific paths became regression tests, proven to fail against the old
  behaviour. Strongest strength, an automated check that fails loudly, and it turns a
  one-time human catch into a permanent machine guard for exactly these two paths.
- The META guard, "run an adversarial data-loss review before merging any change to how
  the app persists data or which store it trusts," is a RULE, medium strength, and it
  is honest to say it cannot easily be mechanized. No test can generate the unimagined
  adversarial future; that is precisely what a fresh mind is for. The `qa_record_test`
  guard forces a qa-log ROW to exist, but a row is not proof a real adversarial review
  happened, only that someone wrote a row. So the machine can tell you the gate was
  claimed, never that it was real. The strongest available written form: any PR that
  adds a second writable store, or changes which store answers reads, must pass an
  independent data-loss review before merge, and the review must name at least one
  rollback future and one interrupted-write future by hand. That is the durable guard
  beyond "remember to run the agents," and it is still a rule, not a machine, said
  plainly rather than dressed up as one.

### Lesson 2. Prove-it-before-you-fix-it was applied to someone else's finding, and that is why the redesign is trustworthy. NOTE, discipline win.

**Evidence.** Both review findings were reproduced in a scratch test before a line
changed. The value: a finding you have watched fail is a fact; a finding you have only
read is a belief, and this project has shipped code and tests built from beliefs that
turned out wrong. Reproducing first is what let the redesign claim it removed the
paths rather than hoped it did, and the same two tests now guard them.

**Guard.** None new needed. The existing "Prove a new test can fail before trusting
it" rule already covers this; this entry only records that it was extended, correctly,
from our own tests to a reviewer's claim, and that the extension is worth keeping.

### Lesson 3. Two limits were written down instead of hidden. NOTE, and this is the healthy behaviour.

**Evidence.** `file_ledger_repository.dart` lines 12 to 14 state the honest limit:
`flush:true` fsyncs the temp file's BYTES, but dart:io has no API to fsync the
DIRECTORY entry the rename creates, so a hard power loss in the instant after
`rename()` returns can still lose the update. And the qa-log row states the
verification limit: "self review on a runner, not a hand test on the phone." Neither
was smoothed over.

**Guard.** None warranted; recording the limits IS the guard, because the expensive
version of both is the unstated one. The fsync gap is bounded anyway: the file is a
shadow that is never read as truth in B1, so a lost directory update costs a copy, not
the ledger. Worth revisiting when B2 promotes the file to authority, where the same
gap would cost real data.

**Open lessons carried forward.**
- **Open 4, nothing compares the phone to main: STILL OPEN.** The comparison remains
  the one thing only the founder can do, and they did it here.
- **Open 7, guard sets are typed lists: STILL HALF CLOSED.** Unchanged this session.
- **Open 8, the edit-pattern hook: CONFIRMED STILL PRESENT.** Checked this session:
  `.claude/hooks/guard-destructive-edits.sh` still exists on disk. Existence is not
  the same as firing; a future session should still trip it deliberately rather than
  assume it bites.
- **Open 10, whether onboarding sample data survives launch: STILL OPEN.**
- **Open 11, the account focus-scroll cannot reach a row far below the fold: STILL
  OPEN.** No change this session.
- **Open 12 (new), ADR 0001 lives only on an un-merged branch.** The design document
  this whole phase follows (ADR 0001) exists on the `claude/phase-2-durable-store`
  branch (PR #259) and never reached `main` (`git show origin/main:docs/adr/...` is
  absent, and there is no `docs/adr/` directory on main). Yet main now carries code
  comments, a stamp, and qa-log rows that all cite "ADR 0001, PR B1" with authority.
  A reader on main is pointed at a document they cannot open. This is the same shape
  as the stale-CLAUDE.md trap: a confident reference to a real thing that is not where
  it is said to be. The fix is cheap, land the ADR on main in its own small PR, and
  until then this is a tracked documentation gap, not a defect in the app.

**For the founder, over lunch.** f3.01 is clean. You confirmed patch 24 on your phone,
the delivery log agrees, and there is no bug in what you are using. Everything below is
about a bug we did NOT ship, and why almost catching it should scare us a little.

The first version of this batch stored your ledger in a new crash-safe file and made
that file the boss. It passed every check we normally trust: the code analyzer was
clean, all 1301 tests were green, we deliberately broke the code to prove a test would
catch it, and you had approved the plan. And it still had two ways to permanently lose
your money. One, after certain rollbacks an OLDER copy would win and overwrite your
newer data. Two, if a "start fresh" was interrupted halfway, the next launch could
bring your just-erased data back from the dead. Both are exactly the kind of thing you
would only find out about long after it hurt you.

None of our automatic checks saw it, and here is the uncomfortable reason: a test can
only check for a future someone thought of, and the person who wrote this code had not
thought of these futures, which is why the code was wrong. What caught it was sending
the design to two separate reviewers whose entire job was to imagine the futures the
author did not. They both found the same two holes, independently, and only because we
actually ran that review as a required gate this time instead of skipping it.

We fixed it the strong way. Instead of trying to teach the two stores which one is
newer (hard, and the hard part is where the bugs were), we kept your existing store as
the one and only truth and turned the new file into a plain backup copy that is written
but never trusted yet. The whole family of "which one is newer" bugs is simply gone for
this step. The real reconciliation waits for the next phase, which uses a proper
database built for it. The two specific holes are now permanent tests that go red if
anyone ever reintroduces them.

What now makes it hard to repeat: the two holes are guarded by tests forever, and the
whole class of bug was designed out. What we could NOT turn into a machine is the thing
that actually saved us, a fresh pair of eyes reviewing the design for disasters the
author could not picture. We wrote that down as a firm rule (any change to how your
data is stored gets an independent data-loss review first), but a rule is only as good
as our willingness to run it. If we ever skip that review to save time on a
data-storage change, the cost is the one we just dodged: a build that is green in every
visible way and still quietly capable of losing everything you have tracked.

---

## 2026-07-30, session 19: a clean patch, and the guards that caught the near-misses before the phone did

**What we believed / What was true.** We believed f2.97 shipped as patch 21,
over the air, on the existing base APK 0.6.3+12, with zero defects. The founder
confirmed the same stamp on the phone: f2.97, patch 21, mode `patch`, base
0.6.3+12. Belief and truth match. This is a CLEAN patch. Nothing bad reached the
phone, no manual install is owed, and nothing was stranded. Said plainly so it is
not buried under the process notes below: the app work was correct, and the point
of this entry is the machinery around it, not a defect in it.

**Timeline (with evidence).**
- Merge commit `65f2973`, "Phase 0: trust the routes (#256)", has two parents
  (`git rev-list --parents -n 1 65f2973` returns three hashes), so it was a merge
  commit and not a squash.
- `git diff --stat 65f2973^ 65f2973`: 17 files, eight fixes across
  `flutter/lib/screens` (overview, search, accounts, insights, onboarding, pan,
  plus the new `pan_routes.dart`), six new or updated test files, and a
  PostToolUse hook (`.claude/settings.json`, `.claude/hooks/watch-created-pr.sh`).
- Delivery row confirmed by reading, not assuming:
  `f2.97 | 21 | patch | 0.6.3+12`, the last line of `docs/delivery-log.md` on
  `origin/main`. Delivery commit `6a5bb05`. The patch number in the file equals
  the patch number on the phone, which is the only real proof and the one the
  founder supplied.

**Root cause.** There is no defect to trace to a root cause, and manufacturing
one would break the single rule of these sessions. What follows are process
findings, each weighed honestly for whether it earns a durable guard or is only a
note.

### Lesson 1. Two existing guards fired on their own and stopped work at the gate. WIN, CLOSED.

**Evidence.** `screen_readability_test.dart` failed the build because the new file
`flutter/lib/screens/pan_routes.dart` was neither swept nor exempted. The failure
forced an explicit decision, recorded in the test:
`'pan_routes.dart': 'no widgets, the Pan CTA destination registry'`. Separately,
`qa_record_test.dart` failed because the f2.97 stamp bump had no row yet in
`docs/qa-log.md`; the row was written and the build went green.

This is the "a derived set is a rule, a typed set is a promise" pattern from f2.96
working exactly as designed, twice, unprompted. A file appeared and the readability
sweep refused to pass until a human said in writing why it does not need sweeping.
A stamp bumped and the QA gate refused to pass until a QA row existed. Neither
needed anyone to remember them.

**Guard.** Already built and already firing. No new guard needed; recording that
these two held is the whole value, because a guard that quietly stops mattering is
the most expensive thing this file can miss, and the opposite happened here.
Strength: strongest, an automated check that fails loudly, and now with a fresh
proof it still bites. CLOSED.

### Lesson 2. The account focus-scroll cannot reach a row far below the fold, and that is documented rather than hidden. OPEN as a tracked limitation.

**Evidence.** In `accounts.dart`, in code, in the honest words the author chose:
"Best effort, and honestly so: the list is a lazy ListView, so a row far below the
fold has no element yet and currentContext is null." When Search asks Accounts to
reveal a matched account, `Scrollable.ensureVisible` needs the target row's build
context; a lazy `ListView` has not built rows that are off screen, so for a user
with 30 or more accounts a match near the bottom flashes nothing. Three review
agents (qa-tester, flutter-ux-craftsman, release-manager) found this as one of four
nice-to-have items and zero must-fix. It was deferred at merge on purpose.

Why it is genuinely fine to ship: the account is still shown in Search, tapping it
still opens the Accounts screen, and the only thing lost is the scroll-and-flash on
a very long list. Nothing is wrong, one nicety is absent in one uncommon case.

**Guard.** A note in code is the weakest of the three guard strengths (a habit
written down), and it is honest to say so: nothing fails if the limitation is
forgotten, because there is nothing failing. The right stronger guard, if this is
ever fixed, is a test that builds a fixture of 30-plus accounts, asks Search to
reveal the last one, and asserts the row became visible; that test would redden
today, which is exactly why it is not written yet. Carried forward as Open 11, a
tracked follow-up, not a defect. If the long-list case is never worth building, say
that out loud and close it; do not let it drift.

### Lesson 3. Onboarding now stores 0 to mean "no budget" instead of fabricating 20000, and this changed no data shape. NOTE, no guard needed.

**Evidence.** `onboarding.dart` in the diff: blank now stores 0 (read by the app as
"no limit"), invalid shows an inline error that blocks Next, zero is an explicit
no-budget choice, and a value past the 100,000,000 cap is capped with the cap
disclosed. The qa-log row states it directly: "both 'set later' and zero resolve to
the 0 the app already reads as 'no limit', so no stored shape changed."

The subtlety worth a sentence: what gets STORED changed (blank used to fabricate
20000, now it stores 0), yet "no data change" is still true, because the stored
value 0 was already a legal value the app already interpreted as no limit. No new
field, no migration, no money math, no golden vector. The meaning the user gets is
now honest (blank means "I did not set one", not "someone guessed 20000 for me"),
and the storage contract is untouched. This is a note so the next reader does not
mistake "the stored value changed" for "the schema changed"; they are different
claims and only the first is true.

**Guard.** None warranted. The existing money-math and golden-vector tests already
guard the storage contract, and they stayed green, which is the proof.

### Lesson 4. Two workflow hazards the human hit while proving tests and while scheduling reminders. Both get a guard.

**Hazard (a): proving a test fails, in the background, is a race.** The
prove-it-can-fail discipline was run by reverting a fix and launching
`flutter test` in the BACKGROUND, then very nearly restoring the file before the
test process had finished COMPILING it. Had the restore landed first, the run would
have compiled the FIXED code and printed a false pass, and the false pass is worse
than no proof because it reads as proof. This is the same class of failure the
whole "prove a new test can fail" rule exists to prevent, reintroduced by timing.

**Guard for (a):** A rule tied to a specific moment, which is medium strength
because it depends on being read at the right time: when you revert code to prove a
test fails, WAIT for the test-run completion notification before restoring the
file. Never restore while the run is still going. Added to CLAUDE.md beside the
"Prove a new test can fail before trusting it" section, because that section is
where someone stands at exactly this moment. A stronger machine guard is not
available here, because nothing in the repo can observe the ordering of a
background job against a manual edit; saying that plainly rather than pretending a
test could catch it.

**Hazard (b): send_later reminders are one-shot and were updated after firing.**
Several reminder triggers were created, then updated AFTER they had already fired,
which is a no-op, and the leftover confusion was over which trigger was actually
live. A fired one-shot trigger is gone; editing it changes nothing and looks like
it changed something.

**Guard for (b):** A rule, medium strength: treat every send_later trigger as
single-use. Each firing must ARM A FRESH trigger if the reminder is still needed;
never update a trigger that has already fired, because there is nothing there to
update. This is a habit-shaped guard and is weak by nature, so the honest backstop
is to keep at most one live trigger per intent and re-create rather than re-edit.

**Open lessons carried forward.**
- **Open 4, nothing compares the phone to main: STILL OPEN.** Unchanged; the
  comparison remains the one thing only the founder can do, and they did it here.
- **Open 7, guard sets are typed lists: STILL HALF CLOSED.** Screens are derived.
  The second-face map and the render harness's shot list are still typed lists, not
  derived sets. This session added no new offender; the readability sweep proved it
  is holding for screens (Lesson 1).
- **Open 8, the edit-pattern hook: CLOSED since f2.96.** The guard now exists
  (`.claude/hooks/guard-destructive-edits.sh`, per CLAUDE.md). Kept here only to
  note it moved from "best-evidenced open item" to "installed"; verify it still
  fires in a future session rather than assuming.
- **Open 10, whether onboarding sample data survives launch: STILL OPEN.** A
  founder decision parked in docs/launch-checklist.md, not a defect.
- **Open 11 (new), the account focus-scroll cannot reach a row far below the fold.**
  Lesson 2 above. A tracked limitation with a known stronger guard that is
  deliberately unwritten because it would redden today.

**For the founder, over lunch.** f2.97 is clean. You confirmed patch 21 on your
phone, the delivery log agrees, and there is no bug to report. Everything below is
about how the work got made, not about what you are using.

Two of our safety nets caught problems by themselves this time, before anything
could reach you. One net checks that every screen file is either tested for
readability or has a written reason why it does not need testing; a brand new file
appeared and the net stopped the build until we wrote down why it is exempt. The
other net refuses to ship a stamp until a quality-assurance note exists for it; it
stopped the build until we wrote that note. These are worth celebrating precisely
because they worked while nobody was watching them.

We are leaving one small nicety unfinished on purpose. When you search for an
account and tap it, the Accounts screen jumps to it and flashes it. If you ever
have more than about 30 accounts and the match is near the very bottom, the jump
does nothing, because the phone has not drawn rows that far down yet. The account
still opens; only the little flash is missing. It is written down in the code and
tracked as Open 11. If we forget it, the cost is that one flash stays missing on
very long lists, and nothing else.

Two habits nearly bit us and now have written rules. First, when we deliberately
break code to check that a test would catch the break, we must wait for the test to
finish before putting the code back; if we put it back too early, the test
accidentally checks the fixed code and lies that everything is fine. Second, the
reminder timers we set only fire once, so if we need another reminder we must set a
brand new timer, never edit one that has already gone off, because editing a
spent timer does nothing while looking like it did something. If either rule is
dropped, the danger is the same in both cases: a false "all clear" that reads
exactly like a real one.

---

## 2026-07-30, session 18: the day the guards were audited, and two were hollow

Six deliveries, f2.86 to f2.91, patches 10 to 15, all mode `patch` on
0.6.3+12. The founder confirmed with two words, "it works". Ground truth is
docs/delivery-log.md, read before this was written: six rows for six merges, no
`release` row, so nothing was stranded and no manual install is owed. All six
merge commits have two parents, so nothing was squashed.

The mechanical side was clean and three of the six batches changed no app code
at all. f2.89 investigated three suspected defects and reported all three as NOT
defects, which is the right instinct and worth saying before anything else: a
retrospective that only rewards found bugs teaches people to find bugs.

This session is long because it audited the GUARDS rather than the app, and
that is where everything was. Two of the six journeys shipped in f2.91 passed
with the feature under test deleted. The fixture four machines now depend on was
two days from expiring. And the defect f2.90 hunted had been sitting, legible,
in a rendered picture for two days.

Facilitated by the lunch-and-learn agent, whose findings were then verified by
hand before any of this was written, and whose proposed guards were built in the
same sitting rather than carried forward. Every lesson below is CLOSED except
where it says otherwise.

### Addendum, the second half of the same day: f2.92 to f2.96

Five more deliveries after the retrospective above, patches 16 to 20, all
confirmed on the phone. Written directly rather than by a second agent pass,
which is worth saying because the entry above was facilitated and this one was
not; treat its self-assessment with the appropriate suspicion.

The reason it exists is that Lesson 3 above, guards that are lists wearing the
title of rules, produced TWO MORE INSTANCES in the hours after being written
down. Naming a pattern does not stop it.

**Instance five, in the guard built to honour the founder's own request.** f2.94
gated the sample data behind a build flag, and the scan checking the gate was
present asked whether the word `kTestingAids` appeared anywhere in the file. It
PASSED with the gate deleted, because the word was still sitting in a comment two
lines above explaining the gate. A check a comment can satisfy. Caught only
because the prove-it-can-fail rule was applied; nothing in review would have
found it. Fixed by stripping comment lines and requiring the code form.

**Instance six, and the most expensive.** The readability sweep covered ten typed
screen names against fifty files in `lib/screens`, and this document plus
CLAUDE.md both described it as covering every screen. When the set was finally
derived from disk in f2.96, the first run found Goals printing
`by 2026-12-31`, the THIRD screen to carry the machine-date defect. Insights had
it in f2.84. The utang list had it in f2.90. Goals kept it through both rounds of
fixing that exact class, for one reason: it was not on the list.

So the guard for Lesson 3 is no longer a candidate, it is built, and the model is
the one that already existed here: enumerate what is on disk, then refuse to pass
until every item is swept or exempted with a stated reason. Applied to the screen
set in f2.96. NOT yet applied to the second-face map or the render harness's shot
list, which stay open.

**What else the five delivered.** f2.92 fixed two journeys from f2.91 that passed
with the feature deleted, and defused a fixture pinned to a month that would have
expired two days later. f2.93 made the sample data reachable from Menu, which the
founder had asked for and could not get to. f2.94 gated it so launch does not
depend on memory. f2.95 parked the one deferred launch decision in the file
somebody opens to flip that flag, rather than in a document whose existence has
to be remembered. f2.96 is above.

**The process failure, tenth outing.** The python assert-before-write heredoc
silently discarded an edit again, ONE TURN after this document recorded it as Open
8 and after the morning entry established that it is guardable. The write never
happened because a later assertion in the same script threw; analyze then reported
errors from an edit that did not exist. This is no longer a lesson, it is a
measurement: the rule has failed ten times and the mechanism to prevent it has
been available the whole time. Nothing here should be read as expecting the
eleventh to go differently.

**Open lessons, updated.**

- **Open 4, nothing compares the phone to main: STILL OPEN.** Unchanged.
- **Open 7, guard sets are typed lists: HALF CLOSED.** Screens are derived now.
  The second-face map (one entry) and the render harness's shot list are not.
- **Open 8, the edit-pattern hook: OPEN, and now the best-evidenced item in this
  file.** Asked of the founder twice. It changes their configuration, so it stays
  theirs to approve.
- **Open 9, sample data unreachable after onboarding: CLOSED** by f2.93.
- **Open 10 (new). Whether the onboarding sample data survives launch.** Deferred
  by the founder on purpose, parked in docs/launch-checklist.md, surfaced from
  build_flags.dart at the moment the flag is set. Not a defect, a decision.

### Lesson 1. Two of the six journeys passed when the feature did nothing

**Evidence.** `journeys_test.dart`, the assertion sitting under a comment
calling itself the honest half:

    expect(_balance(store, 'bank') + _balance(store, 'cash'), closeTo(23000, 0.001));

Bank plus cash is 23,000 after a working transfer. It is also 23,000 after a
transfer that never happened, because a sum is exactly what a transfer
preserves. Verified by deleting the `Move it` tap so no transfer occurred at
all:

    00:02 +1: All tests passed!

Same for the utang round trip with both `Mark paid` taps removed.

The two hollow ones were both journeys whose invariant is a CONSERVATION
statement, "changes nothing", "returns to the start". That is not bad luck. A
conservation invariant is unfalsifiable by inaction by construction, so its
companion check can never be another conservation statement. The four healthy
journeys assert a DIRECTIONAL change and carry their own proof for free.

**What it cost.** Nothing on the phone; the cost was belief. CLAUDE.md, the
commit message, the file header and the agent brief all warned about exactly
this failure, in exactly this slot, and it happened anyway on the same day. A
guard written from the right mental model still landed on an assertion that
could not fail.

**Guard.** Both journeys now assert per-account movement, plus a stored-blob
comparison so inaction cannot satisfy them. Proven by deleting the taps again:
`Expected <1500>, Actual <3000.0>` and "the 900 never came back, so the
repayment did not happen". CLAUDE.md now says the companion check must be
DIRECTIONAL and says why.
Strength: **strong**, and closed in f2.92.

**A real thing learned while fixing it.** The stronger assertions immediately
failed for two reasons that were NOT bugs. The transfer runs Cash to Bank, not
Bank to Cash, because the sheet defaults its source to the first account, and a
conservation check could never have revealed which way the money went. And
recording an utang does not move cash unless a lending account is chosen:
`cashLeg` is true only when one is, because "I lent this last month, let me
write it down" must not invent a withdrawal today. Both were settled by reading
receivables.dart rather than by adjusting the app.

### Lesson 2. The fixture four machines depend on was two days from expiring

**Evidence.** `screens_shot.dart` pinned every fixture date to a constant:

    const y = 2026, m = 7;

Every screen compares against `DateTime.now()`. So on 1 August, two days after
that fixture was written, every expense in it falls into LAST month, Budget
renders "PHP0 of PHP18,000, nothing spent yet this month", and every screen
becomes the first-run empty state again. Silently, by the calendar, with nobody
touching a line. That is session 17's entire lesson returning on a timer.

The narrower half had a date too: the receivable f2.90 added specifically to
make the due-date branch reachable was the literal `2026-08-15`, sitting between
two neighbours that used the relative helper. On 16 August every receivable is
overdue again and the check written for that line becomes a no-op again. The
blind spot f2.90 diagnosed was closed with a seventeen day fuse.

The stated reason for pinning was that golden images changing with the calendar
are noise. That protected a comparison which cannot happen: `test/shots/` is
gitignored, `git ls-files` on it returns nothing, and CI only ever runs the
harness with `--update-goldens`, which writes and never compares. The pinning
bought nothing and cost the expiry.

**What it cost.** Nothing yet, which is the cheapest possible moment to find it.

**Guard.** Dates are anchored to `DateTime.now()` now, the way the app's own
sample data already was, so only the test fixture could ever have rotted. Plus
`test/fixture_still_lived_in_test.dart`, which asserts the states the fixture
exists to present: spending in the CURRENT month, nothing dated in the future,
somebody overdue AND somebody who still has time to pay, a foreign-currency
account, a savings target, income, enough categorised expenses. Proven by
pinning the fixture to the previous month and watching it name the failure:
"every expense in the fixture is outside the current month, so Budget, Insights
and the Home month card all render as a phone nobody has used."
Strength: **strong**, and closed in f2.92.

### Lesson 3. Every guard here is a list wearing the title of a rule

One pattern behind four of the day's moments, and it is one lesson, not four. In
each case a check was named for a CLASS of defect and implemented as an
enumeration of the instances that existed the day it was written.

**Evidence.**

1. `no_iso_dates_in_copy_test.dart`, titled "no user-facing string interpolates
   a raw stored date", matched four literal key names. The offender was called
   `oldestDue`. (f2.90)
2. The fix for it added a second-face map with exactly ONE entry, which is a
   list of the instance just found. Appearance has a `Segmented` control and its
   second face is still never opened.
3. The sweep's screen set was ten typed names against fifty files in
   `lib/screens`. Reports and Debts were in neither the sweep nor the render
   harness, and BOTH carried f2.88's rounding fix: two of the four screens that
   change touched had never been drawn or measured.
4. 21 of 22 store setups in the render harness built their own private person.
   (f2.88, f2.89)

**What it cost.** Two days for the `Due 2026-08-15` defect, and an unknown
amount of false confidence in every check named after a rule.

**Guard.** Partly closed, and said plainly rather than claimed. Reports and
Debts are in the sweep now and both pass. CLAUDE.md no longer claims the sweep
covers every screen and names the gap as a gap. What is NOT done is the real
fix: deriving the set from the codebase the way
`test/palette_contrast_test.dart` already does, where one line,
`expect(seen, barakoThemes.length * 2)`, is the whole difference between a rule
and a list. That model was written in this repo the same week by the same author
and was not reused.
Strength: **medium** today. Open 7 below.

### Lesson 4. The defect f2.90 hunted was legible in a picture for two days

**Evidence.** Rendered from the pre-fix code in a throwaway worktree, the shot
`money-owed-dark.png` reads:

    Migs
    Due 2026-08-15 - 1 entry                      PHP1,500

That shot was created on 2026-07-27, two days before the defect was found, by a
commit whose own comment says it exists so neither segment renders its empty
state.

**What it cost.** Two days, and something worse: the f2.90 write-up diagnosed
the survival as a fixture blind spot, "no render could show it because no render
had anybody who still had time to pay". That is true of the lived-in fixture and
FALSE of the project. A render did have somebody who still had time to pay, in
the picture built for that exact list, and it printed the defect in full. The
comfortable half of the cause was written down and the uncomfortable half was
not. CLAUDE.md already contains the sentence that covers it: a picture nobody
opens proves nothing.

**Guard.** No new render without a machine assertion on what it drew, which is
the same derived-set fix as Lesson 3, so it lands with Open 7.
Strength: **weak** today, a sentence.

### Lesson 5. "Nothing can observe how a file gets edited" was never checked

**Evidence.** Session 17 concluded, about the assert-before-write heredoc
pattern failing for the seventh time: "Nothing in this repository can observe
how a file gets edited. This one is a rule and cannot be a machine." The pattern
was used again today, and `git checkout <file>` was used once to undo a
deliberate break, which discarded real work that had to be rewritten. Eighth and
ninth outings.

The claim was never verified. `.claude/` has `agents/` and `skills/` and no
`settings.json` and no hooks. A PreToolUse hook receives the Bash command string
BEFORE the command runs and can refuse it, which is precisely a machine that
observes how a file is about to be edited. Two consecutive retrospectives
concluded "unguardable" without checking whether the mechanism existed, which is
the same error as Open 3 being carried from session 1 while being false.

**Guard.** A PreToolUse hook refusing a python here-document that writes to a
path in the repo, and `git checkout` or `git restore` naming a tracked file.
NOT installed: hook configuration is the founder's call, not an agent's, so this
entry is the request. Until it exists the lesson is weak and should be called
weak.
Strength: **strong if installed**, currently **weak**. Open 8.

### What went right, and is worth keeping

**The prove-it-can-fail rule caught its own author twice, visibly.** In f2.86
the first proof that the off-the-side check could fire DID NOT FIRE, because a
900 wide box inside a vertical scroll view is clamped to the viewport width; the
check was correctly silent and the proof was measuring air. In f2.90 the new
machine-date check passed cleanly BEFORE the fixture and the tab were fixed, on
an unreachable branch, and the author noticed. Both catches came from the same
rule, and both are cases of it catching the person applying it. After Lesson 1
this is the strongest thing in this entry.

**f2.87 re-read a workflow instead of trusting a carried lesson**, found half of
Open 3 had been false for several sessions, and found the half that was genuinely
open in a different shape. That is the behaviour Lesson 5 says was missing
elsewhere, done correctly in the same day.

### On the reporting cadence: working, with one honest caveat

Six stamps and one confirmation at the end is not a reporting failure. Every
batch produced its delivery row before the next began, and no version number was
spoken before its row existed, which is the session 15 rule.

The caveat is what "it works" proves. Shorebird patches are cumulative, so a
confirmation on patch 15 confirms the app AT patch 15. It does not confirm
f2.87 or f2.89 individually, and a defect introduced in one and masked by
another would not be separately noticed. Three of the six changed no app code,
so for those three "it works" can only mean the app still opens and the stamp is
right. That is the correct amount of evidence for a guard-only batch, and it is
named so nobody later reads six confirmations where there was one.

### One thing the founder asked for that was not delivered, and was not said

The f2.91 request was "test data or transaction to test features", plus an
agent. What shipped was a test file that runs on a runner and an agent brief.
Both are valuable, and the founder cannot see or touch either. The app HAS a
sample data generator, `lib/money/sample_data.dart`, reachable from exactly one
place: inside `completeOnboarding`. An already onboarded founder cannot load it.
So the literal reading, data on my phone to poke at, is one Menu action away and
was neither built nor ruled out loud. A beginner cannot tell which reading they
received.
Guard: when a request has two readings, say which one is being built before
building it. Strength: **weak**, a sentence, and no machine can read intent.

### Open lessons carried forward

- **Open 4 (session 17), nothing compares the phone to main: STILL OPEN.** Today
  moved a great deal of detection from the founder to machines. Nothing compares
  the phone to `main`. The founder remains the detector of last resort, which is
  survivable while they are the only user and not at launch.
- **Open 7, guard sets are typed lists rather than derived rules: OPEN.**
  Lessons 3 and 4. The model is `palette_contrast_test.dart`: iterate what
  exists, then assert you saw all of it. Applies to the sweep's screen set, the
  second-face map, and the render harness's shot list.
- **Open 8, the edit-pattern hook does not exist: OPEN, and it is the founder's
  call.** Lesson 5. Guardable, unguarded, and now known to be guardable.
- **Open 9, the sample data generator is unreachable after onboarding: OPEN.**
  One Menu action. Offered to the founder rather than assumed.

**Closed this session:** session 17's Open 1 (f2.85), Open 2 (f2.86) and Open 3
(f2.87), all verified in the code rather than taken on trust, plus Lessons 1 and
2 above, both closed in f2.92 with proven guards.

### What it cost

Nothing reached the phone wrong. Six patches, six rows, one confirmation, no
money math changed, no data at risk, no manual install owed.

The cost was entirely in the guards, which is why the entry is long. Two of six
journeys did not test what they claimed, and it was provable in four minutes.
The fixture underneath the day's other new machine had two days left. The defect
that cost the most attention was drawn in full in a picture that sat unread for
two days. Nothing here was a failure of care. Every one was a check that was
narrower than its own name, which is the sentence this session exists to leave
behind.

## 2026-07-29, session 17: sixteen screenshots with no money in them

Eight deliveries in one day: f2.76 as a new base APK for the home screen
widget, then patches 1 through 7 (f2.77 to f2.83). Every one confirmed on the
phone. Ground truth is docs/delivery-log.md, read before writing this.

The founder found two bugs before any test did. That is the thread running
through the whole day, and the cause turned out to be one thing.

### Lesson 1. Every screenshot this project has ever taken was of an empty app

**Evidence.** `test/screens_shot.dart`, line 186, inside `shoot()`, the helper
that renders sixteen images (eight screens at two brightnesses):

    SharedPreferences.setMockInitialValues({});

An empty store. So Home, Budget, Insights, Activity, Utang and Menu were
rendered, looked at, and approved dozens of times as FIRST-RUN WELCOME
SCREENS. Not one of those images has ever contained a peso figure.

**What it cost.** The founder opened f2.76 and saw `-₱720` with a line through
it. The display serif drew the peso sign with a long crossbar that ran into the
minus, so every negative amount in the app read as struck through. It was on
Home. It had been rendered many times. It was invisible every time, because
Home had no amounts in it.

CLAUDE.md has said "look at the screen before shipping a screen" since a
previous incident, and that rule was FOLLOWED. It was followed against a
fixture that could not show the defect. A rule about looking is worth nothing
if the thing being looked at is not the thing that ships.

**Guard.** `shoot()` now loads a lived-in phone: four accounts with odd
balances, twelve categorised expenses across a month, income, a card and a
loan, somebody who owes and somebody who is owed, a goal part way there, and a
logging streak. Dates are relative to a fixed day so the images do not churn
with the calendar.
Strength: **strong** (a fixture every future render inherits).

**It paid for itself in the same session.** The first render with real data
surfaced two things nobody had ever seen:

1. Insights printed `(payday 2026-07-30)`, a machine date in a sentence, while
   every other screen in the app says "Jul 30". Fixed, and guarded by
   `test/no_iso_dates_in_copy_test.dart`, which was proven by putting the bug
   back and watching it name the exact line.
2. The first version of the fixture itself used `'category': 'Food'`, which no
   engine reads, so the Budget breakdown quietly grouped by LABEL. The
   screenshot looked plausible. Reading `money/budget.dart` rather than trusting
   the picture is what caught it, which is the same lesson one level down.

### Lesson 2. Two defaults changed underneath the app, and only a phone noticed

**Evidence.** Flutter's `SnackBar` defaults `persist` to `action != null`. So
every snackbar offering Undo, seven of them on the most used write paths,
ignored the `duration` written directly above it. The code said four seconds
and meant it.

**What it cost.** The founder logged an expense and the receipt sat on screen,
on every tab, until swiped. Reported within minutes of installing.

**Guard.** A widget test that logs a real expense and watches the receipt
leave, plus a source scan that refuses any `SnackBar` carrying an action
without an explicit `persist` decision. Both proven failing first. There is a
third test proving the scanner can flag something, because a scanner that
matches nothing reads exactly like a clean bill of health.
Strength: **strong** (two machines).

**The general shape.** Neither of these was a mistake in Salapify's code. Both
were a dependency changing what "no opinion" means. The durable answer is the
one used here twice: where a default decides behaviour a person will notice,
state the choice explicitly and scan for anyone who forgot.

### Lesson 3. "Two versions of one number" recurred twice in one day

**Evidence, both caught internally.**

- f2.80: the Add-account form still showed the Kind chips after the subtype had
  been chosen one screen earlier, so picking "Payroll account" and then tapping
  "Cash" stored `kind: 'cash'` beside `subtype: 'payroll_account'`. Found by
  looking at the render.
- f2.83: with conversion working, net worth counted the converted dollars while
  the row six lines below said "not counted" and the section subtotal excluded
  them. Three numbers on one screen disagreeing. Found by a widget test written
  almost as an afterthought.

**Guard.** Both have tests. The general rule is stronger and is now written
into the two screens: a subtotal must be computed by the same function as the
total, not by a rule that looks equivalent. Every one of these bugs was two
pieces of code that each read correctly on their own.
Strength: **medium** (tests for the two instances, a rule for the class).

### Lesson 4. The assert-before-write pattern bit again, on its seventh outing

**Evidence.** A python heredoc that asserts an anchor string exists and then
writes. The assert threw, the script exited before `write()`, nothing changed,
and `flutter analyze` reported errors from an edit that had never landed. It
cost one round in the middle of delivery E.

Session 16 already concluded: "The fix is not 'be careful', it is 'stop using
that tool for edits', because the safer tool refuses loudly instead of doing
nothing quietly." That conclusion was recorded, agreed, and then not followed.

**Why no guard is possible.** Nothing in this repository can observe how a file
gets edited. This one is a rule and cannot be a machine.

**What changes anyway.** The failure is only silent because the assert runs
BEFORE the write. Ordering it the other way, or using the Edit tool, makes a
missing anchor an immediate loud failure. The Edit tool was used for the repair
and for every edit after it in this session.
Strength: **weak** (a rule that has now failed seven times). Recorded honestly
rather than dressed up.

### What went right, and is worth keeping

Delivery A of the accounts feature shipped INVISIBLY, on purpose, so the data
design could be wrong cheaply. It was: assets already carry a meaningful type
and the first version read them all as "something else", which would have shown
a crypto holding and a house as the same line item. Nothing depended on it yet,
so the fix cost minutes. That ordering is worth repeating on any feature whose
storage shape is uncertain.

Delivery E's riskiest decision was refusing a convenience: the exchange rate
table is passed in as an argument rather than kept in a module variable. A
currency SIGN in a global is fine, because being wrong for one frame is
cosmetic. A RATE in a global is a total that depends on hidden state, which is
how a money app gets "it was right yesterday".

### Open lessons carried forward

**Open 1 (new). Nobody looks at the light renders.** The fixture fix covers
both brightnesses, but the standing habit is to review dark first because that
is what the founder uses, and light usually goes unopened. A contrast defect in
light would survive exactly the way the strikethrough did.
Candidate guard: an automated contrast check over the rendered light images,
rather than another instruction to look.

**Open 2 (new). The render harness is still opt-in.** CI runs it with
`--update-goldens`, which proves it does not crash and proves nothing about
what it drew. Nothing fails when a screen becomes unreadable.

**Open 3 (carried, session 1). A Shorebird step failure is still silent.**
Unchanged. Eight deliveries today all produced rows, so the mechanism is
healthy, but a failure after the tests pass would still be quiet.

> **Correction, 2026-07-29 (f2.87).** This was carried forward from session 1
> without anyone re-reading the workflow, and half of it had already been
> fixed: the "Say plainly that nothing shipped" step opens an issue on any
> non-zero step, so a Shorebird step that FAILS has been loud for several
> sessions. Carrying a lesson forward is not free, and this one had been
> restated in every retrospective since while being false. It is the same
> mistake CLAUDE.md names one paragraph away: when a rule describes what a
> tool does, read the tool, not the rule.
>
> Re-reading it found the half that was genuinely open, and it is a different
> shape from the one written above: a Shorebird step that **succeeds having
> shipped nothing**. On a patch run the patch number is parsed with `|| true`,
> necessarily, so an empty one is indistinguishable from success and the
> delivery row would be written reading "patch: none" while the phone received
> nothing. A row is the one thing here treated as proof of delivery.
> **Closed** by `.github/scripts/verify-shipped.sh`, which runs before the row
> is written, and `flutter/test/publisher_guard_test.dart`, which drives it
> through every failure shape on the branch check. That test is also the first
> time any of the publisher's logic has been testable without shipping.

**Open 4 (carried, session 1). Nothing compares the phone to main.** The
founder is still the detector of last resort. Acceptable while they are the
only user; not acceptable at launch.

### What it cost

Two founder-reported defects, both fixed within the hour of being reported, and
one internal round lost to a known-bad edit pattern. No wrong money reached the
phone and no data was at risk. The expensive part is what almost happened
rather than what did: the conversion work in f2.83 shipped with three numbers
briefly disagreeing on one screen, and it was a test written on a hunch, not
the process, that caught it.

## 2026-07-28, session 16: the bug was in the feature next door

f2.75 delivered cleanly, was confirmed on the founder's phone, and nothing
broken reached it. Ninth clean delivery in a row on the mechanical side, and
the third round running where the pre-merge QA pass ran, found real defects,
and every must-fix was fixed before the merge instead of after.

The patch is clean. The session is long, because this round produced the single
most useful shape a retrospective here has seen: **a defect whose harm was
entirely in a different feature from the one being built**. The batch was a
quick add editor. The damage was to the migration prompt in Menu, which the
editor never touches, never imports, and never mentions. No amount of testing
the quick add editor would have found it, and QA found it anyway.

Four other things are worth the time, and three of them are about work that has
NOT shipped, which is the cheapest moment to say so. A data shape key is
guarded in one direction and completely unguarded in the other, proven by
deleting it against a green suite. The home screen widget's central design
claim, that one pure Dart file holds the entire decision surface, does not hold:
the file between the store and that pure function makes four decisions no test
can see, and three of them were broken here without a single test objecting.
The one test written to catch a native mistake misses three native mistakes that
each make the widget permanently dead. And an assertion that could not fail
turned up three separate times in one round, by three different mechanisms.

### What we believed / What was true

**Believed: f2.75 reached the phone. TRUE, and confirmed in person.** From
`git show origin/main:docs/delivery-log.md | tail -1`:

    | 2026-07-28 22:29 UTC | f2.75 | 25 | patch | 0.6.2+11 | 379f6960 (run 30404001614) |

Mode `patch`, so nothing was stranded and no manual install is owed.
flutter/pubspec.yaml:12 at the delivered tip still reads `version: 0.6.2+11`,
unchanged since session 5. The stamp at flutter/lib/main.dart:29 to :30 of
commit 379f696 is `'f2.75 · The quick add buttons on Budget are yours now:
rename, re-price, delete, or add your own.'`, 97 characters against the 120 cap
at flutter/test/update_stamp_test.dart:20. Stamp in the code, stamp in the log,
stamp on the phone: three for three.

**Believed: the merge used a merge commit, not a squash. TRUE, verified.**
`git cat-file -p 379f696` shows two parents, 0f10b11 and 02b6c4c.

**Believed: the suite is green on what shipped. TRUE, re-run in a clean
checkout.** A throwaway worktree at dd213ca, the delivered tip, reports
`flutter analyze` clean and `flutter test` at **+1001: All tests passed!**, up
from 982 at f2.74. Same caveat as last session, stated rather than smoothed
over: the working tree this session sat in was ALSO being used to write the
next batch while the session ran, and it changed under this session at least
three times while it was running. Every number in this entry that describes
what SHIPPED was measured in the clean worktree at dd213ca. Every number that
describes the unshipped widget work was measured in a second clean worktree at
2ebd297, plus one snapshot of the uncommitted tree taken at a stated moment and
applied to that worktree.

**Believed: the QA pass ran BEFORE the merge. TRUE, with a record.**
docs/qa-log.md:35 carries an f2.75 row naming 2 MUST FIX, 4 SHOULD FIX and 3
deferred findings. The row exists because flutter/test/qa_record_test.dart made
the build fail without it, for the third consecutive round.

**Believed: seeding the presets on OPEN flipped `hasData` true and deleted the
migration prompt. TRUE, and verified against both commits.** At 6988747,
flutter/lib/screens/quick_add_editor.dart:27 called `await
store.seedQuickAdds();` before the sheet was built, and `seedQuickAdds` at
store.dart:1821 to :1838 wrote `'quickAdds': [...]` and `'quickAddsEdited':
true` into settings. `hasData` counts `quickAdds` at store.dart:279, in a list
that has read `['paluwagans', 'treats', 'quickAdds']` since bea60ca, long
before this batch. Menu reads that same boolean at menu.dart:1272:

    Kicker(store.hasData ? 'BACKUP' : 'BRING YOUR DATA OVER'),

So on an empty app, opening a settings sheet and closing it without touching
anything replaced the only in-app route to import from the old React Native app
with a backup card, permanently. Fixed in fdb0e52 by moving the seed into
`_writeQuickAdds` at store.dart:1849, which only the two write paths reach.

**Believed: `quickAddsEdited` follows the conditional-key pattern and QA
verified it. TRUE. Believed it is therefore guarded. HALF TRUE, and the
unguarded half is the dangerous one.** See Lesson 2. Proven both directions in
a clean worktree.

**Believed: the widget's entire decision surface lives in
flutter/lib/money/widget_tile.dart. FALSE, and provably so.** See Lesson 3.
Three deliberate breaks in flutter/lib/services/home_tile.dart leave all 1026
tests passing and `flutter analyze` clean.

**Believed: the pubspec bump to 0.6.3+12 will produce a `release` row, not a
`patch` row. TRUE, verified by reading the workflow rather than the commit
message.** .github/workflows/flutter-preview.yml:85 reads the version straight
out of pubspec.yaml, :103 tests it against `shorebird releases list`, and :109
takes the `shorebird release android` branch with `mode=release` when no such
release exists. docs/delivery-log.md has exactly two release rows, for 0.6.1+10
and 0.6.2+11, so 0.6.3+12 is genuinely new. The consequences the commit claims
all exist in the file: the base APK is uploaded to the fixed flutter-preview
tag at :131, the row records `| none | release |` because the patch scrape at
:127 finds no "Published Patch N" line on a release run, and the manual-install
issue opens at :249. The commit message is accurate.

**Believed: this is the second time in two days a substring matcher weakened a
guard. NOT CONFIRMED as stated, and the true version is stronger.** No earlier
substring-matcher instance is recorded anywhere in this log or in any commit
message; `grep -n "substring" docs/lunch-and-learn.md` returns nothing and only
one commit in the repository mentions the word. What IS in the repository is
better evidence: **three assertions that could not fail, in this one round, by
three different mechanisms**, each caught by a different person-level habit and
none by a machine. See Lesson 5.

### Timeline (with evidence)

All times UTC, from `git log --format=%cI` and the publisher's own rows.

| Time | Event | Evidence |
|------|-------|----------|
| Jul 28 15:34:17 | f2.74 patch 24 delivered, confirmed on the phone | 0f10b11 |
| 16:39:37 | 6988747 batch 9, the quick add editor. 1413 lines added. **No stamp bump**, deliberately, so the stamp lands with the QA row | commit message |
| 17:02:55 | fdb0e52 QA round plus session 15. 2 MUST FIX, 4 SHOULD FIX. Stamp bumped to f2.75 | commit message, docs/qa-log.md:35 |
| 22:04:56 | 02b6c4c, a one-file correction to a header comment that had become false in fdb0e52 | commit message |
| 22:17:24 | Merge #232 (379f696), two parents | `git cat-file -p 379f696` |
| 22:29:25 | f2.75 patch 25 delivered, 12m01s after the merge | delivery row, dd213ca |
| after | **Founder confirms f2.75 on the phone** | founder |
| 22:41:59 | 81c72a6, widget groundwork, on the branch | commit |
| 22:47:20 | c86e2ff, the widget privacy switch | commit |
| 22:50:25 | 2ebd297, the native half and the pubspec bump to 0.6.3+12 | commit |
| during this session | the working tree changed at least three times while the session ran, including a stamp bump past f2.75 | `git status --porcelain` returned clean, then eleven modified files, then a different set |

### Divergence point

**There is no delivery divergence. Nine in a row.** There is no correctness
divergence that reached the phone either, for the third round running.

The divergence worth dating is the one inside the batch, and it is
**6988747 at 16:39:37**, the moment `await store.seedQuickAdds();` entered
quick_add_editor.dart line 27. From that instant, every empty app that opened
the quick add sheet lost its import prompt forever. It never shipped, because
QA ran before the merge. Twenty three minutes separated the defect from its
discovery.

Worth saying plainly, because it is the whole point of this session: nothing
about the quick add editor was wrong. Every preset rule matched the RN engine
across 22 golden cases. The editor added, removed, refused and reported
correctly. The batch was correct AND it deleted a migration path, and those two
facts are not in tension, because the harm happened in a file the batch never
opened.

### Root cause

**1. `hasData` is a derived signal with eleven collection inputs, four settings
inputs, and one consumer whose failure is irreversible.**

store.dart:262 to :287 computes `hasData` from eleven collections plus
`paluwagans`, `treats`, `quickAdds` and `steadyPay`. Its own docstring at :275
to :281 explains why settings-era data counts: someone whose only data is a
paluwagan deserves the same backup buttons. That reasoning is right and it is
the reason the trap exists. Any new feature that writes into one of those four
settings keys silently answers a question asked in a completely different
screen.

The consumer that matters is menu.dart:1272. It is not symmetric. Showing
BACKUP to someone with no data is a cosmetic mistake. Showing BACKUP to someone
who still needs to import from the old app removes the only route they have,
and they will not know it was ever there. There is no undo, because there is
nothing to undo: the app simply stops offering.

So the root cause is not "the seed was in the wrong place". It is that **a write
and its most expensive consequence live in different files with nothing
connecting them**, and the connection is a boolean that reads as harmless.

**2. Every test in the batch tested the batch.**

quick_add_editor_test.dart at 6988747 was 201 lines and thorough. It covered
adding, removing, refusing, trimming, duplicate labels in different cases, hex
literals, leading plus signs. Every one of those assertions is about the quick
add editor. Not one is about anything outside it, because nothing about the
feature suggests there is an outside. This is the general shape: **the blast
radius of a change is not the same set of files as the change**, and test
authorship follows the change.

**3. For the widget: a design principle was stated, believed, and then not
enforced anywhere.**

The claim is written three times, in three files, with real conviction:
widget_tile.dart:1 to :7 ("the ENTIRE decision surface is here"),
home_tile.dart:8 to :11 ("Nothing here decides anything, which is why nothing
here needs to"), and YourNumberWidget.kt:17 to :21 ("nothing here is allowed to
be interesting"). It is a good principle. It is also just prose. Nothing checks
it, and it is already false in the file that asserts it hardest, at
home_tile.dart:81 to :90.

**4. For the conditional key and the manifest test: a guard written against one
failure direction reads as a guard against the concept.**

The golden key-set contract genuinely catches `quickAddsEdited` being emitted
when it should not be. It catches nothing at all when the key is dropped when it
should not be, because RN fixtures never carry it, so dropping it agrees with
every fixture. Same shape in widget_manifest_test.dart: it catches the receiver
class name being wrong, which is the failure someone imagined, and misses three
other ways to make the same widget permanently dead.

### Lessons and guards

**Lesson 1. The harm was entirely in a feature the batch never touched, and
that is a class, not an accident.**

The instance is fixed and guarded. The class is not.

**Guard for the instance: SHIPPED, strongest tier, re-proven live this
session.** flutter/test/quick_add_editor_test.dart:199 to :227, 'opening the
editor and closing it writes NOTHING', which mounts an app with an empty blob,
opens the sheet, taps Done, and asserts both that settings is byte identical and
that `store.hasData` is still false. Its failure line is quoted in fdb0e52:

    expect(store.hasData, isFalse)   Expected: false  Actual: <true>

**Guard for the class: NOT WRITTEN. NEW Open 39.** The candidate is strongest
tier, and the trick that makes it work while nobody is watching is one this
project has already used successfully in widget_manifest_test.dart: **have the
test read the source tree so its own coverage list cannot go stale.**

Concretely, two assertions in one file:

- On an empty app, open and close every read-only entry point in a list, and
  assert `jsonEncode(store.data)` is unchanged and `store.hasData` is still
  false after each.
- Assert that the list covers every `Future<void> show*Editor(` and
  `Future<void> show*Sheet(` function found by grepping lib/screens off disk, so
  a new sheet added next month fails this test until somebody puts it in the
  list.

Without the second assertion it is a list that rots. With it, it is a guard.

The medium-tier companion, and it should be written whether or not the test is:
**the QA pass must ask, for every new write, which derived signals read that
key and who consumes them.** For settings writes the answer is currently four
keys at store.dart:279 to :283 and a consumer at menu.dart:1272.

**Lesson 2. The new settings key is guarded against being present and completely
unguarded against being absent, and the absent direction is the one that loses a
person's choice.**

`quickAddsEdited` follows the conditional-key pattern at
flutter/lib/data/backup.dart:498 to :503, exactly like `paluwagans` at :504 and
`steadyPay` at :510. QA is right that it survives save, export, parse, restore
and undo-import. The question this session was asked to answer is whether
anything PINS that conditionality, since paluwagans and steadyPay each have an
explicit omission test and this key has none.

Measured, not assumed, in a clean worktree at dd213ca:

- **Emitting it unconditionally: CAUGHT, loudly.** Replacing the conditional
  with a bare `s['quickAddsEdited'] = true;` fails ten tests, including
  `backup_golden_test.dart: sanitizeData matches the RN engine on every fixture,
  keys included` and `backup_export_golden_test.dart: buildBackupText decodes to
  exactly what the RN buildBackup writes`. The golden key-set contract does the
  work, and it does it well.
- **Dropping it unconditionally: NOT CAUGHT AT ALL.** Replacing the conditional
  with a bare `s.remove('quickAddsEdited');` leaves **+1001: All tests passed!**

The second one is not a theoretical direction. `sanitizeData` runs on every app
load, at store.dart:336. So a bug in that direction does not wait for an export:
it erases the flag on the next app open, `_quickAddsSeeded` at store.dart:1815
goes false, and the `quickAdds` getter at store.dart:1802 refills the four
defaults. Somebody who deliberately deleted every quick add would find Coffee
₱120 back, and the app would keep bringing it back forever. That is precisely
the behaviour this key was invented to prevent, described in its own docstring
at store.dart:1808 to :1814.

The reason paluwagans and steadyPay are safe in both directions is that they
have the named test the golden contract cannot provide:
flutter/test/paluwagan_store_test.dart:101, 'sanitize omits the key when there
are no paluwagans (golden safety)', and
flutter/test/steadypay_store_test.dart:46 and :66.

**Guard: NOT WRITTEN. NEW Open 40. Strongest tier, and it is about six lines.**
A `quick_add_store_test` mirroring paluwagan_store_test.dart:101 in both
directions: absent on a store that never edited, and PRESENT after an edit,
through `sanitizeData` and through `buildBackupText`. The general rule behind
it, worth writing beside the conditional-key comment in backup.dart: **a
conditional key needs two tests, because the golden fixtures can only ever
prove one direction.** The fixtures are generated by an app that has never heard
of the key, so agreement with them is agreement that it is missing.

**Lesson 3. "The entire decision surface is one pure Dart file" is false, and
the decisions that escaped are the two the widget exists to get right.**

Answering the question directly: widget_tile.dart is an excellent pure function
and every one of its eight states is driven by tests. It is not the whole
decision surface. flutter/lib/services/home_tile.dart makes at least four
decisions no test reaches, and YourNumberWidget.kt makes three more.

In home_tile.dart, at 2ebd297:

- **:81 and :82, the settings-key mapping.** `appLock: settings['appLock'] ==
  true` and `hideAmounts: settings['widgetHideAmount'] == true`. The pure
  function takes booleans; deciding which stored key produces them happens here.
- **:88 to :90, the palette.** `yn_text`, `yn_muted` and `yn_accent` are
  computed from `Barako.text`, `Barako.muted` and `Barako.primary` and never
  pass through `widgetTileStrings` at all. No test mentions any of the three
  names.
- **:83, the stamp**, `updateStamp.split(' ').first`.
- **:68, the readiness gate**, `if (!_supported || !ready) return;`, with a
  careful eleven line comment at :34 to :42 explaining why the first push must
  be dropped. Nothing exercises it.

**Proven, not argued.** Three edits in a clean worktree at 2ebd297, then the
whole suite:

    appLock:     settings['appLock']         -> settings['appLocked']
    hideAmounts: settings['widgetHideAmount'] -> settings['widgetHideAmounts']
    'yn_accent': _hex(Barako.primary)         -> _hex(Barako.background)

Result: `flutter analyze` clean, and **+1026: All tests passed!**

Read what each of those three would do on a phone. The first puts the daily peso
figure on a home screen that is visible before any unlock, which is the exact
failure widget_tile.dart:127 to :130 was written to prevent and ranks second in
its own state order. The second makes the privacy switch in Menu write a setting
nothing reads, so the person turns it on, watches nothing happen, and their
salary stays in public. The third draws the Log bar's label in the background
colour, so the tile's only action becomes invisible. All three are frozen in a
release the founder must install by hand.

The reason the tests miss the first two is worth naming precisely, because it
looks like coverage. flutter/test/widget_privacy_test.dart:45 to :55 defines its
own `_tile(store)` helper which reads `settings['appLock']` and
`settings['widgetHideAmount']` and calls `widgetTileStrings` directly. It never
calls `HomeTile.push`. So the test contains a second, private copy of the exact
line that would be wrong, and asserts the copy agrees with itself. That is not
carelessness; it is the only way to test a function whose real caller is
unreachable in a unit test. It is still a hole.

In the Kotlin, three more, all at 2ebd297:

- **:42 to :48, six fallback constants duplicated from Dart.** `"Start here"`,
  the "Add your cash and log one expense" sentence, `"Log an expense"`, `"1"`
  and `20f` all restate values that widget_tile.dart:154 to :160 and :110 also
  define. Change the Dart copy and the Kotlin fallbacks silently disagree.
- **:81, the tap encoding.** `if (barTap == "1") log else home`. The meaning of
  the string "1" is asserted in a comment on both sides and nowhere else.
- **The kicker.** `R.id.yn_kicker` appears once in the Kotlin, at :65, and only
  to be tinted. Its text, "YOUR NUMBER", is set only in
  res/layout/widget_your_number.xml:23. One visible string on the tile is
  decided in XML and appears in no Dart file at all.

**Proven for the key contract too.** Renaming `getString("yn_sub", ...)` to
`getString("yn_subtitle", ...)` in the Kotlin, and changing the tap encoding
from "1" to "7", leaves **+1026: All tests passed!** The first makes the sub
line show the "Add your cash" fallback forever under a real headline; the second
makes the only button on the tile stop logging. Neither is visible to
`flutter analyze`, to `flutter test`, or to a Gradle build.

**Guard: NOT WRITTEN. NEW Open 41.** Three candidates, ranked.

Strongest and cheapest: **a test that reads YourNumberWidget.kt off disk and
asserts the set of `getString("...")` keys it reads is exactly the set of keys
`HomeTile.push` writes.** Both are string literals in files this suite can
already read; widget_manifest_test.dart:97 already parses the Kotlin with a
regex. That closes the whole rename class in both directions.

Strongest for the two privacy decisions: **call `HomeTile.push` in the test
instead of a private copy.** `HomeWidget.saveWidgetData` needs a platform
channel, which a widget test can fake with
`TestDefaultBinaryMessengerBinding.defaultBinaryMessenger.setMockMethodCallHandler`,
collecting the written keys into a map. Then widget_privacy_test.dart asserts
against what the app would really write, and `_tile` at :45 is deleted rather
than trusted. That is more work than the first candidate and it is the one that
would have caught the app lock break.

Medium tier, and it should happen regardless: **stop the three files claiming
the decision surface is one file until it is one file.** A comment that is read
with authority and is not true is the exact failure CLAUDE.md already warns
about, in the paragraph about the render harness.

**Lesson 4. The one test written to catch a native mistake catches the mistake
somebody imagined and misses three that are just as fatal.**

The brief was to try to break the native setup in a way
flutter/test/widget_manifest_test.dart does NOT catch. Three found, all proven,
all applied at once to the manifest at 2ebd297, and then repeated against the
in-flight version of the test that adds the RemoteViews inflation check:

    <intent-filter> with android.appwidget.action.APPWIDGET_UPDATE   deleted
    receiver android:exported="true"                              -> "false"
    meta-data android:name="android.appwidget.provider"           -> "...providerZZZ"

Result both times: **All tests passed!**

Each one alone is fatal and none is a compile error. Android discovers app
widget providers by scanning for receivers that declare the APPWIDGET_UPDATE
action and carry the `android.appwidget.provider` meta-data, so with either of
those gone the tile does not appear in the widget picker at all. `exported`
false is the risk the manifest's own comment at :71 to :77 spends seven lines
justifying as true, and the test that appears to check it does not:

    expect(manifest, contains('android:exported="true"'));

MainActivity is also exported at AndroidManifest.xml:23, so that assertion is
satisfied by a completely different element and can never fail while the app has
a launcher activity. That is the same species as the `@+id/yn_asof` bug from
Lesson 5, in the same file, uncaught.

The neighbouring assertion has the same weakness in the substring form:
`contains('@xml/your_number_widget_info')` at :63 also matches
`@xml/your_number_widget_info_gone`. That one would be caught by Gradle, because
the resource would not resolve, but only in the "Android actually compiles" step
that is still uncommitted at the time of writing.

**Guard: NOT WRITTEN. NEW Open 42. Strongest tier and small.** Parse the
receiver BLOCK rather than the whole file. One regex from `<receiver` to
`</receiver>` around `.YourNumberWidget`, then assert inside that substring:
`android:exported="true"`, the APPWIDGET_UPDATE action, and
`android:name="android.appwidget.provider"` with its closing quote. The general
rule, which is the reusable part: **an assertion about one element must be
scoped to that element, or a different element will satisfy it.** In a file that
declares an activity, three receivers and two meta-data blocks, a whole-file
`contains` is a coin toss.

Credit where it is due, because a session that only lists holes is misleading:
the in-flight version of this file adds 'the layout uses ONLY classes
RemoteViews can inflate', which caught an `android.widget.Space` that would have
made the launcher draw "Problem loading widget" instead of the tile, on every
Android version, frozen in res/ until a second manual install. That is a real
catch of exactly the kind this file exists for, and it was found by an audit
before anything shipped.

**Lesson 5. Three assertions that could not fail, in one round, found three
different ways. This deserves a name.**

The brief asked whether the substring matcher is worth a named pattern. It is,
but the pattern is broader than substrings, and the evidence in this round is
better than the brief claimed.

- **The substring matcher.** From 2ebd297's commit message, recorded by the
  author against themselves: `contains('@+id/yn_asof')` also matches
  `'@+id/yn_asof_typo'`, so renaming an id left the guard green. Fixed by
  including the closing quote, now at widget_manifest_test.dart:101 to :105 with
  the reason written in. Found by breaking the code.
- **The fixture that pre-satisfied the assertion.** From
  quick_add_editor_test.dart:206 to :208, in the shipped tree: "the first
  version of this test used the default fixture, which carries an account, so
  hasData was already true and the assertion could not have failed." Found by
  re-reading the fixture.
- **The unloaded store.** From c86e2ff's commit message and preserved as a
  docstring at widget_privacy_test.dart:34 to :37: assigning `store.data`
  directly leaves `loaded` false, which makes `canWrite` false, which makes the
  tile show the failed-read face in every case, so a "no money on the tile"
  assertion "passes with flying colours while testing nothing". Found by
  printing what the code actually produced.

Three mechanisms, one shape: **the assertion is satisfied by something other
than the behaviour it names.** A matcher that matches too much, a fixture that
already satisfies it, and a setup that forces the answer. All three read as
correct tests. All three would have been described honestly as "guarded" in a QA
row.

**Guard: the strongest tier version already exists and is already in CLAUDE.md.**
It is the prove-it-can-fail rule, and it caught the first of the three. What is
missing is that the rule reads as being about NEW tests guarding new lessons,
and two of these three were about the SETUP rather than the assertion.

**NEW Open 43, medium tier by construction, because it is a sentence.** The
addition to CLAUDE.md's prove-it-can-fail section, phrased as a question that
can be asked in ten seconds: **before trusting a green assertion, ask what ELSE
would satisfy it.** Three answers to check by name, because all three have now
happened here: a longer string that contains yours, a fixture that already meets
the condition before the code runs, and a setup that puts the code on a path
where the assertion is trivially true. This is the fourth named species of "a
test that passes for the wrong reason" in this log, after a test written from
the same wrong model, an alarm that never proved its silent half, and a test
that reads layout while the bug is in state.

The stronger companion, and it is available for one of the three: **a lint or
test-of-tests that flags `contains(` on a bare identifier in a file that reads
source off disk.** There are few such sites, they are all in
widget_manifest_test.dart today, and the fix is always the same, add the
delimiter. Worth doing only if that file grows.

**Lesson 6. The scripted edit that silently does nothing is now a six instance
pattern across two days, one of them produced while writing this lesson, and it
needs a mechanical answer rather than another rule.**

Repository-corroborated instances, and the count is stated as evidence rather
than as an impression:

- 52da033's commit message, the period selector clock fix: "the python anchor
  did not match the formatted text, the assert fired, and the script exited
  before its write. Caught by grepping for the result instead of trusting the
  exit code."
- 6988747's commit message, the seedQuickAdds edit: "The python edit script
  silently did nothing AGAIN, third time today: the anchor did not survive dart
  format, the assert fired, the script exited before its write." By its own
  count that is three occurrences on 2026-07-28.
- docs/lunch-and-learn.md:454 to :460, session 15's own file-editing script,
  twice, while writing the entry that described the problem.

Session 14 named it. Session 15 proved it twice and corrected Open 31's proposed
wording, because an assert that FIRES prevents a wrong write and does nothing to
announce a missing one. This round adds two more and, importantly, adds nothing
new about the mechanism: it is always the same, an anchor written the way the
code looks in an editor cannot match the way `dart format` chose to wrap it, and
the direction flips file to file.

**The honest assessment the brief asked for: yes, this now needs a mechanical
guard, and no, it cannot have a strongest-tier one.** Every strongest-tier guard
in this project is a check that runs in CI against the repository. This failure
happens inside a chat session, before any commit exists, and its symptom is that
a file the operator believes changed did not change. No workflow can observe
that, because there is nothing yet to observe.

What IS available, ranked, and the top option is genuinely mechanical rather
than a habit:

1. **Stop using heredoc scripts to edit source files. Use the file editing tool,
   which errors when its target string is absent and cannot silently no-op.**
   This outranks any rule because it is a property of a different tool, not a
   thing to remember. It is the single change that would have prevented all six
   instances. Call it strong-medium: it works while nobody is watching, but only
   while the tool is the one being used.
2. **Where a script is genuinely necessary, put the reporting INSIDE the
   script.** End every edit script with an unconditional
   `git diff --stat -- <file>` and a printed line naming the file and whether it
   changed, and run it with `;` rather than `&&` so the report still prints when
   the assert fires. Mechanical, because the printing lives in the tool rather
   than in the operator's memory. Also cheap: three lines.
3. **Match on a normalised anchor.** Collapse runs of whitespace in both the
   file text and the anchor before searching, so a formatter's line wrapping
   cannot break a match. This removes the actual cause rather than reporting it.

Grepping for the result afterwards, which is what caught all five, is the
weakest tier and should be described that way every time it is credited.

**A sixth instance, produced by this session, while writing this lesson.** The
script that corrected two line numbers in this entry asserted on an anchor
spanning a line break, the draft had wrapped it differently, the assert fired,
and the script exited before its write. Exactly the mechanism described three
paragraphs above, in the file describing it, minutes after describing it. It was
caught by grepping for the number afterwards, which is the weakest tier habit,
and the retry that worked used no anchor at all: a plain replace of a string
short enough not to contain a line break, with the replacement count printed.

Six instances, four files, three processes, two days. This is now the most
frequently repeating finding in this log, and it is the only one whose best
available guard is a different tool rather than a test.

**Lesson 7. The standing CLAUDE.md fact check. Clean, with one sentence that is
about to become false.**

Sessions 12, 13, 14 and 15 found it clean; this is the fifth. CLAUDE.md changed
once since session 15's audit, inside fdb0e52, adding eleven lines at :268 to
:278, the "never SAY a version number until its delivery row exists" rule that
session 15 asked for. That text makes no factual claim about a path, a command
or a trigger, so there is nothing in it to be wrong. `git diff fdb0e52 HEAD
--stat -- CLAUDE.md .github/ .claude/` is empty, so every workflow is byte
identical to what session 15 audited.

Re-verified by reading and running anyway, because "unchanged" is a claim about
the file and the fact check is about the world it describes:

- Every path CLAUDE.md names exists where it says: flutter/shorebird.yaml,
  flutter/test/update_stamp_test.dart, flutter/test/screens_shot.dart,
  flutter/lib/widgets/salapify_icon.dart, flutter/lib/main.dart,
  docs/delivery-log.md, docs/qa-log.md, mobile/app/(tabs)/more.js,
  flutter/test/qa_record_test.dart, .github/workflows/flutter-check.yml,
  .github/workflows/flutter-preview.yml, .github/workflows/eas-update.yml.
- All five skills exist in .claude/skills and the split, three adapted and two
  ours, still matches the directory.
- mobile/lib/storage.js:9 still holds `salapify_data_v2`.
- mobile/package.json:11 still pins `"expo": "~54.0.0"`.
- The 120 character stamp cap is live at update_stamp_test.dart:20; the
  delivered stamp is 97.
- flutter-check.yml:20 triggers on `claude/**` with no paths filter, and runs
  the shot harness separately with `--update-goldens` at :79.
- flutter-preview.yml:17 triggers on `main` with paths `flutter/**` at :19 and
  watches its own definition at :26.
- The app id claim holds: flutter/shorebird.yaml:4 carries it in plain text and
  no token.
- The committed preview keystore claim holds:
  flutter/android/app/preview-keystore.jks exists and build.gradle.kts:42 points
  at it.
- The local SDK claim holds: /opt/flutter runs 3.44.6 stable, and analyze, test
  and the shot harness all ran from it this session.
- The three delivery commands ran as written and returned f2.75 patch 25.
- The render rule was followed this round: batch 9 added a dark-only quick add
  editor shot at screens_shot.dart:359 to :392, rendered and looked at here.

**The one sentence to watch, and it is a warning rather than a finding.**
CLAUDE.md's Flutter rule 1 describes the branch check as "analyze and test only,
on a real runner, nothing published". At the delivered tip that is defensible,
because the extra step at flutter-check.yml:79 is itself a `flutter test`
invocation and the word "only" is carrying "nothing published". The uncommitted
tree adds a `flutter build apk --debug` step to that workflow, gated on native
paths. If that lands, "analyze and test only" becomes a false description of the
branch check, and it is a description the founder and every future session read
with authority. **The fix costs one line and belongs in the same commit as the
workflow change, not in the next retrospective.** This is exactly the shape that
five consecutive sessions repeated before session 12: a sentence about a tool
that was true when written.

**One number correction, in the spirit of the log measuring rather than
inheriting.** Session 15 reported "34 patch rows and 2 release rows" in
docs/delivery-log.md. The file has 34 rows in total: 32 `patch` and 2 `release`.
Session 15 also reported 23 `MaterialApp(` sites and 33 `expectLater` sites in
screens_shot.dart at the f2.74 tip; at 0f10b11, the actual f2.74 tip, they are
22 and 32, and the 23 and 33 it measured were the live tree with batch 9 already
in it. Session 15 said out loud that its tree was moving, so this is a
confirmation of its own caveat rather than a contradiction of it.

### Open lessons carried forward

**Open 3, nothing compares the phone to main: STILL OPEN, by design.** The
founder confirmed f2.75 in person, which remains the only proof that counts.

**Open 6, the watchdog has never been observed running a scheduled pass: STILL
OPEN.** Run history is unreadable from this sandbox and `gh` is not installed
here, re-confirmed. No spurious issue in evidence, and this round's 12m01s
merge-to-row gap was well inside the 2700 second grace at
delivery-watchdog.yml:43.

**Open 7, the watchdog blind spot for merges that do not bump the stamp: STILL
OPEN.** Not exercised. Batch 9 was again committed deliberately without a stamp
bump, on a branch, with the stamp landing alongside the QA row. That is now the
settled practice and the QA record guard is what created it.

**Open 8, split the publish step from the log scraping: STILL OPEN,** re-verified
by reading. The scrape is still inside the ship step with `|| true` at
flutter-preview.yml:127 and its load-bearing comment intact at :112 to :126.

**Open 9, FAILED rows in docs/delivery-log.md: STILL OPEN.** 32 `patch` rows,
2 `release` rows, no failure rows at all.

**Open 10, nothing holds Pan's rendered size: STILL OPEN.**

**Open 11, nothing stops a sixth private kicker: STILL OPEN.**

**Open 13, the shot harness mounts screens through a private copy of the shell's
wiring: STILL OPEN, and this round gives it a clean illustration.**
`MaterialApp(` sites in screens_shot.dart are 23 at the delivered tip, up from 22
at f2.74. The new quick add editor shot at :359 to :392 mounts
`QuickAddEditor(store: store)` inside a `SingleChildScrollView`, not through
`showQuickAddEditor`. So the render could never have shown the seed-on-open
defect, because the seed lived in the wrapper the shot skips, and it also cannot
show the safe area or the height cap that QA's fourth SHOULD FIX was about. The
picture is real and it proves less than it appears to.

**Open 14, CLAUDE.md workflow item 4 versus the eas-update trigger: STILL OPEN,
untouched, re-verified.** eas-update.yml:18 still triggers only on
`claude/salapify-v2`, a branch retired in cf5c6a7.

**Open 15, the walk-keying and frame-asserting rule: STILL OPEN, flat.**
Measured the same way as the last four sessions, at the delivered tip: 10 of 33
`expectLater` sites are preceded within six lines by an `expect(`. The new quick
add editor shot is one of the 23 that are not, going straight from
`pumpAndSettle` to `expectLater`.

**Open 16, prove-it-fails says how to break the code and not how to restore it:
STILL OPEN.** `grep -rn "git checkout\|git restore" CLAUDE.md
.claude/skills/*/SKILL.md` still returns nothing. This session broke code eight
times to prove things and used two throwaway `git worktree` checkouts, the same
workaround session 15 invented. Two sessions in a row inventing the same
workaround is the argument for writing it down.

**Open 17, nothing generalises the payday guard: STILL OPEN, re-verified.**
`PlannedReminder` at flutter/lib/money/reminders.dart:25 to :29 still carries
only title, body and when.

**Open 18, the habit signal has several independent remembering events: STILL
OPEN.** `sampleTxIds` still appears at 10 sites under flutter/lib with no shared
accessor.

**Open 20, mobile/lib/notifications.js has the same sample-row defect Flutter
fixed: STILL OPEN, re-verified.** `loggedToday` is now at :100 and still reads
`(data.transactions || []).some((t) => t.date === todayISO())` with no sample
exclusion.

**Open 21, the balance label guards are example-shaped: STILL OPEN.**
`grep -rn "never refused as an overdraft" flutter/test/` still returns nothing.

**Open 23, a shared centavo helper exists and nothing points at it: STILL HALF
CLOSED.** flutter/lib/money/thirteenth.dart:20 still carries a private `_round2`
and nothing in the porting skill names the shared one.

**Open 25, nothing says that a test for a default must exercise the untouched
path: STILL OPEN.** CLAUDE.md did not change on this point.

**Open 26, a defect found by looking is not fixed until an assertion fails on the
old behaviour: STILL OPEN, but this round is its best round yet.** Both of the
f2.74 fixes session 15 proved unguarded are now guarded, and both re-proven live
here. See the guard re-check.

**Open 27, whether to port a DISPLAY bug faithfully: EXERCISED, and answered
deliberately.** Batch 9 diverges from RN on purpose in two places, and fdb0e52
put both divergences INTO the goldens with RN's own answer recorded beside each,
so the replay stays a statement about RN and nobody later "fixes" the port back.
That is the pattern this open lesson was asking for, applied by hand.

**Open 29, nothing decides what counts as money math: STILL OPEN.** The quick add
engine was locked to RN across 22 golden cases, which is the right call, and
nothing in the repository would have required it.

**Open 30, nothing distinguishes a test that asserts how the code behaves from a
test that asserts a fact about the world: STILL OPEN.** Lesson 3's proposal, that
the Kotlin key set and the Dart key set be compared by reading both files, is the
same family: an assertion about a fact that spans two languages.

**Open 31, nothing says how to edit or undo safely: STILL OPEN, RESTATED with a
ranking.** Six documented instances now, one of them produced by this session
while writing the lesson about it. See Lesson 6 for the three mechanical options
and their honest ceiling.

**Open 32, one sanitizer makes every raw money read safe and nothing at any read
site says so: STILL OPEN.** Still 12 files under flutter/lib/screens/ containing
`is num`.

**Open 33, a proven-to-fail failure line proves ONE assertion: STILL OPEN.**
fdb0e52 quotes one failure line and describes six findings.

**Open 34, half of the first deliberate golden-lock divergence was unguarded:
STILL HALF CLOSED.** flutter/test/statement_golden_test.dart:28 is still named
'every statement matches the RN text byte for byte' and still says nothing about
the injected formatter.

**Open 35, a report can be accurate in every word and still function as a
promise: STILL OPEN, and NOT exercised this round.** The founder was not sent to
their phone by anything this round. The rule at CLAUDE.md:268 to :278 has now
been live for one full batch with nothing to test it against, which is neither
evidence for nor against it.

**Open 36, nothing stops a widget test depending on the real calendar: HALF
CLOSED, and the closing is verified.** Session 15's live instance is fixed:
screens_shot.dart now mounts Activity with `clock: () => DateTime(2026, 7, 28)`
and a four line comment naming session 15 as the finder. What remains open is
the class guard, making the clock a REQUIRED parameter on widgets that read
today, so `DateTime.now` has to be typed at the call site.

**Open 37, an ambiguous finder is a user interface report and gets filed as a
test-authoring chore: STILL OPEN.** No new chip screens this round.

**Open 38, two fixes shipped with no guard: CLOSED, and both guards re-proven
live this session.** See the guard re-check for the failure lines.

**NEW Open 39: nothing tests that opening a read-only screen writes nothing.**
The quick add editor flipped `hasData` true and deleted Menu's BRING YOUR DATA
OVER card by being opened. Instance guarded at quick_add_editor_test.dart:199.
Candidate class guard, strongest tier: an empty-app test that opens and closes
every sheet in a list and asserts `store.data` is unchanged and `hasData` is
still false, plus a second assertion that the list covers every `show*Editor`
and `show*Sheet` found by grepping lib/screens off disk, so the list cannot rot.

**NEW Open 40: a conditional settings key is pinned in one direction only.**
Proven live: emitting `quickAddsEdited` unconditionally fails ten tests;
DROPPING it leaves all 1001 passing, and `sanitizeData` runs on every load, so
that direction resurrects the four default quick adds for anyone who deleted
them on purpose. Candidate guard, strongest tier and about six lines: an
omission-and-presence test mirroring paluwagan_store_test.dart:101. General rule
worth writing beside backup.dart:490: a conditional key needs two tests, because
RN fixtures can only ever prove the absent direction.

**NEW Open 41: the home tile's decision surface is not the file that claims to
hold it.** Proven live at 2ebd297: misspelling the app lock key, misspelling the
privacy key, and setting the accent to the background colour all leave 1026
tests passing and analyze clean; renaming a key in the Kotlin, or changing the
tap encoding, does the same. Candidate guards, strongest first: compare the
Kotlin's `getString` key set against the keys `HomeTile.push` writes by reading
both files; then make widget_privacy_test.dart call `HomeTile.push` behind a
mock platform channel instead of its private `_tile` copy at :45.

**NEW Open 42: widget_manifest_test.dart misses three fatal native mistakes.**
Proven live, individually and together, against both the committed and the
in-flight version of the file: deleting the APPWIDGET_UPDATE intent-filter,
setting the receiver to `exported="false"`, and renaming the
`android.appwidget.provider` meta-data all leave every test passing. The
`exported` assertion at :62 is satisfied by MainActivity, a different element.
Candidate guard, strongest tier: scope every manifest assertion to the receiver
BLOCK, and never assert about one element with a whole-file `contains`.

**NEW Open 43: an assertion can be satisfied by something other than the
behaviour it names, and three different mechanisms did that in one round.** A
matcher that matches too much, a fixture that already satisfies the condition,
and a setup that forces the answer. Guard is a medium tier addition to
CLAUDE.md's prove-it-can-fail section: before trusting a green assertion, ask
what ELSE would satisfy it, and check those three by name. This is the fourth
named species of "a test that passes for the wrong reason" in this log.

### Guard status re-check

Read and re-run, not assumed. `git diff fdb0e52 HEAD --stat -- .github/
CLAUDE.md .claude/` returns NOTHING in the committed tree, so every workflow
line the last eight entries recorded still stands. Verified by reading anyway,
and by breaking several of them:

- The duplicate stamp refusal: PRESENT, flutter-preview.yml:165 to :181.
  Correctly silent, the stamp was distinct.
- The `|| true` scrape guard: PRESENT, flutter-preview.yml:127, comment intact.
- The nothing-shipped failure issue: PRESENT, flutter-preview.yml:223 onward.
  Not fired, correctly.
- The release install shout: PRESENT, flutter-preview.yml:249 onward. Correctly
  silent this round, the row reads `patch`. It WILL fire on the widget batch,
  and that is the intended behaviour, verified by reading the branch logic at
  :103 to :110.
- The publisher watching its own definition: PRESENT at flutter-preview.yml:26.
- The delivery watchdog's `--first-parent` and 2700 second grace: PRESENT,
  delivery-watchdog.yml:99 and :43.
- flutter-check.yml on `claude/**` with NO paths filter: PRESENT at :20, and the
  separate shot harness run at :79.
- The stamp cap: PRESENT, update_stamp_test.dart:20; the delivered stamp is 97
  of 120 characters.
- **The QA record guard: PRESENT, and it produced its third consecutive row.**
  docs/qa-log.md:35 exists because the build fails without it. It is still the
  most valuable guard built in this log.
- **Session 15's two new guards: PRESENT and BOTH RE-PROVEN LIVE.** In a clean
  worktree at dd213ca, reverting the picker bounds at
  flutter/lib/widgets/period_selector.dart:78 to :82 back to a constant
  `firstDate` with no clamp, and separately removing `initialPeriod:
  Period.monthOf(_ref)` from flutter/lib/screens/reports.dart:532:

      lastDate 1975-12-31 00:00:00.000 must be on or after firstDate 2000-01-01
      Failed assertion: line 231 pos 5: '!lastDate.isBefore(firstDate)'
      00:04 +16 -2: the date picker opens on a phone whose clock is in 1970 [E]

      Expected: no matching candidates
        Actual: Found 1 widget with text containing ₱500 descending from widget
      00:03 +12 -1: tapping a category row carries the month you were reading [E]

  Third consecutive round in which a retrospective's own recommendation was
  implemented and then verified by the next retrospective. Open 38 is closed.
- Session 14's reminder centavo guard: PRESENT at person_sheet_test.dart:310.
- Session 12's guard, 'the DEFAULT is moving, not untagging': PRESENT at
  categories_screen_test.dart:137.
- Session 13's guard, 'a cap fires for an entry logged with the main Log
  button': PRESENT at categories_screen_test.dart:234.
- Sessions 6 through 11 guards: PRESENT, spot-checked by grep, none deleted.
- The shot harness: RUNS, verified rather than assumed. `flutter test
  test/screens_shot.dart --update-goldens` in the clean worktree reports 37
  passing render tests writing 49 files.
- The whole delivered suite: 1001 pass and analyze clean, measured in a clean
  checkout of dd213ca, up from 982 at f2.74.

**No guard was found deleted, disabled or routed around, and no test was deleted
or inverted this round.** `git diff 0f10b11 379f696 -- flutter/test/` shows
1296 insertions and 14 deletions, and every deletion is `dart format`
re-wrapping the signature of a test that still exists. No assertion changed
meaning, which means nothing in this round's suite was defending a defect.

The nearest thing to a bad finding is again the opposite shape, and it is
bigger than last round: four separate guards that read as coverage and are
satisfied by something other than the thing they name. The conditional key
guarded in one direction, the privacy test asserting a copy of the code, the
manifest test satisfied by a different element, and the substring matcher that
matched a renamed id. All four look right. Three of the four were found by
deliberately breaking working code, which is the only method that has ever found
this class here.

---

## 2026-07-28, session 15: the words were accurate and the founder still went looking

f2.74 delivered cleanly, was confirmed on the founder's phone, and nothing
broken reached it. Eighth clean delivery in a row on the mechanical side, and
the second round running where the pre-merge QA pass ran, found real defects,
and every must-fix was fixed before the merge instead of after.

The patch is clean. The session is not short, because the headline is not a code
failure at all. Between f2.73 and f2.74 the founder went to the phone, tapped
check for update, and found nothing new. They were right: f2.74 was sitting
unmerged on the working branch at that moment. The message that sent them there
was accurate in every word. CLAUDE.md predicts this exact event, by name, in the
section written to prevent it. So the interesting question is not who was
careless. It is why a rule can describe an event precisely and still not stop it.

Three other things are worth the time. A set of tests shipped with a fuse in
them, four days from turning the branch check red, while a file written in the
same commit by the same author states the exact rule they broke. A user
interface collision that no test caught was caught by looking at the render, and
the one automated warning that did exist was silenced by the person who received
it. And a scripted edit silently did nothing for the second time in one day,
this time WITH the assert session 14 recommended already in place.

### What we believed / What was true

**Believed: f2.74 reached the phone. TRUE, and confirmed in person.** From
`git show origin/main:docs/delivery-log.md | tail -1`:

    | 2026-07-28 15:34 UTC | f2.74 | 24 | patch | 0.6.2+11 | 22f15d85 (run 30373019870) |

Mode `patch`, so nothing was stranded and no manual install is owed.
flutter/pubspec.yaml:12 still reads `version: 0.6.2+11`, unchanged since
session 5. The stamp in the tree at flutter/lib/main.dart:30 is
`'f2.74 · Activity can now show just one month, one year, or any date range you
pick.'`, 83 characters against the 120 cap at
flutter/test/update_stamp_test.dart:20. Stamp in the code, stamp in the log,
stamp on the phone: three for three.

**Believed: the merge used a merge commit, not a squash. TRUE, verified.**
`git cat-file -p 22f15d8` shows two parents, d851266 and 52da033.

**Believed: the suite is green on what shipped. TRUE, re-run in a clean
checkout.** A throwaway worktree at 0f10b11, the delivered tip, reports
`flutter analyze` clean and `flutter test` at **+982: All tests passed!**, up
from 951 at f2.73. The caveat is stated rather than smoothed over, because this
log measures rather than inherits: the working tree this session sat in was also
being used to write the NEXT batch while the session ran, and batch 9 was
committed as 6988747 at 16:39 UTC partway through. Every number in this entry
that describes what shipped was therefore measured in the clean worktree, not in
the live tree.

**Believed: the QA pass ran BEFORE the merge. TRUE, with a record.**
docs/qa-log.md:34 carries an f2.74 row naming 3 MUST FIX, 5 SHOULD FIX and 2
deferred findings. The row exists because flutter/test/qa_record_test.dart made
the build fail without it, for the second consecutive round.

**Believed: three of the new tests were going to start failing on 1 August 2026.
NOT EXACTLY. Two would have failed on 1 August. Measured, not assumed.** The
fuse is completely real and this correction does not soften it. Method: a
throwaway worktree at 6c8ecfb, the pre-fix commit, with the selector's default
clock at flutter/lib/widgets/period_selector.dart:42 (`clock ?? DateTime.now`)
simulated forward, because the fixtures cannot move and the calendar can. At
1 August 2026, 2 of the 10 tests in that file fail, with exactly the two failure
lines the commit message quotes:

    Actual: Found 0 widgets with text "ThisMonth" descending from widgets
    00:01 +1 -1: picking Month narrows the list to this month [E]
    Actual: Found 0 widgets with text "June 2026": []
    00:02 +4 -2: stepping back a month shows that month, and its name [E]
    00:03 +8 -2: Some tests failed.

At 1 January 2027 it is four, adding 'picking Year keeps this year and drops the
one before' and 'the period and the text filter both apply'. So the honest
statement is that the fuse was lit for two tests in four days and for four tests
in five months. Both the commit message and the docs/qa-log.md row say three.

**Believed: the two orange chips both saying "All" reached a commit. FALSE, and
this matters for how the event is read.** The collision was caught during batch 8
and fixed before that batch was committed. The pre-fix commit 6c8ecfb already
carries `if (allowAll) (PeriodMode.all, 'All time')` at
flutter/lib/widgets/period_selector.dart:101, and already carries the guard test
'the two chip rows do not both say All'. So this is not a defect that shipped and
was retrofitted. It is a defect that existed for the length of one work session
and never left the branch. Everything else about the account holds, and the
repository corroborates the mechanism, below.

**Believed: f2.74 was unmerged at the moment the founder checked the phone.
CONSISTENT with the timeline, and the words themselves are not in the
repository.** The stamp was bumped to f2.74 inside 52da033 at 14:56:32 UTC. The
merge landed at 15:22:06 UTC. The delivery row was written at 15:34:17 UTC. So
there is a 26 minute window in which a build named f2.74 existed in the
repository and on no phone, preceded by a 20 minute window in which the batch
existed with the old stamp. What was actually said in chat leaves no artifact
here, so this entry treats the wording as reported and the timing as proven.

### Timeline (with evidence)

All times UTC, from `git log --format=%cI` and the publisher's own rows.

| Time | Event | Evidence |
|------|-------|----------|
| Jul 28 14:09:35 | f2.73 patch 23 delivered, confirmed on the phone | d851266 |
| 14:34:52 | f4753ea, session 14 written up. Also carries two code fixes it recommended, announced in its own commit message | commit stat: statement.dart and person_sheet_test.dart |
| 14:36:04 | 6c8ecfb batch 8, the period selector. 3913 lines added. **No stamp bump**, deliberately, so the stamp lands with the QA row | commit message |
| between | **The founder checks the phone and finds nothing new.** f2.74 does not exist yet, then exists only on the branch | reported; window proven above |
| 14:56:32 | 52da033 QA round. Stamp bumped to f2.74. 3 MUST FIX, 5 SHOULD FIX | commit message, docs/qa-log.md:34 |
| 15:22:06 | Merge #231 (22f15d8), two parents | `git cat-file -p 22f15d8` |
| 15:34:17 | f2.74 patch 24 delivered, 12m11s after the merge | delivery row, 0f10b11 |
| after | **Founder confirms f2.74 on the phone** | founder |
| 16:39:37 | Batch 9 committed on the branch while this session ran | 6988747 |

### Divergence point

**There is no delivery divergence. Eight in a row.** There is no correctness
divergence that reached the phone either, for the second round running.

The divergence this round is between what was true and what the founder had
reason to believe, and it can be dated exactly. It is **14:56:32 UTC**, the
moment the string `f2.74` entered the repository. From that moment there existed
a name for something the founder could look for, and no row anywhere saying it
had arrived. The founder looked. Nothing was there. Twenty six minutes later it
was.

Worth saying plainly: the split was not caused by anything untrue. Every
individual sentence in the report was correct. The divergence was created by
naming a build before it existed anywhere the founder could reach.

### Root cause

**1. The rule governs the ACT of merging. The failure was in the WORDS about not
having merged yet.**

CLAUDE.md's "Finished means delivered" section, at CLAUDE.md:253 to :259, reads:

    Concretely, before answering any new question or starting any new work:
    - If a pull request is open with finished work in it, merge it or say out
      loud, to the founder, why it is waiting. Never silently move on.
    - After merging, watch the build through and report the patch number from
      docs/delivery-log.md.
    - The founder should never have to tap "check for update" to discover whether
      something was finished. If they are asking, the reporting already failed.

Read it as an instruction and it was followed. The work was not silently moved
on from. The reason for waiting was said out loud, and it was the true reason.
Read it as a promise to the founder and it was broken, because the third bullet
is not addressed to the same actor as the first two. The first two tell Claude
what to DO. The third describes a state of the FOUNDER, and nothing in between
connects the doing to the state.

So this is not a gap in the rule's coverage. The rule names the event with
uncomfortable precision. It is a gap in what the rule attaches to: it attaches to
merging, and the harmful act was speaking.

**2. "Ready" and "waiting on the check" are true sentences whose effect on a
beginner is a phone check.**

The founder is not a release engineer and does not hold a model of the pipeline.
Given "f2.74 is ready", the reasonable inference is that a thing exists with that
name. The word "ready" is doing something the speaker did not intend and the
listener could not be expected to discount. Naming the stamp made it worse and is
the specific, fixable part: a stamp name is exactly the token the founder is
trained to compare against the phone. CLAUDE.md itself trains them to do that, at
the delivery check section, which tells them the row and the phone can be
compared directly and that this comparison is the one thing they can do that
Claude cannot.

**3. The mechanical half already exists, and it points at the log instead of the
founder.**

.github/workflows/flutter-check.yml:91 to :105 already computes exactly the two
numbers this failure was about:

    - name: Branch stamp vs the stamp actually delivered
      ...
        echo "This branch builds stamp: ${BRANCH:-unknown}"
        echo "Last stamp on the phone:  ${DELIVERED:-none recorded}"

and its comment at :82 to :90 says why it was built: "a batch once sat in an open
pull request while the founder tapped check-for-update and read back the old
stamp". So a previous session built a check for precisely this and made it
informational, correctly, because failing on it would cry wolf on every push. The
check is right and it is aimed at a log file. The founder does not read GitHub
Actions logs. The gap is not detection. It is delivery of the detection.

**4. For the fuse and the ambiguous finder, one shared root: a rule stated in a
file does not travel to the file next door, even inside one commit.**

This is session 14's headline arriving for the second day running, and this time
the distance is smaller than ever. flutter/test/goldens/gen-period-goldens.js:10
to :12, in commit 6c8ecfb, states:

    // Every fixture that involves "today" passes an explicit ref date. periodIsFuture
    // falls back to `new Date()`, and a golden file whose answers change depending
    // on the day it was generated is not a golden file.

That is the rule the widget tests in the same commit broke, written by the same
author, in a sibling directory, hours apart at most. The generator was made
clock-explicit. The widget tests were not. Nothing carried the sentence across,
because nothing exists to carry it: the rule lives in a comment attached to one
file, and comments do not travel.

### Lessons and guards

**Lesson 1. A report can be accurate in every word and still function as a
promise. That is a fourth distinct cause of delivery confusion, and it is the
first one with no automated guard available.**

The three earlier causes each got a guard, and each guard holds:

- A test that passed locally and failed on a runner: guarded by
  .github/workflows/flutter-check.yml running the whole suite on every push to a
  `claude/**` branch, with no paths filter. Strongest tier.
- A QA pass that was simply skipped: guarded by docs/qa-log.md plus
  flutter/test/qa_record_test.dart. Strongest tier, and it fired again this round.
- Finished work never merged at all: guarded by CLAUDE.md's "Finished means
  delivered" rule. Medium tier by construction, because it is prose.

This round is the fourth cause: **finished-sounding words about unfinished work**.
Nothing catches it, and the honest reason is that the artifact is a sentence in a
chat window. No test, no workflow, and no assertion can read it. Every automated
guard in this project inspects the repository, and the repository was correct at
every instant.

**Guard, and its strength stated honestly: MEDIUM, a rule tied to a specific
moment. NEW Open 35 for the class.** The rule that fits the actual failure, and
which is narrow enough to be checkable by the person about to break it:

> Never write a stamp name (f2.xx) to the founder before a delivery row exists
> for it. Until that row exists, say what is happening in words that cannot be
> looked up on the phone: "nothing new on your phone yet, I will tell you when
> there is." The stamp name is the founder's lookup key. Handing them a key
> before the door exists is what sends them to the door.

Two things make this stronger than an intention without making it strong.

First, it names the exact keystroke that triggers it, which is typing an
`f` followed by a digit into a message. That is a much better trigger than
"report carefully", because it is recognisable in the moment.

Second, there is a mechanical assist that already exists and costs nothing: the
three delivery commands in CLAUDE.md, which read the row rather than guessing. If
a stamp name is about to be typed, those three commands settle whether it may be.

**What would be stronger, and why it is not available.** The strongest version of
this guard would be an automated message to the founder when, and only when, a
delivery row appears, so that no interim status message is ever needed. The
publisher already writes the row and already opens GitHub issues for two other
conditions (nothing shipped, at flutter-preview.yml:223, and a release needing a
manual install, at :248). Neither of those reaches the founder's phone either.
There is no channel from this repository to the founder that they actually watch,
other than the app itself and Claude's own messages. Until there is, this lesson
stays at medium tier and should be described that way every time it is cited.

**A weaker but real fallback if this recurs: stop reporting progress between
merges entirely.** Two messages per batch, "starting X" and "delivered as f2.xx,
patch N". That removes the class rather than patching it, at the cost of the
founder hearing less. It is written down here so that the next session has
somewhere to escalate to, rather than repeating the same medium guard louder.

**Lesson 2. Three tests were pinned to July while the screen they mounted read
the real calendar, and the rule against exactly that was written into a file in
the same commit.**

The defect: flutter/test/period_selector_test.dart mounts HistoryScreen with
fixtures hard coded to July 2026, and pre-fix the screen passed no clock to
PeriodSelector, whose constructor defaults to `clock ?? DateTime.now` at
flutter/lib/widgets/period_selector.dart:42. Every assertion about "this month"
was therefore an assertion about the day the suite happened to run.

Measured this session, in a clean pre-fix worktree, rather than taken from the
commit message: two of those tests fail on 1 August 2026, four fail by
1 January 2027. See the beliefs section for the failure lines. The commit message
and the QA row both say three. The direction of the finding is right and the
count is wrong, which is worth recording because this log has now corrected a
QA row's arithmetic twice in two sessions.

The sharp part is not the mistake, it is the distance. The rule was written in
flutter/test/goldens/gen-period-goldens.js:10 to :12, quoted in full under Root
cause, in the same commit, about the same concept, for the JS generator. It says
an answer that changes with the day it was generated is not a fixed answer. Two
directories away, in Dart, the same author let three answers depend on the day.
Session 14's headline was a rule applied in one file and not its sibling. This is
the same shape on the next day, with the gap narrowed from "hours apart" to "same
commit".

**Guard for the instance: SHIPPED, strongest tier, re-proven live this session.**
HistoryScreen now takes an injectable clock, at flutter/lib/screens/history.dart:99
(`final DateTime Function()? clock;`) and :132
(`DateTime _now() => (widget.clock ?? DateTime.now)();`), and the test mounts it
with `clock: _now` at flutter/test/period_selector_test.dart:60. The comment at
:53 to :57 records why. Pushing the injected clock to August in the CURRENT tree
still fails those same two tests, which is the correct behaviour: the fixtures and
the clock are now both pinned and both under the test's control.

**Guard for the class: NOT WRITTEN. NEW Open 36.** Nothing stops the next widget
test from mounting a screen that reads the real calendar. The candidate guard is
small, mechanical and strongest tier: **make the clock a required parameter rather
than a defaulted one on any widget that reads today**, so `DateTime.now` has to be
typed at the call site by whoever wants it. A defaulted clock is invisible at the
call site, and a test author cannot forget a parameter the compiler demands.
Currently `PeriodSelector.clock` defaults at period_selector.dart:42 and
`HistoryScreen.clock` is nullable at history.dart:99, so both can be omitted in
silence.

**An instance of the same class that is still live, found by this session and not
filed by anyone.** flutter/test/screens_shot.dart:443 mounts
`HistoryScreen(store: store, onMenu: () {})` with no clock, for three shots
(`history-period-dark.png`, `history-period-custom-dark.png`,
`history-period-month-dark.png` at :450, :462 and :478). The QA fix injected the
clock into the widget test and not into the photograph. Stated precisely and
without inflation: this cannot turn a build red, because CI runs the harness with
`--update-goldens` so it only writes. What it means is that the month label in the
third shot is whatever month the machine thinks it is, so two runs on two days
produce different pictures for reasons that have nothing to do with the code, and
a reviewer comparing them is comparing the calendar. Small, real, and exactly the
sentence the generator header was written to prevent.

**Lesson 3. The only automated warning about the "All" collision was a failing
finder, and it was treated as a test-authoring annoyance.**

What happened, from the commit message of 6c8ecfb and the two comments it left
behind: on Activity, the period row sat directly above the type filter row, both
led with an orange chip, and both chips said "All". Looking at the render showed
it at a glance. No test asserted anything about it.

But one test did react. `find.text('All')` was ambiguous, because there were two,
and an ambiguous finder throws. The response was to scope the finder past the
ambiguity. That artifact is still in the delivered tree, at
flutter/test/period_selector_test.dart:96 to :100:

    /// Scoped to the selector. The type filter row on Activity sits right below
    /// this one, so a bare find.text can reach the wrong chip.
    Finder _chip(String label) => find.descendant(
      of: find.byType(PeriodSelector),
      matching: find.text(label),
    );

Read that docstring cold and it is good practice. Read it knowing what happened
and it is a description of the bug, written as if it were a testing convenience.
Two chips on one screen carry the same word, therefore the test must disambiguate.
The person who wrote that sentence had all the information and filed it under
housekeeping.

The code now records the correction, at
flutter/lib/widgets/period_selector.dart:119 to :124:

    // 'All time', not 'All'. On Activity this row sits directly above the
    // type filter row, whose first chip is also called All and is also
    // highlighted, so two orange chips called All stacked on top of each
    // other and neither said which was which. The render showed it; no test
    // did, and the test that DID trip over the ambiguity was rewritten to
    // scope past it, which silenced the only warning there was.

**What makes an ambiguous finder recognisable as a user interface signal rather
than a chore.** This is the useful part of the lesson, so it is worth being
precise instead of moralising. The two cases are genuinely different and the
difference is checkable in seconds:

- The duplicates are in DIFFERENT parts of the screen that a person reads
  separately, for example the same word inside a text field and inside a list
  row. Scoping is correct. `_row` at :103 to :106 is exactly this case, and its
  docstring says so: typing a word into the filter puts that word on screen
  inside the field.
- The duplicates are in the SAME visual band, side by side or stacked, both
  drawn in the same accent, both tappable. Then the finder is not confused. The
  USER is. Scoping is suppressing the report.

So the recognisable question, asked at the moment the finder throws, is: **would
a person looking at this screen also have to disambiguate?** If yes, it is a
defect. If no, scope it.

**Guard for the instance: SHIPPED, strongest tier.**
flutter/test/period_selector_test.dart:146 to :154, 'the two chip rows do not
both say All', asserting `find.text('All')` finds exactly one widget and
`find.text('All time')` finds exactly one. Any future rename that recreates the
collision makes the first assertion ambiguous again, and this time it fails as a
named guard rather than as noise in an unrelated test.

**Guard for the class: NOT WRITTEN. NEW Open 37.** There is a strongest tier
candidate here and it is broader than one screen: **a test that mounts each
screen and asserts no two chips visible at once carry the same label.** The chip
labels are the app's own strings, the widgets are all `ChoiceChip` or
`FilterChip`, and the assertion is a set comparison. That works while nobody is
watching, on screens nobody thought to look at. The medium tier fallback, if the
sweep is judged too large, is the paragraph above written into CLAUDE.md beside
the render rule, since the render rule is where a person already is when this
happens.

**Lesson 4. A scripted edit silently did nothing, for the second time in one day,
and this time the assert session 14 asked for was already there.**

From the commit message of 52da033, recorded by the author against themselves:

    One process note worth recording. The clock fix silently did not apply on its
    first attempt: the python anchor did not match the formatted text, the assert
    fired, and the script exited before its write. Caught by grepping for the
    result instead of trusting the exit code.

**Corroboration from the diff, since session 14 could only report its instance.**
The edit target was `_openHistory` in the pre-fix test file. At 6c8ecfb its mount
is a single physical line:

    home: Scaffold(body: HistoryScreen(store: store)),

and in the delivered tree it is three, because adding `clock: _now` pushed it past
the line width and `dart format` reflowed it:

    home: Scaffold(
      body: HistoryScreen(store: store, clock: _now),
    ),

An anchor written the way the code reads in an editor, across lines, cannot match
a formatter-collapsed single line, and an anchor written flat cannot match a
formatter-expanded block. Both directions occur in the same file within one
commit. That is the mechanism, and it is now demonstrated twice in one day from
two different commits, in opposite directions, which makes it a property of the
toolchain rather than an unlucky afternoon.

**The important difference from session 14, and it is a correction to Open 31's
proposed wording.** Session 14's recommendation was that an edit script should
assert its match count BEFORE writing. Here the assert was present and it fired.
The edit still silently did not happen, because an assert that fires prevents a
WRONG write and does nothing to announce a MISSING one. The failure moved one
step downstream: from "wrote the wrong thing" to "wrote nothing, and the next
step assumed it had". Open 31's wording, followed exactly, would not have
prevented this round's instance.

**Guard: MEDIUM at best as prose, and there is a mechanical option that is
genuinely stronger. Open 31 restated.** The mechanical option is available today
and requires no new code: **do not edit source files with heredoc scripts at all.
Use the file editing tool, which fails loudly when its target string is absent and
cannot silently no-op.** That is not a habit, it is a property of a different
tool, which is why it ranks above the rule. Where a script is genuinely necessary,
for example a hundred call sites, the script must END by printing
`git diff --stat` for the file it claimed to change, so that "nothing happened" is
visible in the same output as "it worked".

The thing that actually caught it this time was neither: it was grepping for the
result. That is a habit, weakest tier, and it worked, and it should not be relied
on again.

**A third instance, produced by this session while writing this entry.** The
script that corrected line numbers in this file asserted on anchors that did not
match, because the draft's own line wrapping split them differently than expected,
and it exited before its write. Twice. Both times it was caught by grepping for
the result rather than by the exit status, which is the same weakest-tier habit
described above. Three instances in one day, in three different files, by two
different processes, is enough evidence to stop treating this as bad luck.

**Lesson 5. Two fixes shipped with no test at all, and one of them is a repeat of
a bug this project already found and guarded elsewhere.**

Proven this session, by removing each fix in a clean worktree at the delivered tip
and running the whole suite:

- **The date picker crash on a device clock before 1995.** MUST FIX number 2 in
  the QA round. Reverting the clamp at flutter/lib/widgets/period_selector.dart:78
  to :82 back to a constant `firstDate` and an unclamped `initialDate` leaves
  **+982: All tests passed!**
- **The Reports carry-over.** Removing `initialPeriod: Period.monthOf(_ref)` from
  flutter/lib/screens/reports.dart:532 leaves **+982: All tests passed!** The
  existing drilldown test at flutter/test/reports_screen_test.dart:97 to :100
  asserts the pushed Activity route pre-fills the category name, and asserts
  nothing about the period, so tapping "Food ₱4,200" under June could silently go
  back to listing every month's Food without a single test objecting.

Neither is a hidden failure. The commit message quotes a failure line for findings
1, 3, 4, 5, 6 and 8 and quotes none for finding 2 or for the Reports fix, so
nobody claimed guards that do not exist. What is missing is that the record does
not distinguish them. The docs/qa-log.md row describes all of them identically as
"fixed and re-checked".

The picker crash deserves its own sentence, because it is not a new bug shape. The
identical bug was found by QA in the edit sheet and IS guarded, at
flutter/test/edit_entry_test.dart:225 to :264, whose reason string reads:

    'Opening the picker on a pre-2015 entry crashed on the '
    'firstDate assertion before the clamp.'

So the project has met this exact assertion failure before, wrote a test for it
there, and shipped the same fix in a new widget with no test. The fix's own
comment at period_selector.dart:69 to :77 even says the hazard was known and only
half handled the first time. It is now fully handled and completely unguarded.

**Guard: NOT WRITTEN. NEW Open 38.** Two candidates, and the cheap one is
strongest.

Cheap and strongest tier, about six lines: **a picker bounds test for
PeriodSelector, mirroring edit_entry_test.dart:225**, mounting the selector with a
clock at 1970 and asserting `find.byType(DatePickerDialog)` appears. It costs
minutes and it closes a bug shape that has now occurred twice.

Structural and medium tier: **the QA log row should mark which findings have a
guard and which do not.** A row that says "3 MUST FIX fixed" reads as "3 MUST FIX
fixed and guarded" to every future reader, including the next retrospective. A
row that says "fixed, guard: none" is a sentence someone has to write on purpose,
which is the same mechanism that made the QA record guard work.

**Lesson 6. The standing CLAUDE.md fact check. Clean this round, and the check is
the reason to say so out loud.**

Five consecutive sessions found a false factual claim in CLAUDE.md before session
12. Sessions 12, 13 and 14 found it clean. This round it is clean again, and
CLAUDE.md did not change at all: `git log f4753ea..origin/main --oneline --
CLAUDE.md .github/ .claude/` returns exactly one commit, 52da033, and it touched
only `.claude/agents/home-screen-widget-designer.md`, a new agent file. CLAUDE.md
and every workflow are byte identical to what session 14 audited.

Re-verified by reading and running anyway, because "unchanged" is a claim about
the file and the fact check is about the world the file describes:

- Every path CLAUDE.md names exists where it says: flutter/shorebird.yaml,
  flutter/test/update_stamp_test.dart, flutter/test/screens_shot.dart,
  flutter/lib/widgets/salapify_icon.dart, flutter/lib/main.dart,
  docs/delivery-log.md, docs/qa-log.md, mobile/app/(tabs)/more.js,
  flutter/test/qa_record_test.dart.
- All five skills exist in .claude/skills and the description of them, three
  adapted and two ours, still matches the directory.
- mobile/lib/storage.js:9 still holds `salapify_data_v2`.
- mobile/package.json:11 still pins `"expo": "~54.0.0"`.
- The 120 character stamp cap is live at update_stamp_test.dart:20; the shipped
  stamp is 83.
- flutter-check.yml:20 triggers on `claude/**` with no paths filter, and runs the
  shot harness separately with `--update-goldens` at :79.
- flutter-preview.yml triggers on `main` with paths `flutter/**` and watches its
  own definition.
- The local SDK claim holds: /opt/flutter runs 3.44.6 stable, analyze and test
  both ran from it this session.
- The three delivery commands ran as written and returned f2.74 patch 24.
- The render rule was followed this round and paid for itself: batch 8 added a
  dark-only Activity shot at screens_shot.dart:396, and looking at it is what
  caught the "All" collision.
- The "directory listing is the count" sentence still holds; flutter/test/shots
  now carries 51 files.

**One fact worth recording that is not an error.** Session 14's own commit,
f4753ea, is a docs commit that also changed flutter/lib/money/statement.dart and
flutter/test/person_sheet_test.dart. That is announced clearly in its commit
message and both changes are the guards session 14 asked for, so it is not a
smuggled edit. It is noted here only so that a future reader running
`git log -- flutter/lib/money/` is not surprised to find code inside a
retrospective.

### Open lessons carried forward

**Open 3, nothing compares the phone to main: STILL OPEN, by design.** The
founder confirmed f2.74 in person, which remains the only proof that counts.

**Open 6, the watchdog has never been observed running a scheduled pass: STILL
OPEN.** Run history is unreadable from this sandbox and `gh` is not installed
here, re-confirmed this session. No spurious issue in evidence, and this round's
12m11s merge-to-row gap was well inside the 2700 second grace at
delivery-watchdog.yml:43.

**Open 7, the watchdog blind spot for merges that do not bump the stamp: STILL
OPEN.** Not exercised, the merge bumped the stamp. Batch 8 was again committed
deliberately without a stamp bump, on a branch rather than at a merge, which is
now the settled practice created by the QA record guard.

**Open 8, split the publish step from the log scraping: STILL OPEN,** re-verified
by reading, the scrape is still inside the ship step with `|| true` at
flutter-preview.yml:127 and its load-bearing comment intact at :112 to :126.

**Open 9, FAILED rows in docs/delivery-log.md: STILL OPEN.** The log now carries
34 `patch` rows and 2 `release` rows and no failure rows at all.

**Open 10, nothing holds Pan's rendered size: STILL OPEN.**

**Open 11, nothing stops a sixth private kicker: STILL OPEN.**

**Open 13, the shot harness mounts screens through a private copy of the shell's
wiring: STILL OPEN, and it grew again.** `MaterialApp(` sites in screens_shot.dart
are now 23, up from 21. The new ones hand-build Activity at :443 with no clock,
which is also the live instance of NEW Open 36 described in Lesson 2.

**Open 14, CLAUDE.md workflow item 4 versus the eas-update trigger: STILL OPEN,
untouched, re-verified.** eas-update.yml:18 still triggers only on
`claude/salapify-v2`, a branch retired in cf5c6a7.

**Open 15, the walk-keying and frame-asserting rule: STILL OPEN, and it slipped
again, though less than the raw number suggests.** Measured the same way as the
last three sessions, 10 of 33 `expectLater` sites are preceded within six lines by
an `expect(`, against 9 of 29 last session, so the ratio is flat. Fairly stated:
the second and third new Activity shots at :462 and :478 are preceded by taps on
scoped finders, which do fail loudly when the control is absent, so they are not
blind. The first, at :450, goes straight from `pumpAndSettle` to `expectLater`.

**Open 16, prove-it-fails says how to break the code and not how to restore it:
STILL OPEN.** `grep -rn "git checkout\|git restore" CLAUDE.md .claude/skills/*/SKILL.md`
still returns nothing. This session broke the delivered code three times to prove
things and used a throwaway `git worktree` each time, which is a cleaner
workaround than the previous three sessions invented and is written down here so
the fourth session does not invent a fifth.

**Open 17, nothing generalises the payday guard: STILL OPEN, re-verified.**
`PlannedReminder` at flutter/lib/money/reminders.dart:25 to :29 still carries only
title, body and when.

**Open 18, the habit signal has several independent remembering events: STILL
OPEN.** `sampleTxIds` still appears at 10 sites under flutter/lib with no shared
accessor.

**Open 20, mobile/lib/notifications.js has the same sample-row defect Flutter
fixed: STILL OPEN, re-verified.** `loggedToday` at :99 still does not exclude the
sample ids.

**Open 21, the balance label guards are example-shaped: STILL OPEN.**
`grep -rn "never refused as an overdraft" flutter/test/` still returns nothing.

**Open 23, a shared centavo helper exists and nothing points at it: HALF CLOSED,
and the closing is verified.** flutter/lib/money/statement.dart:238 now reads
`final open = round2(totalLent - totalPaid);` and imports it at :29, replacing the
hand-inlined `(((totalLent - totalPaid) * 100) + 0.5).floorToDouble() / 100`
session 14 measured. The two are identical by construction:
accounts_calc.dart:7 defines `_jsRound(x) => (x + 0.5).floorToDouble()`. What
remains open is the pointer: flutter/lib/money/thirteenth.dart:20 still carries a
private `_round2`, and nothing in the porting skill names the shared one.

**Open 25, nothing says that a test for a default must exercise the untouched
path: STILL OPEN.** CLAUDE.md did not change on this point.

**Open 26, a defect found by looking is not fixed until an assertion fails on the
old behaviour: STILL OPEN, and this round is its clearest instance yet.** Two
fixes shipped with no assertion at all, both proven unguarded by removing them
against a green suite. See Lesson 5 and NEW Open 38.

**Open 27, whether to port a DISPLAY bug faithfully: STILL OPEN.** Not exercised
this round. Batch 8 made the opposite kind of decision on purpose and wrote it
down: the malformed period shapes RN produces are reproduced rather than tidied,
because none is reachable from the selector and locking them stops a future
refactor rendering the word 'null' on the screen.

**Open 29, nothing decides what counts as money math, so a ported rule written
inside a screen escapes the golden contract: STILL OPEN, and batch 8 is the best
counter-example so far.** The period engine is not money math and was locked as
hard as money math, with the reason written in the commit message: it decides
WHICH money a screen adds up, so a period that quietly drops an entry makes every
total wrong while every total still looks right. That is the right instinct
applied by hand. Nothing in the repository would have required it.

**Open 30, nothing distinguishes a test that asserts how the code behaves from a
test that asserts a fact about the world: STILL OPEN.** Not exercised this round.

**Open 31, nothing says how to edit or undo safely: STILL OPEN, RESTATED, and its
previous wording is now known to be insufficient.** An assert before writing
prevents a wrong write and does not announce a missing one. See Lesson 4 for the
replacement wording and the mechanical option that outranks it.

**Open 32, one sanitizer makes every raw money read in every screen safe and
nothing at any read site says so: STILL OPEN, unchanged.** Still 12 files under
flutter/lib/screens/ containing `is num`. Batch 8 added no new money reads.

**Open 33, a proven-to-fail failure line proves ONE assertion: STILL OPEN, and
this round gives it a second shape.** Six of this round's eight findings carry a
failure line, and the QA row describes all eight identically. NEW Open 38 is the
concrete fix for the recording half.

**Open 34, half of the first deliberate golden-lock divergence was unguarded:
HALF CLOSED, and the closed half is re-proven live.** f4753ea added the reminder
centavo guard. Re-proven this session by removing `money: formatMoney` from the
Remind call at flutter/lib/screens/utang.dart:707 in a clean worktree:

    Expected: contains '₱100.50'
      Actual: 'Hi Ana! Friendly reminder about the ₱101 total you still owe.
    00:02 +10 -1: the reminder shows centavos too, not just the statement [E]

The OTHER half is still open, exactly as session 14 described it:
flutter/test/statement_golden_test.dart:28 is still named 'every statement matches
the RN text byte for byte' and still says nothing anywhere about the injected
formatter, so the one file a reader opens to learn what the lock covers still
tells them something that is not true of the shipped app.

**NEW Open 35: a report can be accurate in every word and still function as a
promise.** The fourth distinct cause of delivery confusion in this log, and the
first with no automated guard available, because the artifact is a sentence in a
chat window that no checker can read. Guard is the medium tier rule in Lesson 1:
never write a stamp name to the founder before a delivery row exists for it.
Escalation if it recurs: two messages per batch and no interim status at all.

**NEW Open 36: nothing stops a widget test depending on the real calendar.**
Proven live: two tests would have failed on 1 August 2026, four by 1 January 2027.
Fixed for this instance by injection. Candidate guard, strongest tier and small:
make the clock a REQUIRED parameter on widgets that read today, so `DateTime.now`
has to be typed at the call site. Live instance still in the tree:
screens_shot.dart:443 mounts Activity with no clock for three shots.

**NEW Open 37: an ambiguous finder is a user interface report and gets filed as a
test-authoring chore.** The distinguishing question, and it takes seconds: would a
person looking at this screen also have to disambiguate? Candidate guard,
strongest tier: a test asserting no two chips visible at once carry the same
label. Medium fallback: that question written into CLAUDE.md beside the render
rule, which is where someone already is when this happens.

**NEW Open 38: two fixes shipped with no guard, and the record does not
distinguish a guarded fix from an unguarded one.** Proven live: removing the
picker clamp, and separately removing the Reports period carry-over, each leaves
all 982 tests passing. The picker crash is a repeat of a bug shape already guarded
at edit_entry_test.dart:225. Candidate guards: a six line picker bounds test for
PeriodSelector, strongest tier; and a "guard: none" column or phrase in the
docs/qa-log.md row, medium tier, so that an unguarded fix has to be written down
as one.

### Guard status re-check

Read and re-run, not assumed. `git log f4753ea..origin/main -- .github/workflows/
CLAUDE.md` returns NOTHING, so every workflow line the last seven entries recorded
still stands. Verified by reading anyway, and by breaking three of them:

- The duplicate stamp refusal: PRESENT, flutter-preview.yml:165 to :181.
  Correctly silent, the stamp was distinct.
- The `|| true` scrape guard: PRESENT, flutter-preview.yml:127, comment intact.
- The nothing-shipped failure issue: PRESENT, flutter-preview.yml:223 onward. Not
  fired, correctly.
- The release install shout: PRESENT, flutter-preview.yml:248 onward. Correctly
  silent, the row reads `patch`.
- The publisher watching its own definition: PRESENT.
- The delivery watchdog's `--first-parent` and 2700 second grace: PRESENT,
  delivery-watchdog.yml:99 and :43.
- flutter-check.yml on `claude/**` with NO paths filter: PRESENT at :20, the
  separate shot harness run at :79, and the informational stamp comparison at :91.
- The stamp cap: PRESENT, update_stamp_test.dart:20; the shipped stamp is 83 of
  120 characters.
- **The QA record guard: PRESENT and RE-PROVEN LIVE, and it fired for real a
  second time.** Setting the delivered stamp to f9.99 in a clean worktree:

      Stamp f9.99 has 0 rows in docs/qa-log.md, expected exactly one. Add a row
      saying who reviewed this batch and what they found. SKIPPED is a valid
      verdict; a missing row is not, because a missing row is what shipped a
      broken monthly cap to the founder's phone in f2.71.

  Second consecutive round in which a retrospective's own recommendation stopped
  something. It is now the most valuable guard built in this log.
- **Session 14's new reminder centavo guard: PRESENT and PROVEN LIVE**, failure
  line quoted under Open 34.
- Session 12's guard, 'the DEFAULT is moving, not untagging': PRESENT at
  flutter/test/categories_screen_test.dart:137.
- Session 13's guard, 'a cap fires for an entry logged with the main Log button':
  PRESENT at flutter/test/categories_screen_test.dart:234.
- Sessions 6 through 11 guards: PRESENT, spot-checked by grep, none deleted.
- The whole delivered suite: 982 pass and analyze clean, measured in a clean
  checkout of 0f10b11, up from 951 at f2.73.

**No guard was found deleted, disabled or routed around, and no test was deleted
or inverted this round.** The nearest thing to a bad finding is the opposite
shape: two fixes shipped with no guard at all, both proven unguarded here, and one
warning that DID exist, an ambiguous finder, was routed around by scoping before
it was understood. That last one is the closest this log has come to a guard being
silenced by hand, and it is worth remembering that it was silenced for an entirely
reasonable-sounding reason, written into a docstring that still reads as good
practice.

---

## 2026-07-28, session 14: the rule was written down, and the same shape came back anyway

f2.73 delivered cleanly, was confirmed on the founder's phone, and nothing
broken reached it. Seven clean deliveries in a row on the mechanical side, and
the first round in this log where the pre-merge QA pass ran, found seven real
defects, and every one of them was fixed before the merge instead of after.

So the patch is clean and the session is not short, because the interesting
material is entirely in how the batch got there.

Three things stand out. The guard session 13 asked for was built two minutes
after session 13 was written, and it failed the build on its first live use.
The silent-zero shape session 13 had just named came back in the same round, in
new code, which is worth understanding rather than scolding. And this session
had to correct two confident claims made by the round it is reviewing: one in a
commit message, one in session 13's own text. Both are corrected below with the
evidence that settles them.

### What we believed / What was true

**Believed: f2.73 reached the phone. TRUE, and confirmed in person.** From
`git show origin/main:docs/delivery-log.md | tail -1`:

    | 2026-07-28 14:09 UTC | f2.73 | 23 | patch | 0.6.2+11 | 0e72729f (run 30366039823) |

Mode `patch`, so nothing was stranded and no manual install is owed.
flutter/pubspec.yaml:12 still reads `version: 0.6.2+11`, unchanged since
session 5. The stamp in the tree at flutter/lib/main.dart:29 to :30 is
`'f2.73 · Share a statement of account with anyone who owes you, and see every
payment they made.'`, 95 characters against the 120 cap at
flutter/test/update_stamp_test.dart:20. Stamp in the code, stamp in the log,
stamp on the phone: three for three.

**Believed: the merge used a merge commit, not a squash. TRUE, verified.**
`git cat-file -p 0e72729` shows two parents, b61d451 and 8e319e8.

**Believed: the suite is green on what shipped. TRUE, re-run this session.**
`flutter analyze` reports "No issues found! (ran in 4.2s)" and `flutter test`
reports "All tests passed!" at +958. One honest caveat, because this log
measures rather than inherits: the working tree during this session also
carried uncommitted work for the NEXT batch (flutter/lib/money/period.dart, a
period selector widget, and flutter/test/period_golden_test.dart, which is 7 of
those 958 on its own). The delivered commit therefore carries 951, up from 935
at f2.72.

**Believed: the QA pass ran BEFORE the merge this time. TRUE, and for the first
time there is a record rather than a claim.** docs/qa-log.md carries a row for
f2.73 naming 3 MUST FIX, 4 SHOULD FIX and 4 deferred findings. The row exists
because flutter/test/qa_record_test.dart made the build fail without it.

**Believed (commit 8e319e8, finding 2): the settled row read a stored amount of
"2400" as zero and printed "₱0 paid" beside a statement saying ₱2,400, and this
is "the silent-zero class that has now shipped twice". FALSE as stated, and
proven false this session.** The code shape was really there. The input cannot
be. Every load goes through `sanitizeData` at flutter/lib/data/store.dart:315,
which routes receivables through `_utangList` at flutter/lib/data/backup.dart:432,
which coerces every amount with `_num` at :587 and every payment amount at :592.
Probed directly: a stored blob carrying `'amount': '2400'` arrives in the screen
as `2400.0`, runtime type `double`. Then the pre-fix expression was put back and
the same fixture rendered through the real sheet:

    expect(find.text('₱2,400 paid'), findsOneWidget);
    expect(find.text('₱0 paid'), findsNothing);
    00:00 +1: All tests passed!

against the BROKEN code. So two of the four assertions in the guarding test pass
on the defect they are named for. The other half of that same finding, the
₱2,000 utang marked paid printing "₱1,250 paid", is completely real and was
genuinely proven to fail. This matters and it is Lesson 1.

**Believed (finding 5): the same payment showed two different amounts on the
same sheet in the shipped app.** Same correction applies to the reachability
half: payment amounts are coerced by the same sanitizer on the same load path,
so the `'0x10'` case cannot arrive at the screen either. The fix and the fixture
extension are still correct and still valuable, because the golden lock is a
parity contract over a PURE function and must hold for any input, not only for
inputs the app can currently produce. The finding is right about the code and
overstated about the phone.

**Believed (session 13): "No shared centavo helper exists in flutter/lib/money/".
FALSE.** `round2` has existed at flutter/lib/money/accounts_calc.dart:11, public
and documented, since the accounts port. What is true is that nothing routes
anyone to it, and this round's new code hand inlined it again at
flutter/lib/money/statement.dart:237:

    final open = (((totalLent - totalPaid) * 100) + 0.5).floorToDouble() / 100;

which is `round2` spelled out. Open 23 is not "no helper exists". It is "a
helper exists and nothing points at it", which is a different and much more
fixable problem.

**Believed: the 20 statement goldens still compare byte for byte after the
formatter was made injectable. TRUE, verified by comparison, not by trust.** The
`statements` and `reminders` arrays in flutter/test/goldens/statement_goldens.json
are byte identical between 8824469 and the delivered tree, 20 and 9. Only the
`history` fixtures changed, 7 to 9.

### Timeline (with evidence)

All times UTC, from `git log --format=%cI` and the publisher's own rows.

| Time | Event | Evidence |
|------|-------|----------|
| Jul 28 13:19:12 | 8b3e2a4, session 13 written up. Names the silent-zero class and escalates Open 28, the missing QA record | commit |
| 13:21:04 | ead214f builds Open 28's guard: docs/qa-log.md plus flutter/test/qa_record_test.dart, both halves proven | commit message |
| 13:22:44 | 8824469 batch 7, the statement. **Deliberately does NOT bump the stamp**, because the guard now ties the stamp to a QA row | commit message: "The stamp and its docs/qa-log.md row land together with the QA round" |
| between | Stamp bumped to f2.73. **The new guard fails the build.** The row is written | reported in 8e319e8; the guard re-proven live this session, below |
| 13:46:38 | 8e319e8 QA round. 3 MUST FIX, 4 SHOULD FIX, 4 deferred, every guard with a failure line | commit message, docs/qa-log.md |
| 13:58:13 | Merge #230 (0e72729), two parents | `git cat-file -p 0e72729` |
| 14:09:35 | f2.73 patch 23 delivered, 11m22s after the merge | delivery row, d851266 |
| after | **Founder confirms f2.73 on the phone** | founder |

One thing the timeline cannot tell you, said plainly rather than smoothed over.
The first three commits land inside three and a half minutes of each other,
which means they were COMMITTED together, not that the code was written in that
order. So this entry does not claim batch 7's code was written after session 13's
lesson. It claims something narrower and checkable: session 13's lesson was in
the repository before batch 7 was, and it did not stop the shape.

### Divergence point

There is no delivery divergence. Seven in a row.

There is no correctness divergence that reached the phone either, which is the
first time that sentence can be written about a round where seven real defects
existed. Every one of them was caught before the merge by the pass CLAUDE.md
requires, which ran because a test made not running it expensive.

The belief divergence is small and worth naming exactly: **8e319e8's commit
message and its docs/qa-log.md row both state, as fact, that a string amount
printed ₱0 on the founder's screen.** It did not, it could not, and the test
written to guard it passes against the broken code. Nothing was harmed by that
sentence except the accuracy of the record, and the record is the thing this
log is for.

### Root cause

**1. One sanitizer makes every raw money read in every screen safe, and nothing
at any read site says so.**

`sanitizeData` is a total function over stored data. It runs on load, on
restore, and on snapshot rollback, and it coerces every money field to a finite
double. That is a genuinely good design. Its cost is that a reader looking at
`(r['amount'] is num) ? (r['amount'] as num).toDouble() : 0.0` in a screen file
cannot tell whether it is a dangerous cast or a redundant one, because the thing
that decides lives in another file entirely.

So a QA pass reasoning from the read site files a real-sounding finding for an
unreachable case, and a fix applied at one read site leaves the identical
expression 117 lines away in the same class. Measured this session: 12 files
under flutter/lib/screens/ contain `is num`, and
flutter/lib/screens/utang.dart:959 still reads

    final amount = (r['amount'] is num) ? (r['amount'] as num).toDouble() : 0.0;

in `_utangCard`, which is the exact expression removed from `_settledRow` at
:842 in the same commit. flutter/lib/screens/edit_sheet.dart:99 and
flutter/lib/screens/history.dart:350 do the same to stored transaction amounts.
All three are currently safe, and none of them says why.

**2. The port contract is the only thing that forces a coercion decision, and it
only reaches files that are ports.**

The obvious reading of this round is that the same author applied the rule in
flutter/lib/money/statement.dart and forgot it one file over. The code says
otherwise. statement.dart's `_num` at :51 carries its own reason at :47 to :50:
"JS `Number(x)`, with anything not finite folded to 0, exactly as statement.js
does". It exists because the porting contract demands byte parity with a JS
function that coerces, not because anyone remembered a lesson about zero. The
screen file is not a port of anything, so nothing demanded anything.

That is session 13's Open 29 arriving a second time from a different direction.
Open 29 said a ported RULE written inside a screen escapes the golden contract.
This round adds: a NON ported rule written inside a screen escapes every
convention the contract carries with it, including how to read a stored number.

**3. Proving a test can fail proves ONE assertion in it, and the commit records
it as proving the test.**

CLAUDE.md's prove-it-can-fail section is one of the strongest habits in this
project and it ran seven times this round. What it produces is one failure line
per FINDING. A test that makes four assertions gets one line, and the other
three are never exercised against the broken code. Here two of the four were
decorative, and the commit message and the QA log both read as though all four
had been earned.

Session 13 named the species "proving a test can fail proves the test is WIRED
UP, it says nothing about whether the behaviour it pins is correct". This is the
neighbouring species: **it says nothing about the assertions the failure line
did not come from.**

### Lessons and guards

**Lesson 1. The silent-zero shape recurred, and the honest version is narrower
and more useful than the headline.**

What is true: `_settledRow` in flutter/lib/screens/utang.dart was written in
this round with a raw `is num` cast on stored money, days after the class was
named. What is not true: that it printed ₱0 to anybody. Proven above.

What was really wrong in that row, and it was real, is the other half. The
pre-fix expression at 8824469:flutter/lib/screens/utang.dart:727 to :729 was

    final amount = engine.remainingOf(r) > 0
        ? engine.remainingOf(r)
        : ((r['amount'] is num) ? (r['amount'] as num).toDouble() : 0.0);

on a row whose label reads "paid". A ₱2,000 utang marked paid with a ₱750
logged payment printed "₱1,250 paid", which is what was LEFT. As the commit
message puts it, the ternary had no correct case.

**Guard for the instance: SHIPPED, strongest tier, genuinely proven failing.**
flutter/test/person_sheet_test.dart:303, with the recorded failure line
`Actual: Found 0 widgets with text "₱2,000 paid"`. Re-proven this session by
restoring the old expression: the same line fails today.

**Guard for the class: NOT WRITTEN. NEW Open 32.** The candidate is automatable
and specific: **a test that fails when a file under flutter/lib/screens/ reads a
stored money field with a raw `is num` cast instead of `ledger.amountOf`.**
Strongest tier when written. It needs the same audit Open 29 needs first, which
is the work; the check afterwards is easy. The cheap half that can be done today
is a sentence at the top of flutter/lib/data/backup.dart's sanitize section
saying which fields it guarantees are numbers, so a read site can be checked
against something instead of guessed at.

**Lesson 2. A name is not an identity. This one was real, reachable, and shipped
nowhere.**

QA reproduced a Statement of Account, a document that leaves the phone and lands
in another person's chat app, billing one Ana for ₱7,000 of a different Ana's
debt. Both gather functions keyed on the lowercased resolved name.

Reachable from ordinary data, and the route is worth stating because it crosses
apps: mobile/app/person.js:97 to :108, `saveEdit`, renames a person with no
uniqueness check at all, so two people called Ana is a state the live RN app
will happily produce. RN itself does not then show this bug, because its person
screen filters by id at mobile/app/person.js:54 and :63. So this is a PORT
defect and not a ported one: the Flutter sheet dropped an identity check the
original had.

**Guard: SHIPPED, strongest tier, proven failing.**
flutter/test/person_sheet_test.dart:224, 'two people who share a name get two
separate statements', asserting both directions:

    expect(sent.single, contains('Ana one'));
    expect(
      sent.single,
      isNot(contains('Ana two')),
      reason: "billing one person for a different person's debt",
    );

The one deliberate difference from RN, that utang with no id at all are still
included rather than dropped, is written into the code at
flutter/lib/screens/utang.dart:45 to :48 with its reason: dropping them
understates a real debt in a real document.

**Lesson 3. Session 13's most valuable unbuilt guard was built two minutes
later and failed the build on its first live use. First time in this log.**

Session 13 escalated Open 28, the QA gate that leaves no artifact, and ranked it
the highest value unwritten guard in the log. ead214f built it at 13:21:04:
docs/qa-log.md, one row per shipped stamp, and flutter/test/qa_record_test.dart,
which fails when the current `updateStamp` has no row.

Both halves were proven at build time, which is the house rule for alarms:
fires on a missing row, silent on a present one. **Re-proven live this session**
rather than taken from the commit message. Setting the stamp to f9.99 in the
delivered tree:

    Stamp f9.99 has 0 rows in docs/qa-log.md, expected exactly one.
      Expected: an object with length of <1>
        Actual: []

and restoring it: `00:00 +1: All tests passed!`

Then it earned its keep the same day. Bumping the stamp to f2.73 failed the
build until the row was written. And there is a second, quieter piece of
evidence that it was already changing behaviour before it ever went red: batch 7
was committed with NO stamp bump, and its message says why, that the stamp and
its QA row land together with the pass "because a row written before the pass
finishes is the exact false sentence that guard exists to make hard". A guard
that reshapes how work is committed before it has fired once is doing more than
its assertion.

**What it cannot do, in its own words**, from the header of
flutter/test/qa_record_test.dart:

    // This cannot verify a pass really ran. Nothing automated can. What it does
    // is make forgetting impossible and make skipping a sentence written down
    // on purpose. SKIPPED is an accepted verdict here, and a far better outcome
    // than silence.

Two things to add to that, neither of which is a criticism of the guard.

First, this session found the limit in practice, not in theory. The f2.73 row is
detailed and honest, and two of its MUST FIX descriptions overstate what could
reach a phone. A presence check cannot audit the contents of the sentence it
forces someone to write. It was never going to, and the file says so.

Second, and the founder should know this one: the same test also runs on the
DELIVERY path, at .github/workflows/flutter-preview.yml:71. A missing QA row is
now a red build, and a red build publishes nothing at all. That is the intended
strength. It is also a way for a documentation mistake to strand the founder
silently, and the backstop for that is the nothing-shipped failure issue at
flutter-preview.yml:223, which is present and has never had to fire.

**Lesson 4. An edit script that used unconditional replacements silently did
nothing, and left the document contradicting itself. The event is reported; the
mechanism and the symptom are corroborated by the diff.**

Reported: a python heredoc script rewrote the statement's formatter call sites
with `str.replace()` and no assert on the match count, `dart format` had already
reflowed two of them, so those replacements silently did nothing while the rest
fired. The result was worse than making no change at all: the statement's line
items printed in whole pesos while its Total lent printed in centavos, so the
document contradicted itself more visibly than before.

**What this session can and cannot verify, stated plainly.** There is no
committed artifact of the failed run. No intermediate commit exists (`git log
--all` and the reflog show only the four commits of this round), and no script
is in the tree. So the event itself remains reported.

What the diff DOES establish is the mechanism and that the symptom fits nothing
else. In the pre-fix file, `grep -n formatMoneyText
8824469:flutter/lib/money/statement.dart` gives nine call sites. Exactly three of
them, :216, :217 and :221, sit inside expressions `dart format` had wrapped
across physical lines, and all three are the utang LINE ITEMS. The other six,
including `'${t.totalLent}: ${formatMoneyText(totalLent)}'` at :261, are single
line. A single-line search pattern misses exactly the wrapped ones and hits
exactly the rest, which produces line items in whole pesos over a Total lent in
centavos, and nothing else in that file produces that.

It was caught by flutter/test/person_sheet_test.dart:326, written minutes
earlier, asserting the exact expected text rather than a total:

    expect(sent.single, contains('Jeep   ₱100.50'));

**Guard: STILL NOT WRITTEN. Open 31 stands, with sharper wording available.**
Session 13 proposed **verify before you write, never after, so a failed check
leaves the file untouched.** This round adds the other half of the same
sentence: **an edit script asserts its match count BEFORE writing, because a
replacement that matches nothing is silent, and silence after a formatter has
touched the file is the normal case, not the rare one.** Medium tier, because it
is prose that has to be read at the right moment.

Worth saying out loud: the thing that actually caught this was not a rule and
would not have been. It was a test that pinned exact output text. That is the
strongest available guard here and it already exists as a habit in this project.

**Lesson 5. The first deliberate divergence from RN's OUTPUT in a golden locked
area. The reasoning is sound, the lock is intact, and half of it is unguarded.**

The finding: RN's whole peso formatter makes the shared statement visibly fail
to add up. Two utang of ₱100.50 print as ₱101 and ₱101 over a total of ₱201, and
the friend holding the document adds 101 and 101 and gets 202.

The fix injects the formatter. The default stays RN's, so the golden replay
still compares byte for byte; the screen passes the app's centavo formatter.

**Is the reasoning sound? Yes, and for a reason worth writing down.** The golden
lock exists to catch PORT errors: structure, ordering, arithmetic, the
reconciling lines a transcription drops. It was never meant to freeze a display
choice. A document whose own lines contradict its own total is worse than a
document that differs from the old app, because the second is invisible to the
person holding it and the first is the only thing they can see.

**Is the lock actually intact? Yes, verified rather than asserted.** The
`statements` and `reminders` arrays in
flutter/test/goldens/statement_goldens.json are byte identical before and after,
20 statements and 9 reminders. Only the `history` fixtures grew, 7 to 9, and
that growth is a separate and good thing: the old junk fixtures only carried
values that Dart's `double.tryParse` and JS `Number()` agree on, so the lock
could not see a real coercion divergence. Extending them is Open 22's rule being
applied, one round after session 12 closed it. Worth noting honestly that QA
found the gap, not the rule.

**Is it recorded well enough for a future reader? In three places out of four.**
flutter/lib/money/statement.dart:10 to :22 explains it at length. The call site
at flutter/lib/screens/utang.dart carries its own comment. The widget test at
flutter/test/person_sheet_test.dart:309 explains it again. The file that does
NOT mention it is flutter/test/statement_golden_test.dart, whose first test is
named 'every statement matches the RN text byte for byte' and which says nothing
about injection anywhere. That is the one file a future reader opens to learn
what the lock covers, and it currently tells them something that is no longer
true of the shipped app.

**And one half of the divergence has no guard at all. Proven this session.**
Deleting `money: formatMoney` from the Remind call in
flutter/lib/screens/utang.dart leaves every test green:

    00:02 +15: All tests passed!

So a future reader "restoring RN parity" can silently put whole peso rounding
back into a message that goes to a friend, and nothing anywhere will object. The
statement half IS guarded: removing the same argument there breaks the ₱100.50
test.

**Guards, TWO, both strongest tier, both about three lines. NEW Open 34.**
First, a reminder centavo test beside the statement one, so both halves of the
divergence fail loudly when undone. Second, a test in
flutter/test/statement_golden_test.dart that builds one centavo fixture both
ways and asserts they differ by name, so the divergence is asserted in the file
that would otherwise mislead, rather than described in three files a reader may
never open.

**Lesson 6. The stale test assertions after a copy change are NOT a lesson, and
saying so is the finding.**

Reported: looking at the render led to changing two labels, two test assertions
went stale, running the single test file passed and only the full suite surfaced
them.

There is no repository artifact. Only flutter/test/person_sheet_test.dart and
flutter/test/screens_shot.dart reference that sheet at all, and both were
written in the same commit as the labels, so nothing can be reconstructed.

The assessment, and it is a real result rather than a shrug: this is ordinary
work, and the guard for it already exists and already worked. The Flutter check
runs the WHOLE suite on a real runner on every push to a `claude/**` branch,
with no paths filter, at .github/workflows/flutter-check.yml:20 and :61. A stale
assertion cannot reach main whether or not anyone runs the full suite by hand.
Running one test file was never a check and nothing in this project ever said it
was. No new guard, and nothing carried forward.

What IS worth keeping from it is the reason the labels changed: looking at the
render caught a card printing raw ISO dates ("due 2026-06-30") directly above a
history that formatted them properly, and a running total labelled "in total"
while the column counts down as it is read. Both were invisible to a green
suite. That is the render doing exactly the job CLAUDE.md gives it, for the
third round running.

**Lesson 7. The standing CLAUDE.md fact check. One rule changed, it is accurate,
and everything else still matches.**

Four consecutive sessions found a false factual claim in CLAUDE.md, which is why
this is a step and not a favour. Sessions 12 and 13 found it clean. This round it
is clean again, and the one new sentence checks out.

`git log 8b3e2a4..origin/main --oneline -- .github/workflows/ CLAUDE.md .claude/`
returns exactly one commit, ead214f, which touched CLAUDE.md only. Its new
sentence claims flutter/test/qa_record_test.dart "fails on the runner when the
current stamp has no row". Verified by reading the wiring, not just the test:
flutter-check.yml sets `working-directory: flutter` at :47 and runs
`flutter test` at :61, so the test's `File('../docs/qa-log.md')` resolves; the
same test also runs at flutter-preview.yml:71. Re-verified everything else by
reading and running regardless:

- Every path CLAUDE.md names exists where it says: flutter/shorebird.yaml,
  flutter/test/update_stamp_test.dart, flutter/test/screens_shot.dart,
  flutter/lib/widgets/salapify_icon.dart, flutter/lib/main.dart,
  docs/delivery-log.md, mobile/app/(tabs)/more.js, and now docs/qa-log.md.
- All five skills exist in .claude/skills and the file's description of them
  (three adapted, two ours) still matches the directory.
- mobile/lib/storage.js:9 still holds `salapify_data_v2`.
- mobile/package.json:11 still pins `"expo": "~54.0.0"`.
- The 120 character stamp cap is live at update_stamp_test.dart:20; the shipped
  stamp is 95.
- flutter-check.yml:20 triggers on `claude/**` with no paths filter;
  flutter-preview.yml:17 triggers on `main` with paths `flutter/**` at :19 and
  its own definition at :26.
- CI runs the shot harness separately with `--update-goldens`:
  flutter-check.yml:80.
- The local SDK claim holds: /opt/flutter reports Flutter 3.44.6 stable.
- The three delivery commands ran as written and returned f2.73 patch 23.
- The brightness sentence still matches the harness: the new person sheet shot
  sets `Brightness.dark` at screens_shot.dart:405 and renders dark only, which
  is what the corrected sentence says happens to screens that are not tabs.
- The "directory listing is the count" sentence still holds; test/shots now
  carries 50 files.

**The correction this round is to session 13, not to CLAUDE.md**, and it is in
the beliefs section above: `round2` at flutter/lib/money/accounts_calc.dart:11
is a shared centavo helper and session 13 said none existed. Open 23 is restated
accordingly below.

**One thing the fact check can see and nobody filed.** The new person sheet shot
mounts `PersonSheet(store: store, name: 'Migs')` at screens_shot.dart:412, with
no `personId`. After the QA fix, that is the LEGACY id-less path; the app's own
call at utang.dart:265 passes a personId. The photograph is real and the screen
is right, and it is a photograph of the fallback rather than of what the founder
sees. Filed under Open 13 rather than as a new item.

**Lesson 8. Is the streak real? The delivery half yes, seven in a row. The
correctness half produced its first clean round since the question was raised.**

The DELIVERY half is mechanical and it works. f2.67 through f2.73 each have a
row, each mode `patch`, each against an unchanged 0.6.2+11, each confirmed on
the phone. Merge to row was 11m50s, 11m54s, 11m04s, 11m33s and now 11m22s.

The CORRECTNESS half has been called unsolved in every entry since session 10,
and session 13 recorded the failure it had been predicting. This round is the
first evidence in the other direction: the gate ran before the merge, found
seven real defects including one that would have sent a wrong document to
another person, and none of them reached the phone. One round is not a trend and
the gate is now backed by a test rather than by memory, which is the difference
between this round and f2.71.

The tally that has never moved still has not moved: **the automated suite has
still never found a novel defect.** Every finding this round came from the QA
pass, from looking at the render, or from a golden fixture someone chose to
extend. What is new is that the suite now HOLDS more of them: seven new guards,
six of them earned with a real failure line.

### Open lessons carried forward

**Open 3, nothing compares the phone to main: STILL OPEN, by design.** The
founder confirmed f2.73 in person, which remains the only proof that counts.

**Open 6, the watchdog has never been observed running a scheduled pass: STILL
OPEN.** Run history is unreadable from this sandbox and `gh` is not installed
here. No spurious issue in evidence, and this round's 11m22s gap was well inside
the 2700 second grace at delivery-watchdog.yml:43.

**Open 7, the watchdog blind spot for merges that do not bump the stamp: STILL
OPEN.** Not exercised, the merge bumped the stamp. Worth noting that batch 7 was
committed deliberately without a stamp bump this round, which is exactly the
shape Open 7 describes, on a branch rather than at a merge.

**Open 8, split the publish step from the log scraping: STILL OPEN,**
re-verified by reading, the scrape is still inside the ship step with `|| true`
at flutter-preview.yml:127 and the load-bearing comment intact.

**Open 9, FAILED rows in docs/delivery-log.md: STILL OPEN.** The log now carries
32 `patch` rows and 2 `release` rows and no failure rows at all, so the f2.73
build that went red on the missing QA row left no trace in the file a reader is
told to trust. That is the clearest instance of Open 9 yet: the log records what
shipped and cannot distinguish "nothing was ready" from "something failed".

**Open 10, nothing holds Pan's rendered size: STILL OPEN.**

**Open 11, nothing stops a sixth private kicker: STILL OPEN.**

**Open 13, the shot harness mounts screens through a private copy of the shell's
wiring: STILL OPEN, and it grew again.** `MaterialApp(` sites in
screens_shot.dart are now 21, up from 20. The new one hand-builds the person
sheet at :407 and, as noted in Lesson 7, mounts the legacy no-personId path.

**Open 14, CLAUDE.md workflow item 4 versus the eas-update trigger: STILL OPEN,
untouched, re-verified.** eas-update.yml:17 still triggers only on
`claude/salapify-v2`, a branch retired in cf5c6a7.

**Open 15, the walk-keying and frame-asserting rule: STILL OPEN, and it slipped
this round.** The new person sheet shot goes straight from `pumpAndSettle` to
`expectLater` at screens_shot.dart:418 with no assertion about what is in front
of the camera. Measured the same way as the last two sessions, 9 of 29
`expectLater` sites are now preceded by such an assertion, down from 9 of 28.
The MEDIUM tier is still not done: the screens_shot.dart header records three
hard-won harness rules and asserting the frame is not one of them, which is
precisely why it slips.

**Open 16, prove-it-fails says how to break the code and not how to restore it:
STILL OPEN.** `grep -n "git checkout\|restore" CLAUDE.md .claude/skills/*/SKILL.md`
still returns only two unrelated hits about backup and restore as a product
feature. This session broke the code three times to prove things and restored
each time from a saved copy in the scratch directory, which is the third session
running to invent the same workaround privately.

**Open 17, nothing generalises the payday guard: STILL OPEN, re-verified.**
`PlannedReminder` at flutter/lib/money/reminders.dart:25 to :29 still carries
only title, body and when.

**Open 18, the habit signal has five independent remembering events: STILL
OPEN.** `sampleTxIds` is still filtered at quickadd.dart:28 and :60,
reminders.dart:112, coach.dart:313 and chain.dart:69. No shared accessor.

**Open 20, mobile/lib/notifications.js has the same sample-row defect Flutter
fixed: STILL OPEN, re-verified.** `loggedToday` at :99 still does not exclude the
sample ids.

**Open 21, the balance label guards are example-shaped: STILL OPEN.**
`grep -rn "never refused as an overdraft" flutter/test/` still returns nothing.

**Open 22, the fixture audit rule: CLOSED in session 12, and this round shows it
working.** The statement history fixtures were extended from 7 to 9 precisely
because the junk cases only carried values both coercions agree on. Found by QA
rather than by the rule, which is worth remembering when ranking it.

**Open 23, the "*100 overflow" rule lives in prose and was walked into anyway:
STILL OPEN, and RESTATED.** Session 13's wording was wrong. A shared centavo
helper does exist, `round2` at flutter/lib/money/accounts_calc.dart:11. The real
problem is that nothing points at it: statement.dart:237 hand inlined it again
this round, and loan.dart:16 and debtmath.dart carry their own private copies.
The guard is now cheap and concrete, which it was not while the item was
mis-stated: move `round2` somewhere neutral and have the porting skill name it.

**Open 25, nothing says that a test for a default must exercise the untouched
path: STILL OPEN.** CLAUDE.md did not change on this point.

**Open 26, a defect found by looking is not fixed until an assertion fails on
the old behaviour: STILL OPEN, and this round gives it a sharper edge.** Six of
the seven guards produced a real failure line. The seventh, the string amount
half of finding 2, produced an assertion that passes against the old code, which
is exactly what Open 26 exists to prevent and exactly what a per-finding failure
line cannot catch. See NEW Open 33.

**Open 27, whether to port a DISPLAY bug faithfully, and what to do about a
defect found in the app being ported FROM: STILL OPEN, and this round supplies a
gentler instance and a harder question.** mobile/app/person.js:97 renames a
person with no uniqueness check, which is the DATA that made Lesson 2 possible,
and RN survives it only because its own screen filters by id. Nothing in the
repository records that. Separately, Lesson 5 is the first time the Flutter app
has deliberately diverged from RN's OUTPUT in a golden locked area, which is the
same question from the other end: this time the port is right and the original
is wrong.

**Open 28, the QA merge gate leaves no artifact: CLOSED, and it paid for itself
in the same round.** docs/qa-log.md and flutter/test/qa_record_test.dart, built
in ead214f, both halves proven then and re-proven live this session. The known
limit stays on the record and is now demonstrated rather than theoretical: a
presence check cannot audit the truth of the sentence it forces someone to
write, and two of the f2.73 row's MUST FIX descriptions overstate what could
reach a phone. Closing it anyway, because the failure it was built for, a stamp
shipping with nobody having looked, is now impossible without a deliberate false
sentence in a diff.

**Open 29, nothing decides what counts as money math, so a ported rule written
inside a screen escapes the golden contract: STILL OPEN, and widened.** This
round adds the non-ported case: a rule written inside a screen also escapes the
conventions the contract carries, including how a stored number is read. The
audit it needs and the audit NEW Open 32 needs are the same audit.

**Open 30, nothing distinguishes a test that asserts how the code behaves from a
test that asserts a fact about the world: STILL OPEN.** Not exercised this round;
no statutory claims were added.

**Open 31, nothing says how to edit or undo safely: STILL OPEN, and Lesson 4 is
its first instance with a corroborating diff.** Wording to add alongside
session 13's: an edit script asserts its match count BEFORE writing, because a
replacement that matches nothing is silent and a formatter reflowing the target
is the normal case.

**NEW Open 32: one sanitizer makes every raw money read in every screen safe,
and nothing at any read site says so.** Measured: 12 files under
flutter/lib/screens/ contain `is num`, including utang.dart:959, which is the
identical expression to the one removed at :842 in the same commit. Candidate
guard, strongest tier after an audit: no screen file reads a stored money field
with a raw `is num` cast. Cheap half available today: state in
flutter/lib/data/backup.dart which fields sanitizeData guarantees are numbers.

**NEW Open 33: a proven-to-fail failure line proves ONE assertion, and the
record presents it as proving the test.** Proven this session: two of the four
assertions in 'the settled row shows the utang, not what is left of it' pass
against the code they were written to catch. Candidate, medium tier: when a test
makes several assertions about several findings, prove each one, or say in the
commit which assertion the failure line came from. The strong version is a habit
this project already has, one finding per test.

**NEW Open 34: half of the first deliberate golden-lock divergence is
unguarded.** Proven this session: removing `money: formatMoney` from the Remind
call leaves all 15 person sheet tests green. Two three-line tests close it, one
of them belonging in flutter/test/statement_golden_test.dart, which currently
tells a reader the shipped statement matches RN byte for byte.

### Guard status re-check

Read and re-run, not assumed. `git log 8b3e2a4..origin/main -- .github/workflows/
.claude/` returns NOTHING, so every workflow line number the last six entries
recorded still stands. Verified by reading anyway:

- The duplicate stamp refusal: PRESENT, flutter-preview.yml:166 to :181.
  Correctly silent, the stamp was distinct.
- The `|| true` scrape guard: PRESENT, flutter-preview.yml:127, comment intact.
- The nothing-shipped failure issue: PRESENT, flutter-preview.yml:223 onward.
  Not fired, correctly.
- The release install shout: PRESENT, flutter-preview.yml:240 to :256. Correctly
  silent, the row reads `patch`.
- The publisher watching its own definition: PRESENT at flutter-preview.yml:26.
- The delivery watchdog's `--first-parent` and 2700 second grace: PRESENT,
  delivery-watchdog.yml:99 and :43.
- flutter-check.yml on `claude/**` with NO paths filter: PRESENT at :20, and the
  separate shot harness run at :80.
- The stamp cap: PRESENT, update_stamp_test.dart:20; the shipped stamp is 95 of
  120 characters.
- **The NEW QA record guard: PRESENT and PROVEN LIVE, both halves.** Fires with
  the exact message quoted in Lesson 3 when the stamp has no row, silent when it
  does. First guard in this log proven live by the retrospective that ranked it.
- Session 12's guard, 'the DEFAULT is moving, not untagging': PRESENT at
  flutter/test/categories_screen_test.dart:137.
- Session 13's guard, 'a cap fires for an entry logged with the main Log button':
  PRESENT at flutter/test/categories_screen_test.dart:234.
- Sessions 6 through 11 guards: PRESENT, spot-checked by grep, none deleted.
- The whole suite: 958 pass and analyze clean, re-run this session, with the
  uncommitted next-batch caveat recorded in the beliefs section.

**No guard was found deleted, disabled or routed around.** No test was deleted
this round. One guard was found to be WEAKER than its record claims, which is
the nearest thing to a bad finding here: two assertions inside a proven test pass
against the broken code, and one half of the formatter divergence has no
assertion at all. Both are proven above rather than suspected, and both cost
three lines to close.

### What it cost, and what it did not

Cost: nothing on the phone. Seven defects were found before the merge, including
one that would have sent a document to another person billing them for someone
else's ₱7,000, and none of them shipped.

Cost, in the record rather than in the product: two sentences in the repository
state that a bug reached a screen when it could not. One is in a commit message,
one is in docs/qa-log.md, and the second one matters more because that file was
created this round specifically to be trusted. Correcting it here is the whole
job of this log.

Not cost: no data was lost, no stamp was stranded, the base APK is untouched,
the founder owes no manual install, and f2.73 arrived exactly as reported.

---

## 2026-07-28, session 13: the cap that never noticed anything

Two deliveries in this round, f2.71 and f2.72, both with clean rows and both
confirmed on the phone by the founder. That is six clean deliveries in a row on
the mechanical side.

And for the first time in this log, a delivery that was clean in every
mechanical sense put a feature on the founder's phone that did not work.

f2.71 shipped a Categories screen whose monthly spending cap could not see the
entries the app's own main Log button creates. The screen said `₱0 this month`
for a category the founder had spent 3,500 pesos in, while the Budget screen
said 3,500 for the same category in the same month. It sat on the phone for two
hours, from 09:51 to 11:51 UTC, and it was found by a QA pass that ran AFTER
the merge, because the QA pass CLAUDE.md requires BEFORE the merge did not run.

Session 12 looked at that exact merge, found no QA record, and wrote that the
record could not answer whether the gate had been satisfied. It filed that as
Open 28 and said explicitly that it was not accusing anyone of skipping it.
This session has the answer, and the answer is that it was skipped, and the
cost is now measurable rather than hypothetical. Open 28 stops being a
housekeeping item.

The other half of the round is the tax work, where a Philippine tax
professional's review found the app stating filing positions it had no way to
know. The evidence there is the strongest kind this log can produce, and unlike
session 12's case it exists as committed diffs: the fix had to DELETE tests
whose names asserted the dangerous behaviour, including one that had been
proven-to-fail first, exactly as CLAUDE.md instructs.

### What we believed / What was true

**Believed: f2.72 reached the phone. TRUE, and confirmed in person.** Read from
`git show origin/main:docs/delivery-log.md | tail -3`, the last row is:

    | 2026-07-28 11:51 UTC | f2.72 | 22 | patch | 0.6.2+11 | 69cb2200 (run 30355725728) |

Mode `patch`, so nothing was stranded and no manual install is owed.
flutter/pubspec.yaml:12 still reads `version: 0.6.2+11`, unchanged since
session 5, so the base APK the founder installed once is still the right one.
The stamp in the tree, flutter/lib/main.dart:29 to :30, is `'f2.72 · Two new
tools: your next BIR filing dates, and a year-end refund or shortfall
estimate.'`, 95 characters, inside the 120 cap enforced at
flutter/test/update_stamp_test.dart:20. Stamp in the code, stamp in the log,
stamp on the phone: three for three.

**Believed: the merge used a merge commit, not a squash. TRUE, verified.**
`git cat-file -p 69cb220` shows two parents, 9bc8fb8 and 2d7a22c.

**Believed: f2.71 delivered a working monthly cap. FALSE, and this one reached
the phone.** The delivered code at 9bc8fb8:flutter/lib/screens/categories.dart:44
contains one line that decides it:

      final id = t['categoryId'];
      if (id == null) continue;

The main Log sheet never writes a `categoryId`. `grep -n "categoryId"
flutter/lib/screens/log_sheet.dart` returns nothing at all, in the delivered
tree and in the current one. So every entry logged with the big plus button was
skipped, and the screen counted only entries tagged from the category picker.

The RN rule this was ported from has two arms, at mobile/app/categories.js:52
to :53:

          (t.categoryId === c.id ||
            ((!t.categoryId || !validIds.has(t.categoryId)) && t.label === c.name))

Only the first arm made it across. Budget was correct all along because it
groups by category OR by trimmed label, at flutter/lib/money/budget.dart:79 to
:89, which is why the two screens disagreed about the same month.

Worth stating precisely, because it changes who was affected: the cap itself is
a Pro feature, but the spend figure is not. The delivered `_subtitle` at
9bc8fb8:screens/categories.dart:171 to :173 builds `'${formatMoneyText(spent)}
this month'` first and only then appends the cap. So EVERY user, Pro or not,
saw a wrong number, and Pro users additionally had a cap that could never fire.

**Believed: the categories golden lock covered the categories screen's money
math. FALSE.** flutter/test/goldens/categories_goldens.json locks four pure
tree helpers (normalizeCategoryTree, promoteChildren, categoryTree,
recategorizeTransactions). The spend rule was never in flutter/lib/money/ at
all, so the golden contract never looked at it. This is the structural root
cause and it is Lesson 2.

**Believed: the BIR dates screen was correct because its dates and arithmetic
were correct. TRUE about the dates, and dangerously incomplete.** The tax
professional confirmed every statutory date, the post TRAIN 1701Q dates and the
correctly absent registration fee. What was wrong was that the screen made
categorical statements about a person's filing obligations from one boolean.
Lesson 3.

**Believed: 935 tests pass and analyze is clean on what shipped. TRUE,
independently re-run this session.** `flutter analyze` reports "No issues
found! (ran in 27.8s)" and `flutter test` reports "All tests passed!" at +935,
run against the live tree at the delivered commit b61d451 with `git status
--porcelain` empty. Third session in a row the number is measured rather than
inherited.

**Believed (session 12, Open 28): the record cannot tell whether the pre-merge
QA pass ran on batch 5. TRUE then, and answered now: it did not run.** Stated
by the session that did the work, and corroborated by the record rather than
taken on trust: 2d7a22c's own message opens "QA on the already-delivered
categories batch (f2.71) found the feature inert on the app's main path". A
pass that runs after delivery is not the gate CLAUDE.md describes.

### Timeline (with evidence)

All times UTC, from `git log --format=%cI` and the publisher's own rows.

| Time | Event | Evidence |
|------|-------|----------|
| Jul 28 08:45:40 | 56bcf41 batch 5. `_spentThisMonth` is written with the tag arm only. 912 green | `git show 9bc8fb8:flutter/lib/screens/categories.dart`, line 44 |
| 09:40:02 | Merge #228 (c7b84f6). **No QA round commit, and no QA pass** | `git log 4d03f13..9bc8fb8 --oneline` returns two commits, neither a QA round |
| 09:51:06 | f2.71 patch 21 delivered. **An inert cap and a wrong spend figure are now on the phone** | delivery row, 9bc8fb8 |
| 10:42:02 | e2a7abd batch 6, BIR dates and the year-end check. 926 green. Ships the 8% rule that deletes the January 2551Q, and stores the answer with no year | commit message, taxdeadlines.dart |
| 10:43:50 | 4646a0d session 12 write-up, which files Open 28 about the unprovable QA gate | commit |
| 11:08:22 | 5b37947 tax review round. Three MUST FIX findings, and three tests asserting the old behaviour are deleted or inverted | `git show 5b37947 -- flutter/test/` |
| 11:34:27 | 2d7a22c caps fix, from a retroactive QA pass on the ALREADY DELIVERED f2.71. 935 green | commit message |
| 11:40:23 | Merge #229 (69cb220), two parents | `git cat-file -p 69cb220` |
| 11:51:56 | f2.72 patch 22 delivered, 11m33s after the merge | delivery row, b61d451 |
| after | **Founder confirms f2.72 on the phone** | founder |

The founder's window with a broken cap: 09:51:06 to 11:51:56, two hours and
fifty seconds.

### Divergence point

There is no DELIVERY divergence this round. Both stamps built, shipped, were
logged and matched the phone. Six in a row.

The belief divergence is **08:45:40 on July 28, inside 56bcf41, at the line
`if (id == null) continue;`**. That is where a two arm RN rule became a one arm
Dart rule, and from that moment every signal in the project said the categories
batch was correct: 912 green tests, a clean analyze, a golden file named
`categories_goldens.json` sitting right there in the same directory, and a
green Flutter check on a real runner.

It is worth being exact about why the golden file was not evidence. It was
real, it was generated by executing the real RN source, and it was completely
correct. It just covered four different functions. A golden file cannot tell
you which rules you failed to put in front of it. That is the same shape as
Open 22 from session 11, one level up: session 11 asked whether the FIXTURES
inside a golden set were enough, and this round asks whether the golden set
covers the right FUNCTIONS at all.

The moment anyone noticed was 11:34:27, one hour and forty nine minutes after
the defect reached the phone, and the thing that noticed was a person doing a
QA pass that should have happened before the merge.

### Root cause

**1. Money math that lives inside a screen file is outside every mechanism
this project has for checking money math.**

CLAUDE.md's Flutter rule 4 says "Money math ports do not merge without matching
test vectors", and the porting-money-logic skill describes exactly how to
generate and lock those vectors. Both are correct and neither could fire here,
because nothing decides what counts as money math. The rule was ported into
`_spentThisMonth`, a private method on a `State` class in
flutter/lib/screens/categories.dart, and a private method on a State class is
not something anyone thinks to golden lock.

This is not a one-off. Measured this session across flutter/lib/screens/, the
money helper `amountOf` is called from six screen files:

    accounts.dart 9, categories.dart 2, debts.dart 22,
    insights.dart 6, reports.dart 8, split_expense.dart 1

Whether each of those is a ported RN rule or merely local display arithmetic
was NOT audited here, and that is exactly the point: nothing in the project
distinguishes the two, so nobody can tell without reading all forty eight call
sites. The fix moved this one rule to flutter/lib/money/categories.dart:117 as
`spentByCategory` and locked it, which is right, and it does nothing about the
next one.

**2. The pre-merge QA pass is the only step that has ever found this class of
defect, and skipping it is invisible.**

Session 12 ranked the QA pass as the strongest of the medium tier guards and
noted that it leaves no artifact. This round supplies the missing half of that
argument. The gate was skipped, every automated signal stayed green, the pull
request looked clean, the merge went through, the publisher shipped, the
delivery row was written, and a broken feature reached the phone. Not one
mechanism anywhere disagreed at any point.

**3. A test can assert a fact about the WORLD as confidently as it asserts a
fact about the code, and nothing in the suite knows the difference.**

The 8% filing tests were well built. They were named clearly, they exercised
the real screen, and one of them was proven to fail first exactly as CLAUDE.md
requires. What they asserted was a claim about Philippine tax law, and every
one of the mechanisms this project uses to check tests is blind to whether such
a claim is true.

### Lessons and guards

**Lesson 1. A skipped QA pass put a broken feature on the founder's phone. This
is the first confirmed instance in this log of a delivery that was mechanically
perfect and functionally wrong.**

The facts, in order. CLAUDE.md's merge rules require, before Claude merges, "a
QA pass ran on the changed code (the qa-tester agent or equivalent) and every
must fix finding was fixed and re-checked". Batch 5 was merged without one.
The QA pass ran two hours later against the delivered code and found, in its
first sweep, three real defects: the inert cap, a cap line shown to non Pro
users that Budget correctly hid, and a non Pro user being unable to rename a
category because the cap field pre-filled from storage and then failed the Pro
gate on a value they could neither see nor have typed.

None of the three were visible to 913 green tests.

**Guard for the instance, SHIPPED, strongest tier, and proven failing first.**
flutter/test/categories_screen_test.dart:234 carries 'a cap fires for an entry
logged with the main Log button', which walks the exact user path: one entry
labelled Food with no `categoryId`, a 3,000 cap saved on Food, then

    expect(find.textContaining('₱3,500 this month'), findsOneWidget);
    expect(find.textContaining('Over the cap.'), findsOneWidget);

and the failure line recorded in 2d7a22c before the fix was
`Expected: exactly one matching candidate / Found 0 widgets with text
containing "₱3,500 this month"`. The rule itself is now golden locked at
flutter/test/goldens/categoryspend_goldens.json against the real RN predicate,
which flutter/test/goldens/gen-catspend-goldens.js cuts out of
mobile/app/categories.js by text and EXECUTES rather than transcribes, with a
sanity check at :30 that the extracted text still mentions `categoryId` and
`isThisMonth`. Twelve fixtures cover the cases that decide the rule, including
the ones a transcription would get wrong: a differently cased label (RN's match
is exact, so it counts for nothing), and a tag pointing at a deleted category
falling back to the label.

**Guard for the class, NOT WRITTEN, and it is now the highest value unwritten
guard in this log. Open 28, ESCALATED.** Session 12 proposed it and ranked it
"strongest tier for presence only". That ranking still holds and the priority
does not. The cheap version is a required line in the pull request body or in
one commit message per round naming the QA pass and its findings, including
"none". The strong version is a step on the Flutter check that fails when a
branch touching flutter/lib/ has no QA record on its head commit. A presence
check can be satisfied by typing the words, and that limit must be said in the
same breath. Presence is nonetheless exactly what was missing here: nothing
anywhere was in a position to notice.

**Lesson 2. The golden lock covered four functions in a file and none of the
money math in the screen beside it, because nothing decides what counts as
money math.**

This is the finding with the longest reach. The porting contract is strong
where it applies and there is no mechanism that decides where it applies. A
rule that lives in an RN file gets ported and locked; the same rule written as
a six line arrow function inside a React component, which is exactly what
`spentFor` is at mobile/app/categories.js:46, gets ported into a Dart State
class and locked by nothing.

**Guard, PARTIAL. The instance is fixed, the class is NEW Open 29.** The
candidate rule, one sentence for
.claude/skills/porting-money-logic/SKILL.md: **a rule that reads transactions
and produces a number goes in flutter/lib/money/ and gets a golden, even when
it is three lines long and even when its RN original lives inside a component
rather than in lib/.** Medium tier when written, because it is prose. There is
a stronger companion available and it should be scoped honestly rather than
promised: a test that fails when a file under flutter/lib/screens/ sums
`amountOf` over `data['transactions']` would be a real automated guard, and it
would need the six existing sites audited and either moved or explicitly
allowed first. That audit is the work; the check is easy afterwards.

**Lesson 3. Three tests asserted the dangerous tax behaviour, by name, and one
of them had been proven to fail first. The diffs exist, and they are quoted
here because this is the strongest evidence a retrospective in this project can
produce.**

Session 12 had to reconstruct its inverted test because it was never committed.
This round does not. All three were shipped in e2a7abd and deleted or inverted
in 5b37947, so `git diff e2a7abd 5b37947` is the proof.

The most dangerous one, from e2a7abd:flutter/test/taxdeadlines_golden_test.dart:94:

    test('the 8 percent option drops the percentage tax rows', () {
      final rows = taxDeadlines(DateTime(2026, 1, 1), onEightPercent: true);
      expect(rows.any((r) => r.form == '2551Q'), isFalse);

Read that with the date in mind. On January 1 2026, with the 8% option on, the
test asserts that NO percentage tax return appears. The January 25 2551Q covers
October to December of the PREVIOUS year. The 8% election is per taxable year
and irrevocable for that year only, so somebody on graduated rates last year
still files it. The app told them it was not theirs to file, and the exposure
for missing it is a 25% surcharge plus 12% interest.

The second, from e2a7abd:flutter/test/tax_screens_test.dart:63, has the bug in
its title:

    testWidgets('the 8% choice drops the percentage tax rows and sticks', (
    ...
      // Remembered, so the same person is not asked again next month.
      expect((store.data['settings'] as Map)['taxOnEightPercent'], true);

"Sticks" and "not asked again next month" are the defect stated as a feature.
The election has to be signified again every year, so one tap in 2026 silenced
percentage tax rows for life.

And here is the part that matters most for this project's habits. That exact
assertion was proven-to-fail first, correctly, following CLAUDE.md. The e2a7abd
commit message records the failure line:

    Guards proven failing first: ... and the 8% choice not persisting
    (Expected: <true> / Actual: <null>).

So the prove-it-can-fail discipline ran, worked, and certified a bug. This is a
NEW named species and it belongs beside the three already recorded in this log:
**proving a test can fail proves the test is WIRED UP. It says nothing about
whether the behaviour it pins is correct.** Every previous species in this log
was about a test looking at the wrong thing. This one looked at exactly the
right thing and had the wrong idea of what the right answer was.

There was a third MUST FIX in the same review that no test asserted either way:
a VAT registered filer was handed four rows telling them to file a 3%
percentage tax. Section 116 applies only to persons who are NOT VAT registered,
who file 2550Q and no 2551Q at all. A boolean cannot express that, which is why
the fix is an enum.

**Guard, SHIPPED, strongest tier, for the instances.**
flutter/lib/money/taxdeadlines.dart:138 introduces
`enum FilingBasis { regular, eightPercent, vatRegistered }`, the January row
survives the 8% election at :173, and the screen expires a stored answer when
the year turns at flutter/lib/screens/tax_deadlines.dart:73:

    if (s['taxBasisYear'] != widget.clock().year) return FilingBasis.regular;

The replacement assertions are the inverse of the deleted ones, at
taxdeadlines_golden_test.dart:132 to :145: `expect(pct.first.date,
DateTime(2026, 1, 25))`, `expect(pct.first.note, contains('LAST year'))`, and
`expect(rows.any((r) => r.form == '2551Q' && r.date.month != 1), isFalse)` so
the April, July and October rows are still genuinely replaced. Proven failing
first, from 5b37947: `Expected: exactly one matching candidate / Found 0
widgets with text "Percentage tax"`.

The divergence from RN is deliberate and is asserted rather than hidden. The
golden test compares 8% cases separately, with the reason at
taxdeadlines_golden_test.dart:66 to :71, and inside our own window at :75 to
:80 so that adding a row does not fail the comparison for the wrong reason.

**Guard for the class, NONE. NEW Open 30.** Nothing distinguishes a test that
asserts how the code behaves from a test that asserts a fact about the world.
The only thing that found these was a domain specialist reading the screens,
which is a discovery method and not a guard, the same category Lesson 2 of
session 12 put "looking at the render" in. The candidate, and it is honestly
weak, is a convention: **a test that encodes a legal, tax or statutory claim
names its source in the test itself, so a later reader can re-check the claim
rather than the code.** Medium tier at best. It does not make the claim true.
It makes the claim visible as a claim, which is the difference between the
January 2551Q assertion above and an assertion about string formatting, and
nothing in the file marked that difference.

**Lesson 4. The RN app has the January 2551Q defect and it was flagged to the
founder rather than fixed. Verified this session, and one detail in the brief
does not hold.**

Confirmed by reading. mobile/lib/taxdeadlines.js:42 builds its list as

    const specs = [ANNUAL, ...INCOME_QUARTERLY, ...(onEight ? [] : PERCENTAGE_QUARTERLY)];

so the 8% option drops all four 2551Q rows including the January 25 one at :20.
The live RN app has the dangerous behaviour, and the Flutter port deliberately
does not copy it, documented at flutter/lib/money/taxdeadlines.dart:161 to :170.
There is no VAT registered mode in RN either; mobile/app/tax-deadlines.js:105
covers it with a sentence of prose telling VAT filers they have extra returns
not listed.

The detail that does NOT hold: the "remembered forever" half is Flutter only.
RN holds the answer in `useState(false)` at mobile/app/tax-deadlines.js:32 and
never persists it at all, so it resets every visit. Saying so matters because
the two apps have DIFFERENT defects here, and a fix applied to RN from a
Flutter description would fix the wrong one.

**Guard: NONE, by decision, and the lesson is OPEN as part of Open 27.** This
is the concrete instance of the question session 12 recorded and did not
answer: what to do when a port finds a real defect in the app it is porting
from. Session 12's candidate wording ("port it faithfully AND open an issue
against mobile/") would resolve it, and this case is stronger than the one that
prompted it, because that one was a duplicated row rendered from corrupt data
and this one is a tax filing somebody could miss. The founder was told. Nothing
in the repository records it, so nothing will remind anyone.

**Lesson 5. Unreadable numeric input read silently as zero. Confirmed on the
year-end screen with a proven guard. The second half of the claim, about the
transfer flow, does NOT hold in the delivered tree, and correcting it changes
the lesson.**

The confirmed instance is real and was shipped inside this round rather than
reaching the phone. flutter/lib/screens/year_end_tax.dart:46 to :51 records it
in the code:

    /// This used to map anything unreadable to zero silently, so pasting
    /// "₱12,500" from a payslip made the screen announce "LIKELY STILL OWED"
    /// to somebody who had actually overpaid, and typing "6 months" in the
    /// months field became one month and overstated a refund twelvefold.

The reader now returns three distinct things, empty, unreadable and a number,
at :52 to :58, and the verdict is withheld while any field is unreadable.

**Guard, SHIPPED, strongest tier.** flutter/test/tax_screens_test.dart:293
enters `₱12,500` in the withheld field and asserts both halves at :295 to :301,
that the screen names the field it cannot read AND that no verdict appears:

    expect(find.textContaining('LIKELY'), findsNothing,
        reason: 'no verdict may be built on a figure the app misread');

then repeats it for the months field, then corrects the input and asserts at
:313 that the warning goes away. That last part is the silent half, which this log has
insisted on since the watchdog.

**The correction.** The brief for this session said the same silent-zero bug
was found in the transfer flow. Checked, and it is not there. Typed amounts go
through `transferAmount` at flutter/lib/money/transfers.dart:67, which returns
NaN for anything unreadable, and `applyTransfer` at :165 refuses it with "Enter
an amount greater than 0." The nearest real thing is a different case: a stored
BALANCE that is unreadable resolves to zero through `ledger.amountOf`, which is
RN's `Number(from.balance) || 0` ported faithfully, and its consequence is a
refusal rather than a confident wrong answer. It has been that way since batch
4 (0fdd121) and it is documented at transfers.dart:154 to :156.

So the honest shape of the lesson is narrower than the brief and more useful:
the silent-zero defect was a ONE screen defect, on a screen that produces a
VERDICT rather than performing an action. That is the distinguishing feature
worth carrying forward. A screen that acts can fail safe by refusing. A screen
that only tells you something has no refusal path unless someone builds one,
and the year-end screen shipped without one.

**Lesson 6. Two process near-misses were reported by the session that did the
work. Neither can be verified from the repository, and that is said plainly
rather than smoothed over.**

Reported: python heredoc edit scripts that assert AFTER writing lose every edit
in the script when the assert fires, which happened about four times; and
`git checkout <file>` was used to undo an edit, which restored the last COMMIT
and destroyed uncommitted QA fixes.

What this session can verify is only the surrounding context, and it does
support them being worth writing down. Open 16, filed in session 10, is exactly
this territory: CLAUDE.md's prove-it-can-fail section says how to BREAK the
code and never says how to restore it. Re-checked this round,
`grep -n "git checkout\|restore" CLAUDE.md .claude/skills/*/SKILL.md` still
returns only two unrelated hits, both about backup and restore as a product
feature. Nothing anywhere in the project says how to undo a deliberate break
safely. Sessions 12 and 13 both worked around it by hand, session 12 by using a
detached worktree and this session by running the suite against a clean tree.

**Guard, NOT WRITTEN. NEW Open 31, and Open 16 is its other half.** Two
sentences, both cheap, both belonging beside prove-it-can-fail in CLAUDE.md:
**verify before you write, never after, so a failed check leaves the file
untouched**, and **undo a deliberate break with the text you saved, never with
`git checkout`, which restores the last commit and takes uncommitted work with
it.** Medium tier, and it must be called medium: it is prose that has to be
read at the right moment. The stronger version exists in principle, a session
level rule that every experimental break happens in a scratch worktree, and it
is worth noting that this is already the practice two sessions running without
being written down anywhere.

**Lesson 7. The standing CLAUDE.md fact check. Everything it claims still
matches the repository this round.**

Three consecutive sessions found a false factual claim in CLAUDE.md, which is
why this is a step and not a favour. Session 12 found it clean. This round it
is clean again, and saying so is the point of doing it.

`git log 9bc8fb8..HEAD --oneline -- .github/workflows/ CLAUDE.md .claude/`
returns nothing at all: not one workflow, rule or skill changed between the two
deliveries. Re-verified by reading and running regardless:

- Every path CLAUDE.md names exists where it says: flutter/shorebird.yaml,
  flutter/test/update_stamp_test.dart, flutter/test/screens_shot.dart,
  flutter/lib/widgets/salapify_icon.dart, flutter/lib/main.dart,
  docs/delivery-log.md, mobile/app/(tabs)/more.js.
- All five skills exist in .claude/skills, and the file's description of them
  (three adapted, two ours) still matches the directory.
- mobile/lib/storage.js:9 still holds `salapify_data_v2`.
- mobile/package.json:11 still pins `"expo": "~54.0.0"`.
- The 120 character stamp cap is live at update_stamp_test.dart:20; the shipped
  stamp is 95 characters.
- flutter-check.yml:20 triggers on `claude/**` with no paths filter;
  flutter-preview.yml:17 triggers on `main`, with paths `flutter/**` at :19 and
  its own definition at :26. Both still match Flutter rule 1 word for word.
- The claim that CI runs the shot harness separately with `--update-goldens` is
  true: flutter-check.yml:80.
- The local SDK claim is true: /opt/flutter reports Flutter 3.44.6 stable.
- The three delivery commands ran as written and returned f2.72 patch 22.
- The "look at the screen" section's brightness claim, which was false for five
  sessions before session 11 corrected it, is now accurate against the harness:
  the two new tax shots share the `Brightness.dark` palette set at
  screens_shot.dart:1094 and render dark only, which is what the corrected
  sentence says happens to screens that are not tabs.

**One thing the fact check cannot see, recorded rather than filed as new.** The
render step is documented as a pre-merge requirement for every UI change. The
tax screens got shots in e2a7abd, and the tax review round 5b37947 then rebuilt
those screens substantially (a three state chip row, a live region, new copy)
without touching screens_shot.dart. That is not necessarily wrong, since the
existing shot renders whatever the screen currently is, and the commit message
mentions "the basis chips stop clipping at large font", which is a thing you
learn by looking. But it is unprovable either way, for the same reason as
Lesson 1: the render leaves no committed artifact, so nobody can tell whether
it ran. That is Open 26 and Open 28 meeting each other, not a new item.

**Lesson 8. Is the six-delivery streak real? The delivery half yes, and this
round the correctness half finally produced the failure it has been predicting.**

The DELIVERY half is real and mechanical. f2.67 through f2.72 each have a row,
each in mode `patch`, each against an unchanged 0.6.2+11, each confirmed on the
phone. Merge to row was 11m50s, 11m54s, 11m04s and now 11m33s. That mechanism
was built after it failed in session 1 and it works.

The CORRECTNESS half has been called unsolved in every entry since session 10,
in increasingly plain language, and each time the miss was caught before the
merge, which makes a warning easy to read as pessimism. This round it was not
caught before the merge. A feature the founder was told had shipped did nothing
for two hours. The prediction was correct, and the six clean rows are exactly
as reassuring as they were before, which is to say they are about delivery only.

The tally over six batches is unchanged and now longer: the automated suite has
still never found a novel defect. Every new defect came from a QA pass, a
specialist review, a render, or a retrospective. What is new this round is the
second half of that sentence: on the one occasion the QA pass did not run, the
defect shipped.

### Open lessons carried forward

**Open 3, nothing compares the phone to main: STILL OPEN, by design.** The
founder confirmed f2.72 in person, which remains the only proof that counts.

**Open 6, the watchdog has never been observed running a scheduled pass: STILL
OPEN.** Run history is unreadable from this sandbox and `gh` is not installed
here (`which gh` returns nothing). No spurious issue in evidence, and this
round's 11m33s gap was well inside the 2700 second grace at
delivery-watchdog.yml:43.

**Open 7, the watchdog blind spot for merges that do not bump the stamp: STILL
OPEN.** Not exercised, the merge bumped the stamp.

**Open 8, split the publish step from the log scraping: STILL OPEN,**
re-verified by reading, the scrape is still inside the ship step with `|| true`
at flutter-preview.yml:127 and the load-bearing comment at :112 to :126 intact.

**Open 9, FAILED rows in docs/delivery-log.md: STILL OPEN.** The log now
carries 32 `patch` rows and 2 `release` rows and no failure rows at all.

**Open 10, nothing holds Pan's rendered size: STILL OPEN.**

**Open 11, nothing stops a sixth private kicker: STILL OPEN.**

**Open 13, the shot harness mounts screens through a private copy of the
shell's wiring: STILL OPEN, and it grew again.** The two tax shots build their
own `MaterialApp` by hand at screens_shot.dart:1096 and :1112. The file now
contains 20 hand-built `MaterialApp` sites, up from 18.

**Open 14, CLAUDE.md workflow item 4 versus the eas-update trigger: STILL OPEN,
untouched, re-verified.** eas-update.yml:18 still triggers only on
`claude/salapify-v2`, a branch retired in cf5c6a7.

**Open 15, the walk-keying and frame-asserting rule: ADVANCED AGAIN, still
open.** The BIR dates shot asserts its frame before photographing it
(`expect(find.text('WHAT IS NEXT'), findsOneWidget)` at screens_shot.dart:1105)
and the year-end shot asserts `find.textContaining('LIKELY')` at :1122.
Measured the same way as last session, 9 of 28 `expectLater` sites are now
preceded by an assertion about what is in front of the camera, up from 7 of 26.
The MEDIUM tier is still not done: the screens_shot.dart header still records
three hard-won harness rules and asserting the frame is not one of them.

**Open 16, prove-it-fails says how to break the code and not how to restore it:
STILL OPEN, and Lesson 6 gives it a second, sharper instance.** A `git checkout`
undo reportedly destroyed uncommitted QA fixes in this round.
`grep -n "git checkout\|restore" CLAUDE.md .claude/skills/*/SKILL.md` still
returns only unrelated hits. See NEW Open 31, which is the same wound from the
other side.

**Open 17, nothing generalises the payday guard: STILL OPEN, re-verified.**
`PlannedReminder` at flutter/lib/money/reminders.dart:25 to :30 still carries
only title, body and when, with no `kind` field.

**Open 18, the habit signal has five independent remembering events: STILL
OPEN.** `sampleTxIds` is still imported and filtered at quickadd.dart:28 and
:60, reminders.dart:112, coach.dart:313 and chain.dart:69. No shared accessor.

**Open 20, mobile/lib/notifications.js has the same sample-row defect Flutter
fixed: STILL OPEN, re-verified.** `loggedToday` at :99 still does not exclude
the sample ids.

**Open 21, the balance label guards are example-shaped and the property is
already proven: STILL OPEN.** `grep -rn "never refused as an overdraft\|
displayed figure" flutter/test/` still returns nothing.

**Open 22, the fixture audit rule: CLOSED in session 12, and this round shows
the shape it does NOT cover.** The rule asks whether the fixtures inside a
golden set are enough. Lesson 2 is about whether the golden set covers the
right functions at all, which is a different question and is NEW Open 29.

**Open 23, the "*100 overflow" rule lives in prose and was walked into anyway:
STILL OPEN.** No shared centavo helper exists in flutter/lib/money/.

**Open 25, nothing says that a test for a default must exercise the untouched
path: STILL OPEN.** CLAUDE.md did not change this round.

**Open 26, a defect found by looking is not fixed until an assertion fails on
the old behaviour: STILL OPEN.** Both fixes this round did produce such an
assertion with the failure line pasted into the commit, so the habit held
again. The sentence is still written nowhere.

**Open 27, whether to port a DISPLAY bug faithfully, and what to do about a
defect found in the app being ported FROM: STILL OPEN, and Lesson 4 makes it
urgent.** The category duplicate-row case that prompted it was cosmetic. The
new instance is a Philippine tax filing that RN's users can miss, carrying a
25% surcharge plus 12% interest. Session 12's candidate wording, "port it
faithfully AND open an issue against mobile/", would have created a record.
There is no record.

**Open 28, the QA merge gate leaves no artifact: STILL OPEN, and ESCALATED from
an instrument defect to a confirmed cost.** Session 12 wrote that it found no
evidence the gate was skipped and was not claiming it had been. This session
has the evidence, and the cost is two hours of a broken feature on the phone
and three defects that shipped. Everything session 12 wrote about the guard's
design still stands, including that a presence check can be satisfied by typing
the words. It should be built anyway.

**NEW Open 29: nothing decides what counts as money math, so a ported rule
written inside a screen escapes the golden contract entirely.** Measured: six
screen files make forty eight `amountOf` calls, unaudited. One sentence for the
porting skill (medium tier), and a genuinely automatable check after the audit
that no screen sums `amountOf` over transactions (strongest tier).

**NEW Open 30: nothing distinguishes a test that asserts how the code behaves
from a test that asserts a fact about the world.** Three tax law assertions were
wrong, well written, and one was proven-to-fail first. Candidate: a test
encoding a statutory claim names its source. Weak, and honest about it: it makes
the claim re-checkable, it does not make it true.

**NEW Open 31: nothing says how to edit or undo safely.** Verify before writing,
never after, so a failed check leaves the file untouched; and never undo a
deliberate break with `git checkout`, which restores the last commit and takes
uncommitted work with it. Both reported from this round, neither reconstructible
from the repository. Medium tier when written. The other half of Open 16.

### Guard status re-check

Read and re-run, not assumed. `git log 9bc8fb8..HEAD -- .github/workflows/
CLAUDE.md .claude/` returns NOTHING, so every workflow line number the last five
entries recorded still stands. Verified by reading anyway:

- The duplicate stamp refusal: PRESENT, flutter-preview.yml:166 to :181, its
  reasoning comment intact. Correctly silent, the stamp was distinct.
- The `|| true` scrape guard: PRESENT, flutter-preview.yml:127, comment intact.
- The nothing-shipped failure issue: PRESENT, flutter-preview.yml:223 onward.
  Not fired, correctly.
- The release install shout: PRESENT, flutter-preview.yml:240 to :256.
  Correctly silent, the row reads `patch`.
- The publisher watching its own definition: PRESENT at flutter-preview.yml:26,
  with the comment at :20 to :25 explaining why.
- The delivery watchdog's `--first-parent` and 2700 second grace: PRESENT,
  delivery-watchdog.yml:99 and :43, load-bearing comments intact.
- flutter-check.yml on `claude/**` with NO paths filter: PRESENT at :20, and the
  separate shot harness run at :80.
- The stamp cap: PRESENT, update_stamp_test.dart:20; the shipped stamp is 95 of
  120 characters.
- Session 6 through 11 guards: PRESENT, spot-checked by grep, none deleted.
- Session 12's guard, 'the DEFAULT is moving, not untagging': PRESENT at
  flutter/test/categories_screen_test.dart:137, with the comment at :143 to :146
  recording why the first version of it passed.
- The whole suite: 935 pass, analyze clean, re-run this session on the delivered
  commit b61d451 in a clean tree.

**No guard was found deleted, disabled or routed around.** One guard was NOT
RUN, which is a different and worse thing, and it is Lesson 1. A guard that is
deleted leaves a diff. A guard that is skipped leaves nothing, which is why
Open 28 matters more than its medium ranking suggests.

Three tests were deleted this round and every one of them was asserting a
defect. Those deletions are correct and they are quoted in Lesson 3 rather than
being counted against the suite.

### What it cost, and what it did not

Cost: a real one, and the first of its kind here. For two hours and fifty
seconds the founder's phone showed a Categories screen with a wrong number on
every row and a Pro cap that could never fire, after being told f2.71 had
shipped. Nobody lost money and no data was harmed. What was spent is the
founder's ability to trust "it shipped", which is the one currency this log
exists to protect.

Also cost, though it never reached the phone: an app that told a freelancer a
tax return was not theirs to file, on a screen built to be authoritative. That
was caught by a specialist review one merge later, which is the system working,
one round late.

Not cost: no data was lost, no stamp was stranded, the base APK is untouched,
the founder owes no manual install, and both stamps arrived exactly as
reported.

---

## 2026-07-28, session 12: the screenshot caught the one thing the batch existed to protect

One delivery, one clean row, confirmed on the phone by the founder. That is the
fifth clean delivery in a row, f2.67 through f2.71, and the honest reading of
the streak is unchanged from session 11 and repeated below because a streak is
read as "everything is fine" the moment nobody repeats it.

The finding this session exists for is this. Batch 5 is a category screen whose
entire reason to exist is the founder's rule that deleting a category must MOVE
its entries and never quietly untag them. The screen shipped that rule
backwards: the delete sheet opened with "No category" already selected, so
anyone tapping straight through would have untagged every entry. The test
written in the same sitting to guard exactly that rule PASSED, because it
asserted the words on the screen instead of which chip was lit.

This is the second confirmed case in this log of a test certifying the bug it
was written to prevent. Session 10 found the first, in the payday guard. Two is
a pattern, and Lesson 1 gives it a name and a rule.

It also closes Open 22 and Open 24, both verified by reading and by running
rather than by trusting a commit message, and it opens a genuine design
question about porting a DISPLAY bug faithfully that is recorded rather than
answered.

### What we believed / What was true

**Believed: f2.71 reached the phone. TRUE, and confirmed in person.** Read from
`git show origin/main:docs/delivery-log.md | tail -3`, the last row is:

    | 2026-07-28 09:51 UTC | f2.71 | 21 | patch | 0.6.2+11 | c7b84f69 (run 30347547209) |

Mode `patch`, so nothing was stranded and no manual install is owed.
flutter/pubspec.yaml:12 still reads `version: 0.6.2+11`, unchanged since
session 5, so the base APK the founder installed once is still the right one.
The stamp in the tree, flutter/lib/main.dart:29 to :30, is `'f2.71 · Categories
in Menu: rename, nest, set a monthly cap, and delete one without losing
entries.'`, 99 characters, inside the 120 cap enforced at
flutter/test/update_stamp_test.dart:20. Stamp in the code, stamp in the log,
stamp on the phone: three for three.

**Believed: the merge used a merge commit, not a squash. TRUE, verified.**
`git cat-file -p c7b84f6` shows two parents, 4d03f13 and 102ef74.

**Believed: the category delete sheet honoured the founder's rule when it was
first written. FALSE. It did the exact opposite by default, and a test written
for that rule said it was fine.** Lesson 1, reproduced from scratch while
writing this entry.

**Believed: 913 tests pass and analyze is clean on what shipped. TRUE,
independently re-run.** `flutter analyze` reports "No issues found!" and
`flutter test` reports "All tests passed!" at +913, run against a clean
checkout of the delivered commit 9bc8fb8 in a throwaway git worktree under the
scratchpad. The live working tree was not used, because another task is
currently building tax deadline screens in it and a run there would measure
that instead of the phone.

**Believed: Open 22 (the fixture audit rule) was written into the porting
skill. TRUE, and the wording is stronger than what session 11 drafted.**
Lesson 3.

**Believed: Open 24 (the transfer race test) was written. TRUE, and it is the
shape session 11 specified.** Whether it fails against the old code is answered
carefully in Lesson 4, including the part that cannot be confirmed.

**Believed, implicitly, that the shot harness leaves an artifact a later build
can be compared against. FALSE, and it changes what "look at the screen" can
ever be.** flutter/test/shots/ is gitignored at .gitignore:7, so no PNG has
ever been committed, and `matchesGoldenFile` under `--update-goldens` only
writes. The render is a discovery tool with no memory. Lesson 2.

### Timeline (with evidence)

All times UTC, from `git log --format=%cI` and the publisher's own rows.

| Time | Event | Evidence |
|------|-------|----------|
| Jul 28 08:28 | f2.70 patch 20 delivered, session 11's ground truth | delivery row, 4d03f13 |
| 08:45:40 | 56bcf41 Phase 3 batch 5: categories, caps, and a delete that never loses entries. 912 green | commit message |
| 08:45:40 | **The render step finds the batch's own core rule inverted before it ships**: the delete sheet opened with "No category" selected. Fixed inside the same commit, and the replacement guard proven by reverting the default | commit message, `Expected: not null / Actual: <null>` |
| 08:45:40 | The categories golden generator executes the real mobile/lib/categories.js. 86 cases across normalizeCategoryTree (8), promoteChildren (40), categoryTree (8) and recategorizeTransactions (30) | flutter/test/goldens/categories_goldens.json, counted |
| 08:53:47 | 102ef74 closes the two gaps session 11 named: the race test and the fixture audit rule. Carries the session 11 write-up. 913 green | commit message, diff |
| 09:40:02 | Merge #228 (c7b84f6), two parents | `git cat-file -p c7b84f6` |
| 09:51:06 | f2.71 patch 21 delivered, 11m04s after the merge | delivery row, 9bc8fb8 |
| after | **Founder confirms f2.71 on the phone** | founder |

Two commits in this round, and no third. The previous three rounds each carried
a separate QA round commit immediately before the merge (63f5b19, fd43e25,
e2186b0). This one does not. That is not an accusation and it is not evidence
that no review happened; it is evidence that nothing in the record can tell us
either way, which is Lesson 6.

### Divergence point

There is no delivery divergence this round. The stamp built, shipped, was
logged, and matched the phone. Five in a row.

The belief divergence is **inside 56bcf41, at the moment the delete sheet was
written with `String? _toId;` and a test named 'untagging is a deliberate
second choice' was written beside it and went green.**

From that moment the branch contained a screen that did the opposite of the
founder's decision, a passing test whose NAME described the correct behaviour,
and a suite of 911 other green tests. Every automated signal in the project
said the rule was honoured. The only thing in the system capable of noticing
was a person looking at a picture of the sheet, and that is what noticed.

The shape, and it is the same shape as session 10's payday case one level up:
**a test written from the same mental model as the code cannot test the model,
only the code's agreement with it.** The model here was "the sheet offers
moving and offers untagging, and untagging is clearly the second choice". That
sentence is true of the LAYOUT and false of the STATE. A test that reads text
can only ever check the layout.

### Root cause

**1. The test asserted the presence of options, not the selection among them.**
The distinction sounds pedantic and is worth 250 pesos of someone's grocery
history. `find.text('No category')` finds the chip whether it is selected or
not. `find.textContaining('They stay in your history with no category')` finds
the explanation whether or not it describes what is about to happen. Neither
finder can see `selected:`, which is the only property that decided the
outcome. The chips are built at flutter/lib/screens/categories.dart:577 and
:591, and the state that drives them is one field.

The shipped version makes the default explicit and says why, at
flutter/lib/screens/categories.dart:483 to :490:

    /// Starts on a REAL category, not on "No category".
    ///
    /// The render caught this: the sheet opened with "No category" selected, so
    /// the default outcome of tapping Delete was untagging every entry. That is
    /// the exact opposite of the rule this screen exists to honour.
    late String? _toId = _others.isEmpty ? null : '${_others.first['id']}';

**2. Nothing in the suite could see a default, because no test tapped nothing.**
Every category test taps a chip before asserting, which makes all of them
correct and all of them blind to the starting state. Measured rather than
argued: reverting the default in a scratch worktree and running the whole
categories file failed exactly ONE test out of nine. The other eight, including
'untagging happens only when it is chosen' and 'deleting a category MOVES its
entries, keeping every peso', stayed green while a straight-through tap
untagged everything.

**3. The render has no memory, so its catches are leads and not guards.**
flutter/test/shots/ is gitignored, CI runs the harness with `--update-goldens`
so it only ever writes, and the PNGs are never committed. Nothing compares
today's sheet to yesterday's. This is a deliberate design, documented in
CLAUDE.md, and it is correct for its purpose, but it means the render can never
protect anything on its own. Every render catch has to be converted into an
assertion or it protects nothing after the day it happened.

### Lessons and guards

**Lesson 1. A test for a DEFAULT or a SELECTION must assert the selected state,
not the presence of the options. This is the second time in three sessions that
a test certified the bug it was written to prevent.**

The old test was never committed, because it was rewritten inside the same
commit that introduced it. That matters, so it is said plainly: the strongest
evidence this log knows how to produce, a diff showing an assertion being
inverted, DOES NOT EXIST for this case. What exists is the commit message of
56bcf41, which wrote it down:

    the test I had written asserted that untagging was "a deliberate second
    choice" and passed, because it checked the words on screen and not which
    chip was lit. A test written from the same mistaken picture as the code
    certifies the mistake.

and the comment kept in the replacement test, flutter/test/categories_screen_test.dart:143
to :146:

    // The first version of this test asserted that untagging was "a
    // deliberate second choice" while the code made it the default. It
    // passed. A test written from the same mistaken picture as the code
    // certifies the mistake.

Rather than take either on trust, both halves were reproduced in a detached
worktree of the delivered commit. The buggy default was restored
(`String? _toId;`), and the old test was reconstructed from the description
above:

    testWidgets('RECONSTRUCTED OLD: untagging is a deliberate second choice', (tester) async {
      await _open(tester);
      await _openDeleteFor(tester, 'Food');
      expect(find.text('No category'), findsOneWidget);
      await tester.tap(find.text('No category'));
      await tester.pumpAndSettle();
      expect(find.textContaining('They stay in your history with no category'), findsOneWidget);
    });

Result: the reconstruction PASSES against the buggy code, and the shipped guard
fails against it with the exact line the commit message quoted:

    Expected: not null
      Actual: <null>
    tapping straight through must not drop the tag

So a test named for the rule, green, in the file for the feature, sat one line
away from a screen that broke the rule. The reconstruction is labelled a
reconstruction because it is one; the failure line is not, it came out of a
real run this session.

**Guard for the instance, SHIPPED, strongest tier, and independently proven
this session rather than inherited.** flutter/test/categories_screen_test.dart:137,
'the DEFAULT is moving, not untagging'. It opens the sheet, taps Delete
immediately without touching a chip, and asserts the entry still has a
`categoryId` and still has its 250 pesos. It is the only test in the file that
taps nothing first, and it is the only one that fails when the default is
wrong.

**Guard for the class, NOT WRITTEN. NEW Open 25.** The rule is one sentence and
it generalises past chips: **when a screen has a default, a test must exercise
the path where the user changes nothing.** The natural home is CLAUDE.md beside
the prove-it-can-fail section, because that section is already about tests that
pass for the wrong reason, and this is the third named species of that (a test
written from the same model, an alarm that never proved its silent half, and
now a test that reads layout while the bug is in state). Medium tier when
written, and it should be called medium, because nothing fails if it is
forgotten. The stronger companion, and it is cheap, is a shared test helper
that makes asserting selection easier than asserting text, so the lazy path and
the correct path are the same path. Neither is written here; this session does
not edit CLAUDE.md or flutter/test.

**Lesson 2. Looking at the render is now the highest-yield defect finder in the
project, and it is not a guard at all. It is a lead generator with no memory,
and its whole value depends on each lead being converted into an assertion.**

The record, verified against commit messages rather than recalled: batch 2
(a9c152e, session 9), the harness photographed leftover state and labelled it
fresh, found by looking. Batch 4 (0fdd121, session 11), the account chip printed
a rounded balance the next tap refused, found by looking. Batch 5 (56bcf41,
this session), the delete sheet defaulted to untagging, found by looking. Three
catches in the last four batches, and the missing batch (a10041e, the nightly
nudge) is the one where the QA pass found everything instead.

Every one of those three was invisible to a fully green suite on a real runner:
673 tests then, 893 then, 912 this time.

So the honest ranking. Looking at the screen is a DISCOVERY method, and this
log's guard tiers do not have a slot for discovery methods, because all three
tiers are about what happens when nobody is watching, and this one only works
when somebody is. The reason it keeps winning is not that it is strong; it is
that it is the only step in the pipeline that inspects the actual artifact
rather than a claim about it. Sessions 6 through 9 kept finding the same shape,
a checking tool that verifies a stand-in, and looking at a PNG is the one step
with no stand-in in it.

What that implies about the automated tier is uncomfortable and should be
written down: **the automated tier in this project has still never caught a
defect that the author had not already thought of.** It catches regressions of
known defects, reliably and cheaply, which is real value. It does not find
anything new. Every new defect in five batches came from a render, a QA pass or
a retrospective.

**Guard, EXISTING and correctly ranked at last, plus a conversion rule that is
already being followed and is not written down anywhere. NEW Open 26.**
The existing guard is the CLAUDE.md rule to render every UI change before the
merge, and CI running the harness so it cannot rot. The missing piece is the
sentence that turns a lead into a guard: **a defect found by looking is not
fixed until an assertion exists that fails on the old behaviour.** All three
render catches did in fact produce one, so this is a habit being written into a
rule before it lapses rather than after. Medium tier, honestly, and the reason
it cannot be automated is worth recording so nobody proposes it again: the
obvious automated version, fail a pull request that touches
flutter/lib/screens/ without changing a file under flutter/test/shots/, is
IMPOSSIBLE here, because .gitignore:7 excludes that whole directory and no shot
has ever been committed. Committing them would turn every font or platform
difference between the sandbox and the runner into a red build, which is how
the harness got abandoned once before.

**Lesson 3. Open 22 is closed, and the version that shipped is better than the
version the retrospective drafted.**

Verified by reading .claude/skills/porting-money-logic/SKILL.md, not the commit
message. The file grew from 67 to 83 lines in 102ef74, and the new section at
:31 is titled "Audit the fixtures, not just the port". Session 11 drafted an
abstract instruction. What shipped keeps the instruction and adds both real
cases underneath it, which is the difference between a rule someone nods at and
a rule someone recognises:

    A golden replay proves parity on the cases someone thought to include, and
    nothing at all about the rest. So after the replay goes green, BREAK the core
    semantic on purpose and require it to fail: swap _jsRound for Dart's .round(),
    drop the JS coercion branch, remove the sort tiebreak. A replay that still
    passes has told you the fixture set is incomplete, not that the port is right.

**Guard, SHIPPED, medium tier and it must be called medium.** It is prose in a
skill file. Session 11's Lesson 3 is the standing proof that prose in this exact
file can be correct, nine days old, and walked into anyway. What makes this one
better than average is that a golden port cannot proceed without reading the
file, and the two examples are concrete enough to be recognised at the keyboard.
**Open 22: CLOSED.**

**Lesson 4. Open 24 is closed. The race test exists, it is the shape that was
specified, and one thing about it cannot be confirmed and is said instead of
smoothed over.**

flutter/test/transfer_screen_test.dart:213, 'a write landing mid-transfer
refuses instead of crashing'. It seeds Cash at 1000, starts a 1000 peso expense
WITHOUT awaiting it, immediately asks to move 1000 out of the same account,
then awaits both. It asserts the transfer comes back as an ordinary
`TransferRefusal.overdraft`, and that both balances are exactly where the spend
left them. That is session 11's specification, with 1000 instead of 3200.

The mechanism is sound by reading, and the reading is in the code rather than
in the test's own claims. `_serialized` at flutter/lib/data/store.dart:523
defers through `_writes.then(...)`, so a write started first is still queued
when the next caller's synchronous body runs. The old implementation at
0fdd121:store.dart:1741 ran `applyTransfer` against `data` synchronously before
its first `await`, saw 1000 pesos still there, approved, and then ran the engine
a second time inside `_mutate` after the spend had landed, where it threw
`StateError('the transfer became invalid mid-write')`.

**What cannot be confirmed, and why.** The new test cannot be run verbatim
against the old code, because the fix also changed the method's return type:
0fdd121 returned `Future<String?>`, the shipped version returns
`Future<transfers.TransferOutcome?>`, and the test reads `refusal!.refusal`. So
"this exact test goes red on the old shape" is a reasoned claim here, not a
measured one. It is not a bare guess either: session 11 staged the equivalent
race in a worktree against the old code and recorded the output,
`THROWN: Bad state: the transfer became invalid mid-write`. The honest summary
is that the alarm's firing half was proven on the old code by a different
harness, and its silent half was proven this session, since it is green in the
913 run.

**Guard, SHIPPED, strongest tier. Open 24: CLOSED.**

**Lesson 5. The category port reproduces an RN DISPLAY bug on purpose, and
whether that is right is an open question rather than a settled one. Recording
the question, and the reasoning on both sides, because the next porter will hit
it.**

The bug is real and small. mobile/lib/categories.js:60 filters children with
`c.parentId === pid`. When a category in the stored list has no `id` at all,
`pid` is `undefined`, and every ordinary top level category also has
`parentId === undefined`, so every one of them matches. The result is that each
top level row renders twice: once as a phantom child of the id-less row, once
at top level where it belongs.

It is visible in the locked fixtures, so nobody has to take this on trust. The
`junk` tree case in flutter/test/goldens/categories_goldens.json has the input
`[null, { name: 'no id' }, { id: 'ok', name: 'Ok' }]` and the recorded RN output
is three rows: the id-less row at depth 0, `ok` at depth 1, and `ok` again at
depth 0.

The Dart port reproduces it exactly, at flutter/lib/money/categories.dart:62,
where `child['parentId'] == t['id']` compares null to null for the same reason
`===` compares undefined to undefined. And the golden test compares the whole
row list rather than filtering, with the reason recorded at
flutter/test/categories_golden_test.dart:91 to :97. The commit message is
explicit that the first version of the test filtered those rows out and hid the
difference, and that it was changed to compare everything.

**The question. For MONEY math, porting the bug is unambiguously right**, and
CLAUDE.md and the porting skill both say so: the two apps must agree to the
centavo, a "fix" in one of them is a divergence, and a user who restores a
backup into the other app must see the same numbers. **For DISPLAY logic the
argument does not obviously carry**, and here is both sides as fairly as this
session can put them.

For porting it faithfully: the golden lock is the only mechanism that keeps the
two apps honest, and it works precisely because it has no exceptions to
negotiate. The moment "port it exactly, unless it looks wrong to you" enters the
rule, every future porter has a judgement call, and judgement calls are where
divergences hide. The input that triggers this is corrupt data that normal
loads never produce, since `normalizeCategoryTree` runs on load, so the cost of
faithfulness is a duplicated row on data that is already broken. And a
duplicated row is visible and harmless; the entries themselves are untouched.

Against: a duplicated category row is a lie on screen, the founder's users see
Flutter and not RN, and there is no user anywhere who benefits from two apps
agreeing about how to render corrupt input. Money must match because money is
compared across a restore. Pixels are never compared across a restore.

**Guard: NONE, deliberately, and the lesson is OPEN. NEW Open 27.** This is a
decision the founder or a session with that mandate should make, and it is one
sentence in .claude/skills/porting-money-logic/SKILL.md once made. The candidate
wording, so making the decision is a paste and not a project: **port the
behaviour exactly for anything a user could compare across the two apps
(amounts, dates, ordering, what is included), and for pure display of corrupt
input, port it faithfully AND open an issue against mobile/, so the two apps
converge by fixing RN rather than by diverging quietly.** That last clause is
what makes it safe: it keeps the lock absolute and gives the tidier behaviour
somewhere to go. It is written here and not applied.

**Lesson 6. The pre-merge QA pass is the guard this log ranks highest among the
medium tier, and it leaves no artifact, so nobody can tell whether it ran.**

Facts only. CLAUDE.md's merge rules require that "a QA pass ran on the changed
code (the qa-tester agent or equivalent) and every must fix finding was fixed
and re-checked" before Claude merges. Batches 2, 3 and 4 each produced a commit
that says so in its subject: 63f5b19 "Onboarding QA round", fd43e25 "Nudge QA
round", e2186b0 "Transfers QA round". Between them they carried nine real
defects that 673, 893 and 912 green tests could not see. Batch 5 has no such
commit. `git log 4d03f13..origin/main --oneline` returns exactly two commits,
the batch and the gap-closing follow-up, and the merge is 46 minutes after the
last of them.

What that does NOT establish: whether a QA pass ran. A pass that finds nothing
correctly produces no commit. This round also had its major defect caught
earlier, by the render, which is a plausible reason a later pass would find
less.

What it DOES establish, and this is the finding: **the record cannot answer the
question.** A merge gate whose satisfaction leaves no trace is a gate that can
be skipped on a busy day with nothing anywhere disagreeing, and the next
retrospective will not be able to tell either. That is the same failure class
as the delivery outage of session 1, where "merged" was believed to mean
"delivered" because nothing wrote down which one had happened. The fix there
was the publisher writing its own row into docs/delivery-log.md, and that fix
ended the outage permanently.

**Guard, NOT WRITTEN. NEW Open 28.** The cheap version is a required line in the
pull request body or in one commit message per round, naming the QA pass and
its findings, including "none". The strong version is the same thing checked
automatically: a step on the Flutter check that fails when the head commit of a
branch touching flutter/lib/ carries no QA record. Strongest tier for PRESENCE
only, and that limit must be stated in the same breath, because a presence
check can be satisfied by typing the words. Presence is nonetheless exactly
what is missing: today there is no way to know, and a check that makes the
absence visible converts a silent skip into a red X. Note this session did not
find evidence that the gate was skipped, and it is not claiming that. It found
that the question is unanswerable, which is a defect in the instrument.

**Lesson 7. The standing CLAUDE.md fact check. Everything it claims still
matches the repository this round, and the check is reported anyway.**

Two consecutive sessions found a false factual claim in CLAUDE.md, which is why
this is a step and not a favour. This round the answer is that it is clean, and
saying so is the point of doing it.

`git log 4d03f13..origin/main -- .github/workflows/ CLAUDE.md .claude/` returns
exactly one commit, 102ef74, whose only change in that set is the sixteen line
fixture audit section in the porting skill. No workflow changed and CLAUDE.md
did not change. Re-verified by reading regardless:

- Every path CLAUDE.md names exists where it says: flutter/shorebird.yaml,
  flutter/test/update_stamp_test.dart, flutter/test/screens_shot.dart,
  flutter/lib/widgets/salapify_icon.dart, flutter/lib/main.dart,
  docs/delivery-log.md, mobile/app/(tabs)/more.js.
- All five skills exist in .claude/skills, and the file's description of them
  (three adapted, two ours) still matches the directory.
- mobile/lib/storage.js:9 still holds `salapify_data_v2`.
- mobile/package.json:11 still pins `"expo": "~54.0.0"`, matching the SDK 54
  claim in the opening paragraph.
- The 120 character stamp cap is live at update_stamp_test.dart:20; the live
  stamp is 99 characters.
- flutter-check.yml:20 triggers on `claude/**` with no paths filter;
  flutter-preview.yml triggers on `main` with paths `flutter/**` plus its own
  definition. Both still match rule 1 word for word.
- The icon rule's named test exists: lessons_content_test.dart:215, 'every icon
  name actually resolves to a glyph'.
- The claim that CI runs the shot harness separately with `--update-goldens` is
  true: flutter-check.yml:80.
- The local SDK claim is true: /opt/flutter reports Flutter 3.44.6 stable.
- The three delivery commands ran as written and returned f2.71 patch 21.
- The render command in the "look at the screen" section ran as written this
  session, in a worktree of the delivered commit, and passed at +33 in 15
  seconds, writing 42 files into flutter/test/shots/.

**One imprecision, named rather than left for session 13.** The "look at the
screen" section says "The directory listing is the count", which is good advice
and slightly misleading in one respect: the directory is gitignored
(.gitignore:7), so the listing counts whatever the last local run happened to
leave behind, not what the harness currently renders. The live checkout has 44
files and a clean render of the delivered commit produces 42; the two extra
(catalog.png, lesson.png) are leftovers from renamed shots that nothing ever
cleans up. Nobody was misled this round. The accurate version of the sentence
is that the harness is the count, and `ls` after a fresh run is how to read it.
Not a new open item, because it is a refinement of the same wording Open 19
already improved once, and this log has learned that rewriting one sentence
repeatedly is its own failure mode.

**Lesson 8. Is the five-delivery streak real? Same answer as last session, and
it is worth repeating rather than assuming it was read.**

The DELIVERY half is real and mechanical. f2.67 through f2.71 each have a row,
each in mode `patch`, each against an unchanged 0.6.2+11, each confirmed on the
phone. Merge to row was 11m50s, 11m54s and 11m04s in the last three rounds. The
mechanism that produces those rows was built after it failed in session 1 and it
is working.

The CORRECTNESS half is not solved and this round makes that clearer, not less
clear. In five batches, the automated suite has never once been the thing that
found a new defect. This round it was green while the flagship behaviour of the
batch was inverted. Delivery is solved. Correctness rests on a human-shaped pass
and a human looking at pictures, both of which are medium tier by this log's own
ranking, and Lesson 6 says the first of them cannot currently be shown to have
happened.

### Open lessons carried forward

**Open 3, nothing compares the phone to main: STILL OPEN, by design.** The
founder confirmed f2.71 in person, which remains the only proof that counts.

**Open 6, the watchdog has never been observed running a scheduled pass: STILL
OPEN.** Run history is unreadable from this sandbox and `gh` is not installed
here. No spurious issue in evidence, and this round's 11m04s gap was well
inside the 2700 second grace at delivery-watchdog.yml:43.

**Open 7, the watchdog blind spot for merges that do not bump the stamp: STILL
OPEN.** Not exercised, the merge bumped the stamp.

**Open 8, split the publish step from the log scraping: STILL OPEN,**
re-verified by reading, the scrape is still inside the ship step with `|| true`
at flutter-preview.yml:127 and the comment at :112 to :126 intact.

**Open 9, FAILED rows in docs/delivery-log.md: STILL OPEN.** The log carries 31
`patch` rows and 2 `release` rows and no failure rows at all, so a build that
ships nothing still leaves no trace in the file the delivery check reads.

**Open 10, nothing holds Pan's rendered size: STILL OPEN.**

**Open 11, nothing stops a sixth private kicker: STILL OPEN.**

**Open 13, the shot harness mounts screens through a private copy of the
shell's wiring: STILL OPEN, and it grew.** The two new category shots build
their own `MaterialApp` by hand at screens_shot.dart:1053 to :1058. The file now
contains 18 hand-built `MaterialApp` sites.

**Open 14, CLAUDE.md workflow item 4 versus the eas-update trigger: STILL OPEN,
untouched, re-verified.** eas-update.yml:18 still triggers only on
`claude/salapify-v2`, a branch retired in cf5c6a7.

**Open 15, the walk-keying and frame-asserting rule: ADVANCED AGAIN, still
open.** Both new shots assert their frame before photographing it
(`expect(find.text('YOUR CATEGORIES'), findsOneWidget)` at screens_shot.dart:1060
and `expect(find.textContaining('entry is tagged'), findsOneWidget)` at :1070).
Measured coverage: 7 of 26 `expectLater` sites now assert what is in front of
the camera, up from 5 of 24. The practice is being applied to every new shot,
which is what this item wanted; the MEDIUM tier is still not done, since the
screens_shot.dart header still records three hard-won harness rules and
asserting the frame is not one of them.

**Open 16, prove-it-fails says how to break the code and not how to restore it:
STILL OPEN, and it earned its keep again.** Every break in this session ran in a
detached worktree under the scratchpad rather than in the live tree, which was
the only safe choice, because the live tree currently holds another task's
uncommitted tax deadline work. `grep -n "restore\|git checkout" CLAUDE.md
.claude/skills/*/SKILL.md` still returns only unrelated hits.

**Open 17, nothing generalises the payday guard: STILL OPEN, re-verified.**
`PlannedReminder` at flutter/lib/money/reminders.dart:25 still carries only
title, body and when, with no `kind` field, so nothing can assert that every
notification key onboarding writes is one the planner can act on.

**Open 18, the habit signal has four independent remembering events: STILL
OPEN, and it is five now.** `sampleTxIds` is imported and filtered at
quickadd.dart:28 and :60, reminders.dart:112, coach.dart:313 and chain.dart:69.
No shared accessor exists.

**Open 20, mobile/lib/notifications.js has the same sample-row defect Flutter
fixed: STILL OPEN, re-verified.** `loggedToday` at :99 still does not exclude
the sample ids.

**Open 21, the balance label guards are example-shaped and the property is
already proven: STILL OPEN.** The property test session 11 specified is not in
the tree; `grep -rn "never refused as an overdraft\|displayed figure" flutter/test/`
returns nothing. The three example-shaped guards are all present and green.

**Open 22, porting-money-logic says how to generate goldens and not how to find
out whether they are enough: CLOSED.** Shipped in 102ef74 as the "Audit the
fixtures, not just the port" section at SKILL.md:31, with both worked examples.
See Lesson 3.

**Open 23, the "*100 overflow" rule lives in prose and was walked into anyway:
STILL OPEN.** No shared centavo helper exists in flutter/lib/money/; the inline
`* 100` pattern still appears across accounts_calc.dart, budget.dart, coach.dart,
cycle.dart, debtmath.dart and goals_calc.dart.

**Open 24, nothing guards the transfer race: CLOSED.** Shipped in 102ef74 at
transfer_screen_test.dart:213. See Lesson 4, including the one thing about it
that is reasoned rather than measured.

**NEW Open 25: nothing says that a test for a default must exercise the
untouched path.** One sentence in CLAUDE.md beside prove-it-can-fail, plus the
cheaper companion of a selection-asserting test helper. Medium tier when done.
Two instances now, sessions 10 and 12.

**NEW Open 26: a defect found by looking is not fixed until an assertion fails
on the old behaviour, and that sentence is written nowhere.** All three render
catches happened to produce one. Medium tier when written, and Lesson 2 records
why the automated version is impossible while flutter/test/shots/ is
gitignored.

**NEW Open 27: whether to port a DISPLAY bug faithfully is undecided.** The
category tree duplicates every top level row when a category has no id, in both
apps, on purpose. Candidate wording is in Lesson 5, and it needs a decision
rather than a guard.

**NEW Open 28: the QA merge gate leaves no artifact, so nobody can tell whether
it ran.** A required QA line per round, ideally checked by the Flutter check.
Strongest tier for presence only, which is the honest limit and also exactly
what is missing.

### Guard status re-check

Read and re-run, not assumed. `git log 4d03f13..origin/main -- .github/workflows/
CLAUDE.md .claude/` returns only 102ef74, whose sole change in that set is the
new skill section, so every workflow line number the last four entries recorded
still stands. Verified by reading anyway:

- The duplicate stamp refusal: PRESENT, flutter-preview.yml:173 to :181.
  Correctly silent, the stamp was distinct.
- The `|| true` scrape guard: PRESENT, flutter-preview.yml:127, comment intact.
- The nothing-shipped failure issue: PRESENT, flutter-preview.yml:221 onward.
  Not fired, correctly.
- The release install shout: PRESENT. Correctly silent, the row reads `patch`.
- The publisher watching its own definition: PRESENT in the paths filter.
- The delivery watchdog's `--first-parent` and 2700 second grace: PRESENT,
  delivery-watchdog.yml:99 and :43, load-bearing comments intact.
- flutter-check.yml on `claude/**` with NO paths filter: PRESENT at :20, and the
  separate shot harness run at :80.
- The stamp cap: PRESENT, update_stamp_test.dart:20, and the live stamp is 99
  of 120 characters.
- Session 6 and 7 guards (a11y_test.dart, nav_ambiguity_test.dart, the injected
  clock, header_action_test.dart, app_harness.dart): PRESENT.
- Session 8's guards: PRESENT and untouched.
- Session 9's guards: PRESENT. onboarding_test.dart 'the QA round' group intact.
- Session 10's guards: PRESENT. onboarding_test.dart 'the nudge QA round' group
  intact, the `asking` latch, and the sample exclusion at reminders.dart:112.
- Session 11's guards: PRESENT. The three transfer guards (the giant balance,
  the refusal that never claims more than the account holds, the picker label)
  are in transfer_screen_test.dart, and the race test now sits beside them.
- The whole suite: 913 pass, analyze clean, re-run independently on the
  delivered commit 9bc8fb8 in a detached worktree. Second session in a row that
  the number is measured rather than inherited.

**No guard was found deleted, disabled or routed around this round.** That is
the plain answer and it is the first time in three sessions it has been the
answer. The nearest thing to a route-around is Lesson 6, which is not a guard
being bypassed but a guard that cannot be observed either way, and that is
recorded as Open 28 rather than as a violation.

### What it cost, and what it did not

Cost: nothing reached the phone wrong. The delete sheet defect was found and
fixed inside the commit that created it, and the shipped f2.71 behaves as the
founder decided. The real cost is the one this log keeps measuring, which is how
close the miss was: one green suite of 912 tests, one test named after the exact
rule, and the only thing standing between the founder's grocery history and an
untagging tap was somebody opening a PNG.

Not cost: no data was lost, no stamp was stranded, the base APK is untouched,
and the founder owes no manual install.

---

## 2026-07-28, session 11: the fix that moved the lie one decimal place over

One delivery, one clean row, confirmed on the phone by the founder. There is no
delivery incident in this entry and none is manufactured. That is the fourth
clean delivery in a row, and the honest reading of that streak is in its own
section below, because a streak is exactly the kind of thing that starts being
read as "everything is fine".

What this session has instead is a defect shape about FIXES rather than about
code: a fix that was verified against the example that prompted it instead of
against the property it needed to have, and which therefore reproduced the
original defect one decimal place further down. It was caught by the qa-tester
gate, and this entry can put a number on how little the first fix actually
achieved, because the property was run against all three versions in a scratch
worktree while writing this.

It also has the finding this log values most: an existing written guard that
was routed around. Not deleted, not disabled. The rule was in
.claude/skills/porting-money-logic/SKILL.md, it named this exact hazard in
words, and the new code walked into it nine days later.

And it closes Open 19, and pays off the suite baseline debt that sessions 9 and
10 both had to declare.

### What we believed / What was true

**Believed: f2.70 reached the phone. TRUE, and confirmed in person.** Read from
`git show origin/main:docs/delivery-log.md | tail -3`, the last row is:

    | 2026-07-28 08:28 UTC | f2.70 | 20 | patch | 0.6.2+11 | 9ce150ac (run 30341730082) |

Mode `patch`, so nothing was stranded and no manual install is owed.
`flutter/pubspec.yaml:12` still reads `version: 0.6.2+11`, unchanged since
session 5, so the installed base APK is still the right one. The stamp in the
tree, flutter/lib/main.dart:29 to :30, is `'f2.70 · Move money between your own
accounts, in Accounts. It never touches your budget.'`, 88 characters, inside
the 120 cap enforced at flutter/test/update_stamp_test.dart:20. Stamp in the
code, stamp in the log, stamp on the phone: three for three.

**Believed: the merge used a merge commit, not a squash. TRUE, verified rather
than assumed.** `git cat-file -p 9ce150a` shows two parents, 9400ebe4 and
e2186b00.

**Believed: rounding the centavos fixed "the chip prints a balance the next tap
refuses". FALSE. It moved the defect, it did not remove it, and it did not even
reduce how OFTEN it happens.** Measured, not argued, in Lesson 1.

**Believed: 229 golden vectors generated by executing the real RN function
means the port matches RN. TRUE for everything the fixture set reaches, and the
fixture set had two holes in one batch.** Lesson 2.

**Believed: validating outside the write queue and applying inside it was safe
because the window is tiny. FALSE, and the window is not tiny, it is a whole
queued write.** Reproduced from scratch while writing this entry, failure line
quoted in Lesson 4.

**Believed, since session 10: the suite baseline is 898 and nobody has re-run
it independently. NOW MEASURED.** 898 tests pass and `flutter analyze` reports
no issues, run against a clean checkout of the delivered commit 4d03f13 in a
throwaway git worktree under the scratchpad, so the count is of the SHIPPED
tree rather than of a tree another task is editing. Two sessions of "we are
inheriting this number on trust" are now settled.

**Believed: CLAUDE.md's brightness claim from Open 19 was corrected. TRUE, it
shipped inside 0fdd121, and the new wording checks out against the harness with
one small imprecision worth naming.** Lesson 6.

### Timeline (with evidence)

All times UTC, from `git log --format=%cI` and the publisher's own rows.

| Time | Event | Evidence |
|------|-------|----------|
| Jul 28 06:41 | f2.69 patch 19 delivered, session 10's ground truth | delivery row, 9400ebe |
| 07:44:29 | 0fdd121 Phase 3 batch 4, transfers, golden locked, 229 cases. Carries the session 10 write-up and the Open 19 CLAUDE.md correction. 893 green | commit message |
| 07:44:29 | **The prove-it-can-fail step finds a hole in the author's own fixtures**: `.round()` for centavos passes all 125 cases because none reaches a negative half centavo | commit message, `Expected: <-2.31> / Actual: <-2.32>` |
| 07:44:29 | **The render step finds a real honesty bug before it ships**: the picker chip printed a rounded balance the next tap refused. Fixed by rounding the centavos | screens_shot.dart:990, transfer-sheet-dark.png, seeded with 48,500.55 at :960 |
| 08:09:10 | e2186b0 QA round. **The qa-tester pass finds three MUST fixes and two SHOULDs**, including that the display fix above was the same defect one decimal over. 898 green | commit message |
| 08:16:34 | Merge #227 (9ce150a), two parents | `git cat-file -p 9ce150a` |
| 08:28:28 | f2.70 patch 20 delivered, 11m54s | delivery row, 4d03f13 |
| after | **Founder confirms f2.70 on the phone** | founder |

Test counts, independently re-run this time. 898 pass and analyze is clean on
4d03f13, matching what e2186b0 claimed. The run happened in a detached worktree
in the scratchpad because another task is editing flutter/ right now; a run in
the live tree returned 903, which is that task's in-progress work and not a
measurement of anything shipped. Naming that difference is the point: the same
command in the same repository gave two numbers eleven minutes apart, and only
one of them was about the phone.

### Divergence point

There is no delivery divergence this round. The stamp built, shipped, was
logged, and matched the phone.

The belief divergence worth naming is **07:44:29 UTC, inside 0fdd121, at the
moment the rounded-centavo `balanceLabel` was written and a test was written
alongside it using 48,500.55.** Not the moment the whole-peso formatter was
first used on the chip. That first version was an ordinary oversight and the
render caught it, which is the system working.

The divergence is the instant the FIX was accepted on the strength of the one
example that had exposed the bug. From that moment the branch contained a
screen that still overstated balances, a passing test that said it did not, and
a green Flutter check on a real runner. Everything downstream read as fixed.

Name the shape, because it is new to this log and it will recur: **a bug
arrives as an example, and an example is a terrible specification for a fix.**
The example says what the answer must be for one input. The fix has to be
correct for a set. When the fix is shaped around the example, the natural test
to write is the example, and the example passes, so nothing in the system is
capable of noticing that the fix only shrank the defect.

### Root cause

**1. Rounding was the wrong OPERATION, and both wrong versions were rounding.**
The whole-peso formatter rounds. The first fix rounded the centavos. Rounding a
balance up states more money than the account holds, roughly half the time, at
whatever precision you round to. The example 48,500.55 stopped failing because
its centavos survived, so it never exercised the direction that breaks.
0.999 does: `_jsRound(0.999 * 100) % 100` is `100 % 100`, which is 0, so the
"no centavos, use the whole peso formatter" branch fires and prints `₱1`. The
account holds 0.999.

The consequence QA found is worse than a wrong label, because the refusal
message agreed with it. Moving 1 was refused by a sentence that also said "only
has ₱1". The screen and the sentence agreed with each other and both
contradicted the app.

The shipped fix TRUNCATES, at flutter/lib/money/transfers.dart:88 to :100, and
the comment at :74 to :87 now records why the shape matters rather than why the
example was wrong: "Rounding UP a balance can always overstate it. Truncating
never can, so this is the shape the problem actually has."

**2. The golden lock proves parity on the cases the author thought to include,
and is silent about the rest.** Two independent misses in one batch, one caught
by the author's own prove-it-can-fail step and one caught only by QA. Details
and numbers in Lesson 2. The vectors are generated by EXECUTING the real RN
function, which is the strongest form this project has, and it is still only as
complete as the fixture list. flutter/test/goldens/transfer_goldens.json holds
229 cases built from 7 accounts and 28 distinct amount strings, and both misses
were inputs outside that cross product.

**3. A rule that exists in a skill file is not a rule that gets read at the
moment it applies.** .claude/skills/porting-money-logic/SKILL.md:39 to :41,
added on 2026-07-19 in 089e6b7, says:

    - Guard non-finite before round(): a backup can smuggle Infinity or a value
      whose *100 overflows, and round() throws on non-finite. Render the raw
      value and stay alive, the way formatMoney and _wholePeso do.

The 0fdd121 `balanceLabel` guarded the INPUT (`if (!v.isFinite)`) and then
computed `v.abs() * 100`, which is the overflow the sentence names, in the same
line as the `round()` the sentence names. A balance of 1e307 produced Infinity,
then NaN, then `NaN.toInt()` threw `UnsupportedError`, and the transfer sheet
failed to build. Every later tap threw again with nothing on screen to explain
it, and the only escape was finding and editing that account. Reachable from a
restored backup or a long typed number.

**4. The race was built next to two worked examples of how not to build it.**
Detail in Lesson 4.

### Lessons and guards

**Lesson 1. A fix verified against the example that revealed the bug is only
proven for that example. The guard written from the same example inherits the
same blind spot, and then reads as proof.**

The evidence, and it is the strongest thing in this entry, because it is
measured rather than reasoned. All three versions of `balanceLabel` were run
over the same 20,005 balances (10 hand-picked edges plus 19,995 pseudorandom
values spread across eight orders of magnitude), and for each one the displayed
figure was fed straight back into the real `applyTransfer` engine to see
whether moving it would be refused:

    whole-peso (before any fix):    9974 of 20005 refused, worst overstatement 0.5000
    rounded-centavo (0fdd121 fix): 10241 of 20005 refused, worst overstatement 0.0050
    truncating (shipped, e2186b0):     0 of 20005

Read the middle row carefully. The fix reduced the SIZE of the lie by a factor
of a hundred and did not reduce how often it happened at all. It happened
slightly more often. The screen went on printing a number the next tap refused
about half the time, and the test written to prove it fixed passed, because
that test was 48,500.55.

That test is quoted in full, because the session 5 convention asks which tests
CHANGED and this round the answer is "none, and that is the finding". No
assertion was inverted and none was deleted. What happened is subtler and worth
recognising next time: a NEW test was written for the fix, it was green, it
stayed green, and it was green against broken code. From 0fdd121,
flutter/test/transfer_screen_test.dart:126:

    testWidgets('the picker shows the balance the refusal will use', (
      tester,
    ) async {
      // The render caught this one: an account holding 48,500.55 displayed as
      // "48,501", and moving 48,501 out of it is refused. A screen must not
      // print a number the next tap contradicts.
      await _open(tester);
      await _openSheet(tester);
      expect(find.textContaining('BPI  ₱48,500.55'), findsWidgets);
      expect(find.textContaining('BPI  ₱48,501'), findsNothing);

That test is byte for byte identical in the shipped tree today. It was never
wrong. It was just never about the property.

**Guard for the instance, SHIPPED, strongest tier.**
flutter/test/transfer_screen_test.dart:161, 'the refusal never claims more than
the account holds', which drives an account at 0.999, asserts the chip reads
`₱0.99` and never `₱1`, taps Move it with `1`, and asserts the sentence reads
`Wallet only has ₱0.99.` and that no transaction was written. Both halves.

**Guard for the class, NOT WRITTEN, and it is the honest upgrade. NEW Open 21.**
The current guards for this bug are all example-shaped: three specific balances
in three specific tests. The property is one sentence and it is machine
checkable: **for any balance the picker displays, moving exactly the displayed
figure must never be refused as an overdraft.** That is stronger than "the
label must not exceed the balance", and it is stronger for a reason found by
running it: the naive version FAILS today on negative balances, because
truncation moves toward zero, so an account at -0.999 shows as -₱0.99, which is
more money than it holds. That is harmless, since no positive amount is movable
out of an overdrawn account either way, but a guard written the naive way would
have failed on arrival and the likely response would have been to weaken it.
Stating the property in terms of what the next tap does keeps it true and keeps
it about the user.

Cost and status, measured rather than estimated: about 25 lines, no mocks, runs
in well under a second over 20,000 values, passes against the shipped code, and
FAILS against both earlier versions with the counts above. Both halves of the
alarm are therefore already proven, before the guard exists. It is not written
because flutter/test is being edited by another task as this is written.

**Lesson 2. Golden vectors prove the port matches RN on the cases the fixture
author imagined. Two things escaped in one batch, and the second one moved
money.**

Miss (a), caught by the author's own prove-it-can-fail step. Swapping the Dart
centavo rounding from the JS-faithful `_jsRound` to Dart's `.round()` passed
all 125 cases in the fixture set at the time. `Math.round` and Dart's `round()`
differ only on a negative half centavo, and nothing in the set reached one,
because overdrafts are blocked so the SOURCE can never get there. The
DESTINATION can. Fixed by adding an account sitting at -4.995 (visible today at
transfer_goldens.json, account `halfneg`, and 56 of the 229 cases now involve
it), and the guard then bit: `Expected: <-2.31> / Actual: <-2.32>`.

Miss (b), caught only by QA. `jsNumber` accepted a sign INSIDE a radix literal,
because Dart's `int.tryParse` does. `"0x+10"` parsed as 16, so the Flutter app
would have moved 16 pesos where the live RN app refuses. The goldens could not
see it: the fixture set carries `0x10` and carries `+7`, and it does not carry
the two glued together. Verified by reading the fixture file rather than by
believing the commit message: the 28 distinct amount strings include `0x10`,
`+7`, `-5`, `1e3`, `1,2,3`, `Infinity` and `abc`, and no signed radix form.

The pattern is one sentence. **A replay that passes proves the port matches the
fixtures. It says nothing at all about whether the fixtures reach the
semantics.** Miss (a) was found because someone deliberately broke the
semantics and demanded a red. Miss (b) would have been found the same way, by
breaking the coercion instead of the rounding, and nobody thought to.

**Guard, PROPOSED, medium tier, and NOT written by this session. NEW Open 22.**
The right home is .claude/skills/porting-money-logic/SKILL.md, because a skill
loads when the task matches, which is closer to the moment of use than a
paragraph in CLAUDE.md. It is 67 lines today and it says nothing of this kind;
`grep -n "break\|fail\|prove\|incomplete\|fixture"` over it returns only the
unrelated hits. The two sentences that would close it, added to "The contract"
after item 3:

    5. Before trusting a golden replay, break the port's core semantics ONE at a
       time (the rounding mode, the numeric coercion, the sort tiebreak, the
       date grammar) and require the replay to go RED for each. A replay that
       still passes proves the fixture set is incomplete, not that the port is
       right; extend the fixtures until each break is caught, and record which
       fixture you had to add in the commit message.

This session does not edit skills or CLAUDE.md, on purpose. A lunch and learn
agent writes its own log; a change to the project's standing rules belongs to
the founder or to a session with that mandate. The text is written out above so
closing it is one paste.

**Lesson 3. A written rule named this exact hazard nine days earlier, in the
skill that governs this exact kind of work, and the code walked into it anyway.
This is the most valuable finding in the session, because it is a guard that
was routed around rather than a guard that was missing.**

porting-money-logic/SKILL.md:39 to :41 says to guard non-finite before
`round()`, and it names "a value whose *100 overflows" in those words. The
0fdd121 `balanceLabel` checked the input for non-finite and then wrote
`_jsRound(v.abs() * 100)`. Both halves of the rule are in that one line: the
`*100` and the round. It was not ignored out of disagreement. It was a rule
about a hazard, read at some point in the past, and not recalled at the
keystroke where it applied. The dev sandbox cannot fault the author's attention
here and neither can this log, because "read the skill more carefully" is a fix
that fails the moment anyone is busy.

Cost if it had shipped: a permanently dead transfer sheet for anyone whose
backup carries a very large balance, with no message, no recovery path inside
the feature, and every later tap throwing again.

**Guard for the instance, SHIPPED, strongest tier.**
flutter/test/transfer_screen_test.dart:141, 'a giant balance never takes the
sheet down', drives an account at 1e307 and asserts `tester.takeException()` is
null and the sheet builds. The failure it was born catching, quoted in e2186b0:

    Expected: null / Actual: UnsupportedError: Infinity or NaN toInt

The fix also stopped inventing decimals on saturated values, by falling back to
the whole peso formatter past 2^53 centavos (transfers.dart:92 to :94).

**Guard for the class, NOT WRITTEN, and ranked honestly. NEW Open 23.** The
durable version is not another sentence in the skill; the sentence already
existed and did not fire. It is to make the safe path the only path: one shared
helper in flutter/lib/money/ that takes a value and returns either its centavos
or a "too big, format it whole" signal, with the non-finite and overflow checks
inside it, and every money formatter that needs centavos calling that instead
of writing `* 100` itself. Medium tier when done, and it should be called
medium, because nothing physically stops the next author writing `* 100`
inline. It is still a real improvement over four independent remembering
events, and it is the same structural move Open 18 proposes for the habit
signal. If the two are ever done together, this log should say so, because that
would be two lessons converging on one idea rather than two chores.

**Lesson 4. I built a race that the same file already knew how to avoid, twice,
one of which carries the reason in a comment.**

`store.transferBetweenAccounts` in 0fdd121 ran the money engine twice: once
against `data` outside the write queue to decide whether to refuse, and once
inside `_mutate` to apply, with a `StateError('the transfer became invalid
mid-write')` if the two disagreed. QA reproduced the disagreement with a
recurring bill posting between the two runs, and the result was not a rolled
back transfer, it was a thrown error that left the sheet dead.

The pattern for "a write that can refuse" was already in the file. `saveDebt`
(store.dart:1774) and `logDebtPayment` (store.dart:1789) both run the engine
exactly once, inside `_mutate`, and carry the answer out. And `postDueRecurring`
(store.dart:336 to :356) does something even more pointed: it runs the engine
outside the queue too, but only as a cheap probe whose result it never trusts,
and the comment at :346 says why in one line, "Compute the real post INSIDE the
queue so it folds onto the latest committed state, never overwriting a
concurrent write."

The shipped version is one run inside the queue returning the refusal on the
way out (store.dart:1741 to :1772), with the reason recorded at the site. It
also stopped burning a generated id on every refused attempt, and it quietly
corrected an id prefix: 0fdd121 minted transfer row ids with `_genId
('transactions')` while every other transaction id in the file uses
`_genId('txn')` (store.dart:353, :550, :581).

**Guard: NOT WRITTEN, and this is the gap in an otherwise well guarded round.**
Every other QA finding this round shipped with a test. This one shipped with a
better structure and nothing that fails if the structure is undone. Verified by
reading rather than assumed: `grep -rn "transferBetweenAccounts" test/ lib/`
returns exactly two hits, the definition and the one call in
flutter/lib/screens/accounts.dart:952. No test names the method.

**Guard, PROPOSED, strongest tier, both halves proven while writing this entry.
NEW Open 24.** The race is far easier to stage than it looks, because
`_serialized` defers through `Future.then`, so a write started first is
guaranteed to be still queued when the transfer's synchronous validation runs.
About 40 lines, no mocks, no timing tricks:

    final inFlight = store.addEntry({expense of 3200 from 'cash'});  // not awaited
    final moving = store.transferBetweenAccounts(
      fromId: 'cash', toId: 'gcash', amountText: '3200');
    await inFlight;
    // then assert that awaiting `moving` returns a refusal and does not throw

Run against the shipped code in a clean worktree, it passes and the transfer
returns a `TransferOutcome`. Run against the 0fdd121 shape restored into that
same worktree, it produces:

    THROWN: Bad state: the transfer became invalid mid-write

So the alarm is proven on both halves before it exists, and the only reason it
is not in the tree is that flutter/test belongs to another task right now. The
generalisation worth writing into it is the sentence from the fix's own
comment: running a money engine twice over data that can move between the runs
is a race by construction, however tight the window looks.

**Lesson 5. Session 9's Open 16 paid off a second time, and this round it
caught something new: an edit aimed at a block of code that appears twice.**

Every break and restore in this round asserted its markers, per the practice
session 9 opened after `git checkout` deleted a QA round's uncommitted fixes.
One assertion failed, and it failed usefully. The error display block being
targeted was, in 0fdd121, byte for byte identical in two places in the same
file: flutter/lib/screens/accounts.dart:783 (the account form sheet) and :1042
(the transfer sheet). Verified by extracting both blocks from that commit and
comparing them character by character, which reports identical:

                  if (_err != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      _err!,
                      style: TextStyle(color: Barako.warningStrong, fontSize: 13),
                    ),
                  ],

An unguarded scripted replace would have edited the FIRST one, silently, and
the change would have landed on the account form sheet while the transfer sheet
stayed as it was. The assert turned that into a visible failure. The two blocks
are no longer identical, because the transfer one now wraps the text in a
`Semantics(liveRegion: true)` so a screen reader announces the refusal
(accounts.dart:1083 to :1095), but they were identical at the moment it
mattered.

**Can Open 16 be closed? No, and the check was re-run rather than assumed.**
`grep -n "restore\|git checkout\|replace-back" CLAUDE.md
.claude/skills/*/SKILL.md` still returns only two unrelated hits, both about
backup and restore as a product feature. The practice has now worked three
times and lives nowhere except in this retrospective log, which nothing forces
anyone to read before breaking a file. **Open 16 stays open**, with one
sentence added to the text session 10 already drafted: when the target text
appears more than once, the assert must check the COUNT, not just that the
markers came back.

**Lesson 6. The standing CLAUDE.md fact check. Open 19's correction shipped and
is accurate. One small imprecision in the new wording is named here rather than
left for a sixth session to find.**

The mechanical half first. `git log 9400ebe..origin/main -- .github/workflows/
CLAUDE.md .claude/` returns exactly one commit, 0fdd121, and its only CLAUDE.md
change is the Open 19 correction. No workflow changed. Re-verified by reading
anyway:

- Every path CLAUDE.md names exists where it says: flutter/shorebird.yaml,
  flutter/test/update_stamp_test.dart, flutter/test/screens_shot.dart,
  flutter/lib/widgets/salapify_icon.dart, flutter/lib/main.dart,
  docs/delivery-log.md, mobile/app/(tabs)/more.js.
- All five skills exist in .claude/skills.
- mobile/lib/storage.js:9 still holds `salapify_data_v2`.
- The 120 character stamp cap is live at update_stamp_test.dart:20 and the live
  stamp is 88 characters.
- flutter-check.yml:20 triggers on `claude/**` with no paths filter;
  flutter-preview.yml triggers on `main` with paths `flutter/**` plus its own
  definition. Both still match rule 1 word for word.
- The three delivery commands ran as written and returned f2.70 patch 20.
- The render command in the "look at the screen" section ran as written this
  round and is what caught the original chip bug, evidenced by
  screens_shot.dart:990 and the 48,500.55 balance seeded at :960.

**Open 19: CLOSED.** CLAUDE.md:62 to :67 now reads:

    It renders every tab at BOTH brightnesses, and a growing set of other
    screens, sheets and dialogs in dark only. Look at the dark ones first; that
    is what the founder uses. (This sentence used to claim everything was
    rendered at both brightnesses. It was false the day it was written, and
    five retrospectives repeated it while checking other claims. When a rule
    describes what a tool does, read the tool, not the rule.)

Checked against flutter/test/screens_shot.dart rather than against the commit
message. The tab sweep loops seven screens over both brightnesses and writes
`shots/$name-$suffix.png` at :206. Every other named shot ends in `-dark.png`,
which the file confirms at 21 call sites.

**The imprecision, named rather than smoothed over.** There is one exception the
new sentence does not allow for: `shots/onboarding-welcome-$mode.png` at :875
renders at both brightnesses, inside the onboarding walk, before the walk
breaks out of the light pass at :878. So "a growing set of other screens,
sheets and dialogs in dark only" is slightly narrower than the truth. This is
the opposite direction from the failure that made Open 19 matter: the old
sentence claimed coverage that did not exist and therefore stopped people
looking, and this one understates coverage, which at worst causes someone to
check something that was already checked. It is still worth the honest note,
and the better fix remains the one session 10 proposed and this session
endorses: name no coverage at all and point at `ls flutter/test/shots/`, the
same way the paragraph three lines below already says the directory listing is
the count. That is not a new open item; it is Open 19's better half, and Open 19
is closed on the factual claim being true.

**Lesson 7. The qa-tester merge gate found every defect in this round. That is
three rounds in a row. It needs no new guard, it needs the record kept.**

On PR #225 it found the sample-account money trap. On PR #226 it found three
user-facing untruths and a permission race. On PR #227 it found three MUST
fixes and two SHOULDs: the Infinity crash, the still-overstating balance, a
thrown store failure that left the button disabled forever with no message, the
signed radix literal that moved money, and the validate-then-apply race. 893
tests were green at the time. Every one of those findings was invisible to all
893.

**Guard: EXISTING, medium tier, and it FIRED.** The CLAUDE.md merge rule
requiring a QA pass with every must-fix finding fixed and re-checked. Three
consecutive rounds in which the medium guard caught what the strong guards
missed is now the strongest argument in this log for why the medium tier is not
decoration. It is also the argument for why it must never be waived on a busy
day: the automated tier in this project has never once caught a defect in a
round it did not already know about.

### Is the four-delivery streak real?

Asked because the brief asked, and because "four clean deliveries in a row" is
exactly the kind of sentence that gets read as "the project is fine".

**The delivery half of the streak is real, and it is real for a reason that can
be pointed at.** f2.67 through f2.70 each have a row in docs/delivery-log.md,
each in mode `patch`, each against an unchanged `0.6.2+11`, and the founder
confirmed each on the phone. The gaps from merge to row were 11m50s last round
and 11m54s this round. The machinery that produces those rows is instrumented
now in ways it was not during the thirteen-stamp outage of session 1: the
publisher writes its own row, the `|| true` scrape guard is in place, the
watchdog runs with `--first-parent` and a 2700 second grace, the duplicate
stamp check fails after the publish rather than before it, and a nothing-shipped
run opens an issue. This is not luck. It is a mechanism that was built after it
failed, and it is working.

**What the streak does NOT mean, and this is the part worth saying plainly.**
It says nothing about whether what shipped was correct. In those same four
rounds, the pre-merge QA gate caught a money trap, three user-facing untruths, a
permission race, a crash that killed a screen, a balance that overstated itself,
and a coercion bug that would have moved the wrong amount of money. Every one of
them was found by a human-shaped review pass, and every one of them was invisible
to a fully green suite on a real runner. So the correct summary is: **delivery is
solved, correctness is not, and the streak measures the half that is solved.**

There is one thing being missed that is worth naming rather than filing. Three
rounds in a row, the automated suite has been green while a defect sat in the
branch, and the only reason nothing reached the phone is that the QA pass ran.
The QA pass is a medium tier guard by this log's own ranking, because it depends
on somebody running it at the right moment. The streak is currently resting on
the medium tier. That is a fine place to be while it is written down and a bad
place to be while it is forgotten.

### Open lessons carried forward

**Open 3, nothing compares the phone to main: STILL OPEN, by design.** The
founder confirmed f2.70 in person, which remains the only proof that counts.

**Open 6, the watchdog has never been observed running a scheduled pass: STILL
OPEN.** Run history is unreadable from this sandbox and `gh` is not installed
here. No spurious issue in evidence, and this round's 11m54s gap was well
inside the 2700 second grace at delivery-watchdog.yml:43.

**Open 7, the watchdog blind spot for merges that do not bump the stamp: STILL
OPEN.** Not exercised, the merge bumped the stamp.

**Open 8, split the publish step from the log scraping: STILL OPEN,**
re-verified by reading, the scrape is still inside the ship step with `|| true`
at flutter-preview.yml:127 and the comment at :112 to :126 explaining that its
absence once cost a whole delivery.

**Open 9, FAILED rows in docs/delivery-log.md: STILL OPEN.** No new archaeology
case this round.

**Open 10, nothing holds Pan's rendered size: STILL OPEN.**

**Open 11, nothing stops a sixth private kicker: STILL OPEN.**

**Open 13, the shot harness mounts screens through a private copy of the
shell's wiring: STILL OPEN.** The new transfer sheet shot builds its own
`MaterialApp` by hand at screens_shot.dart:978 to :984, which is a fifth
instance of the thing this item is about.

**Open 14, CLAUDE.md workflow item 4 versus the eas-update trigger: STILL OPEN,
untouched, re-verified.** eas-update.yml:18 still triggers only on
`claude/salapify-v2`, a branch retired in cf5c6a7.

**Open 15, the walk-keying and frame-asserting rule: ADVANCED AGAIN, still
open.** The new transfer sheet shot asserts its frame before photographing it
(`expect(find.text('Move money'), findsOneWidget)` at screens_shot.dart:987),
so the practice is now being applied to new shots as they are written, which is
the behaviour this item wanted. Measured coverage: 5 of 24 `expectLater` sites
assert what is in front of the camera, up from 4 of 23. The MEDIUM tier is
still not done: the screens_shot.dart header still records three hard-won
harness rules and asserting the frame is not one of them.

**Open 16, prove-it-fails says how to break the code and not how to restore it:
STILL OPEN,** and see Lesson 5, which adds the duplicate-target sentence to the
text that would close it.

**Open 17, nothing generalises the payday guard: STILL OPEN.** Not touched this
round; flutter/ was occupied.

**Open 18, the habit signal has four independent remembering events and three
prose counts of itself: STILL OPEN.** See Lesson 3, whose structural fix is the
same move applied to money formatting.

**Open 19, CLAUDE.md's brightness claim: CLOSED.** Corrected in 0fdd121 and
verified true against screens_shot.dart. The one imprecision in the new wording
is recorded in Lesson 6 and does not reopen it.

**Open 20, mobile/lib/notifications.js:100 has the same sample-row defect
Flutter fixed: STILL OPEN, re-verified.** `loggedToday` there still does not
exclude the sample ids.

**NEW Open 21: the balance label guards are example-shaped, and the property is
already proven.** One test asserting that moving exactly the displayed figure is
never refused as an overdraft, over a few thousand generated balances. Passes on
the shipped code, fails on both earlier versions with 9974 and 10241
overstatements respectively. Roughly 25 lines. Not written because flutter/test
is occupied.

**NEW Open 22: porting-money-logic says how to generate goldens and not how to
find out whether they are enough.** The exact paragraph to add is written out in
Lesson 2. Medium tier when done.

**NEW Open 23: the "*100 overflow" rule lives in prose and was walked into
anyway.** One shared centavo-splitting helper in flutter/lib/money/ with the
non-finite and saturation checks inside it, called by every formatter that needs
centavos. Medium tier when done, and it should be called medium.

**NEW Open 24: nothing guards the transfer race, and the guard is already proven
on both halves.** About 40 lines, no mocks, quoted in Lesson 4 along with the
exact failure line it produces against the old code. Strongest tier when
written. This is the one place this round where a QA finding shipped with a
better structure and no alarm.

### Guard status re-check

Read, not assumed. `git log 9400ebe..origin/main -- .github/workflows/
CLAUDE.md .claude/` returns only 0fdd121, whose sole change in that set is the
Open 19 correction, so every workflow line number the last three entries
recorded still stands. Verified by reading anyway:

- The duplicate stamp refusal: PRESENT, flutter-preview.yml:173 to :181.
  Correctly silent, the stamp was distinct.
- The `|| true` scrape guard: PRESENT, flutter-preview.yml:127, comment intact.
- The nothing-shipped failure issue: PRESENT, flutter-preview.yml:221 onward.
  Not fired, correctly.
- The release install shout: PRESENT. Correctly silent, the row reads `patch`.
- The publisher watching its own definition: PRESENT in the paths filter.
- The delivery watchdog's `--first-parent` and 2700 second grace: PRESENT,
  delivery-watchdog.yml:99 and :43, load-bearing comments intact.
- flutter-check.yml on `claude/**` with NO paths filter: PRESENT at :20.
- The stamp cap: PRESENT, update_stamp_test.dart:20.
- Session 6 and 7 guards (a11y_test.dart, nav_ambiguity_test.dart, the injected
  clock, header_action_test.dart, app_harness.dart): PRESENT.
- Session 8's guards: PRESENT and untouched.
- Session 9's guards: PRESENT. onboarding_test.dart:565 'the QA round' group
  intact.
- Session 10's guards: PRESENT. onboarding_test.dart:426 'the nudge QA round'
  group intact, the `asking` latch at onboarding.dart:89 with its gate at :144,
  and the sample exclusion at reminders.dart:112 still importing `sampleTxIds`.
- The whole suite: 898 pass, analyze clean, re-run independently on the
  delivered commit rather than inherited from a commit message. First time in
  three sessions.

**One guard was found routed around, and it is Lesson 3**: the
porting-money-logic rule about guarding a `*100` overflow before `round()` was
present, correct, nine days old, and not applied in the one new function it
described. Nothing was deleted or disabled. A prose rule that does not fire is
the failure mode this section exists to catch, and it is the reason Open 23 asks
for a helper rather than a better sentence.

### What it cost, and what it did not

Cost: a crash that would have permanently killed one screen for anyone with a
very large balance, a display that overstated balances about half the time in
two consecutive versions, a coercion hole that would have moved 16 pesos where
the live app refuses, a button that could stick disabled forever with no
message, and a race that turned a valid transfer into a dead sheet. All five
caught before the merge, none of them by a test. One golden fixture set found
incomplete twice in one batch. One skill rule found unread at the keystroke
where it applied. One QA fix shipped with no regression test.

Did not cost: any delivery failure, any wrong number on the phone, any manual
install, any lost user data, any founder-found bug. One delivery, one row, one
confirmation, 11 minutes 54 seconds.

### For the founder, in plain English

f2.70 is on your phone and you confirmed it: you can now move money between your
own accounts from the Accounts screen, and it correctly counts as neither income
nor spending. Just under twelve minutes from merge to arrival, which is the
normal rhythm. That is four clean deliveries in a row.

**About that streak, honestly.** The delivery machinery is genuinely fixed. Four
in a row is not luck, it is the alarms and logs we built after the outage in
July doing their job. But the streak measures whether things ARRIVE, not whether
what arrives is right. In those same four rounds the review pass caught nine
real defects before they reached you, every single one while the automated tests
were green. So: getting things to your phone is a solved problem, and getting
them CORRECT is still resting on a review step that a busy day could skip. I
would rather you knew that than felt reassured.

Three things are worth your lunch.

**One: I fixed a bug by moving it two decimal places instead of removing it.**
This is the interesting one.

The Accounts screen shows you little chips with each account's balance, so you
can see what is available before you type an amount. The first version rounded
those balances to whole pesos. So an account holding 48,500.55 showed as
"₱48,501", and if you then tried to move 48,501, the app refused, because you do
not have that. A screen must never print a number that the very next tap
contradicts.

I caught that myself, by looking at a rendered picture of the screen, and I
fixed it by showing the centavos. Then I wrote a test using that exact account,
48,500.55, and the test passed, and everything looked finished.

It was not. Rounding the centavos is still rounding, and rounding still rounds
UP. An account holding 0.999 pesos now displayed as "₱1", and moving 1 was
refused by a message that also said "you only have ₱1". The screen and the error
message agreed with each other, and both disagreed with the app.

The fix is to TRUNCATE, which means simply chop off what you cannot show rather
than round it. Chopping can never claim you have more than you do. And here is
the number that makes this worth writing down. I took all three versions and
tested them against twenty thousand different balances, asking each time whether
the app would refuse to move the amount it had just displayed:

- the original whole peso version: refused about 9,974 times out of 20,005
- my first "fix": refused about 10,241 times out of 20,005
- the version on your phone now: zero

My fix made the error a hundred times smaller and did not make it any rarer.
Roughly half of all balances still displayed wrong. And the test I wrote for it
passed the whole time, because the test asked about one account.

**The lesson, and it is about how I fix things, not about this bug.** A bug
usually arrives as an example. An example is a bad instruction for a fix,
because a fix has to be right for every case and the example is one case. When I
shape the fix around the example, the natural test to write is that same
example, so the test cannot possibly notice that I only shrank the problem. The
durable version of the guard is a rule with no example in it: "moving exactly
the amount the screen displays must never be refused". I have written that down,
checked that it passes on your version and fails on both broken ones, and left
it ready to add.

**Two: a rule I had already written down did not stop me breaking it.** There is
a checklist in this project for moving money calculations from the old app to
the new one. Nine days ago I added a line to it warning that multiplying a
balance by 100 can overflow into infinity if someone's backup carries an
enormous number, and that this crashes. Last week I then wrote a new function
that multiplies a balance by 100, without that guard. Someone with a huge
balance would have opened the transfer screen, hit an invisible crash, and had
no way to use that screen ever again.

The honest conclusion is not "read the checklist more carefully", because that
fix stops working the moment I am busy. The conclusion is that a warning written
in prose only helps if it is recalled at the exact keystroke where it applies,
which is asking a lot. The stronger version is to write ONE small helper that
does this arithmetic safely and have everything use it, so the safe way is the
easy way. I have logged that.

**Three: I built a problem that the file I was editing already knew how to
avoid.** The app saves changes one at a time, in a queue, so two things
happening at once cannot corrupt each other. My new "move money" function
checked whether the transfer was allowed BEFORE joining that queue, then did the
transfer once it got its turn. If anything else changed your balances in between,
for example an automatic recurring bill posting, the two answers disagreed and
the app threw an error that left the sheet frozen with no explanation.

Two other functions three lines away in the same file already did it the right
way, and one of them even had a comment explaining exactly why. I did not look.
It is fixed, and I have written the test that would catch it coming back, and
proved that test fails against the old code and passes against yours. It is not
in the app yet only because another job is editing those files right now.

**A note on what did NOT change.** Part of every one of these sessions is
re-reading the project's rulebook and checking its claims against the actual
code. Last week's session found a sentence in it that had been wrong since the
day it was written. That correction shipped and I have verified it is now true.
I found one small thing the new sentence understates, which I have written down,
and which errs in the safe direction: it claims slightly LESS coverage than we
have, so at worst it makes me check something twice.

I also, for the first time in three sessions, re-ran the entire test suite
myself against the exact version on your phone instead of trusting the number
in a commit message. 898 tests pass and the code analyser is clean. Worth
mentioning because "the tests passed" is a claim, and a claim I have not
personally verified is a belief.

**What it costs if these guards are removed.** Take out the balance property
rule and the app goes back to showing you money you cannot move, which is the
fastest way to make someone stop trusting an app about money. Take out the
crash test and one very large number in a backup permanently kills a screen with
no error message. Take out the review pass and you are relying entirely on tests
written by the same mind that wrote the bug, which has now failed to catch
anything in three consecutive rounds. And if the golden number checks are ever
trusted without someone deliberately trying to break them first, they will keep
passing while proving nothing, because they only ever check the cases I thought
to write down.

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
