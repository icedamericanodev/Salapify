import 'dart:math' as math;

import 'format.dart';
import 'js_round.dart';

/// Philippine payroll and income tax, ported from src/utils/philippineFinances.ts.
///
/// Every rate, floor, ceiling and bracket below is the prototype's. Nothing was
/// rounded differently, re-derived from the BIR tables, or "corrected" on the
/// way across: if a figure here is wrong it is wrong in the prototype too, and
/// that is a product question rather than a porting one.

enum PayFrequency { semiMonthly, biWeekly, monthly, annually }

/// How many of a period fit in a month. The prototype applies this to the base
/// salary AND to allowances, overtime and night differential, on the stated
/// assumption that a person enters them the way they receive them.
double _frequencyMultiplier(PayFrequency f) {
  switch (f) {
    case PayFrequency.semiMonthly:
      return 2;
    case PayFrequency.biWeekly:
      return 26 / 12;
    case PayFrequency.annually:
      return 1 / 12;
    case PayFrequency.monthly:
      return 1;
  }
}

class EmployeeTaxCalculation {
  const EmployeeTaxCalculation({
    required this.inputFrequency,
    required this.inputSalary,
    required this.grossMonthlyIncome,
    required this.monthlySalary,
    required this.monthsWorked,
    required this.sss,
    required this.sssEmployer,
    required this.philhealth,
    required this.philhealthEmployer,
    required this.pagibig,
    required this.pagibigEmployer,
    required this.totalContributions,
    required this.taxableIncome,
    required this.withholdingTax,
    required this.netTakeHome,
    required this.semiMonthlyTakeHome,
    required this.annualGrossSalary,
    required this.annualTotalTax,
    required this.annualNetTakeHome,
    required this.thirteenthMonthGross,
    required this.thirteenthMonthTaxable,
    required this.thirteenthMonthTax,
    required this.thirteenthMonthNet,
    required this.isTaxExempt13th,
  });

  final PayFrequency inputFrequency;
  final double inputSalary;
  final double grossMonthlyIncome;
  final double monthlySalary;
  final int monthsWorked;

  final double sss;
  final double sssEmployer;
  final double philhealth;
  final double philhealthEmployer;
  final double pagibig;
  final double pagibigEmployer;
  final double totalContributions;

  final double taxableIncome;
  final double withholdingTax;
  final double netTakeHome;
  final double semiMonthlyTakeHome;

  final double annualGrossSalary;
  final double annualTotalTax;
  final double annualNetTakeHome;

  final double thirteenthMonthGross;
  final double thirteenthMonthTaxable;
  final double thirteenthMonthTax;
  final double thirteenthMonthNet;
  final bool isTaxExempt13th;
}

/// BIR TRAIN law graduated MONTHLY withholding, 2023 onwards.
///
/// The bracket edges are the prototype's own decimals (20833.33 and friends),
/// not the exact twelfths of the annual table. Rounding them to something
/// tidier moves real pesos at the boundary, so they are copied verbatim.
double monthlyWithholdingTax(double taxableIncome) {
  if (taxableIncome <= 20833.33) return 0;
  if (taxableIncome <= 33333.33) return (taxableIncome - 20833.33) * 0.15;
  if (taxableIncome <= 66666.67) {
    return 1875.00 + (taxableIncome - 33333.33) * 0.20;
  }
  if (taxableIncome <= 166666.67) {
    return 8541.67 + (taxableIncome - 66666.67) * 0.25;
  }
  if (taxableIncome <= 666666.67) {
    return 33541.67 + (taxableIncome - 166666.67) * 0.30;
  }
  return 183541.67 + (taxableIncome - 666666.67) * 0.35;
}

