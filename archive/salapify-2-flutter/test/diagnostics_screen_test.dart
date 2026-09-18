// The Diagnostics SCREEN must never show money either.
//
// diagnostics_test.dart guards the pasteable report. This guards the on-screen
// view of it: the tester screen reads the same safe counts (ints) and the
// trimmed error buffer, and must render NEITHER an amount, a name, a note, a
// category, nor the user's own name from the store. Built over the same
// deliberately incriminating store, so a future edit that renders store
// contents on this screen fails here and says which value leaked.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/screens/diagnostics_screen.dart';
import 'package:salapify/services/diagnostics.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Everything the screen must never show, value to reason. Mirrors
/// diagnostics_test.dart so both the report and its view are held to one rule.
const _forbidden = {
  '18450': 'an amount',
  'Jollibee': 'a merchant the user visited',
  'BPI Savings': 'an account name',
  'Kuya Mark': "another person's name",
  'lunch with mom': 'a private note',
  'Groceries': 'a spending category',
  'Lala': 'the name of the person using the app',
};

Map<String, dynamic> _incriminatingStore() => {
  'transactions': [
    {
      'id': 't1',
      'amount': 18450,
      'note': 'lunch with mom',
      'category': 'Groceries',
      'merchant': 'Jollibee',
    },
    {'id': 't2', 'amount': 300},
  ],
  'accounts': [
    {'id': 'a1', 'name': 'BPI Savings', 'balance': 18450},
  ],
  'debts': [
    {'id': 'd1', 'name': 'Kuya Mark', 'amount': 18450},
  ],
  'goals': [],
  'utang': [
    {'id': 'u1', 'person': 'Kuya Mark', 'amount': 18450},
  ],
  'recurring': [],
  'categories': [
    {'id': 'c1', 'name': 'Groceries'},
  ],
  'settings': {'displayName': 'Lala'},
};

void main() {
  testWidgets('shows safe counts and errors, never store contents', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    await Diagnostics.clear();
    // A recorded error whose message is a developer string, not user data, to
    // confirm errors DO render while store PII does not.
    Diagnostics.record(
      'RangeError (index): invalid value',
      'package:salapify/screens/foo.dart 12:3',
    );

    final store = SalapifyStore();
    store.data = _incriminatingStore();

    await tester.pumpWidget(MaterialApp(home: DiagnosticsScreen(store: store)));
    await tester.pumpAndSettle();

    for (final entry in _forbidden.entries) {
      expect(
        find.textContaining(entry.key),
        findsNothing,
        reason:
            '${entry.value} ("${entry.key}") leaked onto the diagnostics '
            'screen. The screen must show counts and error messages only.',
      );
    }

    // The safe counts DO render: two transactions from the incriminating store.
    expect(find.text('transactions'), findsOneWidget);
    expect(find.text('2'), findsWidgets);
    // The error message renders; it is a developer string, not user data.
    expect(find.textContaining('RangeError'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('honest empty state when nothing has gone wrong', (tester) async {
    tester.view.physicalSize = const Size(1200, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    await Diagnostics.clear();
    final store = SalapifyStore();

    await tester.pumpWidget(MaterialApp(home: DiagnosticsScreen(store: store)));
    await tester.pumpAndSettle();

    expect(find.textContaining('No errors recorded'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
