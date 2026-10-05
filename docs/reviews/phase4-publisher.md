# Phase 4, first delivery: signing, stamp, publisher

2026-10-05. Founder approved Phase 4 starting with the signing key.

Phase 4 was called "Cutover" until this morning and described installing
Salapify 3 over Salapify 2 and finding the old data in place. The founder
stopped that: "we are building the Salapify from scratch right using the google
ai studio prototype why you mix it up to Salapify 2". The roadmap phase is
rewritten and the reasoning is in D29's amendment. THERE IS NO CUTOVER.
Salapify 3 is a new app that inherits nothing.

## SCOPE

Three steps, in the order a failure in each would cost most.

1. A real signing key, before anything installable exists.
2. A stamp, and a row on the phone that shows it.
3. The publisher.

## WHAT CHANGED

### 1. Signing (`104ad91`)

`app/android/app/build.gradle.kts` signed RELEASE with
`signingConfigs.getByName("debug")`, under a TODO.

A debug keystore is generated PER MACHINE. A CI runner is a fresh machine every
run, so two base APKs carry two different signatures and the second cannot
install over the first. Android's only route out is uninstall, which deletes
the data directory.

The shape is what made it urgent rather than tidy work: the FIRST install
succeeds and looks perfect, and the bill arrives at the first native change
with weeks of real records to lose. Retrofitting a key after an install is
itself an uninstall, so it could not be done later.

Landed: a fresh `preview-keystore.jks` generated for Salapify 3, proved
distinct from the archived one by fingerprint (`3D:2B:C8:...` against
`7E:F5:EE:...`); `release` pointed at it; and NO flavor machinery copied
across, because Salapify 2's two tracks exist to carry a Play upload key, Play
is a separate later track, and half a production track is worse than none.
What that track will need is written where the config lives.

### 2. Stamp (`8329df4`)

`updateStamp` in `app/lib/main.dart`, at the address the publisher greps, plus
an Update stamp row in Settings under About.

`appVersion` could not do this job. Its own comment says it changes "when
somebody decides it does", so it answers which release line this is and never
which build am I running. Only the second question makes a delivery log
falsifiable.

The `s` prefix exists because `app/` SHARES `docs/delivery-log.md` with
Salapify 2 rather than forking it: CLAUDE.md's three command delivery check
reads exactly that path, and a second file is a second place to forget to look.
The file already ends at `f4.72`.

### 3. Publisher (`a06b579`)

`.github/workflows/app-publish.yml`. Reads the stamp, refuses one that already
has a delivery row, analyzes, tests, builds release, verifies the APK's
signature and size, uploads to a fixed `app-preview` release, writes the
delivery row, and says loudly when nothing shipped.

### Found along the way, and bigger than it looks (`0257e33`)

CI built `flutter build apk --debug`. R8 only runs on release, so switching to
`--release` for the signing work ran R8 for the first time, and it failed:

    ERROR: R8: Missing class
    com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions$Builder
    Execution failed for task ':app:minifyReleaseWithR8'.

**THE RELEASE BUILD HAD NEVER ONCE SUCCEEDED.** Not broken by a change: never
attempted. The first thing to discover it would have been the first attempt to
produce a publishable APK.

Root cause, read from the pinned package: `google_mlkit_text_recognition`
0.17.1 declares one Android dependency, the LATIN model, while its own
`initialize()` names the Chinese, Devanagari, Japanese and Korean option
classes, which live in artifacts it does not pull. Salapify asks for Latin at
exactly one site (`receipt_camera.dart:118`), so those branches are
unreachable and `-dontwarn` lets R8 strip them. Adding the four artifacts
instead would add tens of megabytes of language models for code that can never
run.

## WHAT DID NOT CHANGE

- **No money behaviour.** Nothing in this phase touches a calculation, a
  balance, a sign, a rounding rule or a stored shape. The only `app/lib`
  changes are `updateStamp`, the Settings row, and `_Row.subtitleMaxLines`.
- **No stored data and no migration.** `snapshot.dart`, `json_codec.dart` and
  `store.dart` are untouched by this phase.
- **dev-sync is untouched.** The founder's emulator route keeps working exactly
  as before, through `tools/dev-sync.sh` watching `claude/flutter-final`. At no
  point do they have neither route.
- **Salapify 2 is untouched**, including its `flutter-preview` release, which
  the publisher deliberately does not write to because it is the only way back
  to the app on the founder's phone today.

## VALIDATION

- `flutter analyze`: no issues, on the 3.47.4 pin.
- `flutter test`: **2095 pass, 0 fail**, up from 2073 at the start of the
  phase: 5 signing, 6 stamp, 4 toolchain, plus 7 earlier recovery tests.
