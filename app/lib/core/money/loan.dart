import 'dart:math' as math;

import 'js_round.dart';
import 'debt_ratio.dart';

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

/// The same rounding, kept as WHOLE CENTAVOS.
///
/// The schedule loop works in these rather than in pesos, so a row's parts
/// and its total are the same integers added twice rather than three separate
/// roundings of three separate doubles. See the loop for what that fixed.
int _cent(double v) => jsRound(v * 100).toInt();

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

  // THE SCHEDULE IS BUILT IN WHOLE CENTAVOS, and the totals are the SUM OF
  // THE ROWS. Both halves of that are a deliberate correction, 2026-10-02.
  //
  // What it replaced: the loop computed interest and principal as separate
  // unrounded doubles, added them for the payment, and then rounded all
  // three INDEPENDENTLY on the way into the row. Three roundings of two
  // addends and their sum do not agree, so `principal + interest` did not
  // equal `payment`. On the Car loan tab's own default inputs that was true
  // of all sixty rows. Alongside it, `totalPaid` and `totalInterest` were
  // accumulated from the unrounded values and never saw the rows at all, so
  // the TOTAL PAYABLE chip disagreed with the table printed under it by
  // 0.20, and the CSV export's header disagreed with its own columns. That
  // export exists so somebody can lay it beside the letter their bank sent.
  //
  // Now: interest is rounded ONCE, principal is whatever is left of the
  // payment after it, and the row's payment is those two integers added. The
  // row foots by construction rather than by luck, the balance walks down by
  // exactly the principal, and the last period clamps to the balance so it
  // lands on zero.
  //
  // THIS DIVERGES FROM THE PROTOTYPE ON PURPOSE, which is why it is spelled
  // out here rather than quietly changed. The prototype's own goldens encode
  // the defect: its first row reads 14,583.33 interest and 7,887.37
  // principal against a stated payment of 22,470.71, which is a centavo
  // short. The rule is that an odd prototype behaviour is reproduced and
  // locked, and the stated exception is where a wrong number costs real
  // money. A schedule whose rows do not add up is that: it is the one
  // artefact in this app somebody checks against a lender's paperwork.
  final List<AmortizationRow> schedule = <AmortizationRow>[];

  // A loan whose payment is not a real number cannot be amortised, and
  // reaching _cent with one throws. An unbounded term field can produce it.
  if (!baseMonthlyPayment.isFinite || baseMonthlyPayment <= 0) {
    return LoanCalculationResult(
      monthlyPayment: 0,
      totalPayment: 0,
      totalInterest: 0,
      amortizationSchedule: schedule,
      payoffMonths: 0,
      interestSavedWithExtra: 0,
      monthsSavedWithExtra: 0,
    );
  }

  int balanceCent = _cent(principal);
  final int basePaymentCent = _cent(baseMonthlyPayment);
  final int extraCent = _cent(extraMonthlyPayment);
  // FLAT ADD-ON INTEREST IS A CONTRACT TOTAL, SHARED OUT, not a per-period
  // figure summed up. That distinction is the whole of this block.
  //
  // Rounding `principal * rate / 12` once and charging it sixty times leaves
  // the schedule 0.20 short of the 380,000.00 the contract actually states,
  // because the true monthly figure is 6,966.666... and every row drops a
  // third of a centavo. The number a dealer quotes is the TOTAL, so that is
  // what the rows have to add up to.
  //
  // Same policy as the instalment engine, which already says it: the repeated
  // share is rounded, and the FINAL period absorbs the whole difference.
  final int flatTotalInterestCent = rateType == RateType.flatAddon
      ? _cent(principal * (annualInterestRate / 100) * (termMonths / 12))
      : 0;
  final int flatShareCent = rateType == RateType.flatAddon && termMonths > 0
      ? flatTotalInterestCent ~/ termMonths
      : 0;

  int totalPaidCent = 0;
  int totalInterestCent = 0;
  int actualPayoffMonths = 0;

  // The loop runs to twice the term so an extra payment can finish early
  // without the ceiling cutting a legitimate schedule short.
  for (int period = 1; period <= termMonths * 2; period++) {
    if (balanceCent <= 0) break;

    // The last period of the stated term, where the flat add-on remainder
    // lands.
    final bool isFinalScheduled = period == termMonths;

    // AND WHETHER THIS PERIOD CAN FINISH THE LOAN, which is a different
    // question and the reason these are two flags rather than one.
    //
    // The balance clamp below exists to mop up the few centavos that
    // per-period rounding leaves at the end of a term, so a sixty month loan
    // does not need a sixty first period to collect them. A first version
    // clamped on the term alone, which also truncated the BALLOON case: that
    // loan is deliberately sized to leave the balloon outstanding at month
    // 36 and keeps amortising to month 45, a prototype behaviour captured on
    // purpose because changing it moves money on a screen. Clamping turned
    // it into 36.
    //
    // A residue is smaller than one payment. A balloon is not.
    final bool absorbsResidue =
        isFinalScheduled && balanceCent <= basePaymentCent;

    final int interestCent = rateType == RateType.flatAddon
        // The final period takes the whole remainder, so sixty rows sum to
        // the contract total rather than to 0.20 less than it.
        ? (isFinalScheduled
              ? flatTotalInterestCent - flatShareCent * (termMonths - 1)
              : flatShareCent)
        : _cent(balanceCent / 100 * monthlyRate);

    // Principal is what is LEFT of the payment after interest. Deriving it
    // this way is what makes the row foot: the two parts and their sum are
    // the same integers, not three separate roundings.
    int principalCent = basePaymentCent - interestCent;

    // THE FINAL PERIOD CLEARS THE BALANCE, which is what keeps a 60 month
    // loan 60 months long. Rounding each period to the centavo leaves a few
    // behind, and without this the loop needed a 61st period to collect
    // them, so a five year loan reported as five years and a month.
    if (absorbsResidue) principalCent = balanceCent;
    if (principalCent > balanceCent) principalCent = balanceCent;
    if (principalCent < 0) principalCent = 0;

    final int extraRowCent = math.min(
      extraCent,
      math.max(0, balanceCent - principalCent),
    );

    balanceCent = math.max(0, balanceCent - principalCent - extraRowCent);

    final int paymentCent = principalCent + interestCent;
    totalInterestCent += interestCent;
    totalPaidCent += paymentCent + extraRowCent;
    actualPayoffMonths = period;

    schedule.add(
      AmortizationRow(
        period: period,
        dueDate: 'Month $period',
        scheduledPayment: paymentCent / 100,
        principalComponent: principalCent / 100,
        interestComponent: interestCent / 100,
        extraPayment: extraRowCent / 100,
        remainingBalance: balanceCent / 100,
      ),
    );

    // A period that moves nothing would loop to the ceiling building rows
    // that all say the same thing. It means the payment cannot cover the
    // interest, which is a real input, not a crash.
    if (principalCent == 0 && extraRowCent == 0) break;
  }

  if (balloonPayment > 0 && actualPayoffMonths >= termMonths) {
    totalPaidCent += _cent(balloonPayment);
  }

  return LoanCalculationResult(
    monthlyPayment: _c(baseMonthlyPayment),
    totalPayment: totalPaidCent / 100,
    totalInterest: totalInterestCent / 100,
    amortizationSchedule: schedule,
    payoffMonths: actualPayoffMonths,
    interestSavedWithExtra: _c(
      math.max(0, baselineTotalInterest - totalInterestCent / 100),
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

/// Debt service ratio against the one rule in debt_ratio.dart: at or below
/// 30% comfortable, 30 to 40% moderate, over 40% stretched.
///
/// The RATE now comes from that file rather than being typed here, by founder
/// decision F8. What has NOT changed is the denominator: this takes gross
/// monthly income, where F8's rule is stated on take-home. That difference is
/// recorded in docs/DEFERRED.md rather than collapsed silently, because
/// changing which figure a caller must pass is a bigger change than picking a
/// rate, and a lender assessing capacity really does work on gross.
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
  // 0.35 until P1.7. It was the FOURTH debt to income figure in the app and
  // the only one nothing else agreed with, so it is the one F8 moved.
  final double maxRecommendedMonthlyDebt =
      grossMonthlyIncome * debtShareComfortableFraction;
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
      // NOT "the 30% BSP safety threshold". The BSP publishes no such
      // determination about an individual's ratio, and naming a regulator
      // turns a rule of thumb into an official blessing the app cannot give.
      'Your debt commitments are inside the 30 percent level lenders '
      'commonly treat as comfortable.';
  if (dsr > debtShareStretched) {
    status = AffordabilityStatus.stretched;
    advice =
        'Debt commitments exceed 40% of income. High vulnerability to income shocks.';
  } else if (dsr >= debtShareComfortable) {
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
