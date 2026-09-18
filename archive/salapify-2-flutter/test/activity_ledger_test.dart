// Phase 4 batch 1, the Activity ledger:
//  1. One card per DAY, not per transaction: the rows of a day share a card
//     with hairline dividers, so a screen shows roughly twice the rows.
//  2. A money-move row names its two ends ("From GCash to BPI Savings") from
//     the entry's own account ids, and the old repeated read-only sentence is
//     gone from the list.
//  3. The row's semantics speak the WHOLE row, money and direction included,
//     not just "Edit <label>".
//  4. The first-run empty state opens the Log sheet, not just describes the
//     room.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/screens/history.dart';
import 'package:shared_preferences/shared_preferences.dart';

String _iso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

Future<SalapifyStore> _boot(
  WidgetTester tester, {
  List<Map<String, dynamic>>? transactions,
}) async {
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
      'transactions':
          transactions ??
          [
            {
              'id': 'e1',
              'type': 'expense',
              'label': 'Jollibee',
              'amount': 250,
              'date': _iso(today),
              'accountId': 'gcash',
            },
            {
              'id': 'e2',
              'type': 'income',
              'label': 'Salary',
              'amount': 32000,
              'date': _iso(today),
              'accountId': 'bpi',
            },
            {
              'id': 'e3',
              'type': 'expense',
              'label': 'Grab',
              'amount': 180,
              'date': _iso(today.subtract(const Duration(days: 1))),
              'accountId': 'gcash',
            },
            {
              'id': 't1',
              'type': 'transfer',
              'label': '',
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
  testWidgets('rows share one card per day with dividers between', (
    tester,
  ) async {
    await _boot(tester);
    expect(
      find.byType(Card),
      findsNWidgets(2),
      reason:
          'four entries across two days must produce exactly two day cards, '
          'not a card per transaction',
    );
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Yesterday'), findsOneWidget);
  });

  testWidgets('a money move names its two ends and drops the old sentence', (
    tester,
  ) async {
    await _boot(tester);
    expect(find.text('From GCash to BPI Savings'), findsOneWidget);
    expect(find.text('Transfer'), findsOneWidget, reason: 'capitalized title');
    expect(find.text('Record of a money move, read-only here'), findsNothing);
  });

  testWidgets('the row semantics speak label, direction, and amount', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _boot(tester);
    expect(
      find.bySemanticsLabel(RegExp(r'Jollibee, expense, ₱250')),
      findsOneWidget,
      reason:
          'a screen-reader user hears the money and its direction with the '
          'row, not just "Edit Jollibee"',
    );
    expect(
      find.bySemanticsLabel(RegExp(r'Salary, income, ₱32,000')),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('the first-run empty state opens the Log sheet', (tester) async {
    await _boot(tester, transactions: []);
    final cta = find.text('Log your first entry');
    expect(cta, findsOneWidget);
    await tester.tap(cta);
    await tester.pumpAndSettle();
    expect(
      find.text('Save entry'),
      findsOneWidget,
      reason: 'the CTA must really open the Log sheet',
    );
  });
}
