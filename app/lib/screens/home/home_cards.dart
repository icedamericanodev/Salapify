import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../design/tokens.dart';
import '../../engine/format.dart';
import '../../engine/js_round.dart';
import '../../models/models.dart';
import '../../state/financial_state.dart';

/// A plain card shell, so every card on Home agrees about radius and border.
class HomeCard extends StatelessWidget {
  const HomeCard({
    super.key,
    required this.palette,
    required this.child,
    this.onTap,
  });

  final Palette palette;
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: palette.surface,
      borderRadius: BorderRadius.circular(Radii.card),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.card),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(Spacing.lg),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Radii.card),
            border: Border.all(color: palette.border),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Budget Pulse, ported from src/components/BudgetPulseCard.tsx.
class BudgetPulseCard extends StatelessWidget {
  const BudgetPulseCard({super.key, required this.state});

  final FinancialState state;

  @override
  Widget build(BuildContext context) {
    final Palette palette = Palette.of(state.theme);
    final List<Budget> budgets = state.budgets;
    if (budgets.isEmpty) return const SizedBox.shrink();

    double limitSum = 0;
    double spentSum = 0;
    int watchCount = 0;

    for (final Budget b in budgets) {
      // The prototype matches the category case-insensitively.
      final double spent = state.transactions
          .where((Transaction t) =>
              t.type == TransactionType.expense &&
              t.category.toLowerCase() == b.category.toLowerCase())
          .fold<double>(0, (double sum, Transaction t) => sum + t.amount);

      final double remaining = b.limit - spent;
      final int percent =
          math.min(100, jsRound((spent / b.limit) * 100));
      final bool isOver = remaining < 0;
      final bool isNear = percent >= 80 && remaining >= 0;
      if (isOver || isNear) watchCount++;

      limitSum += b.limit;
      spentSum += spent;
    }

    final double totalRemaining = math.max(0, limitSum - spentSum);
    final int percentTotal =
        limitSum > 0 ? math.min(100, jsRound((spentSum / limitSum) * 100)) : 0;

    return HomeCard(
      palette: palette,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.pie_chart_outline, size: 14, color: palette.positive),
              const SizedBox(width: Spacing.sm),
              Expanded(
                child: Text(
                  'BUDGET PULSE',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                    color: palette.textPrimary,
                  ),
                ),
              ),
              if (watchCount > 0)
                Text(
                  '$watchCount to watch',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: palette.warning,
                  ),
                ),
            ],
          ),
          const SizedBox(height: Spacing.md),
          Text(
            formatPeso(totalRemaining, showDecimals: false),
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: palette.textPrimary,
            ),
          ),
          Text(
            'left of ${formatPeso(limitSum, showDecimals: false)} budgeted',
            style: TextStyle(fontSize: 13, color: palette.textMuted),
          ),
          const SizedBox(height: Spacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(Radii.pill),
            child: LinearProgressIndicator(
              value: percentTotal / 100,
              minHeight: 5,
              backgroundColor: palette.border,
              valueColor: AlwaysStoppedAnimation<Color>(
                percentTotal >= 100 ? palette.negative : palette.accent,
              ),
            ),
          ),
          const SizedBox(height: Spacing.sm),
          Text(
            '$percentTotal% of this month spent',
            style: TextStyle(fontSize: 11, color: palette.textMuted),
          ),
        ],
      ),
    );
  }
}

/// Debts, both directions, ported from src/components/DebtBeamCard.tsx.
class DebtBeamCard extends StatelessWidget {
  const DebtBeamCard({super.key, required this.state});

  final FinancialState state;

