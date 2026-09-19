import 'package:flutter/material.dart';

import '../../core/money/format.dart';
import '../../design/tokens.dart';
import '../../design/type.dart';
import '../../features/shared/sheet_scaffold.dart';
import '../../models/models.dart';
import 'activity_screen.dart' show statusLabel, statusIsStruckThrough;

/// One entry, in full, from src/components/TransactionDetailModal.tsx.
///
/// SCOPE, named rather than implied. This is the VIEW half. The prototype's
/// modal also edits an entry and carries a collaboration thread: comments,
/// mentions, approvals and receipt attachments. Those need a collaboration
/// system and a storage layer that app/ does not have yet, and a comment box
/// that cannot save a comment is worse than no comment box. They migrate with
/// the features behind them.
class TransactionDetailSheet extends StatelessWidget {
  const TransactionDetailSheet({
    super.key,
    required this.palette,
    required this.transaction,
    required this.accounts,
    required this.now,
  });

  final Palette palette;
  final Transaction transaction;
  final List<Account> accounts;
  final DateTime now;

  static Future<void> show(
    BuildContext context, {
    required Palette palette,
    required Transaction transaction,
    required List<Account> accounts,
    required DateTime now,
  }) {
    return SheetScaffold.show<void>(
      context: context,
      palette: palette,
      builder: (BuildContext context) => TransactionDetailSheet(
        palette: palette,
        transaction: transaction,
        accounts: accounts,
        now: now,
      ),
    );
  }

  Account? _account(String? id) {
    if (id == null) return null;
    for (final Account a in accounts) {
      if (a.id == id) return a;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final Palette p = palette;
    final Transaction t = transaction;
    final bool isIncome = t.type == TransactionType.income;
    final bool isTransfer = t.type == TransactionType.transfer;
    final bool struck = statusIsStruckThrough(t.status);

    final Account? from = _account(t.accountId);
    final Account? to = _account(t.toAccountId);

    return SheetScaffold(
      palette: p,
      icon: isIncome
          ? Icons.south_west
          : isTransfer
          ? Icons.swap_horiz
          : Icons.north_east,
      title: t.merchant ?? t.category,
      subtitle: formatDateLabel(t.date, now: now),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // The amount, big, because it is the thing somebody opened this for.
          Text(
            isIncome ? '+${formatPeso(t.amount)}' : formatPeso(t.amount),
            style: AppType.amount(p).copyWith(
              color: struck
                  ? p.textMuted
                  : isIncome
                  ? p.positive
                  : p.textPrimary,
              decoration: struck ? TextDecoration.lineThrough : null,
              decorationColor: p.textMuted,
            ),
          ),
          if (struck) ...<Widget>[
            const SizedBox(height: Spacing.xs),
            Text(
              // Says the quiet part out loud. A struck-through figure is easy
              // to miss, and somebody reconciling needs to know this row is
              // deliberately not in their totals rather than wonder why the
              // sums do not add up.
              t.status == TransactionStatus.duplicate
                  ? 'Marked a duplicate, so it is not counted in your totals.'
                  : 'Excluded on purpose, so it is not counted in your totals.',
              style: AppType.caption(p).copyWith(color: p.warning),
            ),
          ],
          const SizedBox(height: Spacing.lg),

          _Row(
            palette: p,
            label: isTransfer ? 'From' : 'Account',
            value: from?.name ?? 'Unknown account',
            caption: from?.institution,
          ),
          if (isTransfer)
            _Row(
              palette: p,
              label: 'To',
              value: to?.name ?? 'Unknown account',
              caption: to?.institution,
            ),
          _Row(
            palette: p,
            label: 'Category',
            value: t.category,
            caption: t.subcategory,
          ),
          _Row(
            palette: p,
            label: 'Date',
            value: formatDateLabel(t.date, now: now),
            // The stored ISO date as well as the friendly label. "Yesterday"
            // stops being useful the moment somebody is comparing against a
            // bank statement.
            caption: t.date,
          ),
          _Row(palette: p, label: 'Status', value: statusLabel(t.status)),
          if (t.person != null)
            _Row(palette: p, label: 'Person', value: t.person!),
          if (t.profile != null)
            _Row(
              palette: p,
              label: 'Profile',
              value: _profileLabel(t.profile!),
            ),

          if (t.tags.isNotEmpty) ...<Widget>[
            const SizedBox(height: Spacing.md),
            Text('Tags', style: AppType.label(p)),
            const SizedBox(height: Spacing.sm),
            Wrap(
              spacing: Spacing.sm,
              runSpacing: Spacing.sm,
              children: <Widget>[
                for (final String tag in t.tags)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Spacing.md,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: p.surfaceAlt,
                      borderRadius: BorderRadius.circular(Radii.pill),
                      border: Border.all(color: p.border),
                    ),
                    child: Text(tag, style: AppType.caption(p)),
                  ),
              ],
            ),
          ],

          if (t.note != null && t.note!.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: Spacing.lg),
            Text('Note', style: AppType.label(p)),
            const SizedBox(height: Spacing.xs),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(Spacing.md),
              decoration: BoxDecoration(
                color: p.surfaceAlt,
                borderRadius: BorderRadius.circular(Radii.control),
                border: Border.all(color: p.border),
              ),
              child: Text(t.note!, style: AppType.body(p)),
            ),
          ],

          const SizedBox(height: Spacing.lg),
          Text(
            // Honest about what this screen cannot do yet, in the place
            // somebody looks for the button that is missing.
            'Editing an entry, receipts and comments are later migration '
            'steps. Nothing here can be changed yet.',
            style: AppType.caption(p),
          ),
        ],
      ),
    );
  }

  String _profileLabel(ProfileEntity p) => switch (p) {
    ProfileEntity.personal => 'Personal',
    ProfileEntity.household => 'Household',
    ProfileEntity.business => 'Business',
    ProfileEntity.sideHustle => 'Side hustle',
  };
}

class _Row extends StatelessWidget {
  const _Row({
    required this.palette,
    required this.label,
    required this.value,
    this.caption,
  });

  final Palette palette;
  final String label;
  final String value;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 92,
            child: Text(label, style: AppType.label(palette)),
          ),
          const SizedBox(width: Spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(value, style: AppType.rowTitle(palette)),
                if (caption != null && caption!.trim().isNotEmpty)
                  Text(caption!, style: AppType.caption(palette)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
