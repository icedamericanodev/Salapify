import 'package:flutter/material.dart';

import '../../core/money/debt.dart' show parseDebtAmount;
import '../../core/money/format.dart';
import '../../design/tokens.dart';
import '../../design/type.dart';
import '../../models/models.dart';
import '../../state/financial_state.dart';
import '../shared/sheet_scaffold.dart';

/// Pays an instalment, either the scheduled one or extra on top.
///
/// One sheet for both, because they differ in exactly two ways and putting
/// them side by side is what makes the difference legible: a SCHEDULED payment
/// is a fixed amount that advances the counter, and an EXTRA payment is any
/// amount that comes straight off the principal and shortens the plan.
class InstallmentSheet extends StatefulWidget {
  const InstallmentSheet({
    super.key,
    required this.palette,
    required this.state,
    required this.plan,
    required this.extra,
  });

  final Palette palette;
  final FinancialState state;
  final InstallmentPlan plan;

  /// True for a prepayment, false for the scheduled instalment.
  final bool extra;

  static Future<void> show(
    BuildContext context, {
    required Palette palette,
    required FinancialState state,
    required InstallmentPlan plan,
    required bool extra,
  }) {
    return SheetScaffold.show<void>(
      context: context,
      palette: palette,
      builder: (BuildContext ctx) => InstallmentSheet(
        palette: palette,
        state: state,
        plan: plan,
        extra: extra,
      ),
    );
  }

  @override
  State<InstallmentSheet> createState() => _InstallmentSheetState();
}

class _InstallmentSheetState extends State<InstallmentSheet> {
  final TextEditingController _amount = TextEditingController();
  final TextEditingController _note = TextEditingController();
  String? _accountId;

  @override
  void initState() {
    super.initState();
    if (widget.extra) {
      _amount.text = '';
    }
    _accountId = widget.state.accounts
        .where((Account a) => a.isLiquid)
        .firstOrNull
        ?.id;
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Palette p = widget.palette;
    final InstallmentPlan plan = widget.plan;
    final double? typed = parseDebtAmount(_amount.text);
    final bool ready = widget.extra ? typed != null : true;

    return SheetScaffold(
      palette: p,
      icon: widget.extra ? Icons.fast_forward_outlined : Icons.event_available,
      title: widget.extra ? 'Pay extra' : 'Pay this month',
      subtitle: '${plan.provider}, ${plan.name}',
      footer: PrimaryButton(
        palette: p,
        label: widget.extra ? 'Record the extra payment' : 'Record the payment',
        icon: Icons.check,
        onTap: ready ? _save : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _Standing(palette: p, plan: plan),
          const SizedBox(height: Spacing.lg),
          if (widget.extra) ...<Widget>[
            SheetField(
              palette: p,
              label: 'How much extra',
              controller: _amount,
              hint: '0.00',
              prefix: '₱ ',
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: Spacing.lg),
            SheetField(
              palette: p,
              label: 'What it was, if you want a note',
              controller: _note,
              hint: 'Thirteenth month, bonus',
              keyboardType: TextInputType.text,
            ),
          ] else
            Container(
              padding: const EdgeInsets.all(Spacing.lg),
              decoration: BoxDecoration(
                color: p.surfaceAlt,
                borderRadius: BorderRadius.circular(Radii.card),
                border: Border.all(color: p.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('THIS MONTH', style: AppType.kicker(p)),
                  Text(
                    formatPeso(plan.installmentAmount),
                    style: AppType.amount(p),
                  ),
                  const SizedBox(height: Spacing.xs),
                  Text(
                    // Not editable, on purpose. A scheduled instalment is a
                    // fixed amount in a contract; letting somebody type a
                    // different figure here and still have it count as
                    // "payment 6 of 12" would put the counter and the money
                    // out of step. Paying a different amount is the other
                    // button.
                    'The amount is set by the plan. To pay a different amount, '
                    'use Pay extra.',
                    style: AppType.caption(p),
                  ),
                ],
              ),
            ),
          const SizedBox(height: Spacing.lg),
          Text('Where is it coming from', style: AppType.label(p)),
          const SizedBox(height: Spacing.xs),
          Wrap(
            spacing: Spacing.sm,
            runSpacing: Spacing.sm,
            children: <Widget>[
              for (final Account a in widget.state.accounts.where(
                (Account a) => a.isLiquid,
              ))
                _Chip(
                  palette: p,
                  label: a.name,
                  selected: _accountId == a.id,
                  onTap: () => setState(() => _accountId = a.id),
                ),
              _Chip(
                palette: p,
                label: 'No account, just the plan',
                selected: _accountId == null,
                onTap: () => setState(() => _accountId = null),
              ),
            ],
          ),
          const SizedBox(height: Spacing.md),
          _WhatWillHappen(
            palette: p,
            plan: plan,
            extra: widget.extra,
            amount: widget.extra ? typed : plan.installmentAmount,
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
    if (widget.extra) {
      final double? amount = parseDebtAmount(_amount.text);
      if (amount == null) return;
      widget.state.payInstallmentExtra(
        widget.plan.id,
        amount,
        accountId: _accountId,
        note: _note.text,
      );
    } else {
      widget.state.payInstallment(widget.plan.id, accountId: _accountId);
    }
    Navigator.of(context).pop();
  }
}

class _Standing extends StatelessWidget {
  const _Standing({required this.palette, required this.plan});

  final Palette palette;
  final InstallmentPlan plan;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Spacing.lg),
      decoration: BoxDecoration(
        color: palette.surfaceAlt,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Payment ${plan.paidInstallments} of ${plan.totalInstallments}, '
            '${formatPeso(plan.runningBalance)} still to pay.',
            style: AppType.rowTitle(palette),
          ),
          if (plan.interestRemaining > 0) ...<Widget>[
            const SizedBox(height: Spacing.xs),
            Text(
              '${formatPeso(plan.interestRemaining)} of that is interest not '
              'yet charged.',
              style: AppType.caption(palette),
            ),
          ],
        ],
      ),
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

/// What the button is about to do, said before it is pressed.
class _WhatWillHappen extends StatelessWidget {
  const _WhatWillHappen({
    required this.palette,
    required this.plan,
    required this.extra,
    required this.amount,
    required this.accountName,
  });

  final Palette palette;
  final InstallmentPlan plan;
  final bool extra;
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

    final double left = (plan.runningBalance - amount!).clamp(
      0,
      double.infinity,
    );
    final bool clears = left <= 0;

    final List<String> lines = <String>[
      if (extra)
        clears
            ? 'This clears the plan outright.'
            : 'It comes straight off the principal, so '
                  '${formatPeso(left)} would be left and the interest still '
                  'to come shrinks with it.'
      else
        clears
            ? 'This is the last payment. The plan will be paid off.'
            : 'You will be on payment ${plan.paidInstallments + 1} of '
                  '${plan.totalInstallments}, with ${formatPeso(left)} left.',
      if (accountName != null)
        '$accountName goes down by ${formatPeso(amount!)}, and an entry in '
            'your Activity will say why.'
      else
        'No account will change, and nothing will appear in your Activity. '
            'Only the plan moves.',
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
