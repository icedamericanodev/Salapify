// How much of your cash is already promised to something else.
//
// "You can spend ₱468 a day" is a true sentence that hides the interesting
// part: the reason it is not more is that some of the money is already gone in
// every sense except having left the account. A bar shows that in one glance,
// where a sentence makes the reader hold two numbers and subtract.
//
// Deliberately not a chart. Two segments, two labelled amounts, and the same
// plain sentence underneath, because the goal is understanding a division, not
// reading a value off an axis.

import 'package:flutter/material.dart';

import '../theme.dart';
import '../typography.dart';

class SpokenForBar extends StatelessWidget {
  /// Cash already set aside for bills and minimums before the next payday.
  final double committed;

  /// What is genuinely left to live on.
  final double free;

  /// How each amount is rendered. Injected so this widget never owns a second
  /// money formatter: two formatters in one app eventually disagree about a
  /// centavo and the screen shows two versions of the same peso.
  final String Function(num) format;

  // ignore: prefer_const_constructors_in_immutables
  SpokenForBar({
    super.key,
    required this.committed,
    required this.free,
    required this.format,
  });

  @override
  Widget build(BuildContext context) {
    final total = committed + free;
    // A non-finite or empty total would make the flex factors NaN and throw
    // during layout. Junk data must never take a screen down, the same
    // contract formatMoney keeps.
    final safe = total.isFinite && total > 0;
    final committedFlex = safe
        ? (committed / total * 1000).clamp(1, 999).round()
        : 1;
    final freeFlex = safe ? (1000 - committedFlex).clamp(1, 999) : 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(Radii.pill),
          child: SizedBox(
            height: 10,
            child: Row(
              children: [
                Expanded(
                  flex: committedFlex,
                  child: ColoredBox(color: Barako.warning),
                ),
                Expanded(
                  flex: freeFlex,
                  child: ColoredBox(color: Barako.primary),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: Gap.sm),
        _legend(Barako.warning, 'Committed', format(committed)),
        const SizedBox(height: 2),
        _legend(Barako.primary, 'Free to spend', format(free)),
      ],
    );
  }

  Widget _legend(Color swatch, String label, String value) => Row(
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: swatch,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
      const SizedBox(width: Gap.sm),
      // Expanded so a large system font scale grows the label and pushes the
      // amount, rather than overflowing the Row.
      Expanded(child: Text(label, style: AppText.small)),
      Text(value, style: AppText.smallStrong.tabular),
    ],
  );
}