EmployeeTaxCalculation calculateEmployeeTaxDeductions({
  required double inputSalary,
  PayFrequency inputFrequency = PayFrequency.monthly,
  double taxableAllowance = 0,
  double nonTaxableAllowance = 0,
  double overtime = 0,
  double nightDifferential = 0,
  int monthsWorked = 12,
}) {
  double monthlyBaseSalary;
  switch (inputFrequency) {
    case PayFrequency.semiMonthly:
      monthlyBaseSalary = inputSalary * 2;
      break;
    case PayFrequency.biWeekly:
      monthlyBaseSalary = (inputSalary * 26) / 12;
      break;
    case PayFrequency.annually:
      monthlyBaseSalary = inputSalary / 12;
      break;
    case PayFrequency.monthly:
      monthlyBaseSalary = inputSalary;
      break;
  }

  final double m = _frequencyMultiplier(inputFrequency);
  final double monthlyTaxableAllowance = taxableAllowance * m;
  final double monthlyNonTaxableAllowance = nonTaxableAllowance * m;
  final double monthlyOvertime = overtime * m;
  final double monthlyNightDiff = nightDifferential * m;

  if (monthlyBaseSalary <= 0) {
    return EmployeeTaxCalculation(
      inputFrequency: inputFrequency,
      inputSalary: inputSalary,
      grossMonthlyIncome: 0,
      monthlySalary: 0,
      monthsWorked: monthsWorked,
      sss: 0,
      sssEmployer: 0,
      philhealth: 0,
      philhealthEmployer: 0,
      pagibig: 0,
      pagibigEmployer: 0,
      totalContributions: 0,
      taxableIncome: 0,
      withholdingTax: 0,
      netTakeHome: 0,
      semiMonthlyTakeHome: 0,
      annualGrossSalary: 0,
      annualTotalTax: 0,
      annualNetTakeHome: 0,
      thirteenthMonthGross: 0,
      thirteenthMonthTaxable: 0,
      thirteenthMonthTax: 0,
      thirteenthMonthNet: 0,
      isTaxExempt13th: true,
    );
  }

  // 1. SSS. Employee share is 5% of the MONTHLY SALARY CREDIT, employer 10%,
  //    for a total of 15% under the RA 11199 schedule that reached its final
  //    step in January 2025.
  //
  //    THIS WAS 4.5 AND 9.5 ON AN MSC OF 4,000 TO 30,000, which is the 2023
  //    to 2024 step of the same schedule, and it was wrong in two ways at
  //    once. The rates were a step behind, and the MSC was taken as raw
  //    basic pay with no bracketing at all.
  //
  //    Both errors pushed the same way: the app showed MORE take-home than
  //    the payslip, by about 106 pesos a month at a 25,000 salary and 320 at
  //    40,000. That is the worst direction for a figure somebody checks
  //    against their real sweldo, because the app is the optimistic one.
  //
  //    Contributions are charged on the BRACKET, not on the exact salary.
  //    Brackets are 500-peso steps across the range, each centred on its
  //    MSC, so the compensation range for MSC M is M-250 to M+249.99. That
  //    makes the rule a half-up round to the nearest 500, then a clamp.
  //    jsRound is (v + 0.5).floor(), which IS half-up; Dart's own .round()
  //    is not, and the difference shows up at every bracket edge.
  //
  //    The 15% splits internally between regular SSS and WISP above an MSC
  //    of 20,000, and the member's own share stays a flat 5% of the whole
  //    MSC either way. It is one number to the employee and is modelled as
  //    one number here.
  //
  //    EC is deliberately absent. It is employer-borne under PD 626 and
  //    never appears on a payslip as a deduction, so it has no place in a
  //    take-home figure.
  final double sssMsc = math.min(
    35000,
    math.max(5000, jsRound(monthlyBaseSalary / 500) * 500),
  );
  final double sss = jsRound(sssMsc * 0.05).toDouble();
  final double sssEmployer = jsRound(sssMsc * 0.10).toDouble();

  // 2. PhilHealth. 5% premium split evenly, so 2.5% each, on a base floored at
  //    10,000 and capped at 100,000.
  final double philhealthBase = math.min(
    100000,
    math.max(10000, monthlyBaseSalary),
  );
  final double philhealth = jsRound(philhealthBase * 0.025).toDouble();
  final double philhealthEmployer = philhealth;

  // 3. Pag-IBIG. 2% of a fund salary capped at 10,000, so 200 pesos at most.
  final double pagibigBase = math.min(10000, math.max(1500, monthlyBaseSalary));
  final double pagibig = jsRound(pagibigBase * 0.02).toDouble();
  final double pagibigEmployer = pagibig;

  final double totalContributions = sss + philhealth + pagibig;

  final double grossTaxable =
      monthlyBaseSalary +
      monthlyTaxableAllowance +
      monthlyOvertime +
      monthlyNightDiff;
  final double taxableIncome = math.max(0, grossTaxable - totalContributions);
  final double withholdingTax = monthlyWithholdingTax(taxableIncome);

  final double grossMonthlyIncome =
      monthlyBaseSalary +
      monthlyTaxableAllowance +
      monthlyNonTaxableAllowance +
      monthlyOvertime +
      monthlyNightDiff;
  final double netTakeHome = math.max(
    0,
    jsRound(
      grossMonthlyIncome - totalContributions - withholdingTax,
    ).toDouble(),
  );
  final double semiMonthlyTakeHome = jsRound(netTakeHome / 2).toDouble();

  // 13th month, from BASE salary only, with the 90,000 TRAIN exemption. The
  // 20% on the excess is the prototype's stated approximation, not a bracket
  // lookup, and it is kept as such rather than quietly made more precise.
  final int safeMonths = math.min(12, math.max(1, monthsWorked));
  final double thirteenthMonthGross = jsRound(
    (monthlyBaseSalary * safeMonths) / 12,
  ).toDouble();
  final double thirteenthMonthTaxable = math.max(
    0,
    thirteenthMonthGross - 90000,
  );
  final double thirteenthMonthTax = thirteenthMonthTaxable > 0
      ? jsRound(thirteenthMonthTaxable * 0.20).toDouble()
      : 0;
  final double thirteenthMonthNet = thirteenthMonthGross - thirteenthMonthTax;

  return EmployeeTaxCalculation(
    inputFrequency: inputFrequency,
    inputSalary: inputSalary,
    grossMonthlyIncome: grossMonthlyIncome,
    monthlySalary: monthlyBaseSalary,
    monthsWorked: monthsWorked,
    sss: sss,
    sssEmployer: sssEmployer,
    philhealth: philhealth,
    philhealthEmployer: philhealthEmployer,
    pagibig: pagibig,
    pagibigEmployer: pagibigEmployer,
    totalContributions: totalContributions,
    taxableIncome: taxableIncome,
    withholdingTax: withholdingTax,
    netTakeHome: netTakeHome,
    semiMonthlyTakeHome: semiMonthlyTakeHome,
    annualGrossSalary: grossMonthlyIncome * 12,
    annualTotalTax: jsRound(
      withholdingTax * 12 + thirteenthMonthTax,
    ).toDouble(),
    annualNetTakeHome: jsRound(
      netTakeHome * 12 + thirteenthMonthNet,
    ).toDouble(),
    thirteenthMonthGross: thirteenthMonthGross,
    thirteenthMonthTaxable: thirteenthMonthTaxable,
    thirteenthMonthTax: thirteenthMonthTax,
    thirteenthMonthNet: thirteenthMonthNet,
    isTaxExempt13th: thirteenthMonthGross <= 90000,
  );
}

