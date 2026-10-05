import {
  Account,
  BillItem,
  DecisionScenario,
  IncomeStream,
  InstallmentPlan,
  PaydayCycle,
  SafeToSpendAnalysis,
  Transaction,
} from '../types';
import { convertToPhp } from './currencies';

export interface ComputeSafeToSpendOptions {
  accounts: Account[];
  transactions: Transaction[];
  bills: BillItem[];
  debtsIOwe: number;
  installments: InstallmentPlan[];
  incomeStreams: IncomeStream[];
  payday: PaydayCycle;
  scenario: DecisionScenario;
  monthlyLivingExpenseOverride?: number;
}

export function computeSafeToSpend(options: ComputeSafeToSpendOptions): SafeToSpendAnalysis {
  const {
    accounts,
    transactions,
    bills,
    debtsIOwe,
    installments,
    incomeStreams,
    payday,
    scenario,
    monthlyLivingExpenseOverride,
  } = options;

  // 1. Calculate liquid cash (Cash, GCash, Maya, Bank Debit/Savings)
  // Exclude investments and credit limits
  const liquidKinds = ['cash', 'gcash', 'maya', 'bank', 'debit'];
  const totalLiquidCash = accounts
    .filter((a) => liquidKinds.includes(a.kind))
    .reduce((sum, a) => sum + convertToPhp(a.balance, a.currency || 'PHP'), 0);

  // 2. Calculate known bills due in the upcoming cycle
  const pendingBills = bills.filter((b) => !b.isPaid);
  const totalBillsAmount = pendingBills.reduce((sum, b) => sum + b.amount, 0);

  // 3. Active installments monthly obligation
  const activeInstallments = installments.filter((i) => !i.isSettled);
  const totalInstallmentsObligation = activeInstallments.reduce(
    (sum, i) => sum + i.installmentAmount,
    0
  );

  // 4. Debt minimum payments estimation (e.g. 10% of outstanding debt or minimum amortizations)
  const debtMinimums = Math.max(0, debtsIOwe * 0.08);

  // 5. Expected Inflow until next payday based on income streams
  // In conservative scenario: include only confirmed salary and 50% of freelance/irregular.
  // In optimistic scenario: include 100% of confirmed + expected streams.
  let totalExpectedInflow = 0;
  for (const stream of incomeStreams) {
    let amountToAdd = stream.expectedAmount;

    if (scenario === 'conservative') {
      if (stream.type === 'freelance' || stream.type === 'irregular') {
        amountToAdd = stream.expectedAmount * 0.5; // Haircut for volatility
      } else if (stream.type === 'thirteenth_month') {
        amountToAdd = 0; // Exclude year-end bonus from immediate sweldo pacing
      }
    }

    totalExpectedInflow += amountToAdd;
  }

  // Fallback to payday.expectedIncome if no streams declared
  if (totalExpectedInflow === 0 && payday.expectedIncome > 0) {
    totalExpectedInflow = payday.expectedIncome;
  }

  // 6. Emergency Buffer allocation (conservative reserves 15% buffer, optimistic reserves 5%)
  const bufferRate = scenario === 'conservative' ? 0.15 : 0.05;
  const emergencyBuffer = totalLiquidCash * bufferRate;

  // 7. Total Amount that must remain reserved
  const reservedBills = scenario === 'conservative' ? totalBillsAmount * 1.1 : totalBillsAmount;
  const reservedInstallments = totalInstallmentsObligation;
  const reservedDebt = debtMinimums;
  const amountReserved = Math.round(
    reservedBills + reservedInstallments + reservedDebt + emergencyBuffer
  );

  // 8. Safe to Spend calculation
  // Total available money minus non-negotiable commitments
  const daysToPayday = Math.max(1, payday.daysToPayday);
  const uncommittedCash = Math.max(0, totalLiquidCash - amountReserved);

  // For the current cutoff period
  const safeToSpendUntilPayday = Math.round(uncommittedCash * 0.85); // 85% safe to spend, 15% safe to save
  const safeToSave = Math.round(uncommittedCash * 0.15);
  const safeToSpendToday = Math.max(0, Math.round(safeToSpendUntilPayday / daysToPayday));

  // 9. Cash runway calculation based on average burn rate
  // Calculate average daily expenses from the last 30 days of transactions
  const thirtyDaysAgo = Date.now() - 30 * 86400000;
  const recentExpenses = transactions
    .filter((t) => t.type === 'expense' && t.createdAt >= thirtyDaysAgo)
    .reduce((sum, t) => sum + t.amount, 0);

  const baselineMonthlyExpense = recentExpenses > 5000
    ? recentExpenses
    : (monthlyLivingExpenseOverride || 28000);

  const dailyBurnRate = Math.max(100, baselineMonthlyExpense / 30);
  const cashRunwayDays = Math.round(totalLiquidCash / dailyBurnRate);
  const cashRunwayMonths = Math.round((cashRunwayDays / 30) * 10) / 10;

  return {
    scenario,
    safeToSpendToday,
    safeToSpendUntilPayday,
    safeToSave,
    amountReserved,
    cashRunwayDays,
    cashRunwayMonths,
    reservedBreakdown: {
      bills: Math.round(reservedBills),
      debtMinimums: Math.round(reservedDebt),
      installments: Math.round(reservedInstallments),
      emergencyBuffer: Math.round(emergencyBuffer),
    },
    totalLiquidCash: Math.round(totalLiquidCash),
    totalExpectedInflow: Math.round(totalExpectedInflow),
    daysToPayday,
  };
}
