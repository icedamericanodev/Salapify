// Smoke test: the app boots, shows the brand, the empty-state import path,
// and the update stamp. The stamp matters because it is how the founder
// verifies which build arrived, so a build where it vanished must fail CI.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

String _today(int day) {
  final now = DateTime.now();
  final d = day <= now.day ? day : now.day;
  return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}';
}

void main() {
  testWidgets('overview shows the brand, import path, and the update stamp',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = SalapifyStore();
    await tester.pumpWidget(SalapifyApp(store: store));
    await tester.pumpAndSettle();
    expect(find.text('SALAPIFY'), findsOneWidget);
    expect(find.text('NET WORTH'), findsOneWidget);
    // The stamp card sits at the bottom of the list, so scroll it into build.
    await tester.scrollUntilVisible(find.text('Update stamp'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Update stamp'), findsOneWidget);
    expect(find.textContaining('f0.'), findsOneWidget);
    expect(find.text('Import backup'), findsOneWidget);
  });

  testWidgets('Home surfaces the top money decision and it jumps to its tab',
      (tester) async {
    // Spending passed income (overspend, prio 85) and Migs is years overdue
    // (utang, prio 90), so the check-in shows the utang decision, which is
    // tappable and jumps to the Utang tab.
    SharedPreferences.setMockInitialValues({
      storageKey: jsonEncode({
        'schemaVersion': 12,
        'accounts': [
          {'id': 'cash', 'name': 'Cash', 'kind': 'cash', 'balance': 3000},
        ],
        'transactions': [
          {'id': 'i1', 'type': 'income', 'label': 'Sweldo', 'amount': 5000,
              'date': _today(15), 'accountId': 'cash'},
          {'id': 'e1', 'type': 'expense', 'label': 'Milk tea',
              'amount': 6600, 'date': _today(8)},
        ],
        'people': [
          {'id': 'p1', 'name': 'Migs'},
        ],
        'receivables': [
          {'id': 'r1', 'personId': 'p1', 'person': 'Migs', 'amount': 1500,
              'payments': [], 'paid': false, 'dueDate': '2020-01-01'},
        ],
        'settings': {'monthlyLimit': 5000},
      }),
    });
    final store = SalapifyStore();
    await tester.pumpWidget(SalapifyApp(store: store));
    await tester.pumpAndSettle();

    expect(find.text('MONEY CHECK-IN'), findsOneWidget);
    expect(find.text('Follow up Migs'), findsOneWidget);
    await tester.tap(find.text('Follow up Migs'));
    await tester.pumpAndSettle();
    expect(find.text('STILL OUT'), findsOneWidget);
  });

  testWidgets('a fresh empty app shows no money check-in yet', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = SalapifyStore();
    await tester.pumpWidget(SalapifyApp(store: store));
    await tester.pumpAndSettle();
    expect(find.text('MONEY CHECK-IN'), findsNothing);
  });
}
