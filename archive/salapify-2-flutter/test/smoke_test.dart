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
  testWidgets('overview shows the brand, import path, and the update stamp', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(onboardedEmptyStorage());
    final store = SalapifyStore();
    await tester.pumpWidget(SalapifyApp(store: store));
    await tester.pumpAndSettle();
    expect(find.text('SALAPIFY'), findsOneWidget);
    // First run (empty store) shows the welcome card with the lane picker, and
    // the backup import as a quiet link for a migrating tester.
    expect(find.text('WELCOME'), findsOneWidget);
    expect(find.text('Track my spending'), findsOneWidget);
    expect(
      find.text('Coming from the old app? Import a backup'),
      findsOneWidget,
    );
    // The stamp and the full import screen now live under the Menu tab, off
    // the decluttered dashboard.
    // Scrolled to separately, because they sit far apart in a long lazy list
    // and asserting both after ONE scroll was really asserting that they
    // happened to be on screen together. They are not, and a padding change
    // was enough to prove it. What matters is that each is reachable.
    await openMenu(tester);
    await scrollTo(
      tester,
      find.text('Import backup'),
      scope: find.byType(MenuScreen),
    );
    expect(find.text('Import backup'), findsOneWidget);

    await scrollTo(
      tester,
      find.text('Update stamp'),
      scope: find.byType(MenuScreen),
    );
    expect(find.text('Update stamp'), findsOneWidget);
    expect(find.textContaining(RegExp(r'f\d+\.')), findsOneWidget);
  });

  testWidgets('Home surfaces the top money decision and it jumps to its tab', (
    tester,
  ) async {
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
          {
            'id': 'i1',
            'type': 'income',
            'label': 'Sweldo',
            'amount': 5000,
            'date': _today(15),
            'accountId': 'cash',
          },
          {
            'id': 'e1',
            'type': 'expense',
            'label': 'Milk tea',
            'amount': 6600,
            'date': _today(8),
          },
        ],
        'people': [
          {'id': 'p1', 'name': 'Migs'},
        ],
        'receivables': [
          {
            'id': 'r1',
            'personId': 'p1',
            'person': 'Migs',
            'amount': 1500,
            'payments': [],
            'paid': false,
            'dueDate': '2020-01-01',
          },
        ],
        'settings': {'monthlyLimit': 5000},
      }),
    });
    // Tall view so the lazily built Home ListView reaches the check-in card,
    // which now sits below the dashboard-first Net Worth hero and Quick
    // Overview. Non-urgent decisions render below the dashboard by design; a
    // money crunch still leads (home_order_test's urgent group).
    tester.view.physicalSize = const Size(1200, 4600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final store = SalapifyStore();
    await tester.pumpWidget(SalapifyApp(store: store));
    await tester.pumpAndSettle();

    expect(find.text('MONEY CHECK-IN'), findsOneWidget);
    expect(find.text('Follow up Migs'), findsOneWidget);
    await tester.tap(find.text('Follow up Migs'));
    await tester.pumpAndSettle();
    expect(find.text('STILL UNPAID'), findsOneWidget);
  });

  testWidgets('a due-soon check-in opens the Utang I owe screen', (
    tester,
  ) async {
    // A card due today (dueDay = today) is a debtdue decision at prio 92, the
    // top of the check-in here. Its route is /debts, whose home is the Utang
    // "I owe" segment. It once pushed a standalone DebtsScreen, a bare copy
    // with none of the Utang screen's segment control around it.
    final dueDay = DateTime.now().day;
    SharedPreferences.setMockInitialValues({
      storageKey: jsonEncode({
        'schemaVersion': 12,
        'accounts': [
          {'id': 'cash', 'name': 'Cash', 'kind': 'cash', 'balance': 50000},
        ],
        'debts': [
          {
            'id': 'd1',
            'name': 'BPI card',
            'type': 'credit card',
            'remaining': 12000,
            'monthlyRate': 3,
            'minPayment': 500,
            'dueDay': dueDay,
          },
        ],
        'settings': <String, dynamic>{},
      }),
    });
    // Tall view so the lazily built Home ListView reaches the check-in card,
    // which now sits below the dashboard-first Net Worth hero and Quick
    // Overview. Non-urgent decisions render below the dashboard by design; a
    // money crunch still leads (home_order_test's urgent group).
    tester.view.physicalSize = const Size(1200, 4600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final store = SalapifyStore();
    await tester.pumpWidget(SalapifyApp(store: store));
    await tester.pumpAndSettle();

    expect(find.text('MONEY CHECK-IN'), findsOneWidget);
    expect(find.textContaining('due soon'), findsOneWidget);
    await tester.tap(find.textContaining('due soon'));
    await tester.pumpAndSettle();
    // The debts content is showing, and it is the canonical Utang surface, not
    // a standalone DebtsScreen copy: MoneyScreen carries the "I owe" / "Owed to
    // me" segment control (PAYOFF PLAN alone cannot tell them apart, since both
    // render DebtsView). Utang left the bottom bar and is a pushed screen now,
    // so the way out is the header Back arrow rather than a bottom bar under it.
    expect(find.text('PAYOFF PLAN'), findsOneWidget);
    expect(
      find.text('Owed to me'),
      findsOneWidget,
      reason:
          'The check-in must open the full Utang screen with both segments, '
          'not a standalone DebtsScreen copy.',
    );
    expect(
      find.byTooltip('Back'),
      findsOneWidget,
      reason:
          'Utang is a pushed screen now; its header carries the way back where '
          'a bottom bar used to sit.',
    );
  });

  testWidgets('a fresh empty app shows no money check-in yet', (tester) async {
    SharedPreferences.setMockInitialValues(onboardedEmptyStorage());
    final store = SalapifyStore();
    await tester.pumpWidget(SalapifyApp(store: store));
    await tester.pumpAndSettle();
    expect(find.text('MONEY CHECK-IN'), findsNothing);
  });
}
