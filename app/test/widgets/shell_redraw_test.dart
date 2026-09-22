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
    expect(
      find.textContaining('38,414'),
      findsWidgets,
      reason: 'the fixture stopped showing the figure this test watches',
    );

    // A write with no tap behind it, which is exactly what the shot harness
    // does and what no rebuild was reaching.
    state.removeSampleData();
    await tester.pumpAndSettle();

    expect(
      find.textContaining('38,414'),
      findsNothing,
      reason:
          'the screen is still showing a figure the store no longer holds, '
          'so every render taken after a change is a picture of the frame '
          'before it',
    );
  });
}
