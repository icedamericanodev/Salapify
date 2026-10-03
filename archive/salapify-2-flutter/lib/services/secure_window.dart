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

  /// The App Lock baseline: FLAG_SECURE follows this whenever nothing is forcing
  /// it on. Set by [apply], which the App Lock listener drives.
  static bool _baseline = false;

  /// How many transient owners (a reveal, an open QR sheet) are currently
  /// FORCING the flag on regardless of App Lock. A refcount rather than a bool
  /// so two overlapping owners cannot release each other's protection early.
  /// This is the fix for the race where a background store notify, firing
  /// `apply(store.appLockOn)` on an App-Lock-off phone, would otherwise clear
  /// FLAG_SECURE in the middle of a reveal and let the recents thumbnail catch
  /// the digits.
  static int _forced = 0;

  /// Set the App Lock BASELINE and re-sync. Idempotent, crash-proof, and a
  /// no-op on platforms without the channel (web, tests), so it is always safe
  /// to call. The effective flag is `baseline OR forced`, so this can never
  /// clear the flag out from under a live [retain].
  static Future<void> apply(bool secure) async {
    _baseline = secure;
    return _sync();
  }

  /// Force FLAG_SECURE on for a sensitive moment (a revealed number, an open QR),
  /// regardless of App Lock. Pair every call with exactly one [release].
  static Future<void> retain() {
    _forced++;
    return _sync();
  }

  /// End one [retain]. The flag drops back to the App Lock baseline only once
  /// the last owner has released.
  static Future<void> release() {
    if (_forced > 0) _forced--;
    return _sync();
  }

  static Future<void> _sync() async {
    final want = _baseline || _forced > 0;
    if (want == _applied) return;
    if (kIsWeb) {
      _applied = want; // no channel on web; record so we do not retry
      return;
    }
    try {
      await channel.invokeMethod('setSecure', {'secure': want});
      // Commit ONLY after the platform confirms. If the call throws for a
      // transient reason, _applied stays as it was, so the next sync retries
      // instead of falsely believing the flag is set.
      _applied = want;
    } on MissingPluginException {
      // No native side (a test, or a platform that does not register the
      // channel). Treat as applied so we do not cross the channel on every
      // notify; there is nothing to secure and nothing to crash over.
      _applied = want;
    } catch (_) {
      // A window-flag failure must never take the app down, and must not be
      // recorded as success: leave _applied unchanged so a later sync retries.
      // The worst case is a screenshot that was not blocked, never a crash.
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
  static void resetForTest() {
    _applied = false;
    _baseline = false;
    _forced = 0;
  }
}
