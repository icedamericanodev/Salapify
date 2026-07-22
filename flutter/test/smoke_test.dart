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
    // First run (empty store) shows the welcome/import card, not the hero.
    expect(find.text('WELCOME'), findsOneWidget);
    expect(find.text('Import my backup'), findsOneWidget);
    // The stamp and the full import screen now live under the Menu tab, off
    // the decluttered dashboard.
    await tester.tap(find.text('Menu'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Update stamp'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Update stamp'), findsOneWidget);
    expect(find.textContaining(RegExp(r'f\d+\.')), findsOneWidget);
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

  testWidgets('a due-soon check-in is not a dead end, it opens Debts',
      (tester) async {
    // A card due today (dueDay = today) is a debtdue decision at prio 92, the
    // top of the check-in here. Its route is /debts, which is not a bottom
    // tab, so the card must push the Debts screen instead of doing nothing.
    final dueDay = DateTime.now().day;
    SharedPreferences.setMockInitialValues({
      storageKey: jsonEncode({
        'schemaVersion': 12,
        'accounts': [
          {'id': 'cash', 'name': 'Cash', 'kind': 'cash', 'balance': 50000},
        ],
        'debts': [
          {'id': 'd1', 'name': 'BPI card', 'type': 'credit card',
              'remaining': 12000, 'monthlyRate': 3, 'minPayment': 500,
              'dueDay': dueDay},
        ],
        'settings': <String, dynamic>{},
      }),
    });
    final store = SalapifyStore();
    await tester.pumpWidget(SalapifyApp(store: store));
    await tester.pumpAndSettle();

    expect(find.text('MONEY CHECK-IN'), findsOneWidget);
    expect(find.textContaining('due soon'), findsOneWidget);
    await tester.tap(find.textContaining('due soon'));
    await tester.pumpAndSettle();
    // The Debts screen pushed over Home shows its payoff-plan section.
    expect(find.text('PAYOFF PLAN'), findsOneWidget);
  });

  testWidgets('a fresh empty app shows no money check-in yet', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = SalapifyStore();
    await tester.pumpWidget(SalapifyApp(store: store));
    await tester.pumpAndSettle();
    expect(find.text('MONEY CHECK-IN'), findsNothing);
  });
}
