/// Pumping the whole app in a widget test, against a PINNED clock.
///
/// ## What this exists to stop
///
/// On 1 October 2026 six tests went red and not a line of app code had
/// changed. They pumped `const SalapifyApp()`, which builds its own
/// [FinancialState] and therefore reads the REAL clock. The seed ledger is
/// dated September 2026 and those tests assert figures that mean "spent this
/// month", so the moment the calendar rolled, nothing in the seed counted as
/// this month and every budget showed its full limit unspent.
///
/// One of them failed for a second reason worth knowing. The date-picker
/// journey steps back one day and taps that number in the Material calendar.
/// On the FIRST of a month, yesterday is in the previous month, so the number
/// it taps is a future date in the month the picker opened on, the picker
/// refuses it, and the tap lands nowhere. The failure reads as a missing
/// warning rather than as a missed tap.
///
/// Two files were pinned by hand at the time. Fourteen were not, so the same
/// thing was set to happen again on 1 November. This is the shared door, and
/// `test/clock_discipline_test.dart` is what stops a fifteenth being added.
///
/// ## Why a helper rather than a rule
///
/// Pinning is three lines that are easy to leave out and impossible to notice
/// missing, because a test written on the 10th of a month passes all month.
/// A helper makes the pinned path the SHORT path.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/main.dart';
import 'package:salapify/state/financial_state.dart';

export 'test_clock.dart' show testToday;

import 'test_clock.dart';

// testToday comes from test_clock.dart, which engine tests import without
// pulling in flutter_test. One date, one definition.

/// Builds a store on [testToday], pumps the app with it, and settles.
///
/// Returns the store, because almost every caller then needs to read balances
/// off it or assert what a tap wrote.
///
/// The app only restores a store it MADE, so an injected one is restored here.
/// On the default memory store that settles immediately and its only real
/// effect is turning saving on, which is what the production path does before
/// the first frame.
Future<FinancialState> pumpSalapify(
  WidgetTester tester, {
  DateTime? clock,
  bool onboarded = true,
}) async {
  final FinancialState state = FinancialState(clock: clock ?? testToday);
  await state.restore();
  addTearDown(state.dispose);

  // ALREADY ONBOARDED, by default, and that default is the honest fixture
  // rather than a convenience.
  //
  // From 2026-10-03 a first launch opens on the welcome instead of the app,
  // so a store holding only the seed is a phone nobody has introduced
  // themselves to yet. Every caller of this helper wants the app as somebody
  // ALREADY USING IT, and the seeded ledger they then assert against is
  // exactly what the "look around with example data" path leaves behind. So
  // the fixture says that in one line instead of pretending the question was
  // never asked.
  //
  // Pass `onboarded: false` to get the first launch itself. Nothing else in
  // the helper changes, so a test of the welcome pins its clock the same way
  // everything else does.
  if (onboarded) state.startWithExampleData();

  await tester.pumpWidget(SalapifyApp(state: state));
  await tester.pumpAndSettle();
  return state;
}
