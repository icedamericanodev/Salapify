import 'package:flutter/material.dart';

import '../../design/pan_art.dart';
import '../../design/tokens.dart';
import '../../design/type.dart';
import 'app_lock.dart';

/// Lays the lock screen OVER the app when app lock asks for it.
///
/// Over, not instead: a relock after a minute away must not throw away the
/// sheet somebody was halfway through filling in. Underneath, everything is
/// hidden from screen readers while the lock is up, because a lock TalkBack
/// can read through is not a lock.
///
/// The phone's lock is offered once on entering the locked state, never in a
/// loop: a person who backs out sees the Unlock button and chooses when to
/// try again.
class LockGate extends StatefulWidget {
  const LockGate({
    super.key,
    required this.controller,
    required this.palette,
    required this.child,
  });

  final AppLockController controller;
  final Palette palette;
  final Widget child;

  @override
  State<LockGate> createState() => _LockGateState();
}

class _LockGateState extends State<LockGate> with WidgetsBindingObserver {
  /// Whether this stretch of being locked has already offered the prompt.
  bool _prompted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.controller.addListener(_changed);
  }

  @override
  void didUpdateWidget(LockGate old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_changed);
      widget.controller.addListener(_changed);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    final AppLockController c = widget.controller;
    if (!c.locked) _prompted = false;
    // A sentence for somebody who is already IN, which the lock screen
    // cannot carry because it has just gone: the "your phone has no screen
    // lock any more, so app lock turned itself off" case above all. Said
    // once, then cleared.
    final String? note = c.message;
    if (!c.locked && note != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.maybeOf(context)
          ?..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(note)));
        c.clearMessage();
      });
    }
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        widget.controller.onBackground();
      case AppLifecycleState.resumed:
        widget.controller.onForeground();
      case AppLifecycleState.detached:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLockController c = widget.controller;
    final bool show = c.locked || c.covered;

    if (c.locked && !_prompted && !c.busy) {
      _prompted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) c.unlock();
      });
    }

    return Stack(
      children: <Widget>[
        ExcludeSemantics(excluding: show, child: widget.child),
        if (show)
          Positioned.fill(
            child: _LockScreen(
              palette: widget.palette,
              locked: c.locked,
              busy: c.busy,
              message: c.message,
              onUnlock: c.unlock,
            ),
          ),
      ],
    );
  }
}

class _LockScreen extends StatelessWidget {
  const _LockScreen({
    required this.palette,
    required this.locked,
    required this.busy,
    required this.message,
    required this.onUnlock,
  });

  final Palette palette;

  /// False when the screen is only a cover for the app switcher, which
  /// needs no button: coming back within a minute just lifts it.
  final bool locked;
  final bool busy;
  final String? message;
  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context) {
    final Palette p = palette;
    return Material(
      color: p.background,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(Spacing.xxl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                // Shy: the mood the brief keeps for "asking permission".
                const PanArt(mood: PanMood.shy),
                const SizedBox(height: panGap),
                Text(
                  'Salapify is locked',
                  textAlign: TextAlign.center,
                  style: AppType.title(p),
                ),
                const SizedBox(height: Spacing.xs),
                Text(
                  'Use your phone\'s lock to open it.',
                  textAlign: TextAlign.center,
                  style: AppType.body(p).copyWith(color: p.textSecondary),
                ),
                if (locked) ...<Widget>[
                  const SizedBox(height: Spacing.xl),
                  SizedBox(
                    width: 220,
                    child: FilledButton.icon(
                      key: const Key('lock-unlock'),
                      onPressed: busy ? null : onUnlock,
                      style: FilledButton.styleFrom(
                        backgroundColor: p.accent,
                        foregroundColor: p.onAccent,
                        disabledBackgroundColor: p.accent.withValues(
                          alpha: 0.6,
                        ),
                        disabledForegroundColor: p.onAccent,
                        minimumSize: const Size.fromHeight(48),
                      ),
                      icon: const Icon(Icons.lock_open_outlined, size: 18),
                      label: Text(
                        busy ? 'Checking' : 'Unlock',
                        style: AppType.button(p, color: p.onAccent),
                      ),
                    ),
                  ),
                ],
                if (message != null) ...<Widget>[
                  const SizedBox(height: Spacing.md),
                  Text(
                    message!,
                    textAlign: TextAlign.center,
                    style: AppType.caption(p),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
