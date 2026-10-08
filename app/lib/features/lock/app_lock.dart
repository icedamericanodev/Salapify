import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:local_auth/local_auth.dart';
import 'package:path_provider/path_provider.dart';

/// App lock: Salapify opens only after the phone's own lock says so.
///
/// Founder decisions, both taken before this was built:
///   - "Phone's own lock": the fingerprint, face, PIN or pattern the phone
///     already has. No Salapify PIN, so there is nothing new to forget.
///   - "Keep it out" of backups: the setting lives in its own small file,
///     never in the ledger JSON, so a backup restored onto another phone
///     cannot arrive locked behind a lock that phone never had.
///
/// What it is NOT, said in the app as well as here: it stops someone opening
/// Salapify on this phone. It does not encrypt the data or the backups.
///
/// Reused from Salapify 2's LockGate (archive/salapify-2-flutter), with the
/// three things that were wrong there put right:
///   1. It demanded enrolled biometrics, so a phone with only a PIN could not
///      use it. The phone's own lock includes the PIN.
///   2. It timed "away for a minute" on the wall clock, which moving the
///      phone's clock back defeats. This uses a monotonic stopwatch.
///   3. The setting lived inside the backed-up data file.

/// What one attempt to pass the phone's lock came to.
enum UnlockOutcome {
  /// The phone said yes.
  unlocked,

  /// The person backed out of the prompt. Not an error; they can tap again.
  cancelled,

  /// Too many wrong tries; the phone wants a pause.
  lockedOut,

  /// This phone has no screen lock at all, so nothing can be checked.
  unavailable,

  /// Anything else the phone reported.
  error,
}

/// The phone's own lock, behind an interface so a test never reaches a
/// platform channel that does not exist in one.
abstract class LockAuthenticator {
  Future<UnlockOutcome> authenticate(String reason);
}

/// The real one, through local_auth 3.x.
class DeviceLockAuthenticator implements LockAuthenticator {
  DeviceLockAuthenticator();

  final LocalAuthentication _auth = LocalAuthentication();

  @override
  Future<UnlockOutcome> authenticate(String reason) async {
    try {
      final bool ok = await _auth.authenticate(
        localizedReason: reason,
        // The phone's PIN or pattern is always allowed, so a wet finger, a
        // cracked sensor or a biometric cooldown never strands somebody who
        // knows their own phone's code.
        biometricOnly: false,
        // The prompt survives the app being briefly backgrounded instead of
        // failing and making the person start again.
        persistAcrossBackgrounding: true,
      );
      return ok ? UnlockOutcome.unlocked : UnlockOutcome.cancelled;
    } on LocalAuthException catch (e) {
      switch (e.code) {
        case LocalAuthExceptionCode.noCredentialsSet:
          return UnlockOutcome.unavailable;
        case LocalAuthExceptionCode.userCanceled:
        case LocalAuthExceptionCode.systemCanceled:
        case LocalAuthExceptionCode.timeout:
          return UnlockOutcome.cancelled;
        case LocalAuthExceptionCode.temporaryLockout:
        case LocalAuthExceptionCode.biometricLockout:
          return UnlockOutcome.lockedOut;
        default:
          // New codes may be added to the plugin at any time, so there is
          // always a fallback rather than an exhaustive match.
          return UnlockOutcome.error;
      }
    } catch (_) {
      return UnlockOutcome.error;
    }
  }
}

/// Where the one setting lives.
abstract class LockSettingsStore {
  Future<bool> readEnabled();
  Future<void> writeEnabled(bool enabled);
}

/// The real store: `app_lock.json` beside the ledger, NOT inside it, so the
/// export and every backup leave it out by construction.
class FileLockSettings implements LockSettingsStore {
  FileLockSettings();

  Future<File> _file() async {
    final Directory dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/app_lock.json');
  }

  @override
  Future<bool> readEnabled() async {
    try {
      final File f = await _file();
      if (!f.existsSync()) return false;
      final Object? m = jsonDecode(await f.readAsString());
      return m is Map && m['enabled'] == true;
    } catch (_) {
      // An unreadable lock file must never lock somebody out of their own
      // money. Unreadable means off.
      return false;
    }
  }

