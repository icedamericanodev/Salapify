// The thin plugin shell for on-device reminders. All the what-to-fire logic
// lives in the pure, tested money/reminders.dart; this only asks the OS for
// permission and hands the planned reminders to flutter_local_notifications.
// Everything is a guarded no-op off Android/iOS (web, desktop, tests), and any
// failure is swallowed so a reminder problem can never take down the app.

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../money/reminders.dart';

class Reminders {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static bool get _supported {
    if (kIsWeb) return false;
    try {
      return Platform.isAndroid || Platform.isIOS;
    } catch (_) {
      return false;
    }
  }

  /// Whether this device can show reminders at all.
  ///
  /// Public so a screen can decide whether an opt-in step is worth showing:
  /// asking a desktop VM to allow nightly nudges would be a question with no
  /// honest answer, and the RN flow skips the same step for the same reason.
  static bool get supported => _supported;

  static Future<void> _init() async {
    if (_ready || !_supported) return;
    tzdata.initializeTimeZones();
    // Pin to Manila. The Philippines has no daylight saving, so it is a fixed
    // UTC+8 all year, which makes reminder times exact for the launch audience
    // without a native timezone plugin. (A device-timezone lookup can come
    // later for users abroad; it is not worth a native dependency now.)
    try {
      tz.setLocalLocation(tz.getLocation('Asia/Manila'));
    } catch (_) {
      // If the zone database somehow lacks Manila, tz.local stays as-is; a
      // reminder only shifts by the offset, it never crashes.
    }
    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    _ready = true;
  }

  /// Ask the OS for permission to show reminders. Returns true if allowed.
  static Future<bool> requestPermission() async {
    if (!_supported) return false;
    try {
      await _init();
      if (Platform.isAndroid) {
        final android = _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        return (await android?.requestNotificationsPermission()) ?? true;
      }
      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      return (await ios?.requestPermissions(
            alert: true,
            badge: false,
            sound: false,
          )) ??
          false;
    } catch (_) {
      return false;
    }
  }

  // The second half of the lock-screen privacy contract (the first is that the
  // planner keeps names and amounts out of titles) is the notification's
  // lock-screen visibility, and it depends on whether the body carries detail:
  //
  //  - Detailed (opt-in): VISIBILITY_SECRET. Android keeps a SECRET
  //    notification entirely OFF a secure lock screen, no matter how the user
  //    has set "show sensitive content", so the name and amount appear only in
  //    the shade after unlock. PRIVATE is not enough here: it redacts only when
  //    the user has separately chosen to hide sensitive content, and many
  //    phones default to showing everything, so PRIVATE would leak the body on
  //    the lock screen for those users.
  //  - Generic (default): VISIBILITY_PRIVATE. The content carries nothing
  //    sensitive, so it is fine for the generic prompt to appear on the lock
  //    screen.
  //
  // Two DIFFERENT channel ids on purpose. On Android 8+ a channel's
  // lock-screen visibility is fixed when the channel is first created and later
  // code cannot move it, so one shared id would freeze whichever visibility was
  // created first. A separate id per level lets each keep its own.
  @visibleForTesting
  static NotificationDetails detailsFor(bool detailed) => NotificationDetails(
    android: AndroidNotificationDetails(
      detailed ? 'reminders_detailed' : 'reminders',
      detailed ? 'Reminders (with details)' : 'Reminders',
      channelDescription: 'Log nudges, payday, bills, and IOU reminders',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      visibility: detailed
          ? NotificationVisibility.secret
          : NotificationVisibility.private,
    ),
    iOS: const DarwinNotificationDetails(presentSound: false),
  );

  // Rapid resumes/toggles can start overlapping reschedules; each await yields
  // the event loop, so without this a superseded (older) run could re-add
  // reminders a newer run already cancelled. Every run claims a token and bails
  // the moment a newer one starts, so the newest run always wins cleanly.
  static int _runToken = 0;

  /// Wipe the schedule and rebuild it from current data. Safe to call often
  /// (on app resume, and whenever the toggles or data change); the plan is
  /// derived fresh each time so it always matches what is in the app.
  static Future<void> reschedule(Map data, DateTime now) async {
    if (!_supported) return;
    final myRun = ++_runToken;
    try {
      await _init();
      if (myRun != _runToken) return;
      await _plugin.cancelAll();
      // Detailed reminders (names and amounts in the body) are strictly opt-in;
      // absent key means off, so the default is the generic, redacted text.
      final settings = data['settings'];
      final detailed = settings is Map && settings['notifDetailed'] == true;
      final details = detailsFor(detailed);
      var id = 0;
      for (final r in plannedReminders(data, now, detailed: detailed)) {
        if (myRun != _runToken) return; // a newer reschedule superseded us
        if (id >= 60) break; // a sane cap on how many we ever queue
        await _plugin.zonedSchedule(
          id++,
          r.title,
          r.body,
          tz.TZDateTime.from(r.when, tz.local),
          details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      }
    } catch (_) {
      // Scheduling must never crash the app.
    }
  }

  /// Cancel everything, e.g. when the user turns all reminders off or erases
  /// their data with Start fresh. Claiming the token invalidates any reschedule
  /// still mid-flight, so a run started from the old data cannot keep adding
  /// reminders after this wipe (ghost "utang due" pings about erased data).
  static Future<void> cancelAll() async {
    if (!_supported) return;
    _runToken++;
    try {
      await _init();
      await _plugin.cancelAll();
    } catch (_) {}
  }
}
