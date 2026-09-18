import 'dart:math' as math;

import 'js_round.dart';
import 'loan.dart';

/// The Philippine loan products, ported from src/utils/loanCalculators.ts.
///
/// Every one of these is a PRESET over calculateAmortization, which is already
/// golden locked. What they add is the product knowledge: which rate a lender
/// actually charges, what it deducts before handing the money over, and what it
/// gives back. The rates below are the prototype's and are a snapshot, not a
/// live feed.

// ---------------------------------------------------------------- Pag-IBIG

enum PagIbigProgram { affordableHousing, regularHousing }

/// Pag-IBIG housing. The rate is set by the FIXING PERIOD, the years before the
/// rate can be repriced, and affordable housing ignores it entirely at a
/// subsidised 3%.
LoanCalculationResult calculatePagIbigHousingLoan({
  required PagIbigProgram program,
  required double loanAmount,
  required int termYears,
  int fixingPeriodYears = 3,
  double extraMonthlyPayment = 0,
}) {
  double annualRate;
  if (program == PagIbigProgram.affordableHousing) {
    annualRate = 3.0;
  } else {
    switch (fixingPeriodYears) {
      case 1:
        annualRate = 5.375;
        break;
      case 3:
        annualRate = 5.75;
        break;
      case 5:
        annualRate = 6.25;
        break;
      case 10:
        annualRate = 7.125;
        break;
      default:
        annualRate = 7.75;
        break;
    }
  }

  return calculateAmortization(
    principal: loanAmount,
    annualInterestRate: annualRate,
    termMonths: termYears * 12,
    extraMonthlyPayment: extraMonthlyPayment,
  );
}

// ------------------------------------------------------------ Bank housing

class BankHousingResult {
  const BankHousingResult({
    required this.propertyValue,
    required this.downpaymentAmount,
    required this.loanPrincipal,
    required this.monthlyPayment,
    required this.totalPayment,
    required this.totalInterest,
    required this.payoffMonths,
    required this.interestSavedWithExtra,
    required this.repricedMonthlyPayment,
    required this.monthlyPaymentJump,
    required this.schedule,
  });

  final double propertyValue;
  final double downpaymentAmount;
  final double loanPrincipal;
  final double monthlyPayment;
  final double totalPayment;
  final double totalInterest;
  final int payoffMonths;
  final double interestSavedWithExtra;

  /// What the instalment becomes after the fixed period ends.
  final double repricedMonthlyPayment;

  /// The size of that jump, which is the number the calculator exists to show.
  final double monthlyPaymentJump;
  final List<AmortizationRow> schedule;
}

/// A bank housing loan with a REPRICING STRESS TEST.
///
/// The repriced figure is an estimate and the prototype says so in its own
/// code: it assumes 85% of the principal is still outstanding when the fixed
/// period ends, rather than reading the real balance off the schedule. Ported
/// as-is; correcting it would move a number nobody asked to move.
BankHousingResult calculateBankHousingLoan({
  required double propertyValue,
  required double downpaymentPercent,
  required int termYears,
  required double fixedRate,
  double? repricedRate,
  int fixedPeriodYears = 3,
  double extraMonthlyPayment = 0,
}) {
  final double downpaymentAmount = propertyValue * (downpaymentPercent / 100);
  final double loanPrincipal = math.max(0, propertyValue - downpaymentAmount);
  final int termMonths = termYears * 12;

  final LoanCalculationResult result = calculateAmortization(
    principal: loanPrincipal,
    annualInterestRate: fixedRate,
    termMonths: termMonths,
    extraMonthlyPayment: extraMonthlyPayment,
  );

  double repricedMonthlyPayment = result.monthlyPayment;
  if (repricedRate != null && repricedRate > fixedRate) {
    final int remainingTerm =
        math.max(12, termMonths - (fixedPeriodYears * 12));
    final double estimatedBalance = loanPrincipal * 0.85;
    repricedMonthlyPayment = calculateAmortization(
      principal: estimatedBalance,
      annualInterestRate: repricedRate,
      termMonths: remainingTerm,
    ).monthlyPayment;
  }

  return BankHousingResult(
    propertyValue: propertyValue,
    downpaymentAmount: downpaymentAmount,
    loanPrincipal: loanPrincipal,
    monthlyPayment: result.monthlyPayment,
    totalPayment: result.totalPayment,
    totalInterest: result.totalInterest,
    payoffMonths: result.payoffMonths,
    interestSavedWithExtra: result.interestSavedWithExtra,
    repricedMonthlyPayment: repricedMonthlyPayment,
    monthlyPaymentJump:
        math.max(0, repricedMonthlyPayment - result.monthlyPayment),
    schedule: result.amortizationSchedule,
  );
}

