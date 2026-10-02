import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/debt.dart';
import 'package:salapify/core/money/money.dart';
import 'package:salapify/models/models.dart';

/// The 4,650 data loss, reached through the TAKE-BACK door.
///
/// Found by a review pass on 2026-10-02, in code shipped the same day the
/// original was fixed, after the founder had tested and approved it.
///
/// ## The rule that was only half enforced
///
/// `paidBeforeSettle` has a lifecycle: `toggleDebtSettled` writes it on the
/// way in and SPENDS it on the way out, and it only ever describes a settle
/// that is currently in force. Three transitions can end a settle, and only
/// one of them knew about the field.
///
/// `reverseLastDebtPayment` rewinds a payment past the settle that followed
/// it. It restored `paidAmount`, `isSettled`, `settledDate` and
/// `installmentCurrent` from the stored row, and left `paidBeforeSettle`
/// attached, because `Debt.copyWith` carries it through unless told not to.
/// The stale figure then sat on the debt, on no screen, until the next
/// un-settle spent it.
///
/// This is the same shape as the archived-implies-settled defect found hours
/// earlier: a rule enforced at one entry point and not at the others.
///
/// ## What it cost, in the sequence a person can actually tap
///
///     pay 400      paid 400.00    settled no   memory none
///     mark settled paid 1,000.00  settled yes  memory 400.00
///     take it back paid 0.00      settled no   memory 400.00   <- stale
///     pay 1,000    paid 1,000.00  settled yes  memory 400.00
///     not settled  paid 400.00    settled no   memory none     <- 600 gone
///
/// After the last step the account really is 1,000.00 down with a confirmed
/// entry in Activity, and the debt claims 400.00 was paid. The app's own
/// stated invariant, that paying a debt moves an asset and a liability by
/// the same amount, is false by 600.00 and no screen explains it.
///
/// The un-settle button carries no confirmation, deliberately, because
/// "there is nothing to lose by tapping it". That sentence was not true.
void main() {
  const Debt open = Debt(
    id: 'd1',
    person: 'Mom',
    direction: DebtDirection.iOwe,
    totalAmount: Money.pesos(1000),
    paidAmount: Money.zero,
    isSettled: false,
  );
  final DateTime today = DateTime.utc(2026, 10, 2);

  test('a take-back across a settle leaves no stale memory behind', () {
    List<Debt> s = applyDebtPayment(
      <Debt>[open],
      'd1',
      const Money.pesos(400),
      today: today,
      paymentId: 'dp_1',
    );
    s = toggleDebtSettled(s, 'd1', today: today);

    // The midpoint, so the assertions below cannot pass by nothing happening.
    expect(s.single.paidBeforeSettle, const Money.pesos(400));
    expect(s.single.paidAmount, const Money.pesos(1000));

    s = reverseLastDebtPayment(s, 'd1');

    expect(s.single.paidAmount, Money.zero);
    expect(s.single.isSettled, isFalse);
    expect(
      s.single.paidBeforeSettle,
      isNull,
      reason:
          'a memory of a settle that has been rewound is still attached to '
          'this debt, invisible on every screen, and the next un-settle will '
          'spend it and destroy real money',
    );
  });

  test('and the money survives the whole round trip', () {
    // The consequence, spelled out, because the assertion above is about a
    // field and this one is about pesos.
    List<Debt> s = applyDebtPayment(
      <Debt>[open],
      'd1',
      const Money.pesos(400),
      today: today,
      paymentId: 'dp_1',
    );
    s = toggleDebtSettled(s, 'd1', today: today);
    s = reverseLastDebtPayment(s, 'd1');

    s = applyDebtPayment(
      s,
      'd1',
      const Money.pesos(1000),
      today: today,
      paymentId: 'dp_2',
    );
    expect(s.single.isSettled, isTrue, reason: 'paying it off did not settle');

    s = toggleDebtSettled(s, 'd1', today: today);

    expect(
      s.single.paidAmount,
      const Money.pesos(1000),
      reason:
          'the account is 1,000.00 down with a confirmed entry in Activity '
          'and the debt says 400.00 was paid, so 600.00 of real money was '
          'erased by a button that promises nothing can be lost',
    );
  });

  test('a take-back on a debt settled BEFORE the payment keeps its memory', () {
    // The silent half. The fix must not start clearing a memory that is
    // still in force: a stray payment on an already settled debt, taken
    // back, leaves the debt settled, and its original memory still
    // describes that settle.
    List<Debt> s = toggleDebtSettled(
      <Debt>[open.copyWith(paidAmount: const Money.pesos(300))],
      'd1',
      today: today,
    );
    expect(s.single.paidBeforeSettle, const Money.pesos(300));

    s = applyDebtPayment(
      s,
      'd1',
      const Money.pesos(50),
      today: today,
      paymentId: 'dp_x',
    );
    s = reverseLastDebtPayment(s, 'd1');

    expect(s.single.isSettled, isTrue);
    expect(
      s.single.paidBeforeSettle,
      const Money.pesos(300),
      reason:
          'the debt is still settled by the button, so forgetting what it '
          'filled in re-arms the original data loss from the other side',
    );
  });
}
