// Smoke test: the app boots, shows the brand, the empty-state import path,
// and the update stamp. The stamp matters because it is how the founder
// verifies which build arrived, so a build where it vanished must fail CI.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/screens/menu.dart';
import 'package:salapify/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/app_harness.dart';

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
    // First run (empty store) shows the welcome card with the lane picker, and
    // the backup import as a quiet link for a migrating tester.
    expect(find.text('WELCOME'), findsOneWidget);
    expect(find.text('Track my spending'), findsOneWidget);
    expect(find.text('Coming from the old app? Import a backup'), findsOneWidget);
    // The stamp and the full import screen now live under the Menu tab, off
    // the decluttered dashboard.
    // Scrolled to separately, because they sit far apart in a long lazy list
    // and asserting both after ONE scroll was really asserting that they
    // happened to be on screen together. They are not, and a padding change
    // was enough to prove it. What matters is that each is reachable.
    await openMenu(tester);
    await scrollTo(tester, find.text('Import backup'),
        scope: find.byType(MenuScreen));
    expect(find.text('Import backup'), findsOneWidget);

    await scrollTo(tester, find.text('Update stamp'),
        scope: find.byType(MenuScreen));
    expect(find.text('Update stamp'), findsOneWidget);
    expect(find.textContaining(RegExp(r'f\d+\.')), findsOneWidget);
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

  testWidgets('a due-soon check-in lands on the Utang tab, bottom bar intact',
      (tester) async {
    // A card due today (dueDay = today) is a debtdue decision at prio 92, the
    // top of the check-in here. Its route is /debts, whose home is the Utang
    // tab's "I owe" segment. It used to push a standalone DebtsScreen, which
    // showed the right content with NO bottom bar: a copy of the tab the
    // user could not tab away from.
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
    // The debts content is showing. PAYOFF PLAN alone cannot tell the tab
    // from the old pushed copy (both render DebtsView), so the assertion
    // that carries the fix is the NavigationBar: visible on the tab,
    // covered by a pushed route.
    expect(find.text('PAYOFF PLAN'), findsOneWidget);
    expect(
      find.byType(NavigationBar),
      findsOneWidget,
      reason:
          'The check-in must land on the Utang tab, not push a standalone '
          'copy of it with no bottom bar.',
    );
  });

  testWidgets('a fresh empty app shows no money check-in yet', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = SalapifyStore();
    await tester.pumpWidget(SalapifyApp(store: store));
    await tester.pumpAndSettle();
    expect(find.text('MONEY CHECK-IN'), findsNothing);
  });
}
