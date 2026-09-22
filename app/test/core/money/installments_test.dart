import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/installments.dart';
import 'package:salapify/data/seed_data.dart';
import 'package:salapify/models/models.dart';

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
      applyInstallmentPayment(from ?? SeedData.installments, id);

  group('the seed is the prototype\'s, in full', () {
    test('every plan carries its real contract, not a name and an amount', () {
      final InstallmentPlan p = of(SeedData.installments, 'inst_home_credit');
      expect(p.provider, 'Home Credit');
      expect(p.principal, 24500);
      expect(p.totalInterest, 4410);
      expect(p.totalPayable, 28910);
      expect(p.termMonths, 12);
      expect(p.maturityDate, '2027-04-18');
      expect(p.runningBalance, 16864.19);
      expect(
        p.principalRemaining,
        14291.67,
        reason:
            'This class was a four field stub until the Installments '
            'batch. The coverage audit missed it because it compared RECORD '
            'COUNTS, and three stubs count the same as three plans.',
      );
    });

    test('the three plans differ in shape, so the screen can be reviewed', () {
      final List<InstallmentPlan> all = SeedData.installments;
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
      expect(p.runningBalance, closeTo(14455.019999999999, 0.001));
      expect(
        // 12250.003333333334, not 12250. The generator's own PRINT rounded it
        // and the first version of this line copied the rounded figure, which
        // is precisely the hand-derivation the golden-vector rule exists to
        // stop. The carried third of a centavo is real: 24,500 over twelve
        // does not divide evenly, and nothing here rounds it away.
        p.principalRemaining,
        closeTo(12250.003333333334, 0.000001),
        reason:
            'The balance fell by the full 2,409.17 instalment while the '
            'principal fell by only its own 2,041.67 share. Those two moving '
            'by different amounts is the whole reason both are kept: it is '
            'how somebody can see an early payment is mostly interest.',
      );
      expect(p.isSettled, isFalse);
    });

    test('the genuine 0 percent plan moves both by the same amount', () {
      final InstallmentPlan p = of(pay('inst_bpi_sip'), 'inst_bpi_sip');
      expect(p.paidInstallments, 11);
      expect(p.runningBalance, closeTo(29786.25, 0.001));
      expect(
        p.principalRemaining,
        closeTo(29786.25, 0.001),
        reason:
            'no interest means the two balances are the same number, and '
            'stay the same number',
      );
    });

    test('paying one plan touches no other', () {
      final List<InstallmentPlan> after = pay('inst_home_credit');
      for (final InstallmentPlan seeded in SeedData.installments) {
        if (seeded.id == 'inst_home_credit') continue;
        final InstallmentPlan now = of(after, seeded.id);
        expect(now.paidInstallments, seeded.paidInstallments);
        expect(now.runningBalance, seeded.runningBalance);
      }
    });

    test('the last instalment zeroes both balances exactly', () {
      List<InstallmentPlan> list = SeedData.installments;
      for (int i = 0; i < 4; i++) {
        list = pay('inst_spaylater', list);
      }
      final InstallmentPlan p = of(list, 'inst_spaylater');
      expect(p.paidInstallments, 6);
      expect(p.isSettled, isTrue);
      expect(
        p.runningBalance,
        0,
        reason:
            'settled is forced to zero rather than left with a rounding '
            'crumb, so a finished plan never shows "₱0.03 still to go"',
      );
      expect(p.principalRemaining, 0);
      expect(p.interestRemaining, 0);
    });

    // THE DIVERGENCE, asserted so it is measured rather than accidental.
    //
    // The prototype does not guard this: the generator printed
    // paidInstallments 7 on a six instalment plan, because its reducer
    // increments the counter before checking anything. "Payment 7 of 6" is
    // nonsense on a screen whose whole job is to say where you are in a
    // contract.
    test('a settled plan cannot be paid again', () {
      List<InstallmentPlan> list = SeedData.installments;
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
          SeedData.installments,
          'inst_home_credit',
          5000,
          today: today,
        ),
        'inst_home_credit',
      );
      expect(p.runningBalance, closeTo(11864.19, 0.001));
      expect(
        p.principalRemaining,
        closeTo(9291.67, 0.001),
        reason:
            'Both drop by the whole 5,000. That is why an extra payment is '
            'worth making: it takes interest off the END of the plan rather '
            'than paying interest that was already going to be charged.',
      );
      expect(p.extraPayments.length, 1);
      expect(p.extraPayments.single.amount, 5000);
      expect(p.extraPayments.single.date, '2026-09-18');
      expect(p.extraPayments.single.note, 'Principal prepayment');
      expect(p.isSettled, isFalse);
    });

    test('paying the exact balance settles it', () {
      final InstallmentPlan p = of(
        applyExtraPayment(
          SeedData.installments,
          'inst_spaylater',
          6591.20,
          today: today,
        ),
        'inst_spaylater',
      );
      expect(p.runningBalance, 0);
      expect(p.isSettled, isTrue);
    });

    test('overpaying clamps at zero rather than going negative', () {
      final InstallmentPlan p = of(
        applyExtraPayment(
          SeedData.installments,
          'inst_spaylater',
          99999,
          today: today,
        ),
        'inst_spaylater',
      );
      expect(p.runningBalance, 0);
      expect(p.principalRemaining, 0);
      expect(p.isSettled, isTrue);
    });

    test('an extra payment is APPENDED, never replacing the history', () {
      final InstallmentPlan p = of(
        applyExtraPayment(
          SeedData.installments,
          'inst_bpi_sip',
          1000,
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
      expect(
        identical(
          applyExtraPayment(
            SeedData.installments,
            'inst_spaylater',
            0,
            today: today,
          ),
          SeedData.installments,
        ),
        isTrue,
      );
      expect(
        identical(
          applyExtraPayment(
            SeedData.installments,
            'inst_spaylater',
            -5,
            today: today,
          ),
          SeedData.installments,
        ),
        isTrue,
      );
    });
  });

  group('the ledger entry a payment writes', () {
    test('it is filed under a subcategory that EXISTS', () {
      final Transaction? t = installmentEntry(
        plan: of(SeedData.installments, 'inst_home_credit'),
        installmentNumber: 6,
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
      expect(t.amount, 2409.17);
      expect(t.merchant, 'Home Credit, Inverter Refrigerator (Abenson)');
      expect(t.note, contains('6 of 12'));
      expect(t.tags, contains('#installment'));
    });

    test('an extra payment is tagged apart from a scheduled one', () {
      final Transaction? t = extraPaymentEntry(
        plan: of(SeedData.installments, 'inst_home_credit'),
        amount: 5000,
        accountId: 'acc_gcash',
        today: today,
        id: 'tx_test',
        note: 'Bonus',
      );
      expect(t!.amount, 5000);
      expect(t.tags, contains('#prepayment'));
      expect(t.note, contains('Bonus'));
    });

    test('no account means no entry', () {
      expect(
        installmentEntry(
          plan: of(SeedData.installments, 'inst_home_credit'),
          installmentNumber: 6,
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
        monthlyInstallmentLoad(SeedData.installments),
        closeTo(2409.17 + 2291.25 + 1647.80, 0.001),
      );
    });

    test('a settled plan takes nothing out of next month', () {
      List<InstallmentPlan> list = SeedData.installments;
      for (int i = 0; i < 4; i++) {
        list = pay('inst_spaylater', list);
      }
      expect(
        monthlyInstallmentLoad(list),
        closeTo(2409.17 + 2291.25, 0.001),
        reason: 'the SPayLater plan just finished and must drop out',
      );
    });

    test('interest still to come is what a prepayment can still save', () {
      expect(
        interestStillToCome(SeedData.installments),
        closeTo(2572.52 + 0 + 991.20, 0.001),
      );
    });

    test('open and settled are split, and settled is kept', () {
      List<InstallmentPlan> list = SeedData.installments;
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
        rateLabel(of(SeedData.installments, 'inst_home_credit')),
        '1.5% a month',
      );
      expect(
        rateLabel(of(SeedData.installments, 'inst_spaylater')),
        '2.95% a month',
      );
    });

    test('a genuine 0 percent says so in words', () {
      expect(
        rateLabel(of(SeedData.installments, 'inst_bpi_sip')),
        'No interest',
      );
    });

    test('a monthly rate is annualised so it can be compared', () {
      expect(
        annualisedRate(of(SeedData.installments, 'inst_home_credit')),
        closeTo(18, 0.001),
        reason: '1.5 a month is 18 a year, and the 1.5 is what gets quoted',
      );
      expect(
        annualisedRate(of(SeedData.installments, 'inst_spaylater')),
        closeTo(35.4, 0.001),
      );
      expect(
        annualisedRate(of(SeedData.installments, 'inst_bpi_sip')),
        isNull,
        reason: 'a fixed rate has nothing to annualise',
      );
    });
  });
}
