// The Phase 3 validation matrix, the machine half.
//
// The permanent gates already cover 1.0x and 1.5x on every main screen
// (screen_readability_test.dart) and 2.0x at 320dp for the controls that
// wrap (segmented_test.dart, the f3.75 chip fix). This file runs the REST of
// the brief's matrix, the cells no permanent gate owns yet: every tab at
// 1.2x and 2.0x on a 390dp phone, and at 1.0x and 1.3x on a 320dp compact
// phone, collecting every layout exception instead of stopping at the first.
//
// Not *_test.dart on purpose: this is a validation pass run deliberately for
// the Phase 3 report, not a per-push gate. If a cell here ever deserves to
// gate pushes, it moves into screen_readability_test.dart's scales instead.
// Run from flutter/:
//   flutter test test/validation_sweep.dart

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/screens/budget.dart';
import 'package:salapify/screens/history.dart';
import 'package:salapify/screens/insights.dart';
import 'package:salapify/screens/menu.dart';
import 'package:salapify/screens/money.dart';
import 'package:salapify/screens/overview.dart';
import 'package:salapify/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens_shot.dart' show loadRealFonts, loadPanFaces, livedInBlob;

final Map<String, Widget Function(SalapifyStore)> _tabs = {
  'overview': (s) =>
      OverviewScreen(store: s, onSwitchTab: (_) {}, onMenu: () {}),
  'budget': (s) => BudgetScreen(store: s, onMenu: () {}),
  'history': (s) => HistoryScreen(store: s, onMenu: () {}),
  'utang': (s) => MoneyScreen(store: s, onMenu: () {}),
  'insights': (s) =>
      InsightsScreen(store: s, onSwitchTab: (_) {}, onMenu: () {}),
  'menu': (s) => MenuScreen(store: s, onSwitchTab: (_) {}),
};

Future<List<String>> _sweep(
  WidgetTester tester, {
  required Size phone,
  required double scale,
}) async {
  final problems = <String>[];
  for (final e in _tabs.entries) {
    await loadRealFonts(tester);
    await loadPanFaces(tester);
    SharedPreferences.setMockInitialValues({
      storageKey: jsonEncode(livedInBlob),
    });
    final store = SalapifyStore();
    await store.load();

    tester.view.physicalSize = phone * 3.0;
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    Barako.current = Barako.currentTheme.resolve(Brightness.dark);
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(scale)),
        child: MaterialApp(
          theme: salapifyTheme(Barako.current),
          home: Scaffold(body: _tabs[e.key]!(store)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    var thrown = tester.takeException();
    while (thrown != null) {
      problems.add(
        '${e.key} at ${scale}x on ${phone.width.toInt()}dp: '
        '${thrown.toString().split('\n').first}',
      );
      thrown = tester.takeException();
    }
  }
  return problems;
}

void main() {
  testWidgets('every tab at 1.2x on a 390dp phone', (tester) async {
    expect(
      await _sweep(tester, phone: const Size(390, 844), scale: 1.2),
      isEmpty,
    );
  });

  testWidgets('every tab at 2.0x on a 390dp phone', (tester) async {
    expect(
      await _sweep(tester, phone: const Size(390, 844), scale: 2.0),
      isEmpty,
    );
  });

  testWidgets('every tab at 1.0x on a 320dp compact phone', (tester) async {
    expect(
      await _sweep(tester, phone: const Size(320, 640), scale: 1.0),
      isEmpty,
    );
  });

  testWidgets('every tab at 1.3x on a 320dp compact phone', (tester) async {
    expect(
      await _sweep(tester, phone: const Size(320, 640), scale: 1.3),
      isEmpty,
    );
  });
}
