// Pan, the mascot cup, as ONE reusable widget shared by the Home check-in and
// the Ask Pan header. It takes a PanMood (mapped in money/pan_mood.dart from
// either the coach or a chat reply) and shows kapeng Barako reacting: calm rests
// with a slow wisp, nudge leans in attentive, worried goes wide-eyed with a
// bead of sweat, happy beams with lively steam. Motion is change-driven, a short
// one-shot bob when the mood actually changes, never a constant loop, to protect
// battery. His colour is his own and never comes from the active palette.
//
// ==========================================================================
// Pan is drawn from four rendered PNGs (assets/pan/), one per mood. The
// code-drawn PanCupPainter is NOT dead: it is the errorBuilder fallback here,
// and the share cards still paint through it with a baked brand palette so an
// exported image never inherits the sender's theme.
//
// Pan is ONE colour on every theme, and that is a decision rather than a
// limitation (founder, 2026-07-26). The machinery to reskin him per theme was
// built, tested, and looked at across all eight palettes, and then removed on
// purpose: a character whose colour follows the wallpaper is wearing a
// costume, while a character with a fixed colour is recognisably himself. The
// signature is worth more than the colour coordination.
//
// Practically, that means NOTHING here may read a live Barako getter, or Pan
// starts drifting with the theme again through the back door. The fallback
// painter below is handed a baked palette for exactly that reason.
//
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
import '../theme.dart' show Motion;

/// The single source of truth for where the real Pan Rive file will live.
const String kPanRivAsset = 'assets/pan/pan.riv';

/// The rendered face for a mood.
///
/// One file per mood rather than a sprite sheet: four small PNGs are simpler
/// to swap, and a sheet would have to be re-cut every time a face is redrawn.
///
/// All four are rendered on one 360px canvas with the cup at an IDENTICAL
/// width, centre, and baseline, so swapping moods changes the face and
/// nothing else. Per-image cropping would resize Pan between moods, and a
/// character who grows when he smiles reads as a glitch rather than a
/// reaction.
/// Pan's emotional vocabulary: rendered feeling faces, the way Pan actually
/// reacts to your money. The reaction machine speaks in [PanMood] (calm, nudge,
/// worried, happy) and maps into this set, but ANY screen, and Pan the
/// assistant, can also ask for a specific feeling directly. This is Pan's face
/// as Salapify's interface: one recognisable orange cup that genuinely feels.
///
/// The set is deliberately open: a new feeling is a file drop under
/// assets/pan/emotions plus an enum value, nothing else.
enum PanEmotion {
  content, // a soft, pleased smile: on track, all is well
  worried, // brows up, a bead of sweat: money getting tight
  // teary. NEVER a verdict on the user's own money (a missed payment, a blown
  // budget): performing pity at someone who just slipped is unkind and worried
  // already covers money-at-risk. Reserved for non-verdict moments only, a
  // recovered backup or a genuine goodbye, or authored lesson narrative.
  sad,
  angry, // frustrated, never AT you: reserved for a rip-off on your side
  // heavy-lidded, weary. NEVER tied to the SIZE of a balance, bill, or debt,
  // which would read as "your debt tires even me" to exactly the most indebted
  // user. If it ever ships, gate it on a neutral context (a very late-night
  // log), never a judgement on the numbers.
  tired,
}

/// Where each feeling's rendered art lives. One file per emotion, transparent
/// background, cup centred at a consistent size, so swapping feelings changes
/// the face and nothing else.
String panEmotionAsset(PanEmotion e) => 'assets/pan/emotions/pan-${e.name}.png';

/// The four reactive money moods map onto the feelings, so the Home check-in
/// and Ask Pan header light up with the new art for free. Kind by default:
/// everything positive or resting is content, and only genuine money-at-risk is
/// worried. The heavier feelings (sad, tired) and angry are reserved for
/// specific moments rather than the ambient mood, so Pan never cries at, or
/// scowls at, someone who is already worried about their money.
PanEmotion emotionForMood(PanMood mood) => switch (mood) {
  PanMood.worried => PanEmotion.worried,
  PanMood.calm || PanMood.nudge || PanMood.happy => PanEmotion.content,
};

/// The coarse reverse map the code-drawn fallback painter needs. It only knows
/// four faces, so every feeling falls back to the nearest one on the rare path
/// where a rendered asset fails to load (assets are bundled, so this is the
/// belt-and-braces case, never the everyday one).
PanMood _moodForEmotion(PanEmotion e) => switch (e) {
  // calm, not happy: the fallback cup's calm face is a soft, sleepy smile,
  // which matches content far better than happy's big beaming grin. This only
  // shows on the rare path where a bundled emotion PNG fails to load.
  PanEmotion.content => PanMood.calm,
  PanEmotion.worried || PanEmotion.sad || PanEmotion.tired => PanMood.worried,
  PanEmotion.angry => PanMood.worried,
};

