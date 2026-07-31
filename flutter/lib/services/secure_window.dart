// Screen security at the OS level, tied to App Lock.
//
// The LockGate already draws a Flutter overlay when the app goes to the
// background, so money screens do not show in the app-switcher thumbnail. That
// overlay is drawn by Flutter, though, and the OS captures the recents snapshot
// itself: on some phones the real frame is grabbed before or around the
// overlay, and a manual screenshot is never blocked by a widget at all. Only
// the window flag FLAG_SECURE blanks both the recents thumbnail and manual
// screenshots, and only the native side can set it.
//
// The choice, stated plainly: FLAG_SECURE is ON exactly when App Lock is on.
// Turning on App Lock is the user saying "this is private on my phone", so both
// screenshots and the recents preview are blanked then. With App Lock off we
// clear the flag and respect the choice not to lock, so casual screenshots
// (sharing a budget win, say) still work. The single source of truth is
// store.appLockOn, the same read the gate uses, so the two can never disagree.
//
// This file is the whole decision. MainActivity.kt only sets or clears the flag
// when told, so the tested logic lives here in Dart and the native side has
// nothing to get wrong. That split is deliberate: the flag itself cannot be
// checked on a CI runner, but everything that DECIDES the flag can be.

import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:flutter/services.dart';

import '../data/store.dart';

class SecureWindow {
  SecureWindow._();

  /// Matches the handler registered in MainActivity.kt.
  static const MethodChannel channel = MethodChannel('salapify/secure_window');

  /// The last value actually sent to the platform. Kept so a store that
  /// notifies on every keystroke does not cross the method channel on every
  /// keystroke: the flag only changes when App Lock is toggled, which is rare.
  ///
  /// Starts false because a fresh Android window has no FLAG_SECURE set, so the
  /// first apply(false) at startup is a true no-op and never crosses the
  /// channel; only turning App Lock on ever sets it.
  static bool _applied = false;

  /// Ask the OS to set or clear FLAG_SECURE. Idempotent, crash-proof, and a
  /// no-op on platforms without the channel (web, tests), so it is always safe
  /// to call.
  static Future<void> apply(bool secure) async {
    if (secure == _applied) return;
    _applied = secure;
    if (kIsWeb) return;
    try {
      await channel.invokeMethod('setSecure', {'secure': secure});
    } on MissingPluginException {
      // No native side here (a test, or a platform that does not register the
      // channel). Nothing to secure, and nothing to crash over.
    } catch (_) {
      // A window-flag failure must never take the app down. The worst case is
      // a screenshot that was not blocked, never a crash on a money screen.
    }
  }

  /// Keep FLAG_SECURE in sync with App Lock for the life of the app. Call once,
  /// at startup, the same way HomeTile.attach is wired. Applies the current
  /// state immediately, then follows every change to the setting.
  static void attach(SalapifyStore store) {
    apply(store.appLockOn);
    store.addListener(() => apply(store.appLockOn));
  }

  /// Tests toggle App Lock many times against one static; this lets each test
  /// start from a known state so the idempotence guard does not swallow the
  /// first call.
  @visibleForTesting
  static void resetForTest() => _applied = false;
}
