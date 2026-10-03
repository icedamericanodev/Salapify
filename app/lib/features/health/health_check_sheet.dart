import 'package:flutter/material.dart';

import '../../core/money/health_check.dart';
import '../../design/tokens.dart';
import '../../design/type.dart';
import '../../state/financial_state.dart';
import '../shared/sheet_scaffold.dart';

/// Health Check: five questions, and only the answers Salapify actually has.
///
/// Founder decision, 2026-09-20: five indicators, not the prototype's twelve.
/// The engine is core/money/health_check.dart and this file decides only how
/// it looks.
///
/// ## An unmeasured card is a TAP, not a complaint
///
/// This is the whole difference between five cards that help and five cards
/// that read as five chores. Every indicator Salapify cannot answer names
/// the one input that would let it, and offers the control that supplies it.
/// A grey card saying "not enough data" tells somebody they have failed at
/// something without saying at what.
///
/// ## Nothing here is a severity dot
///
/// The prototype paints twelve coloured badges, most of them computed from
/// figures it invented. A colour here only ever appears next to words that
/// say the same thing, because roughly one man in twelve cannot separate
/// this red from this green, and because a screenshot loses it for everyone.
class HealthCheckSheet extends StatelessWidget {
  const HealthCheckSheet({
    super.key,
    required this.palette,
    required this.state,
    this.onAct,
  });

  final Palette palette;
  final FinancialState state;

  /// Opens whatever an unmeasured indicator needs. Null hides the buttons
  /// rather than showing ones that do nothing, which is the same rule the
  /// Plan tiles follow.
  final void Function(HealthNeed need)? onAct;

  static Future<void> show(
    BuildContext context,
    Palette palette,
    FinancialState state, {
    void Function(HealthNeed need)? onAct,
  }) {
    return SheetScaffold.show<void>(
      context: context,
      palette: palette,
      builder: (BuildContext ctx) =>
          HealthCheckSheet(palette: palette, state: state, onAct: onAct),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Palette p = palette;
    final HealthReport r = runHealthCheck(
      transactions: state.transactions,
      accounts: state.accounts,
      budgets: state.budgets,
      goals: state.goals,
      bills: state.bills,
      installments: state.installments,
      payday: state.payday,
      now: state.now,
    );

    return SheetScaffold(
      palette: p,
      icon: Icons.monitor_heart_outlined,
      title: 'Health check',
      subtitle: 'Five questions, answered from what you have recorded.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (r.nothingYet)
            _StartHere(palette: p, onAct: onAct)
          else ...<Widget>[
            if (r.needsAttention != null) ...<Widget>[
              _Attention(palette: p, indicator: r.needsAttention!),
              const SizedBox(height: Spacing.md),
            ],
            for (final HealthIndicator i in r.indicators) ...<Widget>[
              _Card(palette: p, indicator: i, onAct: onAct),
              const SizedBox(height: Spacing.sm),
            ],
          ],
          const SizedBox(height: Spacing.sm),
          Text(
            // The honest frame, once, at the bottom. Salapify reads what
            // somebody typed in; it has no connection to a bank and it is
            // not anybody's accountant.
            'Worked out from your own entries. Salapify is not connected to '
            'any bank, and none of this is financial advice.',
            style: AppType.caption(p),
          ),
        ],
      ),
    );
  }
}

/// Nothing recorded at all: ONE line and a couple of taps.
///
/// Five grey cards on a first visit read as five chores, which is the worst
/// possible first impression for a screen whose job is to be useful.
class _StartHere extends StatelessWidget {
  const _StartHere({required this.palette, required this.onAct});

  final Palette palette;
  final void Function(HealthNeed need)? onAct;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Nothing recorded yet', style: AppType.title(palette)),
        const SizedBox(height: Spacing.xs),
        Text(
          'These five questions need your own figures, and Salapify will not '
          'make any up. Two or three entries is enough to start.',
          style: AppType.body(palette),
        ),
        const SizedBox(height: Spacing.lg),
        if (onAct != null) ...<Widget>[
          _ActionButton(
            palette: palette,
            label: 'Tell Salapify when you get paid',
            onTap: () => onAct!(HealthNeed.setPayday),
          ),
          const SizedBox(height: Spacing.sm),
          _ActionButton(
            palette: palette,
            label: 'Log something you spent',
            onTap: () => onAct!(HealthNeed.logSpending),
          ),
        ],
      ],
    );
  }
}

