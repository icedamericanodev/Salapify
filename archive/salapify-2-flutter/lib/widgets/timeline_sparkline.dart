// A compact sparkline of the Sweldo Timeline's conservative balance line for
// the Home card: the polyline, a dot on the tightest day (warning colored when
// cash runs out), a dashed zero baseline, and a fill that fades out instead of
// reading as a block. Pure drawing: every number arrives computed by
// money/timeline.dart.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// The y-domain the sparkline draws in, as (floor, ceiling).
///
/// The audit's P0-2: scaled to the data's raw min and max, a steady week
/// degenerated into a line riding the card's top edge over one solid
/// rectangle of fill, which read as a rendering bug on the app's front page.
/// The floor stays at zero (or the deepest dip when the window goes
/// negative, so the dip is still on screen), and the ceiling is the next
/// "nice" number a step ABOVE the peak, never the peak itself, so the line
/// always has headroom and the shape reads as a chart.
(double, double) sparkDomain(List<double> vals) {
  var lo = vals.reduce(math.min);
  var hi = vals.reduce(math.max);
  if (lo > 0) lo = 0;
  if (hi < 0) hi = 0;
  // 15 percent of headroom before snapping up, so a peak sitting exactly on
  // a nice number (a 20,000 balance) still gets a ceiling above it. A window
  // that never goes positive gets a sliver of air above zero instead, sized
  // to the dip, so the zero baseline stays visibly inside the frame.
  final ceiling = hi <= 0
      ? _niceCeil(math.max(1, -lo * 0.15))
      : _niceCeil(hi * 1.15);
  return (lo, ceiling);
}

/// The smallest 1 / 1.5 / 2 / 2.5 / 3 / 4 / 5 / 7.5 x 10^k value >= [v].
double _niceCeil(double v) {
  final mag = math.pow(10.0, (math.log(v) / math.ln10).floor()).toDouble();
  for (final m in const [1.0, 1.5, 2.0, 2.5, 3.0, 4.0, 5.0, 7.5]) {
    if (v <= m * mag) return m * mag;
  }
  return 10 * mag;
}

class TimelineSparkline extends StatelessWidget {
  final List<Map<String, dynamic>> days;
  final bool anyNegative;
  final String lowDate;
  final double height;
  const TimelineSparkline({
    super.key,
    required this.days,
    required this.anyNegative,
    required this.lowDate,
    this.height = 44,
  });

  @override
  Widget build(BuildContext context) {
    // The line draws itself in once, left to right, when the card mounts: a
    // reveal, the one motion token sized for content arriving. The tween
    // runs begin-to-end at mount and never again on rebuilds (the tween
    // object is value-equal across builds), and under reduce-motion
    // Motion.of collapses the duration to zero so the chart simply appears
    // complete, which is exactly what that setting asks for.
    return SizedBox(
      height: height,
      width: double.infinity,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: Motion.of(context, Motion.reveal),
        curve: Motion.curve,
        builder: (context, t, _) => CustomPaint(
          painter: _SparkPainter(
            days: days,
            line: Barako.primary,
            fill: Barako.primary.withValues(alpha: BarakoAlpha.hint),
            baseline: Barako.border,
            warn: Barako.warningStrong,
            anyNegative: anyNegative,
            lowDate: lowDate,
            progress: t,
          ),
        ),
      ),
    );
  }
}

class _SparkPainter extends CustomPainter {
  final List<Map<String, dynamic>> days;
  final Color line;
  final Color fill;
  final Color baseline;
  final Color warn;
  final bool anyNegative;
  final String lowDate;

  /// 0..1 draw-in reveal; the painted content is clipped to this fraction of
  /// the width. 1 is the fully drawn chart.
  final double progress;
  _SparkPainter({
    required this.days,
    required this.line,
    required this.fill,
    required this.baseline,
    required this.warn,
    required this.anyNegative,
    required this.lowDate,
    this.progress = 1,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (days.isEmpty) return;
    final vals = [for (final d in days) (d['balance'] as num).toDouble()];
    final (lo, hi) = sparkDomain(vals);
    const pad = 4.0;
    final h = size.height - pad * 2;
    double x(int i) =>
        days.length == 1 ? size.width / 2 : i / (days.length - 1) * size.width;
    double y(double v) => pad + (hi - v) / (hi - lo) * h;

    // The zero baseline, always: it grounds the fill so "how high is the
    // line" has a visible answer. Warning colored when the window actually
    // dips below empty, a quiet hairline otherwise.
    final zeroY = y(0);
    final zp = Paint()
      ..color = anyNegative ? warn.withValues(alpha: 0.45) : baseline
      ..strokeWidth = 1;
    const dash = 3.0;
    for (var dx = 0.0; dx < size.width; dx += dash * 2) {
      canvas.drawLine(Offset(dx, zeroY), Offset(dx + dash, zeroY), zp);
    }

    // Everything below reveals left to right with [progress]; the baseline
    // above stays whole from the first frame so the chart's ground is never
    // the thing animating.
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width * progress, size.height));

    // The fill fades to nothing on the way down. A uniform fill was most of
    // the "flat orange block": with the domain fixed the line has room, and
    // with the fade the area under it reads as shading, not a rectangle.
    final area = Path()..moveTo(x(0), y(vals[0]));
    for (var i = 1; i < vals.length; i++) {
      area.lineTo(x(i), y(vals[i]));
    }
    area
      ..lineTo(x(vals.length - 1), size.height)
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

    final path = Path()..moveTo(x(0), y(vals[0]));
    for (var i = 1; i < vals.length; i++) {
      path.lineTo(x(i), y(vals[i]));
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeJoin = StrokeJoin.round,
    );

    var lowI = 0;
    for (var i = 1; i < days.length; i++) {
      if (days[i]['date'] == lowDate) {
        lowI = i;
        break;
      }
    }
    final markX = x(lowI).clamp(2.5, size.width - 2.5);
    canvas.drawCircle(
      Offset(markX, y(vals[lowI])),
      2.5,
      Paint()..color = anyNegative ? warn : line,
    );

    canvas.restore();
  }

  // Colors included, closing the deferred note from f3.76: they were safe to
  // omit only while the days list was rebuilt every build, which is exactly
  // the kind of coincidence that stops being true silently.
  @override
  bool shouldRepaint(covariant _SparkPainter old) =>
      old.days != days ||
      old.anyNegative != anyNegative ||
      old.progress != progress ||
      old.line != line ||
      old.fill != fill ||
      old.baseline != baseline ||
      old.warn != warn;
}
