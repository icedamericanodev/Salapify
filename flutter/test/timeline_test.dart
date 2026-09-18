// Unit suite for money/timeline.dart, the Sweldo Timeline engine. Every
// expected number below is computed by hand from the fixture and written as a
// literal, the golden-vector discipline for new money math: if the engine and
// the hand arithmetic disagree, the engine is wrong until proven otherwise.
//
// The invariants: every recurring item contributes EVERY occurrence in the
// window (the month-bounded calendar's one-occurrence rule is exactly what
// this engine exists to fix), posted months are never double counted, debts
// contribute every bank cycle, the variable band is an estimate kept separate
// from the conservative line, paydays come only from an explicit schedule,
// scenarios are pure overlays, and junk never throws.

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/money/timeline.dart';

void main() {
  // Wednesday noon, 15 July 2026. Salary lands on the 30th.
  final now = DateTime(2026, 7, 15, 12);

  Map<String, dynamic> fixture() => {
    'accounts': [
      {'id': 'a1', 'name': 'Cash', 'kind': 'cash', 'balance': 5000},
      {'id': 'a2', 'name': 'Ipon', 'kind': 'savings', 'balance': 50000},
    ],
    'recurring': [
      {
        'id': 'r1',
        'type': 'income',
        'label': 'Sweldo',
        'amount': 20000,
        'dayOfMonth': 30,
      },
      {
        'id': 'r2',
        'type': 'bill',
        'label': 'Rent',
        'amount': 8000,
        'dayOfMonth': 5,
      },
      {
        'id': 'r3',
        'type': 'bill',
        'label': 'Internet',
        'amount': 1500,
        'dayOfMonth': 20,
      },
    ],
    'settings': {
      'paydaySchedule': {'mode': 'monthly', 'day': 30},
    },
  };

  double balanceOn(Map<String, dynamic> tl, String iso) =>
      (tl['days'] as List).cast<Map<String, dynamic>>().firstWhere(
            (d) => d['date'] == iso,
          )['balance']
          as double;

  group('the rolling window crosses month boundaries', () {
    test('every recurring occurrence in 60 days lands, hand-checked', () {
      final tl = sweldoTimeline(fixture(), now, horizonDays: 60);
      // Start: only liquid cash counts, 5000. Savings never.
      expect(tl['startBalance'], 5000.0);
      // Hand walk: Jul 20 internet -1500 = 3500; Jul 30 sweldo +20000 =
      // 23500; Aug 5 rent -8000 = 15500; Aug 20 internet -1500 = 14000;
      // Aug 30 sweldo +20000 = 34000; Sep 5 rent -8000 = 26000.
      expect(balanceOn(tl, '2026-07-20'), 3500.0);
      expect(balanceOn(tl, '2026-07-30'), 23500.0);
      expect(balanceOn(tl, '2026-08-05'), 15500.0);
      expect(balanceOn(tl, '2026-08-20'), 14000.0);
      expect(balanceOn(tl, '2026-08-30'), 34000.0);
      expect(balanceOn(tl, '2026-09-05'), 26000.0);
      expect(tl['endBalance'], 26000.0);
      // Rent appears TWICE (Aug 5 and Sep 5). The month-bounded calendar
      // would have shown it once; this line is the engine's reason to exist.
      final rentDays = (tl['days'] as List)
          .cast<Map<String, dynamic>>()
          .where((d) => (d['events'] as List).any((e) => e['label'] == 'Rent'))
          .map((d) => d['date'])
          .toList();
      expect(rentDays, ['2026-08-05', '2026-09-05']);
    });

    test('the lowest day and its date are named', () {
      final tl = sweldoTimeline(fixture(), now, horizonDays: 60);
      expect(tl['lowest'], {'date': '2026-07-20', 'balance': 3500.0});
      expect(tl['anyNegative'], isFalse);
      expect(tl['firstNegativeDate'], isNull);
    });

    test('a posted month is skipped, the NEXT month still projects', () {
      final data = fixture();
      (data['recurring'] as List)[2]['lastPosted'] = '2026-07';
      final tl = sweldoTimeline(data, now, horizonDays: 60);
      // Internet's Jul 20 occurrence is already posted, so no dip there...
      expect(balanceOn(tl, '2026-07-20'), 5000.0);
      // ...but August's is a new cycle and must still be counted.
      expect(balanceOn(tl, '2026-08-20'), 15500.0 + 1500.0 - 1500.0);
      final internetDays = (tl['days'] as List)
          .cast<Map<String, dynamic>>()
          .where(
            (d) => (d['events'] as List).any((e) => e['label'] == 'Internet'),
          )
          .map((d) => d['date'])
          .toList();
      expect(internetDays, ['2026-08-20']);
    });

    test('day 31 clamps to each month\'s real last day', () {
      final data = fixture();
      (data['recurring'] as List).add({
        'id': 'r4',
        'type': 'bill',
        'label': 'Yaya',
        'amount': 100,
        'dayOfMonth': 31,
      });
      final tl = sweldoTimeline(data, now, horizonDays: 80);
      final yayaDays = (tl['days'] as List)
          .cast<Map<String, dynamic>>()
          .where((d) => (d['events'] as List).any((e) => e['label'] == 'Yaya'))
          .map((d) => d['date'])
          .toList();
      // Jul 31 real, Aug 31 real, Sep clamps to 30.
      expect(yayaDays, ['2026-07-31', '2026-08-31', '2026-09-30']);
    });
  });

  group('debts contribute every bank cycle', () {
    test('a dueDay debt lands in both months of a 60 day window', () {
      final data = fixture();
      data['debts'] = [
        {
          'id': 'd1',
          'name': 'Home Credit',
          'remaining': 12000,
          'minPayment': 2500,
          'dueDay': 10,
        },
      ];
      final tl = sweldoTimeline(data, now, horizonDays: 60);
      final dueDays = (tl['days'] as List)
          .cast<Map<String, dynamic>>()
          .where(
            (d) =>
                (d['events'] as List).any((e) => e['label'] == 'Home Credit'),
          )
          .map((d) => d['date'])
          .toList();
      // Aug 10 2026 is a Monday and Sep 10 a Thursday, no bank adjustment.
      expect(dueDays, ['2026-08-10', '2026-09-10']);
      // Both cycles at the minimum: Aug 10 = 15500 - 2500 = 13000, and the
      // running balance carries the first payment into September.
      expect(balanceOn(tl, '2026-08-10'), 13000.0);
      expect(balanceOn(tl, '2026-09-10'), 21000.0);
    });

    test('a weekend-moved due does NOT swallow the later cycles', () {
      // The QA-gate catch: Jul 18 2026 is a Saturday, so the July cycle
      // bank-adjusts to Mon Jul 20. bankDueDate keeps the previous raw due in
      // the running while its ADJUSTED date is still ahead, so a cursor that
      // only steps past the raw due sees the same adjusted date twice, and
      // the first version of this loop then broke out entirely, silently
      // discarding August and September. Roughly two in seven due days are
      // weekend-moved, so this was not an edge case; it made the
      // "conservative" line understate debt outflow.
      final data = fixture();
      data['debts'] = [
        {
          'id': 'd1',
          'name': 'Home Credit',
          'remaining': 12000,
          'minPayment': 2500,
          'dueDay': 18,
        },
      ];
      final tl = sweldoTimeline(data, now, horizonDays: 90);
      final dueDays = (tl['days'] as List)
          .cast<Map<String, dynamic>>()
          .where(
            (d) =>
                (d['events'] as List).any((e) => e['label'] == 'Home Credit'),
          )
          .map((d) => d['date'])
          .toList();
      // Jul 18 Sat -> Mon Jul 20; Aug 18 is a Tuesday and Sep 18 a Friday,
      // no adjustment. All three cycles must land.
      expect(dueDays, ['2026-07-20', '2026-08-18', '2026-09-18']);
    });

    test('a fully paid debt is silent', () {
      final data = fixture();
      data['debts'] = [
        {'id': 'd1', 'name': 'Paid card', 'remaining': 0, 'dueDay': 10},
      ];
      final tl = sweldoTimeline(data, now, horizonDays: 60);
      expect(
        (tl['days'] as List).cast<Map<String, dynamic>>().every(
          (d) => (d['events'] as List).isEmpty || d['date'] != '2026-08-10',
        ),
        isTrue,
      );
      expect((tl['assumptions'] as Map)['debtCount'], 0);
    });
  });

  group('paydays and the tightest day before payday', () {
    test('paydays come from the schedule and mark the days', () {
      final tl = sweldoTimeline(fixture(), now, horizonDays: 60);
      expect(tl['paydays'], ['2026-07-30', '2026-08-30']);
      final day = (tl['days'] as List).cast<Map<String, dynamic>>().firstWhere(
        (d) => d['date'] == '2026-07-30',
      );
      expect(day['isPayday'], isTrue);
    });

    test('the tightest day strictly before the next payday is named', () {
      final tl = sweldoTimeline(fixture(), now, horizonDays: 60);
      expect(tl['lowestBeforePayday'], {
        'date': '2026-07-20',
        'balance': 3500.0,
      });
    });

    test('no schedule, no paydays asserted, ever', () {
      final data = fixture();
      (data['settings'] as Map).remove('paydaySchedule');
      final tl = sweldoTimeline(data, now, horizonDays: 60);
      expect(tl['paydays'], isEmpty);
      expect(tl['lowestBeforePayday'], isNull);
    });
  });

  group('the variable spend band', () {
    Map<String, dynamic> withSpending() {
      final data = fixture();
      // 1400 of ordinary spending inside the trailing 28 full days
      // (Jun 17 to Jul 14 inclusive): rate = 1400 / 28 = 50 a day.
      data['transactions'] = [
        {'id': 't1', 'type': 'expense', 'amount': 700, 'date': '2026-07-01'},
        {'id': 't2', 'type': 'expense', 'amount': 700, 'date': '2026-07-10'},
        // All four below must be EXCLUDED: a recurring post, a debt payment,
        // an income row, and a spend outside the window.
        {
          'id': 't3',
          'type': 'expense',
          'amount': 8000,
          'date': '2026-07-05',
          'recurringId': 'r2',
        },
        {
          'id': 't4',
          'type': 'expense',
          'amount': 2500,
          'date': '2026-07-10',
          'debtId': 'd1',
        },
        {'id': 't5', 'type': 'income', 'amount': 20000, 'date': '2026-06-30'},
        {'id': 't6', 'type': 'expense', 'amount': 9999, 'date': '2026-06-01'},
      ];
      return data;
    }

    test('the rate is the 28 day average of ordinary spending only', () {
      final r = variableSpendRate(withSpending(), now);
      expect(r.dailyRate, 50.0);
      expect(r.sampleCount, 2);
    });

    test('bandLow drains from tomorrow and never touches the line', () {
      final tl = sweldoTimeline(withSpending(), now, horizonDays: 30);
      // Today: no band drain yet.
      final today = (tl['days'] as List).cast<Map<String, dynamic>>().first;
      expect(today['balance'], 5000.0);
      expect(today['bandLow'], 5000.0);
      // Jul 16 is one band day: 5000 - 50. The conservative line is
      // untouched at 5000.
      final d1 = (tl['days'] as List).cast<Map<String, dynamic>>()[1];
      expect(d1['balance'], 5000.0);
      expect(d1['bandLow'], 4950.0);
      // Jul 20, five band days and the internet bill: line 3500, band
      // 3500 - 250.
      final d5 = (tl['days'] as List).cast<Map<String, dynamic>>().firstWhere(
        (d) => d['date'] == '2026-07-20',
      );
      expect(d5['balance'], 3500.0);
      expect(d5['bandLow'], 3250.0);
    });

    test('no qualifying spending means a zero rate, not a guess', () {
      final r = variableSpendRate(fixture(), now);
      expect(r.dailyRate, 0.0);
      expect(r.sampleCount, 0);
    });
  });

  group('scenarios are pure overlays', () {
    test('a one time purchase can push the line negative, hand-checked', () {
      final tl = sweldoTimeline(
        fixture(),
        now,
        horizonDays: 30,
        scenarios: [
          {
            'kind': 'purchase',
            'label': 'Phone',
            'amount': 12000,
            'date': '2026-07-25',
          },
        ],
      );
      // Jul 20: 3500. Jul 25: 3500 - 12000 = -8500. Sweldo rescues on the
      // 30th: -8500 + 20000 = 11500.
      expect(balanceOn(tl, '2026-07-25'), -8500.0);
      expect(tl['anyNegative'], isTrue);
      expect(tl['firstNegativeDate'], '2026-07-25');
      expect(balanceOn(tl, '2026-07-30'), 11500.0);
    });

    test('an extra monthly payment lands every month as money out', () {
      final tl = sweldoTimeline(
        fixture(),
        now,
        horizonDays: 60,
        scenarios: [
          {
            'kind': 'extraMonthly',
            'label': 'Extra to card',
            'amount': 1000,
            'dayOfMonth': 28,
          },
        ],
      );
      // Jul 28: 3500 - 1000 = 2500. Aug 28: 14000 - 1000 - 1000 = 12000.
      expect(balanceOn(tl, '2026-07-28'), 2500.0);
      expect(balanceOn(tl, '2026-08-28'), 12000.0);
      expect(tl['lowest'], {'date': '2026-07-28', 'balance': 2500.0});
    });

    test('an income raise lands as money in on its day', () {
      final tl = sweldoTimeline(
        fixture(),
        now,
        horizonDays: 30,
        scenarios: [
          {
            'kind': 'incomeChange',
            'label': 'Raise',
            'amount': 5000,
            'dayOfMonth': 30,
          },
        ],
      );
      expect(balanceOn(tl, '2026-07-30'), 28500.0);
    });

    test('a spending cut shrinks the band, floor at zero', () {
      final data = fixture();
      data['transactions'] = [
        {'id': 't1', 'type': 'expense', 'amount': 1400, 'date': '2026-07-01'},
      ];
      final tl = sweldoTimeline(
        data,
        now,
        horizonDays: 10,
        scenarios: [
          {
            'kind': 'cutSpending',
            'label': 'Less delivery',
            'amountPerMonth': 3000,
          },
        ],
      );
      // Base rate 50 a day, cut 100 a day, clamped to zero: band hugs the
      // line instead of inventing income.
      expect((tl['band'] as Map)['dailyRate'], 0.0);
      final d1 = (tl['days'] as List).cast<Map<String, dynamic>>()[1];
      expect(d1['bandLow'], d1['balance']);
    });

    test('the base run is untouched by scenarios, overlay means overlay', () {
      final base = sweldoTimeline(fixture(), now, horizonDays: 30);
      sweldoTimeline(
        fixture(),
        now,
        horizonDays: 30,
        scenarios: [
          {
            'kind': 'purchase',
            'label': 'Phone',
            'amount': 12000,
            'date': '2026-07-25',
          },
        ],
      );
      final again = sweldoTimeline(fixture(), now, horizonDays: 30);
      expect(balanceOn(base, '2026-07-25'), balanceOn(again, '2026-07-25'));
      expect(base['anyNegative'], isFalse);
    });
  });

  group('the free horizon', () {
    test('runs to the next payday when a schedule exists', () {
      // Jul 15 to Jul 30 is 15 days.
      expect(freeHorizonDays(fixture(), now), 15);
    });

    test('falls back to the end of the month without a schedule', () {
      final data = fixture();
      (data['settings'] as Map).remove('paydaySchedule');
      // Jul 15 to Jul 31 is 16 days, the calendar screen's existing window.
      expect(freeHorizonDays(data, now), 16);
    });
  });

  test('junk data never throws', () {
    final junk = {
      'accounts': [
        null,
        42,
        {'kind': 'cash', 'balance': 'abc'},
      ],
      'recurring': [
        null,
        {'amount': 'x', 'dayOfMonth': 99},
        7,
      ],
      'debts': [
        null,
        {'remaining': 'abc', 'dueDay': 'x'},
      ],
      'transactions': [
        null,
        'x',
        {'type': 'expense', 'amount': double.nan},
      ],
      'settings': {'paydaySchedule': 'not a map'},
    };
    expect(
      () => sweldoTimeline(
        junk,
        now,
        horizonDays: 90,
        scenarios: [
          {'kind': 'purchase', 'amount': 'x', 'date': 'garbage'},
          {'kind': 'unknown'},
          {'kind': 'cutSpending', 'amountPerMonth': -5},
        ],
      ),
      returnsNormally,
    );
    expect(() => freeHorizonDays(junk, now), returnsNormally);
  });
}