// ------------------------------------------------------------------- Car

class CarLoanResult {
  const CarLoanResult({
    required this.vehiclePrice,
    required this.downpaymentAmount,
    required this.loanPrincipal,
    required this.chattelMortgageFee,
    required this.comprehensiveInsurance,
    required this.initialCashOut,
    required this.monthlyPayment,
    required this.totalPayment,
    required this.totalInterest,
    required this.balloonPayment,
    required this.schedule,
  });

  final double vehiclePrice;
  final double downpaymentAmount;
  final double loanPrincipal;
  final double chattelMortgageFee;
  final double comprehensiveInsurance;

  /// What actually leaves the pocket on day one, which is never just the
  /// downpayment.
  final double initialCashOut;
  final double monthlyPayment;
  final double totalPayment;
  final double totalInterest;
  final double balloonPayment;
  final List<AmortizationRow> schedule;
}

/// A car loan, where the headline is almost always FLAT ADD-ON.
///
/// The balloon is a percentage of the VEHICLE PRICE, not of the loan, which is
/// how dealers quote a residual. Chattel mortgage is 2.5% of the loan and the
/// first year's comprehensive insurance 2.4% of the car.
CarLoanResult calculateCarLoan({
  required double vehiclePrice,
  required double downpaymentPercent,
  required int termMonths,
  required double annualInterestRate,
  required RateType rateType,
  double balloonPercent = 0,
  bool includeInsuranceAndChattel = false,
}) {
  final double downpaymentAmount = vehiclePrice * (downpaymentPercent / 100);
  final double loanPrincipal = math.max(0, vehiclePrice - downpaymentAmount);
  final double balloonPayment = vehiclePrice * (balloonPercent / 100);

  final double chattelMortgageFee =
      includeInsuranceAndChattel ? loanPrincipal * 0.025 : 0;
  final double comprehensiveInsurance =
      includeInsuranceAndChattel ? vehiclePrice * 0.024 : 0;

  final LoanCalculationResult result = calculateAmortization(
    principal: loanPrincipal,
    annualInterestRate: annualInterestRate,
    termMonths: termMonths,
    rateType: rateType,
    balloonPayment: balloonPayment,
  );

  return CarLoanResult(
    vehiclePrice: vehiclePrice,
    downpaymentAmount: downpaymentAmount,
    loanPrincipal: loanPrincipal,
    chattelMortgageFee: chattelMortgageFee,
    comprehensiveInsurance: comprehensiveInsurance,
    initialCashOut:
        downpaymentAmount + chattelMortgageFee + comprehensiveInsurance,
    monthlyPayment: result.monthlyPayment,
    totalPayment: result.totalPayment,
    totalInterest: result.totalInterest,
    balloonPayment: balloonPayment,
    schedule: result.amortizationSchedule,
  );
}

// ---------------------------------------------------------------- Salary

enum SalaryLoanType { sssSalary, pagibigMpl, pagibigCalamity, gsisConso }

class SalaryLoanResult {
  const SalaryLoanResult({
    required this.loanAmount,
    required this.netProceeds,
    required this.processingFee,
    required this.monthlyPayment,
    required this.totalPayment,
    required this.totalInterest,
    required this.estimatedDividendRebate,
    required this.effectiveTotalCost,
    required this.annualRate,
    required this.schedule,
  });

  final double loanAmount;
  final double netProceeds;
  final double processingFee;
  final double monthlyPayment;
  final double totalPayment;
  final double totalInterest;

  /// Pag-IBIG hands part of the interest back as a member dividend, so the
  /// headline rate overstates what an MPL actually costs.
  final double estimatedDividendRebate;
  final double effectiveTotalCost;
  final double annualRate;
  final List<AmortizationRow> schedule;
}

