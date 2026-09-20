import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/import.dart';
import '../data/notification_gateway.dart';
import '../data/seed_data.dart';
import '../data/snapshot.dart';
import '../data/store.dart';
import '../design/tokens.dart';
import '../core/money/accounts.dart';
import '../core/money/debt.dart';
import '../core/money/installments.dart';
import '../core/money/ledger.dart';
import '../core/money/pan/pan_context.dart';
import '../core/money/plan.dart';
import '../core/money/reconciliation.dart';
import '../core/money/reminders.dart';
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
  FinancialState({
    this.clock,
    SnapshotStore? store,
    NotificationGateway? notifications,
  }) : _store = store ?? MemorySnapshotStore(),
       _notifier = notifications ?? const NoNotifications() {
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
    _bills = List<BillItem>.of(SeedData.bills);
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
    bills: _bills,
    notifications: _notifications,
    reminderSettings: _reminderSettings,
    payday: _payday,
    sampleDataRemovedAt: _sampleRemovedAt,
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
  List<Debt> get debts => List<Debt>.unmodifiable(_debts);
  List<Budget> get budgets => List<Budget>.unmodifiable(_budgets);
  List<CategoryInfo> get categories => SeedData.categories;
  List<Goal> get goals => List<Goal>.unmodifiable(_goals);
  List<UpcomingItem> get upcoming => List<UpcomingItem>.unmodifiable(_upcoming);
  List<BillItem> get bills => List<BillItem>.unmodifiable(_bills);
  List<IncomeStream> get incomeStreams =>
      List<IncomeStream>.unmodifiable(_incomeStreams);
  List<InstallmentPlan> get installments =>
      List<InstallmentPlan>.unmodifiable(_installments);
  PaydayCycle get payday => _payday;

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
      payday: _payday,
      liquidCash: totalLiquidCash,
      assets: accountsTotalPhp(assetsOf(_accounts)),
      liabilities: accountsTotalPhp(liabilitiesOf(_accounts)),
      owed: debtsIOwe,
      owedToMe: debtsOwedToMe,
      safeToSpendUntilPayday: s.safeToSpendUntilPayday,
      safeToSpendPerDay: s.safeToSpendToday,
      amountReserved: s.amountReserved,
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

    // Extras ARE cleared, and that is deliberate the other way. They hold keys
    // from the person's own file that this build cannot read, so carrying them
    // through a wipe would write a piece of their data straight back into the
    // supposedly empty file.
    _extras = const Extras.empty();

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
    // _bills and _installments, NOT the seed. Both read the frozen seed list
    // until now, and the comment below about incomeStreams describes exactly
    // this defect while two arguments above it had the same one: a bill or a
    // plan the user pays off stays reserved forever, and a demo bill they
    // never entered reserves money on day one. Measured before the fix: one
    // real 50,000 peso account gave a Safe to Spend of 0.00.
    bills: _bills,
    debtsIOwe: debtsIOwe,
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
    // Never import over a file we could not read. In that state _apply never
    // ran, so what we would "preserve" is the SEED, and the person's real
    // unreadable file is still on disk waiting to be written over.
    if (!_saveEnabled) return false;

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

    // And so is anything the tray was reminding them about. Every message in
    // it was raised from a record that has just been deleted, so leaving it
    // would hand somebody a bill reminder naming a bill that is no longer on
    // any screen, which is unanswerable rather than merely stale.
    _notifications = <AppNotification>[];

    _sampleRemovedAt = now.toUtc().toIso8601String();
    notifyListeners();
  }

  static double _seededBalanceOf(String id) {
    for (final Account a in SeedData.accounts) {
      if (a.id == id) return a.balance;
    }
    return 0;
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
    final Set<String> categories = _budgets
        .map((Budget b) => b.category)
        .toSet();

    // Skip anything whose id is already here, so this can never overwrite a
    // record the person made or adopted. Their ids are timestamped, so a
    // collision with 'acc_bpi' is not possible in the first place; this is the
    // belt as well as the braces.
    _accounts = <Account>[
      ..._accounts,
      for (final Account a in SeedData.accounts)
        if (!accountIds.contains(a.id)) a,
    ];
    _transactions = <Transaction>[
      ..._transactions,
      for (final Transaction t in SeedData.transactions())
        if (!txIds.contains(t.id)) t,
    ];
    _debts = <Debt>[
      ..._debts,
      for (final Debt d in SeedData.debts)
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
      for (final UpcomingItem u in SeedData.upcoming)
        if (!upIds.contains(u.id)) u,
    ];
    _installments = <InstallmentPlan>[
      ..._installments,
      for (final InstallmentPlan p in SeedData.installments)
        if (!planIds.contains(p.id)) p,
    ];
    _bills = <BillItem>[
      ..._bills,
      for (final BillItem b in SeedData.bills)
        if (!billIds.contains(b.id)) b,
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
