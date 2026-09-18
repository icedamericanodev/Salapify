import 'package:flutter/material.dart';

import '../../core/money/format.dart';
import '../../core/money/ledger.dart';
import '../../design/tokens.dart';
import '../../design/type.dart';
import '../../models/models.dart';
import 'activity_screen.dart' show statusLabel, statusIsStruckThrough;

/// One day of entries: a header saying what day it is and what left that day,
/// then the rows.
class DayGroup extends StatelessWidget {
  const DayGroup({
    super.key,
    required this.palette,
    required this.day,
    required this.accounts,
    required this.now,
  });

  final Palette palette;
  final LedgerDay day;
  final List<Account> accounts;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    // Only what actually counts. A day whose single entry is excluded should
    // not claim money left, which is the whole point of marking it excluded.
    final double dayOut = day.transactions
        .where((Transaction t) =>
            t.type == TransactionType.expense && t.countsTowardTotals)
        .fold<double>(0, (double s, Transaction t) => s + t.amount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  formatDateLabel(day.date, now: now),
                  style: AppType.label(palette),
                ),
              ),
              if (dayOut > 0)
                Text(
                  'Out: ${formatPeso(dayOut)}',
                  style: AppType.caption(palette),
                ),
            ],
          ),
        ),
        const SizedBox(height: Spacing.sm),
        Container(
          decoration: BoxDecoration(
            color: palette.card,
            borderRadius: BorderRadius.circular(Radii.card),
            border: Border.all(color: palette.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: <Widget>[
              for (int i = 0; i < day.transactions.length; i++) ...<Widget>[
                if (i > 0) Divider(height: 1, color: palette.border),
                TransactionRow(
                  palette: palette,
                  transaction: day.transactions[i],
                  accounts: accounts,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class TransactionRow extends StatelessWidget {
  const TransactionRow({
    super.key,
    required this.palette,
    required this.transaction,
    required this.accounts,
  });

  final Palette palette;
  final Transaction transaction;
  final List<Account> accounts;

  Account? _account(String? id) {
    if (id == null) return null;
    for (final Account a in accounts) {
      if (a.id == id) return a;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final Transaction t = transaction;
    final bool isIncome = t.type == TransactionType.income;
    final bool isTransfer = t.type == TransactionType.transfer;
    final bool struck = statusIsStruckThrough(t.status);

    final Account? from = _account(t.accountId);
    final Account? to = _account(t.toAccountId);

    final IconData icon = isIncome
        ? Icons.south_west
        : isTransfer
            ? Icons.swap_horiz
            : Icons.north_east;

    return Padding(
      padding: const EdgeInsets.all(Spacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: palette.iconTile,
              borderRadius: BorderRadius.circular(Radii.tile),
            ),
            child: Icon(
              icon,
              size: 17,
              color: isIncome ? palette.positive : palette.textSecondary,
            ),
          ),
          const SizedBox(width: Spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        // The merchant is what a person recognises. The
                        // category is the fallback, not the headline.
                        t.merchant ?? t.category,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.rowTitle(palette),
                      ),
                    ),
                    if (t.status != TransactionStatus.confirmed) ...<Widget>[
                      const SizedBox(width: Spacing.sm),
                      _StatusChip(palette: palette, status: t.status),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  _subtitle(t, from, to, isTransfer),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.rowMeta(palette),
                ),
              ],
            ),
          ),
          const SizedBox(width: Spacing.sm),
          Text(
            isIncome
                ? '+${formatPeso(t.amount)}'
                : formatPeso(t.amount),
            style: AppType.amountSmall(palette).copyWith(
              fontSize: 14,
              color: struck
                  ? palette.textMuted
                  : isIncome
                      ? palette.positive
                      : palette.textPrimary,
              decoration: struck ? TextDecoration.lineThrough : null,
              decorationColor: palette.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  String _subtitle(
    Transaction t,
    Account? from,
    Account? to,
    bool isTransfer,
  ) {
    final StringBuffer b = StringBuffer(t.category);
    b.write(' · ');
    b.write(from?.name ?? 'Account');
    if (isTransfer && to != null) {
      b.write(' → ');
      b.write(to.name);
    }
    if (t.person != null) {
      b.write(' · ');
      b.write(t.person);
    }
    return b.toString();
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.palette, required this.status});

  final Palette palette;
  final TransactionStatus status;

  @override
  Widget build(BuildContext context) {
    // Three meanings, three colours. Pending is a warning because it is
    // money that has not settled; excluded and duplicate are muted because
    // they are deliberately out of the totals and should not shout.
    final (Color fg, Color bg) = switch (status) {
      TransactionStatus.pending => (palette.warning, palette.warningSoft),
      TransactionStatus.duplicate => (palette.negative, palette.negativeSoft),
      TransactionStatus.corrected => (palette.accent, palette.accentSoft),
      TransactionStatus.reconciled => (palette.positive, palette.positiveSoft),
      _ => (palette.textMuted, palette.surfaceAlt),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      child: Text(
        statusLabel(status).toUpperCase(),
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
          color: fg,
        ),
      ),
    );
  }
}
