# app, Salapify 3

The rebuild. Grows next to `flutter/`, which stays frozen and installed on the
founder's phone until this replaces it (Phase 4 of `docs/revamp/05-roadmap.md`).

Read `docs/revamp/02-architecture.md` for the target layout and
`docs/revamp/03-design-system.md` for the look. This file only covers what is
here now.

## What is here

    lib/main.dart       boots the store, builds both themes, hands off
    lib/app/            the router and the four-tab shell
    lib/core/money/     the money engine, 66 files, ported byte for byte
    lib/core/data/      the encrypted store, the backup format, LedgerStore
    lib/design/         the tokens, the type ladder and the component kit
    lib/features/       one folder per screen
    test/core/money/    30 golden replays of the same vectors
    test/core/data/     the storage tests, plus the backup round trip
    test/design/        the contrast sweep and the type discipline guard
    test/goldens/       34 JSON fixtures, byte identical to the shipped app's
    test/shots/         the render harness (not collected by flutter test)

The app boots, shows four tabs in the approved look, and opens the Log sheet.
The screens are EMPTY: connecting them to the ledger is Phase C.

## Looking at it without a phone

    cd app
    flutter test test/shots/screens_shot.dart --update-goldens

Renders every screen in Hapon and Gabi to `test/shots/out` (gitignored). The
reviewed ones are committed to `docs/revamp/mockups/hapon/b3/` and embedded in
that folder's README, which is what GitHub actually renders.

## The design layer

`lib/design` is the only place a colour or a text size is decided, and that is
enforced rather than asked for. `test/design/type_discipline_test.dart` reads
the source of every file under `lib/features` and `lib/app` and fails on a raw
`TextStyle`, a `fontSize:`, a hex colour, a `Colors.*` name or a reach into
Material's own scheme. It found a real breach on its first run: the Log sheet's
scrim was a hex literal, and it is a token now.

`test/design/palette_contrast_test.dart` measures every pair in both skins
against WCAG AA plus D8's 0.2 of headroom, and then reads `tokens.dart`'s own
source to prove no colour was added without being measured. Both halves earned
themselves: the first version checked the bare 4.5 and let the REJECTED accent
back through, and the first version of the coverage regex could not see an
initialised field.

The palette itself came across unchanged from the preview that produced the 24
approved renders. No size, weight, padding, radius or inset moved.

## The one guarantee this folder makes

**No number moved.** The money engine is the expensive part of Salapify and it
is already correct, proven against the React Native app it replaced, to the
centavo. A rebuild that quietly changes someone's balance is worse than no
rebuild, so the engine came across unmodified and the vectors came with it.

Verified rather than asserted: all 66 engine files and all 34 fixtures are
byte-identical to their originals under `flutter/`, and 316 tests pass without
one vector being touched. `.github/workflows/app-check.yml` re-checks that
byte-for-byte on every push, because a suite goes green whether a vector was
honoured or edited, and only the comparison can tell those apart.

## The storage layer

SQLCipher over SQLite holding the JSON document, with the database key in
EncryptedSharedPreferences wrapped by the Android Keystore. Copied unmodified,
because it already works on the founder's phone. Deliberately no biometric gate
on the key, per ADR 0001: App Lock is the UI gate, and a sensor reset must never
cost data.

**`store.dart` was NOT copied.** It is 3,196 lines holding the blob, every
mutation for every feature, and the notifying, in one class every screen reached
into, and `02-architecture.md` names it as the mistake to avoid.
`ledger_store.dart` is the part of its job that was sound: load, hold, save,
notify, and nothing that knows what a debt is. Features get their own view
models. That one rule is what stops the 3,196 lines reassembling.

Its order is persist, then swap, then notify, which is the opposite of
convenient. A UI that updates before the write lands tells the founder their
money is saved when it may not be. Reversing those three lines reddens exactly
the test that names it.

### Restore is proven, not assumed

