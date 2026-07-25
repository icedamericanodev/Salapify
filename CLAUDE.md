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
