import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The app's motion rules in one place, so every animation follows them.
///
/// From the motion review the founder asked for on 2026-10-07. Three rules
/// hold for everything here and for SettleFigure:
///   1. REDUCED MOTION WINS. When the phone asks for less motion, every
///      animation jumps to its final state. An animation a person has
///      switched off is a defect, not a style.
///   2. INTERACTIONS STAY UNDER 400ms, so the app never makes anybody wait to
///      read their money.
///   3. MOTION EXPLAINS A CHANGE. Nothing animates on first paint; a value
///      moves only when it changed while on screen.

/// Whether this phone has asked for less motion.
bool reduceMotion(BuildContext context) =>
    MediaQuery.maybeDisableAnimationsOf(context) ?? false;

/// The house press: shrink to 0.96 while held, spring back on release.
///
/// 0.96 is the floor; below it a press reads as a glitch. Down is quicker
/// than up (100ms, 160ms) because a press should feel immediate and a
/// release settled. It only SCALES; the child keeps its own tap handling,
/// so wrapping a button changes how it feels and nothing it does.
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, this.enabled = true});

  final Widget child;
  final bool enabled;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled || reduceMotion(context)) return widget.child;
    return Listener(
      // A Listener rather than a GestureDetector: it watches the pointer
      // without joining the gesture arena, so the child's own InkWell still
      // receives the tap, and a scroll that starts on the button still
      // scrolls.
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _down ? 0.96 : 1.0,
        duration: Duration(milliseconds: _down ? 100 : 160),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// A value that GROWS to its new level instead of snapping, for any bar.
///
/// After "Record a payment" the debt bar visibly moves, which shows the
/// payment did it. First paint is the value itself: the tween starts at the
/// value it ends on, so only a later change animates. A builder, so each
/// bar keeps its own colours and shape:
///
///     GrowTo(value: debt.progress, builder: (double v) =>
///         LinearProgressIndicator(value: v, ...))
class GrowTo extends StatelessWidget {
  const GrowTo({super.key, required this.value, required this.builder});

  final double value;
  final Widget Function(double value) builder;

  @override
  Widget build(BuildContext context) {
    final double v = value.isFinite ? value.clamp(0.0, 1.0) : 0.0;
    if (reduceMotion(context)) return builder(v);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: v, end: v),
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
      builder: (BuildContext context, double x, Widget? _) => builder(x),
    );
  }
}

/// The buzz that confirms a save. A MILESTONE, a debt paid off or a goal
/// reached, gets a firmer one, because finishing something is the moment the
/// app should feel different from an ordinary entry. It is never used for a
/// warning: a buzz that sometimes means "well done" and sometimes "careful"
/// teaches the thumb nothing.
void saveHaptic({bool milestone = false}) {
  if (milestone) {
    HapticFeedback.mediumImpact();
  } else {
    HapticFeedback.lightImpact();
  }
}
