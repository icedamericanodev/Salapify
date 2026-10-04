import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/accounts.dart';
import 'package:salapify/core/money/daily_projection.dart';
import 'package:salapify/core/money/money.dart';
import 'package:salapify/core/money/ph_calendar.dart';
import 'package:salapify/data/seed_data.dart';
import 'package:salapify/models/models.dart';

import '../../support/test_clock.dart';

/// Sweldo Runway, increment 1: the engine.
///
/// It answers a question no other engine in Salapify answers. Everything else
/// produces an AMOUNT; this produces a DATE, which is the first figure in the
/// app somebody can act on today rather than only obey.
void main() {
  const Account wallet = Account(
    id: 'a_wallet',
    name: 'GCash',
    kind: AccountKind.gcash,
    institution: 'GCash',
    balance: Money.pesos(10000),
    monogram: 'GC',
  );

  const Account ipon = Account(
    id: 'a_ipon',
    name: 'GSave',
    kind: AccountKind.gcash,
    institution: 'GCash',
    balance: Money.pesos(50000),
    monogram: 'GS',
    purpose: AccountPurpose.protected,
  );

  // A Wednesday, so weekend arithmetic below is easy to follow.
  final DateTime wed = DateTime(2026, 10, 7);

  DailyProjection run({
    List<Account> accounts = const <Account>[wallet],
    List<BillItem> bills = const <BillItem>[],
    List<UpcomingItem> upcoming = const <UpcomingItem>[],
    List<InstallmentPlan> installments = const <InstallmentPlan>[],
    List<Debt> debts = const <Debt>[],
    PaydayCycle payday = PaydayCycle.unset,
    DateTime? now,
    int horizonDays = 45,
  }) => projectDailyCash(
    accounts: accounts,
    bills: bills,
    upcoming: upcoming,
    installments: installments,
    debts: debts,
    payday: payday,
    now: now ?? wed,
    horizonDays: horizonDays,
  );

  BillItem bill(String name, int amount, String due) =>
      BillItem(id: name, name: name, amount: Money.pesos(amount), dueDate: due);

  group('where it starts from', () {
    test('spendable cash, not every peso', () {
      // The whole of P2.3 in one assertion. Money set aside cannot cover
      // Friday bill, and starting from the total would make this engine
      // disagree with Safe to Spend about the same money on the same screen.
      expect(
        run(accounts: <Account>[wallet, ipon]).openingBalance,
        const Money.pesos(10000),
      );
    });

    test('a foreign balance is converted, never added raw', () {
      const Account usd = Account(
        id: 'a_usd',
        name: 'Payroll USD',
        kind: AccountKind.bank,
        institution: 'BPI',
        balance: Money.pesos(1000),
        currency: CurrencyCode.usd,
        monogram: 'US',
      );
      final Money opening = run(
        accounts: <Account>[wallet, usd],
      ).openingBalance;
      expect(
        opening,
        Money.fromDouble(accountsTotalPhp(<Account>[wallet, usd])),
      );
      expect(
        opening,
        greaterThan(const Money.pesos(11000)),
        reason: 'a thousand dollars was added as a thousand pesos',
      );
    });
  });

  group('the arithmetic has to foot', () {
    /// Sum every outflow the ledger contains, so the engine can be held to it.
    Money sourceOutflow({
      List<BillItem> bills = const <BillItem>[],
      List<UpcomingItem> upcoming = const <UpcomingItem>[],
      List<InstallmentPlan> installments = const <InstallmentPlan>[],
      List<Debt> debts = const <Debt>[],
    }) {
      Money total = Money.zero;
      for (final BillItem b in bills.where((BillItem b) => !b.isPaid)) {
        total += b.amount;
      }
      for (final UpcomingItem u in upcoming.where(
        (UpcomingItem u) => !u.isPaid && !u.countsAsIncome,
      )) {
        total += u.amount;
      }
      for (final InstallmentPlan i in installments.where(
        (InstallmentPlan i) => !i.isSettled,
      )) {
        total += minMoney(i.installmentAmount, i.runningBalance);
      }
      for (final Debt d in debts.where(
        (Debt d) => !d.isSettled && d.direction == DebtDirection.iOwe,
      )) {
        final Money? m = d.monthlyMinimum;
        if (m != null) total += m;
      }
      return total;
    }

    test('EVERY eligible peso has a home: a day, or a named bucket', () {
      // THE REAL FOOTING CHECK, and the reason the old one was replaced.
      //
      // The obvious assertion, opening plus every inflow less every outflow
      // equals closing, is an IDENTITY: both sides come out of the same
      // accumulator loop, so it passes with every input list deleted. It
      // restated the loop instead of testing it. Found by the controller
      // review, and it was right.
      //
      // This one compares the engine against the LEDGER, which is a different
      // number and can genuinely disagree. It did: 8,840 of overdue bills on
      // the sample ledger were excluded and counted nowhere.
      final List<BillItem> bills = <BillItem>[
        bill('Overdue', 3000, '2026-09-01'),
        bill('Soon', 2000, '2026-10-09'),
        bill('Unreadable', 1500, 'when I can'),
        bill('Far off', 4000, '2027-06-01'),
      ];

      final DailyProjection p = run(bills: bills);

      expect(
        p.accountedOutflow,
        sourceOutflow(bills: bills),
        reason:
            'a peso the person entered is missing from the day grid AND from '
            'every bucket, so a clean projection is hiding an obligation',
      );

      // DIRECTIONAL, per bucket, because the identity above is satisfied by
      // four empty buckets and an empty day grid.
      expect(p.overdueOutflow, const Money.pesos(3000));
      expect(p.overdueOutflowCount, 1);
      expect(p.undatedOutflow, const Money.pesos(1500));
      expect(p.undatedOutflowCount, 1);
      expect(p.beyondHorizonOutflow, const Money.pesos(4000));
      expect(p.beyondHorizonOutflowCount, 1);
      expect(p.closingBalance, const Money.pesos(8000));
    });

    test('the footing is over OCCURRENCES, not over records', () {
      // THE OLD FOOTING TEST WAS A STATEMENT ABOUT ITS FIXTURE. Its helper
      // added each obligation exactly ONCE, which matched the engine only
      // because every date in the fixture was a one-off ISO date. The
      // recurrence change of 2026-10-04 made the engine place a day-of-month
      // bill once per occurrence, so the two definitions quietly disagreed
      // by a whole month's outgoings, and the test passed with the entire
      // recurrence walk deleted.
      //
      // Stated in occurrences it is falsifiable: a 3,000 bill on the 20th in
      // a 45 day window opened on 7 October falls on 20 October and 20
      // November, so six thousand is accounted for and not three.
      final DailyProjection p = run(
        bills: <BillItem>[bill('Meralco', 3000, '20')],
      );

      expect(
        <String>[
          for (final ProjectedDay d in p.days)
            if (d.events.isNotEmpty) d.date.toIso8601String().substring(0, 10),
        ],
        <String>['2026-10-20', '2026-11-20'],
        reason: 'the engine must place the occurrences, not the record',
      );
      expect(p.accountedOutflow, const Money.pesos(6000));
    });

    test('an overdue SALARY is never counted as money leaving', () {
      // The single worst figure this engine produced, and it was about to go
      // on the card as the one line that must stay on screen so a person does
      // not read a comfortable balance and draw a wrong conclusion.
      //
      // `placeOn` asked "is this in the past" before it ever asked "is this
      // income", so an overdue sweldo landed in a bucket named "unpaid,
      // dated, already in the past" and accountedOutflow added it as money
      // going out. On the shipped seed at 18 September 2026 the figure read
      // 42,987.80 across four items, of which 32,500 was the Sweldo Payday
      // item. The real overdue outflow is 10,487.80.
      final DailyProjection p = run(
        bills: <BillItem>[bill('Meralco', 3000, '2026-09-30')],
        upcoming: <UpcomingItem>[
          UpcomingItem(
            id: 'u_sweldo',
            name: 'Sweldo',
            amount: const Money.pesos(32500),
            dueDate: '2026-09-30',
            type: UpcomingItemType.payday,
          ),
        ],
      );

      expect(
        p.overdueOutflow,
        const Money.pesos(3000),
        reason: 'only the bill is money leaving',
      );
      expect(p.overdueOutflowCount, 1);

      // DIRECTIONAL: the salary is not dropped either, it is filed on the
      // other side. Without this the test passes on an engine that throws
      // overdue income away, which is the opposite defect.
      expect(p.overdueInflow, const Money.pesos(32500));
      expect(p.overdueInflowCount, 1);
      expect(
        p.accountedOutflow,
        const Money.pesos(3000),
        reason: 'the footing sum must not carry a salary in it',
      );
    });

    test('and the same split holds past the end of the window', () {
      final DailyProjection p = run(
        upcoming: <UpcomingItem>[
          UpcomingItem(
            id: 'u_bonus',
            name: '13th month',
            amount: const Money.pesos(50000),
            dueDate: '2026-12-20',
            type: UpcomingItemType.payday,
          ),
        ],
      );
      expect(p.beyondHorizonOutflow, Money.zero);
      expect(p.beyondHorizonInflow, const Money.pesos(50000));
      expect(p.accountedOutflow, Money.zero);
    });

    test('a bill due on the LAST day of the window stays in it', () {
      // 21 Nov 2026 is 45 days out and is a Saturday, so the banking shift
      // moves it to the Monday, offset 47. It used to fall off the end and be
      // counted nowhere at all: closing unchanged, undated zero, count zero.
      final DailyProjection p = run(
        bills: <BillItem>[bill('Tuition', 5000, '2026-11-21')],
      );
      expect(
        p.closingBalance,
        const Money.pesos(5000),
        reason:
            'the person entered it inside the window they asked about, and a '
            'bank holiday is not a reason for it to disappear',
      );
      expect(p.beyondHorizonOutflowCount, 0);
    });

    test('the OLD assertion, kept, and labelled as the identity it is', () {
      // Retained because it still guards the accumulator against an
      // arithmetic slip inside the loop. It is NOT evidence that the engine
      // read the ledger, which is what it was mistaken for.
      final DailyProjection p = run(
        bills: <BillItem>[
          bill('Meralco', 2000, '2026-10-09'),
          bill('Rent', 7000, '2026-10-15'),
        ],
        upcoming: <UpcomingItem>[
          const UpcomingItem(
            id: 'u1',
            name: 'Freelance',
            amount: Money.pesos(5000),
            dueDate: '2026-10-12',
            type: UpcomingItemType.bill,
            isIncome: true,
          ),
        ],
      );

      Money ins = Money.zero;
      Money outs = Money.zero;
      for (final ProjectedDay d in p.days) {
        ins += d.moneyIn;
        outs += d.moneyOut;
      }
      expect(p.openingBalance + ins - outs, p.closingBalance);
    });

    test('a quiet ledger never moves', () {
      final DailyProjection p = run();
      expect(p.closingBalance, p.openingBalance);
      expect(p.days.every((ProjectedDay d) => d.isQuiet), isTrue);
      expect(p.runsShort, isFalse);
    });
  });

  group('the date it lands on', () {
    test('a bill due on a Sunday leaves on the Monday', () {
      // 11 Oct 2026 is a Sunday. Banks do not move money on it.
      final DailyProjection p = run(
        bills: <BillItem>[bill('Water', 1000, '2026-10-11')],
      );

      final ProjectedDay sunday = p.days[4];
      expect(sunday.date, DateTime(2026, 10, 11));
      expect(sunday.moneyOut, Money.zero);

      final ProjectedDay monday = p.days[5];
      expect(monday.moneyOut, const Money.pesos(1000));
      expect(monday.events.single.moved, isTrue);
      expect(
        monday.events.single.movedReason,
        'a Sunday',
        reason: 'the screen has to be able to say WHY the date moved',
      );
      expect(monday.events.single.movedFrom, DateTime(2026, 10, 11));
    });

    test('INCOME is not shifted, because a credit is not a payment', () {
      final DailyProjection p = run(
        upcoming: <UpcomingItem>[
          const UpcomingItem(
            id: 'u1',
            name: 'Side gig',
            amount: Money.pesos(3000),
            dueDate: '2026-10-11',
            type: UpcomingItemType.bill,
            isIncome: true,
          ),
        ],
      );
      expect(p.days[4].moneyIn, const Money.pesos(3000));
      expect(p.days[4].events.single.moved, isFalse);
    });

    test('a bill due in the past is not placed on today', () {
      // Unpaid and overdue is a problem, but it is not a FUTURE movement, and
      // putting it on today claims money leaves today that may be long gone.
      final DailyProjection p = run(
        bills: <BillItem>[bill('Old', 500, '2026-09-01')],
      );
      expect(p.days.first.moneyOut, Money.zero);
      expect(
        p.undatedOutflowCount,
        0,
        reason: 'overdue is dated, just behind us',
      );
    });
  });

  group('a window of a month and a half holds a monthly bill TWICE', () {
    // The engine placed every bill, every debt minimum and every instalment
    // exactly ONCE while the payday walk looped, so over forty-five days it
    // counted outgoings for one month and income for one and a half. That is
    // optimistic BY CONSTRUCTION, and optimistic is the one direction a
    // runway must never be wrong in: it tells somebody they are fine on the
    // day they are not.

    test('a bill on the 15th falls twice in forty-five days', () {
      final DailyProjection p = run(
        bills: <BillItem>[bill('Meralco', 3000, '15')],
      );
      final List<int> on = <int>[
        for (final ProjectedDay d in p.days)
          if (d.events.isNotEmpty) d.date.day,
      ];
      expect(on, <int>[15, 16]);
      expect(
        p.closingBalance,
        const Money.pesos(4000),
        reason: '10,000 less two months of a 3,000 bill',
      );
    });

    test('a bill written as ONE DATE still falls once', () {
      // The recurrence is read, never assumed. "2026-10-15" names one day
      // and is then over, and inventing a second one would be the same sin
      // in the other direction.
      final DailyProjection p = run(
        bills: <BillItem>[bill('Tuition', 3000, '2026-10-15')],
      );
      expect(p.closingBalance, const Money.pesos(7000));
    });

    test('a monthly minimum is monthly whatever shape its date is in', () {
      // The seed phone plan carries an ISO due date, so the day-of-month
      // rule above cannot reach it, and the field is literally called
      // monthlyMinimum. The date says WHEN in the month; the name says how
      // often.
      final DailyProjection p = run(
        debts: <Debt>[
          Debt(
            id: 'd1',
            person: 'Home Credit',
            direction: DebtDirection.iOwe,
            totalAmount: const Money.pesos(14700),
            paidAmount: const Money.pesos(7350),
            isSettled: false,
            schedule: DebtSchedule.scheduled,
            installmentCurrent: 3,
            installmentTotal: 6,
            dueDate: '2026-10-15',
          ),
        ],
      );
      expect(p.closingBalance, const Money.pesos(5100));
    });

    test('and the LAST month takes only what is left', () {
      // A card with 3,000 on it and a 2,000 minimum pays 2,000 this month
      // and 1,000 next, not 2,000 twice. Running past the balance would
      // invent an obligation, which is the eight percent rule P2.4 removed,
      // made with a calendar instead of a percentage.
      //
      // The earlier version of this test used a plan with ONE instalment
      // left, which passed with the cap deleted: the running total hit zero
      // after a single pass either way, so the cap was never reached. A
      // remainder smaller than the minimum is the only shape that reaches
      // it.
      final DailyProjection p = run(
        debts: <Debt>[
          Debt(
            id: 'd1',
            person: 'Nearly done',
            direction: DebtDirection.iOwe,
            totalAmount: const Money.pesos(60000),
            paidAmount: const Money.pesos(57000),
            isSettled: false,
            minimumPayment: const Money.pesos(2000),
            dueDate: '2026-10-15',
          ),
        ],
      );
      expect(
        p.closingBalance,
        const Money.pesos(7000),
        reason: '10,000 less the whole 3,000 that is left, never 4,000',
      );
    });
  });

  group('a payment plan has a date, and this engine now reads it', () {
    // The comment here used to say instalments "have no due date of their
    // own in this model". That was never true: nextInstallmentDate derives
    // one from the start date, the instalments paid and the frequency, and
    // the reminder engine has used it all along. So Salapify told somebody
    // in the notification tray when the Home Credit payment was due, and the
    // cash projection over the same ledger called it undatable.

    InstallmentPlan plan({
      String start = '2026-07-10',
      int paid = 3,
      Money balance = const Money.pesos(18000),
    }) => InstallmentPlan(
      id: 'p1',
      name: 'Phone',
      provider: 'Home Credit',
      principal: const Money.pesos(24000),
      interestRate: 0,
      interestRateType: InterestRateType.fixed,
      totalInterest: Money.zero,
      totalPayable: const Money.pesos(24000),
      termMonths: 12,
      installmentAmount: const Money.pesos(2000),
      paidInstallments: paid,
      totalInstallments: 12,
      runningBalance: balance,
      principalRemaining: balance,
      interestRemaining: Money.zero,
      startDate: start,
      maturityDate: '2027-07-10',
    );

    test('every instalment inside the window is placed, by date', () {
      final DailyProjection p = run(installments: <InstallmentPlan>[plan()]);
      expect(
        p.undatedOutflowCount,
        0,
        reason: 'the app knows exactly when these are',
      );
      expect(
        <String>[
          for (final ProjectedDay d in p.days)
            if (d.events.isNotEmpty) d.date.toIso8601String().substring(0, 10),
        ],
        <String>['2026-10-12', '2026-11-10'],
        reason:
            'the 10th of October is a Saturday, so the money leaves on the '
            'Monday; the 10th of November is an ordinary weekday',
      );
      expect(p.closingBalance, const Money.pesos(6000));
    });

    test('a plan whose start date cannot be read is still COUNTED', () {
      final DailyProjection p = run(
        installments: <InstallmentPlan>[
          plan(start: 'sometime', paid: 0, balance: const Money.pesos(6000)),
        ],
      );
      expect(p.undatedOutflow, const Money.pesos(2000));
      expect(p.undatedOutflowCount, 1);
      expect(p.closingBalance, const Money.pesos(10000));
    });
  });

  group('one sweldo is counted once', () {
    // Founder decision D27, 2026-10-04. The asymmetry is the rule: counting a
    // BILL twice makes somebody cautious, counting a SALARY twice hands them
    // money that is not coming.

    UpcomingItem sweldo(
      String due, {
      int amount = 32500,
      String name = 'Sweldo',
    }) => UpcomingItem(
      id: 'u_$name$due',
      name: name,
      amount: Money.pesos(amount),
      dueDate: due,
      type: UpcomingItemType.payday,
    );

    // `nextPayday` and `daysToPayday` MUST be filled, and the reason is a
    // trap worth writing down: `PaydayCycle.isSet` reads those two snapshot
    // fields, not `hasRule`, so a cycle carrying a perfectly good rule and
    // empty labels reads as "nobody has said when they are paid" and the
    // engine places no income at all. In the app that cannot happen, because
    // `FinancialState.payday` fills both from the rule on every read. In a
    // direct engine call it silently produces a projection with no sweldo in
    // it, which is exactly what this fixture did on its first run.
    const PaydayCycle rule = PaydayCycle(
      cycleType: '15_30',
      lastPayday: 'Sep 30',
      nextPayday: 'Oct 15',
      daysToPayday: 8,
      expectedIncome: Money.pesos(32500),
      paydayDays: <int>[15, 30],
    );

    test('a salary in two registers lands on the grid once', () {
      // Measured before the fix: 65,000 on one day, and a closing balance
      // half as big again as the real one.
      final DailyProjection p = run(
        upcoming: <UpcomingItem>[sweldo('2026-10-15')],
        payday: rule,
      );

      expect(
        p.accountedInflow,
        const Money.pesos(97500),
        reason: 'three paydays in the window, never four',
      );
      expect(p.suppressedIncome, const Money.pesos(32500));
      expect(p.duplicateIncomeLabels, <String>['Sweldo']);
    });

    test('it is caught across the MONTH, not only on the same day', () {
      // The seed's own duplicate pair sits three days apart in two
      // registers, so a same-day rule would report nothing at all.
      final DailyProjection p = run(
        upcoming: <UpcomingItem>[sweldo('2026-10-12')],
        payday: rule,
      );
      expect(p.suppressedIncome, const Money.pesos(32500));
      expect(p.accountedInflow, const Money.pesos(97500));
    });

    test('a DIFFERENT income of a different size is never touched', () {
      // The guard that keeps this from eating real money. Somebody with a
      // retainer as well as a salary must keep both.
      final DailyProjection p = run(
        upcoming: <UpcomingItem>[
          sweldo('2026-10-15', amount: 18500, name: 'Retainer'),
        ],
        payday: rule,
      );
      expect(p.suppressedIncome, Money.zero);
      expect(p.duplicateIncomeLabels, isEmpty);
      expect(
        p.accountedInflow,
        const Money.pesos(116000),
        reason: '97,500 of salary plus the 18,500 retainer, all of it kept',
      );
    });

    test('an OUTFLOW in two registers is still counted twice', () {
      // The other half of the asymmetry, and the reason this is one decision
      // rather than two conventions. A bill described twice stays described
      // twice, because being told you are tighter than you are costs nothing.
      final DailyProjection p = run(
        bills: <BillItem>[bill('Meralco', 3000, '2026-10-15')],
        upcoming: <UpcomingItem>[
          UpcomingItem(
            id: 'u_meralco',
            name: 'Meralco',
            amount: const Money.pesos(3000),
            dueDate: '2026-10-15',
            type: UpcomingItemType.bill,
          ),
        ],
      );
      expect(p.accountedOutflow, const Money.pesos(6000));
      expect(p.suppressedIncome, Money.zero);
    });
  });

  group('what it refuses to guess', () {
    test('an unreadable due date is COUNTED, never dropped', () {
      final DailyProjection p = run(
        bills: <BillItem>[
          bill('Sunday-ish', 1500, 'whenever I get paid'),
          bill('Meralco', 2000, '2026-10-09'),
        ],
      );
      expect(p.undatedOutflow, const Money.pesos(1500));
      expect(p.undatedOutflowCount, 1);
      expect(
        p.closingBalance,
        p.openingBalance - const Money.pesos(2000),
        reason: 'an undated bill must not silently move the balance either',
      );
    });

    test('no payday rule means NO invented income', () {
      // The one mistake that would make this feature dangerous.
      // 12,000 against a 10,000 wallet, so it genuinely runs short. An
      // earlier draft used 9,000, which leaves 1,000 and never crosses zero,
      // so the assertion below passed for the wrong reason.
      final DailyProjection p = run(
        bills: <BillItem>[bill('Rent', 12000, '2026-10-15')],
      );
      expect(p.days.every((ProjectedDay d) => d.moneyIn.isZero), isTrue);
      expect(
        p.runsShort,
        isTrue,
        reason:
            'with no payday rule stored there is nothing to rescue this '
            'person, and an engine that invented one would say otherwise',
      );
    });

    test('paydays come from the STORED rule, not a 15 day assumption', () {
      // Paid on the 20th only. A fortnightly guess would put money in on the
      // 5th of November as well, and this person is not paid then.
      final DailyProjection p = run(
        payday: const PaydayCycle(
          cycleType: 'monthly',
          lastPayday: '2026-09-20',
          nextPayday: '2026-10-20',
          daysToPayday: 13,
          expectedIncome: Money.pesos(30000),
          paydayDays: <int>[20],
        ),
      );
      final List<int> paydayOffsets = <int>[
        for (int i = 0; i < p.days.length; i++)
          if (p.days[i].moneyIn.isPositive) i,
      ];
      // 20 Oct is 13 days out, 20 Nov is 44.
      expect(paydayOffsets, <int>[13, 44]);
    });

    test('a DENSE payday rule does not lose the last one to a loop guard', () {
      // Six paydays a month, which a commission earner or a small-shop
      // worker genuinely has. The walk used to stop after eight iterations
      // and silently drop the ninth, at offset 44, which is 5,000 of real
      // income the projection never added. The two-day rule above cannot
      // reach the guard, so nothing caught it.
      final DailyProjection p = run(
        payday: const PaydayCycle(
          cycleType: 'weekly',
          lastPayday: '2026-10-05',
          nextPayday: '2026-10-10',
          daysToPayday: 3,
          expectedIncome: Money.pesos(5000),
          paydayDays: <int>[5, 10, 15, 20, 25, 30],
        ),
      );
      final List<int> offsets = <int>[
        for (int i = 0; i < p.days.length; i++)
          if (p.days[i].moneyIn.isPositive) i,
      ];
      expect(offsets, <int>[3, 8, 13, 18, 23, 29, 34, 39, 44]);
    });
  });

  test('a debt owed TO you never reduces YOUR runway', () {
    // Found by the money review, and it was a real bug in the first version
    // of this engine: the debt loop iterated every Debt and placed every
    // minimum as an outflow, while `monthlyDebtMinimums` has filtered to the
    // `iOwe` direction all along. Two readings of one ledger, disagreeing.
    //
    // The seed hid it completely, because both of its receivables are
    // `flexible`, so `monthlyMinimum` returns null and nothing is placed. It
    // would have appeared the first time a real person recorded "Kuya Mark
    // owes me 12,000, six instalments", at which point THEIR shortfall date
    // moves for somebody else's debt.
    const Debt owedToMe = Debt(
      id: 'd_kuya',
      person: 'Kuya Mark',
      direction: DebtDirection.owedToMe,
      totalAmount: Money.pesos(12000),
      paidAmount: Money.zero,
      isSettled: false,
      schedule: DebtSchedule.scheduled,
      installmentCurrent: 0,
      installmentTotal: 6,
      dueDate: '2026-10-09',
    );

    final DailyProjection p = run(debts: <Debt>[owedToMe]);

    expect(
      p.closingBalance,
      p.openingBalance,
      reason: 'somebody else debt moved this person own balance',
    );
    expect(p.days.every((ProjectedDay d) => d.moneyOut.isZero), isTrue);
    expect(
      p.undatedOutflow,
      Money.zero,
      reason: 'it is not undated either, it is simply not theirs to pay',
    );
  });

  group('the two answers a screen needs', () {
    test('the tightest day, and the first day it goes short', () {
      final DailyProjection p = run(
        bills: <BillItem>[
          bill('Rent', 9000, '2026-10-09'),
          bill('Tuition', 4000, '2026-10-16'),
        ],
        payday: const PaydayCycle(
          cycleType: 'monthly',
          lastPayday: '2026-09-20',
          nextPayday: '2026-10-20',
          daysToPayday: 13,
          expectedIncome: Money.pesos(30000),
          paydayDays: <int>[20],
        ),
      );

      // 10,000 less 9,000 on the 9th leaves 1,000. The 16th takes 4,000 more,
      // which is where it goes under, and payday on the 20th rescues it.
      expect(p.firstShortfall!.date, DateTime(2026, 10, 16));
      expect(p.firstShortfall!.balanceAfter, const Money.pesos(-3000));

      // The LOWEST point is the same day here, and the test says so rather
      // than relying on it: they are different questions and a later, deeper
      // dip is the normal case.
      expect(p.tightestDay!.date, DateTime(2026, 10, 16));

      // TWO paydays land inside the 45 day horizon, the 20th of October and
      // the 20th of November, so the closing balance carries 60,000 of income
      // rather than 30,000. Written out because the first draft of this
      // expectation forgot the second one and the engine was right.
      expect(p.closingBalance, const Money.pesos(57000));
    });

    test('tightest and first-short are NOT the same question', () {
      final DailyProjection p = run(
        bills: <BillItem>[
          bill('One', 10500, '2026-10-09'),
          bill('Two', 2000, '2026-10-20'),
        ],
      );
      expect(p.firstShortfall!.date, DateTime(2026, 10, 9));
      expect(
        p.tightestDay!.date,
        DateTime(2026, 10, 20),
        reason:
            'the first crossing is the day to act before; the lowest point '
            'comes later and is a different fact',
      );
    });
  });

  group('the banking calendar', () {
    test('Easter is computed, so the movable holidays never go stale', () {
      expect(easterSunday(2026), DateTime(2026, 4, 5));
      expect(holidayName(DateTime(2026, 4, 3)), 'Good Friday');
      expect(holidayName(DateTime(2026, 4, 2)), 'Maundy Thursday');
    });

    test('National Heroes Day is the LAST Monday of August', () {
      expect(holidayName(DateTime(2026, 8, 31)), 'National Heroes Day');
      expect(
        holidayName(DateTime(2026, 8, 24)),
        isNull,
        reason: 'the second to last Monday is an ordinary working day',
      );
    });

    test('a run of holidays is stepped over, not landed in', () {
      // Christmas Day 2026 is a Friday, so the 26th and 27th are the weekend
      // and the 28th is the next day a bank moves money.
      final BankingDay d = nextBankingDay(DateTime(2026, 12, 25));
      expect(d.date, DateTime(2026, 12, 28));
      expect(d.reason, 'Christmas Day');
    });

    test('an ordinary weekday does not move', () {
      final BankingDay d = nextBankingDay(DateTime(2026, 10, 7));
      expect(d.moved, isFalse);
      expect(d.date, DateTime(2026, 10, 7));
    });
  });

  test('it runs on the real seed without inventing or losing money', () {
    final DailyProjection p = projectDailyCash(
      accounts: SeedData.accounts(testToday),
      bills: SeedData.bills(testToday),
      upcoming: SeedData.upcoming(testToday),
      installments: SeedData.installments(testToday),
      debts: SeedData.debts(testToday),
      payday: SeedData.payday,
      now: testToday,
    );

    // Opening matches what the Accounts screen would call spendable.
    expect(
      p.openingBalance,
      Money.fromDouble(
        accountsTotalPhp(
          SeedData.accounts(testToday).where((Account a) => a.isSpendable),
        ),
      ),
    );

    // And it foots.
    Money ins = Money.zero;
    Money outs = Money.zero;
    for (final ProjectedDay d in p.days) {
      ins += d.moneyIn;
      outs += d.moneyOut;
    }
    expect(p.openingBalance + ins - outs, p.closingBalance);

    // The seed has instalments, which carry no due date, so the engine must
    // be reporting them as undated rather than quietly skipping them.
    expect(p.undatedOutflowCount, greaterThan(0));
  });
}
