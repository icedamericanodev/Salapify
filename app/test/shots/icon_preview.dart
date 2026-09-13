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
      1012 * 2,
      (150 + candidates.length * 133) * 2.0,
    );
    await tester.pumpWidget(_Sheet(candidates: candidates));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('out/icon-sheet.png'),
    );
  });

  testWidgets('icon candidates in a Play search result', (tester) async {
    await tester.runAsync(loadRealFonts);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    final candidates = buildCandidates();

    // Both of Play's surfaces in one image. The dual-surface problem has been
    // measured since round two and never looked at, and a number in a document
    // has never once stopped a tile shipping.
    tester.view.physicalSize = Size(
      760 * 2,
      (100 + candidates.length * 80) * 2.0,
    );
    await tester.pumpWidget(_PlayStrip(candidates: candidates));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('out/icon-play.png'),
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

/// The Play Store search result, on both of Play's surfaces at once.
///
/// This exists because the dual-surface problem has been MEASURED for three
/// rounds and never LOOKED AT. "Ink is 17.68 against the white page and 1.10
/// against the dark one" is a true sentence that nobody can picture, and a
/// number in a document has never once stopped a tile shipping. Here the same
/// tile sits on both surfaces, side by side, at the size a person scrolling
/// actually sees it, with a title and a rating line beside it because an icon
/// in a search result is never alone.
///
/// Play masks the listing icon at 30 percent and adds its own drop shadow, so
/// both are drawn: [IconMask.play] and a soft shadow underneath. Without the
/// shadow a pale tile on the white page looks worse here than it does in the
/// store, which would be its own kind of lie.
class _PlayStrip extends StatelessWidget {
  const _PlayStrip({required this.candidates});
  final List<IconCandidate> candidates;

  static const _white = Color(0xFFFFFFFF);
  static const _dark = Color(0xFF202124);

  Widget _surface(String label, Color bg, Color fg, Color sub) => Expanded(
    child: Container(
      color: bg,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TypeScale.captionSm(sub)),
          const SizedBox(height: 14),
          for (final c in candidates) ...[
            Row(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(64 * 0.30),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x33000000),
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: IconTile(candidate: c, size: 64, mask: IconMask.play),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Salapify', style: TypeScale.rowTitle(fg)),
                      const SizedBox(height: 2),
                      Text(c.name, style: TypeScale.captionSm(sub)),
                      const SizedBox(height: 2),
                      Text(
                        '4.8 star  Finance',
                        style: TypeScale.captionSm(sub),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => MaterialApp(
    key: UniqueKey(),
    debugShowCheckedModeBanner: false,
    theme: salapifyTheme(hapon),
    home: Scaffold(
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _surface(
            'Play listing page, white',
            _white,
            const Color(0xFF202124),
            const Color(0xFF5F6368),
          ),
          _surface(
            'Play dark surface',
            _dark,
            const Color(0xFFE8EAED),
            const Color(0xFF9AA0A6),
          ),
        ],
      ),
    ),
  );
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
                'under the CIRCLE mask (the harshest launcher, and what is '
                'left after it crops), and with the Android safe zones drawn '
                'over it. The cyan circle is the only area guaranteed visible '
                'on every launcher.',
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
        // The HARSHEST launcher mask, and the one nothing here has ever been
        // drawn against. The safe circle overlay only says where the crop
        // WOULD fall; this shows what is actually left after it. A bleed, a
        // crop, a split or a corner device can look right in the squircle and
        // lose its whole idea here.
        Column(
          children: [
            IconTile(candidate: candidate, size: 72, mask: IconMask.circle),
            const SizedBox(height: 6),
            Text('circle', style: TypeScale.captionSm(const Color(0xFF8A7F75))),
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

/// The app's own signature hero panel, at its exact token stops.
const heroStops = [Color(0xFFFFD9B0), Color(0xFFFEC078), Color(0xFFFB9C52)];

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

// ============================================================== round three
//
// Rounds one and two were both rejected, and the founder's note on the second
// was the one both deserved: "make it related to Salapify or Pan atleast."
//
// It is correct. Every candidate so far was formally competent and had nothing
// to do with THIS app. A counterchanged disc, a cropped stroke, a bitten
// corner: all of them would suit any warm-toned product.
//
// WHAT PAN ACTUALLY IS, which nobody had written into the revamp docs. From
// flutter/lib/widgets/pan_mascot.dart: a chibi panda "who cradles his cup of
// kapeng Barako, with a peso sign rising in the steam and a coffee-cherry
// sprout on his head".
//
// That sentence explains the palette. The theme system is named BARAKO, after
// Philippine coffee. The warm orange was never arbitrary and the first two
// rounds were drawing an abstract orange that merely happened to match it.
//
// FOUNDER DECISION: icon only, Pan stays cut. The icon inherits Pan's
// OBJECT, not his face, and D2 is untouched. That also sidesteps a real trap:
// this rebuild exists because of "it looks like we copy the Tarsi", and an
// animal mascot on the icon beside a competitor named after an animal invites
// exactly that comparison. The cup is Pan without being a panda.
//
// Pan and Pan Cut are included anyway, because the founder named Pan and
// should SEE a geometric Pan rather than be told one would not work.

/// The cup Pan cradles, as a silhouette on the 108 grid.
///
/// Tapered, because a straight-sided rectangle reads as a mug or a box and the
/// taper is what makes it a cup at 48px. The handle is a separate stroked arc
/// so it can be dropped for the smallest sizes without redrawing the body.
Path barakoCup({double top = 46, double bottom = 88}) {
  final h = bottom - top;
  final path = Path()
    ..moveTo(28, top)
    ..lineTo(80, top)
    ..lineTo(74, bottom - h * 0.18)
    ..quadraticBezierTo(72, bottom, 64, bottom)
    ..lineTo(44, bottom)
    ..quadraticBezierTo(36, bottom, 34, bottom - h * 0.18)
    ..close();
  return path;
}

/// The handle, as a stroked arc. Stroke 7, above the 6 unit floor.
Path barakoHandle() =>
    Path()..addArc(const Rect.fromLTWH(72, 52, 24, 24), -1.15, 2.3);

/// The peso, scaled and placed anywhere on the grid.
///
/// The canonical drawing sits in a 38 x 44 box centred at (55, 54) and is the
/// one from round one, kept because its proportions were never the problem:
/// stem 8 over cap height 44 is 0.18, which is where Jakarta ExtraBold sits,
/// so it reads as the same weight as the wordmark.
Path pesoAt({required double cx, required double cy, required double height}) {
  final bowl = Path()
    ..moveTo(46, 32)
    ..lineTo(60, 32)
    ..arcToPoint(const Offset(60, 60), radius: const Radius.circular(14))
    ..lineTo(46, 60)
    ..close();
  var solid = Path.combine(
    PathOperation.union,
    bowl,
    Path()..addRect(const Rect.fromLTRB(46, 32, 54, 76)),
  );
  for (final r in [
    const Rect.fromLTRB(36, 35, 54, 42),
    const Rect.fromLTRB(36, 50, 54, 57),
  ]) {
    solid = Path.combine(PathOperation.union, solid, Path()..addRect(r));
  }
  solid = Path.combine(
    PathOperation.difference,
    solid,
    Path()..addOval(Rect.fromCircle(center: const Offset(60, 46), radius: 6)),
  );

  final s = height / 44.0;
  final m = Matrix4.identity()
    ..translateByDouble(cx, cy, 0, 1)
    ..scaleByDouble(s, s, 1, 1)
    ..translateByDouble(-55, -54, 0, 1);
  return solid.transform(m.storage);
}

/// 1. BARAKO. Pan's cup, bold, with two steam curls.
///
/// The purest form of the object. Coffee is not decoration here: the theme
/// system is named after it.
class BarakoCup extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const r = Rect.fromLTRB(0, 0, 108, 108);
    canvas.drawRect(r, Paint()..shader = _heroShader(r));

    final ink = Paint()..color = kInk;
    canvas.drawPath(barakoCup(), ink);
    canvas.drawPath(
      barakoHandle(),
      Paint()
        ..color = kInk
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round,
    );

    // Steam. Stroke 7, above the 6 unit floor, so it holds at 48px.
    final steam = Paint()
      ..color = kInk
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    for (final cx in [44.0, 63.0]) {
      canvas.drawPath(
        Path()
          ..moveTo(cx, 38)
          ..quadraticBezierTo(cx - 8, 29, cx, 22)
          ..quadraticBezierTo(cx + 8, 15, cx, 9),
        steam,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// 2. BARAKO PISO. The cup cropped off the bottom edge, a big peso as steam.
///
/// Composition: bleeds off the bottom, so the tile is a window rather than a
/// frame. The peso carries the meaning and the cup grounds it.
class BarakoPiso extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const r = Rect.fromLTRB(0, 0, 108, 108);
    canvas.drawRect(r, Paint()..shader = _heroShader(r));

    final ink = Paint()..color = kInk;
    // The rim, then the body running off the bottom edge.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTRB(22, 76, 86, 88),
        const Radius.circular(5),
      ),
      ink,
    );
    canvas.drawRect(const Rect.fromLTRB(30, 88, 78, 110), ink);

    canvas.drawPath(pesoAt(cx: 54, cy: 40, height: 58), ink);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// 3. BUTO. A coffee bean whose centre crease IS an S.
///
/// One shape doing two jobs: Barako, and the initial of Salapify. The crease
/// is cut through to the gradient rather than drawn, so it is a groove.
class ButoBean extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const r = Rect.fromLTRB(0, 0, 108, 108);
    canvas.saveLayer(r, Paint());
    canvas.drawRect(r, Paint()..shader = _heroShader(r));

    // The bean, rotated so it sits on a diagonal and crops at two corners.
    final bean = Path()
      ..addOval(
        Rect.fromCenter(center: const Offset(54, 54), width: 84, height: 66),
      );
    final m = Matrix4.identity()
      ..translateByDouble(54, 54, 0, 1)
      ..rotateZ(-32 * math.pi / 180)
      ..translateByDouble(-54, -54, 0, 1);
    canvas.drawPath(bean.transform(m.storage), Paint()..color = kInk);

    // The crease, cleared straight through the bean to the gradient below. An
    // S rather than the usual straight groove: the letter and the bean are the
    // same line.
    final crease = Path()
      ..moveTo(28, 66)
      ..cubicTo(48, 78, 60, 30, 80, 42);
    canvas.drawPath(
      crease.transform(m.storage),
      Paint()
        ..blendMode = BlendMode.clear
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// 4. BUNGA. The coffee cherry and two leaves from Pan's own head.
///
/// Composition: off centre and small, with a lot of empty tile. Extreme scale
/// contrast, borrowed from Flighty. The most delicate of the seven and the one
/// most likely to fail at 48px, which the render will settle.
class BungaCherry extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const r = Rect.fromLTRB(0, 0, 108, 108);
    canvas.drawRect(r, Paint()..shader = _heroShader(r));

    final ink = Paint()..color = kInk;

    // Stem, thick enough to survive: 7 units.
    canvas.drawPath(
      Path()
        ..moveTo(56, 74)
        ..quadraticBezierTo(54, 56, 58, 42),
      Paint()
        ..color = kInk
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round,
    );

    // Two leaves, as mirrored teardrops off the stem.
    for (final dir in [-1.0, 1.0]) {
      final leaf = Path()
        ..moveTo(58, 44)
        ..quadraticBezierTo(58 + dir * 26, 30, 58 + dir * 8, 20)
        ..quadraticBezierTo(58 + dir * 2, 32, 58, 44)
        ..close();
      canvas.drawPath(leaf, ink);
    }

    // The cherry itself, low and left of the stem.
    canvas.drawCircle(const Offset(46, 80), 16, ink);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// The panda head as pure geometry, used by 5 and 6.
///
/// Circles only, because Pan's shipped art is soft 3D and soft 3D becomes a
/// smudge at 48px. What makes a panda recognisable is not shading, it is two
/// dark ears on a round head and two dark eye patches.
Path pandaEars() {
  var p = Path()
    ..addOval(Rect.fromCircle(center: const Offset(31, 33), radius: 14));
  p = Path.combine(
    PathOperation.union,
    p,
    Path()..addOval(Rect.fromCircle(center: const Offset(77, 33), radius: 14)),
  );
  return p;
}

Path pandaEyes() {
  var p = Path()
    ..addOval(
      Rect.fromCenter(center: const Offset(43, 58), width: 17, height: 21),
    );
  p = Path.combine(
    PathOperation.union,
    p,
    Path()..addOval(
      Rect.fromCenter(center: const Offset(65, 58), width: 17, height: 21),
    ),
  );
  return p;
}

/// 5. PAN. The panda head, drawn as geometry rather than as rendered art.
class PandaHead extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const r = Rect.fromLTRB(0, 0, 108, 108);
    canvas.drawRect(r, Paint()..shader = _heroShader(r));

    final ink = Paint()..color = kInk;
    canvas.drawPath(pandaEars(), ink);
    canvas.drawCircle(const Offset(54, 60), 31, Paint()..color = kCream);
    canvas.drawPath(pandaEyes(), ink);
    canvas.drawCircle(const Offset(54, 72), 4.5, ink);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// 6. PAN CUT. The same head as negative space punched from a slab of ink.
class PandaCut extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const r = Rect.fromLTRB(0, 0, 108, 108);
    canvas.saveLayer(r, Paint());
    canvas.drawRect(r, Paint()..color = kInk);

    final clear = Paint()..blendMode = BlendMode.clear;
    canvas.drawCircle(const Offset(54, 60), 31, clear);
    canvas.drawPath(pandaEars(), clear);
    canvas.restore();

    // The eyes go back ON in ink, so the head reads as a face rather than as a
    // blank hole.
    canvas.drawPath(pandaEyes(), Paint()..color = kInk);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// 7. BASO. The cup astride a horizon, inverting where it crosses.
///
/// Carries forward the one MEASURED win from round two: a split tile is the
/// only kind that holds an edge on both Play surfaces, because orange is 2.10
/// against the white listing page and near black is 1.06 against the dark one,
/// and no single value wins twice.
class BasoHorizon extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const seam = 60.0;
    const upper = Rect.fromLTRB(0, 0, 108, seam);
    canvas.drawRect(upper, Paint()..shader = _heroShader(upper));
    canvas.drawRect(
      const Rect.fromLTRB(0, seam, 108, 108),
      Paint()..color = kInk,
    );

    final cup = Path.combine(
      PathOperation.union,
      barakoCup(top: 40, bottom: 92),
      Path()
        ..addPath(barakoHandle(), Offset.zero)
        ..close(),
    );

    canvas.save();
    canvas.clipPath(barakoCup(top: 40, bottom: 92));
    canvas.drawRect(
      const Rect.fromLTRB(0, 0, 108, seam),
      Paint()..color = kInk,
    );
    canvas.drawRect(
      const Rect.fromLTRB(0, seam, 108, 108),
      Paint()..color = kCream,
    );
    canvas.restore();

    // Steam above, always in ink because it lives entirely in the light half.
    final steam = Paint()
      ..color = kInk
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    for (final cx in [45.0, 63.0]) {
      canvas.drawPath(
        Path()
          ..moveTo(cx, 32)
          ..quadraticBezierTo(cx - 7, 24, cx, 18)
          ..quadraticBezierTo(cx + 7, 12, cx, 7),
        steam,
      );
    }
    // cup is unused beyond the clip; kept for clarity of intent.
    assert(cup.getBounds().width > 0);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// =============================================================== round four
//
// The founder picked one direction and gave it one note: "Buto but the S is
// too hidden." So this is a REFINEMENT round, not a new one. Buto only, plus
// two controls so the change is visible rather than asserted.
//
// WHY THE S IS HIDDEN, read off the round three render rather than guessed.
// Four causes, and they compound:
//
//   1. The crease is transformed by the SAME -32 degree matrix as the bean, so
//      the letter is tilted off its own axis. A tilted S stops being parsed as
//      a letter and becomes a squiggle. This is the biggest single cause.
//   2. It is one shallow cubic. An S needs two real bowls and hooked
//      terminals; a wave is not an S.
//   3. Stroke 9 against a bean 84 wide. Barely over the 6 unit floor, so it
//      reads as a thin slot in a large mass.
//   4. Both terminals stop inside the bean, so it reads as an enclosed slit
//      rather than a stroke that shapes the form.
//
// Contrast is NOT one of them. The groove clears through to the hero gradient,
// which is the app's own onHero pair. This is shape and weight only.

/// A proper S, as a stroked centre line, upright and centred on ([cx], [cy]).
///
/// Shared by four of the five refinements so they draw the SAME letter and the
/// comparison is about the treatment rather than about four near misses.
///
/// Coordinates are given in a normalised -1 to 1 box and scaled, so changing
/// the height or the width ratio never redraws the curve. [widthRatio] is 0.70
/// because that is roughly where Jakarta's own S sits; wider and it reads as a
/// wave again, which is cause 2 above.
///
/// The caller owns the stroke width, and it owns the safe circle with it: the
/// drawn extent is [height] plus the stroke, so height 52 at stroke 12 reaches
/// 32 units from centre and the guaranteed circle is 33.
Path sSpine({
  required double cx,
  required double cy,
  required double height,
  double widthRatio = 0.70,
}) {
  final hh = height / 2;
  final hw = height * widthRatio / 2;
  double x(double t) => cx + t * hw;
  double y(double t) => cy + t * hh;

  return Path()
    // Top right terminal, hooked back so the eye sees a letter ending rather
    // than a line stopping.
    ..moveTo(x(0.86), y(-0.60))
    ..cubicTo(x(0.70), y(-0.96), x(0.18), y(-1.00), x(-0.13), y(-1.00))
    // Down the left of the upper bowl.
    ..cubicTo(x(-0.70), y(-1.00), x(-1.00), y(-0.76), x(-1.00), y(-0.44))
    // The waist, one long diagonal through the middle. This is the segment
    // that makes an S an S.
    ..cubicTo(x(-1.00), y(-0.04), x(1.00), y(0.08), x(1.00), y(0.52))
    // Round the bottom.
    ..cubicTo(x(1.00), y(0.84), x(0.65), y(1.00), x(0.09), y(1.00))
    // Bottom left terminal, hooked to match the top.
    ..cubicTo(x(-0.22), y(1.00), x(-0.70), y(0.92), x(-0.86), y(0.60));
}

/// The bean, as an ellipse rotated onto the diagonal.
///
/// Pulled out of [ButoBean] so every refinement shares one bean and the only
/// thing that varies between rows is the treatment of the S.
Path butoBean({double width = 84, double height = 66}) {
  final bean = Path()
    ..addOval(
      Rect.fromCenter(
        center: const Offset(54, 54),
        width: width,
        height: height,
      ),
    );
  final m = Matrix4.identity()
    ..translateByDouble(54, 54, 0, 1)
    ..rotateZ(-32 * math.pi / 180)
    ..translateByDouble(-54, -54, 0, 1);
  return bean.transform(m.storage);
}

/// A stroke for the S, and it PAINTS rather than clears.
///
/// Round three cleared the crease with [BlendMode.clear], and the first render
/// of this round showed what that really does: it punches a hole through the
/// entire tile. The S then takes the colour of whatever is behind the icon, so
/// the same artwork showed a near black S on a dark home screen and a white
/// one on a light home screen. That is a fifth cause of the founder's note,
/// because the dark wallpaper case is the one that hides it.
///
/// An adaptive icon has a background layer that would catch such a hole, but
/// this artwork is one layer, so the hole is genuinely transparent and a
/// launcher shows wallpaper through it. Painting the gradient into the stroke
/// gives the same look with none of that: the tile is opaque everywhere and
/// looks identical on every wallpaper.
Paint _grooveStroke(double w, Rect r) => Paint()
  ..shader = _heroShader(r)
  ..style = PaintingStyle.stroke
  ..strokeWidth = w
  ..strokeCap = StrokeCap.round;

/// 1. BUTO TUWID. The bean stays tilted, the S stands upright.
///
/// Isolates cause 1 and nothing else, so if this alone fixes it we know why.
/// Stroke 12, which is double the floor rather than one unit over it.
class ButoTuwid extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const r = Rect.fromLTRB(0, 0, 108, 108);
    canvas.drawRect(r, Paint()..shader = _heroShader(r));
    canvas.drawPath(butoBean(), Paint()..color = kInk);
    canvas.drawPath(sSpine(cx: 54, cy: 54, height: 52), _grooveStroke(12, r));
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// 2. BUTO HIWA. The S cuts clean THROUGH the outline at both ends.
///
/// Fixes cause 4. The bean stops being one mass with a slot in it and becomes
/// two interlocking halves, which makes the gap the figure rather than the
/// background. The bean is shrunk to 72 x 56 deliberately: at that size it
/// fits inside the guaranteed circle, so the two places the cut crosses the
/// outline, the part that carries the whole idea, survive a circular launcher.
class ButoHiwa extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const r = Rect.fromLTRB(0, 0, 108, 108);
    canvas.drawRect(r, Paint()..shader = _heroShader(r));
    canvas.drawPath(butoBean(width: 72, height: 56), Paint()..color = kInk);
    // Taller than the bean on purpose, so both terminals run past its edge.
    canvas.drawPath(sSpine(cx: 54, cy: 54, height: 68), _grooveStroke(13, r));
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// 3. BUTO JAKARTA. The crease is the real letter, not a drawing of one.
///
/// Plus Jakarta Sans ExtraBold, the family the app ships and the wordmark is
/// set in, cleared straight through the bean. The strongest brand argument
/// available: the icon's S then IS the wordmark's S, and no letterform has to
/// be invented by hand.
///
/// The risk it carries is Jakarta's own thin joins at the waist, which are
/// narrower than the stems. That is what the 48px column is for.
class ButoJakarta extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const r = Rect.fromLTRB(0, 0, 108, 108);
    canvas.drawRect(r, Paint()..shader = _heroShader(r));
    canvas.drawPath(butoBean(), Paint()..color = kInk);

    // Jakarta's cap height is close to 0.72 of the em, so this size puts the
    // cap at about 53 units, the same as the drawn variants.
    const fontSize = 74.0;
    final tp = TextPainter(
      text: TextSpan(
        text: 'S',
        style: TextStyle(
          fontFamily: 'Jakarta',
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          height: 1.0,
          foreground: Paint()..shader = _heroShader(r),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    // Centre on the CAP, not on the line box: a line box carries descender
    // room the letter S never uses, so centring on it sits the S high.
    final baseline = tp.computeDistanceToActualBaseline(
      TextBaseline.alphabetic,
    );
    const capHeight = fontSize * 0.72;
    tp.paint(canvas, Offset(54 - tp.width / 2, 54 + capHeight / 2 - baseline));
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// 4. BUTO SOLID. The S sits ON the bean instead of being cut out of it.
///
/// Fixes the deepest version of the note. An absence reads as texture and a
/// presence reads as a letter, and every version so far has been an absence.
///
/// Cream on ink measures 13.30 to 1. Cream could NOT go on the gradient: cream
/// on the accent is 1.58, which is why the bean has to stay dark here.
class ButoSolid extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const r = Rect.fromLTRB(0, 0, 108, 108);
    canvas.drawRect(r, Paint()..shader = _heroShader(r));
    canvas.drawPath(butoBean(), Paint()..color = kInk);
    canvas.drawPath(
      sSpine(cx: 54, cy: 54, height: 52),
      Paint()
        ..color = kCream
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// 5. BUTO BALIGTAD. The tile turned inside out.
///
/// Ink ground, the bean in the hero gradient, the S painted back in the ink.
///
/// It TRADES the Play problem rather than solving it, and the measurements say
/// so plainly: an ink tile is 17.68 against Play's white listing page and 1.10
/// against its dark surface, while an orange tile is 1.61 and 9.99. No single
/// value wins twice, which is exactly the round two finding. Only a split tile
/// does, and no Buto variant is one.
class ButoBaligtad extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const r = Rect.fromLTRB(0, 0, 108, 108);
    canvas.drawRect(r, Paint()..color = kInk);
    canvas.drawPath(butoBean(), Paint()..shader = _heroShader(r));
    // Painted in the ground's own ink rather than cleared, for the reason on
    // _grooveStroke: a cleared S is a hole and takes the wallpaper's colour.
    canvas.drawPath(
      sSpine(cx: 54, cy: 54, height: 52),
      Paint()
        ..color = kInk
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

List<IconCandidate> buildCandidates() {
  IconCandidate c(
    String key,
    String name,
    String idea,
    Widget ground, {
    bool loud = true,
  }) => IconCandidate(
    key: key,
    name: name,
    idea: idea,
    loud: loud,
    ground: ground,
    mark: const SizedBox.shrink(),
  );

  // Round four. Buto only, plus two controls, because the founder picked a
  // direction and gave it one note. Every row after the first attacks a
  // different one of the four causes listed above, so the sheet answers WHY
  // rather than just offering five more pictures.
  return [
    c(
      'buto-r3',
      'Buto, round three',
      'CONTROL, unchanged. The one the founder said hides its S. It also has a '
          'defect nobody had seen: its crease is a HOLE through the tile, so '
          'the S takes the wallpaper\'s colour. Compare the two home screens.',
      _painted(ButoBean()),
    ),
    c(
      'buto-tuwid',
      'Buto Tuwid',
      'The bean stays tilted and the S stands UPRIGHT. Fixes the biggest '
          'cause on its own: round three rotated the letter with the bean, and '
          'a tilted S reads as a squiggle. Stroke 12, double the floor.',
      _painted(ButoTuwid()),
    ),
    c(
      'buto-hiwa',
      'Buto Hiwa',
      'FAILED, kept so the failure is on the record. The S cuts clean through '
          'the outline at both ends, and it eats the bean: what is left reads '
          'as a wave with two fangs, and at 48px as noise.',
      _painted(ButoHiwa()),
    ),
    c(
      'buto-jakarta',
      'Buto Jakarta',
      'The crease is the REAL letter: Plus Jakarta Sans ExtraBold, the family '
          'the app ships and the wordmark is set in, cut into the bean in the '
          'hero ramp. The icon\'s S is then literally the wordmark\'s S. '
          'Measured 10.96 against the ink.',
      _painted(ButoJakarta()),
    ),
    c(
      'buto-solid',
      'Buto Solid',
      'The S sits ON the bean in cream instead of being cut out of it. An '
          'absence reads as texture and a presence reads as a letter, and every '
          'version so far has been an absence. Cream on ink measures 13.30.',
      _painted(ButoSolid()),
    ),
    c(
      'buto-baligtad',
      'Buto Baligtad',
      'The tile inside out: ink ground, bean in the hero gradient, S painted '
          'back in the ink. It TRADES the Play problem rather than solving it. '
          'Ink is 17.68 on Play\'s white page and 1.10 on its dark one; orange '
          'is 1.61 and 9.99. Nothing here wins twice.',
      _painted(ButoBaligtad()),
      loud: false,
    ),
    c(
      'barako',
      'Barako',
      'CONTROL, unchanged. The runner up from round three, kept so we can see '
          'whether a fixed Buto now beats it.',
      _painted(BarakoCup()),
    ),
  ];
}
