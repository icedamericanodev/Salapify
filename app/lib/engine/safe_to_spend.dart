import 'dart:math' as math;

import '../models/models.dart';
import 'js_round.dart';

/// Safe to Spend, ported line for line from src/utils/safeToSpendEngine.ts.
///
/// The numbering in the comments matches the numbered steps in the prototype
/// so the two can be read side by side. Nothing here was "improved" on the way
/// across: if a figure looks odd, it looks odd in the prototype too, and that
/// is a product question rather than a porting one.
SafeToSpendAnalysis computeSafeToSpend({
  required List<Account> accounts,
  required List<Transaction> transactions,
  required List<BillItem> bills,
  required double debtsIOwe,
  required List<InstallmentPlan> installments,
  required List<IncomeStream> incomeStreams,
  required PaydayCycle payday,
  required DecisionScenario scenario,
  double? monthlyLivingExpenseOverride,

  /// Injectable clock. The runway step reads "the last 30 days", which is
  /// untestable against a real clock.
  DateTime? now,
}) {
  final int nowMs = (now ?? DateTime.now()).millisecondsSinceEpoch;

  // 1. Liquid cash. Investments and credit limits are excluded on purpose.
  final double totalLiquidCash = accounts
      .where((Account a) => a.isLiquid)
      .fold<double>(0, (double sum, Account a) => sum + a.balance);

  // 2. Bills still owed this cycle.
  final double totalBillsAmount = bills
      .where((BillItem b) => !b.isPaid)
      .fold<double>(0, (double sum, BillItem b) => sum + b.amount);

  // 3. Active installment obligations.
  final double totalInstallmentsObligation = installments
      .where((InstallmentPlan i) => !i.isSettled)
      .fold<double>(0, (double sum, InstallmentPlan i) => sum + i.installmentAmount);

  // 4. Debt minimums, estimated at 8 percent of what is outstanding.
  final double debtMinimums = math.max(0, debtsIOwe * 0.08);

  // 5. Expected inflow before the next payday. The conservative scenario takes
  //    a haircut on money that is not guaranteed.
  double totalExpectedInflow = 0;
  for (final IncomeStream stream in incomeStreams) {
    double amountToAdd = stream.expectedAmount;

    if (scenario == DecisionScenario.conservative) {
      if (stream.type == IncomeStreamType.freelance ||
          stream.type == IncomeStreamType.irregular) {
        amountToAdd = stream.expectedAmount * 0.5;
      } else if (stream.type == IncomeStreamType.thirteenthMonth) {
        // A year-end bonus does not help pace this fortnight.
        amountToAdd = 0;
      }
    }

    totalExpectedInflow += amountToAdd;
  }

  // Fall back to the declared payday income when no streams are set up.
  if (totalExpectedInflow == 0 && payday.expectedIncome > 0) {
    totalExpectedInflow = payday.expectedIncome;
  }

  // 6. Emergency buffer held back from spendable cash.
  final double bufferRate =
      scenario == DecisionScenario.conservative ? 0.15 : 0.05;
  final double emergencyBuffer = totalLiquidCash * bufferRate;

  // 7. Everything that must stay put.
  final double reservedBills = scenario == DecisionScenario.conservative
      ? totalBillsAmount * 1.1
      : totalBillsAmount;
  final double reservedInstallments = totalInstallmentsObligation;
  final double reservedDebt = debtMinimums;
  final double amountReserved = jsRound(
    reservedBills + reservedInstallments + reservedDebt + emergencyBuffer,
  ).toDouble();

  // 8. What is genuinely free to spend, split 85 / 15 between spending and
  //    saving.
  final int daysToPayday = math.max(1, payday.daysToPayday);
  final double uncommittedCash = math.max(0, totalLiquidCash - amountReserved);

  final double safeToSpendUntilPayday = jsRound(uncommittedCash * 0.85).toDouble();
  final double safeToSave = jsRound(uncommittedCash * 0.15).toDouble();
  final double safeToSpendToday =
      math.max(0, jsRound(safeToSpendUntilPayday / daysToPayday)).toDouble();

  // 9. Cash runway, from the burn rate of the last 30 days. A very quiet month
  //    (under 5,000 logged) is treated as not enough signal, and the override
  //    or the 28,000 default stands in.
  final int thirtyDaysAgo = nowMs - 30 * 86400000;
  final double recentExpenses = transactions
      .where((Transaction t) =>
          t.type == TransactionType.expense && t.createdAt >= thirtyDaysAgo)
      .fold<double>(0, (double sum, Transaction t) => sum + t.amount);

  final double baselineMonthlyExpense = recentExpenses > 5000
      ? recentExpenses
      : (monthlyLivingExpenseOverride ?? 28000);

  final double dailyBurnRate = math.max(100, baselineMonthlyExpense / 30);
  final int cashRunwayDays = jsRound(totalLiquidCash / dailyBurnRate);
  final double cashRunwayMonths = jsRound1(cashRunwayDays / 30);

  return SafeToSpendAnalysis(
    scenario: scenario,
    safeToSpendToday: safeToSpendToday,
    safeToSpendUntilPayday: safeToSpendUntilPayday,
    safeToSave: safeToSave,
    amountReserved: amountReserved,
    cashRunwayDays: cashRunwayDays,
    cashRunwayMonths: cashRunwayMonths,
    reservedBills: jsRound(reservedBills).toDouble(),
    reservedDebtMinimums: jsRound(reservedDebt).toDouble(),
    reservedInstallments: jsRound(reservedInstallments).toDouble(),
    emergencyBuffer: jsRound(emergencyBuffer).toDouble(),
    totalLiquidCash: jsRound(totalLiquidCash).toDouble(),
    totalExpectedInflow: jsRound(totalExpectedInflow).toDouble(),
    daysToPayday: daysToPayday,
  );
}
