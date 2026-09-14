// What "now" is, as something a test can set.
//
// Home is the first screen whose content depends on the DATE rather than only
// on the ledger: safe to spend paces a runway to the next payday, the rail
// fills to today, and the top line names the day. Read the system clock
// directly and two things break at once. The committed renders churn every
// midnight, so a review picture is never the same twice and a real change
// hides in the noise. And nothing can test the day before payday, the day
// after, or the end of a month, which are exactly the days the screen has to
// get right.
//
// An InheritedWidget rather than a global function, because a global that
// tests reassign is a global that stays reassigned when a test forgets to put
// it back, and the failure then lands in some unrelated file.
import 'dart:async';

import 'package:flutter/widgets.dart';

class AppClock extends InheritedWidget {
  const AppClock({super.key, required this.now, required super.child});

  /// The moment every screen under this widget treats as the present.
  final DateTime now;

  /// The real clock. What main.dart wraps the app in.
  static Widget live({required Widget child}) => _LiveClock(child: child);

  @override
  bool updateShouldNotify(AppClock old) => old.now != now;
}

/// The real clock, which has to keep MOVING.
///
/// Reading `DateTime.now()` once in a build is a bug rather than a shortcut,
/// and it is not a small one. Android keeps a process alive for days, so an app
/// opened on Friday evening and reopened on Monday would still say "Friday, Sep
/// 11" and "4 days to payday", and a bill that was due on Saturday would still
/// read "tomorrow". Every date derived figure on Home would be silently stale,
/// with nothing on the screen admitting it. Leaving the app open across
/// midnight does the same thing.
///
/// So this refreshes on exactly the two events that can make "now" wrong: the
/// app coming back to the foreground, and the date rolling over while it is
/// open. It does NOT tick every second. Home has no clock face on it, and a
/// per second rebuild of the whole app to change nothing is a battery cost paid
/// for no visible result.
class _LiveClock extends StatefulWidget {
  const _LiveClock({required this.child});
  final Widget child;

  @override
  State<_LiveClock> createState() => _LiveClockState();
}

class _LiveClockState extends State<_LiveClock> with WidgetsBindingObserver {
  DateTime _now = DateTime.now();
  Timer? _midnight;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scheduleMidnight();
  }

  @override
  void dispose() {
    _midnight?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _tick();
  }

  void _tick() {
    setState(() => _now = DateTime.now());
    _scheduleMidnight();
  }

  /// Wake once, just after the date changes.
  ///
  /// A minute past midnight rather than exactly midnight, because a timer that
  /// fires a few milliseconds early would recompute the same date it already
  /// had and then wait another whole day to correct itself.
  void _scheduleMidnight() {
    _midnight?.cancel();
    final now = DateTime.now();
    final next = DateTime(now.year, now.month, now.day + 1, 0, 1);
    _midnight = Timer(next.difference(now), _tick);
  }

  @override
  Widget build(BuildContext context) => AppClock(now: _now, child: widget.child);
}

extension ClockX on BuildContext {
  /// Now, per the nearest [AppClock], or the system clock when there is none.
  ///
  /// The fallback is deliberate and it is not laziness: a screen pushed in a
  /// test or a preview with no clock above it should still draw rather than
  /// assert. The renders that matter go through the harness, which always
  /// supplies one.
  DateTime get now =>
      dependOnInheritedWidgetOfExactType<AppClock>()?.now ?? DateTime.now();
}
