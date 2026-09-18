// Credit Utilization Radar, f4.63. How full each credit card is against its
// limit, and across all cards, measured against the 30 percent healthy line.
//
// The numbers are creditUtilization(...), an engine value; this widget renders
// them and does no money math. Two things the bank-officer and financial-coach
// reviews (2026-08-22) made non-negotiable and that this card carries:
//   - It is framed as HEADROOM, never as interest and never as a score. A high
//     ratio you pay in full before the statement date costs no interest, and
//     that caveat sits under every non-healthy status.
//   - Over-limit reads honestly as more than 100 percent, never capped, and a
//     small-limit card shows its peso balance beside the ratio so a scary
//     percentage on a tiny limit is not mistaken for a large debt.
//
// Every peso figure routes through the injected [money] formatter, so the
// Debts screen's privacy state (if any) hides them the same way it hides the
// rest of the screen.

import 'package:flutter/material.dart';

import '../money/credit_utilization.dart';
import '../theme.dart';
import '../typography.dart';
import 'progress_bar.dart';
import 'salapify_icon.dart';

class CreditRadarCard extends StatelessWidget {
  /// The whole creditUtilization(...) map: cards, overall, overallBand,
  /// overallBalance, overallLimit, limitsUnset, cardCount.
  final Map<String, dynamic> radar;

  /// The screen's money formatter (masks under a privacy toggle if present).
  final String Function(num) money;

  // Not const: build() reads mutable Barako getters, so a const call site would
  // freeze this card in the previous palette after a theme switch.
  // ignore: prefer_const_constructors_in_immutables
  CreditRadarCard({super.key, required this.radar, required this.money});

  List<CardUtilization> get _cards =>
      (radar['cards'] as List).cast<CardUtilization>();
  double? get _overall => radar['overall'] as double?;
  UtilizationBand get _overallBand => radar['overallBand'] as UtilizationBand;
  double get _overallBalance => (radar['overallBalance'] as num).toDouble();
  double get _overallLimit => (radar['overallLimit'] as num).toDouble();
  int get _limitsUnset => (radar['limitsUnset'] as num).toInt();

  static Color bandColor(UtilizationBand b) => switch (b) {
    UtilizationBand.healthy => Barako.primary,
    UtilizationBand.watch => Barako.celebrate,
    UtilizationBand.high => Barako.warning,
    UtilizationBand.maxed => Barako.warningStrong,
    UtilizationBand.none => Barako.muted,
  };

  static String bandWord(UtilizationBand b) => switch (b) {
    UtilizationBand.healthy => 'Healthy',
    UtilizationBand.watch => 'Watch',
    UtilizationBand.high => 'High',
    UtilizationBand.maxed => 'Nearly full',
    UtilizationBand.none => 'No limit set',
  };

  // Whole-percent text for a ratio. Over-limit shows the real figure (110%),
  // never capped, per the bank-officer review; a null ratio has no percent.
  static String pct(double? u) => u == null ? '' : '${(u * 100).round()}%';

