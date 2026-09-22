import 'package:flutter/material.dart';

import '../../core/money/format.dart';
import '../../core/money/installments.dart';
import '../../design/tokens.dart';
import '../../design/type.dart';
import '../../features/debt/installment_sheet.dart';
import '../../models/models.dart';
import '../../state/financial_state.dart';

/// Instalment plans, from src/components/InstallmentsView.tsx.
///
/// A plan is a CONTRACT and the screen is built around that: how far through
/// it you are, what the rate really works out to over a year, what is left,
/// and how much of what is left is interest a prepayment could still remove.
///
/// The prototype's own amortisation TABLE is not here. The engine for it
/// exists (`generateInstallmentAmortization` in loanCalculators.ts is the one
/// piece of that file still unported), and a row-by-row schedule is a
/// different job from "where am I and what should I do". It is noted in the
/// coverage audit rather than half-built.
class InstallmentsView extends StatefulWidget {
  const InstallmentsView({super.key, required this.state});

  final FinancialState state;

  @override
  State<InstallmentsView> createState() => _InstallmentsViewState();
}

class _InstallmentsViewState extends State<InstallmentsView> {
  @override
  Widget build(BuildContext context) {
    final Palette p = Palette.of(widget.state.theme);
    final List<InstallmentPlan> plans = widget.state.installments;
    final ({List<InstallmentPlan> open, List<InstallmentPlan> settled}) split =
        splitPlans(plans);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _Summary(palette: p, plans: plans),
        const SizedBox(height: Spacing.lg),
        if (split.open.isEmpty && split.settled.isEmpty)
          _Empty(palette: p)
        else ...<Widget>[
          for (final InstallmentPlan plan in split.open) ...<Widget>[
            _PlanCard(
              palette: p,
              plan: plan,
              onPay: () => _open(context, p, plan, extra: false),
              onExtra: () => _open(context, p, plan, extra: true),
            ),
            const SizedBox(height: Spacing.sm),
          ],
          if (split.settled.isNotEmpty) ...<Widget>[
            const SizedBox(height: Spacing.sm),
            Text('PAID OFF', style: AppType.kicker(p)),
            const SizedBox(height: Spacing.sm),
            for (final InstallmentPlan plan in split.settled) ...<Widget>[
              _PlanCard(palette: p, plan: plan, onPay: null, onExtra: null),
              const SizedBox(height: Spacing.sm),
            ],
          ],
        ],
      ],
    );
  }

  Future<void> _open(
    BuildContext context,
    Palette palette,
    InstallmentPlan plan, {
    required bool extra,
  }) async {
    await InstallmentSheet.show(
      context,
      palette: palette,
      state: widget.state,
      plan: plan,
      extra: extra,
    );
    if (mounted) setState(() {});
  }
}

/// What every plan costs together, which is the figure a person actually
/// budgets around.
class _Summary extends StatelessWidget {
  const _Summary({required this.palette, required this.plans});

  final Palette palette;
  final List<InstallmentPlan> plans;

  @override
  Widget build(BuildContext context) {
    final double monthly = monthlyInstallmentLoad(plans);
    final double owed = totalStillOwed(plans);
    final double interest = interestStillToCome(plans);

    return Container(
      padding: const EdgeInsets.all(Spacing.xl),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('EVERY MONTH, ALL PLANS', style: AppType.kicker(palette)),
          Text(formatPeso(monthly), style: AppType.hero(palette)),
          const SizedBox(height: Spacing.sm),
          Text(
            '${formatPeso(owed)} still to pay in total.',
            style: AppType.caption(palette),
          ),
          if (interest > 0) ...<Widget>[
            const SizedBox(height: Spacing.xs),
            Text(
              // On the screen rather than behind a dot, because it is the one
              // thing a person can still DO something about. Interest already
              // charged is gone; this is the part a prepayment removes.
              '${formatPeso(interest)} of that is interest you have not been '
              'charged yet. Paying early is what takes it off.',
              style: AppType.caption(palette),
            ),
          ],
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.palette,
    required this.plan,
    required this.onPay,
    required this.onExtra,
  });

  final Palette palette;
  final InstallmentPlan plan;
  final VoidCallback? onPay;
  final VoidCallback? onExtra;

