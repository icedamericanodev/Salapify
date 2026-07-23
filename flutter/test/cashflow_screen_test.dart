// The Cash Flow screen renders the decision card, the projected balance chart,
// and the event list from the tested engine, without overflow or a paint throw.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/backup.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/screens/cashflow.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Fixed reference date the screen and the seed share, so the projected window is
// stable no matter when the suite runs.
final _ref = DateTime(2026, 7, 10);

Future<SalapifyStore> _seed(Map<String, dynamic> data) async {
  SharedPreferences.setMockInitialValues({});
  final store = SalapifyStore();
  await store.load();
  // Set data through sanitize, which does NOT stamp recurring items as posted
  // (importBackupText would, using the real clock, which would fight the fixed
  // reference date the screen projects from).
  store.data = sanitizeData(data, now: _ref);
  return store;
}

Future<void> _pump(WidgetTester tester, SalapifyStore store) async {
  tester.view.physicalSize = const Size(1100, 2600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: CashFlowScreen(store: store, now: _ref),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renders the decision card, chart, and events', (tester) async {
    final store = await _seed({
      'accounts': [
        {'id': 'g', 'name': 'GCash', 'kind': 'ewallet', 'balance': 8000},
      ],
      'recurring': [
        {
          'id': 'r1',
          'type': 'income',
          'label': 'Sweldo',
          'amount': 20000,
          'dayOfMonth': 28,
        },
        {
          'id': 'r2',
          'type': 'expense',
          'label': 'Rent',
          'amount': 12000,
          'dayOfMonth': 20,
        },
      ],
    });
    await _pump(tester, store);

    expect(find.text('Cash flow'), findsOneWidget);
    expect(find.text('PROJECTED BALANCE'), findsOneWidget);
    expect(find.text('WHAT IS COMING'), findsOneWidget);
    expect(find.text('Sweldo'), findsWidgets);
    expect(find.text('Rent'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty app shows the set-up prompt, no crash', (tester) async {
    final store = await _seed({'accounts': [], 'recurring': [], 'debts': []});
    await _pump(tester, store);
    expect(find.text('Set up your month'), findsOneWidget);
    expect(find.text('PROJECTED BALANCE'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a tight month shows the run-out warning', (tester) async {
    // 500 cash, a 12,000 rent later this month, no income until the far future.
    final store = await _seed({
      'accounts': [
        {'id': 'c', 'name': 'Cash', 'kind': 'cash', 'balance': 500},
      ],
      'recurring': [
        {
          'id': 'r2',
          'type': 'expense',
          'label': 'Rent',
          'amount': 12000,
          'dayOfMonth': 20,
        },
      ],
    });
    await _pump(tester, store);
    expect(find.text('Heads up, cash runs short'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
