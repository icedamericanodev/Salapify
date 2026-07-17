// The Insights tab renders the engine's numbers from real stored data:
// DO NEXT decisions in rank order, safe to spend, health score, the trend
// chart, categories, and the runway's honest empty state.

import 'dart:convert';

import 'package:flutter/widgets.dart' show Scrollable;
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> blob() => {
      'schemaVersion': 12,
      'accounts': [
        {'id': 'cash', 'name': 'Cash', 'kind': 'cash', 'balance': 3000},
      ],
      'transactions': [
        {
          'id': 'i1',
          'type': 'income',
          'label': 'Sweldo',
          'amount': 5000,
          'date': _monthDay(15),
          'accountId': 'cash',
        },
        {
          'id': 'e1',
          'type': 'expense',
          'label': 'Milk tea',
          'amount': 2600,
          'date': _monthDay(8),
        },
        {
          'id': 'e2',
          'type': 'expense',
          'label': 'Food',
          'amount': 4000,
          'date': _monthDay(5),
        },
      ],
      'people': [
        {'id': 'p1', 'name': 'Migs'},
      ],
      'receivables': [
        {
          'id': 'r1',
          'personId': 'p1',
          'person': 'Migs',
          'amount': 1500,
          'payments': [],
          'paid': false,
          'dueDate': '2020-01-01',
        },
      ],
      'settings': {'monthlyLimit': 5000},
    };

String _monthDay(int day) {
  final now = DateTime.now();
  // Keep fixture dates in the current month but never in the future, so
  // savings rate and forecast see them regardless of today's date.
  final d = day <= now.day ? day : now.day;
  return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}';
}

void main() {
  testWidgets('the Insights tab renders decisions and numbers from real data',
      (tester) async {
    SharedPreferences.setMockInitialValues({storageKey: jsonEncode(blob())});
    final store = SalapifyStore();
    await tester.pumpWidget(SalapifyApp(store: store));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Insights'));
    await tester.pumpAndSettle();

    expect(find.text('DO NEXT'), findsOneWidget);
    // Spending (6600) passed income (5000) this month: the overspend
    // decision must rank near the top, and Migs is years overdue.
    expect(find.text('Spending passed income this month'), findsOneWidget);
    expect(find.text('Follow up Migs'), findsOneWidget);
    expect(find.text('SAFE TO SPEND UNTIL SWELDO'), findsOneWidget);
    // The lower cards live below the test viewport fold: scroll to each.
    for (final label in [
      'MONEY HEALTH',
      'LAST 6 MONTHS',
      'Income',
      'Spending',
      // Only the current month has spending: runway has no honest number.
      'Not enough history yet',
    ]) {
      await tester.scrollUntilVisible(find.text(label), 200,
          scrollable: find.byType(Scrollable).first);
      expect(find.text(label), findsOneWidget, reason: label);
    }

    // Tapping the utang decision jumps to the Utang tab.
    await tester.scrollUntilVisible(find.text('Follow up Migs'), -200,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Follow up Migs'));
    await tester.pumpAndSettle();
    expect(find.text('STILL OUT'), findsOneWidget);
  });

  testWidgets('an empty app shows the calm all-clear', (tester) async {
    // The mock storage persists across tests in this file; clear it so this
    // store really loads empty.
    SharedPreferences.setMockInitialValues({});
    final store = SalapifyStore();
    await tester.pumpWidget(SalapifyApp(store: store));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Insights'));
    await tester.pumpAndSettle();
    expect(find.text('You are on track'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Not enough history yet'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Not enough history yet'), findsOneWidget);
  });
}
