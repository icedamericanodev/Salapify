// Founder specimen for f4.67: the "Bills and spending" screen. NOT a `_test`
// file. Run with --update-goldens and LOOK. Seeded so all three sections show
// real figures: a committed-vs-everyday split, recurring bills, and a due-date
// radar populated with items landing before the default semimonthly payday.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:salapify/data/store.dart' show SalapifyStore, storageKey;
import 'package:salapify/screens/bills_spending.dart';
import 'package:salapify/theme.dart';

import 'screens_shot.dart' show loadRealFonts;

void main() {
  testWidgets('the bills-and-spending screen, dark', (tester) async {
    await loadRealFonts(tester);
    // Dated in the current month so "this month" spending is non-empty, with a
    // bill (day 28) and a debt minimum (day 27) due before the Aug 31 payday.
    final blob = {
      'schemaVersion': 12,
      'settings': {'onboarded': true},
      'accounts': [
        {'id': 'a1', 'name': 'Cash', 'kind': 'cash', 'balance': 8400},
      ],
      'debts': [
        {
          'id': 'd1',
          'name': 'UnionBank Platinum',
          'type': 'credit card',
          'remaining': 38450,
          'minPayment': 1922.50,
          'monthlyRate': 3.0,
          'dueDay': 27,
        },
      ],
      'recurring': [
        {'id': 'r1', 'type': 'expense', 'amount': 12000, 'dayOfMonth': 5, 'label': 'Rent', 'lastPosted': '2026-08'},
        {'id': 'r2', 'type': 'expense', 'amount': 1899, 'dayOfMonth': 28, 'label': 'Meralco'},
        {'id': 'r3', 'type': 'expense', 'amount': 549, 'dayOfMonth': 20, 'label': 'Netflix and Spotify', 'lastPosted': '2026-08'},
        {'id': 'r4', 'type': 'income', 'amount': 42000, 'dayOfMonth': 15, 'label': 'Salary'},
      ],
      'transactions': [
        {'id': 't1', 'type': 'expense', 'amount': 12000, 'date': '2026-08-05', 'recurringId': 'r1', 'label': 'Rent'},
        {'id': 't2', 'type': 'expense', 'amount': 549, 'date': '2026-08-20', 'recurringId': 'r3', 'label': 'Netflix and Spotify'},
        {'id': 't3', 'type': 'expense', 'amount': 1922.50, 'date': '2026-08-10', 'debtId': 'd1', 'label': 'Card payment'},
        {'id': 't4', 'type': 'expense', 'amount': 3250, 'date': '2026-08-12', 'label': 'Groceries'},
        {'id': 't5', 'type': 'expense', 'amount': 1480, 'date': '2026-08-18', 'label': 'Dining out'},
        {'id': 't6', 'type': 'expense', 'amount': 900, 'date': '2026-08-22', 'label': 'Grab rides'},
      ],
    };
    SharedPreferences.setMockInitialValues({storageKey: jsonEncode(blob)});
    Barako.currentTheme = themeForKey('palawan');
    Barako.current = themeForKey('palawan').resolve(Brightness.dark);
    tester.view.physicalSize = const Size(1170, 2800);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final store = SalapifyStore();
    await store.load();

    await tester.pumpWidget(
      MaterialApp(
        theme: salapifyTheme(Barako.current),
        debugShowCheckedModeBanner: false,
        home: BillsSpendingScreen(store: store),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('shots/bills-spending-dark.png'),
    );
  });
}
