// The logging chain card: seven dots for the last seven days, a check where
// a day was logged, and one line that meets the user where they are. The
// state comes from money/chain.dart; this file only draws it.
//
// The RN version pops the dots with springs and is NOT reduce-motion aware
// there; this port draws statically on purpose. The moment stays calm, the
// patch stays small, and motion can join the mascot work later if the
// founder wants it.

import 'package:flutter/material.dart';

import '../money/chain.dart';
import '../theme.dart';

class WeekChainCard extends StatelessWidget {
  final dynamic transactions;

  /// Injectable clock, the overview.dart seam pattern, so a test can pin
  /// the week instead of inheriting whatever day the suite runs.
  final DateTime Function() clock;

  // ignore: prefer_const_constructors_in_immutables
  WeekChainCard({
    super.key,
    required this.transactions,
    this.clock = DateTime.now,
  });

  @override
  Widget build(BuildContext context) {
    final s = chainState(transactions, clock());
    // The gold is earned: celebrate only at 7 for 7, the reserved-token rule.
    final full = s.fullWeek;
    return Card(
      shape: full
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Radii.lg),
              side: BorderSide(color: Barako.celebrate),
            )
          : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('LOGGING CHAIN', style: Barako.cardKickerStyle),
            const SizedBox(height: Gap.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final d in s.days)
                  Column(
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: d.done ? Barako.primary : null,
                          border: Border.all(
                            color: d.done
                                ? Barako.primary
                                // Today-not-yet: the primary ring marks the
                                // dot waiting for its check. RN dashes this
                                // border; a solid ring reads the same and
                                // needs no custom painter.
                                : d.isToday
                                ? Barako.primary
                                : Barako.border,
                            width: 1.5,
                          ),
                        ),
                        child: d.done
                            ? ExcludeSemantics(
                                child: Icon(
                                  Icons.check,
                                  size: 16,
                                  color: Barako.onPrimary,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(height: Gap.xs),
                      Text(
                        d.letter,
                        style: TextStyle(
                          color: d.isToday ? Barako.primaryText : Barako.muted,
                          fontSize: 11,
                          fontWeight: d.isToday
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: Gap.md),
            Text(
              s.message,
              style: TextStyle(
                color: full ? Barako.celebrate : Barako.textSecondary,
                fontSize: 13,
                height: 1.4,
                fontWeight: full ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
