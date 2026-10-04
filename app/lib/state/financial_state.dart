import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/import.dart';
import '../data/notification_gateway.dart';
import '../data/seed_data.dart';
import '../data/snapshot.dart';
import '../data/store.dart';
import '../design/tokens.dart';
import '../core/money/accounts.dart';
import '../core/money/bills.dart';
import '../core/money/debt.dart';
import '../core/money/health_check.dart';
import '../core/money/payday_schedule.dart';
import '../core/money/installments.dart';
import '../core/money/ledger.dart';
import '../core/money/pan/pan_context.dart';
import '../core/money/plan.dart';
import '../core/money/reconciliation.dart';
import '../core/money/reminders.dart';
import '../core/money/daily_projection.dart';
import '../core/money/safe_to_spend.dart';
import '../models/models.dart';
import '../core/money/money.dart';

/// What happened when somebody asked to take an entry back from Activity.
///
/// Several of these are REFUSALS, and each one is a different refusal on
/// purpose. "You cannot do that here" is not an answer when the person is
/// looking at money that left their account; every value below that is not
/// [done] names a screen where the real take-back lives, and the sheet turns
/// it into that sentence.
enum TakeBackOutcome {
  /// Reversed. The entry stays in Activity marked Taken back, and stops
  /// counting toward every total.
  done,

  /// It was already excluded, a duplicate, or taken back earlier, so there is
  /// nothing left to reverse. Tapping again must not credit the money twice.
  alreadyNotCounting,

  /// The entry has gone since the sheet was opened.
  gone,

  /// A debt payment wrote it. Taking back the ledger row alone would put the
  /// money back and leave the debt still claiming it was paid, which is the
  /// half-landed state measured at 1,500.00 once already.
  belongsToDebt,

  /// An instalment payment wrote it, same reasoning.
  belongsToPlan,

  /// A reconciliation adjustment wrote it, and a record elsewhere says that
  /// account was balanced by exactly this row.
  belongsToReconciliation,

  /// Marking a scheduled bill paid wrote it, and the bill is still ticked.
  belongsToBill,

