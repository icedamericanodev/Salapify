import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/reminders.dart';
import 'package:salapify/data/notification_gateway.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/state/financial_state.dart';

/// Everything between the ledger and the phone's notification tray.
///
/// The engine tests prove WHAT should be said and WHEN. This proves the app
/// actually hands it over, stops handing it over when somebody says stop, and,
/// the one that matters most, TAKES BACK a reminder about something that is no
/// longer true.
class _Recorder implements NotificationGateway {
  _Recorder({this.grant = true});

  /// What Android would answer.
  final bool grant;

  bool asked = false;
  int cancelledAll = 0;

  /// Every call to replaceAll, in order, so a test can see the last plan AND
  /// that replanning happened at all.
  final List<List<PlannedReminder>> plans = <List<PlannedReminder>>[];

  List<PlannedReminder> get latest =>
      plans.isEmpty ? const <PlannedReminder>[] : plans.last;

  bool _granted = false;

  @override
  Future<bool> requestPermission() async {
    asked = true;
    _granted = grant;
    return grant;
  }

  @override
  Future<bool> hasPermission() async => _granted;

  @override
  Future<void> replaceAll(List<PlannedReminder> planned) async {
    plans.add(planned);
  }

  @override
  Future<void> cancelAll() async {
    cancelledAll++;
  }
}

void main() {
  qaRegressions();
  Future<FinancialState> ready(_Recorder r) async {
    final FinancialState state = FinancialState(
      clock: DateTime(2026, 9, 19, 12),
      store: MemorySnapshotStore(),
      notifications: r,
    );
    await state.restore();
    await state.flushWrites();
    return state;
  }

  test('nothing reaches the phone until somebody asks for it', () async {
    final _Recorder r = _Recorder();
    final FinancialState state = await ready(r);

    expect(
      r.asked,
      isFalse,
      reason:
          'Salapify asked for the notification permission before the person '
          'had seen what it does. Android gives no second chance, so an early '
          'no is a permanent one.',
    );
    expect(r.plans, isEmpty, reason: 'scheduled without permission');
    expect(state.reminderSettings.phoneEnabled, isFalse);
  });

  test('switching it on asks, and then schedules', () async {
    final _Recorder r = _Recorder();
    final FinancialState state = await ready(r);

    final bool ok = await state.enablePhoneReminders();

    expect(ok, isTrue);
    expect(r.asked, isTrue);
    expect(state.reminderSettings.phoneEnabled, isTrue);
    expect(
      r.latest,
      isNotEmpty,
      reason:
          'the switch went on and the phone was handed nothing, so it would '
          'never buzz and nothing on screen would say why',
    );
  });

  test('a refusal leaves the switch off rather than lying', () async {
    // The other half of the alarm. A control that stores "on" against a denied
    // permission claims to do something and does nothing.
    final _Recorder r = _Recorder(grant: false);
    final FinancialState state = await ready(r);

    final bool ok = await state.enablePhoneReminders();

    expect(ok, isFalse);
    expect(r.asked, isTrue);
    expect(state.reminderSettings.phoneEnabled, isFalse);
  });

  test('switching it off cancels everything', () async {
    final _Recorder r = _Recorder();
    final FinancialState state = await ready(r);
    await state.enablePhoneReminders();
    final int before = r.cancelledAll;

    await state.disablePhoneReminders();

    expect(state.reminderSettings.phoneEnabled, isFalse);
    expect(
      r.cancelledAll,
      greaterThan(before),
      reason:
          'reminders were switched off and the phone kept every one it had '
          'already been given, so it goes on buzzing for a fortnight',
    );
  });

  test('paying a bill takes back the reminder about it', () async {
    // THE one that matters. A scheduled notification is a statement about a
    // ledger that keeps changing, and the failure mode is a phone buzzing on
    // Saturday morning about a bill settled on Thursday.
    final _Recorder r = _Recorder();
    final FinancialState state = await ready(r);
    await state.enablePhoneReminders();

    final List<PlannedReminder> before = r.latest;
    final PlannedReminder aBill = before.firstWhere(
      (PlannedReminder p) => p.reminder.kind == ReminderKind.billDue,
    );
    final String tag = aBill.reminder.tag;

    // Clearing the sample data removes every seeded bill, which is the
    // bluntest version of "this is no longer owed" the app offers.
    state.removeSampleData();
    await state.flushWrites();

    expect(
      r.plans.length,
      greaterThan(1),
      reason: 'the ledger changed and nothing was re-handed to the phone',
    );
    expect(
      r.latest.any((PlannedReminder p) => p.reminder.tag == tag),
      isFalse,
      reason:
          'the phone is still scheduled to buzz about a bill that is no '
          'longer in the ledger at all',
    );
  });

  test('a phone that will not take a schedule never fails a save', () async {
    // A save that succeeded must not be reported as a failure over a
    // notification. Money on disk is the thing that matters.
    final _ThrowingGateway bad = _ThrowingGateway();
    final FinancialState state = FinancialState(
      clock: DateTime(2026, 9, 19, 12),
      store: MemorySnapshotStore(),
      notifications: bad,
    );
    await state.restore();
    await state.enablePhoneReminders();

    state.toggleTheme();
    await state.flushWrites();

    expect(
      state.saveProblem,
      isNull,
      reason:
          'the app told somebody their entries were not being saved because a '
          'notification could not be scheduled',
    );
  });
}

