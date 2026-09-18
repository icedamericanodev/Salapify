// The Budget tab: the limit card renders engine numbers, a quick add logs
// through the real store with Undo restoring the balance, and the limit can
// be set from the screen.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/main.dart';
import 'package:salapify/money/budget.dart' as budget;
import 'package:shared_preferences/shared_preferences.dart';

import 'support/app_harness.dart';

String _today() {
  final now = DateTime.now();
  return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
}

Map<String, dynamic> blob() => {
  'schemaVersion': 12,
  'accounts': [
    {'id': 'cash', 'name': 'Cash', 'kind': 'cash', 'balance': 5000},
  ],
  'transactions': [
    {
      'id': 't1',
      'type': 'expense',
      'label': 'Groceries',
      'amount': 1200,
      'date': _today(),
      'accountId': 'cash',
    },
  ],
  'settings': {
    'monthlyLimit': 8000,
    'defaultAccountId': 'cash',
    'quickAdds': [
      {'label': 'Food', 'amount': 150},
    ],
  },
};

double cash(SalapifyStore store) =>
    ((store.data['accounts'] as List).cast<Map<String, dynamic>>().firstWhere(
              (a) => a['id'] == 'cash',
            )['balance']
            as num)
        .toDouble();

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({storageKey: jsonEncode(blob())});
  });

  testWidgets('the limit card and a quick add with undo work end to end', (
    tester,
  ) async {
    final store = SalapifyStore();
    await tester.pumpWidget(SalapifyApp(store: store));
    await tester.pumpAndSettle();

    await goToTab(tester, 'Budget');
    await tester.pumpAndSettle();

    // REMAINING is the hero since f3.87 (the "am I safe" inversion); spent
    // of limit is the caption underneath.
    expect(find.text('₱6,800'), findsOneWidget);
    expect(find.text('left this month'), findsOneWidget);
    expect(
      find.textContaining('₱1,200 of ₱8,000 spent so far.'),
      findsOneWidget,
    );

    // Quick add from the remembered account.
    await tester.tap(find.textContaining('Food'));
    await tester.pumpAndSettle();
    expect(cash(store), 4850);
    expect((store.data['transactions'] as List).length, 2);

    // Undo restores the balance exactly.
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(cash(store), 5000);
    expect((store.data['transactions'] as List).length, 1);
  });

  testWidgets('at 85 percent the card says so in words, before the money '
      'is gone', (tester) async {
    final b = blob();
    (b['transactions'] as List).add({
      'id': 't2',
      'type': 'expense',
      'label': 'Rent',
      'amount': 5800,
      'date': _today(),
      'accountId': 'cash',
    });
    SharedPreferences.setMockInitialValues({storageKey: jsonEncode(b)});
    final store = SalapifyStore();
    await tester.pumpWidget(SalapifyApp(store: store));
    await tester.pumpAndSettle();
    await goToTab(tester, 'Budget');
    await tester.pumpAndSettle();
    // 7,000 of 8,000 is 88 percent: the approaching state, carried by words.
    expect(find.textContaining('Getting close.'), findsOneWidget);
    expect(find.text('₱1,000'), findsOneWidget);
  });

  testWidgets('over the limit, the overage is the hero and the biggest '
      'category is named', (tester) async {
    final b = blob();
    (b['transactions'] as List).add({
      'id': 't2',
      'type': 'expense',
      'label': 'Rent',
      'amount': 7650,
      'date': _today(),
      'accountId': 'cash',
    });
    SharedPreferences.setMockInitialValues({storageKey: jsonEncode(b)});
    final store = SalapifyStore();
    await tester.pumpWidget(SalapifyApp(store: store));
    await tester.pumpAndSettle();
    await goToTab(tester, 'Budget');
    await tester.pumpAndSettle();
    // 8,850 of 8,000: the hero is the overage, the words carry the state,
    // and the fix names the biggest lever instead of gesturing at it.
    expect(find.text('₱850'), findsOneWidget);
    expect(find.text('over your limit'), findsOneWidget);
    expect(
      find.textContaining(
        'Rent is your biggest category this month, so the next cut counts '
        'most there.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('No shame'), findsNothing);
  });

  test('dailyRoom spreads the remaining over the days left, engine-side', () {
    // Aug 8 leaves 24 days including today; 3,100 over 24 is 129.1666...
    expect(
      budget.dailyRoom({
        'limit': 18000.0,
        'remaining': 3100.0,
      }, DateTime(2026, 8, 8)),
      closeTo(129.1666, 0.001),
    );
    // The last day of the month spreads over exactly one day.
    expect(
      budget.dailyRoom({
        'limit': 18000.0,
        'remaining': 500.0,
      }, DateTime(2026, 8, 31)),
      closeTo(500.0, 0.0001),
    );
    // No limit, nothing left, or junk: the sentence cannot be said honestly.
    expect(
      budget.dailyRoom({
        'limit': 0.0,
        'remaining': 100.0,
      }, DateTime(2026, 8, 8)),
      isNull,
    );
    expect(
      budget.dailyRoom({
        'limit': 18000.0,
        'remaining': -50.0,
      }, DateTime(2026, 8, 8)),
      isNull,
    );
    expect(
      budget.dailyRoom({
        'limit': 'x',
        'remaining': 100.0,
      }, DateTime(2026, 8, 8)),
      isNull,
    );
  });

  test('budgetSummary clamps the overflow pct to 100 like RN', () {
    final s = budget.budgetSummary({
      'transactions': [
        {
          'id': 'h1',
          'type': 'expense',
          'label': 'A',
          'amount': 1e308,
          'date': _today(),
        },
        {
          'id': 'h2',
          'type': 'expense',
          'label': 'B',
          'amount': 1e308,
          'date': _today(),
        },
      ],
      'settings': {'monthlyLimit': 1},
    }, DateTime.now());
    expect(s['pct'], 100);
    expect(s['over'], true);
  });

  testWidgets('a negative quick add from a hand-edited backup never renders', (
    tester,
  ) async {
    final dirty = blob();
    ((dirty['settings'] as Map)['quickAdds'] as List).add({
      'label': 'Neg',
      'amount': -150,
    });
    SharedPreferences.setMockInitialValues({storageKey: jsonEncode(dirty)});
    final store = SalapifyStore();
    await tester.pumpWidget(SalapifyApp(store: store));
    await tester.pumpAndSettle();
    await goToTab(tester, 'Budget');
    await tester.pumpAndSettle();
    expect(find.textContaining('Neg'), findsNothing);
  });

  testWidgets('the limit can be removed from the dialog', (tester) async {
    final store = SalapifyStore();
    await tester.pumpWidget(SalapifyApp(store: store));
    await tester.pumpAndSettle();
    await goToTab(tester, 'Budget');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Change limit'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove limit'));
    await tester.pumpAndSettle();
    expect(find.text('Set a limit'), findsOneWidget);
    final fresh = SalapifyStore();
    await fresh.load();
    expect(
      ((fresh.data['settings'] as Map)['monthlyLimit'] as num).toDouble(),
      0,
    );
  });

  testWidgets('setting the limit from the screen persists', (tester) async {
    final store = SalapifyStore();
    await tester.pumpWidget(SalapifyApp(store: store));
    await tester.pumpAndSettle();

    await goToTab(tester, 'Budget');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Change limit'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '12000');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.textContaining('of ₱12,000 spent so far.'), findsOneWidget);
    final fresh = SalapifyStore();
    await fresh.load();
    expect(
      ((fresh.data['settings'] as Map)['monthlyLimit'] as num).toDouble(),
      12000,
    );
  });
}