/// One slice of the 13th month blueprint.
class ThirteenthMonthAllocation {
  const ThirteenthMonthAllocation({
    required this.id,
    required this.category,
    required this.name,
    required this.percentage,
    required this.targetAmount,
    required this.note,
  });

  final String id;
  final String category;
  final String name;
  final int percentage;
  final double targetAmount;
  final String note;
}

class ThirteenthMonthPlan {
  const ThirteenthMonthPlan({
    required this.basicMonthlySalary,
    required this.monthsWorkedTotal,
    required this.calculatedGrossAmount,
    required this.taxExemptThreshold,
    required this.taxExemptAmount,
    required this.taxableExcessAmount,
    required this.estimatedWithholdingTax,
    required this.net13thMonthPay,
    required this.allocations,
  });

  final double basicMonthlySalary;
  final int monthsWorkedTotal;
  final double calculatedGrossAmount;
  final double taxExemptThreshold;
  final double taxExemptAmount;
  final double taxableExcessAmount;
  final double estimatedWithholdingTax;
  final double net13thMonthPay;
  final List<ThirteenthMonthAllocation> allocations;
}

/// 13th month pay, PD 851 with the TRAIN law's 90,000 exemption.
///
/// Note it does NOT round the gross, unlike the 13th month figure inside
/// calculateEmployeeTaxDeductions, which does. That inconsistency is the
/// prototype's and is preserved: making them agree here would change a number
/// on a screen without anyone deciding to.
ThirteenthMonthPlan calculate13thMonthPay({
  required double basicMonthlySalary,
  int monthsWorked = 12,
  double marginalTaxRate = 0.20,
}) {
  final int safeMonths = math.min(12, math.max(0, monthsWorked));
  final double calculatedGross = (basicMonthlySalary * safeMonths) / 12;
  const double taxExemptThreshold = 90000;

  final double taxExemptAmount = math.min(calculatedGross, taxExemptThreshold);
  final double taxableExcessAmount = math.max(
    0,
    calculatedGross - taxExemptThreshold,
  );
  final double estimatedWithholdingTax = taxableExcessAmount * marginalTaxRate;
  final double net = calculatedGross - estimatedWithholdingTax;

  return ThirteenthMonthPlan(
    basicMonthlySalary: basicMonthlySalary,
    monthsWorkedTotal: safeMonths,
    calculatedGrossAmount: calculatedGross,
    taxExemptThreshold: taxExemptThreshold,
    taxExemptAmount: taxExemptAmount,
    taxableExcessAmount: taxableExcessAmount,
    estimatedWithholdingTax: estimatedWithholdingTax,
    net13thMonthPay: net,
    allocations: <ThirteenthMonthAllocation>[
      ThirteenthMonthAllocation(
        id: 'alloc-1',
        category: 'Ipon & Pag-IBIG MP2',
        name: 'Pag-IBIG MP2 / High-Yield Savings Boost',
        percentage: 35,
        targetAmount: jsRound(net * 0.35).toDouble(),
        note: 'Compounding wealth builder for long-term goals',
      ),
      ThirteenthMonthAllocation(
        id: 'alloc-2',
        category: 'Debt & Loan Servicing',
        name: 'Debt & Installment Accelerator (Utang clearance)',
        percentage: 25,
        targetAmount: jsRound(net * 0.25).toDouble(),
        note: 'Knock down high-interest credit or gadget balances',
      ),
      ThirteenthMonthAllocation(
        id: 'alloc-3',
        category: 'Family Support & Remittance',
        name: 'Family Pamasko & Sweldo Padala',
        percentage: 20,
        targetAmount: jsRound(net * 0.20).toDouble(),
        note: 'Gifts and support for parents & relatives in the province',
      ),
      ThirteenthMonthAllocation(
        id: 'alloc-4',
        category: 'Food & Dining',
        name: 'Christmas Noche Buena & Holiday Celebrations',
        percentage: 10,
        targetAmount: jsRound(net * 0.10).toDouble(),
        note: 'Family holiday feast and festivities',
      ),
      ThirteenthMonthAllocation(
        id: 'alloc-5',
        category: 'Shopping & Personal',
        name: 'Guilt-free Self Reward & Year-End Treat',
        percentage: 10,
        targetAmount: jsRound(net * 0.10).toDouble(),
        note: 'Well-deserved reward for the entire year of hard work',
      ),
    ],
  );
}

