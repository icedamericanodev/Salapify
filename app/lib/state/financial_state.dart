import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/seed_data.dart';
import '../data/snapshot.dart';
import '../data/store.dart';
import '../design/tokens.dart';
import '../core/money/debt.dart';
import '../core/money/installments.dart';
import '../core/money/ledger.dart';
import '../core/money/plan.dart';
import '../core/money/reconciliation.dart';
import '../core/money/safe_to_spend.dart';
import '../models/models.dart';

/// The single store the screens read, standing in for the prototype's
/// FinancialContext. It holds the ledger and derives everything else, so no
/// screen ever computes money on its own.
class FinancialState extends ChangeNotifier {
  /// [store] defaults to memory, and that default is chosen ON PURPOSE.
  ///
  /// The safe default is the one where forgetting costs nothing. A test or a
  /// preview that forgets to pass a store gets memory and writes no files on
  /// a CI runner; production forgetting to pass one would be a bug, and
  /// `main_wiring_test.dart` is what catches that, by reading main.dart and
  /// insisting it hands over a real [FileSnapshotStore]. Defaulting the other
  /// way would put the cost of forgetting on the person's disk.
  FinancialState({this.clock, SnapshotStore? store})
    : _store = store ?? MemorySnapshotStore() {
    _seed();
  }

  void _seed() {
    _transactions = SeedData.transactions();
    _upcoming = List<UpcomingItem>.of(SeedData.upcoming);
    _debts = List<Debt>.of(SeedData.debts);
    _accounts = List<Account>.of(SeedData.accounts);
    _budgets = List<Budget>.of(SeedData.budgets);
    _goals = List<Goal>.of(SeedData.goals);
    _incomeStreams = List<IncomeStream>.of(SeedData.incomeStreams);
    _installments = List<InstallmentPlan>.of(SeedData.installments);
  }

  /// Injectable clock, so a test can pin "today".
  final DateTime? clock;

  late List<Transaction> _transactions;
  late List<UpcomingItem> _upcoming;
  late List<Debt> _debts;
  late List<Account> _accounts;

  // Mutable from here, because Plan writes to all three: a budget limit can be
  // changed, a goal can be added and contributed to, and an income stream can
  // be added. They were const pass-throughs to the seed while every screen
  // only read them.
  late List<Budget> _budgets;
  late List<Goal> _goals;
  late List<IncomeStream> _incomeStreams;

  /// Mutable now that the Installments screen can pay one.
  late List<InstallmentPlan> _installments;

  /// Reconciliations recorded this session. Starts empty rather than seeded:
  /// the prototype seeds one, and a history row claiming somebody checked an
  /// account they have never opened is a small lie in the one place whose
  /// whole job is to be trustworthy.
  List<ReconciliationRecord> _reconciliations = const <ReconciliationRecord>[];

  ThemeMode2 _theme = ThemeMode2.gabi;
  DecisionScenario _scenario = DecisionScenario.conservative;
  ProfileEntity? _activeProfile;
  MovementFilter _movementFilter = MovementFilter.all;

  // -------------------------------------------------------------------------
  // Persistence
  // -------------------------------------------------------------------------

  final SnapshotStore _store;

  /// Keys read from the file that this build does not model. Carried so that
  /// saving cannot destroy what a newer build, or the prototype, wrote.
  Extras _extras = const Extras.empty();

  /// OFF until [restore] has decided it is safe. Two states leave it off: the
  /// app has not loaded yet, and the file could not be read.
  bool _saveEnabled = false;
  bool _pendingSave = false;
  Future<void> _writeChain = Future<void>.value();

  LoadStatus _loadStatus = LoadStatus.fresh;
  String? _loadProblem;
  String? _saveProblem;

  /// What happened on the last load. A screen can ask, and the one that does
  /// is the banner that warns somebody their entries are not being kept.
  LoadStatus get loadStatus => _loadStatus;

  /// Set when the stored file could not be read. While this is non null,
  /// NOTHING is written, so the file it could not read is still there.
  String? get loadProblem => _loadProblem;

  /// Set when a save itself failed, a full disk being the usual reason.
  String? get saveProblem => _saveProblem;

  /// True when entries made now will still be here tomorrow.
  bool get isSaving => _saveEnabled;

