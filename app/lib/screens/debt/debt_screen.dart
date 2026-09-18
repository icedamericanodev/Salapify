import 'package:flutter/material.dart';

import '../../core/money/debt.dart';
import '../../core/money/format.dart';
import '../../design/tokens.dart';
import '../../design/type.dart';
import '../../features/debt/add_debt_sheet.dart';
import '../../features/debt/payment_sheet.dart';
import '../../features/info/info_dot.dart';
import '../../features/info/info_sheet.dart';
import '../../models/models.dart';
import '../../state/financial_state.dart';
import 'debt_calculators.dart';

/// The debt register, both ways, from src/components/DebtScreen.tsx.
///
/// Debt here means what you owe AND what is owed to you, which is the
/// product's own definition and the reason the two directions are a segmented
/// control rather than one list with the receivables tucked underneath.
///
/// SCOPE, named rather than implied. The prototype's screen has three
/// sections. Two are here: the register itself, which holds the write path,
/// and the nine calculators. The third, `InstallmentsView` (565 lines, formal
/// instalment plans with their own amortisation), is a later batch and is NOT
/// offered as a third tab rather than being offered and empty.
class DebtScreen extends StatefulWidget {
  const DebtScreen({super.key, required this.state, this.onBack});

  final FinancialState state;
  final VoidCallback? onBack;

  @override
  State<DebtScreen> createState() => _DebtScreenState();
}

/// The prototype's two main sections. Its third, Installments, is a later
/// batch and is not offered here rather than being offered and empty.
enum _Section { debts, calculators }

class _DebtScreenState extends State<DebtScreen> {
  DebtDirection _direction = DebtDirection.iOwe;
  _Section _section = _Section.debts;