enum FreelanceTaxOption { eightPercentGit, graduatedRates }

/// The gross above which the 8% option is not available.
///
/// One named constant rather than a literal in two files, because it carries
/// a statutory inflation-adjustment clause and will move one day. Verified
/// still 3,000,000 on 2026-09-20.
const double vatThreshold = 3000000;

class FreelanceTaxCalculation {
  const FreelanceTaxCalculation({
    required this.grossIncome,
    required this.taxOption,
    required this.taxFreeAllowance,
    required this.taxableBase,
    required this.estimatedTaxDue,
    required this.effectiveTaxRate,
    required this.monthlyTaxProvision,
    required this.leanMonthsBufferRecommended,
    this.percentageTax = 0,
    this.eightPercentAvailable = true,
    this.unavailableReason,
  });

  final double grossIncome;
  final FreelanceTaxOption taxOption;

  /// The 250,000 that is not taxed under the 8% route.
  ///
  /// RENAMED from allowableDeduction, because it is not a deduction and
  /// calling it one is what produced the bug beside it. Under the 8% regime
  /// NO deductions are allowed: no itemised, no OSD, nothing. This figure
  /// stands in for the zero bracket of the graduated table, which is exactly
  /// why a mixed-income earner does not get it: their salary already used it.
  final double taxFreeAllowance;

