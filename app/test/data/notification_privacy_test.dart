import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/reminders.dart';
import 'package:salapify/data/notification_gateway.dart';

/// While app lock is on, a reminder on the phone's own lock screen must not
/// carry a figure or a name.
///
/// Android's "private" visibility alone is not enough: it hides the text
/// only when the person has turned off "show sensitive content", and that
/// setting is on by default. So the WORDS have to change. This drives the
/// real gateway down to the plugin's own channel and reads what would have
/// been handed to Android.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel(
    'dexterous.com/flutter/local_notifications',
  );
  final List<Map<Object?, Object?>> scheduled = <Map<Object?, Object?>>[];

  setUp(() {
    scheduled.clear();
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
          switch (call.method) {
            case 'initialize':
            case 'areNotificationsEnabled':
              return true;
            case 'zonedSchedule':
              scheduled.add(call.arguments as Map<Object?, Object?>);
              return null;
            default:
              return null;
          }
        });
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  final List<PlannedReminder> plan = <PlannedReminder>[
    PlannedReminder(
      // Far ahead, because the plugin refuses a time already past.
      at: DateTime(2099, 1, 5, 9),
      reminder: const Reminder(
        tag: 'bill:meralco:2099-01-05',
        kind: ReminderKind.billDue,
        title: 'Meralco is due in 3 days',
        body: 'Your payment of 8,500 to Meralco',
      ),
    ),
  ];

  test('lock off: the reminder says what it is about', () async {
    final LocalNotificationGateway gateway = LocalNotificationGateway();
    await gateway.replaceAll(plan);
    expect(scheduled, hasLength(1));
    expect(scheduled.single['title'], 'Meralco is due in 3 days');
  });

  test('lock on: no figure and no name reach the lock screen', () async {
    final LocalNotificationGateway gateway = LocalNotificationGateway()
      ..privateOnLockScreen = true;
    await gateway.replaceAll(plan);
    expect(scheduled, hasLength(1));
    final String words =
        '${scheduled.single['title']} '
        '${scheduled.single['body']}';
    expect(
      words,
      isNot(contains('8,500')),
      reason: 'an amount was shown on a locked phone',
    );
    expect(words, isNot(contains('Meralco')));
    expect(scheduled.single['body'], contains('A reminder is due'));
  });
}
