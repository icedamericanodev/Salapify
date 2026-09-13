// App icon candidates, drawn in the real palette and rendered the way an icon
// is actually seen.
//
// Run:  flutter test test/shots/icon_preview.dart --update-goldens
// Out:  test/shots/out/icon-*.png   (gitignored; the reviewed ones are copied
//                                    into docs/revamp/mockups/hapon/icon/)
//
// NOT named *_test.dart, so `flutter test` never collects it. Same rule as
// screens_shot.dart and for the same reason.
//
// WHY THIS IS FLUTTER AND NOT AN IMAGE EDITOR. The candidates read their
// colours from app/lib/design/tokens.dart, the same file the app ships, so the
// icon that gets approved is drawn from the same hex values as the screens it
// will sit on. A mockup made anywhere else can drift from the code by one
// digit and nobody would ever catch it.
//
// A 512px picture of an icon tells you almost nothing about the decision, so
// every candidate is also rendered at 48px (the app drawer, where fine detail
// dies), inside the Android adaptive-icon safe circle, and in a home screen
// grid beside the apps it will actually compete with.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/design/tokens.dart';
import 'package:salapify/design/type.dart';

import 'screens_shot.dart' show loadRealFonts;

// ---------------------------------------------------------------- geometry
//
// Android adaptive icons, and these three numbers are the whole constraint.
// The art is 108dp square. Launchers only ever show the middle 72dp. Only the
// middle 66dp CIRCLE is guaranteed visible on every launcher shape, because a
// circular mask, a squircle and a teardrop all crop differently.
//
// So a mark that fills the tile gets its corners eaten on some phones, and the
// only safe place for anything that must be seen is that inner circle.
const double kCanvas = 108;
const double kVisible = 72;
const double kSafe = 66;

/// One candidate: a ground and a mark, both drawn on the 108 unit grid.
class IconCandidate {
  const IconCandidate({
    required this.key,
    required this.name,
    required this.idea,
    required this.loud,
    required this.ground,
    required this.mark,
  });

  final String key;
  final String name;

  /// One sentence, so the review sheet explains itself.
  final String idea;

  /// Loud means the ground is the accent and the mark is cut out of it. Quiet
  /// means a cream or warm-black ground carrying an orange mark.
  final bool loud;

  final Widget ground;

  /// Drawn on a [kCanvas] square. Must sit inside the [kSafe] circle.
  final Widget mark;
}

/// The masks this artwork actually meets in the wild.
///
/// Verified against Google's own current spec rather than remembered:
/// developer.android.com/google-play/resources/icon-design-specifications says
/// the Play listing icon is 512 square, 32 bit PNG, sRGB, under 1024KB,
/// submitted as a FULL SQUARE with no corners rounded and no shadow added,
/// because "radius will be equivalent to 30% of icon size" and "Google Play
/// will dynamically add a drop shadow around the final icon once uploaded".
///
/// A launcher is a different and harsher story: the same art gets masked to
/// whatever shape the phone's launcher uses, and circle is the worst case.
enum IconMask {
  /// A typical launcher squircle.
  squircle(0.225, 'launcher'),

  /// The harshest launcher mask, and the one that eats corners.
  circle(0.5, 'circle'),

  /// What the Play listing does to it.
  play(0.30, 'Play 30%');

  const IconMask(this.radiusFactor, this.label);
  final double radiusFactor;
  final String label;
}

/// Renders one candidate at [size] under a given [mask], so it is judged as a
/// tile rather than as a square picture.
class IconTile extends StatelessWidget {
  const IconTile({
    super.key,
    required this.candidate,
    required this.size,
    this.mask = IconMask.squircle,
  });

