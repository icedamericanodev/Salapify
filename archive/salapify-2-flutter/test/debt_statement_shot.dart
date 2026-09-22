// Founder specimen for f4.66: the "Your debts in one place" screen. NOT a
// `_test` file. Run with --update-goldens and LOOK.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:salapify/data/store.dart' show SalapifyStore, storageKey;
import 'package:salapify/screens/debt_statement.dart';
import 'package:salapify/theme.dart';

import 'screens_shot.dart' show loadRealFonts;

void main() {
  testWidgets('the debts-in-one-place screen, dark', (tester) async {
    await loadRealFonts(tester);
    final blob = {
      'schemaVersion': 12,
      'settings': {'onboarded': true},
      'debts': [
        {
          'id': 'a',
          'name': 'UnionBank Platinum',
          'type': 'credit card',
          'remaining': 38450,
          'minPayment': 1922.50,
          'monthlyRate': 3.0,
          'creditLimit': 60000,
          'dueDay': 8,
        },
        {
          'id': 'b',
          'name': 'BDO Titanium',
          'type': 'credit card',
          'remaining': 64200,
          'minPayment': 3210,
          'monthlyRate': 3.0,
          'creditLimit': 120000,
          'dueDay': 25,
        },
        {
          'id': 'c',
          'name': 'Shopee PayLater',
          'type': 'bnpl',
          'remaining': 12800,
          'minPayment': 2560,
          'monthlyRate': 3.5,
          'dueDay': 20,
        },
        {
          'id': 'd',
          'name': 'Home Credit Loan',
          'type': 'personal loan',
          'remaining': 24500,
          'minPayment': 2750,
          'monthlyRate': 2.375,
          'dueDay': 28,
        },
      ],
    };
    SharedPreferences.setMockInitialValues({storageKey: jsonEncode(blob)});
    Barako.currentTheme = themeForKey('palawan');
    Barako.current = themeForKey('palawan').resolve(Brightness.dark);
    tester.view.physicalSize = const Size(1170, 3200);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final store = SalapifyStore();
    await store.load();

    await tester.pumpWidget(
      MaterialApp(
        theme: salapifyTheme(Barako.current),
        debugShowCheckedModeBanner: false,
        home: DebtStatementScreen(store: store),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('shots/debt-statement-dark.png'),
    );
  });
}
