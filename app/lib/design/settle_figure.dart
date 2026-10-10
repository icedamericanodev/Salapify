import 'package:flutter/material.dart';

/// SETTLE: a peso figure whose changed digits roll to their new value.
///
/// Salapify's signature motion, chosen 2026-10-07 by the motion review the
/// founder asked for ("add animation motion to make the appearance of the
/// app more appealing to the users and unique"). Many apps animate a balance
/// by counting it up; this does something narrower and, for money, more
/// honest:
///
///   ONLY THE DIGITS THAT CHANGED MOVE. Log 250 against 24,332.00 and the
///   "4,3" stays put while "32" rolls to "07". A person sees WHERE the
///   number moved, the hundreds or the thousands, which a count-up hides.
///
///   NEVER A WRONG NUMBER ON A GLANCE. No count-up from zero, no stagger
///   between digits: every changed digit moves at once, so at no instant
///   does the figure read as a third value that is neither the old one nor
///   the new one. The first paint is always the final value.
///
///   ONLY ON CHANGE. A figure animates when it changes while on screen,
///   which in this app means the person just did something (logged, undid,
///   paid, switched a scenario). Opening a screen never animates.
///
///   QUIET WHEN ASKED. Reduced motion on the phone shows the plain figure.
///
/// AT REST IT IS ONE ORDINARY Text, so screen readers, tests that find a
/// figure by its text, and layout all behave exactly as before. The per
/// character row exists only for the 240ms of a roll.
class SettleFigure extends StatefulWidget {
  const SettleFigure(
    this.text, {
    super.key,
    required this.style,
    this.maxLines,
    this.overflow,
  });

  /// The formatted figure, e.g. "₱24,332.00". Formatting stays with the
  /// caller, so the figure on screen is exactly what it was before.
  final String text;
  final TextStyle style;

  /// Passed to the figure at rest, so a call site keeps the layout it had.
  final int? maxLines;
  final TextOverflow? overflow;

  /// How long a roll takes. Under the 400ms ceiling for interactions.
  static const Duration duration = Duration(milliseconds: 240);

  @override
  State<SettleFigure> createState() => _SettleFigureState();
}

class _SettleFigureState extends State<SettleFigure>
    with SingleTickerProviderStateMixin {
  late final AnimationController _roll = AnimationController(
    vsync: this,
    duration: SettleFigure.duration,
  )..addStatusListener(_onStatus);

  /// The figure being rolled AWAY from, or null when at rest.
  String? _from;

  void _onStatus(AnimationStatus s) {
    if (s == AnimationStatus.completed && mounted) {
      setState(() => _from = null);
    }
  }

  @override
  void didUpdateWidget(SettleFigure old) {
    super.didUpdateWidget(old);
    if (old.text == widget.text) return;
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _from = null;
      return;
    }
    // A change mid-roll rolls from the figure the person last READ, the
    // previous target, never from a half-moved frame.
    _from = old.text;
    _roll.forward(from: 0);
  }

  @override
  void dispose() {
    _roll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Tabular digits, so a "1" and an "8" are the same width and nothing
    // beside the figure shifts when it changes.
    final TextStyle style = widget.style.copyWith(
      fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
    );
    final String? from = _from;
    if (from == null) {
      return Text(
        widget.text,
        style: style,
        maxLines: widget.maxLines,
        overflow: widget.overflow,
      );
    }

    // Columns aligned from the RIGHT: centavos line up with centavos, so a
    // figure that gains a digit grows on the left like a written number.
    final String to = widget.text;
    final int n = to.length > from.length ? to.length : from.length;
    String at(String s, int i) {
      final int k = i - (n - s.length);
      return k < 0 ? '' : s[k];
    }

    return Semantics(
      label: to,
      excludeSemantics: true,
      child: AnimatedBuilder(
        animation: _roll,
        builder: (BuildContext context, Widget? _) {
          final double t = Curves.easeOutCubic.transform(_roll.value);
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              for (int i = 0; i < n; i++)
                _column(at(from, i), at(to, i), t, style),
            ],
          );
        },
      ),
    );
  }

  /// One character position: still when unchanged, rolling when not.
  Widget _column(String a, String b, double t, TextStyle style) {
    if (a == b) return Text(b, style: style);
    return ClipRect(
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          // The old character leaves upward.
          FractionalTranslation(
            translation: Offset(0, -t),
            child: Opacity(
              opacity: 1 - t,
              child: Text(a.isEmpty ? ' ' : a, style: style),
            ),
          ),
          // The new one arrives from below.
          FractionalTranslation(
            translation: Offset(0, 1 - t),
            child: Opacity(
              opacity: t,
              child: Text(b.isEmpty ? ' ' : b, style: style),
            ),
          ),
        ],
      ),
    );
  }
}