  @override
  Widget build(BuildContext context) {
    final Palette p = Palette.of(widget.state.theme);
    final List<Debt> debts = widget.state.debts;
    final ({List<Debt> open, List<Debt> settled}) split = splitByStatus(
      debts,
      _direction,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _Header(
          palette: p,
          onBack: widget.onBack,
          onAdd: _section == _Section.debts ? () => _openAdd(context, p) : null,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Spacing.lg,
            Spacing.sm,
            Spacing.lg,
            0,
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: _Tab(
                  palette: p,
                  label: 'What is owed',
                  selected: _section == _Section.debts,
                  onTap: () => setState(() => _section = _Section.debts),
                ),
              ),
              const SizedBox(width: Spacing.sm),
              Expanded(
                child: _Tab(
                  palette: p,
                  label: 'Work it out',
                  selected: _section == _Section.calculators,
                  onTap: () => setState(() => _section = _Section.calculators),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              Spacing.lg,
              Spacing.md,
              Spacing.lg,
              Spacing.xl,
            ),
            children: _section == _Section.calculators
                ? <Widget>[DebtCalculators(palette: p)]
                : <Widget>[
                    _Beam(palette: p, debts: debts),
                    const SizedBox(height: Spacing.md),
                    _DirectionPicker(
                      palette: p,
                      current: _direction,
                      owe: outstanding(debts, DebtDirection.iOwe),
                      owed: outstanding(debts, DebtDirection.owedToMe),
                      onSelect: (DebtDirection d) =>
                          setState(() => _direction = d),
                    ),
                    const SizedBox(height: Spacing.lg),
                    if (split.open.isEmpty && split.settled.isEmpty)
                      _Empty(palette: p, direction: _direction)
                    else ...<Widget>[
                      for (final Debt d in split.open) ...<Widget>[
                        _DebtCard(
                          palette: p,
                          debt: d,
                          onPay: () => _openPayment(context, p, d),
                          onSettle: () =>
                              widget.state.toggleDebtSettledById(d.id),
                        ),
                        const SizedBox(height: Spacing.sm),
                      ],
                      if (split.settled.isNotEmpty) ...<Widget>[
                        const SizedBox(height: Spacing.sm),
                        Text('CLEARED', style: AppType.kicker(p)),
                        const SizedBox(height: Spacing.sm),
                        for (final Debt d in split.settled) ...<Widget>[
                          _DebtCard(
                            palette: p,
                            debt: d,
                            onPay: null,
                            onSettle: () =>
                                widget.state.toggleDebtSettledById(d.id),
                          ),
                          const SizedBox(height: Spacing.sm),
                        ],
                      ],
                    ],
                  ],
          ),
        ),
      ],
    );
  }

  Future<void> _openAdd(BuildContext context, Palette palette) async {
    final Debt? added = await AddDebtSheet.show(context, palette);
    if (added != null) widget.state.addDebt(added);
    if (mounted) setState(() {});
  }

  Future<void> _openPayment(
    BuildContext context,
    Palette palette,
    Debt debt,
  ) async {
    await PaymentSheet.show(
      context,
      palette: palette,
      state: widget.state,
      debt: debt,
    );
    if (mounted) setState(() {});
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.palette,
    required this.onBack,
    required this.onAdd,
  });

  final Palette palette;
  final VoidCallback? onBack;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Spacing.sm, Spacing.md, Spacing.sm, 0),
      child: Row(
        children: <Widget>[
          if (onBack != null)
            Semantics(
              button: true,
              label: 'Back',
              child: InkWell(
                onTap: onBack,
                customBorder: const CircleBorder(),
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Icon(
                    Icons.arrow_back,
                    size: 18,
                    color: palette.textSecondary,
                  ),
                ),
              ),
            )
          else
            const SizedBox(width: Spacing.sm),
          Text('Debts', style: AppType.title(palette)),
          InfoDot(
            color: palette.textMuted,
            semanticLabel: 'How debt both ways works',
            onTap: () =>
                InfoSheet.show(context, palette, InfoTopic.debtBothWays),
          ),
          const Spacer(),
          // Hidden rather than disabled on the calculators tab. A greyed
          // button invites a tap and then does nothing, which reads as a bug;
          // an absent one reads as "not on this tab".
          if (onAdd != null)
            Semantics(
              button: true,
              label: 'Add a debt',
              child: InkWell(
                onTap: onAdd,
                borderRadius: BorderRadius.circular(Radii.pill),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 44),
                  padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(Icons.add, size: 16, color: palette.accent),
                      const SizedBox(width: Spacing.xs),
                      Text(
                        'Add',
                        style: AppType.button(palette, color: palette.accent),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The two totals with the proportional bar between them.
class _Beam extends StatelessWidget {
  const _Beam({required this.palette, required this.debts});

  final Palette palette;
  final List<Debt> debts;

  @override
  Widget build(BuildContext context) {
    final double owe = outstanding(debts, DebtDirection.iOwe);
    final double owed = outstanding(debts, DebtDirection.owedToMe);
    final ({double owedToMe, double youOwe}) split = beamSplit(debts);
    final double net = owed - owe;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Spacing.xl),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('YOU OWE', style: AppType.kicker(palette)),
                    Text(
                      formatPeso(owe),
                      style: AppType.amount(
                        palette,
                      ).copyWith(color: palette.negative),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Text('OWED TO YOU', style: AppType.kicker(palette)),
                  Text(
                    formatPeso(owed),
                    style: AppType.amount(
                      palette,
                    ).copyWith(color: palette.positive),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: Spacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(Radii.pill),
            child: Row(
              children: <Widget>[
                Expanded(
                  flex: (split.youOwe * 10).round(),
                  child: Container(height: 8, color: palette.negative),
                ),
                const SizedBox(width: 2),
                Expanded(
                  flex: (split.owedToMe * 10).round(),
                  child: Container(height: 8, color: palette.positive),
                ),
              ],
            ),
          ),
          const SizedBox(height: Spacing.sm),
          Text(
            // The one figure that matters, said as a sentence rather than left
            // for the reader to subtract. The bar itself is clamped so neither
            // side vanishes, which makes it an illustration; this is the
            // number.
            net == 0
                ? 'What you owe and what you are owed cancel out exactly.'
                : net > 0
                ? 'On balance, ${formatPeso(net)} is owed to you.'
                : 'On balance, you owe ${formatPeso(net)}.',
            style: AppType.caption(palette),
          ),
        ],
      ),
    );
  }
}

class _DirectionPicker extends StatelessWidget {
  const _DirectionPicker({
    required this.palette,
    required this.current,
    required this.owe,
    required this.owed,
    required this.onSelect,
  });

