import 'package:flutter/material.dart';

import '../../design/tokens.dart';
import '../../core/money/format.dart';
import '../../models/models.dart';
import '../../state/financial_state.dart';
import 'home_kit.dart';

/// Latest, ported from src/components/LatestTransactions.tsx.
///
/// Six rows, each carrying the direction arrow, the merchant, the category and
/// the ACCOUNT it moved through. That last one is what makes the row auditable:
/// a figure with no account behind it cannot be checked against anything.
class LatestTransactions extends StatelessWidget {
  const LatestTransactions({super.key, required this.state, this.onSeeAll});

  final FinancialState state;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    final Palette palette = Palette.of(state.theme);
    final List<Transaction> latest = state.latestTransactions.take(6).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text(
              'Latest',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: palette.textPrimary,
              ),
            ),
            const Spacer(),
            SectionLink(palette: palette, label: 'See all', onTap: onSeeAll),
          ],
        ),
        const SizedBox(height: Spacing.sm),
        SectionCard(
          palette: palette,
          padding: EdgeInsets.zero,
          radius: Radii.control,
          child: latest.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(Spacing.xxl),
                  child: Text(
                    'No transactions logged yet. Tap the Log button to add one.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: palette.textMuted),
                  ),
                )
              : Column(
                  children: <Widget>[
                    for (int i = 0; i < latest.length; i++) ...<Widget>[
                      if (i > 0) Divider(height: 1, color: palette.border),
                      _Row(state: state, palette: palette, tx: latest[i]),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.state, required this.palette, required this.tx});

  final FinancialState state;
  final Palette palette;
  final Transaction tx;

  @override
  Widget build(BuildContext context) {
    final bool isIncome = tx.type == TransactionType.income;
    final bool isTransfer = tx.type == TransactionType.transfer;

    final IconData icon = isIncome
        ? Icons.south_west
        : isTransfer
        ? Icons.swap_horiz
        : Icons.north_east;

    return Padding(
      padding: const EdgeInsets.all(Spacing.md),
      child: Row(
        children: <Widget>[
          IconTile(
            palette: palette,
            icon: icon,
            iconSize: 17,
            foreground: isIncome ? palette.positive : palette.textSecondary,
          ),
          const SizedBox(width: Spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  tx.merchant ?? tx.category,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: palette.textPrimary,
                  ),
                ),
                Text(
                  '${tx.category} · ${state.accountShortName(tx.accountId)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: palette.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: Spacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(
                isIncome
                    ? formatSignedPeso(tx.amount, isIncome: true)
                    : formatPeso(tx.amount),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: isIncome ? palette.positive : palette.textPrimary,
                ),
              ),
              Text(
                formatDateLabel(tx.date, now: state.now),
                style: TextStyle(fontSize: 10, color: palette.textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
