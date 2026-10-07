import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
        // Flexible, so at 2.0x the readout breaks between the label and the
        // figure, never inside a peso amount.
        Flexible(child: Text(label, style: AppType.caption(palette))),
      ],
    );
  }
}

/// THIS MONTH'S SPENDING, DAY BY DAY, AGAINST LAST MONTH'S.
///
/// The solid line is this month so far, with a soft fill under it; the dotted
/// line is the whole of last month, so a person sees both where last month
/// stood on this day and where it ended up. The sentence above it is the
/// answer the chart exists to give, and always speaks about TODAY.
///
/// NO FLOATING TOOLTIP, deliberately, and this is the second design. The
/// first used fl_chart's built-in bubble and a review measured three real
/// faults with it: it wraps at 120dp, so at large text a peso figure broke
/// across two lines and read as two numbers; at 2.0x it grew taller than the
/// chart and covered the sentence; and on Android it vanished the moment the
/// finger lifted, so a tap could not be read at all. Instead the key under
/// the chart is a LIVE READOUT: tap or drag to a day, and that day's figures
/// stay there after the finger lifts. It is the same "pick a thing, read it
/// below" model the month by month card uses, and the one Copilot uses.
///
/// ONLY A SETTLED GESTURE SELECTS. A finger landing is not a choice: the
/// chart sits in a scrolling page, and fl_chart reports a touch DOWN before
/// the page has decided the gesture is a scroll. So a day is picked on a tap
/// completing, or on a horizontal drag that has already won against the
/// scroll, never on the first contact.
class SpendingPaceChart extends StatefulWidget {
  const SpendingPaceChart({
    super.key,
    required this.palette,
    required this.pace,
  });

  final Palette palette;
  final SpendingPace pace;

  @override
  State<SpendingPaceChart> createState() => _SpendingPaceChartState();
}

class _SpendingPaceChartState extends State<SpendingPaceChart> {
  /// The day the readout shows, or null for today.
  int? _day;

