import 'package:flutter/material.dart';

import '../../design/tokens.dart';
import '../../core/money/format.dart';
import '../../models/models.dart';
import '../../state/financial_state.dart';

/// The Safe to Spend hero, ported from src/components/HeroPanel.tsx.
///
/// It keeps its warm gradient in both themes, exactly as the prototype does,
/// and lays a soft dark veil over it at night instead of inverting. Every
/// label on it is drawn in one of two browns, because the gradient underneath
/// does not change between Hapon and Gabi.
class HeroPanel extends StatelessWidget {
  const HeroPanel({
    super.key,
    required this.state,
    this.onOpenDetails,
    this.onOpenHealthCheck,
    this.onInfo,
  });

  final FinancialState state;
  final VoidCallback? onOpenDetails;
  final VoidCallback? onOpenHealthCheck;
  final VoidCallback? onInfo;

  @override
  Widget build(BuildContext context) {
    final SafeToSpendAnalysis analysis = state.safeToSpendAnalysis;
    final PaydayCycle payday = state.payday;
    final bool isNight = state.theme == ThemeMode2.gabi;

    // How far along the current cutoff we are. The prototype clamps this
    // between 10 and 100 so the rail is never an invisible sliver.
    //
    // An UNSET payday would compute 15 days passed out of 15 and draw a full
    // rail, which reads as "your cutoff is over" to somebody who has never
    // told Salapify when they get paid. It sits at the floor instead.
    const int cycleDays = 15;
    final int daysPassed = cycleDays - payday.daysToPayday;
    final double progress = payday.isSet
        ? ((daysPassed / cycleDays) * 100).clamp(10, 100) / 100
        : 0.1;

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
            padding: const EdgeInsets.fromLTRB(
              Spacing.lg,
              Spacing.md,
              Spacing.lg,
              Spacing.lg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _kickerRow(),
                _toolRow(),
                Text(
                  formatPeso(state.safeToSpend),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 36,
                    height: 1.1,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.8,
                    color: HeroColors.inkStrong,
                  ),
                ),
                const SizedBox(height: Spacing.xs),
                Text(
                  // NO PER-DAY FIGURE WITHOUT A PAYDAY, and this is the most
                  // important line in the file. The engine divides by
                  // max(1, daysToPayday), so an unset cycle makes the daily
                  // figure equal the WHOLE fortnight's. The card would tell
                  // somebody with 36,125 pesos of room that they may spend
                  // 36,125 pesos a day, which is not a rounding error, it is
                  // the opposite of the advice this screen exists to give.
                  payday.isSet
                      ? '${formatPeso(state.safeToSpendPerDay, showDecimals: false)} a day until payday. '
                            '· Lasts ${analysis.cashRunwayDays} days'
                      : 'Set your payday to see a daily figure. '
                            '· Lasts ${analysis.cashRunwayDays} days',
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                    color: HeroColors.ink,
                  ),
                ),
                const SizedBox(height: Spacing.md),
                ClipRRect(
                  borderRadius: BorderRadius.circular(Radii.pill),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 5,
                    backgroundColor: HeroColors.ink.withValues(alpha: 0.22),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      HeroColors.ink,
                    ),
                  ),
                ),
                const SizedBox(height: Spacing.sm),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        payday.isSet
                            ? '${payday.daysToPayday} days to payday'
                            : 'Payday not set',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: HeroColors.ink,
                        ),
                      ),
                    ),
                    const SizedBox(width: Spacing.sm),
                    Text(
                      payday.isSet
                          ? '${payday.lastPayday} to ${payday.nextPayday.split(',').first}'
                          : '',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: HeroColors.ink,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _kickerRow() {
    final bool isConservative = state.scenario == DecisionScenario.conservative;

    // A Wrap rather than a Row. At 320dp the label, the scenario chip and the
    // info button together need more width than the card has, and a Row
    // overflows instead of giving way. Wrapping lets the chip drop to a second
    // line on a small phone and changes nothing on a normal one.
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        const Text(
          'SAFE TO SPEND',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
            color: HeroColors.ink,
          ),
        ),
        const SizedBox(width: Spacing.sm),
        // Tapping the chip flips the scenario, the prototype's conservative
        // and optimistic switch.
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
            // Center with widthFactor 1 is the point. A Container carrying an
            // `alignment` expands to every pixel its parent allows, which in a
            // Row went unnoticed (children get unbounded width there) and in a
            // Wrap made the chip claim a whole line to itself. widthFactor
            // shrink-wraps it back to the chip.
            child: SizedBox(
              height: 44,
              child: Center(
                widthFactor: 1,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: HeroColors.ink.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isConservative ? 'CONSERVATIVE' : 'OPTIMISTIC',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                      color: HeroColors.ink,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        Semantics(
          button: true,
          label: 'How Safe to Spend is calculated',
          child: InkWell(
            onTap: onInfo,
            customBorder: const CircleBorder(),
            child: const SizedBox(
              width: 44,
              height: 44,
              child: Icon(Icons.info_outline, size: 15, color: HeroColors.ink),
            ),
          ),
        ),
      ],
    );
  }

  /// Health Check and Details, the two ways off this card. Wrapped for the
  /// same reason as the kicker: both labels are set in caps and do not fit
  /// beside each other on a 320dp phone.
  Widget _toolRow() {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        _HeroTool(
          icon: Icons.monitor_heart_outlined,
          label: 'HEALTH CHECK',
          onTap: onOpenHealthCheck,
          // The dot is the diagnostic's own verdict. Until the health engine
          // is migrated it stays a single neutral-to-warning marker rather
          // than a green light nobody computed.
          trailing: Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Color(0xFFB91C1C),
              shape: BoxShape.circle,
            ),
          ),
        ),
        const SizedBox(width: Spacing.md),
        _HeroTool(
          icon: Icons.auto_awesome,
          label: 'DETAILS',
          onTap: onOpenDetails,
        ),
      ],
    );
  }
}

class _HeroTool extends StatelessWidget {
  const _HeroTool({
    required this.icon,
    required this.label,
    this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.pill),
        // Height fixed, width left to the child. Giving this an `alignment`
        // instead made it expand to the full width of the Wrap, so each tool
        // took a line of its own.
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: 13, color: HeroColors.ink),
              const SizedBox(width: Spacing.xs),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                  color: HeroColors.ink,
                ),
              ),
              if (trailing != null) ...<Widget>[
                const SizedBox(width: Spacing.xs),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
