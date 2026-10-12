import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/money/format.dart';
import '../../core/money/reports.dart';
import '../../design/chart_colors.dart';
import '../../design/tokens.dart';
import '../../design/type.dart';

/// The Reports charts, one per tab, drawn with `fl_chart`.
///
/// Founder direction, 2026-10-07, after the first round of chart work went to
/// Home instead: "where the insight/graphs on the reports tab for financial
/// position, performance and cashflow ... USE THE FLUTTER CHARTS DEV PACKAGES
/// OR LIBRARIES". So these use fl_chart rather than hand painting.
///
/// THE FORM WAS PICKED BY THE DATA'S JOB, before any colour:
///   Position     what you own and owe, by part   part-to-whole, compared
///                                                -> stacked bars, one scale
///   Performance  money in against money out      magnitude, compared
///                                                -> two bars, one scale
///   Cash flow    each section above or below 0   polarity
///                                                -> diverging bars
///
/// NO PIE OR DONUT, deliberately. Length is judged far more accurately than
/// angle, and a bar keeps working when one part is tiny.
///
/// THE CHARTS ADD SHAPE, NOT WORDS. The founder's standing complaint about
/// these screens is that they are wordy, so a chart either REPLACES the text it
/// draws (Performance replaces two stat tiles; Cash flow replaces a caption
/// that only named the three sections) or sits on top of rows that already
/// print each part and turns those rows into its legend with a colour dot
/// (Position, via `BreakdownRow.swatch`). One deliberate repeat: each Cash
/// flow bar carries its net, which the section cards below also print,
/// because the three bars are the summary that adds up to the headline right
/// above them and a bar without its figure cannot be checked against it.
///
/// The exact peso always stays on the screen in text, because a bar cannot be
/// read to the centavo and this is a financial report. The shape is the
/// overview; the text is the record.
///
/// Touch tooltips are off. Every figure is already printed, so a tooltip
/// would repeat it and add a gesture that fights the scroll.

/// The bar thickness, and the rounding of its data end.
const double _barThickness = 12;
const double _barRadius = 4;

/// One coloured part of a bar, with the words that name it.
class ChartSegment {
  const ChartSegment(this.label, this.value, this.color);

  final String label;

  /// In pesos. Only the positive part is drawn; see [ShareBar].
  final double value;
  final Color color;
}

/// One horizontal bar built from stacked parts, on a scale given from outside.
///
/// fl_chart draws vertical bars; `rotationQuarterTurns: 1` lays them on their
/// side. Axes, grid and border are all off. The scale is shared by handing the
/// same [maxY] to sibling bars, which is what lets two bars be compared by
/// length at all.
class ShareBar extends StatelessWidget {
  const ShareBar({
    super.key,
    required this.palette,
    required this.segments,
    required this.maxY,
    this.showTrack = true,
  });

  final Palette palette;
  final List<ChartSegment> segments;
  final double maxY;

  /// Whether to draw the faint track for the unused rest of the scale.
  /// Off on Position: there the scale belongs to a bar in ANOTHER card, and
  /// a track reads as "40% of something", the way every other track in the
  /// app means share or progress. Without it the two bars still compare by
  /// length, with no false 100% behind them.
  final bool showTrack;

