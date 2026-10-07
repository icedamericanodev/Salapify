import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/money/format.dart';
import '../../core/money/trends.dart';
import '../../design/chart_colors.dart';
import '../../design/tokens.dart';
import '../../design/type.dart';

/// The Reports charts that show CHANGE, which is what the first round lacked.
///
/// Founder, 2026-10-07, on the snapshot bars: "ITS PRETTY BASIC, IF WE
/// COMPARE TO OTHER APPS OUT THERE WE CANNOT COMPETE." A competitor benchmark
/// (Copilot, Monarch, YNAB, Revolut, Emma) found the gap was not the drawing
/// but the question: every premium chart answers "better or worse than
/// before?", and a single period's bar cannot. These two answer it, and both
/// are things a person can act on:
///
///   [SpendingPaceChart]   am I spending faster than last month, by today?
///                         Copilot's dashboard line, this month solid
///                         against last month dotted.
///   [MonthlyInOutChart]   is this month normal, or did a bonus hide a bad
///                         one? Copilot, YNAB and Monarch's month bars.
///
/// Both use fl_chart's own touch and animation rather than anything painted
/// by hand, and every peso they show comes from `trends.dart`, which runs
/// the existing Reports engine and adds no maths of its own.
///
/// MOTION is a draw-in on first build, and it is skipped when the phone asks
/// for reduced motion: an animation a person has turned off is a defect.

const List<String> _monthShort = <String>[
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

const List<String> _monthLong = <String>[
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// Grows a chart from its baseline once, on first build.
///
/// fl_chart animates between two DATA states, never in from nothing, so the
/// draw-in is a 0 to 1 factor the chart multiplies its values by.
class _DrawIn extends StatelessWidget {
  const _DrawIn({required this.builder});

  final Widget Function(double t) builder;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      return builder(1);
    }
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (BuildContext context, double t, Widget? _) => builder(t),
    );
  }
}

/// A small key: a swatch, or a dash for a dotted series, and its name.
class _Key extends StatelessWidget {
  const _Key({
    required this.palette,
    required this.color,
    required this.label,
    this.dashed = false,
  });

  final Palette palette;
  final Color color;
  final String label;
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (dashed)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              for (int i = 0; i < 3; i++)
                Container(
                  width: 4,
                  height: 2,
                  margin: const EdgeInsets.only(right: 2),
                  color: color,
                ),
            ],
          )
        else
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        const SizedBox(width: Spacing.xs),
        Text(label, style: AppType.caption(palette)),
      ],
    );
  }
}

/// THIS MONTH'S SPENDING, DAY BY DAY, AGAINST LAST MONTH'S.
///
/// The solid line is this month so far, with a soft fill under it; the dotted
/// line is the whole of last month, so a person sees both where last month
/// stood on this day and where it ended up. Drag along the chart to read any
/// day. The one sentence above it is the answer the chart exists to give.
class SpendingPaceChart extends StatelessWidget {
  const SpendingPaceChart({
    super.key,
    required this.palette,
    required this.pace,
  });

  final Palette palette;
  final SpendingPace pace;

