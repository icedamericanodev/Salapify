import 'package:flutter/material.dart';

import '../../design/tokens.dart';
import '../../core/money/format.dart';
import '../../core/money/health_check.dart';
import '../../models/models.dart';
import '../../state/financial_state.dart';

/// Lets a test find the attention marker beside HEALTH CHECK, or prove there
/// is none. An absent dot is the interesting case and nothing else on the
/// card changes shape when it goes, so without a handle on it a guard would
/// have to assert about a colour.
const Key healthDotKey = ValueKey<String>('health-dot');

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
    this.onSetPayday,
    this.onInfo,
  });

  final FinancialState state;
  final VoidCallback? onOpenDetails;
  final VoidCallback? onOpenHealthCheck;

  /// Opens the payday editor.
  ///
  /// This card has asked for a payday since it was built, in the sentence
  /// under the big figure, and until now there was nowhere to answer it. The
  /// prompt is the control now rather than a suggestion about some other
  /// screen the person is meant to find.
  final VoidCallback? onSetPayday;
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
                  _subtitle(analysis),
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
                    // TAPPABLE, and the unset case is the reason.
                    //
                    // "Payday not set" was a statement with nowhere to go,
                    // under a sentence asking for one. It is the way in now.
                    // A set cycle opens the same editor, because the only
                    // other way to correct a wrong day would be to find the
                    // sheet somewhere else.
                    Flexible(
                      child: Semantics(
                        button: onSetPayday != null,
                        label: payday.isSet
                            ? 'Change your payday'
                            : 'Set your payday',
                        child: InkWell(
                          onTap: onSetPayday,
                          borderRadius: BorderRadius.circular(Radii.pill),
                          child: Container(
                            // The floor, met by growing the tap target rather
                            // than the text: this row sits under a progress
                            // rail and pushing it taller would unbalance the
                            // card.
                            constraints: const BoxConstraints(minHeight: 44),
                            alignment: Alignment.centerLeft,
                            child: Text(
                              payday.isSet
                                  ? '${payday.daysToPayday} days to payday'
                                  : 'Payday not set',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: HeroColors.ink,
                                decoration: payday.isSet || onSetPayday == null
                                    ? null
                                    : TextDecoration.underline,
                                decorationColor: HeroColors.ink,
                              ),
                            ),
                          ),
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

  /// The line under the big figure. Two clauses, each earned separately.
  ///
  /// NO PER-DAY FIGURE WITHOUT A PAYDAY, and this is the most important rule
  /// in the file. The engine divides by max(1, daysToPayday), so an unset
  /// cycle makes the daily figure equal the WHOLE fortnight's. The card would
  /// tell somebody with 36,125 pesos of room that they may spend 36,125 pesos
  /// a day, which is not a rounding error, it is the opposite of the advice
  /// this screen exists to give.
  ///
  /// AND NO RUNWAY WITHOUT A MEASURED PACE, which is the same rule applied to
  /// the second clause. The runway is liquid cash divided by a daily burn,
  /// and under 5,000 logged in thirty days that burn is a stand-in of 28,000
  /// a month that nobody recorded. On a phone ten seconds old it divided zero
  /// by an invented figure and printed "Lasts 0 days" beside a zero balance,
  /// which reads as a verdict on the person rather than as what it is: two
  /// placeholders, and nothing recorded to say anything about.
  ///
  /// The number itself is not touched. It is locked by golden vectors and
  /// the Safe to Spend sheet still shows it, captioned with which of the two
  /// burn rates it used. What changes is only whether the hero states it
  /// flatly, with no room for the caption that makes it honest.
  String _subtitle(SafeToSpendAnalysis analysis) {
    final String pace = state.payday.isSet
        ? '${formatPeso(state.safeToSpendPerDay, showDecimals: false)} a day until payday.'
        : 'Set your payday to see a daily figure.';

    if (!analysis.runwayFromLoggedSpending) return pace;

    return '$pace · Lasts ${analysis.cashRunwayDays} days';
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
          // The dot is the diagnostic's OWN verdict now that the engine is
          // migrated. It used to be a hardcoded dark red, with a comment
          // saying so, which meant a brand new install showed an alarm over
          // a sheet that opens on "Nothing recorded yet". That is the cry
          // wolf failure: a marker that is always on is a marker nobody
          // reads on the day it means something.
          //
          // No dot when nothing is wrong, and no dot when nothing is known.
          // Green would be a third thing to learn and would claim a verdict
          // on an app with no figures in it.
          trailing: _healthDot(state.healthReport),
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

  /// The marker beside HEALTH CHECK, or nothing at all.
  ///
  /// Three states, and only two of them draw anything:
  ///   tight  a red dot, something is over or short right now
  ///   watch  an amber dot, something is heading that way
  ///   otherwise nothing, which covers BOTH "all five are fine" and
  ///          "nothing is recorded yet"
  ///
  /// Those last two look identical on purpose. A dot means go and look, and
  /// on an app with nothing in it there is nothing to look at: the sheet
  /// itself says so and offers the two taps that start it off.
  ///
  /// The colours are the hero card's own inks, not the palette's. Everything
  /// on this gradient is drawn in a brown that works over it in both
  /// themes, and an accent-red pulled from Gabi disappears against it.
  Widget? _healthDot(HealthReport report) {
    final HealthIndicator? worst = report.needsAttention;
    if (worst == null) return null;

    final bool tight = worst.tone == HealthTone.tight;

    // A LABEL, not only a colour. Eight pixels of red says nothing to
    // somebody using a screen reader, and red against amber says nothing to
    // the large share of men who cannot tell them apart. The word is the
    // signal and the colour is the shortcut.
    return Semantics(
      key: healthDotKey,
      container: true,
      label: tight
          ? 'Health check, something needs attention'
          : 'Health check, something to watch',
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: tight ? const Color(0xFFB91C1C) : const Color(0xFF92400E),
          shape: BoxShape.circle,
        ),
      ),
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