  final IconCandidate candidate;
  final double size;
  final IconMask mask;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * mask.radiusFactor),
      child: SizedBox(
        width: size,
        height: size,
        child: FittedBox(
          fit: BoxFit.fill,
          child: SizedBox(
            width: kCanvas,
            height: kCanvas,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(child: candidate.ground),
                candidate.mark,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The same tile with the adaptive-icon zones drawn over it, so a mark that
/// strays outside the guaranteed-safe circle is visible as a fault here rather
/// than as a surprise on somebody's phone.
class SafetyOverlay extends StatelessWidget {
  const SafetyOverlay({super.key, required this.candidate, this.size = 160});
  final IconCandidate candidate;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          IconTile(candidate: candidate, size: size),
          CustomPaint(size: Size(size, size), painter: _ZonesPainter()),
        ],
      ),
    );
  }
}

class _ZonesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final scale = size.width / kCanvas;

    final visible = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0x66FFFFFF);
    final safe = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = const Color(0xCC00E5FF);

    canvas.drawRect(
      Rect.fromCenter(
        center: c,
        width: kVisible * scale,
        height: kVisible * scale,
      ),
      visible,
    );
    canvas.drawCircle(c, kSafe * scale / 2, safe);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ---------------------------------------------------------------- neighbours
//
// Stand-ins for the apps a Filipino home screen actually carries, so "does it
// stand out" can be answered by looking rather than guessed. Deliberately
// PLAIN coloured tiles with one letter: these are colour placeholders for a
// private design review, not reproductions of anyone's logo.
class NeighbourTile extends StatelessWidget {
  const NeighbourTile({
    super.key,
    required this.letter,
    required this.bg,
    required this.fg,
    required this.size,
  });

  final String letter;
  final Color bg;
  final Color fg;
  final double size;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(size * 0.225),
    child: Container(
      width: size,
      height: size,
      color: bg,
      alignment: Alignment.center,
      child: Text(
        letter,
        style: TextStyle(
          fontFamily: 'Jakarta',
          fontSize: size * 0.44,
          fontWeight: FontWeight.w800,
          color: fg,
        ),
      ),
    ),
  );
}

/// The colours those apps are known by, as flat tiles.
const neighbours = <(String, Color, Color)>[
  ('G', Color(0xFF0057FF), Color(0xFFFFFFFF)), // a blue e-wallet
  ('M', Color(0xFF00C86F), Color(0xFF04331F)), // a green e-wallet
  ('B', Color(0xFFB01F24), Color(0xFFFFFFFF)), // a red bank
  ('D', Color(0xFF002B5C), Color(0xFFFFFFFF)), // a navy bank
  ('S', Color(0xFF111318), Color(0xFFE6E8EC)), // a dark utility app
  ('W', Color(0xFFF2F3F5), Color(0xFF20242B)), // a light utility app
];

void main() {
  testWidgets('icon candidates', (tester) async {
    await tester.runAsync(loadRealFonts);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    // Placeholder set. Replaced with the expert geometry before this is shown
    // to anyone: the harness is being proven to render first, so that when the
    // real marks arrive the only thing left to get right is the marks.
    final candidates = buildCandidates();

    tester.view.physicalSize = Size(
      920 * 2,
      (150 + candidates.length * 133) * 2.0,
    );
    await tester.pumpWidget(_Sheet(candidates: candidates));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('out/icon-sheet.png'),
    );
  });

  testWidgets('icon candidates on a home screen', (tester) async {
    await tester.runAsync(loadRealFonts);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    final candidates = buildCandidates();

    // "Does it stand out" is unanswerable for an icon on its own and obvious
    // in a grid. Both wallpapers, because a light home screen and a dark one
    // flatter completely different tiles, and the founder cannot change which
    // one a stranger in the Play Store has.
    for (final dark in [true, false]) {
      tester.view.physicalSize = Size(
        460 * 2,
        (150 + ((candidates.length + neighbours.length) / 4).ceil() * 108) *
            2.0,
      );
      await tester.pumpWidget(_HomeScreen(candidates: candidates, dark: dark));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('out/icon-home-${dark ? "dark" : "light"}.png'),
      );
    }
  });
}

/// The candidates dropped into a grid beside the apps they compete with.
class _HomeScreen extends StatelessWidget {
  const _HomeScreen({required this.candidates, required this.dark});
  final List<IconCandidate> candidates;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    const tile = 62.0;
    final ink = dark ? const Color(0xFFE8E4E0) : const Color(0xFF1A1A1A);

