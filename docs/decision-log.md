# Decision log

This file implements section 46 of docs/Salapify_Master_Constitution.md: a
lightweight record of autonomous decisions that materially affect the
implementation. Each entry records the decision, the reason, the alternatives
considered, the evidence, and the impact.

It is deliberately lightweight. The constitution says not to create excessive
documentation for trivial decisions, so only decisions a later session would
otherwise have to re-derive belong here.

Section 46 scopes this file to AUTONOMOUS decisions, so a founder-gated one is
not an entry here. Those go to the founder before they are made, and when they
are significant enough to need a written record afterwards, the established
home is docs/adr, alongside 0001-durable-encrypted-store.md and
0002-privacy-release-evidence.md.

Newest entry first.

---

## 2026-08-16: Guard the lockfile after the sandbox default moved to Flutter 3.47.0

### Decision

The founder directed that `flutter` on PATH be 3.47.0, so /opt/flutter is now
3.47.0 while every repository pin stays at 3.44.6. That instruction is theirs
and is not the decision being logged here. What is logged is what was decided
autonomously in response to it:

1. Keep the pinned SDK on the box at /opt/flutter-3.44.6, so a change can still
   be verified against what the runner will actually build before it is pushed.
2. Add a CI step to flutter-check.yml that fails when resolving dependencies at
   the pin changes pubspec.lock or analysis_options.yaml.
3. Leave flutter/README.md line 33 stale rather than correct it, for now.

### Reason

A default newer than the pin creates one specific, likely failure, and it is
not the one people expect. The worry is usually "a test passes locally and
fails on the runner". The real hazard is quieter: `flutter pub get` REWRITES
pubspec.lock to the resolution of whichever SDK ran it, and from 3.47 it also
writes an analyzer.exclude block into analysis_options.yaml. Both files are
SDK-specific. Commit them by accident and the runner is handed a resolution it
cannot reproduce, while analyze and test both still pass, because neither cares
who resolved the lockfile.

This is not a projection. The first `flutter pub get` run after the default
moved dirtied both files immediately.

That is exactly the shape that belongs in a machine rather than a rule, so it
became a CI step instead of a paragraph telling future sessions to be careful.

### Alternatives considered

1. Refuse the default change and stay on the pin. Rejected: it is the founder's
   environment and their call, and the hazard is guardable.
2. Take the default change and rely on sessions remembering to check
   `git status` after a pub get. Rejected: that is precisely the kind of rule
   that holds until the one time it matters.
