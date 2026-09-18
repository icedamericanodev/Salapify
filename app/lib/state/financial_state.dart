import 'package:flutter/foundation.dart';

import '../data/seed_data.dart';
import '../design/tokens.dart';
import '../core/money/safe_to_spend.dart';
import '../models/models.dart';

/// The single store the screens read, standing in for the prototype's
/// FinancialContext. It holds the ledger and derives everything else, so no
/// screen ever computes money on its own.
class FinancialState extends ChangeNotifier {
  FinancialState({this.clock}) {
    _transactions = SeedData.transactions();
    _upcoming = List<UpcomingItem>.of(SeedData.upcoming);
    _debts = List<Debt>.of(SeedData.debts);
  }

  /// Injectable clock, so a test can pin "today".
  final DateTime? clock;

  late List<Transaction> _transactions;
  late List<UpcomingItem> _upcoming;
  late List<Debt> _debts;

  ThemeMode2 _theme = ThemeMode2.gabi;
  DecisionScenario _scenario = DecisionScenario.conservative;
  ProfileEntity? _activeProfile;
  MovementFilter _movementFilter = MovementFilter.all;

  ThemeMode2 get theme => _theme;
  DecisionScenario get scenario => _scenario;

  /// null means "All Profiles", the prototype's 'all' tab.
  ProfileEntity? get activeProfile => _activeProfile;
  MovementFilter get movementFilter => _movementFilter;

  DateTime get now => clock ?? DateTime.now();

  List<Account> get accounts => SeedData.accounts;
  List<Transaction> get transactions =>
      List<Transaction>.unmodifiable(_transactions);
  List<Debt> get debts => List<Debt>.unmodifiable(_debts);
  List<Budget> get budgets => SeedData.budgets;
  List<CategoryInfo> get categories => SeedData.categories;
  List<Goal> get goals => SeedData.goals;
  List<UpcomingItem> get upcoming => List<UpcomingItem>.unmodifiable(_upcoming);
  List<BillItem> get bills => SeedData.bills;
  List<IncomeStream> get incomeStreams => SeedData.incomeStreams;
  List<InstallmentPlan> get installments => SeedData.installments;
  PaydayCycle get payday => SeedData.payday;

  /// Header badges. Static for now: the notification engine and the
  /// collaboration hub are later migration steps, and a badge that lies is
  /// worse than one that is honest about where its number comes from.
  int get unreadNotificationsCount => SeedData.unreadNotifications;
  int get memberCount => SeedData.memberCount;

  void toggleTheme() {
    _theme = _theme == ThemeMode2.hapon ? ThemeMode2.gabi : ThemeMode2.hapon;
    notifyListeners();
  }

  void setScenario(DecisionScenario next) {
    if (_scenario == next) return;
    _scenario = next;
    notifyListeners();
  }

  void setActiveProfile(ProfileEntity? next) {
    if (_activeProfile == next) return;
    _activeProfile = next;
    notifyListeners();
  }

  void setMovementFilter(MovementFilter next) {
    if (_movementFilter == next) return;
    _movementFilter = next;
    notifyListeners();
  }

  /// Ticks an upcoming item off. It leaves the ledger alone on purpose: this
  /// marks an EXPECTATION as met, it does not log a transaction, and the
  /// prototype behaves the same way.
  /// Records a debt the user just entered in the Add Debt sheet.
  ///
  /// It goes to the front of the list because the screens that read debts sort
  /// by due date and a brand new row with no due date would otherwise land
  /// somewhere the person who just typed it would not think to look.
  ///
  /// This lives in memory only, like every other write on this store today:
  /// the prototype's local storage layer is a later migration step, so a debt
  /// added now is gone on the next cold start. That is honest rather than
  /// desirable, and the sheet says so when it saves.
  void addDebt(Debt debt) {
    _debts = <Debt>[debt, ..._debts];
    notifyListeners();
  }

  void markUpcomingPaid(String id) {
    final int i = _upcoming.indexWhere((UpcomingItem u) => u.id == id);
    if (i == -1 || _upcoming[i].isPaid) return;
    final UpcomingItem old = _upcoming[i];
    _upcoming[i] = UpcomingItem(
      id: old.id,
      name: old.name,
      amount: old.amount,
      dueDate: old.dueDate,
      type: old.type,
      isIncome: old.isIncome,
      isPaid: true,
      category: old.category,
    );
    notifyListeners();
  }

  /// Which profile an upcoming row belongs to, ported from getItemProfile in
  /// src/components/ComingUpCard.tsx. The prototype does not store this, it
  /// reads the name, so the keyword lists are the behaviour rather than a
  /// convenience.
  ProfileEntity profileOf(UpcomingItem item) =>
      _inferProfile(item.name, item.category ?? '');