SalaryLoanResult calculateSalaryLoan({
  required SalaryLoanType loanType,
  required double loanAmount,
  required int termMonths,
}) {
  double annualRate;
  double processingFeePercent;
  double dividendRebatePercent = 0;

  switch (loanType) {
    case SalaryLoanType.sssSalary:
      annualRate = 10.0;
      processingFeePercent = 1.0;
      break;
    case SalaryLoanType.pagibigMpl:
      annualRate = 10.5;
      processingFeePercent = 0;
      dividendRebatePercent = 20.0;
      break;
    case SalaryLoanType.pagibigCalamity:
      annualRate = 5.95;
      processingFeePercent = 0;
      break;
    case SalaryLoanType.gsisConso:
      annualRate = 12.0;
      processingFeePercent = 1.5;
      break;
  }

  final LoanCalculationResult result = calculateAmortization(
    principal: loanAmount,
    annualInterestRate: annualRate,
    termMonths: termMonths,
  );

  final double processingFee = loanAmount * (processingFeePercent / 100);
  final double rebate = result.totalInterest * (dividendRebatePercent / 100);

  return SalaryLoanResult(
    loanAmount: loanAmount,
    netProceeds: loanAmount - processingFee,
    processingFee: processingFee,
    monthlyPayment: result.monthlyPayment,
    totalPayment: result.totalPayment,
    totalInterest: result.totalInterest,
    estimatedDividendRebate: rebate,
    effectiveTotalCost:
        jsRound(result.totalInterest - rebate + processingFee).toDouble(),
    annualRate: annualRate,
    schedule: result.amortizationSchedule,
  );
}

// -------------------------------------------------------------- Personal

class PersonalLoanResult {
  const PersonalLoanResult({
    required this.principal,
    required this.processingFee,
    required this.netCashReceived,
    required this.monthlyPayment,
    required this.totalPayment,
    required this.totalInterest,
    required this.schedule,
  });

  final double principal;
  final double processingFee;

  /// What lands in the account. Never the amount on the contract.
  final double netCashReceived;
  final double monthlyPayment;
  final double totalPayment;
  final double totalInterest;
  final List<AmortizationRow> schedule;
}

/// A digital bank or personal loan, quoted as a MONTHLY ADD-ON rate.
///
/// "1.5% a month" sounds small and is 18% a year on the ORIGINAL balance, which
/// is far worse than 18% diminishing. Multiplying by 12 and running it as flat
/// add-on is what makes that visible.
PersonalLoanResult calculatePersonalLoan({
  required double principal,
  required int termMonths,
  required double monthlyAddOnRate,
  required double processingFee,
}) {
  final LoanCalculationResult result = calculateAmortization(
    principal: principal,
    annualInterestRate: monthlyAddOnRate * 12,
    termMonths: termMonths,
    rateType: RateType.flatAddon,
  );

  return PersonalLoanResult(
    principal: principal,
    processingFee: processingFee,
    netCashReceived: math.max(0, principal - processingFee),
    monthlyPayment: result.monthlyPayment,
    totalPayment: result.totalPayment,
    totalInterest: result.totalInterest,
    schedule: result.amortizationSchedule,
  );
}

// -------------------------------------------------------------- Business

enum RepaymentSchedule { dailyDebit, weekly, monthly }

class BusinessLoanResult {
  const BusinessLoanResult({
    required this.principal,
    required this.netDisbursed,
    required this.originationFee,
    required this.monthlyPayment,
    required this.installmentAmount,
    required this.frequencyLabel,
    required this.totalInstallmentCycles,
    required this.totalPayment,
    required this.totalInterest,
    required this.schedule,
  });

  final double principal;
  final double netDisbursed;
  final double originationFee;
  final double monthlyPayment;

  /// The monthly figure restated at the repayment frequency the lender debits
  /// at. A daily debit is the same money, felt very differently.
  final double installmentAmount;
  final String frequencyLabel;
  final int totalInstallmentCycles;
  final double totalPayment;
  final double totalInterest;
  final List<AmortizationRow> schedule;
}

