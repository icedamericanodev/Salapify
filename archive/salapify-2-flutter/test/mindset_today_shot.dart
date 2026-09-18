// Renders the Mindset Today dashboard so it can be looked at.
// Not *_test.dart, so `flutter test` never collects it.
//   flutter test test/mindset_today_shot.dart --update-goldens
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/screens/mindset_decisions_list.dart';
import 'package:salapify/screens/mindset_insights.dart';
import 'package:salapify/screens/mindset_today.dart';
import 'package:salapify/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens_shot.dart' show loadPanFaces, loadRealFonts;

/// A lived-in fixture for the 30-day insights screen: decision checks and wins
/// spread over the last four weeks so the snapshot counts, the spending-avoided
/// figure, the mindful streak dots, and the small wins all render with real
/// numbers instead of an empty first-run screen.
Map<String, dynamic> _insightsBlob() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  String iso(DateTime t) =>
      '${t.year.toString().padLeft(4, '0')}-'
      '${t.month.toString().padLeft(2, '0')}-'
      '${t.day.toString().padLeft(2, '0')}';
  String ago(int d) => iso(today.subtract(Duration(days: d)));
  final blob = _blob();
  (blob['settings'] as Map)['mindsetChecks'] = [
    {'date': ago(1), 'verdict': 'pause24h'},
    {'date': ago(8), 'verdict': 'notInPlan'},
    {'date': ago(16), 'verdict': 'fitsPlan'},
  ];
  (blob['settings'] as Map)['mindsetWaiting'] = [
    {'id': 'p1', 'createdAt': ago(2), 'status': 'waiting', 'amount': 4990},
  ];
  blob['wins'] = [
    {'id': 'w1', 'note': 'Skipped new shoes', 'amount': 3200, 'date': ago(3)},
    {
      'id': 'w2',
      'note': 'Packed lunch all week',
      'amount': 1800,
      'date': ago(9),
    },
  ];
  return blob;
}

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
      'mindsetWaiting': [
        {
          'id': 'w1',
          'itemName': 'New headphones',
          'amount': 4990,
          'status': 'waiting',
          'createdAt': now.subtract(const Duration(days: 2)).toIso8601String(),
          'revisitAt': now.subtract(const Duration(hours: 3)).toIso8601String(),
        },
        {
          'id': 'w2',
          'itemName': 'Weekend getaway',
          'amount': 6500,
          'status': 'waiting',
          'createdAt': now.toIso8601String(),
          'revisitAt': now.add(const Duration(hours: 18)).toIso8601String(),
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
  Future<void> shootScreen(
    WidgetTester tester,
    Brightness b,
    Widget Function(SalapifyStore) build,
    Map<String, dynamic> blob,
    String file,
  ) async {
    await loadRealFonts(tester);
    await loadPanFaces(tester);
    SharedPreferences.setMockInitialValues({
      'salapify_data_v2': jsonEncode(blob),
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
        home: build(store),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile(file));
  }

  testWidgets('Mindset insights (My 30 days), dark', (tester) async {
    await shootScreen(
      tester,
      Brightness.dark,
      (s) => MindsetInsightsScreen(store: s),
      _insightsBlob(),
      'shots/mindset-insights-dark.png',
    );
  });
  testWidgets('Mindset insights (My 30 days), light', (tester) async {
    await shootScreen(
      tester,
      Brightness.light,
      (s) => MindsetInsightsScreen(store: s),
      _insightsBlob(),
      'shots/mindset-insights-light.png',
    );
  });
  testWidgets('Mindset View all with filter, dark', (tester) async {
    await shootScreen(
      tester,
      Brightness.dark,
      (s) => MindsetDecisionsListScreen(store: s),
      _blob(),
      'shots/mindset-viewall-dark.png',
    );
  });
  testWidgets('Mindset View all with filter, light', (tester) async {
    await shootScreen(
      tester,
      Brightness.light,
      (s) => MindsetDecisionsListScreen(store: s),
      _blob(),
      'shots/mindset-viewall-light.png',
    );
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
