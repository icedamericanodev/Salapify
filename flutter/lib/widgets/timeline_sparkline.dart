// A compact sparkline of the Sweldo Timeline's conservative balance line for
// the Home card: the polyline, a dot on the tightest day (warning colored when
// cash runs out), and a dashed zero line when the window dips below empty.
// Pure drawing: every number arrives computed by money/timeline.dart.

import 'package:flutter/material.dart';

import '../theme.dart';

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
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _SparkPainter(
          days: days,
          line: Barako.primary,
          fill: Barako.primary.withValues(alpha: 0.14),
          warn: Barako.warningStrong,
          anyNegative: anyNegative,
          lowDate: lowDate,
        ),
      ),
    );
  }
}

class _SparkPainter extends CustomPainter {
  final List<Map<String, dynamic>> days;
  final Color line;
  final Color fill;
  final Color warn;
  final bool anyNegative;
  final String lowDate;
  _SparkPainter({
    required this.days,
    required this.line,
    required this.fill,
    required this.warn,
    required this.anyNegative,
    required this.lowDate,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (days.isEmpty) return;
    final vals = [for (final d in days) (d['balance'] as num).toDouble()];
    var lo = vals.reduce((a, b) => a < b ? a : b);
    var hi = vals.reduce((a, b) => a > b ? a : b);
    if (lo > 0) lo = 0;
    if (hi < 0) hi = 0;
    if (hi == lo) hi = lo + 1;
    const pad = 4.0;
    final h = size.height - pad * 2;
    double x(int i) =>
        days.length == 1 ? size.width / 2 : i / (days.length - 1) * size.width;
    double y(double v) => pad + (hi - v) / (hi - lo) * h;

    if (lo < 0) {
      final zeroY = y(0);
      final zp = Paint()
        ..color = warn.withValues(alpha: 0.45)
        ..strokeWidth = 1;
      const dash = 3.0;
      for (var dx = 0.0; dx < size.width; dx += dash * 2) {
        canvas.drawLine(Offset(dx, zeroY), Offset(dx + dash, zeroY), zp);
      }
    }

    final area = Path()..moveTo(x(0), y(vals[0]));
    for (var i = 1; i < vals.length; i++) {
      area.lineTo(x(i), y(vals[i]));
    }
    area
      ..lineTo(x(vals.length - 1), size.height)
      ..lineTo(x(0), size.height)
      ..close();
    canvas.drawPath(area, Paint()..color = fill);

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
  }

  @override
  bool shouldRepaint(covariant _SparkPainter old) =>
      old.days != days || old.anyNegative != anyNegative;
}
