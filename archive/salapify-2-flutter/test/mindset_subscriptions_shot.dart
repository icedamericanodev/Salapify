// Renders the Subscriptions screen so it can be looked at. Not *_test.dart, so
// `flutter test` never collects it.
//   flutter test test/mindset_subscriptions_shot.dart --update-goldens
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/screens/mindset_subscriptions_screen.dart';
import 'package:salapify/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens_shot.dart' show loadPanFaces, loadRealFonts;

Map<String, dynamic> _blob() => {
  'schemaVersion': 12,
  'settings': {
    'onboarded': true,
    'mindsetSubscriptions': [
      {
        'id': 's1',
        'name': 'Streaming',
        'amount': 149,
        'cycle': 'monthly',
        'emoji': '🎬',
      },
      {
        'id': 's2',
        'name': 'Music',
        'amount': 99,
        'cycle': 'monthly',
        'emoji': '🎵',
      },
      {
        'id': 's3',
        'name': 'Cloud storage',
        'amount': 1200,
        'cycle': 'annual',
        'emoji': '☁️',
      },
      {'id': 's4', 'name': 'Gym', 'amount': 900, 'cycle': 'monthly'},
    ],
  },
  'accounts': [
    {'id': 'gcash', 'name': 'GCash', 'kind': 'ewallet', 'balance': 6000},
  ],
  'transactions': [],
};

void main() {
  testWidgets('Subscriptions screen, dark', (tester) async {
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
    Barako.current = Barako.currentTheme.resolve(Brightness.dark);

    await tester.pumpWidget(
      MaterialApp(
        theme: salapifyTheme(Barako.current),
        debugShowCheckedModeBanner: false,
        home: MindsetSubscriptionsScreen(store: store),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('shots/mindset-subscriptions-dark.png'),
    );
  });
}
