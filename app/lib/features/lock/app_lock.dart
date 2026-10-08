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

  /// Fingerprint and face are paused until the phone itself is unlocked
  /// with its PIN, pattern or password. Waiting does not end this one.
  biometricsPaused,

  /// This phone has no screen lock at all, so nothing can be checked.
  unavailable,

  /// Anything else the phone reported.
  error,
}

/// The phone's own lock, behind an interface so a test never reaches a
/// platform channel that does not exist in one.
abstract class LockAuthenticator {
  Future<UnlockOutcome> authenticate(String reason);

  /// Android's own "confirm your PIN, pattern or password" screen, without
  /// the biometric prompt in front of it. The way round a fingerprint
  /// prompt that keeps failing on some phones: still the phone's own lock,
  /// never a way past it.
  Future<UnlockOutcome> confirmWithPhoneCode(String reason);
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
          return UnlockOutcome.lockedOut;
        case LocalAuthExceptionCode.biometricLockout:
          return UnlockOutcome.biometricsPaused;
        default:
          // New codes may be added to the plugin at any time, so there is
          // always a fallback rather than an exhaustive match.
          return UnlockOutcome.error;
      }
    } catch (_) {
      return UnlockOutcome.error;
    }
  }

  static const MethodChannel _channel = MethodChannel('salapify/secure_window');

  @override
  Future<UnlockOutcome> confirmWithPhoneCode(String reason) async {
    try {
      final bool? ok = await _channel.invokeMethod<bool>(
        'confirmDeviceCredential',
        <String, Object>{'title': 'Unlock Salapify', 'description': reason},
      );
      if (ok == null) return UnlockOutcome.unavailable;
      return ok ? UnlockOutcome.unlocked : UnlockOutcome.cancelled;
    } catch (_) {
      return UnlockOutcome.error;
    }
  }
}

/// Where the one setting lives.
abstract class LockSettingsStore {
  Future<bool> readEnabled();
  Future<void> writeEnabled(bool enabled);

  /// True when the last read found a setting it could not understand and
  /// fell back to off, so the person can be told rather than left guessing.
  bool get readFailed;
}

/// The real store: `app_lock.json` beside the ledger, NOT inside it, so the
/// export and every backup leave it out by construction.
class FileLockSettings implements LockSettingsStore {
  FileLockSettings();

  @override
  bool readFailed = false;

  Future<File> _file() async {
    final Directory dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/app_lock.json');
  }

  @override
  Future<bool> readEnabled() async {
    readFailed = false;
    File? f;
    try {
      f = await _file();
      if (!f.existsSync()) return false;
      final Object? m = jsonDecode(await f.readAsString());
      if (m is Map && m['enabled'] == true) return true;
      readFailed = true;
      return false;
    } catch (_) {
      // An unreadable lock file must never lock somebody out of their own
      // money. Unreadable means off, and the person is told.
      readFailed = f != null;
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
    // Written beside and renamed over, the way the ledger is written, so a
    // crash halfway cannot leave a half file that silently reads as off.
    final File tmp = File('${f.path}.tmp');
    await tmp.writeAsString(
      jsonEncode(<String, Object>{'enabled': true}),
      flush: true,
    );
    await tmp.rename(f.path);
  }
}

/// For tests and previews.
class MemoryLockSettings implements LockSettingsStore {
  MemoryLockSettings([this.enabled = false]);

  bool enabled;