/// Pan's signature colour, and the ONLY colour he is ever drawn in.
///
/// It matches Barako's primary because Barako is the Salapify look, but the
/// two are now independent on purpose: if Barako is ever retuned, Pan does
/// NOT follow. That is the whole point of a signature. Change this only when
/// deliberately restyling the character, and expect to redraw the artwork to
/// match, because the PNGs carry this colour baked in.
const Color panSignatureColor = Color(0xFFFF8A3D);

/// The palette the fallback cup is drawn with when an asset fails to load.
///
/// Baked, never live. If this read the active Barako palette, a missing asset
/// would produce a Pan that DOES change colour with the theme, which is the
/// one behaviour the signature exists to prevent, showing up only in the rare
/// case nobody looks at.
const PanPalette kPanSignaturePalette = PanPalette(
  cup: panSignatureColor,
  face: Color(0xFF3B2415),
  calm: Color(0xFFF0E2D8),
  nudge: panSignatureColor,
  worried: Color(0xFFE8B14C),
  happy: Color(0xFFF0E2D8),
);

class PanMascot extends StatefulWidget {
  final PanEmotion emotion;
  final double size;

  /// Const is SAFE here only because Pan reads no live palette at all: his
  /// colour is baked into the artwork and into [kPanSignaturePalette].
  ///
  /// If anything in build() below ever reads a mutable Barako getter again,
  /// this const must come off. Dart canonicalizes const instances, so a const
  /// call site would make two builds compare equal, Element.updateChild would
  /// skip build() entirely, and Pan would be frozen in the previous palette
  /// while every other pixel on screen moved on. That footgun has bitten this
  /// codebase twice.
  const PanMascot.emotion({super.key, required this.emotion, this.size = 64});

  /// The reactive callers speak in [PanMood]; this maps a mood to its feeling
  /// so the existing check-in and Ask Pan header light up with the new art
  /// unchanged. Not const because it computes the mapping, which is fine: those
  /// call sites were never const.
  PanMascot({Key? key, required PanMood mood, double size = 64})
    : this.emotion(key: key, emotion: emotionForMood(mood), size: size);

  @override
  State<PanMascot> createState() => _PanMascotState();
}

class _PanMascotState extends State<PanMascot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bob = AnimationController(
    vsync: this,
    duration: Motion.reveal,
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reduce-motion collapses the bob to an instant settle. The duration is
    // set here because Motion.of needs a context, which the field initializer
    // does not have, and the first forward waits for the same reason: this
    // controller used to ignore the OS setting entirely.
    _bob.duration = Motion.of(context, Motion.reveal);
    if (!_started) {
      _started = true;
      _bob.forward();
    }
  }

  @override
  void didUpdateWidget(PanMascot old) {
    super.didUpdateWidget(old);
    // Only react when the feeling genuinely changes, not on every rebuild.
    if (old.emotion != widget.emotion) _bob.forward(from: 0);
  }

  @override
  void dispose() {
    _bob.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Pan, your coffee guide, ${_emotionWord(widget.emotion)}',
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
              // The rendered artwork, with the code-drawn cup as the safety
              // net. A missing or corrupt asset must never leave a hole where
              // the app's character should be, and errorBuilder is the only
              // thing standing between that and a blank box.
              child: Image.asset(
                panEmotionAsset(widget.emotion),
                width: widget.size,
                height: widget.size,
                // Pan is small on screen and the source is 360px, so filtering
                // quality matters more than usual here.
                filterQuality: FilterQuality.medium,
                // The baked palette, NOT the live one. A missing asset must
                // fall back to a Pan the same colour as the real Pan; letting
                // this read Barako would reintroduce theme-following colour in
                // precisely the case nobody ever looks at.
                errorBuilder: (context, error, stack) => CustomPaint(
                  painter: PanCupPainter(
                    mood: _moodForEmotion(widget.emotion),
                    wisp: t,
                    palette: kPanSignaturePalette,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String _emotionWord(PanEmotion e) => switch (e) {
    PanEmotion.content => 'content',
    PanEmotion.worried => 'a little worried',
    PanEmotion.sad => 'sad',
    PanEmotion.angry => 'frustrated',
    PanEmotion.tired => 'weary',
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

  /// REQUIRED, and deliberately so. This used to default to the live Barako
  /// palette, which is a back door onto the one behaviour Pan's signature
  /// exists to prevent: a cup whose colour follows the theme. Every caller now
  /// has to name the palette it wants, so nobody can reintroduce
  /// theme-following colour by simply omitting an argument.
  ///
  /// One caution: shouldRepaint compares palettes by IDENTITY, so pass a const
  /// (as every caller does) or a cached instance, never a fresh object per
  /// build.
  final PanPalette palette;
  PanCupPainter({
    required this.mood,
    required this.wisp,
    required this.palette,
  });

  PanPalette get _colors => palette;

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
