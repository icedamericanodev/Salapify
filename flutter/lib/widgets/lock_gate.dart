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
      // biometricOnly: false lets the OS offer the device PIN or pattern as a
      // backstop, so a wet sensor or a biometric cooldown never strands an
      // owner who knows their passcode. Matches the RN default.
      return await _auth.authenticate(
        localizedReason: 'Unlock Salapify',
        options: const AuthenticationOptions(
            biometricOnly: false, stickyAuth: true),
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
  // Cover the app the moment it goes to the background (when the lock is on),
  // so the money screens never appear in the app-switcher thumbnail or a
  // screenshot. This is separate from needing re-auth: a quick hop back within
  // the grace window just lifts the cover, no fingerprint required.
  bool _obscure = false;
  DateTime? _awaySince;

  // A finance app should not stay open to whoever grabs the phone next, so the
  // no-reprompt window is short. Long enough to copy a GCash number and come
  // back, short enough that a set-down phone re-locks quickly.
  static const _graceMs = 30 * 1000;

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

  // Cover on background immediately; re-require the fingerprint only after the
  // grace window, so a few seconds in GCash or Messages does not re-prompt.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_lockOn) return;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      _awaySince ??= DateTime.now();
      if (!_obscure) setState(() => _obscure = true);
    } else if (state == AppLifecycleState.resumed) {
      final away = _awaySince;
      final beyondGrace = away != null &&
          DateTime.now().difference(away).inMilliseconds > _graceMs;
      setState(() {
        if (beyondGrace) {
          _unlocked = false;
          _promptedForThisLock = false;
        }
        _obscure = false;
      });
      _awaySince = null;
    }
  }

  Future<void> _unlock() async {
    if (_checking) return;
    setState(() => _checking = true);
    try {
      // No biometrics enrolled? A lock could only ever lock the owner out, so
      // turn it off and let them in. Letting them in must NOT depend on the
      // disable-write succeeding, or a failed save would strand them behind a
      // lock they can never pass, so the persist is best-effort.
      if (!await widget.authenticator.canLock()) {
        try {
          if (widget.store.canWrite) await widget.store.setAppLock(false);
        } catch (_) {}
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

    // Needing auth drives the biometric prompt; the overlay also shows while
    // merely obscured (backgrounded within the grace window), which hides the
    // app-switcher thumbnail without demanding a fingerprint on quick return.
    final needsAuth = _lockOn && !_unlocked;
    final showOverlay = _lockOn && (!_unlocked || _obscure);

    // Prompt once when entering the locked state (not for a mere cover).
    if (needsAuth && !_promptedForThisLock && !_checking) {
      _promptedForThisLock = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _unlock();
      });
    }

    return Stack(
      children: [
        // A lock TalkBack can read through is not a lock: hide the content
        // behind the overlay from screen readers while it is up.
        ExcludeSemantics(excluding: showOverlay, child: widget.child),
        if (showOverlay)
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
                // The badge is the obvious "press here", so make it unlock too.
                Semantics(
                  button: true,
                  label: 'Unlock',
                  child: InkWell(
                    borderRadius: BorderRadius.circular(44),
                    onTap: checking ? null : onUnlock,
                    child: Container(
                      width: 88,
                      height: 88,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Barako.card,
                        shape: BoxShape.circle,
                        border: Border.all(color: Barako.border),
                      ),
                      child: Icon(Icons.fingerprint,
                          size: 44, color: Barako.primary),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text('Salapify is locked',
                    style: TextStyle(
                        color: Barako.text,
                        fontSize: 22,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text('Private to you on this phone.',
                    style: TextStyle(color: Barako.muted, fontSize: 15)),
                const SizedBox(height: 28),
                FilledButton(
                  onPressed: checking ? null : onUnlock,
                  style: FilledButton.styleFrom(
                    backgroundColor: Barako.primary,
                    foregroundColor: Barako.onPrimary,
                    disabledBackgroundColor:
                        Barako.primary.withValues(alpha: 0.6),
                    // Keep the label legible while checking (Material's default
                    // disabled foreground would fade it below AA).
                    disabledForegroundColor: Barako.onPrimary,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 40, vertical: 14),
                  ),
                  child: checking
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Barako.onPrimary),
                        )
                      : const Text('Unlock',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
