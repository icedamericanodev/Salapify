// The shared segmented control, and the first accessibility guideline test in
// this repo.
//
// Nothing in Salapify has ever been checked against Flutter's own
// accessibility guidelines. Starting on a 140 line widget rather than on a
// whole screen is deliberate: the guidelines report a rect and a semantics
// node, and reading that output for the first time is much easier when there
// is exactly one control on screen to blame.
//
// Two of these checks would have failed on the version of this control that
// shipped inside the Appearance screen. That is the point of extracting it.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/theme.dart';
import 'package:salapify/widgets/segmented.dart';

Widget _harness(
  String current, {
  void Function(String)? onPick,
  double textScale = 1.0,
  Size size = const Size(390, 844),
  bool reduceMotion = false,
}) => MaterialApp(
  theme: salapifyTheme(Barako.current),
  home: MediaQuery(
    data: MediaQueryData(
      size: size,
      textScaler: TextScaler.linear(textScale),
      disableAnimations: reduceMotion,
    ),
    child: Scaffold(
      // This layout is load-bearing and took two wrong versions to get right,
      // so both traps are written down.
      //
      // The horizontal padding: MinimumTapTargetGuideline SKIPS any node
      // touching the edge of the view, on the theory that it might be
      // partially scrolled offscreen, and the tolerance is 0.001. A full-bleed
      // Row of Expandeds puts its outermost segments exactly on the view edge,
      // so the whole control was exempt and this file passed with a 20 pixel
      // target. Every real screen has 20 of page padding anyway.
      //
      // The Column with mainAxisSize.min: a bare Padding hands the control
      // loose constraints the full height of the body, and it took all of
      // them. The guideline duly measured a 514 pixel tall segment and passed,
      // no matter what minHeight said. In a real screen this control sits in a
      // ListView, where it gets its natural height. A harness that lays a
      // widget out differently from the app tests a widget the app does not
      // have.
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Segmented<String>(
              current: current,
              onPick: onPick ?? (_) {},
              options: const [
                SegmentOption(value: 'owe', label: 'I owe'),
                SegmentOption(value: 'owed', label: 'Owed to me'),
              ],
            ),
          ],
        ),
      ),
    ),
  ),
);

