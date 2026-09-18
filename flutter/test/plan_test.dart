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
      // The card's bar: 2500 in of a 12000 journey (2500 + 9500 left).
      expect(s['progress'], closeTo(2500 / 12000, 1e-9));
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
          // targetDate, the field goals really store. The first version of
          // this fixture said dueDate, the same wrong mental model as the
          // code it was testing, so the deadline-pace branch passed while
          // being dead in production. Field names in fixtures must match
          // the writer (store.addGoal), not the reader's guess.
          'targetDate': '2027-01-15',
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

    test(
      'a pace that rounds to zero kills the offer instead of storing it',
      () {
        // Target 1000, saved 995, no date: gap 5 over a default year is 0.42,
        // which rounds to 0. A zero-amount plan is one activePlanOf rejects,
        // so accepting it would create a plan with no card, no Drop button,
        // and a permanent block on every future offer. The offer must die
        // here, before it can be tapped.
        final nearDone = {
          'settings': <String, dynamic>{},
          'goals': [
            {'id': 'g9', 'name': 'Trip', 'target': 1000, 'saved': 995},
          ],
        };
        expect(planOfferFor(nearDone, 'goal_pace', now), isNull);
      },
    );

    test('an absurd asked amount falls back to the minimum payment', () {
      // The edit sheet refuses anything over 100 million; the chip must
      // never offer what the sheet would refuse to save.
      final offer = planOfferFor(
        data,
        'debt_free',
        now,
        askedAmount: 999999999999,
      )!;
      expect(offer['amount'], 1250.0);
    });

    test('the goal offer follows the goal the message names', () {
      final twoGoals = {
        'settings': <String, dynamic>{},
        'goals': [
          {
            'id': 'g1',
            'name': 'Emergency fund',
            'target': 60000,
            'saved': 30000,
          },
          {'id': 'g2', 'name': 'Pasko fund', 'target': 12000, 'saved': 6000},
        ],
      };
      final offer = planOfferFor(
        twoGoals,
        'goal_pace',
        now,
        raw: 'am I on track for the pasko fund?',
      )!;
      expect(offer['targetId'], 'g2');
      expect(offer['label'], 'Save for Pasko fund');
    });

    test('with nothing named, the offer follows the behind goal first', () {
      // The resolver's focus order is named, then behind, then lowest pct.
      // The offer must land on the SAME goal the reply is talking about;
      // the first version took the first unfinished goal in list order, so
      // the reply could discuss one goal while the button silently
      // committed to another.
      final twoGoals = {
        'settings': <String, dynamic>{},
        'goals': [
          // Listed first, healthy: no deadline, half way.
          {
            'id': 'g1',
            'name': 'Emergency fund',
            'target': 60000,
            'saved': 30000,
          },
          // Behind: the deadline is already past.
          {
            'id': 'g2',
            'name': 'Pasko fund',
            'target': 12000,
            'saved': 6000,
            'targetDate': '2026-06-01',
          },
        ],
      };
      final offer = planOfferFor(twoGoals, 'goal_pace', now)!;
      expect(offer['targetId'], 'g2');
    });

    test('a month-only target date still gets the deadline pace', () {
      // Goals may store YYYY-MM; goalPace reads it, so the offer must too.
      // Jul 2026 to Jan 2027 is 6 whole months; 6000 short: 1000 a month.
      final monthOnly = {
        'settings': <String, dynamic>{},
        'goals': [
          {
            'id': 'g1',
            'name': 'Pasko fund',
            'target': 12000,
            'saved': 6000,
            'targetDate': '2027-01',
          },
        ],
      };
      final offer = planOfferFor(monthOnly, 'goal_pace', now)!;
      expect(offer['amount'], 1000.0);
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
