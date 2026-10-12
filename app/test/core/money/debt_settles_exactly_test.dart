import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/debt.dart';
import 'package:salapify/core/money/money.dart';
import 'package:salapify/models/models.dart';

/// A debt paid off in instalments must actually read as settled.
///
/// ## The defect, in two ordinary typed figures
///
///     debt total       : 78,510.57
///     paid 70,662.84 then 7,847.73
///     accumulated to   : 78,510.56999999999
///     paid >= total ?  : FALSE
///     remaining        : 0.0000000000145, shown as "PHP 0.00"
///
/// So the card said "₱0.00 remaining" and "not settled" at the same time.
/// Nothing was lost and nothing could be put right either: the only way to
/// clear it was "Mark settled", which fills the paid amount to the total and
/// until recently destroyed the real figure on the way back.
///
/// `paidAmount` accumulated in a double and `newPaid >= d.totalAmount`
/// compared two of them. Neither is a rounding policy problem, so no rounding
/// policy could have fixed it; the figures simply are not representable.
/// In whole centavos the comparison means what it says.
///
/// For somebody keeping books, a row that contradicts itself discredits every
/// other figure on the screen, which is why this is not a cosmetic item.
void main() {
  group('a debt paid in full reads as settled', () {
    test('the figures that could not be held in a double', () {
      // Chosen because they are exactly representable in centavos and not in
      // a double. 78,510.57 is an ordinary balance and the two payments are
      // ordinary payments.
      const Debt d = Debt(
        id: 'd1',
        person: 'BPI Personal Loan',
        direction: DebtDirection.iOwe,
        totalAmount: Money.of(78510, 57),
        paidAmount: Money.zero,
        isSettled: false,
      );

      final DateTime today = DateTime.utc(2026, 10, 1);
      List<Debt> debts = <Debt>[d];
      debts = applyDebtPayment(
        debts,
        'd1',
        const Money.of(70662, 84),
        today: today,
      );
      debts = applyDebtPayment(
        debts,
        'd1',
        const Money.of(7847, 73),
        today: today,
      );

      final Debt after = debts.single;

      expect(
        after.paidAmount,
        const Money.of(78510, 57),
        reason: 'the two payments did not add up to the debt, to the centavo',
      );
      expect(
        after.remaining,
        Money.zero,
        reason: 'a residue is left over that the screen rounds away to 0.00',
      );
      expect(
        after.isSettled,
        isTrue,
        reason:
            'the card says "0.00 remaining" and "not settled" at once, which '
            'for somebody keeping books discredits every other figure on it',
      );
    });

    test('and a debt genuinely short is still NOT settled', () {
      // The directional half. Settling everything would pass the test above
      // and would be a far worse bug: a debt marked clear while money is
      // still owed on it.
      const Debt d = Debt(
        id: 'd1',
        person: 'BPI Personal Loan',
        direction: DebtDirection.iOwe,
        totalAmount: Money.of(78510, 57),
        paidAmount: Money.zero,
        isSettled: false,
      );

      final List<Debt> debts = applyDebtPayment(
        <Debt>[d],
        'd1',
        // One centavo short, which is the smallest amount that must still
        // count as owing.
        const Money.of(78510, 56),
        today: DateTime.utc(2026, 10, 1),
      );

      expect(debts.single.isSettled, isFalse);
      expect(debts.single.remaining, const Money(1));
    });
  });
}