  final Palette palette;
  final DebtDirection current;
  final double owe;
  final double owed;
  final ValueChanged<DebtDirection> onSelect;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: _Tab(
            palette: palette,
            label: 'You owe',
            selected: current == DebtDirection.iOwe,
            onTap: () => onSelect(DebtDirection.iOwe),
          ),
        ),
        const SizedBox(width: Spacing.sm),
        Expanded(
          child: _Tab(
            palette: palette,
            label: 'Owed to you',
            selected: current == DebtDirection.owedToMe,
            onTap: () => onSelect(DebtDirection.owedToMe),
          ),
        ),
      ],
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
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
        borderRadius: BorderRadius.circular(Radii.control),
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
          decoration: BoxDecoration(
            color: selected ? palette.accent : palette.surface,
            borderRadius: BorderRadius.circular(Radii.control),
            border: Border.all(
              color: selected ? palette.accent : palette.border,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: AppType.family,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: selected ? palette.onAccent : palette.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

/// One debt, with everything a person needs to decide what to do about it.
class _DebtCard extends StatelessWidget {
  const _DebtCard({
    required this.palette,
    required this.debt,
    required this.onPay,
    required this.onSettle,
  });

  final Palette palette;
  final Debt debt;
  final VoidCallback? onPay;
  final VoidCallback onSettle;

  @override
  Widget build(BuildContext context) {
    final bool owing = debt.direction == DebtDirection.iOwe;
    final Color tint = owing ? palette.negative : palette.positive;

    final List<String> meta = <String>[
      if (debt.installmentCurrent != null && debt.installmentTotal != null)
        'Payment ${debt.installmentCurrent} of ${debt.installmentTotal}'
      else if (debt.schedule == DebtSchedule.flexible)
        'Flexible, pay when you can',
      if (debt.dueDate != null && !debt.isSettled) 'Due ${debt.dueDate}',
      if (debt.isSettled && debt.settledDate != null)
        'Cleared ${debt.settledDate}',
    ];

    return Container(
      padding: const EdgeInsets.all(Spacing.lg),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(debt.person, style: AppType.section(palette)),
                    if (meta.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 2),
                      Text(meta.join(' · '), style: AppType.rowMeta(palette)),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: Spacing.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Text(
                    formatPeso(
                      debt.isSettled ? debt.totalAmount : debt.remaining,
                    ),
                    style: AppType.amountSmall(palette).copyWith(
                      color: debt.isSettled ? palette.textMuted : tint,
                    ),
                  ),
                  Text(
                    debt.isSettled ? 'paid in full' : 'still to go',
                    style: AppType.caption(palette),
                  ),
                ],
              ),
            ],
          ),
          if (!debt.isSettled) ...<Widget>[
            const SizedBox(height: Spacing.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(Radii.pill),
              child: LinearProgressIndicator(
                value: debt.progress,
                minHeight: 6,
                backgroundColor: palette.trackSoft,
                valueColor: AlwaysStoppedAnimation<Color>(tint),
              ),
            ),
            const SizedBox(height: Spacing.xs),
            Text(
              '${formatPeso(debt.paidAmount)} of '
              '${formatPeso(debt.totalAmount)} so far',
              style: AppType.caption(palette),
            ),
          ],
          if (debt.notes != null) ...<Widget>[
            const SizedBox(height: Spacing.sm),
            Text(debt.notes!, style: AppType.caption(palette)),
          ],
          const SizedBox(height: Spacing.md),
          Row(
            children: <Widget>[
              if (onPay != null)
                Expanded(
                  child: _Action(
                    palette: palette,
                    label: owing ? 'Record a payment' : 'Record a collection',
                    filled: true,
                    onTap: onPay,
                  ),
                ),
              if (onPay != null) const SizedBox(width: Spacing.sm),
              Expanded(
                child: _Action(
                  palette: palette,
                  label: debt.isSettled
                      ? 'Not settled after all'
                      : 'Mark settled',
                  filled: false,
                  onTap: onSettle,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.palette,
    required this.label,
    required this.filled,
    required this.onTap,
  });

  final Palette palette;
  final String label;
  final bool filled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.control),
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
          decoration: BoxDecoration(
            color: filled ? palette.accent : palette.surface,
            borderRadius: BorderRadius.circular(Radii.control),
            border: Border.all(color: filled ? palette.accent : palette.border),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppType.family,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: filled ? palette.onAccent : palette.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.palette, required this.direction});

  final Palette palette;
  final DebtDirection direction;

  @override
  Widget build(BuildContext context) {
    final bool owing = direction == DebtDirection.iOwe;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Spacing.xxl),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        children: <Widget>[
          Icon(
            Icons.volunteer_activism_outlined,
            size: 28,
            color: palette.textMuted,
          ),
          const SizedBox(height: Spacing.sm),
          Text(
            owing ? 'You owe nobody anything' : 'Nobody owes you anything',
            style: AppType.section(palette),
          ),
          const SizedBox(height: Spacing.xs),
          Text(
            owing
                ? 'Add a loan, a card plan or a pahiram and Salapify will '
                      'track what is left and when it is due.'
                : 'Lent somebody money? Add it here so it is written down '
                      'somewhere other than your memory.',
            textAlign: TextAlign.center,
            style: AppType.body(palette),
          ),
        ],
      ),
    );
  }
}
