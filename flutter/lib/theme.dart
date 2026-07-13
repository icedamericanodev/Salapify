// The Barako brand palette, ported from mobile/theme.js so the Flutter app
// looks like Salapify from the first build. Dark roast espresso base, roasted
// orange doing the dopamine work, warm caramel and amber for kickers and wins.
// Warning stays rose crimson and is reserved for debt and over limit states.

import 'package:flutter/material.dart';

class Barako {
  static const background = Color(0xFF1A130E);
  static const card = Color(0xFF251A13);
  static const surfaceRaised = Color(0xFF2E211A);
  static const border = Color(0xFF3A2A20);
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
      error: Barako.warning,
    ),
    cardTheme: const CardThemeData(
      color: Barako.card,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
        side: BorderSide(color: Barako.border),
      ),
    ),
    dividerColor: Barako.border,
  );
}
