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
    final candidates = provisionalCandidates();

    tester.view.physicalSize = Size(
      920 * 2,
      (200 + candidates.length * 148) * 2.0,
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

    final candidates = provisionalCandidates();

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

// ---------------------------------------------------------------- provisional
//
// Deliberately simple, and deliberately temporary. These exist only to prove
// the harness renders; the real geometry comes from the design pass.
List<IconCandidate> provisionalCandidates() {
  Widget flat(Color c) => ColoredBox(color: c);
  Widget glyph(String s, Color c, double size, FontWeight w) => Text(
    s,
    style: TextStyle(
      fontFamily: 'Jakarta',
      fontSize: size,
      fontWeight: w,
      color: c,
      height: 1.0,
    ),
  );

  return [
    IconCandidate(
      key: 'peso-loud',
      name: 'Peso',
      idea: 'placeholder',
      loud: true,
      ground: flat(hapon.accent),
      mark: glyph('₱', const Color(0xFFFFF3E8), 56, FontWeight.w800),
    ),
    IconCandidate(
      key: 'peso-quiet',
      name: 'Peso',
      idea: 'placeholder',
      loud: false,
      ground: flat(gabi.bg),
      mark: glyph('₱', gabi.accent, 56, FontWeight.w800),
    ),
    IconCandidate(
      key: 'letter-loud',
      name: 'Letter S',
      idea: 'placeholder',
      loud: true,
      ground: flat(hapon.accent),
      mark: glyph('S', const Color(0xFFFFF3E8), 62, FontWeight.w800),
    ),
    IconCandidate(
      key: 'letter-quiet',
      name: 'Letter S',
      idea: 'placeholder',
      loud: false,
      ground: flat(hapon.bg),
      mark: glyph('S', hapon.accent, 62, FontWeight.w800),
    ),
  ];
}
