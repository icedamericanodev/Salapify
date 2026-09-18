// One-off renders for Phase 3 batch 4 (one face for money on Home), dark
// first, on the lived-in fixture. Not *_test.dart on purpose: pictures to
// look at, never a CI gate. Run deliberately, from flutter/:
//   flutter test test/batch4_shot.dart --update-goldens

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/screens/overview.dart';
import 'package:salapify/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens_shot.dart' show loadRealFonts, loadPanFaces, livedInBlob;

Future<void> _shoot(
  WidgetTester tester,
  String name, {
  double scrollBy = 0,
}) async {
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
        body: OverviewScreen(store: store, onSwitchTab: (_) {}, onMenu: () {}),
      ),
    ),
  );
  await tester.pumpAndSettle();
  if (scrollBy != 0) {
    await tester.drag(find.byType(ListView).first, Offset(0, -scrollBy));
    await tester.pumpAndSettle();
  }
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('shots/$name-dark.png'),
  );
}

void main() {
  testWidgets('the hero on the ladder face', (tester) async {
    await _shoot(tester, 'batch4-home-top');
  });

  testWidgets('the tail: THIS MONTH, accounts, net worth on one face', (
    tester,
  ) async {
    await _shoot(tester, 'batch4-home-tail', scrollBy: 1500);
  });
}
