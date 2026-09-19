import 'dart:math' as math;

import 'js_round.dart';

/// Loan amortization and affordability, ported from src/utils/loanCalculators.ts.
///
/// Two interest conventions, and the difference is the whole point in the
/// Philippines. DIMINISHING charges interest on what is still owed, so the
/// interest component shrinks every month. FLAT ADD-ON charges interest on the
/// ORIGINAL principal for the whole term, which is what appliance and car
/// dealers quote, and it costs far more than the same headline rate suggests.

enum RateType { diminishing, flatAddon }

/// Rounds to centavos the way the prototype does, Math.round(x * 100) / 100.
double _c(double v) => jsRound(v * 100) / 100;

class AmortizationRow {
  const AmortizationRow({
    required this.period,
    required this.dueDate,
    required this.scheduledPayment,
    required this.principalComponent,
    required this.interestComponent,
    required this.extraPayment,
    required this.remainingBalance,
  });

  final int period;
  final String dueDate;
  final double scheduledPayment;
  final double principalComponent;
  final double interestComponent;
  final double extraPayment;
  final double remainingBalance;
}

class LoanCalculationResult {
  const LoanCalculationResult({
    required this.monthlyPayment,
    required this.totalPayment,
    required this.totalInterest,
    required this.amortizationSchedule,
    required this.payoffMonths,
    required this.interestSavedWithExtra,
    required this.monthsSavedWithExtra,
  });

  final double monthlyPayment;
  final double totalPayment;
  final double totalInterest;
  final List<AmortizationRow> amortizationSchedule;
  final int payoffMonths;
  final double interestSavedWithExtra;
  final int monthsSavedWithExtra;
}

LoanCalculationResult calculateAmortization({
  required double principal,

  /// A percentage, so 6.25 means 6.25%.
  required double annualInterestRate,
  required int termMonths,
  RateType rateType = RateType.diminishing,
  double balloonPayment = 0,
  double extraMonthlyPayment = 0,
}) {
  if (principal <= 0 || termMonths <= 0) {
    return const LoanCalculationResult(
      monthlyPayment: 0,
      totalPayment: 0,
      totalInterest: 0,
      amortizationSchedule: <AmortizationRow>[],
      payoffMonths: 0,
      interestSavedWithExtra: 0,
      monthsSavedWithExtra: 0,
    );
  }

  final double monthlyRate = annualInterestRate / 100 / 12;

  double baseMonthlyPayment;
  if (rateType == RateType.flatAddon) {
    final double totalFlatInterest =
        principal * (annualInterestRate / 100) * (termMonths / 12);
    baseMonthlyPayment =
        (principal - balloonPayment + totalFlatInterest) / termMonths;
  } else if (monthlyRate == 0) {
    baseMonthlyPayment = (principal - balloonPayment) / termMonths;
  } else {
    final double factor = math.pow(1 + monthlyRate, termMonths).toDouble();
    baseMonthlyPayment =
        ((principal * monthlyRate * factor) - (balloonPayment * monthlyRate)) /
        (factor - 1);
  }

  // A baseline run with NO extra payment, purely so the saving can be
  // reported. It uses the diminishing rate even for a flat add-on loan, which
  // is the prototype's behaviour and is left alone.
  double baselineTotalInterest = 0;
  double balance = principal;
  for (int m = 1; m <= termMonths; m++) {
    final double interest = balance * monthlyRate;
    final double principalPart = math.min(
      balance,
      baseMonthlyPayment - interest,
    );
    baselineTotalInterest += interest;
    balance -= principalPart;
    if (balance <= 0) break;
  }

  final List<AmortizationRow> schedule = <AmortizationRow>[];
  double remainingBalance = principal;
  double totalPaid = 0;
  double totalInterest = 0;
  int actualPayoffMonths = 0;

  // The loop runs to twice the term so an extra payment can finish early
  // without the ceiling cutting a legitimate schedule short.
  for (int period = 1; period <= termMonths * 2; period++) {
    if (remainingBalance <= 0.01) break;

    final double interestComponent = rateType == RateType.flatAddon
        ? (principal * (annualInterestRate / 100) / 12)
        : (remainingBalance * monthlyRate);

    double scheduledPrincipal = baseMonthlyPayment - interestComponent;
    if (scheduledPrincipal > remainingBalance) {
      scheduledPrincipal = remainingBalance;
    }

    final double extra = math.min(
      extraMonthlyPayment,
      math.max(0, remainingBalance - scheduledPrincipal),
    );

    remainingBalance = math.max(
      0,
      remainingBalance - (scheduledPrincipal + extra),
    );
    final double scheduledPaymentForMonth =
        scheduledPrincipal + interestComponent;

    totalInterest += interestComponent;
    totalPaid += scheduledPaymentForMonth + extra;
    actualPayoffMonths = period;

    schedule.add(
      AmortizationRow(
        period: period,
        dueDate: 'Month $period',
        scheduledPayment: _c(scheduledPaymentForMonth),
        principalComponent: _c(scheduledPrincipal),
        interestComponent: _c(interestComponent),
        extraPayment: _c(extra),
        remainingBalance: _c(remainingBalance),
      ),
    );

    if (remainingBalance <= 0) break;
  }

  if (balloonPayment > 0 && actualPayoffMonths >= termMonths) {
    totalPaid += balloonPayment;
  }

  return LoanCalculationResult(
    monthlyPayment: _c(baseMonthlyPayment),
    totalPayment: _c(totalPaid),
    totalInterest: _c(totalInterest),
    amortizationSchedule: schedule,
    payoffMonths: actualPayoffMonths,
    interestSavedWithExtra: _c(
      math.max(0, baselineTotalInterest - totalInterest),
    ),
    monthsSavedWithExtra: math.max(0, termMonths - actualPayoffMonths),
  );
}