  @override
  Widget build(BuildContext context) {
    final Palette palette = widget.palette;
    final SpendingPace pace = widget.pace;
    final ChartColors c = ChartColors.of(palette);
    final Color line = c.outflow;
    final Color ghost = palette.textMuted;
    final int lastDay = math.max(pace.daysInThisMonth, pace.lastMonth.length);
    final double top = <double>[
      pace.spentSoFar,
      if (pace.lastMonth.isNotEmpty) pace.lastMonth.last,
    ].reduce(math.max);
    final double maxY = top <= 0 ? 1 : top * 1.12;
    final TextScaler tick = _tickScaler(context);

    final double diff = pace.difference;
    final String? verdict = !pace.hasLastMonth
        ? null
        : diff.abs() < 0.005
        ? 'Exactly where last month was by day ${pace.day}.'
        : '${formatPeso(diff.abs())} ${diff > 0 ? 'more' : 'less'} than last '
              'month by day ${pace.day}.';

    // The readout reads the ENGINE'S figures for the day, never the drawn
    // spot: during the draw-in the spot is a fraction of the real value.
    final int day = (_day ?? pace.day).clamp(1, lastDay);
    final double? thisAt = day <= pace.thisMonth.length
        ? pace.thisMonth[day - 1]
        : null;
    // Past the end of a shorter last month, its last day, the same rule the
    // verdict uses (`lastMonthSameDay`).
    final double? lastAt = pace.lastMonth.isEmpty
        ? null
        : pace.lastMonth[math.min(day, pace.lastMonth.length) - 1];

    void pick(FlTouchEvent e, LineTouchResponse? r) {
      final bool settled =
          e is FlTapUpEvent ||
          e is FlPanStartEvent ||
          e is FlPanUpdateEvent ||
          e is FlLongPressStart ||
          e is FlLongPressMoveUpdate;
      if (!settled) return;
      final List<TouchLineBarSpot>? spots = r?.lineBarSpots;
      if (spots == null || spots.isEmpty) return;
      final int d = spots.first.x.round();
      if (d == day) return;
      HapticFeedback.selectionClick();
      setState(() => _day = d);
    }

    return Semantics(
      // The verdict below is visible text and is read in its own right; this
      // adds only what the chart shows and the sentence does not.
      label: pace.hasLastMonth
          ? 'Spent ${formatPeso(pace.spentSoFar)} so far this month. Last '
                'month by day ${pace.day}: '
                '${formatPeso(pace.lastMonthSameDay)}.'
          : 'Spent ${formatPeso(pace.spentSoFar)} so far this month.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // THE ANSWER LEADS, not the amount. The amount spent so far is
          // "Money out" in the card directly above on this view, and printing
          // it a second time here made the same figure appear three times in
          // a row once the month by month card was added under this one.
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
          ExcludeSemantics(
            child: SizedBox(
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
                          reservedSize: _tickBand(palette, tick),
                          interval: 1,
                          getTitlesWidget: (double v, TitleMeta meta) {
                            final int d = v.round();
                            // Day 1, the middle, and the end: enough to place
                            // a point, few enough for a 320dp phone.
                            if (d != 1 && d != 15 && d != lastDay) {
                              return const SizedBox.shrink();
                            }
                            return SideTitleWidget(
                              meta: meta,
                              child: Text(
                                '$d',
                                textScaler: tick,
                                style: AppType.caption(palette),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    lineTouchData: LineTouchData(
                      handleBuiltInTouches: false,
                      touchCallback: pick,
                      getTouchedSpotIndicator:
                          (LineChartBarData bar, List<int> spots) =>
                              <TouchedSpotIndicatorData>[
                                for (final int _ in spots)
                                  TouchedSpotIndicatorData(
                                    FlLine(
                                      color: palette.textMuted,
                                      strokeWidth: 1,
                                      dashArray: <int>[3, 3],
                                    ),
                                    FlDotData(
                                      getDotPainter:
                                          (_, _, LineChartBarData b, _) =>
                                              FlDotCirclePainter(
                                                radius: 4,
                                                color: b.color ?? line,
                                                strokeColor: palette.surface,
                                                strokeWidth: 2,
                                              ),
                                    ),
                                  ),
                              ],
                    ),
                    lineBarsData: <LineChartBarData>[
                      // Index 0: last month, dotted and quiet, drawn first so
                      // this month's line sits on top of it.
                      LineChartBarData(
                        spots: <FlSpot>[
                          for (int i = 0; i < pace.lastMonth.length; i++)
                            FlSpot(i + 1.0, pace.lastMonth[i] * t),
                        ],
                        // The picked day's marker, only once a day is picked:
                        // today already has its own dot.
                        showingIndicators: <int>[
                          if (_day != null && day <= pace.lastMonth.length)
                            day - 1,
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
                        showingIndicators: <int>[
                          if (_day != null && day <= pace.thisMonth.length)
                            day - 1,
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
          ),
          const SizedBox(height: Spacing.sm),
          // THE READOUT, which is also the key: each series' swatch, name
          // and its figure on the picked day.
          ExcludeSemantics(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  _day == null ? 'TODAY, DAY $day' : 'DAY $day',
                  style: AppType.kicker(palette),
                ),
                const SizedBox(height: Spacing.xs),
                Wrap(
                  spacing: Spacing.md,
                  runSpacing: Spacing.xs,
                  children: <Widget>[
                    _Key(
                      palette: palette,
                      color: line,
                      label: thisAt == null
                          ? 'This month, not yet'
                          : 'This month ${formatPeso(thisAt)}',
                    ),
                    if (lastAt != null)
                      _Key(
                        palette: palette,
                        color: ghost,
                        label: 'Last month ${formatPeso(lastAt)}',
                        dashed: true,
                      ),
                  ],
                ),
              ],
            ),
          ),
          // Said, because "Money out" above includes it and the line does
          // not, and two figures disagreeing in silence read as an error.
          if (pace.scheduledLater > 0) ...<Widget>[
            const SizedBox(height: Spacing.sm),
            Text(
              '${formatPeso(pace.scheduledLater)} dated later this month is '
              'not on the line yet.',
              style: AppType.caption(palette),
            ),
          ],
        ],
      ),
    );
  }
}

/// Axis ticks follow the system text size, but only up to 1.3x.
///
/// At 1.5x the tick labels were cut off at the bottom, and at 2.0x the six
/// month names ran into one word, "AprMayJunJulAugSep". Capping the TICKS is
/// acceptable because nothing is lost: the picked day and the selected month
/// are each repeated at full size in the readout under the chart.
TextScaler _tickScaler(BuildContext context) =>
    MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.3);

/// The height the tick row needs at that scale, so it is never clipped.
double _tickBand(Palette palette, TextScaler tick) {
  final TextStyle s = AppType.caption(palette);
  return tick.scale((s.fontSize ?? 11) * (s.height ?? 1.3)) + 8;
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
    this.initialIndex,
  });

  final Palette palette;

  /// Oldest first, current month last.
  final List<MonthTotals> months;

