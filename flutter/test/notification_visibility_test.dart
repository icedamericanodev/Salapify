// The lock-screen visibility of a reminder is a privacy decision, so a machine
// holds it.
//
// The QA gate on PR1 found that VISIBILITY_PRIVATE does NOT keep detail off the
// lock screen on its own: it redacts only when the user has separately chosen
// to hide sensitive content, and many phones default to showing everything. So
// detailed reminders (the opt-in) use VISIBILITY_SECRET, which Android keeps
// off a secure lock screen regardless of that setting, on their own channel
// (channel visibility is fixed at creation, so a shared id would freeze the
// wrong one). This asserts that mapping, so a well-meaning "simplify to one
// channel" or "PRIVATE is fine" change reddens here instead of on a phone.

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/services/notifications.dart';

void main() {
  test('detailed reminders are SECRET, on their own channel', () {
    final android = Reminders.detailsFor(true).android!;
    expect(
      android.visibility,
      NotificationVisibility.secret,
      reason:
          'detailed reminders carry names and amounts; SECRET is what keeps '
          'them off the lock screen no matter the user setting.',
    );
    expect(
      android.channelId,
      'reminders_detailed',
      reason:
          'a channels lock-screen visibility is fixed at creation, so detailed '
          'needs its own id or it inherits the generic channels PRIVATE.',
    );
  });

  test('generic reminders are PRIVATE, on the default channel', () {
    final android = Reminders.detailsFor(false).android!;
    expect(android.visibility, NotificationVisibility.private);
    expect(android.channelId, 'reminders');
  });
}
