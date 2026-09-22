// Phase 4 batch 2, the receipt:
//  1. Tapping a row opens a RECEIPT (amount headline, fact rows, Edit and
//     Delete underneath), never a form with a blinking cursor.
//  2. A transfer receipt shows From and To as fact rows.
//  3. Delete on the receipt really deletes, restores the balance through the
//     same engine path as the swipe, and offers Undo.
//  4. A locked record's receipt keeps the explainer and offers no Edit or
//     Delete.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/screens/history.dart';
import 'package:shared_preferences/shared_preferences.dart';

String _iso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

Future<SalapifyStore> _boot(WidgetTester tester) async {
  final today = DateTime.now();
  SharedPreferences.setMockInitialValues({
    storageKey: jsonEncode({
      'schemaVersion': 12,
      'settings': {'onboarded': true},
      'accounts': [
        {'id': 'gcash', 'name': 'GCash', 'kind': 'ewallet', 'balance': 5000},
        {
          'id': 'bpi',
          'name': 'BPI Savings',
          'kind': 'savings',
          'balance': 20000,
        },
      ],
      'categories': [
        {'id': 'c-food', 'name': 'Food', 'icon': '🍔'},
      ],
      'transactions': [
        {
          'id': 'e1',
          'type': 'expense',
          'label': 'Jollibee',
          'amount': 250,
          'date': _iso(today),
          'accountId': 'gcash',
          'categoryId': 'c-food',
        },
        {
          'id': 't1',
          'type': 'transfer',
          'label': 'Cash to Bank',
          'amount': 1000,
          'date': _iso(today),
          'transferFromId': 'gcash',
          'transferToId': 'bpi',
        },
      ],
    }),
  });
  final store = SalapifyStore();
  await store.load();
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: HistoryScreen(store: store, onMenu: () {}),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return store;
}

void main() {
  testWidgets('a row opens the receipt, and Edit sits one tap deeper', (
    tester,
  ) async {
    await _boot(tester);
    await tester.tap(find.text('Jollibee'));
    await tester.pumpAndSettle();
    expect(find.text('Edit entry'), findsOneWidget);
    expect(find.text('Delete entry'), findsOneWidget);
    expect(find.text('Food'), findsOneWidget, reason: 'the category fact row');
    expect(
      find.text('Save changes'),
      findsNothing,
      reason: 'reading a transaction must not land in a form',
    );
    await tester.tap(find.text('Edit entry'));
    await tester.pumpAndSettle();
    expect(find.text('Save changes'), findsOneWidget);
  });

  testWidgets('a transfer receipt shows From and To', (tester) async {
    await _boot(tester);
    await tester.tap(find.text('Cash to Bank'));
    await tester.pumpAndSettle();
    expect(find.text('From'), findsOneWidget);
    expect(find.text('To'), findsOneWidget);
    expect(find.text('GCash'), findsOneWidget);
    expect(find.text('BPI Savings'), findsOneWidget);
    expect(
      find.text('Edit entry'),
      findsNothing,
      reason: 'a record cannot be edited and its receipt offers no editor',
    );
    expect(find.text('Delete entry'), findsNothing);
    expect(find.textContaining('cannot be edited'), findsOneWidget);
  });

  testWidgets('Delete on the receipt deletes, moves the balance back, and '
      'offers Undo', (tester) async {
    final store = await _boot(tester);
    await tester.tap(find.text('Jollibee'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete entry'));
    await tester.pumpAndSettle();
    expect(
      (store.data['transactions'] as List).any((t) => t['id'] == 'e1'),
      isFalse,
      reason: 'the receipt delete must go through the real engine path',
    );
    final gcash = (store.data['accounts'] as List).firstWhere(
      (a) => a['id'] == 'gcash',
    );
    expect(
      (gcash['balance'] as num).toDouble(),
      5250.0,
      reason: 'deleting the expense gives the account its money back',
    );
    expect(find.text('Undo'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(
      (store.data['transactions'] as List).any((t) => t['id'] == 'e1'),
      isTrue,
      reason: 'Undo restores the entry',
    );
  });
}
