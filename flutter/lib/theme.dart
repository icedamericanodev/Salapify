// The Salapify mood themes. The founder picked Kape Latte as the default
// (2026-07-17) and asked for mood switching, so the palette became an
// instance: three coffee-family moods share the Barako brand's roasted
// orange spine and the Fraunces plus Jakarta type pairing. Colors are pure
// Dart, so new moods ship as ordinary patches; only the FONTS needed the
// 0.2.1+4 base APK.
//
// Barako stays the color namespace every screen reads (Barako.text and so
// on), but the members are now getters over the active palette, switched
// from settings.themeMood and rebuilt from the app root. That is why the
// screens avoid const on color-bearing widgets: const would freeze the
// mood at compile time (see analysis_options.yaml).

import 'package:flutter/material.dart';

class BarakoPalette {
  final String mood; // stored in settings.themeMood
  final String label;
  final Brightness brightness;
  final Color background;
  final Color card;
  final Color surfaceRaised;
  final Color border;
  final Color primary;
  // A darker roast of the brand orange for SMALL text and links, where the
  // hero-size primary would fail AA against a light card. On the dark moods
  // it is the same as primary (which already passes small there).
  final Color primaryText;
  final Color caramel;
  final Color text;
  final Color textSecondary;
  final Color muted;
  final Color faint;
  final Color warning;
  final Color warningStrong;
  final Color onPrimary;
  final Color celebrate;

  const BarakoPalette({
    required this.mood,
    required this.label,
    required this.brightness,
    required this.background,
    required this.card,
    required this.surfaceRaised,
    required this.border,
    required this.primary,
    required this.primaryText,
    required this.caramel,
    required this.text,
    required this.textSecondary,
    required this.muted,
    required this.faint,
    required this.warning,
    required this.warningStrong,
    required this.onPrimary,
    required this.celebrate,
  });
}

/// Kape Latte: the founder-chosen default. Steamed milk, espresso ink.
const lattePalette = BarakoPalette(
  mood: 'latte',
  label: '☕ Latte',
  brightness: Brightness.light,
  background: Color(0xFFF5EDE2),
  card: Color(0xFFFFFAF2),
  surfaceRaised: Color(0xFFFFF6EA),
  border: Color(0xFFE7DACA),
  primary: Color(0xFFC75B12),
  // A darker roast for small text; the hero orange fails AA at 11-13px on
  // the light card, this passes (~4.9:1).
  primaryText: Color(0xFFA8480C),
  caramel: Color(0xFFB98A55),
  text: Color(0xFF2B1A0E),
  textSecondary: Color(0xFF5C4632),
  // Darkened for AA at the 11-13px sizes these are used at on the light
  // card (the old #8A7460 / #A08468 were ~4.1 and ~3.3, below 4.5).
  muted: Color(0xFF6E5945),
  faint: Color(0xFF836A52),
  warning: Color(0xFFD93A52),
  warningStrong: Color(0xFFC22B42),
  onPrimary: Color(0xFFFFF6EA),
  celebrate: Color(0xFFB97F1F),
);

/// Barako: the original dark roast, for late night logging.
const barakoPalette = BarakoPalette(
  mood: 'barako',
  label: '🌙 Barako',
  brightness: Brightness.dark,
  background: Color(0xFF17110C),
  card: Color(0xFF231810),
  surfaceRaised: Color(0xFF2C1F16),
  border: Color(0xFF35261B),
  primary: Color(0xFFFF8A3D),
  primaryText: Color(0xFFFF8A3D),
  caramel: Color(0xFFE9BC8E),
  text: Color(0xFFFBF3E9),
  textSecondary: Color(0xFFE0CEBB),
  muted: Color(0xFFA99182),
  faint: Color(0xFF97806F),
  warning: Color(0xFFFF5D73),
  warningStrong: Color(0xFFF5384F),
  onPrimary: Color(0xFF2A1305),
  celebrate: Color(0xFFFFC24D),
);

/// Milk Tea: the soft warm middle, honey amber on mocha.
const milkTeaPalette = BarakoPalette(
  mood: 'milktea',
  label: '🧋 Milk Tea',
  brightness: Brightness.dark,
  background: Color(0xFF2B211B),
  card: Color(0xFF382C24),
  surfaceRaised: Color(0xFF423429),
  border: Color(0xFF4A3A2E),
  primary: Color(0xFFF2B04E),
  primaryText: Color(0xFFF2B04E),
  caramel: Color(0xFFD9B98A),
  text: Color(0xFFF7EDDF),
  textSecondary: Color(0xFFE5D5C2),
  muted: Color(0xFFB49C87),
  faint: Color(0xFFAB937D),
  warning: Color(0xFFFF5D73),
  warningStrong: Color(0xFFF5384F),
  onPrimary: Color(0xFF33230F),
  celebrate: Color(0xFFFFC24D),
);

