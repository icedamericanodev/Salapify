// "Add a budget", in both halves the working rules ask of a write path
// (founder direction 2026-10-08, "yes build add a budget").
//
// Half one: the budget is really stored, with the limit typed.
// Half two: a person can SEE it where they would look, Plan's Budgets, and
// it is still there after the app is closed and opened again.
//
// The fixture is a CLEARED book, which is exactly the case that could not
// get a budget back before this existed.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/main.dart';
import 'package:salapify/core/money/money.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/models/models.dart';
import 'package:salapify/state/financial_state.dart';

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a cleared book can set a budget, see it, and keep it', (
    WidgetTester tester,
  ) async {
    final MemorySnapshotStore store = MemorySnapshotStore();
    final FinancialState state = FinancialState(
      clock: DateTime(2026, 9, 18, 12),
      store: store,
    );
    // Loaded first, as the real app does: saving stays off until the
    // store has been read, so nothing can overwrite a file never opened.
    await state.restore();
    state.startWithExampleData();
    state.removeSampleData();
    expect(state.budgets, isEmpty);

    await tester.pumpWidget(SalapifyApp(state: state));
    await tester.pumpAndSettle();
    await _tap(tester, find.byIcon(Icons.track_changes_outlined));
    await _tap(tester, find.text('Budgets').first);
    expect(find.text('No budget set'), findsOneWidget);

    await _tap(tester, find.text('Set your budget'));
    expect(find.text('New budget'), findsOneWidget);
    await _tap(tester, find.text('Groceries'));
    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('new-budget-limit')),
        matching: find.byType(TextField),
      ),
      '8000',
    );
    await tester.pumpAndSettle();
    await _tap(tester, find.text('Set budget'));

    // Half one, directional: exactly one budget, with the typed limit.
    expect(state.budgets, hasLength(1));
    expect(state.budgets.single.category, 'Groceries');
    expect(state.budgets.single.limit, const Money.pesos(8000));

    // Half two: on the screen where a person would look for it.
    expect(find.text('No budget set'), findsNothing);
    expect(find.text('Groceries'), findsOneWidget);
    expect(find.text('LEFT TO SPEND THIS MONTH'), findsOneWidget);
    // Nothing spent on a cleared book, so all of it is left.
    expect(find.text('₱8,000.00'), findsWidgets);

    // And it survives the app being closed and opened again.
    await state.flushWrites();
    final FinancialState reopened = FinancialState(
      clock: DateTime(2026, 9, 18, 12),
      store: store,
    );
    await reopened.restore();
    expect(reopened.budgets.map((Budget b) => b.category), <String>[
      'Groceries',
    ], reason: 'the budget was not saved to the phone');
  });

  // From the QA review of 2026-10-08. "0.004" parses as a number but rounds
  // to ₱0.00, which the engine refuses; the button must refuse it first, or
  // the sheet closes looking exactly as if it had saved.
  testWidgets('a limit that rounds to zero cannot be set', (
    WidgetTester tester,
  ) async {
    final FinancialState state = FinancialState(
      clock: DateTime(2026, 9, 18, 12),
      store: MemorySnapshotStore(),
    );
    await state.restore();
    state.startWithExampleData();
    state.removeSampleData();
    await tester.pumpWidget(SalapifyApp(state: state));
    await tester.pumpAndSettle();
    await _tap(tester, find.byIcon(Icons.track_changes_outlined));
    await _tap(tester, find.text('Budgets').first);
    await _tap(tester, find.text('Set your budget'));
    await _tap(tester, find.text('Groceries'));
    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('new-budget-limit')),
        matching: find.byType(TextField),
      ),
      '0.004',
    );
    await tester.pumpAndSettle();
    await _tap(tester, find.text('Set budget'));

    expect(state.budgets, isEmpty);
    expect(
      find.text('New budget'),
      findsOneWidget,
      reason: 'the sheet closed as if a zero limit had been saved',
    );
  });
}
