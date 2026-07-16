// The first write path: logging an entry must move balances through the
// golden-verified engine, persist across a store reload, and update the UI.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> seedBlob() => {
      'schemaVersion': 12,
      'accounts': [
        {'id': 'cash', 'name': 'Cash', 'kind': 'cash', 'balance': 1000},
        {'id': 'bank', 'name': 'Bank', 'kind': 'bank', 'balance': 5000},
      ],
      'transactions': <Map<String, dynamic>>[],
    };

void main() {
  testWidgets('logging an expense moves the account and this month',
      (tester) async {
    SharedPreferences.setMockInitialValues(
        {storageKey: jsonEncode(seedBlob())});
    final store = SalapifyStore();
    await tester.pumpWidget(SalapifyApp(store: store));
    await tester.pumpAndSettle();

    // Net worth starts at 6,000 and Cash shows 1,000.
    expect(find.text('₱6,000'), findsOneWidget);
    expect(find.text('₱1,000'), findsOneWidget);

    await tester.tap(find.text('Log'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), '250');
    await tester.enterText(find.byType(TextField).at(1), 'Groceries');
    await tester.tap(find.widgetWithText(ChoiceChip, 'Cash'));
    await tester.pump();
    await tester.tap(find.text('Save entry'));
    await tester.pumpAndSettle();

    // Cash 1,000 - 250 = 750; net worth 5,750; this month spending 250.
    expect(find.text('₱750'), findsOneWidget);
    expect(find.text('₱5,750'), findsOneWidget);
    expect(find.text('₱250'), findsWidgets);

    // And it persisted: a brand new store instance reads the same state.
    final fresh = SalapifyStore();
    await fresh.load();
    final txs = (fresh.data['transactions'] as List);
    expect(txs.length, 1);
    expect((txs.first as Map)['label'], 'Groceries');
    final cash = (fresh.data['accounts'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((a) => a['id'] == 'cash');
    expect(cash['balance'], 750);
  });

  testWidgets('a junk amount is refused, nothing is saved', (tester) async {
    SharedPreferences.setMockInitialValues(
        {storageKey: jsonEncode(seedBlob())});
    final store = SalapifyStore();
    await tester.pumpWidget(SalapifyApp(store: store));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Log'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save entry'));
    await tester.pump();

    expect(find.text('Enter an amount above zero.'), findsOneWidget);
    expect((store.data['transactions'] as List), isEmpty);
  });
}
