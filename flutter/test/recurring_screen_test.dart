// Recurring bills and income: posting on load (the money path), plus the CRUD
// screen and the free-limit Pro wall. The posting engine itself is golden
// locked in recurring_golden_test.dart; this covers the store wiring and UI.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

String _monthKey() {
  final n = DateTime.now();
  return '${n.year}-${n.month.toString().padLeft(2, '0')}';
}

List _txns(SalapifyStore s) => s.data['transactions'] as List;
List _recur(SalapifyStore s) => s.data['recurring'] as List;

Future<void> _openRecurring(WidgetTester tester) async {
  await tester.tap(find.text('Menu'));
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(find.text('Recurring'), 200,
      scrollable: find.byType(Scrollable).first);
  await tester.ensureVisible(find.text('Recurring'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Recurring'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a due recurring item posts on load and moves the account',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'salapify_data_v2': jsonEncode({
        'accounts': [
          {'id': 'cash', 'name': 'Cash', 'kind': 'cash', 'balance': 5000},
        ],
        // Day 1 has always passed, no lastPosted, so it is due this month.
        'recurring': [
          {'id': 'r1', 'type': 'expense', 'label': 'Rent', 'amount': 3000, 'dayOfMonth': 1, 'accountId': 'cash', 'lastPosted': ''},
        ],
      }),
    });
    final store = SalapifyStore();
    await tester.pumpWidget(SalapifyApp(store: store));
    await tester.pumpAndSettle();

    // One transaction posted, linked to the rule, account moved 5000 -> 2000.
    expect(_txns(store).length, 1);
    final tx = _txns(store).first as Map;
    expect(tx['recurringId'], 'r1');
    expect(tx['type'], 'expense');
    expect(tx['amount'], 3000);
    final cash = (store.data['accounts'] as List)
        .firstWhere((a) => a['id'] == 'cash') as Map;
    expect(cash['balance'], 2000);
    // The item is stamped, so a second load never double posts.
    expect((_recur(store).first as Map)['lastPosted'], _monthKey());
  });

  testWidgets('add a recurring item from the screen', (tester) async {
    tester.view.physicalSize = const Size(1200, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    final store = SalapifyStore();
    await tester.pumpWidget(SalapifyApp(store: store));
    await tester.pumpAndSettle();
    await _openRecurring(tester);

    expect(find.text('No recurring items yet'), findsOneWidget);
    await tester.tap(find.text('+ Add'));
    await tester.pumpAndSettle();
    expect(find.text('New recurring'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(0), 'Netflix');
    await tester.enterText(find.byType(TextField).at(1), '549');
    await tester.enterText(find.byType(TextField).at(2), '28');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(_recur(store).length, 1);
    final r = _recur(store).first as Map;
    expect(r['label'], 'Netflix');
    expect(r['amount'], 549.0);
    expect(r['dayOfMonth'], 28);
    expect(r['type'], 'expense');
  });

  testWidgets('the free limit shows the Pro wall at 5 items', (tester) async {
    tester.view.physicalSize = const Size(1200, 3600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final items = [
      for (var i = 0; i < 5; i++)
        {'id': 'r$i', 'type': 'expense', 'label': 'Bill $i', 'amount': 100, 'dayOfMonth': 28, 'accountId': '', 'lastPosted': _monthKey()},
    ];
    SharedPreferences.setMockInitialValues({
      'salapify_data_v2': jsonEncode({'recurring': items}),
    });
    final store = SalapifyStore();
    await tester.pumpWidget(SalapifyApp(store: store));
    await tester.pumpAndSettle();
    await _openRecurring(tester);

    await tester.tap(find.text('+ Add'));
    await tester.pumpAndSettle();
    // The Pro wall opens instead of the add form.
    expect(find.text('Free keeps 5 recurring items'), findsOneWidget);
    expect(find.text('New recurring'), findsNothing);
  });
}
