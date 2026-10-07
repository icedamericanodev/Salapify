// SalapifyColors: a ThemeExtension surface over the app's palette.
//
// WHY THIS EXISTS, and what it is NOT. The app's screens read the Barako palette
// (theme.dart), which carries nineteen semantic roles and is guarded by
// palette_contrast_test (every colour pair clears WCAG AA in every theme) and by
// the theme-invariant win gold. This file does NOT replace that. It is the
// forward-facing ThemeExtension the founder asked for: a smaller, context-read
// surface that NEW widgets can use via SalapifyColors.of(context), sourced live
// from the active Barako palette (see salapifyTheme() in theme.dart, which
// registers it). Old screens keep reading Barako; new ones may read this; the
// two never disagree because both come from the same active palette.
//
// The four modern presets below (Palawan Lagoon, Mayon Sunset, BGC Obsidian,
// Pearl) are the design source for the matching Barako themes added to the
// registry, plus barakoClassic for the brand default. They are AA-checked design
// references; the values the app actually paints are the Barako palettes those
// themes carry, which the contrast guard proves.

import 'package:flutter/material.dart';

/// The named looks. Each maps to a Barako theme in the registry (theme.dart).
enum SalapifyThemePreset {
  palawanLagoon,
  mayonSunset,
  bgcObsidian,
  pearlMinimalist,
  barakoClassic,
}

@immutable
class SalapifyColors extends ThemeExtension<SalapifyColors> {
  final Color primary;
  final Color secondary;
  final Color background;
  final Color surface;
  final Color surfaceSubtle;
  final Color textPrimary;
  final Color textSecondary;
  final Color cardBorder;
  final Color accentSuccess;
  final Color accentDanger;

  const SalapifyColors({
    required this.primary,
    required this.secondary,
    required this.background,
    required this.surface,
    required this.surfaceSubtle,
    required this.textPrimary,
    required this.textSecondary,
    required this.cardBorder,
    required this.accentSuccess,
    required this.accentDanger,
  });

  /// The active colours, read from the theme. Falls back to the Palawan preset
  /// only if no extension was registered (should not happen in the real app,
  /// which always registers one from the active Barako palette).
  static SalapifyColors of(BuildContext context) {
    return Theme.of(context).extension<SalapifyColors>() ?? palawanLagoon;
  }

  /// The preset a name refers to, or null. Used by the design reference and
  /// tests; the app selects looks through the Barako theme picker.
  static SalapifyColors? preset(SalapifyThemePreset p) => _presets[p];

  // 1. Palawan Lagoon (default modern emerald)
  static const palawanLagoon = SalapifyColors(
    primary: Color(0xFF00E5A3),
    secondary: Color(0xFF00B4D8),
    background: Color(0xFF0B131F),
    surface: Color(0xFF131F30),
    surfaceSubtle: Color(0xFF1B2C44),
    textPrimary: Color(0xFFF8FAFC),
    textSecondary: Color(0xFFC4D2E0),
    cardBorder: Color(0xFF1E3A5F),
    accentSuccess: Color(0xFF10B981),
    accentDanger: Color(0xFFF87086),
  );

  // 2. Mayon Sunset (warm coral)
  static const mayonSunset = SalapifyColors(
    primary: Color(0xFFF27457),
    secondary: Color(0xFFFFAA5A),
    background: Color(0xFF140E1B),
    surface: Color(0xFF22172C),
    surfaceSubtle: Color(0xFF31223E),
    textPrimary: Color(0xFFFFF1F2),
    textSecondary: Color(0xFFFDA4AF),
    cardBorder: Color(0xFF3A2A45),
    accentSuccess: Color(0xFF34D399),
    accentDanger: Color(0xFFF87086),
  );

  // 3. BGC Obsidian (neo cyan on near black). textSecondary lifted from the
  // spec's 0xFF64748B, which measured 4.18:1 on this background (under the 4.5
  // AA bar), to a light slate that clears it.
  static const bgcObsidian = SalapifyColors(
    primary: Color(0xFF00F0FF),
    secondary: Color(0xFF7000FF),
    background: Color(0xFF07090E),
    surface: Color(0xFF0F141C),
    surfaceSubtle: Color(0xFF171F2C),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFFAEBAC9),
    cardBorder: Color(0xFF1E293B),
    accentSuccess: Color(0xFF00F0FF),
    accentDanger: Color(0xFFFF6B81),
  );

  // 4. Pearl (light minimalist)
  static const pearlMinimalist = SalapifyColors(
    primary: Color(0xFF005CEE),
    secondary: Color(0xFF0D9488),
    background: Color(0xFFF8FAFC),
    surface: Color(0xFFFFFFFF),
    surfaceSubtle: Color(0xFFF1F5F9),
    textPrimary: Color(0xFF0F172A),
    textSecondary: Color(0xFF55606E),
    cardBorder: Color(0xFFE2E8F0),
    accentSuccess: Color(0xFF059669),
    accentDanger: Color(0xFFC81E1E),
  );

  // 5. Barako Classic (the brand default), so the enum is whole.
  static const barakoClassic = SalapifyColors(
    primary: Color(0xFFFF7A45),
    secondary: Color(0xFFE9BC8E),
    background: Color(0xFF0F0F0F),
    surface: Color(0xFF1C1A17),
    surfaceSubtle: Color(0xFF2A231D),
    textPrimary: Color(0xFFF5EDE1),
    textSecondary: Color(0xFFD9C8B6),
    cardBorder: Color(0xFF3D3126),
    accentSuccess: Color(0xFF10B981),
    accentDanger: Color(0xFFFF5D73),
  );

  static const Map<SalapifyThemePreset, SalapifyColors> _presets = {
    SalapifyThemePreset.palawanLagoon: palawanLagoon,
    SalapifyThemePreset.mayonSunset: mayonSunset,
    SalapifyThemePreset.bgcObsidian: bgcObsidian,
    SalapifyThemePreset.pearlMinimalist: pearlMinimalist,
    SalapifyThemePreset.barakoClassic: barakoClassic,
  };

  @override
  SalapifyColors copyWith({
    Color? primary,
    Color? secondary,
    Color? background,
    Color? surface,
    Color? surfaceSubtle,
    Color? textPrimary,
    Color? textSecondary,
    Color? cardBorder,
    Color? accentSuccess,
    Color? accentDanger,
  }) {
    return SalapifyColors(
      primary: primary ?? this.primary,
      secondary: secondary ?? this.secondary,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceSubtle: surfaceSubtle ?? this.surfaceSubtle,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      cardBorder: cardBorder ?? this.cardBorder,
      accentSuccess: accentSuccess ?? this.accentSuccess,
      accentDanger: accentDanger ?? this.accentDanger,
    );
  }

  @override
  SalapifyColors lerp(ThemeExtension<SalapifyColors>? other, double t) {
    if (other is! SalapifyColors) return this;
    return SalapifyColors(
      primary: Color.lerp(primary, other.primary, t)!,
      secondary: Color.lerp(secondary, other.secondary, t)!,
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceSubtle: Color.lerp(surfaceSubtle, other.surfaceSubtle, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      cardBorder: Color.lerp(cardBorder, other.cardBorder, t)!,
      accentSuccess: Color.lerp(accentSuccess, other.accentSuccess, t)!,
      accentDanger: Color.lerp(accentDanger, other.accentDanger, t)!,
    );
  }
}
