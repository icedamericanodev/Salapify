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

| File | What it shows |
|---|---|
| hapon.png, gabi.png | Home, first viewport |
| hapon-scrolled.png, gabi-scrolled.png | Home after one scroll |
| hapon-dense.png, gabi-dense.png | The Latest list at fourteen transactions, the real daily state |
| hapon-dense-bottom.png, gabi-dense-bottom.png | The bottom of that list, behind the tab bar |

The dense pair matters most. A design that only works at three transactions is
not a design, so the fixture logs fourteen and the renders show what the page
looks like once the founder has actually been using it.

## Re-rendering them

The source in source/ is a throwaway Flutter project, four files. To rebuild
it in a fresh session:

    flutter create --project-name salapify_preview /path/to/preview
    cd /path/to/preview
    cp <this folder>/source/main.dart lib/main.dart
    cp <this folder>/source/skin.dart lib/skin.dart
    cp <this folder>/source/shot_test.dart test/shot_test.dart
    cp <this folder>/source/pubspec.yaml pubspec.yaml
    mkdir -p assets/fonts && cp ../../flutter/assets/fonts/PlusJakartaSans-*.ttf assets/fonts/
    flutter pub get
    flutter test test/shot_test.dart --update-goldens

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
