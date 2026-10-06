import 'package:salapify/core/money/money.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/debt.dart';
import 'package:salapify/models/models.dart';

/// "Mark settled" then "Not settled after all" must not destroy the real
/// paid figure.
///
/// ## What this cost, measured before the fix
///
///     start        : paid 7,350.00 of 12,000.00
///     Mark settled : paid 12,000.00
///     Not settled  : paid 12,000.00, and 7,350.00 is gone for good
///
/// 4,650.00 the person never paid, recorded as paid, permanently. A debt
/// keeps no payment history, and the app has no edit or delete for one, so
/// the only route back was wiping the whole phone. Both buttons were wired
/// straight through with no confirmation on either.
///
/// The old behaviour was not careless, which is why it survived review: its
/// comment defended leaving the figure alone, and for a debt settled by REAL
/// PAYMENTS that is right, because the money really was paid and inventing a
/// smaller figure would be worse than a wrong flag. One function was serving
/// two cases that need opposite answers.
///
/// Founder direction, 2026-10-01, choosing restoration over a warning.
Debt _open() => const Debt(
  id: 'd1',
  person: 'Home Credit',
  direction: DebtDirection.iOwe,
  totalAmount: Money.pesos(12000),
  paidAmount: Money.pesos(7350),
  isSettled: false,
);

final DateTime _today = DateTime.utc(2026, 10, 1);

List<Debt> _toggle(List<Debt> debts) =>
    toggleDebtSettled(debts, 'd1', today: _today);

