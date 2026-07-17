// The Barako brand palette, ported from mobile/theme.js and given the
// coffee-shop polish pass the founder asked for: aesthetic, neat, clean,
// warm. Dark roast espresso base, roasted orange doing the dopamine work,
// warm caramel and amber for kickers and wins. Warning stays rose crimson
// and is reserved for debt and over limit states. The component themes
// below are what make every screen feel like one calm cafe: soft 20px
// radii, hairline borders instead of harsh outlines, floating rounded
// snackbars, a pill navigation indicator, and a warm ripple.
//
// A custom display font is an ASSET and assets cannot ride in a Shorebird
// patch (the f0.14 lesson); typography personality beyond weights and
// letterspacing waits for the next base APK and gets flagged loudly.

import 'package:flutter/material.dart';

class Barako {
  static const background = Color(0xFF17110C);
  static const card = Color(0xFF231810);
  static const surfaceRaised = Color(0xFF2C1F16);
  static const border = Color(0xFF35261B);
  static const primary = Color(0xFFFF8A3D);
  static const caramel = Color(0xFFE9BC8E);
  static const text = Color(0xFFFBF3E9);
  static const textSecondary = Color(0xFFE0CEBB);
  static const muted = Color(0xFFA99182);
  static const faint = Color(0xFF97806F);
  static const warning = Color(0xFFFF5D73);
  static const warningStrong = Color(0xFFF5384F);
  static const onPrimary = Color(0xFF2A1305);
  static const celebrate = Color(0xFFFFC24D);
}

ThemeData barakoDarkTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: Barako.background,
    colorScheme: const ColorScheme.dark(
      primary: Barako.primary,
      onPrimary: Barako.onPrimary,
      surface: Barako.card,
      onSurface: Barako.text,
      secondary: Barako.caramel,
      onSecondary: Barako.onPrimary,
      error: Barako.warning,
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
      backgroundColor: Barako.surfaceRaised,
      contentTextStyle: const TextStyle(color: Barako.text, fontSize: 14),
      actionTextColor: Barako.primary,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Barako.border),
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
        textStyle:
            const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.2),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: Barako.border),
        foregroundColor: Barako.textSecondary,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: Barako.primary,
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Barako.card,
      side: const BorderSide(color: Barako.border),
      labelStyle: const TextStyle(
          color: Barako.textSecondary, fontWeight: FontWeight.w600),
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
      hintStyle: const TextStyle(color: Barako.faint),
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
