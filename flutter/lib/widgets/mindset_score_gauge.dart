// The Money Mindset Decision Score gauge: a circular 0..100 dial with a
// green-to-amber-to-red arc that fills to the score and the number in the
// middle. Pure CustomPaint (ships over the air, no new dependency) with an
// animated sweep on first build. The scale colour is fixed traffic-light
// meaning (comfortable / pause / big impact), the same three bands the rest of
// Money Mindset speaks.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';
import '../typography.dart';

class MindsetScoreGauge extends StatelessWidget {
  const MindsetScoreGauge({
    super.key,
    required this.score,
    required this.band,
    this.size = 168,
    this.animate = true,
  });

  /// 0..100 Decision Score.
  final int score;

  /// 1 comfortable, 2 pause, 3 big impact (drives the centre number colour).
  final int band;
  final double size;
  final bool animate;

  static Color _bandColor(int band) => switch (band) {
    1 => Barako.primary,
    2 => Barako.warning,
    _ => Barako.warningStrong,
  };

  @override
  Widget build(BuildContext context) {
    final target = (score.clamp(0, 100)) / 100;
    final color = _bandColor(band);
    Widget gauge(double t) => SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size.square(size),
            painter: _GaugePainter(
              fraction: t,
              track: Barako.border,
              // The traffic-light scale, so the score always reads against where
              // it sits on the comfortable-to-danger dial.
              scale: [Barako.primary, Barako.warning, Barako.warningStrong],
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$score',
                style: TextStyle(
                  fontFamily: AppText.hero.fontFamily,
                  fontSize: size * 0.30,
                  fontWeight: TypeWeight.heavy,
                  color: color,
                  height: 1.0,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 2),
              Text('/ 100', style: AppText.small.tint(Barako.muted)),
            ],
          ),
        ],
      ),
    );

    if (!animate) return gauge(target);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: target),
      duration: const Duration(milliseconds: 750),
      curve: Curves.easeOutCubic,
      builder: (context, t, _) => gauge(t),
    );
  }
}

class _GaugePainter extends CustomPainter {
  _GaugePainter({
    required this.fraction,
    required this.track,
    required this.scale,
  });

  final double fraction;
  final Color track;
  final List<Color> scale;

  // A 270-degree dial with the gap at the bottom, like a speedometer.
  static const double _start = math.pi * 0.75; // 135 deg
  static const double _sweep = math.pi * 1.5; // 270 deg

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.085;
    final rect = Rect.fromLTWH(
      stroke / 2,
      stroke / 2,
      size.width - stroke,
      size.height - stroke,
    );

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = track;
    canvas.drawArc(rect, _start, _sweep, false, trackPaint);

    if (fraction <= 0) return;

    final valuePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: _start,
        endAngle: _start + _sweep,
        colors: scale,
        stops: const [0.0, 0.55, 1.0],
        transform: GradientRotation(_start),
      ).createShader(rect);
    canvas.drawArc(rect, _start, _sweep * fraction, false, valuePaint);
  }

  @override
  bool shouldRepaint(_GaugePainter old) =>
      old.fraction != fraction || old.track != track;
}
