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

    test('a payment recorded while settled does not lose the memory', () {
      // copyWith carries paidBeforeSettle through, unlike isSample. Without
      // that, any write to the debt between the two taps drops the memory and
      // the figure is lost by a different route.
      final Debt settled = _toggle(<Debt>[_open()]).single;
      final Debt afterPayment = settled.copyWith(
        paidAmount: const Money.pesos(12500),
      );

      expect(afterPayment.paidBeforeSettle, const Money.pesos(7350));
    });
  });
}
