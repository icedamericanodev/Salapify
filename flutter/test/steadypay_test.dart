// Steady Pay engine: the weekly draw is planned on the three leanest of the
// last six FULL income months (the current partial month never counts), utang
// collections are never income, thin history yields silence instead of a
// made-up salary, and junk never throws. Net-new logic, unit-tested with hard
// invariants.

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/money/steadypay.dart';

void main() {
  final ref = DateTime(2026, 7, 20);

  Map<String, dynamic> withIncomes(Map<String, num> byMonth) => {
    'accounts': [
      {'id': 'c', 'name': 'Cash', 'kind': 'cash', 'balance': 30000},
    ],
    'transactions': [
      for (final e in byMonth.entries)
        {
          'id': 'i${e.key}',
          'type': 'income',
          'label': 'Gigs',
          'amount': e.value,
          'date': '${e.key}-10',
        },
    ],
  };

  test('plans on the three leanest of the last six full months', () {
    // Jan..Jun full months; July (current) must not count.
    final sp = steadyPaySuggestion(
      withIncomes({
        '2026-01': 30000,
        '2026-02': 12000,
        '2026-03': 25000,
        '2026-04': 9000,
        '2026-05': 40000,
        '2026-06': 15000,
        '2026-07': 999999, // current partial month, excluded
      }),
      ref,
    );
    // Leanest three: 9000, 12000, 15000 -> baseline 12000.
    expect(sp.leanBaseline, 12000);
    expect(sp.weeklyDraw, closeTo(12000 * 12 / 52, 0.001));
    expect(sp.activeMonths, 6);
    // Runway: 30000 liquid over the 12000 baseline.
    expect(sp.runwayMonths, closeTo(2.5, 0.001));
  });

  test('fewer than three income months stays silent', () {
    final sp = steadyPaySuggestion(
      withIncomes({'2026-05': 20000, '2026-06': 18000}),
      ref,
    );
    expect(sp.weeklyDraw, isNull);
    expect(sp.leanBaseline, isNull);
    expect(sp.activeMonths, 2);
  });

  test('utang collections are not income', () {
    final d = withIncomes({'2026-04': 10000, '2026-05': 10000});
    (d['transactions'] as List).add({
      'id': 'r1',
      'type': 'income',
      'source': 'receivable',
      'label': 'Paid back',
      'amount': 50000,
      'date': '2026-06-10',
    });
    final sp = steadyPaySuggestion(d, ref);
    expect(sp.activeMonths, 2, reason: 'the collection month adds no income');
    expect(sp.weeklyDraw, isNull);
  });

  test('a zero-income month is skipped, not counted as lean', () {
    final sp = steadyPaySuggestion(
      withIncomes({'2026-02': 20000, '2026-04': 22000, '2026-06': 24000}),
      ref,
    );
    // Three active months across the window; gaps do not drag the baseline
    // to zero.
    expect(sp.activeMonths, 3);
    expect(sp.leanBaseline, 22000);
  });

  test('overflowed amounts yield silence, never Infinity', () {
    final sp = steadyPaySuggestion(
      withIncomes({'2026-02': 1.5e308, '2026-03': 1.5e308, '2026-04': 1.5e308}),
      ref,
    );
    // Each month is finite alone, but the baseline mean overflows; sum of
    // three 1.5e308 is Infinity, so the guard nulls the suggestion.
    expect(sp.weeklyDraw, isNull);
  });

  test('junk never throws', () {
    expect(steadyPaySuggestion(null, ref).weeklyDraw, isNull);
    expect(steadyPaySuggestion('junk', ref).weeklyDraw, isNull);
    expect(steadyPaySuggestion({'transactions': 'nope'}, ref).activeMonths, 0);
  });

  group('steadyPayWeek', () {
    test('sums this week\'s discretionary spend against the draw', () {
      // ref Mon Jul 20; week is Jul 20..20 so far.
      final week = steadyPayWeek(
        {
          'transactions': [
            {
              'id': 'e1',
              'type': 'expense',
              'label': 'Food',
              'amount': 400,
              'date': '2026-07-20',
            },
            {
              'id': 'e2',
              'type': 'expense',
              'label': 'Last week',
              'amount': 999,
              'date': '2026-07-19',
            },
            {
              'id': 'e3',
              'type': 'expense',
              'label': 'Interest',
              'amount': 100,
              'date': '2026-07-20',
              'source': 'interest',
            },
            {
              'id': 'e4',
              'type': 'expense',
              'label': 'Card pay',
              'amount': 500,
              'date': '2026-07-20',
              'debtId': 'd1',
            },
            {
              'id': 'e5',
              'type': 'expense',
              'label': 'Rent',
              'amount': 800,
              'date': '2026-07-20',
              'recurringId': 'r1',
            },
          ],
        },
        ref,
        3000,
      );
      expect(week.spent, 400);
      expect(week.draw, 3000);
      expect(week.remaining, 2600);
    });

    test('a week over the draw reads negative, honestly', () {
      final week = steadyPayWeek(
        {
          'transactions': [
            {
              'id': 'e1',
              'type': 'expense',
              'label': 'Big',
              'amount': 5000,
              'date': '2026-07-20',
            },
          ],
        },
        ref,
        3000,
      );
      expect(week.remaining, -2000);
    });

    test('junk draw and junk data never throw', () {
      final week = steadyPayWeek(null, ref, double.infinity);
      expect(week.draw, 0);
      expect(week.spent, 0);
    });
  });

  group('acceptedSteadyPay', () {
    test('reads a valid accepted draw and rejects junk', () {
      expect(
        acceptedSteadyPay({
          'settings': {
            'steadyPay': {'amount': 2500.0, 'acceptedAt': '2026-07-24'},
          },
        }),
        2500,
      );
      expect(acceptedSteadyPay({'settings': {}}), isNull);
      expect(
        acceptedSteadyPay({
          'settings': {'steadyPay': 'junk'},
        }),
        isNull,
      );
      expect(
        acceptedSteadyPay({
          'settings': {
            'steadyPay': {'amount': -5},
          },
        }),
        isNull,
      );
      expect(acceptedSteadyPay(null), isNull);
    });
  });
}
