import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/design/app_theme.dart';
import 'package:salapify/design/tokens.dart';
import 'package:salapify/models/models.dart';
import 'package:salapify/screens/home/hero_panel.dart';
import 'package:salapify/state/financial_state.dart';

import '../shots/screens_shot.dart' show loadRealFonts;

/// The line under the big figure never states what was not measured.
///
/// It used to end in "· Lasts N days" unconditionally. The runway is liquid
/// cash divided by a daily burn rate, and under 5,000 logged in thirty days
/// that burn rate is a stand-in of 28,000 a month that nobody recorded. So a
/// phone ten seconds old divided zero by an invented figure and printed
/// "Lasts 0 days" under a zero balance: not a measurement, and it reads as a
/// verdict.
///
/// The ENGINE is untouched. `cashRunwayDays` still returns what its golden
/// vectors say, and the Safe to Spend sheet still shows it with the caption
/// that names which burn rate it used. This is about the one surface that
/// stated it flatly, with no room for that caption.
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

  testWidgets('a phone with nothing on it is not told it lasts 0 days', (
    WidgetTester tester,
  ) async {
    final FinancialState state = FinancialState(
      clock: DateTime.utc(2026, 9, 18),
    );
    state.removeSampleData();
    await pump(tester, state);

    // The engine still returns the figure. This is a display decision, and
    // asserting it here is what stops somebody "fixing" the zero in the
    // engine, where a golden vector holds it.
    expect(
      state.safeToSpendAnalysis.cashRunwayDays,
      0,
      reason: 'the fixture no longer produces the figure this test is about',
    );
    expect(
      state.safeToSpendAnalysis.runwayFromLoggedSpending,
      isFalse,
      reason: 'the fixture measured a pace, so this proves nothing',
    );

    expect(
      find.textContaining('Lasts'),
      findsNothing,
      reason:
          'the card is stating a runway it divided out of an invented burn '
          'rate, and on an empty phone that reads as a verdict',
    );

    // And it still says the ONE thing it can say, so the fix is not a blank
    // line where a sentence used to be.
    expect(find.textContaining('Set your payday'), findsOneWidget);
  });

  testWidgets('a lived-in phone still gets its runway', (
    WidgetTester tester,
  ) async {
    final FinancialState state = FinancialState(
      clock: DateTime.utc(2026, 9, 18),
    );
    await pump(tester, state);

    expect(
      state.safeToSpendAnalysis.runwayFromLoggedSpending,
      isTrue,
      reason: 'the fixture stopped measuring a pace, so this proves nothing',
    );

    expect(
      find.textContaining('Lasts 116 days'),
      findsOneWidget,
      reason:
          'a real measurement was removed along with the invented one, which '
          'is a regression and not a fix',
    );
  });

  testWidgets('money recorded but no spending logged still says nothing', (
    WidgetTester tester,
  ) async {
    // The case between the two above, and the reason the condition is the
    // MEASURED flag rather than "is the app empty". Somebody who has entered
    // their accounts but logged nothing has real cash and an invented pace,
    // so the runway would read as a confident number built on a guess.
    final FinancialState state = FinancialState(
      clock: DateTime.utc(2026, 9, 18),
    );
    state.removeSampleData();
    state.addAccount(
      const Account(
        id: 'mine',
        name: 'My savings',
        kind: AccountKind.bank,
        institution: 'SeaBank',
        balance: 50000,
        monogram: 'SB',
      ),
    );
    await pump(tester, state);

    expect(
      state.safeToSpendAnalysis.cashRunwayDays,
      greaterThan(0),
      reason: 'there is no cash, so this is the empty case again',
    );
    expect(
      find.textContaining('Lasts'),
      findsNothing,
      reason:
          'a runway built from the 28,000 stand-in is being stated as '
          'though it came from this person',
    );
  });
}
