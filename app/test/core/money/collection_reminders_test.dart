import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/money.dart';
import 'package:salapify/core/money/reminders.dart';
import 'package:salapify/data/json_codec.dart';
import 'package:salapify/models/models.dart';

/// Reminders to ask for money owed to you (D38.1): the due day, then weekly
/// for eight weeks; no due date, the last day of the month; never before a
/// date, never for money you owe, never for a debt that is paid.
void main() {
  Debt lent({
    String id = 'debt_ana',
    String? due = '2026-10-05',
    DebtDirection direction = DebtDirection.owedToMe,
    bool settled = false,
    String? openingTxId,
    List<DebtPayment> payments = const <DebtPayment>[],
  }) => Debt(
    id: id,
    person: 'Ana Reyes',
    direction: direction,
    totalAmount: const Money.pesos(3000),
    paidAmount: const Money.pesos(500),
    isSettled: settled,
    dueDate: due,
    openingTxId: openingTxId,
    payments: payments,
  );

  Reminder? at(Debt d, DateTime now, [List<Transaction> txs = const []]) =>
      collectionReminder(d, now, txs);

  group('with a due date', () {
    test('nothing before the date: there is nothing to ask yet', () {
      expect(at(lent(), DateTime(2026, 10, 4, 9)), isNull);
    });

    test('the due day names the person, the amount left, and the offer', () {
      final Reminder r = at(lent(), DateTime(2026, 10, 5, 9))!;
      expect(r.kind, ReminderKind.collection);
      expect(r.title, 'Owed to you: Ana Reyes');
      expect(
        r.body,
        'Ana Reyes owes you ₱2,500.00, due today. A friendly message is '
        'ready when you are.',
      );
      expect(r.tag, 'collect-debt_ana-2026-10-05-w0');
    });

    test('one per WEEK: any day of a week shares its tag, the next week '
        'gets a new one', () {
      expect(
        at(lent(), DateTime(2026, 10, 8))!.tag,
        'collect-debt_ana-2026-10-05-w0',
        reason: 'opened 3 days late, still the first week',
      );
      expect(
        at(lent(), DateTime(2026, 10, 8))!.body,
        contains('due 3 days ago'),
      );
      expect(
        at(lent(), DateTime(2026, 10, 12))!.tag,
        'collect-debt_ana-2026-10-05-w1',
      );
    });

    test('stops after eight weeks late', () {
      // 56 days late is week 8, the last one.
      expect(at(lent(), DateTime(2026, 11, 30)), isNotNull);
      // 63 days late is week 9.
      expect(at(lent(), DateTime(2026, 12, 7)), isNull);
    });

    test('never for money YOU owe, a settled debt, or nothing left', () {
      final DateTime day = DateTime(2026, 10, 5);
      expect(at(lent(direction: DebtDirection.iOwe), day), isNull);
      expect(at(lent(settled: true), day), isNull);
    });
  });

  group('without a due date', () {
    test('the last day of the month, and the first three days after', () {
      final Debt d = lent(due: null);
      expect(at(d, DateTime(2026, 10, 30)), isNull);
      final Reminder r = at(d, DateTime(2026, 10, 31, 9))!;
      expect(r.tag, 'collect-debt_ana-nodate-2026-10');
      expect(
        r.body,
        'Ana Reyes still owes you ₱2,500.00. Around payday is an easy time '
        'to ask. A friendly message is ready when you are.',
      );
      expect(at(d, DateTime(2026, 11, 3))!.tag, r.tag);
      expect(at(d, DateTime(2026, 11, 4)), isNull);
    });

    test('quiet while the loan is under a week old', () {
      final Debt d = lent(due: null, openingTxId: 'tx_lend');
      List<Transaction> lentOn(String date) => <Transaction>[
        Transaction(
          id: 'tx_lend',
          type: TransactionType.transfer,
          amount: const Money.pesos(3000),
          category: 'Lending',
          accountId: 'acc_cash',
          date: date,
          createdAt: 1,
        ),
      ];
      expect(at(d, DateTime(2026, 10, 31), lentOn('2026-10-28')), isNull);
      // Lent on the 20th: eleven days old by the 31st.
      expect(at(d, DateTime(2026, 10, 31), lentOn('2026-10-20')), isNotNull);
    });

    test('quiet within a week of a payment towards it', () {
      final Debt d = lent(
        due: null,
        payments: <DebtPayment>[
          DebtPayment(
            id: 'p1',
            date: '2026-10-29',
            amount: const Money.pesos(500),
            paidBefore: const Money.pesos(0),
            settledBefore: false,
          ),
        ],
      );
      expect(at(d, DateTime(2026, 10, 31)), isNull);
    });
  });

  group('the engine and the planner', () {
    test('the switch silences it, and nothing else', () {
      final ReminderResult on = evaluateReminders(
        settings: ReminderSettings.defaults.copyWith(
          dailyExpenseEnabled: false,
        ),
        transactions: const <Transaction>[],
        debts: <Debt>[lent()],
        bills: const <BillItem>[],
        sentTags: const <String>{},
        now: DateTime(2026, 10, 5, 9),
      );
      expect(on.fresh.map((Reminder r) => r.kind), <ReminderKind>[
        ReminderKind.collection,
      ]);

      final ReminderResult off = evaluateReminders(
        settings: ReminderSettings.defaults.copyWith(
          dailyExpenseEnabled: false,
          collectionEnabled: false,
        ),
        transactions: const <Transaction>[],
        debts: <Debt>[lent()],
        bills: const <BillItem>[],
        sentTags: const <String>{},
        now: DateTime(2026, 10, 5, 9),
      );
      expect(off.fresh, isEmpty);
    });

    test('the phone hears it on the due day and every seventh day after, '
        'at 9 in the morning, and on no other day', () {
      final List<PlannedReminder> plan = planReminders(
        settings: ReminderSettings.defaults.copyWith(
          dailyExpenseEnabled: false,
        ),
        transactions: const <Transaction>[],
        debts: <Debt>[lent()],
        bills: const <BillItem>[],
        sentTags: const <String>{},
        from: DateTime(2026, 10, 4, 20),
        days: 22,
      );
      expect(plan.map((PlannedReminder p) => p.at), <DateTime>[
        DateTime(2026, 10, 5, 9),
        DateTime(2026, 10, 12, 9),
        DateTime(2026, 10, 19, 9),
      ]);
    });

    test('a tray message finds its debt by tag, and not a longer id that '
        'shares the prefix', () {
      final Debt one = lent(id: 'd1');
      final Debt twelve = lent(id: 'd12');
      expect(
        collectionDebtFor('collect-d12-2026-10-05-w0', <Debt>[one, twelve]),
        same(twelve),
      );
      expect(
        collectionDebtFor('collect-d1-2026-10-05-w0', <Debt>[
          one.copyWith(isSettled: true),
        ]),
        isNull,
        reason: 'a paid debt offers no message',
      );
    });
  });

  group('QA fixes', () {
    test('a due date Salapify cannot read asks at month end instead of '
        'never', () {
      final Debt d = lent(due: 'payday');
      expect(at(d, DateTime(2026, 10, 15)), isNull);
      expect(
        at(d, DateTime(2026, 10, 31))!.tag,
        'collect-debt_ana-nodate-2026-10',
      );
    });

    test('a repeating "15th" asks again next month, under a new tag', () {
      final Debt d = lent(due: '15th');
      final Reminder oct = at(d, DateTime(2026, 10, 15))!;
      final Reminder nov = at(d, DateTime(2026, 11, 15))!;
      expect(oct.tag, isNot(nov.tag));
      expect(nov.tag, 'collect-debt_ana-2026-11-15-w0');
    });

    test('a payment on the 1st quiets the month-end ask in the grace days', () {
      final Debt d = lent(
        due: null,
        payments: <DebtPayment>[
          DebtPayment(
            id: 'p1',
            date: '2026-11-01',
            amount: const Money.pesos(500),
            paidBefore: const Money.pesos(0),
            settledBefore: false,
          ),
        ],
      );
      expect(at(d, DateTime(2026, 11, 2)), isNull);
    });

    test('a debt typed in by hand this week is not asked about yet', () {
      final int lentAt = DateTime(2026, 10, 29, 10).millisecondsSinceEpoch;
      expect(
        at(lent(id: 'debt_$lentAt', due: null), DateTime(2026, 10, 31)),
        isNull,
      );
      final int earlier = DateTime(2026, 10, 1, 10).millisecondsSinceEpoch;
      expect(
        at(lent(id: 'debt_$earlier', due: null), DateTime(2026, 10, 31)),
        isNotNull,
      );
    });

    test('the evening nudge pass never schedules an ask a second time', () {
      final List<PlannedReminder> plan = planReminders(
        settings: ReminderSettings.defaults.copyWith(dailyExpenseEnabled: true),
        // Something logged every day, so the evening pass has no nudge of
        // its own to raise and anything it plans is a duplicate.
        transactions: <Transaction>[
          for (int i = 0; i < 3; i++)
            Transaction(
              id: 'tx_$i',
              type: TransactionType.expense,
              amount: const Money.pesos(1),
              category: 'Food & Dining',
              accountId: 'acc_cash',
              date: '2026-10-0${5 + i}',
              createdAt: 1,
            ),
        ],
        debts: <Debt>[lent()],
        bills: const <BillItem>[],
        // The 9am message was raised and then cleared: not in the tray.
        sentTags: const <String>{},
        from: DateTime(2026, 10, 5, 10),
        days: 1,
      );
      expect(
        plan.where(
          (PlannedReminder p) => p.reminder.kind == ReminderKind.collection,
        ),
        isEmpty,
        reason: 'scheduled again at the evening nudge hour',
      );
    });
  });

  group('saved', () {
    test('the switch survives a save, and a file without it reads as on', () {
      final Map<String, dynamic> off = reminderSettingsToJson(
        ReminderSettings.defaults.copyWith(collectionEnabled: false),
      );
      expect(reminderSettingsFromJson(off).collectionEnabled, isFalse);
      expect(
        reminderSettingsFromJson(<String, dynamic>{}).collectionEnabled,
        isTrue,
      );
    });

    test('a tray message of the new kind round-trips', () {
      const AppNotification n = AppNotification(
        id: 'collect-debt_ana-2026-10-05-w0',
        kind: ReminderKind.collection,
        title: 't',
        body: 'b',
        createdAt: 1,
      );
      expect(notificationToJson(n)['type'], 'collection');
      expect(
        notificationFromJson(notificationToJson(n)).kind,
        ReminderKind.collection,
      );
    });
  });
}
