// The 1-2-3-4 progress header for the Money Mindset flow: numbered dots joined
// by lines, the current step filled, completed steps ticked, upcoming steps
// quiet. Pure widgets with implicit animation, so a step change eases rather
// than snaps. Ships over the air.
import 'package:flutter/material.dart';

import '../theme.dart';
import '../typography.dart';
import 'salapify_icon.dart';

class MindsetStepIndicator extends StatelessWidget {
  const MindsetStepIndicator({
    super.key,
    required this.current,
    this.total = 4,
  });

  /// 1-based index of the active step.
  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Step $current of $total',
      child: Row(
        children: [
          for (var i = 1; i <= total; i++) ...[
            _dot(context, i),
            if (i < total) Expanded(child: _line(context, i)),
          ],
        ],
      ),
    );
  }

  Widget _dot(BuildContext context, int i) {
    final done = i < current;
    final active = i == current;
    final filled = done || active;
    return AnimatedContainer(
      duration: Motion.of(context, Motion.move),
      curve: Motion.curve,
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled ? Barako.primary : Colors.transparent,
        border: Border.all(
          color: filled ? Barako.primary : Barako.border,
          width: 1.5,
        ),
      ),
      child: Center(
        child: done
            ? Icon(salapifyIcon('done'), size: 15, color: Barako.onPrimary)
            : Text(
                '$i',
                style: AppText.small.w7.tint(
                  active ? Barako.onPrimary : Barako.muted,
                ),
              ),
      ),
    );
  }

  Widget _line(BuildContext context, int i) => AnimatedContainer(
    duration: Motion.of(context, Motion.move),
    curve: Motion.curve,
    height: 2,
    margin: const EdgeInsets.symmetric(horizontal: 6),
    color: i < current ? Barako.primary : Barako.border,
  );
}