  /// Reads the stored file and replaces the seed with it.
  ///
  /// Call once, before the first frame. Three outcomes:
  ///   - no file: the seed stays and saving turns ON, so the first entry
  ///     creates the file;
  ///   - a file: it replaces the seed and saving turns ON;
  ///   - a file that cannot be read: the seed stays for something to look at,
  ///     saving stays OFF, and [loadProblem] says why. That combination is
  ///     deliberate. Demo accounts on screen are confusing for a minute;
  ///     demo accounts SAVED OVER a real ledger are permanent, and there is
  ///     no server holding a copy.
  Future<void> restore() async {
    final LoadResult result = await loadSnapshot(_store);
    _loadStatus = result.status;
    switch (result.status) {
      case LoadStatus.fresh:
        _saveEnabled = true;
      case LoadStatus.loaded:
        _apply(result.snapshot!);
        _saveEnabled = true;
      case LoadStatus.recovered:
        // The previous generation opened. Everything is here except whatever
        // the interrupted save was carrying, so saving turns back ON: the
        // person's next entry belongs in a file, and continuing to write is
        // how the good copy becomes the current one again.
        _apply(result.snapshot!);
        _loadProblem = result.problem;
        _saveEnabled = true;
      case LoadStatus.unreadable:
        _loadProblem = result.problem;
        _saveEnabled = false;
    }
    super.notifyListeners();
  }

  void _apply(Snapshot s) {
    _accounts = List<Account>.of(s.accounts);
    _transactions = List<Transaction>.of(s.transactions);
    _debts = List<Debt>.of(s.debts);
    _budgets = List<Budget>.of(s.budgets);
    _goals = List<Goal>.of(s.goals);
    _upcoming = List<UpcomingItem>.of(s.upcoming);
    _incomeStreams = List<IncomeStream>.of(s.incomeStreams);
    _installments = List<InstallmentPlan>.of(s.installments);
    _reconciliations = List<ReconciliationRecord>.of(s.reconciliations);
    _theme = s.theme;
    _scenario = s.scenario;
    _activeProfile = s.activeProfile;
    _extras = s.extras;
  }

  /// Everything this store holds, as one document.
  Snapshot snapshot() => Snapshot(
    accounts: _accounts,
    transactions: _transactions,
    debts: _debts,
    budgets: _budgets,
    goals: _goals,
    upcoming: _upcoming,
    incomeStreams: _incomeStreams,
    installments: _installments,
    reconciliations: _reconciliations,
    theme: _theme,
    scenario: _scenario,
    activeProfile: _activeProfile,
    extras: _extras,
  );

  /// Every mutation ends in a notify, so every mutation ends in a save.
  ///
  /// Overridden rather than calling a save helper from each of the twenty
  /// mutating methods, because the twenty first is the one somebody forgets,
  /// and a silently unsaved write is exactly the defect this whole file
  /// exists to prevent.
  @override
  void notifyListeners() {
    super.notifyListeners();
    _scheduleSave();
  }

  void _scheduleSave() {
    if (!_saveEnabled || _pendingSave) return;
    _pendingSave = true;
    // Coalesce: a single tap can notify several times, and that is one write,
    // not several. The chain then keeps writes in order, so two saves can
    // never interleave and produce a file that is half of each.
    scheduleMicrotask(() {
      _pendingSave = false;
      _writeChain = _writeChain.then((_) => _writeNow());
    });
  }

  Future<void> _writeNow() async {
    final String encoded;
    try {
      encoded = snapshot().encode(at: now);
    } on Object catch (e) {
      _reportSaveProblem('Salapify could not prepare your data to save. $e');
      return;
    }
    try {
      await _store.write(encoded);
      if (_saveProblem != null) {
        _saveProblem = null;
        super.notifyListeners();
      }
    } on Object catch (e) {
      _reportSaveProblem(
        'Salapify could not save to this device. Your entries are on screen '
        'but not stored yet. $e',
      );
    }
  }

  /// Reports through [super.notifyListeners] deliberately. Going through the
  /// override would schedule another save, which would fail the same way, and
  /// a disk that is full stays full: that is an endless loop of failing
  /// writes rather than a message somebody can act on.
  void _reportSaveProblem(String message) {
    if (_saveProblem == message) return;
    _saveProblem = message;
    super.notifyListeners();
  }

