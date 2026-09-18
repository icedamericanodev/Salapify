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
    required this.negative,
    required this.warning,
  });

  final Color background;
  final Color surface;
  final Color surfaceAlt;
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
  final Color negative;
  final Color warning;

  /// Hapon, the daylight theme.
  static const Palette hapon = Palette(
    background: Color(0xFFFFF9F3),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFFFEEDF),
    border: Color(0xFFF3DFCD),
    borderStrong: Color(0xFFF0D5C0),
    textPrimary: Color(0xFF15120F),
    textSecondary: Color(0xFF5A5148),
    textMuted: Color(0xFF6B6156),
    accent: Color(0xFFB03C09),
    onAccent: Color(0xFFFFFFFF),
    accentSoft: Color(0xFFFFEEDF),
    positive: Color(0xFF16643F),
    negative: Color(0xFF9E2C1B),
    warning: Color(0xFFB45309),
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
    textMuted: Color(0xFFAC9E92),
    accent: Color(0xFFFF9A52),
    onAccent: Color(0xFF1E0E03),
    accentSoft: Color(0xFF2A221C),
    positive: Color(0xFF5FCB8E),
    negative: Color(0xFFF08A72),
    warning: Color(0xFFF0B24A),
  );

  static Palette of(ThemeMode2 mode) =>
      mode == ThemeMode2.hapon ? hapon : gabi;
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
  static const double pill = 999;
}
