import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/health_check.dart';
import 'package:salapify/models/models.dart';

/// Five questions, answered only where they can be.
///
/// The thing most of this file is about is the person D19 names: somebody who
/// installed the app ten seconds ago, with no accounts, no payday and no
/// reason to trust it yet. The prototype's engine answers all twelve of its
/// questions for that person, using a 28,000 monthly spend and a 65,000
/// salary it made up. Every indicator here has to stay silent instead.
void main() {
  final DateTime now = DateTime(2026, 9, 20, 12);

  String iso(int daysAgo) {
    final DateTime d = now.subtract(Duration(days: daysAgo));
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  int seq = 0;
  Transaction spend(double amount, {int daysAgo = 1, String? date}) =>
      Transaction(
        id: 'tx${seq++}',
        type: TransactionType.expense,
        amount: amount,
        category: 'Food & Dining',
        accountId: 'a',
        date: date ?? iso(daysAgo),
        createdAt: 1758326400000,
      );

  Transaction earn(double amount, {int daysAgo = 1, String? date}) =>
      Transaction(
        id: 'tx${seq++}',
        type: TransactionType.income,
        amount: amount,
        category: 'Salary & Compensation',
        accountId: 'a',
        date: date ?? iso(daysAgo),
        createdAt: 1758326400000,
      );

  /// Enough separate days to make a pace a measurement.
  List<Transaction> paceOf(double perDay) => <Transaction>[
    for (int i = 1; i <= 10; i++) spend(perDay * 3, daysAgo: i),
  ];

  Account cash(double balance) => Account(
    id: 'a',
    name: 'GCash',
    kind: AccountKind.gcash,
    institution: 'GCash',
    balance: balance,
    monogram: 'GC',
  );

  const PaydayCycle setPayday = PaydayCycle(
    cycleType: '15_30',
    lastPayday: '2026-09-15',
    nextPayday: '2026-09-30',
    daysToPayday: 10,
    expectedIncome: 20000,
  );

  HealthReport run({
    List<Transaction>? transactions,
    List<Account>? accounts,
    List<Budget>? budgets,
    List<Goal>? goals,
    List<BillItem>? bills,
    List<InstallmentPlan>? installments,
    PaydayCycle? payday,
  }) => runHealthCheck(
    transactions: transactions ?? const <Transaction>[],
    accounts: accounts ?? const <Account>[],
    budgets: budgets ?? const <Budget>[],
    goals: goals ?? const <Goal>[],
    bills: bills ?? const <BillItem>[],
    installments: installments ?? const <InstallmentPlan>[],
    payday: payday ?? PaydayCycle.unset,
    now: now,
  );

  HealthIndicator of(HealthReport r, String id) =>
      r.indicators.firstWhere((HealthIndicator i) => i.id == id);

  group('the person who installed it ten seconds ago', () {
    final HealthReport fresh = run();

    test('gets five indicators and not one figure', () {
      expect(fresh.indicators, hasLength(5));
      expect(
        fresh.measured,
        isEmpty,
        reason:
            'an indicator answered a question about somebody who has '
            'entered nothing, which it can only have done by inventing the '
            'input',
      );
      expect(fresh.nothingYet, isTrue);
    });

    test('and every one of the five offers a way to fix that', () {
      for (final HealthIndicator i in fresh.indicators) {
        expect(i.need, isNotNull, reason: '${i.id} names no next step');
        expect(i.missing, isNotEmpty, reason: '${i.id} says nothing');
        expect(
          i.tone,
          isNull,
          reason: '${i.id} put a colour on a thing it did not measure',
        );
      }
    });

    test('no indicator shows a zero, because a zero is a measurement', () {
      for (final HealthIndicator i in fresh.indicators) {
        final String text = '${i.missing}';
        expect(
          text.contains('₱0'),
          isFalse,
          reason: '${i.id} shows a zero to somebody who has entered nothing',
        );
      }
    });
  });

  group('1. will I make it to payday', () {
    test('no payday set asks for the payday, not for spending', () {
      final HealthIndicator i = of(run(), 'payday');
      expect(i.need, HealthNeed.setPayday);
    });

    test('a payday but no logged spending asks for spending', () {
      final HealthIndicator i = of(run(payday: setPayday), 'payday');
      expect(i.need, HealthNeed.logSpending);
      expect(i.measured, isFalse);
    });

    test('a few receipts from ONE day is not a pace', () {
      // Coverage of the period, not a count of entries. Five receipts from
      // one Saturday say nothing about a month.
      final HealthReport r = run(
        payday: setPayday,
        accounts: <Account>[cash(20000)],
        transactions: <Transaction>[
          for (int i = 0; i < 8; i++) spend(200, daysAgo: 3),
        ],
      );
      expect(of(r, 'payday').measured, isFalse);
    });

    test('with a pace and cash, it answers', () {
      // 300 a day for 10 days is 3,000 needed, against 20,000 held.
      final HealthReport r = run(
        payday: setPayday,
        accounts: <Account>[cash(20000)],
        transactions: paceOf(300),
      );
      final HealthIndicator i = of(r, 'payday');
      expect(i.measured, isTrue);
      expect(i.reading, contains('Covered'));
      expect(i.tone, HealthTone.good);
    });

    test('a covered cycle prints NO peso figure of spare money', () {
      // Found by looking at the render, not by a test. It used to read
      // "₱105,303.87 spare over the next 4 days" directly under a Home card
      // reading "Safe to spend ₱38,414.00" for the same period. Both were
      // right; they differ because Safe to Spend also reserves debt
      // minimums, instalments and an emergency buffer. Two screens
      // disagreeing about the same month is a defect even when both are
      // defensible, and the bigger number wins in somebody's head.
      final HealthReport r = run(
        payday: setPayday,
        accounts: <Account>[cash(100000)],
        transactions: paceOf(300),
      );
      final String reading = of(r, 'payday').reading!;
      expect(
        reading.contains('₱'),
        isFalse,
        reason:
            'this card minted a second spare-money figure to compete with '
            'Safe to Spend: "$reading"',
      );
    });

    test('but a SHORTFALL keeps its size, because nothing else reports it', () {
      // The other half. Dropping every peso figure would pass the test above
      // and would leave somebody knowing they are short without knowing by
      // how much, which is the whole of that answer.
      final HealthReport r = run(
        payday: setPayday,
        accounts: <Account>[cash(500)],
        transactions: paceOf(300),
      );
      expect(of(r, 'payday').reading, contains('₱'));
    });

    test('a shortfall keeps its size and says short', () {
      final HealthReport r = run(
        payday: setPayday,
        accounts: <Account>[cash(500)],
        transactions: paceOf(300),
      );
      final HealthIndicator i = of(r, 'payday');
      expect(i.reading, contains('short'));
      expect(i.tone, HealthTone.tight);
    });

    test('the buffer threshold scales with the person, not with pesos', () {
      // The prototype calls 5,000 comfortable for everybody. Here comfort is
      // three days of your OWN pace, so a small earner can reach it and a
      // large one is not told they are fine on a day and a half.
      final HealthReport small = run(
        payday: setPayday,
        accounts: <Account>[cash(3400)],
        transactions: paceOf(100),
      );
      expect(
        of(small, 'payday').tone,
        HealthTone.good,
        reason: '400 spare on a 100 a day pace is four days, which is fine',
      );

      final HealthReport large = run(
        payday: setPayday,
        accounts: <Account>[cash(20400)],
        transactions: paceOf(2000),
      );
      expect(
        of(large, 'payday').tone,
        HealthTone.watch,
        reason: '400 spare on a 2,000 a day pace is under five hours',
      );
    });

    test('a bill due before payday is counted, one after it is not', () {
      final HealthReport r = run(
        payday: setPayday,
        accounts: <Account>[cash(20000)],
        transactions: paceOf(300),
        bills: <BillItem>[
          BillItem(
            id: 'b1',
            name: 'Meralco',
            amount: 2840,
            dueDate: iso(-3),
            isPaid: false,
          ),
          BillItem(
            id: 'b2',
            name: 'Next month',
            amount: 9000,
            dueDate: iso(-40),
            isPaid: false,
          ),
          BillItem(
            id: 'b3',
            name: 'Already paid',
            amount: 500,
            dueDate: iso(-2),
            isPaid: true,
          ),
        ],
      );
      final HealthIndicator i = of(r, 'payday');
      expect(i.detail, contains('2,840'));
      expect(
        i.detail,
        isNot(contains('11,840')),
        reason: 'a bill due after payday was charged to this cycle',
      );
    });
  });

  group('2. how much of my pay is already promised', () {
    test('no income recorded asks for it', () {
      expect(of(run(), 'promised').need, HealthNeed.setPayday);
    });

    test('owing nothing is a MEASUREMENT, not a missing input', () {
      // Unlike a missing credit limit, "no loans" is a real answer. Telling
      // somebody with none that Salapify cannot work it out is absurd.
      final HealthIndicator i = of(run(payday: setPayday), 'promised');
      expect(i.measured, isTrue);
      expect(i.tone, HealthTone.good);
      expect(i.reading, contains('Nothing recorded'));
    });

    test('the share is measured from real schedules', () {
      // 20,000 twice a month is 40,000. A 6,000 a month plan is 15%.
      final HealthReport r = run(
        payday: setPayday,
        installments: <InstallmentPlan>[_plan(monthly: 6000, left: 8)],
      );
      final HealthIndicator i = of(r, 'promised');
      expect(i.reading, contains('15%'));
      expect(i.tone, HealthTone.good);
    });

    test('and it counts the paydays still committed', () {
      // The figure the prototype never computes and the one that changes
      // behaviour: "31%" is abstract, "eight more payments" is not.
      final HealthReport r = run(
        payday: setPayday,
        installments: <InstallmentPlan>[_plan(monthly: 6000, left: 8)],
      );
      expect(of(r, 'promised').detail, contains('8 more payments'));
    });

    test('an informal debt does NOT inflate the ratio', () {
      // There is no minimum payment on money you owe your tita. The
      // prototype charges 8% of every outstanding debt as a monthly minimum,
      // which inflates the ratio and then bases the advice on it.
      final HealthReport withUtang = run(
        payday: setPayday,
        installments: <InstallmentPlan>[_plan(monthly: 6000, left: 8)],
      );
      expect(
        of(withUtang, 'promised').reading,
        contains('15%'),
        reason: 'only scheduled instalments belong in a debt service ratio',
      );
    });

    test('a heavy load reads tight', () {
      final HealthReport r = run(
        payday: setPayday,
        installments: <InstallmentPlan>[_plan(monthly: 18000, left: 3)],
      );
      expect(of(r, 'promised').tone, HealthTone.tight);
    });
  });

  group('3. do I have a cushion', () {
    test('it is NEVER inferred from what is lying around', () {
      // The prototype takes half of whatever is liquid, which tells somebody
      // who has saved nothing that they are halfway to safe.
      final HealthReport r = run(accounts: <Account>[cash(80000)]);
      final HealthIndicator i = of(r, 'cushion');
      expect(i.measured, isFalse);
      expect(i.need, HealthNeed.startCushion);
      expect(
        i.missing,
        contains('10,000'),
        reason: 'the first rung has to be a figure somebody can picture',
      );
    });

    test('a named fund is counted, even before a pace exists', () {
      final HealthReport r = run(goals: <Goal>[_goal(saved: 12000)]);
      final HealthIndicator i = of(r, 'cushion');
      expect(i.measured, isTrue);
      expect(i.reading, contains('12,000'));
      expect(i.detail, contains('logged spending'));
    });

    test('with a pace it reads in months of the person OWN spending', () {
      // 300 a day is 9,000 a month, so 27,000 is three months.
      final HealthReport r = run(
        goals: <Goal>[_goal(saved: 27000)],
        transactions: paceOf(300),
      );
      final HealthIndicator i = of(r, 'cushion');
      expect(i.reading, contains('3.0 months'));
      expect(i.tone, HealthTone.good);
    });

    test('a thin cushion reads tight rather than absent', () {
      final HealthReport r = run(
        goals: <Goal>[_goal(saved: 2000)],
        transactions: paceOf(300),
      );
      expect(of(r, 'cushion').tone, HealthTone.tight);
    });
  });

  group('4. am I keeping any of it', () {
    test('nothing logged at all asks for entries', () {
      expect(of(run(), 'keeping').need, HealthNeed.logSpending);
    });

    test(
      'one month of data reports it and says the comparison comes later',
      () {
        final HealthReport r = run(
          transactions: <Transaction>[
            earn(30000, daysAgo: 5),
            spend(10000, daysAgo: 4),
          ],
        );
        final HealthIndicator i = of(r, 'keeping');
        expect(i.reading, contains('20,000'));
        expect(i.detail, contains('Next month'));
      },
    );

    test('two months compares them, which is the whole point', () {
      // DIRECTIONAL rather than a percentage. A 20% target on a Metro Manila
      // salary after rent is often arithmetically impossible, so an absolute
      // rate becomes a monthly notice that somebody doing their best has
      // failed.
      final HealthReport r = run(
        transactions: <Transaction>[
          earn(30000, date: '2026-09-05'),
          spend(10000, date: '2026-09-06'),
          earn(30000, date: '2026-08-05'),
          spend(25000, date: '2026-08-06'),
        ],
      );
      final HealthIndicator i = of(r, 'keeping');
      expect(i.reading, contains('20,000'));
      expect(i.detail, contains('15,000.00 better'));
      expect(i.tone, HealthTone.good);
    });

    test('going backwards says so plainly', () {
      final HealthReport r = run(
        transactions: <Transaction>[
          earn(30000, date: '2026-09-05'),
          spend(28000, date: '2026-09-06'),
          earn(30000, date: '2026-08-05'),
          spend(10000, date: '2026-08-06'),
        ],
      );
      final HealthIndicator i = of(r, 'keeping');
      expect(i.detail, contains('worse'));
      expect(i.tone, HealthTone.watch);
    });

    test('spending more than came in is tight, whatever last month did', () {
      final HealthReport r = run(
        transactions: <Transaction>[
          earn(10000, date: '2026-09-05'),
          spend(28000, date: '2026-09-06'),
        ],
      );
      expect(of(r, 'keeping').tone, HealthTone.tight);
    });

    test('a transfer moves nothing here', () {
      // Moving your own money between your own accounts is not income and
      // not spending, and counting it would report a saving that is a
      // rearrangement.
      final HealthReport r = run(
        transactions: <Transaction>[
          earn(30000, daysAgo: 5),
          Transaction(
            id: 'tr',
            type: TransactionType.transfer,
            amount: 9000,
            category: 'Transfer',
            accountId: 'a',
            toAccountId: 'b',
            date: iso(4),
            createdAt: 1758326400000,
          ),
        ],
      );
      expect(of(r, 'keeping').reading, contains('30,000'));
    });
  });

  group('5. am I inside the limits I set', () {
    test('no limits asks for ONE, not for twelve', () {
      // A fresh user asked to budget every category sets none.
      final HealthIndicator i = of(run(), 'limits');
      expect(i.need, HealthNeed.setBudget);
      expect(i.missing, contains('the one category'));
    });

    test('it reports the closest to its limit', () {
      final HealthReport r = run(
        budgets: <Budget>[_budget('Food & Dining', 5000)],
        transactions: <Transaction>[spend(4200, date: '2026-09-10')],
      );
      final HealthIndicator i = of(r, 'limits');
      expect(i.reading, contains('84%'));
      expect(i.tone, HealthTone.watch);
    });

    test('over the limit says by how much', () {
      final HealthReport r = run(
        budgets: <Budget>[_budget('Food & Dining', 5000)],
        transactions: <Transaction>[spend(6200, date: '2026-09-10')],
      );
      final HealthIndicator i = of(r, 'limits');
      expect(i.reading, contains('over by'));
      expect(i.reading, contains('1,200'));
      expect(i.tone, HealthTone.tight);
    });

    test('last month\'s spending does not count against this month', () {
      // The prototype sums EVERY transaction ever against a monthly limit,
      // so a six month old ledger shows every budget permanently breached.
      final HealthReport r = run(
        budgets: <Budget>[_budget('Food & Dining', 5000)],
        transactions: <Transaction>[
          spend(4000, date: '2026-08-10'),
          spend(1000, date: '2026-09-10'),
        ],
      );
      expect(of(r, 'limits').reading, contains('20%'));
    });
  });

  group('the order, and what it protects', () {
    test('it is always the same five, in the same order', () {
      expect(run().indicators.map((HealthIndicator i) => i.id), <String>[
        'payday',
        'promised',
        'cushion',
        'keeping',
        'limits',
      ]);
    });

    test('a liquidity problem outranks anything below it', () {
      // The fixed order is what stops a budget note rendering above "you are
      // short before payday".
      final HealthReport r = run(
        payday: setPayday,
        accounts: <Account>[cash(200)],
        transactions: <Transaction>[
          ...paceOf(300),
          spend(6200, date: '2026-09-10'),
        ],
        budgets: <Budget>[_budget('Food & Dining', 5000)],
      );
      expect(of(r, 'payday').tone, HealthTone.tight);
      expect(of(r, 'limits').tone, HealthTone.tight);
      expect(
        r.needsAttention?.id,
        'payday',
        reason: 'the budget was raised above running out of money',
      );
    });

    test('with nothing wrong, nothing is raised', () {
      // The other half. A rule that always returned something would pass the
      // test above and would make the screen permanently alarmed.
      // The income matters: paceOf logs only EXPENSES, so without it the
      // month is genuinely negative and 'keeping' is right to say so. That
      // is the engine working, and it took this test to notice the fixture
      // was describing somebody who earns nothing.
      final HealthReport r = run(
        payday: setPayday,
        accounts: <Account>[cash(50000)],
        transactions: <Transaction>[...paceOf(300), earn(40000, daysAgo: 6)],
      );
      expect(r.needsAttention, isNull);
    });
  });
}

InstallmentPlan _plan({required double monthly, required int left}) =>
    InstallmentPlan(
      id: 'p1',
      name: 'Gadget',
      provider: 'Home Credit',
      principal: 48000,
      interestRate: 0,
      interestRateType: InterestRateType.monthly,
      totalInterest: 0,
      totalPayable: 48000,
      termMonths: 12,
      installmentAmount: monthly,
      paidInstallments: 12 - left,
      totalInstallments: 12,
      runningBalance: monthly * left,
      principalRemaining: monthly * left,
      interestRemaining: 0,
      startDate: '2026-01-05',
      maturityDate: '2026-12-05',
    );

Goal _goal({required double saved}) => Goal(
  id: 'g1',
  name: 'Emergency fund',
  emoji: '🛡️',
  targetAmount: 90000,
  currentAmount: saved,
  targetDate: '2027-06-30',
  monthlyTarget: 5000,
);

Budget _budget(String category, double limit) =>
    Budget(category: category, limit: limit, emoji: '🍔');