  @override
  Widget build(BuildContext context) {
    final ChartColors c = ChartColors.of(palette);
    final Color line = c.outflow;
    final Color ghost = palette.textMuted;
    final int lastDay = math.max(pace.daysInThisMonth, pace.lastMonth.length);
    final double top = <double>[
      pace.spentSoFar,
      if (pace.lastMonth.isNotEmpty) pace.lastMonth.last,
    ].reduce(math.max);
    final double maxY = top <= 0 ? 1 : top * 1.12;

    final double diff = pace.difference;
    final String? verdict = !pace.hasLastMonth
        ? null
        : diff.abs() < 0.005
        ? 'Exactly where last month was by day ${pace.day}.'
        : '${formatPeso(diff.abs())} ${diff > 0 ? 'more' : 'less'} than last '
              'month by day ${pace.day}.';

    return Semantics(
      label:
          'Spent ${formatPeso(pace.spentSoFar)} so far this month. '
          '${verdict ?? ''}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // THE ANSWER LEADS, not the amount. The amount spent so far is
          // "Money out" in the card directly above on this view, and printing
          // it a second time here made the same figure appear three times in
          // a row once the month by month card was added under this one.
          // A first month has no answer yet, and then the key says what the
          // line is.
          if (verdict != null) ...<Widget>[
            Text(
              verdict,
              style: AppType.rowTitle(palette).copyWith(
                // Spending ahead of last month is the one worth noticing.
                color: diff > 0.005 ? palette.negative : palette.positive,
              ),
            ),
            const SizedBox(height: Spacing.md),
          ],
          SizedBox(
            height: 150,
            child: _DrawIn(
              builder: (double t) => LineChart(
                duration: Duration.zero,
                LineChartData(
                  minX: 1,
                  maxX: lastDay.toDouble(),
                  minY: 0,
                  maxY: maxY,
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(
                    drawVerticalLine: false,
                    horizontalInterval: maxY / 3,
                    getDrawingHorizontalLine: (double _) =>
                        FlLine(color: palette.border, strokeWidth: 1),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(),
                    rightTitles: const AxisTitles(),
                    topTitles: const AxisTitles(),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 22,
                        interval: 1,
                        getTitlesWidget: (double v, TitleMeta meta) {
                          final int d = v.round();
                          // Day 1, the middle, and the end: enough to place a
                          // point, few enough not to crowd a 320dp phone.
                          if (d != 1 && d != 15 && d != lastDay) {
                            return const SizedBox.shrink();
                          }
                          return SideTitleWidget(
                            meta: meta,
                            child: Text('$d', style: AppType.caption(palette)),
                          );
                        },
                      ),
                    ),
                  ),
                  lineTouchData: LineTouchData(
                    getTouchedSpotIndicator:
                        (
                          LineChartBarData bar,
                          List<int> spots,
                        ) => <TouchedSpotIndicatorData>[
                          for (final int _ in spots)
                            TouchedSpotIndicatorData(
                              FlLine(
                                color: palette.textMuted,
                                strokeWidth: 1,
                                dashArray: <int>[3, 3],
                              ),
                              FlDotData(
                                getDotPainter: (_, _, LineChartBarData b, _) =>
                                    FlDotCirclePainter(
                                      radius: 4,
                                      color: b.color ?? line,
                                      strokeColor: palette.surface,
                                      strokeWidth: 2,
                                    ),
                              ),
                            ),
                        ],
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (_) => palette.surfaceAlt,
                      tooltipBorder: BorderSide(color: palette.border),
                      fitInsideHorizontally: true,
                      fitInsideVertically: true,
                      getTooltipItems: (List<LineBarSpot> spots) =>
                          <LineTooltipItem?>[
                            // The day heads the FIRST line, whichever series
                            // that is: past today only last month has a point.
                            for (int i = 0; i < spots.length; i++)
                              LineTooltipItem(
                                '${i == 0 ? 'Day ${spots[i].x.round()}\n' : ''}'
                                '${spots[i].barIndex == 1 ? 'This month' : 'Last month'}'
                                ' ${formatPeso(spots[i].y / (t == 0 ? 1 : t))}',
                                AppType.caption(
                                  palette,
                                ).copyWith(color: palette.textPrimary),
                                textAlign: TextAlign.left,
                              ),
                          ],
                    ),
                  ),
                  lineBarsData: <LineChartBarData>[
                    // Index 0: last month, dotted and quiet, drawn first so
                    // this month's line sits on top of it.
                    LineChartBarData(
                      spots: <FlSpot>[
                        for (int i = 0; i < pace.lastMonth.length; i++)
                          FlSpot(i + 1.0, pace.lastMonth[i] * t),
                      ],
                      isCurved: true,
                      preventCurveOverShooting: true,
                      color: ghost,
                      barWidth: 2,
                      dashArray: <int>[4, 4],
                      dotData: const FlDotData(show: false),
                    ),
                    // Index 1: this month, to today.
                    LineChartBarData(
                      spots: <FlSpot>[
                        for (int i = 0; i < pace.thisMonth.length; i++)
                          FlSpot(i + 1.0, pace.thisMonth[i] * t),
                      ],
                      isCurved: true,
                      preventCurveOverShooting: true,
                      color: line,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      // Only today's point gets a dot: it is the "you are
                      // here" of the chart.
                      dotData: FlDotData(
                        checkToShowDot: (FlSpot s, LineChartBarData _) =>
                            s.x.round() == pace.day,
                        getDotPainter: (_, _, _, _) => FlDotCirclePainter(
                          radius: 4.5,
                          color: line,
                          strokeColor: palette.surface,
                          strokeWidth: 2,
                        ),
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: <Color>[
                            line.withValues(alpha: 0.32),
                            line.withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: Spacing.sm),
          Wrap(
            spacing: Spacing.md,
            runSpacing: Spacing.xs,
            children: <Widget>[
              _Key(palette: palette, color: line, label: 'This month so far'),
              if (pace.lastMonth.isNotEmpty)
                _Key(
                  palette: palette,
                  color: ghost,
                  label: 'Last month',
                  dashed: true,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// MONEY IN AND OUT, MONTH BY MONTH.
///
/// Paired bars per month, the current month on the right. Tapping a month
/// selects it and the line under the chart gives its exact figures, the way
/// Copilot's cash flow bars work: the chart is the overview, the selected
/// month is the record, and nothing floats over the bars on a small phone.
class MonthlyInOutChart extends StatefulWidget {
  const MonthlyInOutChart({
    super.key,
    required this.palette,
    required this.months,
  });

  final Palette palette;

  /// Oldest first, current month last.
  final List<MonthTotals> months;

  @override
  State<MonthlyInOutChart> createState() => _MonthlyInOutChartState();
}

class _MonthlyInOutChartState extends State<MonthlyInOutChart> {
  /// Null means the current month, so a rebuild with one more month still
  /// lands on the newest rather than on a stale index.
  int? _selected;

  @override
  Widget build(BuildContext context) {
    final Palette palette = widget.palette;
    final List<MonthTotals> months = widget.months;
    final ChartColors c = ChartColors.of(palette);
    final int sel = (_selected ?? months.length - 1).clamp(
      0,
      months.length - 1,
    );
    final MonthTotals m = months[sel];
    final double top = months.fold<double>(
      0,
      (double a, MonthTotals x) => math.max(a, math.max(x.income, x.expenses)),
    );
    final double maxY = top <= 0 ? 1 : top * 1.1;

    Color dim(Color col, int i) => i == sel ? col : col.withValues(alpha: 0.35);

    final double net = m.income - m.expenses;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          height: 150,
          child: _DrawIn(
            builder: (double t) => BarChart(
              duration: Duration.zero,
              BarChartData(
                minY: 0,
                maxY: maxY,
                alignment: BarChartAlignment.spaceAround,
                borderData: FlBorderData(show: false),
                gridData: FlGridData(
                  drawVerticalLine: false,
                  horizontalInterval: maxY / 3,
                  getDrawingHorizontalLine: (double _) =>
                      FlLine(color: palette.border, strokeWidth: 1),
                ),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(),
                  rightTitles: const AxisTitles(),
                  topTitles: const AxisTitles(),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      getTitlesWidget: (double v, TitleMeta meta) {
                        final int i = v.round();
                        if (i < 0 || i >= months.length) {
                          return const SizedBox.shrink();
                        }
                        return SideTitleWidget(
                          meta: meta,
                          child: Text(
                            _monthShort[months[i].month - 1],
                            style: AppType.caption(palette).copyWith(
                              color: i == sel
                                  ? palette.textPrimary
                                  : palette.textMuted,
                              fontWeight: i == sel
                                  ? FontWeight.w800
                                  : FontWeight.w500,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barTouchData: BarTouchData(
                  handleBuiltInTouches: false,
                  // A month is a generous target: the whole column, not
                  // the 10dp bar, so a thumb does not have to aim.
                  touchExtraThreshold: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 200,
                  ),
                  allowTouchBarBackDraw: true,
                  touchCallback: (FlTouchEvent e, BarTouchResponse? r) {
                    final int? i = r?.spot?.touchedBarGroupIndex;
                    if (i == null || !e.isInterestedForInteractions) return;
                    if (i != sel) setState(() => _selected = i);
                  },
                ),
                barGroups: <BarChartGroupData>[
                  for (int i = 0; i < months.length; i++)
                    BarChartGroupData(
                      x: i,
                      barsSpace: 3,
                      barRods: <BarChartRodData>[
                        BarChartRodData(
                          toY: months[i].income * t,
                          width: 10,
                          color: dim(c.inflow, i),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4),
                          ),
                        ),
                        BarChartRodData(
                          toY: months[i].expenses * t,
                          width: 10,
                          color: dim(c.outflow, i),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: Spacing.sm),
        Wrap(
          spacing: Spacing.md,
          children: <Widget>[
            _Key(palette: palette, color: c.inflow, label: 'In'),
            _Key(palette: palette, color: c.outflow, label: 'Out'),
          ],
        ),
        Divider(color: palette.border, height: Spacing.lg),
        // The selected month, exactly. Announced on change so a screen
        // reader user hears what their tap selected.
        Semantics(
          liveRegion: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                '${_monthLong[m.month - 1]} ${m.year}'.toUpperCase(),
                style: AppType.kicker(palette),
              ),
              const SizedBox(height: Spacing.xs),
              Wrap(
                spacing: Spacing.lg,
                runSpacing: Spacing.xs,
                children: <Widget>[
                  _Figure(palette: palette, label: 'In', value: m.income),
                  _Figure(palette: palette, label: 'Out', value: m.expenses),
                  _Figure(
                    palette: palette,
                    label: net >= 0 ? 'Kept' : 'Overspent',
                    value: net.abs(),
                    color: net >= 0 ? palette.positive : palette.negative,
                    suffix: m.keptRate != null && net >= 0
                        ? ' (${m.keptRate!.toStringAsFixed(1)}%)'
                        : null,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({
    required this.palette,
    required this.label,
    required this.value,
    this.color,
    this.suffix,
  });

  final Palette palette;
  final String label;
  final double value;
  final Color? color;
  final String? suffix;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(label, style: AppType.caption(palette)),
        Text(
          '${formatPeso(value)}${suffix ?? ''}',
          style: AppType.amountSmall(
            palette,
          ).copyWith(color: color ?? palette.textPrimary),
        ),
      ],
    );
  }
}