  /// The month selected at first, or null for the current month. On the
  /// monthly view the screen passes LAST month: the current month's three
  /// figures are already printed in the cards above and below this one, and
  /// opening on them repeated all three within a thumb's scroll. Last month
  /// is the comparison a person cannot see anywhere else.
  final int? initialIndex;

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
    final int sel = (_selected ?? widget.initialIndex ?? months.length - 1)
        .clamp(0, months.length - 1);
    final TextScaler tick = _tickScaler(context);

    // Screen reader stepping: swipe up or down on the card to move a month,
    // since a bar chart offers TalkBack nothing to tap.
    void step(int by) {
      final int to = (sel + by).clamp(0, months.length - 1);
      if (to != sel) setState(() => _selected = to);
    }

    String name(MonthTotals x) => '${_monthLong[x.month - 1]} ${x.year}';
    final MonthTotals m = months[sel];
    final double top = months.fold<double>(
      0,
      (double a, MonthTotals x) => math.max(a, math.max(x.income, x.expenses)),
    );
    final double maxY = top <= 0 ? 1 : top * 1.1;

    // 0.45, not lower: at 0.35 the other months went a muddy navy and brown
    // on the dark card.
    Color dim(Color col, int i) => i == sel ? col : col.withValues(alpha: 0.45);

