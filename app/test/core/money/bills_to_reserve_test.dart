import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/bills_to_reserve.dart';
import 'package:salapify/core/money/money.dart';
import 'package:salapify/models/models.dart';

/// What Safe to Spend holds back: the built-in bills AND the bills a person
/// adds on the Bills screen (D32, 2026-10-09). Before D32 an added bill was
/// held back by nothing.
void main() {
  // A Friday. Payday is 12 days away, on the 30th.
  final DateTime now = DateTime(2026, 9, 18, 12);
  const int days = 12;

  UpcomingItem up(
    String id,
    String name,
    int pesos,
    String due, {
    UpcomingItemType type = UpcomingItemType.bill,
    bool paid = false,
    bool income = false,
  }) => UpcomingItem(
    id: id,
    name: name,
    amount: Money.pesos(pesos),
    dueDate: due,
    type: type,
    isPaid: paid,
    isIncome: income,
  );

  BillItem bill(String id, String name, int pesos, {bool paid = false}) =>
      BillItem(
        id: id,
        name: name,
        amount: Money.pesos(pesos),
        dueDate: '2026-09-25',
        isPaid: paid,
      );

  List<String> ids(List<BillItem> out) =>
      out.map((BillItem b) => b.id).toList();

  test('an added bill due before payday is held back, at its amount', () {
    final List<BillItem> out = billsToReserve(
      bills: <BillItem>[bill('b1', 'Manila Water', 480)],
      upcoming: <UpcomingItem>[up('u1', 'PLDT Fibr', 1699, '2026-09-25')],
      daysToPayday: days,
      now: now,
    );
    // Directional: the list grew by exactly the added bill, and the built-in
    // one is still there.
    expect(ids(out), <String>['b1', 'upcoming:u1']);
    expect(out.last.amount, const Money.pesos(1699));
  });

  test('a bill due after payday waits for the next cycle', () {
    final List<BillItem> out = billsToReserve(
      bills: const <BillItem>[],
      upcoming: <UpcomingItem>[
        up('due', 'On payday itself', 100, '2026-09-30'),
        up('late', 'The day after', 200, '2026-10-01'),
      ],
      daysToPayday: days,
      now: now,
    );
    expect(ids(out), <String>['upcoming:due']);
  });

  test('overdue counts, and so does a date nobody can read', () {
    final List<BillItem> out = billsToReserve(
      bills: const <BillItem>[],
      upcoming: <UpcomingItem>[
        up('old', 'Missed last week', 300, '2026-09-10'),
        up('vague', 'Sometime', 400, 'when they ask'),
      ],
      daysToPayday: days,
      now: now,
    );
    expect(ids(out), <String>['upcoming:old', 'upcoming:vague']);
  });

  test('paid, income and payday rows are never held back', () {
    final List<BillItem> out = billsToReserve(
      bills: const <BillItem>[],
      upcoming: <UpcomingItem>[
        up('paid', 'Paid already', 100, 'Today', paid: true),
        up('in', 'Refund', 100, 'Today', income: true),
        up('pay', 'Sweldo', 100, 'Today', type: UpcomingItemType.payday),
        up('rent', 'Rent', 100, 'Today', type: UpcomingItemType.rent),
      ],
      daysToPayday: days,
      now: now,
    );
    expect(ids(out), <String>['upcoming:rent']);
  });

  Debt homeCredit({String? due = '2026-09-18'}) => Debt(
    id: 'd',
    person: 'Home Credit (Phone)',
    direction: DebtDirection.iOwe,
    totalAmount: const Money.pesos(20000),
    paidAmount: Money.zero,
    isSettled: false,
    dueDate: due,
    minimumPayment: const Money.pesos(2450),
  );

  test('a payment a debt already holds back is not held back again, '
      'whatever type it was scheduled as', () {
    // Found by the ledger-reconciler: scheduled as a "Bill", this was held
    // back here AND as the debt's minimum, 2,450 twice.
    for (final UpcomingItemType t in <UpcomingItemType>[
      UpcomingItemType.bill,
      UpcomingItemType.debt,
    ]) {
      final List<BillItem> out = billsToReserve(
        bills: const <BillItem>[],
        upcoming: <UpcomingItem>[
          up('u', 'Home Credit phone', 2450, 'Today', type: t),
        ],
        daysToPayday: days,
        now: now,
        debts: <Debt>[homeCredit()],
      );
      expect(ids(out), isEmpty, reason: '$t was held back twice');
    }
  });

  test('a "Debt" row with no debt behind it IS held back', () {
    // Skipping by type held this back nowhere: 5,000 the person scheduled
    // and Safe to Spend never set aside.
    final List<BillItem> out = billsToReserve(
      bills: const <BillItem>[],
      upcoming: <UpcomingItem>[
        up(
          'u',
          'BDO card payment',
          5000,
          '2026-09-23',
          type: UpcomingItemType.debt,
        ),
      ],
      daysToPayday: days,
      now: now,
      debts: <Debt>[homeCredit()],
    );
    expect(ids(out), <String>['upcoming:u']);
  });

  test('a payment plan already holds back its own instalment', () {
    // Eight of twelve paid from January 25th, so the next is September 25th.
    const InstallmentPlan plan = InstallmentPlan(
      id: 'p',
      name: 'Samsung fridge',
      provider: 'Abenson',
      principal: Money.pesos(36000),
      interestRate: 0,
      interestRateType: InterestRateType.monthly,
      totalInterest: Money.pesos(0),
      totalPayable: Money.pesos(36000),
      termMonths: 12,
      installmentAmount: Money.pesos(3000),
      paidInstallments: 8,
      totalInstallments: 12,
      runningBalance: Money.pesos(12000),
      principalRemaining: Money.pesos(12000),
      interestRemaining: Money.pesos(0),
      startDate: '2026-01-25',
      maturityDate: '2026-12-25',
    );
    final List<BillItem> out = billsToReserve(
      bills: const <BillItem>[],
      upcoming: <UpcomingItem>[up('u', 'Fridge (Samsung)', 3000, '2026-09-25')],
      daysToPayday: days,
      now: now,
      installments: <InstallmentPlan>[plan],
    );
    expect(ids(out), isEmpty);
  });

  test('a bill on both lists is held back once', () {
    final List<BillItem> out = billsToReserve(
      bills: <BillItem>[bill('b', 'Meralco Electricity', 2840)],
      upcoming: <UpcomingItem>[up('u', 'Meralco Electric Bill', 2840, 'Today')],
      daysToPayday: days,
      now: now,
    );
    expect(ids(out), <String>['b']);
  });

  test('a built-in bill absorbs one twin, not two', () {
    final List<BillItem> out = billsToReserve(
      bills: <BillItem>[bill('b', 'Meralco', 2840)],
      upcoming: <UpcomingItem>[
        up('u1', 'Meralco', 2840, 'Today'),
        up('u2', 'Meralco', 2840, 'Tomorrow'),
      ],
      daysToPayday: days,
      now: now,
    );
    expect(ids(out), <String>['b', 'upcoming:u2']);
  });

  test('a PAID built-in bill is not a twin of an unpaid added one', () {
    // The seed has exactly this: Spotify paid on the 14th on one list and
    // unpaid, due Sunday, on the Bills screen. The "Counted twice" notice
    // skips paid bills too, so the two readers agree these are two entries.
    final List<BillItem> out = billsToReserve(
      bills: <BillItem>[bill('b', 'Spotify Family Plan', 239, paid: true)],
      upcoming: <UpcomingItem>[
        up('u', 'Spotify Premium Family', 239, 'Sunday'),
      ],
      daysToPayday: days,
      now: now,
    );
    expect(ids(out), <String>['b', 'upcoming:u']);
  });

  test('two rents eleven days apart are two rents', () {
    // The same amount and a shared word, but more than seven days apart:
    // the "Counted twice" notice calls these two payments, so the figure
    // must too. Merging them dropped 14,000 of reserve without a word.
    final List<BillItem> out = billsToReserve(
      bills: <BillItem>[
        BillItem(
          id: 'b',
          name: 'Condo Unit Rental',
          amount: const Money.pesos(14000),
          dueDate: '2026-09-30',
        ),
      ],
      upcoming: <UpcomingItem>[
        up('u', 'Condo rent', 14000, '2026-09-19', type: UpcomingItemType.rent),
      ],
      daysToPayday: days,
      now: now,
    );
    expect(ids(out), <String>['b', 'upcoming:u']);
  });

  test('a different amount is a different bill, whatever the name', () {
    final List<BillItem> out = billsToReserve(
      bills: <BillItem>[bill('b', 'Meralco', 2840)],
      upcoming: <UpcomingItem>[up('u', 'Meralco', 3100, 'Today')],
      daysToPayday: days,
      now: now,
    );
    expect(ids(out), <String>['b', 'upcoming:u']);
  });

  test('a built-in bill due after payday waits too (D33)', () {
    // The engine holds back every built-in bill it is handed, so the date
    // has to be applied here or a bill due next cycle is reserved now.
    final List<BillItem> out = billsToReserve(
      bills: <BillItem>[
        BillItem(
          id: 'tuition',
          name: 'Tuition',
          amount: const Money.pesos(8500),
          dueDate: '2026-10-05',
        ),
        BillItem(
          id: 'late',
          name: 'Overdue water',
          amount: const Money.pesos(480),
          dueDate: '2026-09-10',
        ),
        BillItem(
          id: 'paid',
          name: 'Paid in October',
          amount: const Money.pesos(100),
          dueDate: '2026-10-20',
          isPaid: true,
        ),
      ],
      upcoming: const <UpcomingItem>[],
      daysToPayday: days,
      now: now,
    );
    // Overdue stays held; a paid one passes through for Pan to report.
    expect(ids(out), <String>['late', 'paid']);
  });

  test('a bill on both lists keeps the date the Bills screen shows (D33)', () {
    final List<BillItem> out = billsToReserve(
      bills: <BillItem>[
        BillItem(
          id: 'b',
          name: 'Meralco Electricity',
          amount: const Money.pesos(2840),
          dueDate: '2026-09-15',
        ),
      ],
      upcoming: <UpcomingItem>[up('u', 'Meralco Electric Bill', 2840, 'Today')],
      daysToPayday: days,
      now: now,
    );
    expect(ids(out), <String>['b']);
    expect(out.single.dueDate, '2026-09-18');
  });

  test('a twin dated after payday on the Bills screen waits too', () {
    final List<BillItem> out = billsToReserve(
      bills: <BillItem>[
        BillItem(
          id: 'b',
          name: 'PLDT Fibr',
          amount: const Money.pesos(1699),
          dueDate: '2026-09-28',
        ),
      ],
      upcoming: <UpcomingItem>[up('u', 'PLDT Fibr', 1699, '2026-10-02')],
      daysToPayday: days,
      now: now,
    );
    expect(ids(out), isEmpty);
  });

  test('paying the Bills-screen copy lets the built-in twin go too', () {
    // A one-off ticked on Bills, and a monthly one paid once (now next
    // month, with the payment it moved on). Either way the built-in twin is
    // money already gone, not money to hold back.
    for (final UpcomingItem paid in <UpcomingItem>[
      up('u', 'Meralco Electricity', 2840, 'Today', paid: true),
      const UpcomingItem(
        id: 'u',
        name: 'Meralco Electricity',
        amount: Money.pesos(2840),
        dueDate: '2026-10-18',
        type: UpcomingItemType.bill,
        repeatDay: 18,
        lastPaidTxId: 'tx_bill_1',
      ),
    ]) {
      final List<BillItem> out = billsToReserve(
        bills: <BillItem>[
          BillItem(
            id: 'b',
            name: 'Meralco Electricity',
            amount: const Money.pesos(2840),
            dueDate: '2026-09-17',
          ),
        ],
        upcoming: <UpcomingItem>[paid],
        daysToPayday: days,
        now: now,
      );
      expect(
        out.where((BillItem b) => !b.isPaid).map((BillItem b) => b.id),
        isEmpty,
        reason: 'held back money already paid (${paid.repeats})',
      );
    }
  });

  test('the held-back copy carries a date the other readers can parse', () {
    final List<BillItem> out = billsToReserve(
      bills: const <BillItem>[],
      upcoming: <UpcomingItem>[
        up('sun', 'Spotify', 239, 'Sep 20'),
        up('vague', 'Sometime', 400, 'when they ask'),
      ],
      daysToPayday: days,
      now: now,
    );
    expect(out.first.dueDate, '2026-09-20');
    expect(DateTime.tryParse(out.first.dueDate), isNotNull);
    // No date to write, so the label stays as typed.
    expect(out.last.dueDate, 'when they ask');
  });
}
