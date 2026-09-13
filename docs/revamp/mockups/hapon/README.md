# Hapon and Gabi, the Salapify 3 look

These are real Flutter renders, not drawings. Every pixel here came out of a
Flutter widget tree at 412 by 915 logical pixels, device pixel ratio 2, with
Plus Jakarta Sans and the Material icon font actually loaded. If it renders
here it renders on the phone.

## The two skins

Hapon (late afternoon) is the primary light look. A flat peach page, white
cards, and one light apricot gradient panel carrying dark ink. Gabi (night) is
the same hues one step over: a warm brown black page and the same light panel,
slightly deeper so it is not a lamp at night. There is no third option and no
theme picker. See D10 and D13 in ../../07-decisions.md.

## The pictures

Every one exists twice, once per skin. `hapon-` is light, `gabi-` is dark.

| File | What it shows |
|---|---|
| `<skin>.png` | Home, first viewport. Approved and locked 2026-09-13 |
| `<skin>-scrolled.png` | Home after one scroll |
| `<skin>-dense.png` | The Latest list at fourteen transactions, the real daily state |
| `<skin>-dense-bottom.png` | The bottom of that list, behind the tab bar |
| `<skin>-log.png` | The Log sheet, over Home, scrim and all |
| `<skin>-ledger.png`, `-ledger-scrolled.png` | Ledger, grouped by day |
| `<skin>-plan.png`, `-plan-scrolled.png` | Plan, Budget segment |
| `<skin>-accounts.png`, `-accounts-scrolled.png` | Accounts, net worth on top |
| `<skin>-debt.png` | Debt, both directions |

The dense pair matters most. A design that only works at three transactions is
not a design, so the fixture logs fourteen and the renders show what the page
looks like once the founder has actually been using it.

The Log sheet is rendered OVER Home rather than alone, because that is how it
is actually seen. Logging is the heartbeat, so the thing to judge is whether
the sheet reads well against a screen that is still there behind it.

## Three defects these renders caught

All three were invisible to `flutter analyze` and to every test here, and all
three were found by opening the picture. That is the whole argument for the
rule.

1. **Every label in the Log sheet had a yellow double underline.** That is
   Flutter's marker for text with no `Material` ancestor: Home brings its own
   `Scaffold`, but the sheet stacked beside it had none.
2. **The credit card drew an empty progress bar.** A statement balance has no
   "3 of 6" to be part way through, so an empty bar said "zero progress on a
   plan" when the truth is "there is no plan". Different facts about someone's
   money.
3. **The credit card balance rendered in the same ink as a savings balance.**
   On a screen whose hero is net worth, a liability that looks like an asset is
   the worst ambiguity available. It is the accent now, matching "You owe"
   everywhere else.

## Re-rendering them

The source in `source/` is a throwaway Flutter project. To rebuild it in a
fresh session:

    flutter create --project-name salapify_preview /path/to/preview
    cd /path/to/preview
    cp <this folder>/source/*.dart lib/
    mv lib/shot_test.dart test/shot_test.dart
    cp <this folder>/source/pubspec.yaml pubspec.yaml
    mkdir -p assets/fonts && cp ../../flutter/assets/fonts/PlusJakartaSans-*.ttf assets/fonts/
    flutter pub get
    flutter test test/shot_test.dart --update-goldens

`kit.dart` is the load-bearing file. Every screen is assembled from it and
nothing else, so a screen cannot quietly invent a second card shape or a second
way to draw a row. D12 locks the look; that file is where the lock lives in
code rather than in a document.

The PNGs land in test/goldens. Two gotchas are already handled in
shot_test.dart and both cost a round when they were not: the fonts must load
inside tester.runAsync, because testWidgets uses a fake clock and a real file
read never completes inside it, and the Material icon font ships with the SDK
rather than the app, so without loading it separately every icon draws as an
empty box and the screenshot proves nothing.

## Why these colours

Every colour in skin.dart was measured against WCAG before it was chosen,
never after, and the measured ratio sits in a comment beside it. The accent is
#B03C09 rather than the prettier #C2410C because #C2410C measures 4.57 to 1 on
this page, which clears the 4.5 body bar by 0.07, and nothing should ship that
thin. Text over the gradient panel is measured against the panel's darkest
stop, because text over a gradient has to pass against the worst pixel behind
it.

This look replaces Sinag, which the founder rejected. The Sinag renders stay
one folder up as history.