void main() {
  group('settling by hand is reversible', () {
    test('the real figure comes back, to the centavo', () {
      final List<Debt> start = <Debt>[_open()];

      final List<Debt> settled = _toggle(start);
      expect(settled.single.isSettled, isTrue);
      expect(
        settled.single.paidAmount,
        const Money.pesos(12000),
        reason:
            'settling must still FILL, or "settled" and "owes 7,350" '
            'can both be true on one row',
      );
      expect(settled.single.settledDate, '2026-10-01');

      final List<Debt> back = _toggle(settled);

      expect(
        back.single.paidAmount,
        const Money.pesos(7350),
        reason:
            '4,650.00 nobody paid is recorded as paid, and there is no screen '
            'in the app that can put it right',
      );
      expect(back.single.isSettled, isFalse);
      expect(back.single.settledDate, isNull);
      expect(
        back.single.paidBeforeSettle,
        isNull,
        reason:
            'the remembered figure was spent, so a later un-settle must not '
            'wind back to a settle that has already been undone',
      );
    });

    test('and nothing is remembered on a debt that was never filled', () {
      // The directional half for the field itself. If settling did not write
      // it, the test above could pass on a value that happened to be there.
      expect(_open().paidBeforeSettle, isNull);
      expect(
        _toggle(<Debt>[_open()]).single.paidBeforeSettle,
        const Money.pesos(7350),
      );
    });

    test('a debt settled by REAL PAYMENTS keeps its figure, as before', () {
      // The case the old behaviour was written for, and it is still right.
      // Un-settling here must NOT invent a smaller number: the money really
      // was paid. Null paidBeforeSettle is what says so.
      const Debt paidOff = Debt(
        id: 'd1',
        person: 'BPI',
        direction: DebtDirection.iOwe,
        totalAmount: Money.pesos(15000),
        paidAmount: Money.pesos(15000),
        isSettled: true,
        settledDate: '2026-09-01',
      );

      final List<Debt> back = _toggle(<Debt>[paidOff]);

      expect(
        back.single.paidAmount,
        const Money.pesos(15000),
        reason:
            'un-settling wound back a debt that was genuinely paid, which '
            'invents a smaller figure and is the defect this fix was meant '
            'to avoid causing',
      );
      expect(back.single.isSettled, isFalse);
    });

    test('a debt stored before this field existed behaves the old way', () {
      // Every debt already on the founder's phone reads null here, and null
      // has to mean the safe thing rather than the new thing.
      const Debt old = Debt(
        id: 'd1',
        person: 'Kuya Mark',
        direction: DebtDirection.iOwe,
        totalAmount: Money.pesos(5000),
        paidAmount: Money.pesos(5000),
        isSettled: true,
      );

      expect(_toggle(<Debt>[old]).single.paidAmount, const Money.pesos(5000));
    });

    test('settle, un-settle, settle again still remembers correctly', () {
      // Catches a remembered value going stale across a round trip, which is
      // the shape a single apply-then-reverse test cannot see.
      List<Debt> d = <Debt>[_open()];
      d = _toggle(d); // settled, remembers 7350
      d = _toggle(d); // back to 7350, forgets
      expect(d.single.paidAmount, const Money.pesos(7350));

      d = _toggle(d); // settled again, remembers 7350 afresh
      expect(d.single.paidBeforeSettle, const Money.pesos(7350));
      d = _toggle(d);
      expect(d.single.paidAmount, const Money.pesos(7350));
    });

    test('an unrelated copy of the debt does not lose the memory', () {
      // RENAMED 2026-10-06, and the old name is why this is worth reading.
      //
      // It used to be called "a payment recorded while settled does not lose
      // the memory", and it never recorded a payment. It calls `copyWith`
      // directly, which is the right subject for what it actually checks:
      // that an unrelated write to the debt carries `paidBeforeSettle`
      // through, unlike `isSample`.
      //
      // Under the old name it read as proof that the payment path was safe.
      // It was not. A real payment goes through `applyDebtPayment`, and that
      // left the memory STALE, which erased money on the next un-settle. The
      // group below is the test that was missing, and this one stops one step
      // short of the place the defect lived.
      //
      // Exactly the shape CLAUDE.md warns about: a test written from the same
      // mental model as the code, passing for the wrong reason, reading as
      // proof.
      final Debt settled = _toggle(<Debt>[_open()]).single;
      final Debt afterCopy = settled.copyWith(
        paidAmount: const Money.pesos(12500),
      );

      expect(afterCopy.paidBeforeSettle, const Money.pesos(7350));
    });
  });

  group('a payment landing on a settled debt is not erased by un-settling', () {
    // THE DEFECT, measured on the real seeded ledger before the fix:
    //
    //   start          paid 7,350.00 of 14,700.00, GCash 8,420.50
    //   Mark settled   paid 14,700.00, memory 7,350.00
    //   pay 2,450.00   paid 17,150.00, GCash 5,970.50, one register row
    //   Not settled    paid 7,350.00, GCash 5,970.50
    //
    //   ACCOUNT went DOWN by 2,450.00
    //   DEBT paid went UP by     0.00
    //
    // The money left the account with a confirmed entry naming it, the
    // register recorded it, and the debt forgot it. The person is told they
    // still owe money they have already handed over.
    //
    // Same loss and same field as the take-back route that
    // stale_settle_memory_test.dart closed. This is the DIRECT route, which
    // that fix did not reach.

    List<Debt> pay(List<Debt> debts, Money amount) =>
        applyDebtPayment(debts, 'd1', amount, today: _today);

    test('the debt keeps the payment when the settle is undone', () {
      List<Debt> d = <Debt>[_open()]; // 7,350 of 12,000
      d = _toggle(d); // settled, fills to 12,000, remembers 7,350
      d = pay(d, const Money.pesos(2450)); // a REAL payment on top
      d = _toggle(d); // not settled after all

      expect(
        d.single.paidAmount,
        const Money.pesos(9800),
        reason: '7,350 really paid plus a real 2,450 is 9,800. Restoring the '
            'stale 7,350 erases a payment the account has already made.',
      );
    });

    test('the account and the debt move by the SAME amount', () {
      // The invariant, stated as itself rather than as a figure. Paying a
      // debt moves an asset down and a liability down by one amount, and the
      // defect broke that by exactly the payment.
      final List<Debt> before = <Debt>[_open()];
      List<Debt> d = _toggle(before);
      d = pay(d, const Money.pesos(2450));
      d = _toggle(d);

      expect(
        d.single.paidAmount - before.single.paidAmount,
        const Money.pesos(2450),
      );
    });

    test('with NO payment in between, nothing changes', () {
      // The directional half. Every assertion above is satisfied by a fix
      // that simply stopped restoring anything, which would reintroduce the
      // original 4,650 defect this whole file exists for.
      List<Debt> d = <Debt>[_open()];
      d = _toggle(d);
      d = _toggle(d);

      expect(
        d.single.paidAmount,
        const Money.pesos(7350),
        reason: 'an un-settle with nothing in between must still put the '
            'real figure back, which is what this file was written for',
      );
    });

    test('taking the payment back takes the memory back with it', () {
      // The symmetric half. The payment bumps the memory, so the take-back
      // has to unbump it, or the memory keeps money the person just undid and
      // the next un-settle hands it back.
      List<Debt> d = <Debt>[_open()];
      d = _toggle(d); // remembers 7,350
      d = pay(d, const Money.pesos(2450)); // memory becomes 9,800
      d = reverseLastDebtPayment(d, 'd1'); // and must go back to 7,350

      expect(
        d.single.paidBeforeSettle,
        const Money.pesos(7350),
        reason: 'the take-back left the bump in place',
      );

      d = _toggle(d);
      expect(
        d.single.paidAmount,
        const Money.pesos(7350),
        reason: 'un-settling after the take-back must land on the real figure',
      );
    });

    test('two payments on a settled debt both survive', () {
      List<Debt> d = <Debt>[_open()];
      d = _toggle(d);
      d = pay(d, const Money.pesos(1000));
      d = pay(d, const Money.pesos(500));
      d = _toggle(d);

      expect(d.single.paidAmount, const Money.pesos(8850));
    });
  });
}
