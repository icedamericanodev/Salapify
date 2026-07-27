// Every monetary write shows what happened, and the main Log sheet is no
// exception. It was: the single most used write path in the app saved in
// silence while the Budget quick add showed a receipt and an Undo. A
// fat-fingered ₱25000 for ₱2500 had no escape hatch exactly where mistakes
// are most likely.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _blob() => {
  'schemaVersion': 12,
  'accounts': [
    {'id': 'cash', 'name': 'Cash', 'kind': 'cash', 'balance': 1000},
  ],
  'transactions': <Map<String, dynamic>>[],
};

Future<void> _logExpense(WidgetTester tester) async {
  await tester.tap(find.text('Log'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField).at(0), '250');
  await tester.enterText(find.byType(TextField).at(1), 'Groceries');
  await tester.tap(find.widgetWithText(ChoiceChip, 'Cash'));
  await tester.pump();
  await tester.tap(find.text('Save entry'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      storageKey: jsonEncode(_blob()),
    });
  });

  testWidgets('saving from the Log sheet shows a receipt', (tester) async {
    final store = SalapifyStore();
    await tester.pumpWidget(SalapifyApp(store: store));
    await tester.pumpAndSettle();

    await _logExpense(tester);

    expect(
      find.text('Groceries ₱250 logged.'),
      findsOneWidget,
      reason:
          'The Log sheet saved without a receipt. Monetary writes show what '
          'happened; the Budget quick add already does, and the main write '
          'path must not be the one exception.',
    );
  });

  testWidgets('the receipt Undo really removes the entry', (tester) async {
    // Tall viewport so the lazy Home column builds the MY MONEY rows; the
    // balance assertion at the end reads them. Same reason as log_entry_test.
    tester.view.physicalSize = const Size(1200, 3600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final store = SalapifyStore();
    await tester.pumpWidget(SalapifyApp(store: store));
    await tester.pumpAndSettle();

    await _logExpense(tester);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    final txs = store.data['transactions'] as List;
    expect(
      txs,
      isEmpty,
      reason: 'Undo left the entry in the store. The receipt promised an '
          'escape hatch it did not deliver.',
    );
    // And the balance is whole again on screen. findsWidgets, not one: with
    // no debts, net worth equals total assets and the same figure renders
    // more than once on purpose, same as log_entry_test documents.
    expect(find.text('₱1,000'), findsWidgets);
  });
}