  /// Waits for any queued write to finish. For tests, and for anywhere that
  /// has to know the file is on disk before moving on.
  ///
  /// A MICROTASK, never `Future.delayed`. Delayed schedules a TIMER, and a
  /// widget test runs on a fake clock where timers only fire when somebody
  /// pumps, so awaiting one inside `testWidgets` deadlocks the whole test with
  /// no output at all. It worked everywhere it was first used because those
  /// were plain `test()` cases on real async, and it hung the moment a widget
  /// test called it. The save is queued with `scheduleMicrotask`, so a
  /// microtask is also the correct thing to wait on.
  Future<void> flushWrites() async {
    await Future<void>.microtask(() {});
    await _writeChain;
  }

  ThemeMode2 get theme => _theme;
  DecisionScenario get scenario => _scenario;

  /// null means "All Profiles", the prototype's 'all' tab.
  ProfileEntity? get activeProfile => _activeProfile;
  MovementFilter get movementFilter => _movementFilter;

  DateTime get now => clock ?? DateTime.now();

  List<Account> get accounts => List<Account>.unmodifiable(_accounts);
  List<Transaction> get transactions =>
      List<Transaction>.unmodifiable(_transactions);
  List<Debt> get debts => List<Debt>.unmodifiable(_debts);
  List<Budget> get budgets => List<Budget>.unmodifiable(_budgets);
  List<CategoryInfo> get categories => SeedData.categories;
  List<Goal> get goals => List<Goal>.unmodifiable(_goals);
  List<UpcomingItem> get upcoming => List<UpcomingItem>.unmodifiable(_upcoming);
  List<BillItem> get bills => SeedData.bills;
  List<IncomeStream> get incomeStreams =>
      List<IncomeStream>.unmodifiable(_incomeStreams);
  List<InstallmentPlan> get installments =>
      List<InstallmentPlan>.unmodifiable(_installments);
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

  /// Records a payment on a debt, in BOTH halves.
  ///
  /// Half one, the debt moves, goes through applyDebtPayment in
  /// core/money/debt.dart, which is locked to vectors from the prototype's own
  /// reducer. Half two, an ENTRY EXPLAINS IT, goes through logTransaction, so
  /// the account balance moves down the ordinary path and the entry appears in
  /// Activity, in Reports and against the Debt & Loan Servicing budget.
  ///
  /// Half two is the one that gets forgotten, and forgetting it is not a
  /// cosmetic miss: a founder once paid 1,500 off a loan, opened the account
  /// it came out of, and found nothing in its history. The balance had moved
  /// and no entry said why, which for anybody who keeps books is the defect.
  ///
  /// Passing no [accountId] records the debt alone. That is a real choice, for
  /// somebody settling in cash they never logged, and the sheet says what it
  /// will and will not do before they confirm.
  void recordDebtPayment(String debtId, double amount, {String? accountId}) {
    if (amount <= 0) return;
    final int i = _debts.indexWhere((Debt d) => d.id == debtId);
    if (i < 0) return;
    final Debt before = _debts[i];

    _debts = applyDebtPayment(_debts, debtId, amount, today: now);

    final Transaction? entry = paymentEntry(
      debt: before,
      amount: amount,
      accountId: accountId,
      today: now,
      id: 'tx_debt_${DateTime.now().microsecondsSinceEpoch}',
    );
    if (entry != null) {
      // logTransaction notifies as well. One notify too many is a repaint;
      // one too few is a screen showing yesterday's money.
      logTransaction(entry);
      return;
    }
    notifyListeners();
  }

  /// Marks a debt settled, or puts it back.
  ///
  /// Writes NO ledger entry, deliberately, and this is the difference between
  /// the two buttons on that screen. "Record a payment" says money moved and
  /// names the account it moved from. "Mark settled" says the books were
  /// wrong and the debt is actually clear, which is a correction rather than
  /// a movement. Writing an entry for it would invent a payment out of an
  /// account that never lost the money, and the account and the ledger would
  /// then disagree by exactly the amount nobody paid.
  void toggleDebtSettledById(String debtId) {
    final List<Debt> next = toggleDebtSettled(_debts, debtId, today: now);
    if (identical(next, _debts)) return;
    _debts = next;
    notifyListeners();
  }

  /// Pays one scheduled instalment on a plan, in both halves.
  ///
  /// The plan advances through applyInstallmentPayment in
  /// core/money/installments.dart, vector-locked to the prototype's reducer,
  /// and a ledger entry explains the account movement. Same split as every
  /// other write here: the engine decides WHAT, this decides WHEN.
  void payInstallment(String planId, {String? accountId}) {
    final int i = _installments.indexWhere(
      (InstallmentPlan p) => p.id == planId,
    );
    if (i < 0) return;
    final InstallmentPlan before = _installments[i];
    if (before.isSettled) return;

    _installments = applyInstallmentPayment(_installments, planId);

    final Transaction? entry = installmentEntry(
      plan: before,
      installmentNumber: before.paidInstallments + 1,
      accountId: accountId,
      today: now,
      id: 'tx_inst_${DateTime.now().microsecondsSinceEpoch}',
    );
    if (entry != null) {
      logTransaction(entry);
      return;
    }
    notifyListeners();
  }

