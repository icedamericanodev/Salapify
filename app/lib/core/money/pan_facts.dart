import '../../models/models.dart';

/// Everything Pan is allowed to know, gathered once, with no live objects.
///
/// Pan reads THIS and nothing else. It cannot reach FinancialState, cannot
/// reach the store, and has no way to write anything, which is what makes the
/// whole assistant a pure function of a value: hand it the same facts twice
/// and it answers identically, and a test can hand it any ledger at all
/// without building an app.
///
/// It is also the privacy boundary written down. Whatever is not in this class
/// is something Pan physically cannot mention.
class PanFacts {
  const PanFacts({
    required this.now,
    required this.accounts,
    required this.transactions,
    required this.debts,
    required this.budgets,
    required this.goals,
    required this.bills,
    required this.installments,
    required this.upcoming,
    required this.payday,
    required this.liquidCash,
    required this.assets,
    required this.liabilities,
    required this.owed,
    required this.owedToMe,
    required this.safeToSpendUntilPayday,
    required this.safeToSpendPerDay,
    required this.amountReserved,
    required this.cashRunwayMonths,
    required this.monthIn,
    required this.monthOut,
    required this.spendingByCategory,
    required this.hasSampleData,
    required this.phoneRemindersOn,
    required this.unreadReminders,
  });

  final DateTime now;

  final List<Account> accounts;
  final List<Transaction> transactions;
  final List<Debt> debts;
  final List<Budget> budgets;
  final List<Goal> goals;
  final List<BillItem> bills;
  final List<InstallmentPlan> installments;
  final List<UpcomingItem> upcoming;
  final PaydayCycle payday;

  /// Money that can actually be spent today. Credit limits are NOT in here:
  /// money you can borrow is not money you have.
  final double liquidCash;

  /// Kept APART and never summed, the rule every summary in this app follows.
  final double assets;
  final double liabilities;

  final double owed;
  final double owedToMe;

  final double safeToSpendUntilPayday;
  final double safeToSpendPerDay;
  final double amountReserved;
  final double cashRunwayMonths;

  /// This calendar month, from the person's own entries.
  final double monthIn;
  final double monthOut;
  final List<({String category, double amount})> spendingByCategory;

  final bool hasSampleData;
  final bool phoneRemindersOn;
  final int unreadReminders;

  /// True when there is genuinely nothing to talk about yet.
  bool get isEmpty => accounts.isEmpty && transactions.isEmpty;

  double get netWorth => assets - liabilities;
}
