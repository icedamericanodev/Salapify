// The tab bar fits, on the narrowest phone anybody still uses.
//
// THE DEFECT THIS EXISTS TO STOP, which shipped and was found only because an
// IA question forced somebody to measure: at 320dp "Accounts" did not fit its
// 45.1dp column in Plus Jakarta and wrapped MID-WORD, rendering "Account" over
// a lone "s", which also pushed that tab's icon out of line with the other
// three. At 1.3x system text "Ledger" broke as well.
//
// It was invisible to every existing check for one reason: the render harness
// and the founder's emulator are both 412dp, where nothing wraps. A screen
// reviewed only at the width it was designed for is not reviewed.
//
// REAL FONTS ARE NOT OPTIONAL. Flutter's default test font is wider than Plus
// Jakarta Sans, so a width measured without them answers a question about a
// font nobody sees, and would fail here for the wrong reason.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/design/kit.dart';
import 'package:salapify/design/tokens.dart';

import '../shots/screens_shot.dart' show loadRealFonts;

/// One line of the tab label at 1.0x, plus a point of slack.
const double _oneLine = 17;

Future<void> _pumpBar(WidgetTester tester, double width, double scale) async {
  tester.view.physicalSize = Size(width * 3, 640 * 3);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: salapifyTheme(hapon),
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(scale)),
        child: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: NavBar(active: 0, onTab: (_) {}, onLog: () {}),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final width in [320.0, 360.0, 412.0]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets('no tab label wraps at ${width.toInt()}dp at ${scale}x', (
        tester,
      ) async {
        await tester.runAsync(loadRealFonts);
        await _pumpBar(tester, width, scale);

        for (final (label, _) in NavBar.tabs) {
          final size = tester.getSize(find.text(label));
          expect(
            size.height,
            lessThan(_oneLine * scale),
            reason:
                '"$label" wrapped onto a second line at ${width.toInt()}dp at '
                '${scale}x, which on the shipped build rendered as the word '
                'broken in half with its icon knocked out of alignment',
          );
        }
      });
    }
  }

  testWidgets('the bar does not overflow its own width at 320dp', (
    tester,
  ) async {
    // The other half. A label that fits by SHRINKING is fine; a row that is
    // wider than the phone is a yellow-and-black stripe on the most-seen
    // widget in the app. `tester.takeException` is what catches that, because
    // a RenderFlex overflow is thrown during paint rather than returned.
    await tester.runAsync(loadRealFonts);
    await _pumpBar(tester, 320, 1.3);
    expect(tester.takeException(), isNull);
  });
}
