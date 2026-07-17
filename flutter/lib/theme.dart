// Kape Latte: the founder-chosen light theme (2026-07-17, option B of the
// rendered panel). The Barako brand keeps its name and its roasted orange,
// but the surfaces flip to steamed milk: cream background, warm white
// cards, espresso ink text. Type carries the coffee shop personality:
// Fraunces (a soft serif) on display money, Plus Jakarta Sans everywhere
// else. Warning stays rose crimson, darkened for contrast on cream, and is
// reserved for debt and over limit states.
//
// The fonts are bundled ASSETS, which cannot ride in a Shorebird patch, so
// this theme shipped with the 0.2.0+3 base APK (one manual install).

import 'package:flutter/material.dart';

class Barako {
  static const background = Color(0xFFF5EDE2);
  static const card = Color(0xFFFFFAF2);
  static const surfaceRaised = Color(0xFFFFF6EA);
  static const border = Color(0xFFE7DACA);
  static const primary = Color(0xFFC75B12);
  static const caramel = Color(0xFFB98A55);
  static const text = Color(0xFF2B1A0E);
  static const textSecondary = Color(0xFF5C4632);
  static const muted = Color(0xFF8A7460);
  static const faint = Color(0xFFA08468);
  static const warning = Color(0xFFD93A52);
  static const warningStrong = Color(0xFFC22B42);
  static const onPrimary = Color(0xFFFFF6EA);
  static const celebrate = Color(0xFFB97F1F);

  /// The display serif for big peso amounts (Fraunces). Body text inherits
  /// Jakarta from the ThemeData fontFamily.
  static const displayFont = 'Fraunces';
}

ThemeData kapeLatteTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    fontFamily: 'Jakarta',
    scaffoldBackgroundColor: Barako.background,
    colorScheme: const ColorScheme.light(
      primary: Barako.primary,
      onPrimary: Barako.onPrimary,
      surface: Barako.card,
      onSurface: Barako.text,
      secondary: Barako.caramel,
      onSecondary: Barako.onPrimary,
      error: Barako.warningStrong,
    ),
    splashColor: Barako.primary.withValues(alpha: 0.08),
    highlightColor: Barako.primary.withValues(alpha: 0.05),
    cardTheme: const CardThemeData(
      color: Barako.card,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(20)),
        side: BorderSide(color: Barako.border),
      ),
    ),
    dividerColor: Barako.border,
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Barako.card,
      indicatorColor: Barako.primary,
      height: 68,
      surfaceTintColor: Colors.transparent,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontFamily: 'Jakarta',
          fontSize: 11,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w800
              : FontWeight.w600,
          letterSpacing: 0.3,
          color: states.contains(WidgetState.selected)
              ? Barako.text
              : Barako.muted,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          size: 22,
          color: states.contains(WidgetState.selected)
              ? Barako.onPrimary
              : Barako.muted,
        ),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: Barako.text,
      contentTextStyle: const TextStyle(
          fontFamily: 'Jakarta', color: Barako.card, fontSize: 14),
      actionTextColor: Barako.celebrate,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: Barako.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(20)),
        side: BorderSide(color: Barako.border),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Barako.primary,
        foregroundColor: Barako.onPrimary,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(
            fontFamily: 'Jakarta',
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: Barako.border),
        foregroundColor: Barako.textSecondary,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(
            fontFamily: 'Jakarta', fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: Barako.primary,
        textStyle: const TextStyle(
            fontFamily: 'Jakarta', fontWeight: FontWeight.w700),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Barako.background,
      side: const BorderSide(color: Barako.border),
      labelStyle: const TextStyle(
          fontFamily: 'Jakarta',
          color: Barako.textSecondary,
          fontWeight: FontWeight.w600),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      showCheckmark: false,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: Barako.primary,
      linearTrackColor: Barako.border,
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: Barako.primary,
      foregroundColor: Barako.onPrimary,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Barako.background,
      hintStyle:
          const TextStyle(fontFamily: 'Jakarta', color: Barako.faint),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Barako.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Barako.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Barako.primary, width: 1.4),
      ),
    ),
  );
}
