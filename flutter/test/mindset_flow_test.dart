// The redesigned Money Mindset flow: walks the four steps and checks the
// action write-through lands in the store through the existing tested paths.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/screens/mindset_flow.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _blob() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  String iso(DateTime t) =>
      '${t.year.toString().padLeft(4, '0')}-'
      '${t.month.toString().padLeft(2, '0')}-'
      '${t.day.toString().padLeft(2, '0')}';
  DateTime back(int m, int day) => DateTime(today.year, today.month - m, day);
  final txns = <Map<String, dynamic>>[];
  for (var m = 0; m <= 5; m++) {
    txns.add({
      'id': 'in$m',
      'type': 'income',
      'label': 'Salary',
      'amount': 32000,
      'date': iso(back(m, 5)),
      'accountId': 'pay',
    });
  }
  return {
    'schemaVersion': 12,
    'settings': {'onboarded': true},
    'accounts': [
      {'id': 'pay', 'name': 'Payroll', 'kind': 'checking', 'balance': 40000},
    ],
    'transactions': txns,
  };
}

Future<SalapifyStore> _pump(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({
    'salapify_data_v2': jsonEncode(_blob()),
  });
  final store = SalapifyStore();
  await store.load();
  tester.view.physicalSize = const Size(900, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: MindsetFlowScreen(store: store)));
  await tester.pumpAndSettle();
  return store;
}

Future<void> _toDecision(WidgetTester tester) async {
  await tester.enterText(find.byType(TextField).at(1), '3000');
  await tester.pumpAndSettle();
  await tester.tap(find.text('Continue')); // step 2
  await tester.pumpAndSettle();
  await tester.tap(find.text('Continue')); // step 3
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('mindsetAnswer_0_true')));
  await tester.pumpAndSettle();
  // "No" to affording without reserved money hard-caps the band at a pause, so
  // the result always offers a Remind me action.
  await tester.tap(find.byKey(const Key('mindsetAnswer_1_false')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('mindsetAnswer_2_true')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('skipping records a win and logs the check', (tester) async {
    final store = await _pump(tester);
    expect((store.data['wins'] as List?)?.length ?? 0, 0);

    await _toDecision(tester);
    await tester.tap(find.text('Skip for now'));
    await tester.pumpAndSettle();

    // A win was recorded and the check logged; nothing moved a balance.
    expect((store.data['wins'] as List).length, 1);
    expect(store.mindsetChecks.length, 1);
    expect(find.text('Your last 30 days'), findsOneWidget); // reached step 4
  });

  testWidgets('remind me records a waiting item', (tester) async {
    final store = await _pump(tester);
    expect(store.mindsetWaiting.length, 0);

    await _toDecision(tester);
    final remind = find.textContaining('Remind me');
    expect(remind, findsOneWidget);
    await tester.tap(remind);
    await tester.pumpAndSettle();

    expect(store.mindsetWaiting.length, 1);
  });

  testWidgets('the Credit or BNPL path shows the flat add-on cost breakdown', (
    tester,
  ) async {
    await _pump(tester);
    // Choose the credit path.
    await tester.tap(find.text('Credit or BNPL'));
    await tester.pumpAndSettle();

    // The fee is labelled a one-time fee, never "interest per month".
    expect(find.text('One-time fee (% of price)'), findsOneWidget);

    // Price 20,000 on a 6-month plan (default) with a 3% one-time fee.
    await tester.enterText(find.byType(TextField).at(1), '20000');
    await tester.enterText(find.byType(TextField).at(2), '3');
    await tester.pumpAndSettle();

    // extra = 600, total = 20,600, monthly = 3,433.33; the cost card shows them.
    expect(find.text('Monthly payment (approx.)'), findsOneWidget);
    expect(find.text('Total paid'), findsOneWidget);
    expect(find.text('Extra cost'), findsOneWidget);
    expect(find.textContaining('20,600'), findsWidgets);
    expect(find.textContaining('600'), findsWidgets);
    // The honest annualized cost is surfaced, not just the small peso fee.
    expect(find.text('Real cost per year'), findsOneWidget);
  });

  testWidgets('the Subscription path compares monthly vs yearly', (
    tester,
  ) async {
    await _pump(tester);
    await tester.tap(find.text('Subscription'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(1), '499');
    await tester.pumpAndSettle();

    // Default is Monthly: 499/mo and 5,988/yr (499 * 12).
    expect(find.text('Per month'), findsOneWidget);
    expect(find.text('Per year'), findsOneWidget);
    expect(find.textContaining('5,988'), findsWidgets);

    // Switch to Yearly: now 499 is the yearly figure, ~41.58/mo.
    await tester.tap(find.text('Yearly'));
    await tester.pumpAndSettle();
    expect(find.textContaining('41'), findsWidgets); // 499/12 per month
  });

  testWidgets('the flow never records a transaction (read-only money)', (
    tester,
  ) async {
    final store = await _pump(tester);
    final txCount = (store.data['transactions'] as List).length;
    await _toDecision(tester);
    await tester.tap(find.text('Buy anyway'));
    await tester.pumpAndSettle();
    expect((store.data['transactions'] as List).length, txCount);
  });
}
