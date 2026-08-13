// Phase 3 batch 3b, the calmer Home trio:
//  1. The bills card folds past four rows into "and N more before payday".
//  2. The all-good check-in is one quiet row: no Pan, no bubble, still a tap.
//  3. One pulse per screen: while the good row shows, the hero does not also
//     say its fitting pace line (the over-pace warning always may).
//
// The bills fold is tested on the WIDGET with fixed rows, clock-free, per the
// rule at the top of home_bills_test.dart: a screen-level bill fixture passes
// or fails depending on the day it runs.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/main.dart' show SalapifyApp;
import 'package:salapify/widgets/bills_before_payday.dart';
import 'package:salapify/widgets/pan_mascot.dart';
import 'package:shared_preferences/shared_preferences.dart';

String _iso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// A store with a payday about three weeks out, one funded account, and steady
/// small spending, so the hero shows, the pace projection exists and fits,
/// and nothing needs a decision: the check-in is the calm all-clear.
Map<String, Object> _calmStorage() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final payday = today.add(const Duration(days: 20));
  return {
    storageKey: jsonEncode({
      'schemaVersion': 12,
      'settings': {
        'onboarded': true,
        'paydaySchedule': {'mode': 'monthly', 'day': payday.day},
      },
      'accounts': [
        {'id': 'cash', 'name': 'Cash', 'kind': 'cash', 'balance': 30000},
      ],
      'transactions': [
        for (var k = 1; k <= 6; k++)
          {
            'id': 't$k',
            'type': 'expense',
            'label': 'Meals',
            'amount': 60,
            'date': _iso(today.subtract(Duration(days: k))),
            'accountId': 'cash',
          },
      ],
    }),
  };
}

List<Map<String, dynamic>> _rows(int n) => [
  for (var i = 0; i < n; i++)
    {
      'name': 'Bill $i',
      'kind': 'recurring',
      'date': '2026-08-2${i + 1}',
      'amount': 300,
    },
];

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  testWidgets('five bills fold to four rows and an "and 1 more" line', (
    tester,
  ) async {
    var opened = 0;
    await tester.pumpWidget(
      _host(
        BillsBeforePayday(
          bills: _rows(5),
          total: 1500,
          format: (n) => 'P$n',
          formatDay: (s) => s,
          onMore: () => opened += 1,
        ),
      ),
    );
    expect(find.text('and 1 more before payday'), findsOneWidget);
    expect(find.text('Bill 0'), findsOneWidget);
    expect(find.text('Bill 3'), findsOneWidget);
    expect(
      find.text('Bill 4'),
      findsNothing,
      reason: 'the fifth bill lives behind the fold',
    );
    await tester.tap(find.text('and 1 more before payday'));
    expect(opened, 1, reason: 'the fold row is the door to the full list');
  });

  testWidgets('four bills or fewer show every row and no fold line', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        BillsBeforePayday(
          bills: _rows(4),
          total: 1200,
          format: (n) => 'P$n',
          formatDay: (s) => s,
        ),
      ),
    );
    expect(find.text('Bill 3'), findsOneWidget);
    expect(find.textContaining('more before payday'), findsNothing);
  });

  testWidgets('the all-good check-in is one quiet row without Pan', (
    tester,
  ) async {
    // Tall view so the lazily built Home ListView reaches the number and the
    // calm check-in row, which now sit below the dashboard-first Net Worth hero
    // and Quick Overview (the same reason home_order_test pumps tall).
    tester.view.physicalSize = const Size(1200, 4600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues(_calmStorage());
    final store = SalapifyStore();
    await tester.pumpWidget(SalapifyApp(store: store));
    await tester.pumpAndSettle();

    expect(find.text('You are on track this week'), findsOneWidget);
    expect(
      find.byType(PanMascot),
      findsNothing,
      reason:
          'the calm all-clear earns a quiet row, not the full Pan card; Pan '
          'stays big where he has something to say',
    );
  });

  testWidgets('one pulse per screen: the good row mutes the fitting pace', (
    tester,
  ) async {
    // Tall view so the lazily built Home ListView reaches the number, which now
    // sits below the dashboard-first Net Worth hero and Quick Overview.
    tester.view.physicalSize = const Size(1200, 4600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues(_calmStorage());
    final store = SalapifyStore();
    await tester.pumpWidget(SalapifyApp(store: store));
    await tester.pumpAndSettle();

    expect(find.text('SAFE TO SPEND'), findsOneWidget);
    expect(find.text('You are on track this week'), findsOneWidget);
    expect(
      find.text('This pace holds to payday. Keep going.'),
      findsNothing,
      reason:
          'while the calm check-in row shows, the hero must not stack a '
          'second all-clear under the number',
    );
  });
}
