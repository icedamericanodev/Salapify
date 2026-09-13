# app, Salapify 3

The rebuild. Grows next to `flutter/`, which stays frozen and installed on the
founder's phone until this replaces it (Phase 4 of `docs/revamp/05-roadmap.md`).

Read `docs/revamp/02-architecture.md` for the target layout and
`docs/revamp/03-design-system.md` for the look. This file only covers what is
here now.

## What is here

    lib/core/money/     the money engine, 66 files, ported byte for byte
    lib/core/data/      the encrypted store, the backup format, LedgerStore
    test/core/money/    30 golden replays of the same vectors
    test/core/data/     the storage tests, plus the backup round trip
    test/goldens/       34 JSON fixtures, byte identical to the shipped app's

No screens and no design tokens yet. That is Phase B3.

## The one guarantee this folder makes

**No number moved.** The money engine is the expensive part of Salapify and it
is already correct, proven against the React Native app it replaced, to the
centavo. A rebuild that quietly changes someone's balance is worse than no
rebuild, so the engine came across unmodified and the vectors came with it.

Verified rather than asserted: all 64 engine files and all 34 fixtures are
byte-identical to their originals under `flutter/`, and 215 tests pass without
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

## Why the engine needs no dependencies

`pubspec.yaml` lists nothing beyond the framework, and that is a property of
the engine rather than a choice: none of the 64 files imports a package, not
even Flutter. It is plain Dart doing arithmetic on maps. That is what makes it
portable, and it is why the golden tests run in under ten seconds.

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