- **CI green on the release build**, which is the only place it can be proved:
  this sandbox has no Android SDK at all. From the Android job on `c314511`,
  read rather than assumed:

      Built build/app/outputs/flutter-apk/app-release.apk (93.4MB)
      expected: 3d2bc86c0d2524eb684e5f66acfb13a511646f13c4ec123328514ce7bce75112
      actual:   3d2bc86c0d2524eb684e5f66acfb13a511646f13c4ec123328514ce7bce75112
      Signed with the preview key, so this build installs in place.

- Every guard proved able to fail, per CLAUDE.md:
  - signing, with `release` put back to the debug key: "Expected: contains
    'signingConfigs.getByName("preview")'" and "Expected: not contains
    ...debug...".
  - stamp, with a stamp that appends the previous build's notes: 196 characters
    against the 120 cap, two versions named instead of one, and an `f` stamp
    smuggled in.
  - toolchain, with the publisher set to 3.44.6 against the check's 3.47.4:
    "Expected: <1> Actual: <2>".
- Screens rendered and shown to the founder, dark: the wipe sheet (new export
  row) and the bottom of Settings (new stamp row). Neither had ever been
  rendered before.

## DEVIATIONS FROM THE PLAN

**The publisher ships a signed APK, not a Shorebird patch.** Shorebird needs an
account, an app id minted by its CLI, and a `SHOREBIRD_TOKEN` secret, all
founder actions; this environment cannot even read secret NAMES to check
whether one exists (the proxy returns 403 on that path). Building the workflow
and discovering the token missing at the first publish is the wrong order.

It is a prerequisite rather than a detour: a Shorebird release IS a signed
release APK, so all of this must work before Shorebird could. Adding it later
is a step between build and upload.

**One audit finding did not survive checking**, recorded because the rule is
that a finding is a lead. A reviewer reported no keystore ignore patterns
anywhere, having grepped three `.gitignore` files; `app/android/.gitignore` has
carried `key.properties`, `**/*.keystore` and `**/*.jks` the whole time. The
real consequence was the opposite of the report: the new key was being IGNORED
and would not have committed. It goes in through one narrow named exception
with the blanket ban untouched.

**A second claim was half right.** An audit called the `s` prefix a clash with
`app-cNN` in `docs/qa-log.md`. Those rows say "no stamp: no publisher" in their
own text, so `app-cNN` is a placeholder for the absence of a stamp rather than
a rival scheme.

## DEFERRED

- **Shorebird**, as above. Needs founder action first.
- **The Flutter pin question.** `app-check.yml:65` instructs that the pin must
  come down to whatever Shorebird supports when `app/` gains it. One reviewer
  found evidence 3.47.4 is inside Shorebird's support window; another marked it
  UNVERIFIED. Nobody can settle it here: no Shorebird CLI, and
  `docs.shorebird.dev` is egress-blocked. Left unbuilt rather than guessed,
  because getting it wrong fails at the first `shorebird release`.
- **`qa_record_test` for `app/`.** Belongs with a publisher that gates merges
  to main. `docs/qa-log.md`'s header corrected meanwhile: it claimed a guard
  was watching the file when that guard has been archived since 2026-09-18.
- **`targetSdk` and `minSdk` are inherited** from the Flutter SDK rather than
  pinned. Not a preview blocker, a store blocker, and cheap.
- **A merged-manifest check.** Nothing inspects `app/`'s merged manifest, so a
  plugin bump can add a permission with no signal.
- **The home screen widget.** `app/` has none. Verified: no `home_widget`
  dependency, no `AppWidgetProvider`.

## RISKS

1. **The 93.4MB APK.** Mostly the bundled ML Kit model. Fine for sideloading,
   worth revisiting before a store listing.
2. **Icon tree-shaking is active** (the log shows the Material font reduced
   98.7%). Harmless for an APK. If Shorebird is added, `--no-tree-shake-icons`
   is required on BOTH release and patch, because Salapify resolves glyphs by
   name through `salapify_icon.dart` and that is the exact shape that threw
   `UnpatchableChangeException` on Salapify 2.
3. **Nothing in the repository can observe whether the founder actually
   installed an APK.** The delivery row says a build was published. Only the
   stamp on the phone says it arrived. That is a rule, not a machine, and it is
   stated rather than engineered around.

## FOUNDER DECISION

**One, and it is the only thing blocking a first delivery: should the publisher
be run?**

It has never been fired. No delivery row exists, nothing is on any phone, and
no version number should be described as live. Running it by hand produces a
release page with an installable APK.

The trigger on merges to `main` is correct and currently inert, because nothing
reaches `main` while PR #473 stays open by founder instruction. That is not a
problem to solve today; `workflow_dispatch` covers it, and a preview build
somebody asked for is the better shape anyway.
