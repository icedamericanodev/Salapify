import 'package:flutter/material.dart';

import 'tokens.dart';

/// The type scale, named by MEANING rather than by size.
///
/// Every screen before this carried its own inline TextStyle, which is how a
/// heading ends up at 14 on one card and 15 on the next with nobody deciding
/// it. A style here says what a piece of text IS; the numbers are this file's
/// business.
///
/// Sizes are unscaled logical pixels. Flutter applies the phone's own text
/// scaling on top, so a 13 here becomes 19.5 for somebody at 1.5x, and the
/// layouts are tested at that size.
class AppType {
  const AppType._();

  /// The one big number on a screen. Safe to Spend, a payoff total.
  static TextStyle hero(Palette p) => TextStyle(
    fontSize: 36,
    height: 1.1,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.8,
    color: p.textPrimary,
  );

  /// A money figure that leads a card without owning the screen.
  static TextStyle amount(Palette p) => TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w800,
    color: p.textPrimary,
  );

  /// A money figure inside a row or a grid cell.
  static TextStyle amountSmall(Palette p) => TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w800,
    color: p.textPrimary,
  );

  /// A sheet or screen title.
  static TextStyle title(Palette p) => TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.2,
    color: p.textPrimary,
  );

  /// A section heading inside a screen.
  static TextStyle section(Palette p) => TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w800,
    color: p.textPrimary,
  );

  /// The all-caps kicker above a figure. Letter-spaced, because caps without
  /// tracking reads as shouting rather than as a label.
  static TextStyle kicker(Palette p) => TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w800,
    letterSpacing: 1.0,
    color: p.textMuted,
  );

  /// Ordinary sentence text.
  static TextStyle body(Palette p) =>
      TextStyle(fontSize: 13, height: 1.35, color: p.textSecondary);

  /// The strong half of a row, usually a name.
  static TextStyle rowTitle(Palette p) => TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w700,
    color: p.textPrimary,
  );

  /// The quiet half of a row: a category, a date, an account.
  static TextStyle rowMeta(Palette p) =>
      TextStyle(fontSize: 11, color: p.textMuted);

  /// Explanatory text under a control, and the smallest size that ships.
  /// Anything below 11 fails to read on a phone in sunlight.
  static TextStyle caption(Palette p) =>
      TextStyle(fontSize: 11, height: 1.3, color: p.textMuted);

  /// Text on a button or a pill.
  static TextStyle button(Palette p, {Color? color}) => TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w800,
    color: color ?? p.onAccent,
  );

  /// The label on a form field.
  static TextStyle label(Palette p) => TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: p.textSecondary,
  );
}
