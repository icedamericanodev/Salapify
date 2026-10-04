import 'dart:math' as math;

import '../../models/models.dart';
import 'js_round.dart';
import 'money.dart';

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
      .fold<double>(0, (double sum, Account a) => sum + a.balance.pesos);

  // 2. Bills still owed this cycle.
  final double totalBillsAmount = bills
      .where((BillItem b) => !b.isPaid)
      // Read as pesos rather than summed as Money, DELIBERATELY. Every
      // figure this engine produces is still a double, so folding in
      // centavos here would only convert back two lines later and change
      // the arithmetic of a golden-locked engine for no gain. The engine
      // moves whole, with its outputs, in the next increment.
      .fold<double>(0, (double sum, BillItem b) => sum + b.amount.pesos);

  // 3. Active installment obligations.
  final double totalInstallmentsObligation = installments
      .where((InstallmentPlan i) => !i.isSettled)
      .fold<double>(
        0,
        // Capped at the balance, so Safe to Spend stops holding back a
        // whole instalment for a plan with less than one left on it.
        (double sum, InstallmentPlan i) =>
            sum + minMoney(i.installmentAmount, i.runningBalance).pesos,
      );

  // 4. Debt minimums, estimated at 8 percent of what is outstanding.
  final double debtMinimums = math.max(0, debtsIOwe * 0.08);

  // 5. Expected inflow before the next payday. The conservative scenario takes
  //    a haircut on money that is not guaranteed.
  double totalExpectedInflow = 0;
  for (final IncomeStream stream in incomeStreams) {
    double amountToAdd = stream.expectedAmount.pesos;

    if (scenario == DecisionScenario.conservative) {
      if (stream.type == IncomeStreamType.freelance ||
          stream.type == IncomeStreamType.irregular) {
        amountToAdd = stream.expectedAmount.pesos * 0.5;
      } else if (stream.type == IncomeStreamType.thirteenthMonth) {
        // A year-end bonus does not help pace this fortnight.
        amountToAdd = 0;
      }
    }

    totalExpectedInflow += amountToAdd;
  }

  // Fall back to the declared payday income when no streams are set up.
  if (totalExpectedInflow == 0 && payday.expectedIncome.isPositive) {
    totalExpectedInflow = payday.expectedIncome.pesos;
  }

  // 6. Emergency buffer held back from spendable cash.
  final double bufferRate = scenario == DecisionScenario.conservative
      ? 0.15
      : 0.05;
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

  final double safeToSpendUntilPayday = jsRound(
    uncommittedCash * 0.85,
  ).toDouble();
  final double safeToSave = jsRound(uncommittedCash * 0.15).toDouble();
  final double safeToSpendToday = math
      .max(0, jsRound(safeToSpendUntilPayday / daysToPayday))
      .toDouble();

  // 9. Cash runway, from the burn rate of the last 30 days. A very quiet month
  //    (under 5,000 logged) is treated as not enough signal, and the override
  //    or the 28,000 default stands in.
  final int thirtyDaysAgo = nowMs - 30 * 86400000;
  // STATUS IS CHECKED HERE TOO, and this one reaches further than the alert:
  // the burn rate feeds the runway, which feeds the headline figure on Home.
  // An entry marked excluded, duplicate or taken back used to keep inflating
  // it, so the number a person reads first was built partly from money that
  // did not move.
  final double recentExpenses = transactions
      .where(
        (Transaction t) =>
            t.countsTowardTotals &&
            t.type == TransactionType.expense &&
            t.createdAt >= thirtyDaysAgo,
      )
      .fold<double>(0, (double sum, Transaction t) => sum + t.amount.pesos);

  // Whether the figure below is the person's own spending or the stand-in.
  //
  // The 5,000 test and the 28,000 default are the prototype's, reproduced
  // deliberately and locked by golden vectors, so neither moves here. What
  // moves is that the ANSWER now says which of the two it used. Without
  // that, a screen cannot tell a measurement from a placeholder, and two of
  // them called the placeholder "your recent burn rate".
  final bool measuredBurn =
      recentExpenses > 5000 || monthlyLivingExpenseOverride != null;

  final double baselineMonthlyExpense = recentExpenses > 5000
      ? recentExpenses
      : (monthlyLivingExpenseOverride ?? 28000);

  final double dailyBurnRate = math.max(100, baselineMonthlyExpense / 30);
  final int cashRunwayDays = jsRound(totalLiquidCash / dailyBurnRate);
  final double cashRunwayMonths = jsRound1(cashRunwayDays / 30);

  // THE ONE BOUNDARY, and the reason every golden vector survives P2.1's last
  // increment untouched.
  //
  // Everything above stays in pesos, exactly as the prototype computes it,
  // because this file says in its own header that nothing was improved on the
  // way across. Working in centavos internally would be MORE precise and
  // therefore WRONG: it would round differently from
  // src/utils/safeToSpendEngine.ts in the cases the vectors do not cover, and
  // the port would stop being a port.
  //
  // Each figure is already a whole peso by the time it reaches here, since
  // every one of them goes through `jsRound` first. `Money.pesos` says that
  // out loud and refuses to compile if it ever stops being true, where
  // `Money.fromDouble` would silently accept a fraction and hide the day the
  // engine's contract changed.
  Money whole(double pesos) => Money.pesos(jsRound(pesos));

  return SafeToSpendAnalysis(
    scenario: scenario,
    safeToSpendToday: whole(safeToSpendToday),
    safeToSpendUntilPayday: whole(safeToSpendUntilPayday),
    safeToSave: whole(safeToSave),
    amountReserved: whole(amountReserved),
    cashRunwayDays: cashRunwayDays,
    cashRunwayMonths: cashRunwayMonths,
    runwayFromLoggedSpending: measuredBurn,
    reservedBills: whole(reservedBills),
    reservedDebtMinimums: whole(reservedDebt),
    reservedInstallments: whole(reservedInstallments),
    emergencyBuffer: whole(emergencyBuffer),
    totalLiquidCash: whole(totalLiquidCash),
    totalExpectedInflow: whole(totalExpectedInflow),
    daysToPayday: daysToPayday,
  );
}
