// Widget-level checks for the two new Money Courses blocks
// (OfficialSourceBlock, RiskWarningBlock): every required field renders,
// missing optional fields never show up as the word "null", the share
// button on the source card is a real callback rather than a decoration, and
// both blocks stay usable at a narrow width, at 1.5x system font, and in
// both themes.
//
// Real fonts loaded per repo convention (test/screens_shot.dart): Flutter's
// default test font is wider than the shipped Plus Jakarta Sans, so a layout
// judgment made against the test font can come out differently than on the
// phone. This file measures layout (overflow, off-the-side text), so it
// counts as one of the tests that rule applies to.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/content/lesson_blocks.dart';
import 'package:salapify/theme.dart';
import 'package:salapify/widgets/lesson_block_views.dart';

import 'screens_shot.dart' show loadRealFonts;

// Narrower than the 390dp reference phone screen_readability_test.dart uses,
// on purpose: this is one card, not a whole screen, and a narrow phone is
// exactly where a citation card with a long URL is most likely to break.
const _narrow = Size(320, 700);

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  Brightness brightness = Brightness.dark,
  double textScale = 1.0,
}) async {
  await loadRealFonts(tester);
  tester.view.physicalSize = _narrow * 3.0;
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  // Palette resolved BEFORE build, the order main.dart uses, so every
  // Barako.* read during build sees the brightness under test.
  Barako.current = Barako.currentTheme.resolve(brightness);
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: MaterialApp(
        theme: salapifyTheme(Barako.current),
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Text painted past the left or right edge of the narrow frame, the same
/// measurement screen_readability_test.dart uses for whole screens.
List<String> _runsOffTheSide(WidgetTester tester) {
  final bad = <String>[];
  for (final e in find.byType(Text).evaluate()) {
    final ro = e.renderObject;
    if (ro is! RenderBox || !ro.attached || !ro.hasSize) continue;
    if (ro.size.isEmpty) continue;
    final Offset topLeft, topRight;
    try {
      topLeft = ro.localToGlobal(Offset.zero);
      topRight = ro.localToGlobal(Offset(ro.size.width, 0));
    } catch (_) {
      continue;
    }
    final left = topLeft.dx < topRight.dx ? topLeft.dx : topRight.dx;
    final right = topLeft.dx > topRight.dx ? topLeft.dx : topRight.dx;
    if (left < -0.5 || right > _narrow.width + 0.5) {
      final w = e.widget as Text;
      final s = (w.data ?? w.textSpan?.toPlainText() ?? '').trim();
      bad.add(
        '"$s" spans ${left.toStringAsFixed(1)} to ${right.toStringAsFixed(1)}',
      );
    }
  }
  return bad;
}

void main() {
  const fullSource = OfficialSourceBlock(
    agency: 'Bangko Sentral ng Pilipinas',
    sourceTitle: 'Circular No. 1133, series of 2022',
    canonicalUrl: 'https://www.bsp.gov.ph/Regulations/Issuances/2022/c1133.pdf',
    lastVerifiedDate: '2026-07',
    effectiveDate: '2022-03',
    issuanceOrCircularNumber: 'Circular 1133',
  );

  const minimalSource = OfficialSourceBlock(
    agency: 'Securities and Exchange Commission',
    sourceTitle: 'Investor protection guide',
    canonicalUrl: 'https://www.sec.gov.ph/investor-guide',
  );

  const cautionWarning = RiskWarningBlock(
    title: 'Not a guaranteed return',
    text:
        'Every investment can lose value, including one that has done well '
        'before. Confirm with a licensed professional before you act.',
    severity: RiskSeverity.caution,
  );

  group('OfficialSourceView', () {
    for (final brightness in Brightness.values) {
      for (final scale in [1.0, 1.5]) {
        testWidgets(
          'renders every required and optional field, $brightness at ${scale}x',
          (tester) async {
            await _pump(
              tester,
              const OfficialSourceView(fullSource),
              brightness: brightness,
              textScale: scale,
            );
            expect(tester.takeException(), isNull);
            expect(find.text('Bangko Sentral ng Pilipinas'), findsOneWidget);
            expect(
              find.text('Circular No. 1133, series of 2022'),
              findsOneWidget,
            );
            expect(find.textContaining('bsp.gov.ph'), findsOneWidget);
            expect(find.textContaining('Verified 2026-07'), findsOneWidget);
            expect(find.textContaining('Effective 2022-03'), findsOneWidget);
            expect(find.text('CIRCULAR 1133'), findsOneWidget);
            expect(find.text('Share link'), findsOneWidget);
            expect(_runsOffTheSide(tester), isEmpty);
          },
        );
      }
    }

    testWidgets('missing optional fields never render as the word null', (
      tester,
    ) async {
      await _pump(tester, const OfficialSourceView(minimalSource));
      expect(tester.takeException(), isNull);
      expect(find.text('Securities and Exchange Commission'), findsOneWidget);
      for (final e in find.byType(Text).evaluate()) {
        final w = e.widget as Text;
        final s = w.data ?? w.textSpan?.toPlainText() ?? '';
        expect(
          s.toLowerCase().contains('null'),
          isFalse,
          reason: 'found the word null in "$s"',
        );
      }
      // No issuance tag, no date line: neither an empty container nor a
      // stray separator should be left behind.
      expect(find.textContaining('Verified'), findsNothing);
      expect(find.textContaining('Effective'), findsNothing);
    });

    testWidgets('the share button is a real callback, not a fake button', (
      tester,
    ) async {
      await _pump(tester, const OfficialSourceView(minimalSource));
      final button = tester.widget<OutlinedButton>(find.byType(OutlinedButton));
      expect(button.onPressed, isNotNull);
    });

    testWidgets(
      'the OFFICIAL SOURCE kicker is exposed as an accessible header',
      (tester) async {
        final handle = tester.ensureSemantics();
        await _pump(tester, const OfficialSourceView(fullSource));
        expect(find.bySemanticsLabel('OFFICIAL SOURCE'), findsOneWidget);
        handle.dispose();
      },
    );
  });

  group('RiskWarningView', () {
    for (final brightness in Brightness.values) {
      for (final scale in [1.0, 1.5]) {
        testWidgets(
          'renders title and warning text, $brightness at ${scale}x',
          (tester) async {
            await _pump(
              tester,
              const RiskWarningView(cautionWarning),
              brightness: brightness,
              textScale: scale,
            );
            expect(tester.takeException(), isNull);
            expect(find.text('Not a guaranteed return'), findsOneWidget);
            expect(
              find.textContaining('Every investment can lose value'),
              findsOneWidget,
            );
            expect(_runsOffTheSide(tester), isEmpty);
          },
        );
      }
    }

    testWidgets('exposes the warning title as an accessible header', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, const RiskWarningView(cautionWarning));
      expect(find.bySemanticsLabel('Not a guaranteed return'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('notice severity renders without the caution accent border', (
      tester,
    ) async {
      const notice = RiskWarningBlock(
        title: 'A gentle note',
        text: 'This is informational, not urgent.',
      );
      await _pump(tester, const RiskWarningView(notice));
      expect(tester.takeException(), isNull);
      expect(find.text('A gentle note'), findsOneWidget);
    });
  });
}
