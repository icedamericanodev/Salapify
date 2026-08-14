// Renders the Money Mindset screen with a purchase entered, so the new Money
// impact (Decision Score) card can actually be looked at, dark first, per the
// repo rule. NOT named *_test.dart on purpose, so `flutter test` never collects
// it (it only writes PNGs under shots/ with --update-goldens):
//
//   flutter test test/mindset_shot.dart --update-goldens
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/theme.dart';
import 'package:salapify/screens/mindset.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens_shot.dart' show loadPanFaces, loadRealFonts;

/// A ledger with several completed months of income and spending, so the
/// multi-month engines (typical income, average expense) have a real base and
/// every axis of the Decision Score renders with true figures, not the honest
/// thin-data fallbacks an empty ledger shows.
Map<String, dynamic> _richBlob() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  String iso(DateTime t) =>
      '${t.year.toString().padLeft(4, '0')}-'
      '${t.month.toString().padLeft(2, '0')}-'
      '${t.day.toString().padLeft(2, '0')}';
  DateTime back(int m, int day) => DateTime(today.year, today.month - m, day);
  final txns = <Map<String, dynamic>>[];
  for (var m = 0; m <= 5; m++) {
    txns.add({
      'id': 'in$m',
      'type': 'income',
      'label': 'Salary',
      'amount': 32000,
      'date': iso(back(m, 5)),
      'accountId': 'pay',
    });
    txns.add({
      'id': 'rent$m',
      'type': 'expense',
      'label': 'Rent',
      'amount': 9500,
      'date': iso(back(m, 6)),
      'accountId': 'pay',
    });
    txns.add({
      'id': 'food$m',
      'type': 'expense',
      'label': 'Groceries',
      'amount': 8200,
      'date': iso(back(m, 12)),
      'accountId': 'gcash',
    });
  }
  return <String, dynamic>{
    'schemaVersion': 12,
    'settings': {
      'onboarded': true,
      'name': 'Carla',
      'paydaySchedule': {'mode': 'monthly', 'day': 30},
      'monthlyLimit': 18000,
    },
    'accounts': [
      {'id': 'cash', 'name': 'Cash', 'kind': 'cash', 'balance': 4000},
      {'id': 'bpi', 'name': 'BPI Savings', 'kind': 'savings', 'balance': 55000},
      {'id': 'gcash', 'name': 'GCash', 'kind': 'ewallet', 'balance': 3000},
      {
        'id': 'pay',
        'name': 'Salary account',
        'kind': 'checking',
        'balance': 14000,
      },
    ],
    'recurring': [
      {
        'id': 'r-rent',
        'type': 'expense',
        'label': 'Rent',
        'amount': 9500,
        'dayOfMonth': 5,
      },
      {
        'id': 'r-net',
        'type': 'expense',
        'label': 'Internet',
        'amount': 1699,
        'dayOfMonth': 18,
      },
    ],
    'goals': [
      {
        'id': 'g1',
        'name': 'Emergency fund',
        'target': 100000,
        'saved': 40000,
        'targetDate': iso(DateTime(today.year, today.month + 6, 1)),
        'kind': 'savings',
        'frequency': 'monthly',
        'createdAt': iso(back(4, 1)),
        'startSaved': 10000,
        'contributions': [
          {'id': 'c1', 'amount': 10000, 'date': iso(back(3, 1))},
          {'id': 'c2', 'amount': 20000, 'date': iso(back(1, 1))},
        ],
      },
    ],
    'transactions': txns,
  };
}

Future<void> _shootMindset(
  WidgetTester tester,
  String amount,
  String name,
) async {
  await loadRealFonts(tester);
  await loadPanFaces(tester);
  SharedPreferences.setMockInitialValues({
    'salapify_data_v2': jsonEncode(_richBlob()),
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
      home: MindsetScreen(store: store),
    ),
  );
  await tester.pumpAndSettle();

  await tester.enterText(find.byKey(const Key('mindsetAmount')), amount);
  await tester.pumpAndSettle();

  // Bring the new Money impact card into frame.
  await tester.scrollUntilVisible(
    find.text('MONEY IMPACT'),
    150,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();

  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('shots/$name-dark.png'),
  );
}

void main() {
  testWidgets('Money impact card, a comfortable one-time buy, dark', (
    tester,
  ) async {
    await _shootMindset(tester, '1200', 'mindset-impact-low');
  });

  testWidgets('Money impact card, a heavy one-time buy, dark', (tester) async {
    await _shootMindset(tester, '48000', 'mindset-impact-high');
  });
}