/// The one thing worth saying first, when there is one.
class _Attention extends StatelessWidget {
  const _Attention({required this.palette, required this.indicator});

  final Palette palette;
  final HealthIndicator indicator;

  @override
  Widget build(BuildContext context) {
    final bool tight = indicator.tone == HealthTone.tight;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: palette.surfaceAlt,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: tight ? palette.negative : palette.warning),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            // The WORD, so the border is never carrying the meaning alone.
            tight ? 'WORTH DOING SOMETHING ABOUT' : 'WORTH WATCHING',
            style: AppType.kicker(
              palette,
            ).copyWith(color: tight ? palette.negative : palette.warning),
          ),
          const SizedBox(height: Spacing.xs),
          // THE READING, not the question again. An earlier version printed
          // the question here as well, so with only five cards, all of them
          // on one scroll, the banner was a verbatim copy of one of them a
          // few lines further down. The reading describes itself: "₱1,200
          // short, on the pace you are on" needs no heading above it.
          Text(indicator.reading!, style: AppType.rowTitle(palette)),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({
    required this.palette,
    required this.indicator,
    required this.onAct,
  });

  final Palette palette;
  final HealthIndicator indicator;
  final void Function(HealthNeed need)? onAct;

  Color get _tone => switch (indicator.tone) {
    HealthTone.good => palette.positive,
    HealthTone.watch => palette.warning,
    HealthTone.tight => palette.negative,
    null => palette.textMuted,
  };

  String get _toneWord => switch (indicator.tone) {
    HealthTone.good => 'Fine',
    HealthTone.watch => 'Watch',
    HealthTone.tight => 'Tight',
    null => 'Not yet',
  };

  @override
  Widget build(BuildContext context) {
    final Palette p = palette;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(indicator.question, style: AppType.rowTitle(p)),
              ),
              const SizedBox(width: Spacing.sm),
              Text(
                // A word AND a colour, never a colour alone.
                _toneWord,
                style: AppType.caption(
                  p,
                ).copyWith(fontWeight: FontWeight.w800, color: _tone),
              ),
            ],
          ),
          const SizedBox(height: Spacing.xs),
          if (indicator.measured) ...<Widget>[
            Text(indicator.reading!, style: AppType.body(p)),
            if (indicator.detail != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(indicator.detail!, style: AppType.caption(p)),
              ),
          ] else ...<Widget>[
            Text(indicator.missing!, style: AppType.body(p)),
            if (onAct != null && indicator.need != null) ...<Widget>[
              const SizedBox(height: Spacing.sm),
              _ActionButton(
                palette: p,
                label: _labelFor(indicator.need!),
                onTap: () => onAct!(indicator.need!),
              ),
            ],
          ],
        ],
      ),
    );
  }

  static String _labelFor(HealthNeed need) => switch (need) {
    HealthNeed.setPayday => 'Set your payday',
    HealthNeed.logSpending => 'Log an entry',
    HealthNeed.addBill => 'Add a bill',
    HealthNeed.startCushion => 'Start an emergency fund',
    HealthNeed.setBudget => 'Set one limit',
  };
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.palette,
    required this.label,
    required this.onTap,
  });

  final Palette palette;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.pill),
        child: Container(
          // minHeight for the 44dp floor, and a Row so the label centres
          // without an `alignment`, which on a Container with no width
          // fills everything it is offered.
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
          decoration: BoxDecoration(
            color: palette.accentSoft,
            borderRadius: BorderRadius.circular(Radii.pill),
            border: Border.all(color: palette.accent),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.arrow_forward, size: 15, color: palette.accent),
              const SizedBox(width: Spacing.xs),
              Text(
                label,
                style: AppType.caption(
                  palette,
                ).copyWith(fontWeight: FontWeight.w800, color: palette.accent),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
