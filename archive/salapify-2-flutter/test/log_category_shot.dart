// Founder specimen for f4.71: the Log sheet now has a CATEGORY row for an
// expense. NOT a `_test` file. (Emoji renders as a box in the sandbox with no
// emoji font; it is fine on the phone.)

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:salapify/data/store.dart' show SalapifyStore, storageKey;
import 'package:salapify/screens/log_sheet.dart' show LogSheet;
import 'package:salapify/theme.dart';

import 'screens_shot.dart' show loadRealFonts;

void main() {
  testWidgets('the log sheet with a category row, dark', (tester) async {
    await loadRealFonts(tester);
    final blob = {
      'schemaVersion': 12,
      'settings': {'onboarded': true},
      'accounts': [
        {'id': 'cash', 'name': 'Cash', 'kind': 'cash', 'balance': 3000},
        {'id': 'gcash', 'name': 'GCash', 'kind': 'ewallet', 'balance': 1500},
      ],
      'categories': [
        {'id': 'cat_food', 'name': 'Food', 'icon': '🍜', 'monthlyCap': 0},
        {'id': 'cat_transport', 'name': 'Transport', 'icon': '🚌', 'monthlyCap': 0},
        {'id': 'cat_load', 'name': 'Load', 'icon': '📱', 'monthlyCap': 0},
        {'id': 'cat_fun', 'name': 'Fun', 'icon': '🎉', 'monthlyCap': 0},
      ],
      'transactions': <dynamic>[],
    };
    SharedPreferences.setMockInitialValues({storageKey: jsonEncode(blob)});
    Barako.currentTheme = themeForKey('palawan');
    Barako.current = themeForKey('palawan').resolve(Brightness.dark);
    tester.view.physicalSize = const Size(1170, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final store = SalapifyStore();
    await store.load();

    await tester.pumpWidget(
      MaterialApp(
        theme: salapifyTheme(Barako.current),
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Barako.background,
          body: LogSheet(store: store),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('shots/log-category-dark.png'),
    );
  });
}
