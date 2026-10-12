# app, Salapify

The Flutter app, rebuilt from the Google AI Studio prototype in `src/`.

Founder direction, 2026-09-18: start `app/` from zero and migrate the
prototype tab by tab, in the prototype's own order. The previous contents of
this folder are not lost, they are on `main` and in git history.

`flutter/` and `mobile/` stay frozen and are not touched.

## What is here

    lib/main.dart          boots the store and builds the theme
    lib/design/tokens.dart the Hapon and Gabi palettes, lifted from the prototype
    lib/models/            the data model, ported from src/types.ts
    lib/engine/            the money math, ported from src/utils/
    lib/data/seed_data.dart the lived-in fixture, from src/data/initialData.ts
    lib/state/             the one store every screen reads
    lib/shell/             the five-tab shell and the Log pill
    lib/screens/home/      tab 1, migrated
    test/engine/           golden vectors generated from the prototype itself
    test/shots/            the render harness (not collected by flutter test)

## Running it

    cd app
    flutter pub get
    flutter run

Press `r` in the terminal for hot reload.

## Looking at it without a phone

    flutter test test/shots/screens_shot.dart --update-goldens

Writes `test/shots/out/*.png`, which is gitignored. The reviewed renders are
committed under `docs/migration/screens/` and shown inline in
`docs/migration/README.md`, so they can be opened on GitHub.

## How money math gets ported

Never by reading the TypeScript and writing Dart that looks right. The
prototype's own engine is RUN, under bun, against the prototype's own fixture,
and the numbers it prints become the expectations in `test/engine/`.

That is how `safeToSpendEngine.ts` was ported. Its vectors caught nothing on
the way in, which is the point: they will catch the next change.

## Two things that bit this app already

1. `NumberFormat`/`DateFormat` must NOT be given the `'en_PH'` locale name.
   Doing so makes intl demand `initializeDateFormatting()` first, and every
   screen showing a date throws on its first build. The explicit pattern
   already produces en-PH grouping, so the locale name buys nothing.
2. Real fonts load inside `tester.runAsync`. `testWidgets` runs on a fake
   clock, so a real file read never completes inside it and the run hangs with
   no output.
