import 'package:flutter/material.dart';

import '../../core/money/format.dart';
import '../../core/money/ledger.dart';
import '../../design/tokens.dart';
import '../../design/type.dart';

/// The summary card above the entries list.
///
/// It describes the SCOPED selection, not the type tab below it, so tapping
/// "In" narrows the list without moving these figures. That is deliberate: a
/// card that changes every time a tab is tapped cannot be used to compare
/// anything.
class LedgerSummaryCard extends StatelessWidget {
  const LedgerSummaryCard({
    super.key,
    required this.palette,
    required this.totals,
  });

  final Palette palette;
  final LedgerTotals totals;

  @override
  Widget build(BuildContext context) {
    final bool kept = totals.netMovement >= 0;

    return Container(
      padding: const EdgeInsets.all(Spacing.lg),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('WHAT MOVED', style: AppType.kicker(palette)),
          const SizedBox(height: Spacing.md),

          // Three figures, stacked two-then-one rather than three across. At
          // 320dp three peso amounts side by side are unreadable, which the
          // prototype solves with a responsive grid and a phone cannot.
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Expanded(
                  child: _Figure(
                    palette: palette,
                    label: 'In',
                    amount: totals.totalIn,
                    count: totals.inflowCount,
                    color: palette.positive,
                  ),
                ),
                const SizedBox(width: Spacing.md),
                Expanded(
                  child: _Figure(
                    palette: palette,
                    label: 'Out',
                    amount: totals.totalOut,
                    count: totals.outflowCount,
                    color: palette.negative,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Spacing.md),

          _Figure(
            palette: palette,
            label: kept ? 'Kept' : 'Short by',
            // The sign is carried by the label, so the figure reads as an
            // amount rather than as an equation.
            amount: totals.netMovement.abs(),
            count: totals.transferCount,
            // Only mentioned when there ARE transfers. "0 moves between your
            // own accounts" is a sentence that appears exactly when it has
            // nothing to say, and it sat under the most important figure on
            // the card.
            countLabel: switch (totals.transferCount) {
              0 => 'What came in, less what went out',
              1 => 'Plus 1 move between your own accounts',
              final int n => 'Plus $n moves between your own accounts',
            },
            color: kept ? palette.positive : palette.negative,
          ),
          // Only when there IS money to describe. With a selection holding
          // nothing but a transfer the bar drew 100% green under the words
          // "Nothing came in during this selection", which reads as "you kept
          // everything" over an empty set.
          if (totals.totalIn > 0 || totals.totalOut > 0) ...<Widget>[
            const SizedBox(height: Spacing.lg),
            _ProportionBar(palette: palette, totals: totals),
          ],
        ],
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({
    required this.palette,
    required this.label,
    required this.amount,
    required this.count,
    required this.color,
    this.countLabel,
  });

  final Palette palette;
  final String label;
  final double amount;
  final int count;
  final Color color;
  final String? countLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: AppType.label(palette)),
        const SizedBox(height: 2),
        Text(
          formatPeso(amount),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppType.amountSmall(palette).copyWith(color: color),
        ),
        Text(
          countLabel ?? (count == 1 ? '1 entry' : '$count entries'),
          style: AppType.caption(palette),
        ),
      ],
    );
  }
}

class _ProportionBar extends StatelessWidget {
  const _ProportionBar({required this.palette, required this.totals});

  final Palette palette;
  final LedgerTotals totals;

  @override
  Widget build(BuildContext context) {
    final int out = totals.outflowPercentage;
    final int kept = totals.retentionPercentage;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                totals.totalIn > 0
                    ? '$out% of what came in went back out'
                    : 'Nothing came in during this selection',
                style: AppType.caption(palette),
              ),
            ),
            if (totals.totalIn > 0)
              Text('$kept% kept', style: AppType.label(palette)),
          ],
        ),
        const SizedBox(height: Spacing.sm),
        ClipRRect(
          borderRadius: BorderRadius.circular(Radii.pill),
          // A fixed height, so the bar cannot collapse to nothing under a
          // Row's loose vertical constraints. That exact shape drew an
          // invisible bar on Home once.
          child: SizedBox(
            height: 8,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                if (out > 0)
                  Expanded(
                    flex: out,
                    child: ColoredBox(color: palette.negative),
                  ),
                if (100 - out > 0)
                  Expanded(
                    flex: 100 - out,
                    child: ColoredBox(color: palette.positiveSoft),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