  @override
  Widget build(BuildContext context) {
    final double top = maxY <= 0 ? 1 : maxY;
    double from = 0;
    final List<BarChartRodStackItem> items = <BarChartRodStackItem>[];
    for (final ChartSegment s in segments) {
      // A part below zero (an overdrawn wallet) has no honest length in a
      // part-to-whole bar, so it is not drawn. Its signed figure is still in
      // the row beside it.
      if (s.value <= 0) continue;
      final double to = from + s.value;
      items.add(
        BarChartRodStackItem(
          from,
          to,
          s.color,
          // A hairline of the card surface between parts, so two
          // neighbouring colours never merge into one block.
          borderSide: BorderSide(color: palette.surface, width: 1),
        ),
      );
      from = to;
    }

    return SizedBox(
      height: _barThickness,
      child: BarChart(
        BarChartData(
          rotationQuarterTurns: 1,
          minY: 0,
          maxY: top,
          alignment: BarChartAlignment.start,
          groupsSpace: 0,
          titlesData: const FlTitlesData(show: false),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          barTouchData: BarTouchData(enabled: false),
          barGroups: <BarChartGroupData>[
            BarChartGroupData(
              x: 0,
              barRods: <BarChartRodData>[
                BarChartRodData(
                  toY: from,
                  width: _barThickness,
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(_barRadius),
                  rodStackItems: items,
                  // The unused rest of the scale, drawn faintly, so a short
                  // bar reads as short against something.
                  backDrawRodData: BackgroundBarChartRodData(
                    show: showTrack,
                    toY: top,
                    color: palette.trackSoft,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A label and its exact figure on one line, with the bar underneath.
///
/// Stacked rather than side by side ON PURPOSE: a peso figure in the millions
/// at 1.5x system font does not fit beside a bar on a 320dp phone, and a bar
/// squeezed to nothing says nothing.
class _BarRow extends StatelessWidget {
  const _BarRow({
    required this.palette,
    required this.label,
    required this.value,
    required this.bar,
  });

  final Palette palette;
  final String label;
  final String value;
  final Widget bar;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Spacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // A Wrap, not a Row with an Expanded label. Beside a figure that
          // cannot shrink, an Expanded label is what gives way, and at 320dp
          // and 2.0x text it was squeezed to one letter per line. A Wrap
          // keeps both whole and drops the figure to its own line only when
          // the two genuinely do not fit side by side.
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: Spacing.sm,
            runSpacing: 2,
            children: <Widget>[
              Text(label, style: AppType.body(palette).copyWith(fontSize: 12)),
              // The figure in the TEXT colour, never the bar's: the bar
              // carries identity and the number stays readable in both modes.
              Text(
                value,
                style: AppType.amountSmall(
                  palette,
                ).copyWith(color: palette.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: Spacing.xs),
          bar,
        ],
      ),
    );
  }
}

/// POSITION. The parts of what you own and of what you owe, and ONE scale
/// for both bars, so the gap between them is something you see rather than
/// something you subtract.
///
/// Returned as data rather than a widget because the two bars live in two
/// different cards, above the rows that already print each part.
({List<ChartSegment> own, List<ChartSegment> owe, double scale})
positionSegments(Palette palette, FinancialPosition p) {
  final ChartColors c = ChartColors.of(palette);
  final List<ChartSegment> own = <ChartSegment>[
    ChartSegment(
      'Cash and e-wallets',
      p.cashEquivalents.pesos,
      c.categories[0],
    ),
    ChartSegment('Investments', p.investments.pesos, c.categories[1]),
    ChartSegment('Owed to you', p.receivables.pesos, c.categories[2]),
    ChartSegment('Property', p.property.pesos, c.categories[3]),
  ];
  final List<ChartSegment> owe = <ChartSegment>[
    // Owed money gets its own pair, NOT a continuation of the owned set:
    // blue on both bars would read as the same kind of thing.
    ChartSegment('Credit cards', p.creditCards.pesos, c.outflow),
    ChartSegment('Loans and mortgage', p.loans.pesos, c.categories[4]),
  ];
  // Measured from what is DRAWN, the positive parts, not from the totals. An
  // overdrawn wallet makes the total smaller than the parts drawn, and a
  // scale taken from the total would run the bar off its own end. Separate
  // scales would be worse: a 12,000 debt would draw as long as a 460,000 one.
  double drawn(List<ChartSegment> parts) => parts.fold<double>(
    0,
    (double a, ChartSegment s) => s.value > 0 ? a + s.value : a,
  );
  // A PART BELOW ZERO MEANS NO BARS, and the rows alone carry the figures.
  // A negative part has no length, so the bar draws only the positive ones
  // and comes out longer than the total it stands for. With cash at -3,000,
  // 5,000 owed to you and 4,000 owed, the headline says "Still to pay off
  // 2,000" while the own bar draws 5,000 and outruns the owe bar of 4,000:
  // a picture that contradicts the figure above it. That is common, too, for
  // anybody who logged spending from a zero opening balance or overpaid a
  // card. A chart that misleads is worse than no chart.
  if (<ChartSegment>[...own, ...owe].any((ChartSegment s) => s.value < 0)) {
    return (own: own, owe: owe, scale: 0);
  }
  return (own: own, owe: owe, scale: math.max(drawn(own), drawn(owe)));
}

/// PERFORMANCE. Money in against money out, on one scale.
///
/// It replaces the two stat tiles that printed the same two figures, so the
/// screen gains a shape and no extra words.
class InOutChart extends StatelessWidget {
  const InOutChart({
    super.key,
    required this.palette,
    required this.moneyIn,
    required this.moneyOut,
  });

  final Palette palette;
  final double moneyIn;
  final double moneyOut;

  @override
  Widget build(BuildContext context) {
    final ChartColors c = ChartColors.of(palette);
    final double scale = math.max(math.max(moneyIn, moneyOut), 0);

    Widget bar(double v, Color colour) => ShareBar(
      palette: palette,
      segments: <ChartSegment>[ChartSegment('', v, colour)],
      maxY: scale,
    );

    return Semantics(
      label:
          'Money in ${formatPeso(moneyIn)}, money out ${formatPeso(moneyOut)}.',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _BarRow(
            palette: palette,
            label: 'Money in',
            value: formatPeso(moneyIn),
            bar: bar(moneyIn, c.inflow),
          ),
          _BarRow(
            palette: palette,
            label: 'Money out',
            value: formatPeso(moneyOut),
            bar: bar(moneyOut, c.outflow),
          ),
        ],
      ),
    );
  }
}

/// A bar from a shared zero line in the middle: right of the line added cash,
/// left of it took cash away.
class _DivergingBar extends StatelessWidget {
  const _DivergingBar({
    required this.palette,
    required this.value,
    required this.reach,
    required this.color,
  });

  final Palette palette;
  final double value;
  final double reach;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final double r = reach <= 0 ? 1 : reach;
    return SizedBox(
      height: _barThickness,
      child: BarChart(
        BarChartData(
          rotationQuarterTurns: 1,
          minY: -r,
          maxY: r,
          alignment: BarChartAlignment.start,
          groupsSpace: 0,
          titlesData: const FlTitlesData(show: false),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          barTouchData: BarTouchData(enabled: false),
          // The zero line, which is the whole point of the chart: everything
          // is read against it.
          extraLinesData: ExtraLinesData(
            horizontalLines: <HorizontalLine>[
              HorizontalLine(y: 0, color: palette.textMuted, strokeWidth: 1.5),
            ],
          ),
          barGroups: <BarChartGroupData>[
            BarChartGroupData(
              x: 0,
              barRods: <BarChartRodData>[
                BarChartRodData(
                  toY: value,
                  width: _barThickness,
                  color: color,
                  borderRadius: BorderRadius.circular(_barRadius),
                  backDrawRodData: BackgroundBarChartRodData(
                    show: true,
                    fromY: -r,
                    toY: r,
                    color: palette.trackSoft,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// CASH FLOW. The three sections that make up the net change in cash, each
/// as a bar from one shared zero line.
///
/// Polarity is carried THREE ways, so colour is never the only cue: which side
/// of the line the bar sits, the sign on the figure, and the colour. That is
/// what lets this chart use the app's own green and orange, the pair that
/// failed colour-blind separation as bare colour (chart_colors.dart): here the
/// colour is the third cue, never the only one.
class CashFlowChart extends StatelessWidget {
  const CashFlowChart({
    super.key,
    required this.palette,
    required this.cashFlow,
  });

  final Palette palette;
  final CashFlow cashFlow;

  @override
  Widget build(BuildContext context) {
    final List<({String label, double net})> rows =
        <({String label, double net})>[
          (label: 'Day to day', net: cashFlow.netOperating),
          (label: 'Investments', net: cashFlow.netInvesting),
          (label: 'Loans and cards', net: cashFlow.netFinancing),
        ];

    // SYMMETRIC around zero and shared by all three rows, so the zero line
    // sits in the same place on each and the bars compare by length.
    final double reach = rows.fold<double>(
      0,
      (double a, ({String label, double net}) r) => math.max(a, r.net.abs()),
    );
    if (reach <= 0) return const SizedBox.shrink();

    return Semantics(
      label:
          'Day to day ${formatPesoWithSign(cashFlow.netOperating)}, '
          'investments ${formatPesoWithSign(cashFlow.netInvesting)}, '
          'loans and cards ${formatPesoWithSign(cashFlow.netFinancing)}.',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (final ({String label, double net}) r in rows)
            _BarRow(
              palette: palette,
              label: r.label,
              value: formatPesoWithSign(r.net),
              bar: _DivergingBar(
                palette: palette,
                value: r.net,
                reach: reach,
                // The app's own green and orange HERE, not the chart blue.
                // The hero above and the section cards below print these
                // same nets in green and orange, and a third colour for the
                // same figure invites "what is blue?". The colour-blind
                // reason for blue does not apply on this chart: the side of
                // the zero line and the minus sign already carry direction.
                color: r.net >= 0 ? palette.positive : palette.negative,
              ),
            ),
        ],
      ),
    );
  }
}
