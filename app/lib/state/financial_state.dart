import 'package:flutter/foundation.dart';

import '../data/seed_data.dart';
import '../design/tokens.dart';
import '../engine/safe_to_spend.dart';
import '../models/models.dart';

/// The single store the screens read, standing in for the prototype's
/// FinancialContext. It holds the ledger and derives everything else, so no
/// screen ever computes money on its own.
class FinancialState extends ChangeNotifier {
  FinancialState({this.clock}) {
    _transactions = SeedData.transactions();
  }

  /// Injectable clock, so a test can pin "today".
  final DateTime? clock;

  late List<Transaction> _transactions;

  ThemeMode2 _theme = ThemeMode2.gabi;
  DecisionScenario _scenario = DecisionScenario.conservative;

  ThemeMode2 get theme => _theme;
  DecisionScenario get scenario => _scenario;

  List<Account> get accounts => SeedData.accounts;
  List<Transaction> get transactions => List<Transaction>.unmodifiable(_transactions);
  List<Debt> get debts => SeedData.debts;
  List<Budget> get budgets => SeedData.budgets;
  List<Goal> get goals => SeedData.goals;
  List<UpcomingItem> get upcoming => SeedData.upcoming;
  List<BillItem> get bills => SeedData.bills;
  PaydayCycle get payday => SeedData.payday;

  void toggleTheme() {
    _theme = _theme == ThemeMode2.hapon ? ThemeMode2.gabi : ThemeMode2.hapon;
    notifyListeners();
  }

  void setScenario(DecisionScenario next) {
    if (_scenario == next) return;
    _scenario = next;
    notifyListeners();
  }

  /// Everything a person owes, across unsettled debts pointing outward.
  double get debtsIOwe => debts
      .where((Debt d) => !d.isSettled && d.direction == DebtDirection.iOwe)
      .fold<double>(0, (double sum, Debt d) => sum + d.remaining);

  /// Everything owed back to them.
  double get debtsOwedToMe => debts
      .where((Debt d) => !d.isSettled && d.direction == DebtDirection.owedToMe)
      .fold<double>(0, (double sum, Debt d) => sum + d.remaining);

  /// Liquid cash only. This is NOT net worth: it leaves out investments,
  /// receivables and every borrowing line on purpose.
  double get totalLiquidCash => accounts
      .where((Account a) => a.isLiquid)
      .fold<double>(0, (double sum, Account a) => sum + a.balance);

  SafeToSpendAnalysis get safeToSpendAnalysis => computeSafeToSpend(
        accounts: accounts,
        transactions: _transactions,
        bills: SeedData.bills,
        debtsIOwe: debtsIOwe,
        installments: SeedData.installments,
        incomeStreams: SeedData.incomeStreams,
        payday: payday,
        scenario: _scenario,
        now: clock,
      );

  double get safeToSpend => safeToSpendAnalysis.safeToSpendUntilPayday;
  double get safeToSpendPerDay => safeToSpendAnalysis.safeToSpendToday;

  /// Spending so far per budget category, used by the Budget Pulse card.
  double spentInCategory(String category) => _transactions
      .where((Transaction t) =>
          t.type == TransactionType.expense && t.category == category)
      .fold<double>(0, (double sum, Transaction t) => sum + t.amount);

  /// Newest first, for the Latest Transactions card.
  List<Transaction> get latestTransactions {
    final List<Transaction> sorted = List<Transaction>.of(_transactions)
      ..sort((Transaction a, Transaction b) => b.createdAt.compareTo(a.createdAt));
    return sorted;
  }
}