  @override
  Future<void> writeEnabled(bool enabled) async {
    final File f = await _file();
    if (!enabled) {
      if (f.existsSync()) await f.delete();
      return;
    }
    await f.writeAsString(jsonEncode(<String, Object>{'enabled': true}));
  }
}

/// For tests and previews.
class MemoryLockSettings implements LockSettingsStore {
  MemoryLockSettings([this.enabled = false]);

  bool enabled;

  @override
  Future<bool> readEnabled() async => enabled;

  @override
  Future<void> writeEnabled(bool value) async => enabled = value;
}

/// The one place app lock's state and rules live. The screens read it and
/// call it; none of them decide anything.
class AppLockController extends ChangeNotifier {
  AppLockController({
    required this.settings,
    required this.authenticator,
    Duration Function()? elapsed,
    this.relockAfter = const Duration(minutes: 1),
    this.setSecureWindow = _platformSecureWindow,
  }) : _elapsed = elapsed ?? _monotonic();

  /// A controller that is already loaded and off, for tests and previews
  /// that never think about the lock.
  factory AppLockController.off() {
    final AppLockController c = AppLockController(
      settings: MemoryLockSettings(),
      authenticator: _NeverAuthenticator(),
      setSecureWindow: (bool _) async {},
    );
    c._loaded = true;
    return c;
  }

  final LockSettingsStore settings;
  final LockAuthenticator authenticator;

  /// Time since some fixed point, that only ever moves forward. NOT the wall
  /// clock: setting the phone's clock back an hour must not count as being
  /// away for less than a minute.
  final Duration Function() _elapsed;

  /// How long away before the phone's lock is asked for again. Long enough
  /// to copy a GCash number and come back; short enough that a phone left on
  /// a table locks again.
  final Duration relockAfter;

  /// Tells Android whether to hide the app from screenshots and the recent
  /// apps view. Injected so a test can see what was asked.
  final Future<void> Function(bool secure) setSecureWindow;

  bool _loaded = false;
  bool _enabled = false;
  bool _locked = false;
  bool _covered = false;
  bool _busy = false;
  String? _message;
  Duration? _awayAt;

  bool get loaded => _loaded;
  bool get enabled => _enabled;

  /// Waiting for the phone's lock before anything shows.
  bool get locked => _enabled && _locked;

  /// Briefly hidden because the app is in the background; no lock needed
  /// to come back within [relockAfter].
  bool get covered => _enabled && _covered;
  bool get busy => _busy;

  /// The last thing worth telling the person, or null.
  String? get message => _message;

  static Duration Function() _monotonic() {
    final Stopwatch watch = Stopwatch()..start();
    return () => watch.elapsed;
  }

  /// Reads the setting. On a cold start with the lock on, the app starts
  /// LOCKED, before the first frame, so no figure ever flashes.
  Future<void> load() async {
    _enabled = await settings.readEnabled();
    _locked = _enabled;
    _loaded = true;
    await _secure();
    notifyListeners();
  }

  /// One try at the phone's lock, from the lock screen.
  Future<void> unlock() async {
    if (_busy || !locked) return;
    _busy = true;
    _message = null;
    notifyListeners();
    final UnlockOutcome outcome = await authenticator.authenticate(
      'Unlock Salapify',
    );
    _busy = false;
    switch (outcome) {
      case UnlockOutcome.unlocked:
        _locked = false;
      case UnlockOutcome.unavailable:
        // THE WAY OUT, and the most important branch in this file. The
        // phone's screen lock was removed after app lock was turned on, so
        // there is nothing left to check against. Locking now would lock the
        // owner out of their own money for good, so the lock opens and turns
        // itself off, and says so. Letting them in does not wait on the
        // write succeeding.
        _locked = false;
        _enabled = false;
        _message =
            'App lock is off: this phone no longer has a screen lock. Set '
            'one in your phone\'s settings, then turn app lock on again.';
        try {
          await settings.writeEnabled(false);
        } catch (_) {}
        await _secure();
      case UnlockOutcome.lockedOut:
        _message =
            'Too many tries. Wait a moment, then tap Unlock to try again.';
      case UnlockOutcome.cancelled:
        _message = null;
      case UnlockOutcome.error:
        _message = 'Your phone could not check its lock. Tap Unlock to retry.';
    }
    notifyListeners();
  }

