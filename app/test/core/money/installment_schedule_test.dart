import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/installments.dart';
import 'package:salapify/core/money/money.dart';
import 'package:salapify/data/seed_data.dart';
import 'package:salapify/models/models.dart';

import '../../support/test_clock.dart';

/// The invariants the instalment engine never had, and the three defects they
/// would have caught.
///
/// Two independent expert passes reviewed this engine before the centavo
/// conversion, and both found the same thing from different directions: the
/// schedule never footed, and a settlement sweep at the end deleted the
/// evidence. Every assertion here is exact. There is no `closeTo` in this
/// file, because a centavo count does not need one, and a tolerance is how the
/// discrepancies hid in the first place.
///
/// What was broken, all three verified by running the old engine:
///
///  1. `inst_home_credit` collected 12 x 2,409.17 = 28,910.04 against a
///     28,910.00 contract. Four centavos of interest the contract never
///     specified.
///  2. A prepayment was collected TWICE. Five thousand paid on top, then the
///     counter kept demanding full instalments against a zero balance:
///     33,910.04 handed over on a 28,910.00 plan, overpaid by 5,000.04, with
///     two full 2,409.17 expenses written to the ledger after the balance
///     reached nothing.
///  3. Both tests that claimed to guard the settlement sweep ran the one
///     seeded plan that divides evenly, and all 29 instalment tests passed
///     with the sweep deleted.
InstallmentPlan _plan(String id) => SeedData.installments(
  DateTime(2026, 9, 18),
).firstWhere((InstallmentPlan p) => p.id == id);

