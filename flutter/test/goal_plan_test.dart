// Unit suite for money/goal_plan.dart. Hand-computed literals, and the FIRST
// vectors exercise the edges the functions exist to handle (deadline today,
// deadline passed, zero target, over target), per the session 28 rule:
// convenient inputs and the edge are mutually exclusive, so the edge goes
// first or it goes untested.

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/money/goal_plan.dart';

void main() {
  final now = DateTime(2026, 7, 15);

  group('requiredContribution, the edges first', () {
    test('no deadline asks for nothing, honestly', () {
      final r = requiredContribution({
        'target': 10000,
        'saved': 2000,
        'targetDate': '',
      }, now);
      expect(r['hasDeadline'], isFalse);
      expect(r['amount'], 0.0);
      expect(r['remaining'], 8000.0);
    });

    test('a deadline this month asks for the whole gap', () {
      final r = requiredContribution({
        'target': 10000,
        'saved': 4000,
        'targetDate': '2026-07-31',
      }, now);
      // goalPace calls this due-soon: monthsLeft 0, perMonth = remaining.
      expect(r['hasDeadline'], isTrue);
      expect(r['amount'], 6000.0);
    });

    test('a passed deadline still reports the gap, no shame attached', () {
      final r = requiredContribution({
        'target': 10000,
        'saved': 4000,
        'targetDate': '2026-06-01',
      }, now);
      expect(r['status'], 'behind');
      expect(r['amount'], 6000.0);
    });

    test('zero target and over-target owe nothing', () {
      expect(
        requiredContribution({
          'target': 0,
          'saved': 500,
          'targetDate': '2026-12-31',
        }, now)['amount'],
        0.0,
      );
      expect(
        requiredContribution({
          'target': 1000,
          'saved': 1500,
          'targetDate': '2026-12-31',
        }, now)['amount'],
        0.0,
      );
    });

    test('an active deadline matches goalPace to the peso, monthly', () {
      // Jul 15 to Jan 15 is 6 whole months, 6000 short: ceil(1000) a month.
      final r = requiredContribution({
        'target': 12000,
        'saved': 6000,
        'targetDate': '2027-01-15',
      }, now);
      expect(r['amount'], 1000.0);
      expect(r['frequency'], 'monthly');
    });

    test('weekly frequency reads the weekly pace', () {
      final r = requiredContribution({
        'target': 12000,
        'saved': 6000,
        'targetDate': '2027-01-15',
        'frequency': 'weekly',
      }, now);
      // goalPace perWeek: 6000 / (6 * 52/12) = 230.77, ceil 231.
      expect(r['amount'], 231.0);
      expect(r['frequency'], 'weekly');
    });
  });

  group('goalStatusLabel', () {
    test('paused outranks everything, even done', () {
      expect(
        goalStatusLabel({'target': 100, 'saved': 100, 'paused': true}, now),
        'Paused',
      );
    });

    test('the six labels land on their states', () {
      expect(goalStatusLabel({'target': 100, 'saved': 100}, now), 'Completed');
      expect(
        goalStatusLabel({
          'target': 100,
          'saved': 10,
          'targetDate': '2026-06-01',
        }, now),
        'Overdue',
      );
      expect(
        goalStatusLabel({
          'target': 100,
          'saved': 10,
          'targetDate': '2026-07-31',
        }, now),
        'Needs adjustment',
      );
      // No date, active: nothing to be behind.
      expect(goalStatusLabel({'target': 100, 'saved': 10}, now), 'On track');
    });

    test('ahead and needs-adjustment come from the linear expectation', () {
      // Created Jan 15 aiming Jan 15 next year, from 0 to 12000: by Jul 15
      // the plan expects 181/365 of it, about 5950. One month's share is
      // about 986.
      Map<String, dynamic> g(double saved) => {
        'target': 12000,
        'saved': saved,
        'targetDate': '2027-01-15',
        'createdAt': '2026-01-15',
        'startSaved': 0,
      };
      expect(goalStatusLabel(g(7000), now), 'Ahead');
      expect(goalStatusLabel(g(6000), now), 'On track');
      expect(goalStatusLabel(g(4900), now), 'Needs adjustment');
    });

    test('a legacy goal with no createdAt reads On track while active', () {
      expect(
        goalStatusLabel({
          'target': 12000,
          'saved': 100,
          'targetDate': '2027-01-15',
        }, now),
        'On track',
      );
    });
  });

  group('goalWhatIf', () {
    test('a one-time top-up that finishes it finishes today', () {
      final r = goalWhatIf(
        {'target': 1000, 'saved': 900},
        now,
        perPeriod: 0,
        oneTime: 100,
      )!;
      expect(r['finishDate'], '2026-07-15');
      expect(r['periods'], 0);
    });

    test('monthly pace projects a calendar finish and checks the deadline', () {
      final r = goalWhatIf(
        {'target': 10000, 'saved': 4000, 'targetDate': '2026-12-31'},
        now,
        perPeriod: 2000,
      )!;
      // 6000 gap at 2000: 3 months, Oct 15, inside Dec 31.
      expect(r['finishDate'], '2026-10-15');
      expect(r['meetsDeadline'], isTrue);
      final slow = goalWhatIf(
        {'target': 10000, 'saved': 4000, 'targetDate': '2026-08-31'},
        now,
        perPeriod: 2000,
      )!;
      expect(slow['meetsDeadline'], isFalse);
    });

    test('weekly pace walks in weeks', () {
      final r = goalWhatIf(
        {'target': 1000, 'saved': 0},
        now,
        perPeriod: 250,
        frequency: 'weekly',
      )!;
      expect(r['periods'], 4);
      expect(r['finishDate'], '2026-08-12');
    });

    test('a pace too small to finish inside the cap answers null', () {
      expect(
        goalWhatIf({'target': 1000000, 'saved': 0}, now, perPeriod: 1),
        isNull,
      );
      expect(goalWhatIf({'target': 1000, 'saved': 0}, now, perPeriod: 0), isNull);
    });
  });

  group('quarters', () {
    test('reached quarters floor at the line', () {
      expect(quartersReached({'target': 1000, 'saved': 249}), isEmpty);
      expect(quartersReached({'target': 1000, 'saved': 250}), [25]);
      expect(quartersReached({'target': 1000, 'saved': 1000}), [
        25,
        50,
        75,
        100,
      ]);
      expect(quartersReached({'target': 0, 'saved': 500}), isEmpty);
    });

    test('a crossing reports the highest line stepped over', () {
      expect(quarterCrossed(200, 600, 1000), 50);
      expect(quarterCrossed(200, 240, 1000), isNull);
      // Reaching the target itself is the milestone sheet's moment, not a
      // quarter toast: two celebrations on one tap is one too many.
      expect(quarterCrossed(700, 1000, 1000), isNull);
      expect(quarterCrossed(700, 800, 1000), 75);
      expect(quarterCrossed(0, 0, 0), isNull);
    });
  });

  group('essentialMonthly and the emergency suggestion', () {
    test('no data means null, never a made-up figure', () {
      expect(essentialMonthly({'recurring': [], 'transactions': []}, now),
          isNull);
    });

    test('recurring bills plus trailing spend, scaled honestly', () {
      final data = {
        'recurring': [
          {'id': 'r1', 'type': 'expense', 'label': 'Rent', 'amount': 8000},
          {'id': 'r2', 'type': 'income', 'label': 'Sweldo', 'amount': 30000},
        ],
        'transactions': <Map<String, dynamic>>[],
      };
      final e = essentialMonthly(data, now)!;
      expect(e['recurring'], 8000.0);
      expect(e['total'], 8000.0);
    });

    test('the emergency template suggests three months, whole hundreds', () {
      final data = {
        'recurring': [
          {'id': 'r1', 'type': 'expense', 'label': 'Rent', 'amount': 8050},
        ],
        'transactions': <Map<String, dynamic>>[],
      };
      final t = goalTemplates(data, now).firstWhere((t) => t.key == 'emergency');
      // 8050 * 3 = 24150, ceil to hundreds: 24200.
      expect(t.suggestedTarget, 24200.0);
      expect(t.why, isNotNull);
    });

    test('without data the emergency template offers no number', () {
      final t = goalTemplates({}, now).firstWhere((t) => t.key == 'emergency');
      expect(t.suggestedTarget, isNull);
      expect(t.why, isNull);
    });

    test('pasko aims at December 1, flipping to next year from October', () {
      expect(
        goalTemplates({}, DateTime(2026, 7, 15))
            .firstWhere((t) => t.key == 'pasko')
            .suggestedDeadline,
        '2026-12-01',
      );
      expect(
        goalTemplates({}, DateTime(2026, 10, 2))
            .firstWhere((t) => t.key == 'pasko')
            .suggestedDeadline,
        '2027-12-01',
      );
    });

    test('debt payoff appears only when a live debt exists', () {
      expect(
        goalTemplates({}, now).where((t) => t.key == 'debtPayoff'),
        isEmpty,
      );
      final withDebt = {
        'debts': [
          {'id': 'd1', 'name': 'Card', 'remaining': 5000},
        ],
      };
      expect(
        goalTemplates(withDebt, now).where((t) => t.key == 'debtPayoff'),
        isNotEmpty,
      );
    });

    test('custom offers no recommendation, ever', () {
      final t = goalTemplates({}, now).firstWhere((t) => t.key == 'custom');
      expect(t.suggestedTarget, isNull);
      expect(t.suggestedDeadline, isNull);
      expect(t.why, isNull);
    });
  });

  group('safeToSetAside', () {
    final base = {
      'accounts': [
        {'id': 'c', 'name': 'Cash', 'kind': 'cash', 'balance': 9000},
      ],
      'settings': {
        'paydaySchedule': {'mode': 'monthly', 'day': 30},
      },
      'debts': <Map<String, dynamic>>[],
      'recurring': <Map<String, dynamic>>[],
    };

    test('no liquid account, no estimate', () {
      expect(safeToSetAside({'accounts': []}, now), isNull);
    });

    test('no payday and no bills, no estimate', () {
      expect(
        safeToSetAside({
          'accounts': [
            {'id': 'c', 'name': 'Cash', 'kind': 'cash', 'balance': 9000},
          ],
        }, now),
        isNull,
      );
    });

    test('the default buffer holds back 1000', () {
      final r = safeToSetAside(base, now)!;
      expect(r['buffer'], 1000.0);
      expect(r['amount'], (r['available'] as double) - 1000.0);
    });

    test('a user buffer replaces the default, and the floor is zero', () {
      final r = safeToSetAside({
        ...base,
        'settings': {
          'paydaySchedule': {'mode': 'monthly', 'day': 30},
          'goalBuffer': 8500,
        },
      }, now)!;
      expect(r['buffer'], 8500.0);
      expect(r['amount'], greaterThanOrEqualTo(0.0));
    });
  });

  group('focusGoal', () {
    test('user priority beats every rule', () {
      final f = focusGoal([
        {
          'id': 'a',
          'target': 100,
          'saved': 0,
          'targetDate': '2026-06-01',
        },
        {'id': 'b', 'target': 100, 'saved': 0, 'priority': 0},
      ], now);
      expect(f!['id'], 'b');
    });

    test('without priority, overdue first, then soonest date', () {
      final f = focusGoal([
        {'id': 'a', 'target': 100, 'saved': 0, 'targetDate': '2027-05-01'},
        {'id': 'b', 'target': 100, 'saved': 0, 'targetDate': '2026-06-01'},
      ], now);
      expect(f!['id'], 'b');
    });

    test('paused and finished goals never take focus', () {
      final f = focusGoal([
        {'id': 'a', 'target': 100, 'saved': 100},
        {'id': 'b', 'target': 100, 'saved': 0, 'paused': true},
        {'id': 'c', 'target': 100, 'saved': 10},
      ], now);
      expect(f!['id'], 'c');
      expect(focusGoal([], now), isNull);
    });
  });

  group('debtGoalFigures', () {
    final data = {
      'debts': [
        {'id': 'd1', 'name': 'BPI card', 'remaining': 8000},
      ],
    };

    test('derives from the linked debt, never copies its balance', () {
      final f = debtGoalFigures({
        'kind': 'debt',
        'linkedDebtId': 'd1',
        'startLevel': 12000,
      }, data)!;
      expect(f['target'], 12000.0);
      expect(f['saved'], 4000.0);
      expect(f['remaining'], 8000.0);
      expect(f['done'], isFalse);
    });

    test('a deleted debt answers null instead of guessing', () {
      expect(
        debtGoalFigures({
          'kind': 'debt',
          'linkedDebtId': 'gone',
          'startLevel': 12000,
        }, data),
        isNull,
      );
      expect(debtGoalFigures({'kind': 'savings'}, data), isNull);
    });

    test('a debt paid to zero reads done', () {
      final f = debtGoalFigures(
        {'kind': 'debt', 'linkedDebtId': 'd1', 'startLevel': 12000},
        {
          'debts': [
            {'id': 'd1', 'name': 'BPI card', 'remaining': 0},
          ],
        },
      )!;
      expect(f['done'], isTrue);
      expect(f['saved'], 12000.0);
    });
  });
}
