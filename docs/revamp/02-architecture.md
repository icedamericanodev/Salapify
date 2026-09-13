# 02. Architecture

## The decision in one sentence

Salapify 3 is a NEW Flutter app in a new folder, app/, that reuses the money
engine and the encrypted store from the current app as copied, tested
library code, and rebuilds every screen, the navigation, the state layer
and the design system from a blank file.

## Why Flutter again, and not something else

The founder mentioned Google AI Studio, which can now generate native
Android apps in Kotlin and Jetpack Compose. That was considered seriously.
The reasons to stay on Flutter:

1. The money engine is the expensive part and it is already in Dart: about
   ninety pure files with thousands of golden test vectors that match the
   old React Native app to the centavo. Rewriting that in Kotlin means
   re-earning every one of those numbers.
2. The encrypted store (SQLCipher plus a key in the Android Keystore) is
   in Dart with native glue that already works on the founder's phone.
   Keeping it means Salapify 3 opens with the founder's data already there.
3. Over-the-air delivery via Shorebird already works. A Kotlin app would
   need a new install for every change.
4. Flutter keeps the iOS door open at no cost.
5. Claude Code writes Flutter well, and there is a rendering harness that
   produces screenshots for review without a phone.

Google AI Studio and Stitch still have a job: design exploration and rapid
mockups. See 06-tooling.md.

## Why a new folder and not a rebuild in place

The current app in flutter/ is what is installed on the founder's phone and
every merge that touches flutter/ ships a patch to it. Rebuilding inside
that folder means the founder's daily app is half old, half new for months.
A new folder means:

- flutter/ stays frozen and working. No feature work goes there; only a
  fix the founder actually needs while waiting.
- app/ grows with no pressure to ship until it is better than what it
  replaces. The same pattern was used once already, when the Flutter app
  grew next to the React Native app in mobile/.
- The old code is a reference, not a constraint. Copy what earns its place,
  leave the rest.

When Salapify 3 replaces the old app on the founder's phone, flutter/ and
mobile/ are deleted from the working tree (history keeps them). That
deletion is a founder decision, listed in 07-decisions.md.

## Repository layout, target state

    app/                      Salapify 3 (Flutter). The only app once the cutover is done.
      lib/
        main.dart             boots the store, applies the theme, hands off to the router
        app/                  router, shell (tabs plus the Log button), app-level state
        core/
          money/              the engine, copied from flutter/lib/money, trimmed to what v3 uses
          data/               models, ledger repository, encrypted store, backup, migrations
          format/             peso formatting, dates, relative time
        design/               tokens (colour, type, space, radius, motion) and the component kit
        features/
          home/               screen plus its view model
          log/                the log sheet and the fast-log parser glue
          activity/
          accounts/
          budget/
          upcoming/
          debt/
          insights/
          goals/
          settings/
      test/
        money/                the golden vectors, moved with the engine, unchanged
        data/                 store, backup and migration tests, unchanged
        design/               token guards: contrast, type discipline, radius ladder
        features/             one widget test file per screen plus journeys_test.dart
        shots/                the render harness (not collected by flutter test)
    docs/
      revamp/                 this folder, the governing set
      archive/                everything superseded, moved not deleted (after founder OK)
    flutter/                  the current app, frozen, deleted after cutover
    mobile/                   the React Native app, frozen since August, deleted after cutover

Feature-first folders (features/home holds the home screen AND its logic)
rather than layer-first (all screens in one folder, all logic in another).
With one person and Claude working on it, a feature being one folder is
what keeps a change small.

## The layers, and the one rule between them

    UI (features/*)  ->  view models  ->  core/data (repository)  ->  core/money (pure functions)

- core/money never imports Flutter. It takes plain data in and returns
  plain data out. This is what makes it testable to the centavo and what
  makes it copyable from the old app unchanged.
- core/data owns the single Ledger (the whole dataset as one immutable
  value), how it is persisted, and how it is backed up. Screens never touch
  storage.
- A view model per feature (a ChangeNotifier) reads the Ledger, calls money
  functions, and exposes exactly what its screen shows. Screens are dumb:
  they render what the view model gives them and call its methods.
- No screen imports another screen's view model. If two screens need the
  same number, the number comes from core/money and both compute it from
  the Ledger.

## State management

Plain ChangeNotifier, one per feature, plus one app-level LedgerStore that
holds the Ledger and persists it. No Riverpod, no Bloc, no code generation.
Reasons: the founder is a beginner and will read this code; the current
app already proved ChangeNotifier is enough; and every extra framework is
one more thing Context7 has to verify per version. The mistake to avoid is
the current app's, one 3,000-line store that every screen reaches into.
The cure is the feature view models above, not a bigger framework.

If a feature ever needs more (a stream, undo history), that is a decision
for that feature, logged in 07-decisions.md, not a global switch.

## Navigation

go_router, one file, typed route names. Four tabs in a shell plus a Log
button in the centre. Every other screen is pushed over the shell. Deep
links (from the home screen widget, from a notification) resolve through
the same router. See 04-screens.md for the tab set.

## Data: what is kept exactly

- The encrypted store and its key handling, copied from flutter/lib/data.
- The backup JSON format at schema v12 and its forward migration chain.
  Salapify 3 must import a backup made by the current app on day one; that
  is the test that gates Phase 2.
- The data key salapify_data_v2 and the applicationId. Same package name,
  same signing key, higher version code, so the new APK installs over the
  old one and finds the data in place. Backup first anyway; the restore
  path is the safety net.

Models get cleaned up where the old shape was a JSON map read by name in
fifty places: v3 gives each collection a typed Dart class with a
fromJson and toJson that round-trip the v12 shape byte for byte. That is
a code change, not a data change, and the round-trip test is what proves it.

Anything that would change the stored shape (a new field, a renamed one)
is a schema bump and a founder decision, same as today.

## Testing strategy

Kept from today, because it works:
- Golden money vectors: every function in core/money keeps its test file.
- Journeys: one file that taps through several features on one store and
  checks every screen agrees about the money.
- Design guards: contrast (WCAG AA on every colour pair), type discipline
  (no raw TextStyle in features/), radius and spacing ladder use.
- Readability sweep: every screen at 1.0x and 1.5x text, no overflow, no
  raw dates, no ellipsis on money.
- The render harness: PNG of every screen, dark and light, surfaced in the
  conversation for every UI change.

Dropped: the constitution citation test, the stamp-in-prose tests that
guarded the old delivery model, and the content tests for courses.

## Delivery

Unchanged mechanics, new target: the same two GitHub Actions (check on the
branch, build and Shorebird patch on merge to main) pointed at app/ instead
of flutter/. Until Phase 4 (cutover) the app/ publisher does not exist;
app/ is check-only. The founder installs Salapify 3 once as a new base APK
at cutover; every change after that is a patch.

The update stamp survives, one line, in app/lib/main.dart, and starts at
s3.01 so it can never collide with the f-series.

## Dependencies, kept deliberately small

Carried over: sqflite_sqlcipher, flutter_secure_storage, shared_preferences
(settings only), path_provider, share_plus, file_picker, local_auth,
flutter_local_notifications, timezone, home_widget, shorebird_code_push.
Added: go_router. Dropped: fl_chart (v3 charts are drawn with
CustomPainter, one grammar, no library styling to fight), animations,
flutter_spinkit, csv, excel, pdf (return with the features that need them,
if they return).

Every version is checked against Context7 before use, per CLAUDE.md.
