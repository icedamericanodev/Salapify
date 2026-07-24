// Unit suite for money/reminders.dart: the pure planner that decides which
// on-device reminders to fire. Adapted from mobile/lib/notifications.js; the
// plugin side is a thin shell, so all the logic worth testing is here. The
// invariants: nothing fires when a toggle is off, nothing fires in the past,
// the daily nudge is dropped once you have logged today, bills fire before and
// on the due date, utang fires for what is still owed, and junk never throws.

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/money/reminders.dart';
import 'package:salapify/money/statements.dart' show todayISO;

void main() {
  final now = DateTime(2026, 7, 15, 12); // noon, 15 July 2026.

  Map<String, dynamic> withNotifs(
    Map<String, dynamic> notifs, {
    Map<String, dynamic>? extra,
  }) => {
    'settings': {'notifications': notifs},
    ...?extra,
  };

  group('monthly backup nudge', () {
    final withData = {
      'accounts': [
        {'id': 'a', 'name': 'Cash', 'kind': 'cash', 'balance': 100},
      ],
    };

    test('fires on the 1st at 10am, future months only', () {
      final plans = plannedReminders(
        withNotifs({'backup': true}, extra: withData),
        now,
      );
      final backups = plans.where((p) => p.title == 'Monthly backup').toList();
      // From noon July 15: July 1 is past, so Aug 1 and Sep 1 remain.
      expect(backups.length, 2);
      expect(backups.first.when, DateTime(2026, 8, 1, 10));
      expect(backups.last.when, DateTime(2026, 9, 1, 10));
    });

    test('silent with the toggle off, and silent with nothing to lose', () {
      expect(
        plannedReminders(
          withNotifs({}, extra: withData),
          now,
        ).where((p) => p.title == 'Monthly backup'),
        isEmpty,
      );
      expect(
        plannedReminders(
          withNotifs({'backup': true}),
          now,
        ).where((p) => p.title == 'Monthly backup'),
        isEmpty,
        reason: 'an empty store has nothing worth nagging about',
      );
    });
  });

  test('no reminders when every toggle is off', () {
    final plans = plannedReminders(withNotifs({}), now);
    expect(plans, isEmpty);
  });

  test('the plan is sorted soonest-first, so a cap keeps the nearest', () {
    final data = withNotifs(
      {'daily': true, 'collect': true},
      extra: {
        'receivables': [
          {
            'id': 'r1',
            'person': 'Migs',
            'amount': 500,
            'dueDate': '2026-07-16',
          },
        ],
      },
    );
    final plans = plannedReminders(data, now);
    for (var i = 1; i < plans.length; i++) {
      expect(plans[i].when.isBefore(plans[i - 1].when), false);
    }
  });

  group('daily log nudge', () {
    test('schedules future evenings and never the past', () {
      final plans = plannedReminders(withNotifs({'daily': true}), now);
      expect(plans, isNotEmpty);
      expect(plans.every((p) => p.when.isAfter(now)), true);
      expect(plans.every((p) => p.when.hour == 20), true);
      // Tonight (the 15th at 8pm) is still ahead of noon, so it is included.
      expect(plans.any((p) => p.when.day == 15), true);
    });

    test('drops tonight once you have logged today', () {
      final data = withNotifs(
        {'daily': true},
        extra: {
          'transactions': [
            {'date': todayISO(now), 'type': 'expense', 'amount': 100},
          ],
        },
      );
      final plans = plannedReminders(data, now);
      // The 15th (today) is skipped; the next nudge is the 16th onward.
      expect(plans.any((p) => p.when.day == 15), false);
      expect(plans.any((p) => p.when.day == 16), true);
    });
  });

  group('bills due', () {
    // A credit card with a statement/grace cycle so bankDueDate resolves.
    Map<String, dynamic> billData() => withNotifs(
      {'bills': true},
      extra: {
        'debts': [
          {
            'id': 'd1',
            'name': 'BPI card',
            'remaining': 8000,
            'minPayment': 500,
            'apr': 36,
            'statementDay': 20,
            'graceDays': 21,
          },
        ],
      },
    );

    test('fires a heads-up and a due-day reminder, all in the future', () {
      final plans = plannedReminders(billData(), now);
      expect(plans, isNotEmpty);
      expect(plans.every((p) => p.when.isAfter(now)), true);
      expect(plans.any((p) => p.title.contains('due in 3 days')), true);
      expect(plans.any((p) => p.title.contains('due today')), true);
      // The minimum is named on the lock-screen line.
      expect(plans.any((p) => p.body.contains('500')), true);
    });

    test('a fully paid debt is not chased', () {
      final data = billData();
      (data['debts'] as List)[0]['remaining'] = 0;
      expect(plannedReminders(data, now), isEmpty);
    });
  });

  group('utang to collect', () {
    test('reminds for what is still owed after partial payment', () {
      final data = withNotifs(
        {'collect': true},
        extra: {
          'receivables': [
            {
              'id': 'r1',
              'person': 'Migs',
              'amount': 1000,
              'dueDate': '2026-07-20',
              'payments': [
                {'amount': 400, 'date': '2026-07-10'},
              ],
            },
          ],
        },
      );
      final plans = plannedReminders(data, now);
      expect(plans, isNotEmpty);
      // Owes 600 now, not the original 1000.
      expect(plans.any((p) => p.body.contains('600')), true);
      expect(plans.any((p) => p.body.contains('1,000')), false);
    });

    test('a paid or fully-collected utang is silent', () {
      final data = withNotifs(
        {'collect': true},
        extra: {
          'receivables': [
            {
              'id': 'r1',
              'person': 'Migs',
              'amount': 1000,
              'dueDate': '2026-07-20',
              'paid': true,
            },
            {
              'id': 'r2',
              'person': 'Ana',
              'amount': 500,
              'dueDate': '2026-07-20',
              'payments': [
                {'amount': 500, 'date': '2026-07-10'},
              ],
            },
          ],
        },
      );
      expect(plannedReminders(data, now), isEmpty);
    });
  });

  test('junk data never throws', () {
    final data = {
      'settings': {
        'notifications': {'daily': true, 'bills': true, 'collect': true},
      },
      'transactions': [null, 42, 'x'],
      'debts': [
        null,
        {'remaining': 'abc'},
        7,
      ],
      'receivables': [
        null,
        {'person': 5, 'dueDate': '2026-02-31', 'amount': 'x'},
      ],
    };
    expect(() => plannedReminders(data, now), returnsNormally);
  });
}
