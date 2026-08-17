// The net worth trend screen: the mockup's "Net Worth" detail, reached by
// tapping the figure on the Accounts hero. A period selector, a line chart of
// the recorded monthly net worth, and the window's highest, lowest and average.
//
// TWO deliberate, founder-relevant choices live here:
//
// 1. The line is a hand-rolled CustomPainter, NOT fl_chart. That is the
//    founder-approved charting architecture (docs/reviews/
//    charting-architecture-evaluation.md, Decision 4): fl_chart carries
//    part-to-whole charts like the donut, while the bespoke net worth line
//    stays a painter so its exact look and cheap repaint are preserved, the
//    same family as the Home sparkline and the Sweldo Timeline.
//
// 2. The periods are 3M, 6M, 1Y and All, not the mockup's 1M/3M/6M/1Y/All.
//    Salapify records ONE net worth snapshot per month, so a one-month window
//    is a single point with no line to draw. Rather than ship a tab that
//    always shows an empty state, the shortest honest window is three months.
//    Finer tracking would need daily snapshots, which is a storage change and
//    a founder decision, so it is deliberately not faked here.
//
// Every number is a golden-locked engine read (netWorthParts for the live
// figure, the recorded history for the rest); netWorthWindow and netWorthStats
// only window and describe those values, they compute no new money.

import 'package:flutter/material.dart';

import '../data/store.dart';
import '../money/debtmath.dart' show formatMoneyText;
import '../money/format.dart' show formatMoney;
import '../money/net_worth_history.dart';
import '../money/statements.dart' show netWorthParts;
import '../theme.dart';
import '../typography.dart';
import '../widgets/net_worth_sparkline.dart' show netWorthSparkDomain;
import '../widgets/salapify_icon.dart';
import '../widgets/segmented.dart';

const _monthAbbr = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// 'YYYY-MM' to a short axis label, e.g. 'Jun' or, when a window crosses a year
/// boundary, 'Jun 25'. The year is only shown when it adds information.
String _monthLabel(String key, {bool withYear = false}) {
  final parts = key.split('-');
  if (parts.length != 2) return key;
  final m = int.tryParse(parts[1]);
  if (m == null || m < 1 || m > 12) return key;
  final label = _monthAbbr[m - 1];
  if (!withYear) return label;
  final yy = parts[0].length >= 2 ? parts[0].substring(parts[0].length - 2) : parts[0];
  return '$label $yy';
}

class NetWorthTrendScreen extends StatefulWidget {
  final SalapifyStore store;
  const NetWorthTrendScreen({super.key, required this.store});

  @override
  State<NetWorthTrendScreen> createState() => _NetWorthTrendScreenState();
}

