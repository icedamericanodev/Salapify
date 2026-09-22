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

  Map<String, dynamic> projectable({bool pro = false}) => {
    'settings': {
      if (pro) 'pro': true,
      'paydaySchedule': {'mode': 'monthly', 'day': 28},
    },
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
        'amount': 6000,
        'dayOfMonth': 20,
      },
    ],
  };

  testWidgets('the longer horizons are gated until Pro', (tester) async {
    final store = await _seed(projectable());
    await _pump(tester, store);
    expect(find.text('From today to the end of the month'), findsOneWidget);
    await tester.tap(find.text('60 days'));
    await tester.pumpAndSettle();
    // The gate speaks, and the window does not move.
    expect(
      find.textContaining('The longer view is part of Pro'),
      findsOneWidget,
    );
    expect(find.text('From today to the end of the month'), findsOneWidget);
    expect(find.text('The next 60 days'), findsNothing);
  });

  testWidgets('the gate has a working door: Unlock free applies the choice', (
    tester,
  ) async {
    // The gate must never point at a door that does not exist; its snackbar
    // action unlocks Pro (free during early access) and then applies the
    // chip the user was trying to reach.
    final store = await _seed(projectable());
    await _pump(tester, store);
    await tester.tap(find.text('60 days'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unlock free'));
    await tester.pumpAndSettle();
    expect((store.data['settings'] as Map)['pro'], true);
    expect(find.text('The next 60 days'), findsOneWidget);
  });

  testWidgets('Pro switches the horizon and the labels follow', (tester) async {
    final store = await _seed(projectable(pro: true));
    await _pump(tester, store);
    await tester.tap(find.text('60 days'));
    await tester.pumpAndSettle();
    expect(find.text('The next 60 days'), findsOneWidget);
    expect(find.text('IN 60 DAYS'), findsOneWidget);
    // The payday chip exists because a schedule exists.
    await tester.tap(find.text('To payday'));
    await tester.pumpAndSettle();
    expect(find.text('From today to your next payday'), findsOneWidget);
    expect(find.text('AT PAYDAY'), findsOneWidget);
  });

  testWidgets('a Pro user saves a what if and it overlays the plan', (
    tester,
  ) async {
    final store = await _seed(projectable(pro: true));
    await _pump(tester, store);
    await tester.scrollUntilVisible(
      find.text('Add a what if'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Add a what if'));
    await tester.pumpAndSettle();
    // Default kind is A big buy, dated a week out, inside every window.
    await tester.enterText(
      find.widgetWithText(TextField, 'Name (optional)'),
      'New phone',
    );
    await tester.enterText(find.widgetWithText(TextField, 'Amount'), '12000');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    // Persisted through the store, not widget state.
    expect(store.timelineScenarios, hasLength(1));
    expect(store.timelineScenarios.single['amount'], 12000.0);
    // The row renders and the event list marks the overlay as a what if.
    expect(find.text('New phone'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('New phone (what if)'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('New phone (what if)'), findsOneWidget);
  });

  testWidgets('the free user is told what ifs are Pro', (tester) async {
    final store = await _seed(projectable());
    await _pump(tester, store);
    await tester.scrollUntilVisible(
      find.text('Add a what if'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Add a what if'));
    await tester.pumpAndSettle();
    expect(find.textContaining('What ifs are part of Pro'), findsOneWidget);
    expect(store.timelineScenarios, isEmpty);
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
