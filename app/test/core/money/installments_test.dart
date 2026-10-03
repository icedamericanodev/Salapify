import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/installments.dart';
import 'package:salapify/data/seed_data.dart';
import 'package:salapify/models/models.dart';

import '../../support/test_clock.dart';
import 'package:salapify/core/money/money.dart';

/// Golden vectors for the instalment plan port.
///
/// Every figure below was PRINTED by running the prototype's own reducers over
/// the prototype's own seeded plans, via app/tool/gen_installment_vectors.ts
/// under bun.
///
/// ONE DIVERGENCE is asserted rather than hidden: see "a settled plan cannot
/// be paid again".
void main() {
  final DateTime today = DateTime(2026, 9, 18);

  InstallmentPlan of(List<InstallmentPlan> list, String id) =>
      list.firstWhere((InstallmentPlan p) => p.id == id);

  List<InstallmentPlan> pay(String id, [List<InstallmentPlan>? from]) =>
      applyInstallmentPayment(
        from ?? SeedData.installments(testToday),
        id,
        today: testToday,
      );

  group('the seed is the prototype\'s, in full', () {
    test('every plan carries its real contract, not a name and an amount', () {
      final InstallmentPlan p = of(
        SeedData.installments(testToday),
        'inst_home_credit',
      );
      expect(p.provider, 'Home Credit');
      expect(p.principal, const Money.pesos(24500));
      expect(p.totalInterest, const Money.pesos(4410));
      expect(p.totalPayable, const Money.pesos(28910));
      expect(p.termMonths, 12);
      expect(p.maturityDate, '2027-04-18');
      // CORRECTED with the centavo conversion. These were 16,864.19 and
      // 14,291.67, computed as seven times the ROUNDED instalment, which is
      // four centavos more than the contract. Derived from the contract now:
      // 24,500 less five shares of 2,041.67, and 4,410 less five of 367.50.
      expect(p.runningBalance, const Money.of(16864, 15));
      expect(
        p.principalRemaining,
        const Money.of(14291, 65),
        reason:
            'This class was a four field stub until the Installments '
            'batch. The coverage audit missed it because it compared RECORD '
            'COUNTS, and three stubs count the same as three plans.',
      );
    });

    test('the three plans differ in shape, so the screen can be reviewed', () {
      final List<InstallmentPlan> all = SeedData.installments(testToday);
      expect(
        all.where((InstallmentPlan p) => p.isZeroInterest).length,
        1,
        reason: 'a genuine 0 percent promo',
      );
      expect(
        all.where((InstallmentPlan p) => p.extraPayments.isNotEmpty).length,
        1,
        reason: 'one plan with a prepayment already against it',
      );
      expect(
        all
            .where(
              (InstallmentPlan p) =>
                  p.interestRateType == InterestRateType.monthly,
            )
            .length,
        2,
      );
    });
  });

  group('a scheduled payment matches the prototype', () {
    test('the monthly add-on plan', () {
      final InstallmentPlan p = of(pay('inst_home_credit'), 'inst_home_credit');
      expect(p.paidInstallments, 6);
      expect(p.runningBalance, const Money.of(14454, 98));
      expect(
        // 12,249.98, and EXACTLY, with no tolerance. This line used to read
        // closeTo(12250.003333333334, 0.000001), with a comment explaining
        // that the carried third of a centavo was real and that "nothing here
        // rounds it away". That was the defect written down as a feature: the
        // third of a centavo existed because the schedule never footed, and a
        // sweep at the end deleted the evidence. The share is a whole 2,041.67
        // now, and the twelfth payment carries the difference.
        p.principalRemaining,
        const Money.of(12249, 98),
        reason:
            'The balance fell by the full 2,409.17 instalment while the '
            'principal fell by only its own 2,041.67 share. Those two moving '
            'by different amounts is the whole reason both are kept: it is '
            'how somebody can see an early payment is mostly interest.',
      );
      expect(p.interestRemaining, const Money.of(2205, 0));
      expect(p.isSettled, isFalse);
    });

    test('the genuine 0 percent plan moves both by the same amount', () {
      final InstallmentPlan p = of(pay('inst_bpi_sip'), 'inst_bpi_sip');
      expect(p.paidInstallments, 11);
      // 25,203.75, not 29,786.25. The seed records a 4,582.50 prepayment that
      // its own balances used to ignore: 32,077.50 was exactly fourteen
      // untouched instalments. The prepayment is credited now, so the plan
      // genuinely has less to pay.
      expect(p.runningBalance, const Money.of(25203, 75));
      expect(
        p.principalRemaining,
        const Money.of(25203, 75),
        reason:
            'no interest means the two balances are the same number, and '
            'stay the same number',
      );
    });

    test('paying one plan touches no other', () {
      final List<InstallmentPlan> after = pay('inst_home_credit');
      for (final InstallmentPlan seeded in SeedData.installments(testToday)) {
        if (seeded.id == 'inst_home_credit') continue;
        final InstallmentPlan now = of(after, seeded.id);
        expect(now.paidInstallments, seeded.paidInstallments);
        expect(now.runningBalance, seeded.runningBalance);
      }
    });

    test('the last instalment zeroes both balances exactly', () {
      List<InstallmentPlan> list = SeedData.installments(testToday);
      for (int i = 0; i < 4; i++) {
        list = pay('inst_spaylater', list);
      }
      final InstallmentPlan p = of(list, 'inst_spaylater');
      expect(p.paidInstallments, 6);
      expect(p.isSettled, isTrue);
      expect(
        p.runningBalance,
        Money.zero,
        reason:
            'It ARRIVES at zero by subtraction now. It used to be forced '
            'there by a settlement sweep, and that sweep was not preventing a '
            'rounding crumb, it was deleting one the schedule guaranteed. '
            'Both tests that claimed to guard it ran this plan, which divides '
            'evenly and has no crumb, and both passed with the sweep removed. '
            'installment_schedule_test.dart runs the Home Credit plan, which '
            'is the only seeded one that can fail it.',
      );
      expect(p.principalRemaining, Money.zero);
      expect(p.interestRemaining, Money.zero);
    });

    // THE DIVERGENCE, asserted so it is measured rather than accidental.
    //
    // The prototype does not guard this: the generator printed
    // paidInstallments 7 on a six instalment plan, because its reducer
    // increments the counter before checking anything. "Payment 7 of 6" is
    // nonsense on a screen whose whole job is to say where you are in a
    // contract.
    test('a settled plan cannot be paid again', () {
      List<InstallmentPlan> list = SeedData.installments(testToday);
      for (int i = 0; i < 5; i++) {
        list = pay('inst_spaylater', list);
      }
      final InstallmentPlan p = of(list, 'inst_spaylater');
      expect(
        p.paidInstallments,
        6,
        reason:
            'The prototype would print 7 of 6 here. A contract with six '
            'instalments in it has six.',
      );
      expect(p.isSettled, isTrue);
    });
  });

  group('an extra payment matches the prototype', () {
    test('it comes off BOTH balances in full', () {
      final InstallmentPlan p = of(
        applyExtraPayment(
          SeedData.installments(testToday),
          'inst_home_credit',
          const Money.pesos(5000),
          today: today,
        ),
        'inst_home_credit',
      );
      expect(p.runningBalance, const Money.of(11864, 15));
      expect(
        p.principalRemaining,
        const Money.of(9291, 65),
        reason:
            'It comes off PRINCIPAL, and the balance falls by the same 5,000 '
            'because the balance is principal plus interest. On a fixed '
            'add-on plan the interest was set at signing, so prepaying '
            'finishes the plan sooner rather than reducing what is owed in '
            'interest.',
      );
      expect(
        p.interestRemaining,
        const Money.of(2572, 50),
        reason: 'contracted interest is not forgiven by a prepayment',
      );
      expect(p.extraPayments.length, 1);
      expect(p.extraPayments.single.amount, const Money.pesos(5000));
      expect(p.extraPayments.single.date, '2026-09-18');
      expect(p.extraPayments.single.note, 'Principal prepayment');
      expect(p.isSettled, isFalse);
    });

    test('paying the exact balance settles it', () {
      final InstallmentPlan p = of(
        applyExtraPayment(
          SeedData.installments(testToday),
          'inst_spaylater',
          const Money.of(6591, 20),
          today: today,
        ),
        'inst_spaylater',
      );
      expect(p.runningBalance, Money.zero);
      expect(p.isSettled, isTrue);
    });

    test('overpaying clamps at zero rather than going negative', () {
      final InstallmentPlan p = of(
        applyExtraPayment(
          SeedData.installments(testToday),
          'inst_spaylater',
          const Money.pesos(99999),
          today: today,
        ),
        'inst_spaylater',
      );
      expect(p.runningBalance, Money.zero);
      expect(p.principalRemaining, Money.zero);
      expect(p.isSettled, isTrue);
      expect(
        p.extraPayments.single.amount,
        const Money.of(6591, 20),
        reason:
            'the history records what was APPLIED, not the 99,999 offered. A '
            'plan that logs money it never credited is a plan that cannot be '
            'reconciled against a bank statement.',
      );
    });

    test('an extra payment is APPENDED, never replacing the history', () {
      final InstallmentPlan p = of(
        applyExtraPayment(
          SeedData.installments(testToday),
          'inst_bpi_sip',
          const Money.pesos(1000),
          today: today,
          note: 'Thirteenth month',
        ),
        'inst_bpi_sip',
      );
      expect(
        p.extraPayments.length,
        2,
        reason:
            'the seeded mid-year bonus prepayment must survive; a plan '
            'that forgets what you already paid extra is a plan nobody trusts',
      );
      expect(p.extraPayments.first.note, 'Mid-year bonus prepayment');
      expect(p.extraPayments.last.note, 'Thirteenth month');
    });

    test('zero and negative do nothing at all', () {
      // Compares against the SAME list that went in. This used to call
      // SeedData twice and compare the results, which passed only because the
      // seed was a const list and every reference was one object. The seed
      // is built from a clock now and hands back a new list each call, so two
      // calls are never identical and the check broke while the behaviour it
      // describes did not. Capturing the input is what it always meant.
      final List<InstallmentPlan> input = SeedData.installments(testToday);
      expect(
        identical(
          applyExtraPayment(input, 'inst_spaylater', Money.zero, today: today),
          input,
        ),
        isTrue,
      );
      expect(
        identical(
          applyExtraPayment(
            input,
            'inst_spaylater',
            const Money.pesos(-5),
            today: today,
          ),
          input,
        ),
        isTrue,
      );
    });
  });

  group('the ledger entry a payment writes', () {
    test('it is filed under a subcategory that EXISTS', () {
      final InstallmentPlan plan = of(
        SeedData.installments(testToday),
        'inst_home_credit',
      );
      final Transaction? t = installmentEntry(
        plan: plan,
        installmentNumber: 6,
        amount: nextPaymentFor(plan),
        accountId: 'acc_gcash',
        today: today,
        id: 'tx_test',
      );

      expect(t!.category, 'Debt & Loan Servicing');
      expect(t.subcategory, installmentSubcategory);
      expect(
        SeedData.categories
            .firstWhere((CategoryInfo c) => c.name == t.category)
            .subcategories,
        contains(t.subcategory),
        reason:
            'The prototype writes "Personal Loan", which is NOT in its own '
            'category list. Budgets and the Reports sub-breakdown both group '
            'by subcategory, so the money would sit perfectly in the ledger '
            'and vanish from every summary that reads it.',
      );
      expect(t.amount, Money.of(2409, 17));
      expect(t.merchant, 'Home Credit, Inverter Refrigerator (Abenson)');
      expect(t.note, contains('6 of 12'));
      expect(t.tags, contains('#installment'));
    });

    test('an extra payment is tagged apart from a scheduled one', () {
      final Transaction? t = extraPaymentEntry(
        plan: of(SeedData.installments(testToday), 'inst_home_credit'),
        amount: const Money.pesos(5000),
        accountId: 'acc_gcash',
        today: today,
        id: 'tx_test',
        note: 'Bonus',
      );
      expect(t!.amount, Money.pesos(5000));
      expect(t.tags, contains('#prepayment'));
      expect(t.note, contains('Bonus'));
    });

    test('no account means no entry', () {
      expect(
        installmentEntry(
          plan: of(SeedData.installments(testToday), 'inst_home_credit'),
          installmentNumber: 6,
          amount: const Money.of(2409, 17),
          accountId: null,
          today: today,
          id: 'tx_test',
        ),
        isNull,
      );
    });
  });

  group('the totals across every plan', () {
    test('what they cost together each month', () {
      expect(
        monthlyInstallmentLoad(SeedData.installments(testToday)),
        const Money.of(2409, 17) +
            const Money.of(2291, 25) +
            const Money.of(1647, 80),
      );
    });

    test('a settled plan takes nothing out of next month', () {
      List<InstallmentPlan> list = SeedData.installments(testToday);
      for (int i = 0; i < 4; i++) {
        list = pay('inst_spaylater', list);
      }
      expect(
        monthlyInstallmentLoad(list),
        const Money.of(2409, 17) + const Money.of(2291, 25),
        reason: 'the SPayLater plan just finished and must drop out',
      );
    });

    test('interest still to come is what a prepayment can still save', () {
      expect(
        interestStillToCome(SeedData.installments(testToday)),
        // 2,572.50 rather than 2,572.52: derived from the contract as seven
        // shares of 367.50, not from seven rounded instalments.
        const Money.of(2572, 50) + const Money.of(991, 20),
      );
    });

    test('open and settled are split, and settled is kept', () {
      List<InstallmentPlan> list = SeedData.installments(testToday);
      for (int i = 0; i < 4; i++) {
        list = pay('inst_spaylater', list);
      }
      final ({List<InstallmentPlan> open, List<InstallmentPlan> settled}) s =
          splitPlans(list);
      expect(s.open.length, 2);
      expect(s.settled.map((InstallmentPlan p) => p.id), <String>[
        'inst_spaylater',
      ]);
    });
  });

  group('how the rate is described', () {
    test('the unit is spelled out, because the number alone means nothing', () {
      expect(
        rateLabel(of(SeedData.installments(testToday), 'inst_home_credit')),
        '1.5% a month',
      );
      expect(
        rateLabel(of(SeedData.installments(testToday), 'inst_spaylater')),
        '2.95% a month',
      );
    });

    test('a genuine 0 percent says so in words', () {
      expect(
        rateLabel(of(SeedData.installments(testToday), 'inst_bpi_sip')),
        'No interest',
      );
    });

    test('a monthly rate is annualised so it can be compared', () {
      expect(
        annualisedRate(
          of(SeedData.installments(testToday), 'inst_home_credit'),
        ),
        closeTo(18, 0.001),
        reason: '1.5 a month is 18 a year, and the 1.5 is what gets quoted',
      );
      expect(
        annualisedRate(of(SeedData.installments(testToday), 'inst_spaylater')),
        closeTo(35.4, 0.001),
      );
      expect(
        annualisedRate(of(SeedData.installments(testToday), 'inst_bpi_sip')),
        isNull,
        reason: 'a fixed rate has nothing to annualise',
      );
    });
  });
}
