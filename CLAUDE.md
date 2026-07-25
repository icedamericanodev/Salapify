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
   real runner, nothing published. Only pushes to main or claude/salapify-v2
   that touch flutter/ run the "Flutter preview APK" action
   (.github/workflows/flutter-preview.yml): flutter analyze (zero issues),
   flutter test, then Shorebird ships it. So a push touching flutter/ on the
   working branch publishes NOTHING; delivery happens at the merge to main,
   and is not real until that run is green. One RELEASE exists per pubspec
   version (the base APK at the fixed flutter-preview release tag, installed
   once); every later push PATCHES that release over the air and the
   installed app updates itself on reopen. Bump the pubspec version ONLY for
   native-level changes; that forces a new base APK and one manual install,
   flag it loudly to the founder. Auth is the SHOREBIRD_TOKEN repo secret;
   the app id lives in flutter/shorebird.yaml (public, not a secret).
2. Bump the updateStamp constant in flutter/lib/main.dart on every push
   (f0.01, f0.02, ...), same verify-on-phone discipline as the RN stamp.
   KEEP IT SHORT, one high level line, 120 characters, enforced by
   test/update_stamp_test.dart. It became a forty line wall of text on the
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

## Look at the screen before shipping a screen

Claude can render any Flutter screen to a PNG and actually look at it:

    cd flutter && flutter test test/screens_shot.dart --update-goldens

Do this for every UI change, before the merge. Two real bugs reached the
founder's phone because it was not done: a lesson rendering its reference
prose as a wall of text, and lessons losing their completed tick. Both were
obvious at a glance and invisible to 673 passing tests, because a test checks
what someone thought to check.

It renders every tab, a lesson, and the diagnostics dialog, at BOTH
brightnesses. Look at the dark ones first; that is what the founder uses.
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

The file lives under test/ but is NOT named `*_test.dart`, and both halves of
that are deliberate. Under test/, because the analyzer only permits test-only
APIs there and parking it in tool/ turned `flutter analyze` red. Without the
`_test` suffix, because `flutter test` only ever collects files matching
`*_test.dart`, so it can never join a CI run and fail there on fonts. A tag
would not have been enough: tags only filter when you pass `--tags`.

CI does run it, deliberately and separately, with `--update-goldens` so it only
writes. That proves the harness still renders. It was abandoned once already
after a runtime failure nobody wrote down.

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

## Development workflow

1. Develop on the branch claude/salapify-v2 and open PRs to main.
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
  and every must fix finding was fixed and re-checked.
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
