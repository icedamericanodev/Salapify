import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../design/tokens.dart';
import '../../core/money/format.dart';
import '../../core/money/js_round.dart';
import '../../models/models.dart';
import '../../state/financial_state.dart';
import 'home_kit.dart';

/// Budget Pulse, ported from src/components/BudgetPulseCard.tsx.
///
/// One figure answers the question people actually open this for: how much of
/// the month's budget is left. The percentage and the small rail sit on the
/// right so the peso amount keeps the eye.
class BudgetPulseCard extends StatelessWidget {
  const BudgetPulseCard({super.key, required this.state, this.onSeeAll});

  final FinancialState state;
  final VoidCallback? onSeeAll;

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
          .where(
            (Transaction t) =>
                t.type == TransactionType.expense &&
                t.category.toLowerCase() == b.category.toLowerCase(),
          )
          .fold<double>(0, (double sum, Transaction t) => sum + t.amount);

      final double remaining = b.limit - spent;
      final int percent = math.min(100, jsRound((spent / b.limit) * 100));
      final bool isOver = remaining < 0;
      final bool isNear = percent >= 80 && remaining >= 0;
      if (isOver || isNear) watchCount++;

      limitSum += b.limit;
      spentSum += spent;
    }

    final double totalRemaining = math.max(0, limitSum - spentSum);
    final int percentTotal = limitSum > 0
        ? math.min(100, jsRound((spentSum / limitSum) * 100))
        : 0;

    return SectionCard(
      palette: palette,
      onTap: onSeeAll,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              IconTile(
                palette: palette,
                icon: Icons.pie_chart_outline,
                size: 26,
                iconSize: 13,
                background: palette.positiveSoft,
                foreground: palette.positive,
              ),
              const SizedBox(width: Spacing.sm),
              Expanded(
                child: Text(
                  'BUDGET PULSE',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                    color: palette.textPrimary,
                  ),
                ),
              ),
              Icon(Icons.chevron_right, size: 18, color: palette.textMuted),
            ],
          ),
          const SizedBox(height: Spacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Total Remaining',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: palette.textMuted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      formatPeso(totalRemaining),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: palette.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Spacing.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Text(
                    '$percentTotal% Spent',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: palette.textMuted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(Radii.pill),
                    child: SizedBox(
                      width: 80,
                      height: 8,
                      child: LinearProgressIndicator(
                        value: percentTotal / 100,
                        backgroundColor: palette.trackSoft,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          palette.positive,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (watchCount > 0) ...<Widget>[
            const SizedBox(height: Spacing.md),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: Spacing.md,
                vertical: Spacing.sm,
              ),
              decoration: BoxDecoration(
                color: palette.warningSoft,
                borderRadius: BorderRadius.circular(Radii.tile),
              ),
              child: Row(
                children: <Widget>[
                  Icon(
                    Icons.error_outline,
                    size: 13,
                    color: palette.textPrimary,
                  ),
                  const SizedBox(width: Spacing.sm),
                  Expanded(
                    child: Text(
                      watchCount == 1
                          ? '1 category requires attention'
                          : '$watchCount categories require attention',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: palette.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
