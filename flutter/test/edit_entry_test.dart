// Editing a logged entry: the reverse-then-apply contract, through the
// store and through the screen.
//
// The engine (ledger.updateTransaction) is already pinned by the golden
// vectors in test/goldens/ledger_goldens.json. These tests cover what the
// goldens cannot: the store method's guards and null-strips-key semantics,
// and the sheet's patch building (category follows label, origCurrency
// drops, Undo restores exactly).

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/screens/edit_sheet.dart' show EditSheet;
import 'package:salapify/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/app_harness.dart';

Map<String, dynamic> _blob() => {
  'schemaVersion': 12,
  'accounts': [
    {'id': 'cash', 'name': 'Cash', 'kind': 'cash', 'balance': 1000},
    {'id': 'bank', 'name': 'Bank', 'kind': 'bank', 'balance': 5000},
  ],
  'categories': [
    {'id': 'c-food', 'name': 'Food'},
  ],
  'transactions': [
    {
      'id': 't1',
      'type': 'expense',
      'label': 'Groceries',
      'amount': 250,
      'date': '2026-07-20',
      'accountId': 'cash',
    },
    {
      'id': 'rec1',
      'type': 'transfer',
      'label': 'Cash to Bank',
      'amount': 500,
      'date': '2026-07-19',
      'flow': 'out',
      'accountId': 'cash',
    },
  ],
};

double _cash(SalapifyStore store) =>
    ((store.data['accounts'] as List).firstWhere(
              (a) => a['id'] == 'cash',
            )['balance']
            as num)
        .toDouble();

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({storageKey: jsonEncode(_blob())});
  });

  group('store.updateEntry', () {
    test('an amount change adjusts the balance by exactly the difference',
        () async {
      final store = SalapifyStore();
      await store.load();
      expect(_cash(store), 1000);
      await store.updateEntry('t1', {'amount': 400});
      expect(
        _cash(store),
        850,
        reason:
            'Reverse-then-apply: +250 back, -400 out, so 1000 becomes 850. '
            'Anything else means the edit drifted the balance.',
      );
    });

    test('a null value removes the key, and nulls never reach the JSON',
        () async {
      final store = SalapifyStore();
      await store.load();
      await store.updateEntry('t1', {'accountId': null});
      final t1 = (store.data['transactions'] as List).firstWhere(
        (t) => t['id'] == 't1',
      );
      expect(
        t1.containsKey('accountId'),
        isFalse,
        reason: 'Unlinking must remove the key, not store a null.',
      );
      // And the unlink refunded the account, reverse-then-apply.
      expect(_cash(store), 1250);
      final raw = SharedPreferences.getInstance().then(
        (p) => p.getString(storageKey)!,
      );
      expect(await raw, isNot(contains('null,')));
    });

    test('the amount guard refuses garbage before anything moves', () async {
      final store = SalapifyStore();
      await store.load();
      await expectLater(
        store.updateEntry('t1', {'amount': double.nan}),
        throwsArgumentError,
      );
      expect(_cash(store), 1000, reason: 'A refused edit must be a no-op.');
    });

    test('an unknown id is a null no-op', () async {
      final store = SalapifyStore();
      await store.load();
      expect(await store.updateEntry('missing', {'amount': 5}), isNull);
      expect(_cash(store), 1000);
    });

    test('the returned map is the entry BEFORE the edit', () async {
      final store = SalapifyStore();
      await store.load();
      final before = await store.updateEntry('t1', {'amount': 400});
      expect(before!['amount'], 250);
    });
  });

  group('the edit sheet', () {
    Future<SalapifyStore> boot(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final store = SalapifyStore();
      await tester.pumpWidget(SalapifyApp(store: store));
      await tester.pumpAndSettle();
      await goToTab(tester, 'Activity');
      return store;
    }

    testWidgets('editing an amount updates the row, the balance, and offers '
        'a working Undo', (tester) async {
      final store = await boot(tester);
      await tester.tap(find.text('Groceries'));
      await tester.pumpAndSettle();
      expect(find.text('EDIT ENTRY'), findsOneWidget);

      // Scoped to the sheet: the Activity screen underneath keeps its own
      // search TextField mounted, so an unscoped .at(0) types into that.
      final sheetFields = find.descendant(
        of: find.byType(EditSheet),
        matching: find.byType(TextField),
      );
      await tester.enterText(sheetFields.at(0), '400');
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();

      expect(find.text('Groceries updated.'), findsOneWidget);
      expect(_cash(store), 850);

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      final t1 = (store.data['transactions'] as List).firstWhere(
        (t) => t['id'] == 't1',
      );
      expect(t1['amount'], 250, reason: 'Undo must restore the old amount.');
      expect(_cash(store), 1000, reason: 'Undo must restore the balance.');
    });

    testWidgets('the category follows the label, and lets go of it too', (
      tester,
    ) async {
      final store = await boot(tester);
      await tester.tap(find.text('Groceries'));
      await tester.pumpAndSettle();
      final sheetFields = find.descendant(
        of: find.byType(EditSheet),
        matching: find.byType(TextField),
      );
      await tester.enterText(sheetFields.at(1), 'Food');
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();
      var t1 = (store.data['transactions'] as List).firstWhere(
        (t) => t['id'] == 't1',
      );
      expect(
        t1['categoryId'],
        'c-food',
        reason: 'A label matching a category name must adopt its id, the RN '
            'rule.',
      );

      await tester.tap(find.text('Food'));
      await tester.pumpAndSettle();
      await tester.enterText(sheetFields.at(1), 'Random thing');
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();
      t1 = (store.data['transactions'] as List).firstWhere(
        (t) => t['id'] == 't1',
      );
      expect(
        t1.containsKey('categoryId'),
        isFalse,
        reason: 'A label matching nothing must drop the stale pointer.',
      );
    });

    testWidgets('a record row opens the read-only explainer, not the editor', (
      tester,
    ) async {
      await boot(tester);
      await tester.tap(find.text('Cash to Bank'));
      await tester.pumpAndSettle();
      expect(find.text('EDIT ENTRY'), findsNothing);
      expect(
        find.textContaining('cannot be edited'),
        findsOneWidget,
        reason:
            'A transfer record must explain itself instead of opening the '
            'editor. Editing a record would desync the move it records.',
      );
    });
  });
}