  /// Records money paid on TOP of a plan's schedule.
  void payInstallmentExtra(
    String planId,
    double amount, {
    String? accountId,
    String? note,
  }) {
    if (amount <= 0) return;
    final int i = _installments.indexWhere(
      (InstallmentPlan p) => p.id == planId,
    );
    if (i < 0) return;
    final InstallmentPlan before = _installments[i];

    _installments = applyExtraPayment(
      _installments,
      planId,
      amount,
      today: now,
      note: note,
    );

    final Transaction? entry = extraPaymentEntry(
      plan: before,
      amount: amount,
      accountId: accountId,
      today: now,
      id: 'tx_inst_extra_${DateTime.now().microsecondsSinceEpoch}',
      note: note,
    );
    if (entry != null) {
      logTransaction(entry);
      return;
    }
    notifyListeners();
  }

  /// Everything reconciled so far, newest first.
  List<ReconciliationRecord> get reconciliations =>
      List<ReconciliationRecord>.unmodifiable(_reconciliations);

  /// Records that an account was checked against a statement.
  ///
  /// This alone moves NO money. It is the note in the margin saying somebody
  /// looked, and it is worth keeping even when the two agreed: "we checked on
  /// the 18th and it matched" is exactly what you want to find when the
  /// figures stop matching in November.
  void recordReconciliation({
    required String accountId,
    required double bookBalance,
    required double actualBalance,
    String? notes,
    String? adjustmentTxId,
  }) {
    final double variance = varianceOf(bookBalance, actualBalance);
    _reconciliations = <ReconciliationRecord>[
      ReconciliationRecord(
        id: 'rec_${DateTime.now().microsecondsSinceEpoch}',
        accountId: accountId,
        date: isoDate(now),
        bookBalance: bookBalance,
        actualBalance: actualBalance,
        variance: adjustmentTxId != null ? 0 : variance,
        balanced: adjustmentTxId != null || isBalanced(variance),
        notes: notes,
        adjustmentTxId: adjustmentTxId,
        createdAt: now.millisecondsSinceEpoch,
      ),
      ..._reconciliations,
    ];
    notifyListeners();
  }

  /// Closes a gap by POSTING AN ENTRY, never by editing the balance.
  ///
  /// The account still moves, but it moves the ordinary way, through
  /// logTransaction, so its history explains its own balance afterwards.
  /// Setting the number to match the statement would leave an account whose
  /// entries do not add up to it, which for anybody who keeps books is worse
  /// than the discrepancy they started with.
  void postReconciliationAdjustment({
    required String accountId,
    required double actualBalance,
    String? note,
  }) {
    final int i = _accounts.indexWhere((Account a) => a.id == accountId);
    if (i < 0) return;
    final Account account = _accounts[i];
    final double book = bookBalanceOf(account);
    final double variance = varianceOf(book, actualBalance);
    if (isBalanced(variance)) return;

    final Transaction? entry = adjustmentEntry(
      account: account,
      variance: variance,
      today: now,
      id: 'tx_recon_${DateTime.now().microsecondsSinceEpoch}',
      note: note,
    );
    if (entry == null) return;

    logTransaction(entry);
    recordReconciliation(
      accountId: accountId,
      bookBalance: book,
      actualBalance: actualBalance,
      notes:
          'Traceable adjustment posted: '
          '${note?.trim().isNotEmpty == true ? note!.trim() : 'Statement balance alignment'}',
      adjustmentTxId: entry.id,
    );
  }

  /// Changes one entry's status, the Activity correction path.
  ///
  /// No money moves. What changes is whether the entry COUNTS: excluded and
  /// duplicate entries are left out of every total, so marking one is how a
  /// person says "the app is right that this happened, and wrong that it is
  /// mine".
  void setTransactionStatus(String id, TransactionStatus status) {
    final int i = _transactions.indexWhere((Transaction t) => t.id == id);
    if (i < 0 || _transactions[i].status == status) return;
    _transactions = applyStatusChange(_transactions, id, status);
    notifyListeners();
  }