BusinessLoanResult calculateBusinessLoan({
  required double principal,
  required int termMonths,
  required double annualInterestRate,
  required RepaymentSchedule repaymentSchedule,
  required double originationFeePercent,
}) {
  final LoanCalculationResult result = calculateAmortization(
    principal: principal,
    annualInterestRate: annualInterestRate,
    termMonths: termMonths,
  );

  double installmentAmount = result.monthlyPayment;
  String frequencyLabel = 'Monthly Amortization';
  double cycles = termMonths.toDouble();

  if (repaymentSchedule == RepaymentSchedule.weekly) {
    installmentAmount = (result.monthlyPayment * 12) / 52;
    frequencyLabel = 'Weekly Payment';
    cycles = termMonths * 4.33;
  } else if (repaymentSchedule == RepaymentSchedule.dailyDebit) {
    // 260 banking days a year, not 365.
    installmentAmount = (result.monthlyPayment * 12) / 260;
    frequencyLabel = 'Daily Banking Debit';
    cycles = termMonths * 21.6;
  }

  final double originationFee = principal * (originationFeePercent / 100);

  return BusinessLoanResult(
    principal: principal,
    netDisbursed: principal - originationFee,
    originationFee: originationFee,
    monthlyPayment: result.monthlyPayment,
    installmentAmount: jsRound(installmentAmount).toDouble(),
    frequencyLabel: frequencyLabel,
    totalInstallmentCycles: jsRound(cycles),
    totalPayment: result.totalPayment,
    totalInterest: result.totalInterest,
    schedule: result.amortizationSchedule,
  );
}

// --------------------------------------------------------- Consolidation

class DebtToConsolidate {
  const DebtToConsolidate({
    required this.id,
    required this.name,
    required this.balance,
    required this.monthlyInterestRate,
    required this.currentMonthlyPayment,
  });

  final String id;
  final String name;
  final double balance;
  final double monthlyInterestRate;
  final double currentMonthlyPayment;
}

class ConsolidationResult {
  const ConsolidationResult({
    required this.totalBalance,
    required this.totalCurrentMonthlyPayment,
    required this.newMonthlyPayment,
    required this.monthlyCashflowRelief,
    required this.currentTotalInterest,
    required this.newTotalInterest,
    required this.totalPayment,
    required this.totalInterestSavings,
    required this.newTermMonths,
    required this.schedule,
  });

  final double totalBalance;
  final double totalCurrentMonthlyPayment;
  final double newMonthlyPayment;
  final double monthlyCashflowRelief;
  final double currentTotalInterest;
  final double newTotalInterest;
  final double totalPayment;
  final double totalInterestSavings;
  final int newTermMonths;
  final List<AmortizationRow> schedule;
}

/// Rolling several debts into one loan.
///
/// The "current" interest it compares against is a FLAT 18 MONTH ESTIMATE at
/// each debt's monthly rate, not a real payoff simulation. That is the
/// prototype's assumption and it flatters consolidation whenever the existing
/// debts would actually clear sooner. Ported unchanged, and named here so
/// nobody reads the saving as exact.
ConsolidationResult calculateDebtConsolidation({
  required List<DebtToConsolidate> debts,
  required double newLoanMonthlyRate,
  required int newTermMonths,
}) {
  final double totalBalance = debts.fold<double>(
      0, (double s, DebtToConsolidate d) => s + d.balance);
  final double totalCurrentMonthlyPayment = debts.fold<double>(
      0, (double s, DebtToConsolidate d) => s + d.currentMonthlyPayment);
  final double currentTotalInterest = debts.fold<double>(
      0,
      (double s, DebtToConsolidate d) =>
          s + (d.balance * (d.monthlyInterestRate / 100) * 18));

  final LoanCalculationResult newLoan = calculateAmortization(
    principal: totalBalance,
    annualInterestRate: newLoanMonthlyRate * 12,
    termMonths: newTermMonths,
    rateType: RateType.flatAddon,
  );

  return ConsolidationResult(
    totalBalance: totalBalance,
    totalCurrentMonthlyPayment: totalCurrentMonthlyPayment,
    newMonthlyPayment: newLoan.monthlyPayment,
    monthlyCashflowRelief: jsRound(math.max(
            0, totalCurrentMonthlyPayment - newLoan.monthlyPayment))
        .toDouble(),
    currentTotalInterest: jsRound(currentTotalInterest).toDouble(),
    newTotalInterest: newLoan.totalInterest,
    totalPayment: newLoan.totalPayment,
    totalInterestSavings:
        jsRound(math.max(0, currentTotalInterest - newLoan.totalInterest))
            .toDouble(),
    newTermMonths: newTermMonths,
    schedule: newLoan.amortizationSchedule,
  );
}
