// One-off renders for Phase 3 batch 5 (the polish pass), dark, lived-in
// fixture. Not *_test.dart on purpose: pictures to look at, never a CI gate.
// Run deliberately, from flutter/:
//   flutter test test/batch5_shot.dart --update-goldens

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/screens/history.dart';
import 'package:salapify/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens_shot.dart' show loadRealFonts, loadPanFaces, livedInBlob;

Future<void> _shoot(
  WidgetTester tester,
  String name,
  Widget Function(SalapifyStore) build, {
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
      home: Scaffold(body: build(store)),
    ),
  );
  await tester.pumpAndSettle();
  if (scrollBy != 0) {
    // Drag from a fixed point LOW on the screen: the chart near the top owns
    // a pan gesture that swallows drags starting on it, and one giant fling
    // gets clamped by physics, so the scroll runs in steps.
    var remaining = scrollBy;
    while (remaining > 0) {
      final step = remaining < 600 ? remaining : 600.0;
      await tester.dragFrom(const Offset(195, 760), Offset(0, -step));
      await tester.pumpAndSettle();
      remaining -= step;
    }
  }
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('shots/$name-dark.png'),
  );
}

void main() {
  testWidgets('Activity: period and filter chips on the shared control', (
    tester,
  ) async {
    await _shoot(
      tester,
      'batch5-activity-chips',
      (s) => HistoryScreen(store: s, onMenu: () {}),
    );
  });
}

// No Insights shot on purpose: the what-if ladders sit inside collapsed
// CollapsibleCards, so a scroll shot shows their covers, not their chips,
// and the chips are the SAME shared widget the Activity shot demonstrates
// in both states.