  @override
  Widget build(BuildContext context) {
    final Palette palette = Palette.of(state.theme);
    final double owedToMe = state.debtsOwedToMe;
    final double iOwe = state.debtsIOwe;
    final double combined = owedToMe + iOwe;

    // The beam never collapses to nothing on either side, so both numbers
    // stay readable even when one dwarfs the other.
    final double owedToMePercent =
        combined > 0 ? ((owedToMe / combined) * 100).clamp(12, 88) : 50;

    final List<Debt> dueSoon = state.debts
        .where((Debt d) => !d.isSettled && d.dueDate != null)
        .toList()
      ..sort((Debt a, Debt b) => (a.dueDate ?? '').compareTo(b.dueDate ?? ''));
    final Debt? nextDue = dueSoon.isEmpty ? null : dueSoon.first;

    return HomeCard(
      palette: palette,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Debts (both ways)',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: palette.textPrimary,
            ),
          ),
          const SizedBox(height: Spacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: _beamSide(
                  palette: palette,
                  label: 'Owed to me',
                  amount: owedToMe,
                  color: palette.positive,
                  alignEnd: false,
                ),
              ),
              Expanded(
                child: _beamSide(
                  palette: palette,
                  label: 'I owe',
                  amount: iOwe,
                  color: palette.negative,
                  alignEnd: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.md),
          // The proportional beam, one 5dp track split between the two sides.
          ClipRRect(
            borderRadius: BorderRadius.circular(Radii.pill),
            child: SizedBox(
              height: 5,
              child: Row(
                children: <Widget>[
                  Expanded(
                    flex: owedToMePercent.round(),
                    child: ColoredBox(color: palette.positive),
                  ),
                  Expanded(
                    flex: (100 - owedToMePercent).round(),
                    child: ColoredBox(color: palette.negative),
                  ),
                ],
              ),
            ),
          ),
          if (nextDue != null) ...<Widget>[
            const SizedBox(height: Spacing.md),
            Text(
              'Next due: ${nextDue.person}, ${nextDue.dueDate}',
              style: TextStyle(fontSize: 11, color: palette.textMuted),
            ),
          ],
        ],
      ),
    );
  }

  Widget _beamSide({
    required Palette palette,
    required String label,
    required double amount,
    required Color color,
    required bool alignEnd,
  }) {
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: TextStyle(fontSize: 11, color: palette.textMuted),
        ),
        const SizedBox(height: 2),
        Text(
          formatPeso(amount, showDecimals: false),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }
}

/// Coming Up, the near-term bills, subscriptions and payday.
class ComingUpCard extends StatelessWidget {
  const ComingUpCard({super.key, required this.state});

  final FinancialState state;

  @override
  Widget build(BuildContext context) {
    final Palette palette = Palette.of(state.theme);
    final List<UpcomingItem> items = state.upcoming;

    return HomeCard(
      palette: palette,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Coming up',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: palette.textPrimary,
            ),
          ),
          const SizedBox(height: Spacing.sm),
          for (final UpcomingItem item in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          item.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: palette.textPrimary,
                          ),
                        ),
                        Text(
                          item.dueDate,
                          style: TextStyle(fontSize: 11, color: palette.textMuted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: Spacing.sm),
                  Text(
                    item.isIncome
                        ? formatSignedPeso(item.amount, isIncome: true)
                        : formatPeso(item.amount, showDecimals: false),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: item.isIncome ? palette.positive : palette.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Latest Transactions, the newest handful from the ledger.
class LatestTransactionsCard extends StatelessWidget {
  const LatestTransactionsCard({super.key, required this.state});

  final FinancialState state;

  @override
  Widget build(BuildContext context) {
    final Palette palette = Palette.of(state.theme);
    final List<Transaction> latest = state.latestTransactions.take(5).toList();

    return HomeCard(
      palette: palette,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Latest',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: palette.textPrimary,
            ),
          ),
          const SizedBox(height: Spacing.sm),
          for (final Transaction t in latest)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          t.merchant ?? t.category,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: palette.textPrimary,
                          ),
                        ),
                        Text(
                          '${t.category} · ${formatDateLabel(t.date)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11, color: palette.textMuted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: Spacing.sm),
                  Text(
                    t.type == TransactionType.income
                        ? formatSignedPeso(t.amount, isIncome: true)
                        : formatPeso(t.amount),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: t.type == TransactionType.income
                          ? palette.positive
                          : palette.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