  @override
  bool readFailed = false;

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
    DateTime Function()? wall,
    this.relockAfter = const Duration(minutes: 1),
    this.promptTimeout = const Duration(minutes: 2),
    this.setSecureWindow = _platformSecureWindow,
  }) : _elapsed = elapsed ?? _monotonic(),
       _wall = wall ?? DateTime.now;

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

  /// The wall clock, the other half of measuring time away. The stopwatch
  /// above stops while the phone is asleep on Android, so a phone left
  /// face down for half an hour could count only seconds; the wall clock
  /// keeps counting through sleep but can be moved back. Time away is the
  /// LARGER of the two, so neither weakness alone shortens it.
  final DateTime Function() _wall;

  /// The longest the phone's prompt may take before it counts as a failure,
  /// so a prompt that never answers cannot leave the button stuck on
  /// "Checking" for good.
  final Duration promptTimeout;

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
  DateTime? _awayWall;

  /// Errors in a row from the phone's prompt. After two, the lock screen
  /// offers the phone's PIN screen directly, so a phone whose fingerprint
  /// prompt is broken can still get in, through its own lock.
  int _errors = 0;

  bool get loaded => _loaded;
  bool get enabled => _enabled;

  /// Waiting for the phone's lock before anything shows.
  bool get locked => _enabled && _locked;

  /// Briefly hidden because the app is in the background; no lock needed
  /// to come back within [relockAfter].
  bool get covered => _enabled && _covered;
  bool get busy => _busy;

  /// Whether to offer "Use your phone's PIN instead".
  bool get offerPhoneCode => _errors >= 2;

  /// The last thing worth telling the person, or null.
  String? get message => _message;

  /// Something the person must READ before going on, shown on the lock
  /// screen itself with an "Open Salapify" button rather than in a passing
  /// note. A note drawn under an open sheet expires unseen, and these say
  /// that app lock is off, which nobody should have to discover by chance.
  String? get notice => _notice;
  String? _notice;

  void dismissNotice() {
    if (_notice == null) return;
    _notice = null;
    notifyListeners();
  }

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
    if (settings.readFailed) {
      _notice =
          'App lock\'s setting could not be read, so it is off. Turn it on '
          'again in Settings if you want it.';
    }
    await _secure();
    notifyListeners();
  }

  /// One try at the phone's lock, from the lock screen.
  Future<void> unlock() =>
      _attempt(() => authenticator.authenticate('Unlock Salapify'));

  /// The same, through the phone's PIN screen rather than the biometric
  /// prompt. Offered after repeated errors.
  Future<void> unlockWithPhoneCode() =>
      _attempt(() => authenticator.confirmWithPhoneCode('Unlock Salapify'));

  Future<void> _attempt(Future<UnlockOutcome> Function() ask) async {
    if (_busy || !locked) return;
    _busy = true;
    _message = null;
    notifyListeners();
    UnlockOutcome outcome;
    try {
      outcome = await ask().timeout(
        promptTimeout,
        onTimeout: () => UnlockOutcome.error,
      );
    } catch (_) {
      outcome = UnlockOutcome.error;
    }
    _busy = false;
    _errors = outcome == UnlockOutcome.error ? _errors + 1 : 0;
    switch (outcome) {
      case UnlockOutcome.unlocked:
        _locked = false;
        // The prompt itself sent the app to the background, which started
        // the away clock. A slow PIN entry must not count as time away, or
        // a successful unlock would be followed by a second prompt.
        _awayAt = null;
        _awayWall = null;
        _covered = false;
      case UnlockOutcome.unavailable:
        // THE WAY OUT, and the most important branch in this file. The
        // phone's screen lock was removed after app lock was turned on, so
        // there is nothing left to check against. Locking now would lock the
        // owner out of their own money for good, so the lock opens and turns
        // itself off, and says so. Letting them in does not wait on the
        // write succeeding.
        _locked = false;
        _enabled = false;
        _awayAt = null;
        _awayWall = null;
        _notice =
            'App lock is off. This phone no longer has a screen lock, so '
            'Salapify cannot check one. Set a screen lock in your phone\'s '
            'settings, then turn app lock on again in Salapify\'s Settings.';
        try {
          await settings.writeEnabled(false);
        } catch (_) {}
        await _secure();
      case UnlockOutcome.lockedOut:
        _message =
            'Too many tries. Wait a moment, then tap Unlock to try again.';
      case UnlockOutcome.biometricsPaused:
        _message = _pausedCopy;
      case UnlockOutcome.cancelled:
        _message = null;
      case UnlockOutcome.error:
        // From the second error in a row, the way out is spelled out,
        // including the one move that must NOT be made. Uninstalling is the
        // natural thing to try and it deletes every record.
        _message = offerPhoneCode
            ? 'Your phone still could not check its lock. Your records are '
                  'safe. Use your phone\'s PIN instead, or close Salapify '
                  'fully and open it again. Do not uninstall Salapify: that '
                  'deletes your records.'
            : 'Your phone could not check its lock. Tap Unlock to retry.';
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
        // Saved FIRST, and only reported on once it is. A lock that showed
        // as on but was never written would be off at the next launch,
        // with nobody told.
        try {
          await settings.writeEnabled(true);
        } catch (_) {
          return 'App lock could not be saved, so it is still off.';
        }
        _enabled = true;
        _locked = false;
        _awayAt = null;
        _awayWall = null;
        await _secure();
        notifyListeners();
        return null;
      case UnlockOutcome.unavailable:
        return 'Set a screen lock on your phone first (a PIN, pattern, '
            'fingerprint or face), then turn this on.';
      case UnlockOutcome.lockedOut:
        return 'Too many tries. Wait a moment and try again.';
      case UnlockOutcome.biometricsPaused:
        return _pausedCopy;
      case UnlockOutcome.cancelled:
      case UnlockOutcome.error:
        return 'App lock is still off.';
    }
  }

  static const String _pausedCopy =
      'Fingerprint and face unlock are paused on this phone. Lock your '
      'phone, open it with your PIN, pattern or password, then try again.';

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
    if (!await _turnOff()) {
      return 'App lock is off for now, but the change could not be saved, so '
          'it may come back the next time Salapify opens.';
    }
    return null;
  }

  /// "Delete everything on this phone" takes the lock with it.
  Future<void> wipe() => _turnOff();

  /// Off now, whatever the disk says. True when the setting was saved too.
  Future<bool> _turnOff() async {
    _enabled = false;
    _locked = false;
    _covered = false;
    _awayAt = null;
    _awayWall = null;
    bool saved = true;
    try {
      await settings.writeEnabled(false);
    } catch (_) {
      saved = false;
    }
    await _secure();
    notifyListeners();
    return saved;
  }

  /// The app left the screen: cover it at once, start the clock.
  void onBackground() {
    if (!_enabled) return;
    _awayAt ??= _elapsed();
    _awayWall ??= _wall();
    if (!_covered) {
      _covered = true;
      notifyListeners();
    }
  }

  /// The app is back: lift the cover, and lock if it was away too long.
  void onForeground() {
    if (!_enabled) return;
    final Duration? away = _awayAt;
    final DateTime? awayWall = _awayWall;
    _awayAt = null;
    _awayWall = null;
    if (away != null) {
      final Duration byWatch = _elapsed() - away;
      final Duration byWall = awayWall == null
          ? Duration.zero
          : _wall().difference(awayWall);
      final Duration gone = byWall > byWatch ? byWall : byWatch;
      if (gone > relockAfter) _locked = true;
    }
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

  @override
  Future<UnlockOutcome> confirmWithPhoneCode(String reason) async =>
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
