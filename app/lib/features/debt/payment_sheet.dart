import 'package:flutter/material.dart';

import '../../core/money/debt.dart';
import '../../core/money/format.dart';
import '../../design/tokens.dart';
import '../../design/type.dart';
import '../../models/models.dart';
import '../../state/financial_state.dart';
import '../shared/sheet_scaffold.dart';

/// Records a payment on a debt, or a collection on a receivable.
///
/// The sheet's whole job is to make the CONSEQUENCE visible before the tap,
/// because this is the one write in the app that moves two things at once: the
/// debt, and the balance of whatever account the money came out of. It says
/// which account, what the debt will read afterwards, and what happens if no
/// account is chosen.
class PaymentSheet extends StatefulWidget {
  const PaymentSheet({
    super.key,
    required this.palette,
    required this.state,
    required this.debt,
  });

  final Palette palette;
  final FinancialState state;
  final Debt debt;

  static Future<void> show(
    BuildContext context, {
    required Palette palette,
    required FinancialState state,
    required Debt debt,
  }) {
    return SheetScaffold.show<void>(
      context: context,
      palette: palette,
      builder: (BuildContext ctx) =>
          PaymentSheet(palette: palette, state: state, debt: debt),
    );
  }

  @override
  State<PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends State<PaymentSheet> {
  final TextEditingController _amount = TextEditingController();

  /// Null means "do not touch any account", which is a real answer rather than
  /// an unfilled field: somebody settling in cash they never logged should be
  /// able to record the debt without inventing a movement.
  String? _accountId;

  @override
  void initState() {
    super.initState();
    // Pre-filled with what is actually left, because paying a debt off is the
    // commonest thing anybody does on this sheet and retyping 7,350 from the
    // row above it is work the app can do.
    _amount.text = _plain(widget.debt.remaining);
    _accountId = widget.state.accounts
        .where((Account a) => a.isLiquid)
        .firstOrNull
        ?.id;
  }

  static String _plain(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Palette p = widget.palette;
    final Debt d = widget.debt;
    final bool owing = d.direction == DebtDirection.iOwe;
    final double? amount = parseDebtAmount(_amount.text);

    final List<Account> choices = widget.state.accounts
        .where((Account a) => a.isLiquid)
        .toList();

    return SheetScaffold(
      palette: p,
      icon: owing ? Icons.south_west : Icons.north_east,
      title: owing ? 'Record a payment' : 'Record a collection',
      subtitle: owing
          ? 'Money going to ${d.person}'
          : 'Money coming back from ${d.person}',
      footer: PrimaryButton(
        palette: p,
        label: owing ? 'Record the payment' : 'Record the collection',
        icon: Icons.check,
        onTap: amount == null ? null : _save,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _Standing(palette: p, debt: d),
          const SizedBox(height: Spacing.lg),
          SheetField(
            palette: p,
            label: owing ? 'How much are you paying' : 'How much came back',
            controller: _amount,
            hint: '0.00',
            prefix: '₱ ',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: Spacing.lg),
          Text(
            owing ? 'Where is it coming from' : 'Where is it going',
            style: AppType.label(p),
          ),
          const SizedBox(height: Spacing.xs),
          _AccountPicker(
            palette: p,
            accounts: choices,
            selected: _accountId,
            onSelect: (String? id) => setState(() => _accountId = id),
          ),
          const SizedBox(height: Spacing.md),
          _WhatWillHappen(
            palette: p,
            debt: d,
            amount: amount,
            // The FULL name, not accountShortName. This sentence names the
            // account the person tapped a moment ago, so it has to say the
            // same words the chip did; and with a "GCash Wallet" and a "GCash
            // Savings" the short form is the same for both, which is exactly
            // when somebody most needs to know which one is about to move.
            accountName: _accountId == null
                ? null
                : widget.state.accounts
                      .firstWhere((Account a) => a.id == _accountId)
                      .name,
          ),
        ],
      ),
    );
  }

  void _save() {
    final double? amount = parseDebtAmount(_amount.text);
    if (amount == null) return;
    widget.state.recordDebtPayment(
      widget.debt.id,
      amount,
      accountId: _accountId,
    );
    Navigator.of(context).pop();
  }
}

