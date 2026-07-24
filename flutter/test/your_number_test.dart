// Your Number on Home: the card renders from the cycle composer with a real
// positive number, greets a comeback after quiet days, taps through to
// Insights, and stays hidden on a fresh store. Amount values are asserted
// loosely because Home reads the live clock (daysLeft varies by run day);
// the exact math is pinned in cycle_test.dart against a fixed date.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

String _daysAgo(int n) {
  final d = DateTime.now().subtract(Duration(days: n));
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

// Payday pinned to "tomorrow": these tests are about the number card, so the
// PAYDAY ritual card must never join the layout on a 15th or month-end run.
Map<String, dynamic> _settings() => {
  'paydaySchedule': {
    'mode': 'weekly',
    'weekday': (DateTime.now().weekday % 7 + 1) % 7,
  },
};

void main() {
  testWidgets('a funded account shows Your Number and taps to Insights', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({
      'salapify_data_v2': jsonEncode({
        'accounts': [
          {'id': 'c', 'name': 'Cash', 'kind': 'cash', 'balance': 10000},
        ],
        'settings': _settings(),
        'transactions': [
          {
            'id': 'e1',
            'date': _daysAgo(0),
            'type': 'expense',
            'label': 'Food',
            'amount': 100,
            'accountId': 'c',
          },
        ],
      }),
    });
    final store = SalapifyStore();
    await tester.pumpWidget(SalapifyApp(store: store));
    await tester.pumpAndSettle();

    expect(find.text('YOUR NUMBER'), findsOneWidget);
    expect(find.textContaining('a day'), findsWidgets);
    expect(find.textContaining('payday'), findsWidgets);
    // Logged today, so no comeback greeting.
    expect(find.textContaining('Welcome back'), findsNothing);

    // Tapping the card lands on the Insights tab, where the full
    // safe-to-spend breakdown lives.
    await tester.tap(find.text('YOUR NUMBER'));
    await tester.pumpAndSettle();
    expect(find.text('SAFE TO SPEND UNTIL PAYDAY'), findsWidgets);
  });

  testWidgets('five quiet days greet the comeback kindly', (tester) async {
    tester.view.physicalSize = const Size(1200, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({
      'salapify_data_v2': jsonEncode({
        'accounts': [
          {'id': 'c', 'name': 'Cash', 'kind': 'cash', 'balance': 8000},
        ],
        'settings': _settings(),
        'transactions': [
          {
            'id': 'e1',
            'date': _daysAgo(5),
            'type': 'expense',
            'label': 'Food',
            'amount': 100,
            'accountId': 'c',
          },
        ],
      }),
    });
    final store = SalapifyStore();
    await tester.pumpWidget(SalapifyApp(store: store));
    await tester.pumpAndSettle();

    expect(find.text('YOUR NUMBER'), findsOneWidget);
    expect(find.textContaining('Welcome back, life happens'), findsOneWidget);
  });

  testWidgets('a fresh store shows no number card', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = SalapifyStore();
    await tester.pumpWidget(SalapifyApp(store: store));
    await tester.pumpAndSettle();
    expect(find.text('YOUR NUMBER'), findsNothing);
  });
}