void main() {
  group('accessibility guidelines', () {
    testWidgets('meets the Android 48dp tap target', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_harness('owe'));
      await tester.pumpAndSettle();
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      handle.dispose();
    });

    testWidgets('meets the iOS 44pt tap target', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_harness('owe'));
      await tester.pumpAndSettle();
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      handle.dispose();
    });

    testWidgets('every tappable thing has a label', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_harness('owe'));
      await tester.pumpAndSettle();
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });

    testWidgets('text contrast holds on every theme, both brightnesses', (
      tester,
    ) async {
      // The selected segment puts onPrimary on primary and the rest put
      // textSecondary on card, across sixteen palettes. Checking one is
      // checking the one that happens to be loaded.
      for (final theme in barakoThemes) {
        for (final b in [Brightness.light, Brightness.dark]) {
          Barako.currentTheme = theme;
          Barako.current = theme.resolve(b);
          final handle = tester.ensureSemantics();
          await tester.pumpWidget(_harness('owe'));
          await tester.pumpAndSettle();
          await expectLater(
            tester,
            meetsGuideline(textContrastGuideline),
            reason: '${theme.key} in ${b.name} fails contrast on this control.',
          );
          handle.dispose();
        }
      }
      Barako.currentTheme = barakoThemes.first;
      Barako.current = barakoThemes.first.light;
    });
  });

  group('behaviour', () {
    testWidgets('selection is not carried by colour alone', (tester) async {
      await tester.pumpWidget(_harness('owe'));
      await tester.pumpAndSettle();
      // Exactly one check glyph, on the selected segment. A fill and a heavier
      // font weight are both invisible to a colourblind user squinting at a
      // phone in daylight; a shape is not.
      expect(find.byIcon(Icons.check), findsOneWidget);

      await tester.pumpWidget(_harness('owed'));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.check), findsOneWidget);
      final check = tester.getCenter(find.byIcon(Icons.check));
      final owed = tester.getCenter(find.text('Owed to me'));
      expect(
        (check.dx - owed.dx).abs() < 100,
        isTrue,
        reason: 'The check moved to the newly selected segment.',
      );
    });

    testWidgets('picking reports the value, not the index', (tester) async {
      String? picked;
      await tester.pumpWidget(_harness('owe', onPick: (v) => picked = v));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Owed to me'));
      await tester.pumpAndSettle();
      expect(picked, 'owed');
    });

    testWidgets('labels wrap rather than overflow at text scale 2 on 320dp', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        _harness('owe', textScale: 2.0, size: const Size(320, 800)),
      );
      await tester.pumpAndSettle();
      expect(
        tester.takeException(),
        isNull,
        reason:
            'A RenderFlex overflow here means a label ran out of horizontal '
            'room. It is meant to get taller, not to clip.',
      );
      expect(find.text('Owed to me'), findsOneWidget);
    });

    testWidgets('reduce motion means no animation, not a shorter one', (
      tester,
    ) async {
      await tester.pumpWidget(_harness('owe', reduceMotion: true));
      await tester.pumpAndSettle();
      final box = tester.widget<AnimatedContainer>(
        find.byType(AnimatedContainer).first,
      );
      expect(box.duration, Duration.zero);
    });
  });

  // The theme-mode selector is the reason this control got hardened: "System"
  // is the longest of System / Light / Dark, and it wrapped or clipped at large
  // text. These pin it clip-free across the Flutter accessibility scales in
  // every selected state (the check glyph used to steal width from the selected
  // label so it wrapped differently from its neighbours), and prove the control
  // stacks vertically once three labels no longer fit side by side.
  group('theme mode selector at accessibility scales', () {
    const modes = ['System', 'Light', 'Dark'];

    Widget modeHarness(
      String current, {
      required double scale,
      double width = 320, // a small Android phone
    }) => MaterialApp(
      theme: salapifyTheme(Barako.current),
      home: Scaffold(
        body: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: Center(
            child: SizedBox(
              width: width,
              child: Segmented<String>(
                current: current,
                onPick: (_) {},
                options: [
                  for (final m in modes) SegmentOption(value: m, label: m),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    for (final scale in const [1.0, 1.3, 1.5, 2.0]) {
      for (final selected in modes) {
        testWidgets(
          'no overflow or clip at ${scale}x, "$selected" selected',
          (tester) async {
            await tester.pumpWidget(modeHarness(selected, scale: scale));
            await tester.pumpAndSettle();
            expect(
              tester.takeException(),
              isNull,
              reason: 'the control threw during layout at ${scale}x',
            );
            for (final m in modes) {
              final finder = find.text(m);
              expect(finder, findsOneWidget, reason: '"$m" did not render');
              final rp = tester.renderObject<RenderParagraph>(finder);
              expect(
                rp.didExceedMaxLines,
                isFalse,
                reason:
                    '"$m" is clipped at ${scale}x with "$selected" selected; '
                    'a label that runs out of room must get taller or the '
                    'control must stack, never cut the word off.',
              );
            }
            for (final ink
                in tester.widgetList<InkWell>(find.byType(InkWell))) {
              final box = tester.renderObject<RenderBox>(find.byWidget(ink));
              expect(
                box.size.height,
                greaterThanOrEqualTo(48.0),
                reason: 'a segment is under the 48px Android tap-target floor',
              );
            }
          },
        );
      }
    }

    testWidgets('horizontal at normal scale, stacked at 2.0x on a narrow phone', (
      tester,
    ) async {
      await tester.pumpWidget(modeHarness('System', scale: 1.0));
      await tester.pumpAndSettle();
      expect(
        (tester.getCenter(find.text('System')).dy -
                tester.getCenter(find.text('Dark')).dy)
            .abs(),
        lessThan(8),
        reason: 'at 1.0x the three segments should share one row',
      );

      await tester.pumpWidget(modeHarness('System', scale: 2.0));
      await tester.pumpAndSettle();
      expect(
        tester.getCenter(find.text('Dark')).dy -
            tester.getCenter(find.text('System')).dy,
        greaterThan(48),
        reason:
            'at 2.0x on a narrow phone the segments should stack vertically so '
            'each label gets the full width instead of a clipped third',
      );
    });
  });
}
