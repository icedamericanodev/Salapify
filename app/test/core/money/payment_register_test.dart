import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/debt.dart';
import 'package:salapify/core/money/installments.dart';
import 'package:salapify/core/money/money.dart';
import 'package:salapify/data/seed_data.dart';
import 'package:salapify/models/models.dart';

import '../../support/test_clock.dart';

/// The register records what was APPLIED, so nothing has to be worked out
/// again later.
///
/// ## What it is for, in one sentence
///
/// Both instalment engines split a payment and throw the split away, so the
/// only way back was to re-derive it, and re-deriving it is wrong in a way
/// that every conservation check passes: the total foots and the composition
/// is silently corrupted. These tests pin the figures that proved it.
void main() {
  final DateTime today = testToday;

  InstallmentPlan spaylater() => SeedData.installments(
    testToday,
  ).firstWhere((InstallmentPlan p) => p.id == 'inst_spaylater');

  group('a prepayment records its own split', () {
    test('the 400 that could not be recovered', () {
      // The seeded plan: 5,600.00 principal and 991.20 interest still owed.
      // A 6,000 prepayment crosses the principal, which is exactly where the
      // documented policy ("principal first") stops being enough to rebuild
      // the answer: it would put all 6,000 back on principal.
      final InstallmentPlan before = spaylater();
      expect(before.principalRemaining, const Money.pesos(5600));
      expect(before.interestRemaining, const Money.of(991, 20));

      final InstallmentPlan after = applyExtraPayment(
        <InstallmentPlan>[before],
        before.id,
        const Money.pesos(6000),
        today: today,
      ).single;

      final PlanPayment row = after.payments.last;

      expect(row.amount, const Money.pesos(6000));
      expect(
        row.toPrincipal,
        const Money.pesos(5600),
        reason:
            'the split was not recorded, so a reversal has to guess it, and '
            'the guess overstates principal by the whole 400',
      );
      expect(row.toInterest, const Money.pesos(400));
      expect(
        row.installmentNumber,
        isNull,
        reason:
            'a prepayment is not a scheduled instalment, and the way back '
            'out has to be able to tell them apart',
      );
    });

    test('and the two parts always sum to the whole', () {
      // The invariant a controller would ask for first. Checked across the
      // shapes that take different branches: inside the principal, crossing
      // it, and capped by the balance.
      for (final Money offer in <Money>[
        const Money.pesos(1000),
        const Money.pesos(5600),
        const Money.pesos(6000),
        const Money.pesos(10000),
      ]) {
        final InstallmentPlan after = applyExtraPayment(
          <InstallmentPlan>[spaylater()],
          'inst_spaylater',
          offer,
          today: today,
        ).single;

        final PlanPayment row = after.payments.last;
        expect(
          row.toPrincipal + row.toInterest,
          row.amount,
          reason: 'the parts of a $offer prepayment do not foot',
        );
      }
    });

    test(
      'a capped prepayment records what was APPLIED, not what was offered',
      () {
        // Offering 10,000 against a 6,591.20 balance applies 6,591.20. The
        // difference exists nowhere else in the app, so a row holding the offer
        // would credit back money that never moved.
        final InstallmentPlan after = applyExtraPayment(
          <InstallmentPlan>[spaylater()],
          'inst_spaylater',
          const Money.pesos(10000),
          today: today,
        ).single;

        expect(after.payments.last.amount, const Money.of(6591, 20));
      },
    );
  });

  group('a scheduled instalment records its own split too', () {
    test('an ordinary month', () {
      final InstallmentPlan before = spaylater();
      final InstallmentPlan after = applyInstallmentPayment(
        <InstallmentPlan>[before],
        before.id,
        today: today,
      ).single;

      final PlanPayment row = after.payments.single;
      expect(row.amount, nextPaymentFor(before));
      expect(row.toPrincipal + row.toInterest, row.amount);
      expect(
        row.installmentNumber,
        before.paidInstallments + 1,
        reason: 'the row cannot say which instalment it was',
      );
    });

    test('THE STUB, which is the case that proved the register', () {
      // Prepay, then pay the next scheduled instalment. What it collects is
      // NOT the quoted instalment, because the cap bites. Re-deriving this
      // one from the schedule credited 1,647.80 against a ledger row holding
      // 591.20 and invented 1,400 of principal that was never owed.
      final InstallmentPlan prepaid = applyExtraPayment(
        <InstallmentPlan>[spaylater()],
        'inst_spaylater',
        const Money.pesos(6000),
        today: today,
      ).single;

      final Money collects = nextPaymentFor(prepaid);
      expect(
        collects,
        lessThan(prepaid.installmentAmount),
        reason:
            'the stub is not smaller than a full instalment, so this fixture '
            'no longer reaches the case it was written for',
      );

      final InstallmentPlan after = applyInstallmentPayment(
        <InstallmentPlan>[prepaid],
        prepaid.id,
        today: today,
      ).single;

      final PlanPayment row = after.payments.last;
      expect(
        row.amount,
        collects,
        reason:
            'the row holds the quoted instalment rather than what was '
            'actually collected, which is the 1,056.60 defect',
      );
      expect(row.toPrincipal + row.toInterest, row.amount);
    });

    test('and both kinds land in ONE ordered list', () {
      // One list, not two, because "the most recent event on this plan" has
      // to have an answer. A prepayment shortens the plan, so the instalments
      // after it collected different amounts, and taking it back while they
      // stand would leave them explainable by no schedule at all.
      InstallmentPlan p = spaylater();
      p = applyInstallmentPayment(
        <InstallmentPlan>[p],
        p.id,
        today: today,
      ).single;
      p = applyExtraPayment(
        <InstallmentPlan>[p],
        p.id,
        const Money.pesos(1000),
        today: today,
      ).single;
      p = applyInstallmentPayment(
        <InstallmentPlan>[p],
        p.id,
        today: today,
      ).single;

      expect(p.payments.length, 3);
      expect(p.payments[0].installmentNumber, isNotNull);
      expect(p.payments[1].installmentNumber, isNull, reason: 'the prepayment');
      expect(p.payments[2].installmentNumber, isNotNull);
    });
  });

  group('a debt payment records what cannot be recomputed', () {
    Debt owed({
      Money paid = const Money.pesos(7350),
      bool settled = false,
      String? settledDate,
      int? current,
      int? total,
    }) => Debt(
      id: 'd1',
      person: 'Home Credit',
      direction: DebtDirection.iOwe,
      totalAmount: const Money.pesos(14700),
      paidAmount: paid,
      isSettled: settled,
      settledDate: settledDate,
      installmentCurrent: current,
      installmentTotal: total,
    );

    test('the prior figures are stored, not derived', () {
      final Debt after = applyDebtPayment(
        <Debt>[owed()],
        'd1',
        const Money.pesos(1500),
        today: today,
        accountId: 'acc_gcash',
      ).single;

      final DebtPayment row = after.payments.single;
      expect(row.amount, const Money.pesos(1500));
      expect(row.paidBefore, const Money.pesos(7350));
      expect(row.settledBefore, isFalse);
      expect(row.accountId, 'acc_gcash');
    });

    test('a payment on an ALREADY settled debt keeps the original date', () {
      // The case where clearing the date on the way back would destroy a real
      // one. The row has to remember that it was already settled, and when.
      final Debt after = applyDebtPayment(
        <Debt>[
          owed(
            paid: const Money.pesos(14700),
            settled: true,
            settledDate: '2026-08-01',
          ),
        ],
        'd1',
        const Money.pesos(500),
        today: today,
      ).single;

      final DebtPayment row = after.payments.single;
      expect(row.settledBefore, isTrue);
      expect(
        row.settledDateBefore,
        '2026-08-01',
        reason:
            'the original cleared date is not recorded, so taking this '
            'payment back would either keep a wrong date or wipe a real one',
      );
      expect(
        after.settledDate,
        '2026-08-01',
        reason: 'and it is not restamped',
      );
    });

    test('the SATURATING counter is stored as it was', () {
      // 3 of 3: paying again does not move it. A reversal that decremented
      // would invent a payment nobody undid.
      final Debt after = applyDebtPayment(
        <Debt>[owed(current: 3, total: 3)],
        'd1',
        const Money.pesos(100),
        today: today,
      ).single;

      expect(after.installmentCurrent, 3, reason: 'it saturated, as before');
      expect(
        after.payments.single.installmentCurrentBefore,
        3,
        reason: 'the row says 2, so the way back invents a payment',
      );
    });

    test('paidBefore is the REAL figure, even after Mark settled filled it', () {
      // The one that defeats subtraction. "Mark settled" fills paidAmount to
      // the total between two payments, so after that the running figure is
      // not the sum of the payments and nothing else can tell you so.
      final List<Debt> filled = toggleDebtSettled(
        <Debt>[owed()],
        'd1',
        today: today,
      );
      expect(filled.single.paidAmount, const Money.pesos(14700));

      final Debt after = applyDebtPayment(
        filled,
        'd1',
        const Money.pesos(200),
        today: today,
      ).single;

      expect(
        after.payments.single.paidBefore,
        const Money.pesos(14700),
        reason:
            'the row records the pre-fill figure, so taking this payment back '
            'would wind the debt past the fill and lose it',
      );
    });
  });
}