/// Where the debt stands right now, so the figure being typed has something to
/// be measured against.
class _Standing extends StatelessWidget {
  const _Standing({required this.palette, required this.debt});

  final Palette palette;
  final Debt debt;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Spacing.lg),
      decoration: BoxDecoration(
        color: palette.surfaceAlt,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(debt.person, style: AppType.rowTitle(palette)),
                Text(
                  '${formatPeso(debt.paidAmount)} of '
                  '${formatPeso(debt.totalAmount)} so far',
                  style: AppType.caption(palette),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(
                formatPeso(debt.remaining),
                style: AppType.amountSmall(palette),
              ),
              Text('still to go', style: AppType.caption(palette)),
            ],
          ),
        ],
      ),
    );
  }
}

class _AccountPicker extends StatelessWidget {
  const _AccountPicker({
    required this.palette,
    required this.accounts,
    required this.selected,
    required this.onSelect,
  });

  final Palette palette;
  final List<Account> accounts;
  final String? selected;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: Spacing.sm,
      runSpacing: Spacing.sm,
      children: <Widget>[
        for (final Account a in accounts)
          _Chip(
            palette: palette,
            label: a.name,
            selected: selected == a.id,
            onTap: () => onSelect(a.id),
          ),
        // A real option, not an escape hatch. Somebody handing over cash they
        // never logged should be able to record the debt without inventing a
        // movement out of an account that never held the money.
        _Chip(
          palette: palette,
          label: 'No account, just the debt',
          selected: selected == null,
          onTap: () => onSelect(null),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.palette,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final Palette palette;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.pill),
        child: Container(
          constraints: const BoxConstraints(minHeight: 36),
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.md,
            vertical: Spacing.sm,
          ),
          decoration: BoxDecoration(
            color: selected ? palette.accent : palette.surface,
            borderRadius: BorderRadius.circular(Radii.pill),
            border: Border.all(
              color: selected ? palette.accent : palette.border,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: AppType.family,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: selected ? palette.onAccent : palette.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

/// The consequence, spelled out before the tap.
///
/// This is on the SCREEN rather than behind the dot, deliberately. It is not
/// teaching, it is the outcome of the button directly underneath it, and this
/// is the only write in the app that moves two things at once.
class _WhatWillHappen extends StatelessWidget {
  const _WhatWillHappen({
    required this.palette,
    required this.debt,
    required this.amount,
    required this.accountName,
  });

  final Palette palette;
  final Debt debt;
  final double? amount;
  final String? accountName;

  @override
  Widget build(BuildContext context) {
    if (amount == null) {
      return Text(
        'Enter an amount to see what this will do.',
        style: AppType.caption(palette),
      );
    }

    final bool owing = debt.direction == DebtDirection.iOwe;
    final double left = (debt.remaining - amount!).clamp(0, double.infinity);
    final bool clears = debt.paidAmount + amount! >= debt.totalAmount;
    final double over = debt.paidAmount + amount! - debt.totalAmount;

    final List<String> lines = <String>[
      clears
          ? '${debt.person} will be marked cleared.'
          : '${formatPeso(left)} will still be owed.',
      if (clears && over > 0)
        'That is ${formatPeso(over)} more than the debt, and Salapify records '
            'it rather than rounding it away.',
      if (accountName != null)
        owing
            ? '$accountName goes down by ${formatPeso(amount!)}, and an entry '
                  'in your Activity will say why.'
            : '$accountName goes up by ${formatPeso(amount!)}, and an entry '
                  'in your Activity will say why.'
      else
        'No account will change, and nothing will appear in your Activity. '
            'Only the debt moves.',
    ];

    return Container(
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: palette.accentSoft,
        borderRadius: BorderRadius.circular(Radii.control),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (final String l in lines) ...<Widget>[
            Text(l, style: AppType.caption(palette)),
            if (l != lines.last) const SizedBox(height: Spacing.xs),
          ],
        ],
      ),
    );
  }
}
