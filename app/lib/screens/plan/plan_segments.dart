import 'package:flutter/material.dart';

import '../../core/money/format.dart';
import '../../core/money/plan.dart';
import '../../data/seed_data.dart';
import '../../design/tokens.dart';
import '../../design/type.dart';
import '../../features/info/info_dot.dart';
import '../../features/info/info_sheet.dart';
import '../../features/shared/sheet_scaffold.dart';
import '../../models/models.dart';
import '../../state/financial_state.dart';
import 'budget_sheets.dart';

/// Plan's eight destinations, from src/components/PlanScreen.tsx.
enum PlanSegment {
  overview,
  budgets,
  bills,
  goals,
  decisions,
  trackers,
  calculators,
  academy;

  /// The seven that appear as tiles. Overview is the grid itself.
  static const List<PlanSegment> tiles = <PlanSegment>[
    PlanSegment.budgets,
    PlanSegment.bills,
    PlanSegment.goals,
    PlanSegment.decisions,
    PlanSegment.trackers,
    PlanSegment.calculators,
    PlanSegment.academy,
  ];

  String get title => switch (this) {
    PlanSegment.overview => 'Plan',
    PlanSegment.budgets => 'Budgets',
    PlanSegment.bills => 'Bills and payables',
    PlanSegment.goals => 'Goals',
    PlanSegment.decisions => 'Decisions',
    PlanSegment.trackers => 'Trackers',
    PlanSegment.calculators => 'Calculators',
    PlanSegment.academy => 'Academy',
  };

  String get kicker => switch (this) {
    PlanSegment.overview => 'What is coming, and whether you are on track',
    PlanSegment.budgets => 'Limits by category',
    PlanSegment.bills => 'What is due next',
    PlanSegment.goals => 'Ipon targets',
    PlanSegment.decisions => 'Before you spend',
    PlanSegment.trackers => 'Habits and subscriptions',
    PlanSegment.calculators => 'Tax, loans, pricing',
    PlanSegment.academy => '32 lessons, PH specific',
  };

  IconData get icon => switch (this) {
    PlanSegment.overview => Icons.track_changes_outlined,
    PlanSegment.budgets => Icons.pie_chart_outline,
    PlanSegment.bills => Icons.event_outlined,
    PlanSegment.goals => Icons.flag_outlined,
    PlanSegment.decisions => Icons.balance,
    PlanSegment.trackers => Icons.checklist_outlined,
    PlanSegment.calculators => Icons.calculate_outlined,
    PlanSegment.academy => Icons.school_outlined,
  };
}

// ---------------------------------------------------------------- budgets ---

class BudgetsSegment extends StatelessWidget {
  const BudgetsSegment({super.key, required this.palette, required this.state});

  final Palette palette;
  final FinancialState state;