  @override
  Widget build(BuildContext context) {
    final overallColor = bandColor(_overallBand);
    return Container(
      decoration: BoxDecoration(
        color: Barako.card,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: Barako.border),
      ),
      padding: Insets.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('CREDIT RADAR', style: Barako.kickerStyle),
          const SizedBox(height: Gap.sm),
          // The overall figure, in its band colour, with the plain band word.
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                _overall == null ? 'No limits set' : pct(_overall),
                style: AppText.amountLg.w8.tint(overallColor),
              ),
              const SizedBox(width: Gap.sm),
              if (_overall != null)
                Expanded(
                  child: Text(
                    'of your total limit',
                    style: AppText.small.tint(Barako.textSecondary),
                  ),
                ),
            ],
          ),
          if (_overall != null) ...[
            const SizedBox(height: Gap.md),
            _barWithLine(_overall!, overallColor, 'Overall credit used'),
            const SizedBox(height: Gap.sm),
            Text(
              '${money(_overallBalance)} of ${money(_overallLimit)} used. '
              'The healthy line is 30%.',
              style: AppText.small.tint(Barako.textSecondary),
            ),
          ],
          const SizedBox(height: Gap.md),
          Text(_overallSentence(), style: AppText.small.tint(Barako.text)),
          const SizedBox(height: Gap.lg),
          Container(height: 1, color: Barako.border),
          const SizedBox(height: Gap.lg),
          for (var i = 0; i < _cards.length; i++) ...[
            if (i > 0) const SizedBox(height: Gap.md),
            _cardRow(_cards[i]),
          ],
          if (_limitsUnset > 0) ...[
            const SizedBox(height: Gap.md),
            _caveat(
              _limitsUnset == 1
                  ? '1 card has no limit saved, so it is not in the total above. '
                        'Add its limit to put it on the radar.'
                  : '$_limitsUnset cards have no limit saved, so they are not in '
                        'the total above. Add their limits to put them on the '
                        'radar.',
            ),
          ],
          // The one honesty caveat both reviews required, shown whenever any
          // card is past the healthy line: utilization only bites if carried.
          if (_anyNonHealthy()) ...[
            const SizedBox(height: Gap.md),
            _caveat(
              'If you pay a card in full before its statement date, you owe no '
              'interest and its number resets. Utilization only bites when you '
              'carry the balance past the due date.',
            ),
          ],
        ],
      ),
    );
  }

  bool _anyNonHealthy() => _cards.any(
    (c) =>
        c.band == UtilizationBand.watch ||
        c.band == UtilizationBand.high ||
        c.band == UtilizationBand.maxed,
  );

  // One card row: name and peso balance on the left, the ratio in its band
  // colour on the right, a dense band-coloured bar beneath. The peso balance is
  // always shown so a high ratio on a tiny limit is not read as a large debt.
  Widget _cardRow(CardUtilization c) {
    final color = bandColor(c.band);
    final hasLimit = c.utilization != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: Gap.sm),
            Expanded(
              child: Text(
                c.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.bodyStrong,
              ),
            ),
            const SizedBox(width: Gap.sm),
            Text(
              hasLimit ? pct(c.utilization) : bandWord(c.band),
              style: AppText.amountReference.tint(color),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (hasLimit)
          SalapifyProgressBar(
            value: c.utilization!.clamp(0.0, 1.0),
            size: ProgressBarSize.micro,
            color: color,
            semanticsLabel: '${c.name}, ${pct(c.utilization)} of limit used',
          ),
        const SizedBox(height: 4),
        Text(
          hasLimit
              ? '${money(c.balance)} of ${money(c.limit)}'
              : '${money(c.balance)} balance',
          style: AppText.caption.tint(Barako.muted),
        ),
      ],
    );
  }

  // A determinate bar with a marker at the 30% healthy line, so a person can
  // see at a glance whether they are over or under it.
  Widget _barWithLine(double value, Color color, String label) {
    return SizedBox(
      height: ProgressBarSize.bar.height,
      child: Stack(
        children: [
          SalapifyProgressBar(
            value: value.clamp(0.0, 1.0),
            color: color,
            semanticsLabel: label,
          ),
          // The 30% tick: a thin line the track colour inverts against, aligned
          // to the healthy line so the fill reading over or under it is visible.
          FractionallySizedBox(
            widthFactor: healthyUtilizationLine,
            child: Align(
              alignment: Alignment.centerRight,
              child: Container(width: 2, color: Barako.background),
            ),
          ),
        ],
      ),
    );
  }

  Widget _caveat(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(salapifyIcon('info'), size: IconSizes.dense, color: Barako.muted),
        const SizedBox(width: Gap.xs),
        Expanded(child: Text(text, style: AppText.caption.tint(Barako.muted))),
      ],
    );
  }

  // The overall summary sentence, from the financial-coach review copy. The
  // trailing clause is the only part the band changes; the figure and the 30%
  // line are stated the same way every time.
  String _overallSentence() {
    if (_overall == null) {
      return 'None of your cards has a limit saved yet, so there is nothing to '
          'measure. Add a card limit and the radar lights up.';
    }
    final head = "You are using ${pct(_overall)} of your total credit limit.";
    return switch (_overallBand) {
      UtilizationBand.healthy =>
        '$head That is under the 30% healthy line. Nicely done.',
      UtilizationBand.watch =>
        '$head That is a little over the 30% healthy line, easy to steer back.',
      UtilizationBand.high =>
        '$head That is well past the 30% healthy line. Paying a card down, '
            'starting with the fullest, frees up room. Your payoff plan below '
            'shows the fastest order.',
      UtilizationBand.maxed =>
        '$head Your cards are close to full. This is the first thing worth '
            'tackling, and your payoff plan below can help you plan it.',
      UtilizationBand.none => head,
    };
  }
}
