// Batch 6, the list polish sweep: rows say which account and category they
// belong to, Budget's empty month explains itself and shows today's entries,
// and Home's two informational cards lead somewhere.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/main.dart';
import 'package:salapify/screens/accounts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/app_harness.dart';

String get _today => DateTime.now().toIso8601String().substring(0, 10);

Map<String, dynamic> _blob() => {
  'schemaVersion': 12,
  'accounts': [
    {'id': 'cash', 'name': 'Cash', 'kind': 'cash', 'balance': 1000},
  ],
  'categories': [
    {'id': 'c-food', 'name': 'Food'},
  ],
  'transactions': [
    {
      'id': 't1',
      'type': 'expense',
      'label': 'Jollibee',
      'amount': 150,
      'date': _today,
      'accountId': 'cash',
      'categoryId': 'c-food',
    },
  ],
};

Future<SalapifyStore> _boot(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1200, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({storageKey: jsonEncode(_blob())});
  final store = SalapifyStore();
  await tester.pumpWidget(SalapifyApp(store: store));
  await tester.pumpAndSettle();
  return store;
}

void main() {
  testWidgets('an Activity row names its account and category', (tester) async {
    await _boot(tester);
    await goToTab(tester, 'Activity');
    expect(
      find.text('Cash · Food'),
      findsOneWidget,
      reason:
          'The context line is what tells two rows named "Expense" for the '
          'same amount apart. It comes from the maps the filter already '
          'computes.',
    );
  });

  testWidgets('ACCOUNTS leads to Accounts', (tester) async {
    final _ = await _boot(tester);
    // THIS MONTH's tap-to-Activity affordance moved with its figures: they are
    // the dashboard-first Quick Overview tiles now, and a tap-through to
    // Activity returns with the Recent Transactions "See all" in the next
    // increment. ACCOUNTS still opens the Accounts screen from its tail preview.
    await tester.tap(find.text('ACCOUNTS'));
    await tester.pumpAndSettle();
    expect(
      find.byType(AccountsScreen),
      findsOneWidget,
      reason:
          'Tapping ACCOUNTS must open the Accounts screen; the rows ARE '
          'accounts.',
    );
  });

  testWidgets('Budget shows TODAY entries, and explains an empty month', (
    tester,
  ) async {
    await _boot(tester);
    await goToTab(tester, 'Budget');
    expect(
      find.text('TODAY'),
      findsOneWidget,
      reason:
          'A logged entry today must be visible on the Budget tab, so a '
          'quick add has a consequence you can see.',
    );
    expect(find.text('Jollibee'), findsOneWidget);
  });

  testWidgets('an empty month says so instead of leaving a void', (
    tester,
  ) async {
    // 4600, not 3000: the dashboard-first Net Worth hero and Quick Overview
    // added height above the tail, so the taller view keeps the tail (ACCOUNTS)
    // built in this lazy Home ListView.
    tester.view.physicalSize = const Size(1200, 4600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({
      storageKey: jsonEncode({
        'schemaVersion': 12,
        'accounts': [
          {'id': 'cash', 'name': 'Cash', 'kind': 'cash', 'balance': 1000},
        ],
        'transactions': <Map<String, dynamic>>[],
      }),
    });
    await tester.pumpWidget(SalapifyApp(store: SalapifyStore()));
    await tester.pumpAndSettle();
    await goToTab(tester, 'Budget');
    expect(
      find.text('Nothing spent yet this month'),
      findsOneWidget,
      reason:
          'The 1st of the month left 60 percent of the daily-driver tab as '
          'dead space with no explanation.',
    );
  });
}
