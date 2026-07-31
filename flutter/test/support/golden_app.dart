// The MaterialApp every golden and screenshot render should be built with.
//
// Two things it fixes that a bare MaterialApp does not:
//
//  1. debugShowCheckedModeBanner: false. Goldens render in debug mode, where a
//     MaterialApp paints the red DEBUG ribbon in the top-right corner. The
//     production app already turns it off (main.dart), but the harnesses each
//     hand-rolled their own MaterialApp and none of them did, so every shot
//     carried the ribbon. A ribbon in a pixel baseline is a diff waiting to
//     move the day Flutter restyles it.
//  2. themeAnimationStyle: AnimationStyle.noAnimation, the same as main.dart, so
//     a theme colour never animates mid-capture.
//
// Locale and text direction are fixed here too, so a golden does not depend on
// the machine's locale. The palette still comes from Barako.current, which the
// caller resolves to the brightness under test before pumping.

import 'package:flutter/material.dart';
import 'package:salapify/theme.dart';

/// A deterministic MaterialApp for renders. Pass the screen as [home]. The
/// [textScale] is injected ABOVE the navigator via the app builder, so a pushed
/// modal (a bottom sheet) inherits it too, not just the home subtree.
Widget goldenApp({
  required Widget home,
  Locale locale = const Locale('en'),
  double textScale = 1.0,
}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    themeAnimationStyle: AnimationStyle.noAnimation,
    theme: salapifyTheme(Barako.current),
    locale: locale,
    // A single supported locale so the app never resolves to the host's.
    supportedLocales: const [Locale('en')],
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: home,
  );
}
