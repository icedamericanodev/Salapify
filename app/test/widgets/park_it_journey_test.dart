// Park it for 48 hours, by tapping (D38.2).
//
// The store half is test/data/park_it_test.dart. This is what a person does:
// types a purchase, parks it instead of saving it, finds it on Plan, and two
// days later answers Home's "Still want it?" each of the three ways. Every
// answer is checked where it should show up afterwards.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/money.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/main.dart';
import 'package:salapify/models/models.dart';
import 'package:salapify/screens/home/quick_actions.dart';
import 'package:salapify/state/financial_state.dart';

import '../shots/screens_shot.dart' show loadRealFonts;

void main() {
  final DateTime parkedOn = DateTime(2026, 10, 12, 20, 40);
  final DateTime twoDaysOn = parkedOn.add(const Duration(hours: 49));

  Future<void> setView(WidgetTester tester) async {
    await tester.runAsync(loadRealFonts);
    tester.view.physicalSize = const Size(1170, 3400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
  }

  Future<void> tapIt(WidgetTester tester, Finder f) async {
    await tester.ensureVisible(f.first);
    await tester.pumpAndSettle();
    await tester.tap(f.first);
    await tester.pumpAndSettle();
  }

  Future<void> openTab(WidgetTester tester, String label) async {
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  /// A phone with one item parked two days ago, opened now.
  Future<FinancialState> openWithParked(WidgetTester tester) async {
    final FinancialState earlier = FinancialState(clock: parkedOn);
    earlier.startWithExampleData();
    earlier.parkItem(
      name: 'Running shoes',
      amount: const Money.pesos(4500),
      category: 'Shopping & Personal',
    );
    final FinancialState state = FinancialState(
      clock: twoDaysOn,
      store: MemorySnapshotStore(earlier.snapshot().encode(at: parkedOn)),
    );
    earlier.dispose();
    await state.restore();
    addTearDown(state.dispose);
    await tester.pumpWidget(SalapifyApp(state: state));
    await tester.pumpAndSettle();
    return state;
  }

  Money cash(FinancialState s) =>
      s.accounts.firstWhere((Account a) => a.id == 'acc_cash').balance;

  testWidgets('parking from the Log sheet spends nothing, says when it will '
      'ask, and shows on Plan', (WidgetTester tester) async {
    await setView(tester);
    final FinancialState state = FinancialState(clock: parkedOn);
    await state.restore();
    state.startWithExampleData();
    addTearDown(state.dispose);
    await tester.pumpWidget(SalapifyApp(state: state));
    await tester.pumpAndSettle();
    final int entries = state.transactions.length;

    await tapIt(
      tester,
      find.descendant(
        of: find.byType(QuickActions),
        matching: find.text('Log'),
      ),
    );
    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('log-amount')),
        matching: find.byType(TextField),
      ),
      '4500',
    );
    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('log-merchant')),
        matching: find.byType(TextField),
      ),
      'Running shoes',
    );
    await tester.pumpAndSettle();
    await tapIt(tester, find.byKey(const Key('log-park')));

    expect(state.transactions.length, entries, reason: 'parking logged it');
    expect(state.parkedItems.single.name, 'Running shoes');
    expect(
      find.text('Parked until Wed 8:40 PM. Salapify will ask you then.'),
      findsOneWidget,
    );
    // Not yet: Home does not ask before the 48 hours.
    expect(find.byKey(const Key('parked-card')), findsNothing);

    await openTab(tester, 'Plan');
    await tapIt(tester, find.text('Goals'));
    expect(find.text('PARKED'), findsOneWidget);
    expect(find.text('Running shoes'), findsOneWidget);
    expect(find.text('₱4,500.00'), findsWidgets);
  });

  testWidgets('I bought it: Log opens filled in, the entry saves, the cash '
      'drops by the price, and the card is gone', (WidgetTester tester) async {
    await setView(tester);
    final FinancialState state = await openWithParked(tester);
    final Money before = cash(state);

    expect(find.text('Still want it?'), findsOneWidget);
    await tapIt(tester, find.text('I bought it'));
    // Filled in from the wish.
    expect(find.text('Running shoes'), findsWidgets);
    // Paid in cash, so the movement is on one account we can name.
    await tapIt(tester, find.byKey(const Key('log-source-picker')));
    await tapIt(tester, find.text('Cash on Hand (Pitaka)').last);
    await tapIt(tester, find.text('Save entry'));

    expect(state.parkedItems, isEmpty);
    expect(cash(state), before - const Money.pesos(4500));
    expect(
      state.transactions.any(
        (Transaction t) =>
            t.merchant == 'Running shoes' && t.category == 'Shopping & Personal',
      ),
      isTrue,
    );
    // The shell landed on Activity, where the entry is.
    expect(find.textContaining('Running shoes'), findsWidgets);
  });

  testWidgets('Cancel on I bought it keeps the wish parked', (
    WidgetTester tester,
  ) async {
    await setView(tester);
    final FinancialState state = await openWithParked(tester);
    await tapIt(tester, find.text('I bought it'));
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(state.parkedItems, hasLength(1));
    expect(find.text('Still want it?'), findsOneWidget);
  });

  testWidgets('Let it go says the amount once, and Undo brings the card back', (
    WidgetTester tester,
  ) async {
    await setView(tester);
    final FinancialState state = await openWithParked(tester);
    final Money before = cash(state);

    await tapIt(tester, find.text('Let it go'));
    expect(state.parkedItems, isEmpty);
    expect(find.text('Still want it?'), findsNothing);
    expect(find.text('₱4,500.00 stays with you.'), findsOneWidget);
    expect(cash(state), before, reason: 'letting go moved money');

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(state.parkedItems, hasLength(1));
    expect(find.text('Still want it?'), findsOneWidget);
  });

  testWidgets('Save up for it opens a goal with the name and price, and the '
      'goal is on Plan', (WidgetTester tester) async {
    await setView(tester);
    final FinancialState state = await openWithParked(tester);
    final int goals = state.goals.length;

    await tapIt(tester, find.text('Save up for it'));
    expect(find.text('New goal'), findsOneWidget);
    await tapIt(tester, find.text('Create goal'));

    expect(state.parkedItems, isEmpty);
    expect(state.goals.length, goals + 1);
    final Goal g = state.goals.firstWhere(
      (Goal g) => g.name == 'Running shoes',
    );
    expect(g.targetAmount, const Money.pesos(4500));

    await openTab(tester, 'Plan');
    await tapIt(tester, find.text('Goals'));
    expect(find.text('Running shoes'), findsWidgets);
    expect(find.text('PARKED'), findsNothing);
  });
}
