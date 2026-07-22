// LockGate covers the whole app with a lock screen when App lock is on in
// Settings. Unlocking uses the phone's own biometrics (fingerprint or face)
// through local_auth. Quick hops to another app do not lock it; it locks again
// only after being away for over a minute. The lock is drawn OVER the app
// instead of replacing it, so a re-lock never throws away what you were in the
// middle of. If the phone has no biometrics set up (for example after restoring
// a backup onto a new phone), the gate turns the lock off instead of locking
// you out forever. On web the gate does nothing. Ported from the RN LockGate.

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

import '../data/store.dart';
import '../theme.dart';

/// The biometric check, behind an interface so tests can inject a fake instead
/// of the real platform channel (which does not exist in a widget test).
abstract class LockAuthenticator {
  /// True when the phone has biometrics enrolled and can actually lock. When
  /// false the gate disables App lock so the owner is never locked out.
  Future<bool> canLock();

  /// Prompt for the fingerprint or face. True on success.
  Future<bool> authenticate();
}

class BiometricAuthenticator implements LockAuthenticator {
  final LocalAuthentication _auth = LocalAuthentication();

  @override
  Future<bool> canLock() async {
    try {
      if (!await _auth.isDeviceSupported()) return false;
      if (!await _auth.canCheckBiometrics) return false;
      final available = await _auth.getAvailableBiometrics();
      return available.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> authenticate() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'Unlock Salapify',
        options: const AuthenticationOptions(
            biometricOnly: true, stickyAuth: true),
      );
    } catch (_) {
      return false;
    }
  }
}

class LockGate extends StatefulWidget {
  final SalapifyStore store;
  final Widget child;

  /// Injectable for tests; the app uses the real biometric check.
  final LockAuthenticator authenticator;

  LockGate({
    super.key,
    required this.store,
    required this.child,
    LockAuthenticator? authenticator,
  }) : authenticator = authenticator ?? BiometricAuthenticator();

  @override
  State<LockGate> createState() => _LockGateState();
}

class _LockGateState extends State<LockGate> with WidgetsBindingObserver {
  bool _unlocked = false;
  bool _checking = false;
  // Whether we already fired the biometric prompt for the current locked
  // stretch, so entering the lock prompts exactly once (the user taps Unlock to
  // retry). Reset when we unlock or re-lock.
  bool _promptedForThisLock = false;
  DateTime? _awaySince;

  static const _graceMs = 60 * 1000;

  bool get _native => !kIsWeb;

  bool get _lockOn {
    if (!_native || !widget.store.loaded) return false;
    return (widget.store.data['settings'] as Map?)?['appLock'] == true;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Lock again only after over a minute away, so a few seconds in GCash or
  // Messages does not demand the fingerprint again.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_lockOn) return;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      _awaySince ??= DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final away = _awaySince;
      if (away != null &&
          DateTime.now().difference(away).inMilliseconds > _graceMs) {
        setState(() {
          _unlocked = false;
          _promptedForThisLock = false;
        });
      }
      _awaySince = null;
    }
  }

  Future<void> _unlock() async {
    if (_checking) return;
    setState(() => _checking = true);
    try {
      // No biometrics enrolled? A lock could only ever lock the owner out, so
      // turn it off and let them in.
      if (!await widget.authenticator.canLock()) {
        if (widget.store.canWrite) await widget.store.setAppLock(false);
        if (mounted) {
          setState(() {
            _unlocked = true;
            _checking = false;
          });
        }
        return;
      }
      final ok = await widget.authenticator.authenticate();
      if (mounted) {
        setState(() {
          if (ok) _unlocked = true;
          _checking = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_native) return widget.child;

    // Until the saved settings are read we do not know whether to lock, so show
    // a blank instead of flashing data. If the read failed, let the app render
    // so its storage-error message shows instead of a silent blank forever.
    if (!widget.store.loaded && widget.store.loadError == null) {
      return ColoredBox(color: Barako.background, child: const SizedBox.expand());
    }

    final locked = _lockOn && !_unlocked;

    // Prompt once when entering the locked state.
    if (locked && !_promptedForThisLock && !_checking) {
      _promptedForThisLock = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _unlock();
      });
    }

    return Stack(
      children: [
        // A lock TalkBack can read through is not a lock: hide the content
        // behind the overlay from screen readers while locked.
        ExcludeSemantics(excluding: locked, child: widget.child),
        if (locked)
          Positioned.fill(
            child: _LockScreen(checking: _checking, onUnlock: _unlock),
          ),
      ],
    );
  }
}

class _LockScreen extends StatelessWidget {
  final bool checking;
  final VoidCallback onUnlock;
  const _LockScreen({required this.checking, required this.onUnlock});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: Material(
        color: Barako.background,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 88,
                  height: 88,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Barako.card,
                    shape: BoxShape.circle,
                    border: Border.all(color: Barako.border),
                  ),
                  child: Icon(Icons.fingerprint, size: 44, color: Barako.primary),
                ),
                const SizedBox(height: 20),
                Text('Salapify is locked',
                    style: TextStyle(
                        color: Barako.text,
                        fontSize: 22,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text('Your money stays private.',
                    style: TextStyle(color: Barako.muted, fontSize: 15)),
                const SizedBox(height: 28),
                FilledButton(
                  onPressed: checking ? null : onUnlock,
                  style: FilledButton.styleFrom(
                    backgroundColor: Barako.primary,
                    foregroundColor: Barako.onPrimary,
                    disabledBackgroundColor:
                        Barako.primary.withValues(alpha: 0.5),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 40, vertical: 14),
                  ),
                  child: Text(checking ? 'Checking...' : 'Unlock',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