  /// A split wrote it, and the receivables it created are still standing.
  belongsToSplit,
}

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
  FinancialState({
    this.clock,
    SnapshotStore? store,
    NotificationGateway? notifications,
  }) : _store = store ?? MemorySnapshotStore(),
       _notifier = notifications ?? const NoNotifications() {
    _seed();
  }

  void _seed() {
    _transactions = SeedData.transactions(now);
    _upcoming = List<UpcomingItem>.of(SeedData.upcoming(now));
    _debts = List<Debt>.of(SeedData.debts(now));
    _accounts = List<Account>.of(SeedData.accounts(now));
    _budgets = List<Budget>.of(SeedData.budgets);
    _goals = List<Goal>.of(SeedData.goals);
    _incomeStreams = List<IncomeStream>.of(SeedData.incomeStreams);
    _installments = List<InstallmentPlan>.of(SeedData.installments(now));
    _bills = List<BillItem>.of(SeedData.bills(now));
    _payday = SeedData.payday;
    _notifications = <AppNotification>[];
    _reminderSettings = ReminderSettings.defaults;
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

  /// Bills and the payday cycle, both of which used to be read STRAIGHT OFF
  /// THE SEED by the Safe to Spend engine, and neither of which was stored.
  ///
  /// That was a measured money defect, not a missing feature. A brand new user
  /// holding one real 50,000 peso account saw a Safe to Spend of 0.00, because
  /// 41,184 pesos of demo bills, times the conservative 1.1 multiplier, plus
  /// 6,348 of demo instalments, were reserved against obligations they had
  /// never entered. No screen in the app listed those bills, so the money was
  /// not merely wrong, it was unaccountable: the Plan tab reads a different
  /// collection entirely.
  late List<BillItem> _bills;
  late PaydayCycle _payday;

  /// The reminder tray, newest first, and the rules that fill it.
  ///
  /// It starts EMPTY on a fresh install, which is a deliberate change from
  /// what shipped before: the bell carried a hardcoded 12, from a seed
  /// constant, on a phone that had never been reminded of anything. A badge
  /// that lies is worse than no badge, and a beginner tapping it found a
  /// screen saying "coming soon".
  late List<AppNotification> _notifications;
  late ReminderSettings _reminderSettings;

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

  /// The phone's notification tray. [NoNotifications] by default, so a test,
  /// a preview and the render harness never reach a platform channel.
  final NotificationGateway _notifier;

  /// Keys read from the file that this build does not model. Carried so that
  /// saving cannot destroy what a newer build, or the prototype, wrote.
  Extras _extras = const Extras.empty();

  /// Guide steps the person has ticked off, by step id. See
  /// [Snapshot.guideSteps] for why this is stored and why it is a flat set.
  Set<String> _guideSteps = <String>{};

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
    // AFTER the notify and after saving is decided, so a reminder raised on
    // open is written to the file rather than living until the next restart
    // and being raised all over again.
    refreshReminders();
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
    _bills = List<BillItem>.of(s.bills);
    _notifications = List<AppNotification>.of(s.notifications);
    _trimTray();
    _reminderSettings = s.reminderSettings;
    _payday = s.payday;
    _sampleRemovedAt = s.sampleDataRemovedAt;
    _onboardedAt = s.onboardedAt;
    _setAsideReviewedAt = s.setAsideReviewedAt;
    _theme = s.theme;
    _scenario = s.scenario;
    _activeProfile = s.activeProfile;
    _guideSteps = Set<String>.of(s.guideSteps);
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
    bills: _bills,
    notifications: _notifications,
    reminderSettings: _reminderSettings,
    payday: payday,
    sampleDataRemovedAt: _sampleRemovedAt,
    onboardedAt: _onboardedAt,
    setAsideReviewedAt: _setAsideReviewedAt,
    theme: _theme,
    scenario: _scenario,
    activeProfile: _activeProfile,
    guideSteps: _guideSteps,
    extras: _extras,
  );

  /// Has this guide step been ticked off?
  bool isGuideStepDone(String id) => _guideSteps.contains(id);

  /// Every ticked step, read only. Callers count it; nobody mutates it.
  Set<String> get guideSteps => Set<String>.unmodifiable(_guideSteps);

  /// How many of [ids] are ticked. The caller passes the guide's own list, so
  /// a step that was removed from a guide since it was ticked cannot inflate
  /// that guide's progress. The tick itself is kept, per [Snapshot.guideSteps];
  /// it simply does not count towards a list it is no longer on.
  int guideStepsDoneAmong(Iterable<String> ids) =>
      ids.where(_guideSteps.contains).length;

  /// Tick a step, or untick it. Ends in a notify, so it ends in a save.
  void toggleGuideStep(String id) {
    if (id.isEmpty) return;
    if (!_guideSteps.remove(id)) _guideSteps.add(id);
    notifyListeners();
  }

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
    // Re-checked HERE, not only where the write was scheduled.
    //
    // `deleteEverything` turns saving off and awaits the chain, which covers
    // writes already on it. A notify raised in the same turn as the wipe
    // appends through a microtask AFTER that await, and this method used to
    // write unconditionally once it was on the chain, so the ledger that had
    // just been erased was written straight back out. It is not reachable
    // from today's tap, because microtasks drain between events, but the
    // comment on deleteEverything claims a guard that was an accident of
    // scheduling rather than a guard. One line makes it real.
    if (!_saveEnabled) return;

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
      // The ledger on disk just changed, so what the phone has been told to
      // say about it is now potentially wrong. Replanning here rather than at
      // twenty call sites is the same argument as saving here: the twenty
      // first is the one somebody forgets. It swallows its own failures, so a
      // save that succeeded is never reported as one that did not.
      await replanNotifications();
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

  /// The debts the app shows anywhere, archived ones excluded.
  ///
  /// THE FILTER IS HERE, at the one getter, rather than inside [outstanding].
  /// Every consumer in the app reads this, including
  /// `accounts_screen.dart`, which carries its OWN inline copy of the
  /// outstanding sum rather than calling the engine. Filtering in the engine
  /// would have left that screen counting archived debts while the Debts
  /// screen did not, which is two screens disagreeing about money, the exact
  /// class of defect the journey tests exist for. One getter cannot drift
  /// from itself.
  ///
  /// Only a SETTLED debt can be archived, so in practice this subtracts
  /// nothing from any total: a settled debt is already out of [outstanding].
  /// The filter changes what is LISTED, not what is COUNTED.
  List<Debt> get debts =>
      List<Debt>.unmodifiable(_debts.where((Debt d) => !d.isArchived));

  /// Put away, newest first. Shown only on the Debts screen, in its own
  /// section, where "Put it back" lives.
  List<Debt> get archivedDebts => List<Debt>.unmodifiable(
    _debts.where((Debt d) => d.isArchived).toList()
      ..sort((Debt a, Debt b) => b.archivedAt!.compareTo(a.archivedAt!)),
  );
  List<Budget> get budgets => List<Budget>.unmodifiable(_budgets);
  List<CategoryInfo> get categories => SeedData.categories;
  List<Goal> get goals => List<Goal>.unmodifiable(_goals);
  List<UpcomingItem> get upcoming => List<UpcomingItem>.unmodifiable(_upcoming);
  List<BillItem> get bills => List<BillItem>.unmodifiable(_bills);
  List<IncomeStream> get incomeStreams =>
      List<IncomeStream>.unmodifiable(_incomeStreams);

  /// The plans the app shows anywhere, archived ones excluded.
  ///
  /// The filter is at the one getter for the same reason the debt one is:
  /// every consumer reads this, including Safe to Spend's reserve and the
  /// Plans summary, and one getter cannot drift from itself.
  ///
  /// Only a SETTLED plan can be archived, and a settled plan is already
  /// outside both of those figures, so this subtracts nothing from any total.
  /// It changes what is LISTED, not what is COUNTED.
  List<InstallmentPlan> get installments => List<InstallmentPlan>.unmodifiable(
    _installments.where((InstallmentPlan p) => !p.isArchived),
  );

  /// Put away, newest first. Shown only on the Plans tab, where "Put it back"
  /// lives.
  List<InstallmentPlan> get archivedInstallments =>
      List<InstallmentPlan>.unmodifiable(
        _installments.where((InstallmentPlan p) => p.isArchived).toList()..sort(
          (InstallmentPlan a, InstallmentPlan b) =>
              b.archivedAt!.compareTo(a.archivedAt!),
        ),
      );

  /// The pay cycle, with its countdown worked out against TODAY.
  ///
  /// `_payday` stores a rule and a snapshot of a moment. The rule keeps; the
  /// snapshot does not. Before this getter existed, `daysToPayday` was
  /// whatever had been written once and was never touched again, which
  /// `json_codec.dart` recorded as a defect years in the making: a cycle
  /// "would have said the same in December, because nothing ever recomputed
  /// or stored it". Since that number is the DIVISOR for the per-day figure
  /// on Home, a stale one is a wrong daily allowance, not a wrong label.
  ///
  /// Derived HERE, above the money engine and not inside it, on purpose.
  /// `computeSafeToSpend` still divides by whatever cycle it is handed and
  /// its golden vectors still hand it one directly, so the locked arithmetic
  /// is untouched by any of this.
  ///
  /// A cycle with no rule is returned exactly as stored. That covers every
  /// backup written before the editor existed and every prototype import:
  /// they keep whatever they had rather than having a rule guessed for them.
  PaydayCycle get payday {
    if (!_payday.hasRule) return _payday;

    final PaydayPoints? points = PaydaySchedule(
      _payday.paydayDays,
    ).pointsFrom(now);
    if (points == null) return _payday;

    return _payday.copyWith(
      daysToPayday: points.daysToNext,
      nextPayday: formatPaydayLabel(points.next),
      lastPayday: formatPaydayLabel(points.last),
    );
  }

  /// Records when the person gets paid, and optionally what they expect.
  ///
  /// Only the RULE and the expected amount are the person's to give. The
  /// countdown and the two date labels are derived by the getter above, so
  /// they are deliberately not parameters here: a caller that could set them
  /// could write a countdown that stops counting, which is the whole defect
  /// this replaces.
  ///
  /// An empty [daysOfMonth] CLEARS the cycle back to unset rather than
  /// storing an unusable rule. Somebody who set a payday by mistake needs a
  /// way back out, and leaving a half-built rule behind would show the
  /// screens a cycle that `isSet` calls true and the schedule cannot use.
  void setPaydayRule({required List<int> daysOfMonth, Money? expectedIncome}) {
    final PaydaySchedule schedule = PaydaySchedule(daysOfMonth);

    if (!schedule.isUsable) {
      _payday = PaydayCycle.unset;
      notifyListeners();
      return;
    }

    _payday = _payday.copyWith(
      paydayDays: schedule.daysOfMonth,
      cycleType: schedule.daysOfMonth.length > 1 ? 'semi_monthly' : 'monthly',
      expectedIncome: expectedIncome ?? Money.zero,
    );
    notifyListeners();
  }

  // -------------------------------------------------------------------------
  // Reminders
  // -------------------------------------------------------------------------

  List<AppNotification> get notifications =>
      List<AppNotification>.unmodifiable(_notifications);

  ReminderSettings get reminderSettings => _reminderSettings;

  /// What the bell counts. A real number now: it is the tray, filtered.
  int get unreadNotificationsCount =>
      _notifications.where((AppNotification n) => !n.isRead).length;

  /// Works out what is newly due and puts it in the tray. Returns how many.
  ///
  /// Called when the app opens and whenever the reminders screen is opened,
  /// rather than on a timer. There IS no timer: Salapify has no background
  /// service and no notification permission, so a reminder exists the moment
  /// somebody looks, and the screen says so in as many words rather than
  /// implying the phone will buzz.
  ///
  /// The dedupe set is the tray's own ids, so a reminder that was raised and
  /// then DELETED can come back. That is deliberate. Deleting a message is
  /// not paying the bill, and an app that took a swipe as "handled" would go
  /// quiet about a payment that is still due.
  int refreshReminders() {
    // Nothing is swept while the data file is unreadable. The ledger on
    // screen is the seed in that state, so every reminder would be about
    // somebody else's demo bills, written into a tray they would keep.
    if (_loadStatus == LoadStatus.unreadable) return 0;

    final ReminderResult result = evaluateReminders(
      settings: _reminderSettings,
      transactions: _transactions,
      debts: _debts,
      bills: _bills,
      accounts: _accounts,
      installments: _installments,
      upcoming: _upcoming,
      sentTags: _notifications.map((AppNotification n) => n.id).toSet(),
      now: now,
    );
    if (result.fresh.isEmpty) return 0;

    final int stamp = now.millisecondsSinceEpoch;
    _notifications = <AppNotification>[
      for (final Reminder r in result.fresh)
        AppNotification(
          id: r.tag,
          kind: r.kind,
          title: r.title,
          body: r.body,
          createdAt: stamp,
        ),
      ..._notifications,
    ];
    _trimTray();
    notifyListeners();
    return result.fresh.length;
  }

  /// How many messages the tray keeps.
  static const int maxNotifications = 60;

  /// Old messages are dropped from the bottom.
  ///
  /// A tray nobody can reach the end of is a tray nobody reads, and these are
  /// reminders rather than records: the bill itself is still in the ledger.
  /// Applied on every path that can grow the tray, including a loaded file,
  /// because trimming only on the add path leaves a long tray long forever.
  void _trimTray() {
    if (_notifications.length > maxNotifications) {
      _notifications = _notifications.sublist(0, maxNotifications);
    }
  }

  void markNotificationRead(String id) {
    final int at = _notifications.indexWhere(
      (AppNotification n) => n.id == id && !n.isRead,
    );
    if (at < 0) return;
    _notifications = List<AppNotification>.of(_notifications);
    _notifications[at] = _notifications[at].copyWith(isRead: true);
    notifyListeners();
  }

  void markAllNotificationsRead() {
    if (unreadNotificationsCount == 0) return;
    _notifications = <AppNotification>[
      for (final AppNotification n in _notifications) n.copyWith(isRead: true),
    ];
    notifyListeners();
  }

  void clearNotification(String id) {
    final int before = _notifications.length;
    _notifications = _notifications
        .where((AppNotification n) => n.id != id)
        .toList();
    if (_notifications.length != before) notifyListeners();
  }

  void clearAllNotifications() {
    if (_notifications.isEmpty) return;
    _notifications = <AppNotification>[];
    notifyListeners();
  }

  void updateReminderSettings(ReminderSettings next) {
    _reminderSettings = next;
    notifyListeners();
    // A rule that was just widened can make something due immediately, and
    // waiting until the next app open to say so would make the setting look
    // broken.
    refreshReminders();
  }

  // -------------------------------------------------------------------------
  // Pan
  // -------------------------------------------------------------------------

  /// Everything Pan is allowed to see, as a plain value.
  ///
  /// Built here and handed over, rather than giving Pan this object, so the
  /// assistant is a pure function of a snapshot: it cannot write anything, it
  /// cannot reach the store, and a test can put any ledger in front of it
  /// without building an app. Whatever is not on [PanFacts] is something Pan
  /// physically cannot mention.
  PanFacts get panFacts {
    final List<Transaction> thisMonth = _transactions.where((Transaction t) {
      final DateTime? d = DateTime.tryParse(t.date);
      return d != null && d.year == now.year && d.month == now.month;
    }).toList();

    final LedgerTotals totals = computeTotals(thisMonth);
    final SafeToSpendAnalysis s = safeToSpendAnalysis;

    return PanFacts(
      now: now,
      accounts: accounts,
      transactions: transactions,
      debts: debts,
      budgets: budgets,
      goals: goals,
      bills: bills,
      installments: installments,
      upcoming: upcoming,
      payday: payday,
      liquidCash: totalLiquidCash,
      assets: accountsTotalPhp(assetsOf(_accounts)),
      liabilities: accountsTotalPhp(liabilitiesOf(_accounts)),
      owed: debtsIOwe,
      owedToMe: debtsOwedToMe,
      // READ AS PESOS, deliberately, and this is the line where P2.1 stops.
      // PanFacts is a separate record with its own double fields feeding a
      // whole engine, so converting it belongs to its own increment rather
      // than being dragged along by this one. The guard list P2.1 is measured
      // against covers `lib/models/models.dart`, and this is not in it.
      safeToSpendUntilPayday: s.safeToSpendUntilPayday.pesos,
      safeToSpendPerDay: s.safeToSpendToday.pesos,
      amountReserved: s.amountReserved.pesos,
      cashRunwayMonths: s.cashRunwayMonths,
      runwayFromLoggedSpending: s.runwayFromLoggedSpending,
      monthIn: totals.totalIn,
      monthOut: totals.totalOut,
      spendingByCategory: categorySpending(thisMonth),
      hasSampleData: hasSampleData,
      phoneRemindersOn: _reminderSettings.phoneEnabled,
      unreadReminders: unreadNotificationsCount,
    );
  }

  // -------------------------------------------------------------------------
  // Erasing everything
  // -------------------------------------------------------------------------

  /// Deletes every file Salapify keeps and leaves the app genuinely empty.
  ///
  /// There is NO undo, by construction: the previous generation and the
  /// pre-import copy are the two things that would normally allow one, and
  /// both are part of what this removes. That is the point rather than an
  /// oversight, and the screen has to say it in those words before anybody
  /// taps it.
  ///
  /// THE SAMPLE DATA DOES NOT COME BACK, and that is a deliberate departure
  /// from the prototype's own "Reset to Sample Data". Somebody who has just
  /// asked to erase everything and is then shown eleven demo accounts and a
  /// sweldo they never earned has not been given what they asked for; they
  /// have been given a screen that looks exactly like the failure they were
  /// trying to avoid. Empty means empty.
  ///
  /// Returns how many files were actually removed, so the screen reports what
  /// happened rather than asserting success.
  Future<int> deleteEverything() async {
    // Saving goes OFF first. Every mutation below notifies, every notify
    // schedules a write, and a write landing after the delete would recreate
    // the file that was just erased.
    _saveEnabled = false;
    await _writeChain;

    final int removed = await _store.deleteEverything();
    await _notifier.cancelAll();

    _transactions = <Transaction>[];
    _upcoming = <UpcomingItem>[];
    _debts = <Debt>[];
    _accounts = <Account>[];
    _budgets = <Budget>[];
    _goals = <Goal>[];
    _incomeStreams = <IncomeStream>[];
    _installments = <InstallmentPlan>[];
    _bills = <BillItem>[];
    _reconciliations = <ReconciliationRecord>[];
    _notifications = <AppNotification>[];
    _reminderSettings = ReminderSettings.defaults;
    _payday = PaydayCycle.unset;
    _activeProfile = null;

    // NULL, not a timestamp, and this is a bug fix rather than tidiness.
    //
    // Setting it marked the sample data as "removed", which is what gates the
    // put-it-back control. So two taps after reading "The sample data has NOT
    // come back. You asked for an empty app, so that is what this is",
    // Settings offered a button that injects eleven demo accounts, a demo
    // salary and demo debts into the ledger they had just erased, under the
    // sentence "You removed Salapify's sample data. Everything here is
    // yours." Neither half of that was true of what had happened.
    //
    // After a wipe there is no sample data and none was removed: the ledger is
    // empty and new. Null says exactly that, and the control is correctly
    // absent. Nothing re-seeds, because the empty file written below loads as
    // a real ledger on the next launch rather than as a fresh install.
    _sampleRemovedAt = null;

    // AND THE APP FORGETS THAT IT HAS INTRODUCED ITSELF, which it did not
    // until 2026-10-03 and which left the wipe in a dead end.
    //
    // Clearing the ledger while keeping `onboardedAt` produced an app that was
    // empty AND had no way back to anything. `needsWelcome` stayed false, so
    // no welcome; `_sampleRemovedAt` is correctly null one line up, so the
    // put-it-back control is correctly absent; and Settings simply read "There
    // is no sample data on this phone" with no control beside it. Neither the
    // example data nor the first run could be reached again by any route.
    //
    // It also made the wipe screen's own promise false. It says Salapify is
    // empty and the comment above says the ledger is empty and NEW, and a
    // phone that still remembers being introduced to somebody is not new. The
    // person this matters most to is the one the wipe exists for: somebody
    // handing the phone on, whose recipient would meet a blank app that had
    // already decided it knew them.
    //
    // So a wiped phone meets the welcome again, and both paths are available
    // from it, which is also the only honest way to offer the example data
    // back to somebody who chose their own money and later wants to look.
    _onboardedAt = null;

    // Extras ARE cleared, and that is deliberate the other way. They hold keys
    // from the person's own file that this build cannot read, so carrying them
    // through a wipe would write a piece of their data straight back into the
    // supposedly empty file.
    _extras = const Extras.empty();

    // So are the ticked guide steps, for the same reason. They are the
    // person's own record of how far into registering a business they had
    // got, which is exactly the kind of thing somebody handing a phone on
    // means to erase. The wipe screen promises "Salapify is empty"; a
    // checklist still showing 14 of 30 done would make that sentence false.
    _guideSteps = <String>{};

    _loadStatus = LoadStatus.fresh;
    _loadProblem = null;
    _saveProblem = null;

    // Back ON, so the very next thing the person types is kept. An app that
    // erased itself and then silently stopped saving would be the same defect
    // twice over.
    _saveEnabled = true;
    notifyListeners();
    await flushWrites();
    return removed;
  }

  /// Turns phone notifications on, asking Android for permission first.
  ///
  /// Returns false when the person said no, and that is not an error: the
  /// switch stays off and the screen says where to change their mind. Storing
  /// "on" against a denied permission would be a control that claims to do
  /// something and does nothing, which is the defect this app keeps finding.
  /// The try is around the PERMISSION CALL too, not only the scheduling.
  ///
  /// An earlier note here claimed this path was already guarded. It was not:
  /// the guard went into replanNotifications, and the test's fake threw only
  /// from replaceAll, so it could not have caught this. `requestPermission`
  /// on the real gateway first initialises the plugin and the timezone
  /// database, and any platform exception there (a missing icon resource, a
  /// detached activity, a vendor ROM refusing the call) went straight out of
  /// the tap, leaving the switch spinning forever with nothing on screen.
  Future<bool> enablePhoneReminders() async {
    final bool granted;
    try {
      granted = await _notifier.requestPermission();
    } on Object {
      return false;
    }
    if (!granted) return false;
    updateReminderSettings(_reminderSettings.copyWith(phoneEnabled: true));
    await replanNotifications();
    return true;
  }

  Future<void> disablePhoneReminders() async {
    updateReminderSettings(_reminderSettings.copyWith(phoneEnabled: false));
    try {
      await _notifier.cancelAll();
    } on Object {
      // The setting is off either way, which is the part the person asked
      // for. A phone that will not take the cancel is not worth a crash.
    }
  }

  /// Hands Android the next fortnight of reminders, replacing whatever it had.
  ///
  /// Called after every successful write, which is what keeps a scheduled
  /// notification honest: pay the bill and the buzz about it disappears on
  /// the same tap, rather than arriving on Saturday morning about something
  /// settled on Thursday.
  /// It NEVER throws outward, and the guard lives here rather than at each
  /// call site.
  ///
  /// The first version guarded only the save path, and a test caught what that
  /// missed: tapping the switch on a device whose notification service is
  /// unavailable threw straight out of the tap, through
  /// `enablePhoneReminders`, into the widget. A phone that will not accept a
  /// schedule is a disappointment, not a crash, and it is never a reason to
  /// tell somebody their money was not saved.
  Future<void> replanNotifications() async {
    try {
      await _replan();
    } on Object {
      // Deliberately silent. See above.
    }
  }

  Future<void> _replan() async {
    if (!_reminderSettings.phoneEnabled) {
      await _notifier.cancelAll();
      return;
    }
    await _notifier.replaceAll(
      planReminders(
        settings: _reminderSettings,
        transactions: _transactions,
        debts: _debts,
        bills: _bills,
        accounts: _accounts,
        installments: _installments,
        upcoming: _upcoming,
        // The tray's own ids, so the phone does not buzz about something
        // already sitting unread on the Alerts tab.
        sentTags: _notifications.map((AppNotification n) => n.id).toSet(),
        from: now,
      ),
    );
  }

  /// Puts one message in the tray so a person can see what a reminder looks
  /// like, and check it is switched on at all.
  ///
  /// Ported from the prototype's Test Simulator. It is marked as a test in its
  /// own body, because a tray that mixes a drill with the real thing is how
  /// somebody ends up ignoring a real one.
  void sendTestReminder(ReminderKind kind) {
    final int stamp = now.millisecondsSinceEpoch;
    const Map<ReminderKind, String> what = <ReminderKind, String>{
      ReminderKind.dailyExpense: 'a daily logging nudge',
      ReminderKind.paymentDue: 'a payment reminder',
      ReminderKind.billDue: 'a bill reminder',
      ReminderKind.subscription: 'a subscription renewal',
    };
    _notifications = <AppNotification>[
      AppNotification(
        id: 'test-$stamp-${kind.index}',
        kind: kind,
        title: 'Test: ${what[kind]}',
        body:
            'This is a test, not a real reminder. Nothing is due. It is here '
            'so you can see where reminders appear.',
        createdAt: stamp,
      ),
      ..._notifications,
    ];
    // Capped HERE too. refreshReminders truncates and this did not, so holding
    // the Test button built a tray of any length, persisted it, and re-encoded
    // all of it on every save afterwards, with every row built eagerly into
    // one Column.
    _trimTray();
    notifyListeners();
  }

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
  /// IT PERSISTS. This comment used to say the write was memory only and gone
  /// on the next cold start, which stopped being true when storage landed:
  /// `notifyListeners` is overridden on this store and writes the whole
  /// snapshot. The same false sentence sat on [logTransaction] and was
  /// corrected there; this is the other copy of it. It matters here for the
  /// same reason it mattered there, because a persisted write is what makes
  /// an undo a second write rather than a memory edit.
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

    // QUANTISED ONCE, HERE, so both halves move by the same figure.
    //
    // The debt took the raw typed double while the ledger entry rounded it to
    // the centavo, so the liability fell by 1500.555 and the account fell by
    // 1500.56. "Paying a debt cannot change net worth, an asset falls and a
    // liability falls by the same amount" is one of this app's four stated
    // invariants, and it was false by half a centavo on every payment typed
    // with more than two decimals. The amount field accepts them: it is a
    // decimal keyboard with no formatter.
    final Money paid = Money.fromDouble(amount);
    if (!paid.isPositive) return;

    // ONE STAMP FOR BOTH HALVES, so the register row and the ledger row it
    // writes can be tied to each other later. Taking a payment back has to
    // move the debt AND remove the entry that explains it, and nothing else
    // in the app links the two: a Transaction carries no debtId, which is the
    // same gap that let a debt payment be marked a duplicate and half land.
    final int stamp = DateTime.now().microsecondsSinceEpoch;
    final String txId = 'tx_debt_$stamp';

    _debts = applyDebtPayment(
      _debts,
      debtId,
      paid,
      today: now,
      accountId: accountId,
      paymentId: 'dp_$stamp',
      // Only when an entry will actually exist. paymentEntry returns null
      // with no account, and a row pointing at a transaction that was never
      // written is worse than one pointing at nothing.
      txId: accountId == null ? null : txId,
    );

    final Transaction? entry = paymentEntry(
      debt: before,
      amount: paid.pesos,
      accountId: accountId,
      today: now,
      id: txId,
    );
    if (entry != null) {
      // logTransaction notifies as well. One notify too many is a repaint;
      // one too few is a screen showing yesterday's money.
      logTransaction(entry);
      return;
    }
    notifyListeners();
  }

  /// Takes the most recent payment back off a debt, in BOTH halves.
  ///
  /// Returns false when there is nothing to take back, and false is a real
  /// answer rather than a failure: every debt from a restored backup, and
  /// every payment made before the register existed, has no row to read. The
  /// screen asks before offering the control, so a person never taps into a
  /// refusal.
  ///
  /// The two halves are the same split every other write here uses. The debt
  /// moves through [reverseLastDebtPayment], which RESTORES stored figures
  /// rather than subtracting, and the ledger row goes through the existing
  /// [undoLoggedTransaction], which reverses the balance through the
  /// vector-locked mirror and is already a no-op when the row has gone.
  ///
  /// ## The entry STAYS, marked as taken back
  ///
  /// Founder direction, 2026-10-02, and it is the auditor's answer: a payment
  /// you took back is part of your history, and a gap with no explanation is
  /// worse than a line you can read. The row keeps its figure and its date and
  /// stops counting, through `TransactionStatus.corrected`.
  ///
  /// The balance moves exactly ONCE, inside `setTransactionStatus`, which
  /// reverses it through the vector-locked mirror when an entry stops
  /// counting. Calling that AND removing the row would credit the money back
  /// twice.
  ///
  /// The REGISTER row goes, because that list is what has been applied and
  /// this payment has not been any more. Keeping it would also let the same
  /// payment be taken back a second time.
  bool takeBackDebtPayment(String debtId) {
    final int i = _debts.indexWhere((Debt d) => d.id == debtId);
    if (i < 0) return false;

    final Debt before = _debts[i];
    if (before.payments.isEmpty) return false;
    final DebtPayment row = before.payments.last;

    _debts = reverseLastDebtPayment(_debts, debtId);

    // No txId is a REAL case, not a missing one: a payment recorded with no
    // account writes no entry, deliberately, for somebody settling in cash
    // they never logged. The debt still moves; there is simply nothing to
    // take out of the ledger.
    // MARKED, NOT REMOVED. setTransactionStatus moves the balance back on its
    // own, because the entry stops counting, so this must not also undo it.
    if (row.txId != null) {
      setTransactionStatus(row.txId!, TransactionStatus.corrected);
      return true;
    }

    notifyListeners();
    return true;
  }

  /// Puts a SETTLED debt away. Returns false and changes nothing otherwise.
  ///
  /// The settled-only gate is founder direction, 2026-10-02, and it is the
  /// reason this method moves no money. A settled debt is already out of
  /// [outstanding], so taking it off the list changes no figure on any
  /// screen. Archiving a LIVE debt would have dropped a real liability out
  /// of "You owe" on a tap, with the explanation on a different screen from
  /// the number that moved, and that was the option the founder turned down.
  ///
  /// NOTHING ELSE MOVES. No entry is written, no balance changes, the
  /// payment register is untouched, and the `tx_debt_` rows stay in Activity
  /// and keep counting. That money really did leave the account.
  ///
  /// The gate is HERE and not only in the screen, because a screen that
  /// hides a control is a presentation choice and this is a rule about the
  /// data. Same construction as [markUpcomingPaid]'s account refusal.
  bool archiveDebt(String debtId) {
    final int i = _debts.indexWhere((Debt d) => d.id == debtId);
    if (i < 0) return false;
    if (!_debts[i].isSettled) return false;
    if (_debts[i].isArchived) return false;

    _debts = <Debt>[
      for (final Debt d in _debts)
        if (d.id == debtId) d.copyWith(archivedAt: isoDate(now)) else d,
    ];
    notifyListeners();
    return true;
  }

  /// Brings an archived debt back to the list it came from.
  ///
  /// No confirmation anywhere in the UI, deliberately: nothing is lost by
  /// tapping it, which is the same reasoning the screen already applies to
  /// un-settling.
  bool unarchiveDebt(String debtId) {
    final int i = _debts.indexWhere((Debt d) => d.id == debtId);
    if (i < 0 || !_debts[i].isArchived) return false;

    _debts = <Debt>[
      for (final Debt d in _debts)
        if (d.id == debtId) d.copyWith(clearArchivedAt: true) else d,
    ];
    notifyListeners();
    return true;
  }

  /// Deletes a debt OUTRIGHT, and only one that never moved any money.
  ///
  /// This is the one genuinely irreversible path on the Debts screen, and the
  /// gate is what keeps it safe to offer at all: a debt with a paid figure or
  /// a payment register is refused, every time, whatever the screen shows.
  ///
  /// Why that gate and not a confirmation: deleting a debt that HAS payments
  /// would destroy the only structured record of what those payments were,
  /// while the `tx_debt_` entries they wrote stayed in Activity pointing at
  /// a debt that no longer exists. Reports > Check would then flag one of
  /// those entries, suppress its duplicate button because it is an engine
  /// payment, and tell the person to take the payment back from a Debts
  /// screen that no longer lists it. That dead end shipped once before and
  /// the founder found it within minutes. A debt that moved money gets
  /// archived instead, and archiving needs it settled first.
  ///
  /// There is NO undo. The confirmation says so in those words rather than
  /// implying the backup covers it, because an export is a snapshot of now
  /// and not a history. An export taken BEFORE the delete does contain it,
  /// which is a real route back for somebody who already had one.
  bool deleteDebt(String debtId) {
    final int i = _debts.indexWhere((Debt d) => d.id == debtId);
    if (i < 0) return false;

    final Debt d = _debts[i];
    if (d.paidAmount.isPositive || d.payments.isNotEmpty) return false;

    _debts = <Debt>[
      for (final Debt x in _debts)
        if (x.id != debtId) x,
    ];
    notifyListeners();
    return true;
  }

  /// Takes the most recent payment back off an instalment plan, in both
  /// halves. Same contract as [takeBackDebtPayment].
  /// ARCHIVED IMPLIES SETTLED, enforced wherever a plan can stop being
  /// settled rather than only where it can be archived.
  ///
  /// [reverseLastPlanPayment] restores `isSettled` from the stored row, so
  /// taking back the payment that cleared a plan un-settles it. On an
  /// archived plan that produces live-and-archived, which the `installments`
  /// getter filters out of every total, so a real monthly obligation would
  /// count nowhere. That is exactly the defect found on the debt side on
  /// 2026-10-02, and it is written as a helper here so the next method that
  /// can un-settle a plan has somewhere obvious to call.
  List<InstallmentPlan> _unarchiveIfLive(
    List<InstallmentPlan> plans,
    String planId,
  ) {
    final int i = plans.indexWhere((InstallmentPlan p) => p.id == planId);
    if (i < 0 || plans[i].isSettled || !plans[i].isArchived) return plans;
    return <InstallmentPlan>[
      for (final InstallmentPlan p in plans)
        if (p.id == planId) p.copyWithArchived(null) else p,
    ];
  }

  /// Puts a SETTLED plan away. Returns false and changes nothing otherwise.
  ///
  /// Nothing else moves: no entry, no balance, the register untouched, the
  /// `tx_inst_` rows still in Activity and still counting.
  bool archivePlan(String planId) {
    final int i = _installments.indexWhere(
      (InstallmentPlan p) => p.id == planId,
    );
    if (i < 0) return false;
    if (!_installments[i].isSettled) return false;
    if (_installments[i].isArchived) return false;

    _installments = <InstallmentPlan>[
      for (final InstallmentPlan p in _installments)
        if (p.id == planId) p.copyWithArchived(isoDate(now)) else p,
    ];
    notifyListeners();
    return true;
  }

  /// Brings an archived plan back. No confirmation anywhere behind it,
  /// because nothing is lost by tapping it.
  bool unarchivePlan(String planId) {
    final int i = _installments.indexWhere(
      (InstallmentPlan p) => p.id == planId,
    );
    if (i < 0 || !_installments[i].isArchived) return false;

    _installments = <InstallmentPlan>[
      for (final InstallmentPlan p in _installments)
        if (p.id == planId) p.copyWithArchived(null) else p,
    ];
    notifyListeners();
    return true;
  }

  /// Deletes a plan OUTRIGHT, and only one that never moved any money.
  ///
  /// This is the exit the Plans tab never had. Until it existed a plan could
  /// not be removed by any route: there is no delete, no archive, and no
  /// settle control on a plan card, so a plan restored from a backup that was
  /// cancelled or refinanced outside the app stayed in Safe to Spend's
  /// reserve for ever.
  ///
  /// THE GATE IS THE REGISTER, NOT THE COUNTER, and that distinction is the
  /// difference between a feature that works and one that does not.
  ///
  /// A first version also refused when `paidInstallments > 0`, by analogy
  /// with [deleteDebt]'s paid figure. Every one of the three seeded plans
  /// arrives with a counter of 5, 10 and 2 and an EMPTY register, so not one
  /// of them could be deleted, archived (not settled) or taken back from (no
  /// register). The exit still did not exist, which is the whole thing this
  /// was built to fix.
  ///
  /// The counter is a number copied off a contract. The REGISTER is what
  /// Salapify itself recorded, and it is the only thing that wrote ledger
  /// rows. So the real question is whether deleting this plan would leave
  /// entries in Activity explaining something that no longer exists, and
  /// that is answered by the register alone. A plan with none orphans
  /// nothing.
  ///
  /// A plan that HAS been paid through this app still refuses, and the route
  /// back is unchanged: take the payments back first, which empties the
  /// register and marks their entries corrected, then delete.
  bool deletePlan(String planId) {
    final int i = _installments.indexWhere(
      (InstallmentPlan p) => p.id == planId,
    );
    if (i < 0) return false;

    final InstallmentPlan p = _installments[i];
    if (p.payments.isNotEmpty || p.extraPayments.isNotEmpty) return false;

    _installments = <InstallmentPlan>[
      for (final InstallmentPlan x in _installments)
        if (x.id != planId) x,
    ];
    notifyListeners();
    return true;
  }

  bool takeBackPlanPayment(String planId) {
    final int i = _installments.indexWhere(
      (InstallmentPlan p) => p.id == planId,
    );
    if (i < 0) return false;

    final InstallmentPlan before = _installments[i];
    if (before.payments.isEmpty) return false;
    final PlanPayment row = before.payments.last;

    _installments = _unarchiveIfLive(
      reverseLastPlanPayment(_installments, planId),
      planId,
    );

    // MARKED, NOT REMOVED. setTransactionStatus moves the balance back on its
    // own, because the entry stops counting, so this must not also undo it.
    if (row.txId != null) {
      setTransactionStatus(row.txId!, TransactionStatus.corrected);
      return true;
    }

    notifyListeners();
    return true;
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

    // ARCHIVED IMPLIES SETTLED, and this line is what makes that an INVARIANT
    // rather than a precondition on one transition.
    //
    // [archiveDebt] refuses a live debt, which was taken to be enough. It was
    // not: the Archived section rendered the ordinary settle control, so two
    // taps produced a debt that was live AND archived. Because the `debts`
    // getter filters archived ones out, that debt then counted in NO total
    // anywhere, which is exactly the design the founder turned down on
    // 2026-10-02, reached by a different route. It also fed the reminder
    // engine, which skips settled debts and would therefore have raised a due
    // date for a debt on no screen.
    //
    // Un-settling brings it back to the list rather than refusing. Refusing
    // would leave a dead control, and there is nothing to protect here: the
    // person asked for this debt to be live again, and live debts belong on
    // the live list.
    final int i = next.indexWhere((Debt d) => d.id == debtId);
    _debts = (i >= 0 && !next[i].isSettled && next[i].isArchived)
        ? <Debt>[
            for (final Debt d in next)
              if (d.id == debtId) d.copyWith(clearArchivedAt: true) else d,
          ]
        : next;
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

    // What this payment ACTUALLY collects, worked out before the plan
    // moves. It is the quoted instalment on an ordinary month, less on the
    // adjusting final payment, and less again on a stub left by a
    // prepayment. Writing the quoted figure instead is what moved an
    // account by one number while the plan recorded another.
    final Money collected = nextPaymentFor(before);
    if (!collected.isPositive) return;

    final String txId = 'tx_inst_${DateTime.now().microsecondsSinceEpoch}';

    _installments = applyInstallmentPayment(
      _installments,
      planId,
      today: now,
      accountId: accountId,
      txId: accountId == null ? null : txId,
    );

    final Transaction? entry = installmentEntry(
      plan: before,
      installmentNumber: before.paidInstallments + 1,
      accountId: accountId,
      today: now,
      id: txId,
      amount: collected,
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
    Money amount, {
    String? accountId,
    String? note,
  }) {
    if (!amount.isPositive) return;
    final int i = _installments.indexWhere(
      (InstallmentPlan p) => p.id == planId,
    );
    if (i < 0) return;
    final InstallmentPlan before = _installments[i];

    final String txId =
        'tx_inst_extra_${DateTime.now().microsecondsSinceEpoch}';

    _installments = applyExtraPayment(
      _installments,
      planId,
      amount,
      today: now,
      note: note,
      accountId: accountId,
      txId: accountId == null ? null : txId,
    );

    // THE SAME POLICY THE ENGINE USES, read rather than re-derived.
    //
    // This used to cap at the principal while the engine capped at the
    // balance, so paying a plan off early credited the plan 6,591.20 and
    // moved the account by 5,600.00. The plan's EXTRA PAYMENTS row and the
    // account's own history disagreed by 991.20, with that much real cash
    // unaccounted for on either side.
    final Money applied = appliedExtraPayment(before, amount);

    final Transaction? entry = extraPaymentEntry(
      plan: before,
      amount: applied,
      accountId: accountId,
      today: now,
      id: txId,
      note: note,
    );
    if (entry != null) {
      logTransaction(entry);
      return;
    }
    notifyListeners();
  }

  /// The data file exactly as it is on disk, for the one case where Salapify
  /// cannot read it.
  ///
  /// NOT a snapshot. A snapshot in that state is the SEED, so handing somebody
  /// demo accounts labelled as their backup is how the real file gets thrown
  /// away. These are the bytes, whatever they are.
  Future<String?> rawStoredFile() => _store.read();

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
    final Money book = bookBalanceOf(account);
    final double variance = varianceOf(book.pesos, actualBalance);
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
      bookBalance: book.pesos,
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
  /// Changes one entry's status, and MOVES THE BALANCE TO MATCH.
  ///
  /// P1.2, from fix-before-launch 4 in the October expert review: "Marking an
  /// entry duplicate drops it from totals but leaves the account balance
  /// unchanged." Founder decision F10 settles it: the balance reverses, and
  /// un-marking restores it.
  ///
  /// ## Why it was wrong
  ///
  /// `countsTowardTotals` is false for `excluded` and `duplicate`, and
  /// `applyToBalances` returns the accounts untouched for exactly those two.
  /// So the moment a status crosses that line, the balance the entry once
  /// moved is stranded: the totals stop counting it and the account still
  /// carries it. Marking a 500 peso duplicate left the account 500 down with
  /// nothing in any total explaining the gap, which for somebody reconciling
  /// against a bank app is the defect, not a rounding nit.
  ///
  /// ## Why this is not new money math
  ///
  /// Both halves already existed and are locked to vectors generated from the
  /// prototype: `applyToBalances` and its exact mirror `reverseFromBalances`.
  /// This decides WHEN to call them and never how much. The direction is
  /// taken from whether the entry crossed the counting line, not from the
  /// status names, so a future third non-counting status needs no change
  /// here.
  ///
  /// The OLD entry is reversed and the NEW one applied, which matters because
  /// both functions early-return on a non-counting entry: reversing the new
  /// one would do nothing at all and look like it worked.
  void setTransactionStatus(String id, TransactionStatus status) {
    final int i = _transactions.indexWhere((Transaction t) => t.id == id);
    if (i < 0 || _transactions[i].status == status) return;

    final Transaction before = _transactions[i];
    _transactions = applyStatusChange(_transactions, id, status);
    final Transaction after = _transactions[i];

    if (before.countsTowardTotals && !after.countsTowardTotals) {
      _accounts = reverseFromBalances(_accounts, before);
    } else if (!before.countsTowardTotals && after.countsTowardTotals) {
      _accounts = applyToBalances(_accounts, after);
    }

    notifyListeners();
  }

  /// Takes one entry back out of every total, from Activity, at any time.
  ///
  /// This is the general answer to a question the app could only answer in
  /// one doorway. An ordinary logged entry had a five second Undo on the
  /// snackbar and nothing afterwards; everything else had nothing at all.
  /// Five seconds is a safety net for a slip, not a correction route: a
  /// person who notices on Tuesday that Saturday's lunch went out of the
  /// wrong account was simply stuck.
  ///
  /// ## It MARKS, it does not delete
  ///
  /// The row stays in Activity, struck through and labelled Taken back, and
  /// stops counting. That is deliberate and it is the founder's own ruling
  /// from 2026-10-02, when `corrected` joined the exclusion list: somebody
  /// keeping books needs the history to show what happened, including the
  /// correction. A row that vanishes leaves a balance that moved for no
  /// visible reason, which is the exact complaint that started this whole
  /// batch.
  ///
  /// ## A companion record is a refusal, not a warning
  ///
  /// Reversing a ledger row touches the ACCOUNT and nothing else. When
  /// Salapify wrote that row to explain something else, the something else
  /// does not move with it, and the result is money back in the account with
  /// a debt, a plan, a bill or a reconciliation elsewhere still saying it was
  /// paid. Reconciliation offered exactly that once and it was measured at
  /// 1,500.00.
  ///
  /// So this REFUSES anything with a companion, and the refusal names the
  /// screen that owns the real take-back, because a dead end is not an answer
  /// to somebody looking at their own money.
  ///
  /// ## Stored links first, id prefixes second, and the order is the point
  ///
  /// `DebtPayment.txId`, `PlanPayment.txId` and
  /// `ReconciliationRecord.adjustmentTxId` are STORED. Those three are facts
  /// and they survive a restored backup. The id prefixes
  /// ([Transaction.isEnginePayment] and the two below) are a guess at a
  /// string, which the model's own doc calls a stopgap, so they run second as
  /// a backstop: an entry written by some older build whose register row did
  /// not survive still gets refused on its id rather than waved through.
  ///
  /// The two that have ONLY the guess are bills and splits, because
  /// `UpcomingItem` carries no transaction id and a split's link is a shared
  /// timestamp inside two id strings. Both are named here rather than
  /// quietly treated as ordinary, and both are the argument for storing the
  /// link properly, which is a change to saved data and therefore the
  /// founder's call rather than mine.
  ///
  /// The RAW lists are scanned, not the filtered getters. An archived debt or
  /// plan still owns its payment rows, and missing one because it is archived
  /// would wave through exactly the entry this method exists to refuse.
  TakeBackOutcome takeBackEntry(String txId) {
    final TakeBackOutcome route = takeBackPreview(txId);
    if (route != TakeBackOutcome.done) return route;
    setTransactionStatus(txId, TransactionStatus.corrected);
    return TakeBackOutcome.done;
  }

  /// What [takeBackEntry] WOULD do, changing nothing.
  ///
  /// The sheet asks this before it draws, so a person is never invited to
  /// confirm something that was always going to be refused. Confirming a
  /// decision and then being told no is how an app teaches somebody that its
  /// buttons do not mean anything.
  ///
  /// The two share this one body on purpose. An earlier shape had the screen
  /// deciding whether to show the button and the store deciding whether to
  /// act, which is a rule enforced at one entry point and not the other, the
  /// single defect shape this feature area has now produced five times.
  ///
  /// [TakeBackOutcome.done] from here means "it would be taken back", not
  /// that anything has been.
  TakeBackOutcome takeBackPreview(String txId) {
    final int i = _transactions.indexWhere((Transaction t) => t.id == txId);
    if (i < 0) return TakeBackOutcome.gone;

    final Transaction tx = _transactions[i];
    // Already out of the totals. Reversing again would credit the money back
    // a second time, which setTransactionStatus guards too; this is the
    // earlier, clearer refusal, so the sheet can say why.
    if (!tx.countsTowardTotals) return TakeBackOutcome.alreadyNotCounting;

    for (final Debt d in _debts) {
      for (final DebtPayment p in d.payments) {
        if (p.txId == txId) return TakeBackOutcome.belongsToDebt;
      }
    }

    // Covers prepayments too: applyExtraPayment writes a PlanPayment row
    // beside the ExtraPayment, and the PlanPayment is the one carrying the
    // link. ExtraPayment has no txId of its own.
    for (final InstallmentPlan plan in _installments) {
      for (final PlanPayment p in plan.payments) {
        if (p.txId == txId) return TakeBackOutcome.belongsToPlan;
      }
    }

    for (final ReconciliationRecord r in _reconciliations) {
      if (r.adjustmentTxId == txId) {
        return TakeBackOutcome.belongsToReconciliation;
      }
    }

    // THE GUESSES, after the facts. See the doc above.
    if (tx.isEnginePayment) {
      return txId.startsWith('tx_debt_')
          ? TakeBackOutcome.belongsToDebt
          : TakeBackOutcome.belongsToPlan;
    }
    // A bill needs no survival check, and the asymmetry below is the reason.
    // `undoUpcomingPaid` takes the transaction and calls
    // `undoLoggedTransaction`, so un-ticking the bill REMOVES this entry
    // outright. Follow the refusal's instruction and there is nothing left to
    // refuse, so the route clears itself the way the three stored links do.
    if (txId.startsWith('tx_bill_')) return TakeBackOutcome.belongsToBill;

    // A SPLIT DOES NEED ONE, and shipping it without was a dead end.
    //
    // The refusal tells somebody "the debts it created are still standing,
    // remove those debts from the Debts screen first". The first version of
    // this line returned on the id prefix alone, unconditionally, so they
    // could do exactly that and come back to the identical sentence, now
    // false, with the expense still unreachable forever. Nothing else in the
    // app could take it back either: the five second snackbar was long gone.
    //
    // The test that was supposed to guard this proved the defect instead. It
    // was named "a split entry is refused, because its debts are still
    // standing" and its fixture passed NO DEBTS AT ALL, so it asserted the
    // refusal in precisely the state where the refusal is wrong.
    //
    // The debts carry the link in their ids: `tx_split_<stamp>` writes
    // `debt_split_<stamp>_<seq>`. That is the same guess the prefix itself is,
    // with the same limit (an older build's ids, a restored backup), and it is
    // what there is until the link is stored properly.
    if (txId.startsWith('tx_split_')) {
      final String stamp = txId.substring('tx_split_'.length);
      final String born = 'debt_split_${stamp}_';
      // ANY, not all. One receivable left standing is still a person who
      // owes for a bill that would no longer exist.
      if (_debts.any((Debt d) => d.id.startsWith(born))) {
        return TakeBackOutcome.belongsToSplit;
      }
    }

    return TakeBackOutcome.done;
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
  /// IT PERSISTS. This comment used to say "in memory only, there is no
  /// storage layer in app/ yet, so this is gone on the next cold start", and
  /// that stopped being true when storage landed: `notifyListeners` is
  /// overridden on this store and writes the whole snapshot. The shell's own
  /// confirmation already said "Saved to this phone", so the code and the
  /// comment had been disagreeing about the single most reassuring fact in
  /// the app.
  ///
  /// It matters beyond tidiness, because the save is what makes
  /// [undoLoggedTransaction] a second write rather than a memory edit, and
  /// that is the whole question the undo had to answer.
  void logTransaction(Transaction tx) {
    _transactions = <Transaction>[tx, ..._transactions];
    _accounts = applyToBalances(_accounts, tx);
    notifyListeners();
  }

  /// Takes a just-logged entry straight back out again.
  ///
  /// FOR THE SNACKBAR UNDO ON A FRESH ENTRY, AND NOTHING ELSE. It removes the
  /// row and reverses its effect on the balances, which is the exact inverse
  /// of [logTransaction].
  ///
  /// ## Why a snackbar undo is allowed here when it was refused twice above
  ///
  /// `undoLastImport` and `restoreSampleData` both say, in their own words,
  /// that a snackbar undo would be a second write racing the first and would
  /// leave a half swapped ledger if the app died in the gap. That reasoning
  /// is right and it does not reach this case, for two reasons worth writing
  /// down rather than rediscovering.
  ///
  /// First, those two REPLACE the whole ledger and depend on a second file,
  /// the pre-import copy, being swapped in step with it. Two files can
  /// disagree. This touches one row and the balances it moved, inside the
  /// single snapshot that is written atomically with a previous generation
  /// kept, so there is no intermediate state to be caught in: either the save
  /// with the row landed or the save without it did.
  ///
  /// Second, the failure is benign in a way theirs is not. The worst outcome
  /// here is one extra entry somebody can see on Activity and correct. Theirs
  /// is a ledger half in one shape and half in another with no way back.
  ///
  /// It is still deliberately narrow: it takes the whole transaction rather
  /// than an id, so a caller cannot ask to remove something it has not got in
  /// front of it, and it does nothing at all when the row has already gone.
  void undoLoggedTransaction(Transaction tx) {
    final int before = _transactions.length;
    _transactions = _transactions
        .where((Transaction t) => t.id != tx.id)
        .toList();
    // Nothing removed means nothing to reverse. Without this, tapping Undo
    // twice would credit the money back twice.
    if (_transactions.length == before) return;
    _accounts = reverseFromBalances(_accounts, tx);
    notifyListeners();
  }

  /// Takes a whole Split Bill straight back out again, BOTH HALVES OR NEITHER.
  ///
  /// A split is not one record. One tap writes a receivable for every other
  /// person and, usually, an expense for the whole bill, and the two only mean
  /// anything together: the expense is the money that left the account, the
  /// debts are what brings it back. Undoing one and leaving the other is the
  /// exact half-landed state the duplicate control on Reconciliation already
  /// refuses to create, where money returns to an account and a record
  /// somewhere else still says it is owed, with no screen explaining the
  /// difference.
  ///
  /// So this is ALL OR NOTHING, in both directions:
  ///
  /// 1. It REFUSES WHOLE, returning false and touching nothing, if any of the
  ///    split's debts has since been paid against. That payment is somebody's
  ///    real money and it is not this undo's to erase. The gate is the same
  ///    one [deleteDebt] uses, deliberately, so the two cannot drift apart.
  /// 2. When it does act, both halves move inside ONE notifyListeners, which
  ///    is one snapshot write. There is no instant where the file holds the
  ///    expense without the debts.
  ///
  /// It takes the OBJECTS the split created rather than ids, for the same
  /// reason [undoLoggedTransaction] does: a caller cannot ask to remove
  /// something it has not got in front of it.
  bool undoSplitBill({required Transaction? tx, required List<Debt> debts}) {
    // CHECKED BEFORE ANYTHING IS TOUCHED. A refusal halfway through would be
    // the half-landed state this method exists to prevent.
    for (final Debt d in debts) {
      final int i = _debts.indexWhere((Debt x) => x.id == d.id);
      // Already gone, which is fine: the person deleted it by hand and there
      // is nothing left to protect.
      if (i < 0) continue;
      final Debt live = _debts[i];
      if (live.paidAmount.isPositive || live.payments.isNotEmpty) return false;
    }

    bool changed = false;

    if (tx != null) {
      final int before = _transactions.length;
      _transactions = _transactions
          .where((Transaction t) => t.id != tx.id)
          .toList();
      // Nothing removed means nothing to reverse. Without this, a second tap
      // would credit the money back twice.
      if (_transactions.length != before) {
        _accounts = reverseFromBalances(_accounts, tx);
        changed = true;
      }
    }

    final Set<String> ids = <String>{for (final Debt d in debts) d.id};
    final int debtsBefore = _debts.length;
    _debts = <Debt>[
      for (final Debt d in _debts)
        if (!ids.contains(d.id)) d,
    ];
    if (_debts.length != debtsBefore) changed = true;

    // ONE notify for both halves, which is one save. See the doc above.
    if (changed) notifyListeners();
    return true;
  }

  /// Changes one budget's monthly limit.
  ///
  /// The decision about what is a valid limit lives in applyBudgetLimit, in
  /// core/money/plan.dart, which is vector-locked. This method decides WHEN,
  /// never WHAT, which is the same split every other write on this store uses.
  void setBudgetLimit(String category, Money limit) {
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
  void contributeToGoal(String goalId, Money amount) {
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

  /// Schedules a new bill or expected payment.
  ///
  /// Ported from addUpcoming in src/context/FinancialContext.tsx. No money
  /// moves: scheduling something is a note about the future, and the balance
  /// only changes when it is marked paid.
  void addUpcoming(UpcomingItem item) {
    _upcoming = <UpcomingItem>[..._upcoming, item];
    notifyListeners();
  }

  /// Removes a scheduled item.
  ///
  /// No money moves here either, INCLUDING when the item was already marked
  /// paid. Marking paid writes a ledger entry, and that entry is a record of
  /// something that really happened; deleting the schedule row must not
  /// silently reach into the ledger and un-spend money. The entry stays and
  /// is undone from Activity like any other, which is the one place a person
  /// expects to undo a transaction.
  void deleteUpcoming(String id) {
    _upcoming = _upcoming.where((UpcomingItem u) => u.id != id).toList();
    notifyListeners();
  }

  /// Marks a scheduled item paid AND moves the money.
  ///
  /// Founder direction, 2026-10-01, choosing between three options: "Yes, with
  /// an account picker". Until this, the tick only flipped a flag, so somebody
  /// could mark Meralco paid and find their balance untouched and nothing in
  /// Activity, which is the exact shape of defect CLAUDE.md's "a write path is
  /// not tested until somebody can SEE what it did" rule was written for.
  ///
  /// Returns the ledger entry it wrote, or null when it wrote none, so the
  /// caller can offer an undo. A tick that moves real money needs a way back,
  /// and the ONLY way back otherwise is finding the entry in Activity and
  /// knowing it was the bill that put it there.
  ///
  /// ## Three prototype behaviours deliberately not carried over
  ///
  /// 1. It hardcodes `subcategory: 'Electricity (Meralco)'` on EVERY bill, so
  ///    paying Spotify files it under electricity. [defaultCategoryFor]
  ///    decides instead, from the item's own category when it has one and
  ///    from its type when it does not. The caller may override it, which the
  ///    pay dialog offers, because a category is a judgement and the person
  ///    paying knows better than a map does.
  /// 2. It hardcodes `profile: 'household'`. The app already infers a profile
  ///    from the name and category, and that inference is used instead.
  /// 3. It falls back to `accounts[0]?.id` when no account is given, writing a
  ///    real expense against whichever account happens to be first with no
  ///    signal at all. This refuses instead: no account, no ledger entry. The
  ///    sheet makes the picker required, so the refusal is unreachable from
  ///    the UI and exists for callers that are not the UI.
  ///
  /// Income rows move nothing, which IS the prototype's behaviour
  /// (`if (targetAccountId && !item.isIncome)`). Ticking a payday marks it
  /// arrived without inventing a deposit, because the real deposit is logged
  /// when it lands and a second one would double count it.
  Transaction? markUpcomingPaid(
    String id, {
    String? accountId,
    String? category,
  }) {
    final int i = _upcoming.indexWhere((UpcomingItem u) => u.id == id);
    if (i == -1 || _upcoming[i].isPaid) return null;
    final UpcomingItem old = _upcoming[i];

    _upcoming = <UpcomingItem>[
      ..._upcoming.sublist(0, i),
      UpcomingItem(
        id: old.id,
        name: old.name,
        amount: old.amount,
        dueDate: old.dueDate,
        type: old.type,
        isIncome: old.isIncome,
        isPaid: true,
        category: old.category,
        isSample: old.isSample,
      ),
      ..._upcoming.sublist(i + 1),
    ];

    if (accountId == null ||
        old.countsAsIncome ||
        !_accounts.any((Account a) => a.id == accountId)) {
      notifyListeners();
      return null;
    }

    final DateTime today = now;
    final Transaction tx = Transaction(
      id: 'tx_bill_${DateTime.now().microsecondsSinceEpoch}',
      type: TransactionType.expense,
      amount: old.amount,
      category: category ?? defaultCategoryFor(old),
      accountId: accountId,
      merchant: old.name,
      date:
          '${today.year}-${today.month.toString().padLeft(2, '0')}-'
          '${today.day.toString().padLeft(2, '0')}',
      createdAt: DateTime.now().millisecondsSinceEpoch,
      note: 'Paid scheduled item: ${old.name}',
      profile: profileOf(old),
    );

    // logTransaction notifies, so the flag edit above rides out with it.
    logTransaction(tx);
    return tx;
  }

  /// Takes a bill back off "paid", and reverses the entry it wrote.
  ///
  /// The recovery half of [markUpcomingPaid]. A tick that moves money and
  /// cannot be untapped is a trap on a screen full of small round targets,
  /// and the ledger entry has to come back off with the flag or the balance
  /// stays wrong while the bill reads unpaid.
  void undoUpcomingPaid(String id, Transaction? written) {
    final int i = _upcoming.indexWhere((UpcomingItem u) => u.id == id);
    if (i == -1) return;
    final UpcomingItem old = _upcoming[i];
    _upcoming = <UpcomingItem>[
      ..._upcoming.sublist(0, i),
      UpcomingItem(
        id: old.id,
        name: old.name,
        amount: old.amount,
        dueDate: old.dueDate,
        type: old.type,
        isIncome: old.isIncome,
        category: old.category,
        isSample: old.isSample,
      ),
      ..._upcoming.sublist(i + 1),
    ];
    if (written != null) {
      // Notifies on its own, and is a no-op if the row is already gone, so a
      // double undo cannot credit the money back twice.
      undoLoggedTransaction(written);
    } else {
      notifyListeners();
    }
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

  Money get totalInflows => profileUpcoming
      .where((UpcomingItem u) => u.countsAsIncome)
      .fold<Money>(Money.zero, (Money s, UpcomingItem u) => s + u.amount);

  Money get totalOutflows => profileUpcoming
      .where((UpcomingItem u) => !u.countsAsIncome)
      .fold<Money>(Money.zero, (Money s, UpcomingItem u) => s + u.amount);

  Money get netMovement => totalInflows - totalOutflows;

  /// Everything a person owes, across unsettled debts pointing outward.
  double get debtsIOwe => debts
      .where((Debt d) => !d.isSettled && d.direction == DebtDirection.iOwe)
      .fold<double>(0, (double sum, Debt d) => sum + d.remaining.pesos);

  /// Everything owed back to them.
  double get debtsOwedToMe => debts
      .where((Debt d) => !d.isSettled && d.direction == DebtDirection.owedToMe)
      .fold<double>(0, (double sum, Debt d) => sum + d.remaining.pesos);

  /// The soonest unsettled debt the person actually has to pay.
  ///
  /// Delegates to [nextPaymentDue] rather than sorting here, because this
  /// getter had its own private idea of what a due date is and it was wrong:
  /// it compared the free-text date as a STRING, so "Oct 11" sorted before
  /// "Oct 4" and Home named a debt a week away instead of the one due today.
  /// `daysUntil` is the one correct reader of that field and the tray and
  /// the runway already used it.
  Debt? get nextDueDebt => nextPaymentDue(debts, now);

  /// Spendable cash only. This is NOT net worth: it leaves out investments,
  /// receivables, every borrowing line, and money the person has set aside.
  ///
  /// Two rules, from two changes, and they compose rather than compete.
  /// `isSpendable` is a strict subset of `isLiquid`, so WHICH accounts count
  /// and HOW their balances are added are independent questions:
  ///
  ///  1. WHICH: `isSpendable`, because the one thing that reads this is
  ///     `PanFacts.liquidCash`, which Pan says out loud as "you can reach X
  ///     today". An emergency fund is not money you can reach today in any
  ///     sense Pan means, and a mascot cheerfully counting somebody's ipon
  ///     into their spending money is the defect at its most embarrassing.
  ///  2. HOW: through [accountsTotalPhp], which converts each balance first.
  ///     This used to fold `a.balance.pesos`, the RAW stored figure, so an
  ///     OFW with a dollar payroll account had dollars added to pesos and the
  ///     total labelled pesos. Same sentence of Pan's, wrong for a different
  ///     reason. The two lines beside it in [panFacts] already converted;
  ///     this one did not, and a peso-only fixture cannot tell the difference.
  double get totalLiquidCash =>
      accountsTotalPhp(accounts.where((Account a) => a.isSpendable));

  /// The five-question health check, from one place.
  ///
  /// Both the sheet and the dot on Home read THIS, rather than each running
  /// the engine with its own idea of the inputs. A marker on a screen that
  /// disagrees with the screen it opens is worse than no marker.
  HealthReport get healthReport => runHealthCheck(
    transactions: _transactions,
    accounts: accounts,
    budgets: _budgets,
    goals: _goals,
    bills: _bills,
    installments: _installments,
    payday: payday,
    now: now,
  );

  DailyProjection? _projection;
  int _projectionStamp = -1;

  /// The Sweldo Runway: what the balance DOES between now and the horizon.
  ///
  /// A different question from [safeToSpendAnalysis] over a different window,
  /// and the two must never be merged. Safe to Spend answers how much may be
  /// spent. This answers which DAY gets tight, which is the first figure in
  /// Salapify somebody can act on rather than only obey.
  ///
  /// MEMOISED, because it walks forty-five days and Home rebuilds on every
  /// notifyListeners. The stamp is a cheap shape of the inputs rather than a
  /// deep compare: the point is to skip the walk between repaints of an
  /// unchanged ledger, and anything that actually moves money changes one of
  /// these counts or totals. A stamp that misses a change costs a stale card
  /// for one frame, so it deliberately includes the balances rather than only
  /// the lengths.
  DailyProjection get dailyProjection {
    final int stamp = Object.hash(
      _accounts.length,
      accountsTotalPhp(_accounts.where((Account a) => a.isSpendable)),
      _bills.length,
      _upcoming.length,
      _installments.length,
      _debts.length,
      _payday,
      now.day,
      now.month,
      now.year,
      _debts.fold<int>(0, (int a, Debt d) => a + d.remaining.centavos),
      _bills.fold<int>(0, (int a, BillItem b) => a + b.amount.centavos),
    );
    if (_projection != null && _projectionStamp == stamp) return _projection!;
    _projectionStamp = stamp;
    return _projection = projectDailyCash(
      accounts: _accounts,
      bills: _bills,
      upcoming: _upcoming,
      installments: _installments,
      debts: _debts,
      payday: payday,
      now: now,
    );
  }

  SafeToSpendAnalysis get safeToSpendAnalysis => computeSafeToSpend(
    // CONVERTED ON THE WAY IN. The engine is a line-for-line port of a
    // prototype with no currency field, so it sums `balance` raw and has to
    // keep doing so to stay golden-locked. Converting here instead means
    // every surface answers "how much liquid cash" with the same number.
    //
    // Before this, Pan read the converted total while the engine read the
    // raw one, and Pan's own explanation stopped adding up: on 20,000 pesos
    // plus 1,000 dollars it said "Safe to Spend is 15,173, it starts from
    // the 78,500 you can reach and holds back 3,150", three figures that
    // cannot all be true at once. A sentence whose whole job is to show its
    // working is the worst place in the app for an inconsistency.
    //
    // Peso-only ledgers are bit for bit unchanged, which is why the golden
    // vectors do not move.
    accounts: accountsInPhp(accounts),
    transactions: _transactions,
    // _bills and _installments, NOT the seed. Both read the frozen seed list
    // until now, and the comment below about incomeStreams describes exactly
    // this defect while two arguments above it had the same one: a bill or a
    // plan the user pays off stays reserved forever, and a demo bill they
    // never entered reserves money on day one. Measured before the fix: one
    // real 50,000 peso account gave a Safe to Spend of 0.00.
    bills: _bills,
    debtsIOwe: debtsIOwe,
    // What the debts REALLY cost each month, instead of the prototype's eight
    // percent of the balance. See Debt.monthlyMinimum.
    declaredDebtMinimums: monthlyDebtMinimums(debts).pesos,
    installments: _installments,
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

  Money get safeToSpend => safeToSpendAnalysis.safeToSpendUntilPayday;
  Money get safeToSpendPerDay => safeToSpendAnalysis.safeToSpendToday;

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

  // -------------------------------------------------------------------------
  // Import and undo
  // -------------------------------------------------------------------------

  /// Replaces the WHOLE ledger with [incoming], keeping a copy of what is here.
  ///
  /// Returns false and changes nothing when it cannot keep that copy. That
  /// refusal is the design rather than caution: the confirmation promises the
  /// person can put their ledger back, and the only way to keep a promise like
  /// that is to decline the import when it cannot be kept.
  ///
  /// THE ORDERING IS THE SAFETY PROPERTY. The copy lands first, then the new
  /// ledger is applied and saved. A phone that dies in between leaves the old
  /// ledger plus a copy of the old ledger, which is a harmless no-op. There is
  /// no interleaving that produces a new ledger with no way back.
  Future<bool> importSnapshot(Snapshot incoming) async {
    // AN UNREADABLE FILE NO LONGER BLOCKS AN IMPORT, and the reason the block
    // existed is the reason it can be lifted.
    //
    // It was right that `snapshot()` in that state is the SEED, so the
    // ordinary pre-import copy would have preserved eleven demo accounts and
    // written over the person's real file. But that argument gives the fix
    // rather than forbidding it: copy the BYTES instead. They are what the
    // person needs back, and they are exactly what is on disk.
    //
    // Refusing was the worse answer. Somebody with an unreadable file and a
    // good backup in their email had no move at all except to uninstall,
    // which destroys the very file they might still have rescued.
    if (!_saveEnabled) {
      final String? raw = await _store.read();
      if (raw == null || raw.trim().isEmpty) {
        // Nothing on disk to preserve means nothing to protect, but it also
        // means the copy promise cannot be kept, and this method's whole
        // contract is that the copy lands first. Refuse rather than weaken it.
        return false;
      }
      try {
        await _store.writePreImport(raw);
      } on Object {
        return false;
      }
      _apply(incoming);
      _saveEnabled = true;

      // AND THE WARNINGS COME DOWN, which this branch forgot to do while the
      // ordinary branch below has always done it.
      //
      // The rescue worked, so every sentence the app was showing about the
      // old file is now false, and they were strong sentences: Home said
      // "These figures are not yours ... nothing you type now is being
      // saved", Settings said entries were NOT being saved, and the export
      // row offered "the file Salapify cannot read" and named the download
      // salapify-unreadable. All of it over the person's own correctly
      // restored money, until the app was next restarted.
      //
      // That is worse than cosmetic. Somebody told their rescue failed will
      // restore again, or wipe, or uninstall, and uninstalling at that moment
      // deletes the real, correct, saved file this method just wrote.
      _loadStatus = LoadStatus.loaded;
      _loadProblem = null;

      await _writeNow();
      notifyListeners();
      return true;
    }

    // Land any queued write first, so the copy is of what is actually saved
    // rather than of a state one notification behind it.
    await flushWrites();

    try {
      await _store.writePreImport(snapshot().encode(at: now));
    } on Object catch (e) {
      _reportSaveProblem(
        'Salapify could not keep a copy of your current ledger, so it did not '
        'restore the backup. Nothing has changed. $e',
      );
      return false;
    }

    // The whole document: extras, the sample flags, the removal marker,
    // payday, theme, scenario and profile all come from the FILE. Carrying
    // any of them across would attach this phone's state to somebody else's
    // ledger, and the sample marker is the dangerous one: kept locally, it
    // would offer to inject demo money into a real book.
    _apply(incoming);

    // The recovered-load banner is not true of what is on screen any more.
    _loadStatus = LoadStatus.loaded;
    _loadProblem = null;

    notifyListeners();
    await flushWrites();
    return true;
  }

  /// What the ledger held before the last import, or null when there is none
  /// this build can put back.
  ///
  /// Reads the file every time. There is deliberately NO flag: a flag can go
  /// stale, and one stored in the ledger itself would travel inside an
  /// exported backup and point at a file that does not exist on the phone
  /// that receives it.
  Future<LedgerSummary?> previousLedger() async {
    try {
      final String? raw = await _store.readPreImport();
      if (raw == null) return null;
      final ImportCheck check = checkImportFile(raw);
      return check is ImportReady ? check.summary : null;
    } on Object {
      return null;
    }
  }

  /// Puts back the ledger from before the last import, and keeps the current
  /// one as the new pre-import copy.
  ///
  /// A SWAP, not a restore, so nobody is trapped in the other direction: undo
  /// the undo and you are back where you started. And a permanent Settings
  /// row rather than a snackbar, for the reason restoreSampleData already
  /// records: every mutation here persists immediately, so a snackbar undo
  /// would be a second write racing the first, and an app killed in the gap
  /// would leave a half swapped ledger with no way back. A file has no race
  /// and no window.
  Future<bool> undoLastImport() async {
    if (!_saveEnabled) return false;

    final String? raw = await _store.readPreImport();
    if (raw == null) return false;

    final ImportCheck check = checkImportFile(raw);
    if (check is! ImportReady) return false;

    await flushWrites();

    try {
      await _store.writePreImport(snapshot().encode(at: now));
    } on Object catch (e) {
      _reportSaveProblem(
        'Salapify could not keep a copy of what is here now, so it did not '
        'put the earlier ledger back. Nothing has changed. $e',
      );
      return false;
    }

    _apply(check.incoming);
    _loadStatus = LoadStatus.loaded;
    _loadProblem = null;
    notifyListeners();
    await flushWrites();
    return true;
  }

  // -------------------------------------------------------------------------
  // Sample data
  // -------------------------------------------------------------------------

  String? _sampleRemovedAt;

  String? _onboardedAt;

  String? _setAsideReviewedAt;

  // -------------------------------------------------------------------------
  // P2.3, the one-time "which of these is set aside" card
  // -------------------------------------------------------------------------

  /// Whether to offer the card that asks which accounts are money set aside.
  ///
  /// The defect this closes is silent: `Account.purpose` defaults to spendable
  /// and the app never guesses, which is correct, but it means an existing
  /// ledger keeps counting somebody's ipon as pocket money until they go and
  /// say otherwise. Nobody goes looking for a setting whose absence they
  /// cannot see, so the app asks once.
  ///
  /// ASKS. It does not pre-tick anything, and it is not a nag:
  ///
  ///   - once answered OR dismissed it never returns, because
  ///     [_setAsideReviewedAt] is stored in the backup and not in memory;
  ///   - it needs at least TWO liquid accounts, since the question is
  ///     meaningless to somebody with one wallet and it would be the first
  ///     thing a brand new user saw;
  ///   - it needs one real account, so a demo ledger nobody owns is never
  ///     interrogated about money that is not theirs;
  ///   - and it stays away while the file is unreadable, where nothing the
  ///     person does can be saved.
  bool get shouldOfferSetAsideReview {
    if (_loadStatus == LoadStatus.unreadable) return false;
    if (_setAsideReviewedAt != null) return false;
    if (_accounts.where((Account a) => a.isLiquid).length < 2) return false;
    if (!_accounts.any((Account a) => a.isLiquid && !a.isSample)) return false;
    // Somebody who has already set one is plainly aware of the feature.
    if (_accounts.any((Account a) => a.purpose == AccountPurpose.protected)) {
      return false;
    }
    return true;
  }

  /// Record that the card has been answered or dismissed, either way.
  ///
  /// Deliberately one method for both outcomes. "Not now" and "none of them"
  /// are the same instruction as far as this app is concerned, and offering
  /// to ask again later is how a one-time card becomes a weekly one.
  void markSetAsideReviewed() {
    if (_setAsideReviewedAt != null) return;
    _setAsideReviewedAt = isoDate(now);
    notifyListeners();
  }

  /// Set, or clear, the protected flag on one account.
  ///
  /// Goes through [updateAccount] rather than writing the list directly, so
  /// the review card and the account sheet take exactly the same path into
  /// the store and cannot drift in what they persist.
  void setAccountPurpose(String id, AccountPurpose purpose) {
    final int i = _accounts.indexWhere((Account a) => a.id == id);
    if (i < 0) return;
    if (_accounts[i].purpose == purpose) return;
    updateAccount(_accounts[i].copyWith(purpose: purpose));
  }

  /// What the person has spent today, from entries that count.
  ///
  /// Counts only entries the PERSON made. A demo ledger dated by offsets from
  /// today would otherwise put a stranger's lunch in a row that says "today",
  /// which is the whole defect class the first run work exists to close.
  ///
  /// Transfers are excluded with income, because neither is spending: moving
  /// money between your own accounts is not a day's outlay and counting it
  /// would make the figure jump for a reason nobody could see.
  Money get spentToday {
    final String today = isoDate(now);
    Money total = Money.zero;
    for (final Transaction t in _transactions) {
      if (t.isSample) continue;
      if (t.date != today) continue;
      if (!t.countsTowardTotals) continue;
      if (t.type != TransactionType.expense) continue;
      total = total + t.amount;
    }
    return total;
  }

  /// How many entries today's figure is made of, so a screen can say so.
  int get loggedTodayCount {
    final String today = isoDate(now);
    return _transactions
        .where(
          (Transaction t) =>
              !t.isSample &&
              t.date == today &&
              t.countsTowardTotals &&
              t.type == TransactionType.expense,
        )
        .length;
  }

  /// Whether the welcome still has to be shown.
  ///
  /// TWO QUESTIONS, not one, and the second is what makes this safe. The
  /// stored flag answers "has this app introduced itself on this phone".
  /// On its own it would march somebody through a first run they finished
  /// months ago the moment they restored a backup taken before the field
  /// existed, because that file honestly says null.
  ///
  /// So a ledger that already holds records the person made is treated as
  /// onboarded whatever the flag says. Somebody with their own accounts and
  /// their own entries has plainly met this app before, and asking them where
  /// their money is would be the app forgetting them.
  ///
  /// `hasSampleData` is deliberately NOT part of this. A phone holding only
  /// the demo has not started, which is exactly the state the welcome is for.
  bool get needsWelcome {
    // NEVER OVER AN UNREADABLE FILE, and this is a safety rule rather than a
    // tidiness one. A ledger Salapify cannot parse still shows the SEED in
    // memory, so every test below would say "nothing here, introduce
    // yourself" to somebody whose real book is sitting on the disk intact and
    // merely unread. They would meet a cheerful welcome instead of the banner
    // that tells them their data could not be read, and the one thing they
    // must not do in that state is start typing a replacement.
    //
    // Saving is already off in this state, so nothing they did could land.
    // That makes the welcome worse, not better: it would be a first run that
    // silently discards itself.
    if (_loadStatus == LoadStatus.unreadable) return false;

    if (_onboardedAt != null) return false;
    if (_accounts.any((Account a) => !a.isSample)) return false;
    if (_transactions.any((Transaction t) => !t.isSample)) return false;
    if (_debts.any((Debt d) => !d.isSample)) return false;
    return true;
  }

  /// The person chose to start with their own money.
  ///
  /// EVERY DEMO RECORD GOES, and the payday with it. That last part is the
  /// one worth naming: `SeedData.payday` is not merely absent on a fresh
  /// install, it is FABRICATED, carrying a 15th and 30th cycle, a next payday
  /// and 32,500 of expected income. The hero draws a countdown off it, so an
  /// untouched install counts down to somebody else's sweldo. Starting real
  /// and leaving that behind would be the same defect this whole path exists
  /// to remove.
  ///
  /// The sweep is reused rather than reimplemented. It already knows every
  /// rule: which collections carry `isSample`, that the payday and the income
  /// streams are Salapify's too, and that a demo account the person has
  /// already used gets ADOPTED rather than deleted. Writing a second emptier
  /// here would be a second copy of all of that, and the copies would drift.
  ///
  /// Nothing has been typed yet at this point, so there is nothing to adopt
  /// and the sweep simply clears the lot.
  void startWithOwnMoney({
    required String accountName,
    required Money opening,
  }) {
    removeSampleData();

    // The sweep records a removal, and here that is false: nothing was ever
    // taken away from this person, so the put-it-back control must not
    // appear. `canRestoreSampleData` reads this, and offering somebody who
    // chose their own money a button that injects a stranger's payroll is
    // precisely the mixing this path exists to prevent.
    _sampleRemovedAt = null;

    addAccount(
      Account(
        id: 'acc_${now.microsecondsSinceEpoch}',
        name: accountName,
        kind: AccountKind.cash,
        institution: '',
        monogram: _monogramOf(accountName),
        balance: opening,
      ),
    );

    _onboardedAt = isoDate(now);
    notifyListeners();
  }

  /// The person chose to look around first. The demo stays exactly as it is.
  ///
  /// Home then carries a permanent one line exit from it, which is the whole
  /// bargain: the demo is allowed to exist because somebody asked for it and
  /// because leaving is one tap from the screen they are looking at.
  void startWithExampleData() {
    // THE EXAMPLES HAVE TO ACTUALLY BE THERE, which this method assumed and
    // did not check until a founder tapped the button and reported that
    // nothing happened.
    //
    // It only set the flag, which is correct on a genuinely fresh install
    // because the constructor seeds and the welcome stands in front of that
    // seed. It is wrong after a WIPE: every collection is empty, so setting
    // the flag dismissed the welcome and landed somebody on an empty app. The
    // button promised example data and delivered a blank screen, which from
    // the outside is indistinguishable from a dead button.
    //
    // That gap was opened by the wipe fix shipped the same day. Making the
    // welcome come back after a wipe without making this path work from that
    // state turned one dead end into another.
    //
    // `restoreSampleData` is reused rather than reimplemented, for the reason
    // `startWithOwnMoney` reuses the sweep: it already knows every collection,
    // the payday, the income streams, and to skip any id already present so
    // it can never write over a record somebody made.
    if (!hasSampleData) restoreSampleData();

    _onboardedAt = isoDate(now);
    notifyListeners();
  }

  /// Two letters for an account with no institution behind it.
  ///
  /// The account sheet derives these from a brand when it knows one. This one
  /// is typed by a person on their first screen, so there is no brand to
  /// look up and the name itself is all there is.
  String _monogramOf(String name) {
    final List<String> words = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((String w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return 'SA';
    if (words.length == 1) {
      final String w = words.first;
      return (w.length == 1 ? w : w.substring(0, 2)).toUpperCase();
    }
    return '${words[0][0]}${words[1][0]}'.toUpperCase();
  }

  /// True while any record on this phone is still Salapify's own demo data.
  bool get hasSampleData =>
      _accounts.any((Account a) => a.isSample) ||
      _transactions.any((Transaction t) => t.isSample) ||
      _debts.any((Debt d) => d.isSample) ||
      _budgets.any((Budget b) => b.isSample) ||
      _goals.any((Goal g) => g.isSample) ||
      _upcoming.any((UpcomingItem u) => u.isSample) ||
      _installments.any((InstallmentPlan p) => p.isSample) ||
      _bills.any((BillItem b) => b.isSample);

  /// True once it has been removed AND is not back. Gates the put-it-back
  /// control, so a ledger restored from another phone never offers it.
  bool get canRestoreSampleData => _sampleRemovedAt != null && !hasSampleData;

  /// The ids of sample accounts that a record the USER made points at.
  ///
  /// These cannot be deleted. Somebody's first ever entry defaults to the
  /// first usable account, which on a new phone is a sample one, so deleting
  /// it would leave their transaction pointing at nothing: the entry would
  /// survive, the balance movement it caused would not, and no screen could
  /// explain the difference. They are adopted instead.
  Set<String> _sampleAccountsInUse() {
    final Set<String> used = <String>{};
    for (final Transaction t in _transactions) {
      if (t.isSample) continue;
      used.add(t.accountId);
      if (t.toAccountId != null) used.add(t.toAccountId!);
    }
    for (final ReconciliationRecord r in _reconciliations) {
      used.add(r.accountId);
    }
    return used
        .where(
          (String id) => _accounts.any((Account a) => a.id == id && a.isSample),
        )
        .toSet();
  }

  /// What is on the phone, so the confirmation can name it rather than saying
  /// "some data".
  SampleSummary get sampleSummary {
    final Set<String> kept = _sampleAccountsInUse();
    final List<Account> sampleAccounts = _accounts
        .where((Account a) => a.isSample)
        .toList();
    return SampleSummary(
      accounts: sampleAccounts.length,
      transactions: _transactions.where((Transaction t) => t.isSample).length,
      debts: _debts.where((Debt d) => d.isSample).length,
      budgets: _budgets.where((Budget b) => b.isSample).length,
      goals: _goals.where((Goal g) => g.isSample).length,
      upcoming: _upcoming.where((UpcomingItem u) => u.isSample).length,
      installments: _installments
          .where((InstallmentPlan p) => p.isSample)
          .length,
      bills: _bills.where((BillItem b) => b.isSample).length,
      assets: accountsTotalPhp(assetsOf(sampleAccounts)),
      liabilities: accountsTotalPhp(liabilitiesOf(sampleAccounts)),
      keptAccounts: sampleAccounts
          .where((Account a) => kept.contains(a.id))
          .toList(),
    );
  }

  /// Removes everything Salapify put there itself, and NOTHING else.
  ///
  /// The safety property is one condition, `isSample`, tested in one method.
  /// It is not a convention spread across eight collections that somebody has
  /// to remember, because that is the kind of rule that holds until the ninth
  /// collection is added.
  ///
  /// The one subtle case is an account the user's own entries point at. It is
  /// KEPT and adopted, with the seeded opening balance subtracted, so what
  /// remains is exactly the movement their own entries explain. Deleting it
  /// would silently destroy the balance half of their first ever entry.
  void removeSampleData() {
    if (!hasSampleData) return;

    final Set<String> keep = _sampleAccountsInUse();

    _transactions = _transactions
        .where((Transaction t) => !t.isSample)
        .toList();
    _debts = _debts.where((Debt d) => !d.isSample).toList();
    _budgets = _budgets.where((Budget b) => !b.isSample).toList();
    _goals = _goals.where((Goal g) => !g.isSample).toList();
    _upcoming = _upcoming.where((UpcomingItem u) => !u.isSample).toList();
    _installments = _installments
        .where((InstallmentPlan p) => !p.isSample)
        .toList();
    _bills = _bills.where((BillItem b) => !b.isSample).toList();

    _accounts = <Account>[
      for (final Account a in _accounts)
        if (!a.isSample)
          a
        else if (keep.contains(a.id))
          a.copyWith(
            // Take the seeded opening back out. What is left is the movement
            // the person's own entries caused, and nothing else.
            balance: a.balance - _seededBalanceOf(a.id),
            isSample: false,
          ),
    ];

    // The seed's payday is Salapify's, not theirs.
    _payday = PaydayCycle.unset;

    // AND SO IS THE SEED'S EXPECTED INCOME, which this sweep used to leave
    // behind. Every other collection here is filtered on `isSample`,
    // IncomeStream carries the same flag, and this one line was missing.
    //
    // It was not harmless. Safe to Spend reads the income streams, so after
    // a sweep the most prominent figure on Home was still being computed
    // from demo salary on an app with no accounts, no transactions and no
    // payday: the render of Health Check's empty state showed "Nothing
    // recorded yet" directly under a Home card reading ₱38,414.00 safe to
    // spend. One of those two was wrong and it was not the empty state.
    //
    // This is the mirror of a defect already recorded on _bills and
    // _payday: demo obligations nobody entered reaching a real figure. It
    // removes only rows Salapify put there itself, which is the same rule
    // every line above follows, so a stream the person added survives.
    _incomeStreams = _incomeStreams
        .where((IncomeStream s) => !s.isSample)
        .toList();

    // And so is anything the tray was reminding them about. Every message in
    // it was raised from a record that has just been deleted, so leaving it
    // would hand somebody a bill reminder naming a bill that is no longer on
    // any screen, which is unanswerable rather than merely stale.
    _notifications = <AppNotification>[];

    _sampleRemovedAt = now.toUtc().toIso8601String();
    notifyListeners();
  }

  /// No longer static, because the seed is built against a clock now.
  ///
  /// It only ever reads a BALANCE, which no date affects, so any clock would
  /// do. Taking the store's own keeps one answer to "what does the seed say"
  /// rather than two that could drift.
  Money _seededBalanceOf(String id) {
    for (final Account a in SeedData.accounts(now)) {
      if (a.id == id) return a.balance;
    }
    return Money.zero;
  }

  /// Puts the sample data back, without touching anything the person made.
  ///
  /// This is the undo, and it is a permanent control rather than a snackbar.
  /// Every mutation here saves immediately, so a snackbar undo would be a
  /// second write racing the first, and an app killed in between would leave
  /// a half swept ledger with no way back. A control that is still there next
  /// launch has no race and no window.
  void restoreSampleData() {
    final Set<String> accountIds = _accounts.map((Account a) => a.id).toSet();
    final Set<String> txIds = _transactions
        .map((Transaction t) => t.id)
        .toSet();
    final Set<String> debtIds = _debts.map((Debt d) => d.id).toSet();
    final Set<String> goalIds = _goals.map((Goal g) => g.id).toSet();
    final Set<String> upIds = _upcoming.map((UpcomingItem u) => u.id).toSet();
    final Set<String> planIds = _installments
        .map((InstallmentPlan p) => p.id)
        .toSet();
    final Set<String> billIds = _bills.map((BillItem b) => b.id).toSet();
    final Set<String> streamIds = _incomeStreams
        .map((IncomeStream s) => s.id)
        .toSet();
    final Set<String> categories = _budgets
        .map((Budget b) => b.category)
        .toSet();

    // Skip anything whose id is already here, so this can never overwrite a
    // record the person made or adopted. Their ids are timestamped, so a
    // collision with 'acc_bpi' is not possible in the first place; this is the
    // belt as well as the braces.
    _accounts = <Account>[
      ..._accounts,
      for (final Account a in SeedData.accounts(now))
        if (!accountIds.contains(a.id)) a,
    ];
    _transactions = <Transaction>[
      ..._transactions,
      for (final Transaction t in SeedData.transactions(now))
        if (!txIds.contains(t.id)) t,
    ];
    _debts = <Debt>[
      ..._debts,
      for (final Debt d in SeedData.debts(now))
        if (!debtIds.contains(d.id)) d,
    ];
    _budgets = <Budget>[
      ..._budgets,
      for (final Budget b in SeedData.budgets)
        if (!categories.contains(b.category)) b,
    ];
    _goals = <Goal>[
      ..._goals,
      for (final Goal g in SeedData.goals)
        if (!goalIds.contains(g.id)) g,
    ];
    _upcoming = <UpcomingItem>[
      ..._upcoming,
      for (final UpcomingItem u in SeedData.upcoming(now))
        if (!upIds.contains(u.id)) u,
    ];
    _installments = <InstallmentPlan>[
      ..._installments,
      for (final InstallmentPlan p in SeedData.installments(now))
        if (!planIds.contains(p.id)) p,
    ];
    _bills = <BillItem>[
      ..._bills,
      for (final BillItem b in SeedData.bills(now))
        if (!billIds.contains(b.id)) b,
    ];

    // THE INCOME STREAMS, which this method forgot until 2026-10-03 while the
    // sweep had been removing them since the day it learned to.
    //
    // The asymmetry was invisible because nothing on screen lists an income
    // stream by name. What reads them is Safe to Spend, so a person who
    // removed the examples and put them back got a demo ledger whose most
    // prominent figure was computed without the demo salary, and no screen
    // anywhere could explain the difference. That is the same shape as the
    // defect recorded on the sweep's own side, pointing the other way.
    // THE INCOME STREAMS, which this method forgot until 2026-10-03 while the
    // sweep had been removing them since the day it learned to.
    //
    // The asymmetry was invisible because nothing on screen lists an income
    // stream by name. What reads them is Safe to Spend, so a person who
    // removed the examples and put them back got a demo ledger whose most
    // prominent figure was computed without the demo salary, and no screen
    // anywhere could explain the difference. That is the same shape as the
    // defect recorded on the sweep's own side, pointing the other way.
    _incomeStreams = <IncomeStream>[
      ..._incomeStreams,
      for (final IncomeStream s in SeedData.incomeStreams)
        if (!streamIds.contains(s.id)) s,
    ];

    _payday = SeedData.payday;
    _sampleRemovedAt = null;
    notifyListeners();
  }
}

/// Which side of the cash movement the Coming Up list is showing.
enum MovementFilter { all, inflow, outflow }

/// What Salapify put on the phone itself, and what removing it would take.
class SampleSummary {
  const SampleSummary({
    required this.accounts,
    required this.transactions,
    required this.debts,
    required this.budgets,
    required this.goals,
    required this.upcoming,
    required this.installments,
    required this.bills,
    required this.assets,
    required this.liabilities,
    required this.keptAccounts,
  });

  final int accounts;
  final int transactions;
  final int debts;
  final int budgets;
  final int goals;
  final int upcoming;
  final int installments;
  final int bills;

  /// What the sample ASSETS come to, and what the sample DEBTS come to, kept
  /// apart because adding them together produces a number that means nothing.
  ///
  /// The first version of this summed every account balance and the banner
  /// announced "581,170.50 here is sample money", which counted a 385,000 peso
  /// demo mortgage as money somebody had. Caught by looking at the render, not
  /// by any test: every assertion about it was about the sweep, and the sweep
  /// was correct.
  final double assets;
  final double liabilities;

  /// Sample accounts that a REAL entry points at. These are not deleted; they
  /// are kept and adopted, with the seeded opening balance taken back out.
  /// Named here so the confirmation can say which ones and what happens.
  final List<Account> keptAccounts;

  bool get isEmpty =>
      accounts == 0 &&
      transactions == 0 &&
      debts == 0 &&
      budgets == 0 &&
      goals == 0 &&
      upcoming == 0 &&
      installments == 0 &&
      bills == 0;
}
