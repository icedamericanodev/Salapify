import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../design/tokens.dart';
import '../../core/money/format.dart';
import '../../core/money/js_round.dart';
import '../../core/money/money.dart';
import '../../core/money/plan.dart';
import '../../models/models.dart';
import '../../state/financial_state.dart';
import 'home_kit.dart';

/// Budget Pulse, ported from archive/prototype-google-ai-studio/src/components/BudgetPulseCard.tsx.
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

    // THE PLAN ENGINE'S FIGURES, not a copy of its arithmetic. This card
    // used to run its own loop, and the copy had drifted: it summed spending
    // from ALL TIME and counted entries marked excluded, while Plan counts
    // this month only and skips them. So Home said "Total Remaining
    // 22,585.25" and Plan said "Left to spend this month 25,425.25" for the
    // same budgets. Found by the UI review of 2026-10-07; one source now,
    // so the two can never disagree again.
    final BudgetTotals totals = computeBudgetTotals(
      computeBudgets(
        budgets: budgets,
        transactions: state.transactions,
        now: state.now,
      ),
    );
    final Money totalRemaining = totals.leftToSpend;
    final int watchCount = totals.overCount + totals.nearCount;
    final int percentTotal = totals.totalLimit.isPositive
        ? math.min(
            100,
            jsRound(
              (totals.totalSpent.centavos / totals.totalLimit.centavos) * 100,
            ),
          )
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
                      formatPeso(totalRemaining.pesos),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: palette.textPrimary,
                        fontFeatures: const <FontFeature>[
                          FontFeature.tabularFigures(),
                        ],
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