    Widget labelled(Widget icon, String label) => SizedBox(
      width: 92,
      child: Column(
        children: [
          icon,
          const SizedBox(height: 7),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Jakarta',
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: ink,
            ),
          ),
        ],
      ),
    );

    return MaterialApp(
      key: UniqueKey(),
      debugShowCheckedModeBanner: false,
      theme: salapifyTheme(dark ? gabi : hapon),
      home: Scaffold(
        // A plain wallpaper rather than a photo: a busy photo would flatter or
        // punish tiles at random, and the question here is about the tiles.
        backgroundColor: dark
            ? const Color(0xFF171A1F)
            : const Color(0xFFDCDFE6),
        body: Padding(
          padding: const EdgeInsets.fromLTRB(20, 26, 20, 26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                dark ? 'Dark home screen' : 'Light home screen',
                style: TextStyle(
                  fontFamily: 'Jakarta',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: ink.withValues(alpha: 0.75),
                ),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 8,
                runSpacing: 16,
                children: [
                  for (final c in candidates)
                    labelled(
                      IconTile(candidate: c, size: tile),
                      '${c.name} ${c.loud ? "loud" : "quiet"}',
                    ),
                  for (final (letter, bg, fg) in neighbours)
                    labelled(
                      NeighbourTile(letter: letter, bg: bg, fg: fg, size: tile),
                      '',
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Sheet extends StatelessWidget {
  const _Sheet({required this.candidates});
  final List<IconCandidate> candidates;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      key: UniqueKey(),
      debugShowCheckedModeBanner: false,
      theme: salapifyTheme(gabi),
      home: Scaffold(
        backgroundColor: const Color(0xFF0B0A09),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Salapify app icon, candidates',
                style: TypeScale.screenTitle(const Color(0xFFF6EFE8)),
              ),
              const SizedBox(height: 6),
              Text(
                'Each row: the tile at review size, at 48px (the app drawer), '
                'and with the Android safe zones drawn over it. The cyan '
                'circle is the only area guaranteed visible on every launcher.',
                style: TypeScale.hint(const Color(0xFFAC9E92)),
              ),
              const SizedBox(height: 24),
              for (final c in candidates) ...[
                _Row(candidate: c),
                const SizedBox(height: 18),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.candidate});
  final IconCandidate candidate;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        IconTile(candidate: candidate, size: 112),
        const SizedBox(width: 20),
        // The size that actually decides whether a mark survives.
        Column(
          children: [
            IconTile(candidate: candidate, size: 48),
            const SizedBox(height: 6),
            Text('48px', style: TypeScale.captionSm(const Color(0xFF8A7F75))),
          ],
        ),
        const SizedBox(width: 20),
        SafetyOverlay(candidate: candidate, size: 112),
        const SizedBox(width: 24),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${candidate.name}  ${candidate.loud ? "loud" : "quiet"}',
                style: TypeScale.sectionHead(const Color(0xFFF6EFE8)),
              ),
              const SizedBox(height: 4),
              Text(
                candidate.idea,
                style: TypeScale.hint(const Color(0xFFAC9E92)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ================================================================ round two
//
// The founder rejected round one entirely: "i dont like anything, you can get
// inspiration from dribbble or other resources do not limit yourself and
// explore."
//
// The exploration that followed looked at eleven real references and came back
// with a device for each, because the fault in round one was compositional and
// not chromatic. Every one of those six was a flat symbol centred on a plain
// tile. It also caught a fourth fault nobody had named: the marks were SMALL,
// around 45 percent of tile width with dead gradient all round them. Good
// icons either fill the tile or deliberately crop it.
//
// THREE MEASURED FINDINGS THAT CHANGED THE BRIEF.
//
// 1. A one-value tile cannot hold an edge on both Play surfaces, and a SPLIT
//    tile can. #FB9C52 is 2.10 against Play's white listing page and 8.90
//    against its dark surface; #2A1207 is 17.68 and 1.06. Neither wins twice.
//    A tile carrying both keeps an edge either way, because whichever surface
//    eats one half, the other half still cuts. Round one never tested this and
//    treated loud versus quiet as a matter of taste.
//
// 2. Two hero-ramp tones cannot be told apart. #FFD9B0 against #FB9C52
//    measures 1.58, under the 3.0 non-text bar. (The exploration said 1.87;
//    re-measuring here gives 1.58, which makes its own point harder, not
//    softer.) So a layering direction needs a deliberately chosen dark tone at
//    the overlap, never a blend mode.
//
// 3. THE 48px FLOOR, once, as a number. 108 units render to 48px at 0.667px
//    per unit, so nothing thinner than 6 units and no gap narrower than 6
//    units. Round one's peso had 7-unit bars with an 8-unit gap, which is
//    exactly why its own write-up admitted they softened.
//
// Two colours below are NOT tokens and must never enter tokens.dart:
// #FFF3E6 (Capiz only, the hero ramp continued one step so the light has a
// peak) and #8A2F07 (Dalawa only, the only tone that clears 3.0 against both
// planes at once, at 6.35 and 4.01).

/// The app's own signature hero panel, at its exact token stops.
const heroStops = [Color(0xFFFFD9B0), Color(0xFFFEC078), Color(0xFFFB9C52)];

Widget flatGround(Color c) => ColoredBox(color: c);

/// A ground with the mark punched OUT of it, so the mark is the hole and
/// whatever sits behind shows through.
///
/// Round one could not express this, and it is part of why all six looked like
/// siblings: every mark was a flat shape sitting ON a tile, because that was
/// the only thing this file could draw.
///
/// It needs its own painter rather than a sibling in the Stack, because a
/// widget can only erase pixels sharing its layer, so ground and hole have to
/// be painted together inside one saveLayer.
class CutoutGround extends StatelessWidget {
  const CutoutGround({
    super.key,
    required this.path,
    this.colour,
    this.gradient,
  }) : assert(
         colour != null || gradient != null,
         'A cutout ground needs something to cut out of.',
       );

  final Path path;
  final Color? colour;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _CutoutPainter(path, colour, gradient));
}

class _CutoutPainter extends CustomPainter {
  const _CutoutPainter(this.path, this.colour, this.gradient);
  final Path path;
  final Color? colour;
  final Gradient? gradient;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.saveLayer(rect, Paint());
    final ground = Paint();
    if (gradient != null) {
      ground.shader = gradient!.createShader(rect);
    } else {
      ground.color = colour!;
    }
    canvas.drawRect(rect, ground);
    canvas.drawPath(path, Paint()..blendMode = BlendMode.clear);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CutoutPainter old) => false;
}

/// The hero ramp as a shader across an arbitrary rect on the 108 grid.
Shader _heroShader(Rect r, {Alignment begin = Alignment.topLeft}) =>
    LinearGradient(
      begin: begin,
      end: Alignment.bottomRight,
      colors: heroStops,
      stops: const [0.0, 0.5, 1.0],
    ).createShader(r);

const Color kInk = Color(0xFF2A1207); // onHero
const Color kCream = Color(0xFFFFD9B0); // hero stop 0
const Color kPeak = Color(0xFFFFF3E6); // Capiz only, not a token
const Color kOverlap = Color(0xFF8A2F07); // Dalawa only, not a token

/// 1. HAPON, the counterchanged horizon.
///
/// One disc astride a horizon line, swapping from dark to light where it
/// crosses, so the same object is two things at once.
///
/// Device: the split-flap seam from Basic Apple Guy's Boardy, crossed with
/// heraldic counterchange. It says "two directions" without drawing a single
/// arrow, which is what the Beam failed to do, and the tile is split so it
/// keeps an edge on both Play surfaces.
class HaponHorizon extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const seam = 62.0;
    final upper = const Rect.fromLTRB(0, 0, 108, seam);

    canvas.drawRect(upper, Paint()..shader = _heroShader(upper));
    canvas.drawRect(
      const Rect.fromLTRB(0, seam, 108, 108),
      Paint()..color = kInk,
    );

    final disc = Path()
      ..addOval(Rect.fromCircle(center: const Offset(54, 58), radius: 28));

    canvas.save();
    canvas.clipPath(disc);
    // Above the seam the disc is ink; below it the disc is cream. Same object,
    // inverted across the line.
    canvas.drawRect(
      const Rect.fromLTRB(0, 0, 108, seam),
      Paint()..color = kInk,
    );
    canvas.drawRect(
      const Rect.fromLTRB(0, seam, 108, 108),
      Paint()..color = kCream,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// 2. CAPIZ, the window.
///
/// Not a symbol: a close crop of a capiz shell window with late afternoon
/// light coming through, brightest at the upper left.
///
/// Device: a repeating pattern cropped by the tile so it continues past the
/// edges, with an off-centre light source. Filipino by substance rather than
/// costume, which is the opposite of a flag or a jeepney.
class CapizWindow extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(const Rect.fromLTRB(0, 0, 108, 108), Paint()..color = kInk);

    // Panes bleed off every edge on purpose: the window continues past the
    // tile rather than being contained by it.
    const origins = [-21.0, 10.0, 41.0, 72.0, 103.0];
    final panes = Path();
    for (final x in origins) {
      for (final y in origins) {
        panes.addRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x, y, 24, 24),
            const Radius.circular(3),
          ),
        );
      }
    }

    // ONE shader across all of them, not per-pane fills. That is what makes it
    // read as light falling across a window rather than as a grid of tiles.
    final light = RadialGradient(
      center: const Alignment(-0.296, -0.259), // (38, 40) on the 108 grid
      radius: 78 / 108,
      colors: const [kPeak, kCream, Color(0xFFFEC078), Color(0xFFFB9C52)],
      stops: const [0.0, 0.35, 0.65, 1.0],
    ).createShader(const Rect.fromLTRB(0, 0, 108, 108));

    canvas.drawPath(panes, Paint()..shader = light);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// The peso as a hole, used by direction 3.
Path counterweightPeso() {
  final stem = Path()
    ..addRRect(
      RRect.fromRectAndCorners(
        const Rect.fromLTRB(32, 26, 44, 82),
        bottomLeft: const Radius.circular(4),
        bottomRight: const Radius.circular(4),
      ),
    );
  var ring = Path.combine(
    PathOperation.difference,
    Path()..addOval(Rect.fromCircle(center: const Offset(58, 44), radius: 20)),
    Path()..addOval(Rect.fromCircle(center: const Offset(58, 44), radius: 9)),
  );
  ring = Path.combine(
    PathOperation.intersect,
    ring,
    Path()..addRect(const Rect.fromLTRB(38, 0, 108, 108)),
  );

  var out = Path.combine(PathOperation.union, stem, ring);
  for (final r in [
    const Rect.fromLTRB(26, 38, 50, 46),
    const Rect.fromLTRB(26, 52, 50, 60),
  ]) {
    out = Path.combine(
      PathOperation.union,
      out,
      Path()..addRRect(RRect.fromRectAndRadius(r, const Radius.circular(2))),
    );
  }
  return out;
}

/// 4. OVERSHOOT, one stroke, cropped.
///
/// A single stroke drawn bigger than the tile, entering one edge and leaving
/// another. Nothing centred, nothing complete.
///
/// Device: scale and crop, so the tile is a window onto something larger.
/// Openly Nike Run Club's move. The most robust of the eight at any size and
/// the least specific about money.
class Overshoot extends CustomPainter {
  const Overshoot({this.bead = true});

  /// A 10 unit disc against a 22 unit stroke: extreme scale contrast. It sits
  /// ON the stroke, never on the gradient, because cream on #FB9C52 measures
  /// 1.58 and fails.
  final bool bead;

  @override
  void paint(Canvas canvas, Size size) {
    const r = Rect.fromLTRB(0, 0, 108, 108);
    canvas.drawRect(r, Paint()..shader = _heroShader(r));

    final stroke = Path()
      ..moveTo(-14, 30)
      ..cubicTo(36, 96, 72, 4, 122, 74);
    canvas.drawPath(
      stroke,
      Paint()
        ..color = kInk
        ..style = PaintingStyle.stroke
        ..strokeWidth = 22
        ..strokeCap = StrokeCap.butt,
    );

    if (bead) {
      canvas.drawCircle(const Offset(40, 62), 5, Paint()..color = kCream);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// 5. DALAWA, two planes.
///
/// Two overlapping cards, one for what you owe and one for what you are owed,
/// legible only where they cross.
///
/// Device: two identical shapes overlapping with the overlap as a third
/// colour. Mastercard's move. Structurally honest about the product: take away
/// the overlap and the mark stops working, which is also true of the feature.
class DalawaPlanes extends CustomPainter {
  Path _plane(Rect r, double degrees, Offset about) {
    final p = Path()
      ..addRRect(RRect.fromRectAndRadius(r, const Radius.circular(13)));
    final m = Matrix4.identity()
      ..translateByDouble(about.dx, about.dy, 0, 1)
      ..rotateZ(degrees * math.pi / 180)
      ..translateByDouble(-about.dx, -about.dy, 0, 1);
    return p.transform(m.storage);
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(const Rect.fromLTRB(0, 0, 108, 108), Paint()..color = kInk);

    final a = _plane(
      const Rect.fromLTRB(20, 28, 66, 80),
      -8,
      const Offset(43, 54),
    );
    final b = _plane(
      const Rect.fromLTRB(42, 28, 88, 80),
      8,
      const Offset(65, 54),
    );

    canvas.drawPath(a, Paint()..color = kCream);
    canvas.drawPath(b, Paint()..color = const Color(0xFFFB9C52));
    // The two planes are 1.58 apart and cannot be told from each other. It is
    // this seam that makes the mark readable, which is why a blend mode will
    // not do: a true multiply lands at 1.18 from plane B.
    canvas.drawPath(
      Path.combine(PathOperation.intersect, a, b),
      Paint()..color = kOverlap,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// 6. SOBRE, the bitten corner.
///
/// The tile itself is the mark: a large diagonal bite out of one corner, and
/// one small disc low and left.
///
/// Device: the tile shape as the mark with no glyph at all. Monzo's move, and
/// that is this direction's biggest problem. The bite is deliberately DEEP:
/// a shallower corner cut sits entirely outside the safe circle and vanishes
/// on round launchers.
class SobreCorner extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const r = Rect.fromLTRB(0, 0, 108, 108);
    canvas.drawRect(r, Paint()..shader = _heroShader(r));

    final bite = Path()
      ..moveTo(30, 0)
      ..lineTo(108, 0)
      ..lineTo(108, 78)
      ..close();
    canvas.drawPath(bite, Paint()..color = kInk);
    canvas.drawCircle(const Offset(36, 70), 13, Paint()..color = kInk);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// 7. PISO BUO, the peso at three times scale.
///
/// The rejected subject done with no timidity: the bowl fills the safe circle,
/// the stem runs the full height with no visible ends, both crossbars run off
/// each side. You do not see a peso on a tile, you see a fragment of a huge
/// one.
///
/// Device: blow one glyph up until it stops being a letter, then crop hard.
/// Kept in the set on purpose. It isolates the question of whether the SUBJECT
/// was the problem or the TIMIDITY was, and only the founder can answer that.
class PisoBuo extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const r = Rect.fromLTRB(0, 0, 108, 108);
    canvas.drawRect(r, Paint()..shader = _heroShader(r));

    final ink = Paint()..color = kInk;
    canvas.drawRect(const Rect.fromLTRB(26, -2, 42, 110), ink);

    var ring = Path.combine(
      PathOperation.difference,
      Path()
        ..addOval(Rect.fromCircle(center: const Offset(56, 34), radius: 28)),
      Path()
        ..addOval(Rect.fromCircle(center: const Offset(56, 34), radius: 16)),
    );
    ring = Path.combine(
      PathOperation.intersect,
      ring,
      Path()..addRect(const Rect.fromLTRB(34, -10, 118, 118)),
    );
    canvas.drawPath(ring, ink);

    canvas.drawRect(const Rect.fromLTRB(-2, 62, 110, 72), ink);
    canvas.drawRect(const Rect.fromLTRB(-2, 80, 110, 90), ink);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// 8. RESIBO, the total line.
///
/// A receipt: three thin rules and one thick slab, all edge to edge, with one
/// pale bar inside the slab that is the number that matters.
///
/// Device: extreme thickness contrast and full-bleed banding. The safest and
/// least ownable of the eight, and the exploration said so up front: three
/// horizontal lines at thumbnail size can read as a hamburger menu.
class ResiboTotal extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const r = Rect.fromLTRB(0, 0, 108, 108);
    canvas.drawRect(
      r,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: heroStops,
        ).createShader(r),
    );

    final ink = Paint()..color = kInk;
    for (final b in [
      const Rect.fromLTRB(-2, 16, 110, 23),
      const Rect.fromLTRB(-2, 30, 110, 37),
      const Rect.fromLTRB(-2, 44, 110, 51),
      const Rect.fromLTRB(-2, 62, 110, 90), // the total slab
    ]) {
      canvas.drawRect(b, ink);
    }

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTRB(30, 72, 78, 80),
        const Radius.circular(4),
      ),
      Paint()..color = kCream,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

Widget _painted(CustomPainter p) => CustomPaint(painter: p);

List<IconCandidate> buildCandidates() {
  IconCandidate c(String key, String name, String idea, Widget ground) =>
      IconCandidate(
        key: key,
        name: name,
        idea: idea,
        loud: true,
        ground: ground,
        mark: const SizedBox.shrink(),
      );

  return [
    c(
      'hapon',
      'Hapon',
      'A disc astride a horizon, inverting where it crosses. Says two '
          'directions without an arrow. The only one whose TILE holds an edge '
          'on both Play surfaces. Ink 8.40:1, cream 13.30:1.',
      _painted(HaponHorizon()),
    ),
    c(
      'overshoot',
      'Overshoot',
      'One stroke drawn bigger than the tile, entering one edge and leaving '
          'another. Unbreakable at any size and says nothing about money.',
      _painted(const Overshoot()),
    ),
    c(
      'capiz',
      'Capiz',
      'A cropped capiz shell window with late afternoon light through it. '
          'Filipino by substance, not costume. Risk: a 3x3 grid can read as '
          '"apps" at thumbnail size.',
      _painted(CapizWindow()),
    ),
    c(
      'dalawa',
      'Dalawa',
      'Two overlapping planes, legible only where they cross. The two planes '
          'are 1.58 apart and are told apart ONLY by the dark seam.',
      _painted(DalawaPlanes()),
    ),
    c(
      'piso-buo',
      'Piso Buo',
      'The rejected subject with no timidity: bowl filling the safe circle, '
          'stem and bars running clean off the edges. Isolates whether the '
          'subject was the problem or the smallness was.',
      _painted(PisoBuo()),
    ),
    c(
      'sobre',
      'Sobre',
      'The tile IS the mark: a deep diagonal bite and one disc. Monzo\'s '
          'device, which is its biggest problem.',
      _painted(SobreCorner()),
    ),
    c(
      'resibo',
      'Resibo',
      'A receipt: three thin rules and one thick total slab, edge to edge. '
          'The safest and the least ownable.',
      _painted(ResiboTotal()),
    ),
    c(
      'counterweight',
      'Counterweight',
      'The peso as the HOLE, cut from a slab of ink. Weakest at 48px by its '
          'own designer\'s admission, and 1.06 against Play\'s dark surface.',
      Stack(
        children: [
          // The gradient sits BEHIND and the ink slab is punched through, so
          // the peso is the light coming through rather than a shape drawn on
          // top.
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: heroStops,
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: CutoutGround(path: counterweightPeso(), colour: kInk),
          ),
        ],
      ),
    ),
  ];
}
