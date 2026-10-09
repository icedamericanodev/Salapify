import 'package:flutter/material.dart';

import '../../core/money/format.dart';
import '../../design/tokens.dart';
import '../../design/type.dart';
import '../../features/shared/sheet_scaffold.dart';
import '../../models/models.dart';
import '../../state/financial_state.dart';
import 'activity_screen.dart' show statusLabel, statusIsStruckThrough;

/// One entry, in full, from archive/prototype-google-ai-studio/src/components/TransactionDetailModal.tsx.
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
    required this.state,
    required this.accounts,
    required this.now,
  });

  final Palette palette;
  final Transaction transaction;

  /// The store, for the take-back. The sheet was read only until 2026-10-03
  /// and took only the data it displayed; it now offers an action, and an
  /// action needs somewhere to write.
  final FinancialState state;

  final List<Account> accounts;
  final DateTime now;

  static Future<void> show(
    BuildContext context, {
    required Palette palette,
    required Transaction transaction,
    required FinancialState state,
    required List<Account> accounts,
    required DateTime now,
  }) {
    return SheetScaffold.show<void>(
      context: context,
      palette: palette,
      builder: (BuildContext context) => TransactionDetailSheet(
        palette: palette,
        transaction: transaction,
        state: state,
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
            isIncome
                ? '+${formatPeso(t.amount.pesos)}'
                : formatPeso(t.amount.pesos),
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
              switch (t.status) {
                TransactionStatus.duplicate =>
                  'Marked a duplicate, so it is not counted in your totals.',
                // Names what happened rather than only the consequence. This
                // row describes a payment the person deliberately took back,
                // and the debt or plan it paid has already moved with it.
                TransactionStatus.corrected =>
                  'You took this payment back, so it is not counted in your '
                      'totals. It stays here because it is part of what '
                      'happened.',
                _ =>
                  'Excluded on purpose, so it is not counted in your totals.',
              },
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
          _TakeBack(palette: p, state: state, transaction: t),
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

/// The take-back control, or the sentence explaining why there is not one.
///
/// Both halves live in one widget deliberately. An earlier shape had the
/// screen decide whether to draw the button and the store decide whether to
/// act, which is two copies of one rule; [FinancialState.takeBackPreview] is
/// now the only thing that decides, and this widget only renders the answer.
class _TakeBack extends StatefulWidget {
  const _TakeBack({
    required this.palette,
    required this.state,
    required this.transaction,
  });

  final Palette palette;
  final FinancialState state;
  final Transaction transaction;

  @override
  State<_TakeBack> createState() => _TakeBackState();
}

class _TakeBackState extends State<_TakeBack> {
  @override
  Widget build(BuildContext context) {
    final Palette p = widget.palette;
    final Transaction t = widget.transaction;
    final TakeBackOutcome route = widget.state.takeBackPreview(t.id);

    // Nothing to say. The struck-through figure at the top of this sheet
    // already explains itself, and a second paragraph repeating it would be
    // the sort of clutter the founder ruled out on 2026-09-18.
    if (route == TakeBackOutcome.alreadyNotCounting ||
        route == TakeBackOutcome.gone) {
      return const SizedBox.shrink();
    }

    if (route != TakeBackOutcome.done) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(Spacing.md),
        decoration: BoxDecoration(
          color: p.surfaceAlt,
          borderRadius: BorderRadius.circular(Radii.control),
          border: Border.all(color: p.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Taking this back', style: AppType.label(p)),
            const SizedBox(height: Spacing.xs),
            Text(_refusal(route), style: AppType.body(p)),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        PrimaryButton(
          palette: p,
          label: 'Take this back',
          icon: Icons.undo,
          onTap: () => _confirm(context, p, t),
        ),
        const SizedBox(height: Spacing.sm),
        Text(
          // The second half is the part that stops a wrong conclusion. A
          // person who expects the row to disappear and then sees it still
          // listed has no way to tell whether the take-back worked.
          'Puts the money back and stops this counting. The entry stays '
          'here, marked, so your history still shows what happened.',
          style: AppType.caption(p),
        ),
      ],
    );
  }

  /// Where the real take-back lives, for an entry Salapify wrote itself.
  ///
  /// Never a bare refusal. Reversing the ledger row alone would put the money
  /// back and leave the debt, plan, bill, split or reconciliation still
  /// saying it was paid, so this screen will not do it, and the person is
  /// owed the address of the screen that will.
  String _refusal(TakeBackOutcome route) => switch (route) {
    TakeBackOutcome.belongsToDebt =>
      'Salapify wrote this entry to explain a debt payment. Taking it back '
          'here would put the money back and leave the debt still saying it '
          'was paid. Open that debt on the Debts screen and use Take back '
          'the last payment, which moves both together.',
    TakeBackOutcome.belongsToPlan =>
      'Salapify wrote this entry to explain an instalment payment. Taking it '
          'back here would put the money back and leave the plan still saying '
          'it was paid. Open that plan under Plans and take the payment back '
          'there, which moves both together.',
    TakeBackOutcome.belongsToReconciliation =>
      'This entry is the adjustment that balanced an account, and a record '
          'under Reports, Check still says that account was reconciled by '
          'exactly this row. Removing it would leave that record pointing at '
          'nothing. Reconcile the account again instead.',
    TakeBackOutcome.belongsToBill =>
      'Salapify wrote this entry when a scheduled bill was marked paid, and '
          'the bill is still ticked. Un-tick it under Bills, which puts the '
          'money back and clears the tick together.',
    TakeBackOutcome.belongsToSplit =>
      'A split bill wrote this entry, and the debts it created are still '
          'standing. Taking back only the money would leave people owing you '
          'for a bill that no longer exists. Remove those debts from the '
          'Debts screen first.',
    // Not reachable: the caller returns early on these three.
    TakeBackOutcome.done ||
    TakeBackOutcome.alreadyNotCounting ||
    TakeBackOutcome.gone => '',
  };

  Future<void> _confirm(
    BuildContext context,
    Palette palette,
    Transaction t,
  ) async {
    final String account =
        widget.state.accounts
            .where((Account a) => a.id == t.accountId)
            .map((Account a) => a.name)
            .firstOrNull ??
        'the account';

    final bool income = t.type == TransactionType.income;
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final NavigatorState navigator = Navigator.of(context);

    final bool? yes = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        backgroundColor: palette.surface,
        title: Text('Take this back?', style: AppType.title(palette)),
        content: Text(
          // NAMES THE DIRECTION, because the two are opposite and getting it
          // wrong is the whole worry. Taking back an expense puts money IN;
          // taking back income takes money OUT.
          income
              ? '${formatPeso(t.amount.pesos)} comes back out of $account, '
                    'because this entry put it in.\n\n'
                    'The entry stays in your Activity, marked Taken back, and '
                    'stops counting in every total.'
              : '${formatPeso(t.amount.pesos)} goes back into $account.\n\n'
                    'The entry stays in your Activity, marked Taken back, and '
                    'stops counting in every total.',
          style: AppType.body(palette),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Keep it', style: AppType.body(palette)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Take it back', style: AppType.body(palette)),
          ),
        ],
      ),
    );

    if (yes != true) return;

    final TakeBackOutcome outcome = widget.state.takeBackEntry(t.id);
    if (!mounted) return;

    // CLOSED, because the sheet behind the dialog is now describing a state
    // that has changed under it. Leaving it open would show a figure that is
    // no longer counted with no sign that anything happened.
    navigator.pop();

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            outcome == TakeBackOutcome.done
                ? 'Taken back. $account is where it was, and the entry is '
                      'still in your Activity marked Taken back.'
                // A refusal here means the entry changed between the sheet
                // drawing and the tap. Rare, and silence would be worse: the
                // person confirmed something and deserves to know it did not
                // happen.
                : 'Nothing changed. This entry is no longer one that can be '
                      'taken back.',
            style: TextStyle(color: palette.onAccent),
          ),
          backgroundColor: palette.accent,
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }
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
