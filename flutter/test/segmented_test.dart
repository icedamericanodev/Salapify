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
}
