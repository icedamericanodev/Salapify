import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/daily_projection.dart';
import 'package:salapify/core/money/money.dart';
import 'package:salapify/core/money/reminders.dart';
import 'package:salapify/data/json_codec.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/models/models.dart';
import 'package:salapify/state/financial_state.dart';

/// Repeating bills (D31, 2026-10-10): paying a monthly bill moves the SAME
/// row to next month instead of ticking it off for good, and Undo puts the
/// money and the date back together.
void main() {
  group('the next due date', () {
    test('same day next month, clamped to a short month, and back again', () {
      expect(nextMonthlyDue('2026-09-25', 25), '2026-10-25');
      expect(nextMonthlyDue('2026-12-10', 10), '2027-01-10');
      // The 31st: September has 30, so the 30th; October has 31 again.
      expect(nextMonthlyDue('2026-08-31', 31), '2026-09-30');
      expect(nextMonthlyDue('2026-09-30', 31), '2026-10-31');
      expect(previousMonthlyDue('2026-10-31', 31), '2026-09-30');
      expect(previousMonthlyDue('2027-01-10', 10), '2026-12-10');
      expect(nextMonthlyDue('Sep 25', 25), isNull, reason: 'not ISO');
    });
  });

  test('a monthly bill survives a save and reload; an old row loads as a '
      'one-off', () {
    const UpcomingItem pldt = UpcomingItem(
      id: 'u',
      name: 'PLDT',
      amount: Money.pesos(1699),
      dueDate: '2026-09-25',
      type: UpcomingItemType.bill,
      repeatDay: 25,
      lastPaidTxId: 'tx_bill_1',
    );
    final UpcomingItem back = upcomingFromJson(upcomingToJson(pldt));
    expect(back.repeatDay, 25);
    expect(back.lastPaidTxId, 'tx_bill_1');
    final Map<String, dynamic> old = upcomingToJson(
      const UpcomingItem(
        id: 'o',
        name: 'Old',
        amount: Money.pesos(1),
        dueDate: 'Sep 25',
        type: UpcomingItemType.bill,
      ),
    );
    expect(old.containsKey('repeatDay'), isFalse);
    expect(upcomingFromJson(old).repeatDay, isNull);
    expect(upcomingKeys, containsAll(<String>['repeatDay', 'lastPaidTxId']));
    expect(
      upcomingFromJson(<String, dynamic>{
        ...upcomingToJson(pldt),
        'repeatDay': 45,
      }).repeatDay,
      isNull,
      reason: 'a day that does not exist',
    );
  });

  group('paying and undoing', () {
    Future<FinancialState> fresh() async {
      final FinancialState s = FinancialState(
        clock: DateTime(2026, 9, 18, 12),
        store: MemorySnapshotStore(),
      );
      await s.restore();
      s.startWithExampleData();
      s.addUpcoming(
        const UpcomingItem(
          id: 'up_pldt',
          name: 'PLDT Fibr',
          amount: Money.pesos(1699),
          dueDate: '2026-09-25',
          type: UpcomingItemType.bill,
          repeatDay: 25,
        ),
      );
      return s;
    }

    Money cash(FinancialState s) =>
        s.accounts.firstWhere((Account a) => a.id == 'acc_cash').balance;
    UpcomingItem pldt(FinancialState s) =>
        s.upcoming.firstWhere((UpcomingItem u) => u.id == 'up_pldt');

    test(
      'paying moves the money and the date, and never ticks it off',
      () async {
        final FinancialState s = await fresh();
        final Money start = cash(s);
        final Transaction? tx = s.markUpcomingPaid(
          'up_pldt',
          accountId: 'acc_cash',
        );

        expect(tx, isNotNull);
        expect(cash(s), start - const Money.pesos(1699));
        expect(pldt(s).isPaid, isFalse, reason: 'ticked off for good');
        expect(pldt(s).dueDate, '2026-10-25');
        expect(pldt(s).lastPaidTxId, tx!.id);
      },
    );

    test('Undo puts the money AND the date back, and a second Undo moves '
        'neither', () async {
      final FinancialState s = await fresh();
      final Money start = cash(s);
      final Transaction tx = s.markUpcomingPaid(
        'up_pldt',
        accountId: 'acc_cash',
      )!;
      s.undoUpcomingPaid('up_pldt', tx);
      expect(cash(s), start);
      expect(pldt(s).dueDate, '2026-09-25');
      expect(pldt(s).lastPaidTxId, isNull);

      s.undoUpcomingPaid('up_pldt', tx);
      expect(
        pldt(s).dueDate,
        '2026-09-25',
        reason: 'walked back a month twice',
      );
      expect(cash(s), start);
    });

    test('the last payment is undone on Bills; an older one can be taken '
        'back on its own, never a dead end', () async {
      final FinancialState s = await fresh();
      final Transaction first = s.markUpcomingPaid(
        'up_pldt',
        accountId: 'acc_cash',
      )!;
      final Transaction second = s.markUpcomingPaid(
        'up_pldt',
        accountId: 'acc_cash',
      )!;
      expect(pldt(s).dueDate, '2026-11-25');
      expect(s.takeBackPreview(second.id), TakeBackOutcome.belongsToBill);
      expect(s.takeBackPreview(first.id), TakeBackOutcome.done);
    });

    test(
      'the runway notices a monthly bill moving, with no money moved',
      () async {
        // Paid with no account: no entry, no balance change, the unpaid count
        // and sum unchanged. Only the DATE moves, and the runway's cache used
        // to miss exactly that until midnight.
        final FinancialState s = await fresh();
        bool onSep25(FinancialState st) => st.dailyProjection.days.any(
          (ProjectedDay d) =>
              d.date.month == 9 &&
              d.date.day == 25 &&
              d.events.any((ProjectedEvent e) => e.label == 'PLDT Fibr'),
        );
        expect(onSep25(s), isTrue);
        s.markUpcomingPaid('up_pldt');
        expect(onSep25(s), isFalse, reason: 'the chart still shows Sep 25');
      },
    );

    test('a one-off bill is still ticked off, exactly as before', () async {
      final FinancialState s = await fresh();
      final UpcomingItem meralco = s.upcoming.firstWhere(
        (UpcomingItem u) => u.name.contains('Meralco'),
      );
      expect(meralco.repeats, isFalse);
      s.markUpcomingPaid(meralco.id, accountId: 'acc_cash');
      expect(
        s.upcoming.firstWhere((UpcomingItem u) => u.id == meralco.id).isPaid,
        isTrue,
      );
    });
  });

  test(
    'the runway places a monthly bill every time it falls in the window',
    () {
      final DateTime now = DateTime(2026, 9, 18);
      final DailyProjection p = projectDailyCash(
        accounts: const <Account>[],
        bills: const <BillItem>[],
        upcoming: const <UpcomingItem>[
          UpcomingItem(
            id: 'u',
            name: 'PLDT',
            amount: Money.pesos(1699),
            dueDate: '2026-09-25',
            type: UpcomingItemType.bill,
            repeatDay: 25,
          ),
        ],
        installments: const <InstallmentPlan>[],
        debts: const <Debt>[],
        payday: PaydayCycle.unset,
        now: now,
      );
      Money out = Money.zero;
      for (final ProjectedDay d in p.days) {
        out += d.moneyOut;
      }
      // Sep 25 and Oct 25, both inside 45 days. It used to be placed once.
      expect(out, const Money.pesos(3398));
    },
  );
}
