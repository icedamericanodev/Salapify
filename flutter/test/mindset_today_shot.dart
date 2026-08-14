// Renders the Mindset Today dashboard so it can be looked at.
// Not *_test.dart, so `flutter test` never collects it.
//   flutter test test/mindset_today_shot.dart --update-goldens
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/screens/mindset_today.dart';
import 'package:salapify/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens_shot.dart' show loadPanFaces, loadRealFonts;

Map<String, dynamic> _blob() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  DateTime at(int h, int m) =>
      DateTime(today.year, today.month, today.day, h, m);
  final yest = today.subtract(const Duration(days: 1));
  return {
    'schemaVersion': 12,
    'settings': {
      'onboarded': true,
      'mindsetDecisions': [
        {
          'id': 'd1',
          'itemName': 'GrabFood',
          'amount': 350,
          'outcome': 'avoided',
          'note': 'I cooked at home instead',
          'createdAt': at(10, 30).toIso8601String(),
        },
        {
          'id': 'd2',
          'itemName': 'Coffee run',
          'amount': 180,
          'outcome': 'avoided',
          'createdAt': at(9, 5).toIso8601String(),
        },
        {
          'id': 'd3',
          'itemName': 'New headphones',
          'amount': 4990,
          'outcome': 'waiting',
          'note': 'Sale ends Friday, revisiting',
          'createdAt': at(8, 40).toIso8601String(),
        },
        {
          'id': 'd4',
          'itemName': 'Online shopping',
          'amount': 900,
          'outcome': 'purchased',
          'note': 'Needed for work',
          'createdAt': DateTime(
            yest.year,
            yest.month,
            yest.day,
            19,
            0,
          ).toIso8601String(),
        },
      ],
    },
    'accounts': [
      {'id': 'pay', 'name': 'Payroll', 'kind': 'checking', 'balance': 40000},
    ],
    'transactions': const [],
  };
}

Future<void> _shoot(WidgetTester tester, Brightness b, String file) async {
  await loadRealFonts(tester);
  await loadPanFaces(tester);
  SharedPreferences.setMockInitialValues({
    'salapify_data_v2': jsonEncode(_blob()),
  });
  final store = SalapifyStore();
  await store.load();

  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  Barako.current = Barako.currentTheme.resolve(b);

  await tester.pumpWidget(
    MaterialApp(
      theme: salapifyTheme(Barako.current),
      debugShowCheckedModeBanner: false,
      home: MindsetTodayScreen(store: store),
    ),
  );
  await tester.pumpAndSettle();
  await expectLater(find.byType(MaterialApp), matchesGoldenFile(file));
}

void main() {
  testWidgets('Mindset Today dashboard, dark', (tester) async {
    await _shoot(tester, Brightness.dark, 'shots/mindset-today-dark.png');
  });
  testWidgets('Mindset Today dashboard, light', (tester) async {
    await _shoot(tester, Brightness.light, 'shots/mindset-today-light.png');
  });
  testWidgets('Mindset Today dashboard, empty', (tester) async {
    await loadRealFonts(tester);
    await loadPanFaces(tester);
    SharedPreferences.setMockInitialValues({
      'salapify_data_v2': jsonEncode({
        'schemaVersion': 12,
        'settings': {'onboarded': true},
        'accounts': const [],
        'transactions': const [],
      }),
    });
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
        home: MindsetTodayScreen(store: store),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('shots/mindset-today-empty-dark.png'),
    );
  });
}
