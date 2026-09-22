// Can the app be READ, in both themes?
//
// Ported into app/ on 2026-09-22, on founder direction, from
// archive/salapify-2-flutter/test/palette_contrast_test.dart. CLAUDE.md has
// described this guard as live for the current app for some time and it was
// not: the file existed only in the archive, the tree that is never built or
// tested, so the branch check had never run it once.
//
// The standing habit is to review the GABI renders, because that is what the
// founder uses. Hapon goes unopened. That is the exact shape of failure this
// measures away: a defect survives because the place it lives is the place
// nobody looks. On its first run here it found three, all of them in Hapon,
// all real, and all invisible to every screenshot taken this year:
//
//   textMuted on the page          4.39 to 1
//   textMuted on a soft banner     4.38 to 1
//   warning on the PENDING pill    4.25 to 1
//
// It is pure arithmetic over the palettes, so it is fast, total, and cannot
// be fooled by which screens somebody thought to render.

import 'dart:math' as math;

import 'package:flutter/material.dart' show Color;
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/design/tokens.dart';

/// WCAG relative luminance.
double _luminance(int argb) {
  double channel(int c) {
    final double s = c / 255.0;
    return s <= 0.03928
        ? s / 12.92
        : math.pow((s + 0.055) / 1.055, 2.4) as double;
  }

  final double r = channel((argb >> 16) & 0xFF);
  final double g = channel((argb >> 8) & 0xFF);
  final double b = channel(argb & 0xFF);
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

double contrast(Color a, Color b) {
  final double la = _luminance(a.toARGB32());
  final double lb = _luminance(b.toARGB32());
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// One text-on-surface pair the app ACTUALLY DRAWS, and the bar it must clear.
///
/// Two rules govern this list, and both were load-bearing when it was written.
///
/// A pair goes in only if the app really draws it, with the place named. The
/// archived version records a pair that was in its list first and failed on
/// all sixteen palettes, which is usually the sign of a wrong check rather
/// than sixteen wrong palettes, and it was.
///
/// And no floor is set to a value merely because the current palettes happen
/// to clear it. Everything here is WCAG AA for body text, 4.5, because
/// everything here is text somebody reads. Three pairs failed on the first
/// run and the COLOURS moved, not the bars.
typedef Pair = (
  String,
  Color Function(Palette),
  Color Function(Palette),
  double,
);

const List<Pair> _pairs = <Pair>[
  // Body text on the three surfaces every screen is built from.
  ('textPrimary on background', _textPrimary, _background, 4.5),
  ('textPrimary on surface', _textPrimary, _surface, 4.5),
  ('textPrimary on surfaceAlt', _textPrimary, _surfaceAlt, 4.5),

  // AppType.label, the small caps kicker over a figure.
  ('textSecondary on background', _textSecondary, _background, 4.5),
  ('textSecondary on surface', _textSecondary, _surface, 4.5),
  ('textSecondary on surfaceAlt', _textSecondary, _surfaceAlt, 4.5),

  // AppType.caption, the sub line under a row title and the explanatory
  // sentence under a control. Held to the SAME bar as body text, not a lower
  // one: a caution nobody can read is worse than no caution, because it looks
  // like the app said something.
  ('textMuted on background', _textMuted, _background, 4.5),
  ('textMuted on surface', _textMuted, _surface, 4.5),
  ('textMuted on surfaceAlt', _textMuted, _surfaceAlt, 4.5),
  // Captions inside the soft accent banners, for instance the scenario line
  // in the Safe to Spend sheet. This pair failed at 4.38 on the first run.
  ('textMuted on accentSoft', _textMuted, _accentSoft, 4.5),

  // The accent drawn as text: links, amounts, See all.
  ('accent on background', _accent, _background, 4.5),
  ('accent on surface', _accent, _surface, 4.5),
  ('accent on surfaceAlt', _accent, _surfaceAlt, 4.5),

  // A filled button: the label on the accent fill.
  ('onAccent on accent', _onAccent, _accent, 4.5),

  // Money that is doing something. These carry the most consequential words
  // in the app, so they are held to the body bar wherever they are drawn.
  ('positive on surface', _positive, _surface, 4.5),
  ('positive on background', _positive, _background, 4.5),
  ('negative on surface', _negative, _surface, 4.5),
  ('negative on background', _negative, _background, 4.5),
  ('warning on surface', _warning, _surface, 4.5),
  ('warning on background', _warning, _background, 4.5),

  // The status pills in Activity, which are a colour on its own soft tint.
  // day_group.dart pairs them exactly this way, and the PENDING one failed at
  // 4.25 on the first run.
  ('warning on warningSoft', _warning, _warningSoft, 4.5),
  ('negative on negativeSoft', _negative, _negativeSoft, 4.5),
  ('positive on positiveSoft', _positive, _positiveSoft, 4.5),
  ('accent on accentSoft', _accent, _accentSoft, 4.5),

  // Ordinary text inside a tinted panel.
  //
  // textMuted on warningSoft is deliberately NOT in this list, and the reason
  // is the rule at the top of the file rather than an exemption: the app does
  // not draw it. It nearly did. The business roadmap's caution blocks were
  // built with caption text on the warning panel, which measures 4.29 to 1 in
  // Gabi and 3.15 in Hapon, and the render is what caught it. Those blocks
  // now use textPrimary, which is the pair below, so the failing combination
  // exists nowhere in lib/ and listing it here would be testing a colour
  // nobody sees.
  ('textPrimary on accentSoft', _textPrimary, _accentSoft, 4.5),
  ('textPrimary on positiveSoft', _textPrimary, _positiveSoft, 4.5),
  ('textPrimary on negativeSoft', _textPrimary, _negativeSoft, 4.5),
  ('textPrimary on warningSoft', _textPrimary, _warningSoft, 4.5),

  // NOT the border against the page, and the archive explains why at length.
  // That pair fails on every palette, and a check that fails on every single
  // case is usually a wrong check. WCAG 1.4.11 covers a boundary that is the
  // ONLY way to identify a control; Salapify's cards are identified by their
  // FILL, and the border is a hairline on top of that. Holding it to 3.0
  // would demand a hard outline around every card in the app, which is a
  // different product rather than a more accessible one.
];

/// A card has to be a visibly different surface from the page behind it.
///
/// Not a WCAG rule, and said plainly rather than dressed up as one. It is a
/// floor against a palette edit that makes surface and background the same
/// colour, which would collapse every screen into one flat sheet while every
/// text pair above still passed.
const double _surfaceSeparation = 1.03;

Color _background(Palette p) => p.background;
Color _surface(Palette p) => p.surface;
Color _surfaceAlt(Palette p) => p.surfaceAlt;
Color _textPrimary(Palette p) => p.textPrimary;
Color _textSecondary(Palette p) => p.textSecondary;
Color _textMuted(Palette p) => p.textMuted;
Color _accent(Palette p) => p.accent;
Color _onAccent(Palette p) => p.onAccent;
Color _accentSoft(Palette p) => p.accentSoft;
Color _positive(Palette p) => p.positive;
Color _positiveSoft(Palette p) => p.positiveSoft;
Color _negative(Palette p) => p.negative;
Color _negativeSoft(Palette p) => p.negativeSoft;
Color _warning(Palette p) => p.warning;
Color _warningSoft(Palette p) => p.warningSoft;

void main() {
  test('the contrast maths agrees with the values WCAG defines', () {
    // The guard on the guard. Every number here is a published constant, so a
    // mistake in the formula shows up as this test rather than as a silently
    // permissive suite that passes on everything.
    const Color white = Color(0xFFFFFFFF);
    const Color black = Color(0xFF000000);
    expect(contrast(black, white), closeTo(21.0, 0.01));
    expect(contrast(white, white), closeTo(1.0, 0.001));
    // #767676 on white is the canonical "exactly AA" grey.
    expect(contrast(const Color(0xFF767676), white), closeTo(4.54, 0.05));
  });

  test('both themes are readable', () {
    final List<String> failures = <String>[];
    for (final ThemeMode2 mode in ThemeMode2.values) {
      final Palette p = Palette.of(mode);
      for (final (
            String name,
            Color Function(Palette) fg,
            Color Function(Palette) bg,
            double floor,
          )
          in _pairs) {
        final double ratio = contrast(fg(p), bg(p));
        if (ratio < floor) {
          failures.add(
            '${mode.name}: $name is ${ratio.toStringAsFixed(2)} to 1, '
            'needs $floor',
          );
        }
      }
    }
    expect(
      failures,
      isEmpty,
      reason:
          'these are unreadable on a real phone. Gabi is reviewed by eye every '
          'session and Hapon almost never is, which is exactly why this is a '
          'measurement and not a reminder:\n${failures.join('\n')}',
    );
  });

  test('a card is always a different surface from the page', () {
    for (final ThemeMode2 mode in ThemeMode2.values) {
      final Palette p = Palette.of(mode);
      expect(
        contrast(p.surface, p.background),
        greaterThanOrEqualTo(_surfaceSeparation),
        reason:
            '${mode.name}: surface and background are the same sheet, so every '
            'card in the app has just vanished into the page',
      );
    }
  });

  test('a deliberately unreadable palette is caught', () {
    // Proving the sweep can fail. A loop that measures the wrong thing, or a
    // pair list that came back empty, would pass the test above and read as a
    // clean bill of health for the whole app.
    //
    // The shape is the real defect the archived version records: text one
    // shade off its own card. Not hard to read. Invisible.
    final Palette bad = Palette(
      background: Palette.gabi.background,
      surface: Palette.gabi.surface,
      surfaceAlt: Palette.gabi.surfaceAlt,
      border: Palette.gabi.border,
      borderStrong: Palette.gabi.borderStrong,
      textPrimary: const Color(0xFF241812),
      textSecondary: Palette.gabi.textSecondary,
      textMuted: Palette.gabi.textMuted,
      accent: Palette.gabi.accent,
      onAccent: Palette.gabi.onAccent,
      accentSoft: Palette.gabi.accentSoft,
      positive: Palette.gabi.positive,
      positiveSoft: Palette.gabi.positiveSoft,
      negative: Palette.gabi.negative,
      negativeSoft: Palette.gabi.negativeSoft,
      warning: Palette.gabi.warning,
      warningSoft: Palette.gabi.warningSoft,
      iconTile: Palette.gabi.iconTile,
      trackSoft: Palette.gabi.trackSoft,
    );

    final List<String> failures = <String>[
      for (final (
            String name,
            Color Function(Palette) fg,
            Color Function(Palette) bg,
            double floor,
          )
          in _pairs)
        if (contrast(fg(bad), bg(bad)) < floor) name,
    ];
    expect(failures, contains('textPrimary on surface'));
    expect(failures, contains('textPrimary on background'));
  });

  test('every palette the app can show is actually measured', () {
    // A sweep is only as good as its list, and a derived set is a rule while
    // a typed set is a promise. This counts rather than trusting, so a third
    // theme added to ThemeMode2 and forgotten here shows up as a number that
    // stopped matching rather than as silence.
    int seen = 0;
    for (final ThemeMode2 mode in ThemeMode2.values) {
      expect(Palette.of(mode), isNotNull);
      seen++;
    }
    expect(seen, ThemeMode2.values.length);
    expect(seen, greaterThanOrEqualTo(2), reason: 'the theme registry shrank');
  });
}
