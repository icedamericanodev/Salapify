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
import 'package:flutter/widgets.dart';

class AppClock extends InheritedWidget {
  const AppClock({super.key, required this.now, required super.child});

  /// The moment every screen under this widget treats as the present.
  final DateTime now;

  /// The real clock. What main.dart wraps the app in.
  static Widget live({required Widget child}) =>
      AppClock(now: DateTime.now(), child: child);

  @override
  bool updateShouldNotify(AppClock old) => old.now != now;
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
