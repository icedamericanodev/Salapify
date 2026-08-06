# Salapify working rules

Salapify is an offline first budget, debt, and utang tracker for Filipino
Gen Z, millennials, and working corporate adults. React Native with Expo
SDK 54 lives in mobile/. There is no backend; all data stays on the device
in AsyncStorage under the key salapify_data_v2.

## Flutter rebuild (founder decision, 2026-07-13)

The founder chose to rebuild Salapify from scratch in Flutter. The rebuild
lives in flutter/ and grows NEXT TO the live RN app; mobile/ stays shippable
and untouched for testers until the Flutter app reaches parity. Rules for the
Flutter track:
1. Delivery has TWO actions, and confusing them cost thirteen undelivered
   stamps once already. Pushes to a claude/** branch run the "Flutter check"
   action (.github/workflows/flutter-check.yml): analyze and test only, on a
   real runner, nothing published. Only pushes to main
   that touch flutter/ run the "Flutter preview APK" action
   (.github/workflows/flutter-preview.yml): flutter analyze (zero issues),
   flutter test, then Shorebird ships it. So a push touching flutter/ on the
   working branch publishes NOTHING; delivery happens at the merge to main,
   and is not real until that run is green. THERE IS NO PATH THAT MERGES
   flutter/ TO main WITHOUT SHIPPING: the publisher's trigger is flutter/**,
   so a test-only or docs-under-flutter merge ships exactly like a lib/ change,
   and Shorebird patches on build BYTES, so a functionally identical build is
   still a NEW patch under a new patch number. Every merge to main that touches
   flutter/ therefore needs a unique updateStamp, with no exception for
   test-only, docs-only, or "no app bytes changed" work; never plan a flutter/
   merge on the belief that it ships nothing. That belief shipped f3.10 patch 5
   unrecorded (docs/lunch-and-learn.md session 25). Two guards now hold this: the
   branch check reddens a flutter/-touching PR whose stamp still equals the
   delivered one (.github/scripts/check-stamp-unique.sh), and the publisher's own
   record step is the backstop that refuses to write a colliding row. One RELEASE
   exists per pubspec version (the base APK at the fixed flutter-preview release
   tag, installed once); every later push PATCHES that release over the air and
   the
   installed app updates itself on reopen. Bump the pubspec version ONLY for
   native-level changes; that forces a new base APK and one manual install,
   flag it loudly to the founder. Auth is the SHOREBIRD_TOKEN repo secret;
   the app id lives in flutter/shorebird.yaml (public, not a secret).
2. Bump the updateStamp constant in flutter/lib/main.dart on every push
   (f0.01, f0.02, ...), same verify-on-phone discipline as the RN stamp.
   Bump it FIRST, before writing the feature, not last after testing is
   done: a commit finished and pushed before the stamp is bumped ships with
   an already-stale stamp by construction, and the whole verification pass
   behind it (format, analyze, the full suite) then attaches to a tree that
   is not the one that actually ships, forcing a second full run to re-earn
   a claim the first one already made once. check-stamp-unique.sh already
   catches the collision itself at the PR border every time (see below); this
   is only about not wasting a test run on a tree that was never going to
   ship (session 32, docs/lunch-and-learn.md). KEEP IT SHORT, one high level
   line, 120 characters, enforced by test/update_stamp_test.dart. It became a
   forty line wall of text on the
   founder's phone because each build appended the previous build's notes
   instead of replacing them. The detail belongs in the PULL REQUEST. Not in
   docs/delivery-log.md, which has no notes column and is not meant to gain
   one: it records what shipped, not what changed. That row on the phone
   answers one question, which build am I running, and the founder asked for
   exactly that, high level only.
3. The committed preview keystore signs every build so updates install in
   place. It is NOT a production key; the Play upload key never enters the
   repo.
4. Port order: pure money logic first with the RN test vectors translated to
   Dart so every number matches to the centavo, then storage and backup
   (must import the existing Salapify backup JSON, schema v12 rules), then
   screens. Money math ports do not merge without matching test vectors.
5. The local Flutter SDK in a session lives at /opt/flutter (add
   /opt/flutter/bin to PATH); install 3.44.6 stable from
   storage.googleapis.com if missing.
6. A pre-authored course commit, one that arrives already fully written and
   pushed rather than authored inside a live turn, has repeatedly reached CI
   with the stamp left at the already-delivered value: rule 2's "bump it
   first" cannot reach a commit nobody in a live turn was there to read it
   during (Phase 11, Phase 13, and Phase 15 all did this, three confirmed
   times, session 33, docs/lunch-and-learn.md). check-stamp-unique.sh has
   caught every one before merge with zero phone impact, so this is wasted
   effort, not risk, but it is real waste every time. `.githooks/pre-push`
   runs the identical check locally, one push earlier, before the round
   trip to CI and back; run `git config core.hooksPath .githooks` once in a
   checkout to enable it there. It is NOT a server-side check, GitHub does
   not run one on a standard repository, so it only protects a checkout that
   has actually enabled it, and CI stays the real, unconditional backstop
   either way.

## Look at the screen before shipping a screen

Claude can render any Flutter screen to a PNG and actually look at it:

    cd flutter && flutter test test/screens_shot.dart --update-goldens

Do this for every UI change, before the merge. Two real bugs reached the
founder's phone because it was not done: a lesson rendering its reference
prose as a wall of text, and lessons losing their completed tick. Both were
obvious at a glance and invisible to 673 passing tests, because a test checks
what someone thought to check.

And SHOW the founder the picture, do not just look at it yourself. For every
feature or enhancement, render the screen(s) it touches and surface the PNG in
the chat (SendUserFile), so the founder can review the same image you did, now
and when the next change builds on it. Founder request, 2026-08-01: screenshots
of what shipped belong in the conversation, not only in a gitignored shots
folder nobody opens. Dark is what the founder uses, so show dark first.

It renders against a LIVED-IN phone, and that sentence is the whole point of
this paragraph. For most of the harness's life every per-tab shot used an EMPTY
store, so sixteen images at two brightnesses were all first-run welcome
screens and not one of them ever contained a peso figure. The rule "look at the
screen" was followed, faithfully, against a fixture that could not show the
defect: a crossed-out peso sign sat on Home through dozens of renders and
reached the founder's phone. If you change the fixture, do not shrink it; a
tidy shot of an empty screen is exactly what it replaced.

It renders every tab at BOTH brightnesses, and a growing set of other screens,
sheets and dialogs in dark only. Look at the dark ones first; that is what the
founder uses. (This sentence used to claim everything was rendered at both
brightnesses. It was false the day it was written, and five retrospectives
repeated it while checking other claims. When a rule describes what a tool
does, read the tool, not the rule.)
Deliberately no count or timing here: the last version of this sentence said
"fifteen shots in about eight seconds" and was stale within hours of being
written, because two more shots were added the same day. Numbers in prose rot.
The directory listing is the count.

Three things about the render, learned the hard way:
- Loading the real fonts must happen inside `tester.runAsync`. testWidgets
  uses a fake clock, so real file reads never complete inside it and the run
  hangs with no output. That gotcha cost two rounds of founder screenshots.
- The sandbox has no emoji font, so any remaining emoji (all of it user data
  now) draws as a box in the render but is fine on the phone. Never "fix" one
  of those. Salapify's own ICONS do render, because the harness loads the
  Material icon font from the SDK. It did not always, and the note that said
  "icons draw as boxes, ignore it" was true right up until icons were the
  thing being reviewed, at which point it excused a screenshot that proved
  nothing.
- The palette is set BEFORE the widget is built, the order main.dart uses.
  Every Barako.* read happens during build, so setting brightness afterwards
  renders the old palette while claiming to be the new one.

The same font rule reaches past the render harness. A widget test that MEASURES
layout, whether a label wraps, whether a control stacks, whether anything
overflows or clips, must load the real fonts first with `loadRealFonts` from
`test/screens_shot.dart`, or it judges a font the phone never draws. Flutter's
default test font is wider than Plus Jakarta Sans, the face the app ships, so a
layout decision can come out one way in the test and the other way on the phone.
The theme-mode selector test did exactly this: it demanded the picker stack at
320dp and 2.0x, which is true in the test font and false in Jakarta, where the
labels wrap in a row (`segmented_test.dart`, and the `ui_golden.dart` baseline
shows the row). A test that measures pixels without the shipped font passes for a
reason unrelated to what the founder sees.

The file lives under test/ but is NOT named `*_test.dart`, and both halves of
that are deliberate. Under test/, because the analyzer only permits test-only
APIs there and parking it in tool/ turned `flutter analyze` red. Without the
`_test` suffix, because `flutter test` only ever collects files matching
`*_test.dart`, so it can never join a CI run and fail there on fonts. A tag
would not have been enough: tags only filter when you pass `--tags`.

Looking is still required, and it is no longer the only check. The render is
opt-in by nature: it produces pictures, and a picture nobody opens proves
nothing. So the parts of "readable" a machine can judge were taken off the
human's plate. `test/palette_contrast_test.dart` measures every colour pair in
all sixteen palettes against WCAG AA, and `test/screen_readability_test.dart`
pumps the lived-in fixture through the main screens and fails on an overflow, a
blank screen, a sentence past the edge of the phone, text cut off by an
ellipsis, or a stored date shown raw, scrolling the whole screen and repeating
it at 1.5x system font. Both are ordinary `*_test.dart` files, so they run on
the branch check with everything else.

The sweep's screen list is a LIST, not every screen, and that is a known gap
rather than a feature. It said "every screen" here for a day while covering ten
of the fifty files in lib/screens, and Reports and Debts were missing while both
carried a fix that had just shipped. The model for closing it properly is
`test/palette_contrast_test.dart`, which iterates the theme registry and then
asserts it saw all of it, so a new theme reddens the build; a derived set is a
rule and a typed set is a promise.
What is left for the eye is what only an eye can do: whether the screen reads
well, not whether it fits.

CI does run it, deliberately and separately, with `--update-goldens` so it only
writes. That proves the harness still renders. It was abandoned once already
after a runtime failure nobody wrote down.

There is also a small COMMITTED pixel baseline, and it is a reference, not the
gate. `test/golden/ui_golden.dart` renders the screens one change set touched
into fixed PNGs under `test/golden/baseline/`, deterministic on purpose (fixed
size and DPR, dark theme, en locale, real fonts, animations off, an injected
clock where a date shows). It carries NO `_test` suffix, so `flutter test` never
collects it, and the CI step that compares it is non-blocking: a pixel diff
across environments is information, not a red build. The real per-push regression
gate stays the DETERMINISTIC layout-metric tests (`screen_readability_test.dart`,
`palette_contrast_test.dart`, `segmented_test.dart` and the like), which measure
layout rather than pixels and so cannot flake cross-platform. That split is the
standing answer to "add a stable pixel baseline": commit one for the screens that
can be made deterministic, keep it opt-in and non-blocking, and never let a
cross-environment pixel diff gate a push. Do not re-litigate it into a blocking
pixel check; that is exactly the flake the founder ruled out.

## Test the app the way a person uses it, not one screen at a time

`flutter/test/journeys_test.dart` taps and types through several features in one
sitting and then checks that every screen still agrees about the money. Most of
the other test files drive ONE screen with a store built for it, which is good
and is not this (no count here on purpose: the last version of this sentence
said sixty and the real figure was seventy-nine, two paragraphs from the rule
that says numbers in prose rot): a defect that is correct where it was written and wrong where it
is read has nowhere to be caught by those. Three false alarms in one afternoon
came from two screens seeming to disagree, and none could be settled, because no
test had ever put two screens in front of the same store.

Journeys PREFER invariants and every literal in them has to justify itself. The
earlier version of this paragraph said "never expected values" and the file
already contained four literals when it was written, which is the sort of claim
that makes the rest of a document harder to trust. An invariant is a sentence
that cannot be false: moving money between your own accounts cannot change your
net worth, paying a debt cannot either (an asset falls and a liability falls by
the same amount), spending reduces it by exactly what was spent, lending and
being repaid returns to the start.

Every invariant needs a did-anything-happen check beside it, because an invariant
also holds when the action silently did nothing: a transfer that transfers
nothing preserves net worth perfectly. Without that second assertion the test
passes hardest when the feature is most broken.

That check must be DIRECTIONAL, and this sentence is here because the rule above
was followed and still produced two hollow tests on its first day. The transfer
journey's companion assertion was `bank + cash == 23000`, which is exactly what
a transfer preserves, so it passed with the transfer deleted. A conservation
invariant ("changes nothing", "returns to the start") is unfalsifiable by
inaction by construction, so its companion can never be another conservation
statement: name the per-account movement, or assert the stored blob changed.

The journey-tester agent (.claude/agents/journey-tester.md) owns this file and
the discipline around it. Use it when the founder cannot test by hand, which is
most of the time.

## Three Bash commands are refused by a hook, and why

`.claude/settings.json` runs `.claude/hooks/guard-destructive-edits.sh` before
every Bash call. It blocks exactly three shapes, each of which silently
destroyed work or truth here:

1. A **python here-document that writes to a file**. The shape is
   `python3 - <<'PY' ... assert ... open(p,'w').write(s) ... PY`. When the assert
   throws, the script exits BEFORE the write, so the edit never lands while
   everything looks like it worked, and the next `flutter analyze` reports errors
   from code that was never changed. Ten occurrences. Use Edit or Write, which
   fail loudly when they do not apply.
2. **`git checkout <path>` or `git restore <path>`.** Discards uncommitted work
   with no confirmation and no undo. Used once to reverse a deliberate one-line
   break and it took a whole delivery's edits with it. To undo one change, put
   the original text back with Edit.
3. **`flutter test` piped into another command without pipefail.** A pipeline's
   exit code is the LAST command's, so `flutter test | tail -2` reports 0 from
   tail while the suite fails. That exact shape reported "suite green" over two
   red tests once (session 28). Prefix `set -o pipefail;` and the pipeline
   reports the test run's real exit code.

Ordinary work is untouched, and that is deliberate: a guard that fires on normal
commands gets switched off and is then absent for the real thing. `python3 -c`
one-liners pass, any python that only reads passes, and `git checkout <branch>`,
`git checkout -b`, and `git checkout origin/main` all pass. The discriminator for
rule 2 is whether the argument EXISTS on disk, which is exactly what makes the
command destructive; a ref is not a path. Rule 3 matches only an INVOCATION
(command position on the first line), so a commit message or document that
merely mentions the banned shape passes.

Installed at the founder's explicit request. Worth knowing how it got here: two
consecutive retrospectives concluded "nothing in this repository can observe how
a file gets edited, this is a rule and cannot be a machine", and neither checked
whether the mechanism existed. It did the whole time. When a rule says something
is impossible, read the tool, not the rule.

## Prove a new test can fail before trusting it

When adding a test to guard a lesson, break the code once, watch it fail, and
paste the failure line into the commit message.

This is not ceremony. A test written from the same wrong mental model as the
code passes for the wrong reason and reads as proof. It has already happened
here: a test once asserted the WRONG behaviour on purpose, with a confident
reason string, and 673 green tests then defended a real bug for a whole round.

Three guards were proven this way in one day, each in about three minutes: the
stamp cap rejected a deliberate wall, the icon test caught a renamed icon name
reaching the silent fallback, and the diagnostics privacy test caught a
plausible leak by name ("The report leaked an account name"). So "no time" is
not an objection.

The same applies to ALARMS, and harder. Prove both halves: that it fires when
it should, and that it stays SILENT when it should. The delivery watchdog was
broken in exactly the second half, and only the second half, on its first
version. An alarm that cries wolf gets its battery taken out, and then it is
not there during the fire.

When the deliberate break does NOT produce a failure, that is the most
informative result this procedure can give, and it means the test is wrong,
not that the code is unusually good. Do not shrug and move on, and do not
"fix" it by breaking something else until something goes red. Work out which
branch the test actually reaches, then rewrite the test into the only shape
that reaches the branch the guard lives on. Session 34 hit this: a guard
against re-offering a just-finished lesson passed with the guard deleted,
because the forward scan found a later unfinished lesson before the fallback
branch containing the guard could ever run. Coverage cannot save you here,
and a future session should not build that machine: the guard's LINE was
covered by a sibling test the whole time, what was never exercised was the
condition evaluating false, and `flutter test --coverage` counts line hits,
not condition outcomes.

Restore the deliberate break only AFTER the test run reports, never while it is
still going. The break-then-prove step is usually run by reverting a fix and
launching the test in the background, and on f2.97 the fix was very nearly put
back before the run had finished COMPILING it. A restore that beats the compile
makes the run compile the FIXED code and print a false pass, which is worse than
no proof because it reads exactly like proof. Wait for the completion
notification, read the failure line, then restore. Nothing in the repo can
observe the ordering of a background job against a manual edit, so this one is a
rule and cannot be a machine; that is stated here rather than pretended away.

## Money Courses official-source URLs need a real search, not just a cite

A syntactically well-formed government URL a lesson cites can still be
fabricated, and nothing in flutter test can tell the difference: every content
test that touches a source URL asserts against the lesson file's own declared
constant, never against the live internet, which is tautological against a
wrong value the file declares with full confidence. WebFetch to gov.ph domains
returns a uniform 403 in this environment, so WebSearch cross-verification is
the only channel that can check a URL is real at all.

Any Money Courses lesson introducing or changing an official-source
canonicalUrl on a government domain requires the reviewing agent to
independently WebSearch each URL, not merely cite or WebFetch it, before
governance.reviewStatus is set to verified. The qa-log row must name what was
searched and what confirmed or contradicted it. This caught a real defect
once already: Phase 11's first draft cited a Virtual Pag-IBIG portal URL that
never appeared in any independent search result, a fabricated subdomain a
"zero blockers found" review had waved through, corrected only when the
search was actually run (session 32, docs/lunch-and-learn.md).

"Each URL" means every URL a lesson currently cites, not only the one being
introduced or changed. When a course's source list is touched again for any
reason, a fix, a follow-up, a later phase reusing an existing citation, the
re-search covers every source the course currently keeps, not just the one
prompting the touch. A review can find and fix several real problems in one
pass and still leave one instance of the exact same problem class unfound in
that same pass, because "each URL" was read as the URL under discussion
rather than the full kept list. Phase 15's own review is the proof: it
correctly found and dropped two unconfirmable URLs, and a DILG eBOSS circular
PDF still survived that same pass among the eight it kept, only caught when
a later, unrelated fix independently re-searched all eight rather than
trusting the ones the prior pass had already cleared (session 33,
docs/lunch-and-learn.md). Nothing in flutter test can tell a correctly
re-searched URL from one a reviewer assumed was already covered; the only
defense is actually re-running the search on every kept source, every time.

## Icons: ours are orange, the user's are emoji

Salapify's own icons are Material glyphs in the theme accent, resolved through
flutter/lib/widgets/salapify_icon.dart. Content declares the MEANING ('shield',
'mountain') and that one file decides how it is drawn, so restyling every icon
is one edit. Emoji cannot do this: they are OS-drawn multicolour stickers, the
palette cannot reach them, and they change shape between phones.

The line that decides whether something belongs there: it covers icons
SALAPIFY authors (course tracks, lessons, empty states, moments). It must NEVER
be extended to emoji the USER picked. Category icons, treat icons, account
icons, and goal icons are user data, they live in the backup file, and
replacing them would overwrite a choice that was never ours. Those stay emoji.

A new icon needs a name in the map, or the content test 'every icon name
actually resolves to a glyph' fails. The resolver falls back to a neutral
marker so a typo can never take a screen down, and that test is what stops the
fallback being reached silently.

## Writing style

Never use em dashes or en dashes anywhere: code comments, commit messages,
PR text, UI copy, ads. Use commas or periods instead. Plain English
explanations for the founder, who is a beginner. Small tested steps.

Marketing ads are ALWAYS in English (the audience is global). Filipino
words appear only as product identity flavor (utang, sweldo).

App UI copy is English first (founder decision, 2026-07-23, for the global
launch): every user-facing sentence must read in plain English on its own.
Filipino identity nouns (utang, sweldo, paluwagan, hatian, ipon) may stay as
titles and kickers only where an English gloss sits right beside them; inside
sentences use the English word (payday, salary, contribution, savings). Pan
keeps UNDERSTANDING Tagalog input (matchers and normalization stay), but its
replies and example chips are English. Never
promise "free forever" in marketing; the truthful lines are core features
free forever, free during early access, and early users keep Pro free.

## Enhance what exists, never regress it (founder direction, 2026-08-01)

Existing features are not frozen. Touch them freely, but the goal of every
touch is to enhance, improve, or innovate on what is already there. Prior
work is never discarded wholesale or quietly degraded: a change to a shipped
surface keeps what users already have working (the tests that guard the old
behavior stay green, and nothing a user already has moves behind a wall) and
builds on top of it. The Sweldo Timeline is the pattern to copy: it grew
INSIDE the existing Cash flow screen, the old free month view stayed the
default, and every prior figure kept its meaning. When a vision-spec idea
touches a shipped feature, read docs/Product_Vision_Spec.md's inventory
first so the enhancement lands on what exists instead of beside it.

## Development workflow

1. Develop on the session's assigned claude/** working branch and open PRs
   to main. (The old fixed branch claude/salapify-v2 is retired; each session
   gets its own branch now, and the Flutter check runs on all of them.) If
   git fetch origin <your branch> ever fails with "couldn't find remote
   ref", that branch was already merged (by an earlier PR from this same
   session, or a parallel one) and GitHub deleted it on merge, per its own
   post-merge cleanup. Do not treat this as an error to work around: restart
   it with git checkout -B <your branch> origin/main, which is always safe
   because origin/main is never older than the branch's last delivered
   commit, and any uncommitted working-tree changes apply cleanly on top
   (session 32, docs/lunch-and-learn.md).
2. Compile check every changed file with the Expo Babel preset before
   committing (run node with babel.transformFileSync from mobile/).
3. Commit per milestone with a clear message explaining the why. Push in
   batches (once per finished feature batch, not per commit): every push
   to mobile/ costs a publish job in a slow shared queue.
4. JS only changes ship over the air: every push to the branch that
   touches mobile/ triggers the "Publish OTA update" GitHub Action
   (.github/workflows/eas-update.yml), which runs eas update on the
   preview channel using the EXPO_TOKEN repo secret. This runs on
   GitHub's free runners and does NOT use the EAS CI/CD minute allowance
   (the old .eas workflow did, and ran it out). Bump the Update stamp row
   in mobile/app/(tabs)/more.js on every push so the founder can verify on
   the phone which bundle arrived.
5. Native changes (new native modules, app.json plugin or version changes)
   need a full APK rebuild on EAS and a version bump to isolate runtimes.
   Flag these loudly, they are not over the air.

## Skills (.claude/skills)

Reusable workflow skills live in .claude/skills and load on demand when a task
matches. Three are adapted from obra/superpowers (MIT) and tuned to Salapify:
brainstorming (design and get agreement before building), systematic-debugging
(root cause before any fix, stop and rethink after three failed fixes), and
writing-skills (how to capture a workflow as a new skill). Two are ours:
porting-money-logic, the golden-vector contract for moving money math from
mobile/ to flutter/ so every number matches to the centavo; and
flutter-ui-polish, Flutter and Barako concrete design-engineering principles
adapted from jakubkrehel/skills (MIT) for making a screen feel premium. These
skills assist; they never override this file. Where any external guidance conflicts
with these rules (merge method, never squash, golden lock, no em or en dashes),
this file wins.

## Merge rules (set by the founder on 2026-07-03)

Claude reviews and merges every PR itself, for all builds, when ALL of
these hold:
- A QA pass ran on the changed code (the qa-tester agent or equivalent)
  and every must fix finding was fixed and re-checked. Record it as a row in
  docs/qa-log.md; flutter/test/qa_record_test.dart fails on the runner when
  the current stamp has no row. This rule sat unenforced for weeks and then
  was simply skipped on f2.71, which put a monthly cap that could not see the
  app's own Log entries on the founder's phone for two hours. SKIPPED is an
  accepted verdict in that file. A missing row is not.
- The over the air publish check on the PR head commit is green (the
  "Publish OTA update" GitHub Action). If that mechanism is ever blocked
  by billing or infrastructure rather than by the code, that condition is
  waived and the founder is told; a QA pass plus compile and harness green
  is enough to merge in that case. This waiver NEVER applies to the Flutter
  checks below. It was written for a mechanism that is broken, and applying
  it to one that was working is precisely how twelve real failures got
  ignored. A check that is reporting failures is not blocked, it is talking.
- The merge uses "Create a merge commit". Never squash, squash rewrites
  history and causes merge conflicts on the next PR every single time.

For Flutter work the equivalent check is the "Flutter check" action on the
branch (analyze and test on a real runner). Never treat a green local
`flutter test` as a substitute: the dev sandbox has no outbound network, so
a test can pass locally and fail on a runner. That exact gap once hid a
failing preview build for thirteen stamps, and none of that work reached the
phone.

### The delivery check, in three commands

After every merge to main, confirm delivery by READING, never by assuming.
The publisher writes what it actually shipped into docs/delivery-log.md, so
this needs no GitHub API, no Actions tab, and no guessing:

    git fetch origin main
    git log origin/main --oneline -3
    git show origin/main:docs/delivery-log.md | tail -5

The last row names the stamp and the patch number that genuinely reached the
phone. Rules for reading it:
- A merge with NO new row shipped nothing, whatever the pull request said.
  Either the build is still running or it failed; check before speaking.
- The patch number in that row is the same number the app prints on its
  Update stamp row, so the file and the phone can be compared directly. That
  comparison is the only real proof, and it is the one thing the founder can
  do that Claude cannot.
- Mode `release` (not `patch`) means a NEW base APK: the founder must install
  it by hand or they receive nothing forever while every build stays green.
  Say so loudly, immediately, and never bury it.

### Finished means delivered (founder rule, 2026-07-25)

A batch is FINISHED when it is merged and a delivery row exists for it. Not
when the code is written, not when tests pass, not when the pull request is
open. Applies to every future update, without exception.

Concretely, before answering any new question or starting any new work:
- If a pull request is open with finished work in it, merge it or say out
  loud, to the founder, why it is waiting. Never silently move on.
- After merging, watch the build through and report the patch number from
  docs/delivery-log.md.
- The founder should never have to tap "check for update" to discover whether
  something was finished. If they are asking, the reporting already failed.

This rule exists because three separate delivery failures had three different
causes, a broken test, a missing pre-merge check, and simply never merging a
finished pull request, and only the first two had guards. This one is the
guard for the third.

Never tell the founder a stamp is live until a row for it exists. "Merged"
is not "delivered"; the whole delivery outage was that one word.

Stronger, after session 15: never SAY a version number to the founder at all
until its delivery row exists. Not "f2.74 is ready", not "waiting on the check
for f2.74". Every word of that was true and the founder still went to their
phone and found nothing, because the number is the thing they look up. Handing
them the key before the door exists is what sends them looking. Until a row
exists the wording is "nothing new on your phone yet". This one is a rule and
not a machine, because what went wrong was a sentence in a chat and no test
can read a sentence. If it happens again, the escalation is already decided:
stop giving progress updates between merges entirely, and speak exactly twice
per batch, at the start and when the row lands.

The same caution runs the OTHER way, learned in session 25: do not assert that
nothing shipped either, until the log settles it. "This is banked, nothing
reaches your phone" was said of a test-only merge and was false, because a
flutter/ merge always ships (see rule 1 above). A false "nothing shipped" costs
a beginner founder exactly as much as a false "it shipped". Until the
delivery-log row exists, the only safe statement about the phone is the plan
("this is a test-only change, banked for the next feature"), never the outcome.

After the founder confirms a patch on the phone, run the lunch and learn: a
short blameless retrospective, facilitated by the lunch-and-learn agent,
written up in docs/lunch-and-learn.md. Ground truth is always the stamp on the
phone, never what the repo says should have happened. A clean patch is a valid
result; the session exists to catch the gap between what we believed shipped
and what actually did, and to turn each lesson into a guard that works while
nobody is watching.

For significant changes, Claude still merges, but must clearly tell the
founder what shipped and why it is significant, right after merging.
Significant means any of: the stored data shape or migration logic, money
math (balances, debt payoff, forecasts, analytics), backup and restore,
security or app lock, notifications scheduling, monetization or pricing,
deleting or replacing user data, or anything requiring an APK rebuild.
Anything that could permanently lose user data still goes to the founder
BEFORE merging, that one is never delegated.

After any merge, confirm the branch still merges cleanly into main; if the
founder squash merged by accident, merge origin/main back into the branch
keeping the branch side on conflicts (the branch is always strictly newer).
