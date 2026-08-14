// A number that rolls up from zero to its value on first build, the same
// TweenAnimationBuilder pattern the Decision Score gauge uses. Pure Dart, so it
// ships over the air. Presentation only: the value passed in is already
// computed; this never changes it.
//
// Accessibility: a screen reader hears the FINAL formatted value, once, not the
// digits rolling by. The animated child is wrapped in ExcludeSemantics and the
// destination string is announced through a sibling Semantics node.

import 'package:flutter/material.dart';

class CountUpText extends StatelessWidget {
  /// The destination value to count up to.
  final double value;

  /// Formats the in-flight value into the string to show (e.g. round to an int,
  /// or run it through formatMoney so the peso figure rolls up).
  final String Function(double) format;

  final TextStyle? style;
  final Duration duration;

  const CountUpText({
    super.key,
    required this.value,
    required this.format,
    this.style,
    this.duration = const Duration(milliseconds: 650),
  });

  @override
  Widget build(BuildContext context) {
    // A malformed stored amount can sum to NaN or Infinity. Clamp to 0 so the
    // cell shows a stable figure instead of "PNaN": a non-finite value also
    // breaks the ValueKey (NaN != NaN), which would restart the roll on every
    // rebuild forever.
    final safe = value.isFinite ? value : 0.0;
    return Semantics(
      value: format(safe),
      child: ExcludeSemantics(
        // Keyed by the destination so a value change re-runs the roll from the
        // current frame, and an unchanged value never re-animates on rebuild.
        child: TweenAnimationBuilder<double>(
          key: ValueKey(safe),
          tween: Tween(begin: 0, end: safe),
          duration: duration,
          curve: Curves.easeOutCubic,
          builder: (context, v, _) =>
              Text(format(v), style: style, maxLines: 1),
        ),
      ),
    );
  }
}
