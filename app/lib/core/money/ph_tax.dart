import 'dart:math' as math;

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

  // 1. SSS. Employee share is 4.5% of the monthly salary credit, which is
  //    floored at 4,000 and capped at 30,000 (regular plus WISP).
  final double sssMsc = math.min(30000, math.max(4000, monthlyBaseSalary));
  final double sss = jsRound(sssMsc * 0.045).toDouble();
  final double sssEmployer = jsRound(sssMsc * 0.095).toDouble();

  // 2. PhilHealth. 5% premium split evenly, so 2.5% each, on a base floored at
  //    10,000 and capped at 100,000.
  final double philhealthBase =
      math.min(100000, math.max(10000, monthlyBaseSalary));
  final double philhealth = jsRound(philhealthBase * 0.025).toDouble();
  final double philhealthEmployer = philhealth;

  // 3. Pag-IBIG. 2% of a fund salary capped at 10,000, so 200 pesos at most.
  final double pagibigBase = math.min(10000, math.max(1500, monthlyBaseSalary));
  final double pagibig = jsRound(pagibigBase * 0.02).toDouble();
  final double pagibigEmployer = pagibig;

  final double totalContributions = sss + philhealth + pagibig;

  final double grossTaxable = monthlyBaseSalary +
      monthlyTaxableAllowance +
      monthlyOvertime +
      monthlyNightDiff;
  final double taxableIncome = math.max(0, grossTaxable - totalContributions);
  final double withholdingTax = monthlyWithholdingTax(taxableIncome);

  final double grossMonthlyIncome = monthlyBaseSalary +
      monthlyTaxableAllowance +
      monthlyNonTaxableAllowance +
      monthlyOvertime +
      monthlyNightDiff;
  final double netTakeHome = math.max(
    0,
    jsRound(grossMonthlyIncome - totalContributions - withholdingTax).toDouble(),
  );
  final double semiMonthlyTakeHome = jsRound(netTakeHome / 2).toDouble();

  // 13th month, from BASE salary only, with the 90,000 TRAIN exemption. The
  // 20% on the excess is the prototype's stated approximation, not a bracket
  // lookup, and it is kept as such rather than quietly made more precise.
  final int safeMonths = math.min(12, math.max(1, monthsWorked));
  final double thirteenthMonthGross =
      jsRound((monthlyBaseSalary * safeMonths) / 12).toDouble();
  final double thirteenthMonthTaxable =
      math.max(0, thirteenthMonthGross - 90000);
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
    annualTotalTax: jsRound(withholdingTax * 12 + thirteenthMonthTax).toDouble(),
    annualNetTakeHome:
        jsRound(netTakeHome * 12 + thirteenthMonthNet).toDouble(),
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
  final double taxableExcessAmount =
      math.max(0, calculatedGross - taxExemptThreshold);
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

class FreelanceTaxCalculation {
  const FreelanceTaxCalculation({
    required this.grossIncome,
    required this.taxOption,
    required this.allowableDeduction,
    required this.taxableBase,
    required this.estimatedTaxDue,
    required this.effectiveTaxRate,
    required this.monthlyTaxProvision,
    required this.leanMonthsBufferRecommended,
  });

  final double grossIncome;
  final FreelanceTaxOption taxOption;
  final double allowableDeduction;
  final double taxableBase;
  final double estimatedTaxDue;

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
/// The two options differ in more than the rate, and the differences are the
/// prototype's: only the 8% route gets the 250,000 standard deduction, and the
/// recommended lean-month buffer is three months on 8% and four on graduated.
FreelanceTaxCalculation calculateFreelanceTax({
  required double annualGrossIncome,
  FreelanceTaxOption taxOption = FreelanceTaxOption.eightPercentGit,
}) {
  const double standardDeduction = 250000;

  if (taxOption == FreelanceTaxOption.eightPercentGit) {
    final double taxableBase =
        math.max(0, annualGrossIncome - standardDeduction);
    final double estimatedTaxDue = taxableBase * 0.08;
    return FreelanceTaxCalculation(
      grossIncome: annualGrossIncome,
      taxOption: taxOption,
      allowableDeduction: standardDeduction,
      taxableBase: taxableBase,
      estimatedTaxDue: estimatedTaxDue,
      effectiveTaxRate: annualGrossIncome > 0
          ? (estimatedTaxDue / annualGrossIncome) * 100
          : 0,
      monthlyTaxProvision: estimatedTaxDue / 12,
      leanMonthsBufferRecommended: (annualGrossIncome / 12) * 3,
    );
  }

  final double tax = annualGraduatedTax(annualGrossIncome);
  return FreelanceTaxCalculation(
    grossIncome: annualGrossIncome,
    taxOption: taxOption,
    allowableDeduction: 0,
    taxableBase: annualGrossIncome,
    estimatedTaxDue: tax,
    effectiveTaxRate:
        annualGrossIncome > 0 ? (tax / annualGrossIncome) * 100 : 0,
    monthlyTaxProvision: tax / 12,
    leanMonthsBufferRecommended: (annualGrossIncome / 12) * 4,
  );
}
