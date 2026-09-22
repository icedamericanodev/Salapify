// The one progress bar.
//
// Seventeen LinearProgressIndicator sites shipped at four different heights
// (5, 6, 8, 10) behind four different corner radii, and every one of them
// TELEPORTED: adding money to a goal snapped the bar to its new value while
// the milestone confetti animated right beside it. This widget cuts the
// heights to two named sizes and gives the fill the Motion.reveal beat the
// rest of the app's reveals use, snapping instantly under reduce-motion
// through Motion.of like every other animation in the app.
//
// Colors default to the theme (accent fill on a border-colored track) and
// stay overridable, because a bar's color is a meaning decision the screen
// owns: warning for over-budget, celebrate for a finished goal. What a screen
// no longer owns is geometry.

import 'package:flutter/material.dart';

import '../theme.dart';

/// The two sizes a bar ships in. Anything else is drift.
enum ProgressBarSize {
  /// The standard bar (8): goals, budgets, course progress.
  bar(8),

  /// The dense bar (5): progress inside a row or a tight card corner.
  micro(5);

  const ProgressBarSize(this.height);
  final double height;
}

class SalapifyProgressBar extends StatelessWidget {
  /// Fraction complete, 0 to 1. Out-of-range and non-finite values clamp
  /// instead of throwing, because a backup can smuggle any number.
  final double value;

  final ProgressBarSize size;

  /// Fill color. Defaults to the theme accent via the progress theme.
  final Color? color;

  /// Track color. Defaults to the border hairline via the progress theme.
  final Color? trackColor;

  /// What a screen reader should call this bar ("Goal progress"). Required
  /// so a caller has to decide: a determinate LinearProgressIndicator
  /// announces its percentage either way, and a bare nameless "57%" is what
  /// an omitted label produces. Pass null ONLY when the bar sits inside a
  /// MergeSemantics that already names it.
  final String? semanticsLabel;

  // NOT const. build() reads mutable Barako getters, and a const call site
  // would freeze the palette after a theme switch. Same rule as every shared
  // widget here.
  // ignore: prefer_const_constructors_in_immutables
  SalapifyProgressBar({
    super.key,
    required this.value,
    this.size = ProgressBarSize.bar,
    this.color,
    this.trackColor,
    required this.semanticsLabel,
  });

  @override
  Widget build(BuildContext context) {
    final v = value.isFinite ? value.clamp(0.0, 1.0) : 0.0;
    // Tween with no begin: the first build shows the value immediately (a
    // screen opening does not perform an entrance), and every later change
    // animates from where the bar already is.
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: v),
      duration: Motion.of(context, Motion.reveal),
      curve: Motion.curve,
      // Defaults come from the theme's progressIndicatorTheme (accent fill on
      // a border track), not re-spelled here; only an explicit override is
      // passed through. backgroundColor bypasses the theme's linearTrackColor,
      // so it is set only when a caller genuinely overrides the track.
      builder: (context, animated, _) => ClipRRect(
        borderRadius: BorderRadius.circular(Radii.pill),
        child: LinearProgressIndicator(
          value: animated,
          minHeight: size.height,
          backgroundColor: trackColor,
          color: color,
          semanticsLabel: semanticsLabel,
        ),
      ),
    );
  }
}