  @override
  Widget build(BuildContext context) {
    final List<BudgetStatus> rows = computeBudgets(
      budgets: state.budgets,
      transactions: state.transactions,
      now: state.now,
    );
    final BudgetTotals totals = computeBudgetTotals(rows);

    // Trouble first. A list in a fixed order makes somebody read all seven to
    // find the one that needs them; over, then near, then the rest.
    final List<BudgetStatus> sorted = <BudgetStatus>[...rows]
      ..sort((BudgetStatus a, BudgetStatus b) {
        final int byHealth = b.health.index.compareTo(a.health.index);
        if (byHealth != 0) return byHealth;
        return b.percent.compareTo(a.percent);
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        PlanCard(
          palette: palette,
          title: 'Left to spend this month',
          topic: InfoTopic.budgets,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  formatPeso(totals.leftToSpend),
                  style: AppType.hero(palette).copyWith(
                    color: totals.overCount > 0
                        ? palette.warning
                        : palette.positive,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                totals.allOnTrack
                    ? 'Every budget on track'
                    : '${totals.overCount} over, ${totals.nearCount} to watch',
                style: AppType.caption(palette).copyWith(
                  color: totals.allOnTrack
                      ? palette.textMuted
                      : palette.warning,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: Spacing.md),
        for (final BudgetStatus b in sorted) ...<Widget>[
          _BudgetRow(
            palette: palette,
            row: b,
            onEdit: () => EditBudgetSheet.show(context, state, b),
          ),
          const SizedBox(height: Spacing.sm),
        ],
      ],
    );
  }
}

class _BudgetRow extends StatelessWidget {
  const _BudgetRow({
    required this.palette,
    required this.row,
    required this.onEdit,
  });

  final Palette palette;
  final BudgetStatus row;
  final VoidCallback onEdit;

  Color get _colour => switch (row.health) {
    BudgetHealth.over => palette.negative,
    BudgetHealth.near => palette.warning,
    BudgetHealth.onTrack => palette.positive,
  };

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Change the ${row.category} limit',
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(Radii.card),
        child: Container(
          padding: const EdgeInsets.all(Spacing.md),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(Radii.card),
            border: Border.all(
              // The over row is outlined, not just tinted. A colour difference
              // alone is the thing that disappears in greyscale and for anyone
              // who cannot separate red from green.
              color: row.isOver ? palette.negative : palette.border,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  // The emoji is the USER'S, from their category. Salapify's
                  // own icons are Material glyphs; this one is not ours.
                  Text(row.emoji, style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: Spacing.xs),
                  Expanded(
                    child: Text(
                      row.category,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.rowTitle(palette),
                    ),
                  ),
                  Text(
                    formatPeso(row.spent),
                    style: AppType.amountSmall(palette),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(Radii.pill),
                child: LinearProgressIndicator(
                  value: (row.percent / 100).clamp(0.0, 1.0),
                  minHeight: 6,
                  backgroundColor: palette.trackSoft,
                  valueColor: AlwaysStoppedAnimation<Color>(_colour),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      row.isOver
                          // The amount OVER, not a clamped zero. Somebody 450
                          // past their limit needs the 450.
                          ? '${formatPeso(-row.remaining)} over limit'
                          : '${formatPeso(row.remaining)} left of '
                                '${formatPeso(row.limit, showDecimals: false)}',
                      style: AppType.caption(palette).copyWith(
                        color: row.isOver
                            ? palette.negative
                            : palette.textMuted,
                        fontWeight: row.isOver
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                  Text(
                    '${row.percent}% · '
                    '${row.entryCount == 1 ? '1 entry' : '${row.entryCount} entries'}',
                    style: AppType.caption(palette),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ bills ---

class BillsSegment extends StatelessWidget {
  const BillsSegment({super.key, required this.palette, required this.state});

  final Palette palette;
  final FinancialState state;

  @override
  Widget build(BuildContext context) {
    final UpcomingTotals t = computeUpcomingTotals(state.upcoming);
    final List<UpcomingItem> items = state.upcoming;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // TWO figures, not one. The prototype prints a single "Total Scheduled
        // Bills" that includes payday, so the headline read 38,029 when the
        // bills came to 5,529.
        StatPair(
          left: StatCard(
            palette: palette,
            label: 'Going out',
            value: formatPeso(t.totalOut),
            caption: t.billCount == 1 ? '1 bill' : '${t.billCount} bills',
            valueColor: palette.negative,
          ),
          right: StatCard(
            palette: palette,
            label: 'Coming in',
            value: formatPeso(t.totalIn),
            caption: 'Payday and income',
            valueColor: palette.positive,
          ),
        ),
        const SizedBox(height: Spacing.md),
        PlanCard(
          palette: palette,
          title: 'Scheduled',
          topic: InfoTopic.bills,
          child: items.isEmpty
              ? Text('Nothing scheduled.', style: AppType.caption(palette))
              : Column(
                  children: <Widget>[
                    for (final UpcomingItem u in items)
                      _BillRow(palette: palette, item: u, state: state),
                  ],
                ),
        ),
      ],
    );
  }
}

class _BillRow extends StatelessWidget {
  const _BillRow({
    required this.palette,
    required this.item,
    required this.state,
  });

  final Palette palette;
  final UpcomingItem item;
  final FinancialState state;

  @override
  Widget build(BuildContext context) {
    final bool income = item.countsAsIncome;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: <Widget>[
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: palette.iconTile,
              borderRadius: BorderRadius.circular(Radii.control),
            ),
            child: Icon(
              income ? Icons.south_west : Icons.north_east,
              size: 15,
              color: income ? palette.positive : palette.accent,
            ),
          ),
          const SizedBox(width: Spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.rowTitle(palette).copyWith(
                    decoration: item.isPaid ? TextDecoration.lineThrough : null,
                    color: item.isPaid
                        ? palette.textMuted
                        : palette.textPrimary,
                  ),
                ),
                Text(
                  item.isPaid ? 'Paid' : 'Due ${item.dueDate}',
                  style: AppType.caption(palette),
                ),
              ],
            ),
          ),
          const SizedBox(width: Spacing.sm),
          Text(
            formatPeso(item.amount),
            style: AppType.amountSmall(palette).copyWith(
              color: item.isPaid
                  ? palette.textMuted
                  : (income ? palette.positive : palette.textPrimary),
              decoration: item.isPaid ? TextDecoration.lineThrough : null,
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ goals ---

class GoalsSegment extends StatelessWidget {
  const GoalsSegment({super.key, required this.palette, required this.state});

  final Palette palette;
  final FinancialState state;

  @override
  Widget build(BuildContext context) {
    final List<GoalStatus> rows = computeGoals(state.goals);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        PrimaryButton(
          palette: palette,
          label: 'Add a goal',
          icon: Icons.add,
          onTap: () => AddGoalSheet.show(context, state),
        ),
        const SizedBox(height: Spacing.md),
        for (final GoalStatus g in rows) ...<Widget>[
          _GoalRow(
            palette: palette,
            row: g,
            onContribute: () => ContributeSheet.show(context, state, g),
          ),
          const SizedBox(height: Spacing.sm),
        ],
      ],
    );
  }
}

class _GoalRow extends StatelessWidget {
  const _GoalRow({
    required this.palette,
    required this.row,
    required this.onContribute,
  });

  final Palette palette;
  final GoalStatus row;
  final VoidCallback onContribute;

  @override
  Widget build(BuildContext context) {
    final Goal g = row.goal;

    return Container(
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(
          color: row.isComplete ? palette.positive : palette.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(g.emoji, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: Spacing.xs),
              Expanded(
                child: Text(
                  g.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.rowTitle(palette),
                ),
              ),
              Text(
                formatPeso(g.currentAmount),
                style: AppType.amountSmall(palette),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(Radii.pill),
            child: LinearProgressIndicator(
              value: (row.percent / 100).clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: palette.trackSoft,
              valueColor: AlwaysStoppedAnimation<Color>(
                row.isComplete ? palette.positive : palette.accent,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            row.isComplete
                ? 'Funded. ${formatPeso(g.targetAmount)} reached.'
                : '${row.percent}% of ${formatPeso(g.targetAmount)} · '
                      '${formatPeso(row.remaining)} to go'
                      '${row.monthsAtCurrentRate == null ? '' : ' · about ${row.monthsAtCurrentRate} months at ${formatPeso(g.monthlyTarget, showDecimals: false)} a month'}',
            style: AppType.caption(palette).copyWith(
              color: row.isComplete ? palette.positive : palette.textMuted,
            ),
          ),
          if (!row.isComplete) ...<Widget>[
            const SizedBox(height: Spacing.sm),
            Semantics(
              button: true,
              label: 'Add money to ${g.name}',
              child: InkWell(
                onTap: onContribute,
                borderRadius: BorderRadius.circular(Radii.control),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 44),
                  alignment: Alignment.centerLeft,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(Icons.add, size: 16, color: palette.accent),
                      const SizedBox(width: Spacing.xs),
                      Text(
                        'Add to this goal',
                        style: AppType.button(palette, color: palette.accent),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// -------------------------------------------------------------- decisions ---

class DecisionsSegment extends StatelessWidget {
  const DecisionsSegment({
    super.key,
    required this.palette,
    required this.state,
    required this.onOpenSafeToSpend,
  });

  final Palette palette;
  final FinancialState state;
  final VoidCallback onOpenSafeToSpend;

  @override
  Widget build(BuildContext context) {
    final SafeToSpendAnalysis a = state.safeToSpendAnalysis;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        PlanCard(
          palette: palette,
          title: 'Safe to spend today',
          topic: InfoTopic.decisions,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  formatPeso(a.safeToSpendToday),
                  style: AppType.hero(
                    palette,
                  ).copyWith(color: palette.positive),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${formatPeso(a.amountReserved)} already spoken for',
                style: AppType.caption(palette),
              ),
              const SizedBox(height: Spacing.sm),
              PrimaryButton(
                palette: palette,
                label: 'Open the simulator',
                icon: Icons.tune,
                onTap: onOpenSafeToSpend,
              ),
            ],
          ),
        ),
        const SizedBox(height: Spacing.md),
        PlanCard(
          palette: palette,
          title: 'Money coming in',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              for (final IncomeStream s in state.incomeStreams)
                BreakdownRow(
                  palette: palette,
                  label: s.name,
                  value: formatPeso(s.expectedAmount),
                ),
              const SizedBox(height: Spacing.sm),
              PrimaryButton(
                palette: palette,
                label: 'Add an income stream',
                icon: Icons.add,
                onTap: () => AddStreamSheet.show(context, state),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// --------------------------------------------------------------- trackers ---

class TrackersSegment extends StatelessWidget {
  const TrackersSegment({
    super.key,
    required this.palette,
    required this.state,
  });

  final Palette palette;
  final FinancialState state;

  @override
  Widget build(BuildContext context) {
    const List<HabitItem> habits = SeedData.habits;
    const List<SubscriptionItem> subs = SeedData.subscriptions;

    // COMPUTED, not hardcoded. The prototype prints a fixed 3,288 beside a
    // list that does not add up to it under any reading, and an annual plan
    // counted as monthly is a fivefold error on that row alone.
    final double monthly = subs.fold<double>(
      0,
      (double s, SubscriptionItem x) => s + x.monthlyCost,
    );
    final int longest = habits.fold<int>(
      0,
      (int m, HabitItem h) => h.streak > m ? h.streak : m,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        PlanCard(
          palette: palette,
          title: 'Habits',
          topic: InfoTopic.trackers,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Longest streak $longest days',
                style: AppType.rowTitle(palette),
              ),
              const SizedBox(height: Spacing.sm),
              for (final HabitItem h in habits)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: <Widget>[
                      Icon(
                        h.doneToday
                            ? Icons.check_circle
                            : Icons.circle_outlined,
                        size: 16,
                        color: h.doneToday
                            ? palette.positive
                            : palette.textMuted,
                      ),
                      const SizedBox(width: Spacing.sm),
                      Expanded(
                        child: Text(
                          h.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.body(palette),
                        ),
                      ),
                      Text(
                        '${h.streak} ${h.isDaily ? 'days' : 'weeks'}',
                        style: AppType.caption(palette),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: Spacing.md),
        PlanCard(
          palette: palette,
          title: 'Subscriptions',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                '${formatPeso(monthly)} a month',
                style: AppType.rowTitle(palette),
              ),
              Text(
                'Annual plans counted at a twelfth',
                style: AppType.caption(palette),
              ),
              const SizedBox(height: Spacing.sm),
              for (final SubscriptionItem s in subs)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              s.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppType.body(palette),
                            ),
                            if (s.unusedAlert ||
                                s.duplicateAlert ||
                                s.state == SubscriptionState.trial)
                              Text(
                                s.state == SubscriptionState.trial
                                    ? 'Trial ends ${s.trialEnds}'
                                    : s.duplicateAlert
                                    ? 'Looks like a duplicate'
                                    : 'Looks unused',
                                style: AppType.caption(
                                  palette,
                                ).copyWith(color: palette.warning),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: Spacing.sm),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: <Widget>[
                          Text(
                            formatPeso(s.amount),
                            style: AppType.amountSmall(palette),
                          ),
                          Text(
                            s.cycle == BillingCycle.annual
                                ? 'a year'
                                : 'a month',
                            style: AppType.caption(palette),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------ calculators ---

class CalculatorsSegment extends StatelessWidget {
  const CalculatorsSegment({
    super.key,
    required this.palette,
    required this.onOpenTax,
    required this.onOpenBusiness,
    required this.onOpenDebt,
    required this.onOpenSafeToSpend,
  });

  final Palette palette;
  final VoidCallback onOpenTax;
  final VoidCallback onOpenBusiness;
  final VoidCallback onOpenDebt;
  final VoidCallback onOpenSafeToSpend;

  @override
  Widget build(BuildContext context) {
    // These four already EXIST in app/, built with the Home sheets. This
    // segment is a launcher, not new work, which is why it earns its place in
    // this batch rather than waiting.
    final List<({String title, String note, IconData icon, VoidCallback tap})>
    items = <({String title, String note, IconData icon, VoidCallback tap})>[
      (
        title: 'Income tax',
        note: 'Graduated rates against the 8 percent option',
        icon: Icons.receipt_long_outlined,
        tap: onOpenTax,
      ),
      (
        title: 'Business and pricing',
        note: 'Percentage tax, VAT, and what to charge',
        icon: Icons.storefront_outlined,
        tap: onOpenBusiness,
      ),
      (
        title: 'Loan and payoff',
        note: 'What a debt really costs and when it ends',
        icon: Icons.account_balance_outlined,
        tap: onOpenDebt,
      ),
      (
        title: 'Safe to spend',
        note: 'What is genuinely free to spend today',
        icon: Icons.savings_outlined,
        tap: onOpenSafeToSpend,
      ),
    ];

    return Column(
      children: <Widget>[
        for (final ({
              String title,
              String note,
              IconData icon,
              VoidCallback tap,
            })
            i
            in items) ...<Widget>[
          Semantics(
            button: true,
            label: i.title,
            child: InkWell(
              onTap: i.tap,
              borderRadius: BorderRadius.circular(Radii.card),
              child: Container(
                constraints: const BoxConstraints(minHeight: 44),
                padding: const EdgeInsets.all(Spacing.md),
                decoration: BoxDecoration(
                  color: palette.surface,
                  borderRadius: BorderRadius.circular(Radii.card),
                  border: Border.all(color: palette.border),
                ),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: palette.iconTile,
                        borderRadius: BorderRadius.circular(Radii.control),
                      ),
                      child: Icon(i.icon, size: 16, color: palette.accent),
                    ),
                    const SizedBox(width: Spacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(i.title, style: AppType.rowTitle(palette)),
                          Text(i.note, style: AppType.caption(palette)),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: palette.textMuted,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: Spacing.sm),
        ],
      ],
    );
  }
}

// ------------------------------------------------------------------ shared ---

/// A Plan card, with the same header-row dot arrangement Reports uses so the
/// two tabs do not drift apart.
class PlanCard extends StatelessWidget {
  const PlanCard({
    super.key,
    required this.palette,
    required this.title,
    required this.child,
    this.topic,
  });

  final Palette palette;
  final String title;
  final Widget child;
  final InfoTopic? topic;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  style: AppType.kicker(palette),
                ),
              ),
              if (topic != null)
                InfoDot(
                  color: palette.textMuted,
                  semanticLabel: 'What $title means',
                  onTap: () => InfoSheet.show(context, palette, topic!),
                ),
            ],
          ),
          SizedBox(height: topic == null ? Spacing.sm : 0),
          child,
        ],
      ),
    );
  }
}
