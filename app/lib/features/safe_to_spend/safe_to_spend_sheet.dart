import 'package:flutter/material.dart';

import '../../core/money/format.dart';
import '../../design/tokens.dart';
import '../../design/type.dart';
import '../../models/models.dart';
import '../../state/financial_state.dart';
import '../shared/sheet_scaffold.dart';

/// Safe to Spend Details, ported from src/components/SafeToSpendModal.tsx.
///
/// Three tabs, and the third is the reason the sheet exists. Outputs says what
/// the number is. Streams says what income it assumed. AUDIT says how it got
/// there, line by line, because a figure this consequential should never be
/// something a person has to take on trust.
class SafeToSpendSheet extends StatefulWidget {
  const SafeToSpendSheet({super.key, required this.state});

  final FinancialState state;

  static Future<void> show(BuildContext context, FinancialState state) {
    return SheetScaffold.show<void>(
      context: context,
      palette: Palette.of(state.theme),
      builder: (BuildContext context) => SafeToSpendSheet(state: state),
    );
  }

  @override
  State<SafeToSpendSheet> createState() => _SafeToSpendSheetState();
}

class _SafeToSpendSheetState extends State<SafeToSpendSheet> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final Palette p = Palette.of(widget.state.theme);
    final SafeToSpendAnalysis a = widget.state.safeToSpendAnalysis;

    return SheetScaffold(
      palette: p,
      icon: Icons.auto_awesome,
      title: 'Safe to Spend Details',
      subtitle: 'Understand how much is safe to spend',
      banner: _scenarioBanner(p),
      tabs: const <String>[
        'Outputs & Runway',
        'Income Streams',
        'Audit & Math',
      ],
      selectedTab: _tab,
      onSelectTab: (int i) => setState(() => _tab = i),
      child: switch (_tab) {
        0 => _outputs(p, a),
        1 => _streams(p),
        _ => _audit(p, a),
      },
    );
  }

  Widget _scenarioBanner(Palette p) {
    final bool conservative =
        widget.state.scenario == DecisionScenario.conservative;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.lg,
        vertical: Spacing.sm,
      ),
      decoration: BoxDecoration(
        color: p.accentSoft,
        border: Border(bottom: BorderSide(color: p.border)),
      ),
      // Stacked, not side by side. Squeezed into a Row the sentence wrapped to
      // three lines beside a control that had no room either, and neither half
      // read properly. Full width gives the toggle equal halves and the
      // sentence one line.
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            conservative
                ? 'Conservative: trims irregular income and holds back more.'
                : 'Optimistic: counts every expected peso and holds back less.',
            style: AppType.caption(p),
          ),
          const SizedBox(height: Spacing.sm),
          SegmentedChoice<DecisionScenario>(
            palette: p,
            selected: widget.state.scenario,
            options: const <(DecisionScenario, String)>[
              (DecisionScenario.conservative, 'Conservative'),
              (DecisionScenario.optimistic, 'Optimistic'),
            ],
            onSelect: (DecisionScenario s) =>
                setState(() => widget.state.setScenario(s)),
          ),
        ],
      ),
    );
  }

  Widget _outputs(Palette p, SafeToSpendAnalysis a) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // Two by two rather than a Row of four: at 320dp four money figures
        // side by side is unreadable.
        StatPair(
          left: StatCard(
            palette: p,
            label: 'Safe to Spend Today',
            value: formatPeso(a.safeToSpendToday),
            caption: 'Daily discretionary quota',
            valueColor: p.accent,
          ),
          right: StatCard(
            palette: p,
            label: 'Until Next Payday',
            value: formatPeso(a.safeToSpendUntilPayday),
            caption: '${a.daysToPayday} days left in cutoff',
          ),
        ),
        const SizedBox(height: Spacing.md),
        StatPair(
          left: StatCard(
            palette: p,
            label: 'Safe to Save',
            value: formatPeso(a.safeToSave),
            caption: 'Guilt-free, without starving the month',
            valueColor: p.positive,
          ),
          right: StatCard(
            palette: p,
            label: 'Must Remain Reserved',
            value: formatPeso(a.amountReserved),
            caption: 'Committed bills, debt and buffer',
            valueColor: p.warning,
          ),
        ),
        const SizedBox(height: Spacing.lg),
        _card(
          p,
          title: 'Cash Runway',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                '${a.cashRunwayDays} days',
                style: AppType.amount(p).copyWith(color: p.textPrimary),
              ),
              Text(
                // "YOUR RECENT BURN RATE" WAS NOT ALWAYS YOURS.
                //
                // Under 5,000 logged in thirty days and the engine measures
                // nothing: it stands 28,000 a month in, deliberately, because
                // that is what the prototype does and a golden vector locks
                // it. The number is not the defect. Calling it "your recent
                // burn rate" to somebody who has logged nothing is, and it is
                // the first screen a new install can reach that puts a figure
                // in front of them.
                a.runwayFromLoggedSpending
                    ? 'About ${a.cashRunwayMonths} months at your recent '
                          'spending, if nothing came in at all.'
                    : 'About ${a.cashRunwayMonths} months at a typical '
                          'month of spending, if nothing came in at all. '
                          'Log a few weeks and this switches to your own '
                          'pace.',
                style: AppType.body(p),
              ),
            ],
          ),
        ),
        const SizedBox(height: Spacing.md),
        _card(
          p,
          title: 'What is being held back',
          child: Column(
            children: <Widget>[
              BreakdownRow(
                palette: p,
                label: 'Upcoming bills before payday',
                value: formatPeso(a.reservedBills),
              ),
              BreakdownRow(
                palette: p,
                label: 'Debt minimums (borrowings and loans)',
                value: formatPeso(a.reservedDebtMinimums),
              ),
              BreakdownRow(
                palette: p,
                label: 'Monthly installments (BNPL & SIP)',
                value: formatPeso(a.reservedInstallments),
              ),
              BreakdownRow(
                palette: p,
                label: 'Emergency buffer',
                value: formatPeso(a.emergencyBuffer),
              ),
              Divider(height: Spacing.lg, color: p.border),
              BreakdownRow(
                palette: p,
                label: 'Total reserved',
                value: formatPeso(a.amountReserved),
                valueColor: p.warning,
                emphasis: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _streams(Palette p) {
    final List<IncomeStream> streams = widget.state.incomeStreams;
    final bool conservative =
        widget.state.scenario == DecisionScenario.conservative;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'These are the inflows Safe to Spend assumes before your next '
          'payday. In the conservative scenario, money that is not guaranteed '
          'is discounted.',
          style: AppType.body(p),
        ),
        const SizedBox(height: Spacing.lg),
        for (final IncomeStream s in streams) ...<Widget>[
          _streamRow(p, s, conservative),
          const SizedBox(height: Spacing.sm),
        ],
        const SizedBox(height: Spacing.sm),
        _card(
          p,
          title: 'Counted toward this cutoff',
          child: BreakdownRow(
            palette: p,
            label: 'Total expected inflow',
            value: formatPeso(
              widget.state.safeToSpendAnalysis.totalExpectedInflow,
            ),
            valueColor: p.positive,
            emphasis: true,
          ),
        ),
      ],
    );
  }

  /// One income stream, with the haircut the conservative scenario applies
  /// shown rather than silently subtracted.
  Widget _streamRow(Palette p, IncomeStream s, bool conservative) {
    final bool halved =
        conservative &&
        (s.type == IncomeStreamType.freelance ||
            s.type == IncomeStreamType.irregular);
    final bool excluded =
        conservative && s.type == IncomeStreamType.thirteenthMonth;

    final double counted = excluded
        ? 0
        : halved
        ? s.expectedAmount * 0.5
        : s.expectedAmount;

    return Container(
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(Radii.control),
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  s.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.rowTitle(p),
                ),
              ),
              const SizedBox(width: Spacing.sm),
              Text(
                formatPeso(counted),
                style: AppType.amountSmall(
                  p,
                ).copyWith(color: excluded ? p.textMuted : p.positive),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(_streamLabel(s.type), style: AppType.rowMeta(p)),
          if (halved || excluded) ...<Widget>[
            const SizedBox(height: Spacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: Spacing.sm,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: p.warningSoft,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                excluded
                    ? 'Excluded: a year-end bonus does not help pace this fortnight'
                    : 'Halved: ${formatPeso(s.expectedAmount)} expected, counted at 50% for volatility',
                style: AppType.caption(p).copyWith(color: p.textPrimary),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _streamLabel(IncomeStreamType t) => switch (t) {
    IncomeStreamType.weeklyIncome => 'Weekly Income',
    IncomeStreamType.semimonthlySalary => '15th & 30th Cutoff Salary',
    IncomeStreamType.monthlySalary => 'Monthly Payroll',
    IncomeStreamType.freelance => 'Freelance & Retainers',
    IncomeStreamType.irregular => 'Irregular Gig Income',
    IncomeStreamType.thirteenthMonth => '13th-Month Pay Benefit',
    IncomeStreamType.remittance => 'Remittance & Padala',
  };

  /// The audit tab. Every step in order, with the figure it produced, so the
  /// headline number can be checked rather than believed.
  Widget _audit(Palette p, SafeToSpendAnalysis a) {
    final bool conservative =
        widget.state.scenario == DecisionScenario.conservative;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Every step that produced the figure on Home, in order.',
          style: AppType.body(p),
        ),
        const SizedBox(height: Spacing.lg),
        _step(
          p,
          '1',
          'Add up liquid cash',
          'Cash, GCash, Maya, banks and debit. Investments, receivables and '
              'anything you can borrow are left out.',
          formatPeso(a.totalLiquidCash),
        ),
        _step(
          p,
          '2',
          'Hold back unpaid bills',
          conservative
              ? 'Padded by 10% in the conservative scenario.'
              : 'Taken at face value in the optimistic scenario.',
          formatPeso(a.reservedBills),
        ),
        _step(
          p,
          '3',
          'Hold back debt minimums',
          'Estimated at 8% of what is still outstanding.',
          formatPeso(a.reservedDebtMinimums),
        ),
        _step(
          p,
          '4',
          'Hold back installments',
          'Every active BNPL and investment plan instalment.',
          formatPeso(a.reservedInstallments),
        ),
        _step(
          p,
          '5',
          'Hold back an emergency buffer',
          conservative
              ? '15% of liquid cash in the conservative scenario.'
              : '5% of liquid cash in the optimistic scenario.',
          formatPeso(a.emergencyBuffer),
        ),
        _step(
          p,
          '6',
          'What is left is uncommitted',
          'Liquid cash minus everything reserved above.',
          formatPeso(a.safeToSpendUntilPayday + a.safeToSave),
        ),
        _step(
          p,
          '7',
          'Split it 85 / 15',
          '85% is safe to spend, 15% is safe to save.',
          '${formatPeso(a.safeToSpendUntilPayday)} + ${formatPeso(a.safeToSave)}',
        ),
        _step(
          p,
          '8',
          'Divide by days to payday',
          '${a.daysToPayday} days left, so this is the daily figure.',
          formatPeso(a.safeToSpendToday),
        ),
      ],
    );
  }

  Widget _step(
    Palette p,
    String number,
    String title,
    String detail,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: p.accentSoft,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              number,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: p.accent,
              ),
            ),
          ),
          const SizedBox(width: Spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(child: Text(title, style: AppType.rowTitle(p))),
                    const SizedBox(width: Spacing.sm),
                    Text(
                      value,
                      style: AppType.amountSmall(p).copyWith(fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(detail, style: AppType.caption(p)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(Palette p, {required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Spacing.lg),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(Radii.control),
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: AppType.section(p)),
          const SizedBox(height: Spacing.sm),
          child,
        ],
      ),
    );
  }
}
