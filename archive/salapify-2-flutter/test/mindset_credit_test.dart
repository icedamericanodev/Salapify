// Vectors for the flat add-on BNPL preview. The fee is a ONE-TIME percentage of
// the price spread over the term, not a monthly rate.
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/money/mindset_credit.dart';

void main() {
  test('flat add-on: 20,000 at 3% over 6 months', () {
    final p = bnplFlatPlan(price: 20000, months: 6, feePercent: 3);
    expect(p.extraCost, closeTo(600, 0.001)); // one-time 3% of 20,000
    expect(p.totalPaid, closeTo(20600, 0.001));
    expect(p.monthly, closeTo(3433.333, 0.01)); // 20,600 / 6
  });

  test(
    'the fee is one-time, not per month: the term does not change extraCost',
    () {
      final three = bnplFlatPlan(price: 20000, months: 3, feePercent: 3);
      final twelve = bnplFlatPlan(price: 20000, months: 12, feePercent: 3);
      // Same one-time fee regardless of term (this is the whole point of a flat
      // add-on vs a monthly rate).
      expect(three.extraCost, closeTo(600, 0.001));
      expect(twelve.extraCost, closeTo(600, 0.001));
      // Only the installment size changes with the term.
      expect(three.monthly, closeTo(20600 / 3, 0.01));
      expect(twelve.monthly, closeTo(20600 / 12, 0.01));
    },
  );

  test('zero fee is a true 0% plan: no extra cost, monthly is price/term', () {
    final p = bnplFlatPlan(price: 12000, months: 12, feePercent: 0);
    expect(p.extraCost, 0);
    expect(p.totalPaid, 12000);
    expect(p.monthly, closeTo(1000, 0.001));
  });

  test(
    'credit score inputs: the installment drives the score, not the price',
    () {
      final i = creditScoreInputs(
        bnplFlatPlan(price: 20000, months: 6, feePercent: 3),
      );
      // The first installment (~3,433), NOT the full 20,000, is the cash out and
      // the monthly load; the fee rides as the markup (fee / price).
      expect(i.cashNow, closeTo(3433.33, 0.01));
      expect(i.monthlyLoad, closeTo(3433.33, 0.01));
      expect(i.creditMarkup, closeTo(0.03, 0.0001));
      expect(i.months, 6); // term carried through for the lock-in penalty
    },
  );

  test('a true 0% plan carries no markup', () {
    final i = creditScoreInputs(
      bnplFlatPlan(price: 12000, months: 12, feePercent: 0),
    );
    expect(i.creditMarkup, 0);
    expect(i.cashNow, closeTo(1000, 0.001));
    expect(i.monthlyLoad, closeTo(1000, 0.001));
  });

  test(
    'junk in, safe out: zero price and a stray zero term never divide by zero',
    () {
      final z = bnplFlatPlan(price: 0, months: 6, feePercent: 3);
      expect(z.totalPaid, 0);
      expect(z.monthly, 0);
      final t = bnplFlatPlan(price: 5000, months: 0, feePercent: 5);
      expect(t.months, 1); // floored
      expect(t.monthly, closeTo(5250, 0.001));
      final neg = bnplFlatPlan(price: 5000, months: 6, feePercent: -3);
      expect(neg.extraCost, 0); // negative fee treated as no fee
    },
  );
}
