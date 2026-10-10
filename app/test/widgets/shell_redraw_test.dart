import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/design/app_theme.dart';
import 'package:salapify/design/tokens.dart';
import 'package:salapify/shell/app_shell.dart';
import 'package:salapify/state/financial_state.dart';

import '../shots/screens_shot.dart' show loadRealFonts;

/// The shell redraws when the store changes.
///
/// This is here because it was NOT true, for the whole life of the render
/// harness, and nothing could see it. `main.dart` calls setState on every
/// notification, so the app on the phone was always correct; the harness and
/// every journey test pump `AppShell(state: state)` themselves, with nothing
/// listening, so a screen sat frozen on the frame before the change.
///
/// It produced a picture of a contradiction the app does not have: Health
/// Check's empty-state render said "Nothing recorded yet" over a Home card
/// still reading the sample data's safe-to-spend figure. Every shot taken
/// after a store change had the same flaw, and so did any journey assertion
/// made after writing to the store without tapping.
///
/// The guard is deliberately about the SCREEN, not about the listener. A test
/// that asserted `state.hasListeners` would pass with the shell wired to
/// rebuild nothing.
void main() {
  Future<void> pump(WidgetTester tester, FinancialState state) async {
    await tester.runAsync(loadRealFonts);
    final Palette p = Palette.of(state.theme);
    await tester.pumpWidget(
      MaterialApp(
        theme: salapifyTheme(p, state.theme),
        home: AppShell(state: state),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a figure written to the store reaches the screen', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 3600);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final FinancialState state = FinancialState(
      clock: DateTime.utc(2026, 9, 18),
    );
    await pump(tester, state);

    // The sample data's own safe-to-spend figure, on screen before anything
    // is changed. Without this the test below would pass on an app that
    // never showed the figure at all.
    //
    // 32,056, and it has moved FOUR times for reasons that are the seed's
    // and the engine's rather than this test's. It was 38,414.
    //
    //   P2.3 took it to 27,359: `acc_maya` ships marked set aside, so 15,300
    //   stopped funding today's spending.
    //   P2.4 took it to 24,332: the engine now reserves what the seed's two
    //   loans REALLY cost each month, 4,950, instead of the prototype's eight
    //   percent of their balance, 1,388. It was under-reserving by 3,562.
    //   D32 took it to 24,108: bills added on the Bills screen are held back
    //   too. The seed's Spotify there is unpaid and due Sunday, 239, padded
    //   to 262.90 by the careful scenario, 85 percent of which is 224.
    //   D33 took it to 32,056: only bills due by payday are held back, so
    //   the 8,500 tuition due October 5 waits for the next cycle. 8,500
    //   padded by a tenth is 9,350, 85 percent of which is 7,948.
    //
    // Both figures are generated rather than chosen; see vector D in
    // test/core/money/safe_to_spend_golden_test.dart and the measurement in
    // test/core/money/debt_minimums_test.dart.
    expect(
      find.textContaining('32,056'),
      findsWidgets,
      reason: 'the fixture stopped showing the figure this test watches',
    );

    // A write with no tap behind it, which is exactly what the shot harness
    // does and what no rebuild was reaching.
    state.removeSampleData();
    await tester.pumpAndSettle();

    expect(
      find.textContaining('32,056'),
      findsNothing,
      reason:
          'the screen is still showing a figure the store no longer holds, '
          'so every render taken after a change is a picture of the frame '
          'before it',
    );
  });
}
