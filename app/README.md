# app, Salapify 3

The rebuild. Grows next to `flutter/`, which stays frozen and installed on the
founder's phone until this replaces it (Phase 4 of `docs/revamp/05-roadmap.md`).

Read `docs/revamp/02-architecture.md` for the target layout and
`docs/revamp/03-design-system.md` for the look. This file only covers what is
here now.

## What is here

    lib/core/money/     the money engine, 64 files, ported byte for byte
    test/core/money/    30 golden replays of the same vectors
    test/goldens/       34 JSON fixtures, byte identical to the shipped app's

Nothing else yet. No screens, no storage, no state layer. Those are Phase B2
and B3.

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
