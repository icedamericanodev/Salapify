import 'package:flutter/material.dart';

import '../../design/tokens.dart';
import '../../engine/format.dart';
import '../../models/models.dart';
import '../../state/financial_state.dart';

/// The Safe to Spend hero, ported from src/components/HeroPanel.tsx.
///
/// It keeps its warm gradient in both themes, exactly as the prototype does,
/// and lays a soft dark veil over it at night instead of inverting.
class HeroPanel extends StatelessWidget {
  const HeroPanel({super.key, required this.state});

  final FinancialState state;

  @override
  Widget build(BuildContext context) {
    final SafeToSpendAnalysis analysis = state.safeToSpendAnalysis;
    final PaydayCycle payday = state.payday;
    final bool isNight = state.theme == ThemeMode2.gabi;

    // How far along the current cutoff we are. The prototype clamps this
    // between 10 and 100 so the rail is never an invisible sliver.
    const int cycleDays = 15;
    final int daysPassed = cycleDays - payday.daysToPayday;
    final double progress =
        ((daysPassed / cycleDays) * 100).clamp(10, 100) / 100;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Radii.card),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: HeroColors.gradient,
        ),
      ),
      child: Stack(
        children: <Widget>[
          if (isNight)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(Radii.card),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(Spacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _kickerRow(context),
                const SizedBox(height: Spacing.sm),
                Text(
                  formatPeso(state.safeToSpend),
                  style: const TextStyle(
                    fontSize: 38,
                    height: 1.1,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.8,
                    color: HeroColors.inkStrong,
                  ),
                ),
                const SizedBox(height: Spacing.xs),
                Text(
                  '${formatPeso(state.safeToSpendPerDay, showDecimals: false)} a day until payday. '
                  'Lasts ${analysis.cashRunwayDays} days.',
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                    color: HeroColors.ink,
                  ),
                ),
                const SizedBox(height: Spacing.lg),
                _sweldoRail(progress),
                const SizedBox(height: Spacing.sm),
                _railLabels(payday),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _kickerRow(BuildContext context) {
    final bool isConservative =
        state.scenario == DecisionScenario.conservative;

    return Row(
      children: <Widget>[
        const Flexible(
          child: Text(
            'SAFE TO SPEND',
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
              color: HeroColors.ink,
            ),
          ),
        ),
        const SizedBox(width: Spacing.sm),
        // Tapping the badge flips the scenario, which is the prototype's
        // conservative / optimistic switch.
        Semantics(
          button: true,
          label: 'Switch decision scenario',
          child: InkWell(
            onTap: () => state.setScenario(
              isConservative
                  ? DecisionScenario.optimistic
                  : DecisionScenario.conservative,
            ),
            borderRadius: BorderRadius.circular(Radii.pill),
            child: Container(
              constraints: const BoxConstraints(minHeight: 44),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isConservative
                      ? HeroColors.ink
                      : HeroColors.ink.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isConservative ? 'CONSERVATIVE' : 'OPTIMISTIC',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: isConservative
                        ? const Color(0xFFFFEEDF)
                        : HeroColors.ink,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _sweldoRail(double progress) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(Radii.pill),
      child: LinearProgressIndicator(
        value: progress,
        minHeight: 5,
        backgroundColor: HeroColors.ink.withValues(alpha: 0.22),
        valueColor: const AlwaysStoppedAnimation<Color>(HeroColors.ink),
      ),
    );
  }

  Widget _railLabels(PaydayCycle payday) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Flexible(
          child: Text(
            '${payday.daysToPayday} days to payday',
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: HeroColors.ink,
            ),
          ),
        ),
        const SizedBox(width: Spacing.sm),
        Text(
          '${payday.lastPayday} to ${payday.nextPayday.split(',').first}',
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: HeroColors.ink,
          ),
        ),
      ],
    );
  }
}
