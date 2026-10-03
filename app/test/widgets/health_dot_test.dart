import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/health_check.dart';
import 'package:salapify/design/app_theme.dart';
import 'package:salapify/design/tokens.dart';
import 'package:salapify/screens/home/hero_panel.dart';
import 'package:salapify/state/financial_state.dart';

import '../shots/screens_shot.dart' show loadRealFonts;

/// The dot beside HEALTH CHECK says what the health check says.
///
/// It was a hardcoded dark red for the whole life of the hero card, with a
/// comment admitting it: "until the health engine is migrated it stays a
/// single neutral-to-warning marker". So a person who had just installed the
/// app saw an alarm on the most prominent card on Home, and tapping it opened
/// a sheet reading "Nothing recorded yet".
///
/// That is the cry wolf failure the working rules name: an alarm that is
/// always on gets its battery taken out, and then it is not there during the
/// fire. Both halves are proved here, and the SILENT half is the one that
/// was broken.
void main() {
  Future<void> pump(WidgetTester tester, FinancialState state) async {
    await tester.runAsync(loadRealFonts);
    tester.view.physicalSize = const Size(1170, 2000);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final Palette p = Palette.of(state.theme);
    await tester.pumpWidget(
      MaterialApp(
        theme: salapifyTheme(p, state.theme),
        home: Scaffold(
          backgroundColor: p.background,
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(Spacing.lg),
              child: HeroPanel(state: state),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('an app with nothing in it shows no alarm', (
    WidgetTester tester,
  ) async {
    final FinancialState state = FinancialState(
      clock: DateTime.utc(2026, 9, 18),
    );
    state.removeSampleData();
    await pump(tester, state);

    // The card itself is on screen, so a missing dot means a missing dot and
    // not a missing card.
    expect(find.text('HEALTH CHECK'), findsOneWidget);

    expect(
      state.healthReport.nothingYet,
      isTrue,
      reason: 'the fixture has something recorded, so this proves nothing',
    );
    expect(
      find.byKey(healthDotKey),
      findsNothing,
      reason:
          'a brand new install is being shown an alarm over a sheet that '
          'opens on "Nothing recorded yet"',
    );
  });

  testWidgets('a real problem still raises it', (WidgetTester tester) async {
    final FinancialState state = FinancialState(
      clock: DateTime.utc(2026, 9, 18),
    );
    await pump(tester, state);

    // The seeded fixture genuinely has a budget over its limit, which is
    // what the sheet's own render shows.
    final HealthIndicator? worst = state.healthReport.needsAttention;
    expect(
      worst,
      isNotNull,
      reason: 'nothing in the fixture needs attention, so this proves nothing',
    );

    expect(
      find.byKey(healthDotKey),
      findsOneWidget,
      reason: 'the health check found something and Home says nothing',
    );
  });

  testWidgets('the marker is readable without seeing the colour', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    final FinancialState state = FinancialState(
      clock: DateTime.utc(2026, 9, 18),
    );
    await pump(tester, state);

    expect(
      find.bySemanticsLabel(RegExp(r'^Health check, something')),
      findsOneWidget,
      reason:
          'the dot is eight pixels of colour and nothing else, so a screen '
          'reader and anybody who cannot separate red from amber gets no '
          'signal at all',
    );
    handle.dispose();
  });
}
