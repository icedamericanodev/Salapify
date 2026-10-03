import 'package:flutter/material.dart';

import 'tokens.dart';

/// The app's ThemeData, in ONE place.
///
/// This exists because main.dart and the screenshot harness each built their
/// own, and they were not the same: main.dart passed a ColorScheme and the
/// harness did not. Nothing in the app reads that ColorScheme today, so the
/// renders happened to be honest, but "happened to be" is not a property worth
/// relying on. A harness that builds a different app from the one that ships
/// can only prove things about an app nobody runs.
ThemeData salapifyTheme(Palette palette, ThemeMode2 mode) {
  return ThemeData(
    useMaterial3: true,
    fontFamily: 'PlusJakartaSans',
    scaffoldBackgroundColor: palette.background,
    colorScheme: ColorScheme.fromSeed(
      seedColor: palette.accent,
      brightness: mode == ThemeMode2.gabi ? Brightness.dark : Brightness.light,
    ),
  );
}