class _ThrowingGateway implements NotificationGateway {
  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<bool> hasPermission() async => true;

  @override
  Future<void> replaceAll(List<PlannedReminder> planned) async =>
      throw Exception('no notification service on this device');

  @override
  Future<void> cancelAll() async {}
}

/// Findings from an adversarial QA pass.
void qaRegressions() {
  test(
    'a gateway that throws on the PERMISSION call does not escape',
    () async {
      // The guard went into replanNotifications only, and the fake threw only
      // from replaceAll, so the test could not have caught this. On a real
      // device requestPermission initialises the plugin and the timezone
      // database first, and a platform exception there went straight out of the
      // tap, leaving the switch spinning forever with nothing on screen.
      final FinancialState state = FinancialState(
        clock: DateTime(2026, 9, 19, 12),
        store: MemorySnapshotStore(),
        notifications: _ThrowsOnPermission(),
      );
      await state.restore();

      late bool granted;
      expect(
        () async => granted = await state.enablePhoneReminders(),
        returnsNormally,
      );
      granted = await state.enablePhoneReminders();
      expect(granted, isFalse);
      expect(
        state.reminderSettings.phoneEnabled,
        isFalse,
        reason: 'the switch stored "on" against a permission that never came',
      );
    },
  );

  test('switching off survives a gateway that throws on cancel', () async {
    final FinancialState state = FinancialState(
      clock: DateTime(2026, 9, 19, 12),
      store: MemorySnapshotStore(),
      notifications: _ThrowsOnCancel(),
    );
    await state.restore();
    await state.disablePhoneReminders();
    expect(state.reminderSettings.phoneEnabled, isFalse);
  });

  test('test reminders cannot grow the tray without limit', () async {
    // refreshReminders truncated and this path did not, so holding the Test
    // button built a tray of any length, persisted it, and re-encoded all of
    // it on every save afterwards.
    final FinancialState state = FinancialState(
      clock: DateTime(2026, 9, 19, 12),
      store: MemorySnapshotStore(),
    );
    await state.restore();

    for (int i = 0; i < 200; i++) {
      state.sendTestReminder(ReminderKind.billDue);
    }
    await state.flushWrites();

    expect(
      state.notifications.length,
      lessThanOrEqualTo(FinancialState.maxNotifications),
      reason: 'the tray grew past its own cap and is persisted at that size',
    );
  });

  test(
    'a loaded file with an enormous tray is trimmed on the way in',
    () async {
      // Trimming only the add path leaves a long tray long forever.
      final MemorySnapshotStore store = MemorySnapshotStore();
      final FinancialState first = FinancialState(
        clock: DateTime(2026, 9, 19, 12),
        store: store,
      );
      await first.restore();
      for (int i = 0; i < 200; i++) {
        first.sendTestReminder(ReminderKind.billDue);
      }
      await first.flushWrites();

      final FinancialState second = FinancialState(
        clock: DateTime(2026, 9, 19, 12),
        store: store,
      );
      await second.restore();
      expect(
        second.notifications.length,
        lessThanOrEqualTo(FinancialState.maxNotifications),
      );
    },
  );

  test(
    'after a wipe, Settings does not offer to put demo money back',
    () async {
      // The wipe marked the sample data as "removed", which is what gates the
      // put-it-back control. So two taps after reading "The sample data has NOT
      // come back", Settings offered a button injecting eleven demo accounts
      // and a demo salary into the ledger they had just erased.
      final FinancialState state = FinancialState(
        clock: DateTime(2026, 9, 19, 12),
        store: MemorySnapshotStore(),
      );
      await state.restore();
      await state.deleteEverything();

      expect(state.accounts, isEmpty);
      expect(
        state.canRestoreSampleData,
        isFalse,
        reason:
            'the app promised an empty ledger and then offered a button that '
            'fills it with money the person never earned',
      );
    },
  );

  test('but removing ONLY the sample data still offers the way back', () async {
    // The other half. Suppressing it everywhere would delete a control the
    // founder asked for.
    final FinancialState state = FinancialState(
      clock: DateTime(2026, 9, 19, 12),
      store: MemorySnapshotStore(),
    );
    await state.restore();
    state.removeSampleData();
    await state.flushWrites();

    expect(state.canRestoreSampleData, isTrue);
  });
}

class _ThrowsOnPermission implements NotificationGateway {
  @override
  Future<bool> requestPermission() async =>
      throw Exception('no notification service on this device');

  @override
  Future<bool> hasPermission() async => false;

  @override
  Future<void> replaceAll(List<PlannedReminder> planned) async {}

  @override
  Future<void> cancelAll() async {}
}

class _ThrowsOnCancel implements NotificationGateway {
  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<bool> hasPermission() async => true;

  @override
  Future<void> replaceAll(List<PlannedReminder> planned) async {}

  @override
  Future<void> cancelAll() async => throw Exception('cannot cancel');
}