3. Fix flutter/README.md line 33 so it stops naming a version. Deferred, not
   rejected. The file is under flutter/, the preview publisher triggers on
   flutter/** at the merge to main, and Shorebird patches on build bytes, so a
   one word doc fix spends a real patch and an update stamp. It is worth doing
   as a passenger on the next flutter/ batch that is shipping anyway, where it
   costs nothing, and worth wording as a rule rather than a number so it stops
   going stale every time the sandbox changes.

### Evidence

Both halves of the new guard were proven before it was trusted, which is the
part that matters for an alarm.

- It FIRES on a real fault. Run against the tree 3.47.0's pub get produced, it
  exits 1 and names both paths: pubspec.lock with matcher, meta, test_api and
  vector_math bumped, and analysis_options.yaml with the added exclude block.
- It stays SILENT when it should. Run against the same tree resolved at the
  pinned 3.44.6, `git diff --exit-code` reports no change and the step passes.
  An alarm that cries wolf gets its battery taken out, so this half was tested
  deliberately rather than assumed.

### Impact

- /opt/flutter is 3.47.0, Dart 3.13.0. /opt/flutter-3.44.6 holds the pin.
- No repository pin moved. Delivery is untouched and Shorebird still tops out
  at Flutter 3.44.9, rechecked the same day against RELEASE_NOTES.md.
- flutter/README.md line 33 is stale again while it names a version. Tracked in
  alternative 3 above rather than left as a surprise.
- Nothing under flutter/ changed, so the preview publisher does not trigger and
  no update stamp applies.

---

## 2026-08-16: Stay on the Flutter 3.44.6 toolchain pin after evaluating 3.47.0

### Decision

Install Flutter 3.47.0 stable locally, verify Salapify against it, then put
/opt/flutter back to the pinned 3.44.6. Leave every version pin in the
repository at 3.44.6. No workflow file is changed and no file under flutter/ is
touched, so nothing ships.

Restoring the sandbox afterwards is part of the decision, not tidying up. A
session left on an SDK the runner does not use turns every later green local
run into a weaker signal than it looks, which is the exact class of gap that
once hid a failing preview build for thirteen stamps.

To repeat this evaluation when Shorebird catches up: download the candidate
from storage.googleapis.com over /opt/flutter, run `flutter pub get`,
`flutter analyze` and `flutter test`, restore any file `pub get` rewrote, then
put 3.44.6 back. It costs about twenty minutes, nearly all of it download.

### Reason

Shorebird, not Flutter, sets this number. Salapify's over the air delivery runs
`shorebird release android --flutter-version 3.44.6`, and Shorebird only builds
against Flutter versions it has published support for. Raising the pin to a
version Shorebird cannot build would not have shipped a newer app, it would
have broken delivery outright.

### Alternatives considered

1. Raise every pin to 3.47.0 now. Rejected: Shorebird cannot build it yet, so
   the preview publisher would fail on the next merge to main.
2. Raise only the branch check (flutter-check.yml) and leave the publisher on
   3.44.6. Rejected: that makes CI test the app on a toolchain different from
   the one that actually ships, which is the exact gap the branch check exists
   to close.
3. Leave the pins alone and record why. Chosen.

### Evidence

Checked 2026-08-16.

- Flutter 3.47.0 stable, Dart 3.13.0, released 2026-08-12, installed at
  /opt/flutter. Against it, `flutter analyze` reported no issues and the full
  suite passed, 2940 tests. So the app code is not what holds the pin back.
- The same app on the pinned 3.44.6, Dart 3.12.2, also analyzes clean and
  passes the same 2940 tests, and `flutter pub get` on it leaves the committed
  pubspec.lock byte for byte unchanged. Both halves matter. The identical
  result on both SDKs is what makes "3.47 is fine, Shorebird is the blocker" a
  measurement rather than a hope, and the untouched lockfile confirms the
  committed one is the 3.44.6 resolution.
  Note that 3.47.0's `flutter pub get` does NOT leave the tree clean: it bumps
  matcher, meta, test_api and vector_math in pubspec.lock, all four SDK-pinned
  and therefore belonging to Dart 3.13, and it writes an analyzer.exclude block
  into flutter/analysis_options.yaml. Neither was committed. Anyone repeating
  this evaluation must check `git status` afterwards and restore both files,
  or the newer SDK's resolution silently lands on a branch CI builds at 3.44.6.
- Shorebird's newest release at the time, 1.6.117 of 2026-08-14, still declares
  "Flutter 3.44.9 / Dart 3.12.2 support" in RELEASE_NOTES.md of
  shorebirdtech/shorebird.
- The shorebirdtech/flutter fork carried a 3.47.0-0.1.pre beta tag and no
  3.47.0 stable tag.

### Impact

- No delivery impact. Nothing under flutter/ changed, so the preview publisher
  does not trigger and no update stamp applies.
- The number 3.44.6 is written in six places and all of them still agree:
  flutter-check.yml, flutter-preview.yml twice (the setup step and the
  `shorebird release` argument), flutter-prod-aab.yml, pages.yml, and
  CLAUDE.md rule 5. Moving the pin means moving all six.
- flutter/README.md line 33 also carries it, and that line stayed TRUE at the
  time of this entry, because /opt/flutter was put back to 3.44.6 once the
  evaluation was finished. (Superseded the same day: the founder moved the
  sandbox default to 3.47.0, so that line is stale again. See the entry above.
  The reasoning below still holds and is why it was not simply edited.)
  That ordering is the point, not an afterthought. Editing the README would touch
  flutter/, the preview publisher triggers on flutter/** at the merge to main,
  so a one word README fix would have shipped a real Shorebird patch and needed
  its own update stamp. Restoring the sandbox to the pin cost nothing, shipped
  nothing, and left no sentence in the repository disagreeing with the machine.
  Evaluate on the candidate SDK, then restore the pin, and the gap never opens.

### Before this pin moves

Two conditions, both required.

1. RELEASE_NOTES.md in shorebirdtech/shorebird lists the target Flutter version
   as supported. A green local run is not evidence of this.
2. The founder approves it. A Shorebird patch only applies to a release built
   on the same Flutter revision, so changing `--flutter-version` forces a new
   base APK the founder installs by hand, and until they install it they
   receive nothing while every later build still reports green.

   The authority for that gate is the "Merge or release" stop condition in
   CLAUDE.md's autonomous execution rules. The constitution has no release
   category of its own: section 42 lists product direction, financial
   behavior, security and privacy, architecture, external cost, irreversible
   or high-impact changes, and brand or design, and section 43's Tier 2
   examples do not name releases either. A forced base APK reaches section 42
   only through "irreversible or high-impact changes". Cite it that way, not
   as a section 42 release rule, which is not a thing the document contains.
