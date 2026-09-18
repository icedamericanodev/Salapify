// The core data model, ported from the prototype's src/types.ts.
// Only the types the app actually reads today are here. The rest arrive with
// the tabs that need them, so nothing sits unused.

enum TransactionType { expense, income, transfer }

enum AccountKind {
  cash,
  bank,
  gcash,
  maya,
  debit,
  credit,
  loan,
  mortgage,
  investment,
  receivable,
}

/// The kinds that count as spendable cash. Credit limits and investments are
/// deliberately NOT here: money you can borrow is not money you have.
const Set<AccountKind> liquidKinds = <AccountKind>{
  AccountKind.cash,
  AccountKind.gcash,
  AccountKind.maya,
  AccountKind.bank,
  AccountKind.debit,
};

enum DebtDirection { iOwe, owedToMe }

enum DecisionScenario { conservative, optimistic }

/// The seven income shapes the prototype recognises. The names map one to one
/// onto src/types.ts, so a value can never silently mean something else.
enum IncomeStreamType {
  weeklyIncome,
  semimonthlySalary,
  monthlySalary,
  freelance,
  irregular,
  thirteenthMonth,
  remittance,
}

enum UpcomingItemType {
  bill,
  subscription,
  payday,
  debt,
  remittance,
  rent,
  insurance,
  tuition,
  government,
}

class Account {
  const Account({
    required this.id,
    required this.name,
    required this.kind,
    required this.institution,
    required this.balance,
    required this.monogram,
    this.creditLimit,
    this.interestRate,
    this.accountNumber,
    this.notes,
  });

  final String id;
  final String name;
  final AccountKind kind;
  final String institution;
  final double balance;
  final String monogram;
  final double? creditLimit;
  final double? interestRate;
  final String? accountNumber;
  final String? notes;

  bool get isLiquid => liquidKinds.contains(kind);
}

class Transaction {
  const Transaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.category,
    required this.accountId,
    required this.date,
    required this.createdAt,
    this.subcategory,
    this.toAccountId,
    this.merchant,
    this.note,
  });

  final String id;
  final TransactionType type;
  final double amount;
  final String category;
  final String accountId;

  /// ISO date, YYYY-MM-DD.
  final String date;

  /// Milliseconds since epoch, the way the prototype stores it.
  final int createdAt;
  final String? subcategory;
  final String? toAccountId;
  final String? merchant;
  final String? note;
}

class Debt {
  const Debt({
    required this.id,
    required this.person,
    required this.direction,
    required this.totalAmount,
    required this.paidAmount,
    required this.isSettled,
    this.dueDate,
  });

  final String id;
  final String person;
  final DebtDirection direction;
  final double totalAmount;
  final double paidAmount;
  final bool isSettled;
  final String? dueDate;

  double get remaining => (totalAmount - paidAmount).clamp(0, double.infinity);
}

class Budget {
  const Budget({
    required this.category,
    required this.limit,
    required this.emoji,
  });

  final String category;
  final double limit;
  final String emoji;
}

class Goal {
  const Goal({
    required this.id,
    required this.name,
    required this.emoji,
    required this.targetAmount,
    required this.currentAmount,
    required this.targetDate,
    required this.monthlyTarget,
  });

  final String id;
  final String name;
  final String emoji;
  final double targetAmount;
  final double currentAmount;
  final String targetDate;
  final double monthlyTarget;
}

class UpcomingItem {
  const UpcomingItem({
    required this.id,
    required this.name,
    required this.amount,
    required this.dueDate,
    required this.type,
    this.isIncome = false,
    this.isPaid = false,
  });

  final String id;
  final String name;
  final double amount;

  /// A human label such as "Today", "Sunday" or "Sep 18", exactly as the
  /// prototype stores it.
  final String dueDate;
  final UpcomingItemType type;
  final bool isIncome;
  final bool isPaid;
}

class PaydayCycle {
  const PaydayCycle({
    required this.cycleType,
    required this.lastPayday,
    required this.nextPayday,
    required this.daysToPayday,
    required this.expectedIncome,
  });

  final String cycleType;
  final String lastPayday;
  final String nextPayday;
  final int daysToPayday;
  final double expectedIncome;
}

class BillItem {
  const BillItem({
    required this.id,
    required this.name,
    required this.amount,
    required this.dueDate,
    this.isPaid = false,
  });

  final String id;
  final String name;
  final double amount;
  final String dueDate;
  final bool isPaid;
}

class InstallmentPlan {
  const InstallmentPlan({
    required this.id,
    required this.name,
    required this.installmentAmount,
    this.isSettled = false,
  });

  final String id;
  final String name;
  final double installmentAmount;
  final bool isSettled;
}

class IncomeStream {
  const IncomeStream({
    required this.id,
    required this.name,
    required this.type,
    required this.expectedAmount,
  });

  final String id;
  final String name;
  final IncomeStreamType type;
  final double expectedAmount;
}

/// What computeSafeToSpend returns. Mirrors SafeToSpendAnalysis in types.ts.
class SafeToSpendAnalysis {
  const SafeToSpendAnalysis({
    required this.scenario,
    required this.safeToSpendToday,
    required this.safeToSpendUntilPayday,
    required this.safeToSave,
    required this.amountReserved,
    required this.cashRunwayDays,
    required this.cashRunwayMonths,
    required this.reservedBills,
    required this.reservedDebtMinimums,
    required this.reservedInstallments,
    required this.emergencyBuffer,
    required this.totalLiquidCash,
    required this.totalExpectedInflow,
    required this.daysToPayday,
  });

  final DecisionScenario scenario;
  final double safeToSpendToday;
  final double safeToSpendUntilPayday;
  final double safeToSave;
  final double amountReserved;
  final int cashRunwayDays;
  final double cashRunwayMonths;
  final double reservedBills;
  final double reservedDebtMinimums;
  final double reservedInstallments;
  final double emergencyBuffer;
  final double totalLiquidCash;
  final double totalExpectedInflow;
  final int daysToPayday;
}
