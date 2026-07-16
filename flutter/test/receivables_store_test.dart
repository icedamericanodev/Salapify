// The receivables write paths through the real store: add an utang, collect
// payments, mark paid, remove a payment, all persisting and moving balances
// through the golden-verified engines. Plus the person sheet and add sheet
// rendering against real data.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> blob() => {
      'schemaVersion': 12,
      'accounts': [
        {'id': 'cash', 'name': 'Cash', 'kind': 'cash', 'balance': 5000},
        {'id': 'bank', 'name': 'Bank', 'kind': 'bank', 'balance': 20000},
      ],
      'transactions': [],
      'people': [
        {'id': 'p1', 'name': 'Migs', 'phone': '', 'note': ''},
      ],
      'receivables': [
        {
          'id': 'r1',
          'personId': 'p1',
          'person': 'Migs',
          'amount': 2000,
          'dueDate': '2026-07-04',
          'payments': [],
          'paid': false,
        },
      ],
      'settings': {'defaultAccountId': 'bank'},
    };

Future<SalapifyStore> loaded() async {
  final store = SalapifyStore();
  await store.load();
  return store;
}

double balanceOf(SalapifyStore store, String id) =>
    ((store.data['accounts'] as List)
            .cast<Map<String, dynamic>>()
            .firstWhere((a) => a['id'] == id)['balance'] as num)
        .toDouble();

Map<String, dynamic> receivable(SalapifyStore store, String id) =>
    (store.data['receivables'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((r) => r['id'] == id);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({storageKey: jsonEncode(blob())});
  });

  test('collectUtangPayment posts income to the default account and persists',
      () async {
    final store = await loaded();
    await store.collectUtangPayment('r1', '250');
    expect(balanceOf(store, 'bank'), 20250);
    final r = receivable(store, 'r1');
    expect((r['payments'] as List).length, 1);
    expect(r['paid'], false);
    final txns = (store.data['transactions'] as List)
        .cast<Map<String, dynamic>>();
    expect(txns.length, 1);
    expect(txns.first['source'], 'receivable');
    expect(txns.first['type'], 'income');
    final fresh = await loaded();
    expect(balanceOf(fresh, 'bank'), 20250);
  });

  test('a payment covering everything settles the utang', () async {
    final store = await loaded();
    await store.collectUtangPayment('r1', '2,000');
    expect(receivable(store, 'r1')['paid'], true);
    expect(balanceOf(store, 'bank'), 22000);
  });

  test('markUtangPaid settles the remainder with a settled-tagged payment',
      () async {
    final store = await loaded();
    await store.collectUtangPayment('r1', '500');
    await store.markUtangPaid('r1');
    final r = receivable(store, 'r1');
    expect(r['paid'], true);
    final payments = (r['payments'] as List).cast<Map<String, dynamic>>();
    expect(payments.length, 2);
    expect(payments.last['settled'], true);
    expect(balanceOf(store, 'bank'), 22000);
  });

  test('removeUtangPayment reverses the income and reopens', () async {
    final store = await loaded();
    await store.collectUtangPayment('r1', '2000');
    final r = receivable(store, 'r1');
    final paymentId =
        ((r['payments'] as List).first as Map)['id'].toString();
    await store.removeUtangPayment('r1', paymentId);
    final after = receivable(store, 'r1');
    expect(after['paid'], false);
    expect((after['payments'] as List), isEmpty);
    expect(balanceOf(store, 'bank'), 20000);
    expect((store.data['transactions'] as List), isEmpty);
  });

  test('addUtang creates the person once and records the lend leg', () async {
    final store = await loaded();
    await store.addUtang(
        person: 'Ana', amountText: '600', fromAccount: 'cash');
    expect(balanceOf(store, 'cash'), 4400);
    final people = (store.data['people'] as List).cast<Map<String, dynamic>>();
    expect(people.length, 2);
    // Same person again, case-insensitive: no duplicate person record.
    await store.addUtang(person: 'ana', amountText: '100');
    expect((store.data['people'] as List).length, 2);
    expect((store.data['receivables'] as List).length, 3);
  });

  test('addUtang refuses an impossible date with a friendly message',
      () async {
    final store = await loaded();
    await expectLater(
        store.addUtang(
            person: 'Lita', amountText: '100', dueDate: '2026-02-30'),
        throwsA(isA<ArgumentError>()));
    // Nothing was written.
    expect((store.data['receivables'] as List).length, 1);
    expect((store.data['people'] as List).length, 1);
  });

  testWidgets('the person sheet logs a payment end to end', (tester) async {
    final store = SalapifyStore();
    await tester.pumpWidget(SalapifyApp(store: store));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Utang'));
    await tester.pumpAndSettle();
    expect(find.text('Migs'), findsOneWidget);

    await tester.tap(find.text('Migs'));
    await tester.pumpAndSettle();
    expect(find.text('Log payment'), findsOneWidget);

    await tester.tap(find.text('Log payment'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextField, 'How much came back?'), '250');
    await tester.tap(find.text('Save payment'));
    await tester.pumpAndSettle();

    // The sheet rebuilds live: 1,750 left of 2,000.
    expect(find.textContaining('left of'), findsOneWidget);
    final r = (store.data['receivables'] as List)
        .cast<Map<String, dynamic>>()
        .first;
    expect((r['payments'] as List).length, 1);
  });

  testWidgets('the add utang sheet saves a new utang', (tester) async {
    final store = SalapifyStore();
    await tester.pumpWidget(SalapifyApp(store: store));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Utang'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New utang'));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextField, 'Who borrowed? e.g. Juan'), 'Ben');
    await tester.enterText(find.widgetWithText(TextField, '0.00'), '300');
    // The save button sits below the fold of the sheet in the test viewport.
    await tester.ensureVisible(find.text('Save utang'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save utang'));
    await tester.pumpAndSettle();

    expect(find.text('Ben'), findsOneWidget);
    expect((store.data['receivables'] as List).length, 2);
  });
}
