// One-off renders for Phase 4 batches, dark, lived-in fixture. Not
// *_test.dart on purpose: pictures to look at, never a CI gate. Run from
// flutter/:
//   flutter test test/p4_shot.dart --update-goldens

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/screens/history.dart';
import 'package:salapify/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens_shot.dart' show loadRealFonts, loadPanFaces, livedInBlob;

Future<void> _shoot(WidgetTester tester, String name, {String? tapText}) async {
  await loadRealFonts(tester);
  await loadPanFaces(tester);
  SharedPreferences.setMockInitialValues({storageKey: jsonEncode(livedInBlob)});
  final store = SalapifyStore();
  await store.load();

  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  Barako.current = Barako.currentTheme.resolve(Brightness.dark);

  await tester.pumpWidget(
    MaterialApp(
      theme: salapifyTheme(Barako.current),
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: HistoryScreen(store: store, onMenu: () {}),
      ),
    ),
  );
  await tester.pumpAndSettle();
  if (tapText != null) {
    await tester.tap(find.text(tapText).first);
    await tester.pumpAndSettle();
  }
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('shots/$name-dark.png'),
  );
}

void main() {
  testWidgets('the receipt for an editable expense', (tester) async {
    await _shoot(tester, 'p4b2-receipt', tapText: 'Groceries');
  });
}
