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
import '../typography.dart';
import '../widgets/salapify_icon.dart';

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
        // Densified in the Phase 3 pass: the habit strip earns its slot by
        // changing daily, not by being tall. Smaller dots and tighter gaps
        // took the card from ~140dp toward ~110 with every piece of
        // information kept: seven days, their letters, today's ring, the
        // message that meets the user where they are.
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('LOGGING CHAIN', style: Barako.cardKickerStyle),
            const SizedBox(height: Gap.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final d in s.days)
                  Column(
                    children: [
                      Container(
                        width: 26,
                        height: 26,
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
                                  salapifyIcon('check'),
                                  size: 14,
                                  color: Barako.onPrimary,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(height: Gap.xs),
                      Text(
                        d.letter,
                        style: AppText.micro.copyWith(
                          color: d.isToday ? Barako.primaryText : Barako.muted,
                          fontWeight: d.isToday
                              ? TypeWeight.bold
                              : TypeWeight.medium,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: Gap.sm),
            Text(
              s.message,
              style: AppText.small.copyWith(
                color: full ? Barako.celebrate : Barako.textSecondary,
                height: 1.4,
                fontWeight: full ? TypeWeight.medium : TypeWeight.regular,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
