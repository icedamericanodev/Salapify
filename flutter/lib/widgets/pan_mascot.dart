// Pan, the mascot cup, as ONE reusable widget shared by the Home check-in and
// the Ask Pan header. It takes a PanMood (mapped in money/pan_mood.dart from
// either the coach or a chat reply) and shows kapeng Barako reacting: calm rests
// with a slow wisp, nudge leans in attentive, worried goes wide-eyed with a
// bead of sweat, happy beams with lively steam. Motion is change-driven, a short
// one-shot bob when the mood actually changes, never a constant loop, to protect
// battery. Colors come from the active Barako palette.
//
// ==========================================================================
// RIVE SWAP POINT (the ONE place to swap in the real animated Pan later):
// When a rigged Pan.riv exists, add the `rive` package, drop the file at
// [kPanRivAsset], declare it under flutter/assets in pubspec, and replace the
// `PanCupPainter` below with the Rive widget driving a single number input
// named "mood" set to `mood.input` (0 calm, 1 nudge, 2 worried, 3 happy).
// Nothing else, the mood engine, the call sites, and the input contract, changes.
// (The share card paints Pan through PanCupPainter with a baked PanPalette;
// keep a static-render path for it when swapping.)
// ==========================================================================

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../money/pan_mood.dart';
import '../theme.dart';

/// The single source of truth for where the real Pan Rive file will live.
const String kPanRivAsset = 'assets/pan/pan.riv';

class PanMascot extends StatefulWidget {
  final PanMood mood;
  final double size;
  const PanMascot({super.key, required this.mood, this.size = 64});

  @override
  State<PanMascot> createState() => _PanMascotState();
}

class _PanMascotState extends State<PanMascot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bob = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  )..forward();

  @override
  void didUpdateWidget(PanMascot old) {
    super.didUpdateWidget(old);
    // Only react when the mood genuinely changes, not on every rebuild.
    if (old.mood != widget.mood) _bob.forward(from: 0);
  }

  @override
  void dispose() {
    _bob.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Pan, your coffee guide, looking ${_moodWord(widget.mood)}',
      child: AnimatedBuilder(
        animation: _bob,
        builder: (context, _) {
          // A small settle: bob up a touch then ease home, once per mood change.
          final t = Curves.easeOut.transform(_bob.value);
          final lift = math.sin(t * math.pi) * (widget.size * 0.06);
          return SizedBox(
            width: widget.size,
            height: widget.size,
            child: Transform.translate(
              offset: Offset(0, -lift),
              child: CustomPaint(
                painter: PanCupPainter(mood: widget.mood, wisp: t),
              ),
            ),
          );
        },
      ),
    );
  }

  String _moodWord(PanMood m) => switch (m) {
    PanMood.calm => 'calm',
    PanMood.nudge => 'attentive',
    PanMood.worried => 'worried',
    PanMood.happy => 'happy',
  };
}

/// The colors Pan is drawn with. In the app the painter reads the live Barako
/// palette (no palette passed), so Pan always matches the active theme. The
/// share card passes an explicit baked palette instead: the exported image is
/// brand marketing wherever it lands and must never inherit the sender's
/// theme.
class PanPalette {
  final Color cup; // body, handle, and eye ink
  final Color face; // eyes and mouth strokes
  final Color calm; // per-mood accent (steam, and the worried sweat bead)
  final Color nudge;
  final Color worried;
  final Color happy;
  const PanPalette({
    required this.cup,
    required this.face,
    required this.calm,
    required this.nudge,
    required this.worried,
    required this.happy,
  });
}

/// The placeholder cup, replaced by the real Rive art at the swap point above;
/// the mood contract stays identical. Public because the recap share card
/// paints Pan directly (statically, with its own baked palette).
class PanCupPainter extends CustomPainter {
  final PanMood mood;
  final double wisp; // 0..1 one-shot progress, for a gentle steam settle
  final PanPalette? palette; // null = live Barako, read at paint time
  PanCupPainter({required this.mood, required this.wisp, this.palette});

  PanPalette get _colors =>
      palette ??
      PanPalette(
        cup: Barako.primary,
        face: Barako.onPrimary,
        calm: Barako.faint,
        nudge: Barako.primary,
        worried: Barako.warningStrong,
        happy: Barako.celebrate,
      );

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final c = _colors;
    final accent = switch (mood) {
      PanMood.calm => c.calm,
      PanMood.nudge => c.nudge,
      PanMood.worried => c.worried,
      PanMood.happy => c.happy,
    };
    final cup = c.cup;
    final face = c.face;
    final ink = c.cup;

