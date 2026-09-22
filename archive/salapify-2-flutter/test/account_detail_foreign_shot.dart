// Founder specimen for f4.70: a FOREIGN-currency account's detail. NOT a
// `_test` file. Confirms the balance and card face now show the account's own
// symbol ($) rather than a peso sign.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:salapify/data/store.dart' show SalapifyStore, storageKey;
import 'package:salapify/money/account_taxonomy.dart' show AccountStore;
import 'package:salapify/screens/account_detail.dart';
import 'package:salapify/theme.dart';

import 'screens_shot.dart' show loadRealFonts;

void main() {
  testWidgets('a US-dollar account detail shows its own symbol, dark', (
    tester,
  ) async {
    await loadRealFonts(tester);
    final blob = {
      'schemaVersion': 12,
      'settings': {'onboarded': true, 'currencyCode': 'PHP'},
      'accounts': [
        {
          'id': 'usd1',
          'name': 'US Dollar savings',
          'kind': 'savings',
          'balance': 1000,
          'currencyCode': 'USD',
          'target': 2000,
        },
      ],
    };
    SharedPreferences.setMockInitialValues({storageKey: jsonEncode(blob)});
    Barako.currentTheme = themeForKey('palawan');
    Barako.current = themeForKey('palawan').resolve(Brightness.dark);
    tester.view.physicalSize = const Size(1170, 2200);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final store = SalapifyStore();
    await store.load();

    await tester.pumpWidget(
      MaterialApp(
        theme: salapifyTheme(Barako.current),
        debugShowCheckedModeBanner: false,
        home: AccountDetailScreen(
          store: store,
          id: 'usd1',
          accountStore: AccountStore.accounts,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('shots/account-detail-usd-dark.png'),
    );
  });
}