  /// Turns app lock on, but only after the phone's lock has been passed
  /// once. That proves, before anything is locked, that this person can
  /// open what they are about to lock. Returns a sentence to show when it
  /// did not turn on, or null when it did.
  Future<String?> enable() async {
    if (_enabled) return null;
    final UnlockOutcome outcome = await authenticator.authenticate(
      'Turn on app lock for Salapify',
    );
    switch (outcome) {
      case UnlockOutcome.unlocked:
        _enabled = true;
        _locked = false;
        await settings.writeEnabled(true);
        await _secure();
        notifyListeners();
        return null;
      case UnlockOutcome.unavailable:
        return 'Set a screen lock on your phone first (a PIN, pattern, '
            'fingerprint or face), then turn this on.';
      case UnlockOutcome.lockedOut:
        return 'Too many tries. Wait a moment and try again.';
      case UnlockOutcome.cancelled:
      case UnlockOutcome.error:
        return 'App lock is still off.';
    }
  }

  /// Turns app lock off, after the phone's lock, so somebody handed an
  /// unlocked phone cannot quietly switch it off. A phone with no screen
  /// lock any more may switch it off freely, for the same reason [unlock]
  /// lets them in.
  Future<String?> disable() async {
    if (!_enabled) return null;
    final UnlockOutcome outcome = await authenticator.authenticate(
      'Turn off app lock for Salapify',
    );
    if (outcome != UnlockOutcome.unlocked &&
        outcome != UnlockOutcome.unavailable) {
      return 'App lock is still on.';
    }
    await _turnOff();
    return null;
  }

  /// "Delete everything on this phone" takes the lock with it.
  Future<void> wipe() => _turnOff();

  Future<void> _turnOff() async {
    _enabled = false;
    _locked = false;
    _covered = false;
    try {
      await settings.writeEnabled(false);
    } catch (_) {}
    await _secure();
    notifyListeners();
  }

  /// The app left the screen: cover it at once, start the clock.
  void onBackground() {
    if (!_enabled) return;
    _awayAt ??= _elapsed();
    if (!_covered) {
      _covered = true;
      notifyListeners();
    }
  }

  /// The app is back: lift the cover, and lock if it was away too long.
  void onForeground() {
    if (!_enabled) return;
    final Duration? away = _awayAt;
    _awayAt = null;
    if (away != null && _elapsed() - away > relockAfter) _locked = true;
    _covered = false;
    notifyListeners();
  }

  void clearMessage() {
    if (_message == null) return;
    _message = null;
    notifyListeners();
  }

  Future<void> _secure() async {
    try {
      await setSecureWindow(_enabled);
    } catch (_) {
      // A phone or a test with no such channel: the lock itself still
      // works, only the screenshot shield is missing.
    }
  }

  static const MethodChannel _window = MethodChannel('salapify/secure_window');

  static Future<void> _platformSecureWindow(bool secure) async {
    if (kIsWeb) return;
    await _window.invokeMethod<void>('setSecure', <String, Object>{
      'secure': secure,
    });
  }
}

class _NeverAuthenticator implements LockAuthenticator {
  @override
  Future<UnlockOutcome> authenticate(String reason) async =>
      UnlockOutcome.unavailable;
}

/// Hands the controller to anything under the app, Settings in particular.
class AppLockScope extends InheritedNotifier<AppLockController> {
  const AppLockScope({
    super.key,
    required AppLockController controller,
    required super.child,
  }) : super(notifier: controller);

  static AppLockController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppLockScope>()?.notifier;
}