  final double taxableBase;
  final double estimatedTaxDue;

  /// The 3% percentage tax, which only the GRADUATED route pays.
  ///
  /// It belongs in the comparison because the 8% is in lieu of income tax
  /// AND percentage tax. Leaving it out compared one tax against two, and
  /// was most of why the saving was overstated.
  final double percentageTax;

  /// Whether this taxpayer may elect the 8% at all.
  final bool eightPercentAvailable;

  /// Why not, in words a person can act on. Null when it is available.
  final String? unavailableReason;

  /// Everything owed on this income under the chosen route.
  double get totalTaxDue => estimatedTaxDue + percentageTax;

  /// A percentage, 0 to 100, not a fraction.
  final double effectiveTaxRate;
  final double monthlyTaxProvision;
  final double leanMonthsBufferRecommended;
}

/// BIR ANNUAL graduated income tax, TRAIN law 2023 onwards.
double annualGraduatedTax(double taxableBase) {
  if (taxableBase <= 250000) return 0;
  if (taxableBase <= 400000) return (taxableBase - 250000) * 0.15;
  if (taxableBase <= 800000) return 22500 + (taxableBase - 400000) * 0.20;
  if (taxableBase <= 2000000) return 102500 + (taxableBase - 800000) * 0.25;
  if (taxableBase <= 8000000) return 402500 + (taxableBase - 2000000) * 0.30;
  return 2202500 + (taxableBase - 8000000) * 0.35;
}