const List<BarakoPalette> moodPalettes = [
  lattePalette,
  barakoPalette,
  milkTeaPalette,
];

BarakoPalette paletteForMood(dynamic mood) {
  for (final p in moodPalettes) {
    if (p.mood == mood) return p;
  }
  return lattePalette;
}

/// The color namespace every screen reads. Members are getters over the
/// active palette so a mood switch repaints the whole app on rebuild.
class Barako {
  static BarakoPalette current = lattePalette;

  static Color get background => current.background;
  static Color get card => current.card;
  static Color get surfaceRaised => current.surfaceRaised;
  static Color get border => current.border;
  static Color get primary => current.primary;
  static Color get primaryText => current.primaryText;
  static Color get caramel => current.caramel;
  static Color get text => current.text;
  static Color get textSecondary => current.textSecondary;
  static Color get muted => current.muted;
  static Color get faint => current.faint;
  static Color get warning => current.warning;
  static Color get warningStrong => current.warningStrong;
  static Color get onPrimary => current.onPrimary;
  static Color get celebrate => current.celebrate;

  /// The display serif for big peso amounts (Fraunces).
  static const displayFont = 'Fraunces';

  /// The one section-label style for the little uppercase kicker above a
  /// card's content. Not const: it carries the mood-driven muted color.
  static TextStyle get kickerStyle => TextStyle(
        color: current.muted,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 2,
      );
}

/// The theme for one mood palette.
ThemeData salapifyTheme([BarakoPalette? palette]) {
  final p = palette ?? Barako.current;
  final isLight = p.brightness == Brightness.light;
  final scheme = isLight
      ? ColorScheme.light(
          primary: p.primary,
          onPrimary: p.onPrimary,
          surface: p.card,
          onSurface: p.text,
          secondary: p.caramel,
          onSecondary: p.onPrimary,
          error: p.warningStrong,
        )
      : ColorScheme.dark(
          primary: p.primary,
          onPrimary: p.onPrimary,
          surface: p.card,
          onSurface: p.text,
          secondary: p.caramel,
          onSecondary: p.onPrimary,
          error: p.warning,
        );
  return ThemeData(
    useMaterial3: true,
    brightness: p.brightness,
    fontFamily: 'Jakarta',
    scaffoldBackgroundColor: p.background,
    colorScheme: scheme,
    splashColor: p.primary.withValues(alpha: 0.08),
    highlightColor: p.primary.withValues(alpha: 0.05),
    cardTheme: CardThemeData(
      color: p.card,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radius.circular(20)),
        side: BorderSide(color: p.border),
      ),
    ),
    dividerColor: p.border,
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: p.card,
      indicatorColor: p.primary,
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
          color: states.contains(WidgetState.selected) ? p.text : p.muted,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          size: 22,
          color:
              states.contains(WidgetState.selected) ? p.onPrimary : p.muted,
        ),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: isLight ? p.text : p.surfaceRaised,
      contentTextStyle: TextStyle(
          fontFamily: 'Jakarta',
          color: isLight ? p.card : p.text,
          fontSize: 14),
      actionTextColor: p.celebrate,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: isLight ? BorderSide.none : BorderSide(color: p.border),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: p.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radius.circular(20)),
        side: BorderSide(color: p.border),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: p.primary,
        foregroundColor: p.onPrimary,
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
        side: BorderSide(color: p.border),
        foregroundColor: p.textSecondary,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(
            fontFamily: 'Jakarta', fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: p.primary,
        textStyle: const TextStyle(
            fontFamily: 'Jakarta', fontWeight: FontWeight.w700),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: p.background,
      side: BorderSide(color: p.border),
      labelStyle: TextStyle(
          fontFamily: 'Jakarta',
          color: p.textSecondary,
          fontWeight: FontWeight.w600),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      showCheckmark: false,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: p.primary,
      linearTrackColor: p.border,
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: p.primary,
      foregroundColor: p.onPrimary,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.background,
      hintStyle: TextStyle(fontFamily: 'Jakarta', color: p.faint),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: p.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: p.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: p.primary, width: 1.4),
      ),
    ),
  );
}

/// Kept for callers and tests that want the default explicitly.
ThemeData kapeLatteTheme() => salapifyTheme(lattePalette);