class _NetWorthTrendScreenState extends State<NetWorthTrendScreen> {
  // null is the All window. The others are month counts.
  int? _months = 6;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Net worth')),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: widget.store,
          builder: (context, _) {
            final nw = netWorthParts(
              widget.store.data,
              fx: widget.store.fxTable,
            )['netWorth'] as double;
            final month = netWorthMonthKey(DateTime.now());
            final history = netWorthHistoryOf(widget.store.data);
            final trend = netWorthTrend(history, month, nw);
            final points = netWorthWindow(
              history,
              month,
              nw,
              months: _months,
            );
            final stats = netWorthStats(points);

            return ListView(
              padding: Insets.screen,
              children: [
                _headerCard(nw, trend),
                const SizedBox(height: Gap.lg),
                Segmented<int?>(
                  options: const [
                    SegmentOption(value: 3, label: '3M'),
                    SegmentOption(value: 6, label: '6M'),
                    SegmentOption(value: 12, label: '1Y'),
                    SegmentOption(value: null, label: 'All'),
                  ],
                  current: _months,
                  onPick: (v) {
                    Haptics.select();
                    setState(() => _months = v);
                  },
                ),
                const SizedBox(height: Gap.lg),
                _chartCard(points),
                if (stats != null) ...[
                  const SizedBox(height: Gap.lg),
                  _statsRow(stats, points.length),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _headerCard(double nw, Map<String, dynamic>? trend) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Radii.hero),
        border: Border.all(color: Barako.border),
        gradient: Barako.heroWash,
      ),
      padding: Insets.hero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('CURRENT NET WORTH', style: Barako.kickerStyle),
          const SizedBox(height: Gap.sm),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              formatMoneyText(nw),
              maxLines: 1,
              style: AppText.amountLg.w8,
            ),
          ),
          if (trend != null) ...[
            const SizedBox(height: Gap.sm),
            _trendLine(trend),
          ],
        ],
      ),
    );
  }

  /// The same up-accent, down-muted, flat-in-words convention as the Accounts
  /// and Overview heroes, so a person never finds the three disagreeing.
  Widget _trendLine(Map<String, dynamic> trend) {
    final delta = trend['delta'] as double;
    final pct = trend['pct'] as double?;
    final flat = delta.abs() < 0.005;
    final up = delta > 0;
    final color = up ? Barako.primary : Barako.muted;
    final iconName = flat ? 'forward' : (up ? 'growth' : 'decline');
    final pctText = pct == null ? '' : ' (${pct.abs().toStringAsFixed(1)}%)';
    final label = flat
        ? 'No change this month'
        : '${up ? 'Up' : 'Down'} ${formatMoney(delta.abs())}$pctText this month';
    return Row(
      children: [
        Icon(salapifyIcon(iconName), size: IconSizes.dense, color: color),
        const SizedBox(width: Gap.xs),
        Flexible(
          child: Text(
            label,
            style: AppText.small.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
              height: 1.3,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }

  Widget _chartCard(List<NetWorthPoint> points) {
    // A line needs two points. With monthly snapshots a fresh user has one, so
    // this is the honest state rather than a squashed or invented line.
    if (points.length < 2) {
      return Card(
        child: Padding(
          padding: Insets.card,
          child: Column(
            children: [
              SalapifyGlyph('growth', size: IconSizes.disc),
              const SizedBox(height: Gap.md),
              Text(
                'Not enough history yet',
                style: AppText.subtitle.w7,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: Gap.xs),
              Text(
                'Salapify records your net worth once a month. Come back after '
                'a few months to see the line grow.',
                style: AppText.small.tint(Barako.muted),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    final withYear = points.first.month.substring(0, 4) !=
        points.last.month.substring(0, 4);
    return Card(
      child: Padding(
        padding: Insets.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              label:
                  'Net worth trend, ${points.length} months, from '
                  '${formatMoneyText(points.first.value)} to '
                  '${formatMoneyText(points.last.value)}.',
              child: ExcludeSemantics(
                child: SizedBox(
                  height: 176,
                  width: double.infinity,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: Motion.of(context, Motion.reveal),
                    curve: Motion.curve,
                    builder: (context, t, _) => CustomPaint(
                      painter: _TrendPainter(
                        values: [for (final p in points) p.value],
                        line: Barako.primary,
                        fill: Barako.primary.withValues(alpha: BarakoAlpha.hint),
                        dot: Barako.primary,
                        progress: t,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: Gap.sm),
            // The x-axis, ends only: the first and last month of the window.
            // A dense per-point axis would crowd a phone; the ends orient, and
            // the stats below carry the exact figures.
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _monthLabel(points.first.month, withYear: withYear),
                  style: AppText.caption.tint(Barako.muted),
                ),
                Text(
                  _monthLabel(points.last.month, withYear: withYear),
                  style: AppText.caption.tint(Barako.muted),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statsRow(({double high, double low, double avg}) stats, int count) {
    final label = _months == null ? 'All time' : 'Last $count months';
    return Card(
      child: Padding(
        padding: Insets.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    'OVER THIS WINDOW',
                    style: Barako.kickerStyle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: Gap.sm),
                Flexible(
                  child: Text(
                    label,
                    style: AppText.caption.tint(Barako.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Gap.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _stat('Highest', stats.high, Barako.primaryText)),
                Expanded(child: _stat('Lowest', stats.low, Barako.text)),
                Expanded(child: _stat('Average', stats.avg, Barako.text)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(String label, double value, Color tint) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: AppText.caption.tint(Barako.muted)),
      const SizedBox(height: 2),
      FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          formatMoneyText(value),
          maxLines: 1,
          style: AppText.amountRow.tint(tint),
        ),
      ),
    ],
  );
}

/// The trend line: the sparkline painter grown up for a full-height chart. Same
/// domain rule (the data's own range with headroom, no zero floor, because net
/// worth moves by a few percent and a zero floor would flatten it), same
/// left-to-right reveal, plus a "you are here" dot on the newest month.
class _TrendPainter extends CustomPainter {
  final List<double> values;
  final Color line;
  final Color fill;
  final Color dot;
  final double progress;
  _TrendPainter({
    required this.values,
    required this.line,
    required this.fill,
    required this.dot,
    this.progress = 1,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final (lo, hi) = netWorthSparkDomain(values);
    const pad = 6.0;
    final h = size.height - pad * 2;
    double x(int i) => i / (values.length - 1) * size.width;
    double y(double v) => pad + (hi - v) / (hi - lo) * h;

    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width * progress, size.height));

    final area = Path()..moveTo(x(0), y(values[0]));
    for (var i = 1; i < values.length; i++) {
      area.lineTo(x(i), y(values[i]));
    }
    area
      ..lineTo(x(values.length - 1), size.height)
      ..lineTo(x(0), size.height)
      ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [fill, fill.withValues(alpha: 0)],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    final path = Path()..moveTo(x(0), y(values[0]));
    for (var i = 1; i < values.length; i++) {
      path.lineTo(x(i), y(values[i]));
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();

    if (progress >= 1) {
      final endX = x(values.length - 1).clamp(4.0, size.width - 4.0);
      final endY = y(values.last);
      // A soft halo so the current point reads as "here" without a label.
      canvas.drawCircle(
        Offset(endX, endY),
        7,
        Paint()..color = dot.withValues(alpha: BarakoAlpha.tint),
      );
      canvas.drawCircle(Offset(endX, endY), 3.5, Paint()..color = dot);
    }
  }

  @override
  bool shouldRepaint(covariant _TrendPainter old) =>
      old.values != values ||
      old.progress != progress ||
      old.line != line ||
      old.fill != fill ||
      old.dot != dot;
}
