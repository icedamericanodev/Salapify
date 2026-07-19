// The Insights tab renders the engine's numbers from real stored data:
// DO NEXT decisions in rank order, safe to spend, health score, the trend
// chart, categories, and the runway's honest empty state.

import 'dart:convert';

import 'package:flutter/widgets.dart' show Scrollable;
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/main.dart';
import 'package:salapify/money/analytics.dart' as analytics;
import 'package:salapify/screens/insights.dart'
    show runwayLabel, fundedOnTime;
import 'package:salapify/screens/overview.dart' show formatMoney;
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
  test('formatMoney survives non-finite sums instead of killing the screen',
      () {
    expect(formatMoney(double.infinity), '₱Infinity');
    expect(formatMoney(double.negativeInfinity), '₱-Infinity');
    expect(formatMoney(double.nan), '₱NaN');
    expect(formatMoney(1250.5), '₱1,250.50');
  });

  test('healthScore never fabricates savings points from a NaN rate', () {
    // Two near-max incomes sum to Infinity; savingsRate goes NaN. Dart
    // NaN.clamp would return 1 (35 fake points); the guard scores 0.
    final health = analytics.healthScore({
      'transactions': [
        {
          'id': 'a',
          'type': 'income',
          'label': 'A',
          'amount': 1.7e308,
          'date': _monthDay(10),
        },
        {
          'id': 'b',
          'type': 'income',
          'label': 'B',
          'amount': 1.7e308,
          'date': _monthDay(11),
        },
      ],
      'payments': [],
      'accounts': [],
      'assets': [],
      'debts': [],
      'settings': {},
    }, DateTime.now());
    final total = health['total'] as double;
    expect(total.isFinite, isTrue);
    expect((health['parts'] as Map)['savings'], 0);
  });

  test('a single finite near-max value survives centavo scaling', () {
    // 1.7e308 is finite, but times 100 overflows; round() must never see it.
    final text = formatMoney(1.7e308);
    expect(text.startsWith('₱'), isTrue);
    // The negative twin must not throw either.
    expect(formatMoney(-1.7e308), isA<String>());
  });

  test('infinite debt over infinite assets scores zero, never Infinity', () {
    final health = analytics.healthScore({
      'transactions': [],
      'payments': [],
      'accounts': [
        {'id': 'a', 'balance': 1.7e308},
        {'id': 'b', 'balance': 1.7e308},
      ],
      'assets': [],
      'debts': [
        {'id': 'd1', 'remaining': 1.7e308},
        {'id': 'd2', 'remaining': 1.7e308},
      ],
      'settings': {},
    }, DateTime.now());
    final total = health['total'] as double;
    expect(total.isFinite, isTrue);
    expect((health['parts'] as Map)['debt'], 0);
  });

  test('fundedOnTime is day-precise, never falsely on time within the month',
      () {
    // A day-precise target: a funded date later in the SAME month is late.
    expect(fundedOnTime('2026-08-20', '2026-08-05'), isFalse);
    expect(fundedOnTime('2026-08-03', '2026-08-05'), isTrue);
    expect(fundedOnTime('2026-08-05', '2026-08-05'), isTrue);
    expect(fundedOnTime('2026-07-01', '2026-08-31'), isTrue);
    // A month-only target means end of that month, so any same-month funded
    // date is on time, and the next month is late.
    expect(fundedOnTime('2026-08-28', '2026-08'), isTrue);
    expect(fundedOnTime('2026-09-01', '2026-08'), isFalse);
  });

  test('runwayLabel drops the .0 on whole months', () {
    expect(runwayLabel(null, false), 'Not enough history yet');
    expect(runwayLabel(3.0, false), '3 months');
    expect(runwayLabel(2.5, false), '2.5 months');
    expect(runwayLabel(1.0, false), '1 month');
    expect(runwayLabel(12.0, true), '12+ months');
  });

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

  testWidgets('the what-if simulator projects savings and reacts to the chips',
      (tester) async {
    // A liquid cash cushion (so it is not the crunch state) and the exact
    // three-debt book from the golden. debtFreeProjection's month COUNTS are
    // ref-independent (only the absolute payoff date shifts with today), so
    // the savings deltas are stable whatever day the test runs: baseline 21
    // months, +500 -> 18 (3 sooner), +1000 -> 16 (5 sooner).
    SharedPreferences.setMockInitialValues({
      storageKey: jsonEncode({
        'schemaVersion': 12,
        'accounts': [
          {'id': 'cash', 'name': 'Cash', 'kind': 'cash', 'balance': 20000},
        ],
        'debts': [
          {
            'id': 'card',
            'name': 'BPI card',
            'remaining': 18000,
            'monthlyRate': 3,
            'minPayment': 900,
          },
          {
            'id': 'loan',
            'name': 'Loan',
            'remaining': 45000,
            'monthlyRate': 1,
            'minPayment': 2500,
          },
          {
            'id': 'utang',
            'name': 'Utang',
            'remaining': 4000,
            'monthlyRate': 0,
            'minPayment': 500,
          },
        ],
        'settings': {},
      }),
    });
    final store = SalapifyStore();
    await tester.pumpWidget(SalapifyApp(store: store));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Insights'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
        find.text('WHAT IF YOU PAID A LITTLE EXTRA'), 200,
        scrollable: find.byType(Scrollable).first);
    // Default is +500: the avalanche focus is the 3% card, 3 months sooner.
    expect(find.textContaining('BPI card'), findsOneWidget);
    expect(find.textContaining('3 months sooner'), findsOneWidget);

    // Tapping the +1,000 chip recomputes to 5 months sooner, live.
    await tester.ensureVisible(find.text('+₱1,000 a month'));
    await tester.tap(find.text('+₱1,000 a month'));
    await tester.pumpAndSettle();
    expect(find.textContaining('5 months sooner'), findsOneWidget);
    expect(find.textContaining('3 months sooner'), findsNothing);
  });

  testWidgets('a debt with no rate saved is caveated, never shown as 0 interest',
      (tester) async {
    // remaining but no monthlyRate field: amountOf coerces it to 0, so a
    // naive card would print "0 interest". The guard must caveat instead.
    SharedPreferences.setMockInitialValues({
      storageKey: jsonEncode({
        'schemaVersion': 12,
        'accounts': [
          {'id': 'cash', 'name': 'Cash', 'kind': 'cash', 'balance': 20000},
        ],
        'debts': [
          {'id': 'card', 'name': 'Store card', 'type': 'credit card',
              'remaining': 12000, 'minPayment': 800},
        ],
        'settings': {},
      }),
    });
    final store = SalapifyStore();
    await tester.pumpWidget(SalapifyApp(store: store));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Insights'));
    await tester.pumpAndSettle();

    // The whole card is one ListView child, so scrolling its kicker into view
    // builds every descendant, including the caveat below it.
    await tester.scrollUntilVisible(
        find.text('WHAT IF YOU PAID A LITTLE EXTRA'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(
        find.text(
            'One or more debts have no interest rate saved, so this may understate the real cost. Add the rate for a truer picture.'),
        findsOneWidget);
    // The rosy zero-interest phrasing must never appear.
    expect(find.textContaining('gone to interest'), findsNothing);
  });

  testWidgets('the savings simulator forecasts a goal and reacts to the chips',
      (tester) async {
    // One goal, no debt, so only the savings card shows. No target date, so
    // the funded month (which depends on today) is never asserted; the
    // support sentence, which is date independent, carries the check.
    SharedPreferences.setMockInitialValues({
      storageKey: jsonEncode({
        'schemaVersion': 12,
        'accounts': [
          {'id': 'cash', 'name': 'Cash', 'kind': 'cash', 'balance': 20000},
        ],
        'goals': [
          {'id': 'g1', 'name': 'New phone', 'target': 15000, 'saved': 5000},
        ],
        'settings': {},
      }),
    });
    final store = SalapifyStore();
    await tester.pumpWidget(SalapifyApp(store: store));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Insights'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
        find.text('WHAT IF YOU SAVED EACH WEEK'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.textContaining('New phone'), findsOneWidget);
    expect(find.textContaining('₱10,000 to go'), findsOneWidget);
    expect(find.textContaining('Saving ₱500 a week'), findsOneWidget);

    await tester.ensureVisible(find.text('₱1,000 a week'));
    await tester.tap(find.text('₱1,000 a week'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Saving ₱1,000 a week'), findsOneWidget);
    expect(find.textContaining('Saving ₱500 a week'), findsNothing);
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
