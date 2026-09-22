// The Net Worth hero's trend chart: a sparkline of the monthly net-worth
// snapshots, the rising line the dashboard mockup draws under the figure. Pure
// drawing: the values arrive already computed (each is a netWorthParts snapshot
// from settings.netWorthHistory, plus today's live figure as the last point).
//
// Unlike the Sweldo Timeline sparkline, this one does NOT floor its domain at
// zero. Net worth lives in the hundreds of thousands and moves by a few percent
// a month, so a zero floor would squash every month into one flat line riding
// the top edge. A trend chart's whole job is to show that movement, so it scales
// to the data's own range with a little headroom. The honest magnitude is right
// above it in the hero (the peso figure and the exact percent); this line shows
// the SHAPE.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// The (floor, ceiling) the sparkline draws in: the data's own min and max with
/// 15 percent of headroom on each side, so the line never touches an edge. A
/// flat series (every month identical, or a single point) gets a symmetric band
/// so it sits mid-card instead of on the floor.
(double, double) netWorthSparkDomain(List<double> vals) {
  final lo = vals.reduce(math.min);
  final hi = vals.reduce(math.max);
  if (lo == hi) {
    final band = hi.abs() < 1 ? 1.0 : hi.abs() * 0.08;
    return (lo - band, hi + band);
  }
  final pad = (hi - lo) * 0.15;
  return (lo - pad, hi + pad);
}

/// A compact net-worth trend line for the Home hero. Needs at least two points
/// to draw a trend; the hero already hides it below that, and this guards the
/// same case so it is never a runtime error.
class NetWorthSparkline extends StatelessWidget {
  final List<double> values;
  final double height;
  const NetWorthSparkline({super.key, required this.values, this.height = 64});

  @override
  Widget build(BuildContext context) {
    if (values.length < 2) return SizedBox(height: height);
    // Draws itself in once, left to right, when the card mounts, the same
    // reveal token the Sweldo Timeline sparkline uses. Collapses to an instant
    // appear under reduce-motion.
    return SizedBox(
      height: height,
      width: double.infinity,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: Motion.of(context, Motion.reveal),
        curve: Motion.curve,
        builder: (context, t, _) => CustomPaint(
          painter: _NetWorthSparkPainter(
            values: values,
            line: Barako.primary,
            fill: Barako.primary.withValues(alpha: BarakoAlpha.hint),
            progress: t,
          ),
        ),
      ),
    );
  }
}

class _NetWorthSparkPainter extends CustomPainter {
  final List<double> values;
  final Color line;
  final Color fill;

  /// 0..1 draw-in reveal; the painted content is clipped to this fraction of
  /// the width. 1 is the fully drawn chart.
  final double progress;
  _NetWorthSparkPainter({
    required this.values,
    required this.line,
    required this.fill,
    this.progress = 1,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final (lo, hi) = netWorthSparkDomain(values);
    const pad = 4.0;
    final h = size.height - pad * 2;
    double x(int i) => i / (values.length - 1) * size.width;
    double y(double v) => pad + (hi - v) / (hi - lo) * h;

    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width * progress, size.height));

    // The fill fades to nothing on the way down, so the area under the line
    // reads as shading rather than a solid block.
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
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );

    canvas.restore();

    // The end dot marks "you are here" at the newest month. It sits outside the
    // reveal clip so it lands only when the line has fully drawn in, and is
    // nudged inside the frame so it is never clipped by the card edge.
    if (progress >= 1) {
      final endX = x(values.length - 1).clamp(3.0, size.width - 3.0);
      canvas.drawCircle(
        Offset(endX, y(values.last)),
        3,
        Paint()..color = line,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _NetWorthSparkPainter old) =>
      old.values != values ||
      old.progress != progress ||
      old.line != line ||
      old.fill != fill;
}
