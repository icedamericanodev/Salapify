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

    test('fires for an utang-only user (debts, no account or transaction)', () {
      // Salapify is an utang tracker first: a debts-only user has data worth a
      // backup file, so the nudge must reach them. The old accounts-or-
      // transactions gate silently skipped this exact user.
      final plans = plannedReminders(
        withNotifs(
          {'backup': true},
          extra: {
            'debts': [
              {'id': 'd1', 'name': 'BPI card', 'remaining': 8000},
            ],
          },
        ),
        now,
      );
      expect(plans.where((p) => p.title == 'Monthly backup'), isNotEmpty);
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
    });

    test('the DEFAULT reminder names no debt and no amount, anywhere', () {
      // The lock-screen privacy contract. With detailed off (the default), not
      // one reminder may carry the debt name or the peso amount, in the title
      // OR the body. This test used to assert the OPPOSITE, that 500 appeared
      // "on the lock-screen line", which is exactly the leak it now guards
      // against. Proven to fail by pointing plannedReminders at detailed:true.
      final plans = plannedReminders(billData(), now);
      expect(plans, isNotEmpty);
      for (final p in plans) {
        expect(
          p.title.contains('BPI card'),
          isFalse,
          reason: 'debt name leaked into a default title',
        );
        expect(
          p.body.contains('BPI card'),
          isFalse,
          reason: 'debt name leaked into a default body',
        );
        expect(
          p.body.contains('500'),
          isFalse,
          reason: 'peso amount leaked into a default body',
        );
      }
    });

    test('detailed names the debt and amount, but only in the body', () {
      final plans = plannedReminders(billData(), now, detailed: true);
      expect(
        plans.any((p) => p.body.contains('BPI card')),
        isTrue,
        reason: 'opt-in detail should name the debt in the body',
      );
      expect(
        plans.any((p) => p.body.contains('500')),
        isTrue,
        reason: 'opt-in detail should show the amount in the body',
      );
      // The title stays generic even with detail on, because the title is the
      // one line the lock screen can still show under VISIBILITY_PRIVATE.
      for (final p in plans) {
        expect(
          p.title.contains('BPI card'),
          isFalse,
          reason: 'the debt name must never reach the title',
        );
        expect(
          p.title.contains('500'),
          isFalse,
          reason: 'the amount must never reach the title',
        );
      }
    });

    test('a fully paid debt is not chased', () {
      final data = billData();
      (data['debts'] as List)[0]['remaining'] = 0;
      expect(plannedReminders(data, now), isEmpty);
    });
  });

  group('utang to collect', () {
    // Migs owes 1000, has paid 400, so 600 remains.
    Map<String, dynamic> collectData() => withNotifs(
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

    test('reminds for what is still owed after partial payment', () {
      final plans = plannedReminders(collectData(), now);
      expect(plans, isNotEmpty);
      expect(plans.every((p) => p.when.isAfter(now)), true);
    });

    test('the DEFAULT collect reminder names no person and no amount', () {
      final plans = plannedReminders(collectData(), now);
      expect(plans, isNotEmpty);
      for (final p in plans) {
        expect(
          p.title.contains('Migs') || p.body.contains('Migs'),
          isFalse,
          reason: 'person name leaked into a default reminder',
        );
        expect(
          p.body.contains('600'),
          isFalse,
          reason: 'remaining amount leaked into a default body',
        );
      }
    });

    test(
      'detailed names the person and remaining amount, only in the body',
      () {
        final plans = plannedReminders(collectData(), now, detailed: true);
        // Owes 600 now, not the original 1000.
        expect(plans.any((p) => p.body.contains('600')), isTrue);
        expect(plans.any((p) => p.body.contains('1,000')), isFalse);
        expect(
          plans.any((p) => p.body.contains('Migs')),
          isTrue,
          reason: 'opt-in detail should name the person in the body',
        );
        for (final p in plans) {
          expect(
            p.title.contains('Migs'),
            isFalse,
            reason: 'the person name must never reach the title',
          );
          expect(
            p.title.contains('600'),
            isFalse,
            reason: 'the amount must never reach the title',
          );
        }
      },
    );

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

  group('comeback ladder', () {
    // The four generic titles the comeback kind uses. Kept here so the tests
    // read by intent and a copy change is one edit.
    const comebackTitles = {
      'Still here when you are', // day 2
      'No catching up needed', // day 4
      'A fresh start this week', // day 7
      'Whenever you are ready', // day 14
    };
    List<PlannedReminder> comeback(List<PlannedReminder> plans) =>
        plans.where((p) => comebackTitles.contains(p.title)).toList();

    // A phone with something to come back to. Comeback shares the backup gate:
    // an empty store gets nothing.
    final withData = {
      'accounts': [
        {'id': 'a', 'name': 'Cash', 'kind': 'cash', 'balance': 100},
      ],
    };

    test('FIRES the full 2/4/7/14 ladder for a lapsed user, daily off', () {
      // The whole point of the feature: daily is OFF (the majority case), the
      // user has data, and nothing else is bringing them back. All four pings
      // land at 11:00, at now + 2, 4, 7 and 14 days.
      final plans = plannedReminders(
        withNotifs({'comeback': true}, extra: withData),
        now,
      );
      final pings = comeback(plans);
      expect(pings.map((p) => p.when).toList(), [
        DateTime(2026, 7, 17, 11), // +2
        DateTime(2026, 7, 19, 11), // +4
        DateTime(2026, 7, 22, 11), // +7
        DateTime(2026, 7, 29, 11), // +14
      ]);
      expect(pings.every((p) => p.when.hour == 11), true);
      // Carries no name, amount, or date, so it is lock-screen safe as-is.
      for (final p in pings) {
        expect(p.body.contains('₱'), isFalse);
      }
    });

    test('SILENT with the toggle off', () {
      final plans = plannedReminders(withNotifs({}, extra: withData), now);
      expect(comeback(plans), isEmpty);
    });

    test('SILENT for an empty store, nothing to come back to', () {
      final plans = plannedReminders(withNotifs({'comeback': true}), now);
      expect(
        comeback(plans),
        isEmpty,
        reason: 'a first-run user who bounced is onboarding\'s job, not this',
      );
    });

    test('FIRES for an utang-only user, no account or transaction', () {
      // The core audience: someone who tracks only who owes whom, never opens
      // an account or logs a spend. The old accounts-or-transactions gate
      // silently skipped them; "something to come back to" must include a
      // receivable.
      final plans = plannedReminders(
        withNotifs(
          {'comeback': true},
          extra: {
            'receivables': [
              {'id': 'r1', 'person': 'Migs', 'amount': 600},
            ],
          },
        ),
        now,
      );
      expect(
        comeback(plans),
        isNotEmpty,
        reason: 'an utang-only user has real data and must be brought back',
      );
    });

    test('with daily ON, fires ONLY the day 14 catch, no double-ping', () {
      // A lapsed daily user already gets a 20:00 nudge every evening for 14
      // days, so the early comeback pings would only pile on. Comeback then
      // fires exactly one ping, the morning after daily runs dry.
      final plans = plannedReminders(
        withNotifs({'comeback': true, 'daily': true}, extra: withData),
        now,
      );
      final pings = comeback(plans);
      expect(pings.map((p) => p.title).toList(), ['Whenever you are ready']);
      expect(pings.single.when, DateTime(2026, 7, 29, 11)); // +14 only
    });

    test('a reopen re-arms the ladder, so an active user never lets one fire', () {
      // The structural silent-for-active-users property, at the planner level.
      // The service wipes and rebuilds on every open, so the plan produced at a
      // LATER open must push the whole ladder forward: the day-2 ping the first
      // open armed is gone, replaced by one two days past the new open. An
      // active user who keeps reopening therefore never lets a ping stand.
      final firstOpen = plannedReminders(
        withNotifs({'comeback': true}, extra: withData),
        now, // noon, 15 Jul
      );
      final laterOpen = plannedReminders(
        withNotifs({'comeback': true}, extra: withData),
        now.add(const Duration(days: 3)), // reopened noon, 18 Jul
      );
      final firstEarliest = comeback(firstOpen).first.when;
      final laterEarliest = comeback(laterOpen).first.when;
      expect(firstEarliest, DateTime(2026, 7, 17, 11));
      expect(laterEarliest, DateTime(2026, 7, 20, 11));
      expect(
        laterEarliest.isAfter(firstEarliest),
        isTrue,
        reason: 'reopening must move the ladder forward, not leave it in place',
      );
      expect(
        comeback(laterOpen).any((p) => p.when == firstEarliest),
        isFalse,
        reason:
            'the ping the earlier open armed must be gone once the user returns',
      );
    });
  });

  group('cash flow lookahead', () {
    // Liquid 1000 and a 5000 bill on Jul 22: the conservative projection
    // first dips below zero on the 22nd, so the heads up lands the evening
    // before, Jul 21 at 18:00.
    Map<String, dynamic> tightData() => withNotifs(
      {'lookahead': true},
      extra: {
        'accounts': [
          {'id': 'a', 'name': 'Cash', 'kind': 'cash', 'balance': 1000},
        ],
        'recurring': [
          {
            'id': 'r1',
            'type': 'bill',
            'label': 'Rent',
            'amount': 5000,
            'dayOfMonth': 22,
          },
        ],
      },
    );

    test('FIRES the evening before the projected dip', () {
      final plans = plannedReminders(tightData(), now);
      final heads = plans
          .where((p) => p.title == 'Cash flow heads up')
          .toList();
      expect(heads, hasLength(1), reason: 'one dip, one heads up, never more');
      expect(heads.single.when, DateTime(2026, 7, 21, 18));
    });

    test('SILENT when the projection stays positive', () {
      final data = tightData();
      (data['accounts'] as List)[0]['balance'] = 50000;
      final plans = plannedReminders(data, now);
      expect(
        plans.where((p) => p.title == 'Cash flow heads up'),
        isEmpty,
        reason:
            'an alarm that fires on a healthy projection cries wolf, and a '
            'wolf-crying alarm gets its battery taken out',
      );
    });

    test('SILENT with the toggle off', () {
      final data = tightData();
      ((data['settings'] as Map)['notifications'] as Map).remove('lookahead');
      expect(
        plannedReminders(
          data,
          now,
        ).where((p) => p.title == 'Cash flow heads up'),
        isEmpty,
      );
    });

    test('the DEFAULT heads up carries no amount, name, or date', () {
      final p = plannedReminders(
        tightData(),
        now,
      ).firstWhere((p) => p.title == 'Cash flow heads up');
      expect(p.body.contains('₱'), isFalse);
      expect(p.body.contains('1,000'), isFalse);
      expect(p.body.contains('5,000'), isFalse);
      expect(p.body.contains('Rent'), isFalse);
      expect(p.body.contains('Jul'), isFalse);
    });

    test('detailed names the date only, never an amount or a name', () {
      final p = plannedReminders(
        tightData(),
        now,
        detailed: true,
      ).firstWhere((p) => p.title == 'Cash flow heads up');
      expect(p.body.contains('Jul 22'), isTrue);
      expect(p.body.contains('₱'), isFalse);
      expect(p.body.contains('5,000'), isFalse);
      expect(p.body.contains('Rent'), isFalse);
    });
  });

  group('goal check-in', () {
    Map<String, dynamic> goalData({
      bool on = true,
      bool paused = false,
      String targetDate = '2026-12-01',
      double saved = 1000,
    }) => withNotifs(
      {'goals': on},
      extra: {
        'goals': [
          {
            'id': 'g1',
            'name': 'Pasko fund',
            'target': 12000,
            'saved': saved,
            'targetDate': targetDate,
            if (paused) 'paused': true,
          },
        ],
      },
    );

    test('FIRES monthly for a dated active goal, generic title', () {
      final rs = plannedReminders(
        goalData(),
        now,
      ).where((r) => r.title == 'Goal check-in').toList();
      expect(rs, hasLength(2), reason: 'the 1st of the next two months');
      expect(rs.first.when, DateTime(2026, 8, 1, 10));
      // The generic body names no goal, no amount, no date.
      expect(rs.first.body.contains('Pasko'), isFalse);
    });

    test('the detailed body may name the goal, the title still never does', () {
      final rs = plannedReminders(
        goalData(),
        now,
        detailed: true,
      ).where((r) => r.title == 'Goal check-in').toList();
      expect(rs.first.body.contains('Pasko fund'), isTrue);
      expect(rs.first.title.contains('Pasko'), isFalse);
    });

    test('SILENT when off, paused, undated, or already funded', () {
      expect(
        plannedReminders(
          goalData(on: false),
          now,
        ).where((r) => r.title == 'Goal check-in'),
        isEmpty,
        reason: 'toggle off',
      );
      expect(
        plannedReminders(
          goalData(paused: true),
          now,
        ).where((r) => r.title == 'Goal check-in'),
        isEmpty,
        reason: 'paused goals owe nothing',
      );
      expect(
        plannedReminders(
          goalData(targetDate: ''),
          now,
        ).where((r) => r.title == 'Goal check-in'),
        isEmpty,
        reason: 'no deadline, no nag',
      );
      expect(
        plannedReminders(
          goalData(saved: 12000),
          now,
        ).where((r) => r.title == 'Goal check-in'),
        isEmpty,
        reason: 'a funded goal is finished, not nagged',
      );
    });

    test('two goals at most, whatever the collection holds', () {
      final data = withNotifs(
        {'goals': true},
        extra: {
          'goals': [
            for (var i = 0; i < 5; i++)
              {
                'id': 'g$i',
                'name': 'Goal $i',
                'target': 1000,
                'saved': 0,
                'targetDate': '2026-12-01',
              },
          ],
        },
      );
      expect(
        plannedReminders(
          data,
          now,
        ).where((r) => r.title == 'Goal check-in').length,
        4,
        reason: 'two goals, two months each',
      );
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