    // Steam above the cup: one wisp for calm/nudge/worried, two for happy.
    final steamPaint = Paint()
      ..color = accent.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.035
      ..strokeCap = StrokeCap.round;
    final wisps = mood == PanMood.happy ? 2 : 1;
    for (var i = 0; i < wisps; i++) {
      final cx = w * (wisps == 1 ? 0.5 : (i == 0 ? 0.4 : 0.6));
      final path = Path()..moveTo(cx, h * 0.24);
      final sway = w * 0.05 * (0.6 + 0.4 * wisp);
      path.quadraticBezierTo(cx - sway, h * 0.17, cx, h * 0.11);
      path.quadraticBezierTo(cx + sway, h * 0.05, cx, h * 0.0);
      canvas.drawPath(path, steamPaint);
    }

    // Cup body (rounded), with a little handle on the right.
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.2, h * 0.3, w * 0.52, h * 0.6),
      Radius.circular(w * 0.14),
    );
    canvas.drawRRect(bodyRect, Paint()..color = cup);
    final handle = Path()
      ..addArc(Rect.fromLTWH(w * 0.66, h * 0.42, w * 0.22, h * 0.3), -1.2, 2.4);
    canvas.drawPath(
      handle,
      Paint()
        ..color = cup
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.06,
    );

    // Face plate.
    final faceCx = w * 0.46, faceCy = h * 0.58;
    // Eyes.
    final eyePaint = Paint()..color = face;
    final eyeInk = Paint()..color = ink;
    final eyeDx = w * 0.1, eyeY = faceCy - h * 0.04;
    for (final dir in [-1, 1]) {
      final ex = faceCx + dir * eyeDx;
      switch (mood) {
        case PanMood.worried:
          canvas.drawCircle(Offset(ex, eyeY), w * 0.055, eyePaint);
          canvas.drawCircle(Offset(ex, eyeY), w * 0.025, eyeInk);
        case PanMood.happy:
          // Happy upward arcs.
          final p = Path()
            ..addArc(
              Rect.fromCircle(center: Offset(ex, eyeY), radius: w * 0.05),
              math.pi,
              math.pi,
            );
          canvas.drawPath(
            p,
            Paint()
              ..color = face
              ..style = PaintingStyle.stroke
              ..strokeWidth = w * 0.03
              ..strokeCap = StrokeCap.round,
          );
        case PanMood.calm:
          // Relaxed downward arcs (soft, sleepy).
          final p = Path()
            ..addArc(
              Rect.fromCircle(center: Offset(ex, eyeY), radius: w * 0.045),
              0,
              math.pi,
            );
          canvas.drawPath(
            p,
            Paint()
              ..color = face
              ..style = PaintingStyle.stroke
              ..strokeWidth = w * 0.03
              ..strokeCap = StrokeCap.round,
          );
        case PanMood.nudge:
          canvas.drawCircle(Offset(ex, eyeY), w * 0.04, eyePaint);
          canvas.drawCircle(Offset(ex, eyeY), w * 0.02, eyeInk);
      }
    }

    // Mouth.
    final mouthY = faceCy + h * 0.06;
    final mouthPaint = Paint()
      ..color = face
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.03
      ..strokeCap = StrokeCap.round;
    switch (mood) {
      case PanMood.happy:
        final p = Path()
          ..addArc(
            Rect.fromCircle(center: Offset(faceCx, mouthY), radius: w * 0.09),
            0.15 * math.pi,
            0.7 * math.pi,
          );
        canvas.drawPath(p, mouthPaint);
      case PanMood.worried:
        canvas.drawCircle(
          Offset(faceCx, mouthY + h * 0.01),
          w * 0.03,
          Paint()..color = face,
        );
        // A little bead of sweat by the right eye.
        canvas.drawCircle(
          Offset(faceCx + w * 0.16, eyeY),
          w * 0.022,
          Paint()..color = accent.withValues(alpha: 0.8),
        );
      case PanMood.nudge:
        canvas.drawLine(
          Offset(faceCx - w * 0.05, mouthY),
          Offset(faceCx + w * 0.05, mouthY),
          mouthPaint,
        );
      case PanMood.calm:
        final p = Path()
          ..addArc(
            Rect.fromCircle(center: Offset(faceCx, mouthY), radius: w * 0.06),
            0.2 * math.pi,
            0.6 * math.pi,
          );
        canvas.drawPath(p, mouthPaint);
    }
  }

  @override
  bool shouldRepaint(covariant PanCupPainter old) =>
      old.mood != mood || old.wisp != wisp || old.palette != palette;
}
