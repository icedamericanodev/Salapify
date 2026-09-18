// The Android target level, and the platform behaviors that ride on it, held
// by a machine so they cannot drift.
//
// targetSdk is not a version label, it is a switch that opts the app into a
// platform's newer runtime behaviors. Two ways it goes wrong silently:
//   1. Left as flutter.targetSdkVersion, it changes whenever the Flutter SDK
//      changes its default, so the app can start honoring new behaviors with no
//      commit that says so. This asserts the literal.
//   2. A behavior change at a level we target can require, or forbid, something
//      in the manifest. The one that bites a reminders app is exact alarms:
//      from Android 12 (API 31) SCHEDULE_EXACT_ALARM is restricted, and from
//      Android 13 (API 33) USE_EXACT_ALARM is a Play-policy-gated permission.
//      Salapify deliberately uses INEXACT alarms, so neither permission may
//      appear and the scheduler must ask for inexact delivery.
//
// Docs: https://developer.android.com/google/play/requirements/target-sdk
//       https://developer.android.com/about/versions/12/behavior-changes-12#exact-alarm-permission
//       https://developer.android.com/about/versions/13/behavior-changes-13#use-exact-alarm-permission

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final gradle = File('android/app/build.gradle.kts').readAsStringSync();
  final manifest = File(
    'android/app/src/main/AndroidManifest.xml',
  ).readAsStringSync();
  final notifications = File(
    'lib/services/notifications.dart',
  ).readAsStringSync();

  group('the app targets Android 16 explicitly', () {
    test('targetSdk is the literal 36, not the moving Flutter default', () {
      expect(
        RegExp(r'targetSdk\s*=\s*36').hasMatch(gradle),
        isTrue,
        reason:
            'targetSdk must be pinned to 36. If it reads '
            'flutter.targetSdkVersion, the app silently opts into new platform '
            'behaviors whenever the Flutter SDK moves its default.',
      );
      expect(
        gradle.contains('targetSdk = flutter.targetSdkVersion'),
        isFalse,
        reason: 'targetSdk fell back to the moving Flutter default.',
      );
    });

    test('compileSdk is 36, so 36 APIs are available at build time', () {
      expect(
        RegExp(r'compileSdk\s*=\s*36').hasMatch(gradle),
        isTrue,
        reason: 'compileSdk must be 36 to compile against Android 16 APIs.',
      );
    });
  });

  group('the exact-alarm behavior choice holds (API 31+ and 33+)', () {
    test('neither exact-alarm permission is requested', () {
      for (final perm in ['SCHEDULE_EXACT_ALARM', 'USE_EXACT_ALARM']) {
        expect(
          manifest.contains(perm),
          isFalse,
          reason:
              '$perm appears in the manifest. Salapify uses inexact alarms on '
              'purpose: exact alarms are restricted from Android 12 and the '
              'USE_EXACT_ALARM permission is Play-policy-gated from Android 13. '
              'A reminder app does not need to the minute.',
        );
      }
    });

    test('the scheduler asks for INEXACT delivery', () {
      expect(
        notifications.contains('AndroidScheduleMode.inexactAllowWhileIdle'),
        isTrue,
        reason:
            'the notification scheduler must use inexact delivery, matching the '
            'decision not to request an exact-alarm permission.',
      );
      // Fully qualified so it does not match the "exactAllowWhileIdle" tail of
      // inexactAllowWhileIdle. AndroidScheduleMode.exact... is a different token
      // from AndroidScheduleMode.inexact...
      expect(
        notifications.contains('AndroidScheduleMode.exactAllowWhileIdle'),
        isFalse,
        reason:
            'an exact schedule mode needs an exact-alarm permission the app '
            'deliberately does not request; the reminder would silently never '
            'fire on Android 12+.',
      );
    });
  });
}