/// The 8% gross income tax against the graduated brackets.
///
/// ## Three defects fixed here, and one of them drives an irrevocable choice
///
/// The 8% election is IRREVOCABLE for the taxable year. A person reads this
/// comparison, elects on their first quarter return, and is locked in until
/// December. That makes a wrong comparison here worse than a wrong figure
/// almost anywhere else in the app, because there is no correcting it later.
///
/// 1. NO ELIGIBILITY GATE. The 8% is available only below the VAT threshold
///    and only to somebody not VAT-registered. The old version quoted it to
///    a 5,000,000 freelancer, for whom it is not a worse choice, it is not a
///    lawful one.
///
/// 2. NO MIXED-INCOME CASE. Somebody with a job AND freelance work pays 8%
///    on their whole business gross with NO 250,000 reduction, because the
///    zero bracket on their salary already used it. Granting it twice
///    understated their tax by a flat 20,000.
///
/// 3. THE GRADUATED ARM HAD NO DEDUCTIONS AND NO PERCENTAGE TAX. It ran the
///    table on the full gross, which no filer does, and omitted the 3%
///    percentage tax that only that route pays. At 1,200,000 gross the app
///    advertised a 126,500 saving from electing 8%. The honest figure is
///    about 46,500. Overstating a tax saving by 2.7x, on the screen that
///    triggers a twelve-month commitment, was the worst number in this file.
///
/// The 250,000 itself was NOT the bug and is not removed: for a purely
/// self-employed person it is exactly right.
FreelanceTaxCalculation calculateFreelanceTax({
  required double annualGrossIncome,
  FreelanceTaxOption taxOption = FreelanceTaxOption.eightPercentGit,

  /// Salary income taxed separately under the graduated table. Above zero
  /// means MIXED INCOME, which changes both routes.
  double compensationIncome = 0,

  /// A VAT-registered person may not elect the 8% at any income level, even
  /// one who registered voluntarily while earning far below the threshold.
  bool vatRegistered = false,
}) {
  final bool mixed = compensationIncome > 0;

  // The test is strict: at exactly the threshold the taxpayer is still
  // eligible, so this is > and never >=.
  final String? blocked = vatRegistered
      ? 'The 8% option is not open to anyone registered for VAT, whatever '
            'they earn.'
      : annualGrossIncome > vatThreshold
      ? 'The 8% option is not open above ${formatPeso(vatThreshold)} of '
            'gross. Above that you are VAT registrable and the graduated '
            'rates apply.'
      : null;

  final bool available = blocked == null;

  if (taxOption == FreelanceTaxOption.eightPercentGit && available) {
    // Mixed income gets NO reduction. See defect 2 above.
    final double allowance = mixed ? 0 : 250000;
    final double taxableBase = math.max(0, annualGrossIncome - allowance);
    final double estimatedTaxDue = taxableBase * 0.08;
    return FreelanceTaxCalculation(
      grossIncome: annualGrossIncome,
      taxOption: taxOption,
      taxFreeAllowance: allowance,
      taxableBase: taxableBase,
      estimatedTaxDue: estimatedTaxDue,
      effectiveTaxRate: annualGrossIncome > 0
          ? (estimatedTaxDue / annualGrossIncome) * 100
          : 0,
      monthlyTaxProvision: estimatedTaxDue / 12,
      leanMonthsBufferRecommended: (annualGrossIncome / 12) * 3,
    );
  }

  // GRADUATED, with the two things it actually carries.
  //
  // The 40% Optional Standard Deduction is on GROSS SALES, not on gross
  // income, and is what an individual filer without itemised receipts
  // claims. The 3% percentage tax is separate and is the tax the 8% option
  // substitutes for along with income tax.
  final double osd = annualGrossIncome * 0.40;
  final double businessNet = math.max(0, annualGrossIncome - osd);

  // Mixed income stacks ONE combined base through the table. Never two
  // passes, which would give the 250,000 zero bracket twice.
  final double tax = annualGraduatedTax(businessNet + compensationIncome);
  final double percentageTax = annualGrossIncome * 0.03;

  return FreelanceTaxCalculation(
    grossIncome: annualGrossIncome,
    taxOption: FreelanceTaxOption.graduatedRates,
    taxFreeAllowance: osd,
    taxableBase: businessNet + compensationIncome,
    estimatedTaxDue: tax,
    percentageTax: percentageTax,
    effectiveTaxRate: annualGrossIncome > 0
        ? ((tax + percentageTax) / annualGrossIncome) * 100
        : 0,
    monthlyTaxProvision: (tax + percentageTax) / 12,
    leanMonthsBufferRecommended: (annualGrossIncome / 12) * 4,
    eightPercentAvailable: available,
    unavailableReason: blocked,
  );
}
