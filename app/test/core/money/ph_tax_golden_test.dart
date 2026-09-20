import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/ph_tax.dart';

/// Golden vectors for the Philippine tax port.
///
/// Produced by running src/utils/philippineFinances.ts itself under bun, not by
/// working the brackets out by hand and not by reading the Dart back. Where a
/// figure carries floating point residue (1030.0004999999996) it is asserted
/// with a tight tolerance rather than tidied up, because tidying it would hide
/// a real divergence.
void main() {
  const double eps = 1e-6;

  group('mandatory contributions', () {
    test('a 30,000 monthly salary', () {
      final EmployeeTaxCalculation r = calculateEmployeeTaxDeductions(
        inputSalary: 30000,
      );
      expect(r.sss, 1500);
      expect(r.philhealth, 750);
      expect(r.pagibig, 200);
      expect(r.totalContributions, 2450);
    });

    test('SSS caps at a 35,000 salary credit, so it stops growing', () {
      final EmployeeTaxCalculation mid = calculateEmployeeTaxDeductions(
        inputSalary: 65000,
      );
      final EmployeeTaxCalculation high = calculateEmployeeTaxDeductions(
        inputSalary: 700000,
      );
      expect(mid.sss, 1750);
      expect(high.sss, 1750);
    });

    test('PhilHealth caps at 2,500 and Pag-IBIG at 200', () {
      final EmployeeTaxCalculation r = calculateEmployeeTaxDeductions(
        inputSalary: 200000,
      );
      expect(r.philhealth, 2500);
      expect(r.pagibig, 200);
    });

    test('a low salary is floored, not taken to zero', () {
      final EmployeeTaxCalculation r = calculateEmployeeTaxDeductions(
        inputSalary: 12000,
      );
      expect(r.sss, 600);
      expect(r.philhealth, 300);
      expect(r.pagibig, 200);
      expect(r.totalContributions, 1100);
    });

    test('and the SSS floor is actually reached, which 12,000 never was', () {
      // The test above is named for the floor and does not touch it: at
      // 12,000 the salary credit is 12,000, well clear of both the old
      // 4,000 floor and the new 5,000 one. It has passed for months while
      // testing nothing about flooring.
      final EmployeeTaxCalculation r = calculateEmployeeTaxDeductions(
        inputSalary: 4000,
      );
      expect(r.sss, 250, reason: 'the MSC should be floored at 5,000');
      expect(r.philhealth, 250);
      expect(r.pagibig, 80);
      expect(r.totalContributions, 580);
    });

    test('contributions are charged on the BRACKET, not the exact salary', () {
      // The 500-peso steps, at the two edges where a half-rounding mistake
      // shows up. Each bracket is centred on its MSC, so the range for MSC M
      // is M-250 to M+249.99, and the rule is a half-UP round. Dart's own
      // .round() is not half-up, and the gap is 12.50 a month forever.
      for (final ({double salary, double sss}) v
          in <({double salary, double sss})>[
            (salary: 5249.99, sss: 250),
            (salary: 5250, sss: 275),
            (salary: 12249, sss: 600),
            (salary: 12250, sss: 625),
            (salary: 34749, sss: 1725),
            (salary: 34750, sss: 1750),
          ]) {
        expect(
          calculateEmployeeTaxDeductions(inputSalary: v.salary).sss,
          v.sss,
          reason: 'a salary of ${v.salary} landed in the wrong bracket',
        );
      }
    });

    test('a 25,000 and a 40,000 salary, end to end', () {
      // The two the founder was shown when this defect was reported. Before
      // the fix the app said 22,717.50 and 34,751.67, both higher than the
      // payslip, which is the direction that costs trust.
      final EmployeeTaxCalculation low = calculateEmployeeTaxDeductions(
        inputSalary: 25000,
      );
      expect(low.sss, 1250);
      expect(low.totalContributions, 2075);
      expect(low.taxableIncome, 22925);
      expect(low.withholdingTax, closeTo(313.7505, 1e-6));
      expect(low.netTakeHome, 22611);

      final EmployeeTaxCalculation high = calculateEmployeeTaxDeductions(
        inputSalary: 40000,
      );
      expect(high.sss, 1750, reason: 'the MSC should cap at 35,000');
      expect(high.totalContributions, 2950);
      expect(high.taxableIncome, 37050);
      expect(high.withholdingTax, closeTo(2618.334, 1e-6));
      expect(high.netTakeHome, 34432);
    });
  });

  group('withholding tax across the brackets', () {
    void check(
      String label,
      double salary,
      double taxable,
      double withheld,
      double net,
    ) {
      test(label, () {
        final EmployeeTaxCalculation r = calculateEmployeeTaxDeductions(
          inputSalary: salary,
        );
        expect(r.taxableIncome, closeTo(taxable, eps));
        expect(r.withholdingTax, closeTo(withheld, eps));
        expect(r.netTakeHome, closeTo(net, eps));
      });
    }

    // EVERY FIGURE IN THIS GROUP MOVED when SSS went to the 2025 schedule,
    // and every one moved the same way: a bigger contribution means a
    // smaller taxable income, a smaller tax, and a smaller take-home. The
    // tax falls and the net falls with it, because the contribution rose by
    // more than the tax fell. That is the correct direction and it will look
    // like a regression to anybody who does not know why.
    check('15 percent band, 30,000', 30000, 27550, 1007.5004999999996, 26542);
    check('20 percent band, 65,000', 65000, 61425, 7493.334, 53932);
    check(
      '25 percent band, 200,000',
      200000,
      195550,
      42206.668999999994,
      153343,
    );
    check('35 percent band, 700,000', 700000, 695550, 193650.8355, 501899);

    test('below the 20,833.33 threshold nothing is withheld', () {
      final EmployeeTaxCalculation r = calculateEmployeeTaxDeductions(
        inputSalary: 12000,
      );
      expect(r.withholdingTax, 0);
      expect(r.netTakeHome, 10900);
    });
  });

  group('pay frequency', () {
    test(
      'semi-monthly, bi-weekly and annual land on the same monthly salary',
      () {
        final EmployeeTaxCalculation semi = calculateEmployeeTaxDeductions(
          inputSalary: 16250,
          inputFrequency: PayFrequency.semiMonthly,
        );
        final EmployeeTaxCalculation fortnight = calculateEmployeeTaxDeductions(
          inputSalary: 15000,
          inputFrequency: PayFrequency.biWeekly,
        );

        // 16,250 twice a month and 15,000 every fortnight are both 32,500 a
        // month, so every downstream figure must agree.
        expect(semi.monthlySalary, 32500);
        expect(fortnight.monthlySalary, closeTo(32500, eps));
        expect(semi.philhealth, 813);
        expect(fortnight.philhealth, 813);
        expect(semi.taxableIncome, closeTo(29862, eps));
        expect(fortnight.taxableIncome, closeTo(29862, eps));
        expect(semi.withholdingTax, closeTo(1354.3004999999996, eps));
        expect(semi.netTakeHome, 28508);
        expect(semi.semiMonthlyTakeHome, 14254);
      },
    );

    test('an annual figure divides down to the same monthly result', () {
      final EmployeeTaxCalculation annual = calculateEmployeeTaxDeductions(
        inputSalary: 780000,
        inputFrequency: PayFrequency.annually,
      );
      final EmployeeTaxCalculation monthly = calculateEmployeeTaxDeductions(
        inputSalary: 65000,
      );
      expect(annual.monthlySalary, monthly.monthlySalary);
      expect(annual.netTakeHome, monthly.netTakeHome);
      expect(annual.withholdingTax, closeTo(monthly.withholdingTax, eps));
    });
  });

  group('allowances, overtime and night differential', () {
    test('taxable extras raise the tax, non-taxable ones do not', () {
      final EmployeeTaxCalculation r = calculateEmployeeTaxDeductions(
        inputSalary: 45000,
        taxableAllowance: 5000,
        nonTaxableAllowance: 2000,
        overtime: 3000,
        nightDifferential: 1500,
        monthsWorked: 8,
      );
      expect(r.monthlySalary, 45000);
      expect(r.taxableIncome, closeTo(51425, eps));
      expect(r.withholdingTax, closeTo(5493.334, eps));
      expect(r.netTakeHome, 47932);

      // Contributions read the BASE salary only, never the extras.
      expect(r.philhealth, 1125);
      expect(r.totalContributions, 3075);

      // The non-taxable 2,000 is in gross but not in taxable income.
      expect(
        r.grossMonthlyIncome - r.taxableIncome - r.totalContributions,
        closeTo(2000, eps),
      );
    });

    test(
      'a zero salary returns a zeroed result rather than dividing by it',
      () {
        final EmployeeTaxCalculation r = calculateEmployeeTaxDeductions(
          inputSalary: 0,
        );
        expect(r.monthlySalary, 0);
        expect(r.totalContributions, 0);
        expect(r.netTakeHome, 0);
        expect(r.isTaxExempt13th, isTrue);
      },
    );
  });

  group('13th month', () {
    test('the first 90,000 is exempt and the excess is taxed', () {
      final EmployeeTaxCalculation low = calculateEmployeeTaxDeductions(
        inputSalary: 65000,
      );
      expect(low.thirteenthMonthGross, 65000);
      expect(low.thirteenthMonthTax, 0);
      expect(low.isTaxExempt13th, isTrue);

      final EmployeeTaxCalculation high = calculateEmployeeTaxDeductions(
        inputSalary: 200000,
      );
      expect(high.thirteenthMonthGross, 200000);
      expect(high.thirteenthMonthTaxable, 110000);
      expect(high.thirteenthMonthTax, 22000);
      expect(high.isTaxExempt13th, isFalse);
    });

    test('a part year is prorated by months worked', () {
      final ThirteenthMonthPlan half = calculate13thMonthPay(
        basicMonthlySalary: 30000,
        monthsWorked: 6,
      );
      expect(half.calculatedGrossAmount, 15000);
      expect(half.estimatedWithholdingTax, 0);
      expect(half.net13thMonthPay, 15000);
    });

    test('months worked is clamped to 0 and 12 at both ends', () {
      expect(
        calculate13thMonthPay(
          basicMonthlySalary: 30000,
          monthsWorked: 0,
        ).calculatedGrossAmount,
        0,
      );
      expect(
        calculate13thMonthPay(
          basicMonthlySalary: 30000,
          monthsWorked: 18,
        ).calculatedGrossAmount,
        30000,
      );
    });

    test('above the ceiling, only the excess is withheld', () {
      final ThirteenthMonthPlan plan = calculate13thMonthPay(
        basicMonthlySalary: 120000,
      );
      expect(plan.calculatedGrossAmount, 120000);
      expect(plan.taxExemptAmount, 90000);
      expect(plan.taxableExcessAmount, 30000);
      expect(plan.estimatedWithholdingTax, 6000);
      expect(plan.net13thMonthPay, 114000);
    });

    test(
      'the allocation blueprint splits the net into five and sums to it',
      () {
        final ThirteenthMonthPlan plan = calculate13thMonthPay(
          basicMonthlySalary: 120000,
        );
        expect(plan.allocations.length, 5);
        expect(
          plan.allocations.fold<int>(
            0,
            (int s, ThirteenthMonthAllocation a) => s + a.percentage,
          ),
          100,
        );
        final double total = plan.allocations.fold<double>(
          0,
          (double s, ThirteenthMonthAllocation a) => s + a.targetAmount,
        );
        expect(total, closeTo(plan.net13thMonthPay, 2));
      },
    );
  });

  group('freelance, 8 percent against graduated', () {
    test('the 8 percent route deducts 250,000 first', () {
      final FreelanceTaxCalculation r = calculateFreelanceTax(
        annualGrossIncome: 1200000,
      );
      expect(r.taxFreeAllowance, 250000);
      expect(r.taxableBase, 950000);
      expect(r.estimatedTaxDue, 76000);
      expect(r.effectiveTaxRate, closeTo(6.333333333333334, eps));
      expect(r.monthlyTaxProvision, closeTo(6333.333333333333, eps));
    });

    test('the graduated route carries its OSD and its percentage tax', () {
      // IT USED TO TAX THE WHOLE GROSS with no deductions and no percentage
      // tax, which no filer does either way round. The 40% Optional Standard
      // Deduction is what an individual without itemised receipts claims,
      // and the 3% percentage tax is the OTHER tax the 8% option replaces.
      // Omitting it compared one tax against two and overstated the saving
      // from electing 8% by about 2.7x, on the screen that triggers a
      // choice that cannot be reversed for twelve months.
      final FreelanceTaxCalculation r = calculateFreelanceTax(
        annualGrossIncome: 1200000,
        taxOption: FreelanceTaxOption.graduatedRates,
      );
      expect(r.taxFreeAllowance, 480000, reason: '40% of 1,200,000');
      expect(r.taxableBase, 720000);
      expect(r.estimatedTaxDue, 86500);
      expect(r.percentageTax, 36000);
      expect(r.totalTaxDue, 122500);
    });

    test('the advertised saving is the honest one', () {
      // 122,500 against 76,000 is 46,500. The app used to say 126,500.
      final FreelanceTaxCalculation git = calculateFreelanceTax(
        annualGrossIncome: 1200000,
      );
      final FreelanceTaxCalculation grad = calculateFreelanceTax(
        annualGrossIncome: 1200000,
        taxOption: FreelanceTaxOption.graduatedRates,
      );
      expect(grad.totalTaxDue - git.totalTaxDue, 46500);
    });

    test(
      'MIXED income gets no 250,000, because the salary already used it',
      () {
        // The zero bracket of the graduated table is applied to the
        // compensation side. Granting it again on the business side is a flat
        // 20,000 understatement, every year, for anybody with a job and a
        // sideline.
        final FreelanceTaxCalculation mixed = calculateFreelanceTax(
          annualGrossIncome: 600000,
          compensationIncome: 500000,
        );
        expect(mixed.taxFreeAllowance, 0);
        expect(mixed.taxableBase, 600000);
        expect(mixed.estimatedTaxDue, 48000);

        final FreelanceTaxCalculation pure = calculateFreelanceTax(
          annualGrossIncome: 600000,
        );
        expect(pure.estimatedTaxDue, 28000);
        expect(
          mixed.estimatedTaxDue - pure.estimatedTaxDue,
          20000,
          reason: 'the gap should be exactly 250,000 x 8%',
        );
      },
    );

    test('above the VAT threshold the 8 percent is REFUSED, not compared', () {
      // Not a worse choice. Not a lawful one. Offering it with a warning is
      // offering an unlawful filing position with a caveat attached, and
      // caveats get skipped.
      final FreelanceTaxCalculation r = calculateFreelanceTax(
        annualGrossIncome: 3000001,
      );
      expect(r.eightPercentAvailable, isFalse);
      expect(r.taxOption, FreelanceTaxOption.graduatedRates);
      expect(r.unavailableReason, isNotNull);

      // And at EXACTLY the threshold it is still available. The test is
      // strict, so this is > and never >=.
      expect(
        calculateFreelanceTax(annualGrossIncome: 3000000).eightPercentAvailable,
        isTrue,
      );
    });

    test('a VAT registered person is refused at any income', () {
      final FreelanceTaxCalculation r = calculateFreelanceTax(
        annualGrossIncome: 500000,
        vatRegistered: true,
      );
      expect(r.eightPercentAvailable, isFalse);
      expect(r.taxOption, FreelanceTaxOption.graduatedRates);
    });

    test('every graduated bracket edge', () {
      expect(annualGraduatedTax(250000), 0);
      expect(annualGraduatedTax(400000), 22500);
      expect(annualGraduatedTax(800000), 102500);
      expect(annualGraduatedTax(2000000), 402500);
      expect(annualGraduatedTax(8000000), 2202500);
      expect(annualGraduatedTax(12000000), 3602500);
    });

    test('at 250,000 the 8 percent route owes nothing at all', () {
      final FreelanceTaxCalculation r = calculateFreelanceTax(
        annualGrossIncome: 250000,
      );
      expect(r.taxableBase, 0);
      expect(r.estimatedTaxDue, 0);
      expect(r.effectiveTaxRate, 0);
    });

    test(
      '8 percent beats graduated at this income, which is the whole point',
      () {
        final double git = calculateFreelanceTax(
          annualGrossIncome: 1200000,
        ).totalTaxDue;
        final double graduated = calculateFreelanceTax(
          annualGrossIncome: 1200000,
          taxOption: FreelanceTaxOption.graduatedRates,
        ).totalTaxDue;
        expect(git, lessThan(graduated));
      },
    );

    test('the recommended buffer is 3 months on 8 percent, 4 on graduated', () {
      expect(
        calculateFreelanceTax(
          annualGrossIncome: 1200000,
        ).leanMonthsBufferRecommended,
        300000,
      );
      expect(
        calculateFreelanceTax(
          annualGrossIncome: 1200000,
          taxOption: FreelanceTaxOption.graduatedRates,
        ).leanMonthsBufferRecommended,
        400000,
      );
    });
  });
}
