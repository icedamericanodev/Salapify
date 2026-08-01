// Unit suite for money/plan.dart, the standing plan engine. Hand-computed
// literals throughout, and the FIRST vectors exercise the month-boundary
// clamp, the one edge month arithmetic exists to handle. That ordering is
// the session 28 rule made practice: convenient dates and the edge are
// mutually exclusive, so the edge goes first or it goes untested.

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/money/plan.dart';

void main() {
  group('periodsCompleted, the edge first', () {
    test('a monthly plan started Jan 31 clamps through short months', () {
      final start = DateTime(2026, 1, 31);
      // 2026 is not a leap year: the first period completes on Feb 28.
      expect(periodsCompleted(start, DateTime(2026, 2, 27), 'monthly'), 0);
      expect(periodsCompleted(start, DateTime(2026, 2, 28), 'monthly'), 1);
      // March has a real 31st again, so the second period waits for it.
      expect(periodsCompleted(start, DateTime(2026, 3, 30), 'monthly'), 1);
      expect(periodsCompleted(start, DateTime(2026, 3, 31), 'monthly'), 2);
      expect(periodsCompleted(start, DateTime(2026, 4, 30), 'monthly'), 3);
    });

    test('an ordinary monthly plan counts month birthdays', () {
      final start = DateTime(2026, 5, 15);
      expect(periodsCompleted(start, DateTime(2026, 5, 20), 'monthly'), 0);
      expect(periodsCompleted(start, DateTime(2026, 6, 15), 'monthly'), 1);
      expect(periodsCompleted(start, DateTime(2026, 7, 15), 'monthly'), 2);
    });

    test('weekly is whole weeks, never partial', () {
      final start = DateTime(2026, 7, 15);
      expect(periodsCompleted(start, DateTime(2026, 7, 21), 'weekly'), 0);
      expect(periodsCompleted(start, DateTime(2026, 7, 22), 'weekly'), 1);
      expect(periodsCompleted(start, DateTime(2026, 8, 4), 'weekly'), 2);
    });

    test('a start in the future owes nothing', () {
      expect(
        periodsCompleted(DateTime(2026, 8, 1), DateTime(2026, 7, 15), 'weekly'),
        0,
      );
    });
  });

  Map<String, dynamic> debtData({num remaining = 9500}) => {
    'settings': {
      'activePlan': {
        'kind': 'debt',
        'targetId': 'card',
        'label': 'Extra to BPI card',
        'amount': 1000,
        'cadence': 'monthly',
        'startDate': '2026-05-15',
        'startLevel': 12000,
      },
    },
    'debts': [
      {'id': 'card', 'name': 'BPI card', 'remaining': remaining},
    ],
  };

  final now = DateTime(2026, 7, 15, 12);

  group('planStatus for a debt plan', () {
    test('on track: paid roughly what the pace expects, hand-checked', () {
      final s = planStatus(debtData(), now)!;
      // Two periods done (Jun 15, Jul 15) at 1000: expected 2000. Remaining
      // fell 12000 to 9500: actual 2500. Delta 500, within one period.
      expect(s['periods'], 2);
      expect(s['expected'], 2000.0);
      expect(s['actual'], 2500.0);
      expect(s['delta'], 500.0);
      expect(s['state'], 'onTrack');
      expect(s['leadPeriods'], 0);
    });

    test('ahead by two full periods says so', () {
      final s = planStatus(debtData(remaining: 8000), now)!;
      expect(s['actual'], 4000.0);
      expect(s['state'], 'ahead');
      expect(s['leadPeriods'], 2);
    });

    test('behind by more than a period says so, without shame words', () {
      final s = planStatus(debtData(remaining: 11500), now)!;
      expect(s['actual'], 500.0);
      expect(s['delta'], -1500.0);
      expect(s['state'], 'behind');
      expect(s['leadPeriods'], -1);
    });

    test('a debt at zero is done, whatever the pace says', () {
      final s = planStatus(debtData(remaining: 0), now)!;
      expect(s['state'], 'done');
    });

    test('a freshly started plan owes nothing yet', () {
      final data = debtData();
      ((data['settings'] as Map)['activePlan'] as Map)['startDate'] =
          '2026-07-10';
      final s = planStatus(data, now)!;
      expect(s['periods'], 0);
      expect(s['state'], 'started');
    });

    test('a deleted target orphans the plan instead of crashing', () {
      final data = debtData();
      data['debts'] = <Map<String, dynamic>>[];
      final s = planStatus(data, now)!;
      expect(s['state'], 'orphaned');
    });
  });

  group('planStatus for a goal plan', () {
    Map<String, dynamic> goalData({num saved = 6000}) => {
      'settings': {
        'activePlan': {
          'kind': 'goal',
          'targetId': 'g1',
          'label': 'Save for Emergency fund',
          'amount': 500,
          'cadence': 'weekly',
          'startDate': '2026-06-17',
          'startLevel': 4000,
        },
      },
      'goals': [
        {'id': 'g1', 'name': 'Emergency fund', 'target': 10000, 'saved': saved},
      ],
    };

    test('weekly pace against saved-since-start, hand-checked', () {
      // Jun 17 to Jul 15 is 28 days: 4 weeks, expected 2000. Saved moved
      // 4000 to 6000: actual 2000, dead on pace.
      final s = planStatus(goalData(), now)!;
      expect(s['periods'], 4);
      expect(s['expected'], 2000.0);
      expect(s['actual'], 2000.0);
      expect(s['state'], 'onTrack');
      expect(s['remaining'], 4000.0);
    });

    test('reaching the goal target is done', () {
      final s = planStatus(goalData(saved: 10000), now)!;
      expect(s['state'], 'done');
    });
  });

  group('activePlanOf rejects junk instead of throwing', () {
    test('bad shapes all read as no plan', () {
      final shapes = <dynamic>[
        null,
        'not a map',
        {'kind': 'debt'},
        {
          'kind': 'crypto',
          'targetId': 'x',
          'amount': 1,
          'cadence': 'weekly',
          'startDate': '2026-01-01',
        },
        {
          'kind': 'debt',
          'targetId': '',
          'amount': 1,
          'cadence': 'weekly',
          'startDate': '2026-01-01',
        },
        {
          'kind': 'debt',
          'targetId': 'x',
          'amount': 0,
          'cadence': 'weekly',
          'startDate': '2026-01-01',
        },
        {
          'kind': 'debt',
          'targetId': 'x',
          'amount': 1,
          'cadence': 'daily',
          'startDate': '2026-01-01',
        },
        {
          'kind': 'debt',
          'targetId': 'x',
          'amount': 1,
          'cadence': 'weekly',
          'startDate': '2026-02-31',
        },
      ];
      for (final s in shapes) {
        expect(
          activePlanOf({
            'settings': {'activePlan': s},
          }),
          isNull,
          reason: 'shape $s must read as no plan',
        );
        expect(
          () => planStatus({
            'settings': {'activePlan': s},
          }, now),
          returnsNormally,
        );
      }
    });
  });

  group('planOfferFor', () {
    final data = {
      'settings': <String, dynamic>{},
      'debts': [
        {
          'id': 'd1',
          'name': 'Cheap loan',
          'remaining': 5000,
          'monthlyRate': 1,
          'minPayment': 500,
        },
        {
          'id': 'd2',
          'name': 'BPI card',
          'remaining': 12000,
          'monthlyRate': 3,
          'minPayment': 1250,
        },
      ],
      'goals': [
        {
          'id': 'g1',
          'name': 'Pasko fund',
          'target': 12000,
          'saved': 6000,
          'dueDate': '2027-01-15',
        },
      ],
    };

    test('debt_free offers the costliest debt at the asked amount', () {
      final offer = planOfferFor(data, 'debt_free', now, askedAmount: 1500)!;
      expect(offer['targetId'], 'd2');
      expect(offer['amount'], 1500);
      expect(offer['cadence'], 'monthly');
      expect(offer['startLevel'], 12000.0);
      expect(offer['startDate'], '2026-07-15');
    });

    test('goal_pace offers the deadline pace toward the open goal', () {
      // Jul 2026 to Jan 2027 is 6 whole months; 6000 short: 1000 a month.
      final offer = planOfferFor(data, 'goal_pace', now)!;
      expect(offer['targetId'], 'g1');
      expect(offer['amount'], 1000.0);
      expect(offer['startLevel'], 6000.0);
    });

    test('one plan at a time: an existing plan blocks every offer', () {
      final withPlan = {
        ...data,
        'settings': {
          'activePlan': {
            'kind': 'debt',
            'targetId': 'd2',
            'amount': 1000,
            'cadence': 'monthly',
            'startDate': '2026-07-01',
          },
        },
      };
      expect(planOfferFor(withPlan, 'debt_free', now), isNull);
      expect(planOfferFor(withPlan, 'goal_pace', now), isNull);
    });
  });
}
