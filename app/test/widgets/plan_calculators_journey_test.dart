import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/main.dart';
import 'package:salapify/screens/debt/debt_calculators.dart';
import 'package:salapify/screens/debt/debt_screen.dart';
import 'package:salapify/state/financial_state.dart';

/// The route the founder actually took, and found a wall at the end of.
///
/// They opened Plan, opened Calculators, looked for the loan calculators the
/// prototype has there, and reported them missing. All nine were built. The
/// TILE was wired to the add-a-debt form, so the door led to the wrong room,
/// and no test noticed because every test of the calculators reached them the
/// other way, from Home.
///
/// That is the gap this file exists to close: a feature can be complete and
/// still be unreachable, and only a test that walks the user's own path can
/// tell the difference.
void main() {
  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      SalapifyApp(
        state: FinancialState(
          clock: DateTime(2026, 9, 18, 12),
          store: MemorySnapshotStore(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapAndSettle(WidgetTester tester, Finder f) async {
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  Future<void> openPlanCalculators(WidgetTester tester) async {
    await pumpApp(tester);
    await tapAndSettle(tester, find.byIcon(Icons.track_changes_outlined));
    await tapAndSettle(tester, find.text('Calculators'));
  }

  testWidgets('Plan, Calculators, Debt and loan opens the debt register', (
    WidgetTester tester,
  ) async {
    await openPlanCalculators(tester);

    expect(
      find.text('Debt and loan'),
      findsOneWidget,
      reason: 'the tile the founder went looking for is not in the library',
    );

    await tapAndSettle(tester, find.text('Debt and loan'));

    expect(
      find.byType(DebtScreen),
      findsOneWidget,
      reason:
          'THE test. This tile opened the add-a-debt form, so somebody '
          'looking for what a loan costs was handed a form asking who they '
          'owe. The prototype points it at the same register Home does.',
    );
  });

  testWidgets('and all three of the prototype\'s sections are on it', (
    WidgetTester tester,
  ) async {
    await openPlanCalculators(tester);
    await tapAndSettle(tester, find.text('Debt and loan'));

    // The three the founder named: personal debts, instalments, calculators.
    expect(find.text('Debts'), findsWidgets);
    expect(find.text('Plans'), findsOneWidget);
    expect(find.text('Work it out'), findsOneWidget);
  });

  testWidgets('the nine loan calculators are genuinely reachable from there', (
    WidgetTester tester,
  ) async {
    await openPlanCalculators(tester);
    await tapAndSettle(tester, find.text('Debt and loan'));
    await tapAndSettle(tester, find.text('Work it out'));

    expect(find.byType(DebtCalculators), findsOneWidget);

    // Every one the founder listed by name, plus the four they wrote "etc"
    // for. A count would pass against nine of the wrong calculators.
    for (final String label in <String>[
      'Pag-IBIG housing',
      'Bank housing',
      'Car loan',
      'SSS and Pag-IBIG salary',
      'Personal and digital',
      'Credit card trap',
      'Consolidation',
      'Snowball or avalanche',
      'Can I afford it',
    ]) {
      expect(
        find.text(label),
        findsOneWidget,
        reason: '$label is not reachable from Plan, Calculators',
      );
    }
  });

  testWidgets('a calculator opened this way computes a real figure', (
    WidgetTester tester,
  ) async {
    await openPlanCalculators(tester);
    await tapAndSettle(tester, find.text('Debt and loan'));
    await tapAndSettle(tester, find.text('Work it out'));

    // The directional companion to "the screen is reachable": reaching a
    // screen that shows nothing would satisfy every assertion above.
    expect(
      find.textContaining('₱'),
      findsWidgets,
      reason:
          'the calculators opened but computed nothing, which is a screen '
          'that is present and useless',
    );
  });

  testWidgets('the tile does not go to the add-a-debt form any more', (
    WidgetTester tester,
  ) async {
    await openPlanCalculators(tester);
    await tapAndSettle(tester, find.text('Debt and loan'));

    // 'Add a debt' is the sheet's real title, checked against
    // add_debt_sheet.dart rather than guessed at. The first version of this
    // assertion looked for 'Who do you owe?', which appears nowhere in the
    // app, so it passed with the defect fully restored and proved nothing.
    expect(
      find.text('Add a debt'),
      findsNothing,
      reason: 'the old wrong destination is back',
    );
    expect(find.text('Which way does it go'), findsNothing);
  });
}
