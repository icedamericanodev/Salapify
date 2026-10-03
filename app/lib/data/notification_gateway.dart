import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../core/money/reminders.dart';

/// Handing reminders to the phone, so one can arrive while Salapify is closed.
///
/// Everything above this file is pure: `planReminders` decides WHAT should be
/// said and WHEN, with no plugin anywhere near it, and is locked by vectors.
/// This is the only place a platform channel is touched, which is what lets
/// every rule be tested on a machine with no phone attached.
abstract class NotificationGateway {
  /// Asks Android for permission, and says whether it now has it.
  ///
  /// Called only when somebody switches phone reminders ON. Asking at first
  /// launch, before a person has seen what the app does, is how an app gets a
  /// permanent no.
  Future<bool> requestPermission();

  /// Whether the phone will currently accept a notification from Salapify.
  Future<bool> hasPermission();

  /// Replaces EVERYTHING previously scheduled with exactly this list.
  ///
  /// Replace, never add. A reminder is a statement about a ledger that keeps
  /// changing: pay the bill and the notification about it has to go, and the
  /// only way to be sure is to schedule from a clean slate each time. Adding
  /// would leave a phone buzzing about a bill somebody settled last week.
  Future<void> replaceAll(List<PlannedReminder> planned);

  /// Nothing scheduled at all, for when reminders are switched off.
  Future<void> cancelAll();
}

/// The no-op, and the DEFAULT everywhere except the real app.
///
/// A test, a preview and the render harness all get this, so nothing ever
/// reaches a platform channel by forgetting to pass something. Same reasoning
/// as MemorySnapshotStore being the default store: the safe default is the one
/// where forgetting costs nothing.
class NoNotifications implements NotificationGateway {
  const NoNotifications();

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<bool> hasPermission() async => false;

  @override
  Future<void> replaceAll(List<PlannedReminder> planned) async {}

  @override
  Future<void> cancelAll() async {}
}

/// The real one.
class LocalNotificationGateway implements NotificationGateway {
  LocalNotificationGateway({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _ready = false;

  /// One channel per kind, so a person can silence bill reminders in Android's
  /// own settings without silencing the lot. Android treats a channel as
  /// permanent once created; its importance is theirs to change after that,
  /// which is the point.
  static const Map<ReminderKind, ({String id, String name, String about})>
  _channels = <ReminderKind, ({String id, String name, String about})>{
    ReminderKind.dailyExpense: (
      id: 'salapify_daily',
      name: 'Daily logging nudge',
      about: 'A reminder to log the day if nothing has been entered',
    ),
    ReminderKind.paymentDue: (
      id: 'salapify_payment',
      name: 'Payments you owe',
      about: 'Debts, credit card cutoffs and payment plans',
    ),
    ReminderKind.billDue: (
      id: 'salapify_bill',
      name: 'Bills',
      about: 'Electricity, water, internet, rent and dues',
    ),
    ReminderKind.subscription: (
      id: 'salapify_subscription',
      name: 'Subscription renewals',
      about: 'Anything that renews itself',
    ),
  };

  Future<void> _init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    await _plugin.initialize(
      settings: const InitializationSettings(
        // The launcher icon. A notification with no icon does not appear at
        // all on Android, it throws.
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    _ready = true;
  }

  @override
  Future<bool> requestPermission() async {
    await _init();
    final AndroidFlutterLocalNotificationsPlugin? android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) return false;
    return await android.requestNotificationsPermission() ?? false;
  }

  @override
  Future<bool> hasPermission() async {
    await _init();
    final AndroidFlutterLocalNotificationsPlugin? android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) return false;
    return await android.areNotificationsEnabled() ?? false;
  }

  @override
  Future<void> cancelAll() async {
    await _init();
    await _plugin.cancelAll();
  }

  @override
  Future<void> replaceAll(List<PlannedReminder> planned) async {
    await _init();
    if (!await hasPermission()) return;

    await _plugin.cancelAll();

    for (final PlannedReminder p in planned) {
      final ({String id, String name, String about}) channel =
          _channels[p.reminder.kind]!;

      await _plugin.zonedSchedule(
        id: _idFor(p.reminder.tag),
        title: p.reminder.title,
        body: p.reminder.body,
        // Anchored to the INSTANT, in UTC, rather than looked up in the
        // timezone database.
        //
        // `p.at` is a local wall time, so its instant is already correct, and
        // converting it to UTC preserves that instant exactly. The alternative
        // is another plugin to discover the device's zone name, for a
        // difference that only shows up if somebody flies to another country
        // between two app opens. The plan is rebuilt every time Salapify is
        // opened, so even then it self corrects on the next launch.
        scheduledDate: tz.TZDateTime.from(p.at, tz.UTC),
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            channel.id,
            channel.name,
            channelDescription: channel.about,
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
        ),
        // INEXACT, deliberately. An exact alarm needs SCHEDULE_EXACT_ALARM,
        // which Google restricts to alarm clocks and calendars and which a
        // budgeting app would have to justify at review. A bill reminder that
        // lands at 9:07 instead of 9:00 is the same reminder.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }

  /// A stable 31 bit id from the tag.
  ///
  /// Stable matters: the same bill on the same day must map to the same id
  /// across launches, or a replan would stack duplicates. cancelAll already
  /// clears the slate, so this is belt and braces rather than the mechanism.
  static int _idFor(String tag) => tag.hashCode & 0x7fffffff;
}
