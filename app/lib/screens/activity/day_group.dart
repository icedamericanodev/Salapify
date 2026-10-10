import 'package:flutter/material.dart';

import '../../core/money/format.dart';
import '../../core/money/ledger.dart';
import '../../design/tokens.dart';
import '../../design/type.dart';
import '../../models/models.dart';
import '../../state/financial_state.dart';
import 'activity_screen.dart' show statusLabel, statusIsStruckThrough;
import 'transaction_detail_sheet.dart';

/// One day of entries: a header saying what day it is and what left that day,
/// then the rows.
class DayGroup extends StatelessWidget {
  const DayGroup({
    super.key,
    required this.palette,
    required this.day,
    required this.state,
    required this.accounts,
    required this.now,
  });

  final Palette palette;
  final LedgerDay day;

  /// Passed through to the detail sheet, which can now take an entry back.
  final FinancialState state;

  final List<Account> accounts;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    // Only what actually counts. A day whose single entry is excluded should
    // not claim money left, which is the whole point of marking it excluded.
    final double dayOut = day.transactions
        .where(
          (Transaction t) =>
              t.type == TransactionType.expense && t.countsTowardTotals,
        )
        .fold<double>(0, (double s, Transaction t) => s + t.amount.pesos);

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
                  state: state,
                  accounts: accounts,
                  now: now,
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
    required this.state,
    required this.accounts,
    required this.now,
  });

  final Palette palette;
  final Transaction transaction;

  /// Passed through to the detail sheet this row opens.
  final FinancialState state;

  final List<Account> accounts;
  final DateTime now;

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
    // A repayment from a friend is a transfer, but it is money arriving, so
    // it wears income's plus sign and colour (D35).
    final bool isIncome =
        t.type == TransactionType.income || t.arrivesFromOutside;
    final bool isTransfer = t.type == TransactionType.transfer;
    final bool struck = statusIsStruckThrough(t.status);

    final Account? from = _account(t.accountId);
    final Account? to = _account(t.toAccountId);

    final IconData icon = isIncome
        ? Icons.south_west
        : isTransfer
        ? Icons.swap_horiz
        : Icons.north_east;

    // THE CATEGORY'S OWN EMOJI, when there is one. The UI review of
    // 2026-10-07 found every spending row wearing the same arrow, so a day of
    // food, fares and bills was a column of identical tiles and the eye had
    // nothing to scan by. The emoji is the user's category icon, user data in
    // their backup, so it stays an emoji rather than becoming a Salapify
    // glyph (see design/salapify_icon.dart). Direction is not lost: income
    // still carries its "+" and its green figure on the right. A transfer
    // keeps the swap arrow because it has no category worth showing, and an
    // entry whose category is unknown keeps the arrow it always had.
    final String? emoji = isTransfer ? null : _emojiFor(t.category);

    return InkWell(
      onTap: () => TransactionDetailSheet.show(
        context,
        palette: palette,
        transaction: t,
        state: state,
        accounts: accounts,
        now: now,
      ),
      child: Padding(
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
              alignment: Alignment.center,
              child: emoji != null
                  ? ExcludeSemantics(
                      child: Text(
                        emoji,
                        style: const TextStyle(fontSize: 18, height: 1),
                      ),
                    )
                  : Icon(
                      icon,
                      size: 17,
                      color: isIncome
                          ? palette.positive
                          : palette.textSecondary,
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
                  ? '+${formatPeso(t.amount.pesos)}'
                  : formatPeso(t.amount.pesos),
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
      ),
    );
  }

  /// The emoji of the category this entry is filed under, or null when the
  /// name matches none of them (an imported entry, a category since renamed).
  String? _emojiFor(String category) {
    for (final CategoryInfo c in state.categories) {
      if (c.name == category && c.emoji.isNotEmpty) return c.emoji;
    }
    return null;
  }

  String _subtitle(Transaction t, Account? from, Account? to, bool isTransfer) {
    // "Sample" leads the line for a demo entry, the same rule the Accounts
    // rows follow: the marking has to be where the figure is read.
    final StringBuffer b = StringBuffer(
      t.isSample ? 'Sample · ${t.category}' : t.category,
    );
    b.write(' · ');
    // SOMEBODY ELSE'S MONEY reads as their name, never as "Account": a share
    // a friend paid for touched none of the person's accounts, and a
    // repayment came from the friend, not from an account (D34, D35).
    if (t.isFromOutside) {
      b.write(
        isTransfer && to != null
            ? '${t.counterparty} → ${to.name}'
            : 'Paid by ${t.counterparty}',
      );
      return b.toString();
    }
    b.write(from?.name ?? 'Account');
    if (isTransfer && to != null) {
      b.write(' → ');
      b.write(to.name);
    } else if (isTransfer && t.person != null) {
      // Money lent, which leaves for a person rather than an account.
      b.write(' → ');
      b.write(t.person);
      return b.toString();
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