enum AffordabilityStatus { healthy, moderate, stretched }

class DsrResult {
  const DsrResult({
    required this.dsr,
    required this.status,
    required this.maxRecommendedMonthlyDebt,
    required this.maxBorrowingCapacity30Yr,
    required this.advice,
  });

  /// A percentage, rounded to one decimal.
  final double dsr;
  final AffordabilityStatus status;
  final double maxRecommendedMonthlyDebt;

  /// Borrowing power on a 15 year loan at 7%, despite the field's name. The
  /// prototype names it 30Yr and computes 180 months; the name is kept so the
  /// two stay comparable, and this comment is why it looks wrong.
  final double maxBorrowingCapacity30Yr;
  final String advice;
}

/// Debt service ratio against the BSP prudential bands: under 30% healthy,
/// 30 to 40% moderate, over 40% stretched.
DsrResult calculateDsr({
  required double monthlyDebtObligations,
  required double grossMonthlyIncome,
}) {
  if (grossMonthlyIncome <= 0) {
    return const DsrResult(
      dsr: 0,
      status: AffordabilityStatus.healthy,
      maxRecommendedMonthlyDebt: 0,
      maxBorrowingCapacity30Yr: 0,
      advice: 'Enter gross monthly income to evaluate debt capacity.',
    );
  }

  final double dsr = (monthlyDebtObligations / grossMonthlyIncome) * 100;
  final double maxRecommendedMonthlyDebt = grossMonthlyIncome * 0.35;
  final double remainingDebtCapacity = math.max(
    0,
    maxRecommendedMonthlyDebt - monthlyDebtObligations,
  );

  const double r = 0.07 / 12;
  const int n = 180;
  final double pow = math.pow(1 + r, n).toDouble();
  final double capacity = remainingDebtCapacity > 0
      ? jsRound(remainingDebtCapacity * ((pow - 1) / (r * pow))).toDouble()
      : 0;

  AffordabilityStatus status = AffordabilityStatus.healthy;
  String advice =
      'Your debt commitments are well within the 30% BSP safety threshold.';
  if (dsr > 40) {
    status = AffordabilityStatus.stretched;
    advice =
        'Debt commitments exceed 40% of income. High vulnerability to income shocks.';
  } else if (dsr >= 30) {
    status = AffordabilityStatus.moderate;
    advice =
        'Debt commitments are between 30% and 40%. Approaching the cautionary threshold.';
  }

  return DsrResult(
    dsr: jsRound(dsr * 10) / 10,
    status: status,
    maxRecommendedMonthlyDebt: jsRound(maxRecommendedMonthlyDebt).toDouble(),
    maxBorrowingCapacity30Yr: capacity,
    advice: advice,
  );
}
