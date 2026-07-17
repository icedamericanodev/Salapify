// The Budget tab: the limit card renders engine numbers, a quick add logs
// through the real store with Undo restoring the balance, and the limit can
// be set from the screen.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

String _today() {
  final now = DateTime.now();
  return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
}

Map<String, dynamic> blob() => {
      'schemaVersion': 12,
      'accounts': [
        {'id': 'cash', 'name': 'Cash', 'kind': 'cash', 'balance': 5000},
      ],
      'transactions': [
        {
          'id': 't1',
          'type': 'expense',
          'label': 'Groceries',
          'amount': 1200,
          'date': _today(),
          'accountId': 'cash',
        },
      ],
      'settings': {
        'monthlyLimit': 8000,
        'defaultAccountId': 'cash',
        'quickAdds': [
          {'label': 'Food', 'amount': 150},
        ],
      },
    };

double cash(SalapifyStore store) => ((store.data['accounts'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((a) => a['id'] == 'cash')['balance'] as num)
    .toDouble();

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({storageKey: jsonEncode(blob())});
  });

  testWidgets('the limit card and a quick add with undo work end to end',
      (tester) async {
    final store = SalapifyStore();
    await tester.pumpWidget(SalapifyApp(store: store));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Budget'));
    await tester.pumpAndSettle();

    // 1,200 of 8,000, not over (the amount also shows on the category row).
    expect(find.text('₱1,200'), findsWidgets);
    expect(find.text('of ₱8,000'), findsOneWidget);
    expect(find.text('₱6,800 left this month.'), findsOneWidget);

    // Quick add from the remembered account.
    await tester.tap(find.textContaining('Food'));
    await tester.pumpAndSettle();
    expect(cash(store), 4850);
    expect((store.data['transactions'] as List).length, 2);

    // Undo restores the balance exactly.
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(cash(store), 5000);
    expect((store.data['transactions'] as List).length, 1);
  });

  testWidgets('setting the limit from the screen persists', (tester) async {
    final store = SalapifyStore();
    await tester.pumpWidget(SalapifyApp(store: store));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Budget'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Change limit'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '12000');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('of ₱12,000'), findsOneWidget);
    final fresh = SalapifyStore();
    await fresh.load();
    expect(
        ((fresh.data['settings'] as Map)['monthlyLimit'] as num).toDouble(),
        12000);
  });
}
