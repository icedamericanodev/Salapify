// The Accounts flow: add an account, change its balance (which posts a
// recorded adjustment through the golden ledger and moves the balance), and
// delete it (entries stay, the account row goes). Money math itself is locked
// in accounts_golden_test and ledger tests; this covers the screen + writes.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/screens/accounts.dart';
import 'package:shared_preferences/shared_preferences.dart';

List _accounts(SalapifyStore s) => s.data['accounts'] as List;
List _txs(SalapifyStore s) => s.data['transactions'] as List;

void main() {
  testWidgets('add an account, adjust its balance, then delete it',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = SalapifyStore();
    await store.load();
    await tester.pumpWidget(MaterialApp(home: AccountsScreen(store: store)));
    await tester.pumpAndSettle();

    // Add.
    await tester.tap(find.text('+ Account'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'GCash');
    await tester.enterText(find.byType(TextField).at(1), '5000');
    await tester.ensureVisible(find.text('Save'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(_accounts(store).length, 1);
    expect((_accounts(store).first as Map)['balance'], 5000.0);
    expect(find.text('GCash'), findsOneWidget);

    // Edit balance up: posts a Balance adjustment and moves the balance.
    await tester.tap(find.text('GCash'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(1), '6000');
    await tester.ensureVisible(find.text('Save'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect((_accounts(store).first as Map)['balance'], 6000.0);
    expect(
        _txs(store).any((t) =>
            t is Map &&
            t['type'] == 'adjustment' &&
            t['label'] == 'Balance adjustment'),
        isTrue);

    // Delete.
    await tester.tap(find.text('GCash'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tap again to delete'));
    await tester.pumpAndSettle();

    expect(_accounts(store).isEmpty, isTrue);
    // The recorded adjustment entry stays; only the account row is gone.
    expect(_txs(store).isNotEmpty, isTrue);
  });

  testWidgets('an imported asset with a numeric id edits without crashing',
      (tester) async {
    // Regression: assets were not covered by the id-hardening, so a numeric id
    // crashed the edit on the `as String` cast. ensureEntityIds now normalizes
    // asset ids on load, and the screen guards the cast.
    SharedPreferences.setMockInitialValues({
      'salapify_data_v2': jsonEncode({
        'assets': [
          {'id': 42, 'name': 'BTC', 'kind': 'crypto', 'value': 1000.0},
        ],
      }),
    });
    final store = SalapifyStore();
    await store.load();
    // Load normalized the numeric id to a string.
    expect((_rowId(store)), isA<String>());

    await tester.pumpWidget(MaterialApp(home: AccountsScreen(store: store)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('BTC'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(1), '1500');
    await tester.ensureVisible(find.text('Save'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final assets = store.data['assets'] as List;
    expect(assets.length, 1);
    expect((assets.first as Map)['value'], 1500.0);
  });
}

String? _rowId(SalapifyStore s) {
  final a = (s.data['assets'] as List).first as Map;
  return a['id'] is String ? a['id'] as String : null;
}
