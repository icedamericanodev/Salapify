// Can the APP be read, in every theme, at both brightnesses?
//
// Open lesson 1 from the 2026-07-29 retrospective, closed with a machine
// rather than another instruction.
//
// The standing habit is to review the DARK renders first, because that is what
// the founder uses. The light ones usually go unopened. That is the exact
// shape of the failure the same retrospective was written about: a defect that
// survives because the place it lives is the place nobody looks. The
// strikethrough peso lived on a screen with no money; a low-contrast label
// would live in a theme nobody opens.
//
// widget_contrast_test.dart already does this for the home screen TILE, and
// only for the tile: its card colour is frozen in the APK, so the palette
// pushed to it can be wrong in a way nothing else is. This is the app's own
// surfaces, across all of barakoThemes, both brightnesses, which is sixteen
// palettes nobody renders and nobody could reasonably be asked to eyeball.
//
// It is pure arithmetic over the registry, so it is fast, total, and cannot be
// fooled by which screens somebody thought to shoot.

import 'dart:math' as math;

import 'package:flutter/material.dart' show Brightness, Color;
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/theme.dart';

/// WCAG relative luminance. Same maths as widget_contrast_test, deliberately
/// duplicated rather than shared: a test importing another test's helper makes
/// the two fail together for reasons unrelated to what either measures, and
/// this is eight lines.
double _luminance(int argb) {
  double channel(int c) {
    final s = c / 255.0;
    return s <= 0.03928
        ? s / 12.92
        : math.pow((s + 0.055) / 1.055, 2.4) as double;
  }

  final r = channel((argb >> 16) & 0xFF);
  final g = channel((argb >> 8) & 0xFF);
  final b = channel(argb & 0xFF);
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

double contrast(Color a, Color b) {
  final la = _luminance(a.toARGB32());
  final lb = _luminance(b.toARGB32());
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

/// One text-on-surface pair the app actually draws, and the bar it must clear.
///
/// The bars are WCAG AA: 4.5 for body text, 3.0 for large text and for the
/// non-text edges a person needs to SEE rather than read. Nothing here is set
/// to a value merely because the current palettes happen to pass it; where a
/// pair is held to 3.0 the reason is written next to it.
typedef Pair = (String, Color Function(BarakoPalette), Color Function(BarakoPalette), double);

const List<Pair> _pairs = [
  // Body text. The floor for anything somebody reads a sentence of.
  ('text on background', _text, _background, 4.5),
  ('text on card', _text, _card, 4.5),
  ('text on raised surface', _text, _surfaceRaised, 4.5),
  ('secondary text on card', _textSecondary, _card, 4.5),

  // Muted is the sub line under a row title: a real sentence, read once.
  ('muted on card', _muted, _card, 4.5),
  ('muted on background', _muted, _background, 4.5),

  // Faint is used for hints and disclaimers at 12pt and below. Held to the
  // SAME bar, not a lower one. A disclaimer nobody can read is worse than no
  // disclaimer, because it looks like the app said something.
  ('faint on card', _faint, _card, 4.5),

  // The accent, on the surfaces it is drawn on as text (links, amounts).
  ('primary text on card', _primaryText, _card, 4.5),
  ('primary text on background', _primaryText, _background, 4.5),

  // A filled button: the label on the accent fill.
  ('onPrimary on primary', _onPrimary, _primary, 4.5),

  // Warnings carry the most consequential words in the app.
  ('warning on card', _warning, _card, 4.5),
  ('warningStrong on card', _warningStrong, _card, 4.5),

  // The caramel kicker inside a card. This pair was previously guaranteed
  // only by a comment on Barako.cardKickerStyle ("ranges 5.42 to 9.75"); the
  // repo's own lesson applies, a rule in a comment is not a machine.
  ('caramel on card', _caramel, _card, 4.5),

  // The win gold, now theme-invariant, drawn as small text and icons on both
  // main surfaces (diagnostics status lines, finished-lesson ticks). Held to
  // the small-text bar because it IS small text in places.
  ('celebrate on card', _celebrate, _card, 4.5),
  ('celebrate on background', _celebrate, _background, 4.5),

  // Words on the positive surface (win banners, settled states). The surface
  // is a tinted card, so plain text must still read on it.
  ('text on positiveSurface', _text, _positiveSurface, 4.5),

  // NOT the card border against the page.
  //
  // That pair was in this list first, held to WCAG's 3.0 for a meaningful
  // non-text boundary, and it failed on all SIXTEEN palettes at ratios from
  // 1.13 to 1.93. A check that fails on every single case is usually a wrong
  // check, and it was: 1.4.11 covers a boundary that is the ONLY way to
  // identify a control. Salapify's cards are identified by their FILL, and the
  // border is a hairline refinement on top of that. Holding it to 3.0 would
  // have demanded a hard outline around every card in the app, which is a
  // different product, not a more accessible one.
  //
  // What actually matters is below: the card must be distinguishable from the
  // page at all.
];

/// The card has to be a visibly different surface from the page behind it.
///
/// Not a WCAG rule, and said so plainly rather than dressed up as one. It is a
/// floor against a palette edit that makes card and background the same
/// colour, which would collapse every screen in the app into one flat sheet
/// while every text-contrast pair above still passed.
const double _surfaceSeparation = 1.03;

Color _background(BarakoPalette p) => p.background;
Color _card(BarakoPalette p) => p.card;
Color _surfaceRaised(BarakoPalette p) => p.surfaceRaised;
Color _primary(BarakoPalette p) => p.primary;
Color _primaryText(BarakoPalette p) => p.primaryText;
Color _text(BarakoPalette p) => p.text;
Color _textSecondary(BarakoPalette p) => p.textSecondary;
Color _muted(BarakoPalette p) => p.muted;
Color _faint(BarakoPalette p) => p.faint;
Color _warning(BarakoPalette p) => p.warning;
Color _warningStrong(BarakoPalette p) => p.warningStrong;
Color _onPrimary(BarakoPalette p) => p.onPrimary;
Color _caramel(BarakoPalette p) => p.caramel;
Color _celebrate(BarakoPalette p) => p.celebrate;
Color _positiveSurface(BarakoPalette p) => p.positiveSurface;

void main() {
  test('the contrast maths agrees with the values WCAG defines', () {
    // The guard on the guard. Every number below is a published constant, so
    // a mistake in the formula shows up here rather than as a silently
    // permissive suite that passes on everything.
    const white = Color(0xFFFFFFFF);
    const black = Color(0xFF000000);
    expect(contrast(black, white), closeTo(21.0, 0.01));
    expect(contrast(white, white), closeTo(1.0, 0.001));
    // #767676 on white is the canonical "exactly AA" grey.
    expect(contrast(const Color(0xFF767676), white), closeTo(4.54, 0.05));
  });

  test('every theme, at BOTH brightnesses, is readable', () {
    expect(barakoThemes, isNotEmpty, reason: 'the registry scan found nothing');
    final failures = <String>[];
    for (final theme in barakoThemes) {
      for (final b in [Brightness.light, Brightness.dark]) {
        final p = theme.resolve(b);
        final mode = b == Brightness.dark ? 'dark' : 'light';
        for (final (name, fg, bg, floor) in _pairs) {
          final ratio = contrast(fg(p), bg(p));
          if (ratio < floor) {
            failures.add(
              '${theme.key} $mode: $name is '
              '${ratio.toStringAsFixed(2)} to 1, needs $floor',
            );
          }
        }
      }
    }
    expect(
      failures,
      isEmpty,
      reason:
          'these are unreadable on a real phone. Dark is reviewed by eye every '
          'session and light almost never is, which is exactly why this is a '
          'measurement and not a reminder:\n${failures.join('\n')}',
    );
  });

  test('a card is always a different surface from the page', () {
    final failures = <String>[];
    for (final theme in barakoThemes) {
      for (final b in [Brightness.light, Brightness.dark]) {
        final p = theme.resolve(b);
        final r = contrast(p.card, p.background);
        if (r < _surfaceSeparation) {
          failures.add(
            '${theme.key} ${b == Brightness.dark ? 'dark' : 'light'}: card and '
            'background are ${r.toStringAsFixed(3)} to 1, which is one flat '
            'sheet',
          );
        }
      }
    }
    expect(failures, isEmpty, reason: failures.join('\n'));
  });

  test('a deliberately unreadable palette is caught', () {
    // Proving the sweep can fail. A loop that measures the wrong thing, or a
    // registry that came back empty, would pass the test above and read as a
    // clean bill of health for sixteen palettes.
    const bad = BarakoPalette(
      brightness: Brightness.dark,
      background: Color(0xFF1A130E),
      card: Color(0xFF251A13),
      surfaceRaised: Color(0xFF2E211A),
      border: Color(0xFF3A2A20),
      primary: Color(0xFFFF8A3D),
      primaryText: Color(0xFFFF8A3D),
      caramel: Color(0xFFE9BC8E),
      // The real defect this shape had on the widget: text one shade off its
      // own card, 1.02 to 1. Not hard to read. Invisible.
      text: Color(0xFF241812),
      textSecondary: Color(0xFFE0CEBB),
      muted: Color(0xFFA99182),
      faint: Color(0xFF97806F),
      warning: Color(0xFFFF5D73),
      warningStrong: Color(0xFFF5384F),
      onPrimary: Color(0xFF2A1305),
      celebrate: Color(0xFFFFC24D),
      positiveSurface: Color(0xFF2E2114),
      positiveBorder: Color(0xFF55402C),
      overlay: Color.fromRGBO(10, 7, 5, 0.64),
    );
    final failures = [
      for (final (name, fg, bg, floor) in _pairs)
        if (contrast(fg(bad), bg(bad)) < floor) name,
    ];
    expect(failures, contains('text on card'));
    expect(failures, contains('text on background'));
  });

  test('the win gold is theme-invariant, like Pan\'s orange', () {
    // The reward signature reads identically in every theme: one gold for
    // all dark palettes, one deep gold for all light. Before this rule
    // Voltage celebrated in hot pink and Ultraviolet in lime, so the same
    // win looked like a different app per theme. The registry is the source
    // of truth here, so a new theme with its own win color goes red.
    final darkGold = barakoThemes.first.dark.celebrate;
    final lightGold = barakoThemes.first.light.celebrate;
    expect(darkGold, isNot(lightGold), reason: 'the two brightnesses need their own gold');
    for (final t in barakoThemes) {
      expect(
        t.dark.celebrate,
        darkGold,
        reason:
            '${t.key} dark celebrates in its own color; the win gold is brand, '
            'not theme',
      );
      expect(
        t.light.celebrate,
        lightGold,
        reason:
            '${t.key} light celebrates in its own color; the win gold is '
            'brand, not theme',
      );
    }
  });

  test('every palette in the registry is actually reached', () {
    // A scan is only as good as its list. Counting rather than trusting, so a
    // theme added to the app but not to barakoThemes shows up as a number that
    // stopped matching rather than as silence.
    var seen = 0;
    for (final t in barakoThemes) {
      for (final b in [Brightness.light, Brightness.dark]) {
        expect(t.resolve(b).brightness, b, reason: '${t.key} $b resolved wrong');
        seen++;
      }
    }
    expect(seen, barakoThemes.length * 2);
    expect(seen, greaterThanOrEqualTo(8), reason: 'the registry shrank');
  });
}