`backup_round_trip_test.dart` loads a realistic schema v12 backup, sends it
through JSON and back the way a real restore does, and checks the money rather
than the format. Restore is the founder's only safety net if the cutover goes
wrong, so it is proven before anything leans on it.

The net worth assertion is a HAND-COMPUTED figure, not a comparison against the
other side of the same function. That distinction is not pedantry: comparing
restored against original passed straight through a deliberate break that
rounded every balance to whole pesos, because both sides rounded identically.
The arithmetic is written out in the test above the number.

Writing it also caught two things about the data model worth knowing:

- Debts total on `remaining`, not `balance`.
- A receivable counts toward net worth only when `cashLeg` is true, meaning
  real money left the founder's pocket. A note that someone owes a share of
  something does not move net worth.

Both were errors in the first draft of the fixture, and the hand-computed total
is what found them.

## Dependencies

Five, and the list is checked rather than inherited.

Four came with the encrypted store, which was copied unmodified because it
already works on the founder's phone: `sqflite_sqlcipher`,
`flutter_secure_storage`, `path_provider`, `shared_preferences`.

The fifth is `go_router`, added in B3 for the shell. Not for prettier
navigation: the home screen widget and a notification both have to open a
specific screen from outside the app, and with go_router they resolve through
the same route table as a tap. A `StatefulShellRoute` is also the part that is
genuinely painful to retrofit, so it went in before there were screens to
retrofit it around.

**The money engine still contributes zero of them.** None of the 66 files in
`lib/core/money` imports a package, not even Flutter. It is plain Dart doing
arithmetic on maps, which is what makes it portable and why the golden tests
run in seconds.

The old app also carried `csv`, `excel`, `pdf`, `fl_chart`, `animations` and
`flutter_spinkit`. v3 drops all six: charts are drawn by hand under one grammar
(D9), and export returns in Phase E if it is missed.

## What was left behind, and why

27 money files went with the features `01-vision.md` cuts: courses, lessons,
Money Mindset, treats, milestones, the week chain, the recap. Two golden tests
went with them.

Two decisions worth knowing:

**`deposit_insurance_fact.dart` is gone.** It was the only file blocking the
trim, because it needed one date parser from a courses file. It turned out to
be used by exactly one thing, a course lesson being cut, so it left with them
and the blocker stopped existing rather than needing a workaround.

**Pan is cut, but its text layer survived as `core/money/taglish.dart`.** That
file is `pan/normalize.dart`, byte for byte, renamed. It holds the Taglish
folding and the amount extractor, which are the only two pieces of a fast log
parser anywhere in this repository, and the fast log field is principle 1. The
old test replayed 63 cases and then asserted chat intents, chips and help text,
all cut; `taglish_golden_test.dart` replays the same fixture and asserts only
the two columns v3 still uses, so the lock outlives the feature that owned it.

## Still to be decided before this can ship

**The applicationId.** `flutter create` defaulted it to
`dev.icedamericano.salapify`, which is byte for byte the id of the app on the
founder's phone, so installing this as it stands would replace their working
app. Decision D4, marked loudly in `android/app/build.gradle.kts`. Harmless
today because Phase B builds nothing; not harmless at Phase D.

## Running it

    cd app
    flutter pub get
    flutter test

## Never run `dart format lib/`

Format the folders you actually changed:

    dart format lib/app lib/design lib/features lib/main.dart test/

`dart format lib/` reaches into `lib/core/money`, and reflows four files
(`accounts_breakdown`, `commitments`, `debt_statement`, `net_worth_history`)
whose compact list literals the current formatter expands. Logic untouched,
every test green, and the one guarantee this folder makes quietly broken.

It has happened twice, in B2 and again in B3, so it is a trap rather than an
accident. The formatter cannot be told to skip them: `formatter: exclude:` in
`analysis_options.yaml` is silently ignored by Dart 3.12.2, and
`// dart format off` would change the very bytes it is meant to protect. So it
is caught instead, by `.github/scripts/check-engine-identical.sh`, which runs
both in CI and in `.githooks/pre-push`. If it fires, the fix is the `cp` line
it prints.
