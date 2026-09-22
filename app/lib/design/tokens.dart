import 'package:flutter/material.dart';

/// The two Salapify themes, named the way the prototype names them.
/// Hapon is daylight, Gabi is night. Every colour here was lifted from the
/// React prototype in src/, so the Flutter app and the prototype agree.
enum ThemeMode2 { hapon, gabi }

/// One palette. Both themes fill in the same slots, so a widget never asks
/// "which theme am I", it just reads the slot it needs.
@immutable
class Palette {
  const Palette({
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.border,
    required this.borderStrong,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.accent,
    required this.onAccent,
    required this.accentSoft,
    required this.positive,
    required this.positiveSoft,
    required this.negative,
    required this.negativeSoft,
    required this.warning,
    required this.warningSoft,
    required this.iconTile,
    required this.trackSoft,
  });

  final Color background;
  final Color surface;

  /// A second surface, used where a card sits on a card.
  final Color surfaceAlt;

  /// The page behind everything. Same colour as [background]; the name exists
  /// because the design notes call it the canvas, and one vocabulary is worth
  /// more than a second class holding the same values.
  Color get canvas => background;

  /// The raised surface a card is drawn on. Same colour as [surface].
  Color get card => surface;
  final Color border;
  final Color borderStrong;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color accent;

  /// Text drawn ON the accent colour, which flips between themes: the light
  /// theme puts white on a deep rust, the dark theme puts near-black on amber.
  final Color onAccent;
  final Color accentSoft;

  final Color positive;
  final Color positiveSoft;
  final Color negative;
  final Color negativeSoft;
  final Color warning;
  final Color warningSoft;

  /// The tinted square behind a small leading icon.
  final Color iconTile;

  /// The unfilled part of a progress rail.
  final Color trackSoft;

  /// Hapon, the daylight theme.
  static const Palette hapon = Palette(
    background: Color(0xFFFDEFE2),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFFFFDF9),
    border: Color(0xFFF3DFCD),
    borderStrong: Color(0xFFF0D5C0),
    textPrimary: Color(0xFF15120F),
    textSecondary: Color(0xFF5A5148),
    // Four points darker than the prototype's #7A6E63, on 2026-09-22, and
    // the only reason is measurement. This is caption text, and at the
    // prototype's value it failed WCAG AA on the two surfaces it is most
    // often drawn on: 4.39 to 1 on the page and 4.38 on the soft accent
    // banners, where 4.5 is the floor. It now reads 4.66 and 4.64.
    //
    // It is a shift nobody can see and it was invisible for another reason
    // too: both failures are in HAPON, the light theme, which is reviewed by
    // eye almost never. palette_contrast_test.dart found all of it in
    // arithmetic on its first run.
    textMuted: Color(0xFF766A5F),
    accent: Color(0xFFB03C09),
    onAccent: Color(0xFFFFFFFF),
    accentSoft: Color(0xFFFFEEDF),
    positive: Color(0xFF16643F),
    positiveSoft: Color(0xFFD9F2E4),
    negative: Color(0xFFB03C09),
    negativeSoft: Color(0xFFFCE3DE),
    // Six points darker than the prototype's #92400E, same date and same
    // reason. This is the PENDING pill's text on the amber chip in Activity
    // (day_group.dart), which measured 4.25 to 1 and now reads 4.62. Its
    // other two surfaces had plenty of room and gained a little as well.
    warning: Color(0xFF8C3A08),
    warningSoft: Color(0xFFFBBF24),
    iconTile: Color(0xFFFFEEDF),
    trackSoft: Color(0xFFFFEEDF),
  );

  /// Gabi, the night theme.
  static const Palette gabi = Palette(
    background: Color(0xFF14100D),
    surface: Color(0xFF1E1915),
    surfaceAlt: Color(0xFF27201A),
    border: Color(0xFF383029),
    borderStrong: Color(0xFF332A22),
    textPrimary: Color(0xFFF6EFE8),
    textSecondary: Color(0xFFC6B8AC),
    textMuted: Color(0xFFA89A8D),
    accent: Color(0xFFFF9A52),
    onAccent: Color(0xFF1E0E03),
    accentSoft: Color(0xFF2A221C),
    positive: Color(0xFF5FCB8E),
    positiveSoft: Color(0xFF17352A),
    negative: Color(0xFFFF9A52),
    negativeSoft: Color(0xFF3A241C),
    warning: Color(0xFFF0B24A),
    warningSoft: Color(0xFF4A3410),
    iconTile: Color(0xFF2A221C),
    trackSoft: Color(0xFF14100D),
  );

  static Palette of(ThemeMode2 mode) => mode == ThemeMode2.hapon ? hapon : gabi;
}

/// The Safe to Spend hero keeps ONE set of colours in both themes, because it
/// is a warm gradient card that does not invert. The prototype draws it the
/// same way and only lays a soft dark veil over it at night.
class HeroColors {
  const HeroColors._();

  static const List<Color> gradient = <Color>[
    Color(0xFFFFD9B0),
    Color(0xFFFEC078),
    Color(0xFFFB9C52),
  ];

  /// The ink used for labels on the gradient.
  static const Color ink = Color(0xFF5E2C08);

  /// The darker ink used for the big peso figure.
  static const Color inkStrong = Color(0xFF2A1207);
}

/// Spacing and radius, so a screen never hard-codes a number.
class Spacing {
  const Spacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
}

class Radii {
  const Radii._();

  static const double card = 24;
  static const double control = 16;
  static const double tile = 12;
  static const double pill = 999;
}
