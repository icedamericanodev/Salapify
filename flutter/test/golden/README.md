# Deterministic golden baselines

Version-controlled pixel baselines for the screens and states that the
UI/accessibility change set touched. They are a canonical visual reference: a
normal run COMPARES the current render against the committed image and fails on
a difference; regenerating the baseline is a separate, explicit action.

This sits ALONGSIDE the repo's existing regression safety, it does not replace
it. The per-push guards are the layout-metric tests, which cannot flake across
machines because they measure layout rather than pixels:

- `test/screen_readability_test.dart` (overflow, off-side, clipped, blank, raw
  dates, at 1.0x and 1.5x, scrolled)
- `test/palette_contrast_test.dart` (WCAG contrast over every palette)
- `test/segmented_test.dart`, `test/transfer_screen_test.dart`,
  `test/insights_screen_test.dart` (the specific fixes)

## Commands

Compare against the committed baselines (this is what CI runs):

    cd flutter
    flutter test test/golden/ui_golden.dart

Regenerate the baselines on purpose (review the diff before committing):

    cd flutter
    flutter test test/golden/ui_golden.dart --update-goldens

Baseline regeneration is deliberately a separate command. A normal run never
rewrites a baseline; it only reports a difference.

## Why this file is not named `*_test.dart`

`flutter test` collects every `*_test.dart` file. This one is named
`ui_golden.dart` so it is NOT collected by a plain `flutter test`, exactly like
`screens_shot.dart`. That keeps pixel comparison off the ordinary branch check
(where a cross-platform sub-pixel difference could flake it) and behind the
explicit command above. CI runs it as its own labelled step.

## Determinism

`ui_golden.dart` fixes everything that could move between runs: device size and
pixel ratio, the dark theme, `en` locale and LTR (via `test/support/golden_app.dart`),
the text scale per scenario, the real committed fonts, animations off, the debug
banner off, a fixed fixture, no network (the currency converter is forced
offline), a still text cursor, and an injected fixed clock where a screen shows a
date. Only time-independent or clock-injectable screens are included; the
time-relative populated Insights screen is covered by the layout-metric sweep,
not by a pixel baseline that would rot as the calendar moves.

## Tolerance

`test/golden/flutter_test_config.dart` installs a comparator with a small, fixed
0.5% pixel tolerance, scoped to this directory only. Baselines are generated on a
Linux box and compared on the Linux CI runner, both on the same pinned Flutter
and fonts, so the only expected difference is sub-pixel anti-aliasing at a few
glyph edges. A real regression (a moved box, a wrong colour, changed copy) moves
far more than 0.5% of the pixels and still fails. Do not raise the tolerance to
silence a failure; regenerate the baseline only when the change is intended.

## When a comparison fails

The failure names the baseline, and `flutter_test_config.dart` writes
`failure_*.png` images (the isolated render, the masked baseline, and the diff)
next to the baseline so you can see exactly what moved. If the change is
intended, rerun with `--update-goldens` and commit the new image; if not, it is
a regression to fix.

## Baselines

`baseline/` (tracked in git, unlike the gitignored `test/shots/` working
images):

- `system-selector-normal.png`, `system-selector-large.png` (the theme-mode
  selector at 1.0x and 2.0x)
- `transfer-sheet-normal.png`, `transfer-sheet-constrained-large.png`
- `insights-empty.png`, `insights-error.png`
- `currency-offline.png` (the app's real offline surface)
- `tax-income.png`, `bir-dates.png`, `year-end-tax.png`
- `shared-empty.png`, `shared-error.png`