  /// Adds an account the user just described.
  ///
  /// Newest first, the same order every other add on this store uses, so
  /// somebody who has just typed one finds it at the top of its group rather
  /// than wherever the alphabet put it.
  ///
  /// The balance they typed is taken AS THE TRUTH and no transaction is
  /// written for it. That is deliberate: an opening balance is not income,
  /// and logging one would put a made up 48,500 payday into Reports and
  /// inflate the month's money in. The prototype does the same.
  ///
  /// In memory only, like every other write on this store today.
  void addAccount(Account account) {
    _accounts = <Account>[account, ..._accounts];
    notifyListeners();
  }

  /// Replaces an account with an edited version of itself, matched on id.
  ///
  /// Whole-object replacement rather than a field-by-field patch, because the
  /// sheet already holds every field a person can change and a patch API
  /// invites a caller to change one thing while silently keeping a stale copy
  /// of another.
  ///
  /// Editing a balance here is a CORRECTION, not a movement, so again no
  /// transaction is written. Somebody fixing a typo in their opening balance
  /// is not spending or earning anything, and Reports should not show a
  /// phantom entry for it. Reconciliation, which is the feature for "the bank
  /// says something different", is the one that writes a traceable adjustment,
  /// and it is its own batch.
  void updateAccount(Account account) {
    final int i = _accounts.indexWhere((Account a) => a.id == account.id);
    if (i < 0) return;
    _accounts = <Account>[
      ..._accounts.sublist(0, i),
      account,
      ..._accounts.sublist(i + 1),
    ];
    notifyListeners();
  }

  /// Records an entry the user just logged, and moves the money.
  ///
  /// The balance side goes through applyToBalances in core/money/ledger.dart,
  /// which is locked to vectors from the prototype's own addTransaction, so
  /// this method decides WHEN money moves and never HOW MUCH.
  ///
  /// Newest first, matching the prototype, and matching what the Activity
  /// screen shows: somebody who has just logged something looks at the top.
  ///
  /// In memory only, like every other write on this store today. There is no
  /// storage layer in app/ yet, so this is gone on the next cold start, and
  /// the sheet says so when it saves rather than letting somebody find out
  /// tomorrow.
  void logTransaction(Transaction tx) {
    _transactions = <Transaction>[tx, ..._transactions];
    _accounts = applyToBalances(_accounts, tx);
    notifyListeners();
  }

  /// Changes one budget's monthly limit.
  ///
  /// The decision about what is a valid limit lives in applyBudgetLimit, in
  /// core/money/plan.dart, which is vector-locked. This method decides WHEN,
  /// never WHAT, which is the same split every other write on this store uses.
  void setBudgetLimit(String category, double limit) {
    final List<Budget> next = applyBudgetLimit(_budgets, category, limit);
    if (identical(next, _budgets)) return;
    _budgets = next;
    notifyListeners();
  }

  /// Adds a goal the user just created.
  ///
  /// Front of the list, because somebody who has just typed one looks at the
  /// top for it.
  void addGoal(Goal goal) {
    _goals = <Goal>[goal, ..._goals];
    notifyListeners();
  }

  /// Puts money towards a goal.
  ///
  /// NOTE, and it is the thing to get right when storage lands: this moves the
  /// goal's own progress and DOES NOT move an account balance. A goal is a
  /// statement of intent, not a pot. Somebody who wants the peso to leave an
  /// account logs a transfer, which is a different action with a different
  /// effect on net worth. Making this debit an account would double count
  /// every contribution against the transfer that funded it.
  void contributeToGoal(String goalId, double amount) {
    final List<Goal> next = applyGoalContribution(_goals, goalId, amount);
    if (identical(next, _goals)) return;
    _goals = next;
    notifyListeners();
  }

  /// Adds an expected income stream.
  ///
  /// Safe to Spend reads these, so a new stream changes the headline figure on
  /// Home. That is the intended effect and it is why the sheet says what it
  /// will do before saving.
  void addIncomeStream(IncomeStream stream) {
    _incomeStreams = <IncomeStream>[..._incomeStreams, stream];
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
    // _incomeStreams, NOT the seed. This read the frozen seed list until Plan
    // let somebody add a stream, at which point the new stream would have been
    // stored, listed on Plan, and invisible to the one figure it is supposed
    // to move. Exactly the shape of defect the write-path rule exists for: the
    // write was correct where it was written and wrong where it was read.
    incomeStreams: _incomeStreams,
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