  /// The same inference for a ledger entry.
  ///
  /// A transaction MAY carry a stored profile, and when it does that wins:
  /// the prototype reads `t.profile || 'personal'` and only guesses when the
  /// field is absent. The guess reads the merchant rather than the note,
  /// because the merchant is the name of the thing, and it falls back to the
  /// category.
  ProfileEntity profileOfTransaction(Transaction t) =>
      t.profile ?? _inferProfile(t.merchant ?? t.category, t.category);

  ProfileEntity _inferProfile(String rawName, String rawCategory) {
    final String name = rawName.toLowerCase();
    final String category = rawCategory.toLowerCase();

    const List<String> businessWords = <String>[
      'bir',
      'tax',
      'payroll',
      'freelance',
      'business',
      'client',
      'vendor',
      'dti',
      'sec',
    ];
    for (final String w in businessWords) {
      if (name.contains(w)) return ProfileEntity.business;
    }
    if (category.contains('business')) return ProfileEntity.business;

    const List<String> householdWords = <String>[
      'meralco',
      'maynilad',
      'manila water',
      'water',
      'electric',
      'converge',
      'pldt',
      'rent',
      'hoa',
      'condo',
      'household',
      'groceries',
    ];
    for (final String w in householdWords) {
      if (name.contains(w)) return ProfileEntity.household;
    }
    if (category.contains('household') || category.contains('utility')) {
      return ProfileEntity.household;
    }

    return ProfileEntity.personal;
  }

  /// Unpaid upcoming rows for the selected profile.
  List<UpcomingItem> get profileUpcoming => _upcoming
      .where((UpcomingItem u) => !u.isPaid)
      .where(
        (UpcomingItem u) =>
            _activeProfile == null || profileOf(u) == _activeProfile,
      )
      .toList();

  /// How many unpaid rows a profile tab should show on its counter.
  int upcomingCountFor(ProfileEntity? profile) => _upcoming
      .where((UpcomingItem u) => !u.isPaid)
      .where((UpcomingItem u) => profile == null || profileOf(u) == profile)
      .length;

  /// The rows actually listed, after the inflow / outflow filter.
  List<UpcomingItem> get displayedUpcoming =>
      profileUpcoming.where((UpcomingItem u) {
        switch (_movementFilter) {
          case MovementFilter.inflow:
            return u.countsAsIncome;
          case MovementFilter.outflow:
            return !u.countsAsIncome;
          case MovementFilter.all:
            return true;
        }
      }).toList();

  double get totalInflows => profileUpcoming
      .where((UpcomingItem u) => u.countsAsIncome)
      .fold<double>(0, (double s, UpcomingItem u) => s + u.amount);

  double get totalOutflows => profileUpcoming
      .where((UpcomingItem u) => !u.countsAsIncome)
      .fold<double>(0, (double s, UpcomingItem u) => s + u.amount);

  double get netMovement => totalInflows - totalOutflows;

  /// Everything a person owes, across unsettled debts pointing outward.
  double get debtsIOwe => debts
      .where((Debt d) => !d.isSettled && d.direction == DebtDirection.iOwe)
      .fold<double>(0, (double sum, Debt d) => sum + d.remaining);

  /// Everything owed back to them.
  double get debtsOwedToMe => debts
      .where((Debt d) => !d.isSettled && d.direction == DebtDirection.owedToMe)
      .fold<double>(0, (double sum, Debt d) => sum + d.remaining);

  /// The soonest unsettled debt carrying a due date.
  Debt? get nextDueDebt {
    final List<Debt> dated =
        debts.where((Debt d) => !d.isSettled && d.dueDate != null).toList()
          ..sort(
            (Debt a, Debt b) => (a.dueDate ?? '').compareTo(b.dueDate ?? ''),
          );
    return dated.isEmpty ? null : dated.first;
  }

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

  /// The account's short name, the way the prototype labels a ledger row:
  /// the first word only, so "BPI Preferred Payroll" reads as "BPI".
  String accountShortName(String accountId) {
    for (final Account a in accounts) {
      if (a.id == accountId) return a.name.split(' ').first;
    }
    return 'Account';
  }

  /// Newest first, for the Latest card.
  List<Transaction> get latestTransactions {
    final List<Transaction> sorted = List<Transaction>.of(_transactions)
      ..sort(
        (Transaction a, Transaction b) => b.createdAt.compareTo(a.createdAt),
      );
    return sorted;
  }
}

/// Which side of the cash movement the Coming Up list is showing.
enum MovementFilter { all, inflow, outflow }