    final double net = m.income - m.expenses;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // The chart and its key, as ONE adjustable control for a screen
        // reader: it names the selected month and steps through the others.
        Semantics(
          container: true,
          label: 'Month by month',
          value: name(m),
          increasedValue: sel < months.length - 1
              ? name(months[sel + 1])
              : null,
          decreasedValue: sel > 0 ? name(months[sel - 1]) : null,
          onIncrease: sel < months.length - 1 ? () => step(1) : null,
          onDecrease: sel > 0 ? () => step(-1) : null,
          child: ExcludeSemantics(
            child: Column(
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
                              reservedSize: _tickBand(palette, tick),
                              getTitlesWidget: (double v, TitleMeta meta) {
                                final int i = v.round();
                                if (i < 0 || i >= months.length) {
                                  return const SizedBox.shrink();
                                }
                                return SideTitleWidget(
                                  meta: meta,
                                  child: Text(
                                    _monthShort[months[i].month - 1],
                                    textScaler: tick,
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
                          // ONLY A COMPLETED TAP SELECTS. fl_chart reports the finger
                          // landing before the page decides the gesture is a scroll,
                          // and over this whole card that once meant scrolling past
                          // it quietly swapped the figures below for another month.
                          // A tap completes only if the finger barely moved, so a
                          // scroll can never select. (`isInterestedForInteractions`
                          // is false for a tap UP, so it cannot be the test here.)
                          touchCallback: (FlTouchEvent e, BarTouchResponse? r) {
                            if (e is! FlTapUpEvent) return;
                            final int? i = r?.spot?.touchedBarGroupIndex;
                            if (i == null || i == sel) return;
                            HapticFeedback.selectionClick();
                            setState(() => _selected = i);
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
              ],
            ),
          ),
        ),
        Divider(color: palette.border, height: Spacing.lg),
        // The selected month, exactly. Announced on change so a screen
        // reader user hears what their choice selected, and a CONTAINER so
        // only these figures are announced, not the axis labels as well.
        Semantics(
          container: true,
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

/// CASH, MONTH BY MONTH: did your cash grow or shrink, each month.
///
/// One bar per month from a shared zero line, above it when the month added
/// cash and below when it took cash away, in the app's own green and orange
/// (the side of the line carries direction, so colour is never the only
/// cue). Tap a month and the line under the chart says what it did. Same
/// model as [MonthlyInOutChart]: only a completed tap selects, so a scroll
/// that starts on the chart can never change the month, and on the monthly
/// view it opens on last month, since this month is the headline above.
class MonthlyCashChart extends StatefulWidget {
  const MonthlyCashChart({
    super.key,
    required this.palette,
    required this.months,
    this.initialIndex,
  });

  final Palette palette;

  /// Oldest first, current month last.
  final List<MonthTotals> months;

  /// The month selected at first, or null for the current month.
  final int? initialIndex;

  @override
  State<MonthlyCashChart> createState() => _MonthlyCashChartState();
}

class _MonthlyCashChartState extends State<MonthlyCashChart> {
  int? _selected;

  @override
  Widget build(BuildContext context) {
    final Palette palette = widget.palette;
    final List<MonthTotals> months = widget.months;
    final int sel = (_selected ?? widget.initialIndex ?? months.length - 1)
        .clamp(0, months.length - 1);
    final MonthTotals m = months[sel];
    final TextScaler tick = _tickScaler(context);

    // Symmetric, so the zero line sits mid-chart whatever the months did.
    final double reach = months.fold<double>(
      0,
      (double a, MonthTotals x) => math.max(a, x.cashChange.abs()),
    );
    final double r = reach <= 0 ? 1 : reach * 1.1;

    Color colour(MonthTotals x, int i) {
      final Color c = x.cashChange >= 0 ? palette.positive : palette.negative;
      return i == sel ? c : c.withValues(alpha: 0.45);
    }

    void step(int by) {
      final int to = (sel + by).clamp(0, months.length - 1);
      if (to != sel) setState(() => _selected = to);
    }

    String name(MonthTotals x) => '${_monthLong[x.month - 1]} ${x.year}';

    final String verdict = m.cashChange > 0
        ? 'Your cash grew by ${formatPeso(m.cashChange)}'
        : m.cashChange < 0
        ? 'Your cash went down by ${formatPeso(m.cashChange.abs())}'
        : 'Your cash did not change';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Semantics(
          container: true,
          label: 'Cash, month by month',
          value: name(m),
          increasedValue: sel < months.length - 1
              ? name(months[sel + 1])
              : null,
          decreasedValue: sel > 0 ? name(months[sel - 1]) : null,
          onIncrease: sel < months.length - 1 ? () => step(1) : null,
          onDecrease: sel > 0 ? () => step(-1) : null,
          child: ExcludeSemantics(
            child: SizedBox(
              height: 150,
              child: _DrawIn(
                builder: (double t) => BarChart(
                  duration: Duration.zero,
                  BarChartData(
                    minY: -r,
                    maxY: r,
                    alignment: BarChartAlignment.spaceAround,
                    borderData: FlBorderData(show: false),
                    gridData: const FlGridData(show: false),
                    extraLinesData: ExtraLinesData(
                      horizontalLines: <HorizontalLine>[
                        HorizontalLine(
                          y: 0,
                          color: palette.textMuted,
                          strokeWidth: 1,
                        ),
                      ],
                    ),
                    titlesData: FlTitlesData(
                      leftTitles: const AxisTitles(),
                      rightTitles: const AxisTitles(),
                      topTitles: const AxisTitles(),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: _tickBand(palette, tick),
                          getTitlesWidget: (double v, TitleMeta meta) {
                            final int i = v.round();
                            if (i < 0 || i >= months.length) {
                              return const SizedBox.shrink();
                            }
                            return SideTitleWidget(
                              meta: meta,
                              child: Text(
                                _monthShort[months[i].month - 1],
                                textScaler: tick,
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
                      touchExtraThreshold: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 200,
                      ),
                      allowTouchBarBackDraw: true,
                      // Only a completed tap selects; see MonthlyInOutChart.
                      touchCallback: (FlTouchEvent e, BarTouchResponse? res) {
                        if (e is! FlTapUpEvent) return;
                        final int? i = res?.spot?.touchedBarGroupIndex;
                        if (i == null || i == sel) return;
                        HapticFeedback.selectionClick();
                        setState(() => _selected = i);
                      },
                    ),
                    barGroups: <BarChartGroupData>[
                      for (int i = 0; i < months.length; i++)
                        BarChartGroupData(
                          x: i,
                          barRods: <BarChartRodData>[
                            BarChartRodData(
                              toY: months[i].cashChange * t,
                              width: 16,
                              color: colour(months[i], i),
                              // Rounded at the end away from zero only.
                              borderRadius: months[i].cashChange >= 0
                                  ? const BorderRadius.vertical(
                                      top: Radius.circular(4),
                                    )
                                  : const BorderRadius.vertical(
                                      bottom: Radius.circular(4),
                                    ),
                              // A whole-column target that does not draw.
                              backDrawRodData: BackgroundBarChartRodData(
                                show: true,
                                fromY: -r,
                                toY: r,
                                color: Colors.transparent,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        Divider(color: palette.border, height: Spacing.lg),
        Semantics(
          container: true,
          liveRegion: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(name(m).toUpperCase(), style: AppType.kicker(palette)),
              const SizedBox(height: Spacing.xs),
              Text(
                verdict,
                style: AppType.rowTitle(palette).copyWith(
                  color: m.cashChange > 0
                      ? palette.positive
                      : m.cashChange < 0
                      ? palette.negative
                      : palette.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
