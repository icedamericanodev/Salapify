// Tall one-shot renders of the redesigned Add-a-debt wizard, for LOOKING at the
// flow before it ships. NOT a test (no _test suffix), so `flutter test` never
// collects it. Run from flutter/:
//   flutter test test/debt_wizard_preview.dart --update-goldens
// Output: test/shots/debt-wizard-*.png (gitignored).

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/screens/debts.dart';
import 'package:salapify/theme.dart';

import 'screens_shot.dart' show loadRealFonts, livedInBlob;

void main() {
  testWidgets('add-debt wizard preview', (tester) async {
    await loadRealFonts(tester);
    SharedPreferences.setMockInitialValues({
      storageKey: jsonEncode(livedInBlob),
    });
    final store = SalapifyStore();
    await store.load();
    final card = (store.data['debts'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((d) => d['type'] == 'credit card');

    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    Barako.current = Barako.currentTheme.resolve(Brightness.dark);

    await tester.pumpWidget(
      MaterialApp(
        theme: salapifyTheme(Barako.current),
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Barako.background,
          body: SafeArea(child: DebtFormSheet(store: store, debt: card)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    Future<void> shoot(String name) async {
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('shots/debt-wizard-$name.png'),
      );
    }

    await shoot('1-basics');
    await tester.tap(find.text('Continue'));
    await shoot('2-financial');
    // Show the per-year toggle and the live estimate.
    await tester.tap(find.text('Per year'));
    await shoot('2-financial-annual');
    await tester.tap(find.text('Continue'));
    await shoot('3-schedule');
    await tester.tap(find.text('Continue'));
    await shoot('4-review');
  });
}
