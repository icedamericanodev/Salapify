import 'package:flutter/material.dart';

import '../../core/money/format.dart';
import '../../core/money/installments.dart';
import '../../design/tokens.dart';
import '../../design/type.dart';
import '../../features/debt/installment_sheet.dart';
import '../../models/models.dart';
import '../../state/financial_state.dart';
import '../../core/money/money.dart';
import '../../core/money/true_rate.dart';
import '../../features/info/info_dot.dart';
import '../../features/info/info_sheet.dart';

/// Instalment plans, from archive/prototype-google-ai-studio/src/components/InstallmentsView.tsx.
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
    // Archived plans are filtered out of state.installments, so they reach
    // this screen only here.
    final List<InstallmentPlan> archived = widget.state.archivedInstallments;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _Summary(palette: p, plans: plans),
        const SizedBox(height: Spacing.lg),
        // `archived` belongs in this test. Without it, somebody whose only
        // plan is archived gets the empty state AND no Archived section,
        // which puts the one way back out of reach.
        if (split.open.isEmpty && split.settled.isEmpty && archived.isEmpty)
          _Empty(palette: p)
        else ...<Widget>[
          for (final InstallmentPlan plan in split.open) ...<Widget>[
            _PlanCard(
              palette: p,
              plan: plan,
              onPay: () => _open(context, p, plan, extra: false),
              onExtra: () => _open(context, p, plan, extra: true),
              onTakeBack: plan.payments.isEmpty
                  ? null
                  : () => _confirmTakeBack(context, p, plan),
              onDelete: _canDelete(plan)
                  ? () => _confirmDelete(context, p, plan)
                  : null,
            ),
            const SizedBox(height: Spacing.sm),
          ],
          if (split.settled.isNotEmpty) ...<Widget>[
            const SizedBox(height: Spacing.sm),
            Text('PAID OFF', style: AppType.kicker(p)),
            const SizedBox(height: Spacing.sm),
            for (final InstallmentPlan plan in split.settled) ...<Widget>[
              _PlanCard(
                palette: p,
                plan: plan,
                onPay: null,
                onExtra: null,
                // Offered on a PAID OFF plan too: a payment that settled a
                // plan by mistake is exactly the one somebody needs back.
                onTakeBack: plan.payments.isEmpty
                    ? null
                    : () => _confirmTakeBack(context, p, plan),
                // Settled, so this is the archive side of the gate.
                onArchive: () => _confirmArchive(context, p, plan),
              ),
              const SizedBox(height: Spacing.sm),
            ],
          ],
          // PUT AWAY, and still reachable. Rendered only when non-empty: a
          // permanent "0 archived" heading is clutter that teaches people to
          // stop reading headings.
          if (archived.isNotEmpty) ...<Widget>[
            const SizedBox(height: Spacing.sm),
            Text('ARCHIVED', style: AppType.kicker(p)),
            const SizedBox(height: Spacing.sm),
            for (final InstallmentPlan plan in archived) ...<Widget>[
              _PlanCard(
                palette: p,
                plan: plan,
                onPay: null,
                onExtra: null,
                // ONE ACTION on an archived card. Offering take-back here
                // would un-settle the plan while it stayed archived, and an
                // archived plan counts in no total, so a live obligation
                // would appear nowhere. The state guards it too; this is the
                // half that keeps it unreachable.
                onTakeBack: null,
                onUnarchive: () {
                  widget.state.unarchivePlan(plan.id);
                  setState(() {});
                },
              ),
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

  /// Confirms taking the last payment back, naming both sides in pesos.
  ///
  /// The PRINCIPAL figure is named as well as the balance, which the debt
  /// version has no equivalent of. On an add-on contract the principal is
  /// what decides whether prepaying was worth it, and it is the figure a
  /// re-derived reversal would have corrupted while every total still footed.
  /// The delete gate, repeated from [FinancialState.deletePlan] on purpose.
  /// The state refuses regardless; this stops the screen offering what would
  /// be refused, which is its own kind of lie.
  static bool _canDelete(InstallmentPlan p) =>
      p.payments.isEmpty && p.extraPayments.isEmpty;

  Future<void> _confirmDelete(
    BuildContext context,
    Palette palette,
    InstallmentPlan plan,
  ) async {
    final bool? yes = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        backgroundColor: palette.surface,
        title: Text('Delete ${plan.name}?', style: AppType.title(palette)),
        content: Text(
          '${formatPeso(plan.totalPayable.pesos)} over '
          '${plan.totalInstallments} payments, none of them made yet. '
          'Nothing in your Activity changes and no account moves.\n\n'
          // The figure this frees up, named, because unlike a debt a plan is
          // held back from Safe to Spend every month.
          'Salapify stops holding back '
          '${formatPeso(plan.installmentAmount.pesos)} a month for it, so '
          'Safe to Spend on Home goes up.\n\n'
          'There is no undo. If you want it back you will have to restore a '
          'backup that still has it.',
          style: AppType.body(palette),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Keep it', style: AppType.body(palette)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Delete', style: AppType.body(palette)),
          ),
        ],
      ),
    );

    if (yes == true) {
      widget.state.deletePlan(plan.id);
      if (mounted) setState(() {});
    }
  }

  Future<void> _confirmArchive(
    BuildContext context,
    Palette palette,
    InstallmentPlan plan,
  ) async {
    final bool? yes = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        backgroundColor: palette.surface,
        title: Text('Archive ${plan.name}?', style: AppType.title(palette)),
        content: Text(
          'This takes it off your Plans list. It is NOT deleted. It moves to '
          'Archived at the bottom of this screen, and "Put it back" brings '
          'it up again.\n\n'
          // The sentence that stops the wrong conclusion. A paid off plan is
          // already out of the reserve, so nothing moves, and somebody who
          // has watched every other action move a figure will expect this
          // one to as well.
          'No total changes, and Safe to Spend stays where it is. A plan you '
          'have paid off is already out of what Salapify holds back.'
          '${plan.payments.isEmpty ? '' : '\n\nIts ${plan.payments.length} '
                    'payment${plan.payments.length == 1 ? '' : 's'} stay in '
                    'your Activity and still count. That money really left '
                    'your account, so Salapify does not put it back.'}',
          style: AppType.body(palette),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Keep it here', style: AppType.body(palette)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Archive it', style: AppType.body(palette)),
          ),
        ],
      ),
    );

    if (yes == true) {
      widget.state.archivePlan(plan.id);
      if (mounted) setState(() {});
    }
  }

  Future<void> _confirmTakeBack(
    BuildContext context,
    Palette palette,
    InstallmentPlan plan,
  ) async {
    final PlanPayment row = plan.payments.last;
    final Account? from = row.accountId == null
        ? null
        : widget.state.accounts
              .where((Account a) => a.id == row.accountId)
              .firstOrNull;

    final String what = row.installmentNumber == null
        ? 'the ${formatPeso(row.amount.pesos)} extra payment'
        : 'payment ${row.installmentNumber} of ${plan.totalInstallments}, '
              '${formatPeso(row.amount.pesos)}';

    final bool? yes = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        backgroundColor: palette.surface,
        title: Text('Take this payment back?', style: AppType.title(palette)),
        content: Text(
          'This takes back $what, recorded '
          '${formatDateLabel(row.date, now: widget.state.now).toLowerCase()} '
          'against '
          '${plan.name}.\n\n'
          '${plan.name} goes back to '
          '${formatPeso((plan.runningBalance + row.amount).pesos)} still to '
          'pay, of which '
          '${formatPeso((plan.principalRemaining + row.toPrincipal).pesos)} '
          'is principal.\n\n'
          '${from == null ? 'No account moves, because this payment was recorded against the plan alone.' : '${from.name} goes back up by ${formatPeso(row.amount.pesos)}, and the entry stays in your Activity, marked as taken back.'}',
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

    if (yes == true) {
      // Same reasoning as the debt dialog: `row` is what this confirmation
      // described, so the store acts on that row or refuses.
      widget.state.takeBackPlanPayment(plan.id, paymentId: row.id);
      if (mounted) setState(() {});
    }
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
    final Money monthly = monthlyInstallmentLoad(plans);
    final Money owed = totalStillOwed(plans);
    final Money interest = interestStillToCome(plans);

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
          Text(formatPeso(monthly.pesos), style: AppType.hero(palette)),
          const SizedBox(height: Spacing.sm),
          Text(
            '${formatPeso(owed.pesos)} still to pay in total.',
            style: AppType.caption(palette),
          ),
          if (interest.isPositive) ...<Widget>[
            const SizedBox(height: Spacing.xs),
            Text(
              // On the screen rather than behind a dot, because it is the one
              // thing a person can still DO something about. Interest already
              // charged is gone; this is the part a prepayment removes.
              '${formatPeso(interest.pesos)} of that is interest you have not '
              'been charged yet. On a fixed add-on plan it was set when you '
              'signed, so paying early finishes the plan sooner but does not '
              'usually reduce it.',
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
    this.onTakeBack,
    this.onDelete,
    this.onArchive,
    this.onUnarchive,
  });

  final Palette palette;
  final InstallmentPlan plan;
  final VoidCallback? onPay;
  final VoidCallback? onExtra;

  /// Taking the plan off the list. Exactly one is ever non-null, and which
  /// one is decided by the plan's own figures rather than by the caller.
  final VoidCallback? onDelete;
  final VoidCallback? onArchive;
  final VoidCallback? onUnarchive;

  /// Null when the plan has no record of how it reached its figures, which
  /// is every plan from a restored backup. Absent rather than disabled: a
  /// dead control on a money screen reads as a broken app.
  final VoidCallback? onTakeBack;

  @override
  Widget build(BuildContext context) {
    final double? quotedAnnual = annualisedRate(plan);

    // What the plan ACTUALLY costs, solved from its own payments rather than
    // taken from the rate the lender chose to print.
    final InstallmentSchedule schedule = scheduleFor(plan);
    final double? realMonthly = trueMonthlyRate(
      principal: plan.principal,
      payments: <Money>[
        for (int i = 0; i < schedule.count; i++) schedule.instalmentAt(i),
      ],
    );
    // Shown only when it is MATERIALLY above the quoted figure. On a genuine
    // 0% plan there is nothing to correct, and a line saying "really 0%" would
    // read as an accusation against a lender who charged nothing.
    final bool worthSaying =
        realMonthly != null &&
        plan.interestRate > 0 &&
        realMonthly * 100 > plan.interestRate * 1.1;

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
                    formatPeso(plan.installmentAmount.pesos),
                    style: AppType.amountSmall(palette),
                  ),
                  Text('a month', style: AppType.caption(palette)),
                ],
              ),
            ],
          ),
          if (quotedAnnual != null) ...<Widget>[
            const SizedBox(height: Spacing.xs),
            Text(
              // THIS LINE USED TO CLAIM TO BE THE COMPARISON THE LENDER DOES
              // NOT PUT ON THE POSTER. It is the poster: multiplying a quoted
              // monthly rate by twelve is the lender's own arithmetic, so
              // reprinting it corrects nothing.
              //
              // The real comparison is the line below, and it stays ON the
              // screen rather than behind the dot under the rule's own
              // exception: without it somebody concludes this plan costs 18% a
              // year, which is the wrong conclusion the whole feature exists
              // to prevent. The lesson, why an add-on rate differs from a rate
              // on the balance, is the part that belongs one tap away.
              'Quoted as ${plan.interestRate}% a month, '
              '${quotedAnnual.toStringAsFixed(1)}% a year.',
              style: AppType.caption(palette),
            ),
            if (worthSaying) ...<Widget>[
              const SizedBox(height: 2),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'On what you still owe each month it works out to '
                      '${(realMonthly * 100).toStringAsFixed(1)}%, or '
                      '${(realMonthly * 1200).toStringAsFixed(1)}% a year.',
                      style: AppType.caption(
                        palette,
                      ).copyWith(color: palette.textPrimary),
                    ),
                  ),
                  const SizedBox(width: Spacing.xs),
                  // The FIGURE stays on the card; the lesson about add-on
                  // interest is read once and then skipped forever, so it
                  // goes one tap away.
                  InfoDot(
                    color: palette.textMuted,
                    semanticLabel: 'Why the real rate is higher than quoted',
                    onTap: () =>
                        InfoSheet.show(context, palette, InfoTopic.addOnRate),
                  ),
                ],
              ),
            ],
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
              value: formatPeso(plan.runningBalance.pesos),
            ),
            _Line(
              palette: palette,
              label: 'Of that, still principal',
              value: formatPeso(plan.principalRemaining.pesos),
            ),
            if (plan.interestRemaining.isPositive)
              _Line(
                palette: palette,
                label: 'Of that, interest not yet charged',
                value: formatPeso(plan.interestRemaining.pesos),
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
                value: formatPeso(e.amount.pesos),
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
          if (onTakeBack != null) ...<Widget>[
            const SizedBox(height: Spacing.sm),
            _Action(
              palette: palette,
              // The LAST one, and the label says so. A prepayment shortens
              // the plan, so every instalment after it collected a different
              // amount; letting somebody pick an older one would leave those
              // explainable by no schedule at all.
              label: 'Take back the last payment',
              filled: false,
              onTap: onTakeBack,
            ),
          ]
          // Same rule as the debt card, and the same correction: the branch
          // is decided by the DATA, not by whether the callback is null.
          // Keying it on the callback made every ARCHIVED card claim there
          // was no record, over a plan holding a full register, on the one
          // screen somebody goes to in order to recover.
          else if (plan.paidInstallments > 0 && plan.payments.isEmpty) ...[
            const SizedBox(height: Spacing.sm),
            Text(
              'Salapify has no record of the payments on this plan, so it '
              'cannot take one back. Payments you record from now on can be.',
              style: AppType.caption(palette),
            ),
          ] else if (plan.payments.isNotEmpty) ...<Widget>[
            const SizedBox(height: Spacing.sm),
            Text(
              'Its ${plan.payments.length} '
              'payment${plan.payments.length == 1 ? '' : 's'} '
              '${plan.payments.length == 1 ? 'is' : 'are'} still recorded. '
              'Put it back on the list first if you need to take one back.',
              style: AppType.caption(palette),
            ),
          ],
          // TAKING THE PLAN OFF THE LIST, which was impossible until now.
          if (onUnarchive != null) ...<Widget>[
            const SizedBox(height: Spacing.sm),
            _Action(
              palette: palette,
              label: 'Put it back',
              filled: false,
              onTap: onUnarchive,
            ),
          ] else if (onDelete != null) ...<Widget>[
            const SizedBox(height: Spacing.sm),
            _Action(
              palette: palette,
              label: 'Delete this plan',
              filled: false,
              onTap: onDelete,
            ),
          ] else if (onArchive != null) ...<Widget>[
            const SizedBox(height: Spacing.sm),
            _Action(
              palette: palette,
              label: 'Archive it',
              filled: false,
              onTap: onArchive,
            ),
          ],
          // No line on a plan that can be neither, for the reason the debt
          // screen records: part paid and live is the normal state of a real
          // plan, so a sentence here would land on every card forever. The
          // lesson lives behind this screen's own "i" dot.
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