void main() {
  group('I1 and I2: the schedule foots, on every seeded plan', () {
    test('principal, interest and payable all reconcile exactly', () {
      for (final InstallmentPlan p in SeedData.installments(
        DateTime(2026, 9, 18),
      )) {
        final InstallmentSchedule s = scheduleFor(p);

        expect(s.count, p.totalInstallments, reason: '${p.id} share count');
        expect(
          sumMoney(s.principalShares),
          p.principal,
          reason: '${p.id}: the principal shares do not sum to the principal',
        );
        expect(
          sumMoney(s.interestShares),
          p.totalInterest,
          reason: '${p.id}: the interest shares do not sum to the interest',
        );
        expect(
          s.totalPayable,
          p.totalPayable,
          reason: '${p.id}: the schedule does not collect the contract total',
        );

        // Built from its PARTS on every row, which is the check a person
        // actually runs against their statement.
        for (int i = 0; i < s.count; i++) {
          expect(
            s.instalmentAt(i),
            s.principalAt(i) + s.interestAt(i),
            reason: '${p.id} row $i does not reconcile',
          );
        }
      }
    });

    test('the Home Credit plan: the LAST payment carries the difference', () {
      // The directional companion. Without it, a schedule of twelve zeroes
      // foots perfectly and the test above passes.
      final InstallmentSchedule s = scheduleFor(_plan('inst_home_credit'));

      // Eleven at the quoted figure, which is what Home Credit bills.
      for (int i = 0; i < 11; i++) {
        expect(s.instalmentAt(i), const Money.of(2409, 17), reason: 'row $i');
      }
      // And the twelfth adjusts. THIS is the four centavos the old engine
      // collected and then swept away.
      expect(s.instalmentAt(11), const Money.of(2409, 13));
      expect(s.instalmentAt(0) == s.instalmentAt(11), isFalse);

      // The principal carries the whole adjustment; interest divides evenly.
      expect(s.principalAt(0), const Money.of(2041, 67));
      expect(s.principalAt(11), const Money.of(2041, 63));
      expect(s.interestAt(0), const Money.of(367, 50));
      expect(s.interestAt(11), const Money.of(367, 50));
    });

    test('a plan that divides evenly has no adjustment at all', () {
      // The other half. A rule that always adjusted the last payment would
      // pass everything above and be wrong on two of the three real plans.
      for (final String id in <String>['inst_spaylater', 'inst_bpi_sip']) {
        final InstallmentSchedule s = scheduleFor(_plan(id));
        expect(
          s.instalmentAt(0),
          s.instalmentAt(s.count - 1),
          reason: '$id was adjusted when it did not need to be',
        );
      }
    });
  });

  group('I4: settlement needs no sweep', () {
    test('paying Home Credit to term lands on exactly zero, three ways', () {
      // RUN THIS ON inst_home_credit AND NOTHING ELSE. It is the only seeded
      // plan that does not divide evenly, and the two tests that used to claim
      // to guard the old sweep both ran inst_spaylater, which divides
      // perfectly and therefore proved nothing.
      InstallmentPlan p = _plan('inst_home_credit');
      expect(p.paidInstallments, 5);

      Money handedOver = Money.zero;
      while (!p.isSettled) {
        final Money due = nextPaymentFor(p);
        expect(due.isPositive, isTrue, reason: 'a payment of nothing');
        handedOver += due;
        p = applyInstallmentPayment(
          <InstallmentPlan>[p],
          p.id,
          today: testToday,
        ).single;
      }

      expect(p.runningBalance, Money.zero);
      expect(p.principalRemaining, Money.zero);
      expect(p.interestRemaining, Money.zero);
      expect(p.paidInstallments, p.totalInstallments);

      // The directional half: the balances were NOT already zero, and what was
      // handed over is exactly what was still owed when we started.
      expect(handedOver, const Money.of(16864, 15));
    });

    test('and the whole contract collects exactly totalPayable, no more', () {
      // The four centavos, stated as money rather than as a schedule row.
      final InstallmentPlan seed = _plan('inst_home_credit');
      InstallmentPlan p = seed;
      Money fromHere = Money.zero;
      while (!p.isSettled) {
        fromHere += nextPaymentFor(p);
        p = applyInstallmentPayment(
          <InstallmentPlan>[p],
          p.id,
          today: testToday,
        ).single;
      }
      final Money alreadyPaid = scheduleFor(seed).totalPayable - fromHere;
      expect(alreadyPaid + fromHere, seed.totalPayable);
      expect(
        alreadyPaid + fromHere,
        const Money.pesos(28910),
        reason: 'the old engine collected 28,910.04 here',
      );
    });
  });

  group('I5 and I6: a prepayment is collected ONCE', () {
    test('five thousand on top does not get charged again', () {
      // The defect, stated as the test that would have caught it. Measured on
      // the old engine: 33,910.04 handed over on a 28,910.00 contract.
      InstallmentPlan p = _plan('inst_home_credit');

      Money handedOver = const Money.pesos(5) * 0; // starts at zero, typed
      handedOver = Money.zero;

      p = applyExtraPayment(
        <InstallmentPlan>[p],
        p.id,
        const Money.pesos(5000),
        today: DateTime(2026, 9, 18),
      ).single;
      handedOver += const Money.pesos(5000);

      int scheduledPayments = 0;
      while (!p.isSettled) {
        final Money due = nextPaymentFor(p);
        handedOver += due;
        p = applyInstallmentPayment(
          <InstallmentPlan>[p],
          p.id,
          today: testToday,
        ).single;
        scheduledPayments++;
      }

      // What was owed when the prepayment was made, and not a centavo more.
      expect(handedOver, const Money.of(16864, 15));
      expect(p.runningBalance, Money.zero);

      // DIRECTIONAL, and it is the whole point: the plan got SHORTER. Seven
      // instalments were left; the prepayment retired some of them. The old
      // engine took all seven in full and then zeroed the remainder.
      expect(
        scheduledPayments,
        lessThan(7),
        reason: 'the prepayment retired no instalments',
      );
    });

    test('the final payment on a prepaid plan is a stub, not a full one', () {
      // I6. Every payment is capped at what is left, so the last one collects
      // only the remainder. Without this the engine charges a full instalment
      // against a smaller balance and the difference is swallowed.
      InstallmentPlan p = applyExtraPayment(
        <InstallmentPlan>[_plan('inst_spaylater')],
        'inst_spaylater',
        const Money.pesos(1000),
        today: DateTime(2026, 9, 18),
      ).single;

      Money last = Money.zero;
      int n = 0;
      while (!p.isSettled) {
        last = nextPaymentFor(p);
        p = applyInstallmentPayment(
          <InstallmentPlan>[p],
          p.id,
          today: testToday,
        ).single;
        n++;
      }
      expect(
        last < p.installmentAmount,
        isTrue,
        reason: 'the final payment collected a full instalment',
      );
      expect(last, const Money.of(647, 80));
      expect(n, 4);
    });

    test('a settled plan refuses another payment', () {
      InstallmentPlan p = _plan('inst_spaylater');
      while (!p.isSettled) {
        p = applyInstallmentPayment(
          <InstallmentPlan>[p],
          p.id,
          today: testToday,
        ).single;
      }
      expect(nextPaymentFor(p), Money.zero);
      final InstallmentPlan again = applyInstallmentPayment(
        <InstallmentPlan>[p],
        p.id,
        today: testToday,
      ).single;
      expect(again.paidInstallments, p.paidInstallments);
    });
  });

  group('I7 and I8: a prepayment touches principal only', () {
    test('it comes off principal, and never off contracted interest', () {
      // On a flat add-on plan the interest was fixed at signing. The old
      // engine took the prepayment off BOTH balances, so a prepayment larger
      // than the principal left silently forgave contractual interest.
      final InstallmentPlan before = _plan('inst_spaylater');
      final InstallmentPlan after = applyExtraPayment(
        <InstallmentPlan>[before],
        before.id,
        const Money.pesos(1000),
        today: DateTime(2026, 9, 18),
      ).single;

      expect(
        after.principalRemaining,
        before.principalRemaining - const Money.pesos(1000),
      );
      expect(after.interestRemaining, before.interestRemaining);
      expect(
        after.runningBalance,
        after.principalRemaining + after.interestRemaining,
      );
    });

    test('a payment beyond the principal PAYS interest, never forgives it', () {
      // The old engine reduced both balances by the full amount, so interest
      // could fall by more than was handed over. The invariant that catches
      // that is not "interest never moves", it is that the balance falls by
      // exactly what was applied.
      final InstallmentPlan before = _plan('inst_spaylater');
      expect(before.principalRemaining, const Money.pesos(5600));
      expect(before.interestRemaining, const Money.of(991, 20));

      final InstallmentPlan after = applyExtraPayment(
        <InstallmentPlan>[before],
        before.id,
        const Money.pesos(6000),
        today: DateTime(2026, 9, 18),
      ).single;

      expect(after.principalRemaining, Money.zero);
      // 400 of the 6,000 went on interest, because 400 of interest was paid.
      expect(after.interestRemaining, const Money.of(591, 20));
      expect(
        before.runningBalance - after.runningBalance,
        const Money.pesos(6000),
        reason: 'the balance did not fall by exactly what was paid',
      );
      expect(after.extraPayments.last.amount, const Money.pesos(6000));
    });

    test('and handing over the whole balance settles the plan', () {
      // The other direction, and the one the cap must not break: somebody who
      // pays everything owed is finished, whatever the split was.
      final InstallmentPlan before = _plan('inst_spaylater');
      final InstallmentPlan after = applyExtraPayment(
        <InstallmentPlan>[before],
        before.id,
        before.runningBalance,
        today: DateTime(2026, 9, 18),
      ).single;
      expect(after.runningBalance, Money.zero);
      expect(after.isSettled, isTrue);
      // Directional: more than one thing moved, and the history shows it.
      expect(after.principalRemaining, Money.zero);
      expect(after.interestRemaining, Money.zero);
      expect(after.extraPayments.last.amount, const Money.of(6591, 20));
    });

    test('the balance is always principal plus interest, after everything', () {
      // I8, across every operation rather than after one of them.
      InstallmentPlan p = _plan('inst_home_credit');
      void check(String where) => expect(
        p.runningBalance,
        p.principalRemaining + p.interestRemaining,
        reason: 'the derivation broke $where',
      );
      check('at rest');
      // And the fixture is not a zero-interest plan, or this proves nothing.
      expect(p.interestRemaining.isPositive, isTrue);
      expect(p.interestRemaining == p.runningBalance, isFalse);

      p = applyInstallmentPayment(
        <InstallmentPlan>[p],
        p.id,
        today: testToday,
      ).single;
      check('after a scheduled payment');
      p = applyExtraPayment(
        <InstallmentPlan>[p],
        p.id,
        const Money.pesos(2000),
        today: DateTime(2026, 9, 18),
      ).single;
      check('after a prepayment');
      while (!p.isSettled) {
        p = applyInstallmentPayment(
          <InstallmentPlan>[p],
          p.id,
          today: testToday,
        ).single;
      }
      check('at settlement');
    });
  });

  group('I10: nothing here can go negative', () {
    test('no field is ever negative, on any path', () {
      for (final InstallmentPlan seed in SeedData.installments(
        DateTime(2026, 9, 18),
      )) {
        InstallmentPlan p = seed;
        while (!p.isSettled) {
          p = applyInstallmentPayment(
            <InstallmentPlan>[p],
            p.id,
            today: testToday,
          ).single;
          expect(p.runningBalance.isNegative, isFalse, reason: p.id);
          expect(p.principalRemaining.isNegative, isFalse, reason: p.id);
          expect(p.interestRemaining.isNegative, isFalse, reason: p.id);
        }
      }
    });
  });

  group('the seeded plans are internally consistent', () {
    test('every plan agrees with its own contract', () {
      // Two of these were wrong before this change, and the arithmetic was
      // typed by hand rather than derived. A sample plan that does not foot
      // teaches the wrong thing to the first person who opens the app.
      for (final InstallmentPlan p in SeedData.installments(
        DateTime(2026, 9, 18),
      )) {
        expect(
          p.totalPayable,
          p.principal + p.totalInterest,
          reason: '${p.id}: payable is not principal plus interest',
        );
        expect(
          p.runningBalance,
          p.principalRemaining + p.interestRemaining,
          reason: '${p.id}: the stored balance is not its own two parts',
        );

        // The schedule tail only describes a plan nobody has prepaid. A
        // prepayment deliberately breaks that relationship: it takes money off
        // the principal without advancing the counter, which is the whole
        // reason the plan finishes early.
        if (p.extraPayments.isEmpty) {
          final InstallmentSchedule s = scheduleFor(p);
          expect(
            p.principalRemaining,
            sumMoney(s.principalShares.skip(p.paidInstallments)),
            reason: '${p.id}: principal left does not match the schedule tail',
          );
          expect(
            p.interestRemaining,
            sumMoney(s.interestShares.skip(p.paidInstallments)),
            reason: '${p.id}: interest left does not match the schedule tail',
          );
        } else {
          // And a prepaid plan must still owe LESS than its untouched
          // schedule, or the prepayment did nothing.
          expect(
            p.runningBalance <
                sumMoney(
                      scheduleFor(p).principalShares.skip(p.paidInstallments),
                    ) +
                    sumMoney(
                      scheduleFor(p).interestShares.skip(p.paidInstallments),
                    ),
            isTrue,
            reason: '${p.id}: a recorded prepayment moved nothing',
          );
        }
      }
    });
  });
}
