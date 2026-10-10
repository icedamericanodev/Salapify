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

  test('paid, income, payday and debt rows are never held back', () {
    final List<BillItem> out = billsToReserve(
      bills: const <BillItem>[],
      upcoming: <UpcomingItem>[
        up('paid', 'Paid already', 100, 'Today', paid: true),
        up('in', 'Refund', 100, 'Today', income: true),
        up('pay', 'Sweldo', 100, 'Today', type: UpcomingItemType.payday),
        // Reserved through the debt itself; here it would count twice.
        up('loan', 'Home Credit', 100, 'Today', type: UpcomingItemType.debt),
        up('rent', 'Rent', 100, 'Today', type: UpcomingItemType.rent),
      ],
      daysToPayday: days,
      now: now,
    );
    expect(ids(out), <String>['upcoming:rent']);
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

  test('a different amount is a different bill, whatever the name', () {
    final List<BillItem> out = billsToReserve(
      bills: <BillItem>[bill('b', 'Meralco', 2840)],
      upcoming: <UpcomingItem>[up('u', 'Meralco', 3100, 'Today')],
      daysToPayday: days,
      now: now,
    );
    expect(ids(out), <String>['b', 'upcoming:u']);
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
