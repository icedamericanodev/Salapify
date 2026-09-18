// Phase 3 batch 5, the polish pass guards:
//  1. The sparkline draw-in respects reduce-motion (appears complete, no
//     ticking animation) AND actually animates when motion is allowed, the
//     both-halves alarm rule.
//  2. Budget's WHERE IT WENT rows carry identity keys, so the animated bars
//     never tween from another category's fraction when rows re-sort.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/screens/budget.dart';
import 'package:salapify/widgets/timeline_sparkline.dart';
import 'package:shared_preferences/shared_preferences.dart';

List<Map<String, dynamic>> _days() => [
  for (var i = 0; i < 10; i++)
    {
      'date': '2026-08-${(i + 1).toString().padLeft(2, '0')}',
      'balance': 1000.0 + i * 50,
    },
];

Widget _spark({required bool reduceMotion}) => MediaQuery(
  data: MediaQueryData(disableAnimations: reduceMotion),
  child: MaterialApp(
    home: Scaffold(
      body: TimelineSparkline(
        days: _days(),
        anyNegative: false,
        lowDate: '2026-08-01',
      ),
    ),
  ),
);

void main() {
  testWidgets('the sparkline draw-in is instant under reduce-motion', (
    tester,
  ) async {
    await tester.pumpWidget(_spark(reduceMotion: true));
    await tester.pump();
    expect(
      tester.binding.transientCallbackCount,
      0,
      reason:
          'reduce-motion must collapse the reveal to zero so the chart '
          'simply appears complete',
    );
  });

  testWidgets('the sparkline draw-in actually animates otherwise', (
    tester,
  ) async {
    await tester.pumpWidget(_spark(reduceMotion: false));
    await tester.pump();
    expect(
      tester.binding.transientCallbackCount,
      greaterThan(0),
      reason:
          'with motion allowed the reveal must really run, or the '
          'reduce-motion test above passes vacuously',
    );
    await tester.pumpAndSettle();
  });

  testWidgets('budget category rows carry identity keys', (tester) async {
    SharedPreferences.setMockInitialValues({
      storageKey: jsonEncode({
        'schemaVersion': 12,
        'settings': {'onboarded': true},
        'accounts': [
          {'id': 'cash', 'name': 'Cash', 'kind': 'cash', 'balance': 9000},
        ],
        'transactions': [
          {
            'id': 't1',
            'type': 'expense',
            'label': 'Meals',
            'amount': 500,
            'date':
                '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-01',
            'accountId': 'cash',
          },
        ],
      }),
    });
    final store = SalapifyStore();
    await store.load();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BudgetScreen(store: store, onMenu: () {}),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('cat-Meals')),
      findsOneWidget,
      reason:
          'each WHERE IT WENT row is keyed by its category so a re-sort '
          'moves the row instead of retargeting its animated bar',
    );
  });
}