  @override
  Widget build(BuildContext context) {
    final double? annual = annualisedRate(plan);

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
                    Text(plan.name, style: AppType.section(palette)),
                    const SizedBox(height: 2),
                    Text(
                      '${plan.provider} · ${rateLabel(plan)}',
                      style: AppType.rowMeta(palette),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Spacing.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Text(
                    formatPeso(plan.installmentAmount),
                    style: AppType.amountSmall(palette),
                  ),
                  Text('a month', style: AppType.caption(palette)),
                ],
              ),
            ],
          ),
          if (annual != null) ...<Widget>[
            const SizedBox(height: Spacing.xs),
            Text(
              // The comparison the lender does not put on the poster. A rate
              // quoted per month is the single most misread number in
              // Philippine consumer lending.
              'That ${plan.interestRate}% a month is '
              '${annual.toStringAsFixed(1)}% a year.',
              style: AppType.caption(palette),
            ),
          ],
          const SizedBox(height: Spacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(Radii.pill),
            child: LinearProgressIndicator(
              value: plan.progress,
              minHeight: 6,
              backgroundColor: palette.trackSoft,
              valueColor: AlwaysStoppedAnimation<Color>(
                plan.isSettled ? palette.positive : palette.accent,
              ),
            ),
          ),
          const SizedBox(height: Spacing.xs),
          Text(
            plan.isSettled
                ? 'All ${plan.totalInstallments} payments made.'
                : 'Payment ${plan.paidInstallments} of '
                      '${plan.totalInstallments}, '
                      '${plan.installmentsLeft} to go.',
            style: AppType.caption(palette),
          ),
          const SizedBox(height: Spacing.md),
          if (!plan.isSettled) ...<Widget>[
            _Line(
              palette: palette,
              label: 'Still to pay',
              value: formatPeso(plan.runningBalance),
            ),
            _Line(
              palette: palette,
              label: 'Of that, still principal',
              value: formatPeso(plan.principalRemaining),
            ),
            if (plan.interestRemaining > 0)
              _Line(
                palette: palette,
                label: 'Of that, interest not yet charged',
                value: formatPeso(plan.interestRemaining),
              ),
            _Line(
              palette: palette,
              label: 'Finishes',
              value: plan.maturityDate,
            ),
          ],
          if (plan.extraPayments.isNotEmpty) ...<Widget>[
            const SizedBox(height: Spacing.sm),
            Text('EXTRA PAYMENTS', style: AppType.kicker(palette)),
            const SizedBox(height: Spacing.xs),
            for (final ExtraPayment e in plan.extraPayments)
              _Line(
                palette: palette,
                label: '${e.date}, ${e.note ?? 'Prepayment'}',
                value: formatPeso(e.amount),
              ),
          ],
          if (plan.notes != null) ...<Widget>[
            const SizedBox(height: Spacing.sm),
            Text(plan.notes!, style: AppType.caption(palette)),
          ],
          if (onPay != null || onExtra != null) ...<Widget>[
            const SizedBox(height: Spacing.md),
            Row(
              children: <Widget>[
                if (onPay != null)
                  Expanded(
                    child: _Action(
                      palette: palette,
                      label: 'Pay this month',
                      filled: true,
                      onTap: onPay,
                    ),
                  ),
                if (onPay != null && onExtra != null)
                  const SizedBox(width: Spacing.sm),
                if (onExtra != null)
                  Expanded(
                    child: _Action(
                      palette: palette,
                      label: 'Pay extra',
                      filled: false,
                      onTap: onExtra,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({
    required this.palette,
    required this.label,
    required this.value,
  });

  final Palette palette;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(child: Text(label, style: AppType.body(palette))),
          const SizedBox(width: Spacing.sm),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: AppType.rowTitle(palette),
            ),
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
  const _Empty({required this.palette});

  final Palette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Spacing.xxl),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        children: <Widget>[
          Icon(Icons.inventory_2_outlined, size: 28, color: palette.textMuted),
          const SizedBox(height: Spacing.sm),
          Text('No instalment plans', style: AppType.section(palette)),
          const SizedBox(height: Spacing.xs),
          Text(
            'A phone on Home Credit, a laptop on a bank plan, a desk on '
            'SPayLater. Salapify tracks what is left and what the rate really '
            'costs over a year.',
            textAlign: TextAlign.center,
            style: AppType.body(palette),
          ),
        ],
      ),
    );
  }
}
