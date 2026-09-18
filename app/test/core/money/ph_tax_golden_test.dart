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
      expect(r.sss, 1350);
      expect(r.philhealth, 750);
      expect(r.pagibig, 200);
      expect(r.totalContributions, 2300);
    });

    test('SSS caps at a 30,000 salary credit, so it stops growing', () {
      final EmployeeTaxCalculation mid = calculateEmployeeTaxDeductions(
        inputSalary: 65000,
      );
      final EmployeeTaxCalculation high = calculateEmployeeTaxDeductions(
        inputSalary: 700000,
      );
      expect(mid.sss, 1350);
      expect(high.sss, 1350);
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
      expect(r.sss, 540);
      expect(r.philhealth, 300);
      expect(r.pagibig, 200);
      expect(r.totalContributions, 1040);
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

    check('15 percent band, 30,000', 30000, 27700, 1030.0004999999996, 26670);
    check('20 percent band, 65,000', 65000, 61825, 7573.334, 54252);
    check(
      '25 percent band, 200,000',
      200000,
      195950,
      42326.668999999994,
      153623,
    );
    check('35 percent band, 700,000', 700000, 695950, 193790.8355, 502159);

    test('below the 20,833.33 threshold nothing is withheld', () {
      final EmployeeTaxCalculation r = calculateEmployeeTaxDeductions(
        inputSalary: 12000,
      );
      expect(r.withholdingTax, 0);
      expect(r.netTakeHome, 10960);
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
        expect(semi.taxableIncome, closeTo(30137, eps));
        expect(fortnight.taxableIncome, closeTo(30137, eps));
        expect(semi.withholdingTax, closeTo(1395.5504999999996, eps));
        expect(semi.netTakeHome, 28741);
        expect(semi.semiMonthlyTakeHome, 14371);
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
      expect(r.taxableIncome, closeTo(51825, eps));
      expect(r.withholdingTax, closeTo(5573.334, eps));
      expect(r.netTakeHome, 48252);

      // Contributions read the BASE salary only, never the extras.
      expect(r.philhealth, 1125);
      expect(r.totalContributions, 2675);

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
      expect(r.allowableDeduction, 250000);
      expect(r.taxableBase, 950000);
      expect(r.estimatedTaxDue, 76000);
      expect(r.effectiveTaxRate, closeTo(6.333333333333334, eps));
      expect(r.monthlyTaxProvision, closeTo(6333.333333333333, eps));
    });

    test('the graduated route taxes the whole gross', () {
      final FreelanceTaxCalculation r = calculateFreelanceTax(
        annualGrossIncome: 1200000,
        taxOption: FreelanceTaxOption.graduatedRates,
      );
      expect(r.allowableDeduction, 0);
      expect(r.taxableBase, 1200000);
      expect(r.estimatedTaxDue, 202500);
      expect(r.effectiveTaxRate, closeTo(16.875, eps));
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
        ).estimatedTaxDue;
        final double graduated = calculateFreelanceTax(
          annualGrossIncome: 1200000,
          taxOption: FreelanceTaxOption.graduatedRates,
        ).estimatedTaxDue;
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
