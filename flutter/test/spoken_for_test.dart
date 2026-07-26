// What is already spoken for, and the two ways showing it could go wrong.
//
// The bar exists because "you can spend X a day" hides the interesting half:
// the reason it is not more is that some of the cash is already promised. Two
// things have to hold for that to be worth drawing.
//
// FIRST, both figures must come from the same engine call. `liquid` and
// `available` are carried together on CycleStatus for exactly this reason: two
// separate reads of safeToSpend could drift, and then the bar and the headline
// would describe different money on the same card.
//
// SECOND, and this is the one that would actually crash, the widget divides by
// the total to size its segments. A zero or non-finite total makes the flex
// factors NaN, and NaN flex throws during LAYOUT, which takes the whole screen
// down rather than just looking wrong. A backup can carry junk doubles, so
// this is reachable, not theoretical.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/money/cycle.dart';
import 'package:salapify/screens/overview.dart' show formatMoney;
import 'package:salapify/theme.dart';
import 'package:salapify/widgets/spoken_for_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _bar(double committed, double free) => MaterialApp(
  theme: salapifyTheme(Barako.current),
  home: Scaffold(
    body: SpokenForBar(
      committed: committed,
      free: free,
      format: formatMoney,
    ),
  ),
);

void main() {
  group('the engine carries both halves', () {
    test('liquid rides along with available, from one safeToSpend call', () async {
      SharedPreferences.setMockInitialValues({});
      final store = SalapifyStore();
      await store.load();
      await store.addEntry({
        'type': 'income',
        'amount': 20000.0,
        'date': DateTime.now().toIso8601String(),
      });

      final s = cycleStatus(store.data, DateTime.now());
      if (!s.show) return; // A state with no number to show; nothing to check.
      expect(
        s.liquid,
        greaterThanOrEqualTo(s.available),
        reason:
            'Committed is liquid minus available, so liquid below available '
            'would render a negative segment. If these ever come from two '
            'different reads they can drift into exactly that.',
      );
    });

    test('a silent state defaults both to zero rather than to junk', () {
      const s = CycleStatus(show: false, reason: 'quiet');
      expect(s.liquid, 0);
      expect(s.available, 0);
      expect(
        s.liquid > s.available,
        isFalse,
        reason:
            'Home gates the bar on liquid > available. A default that made '
            'that true would draw a bar for a user with no data at all.',
      );
    });
  });

  group('the bar survives the inputs a backup can produce', () {
    testWidgets('a normal split renders both segments and both amounts', (
      tester,
    ) async {
      await tester.pumpWidget(_bar(250, 2810));
      await tester.pumpAndSettle();
      expect(find.text('Committed'), findsOneWidget);
      expect(find.text('Free to spend'), findsOneWidget);
      expect(find.text('₱250'), findsOneWidget);
      expect(find.text('₱2,810'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a zero total does not throw during layout', (tester) async {
      // The division guard. Without it the flex factors are NaN and this
      // throws in performLayout, taking Home down rather than looking odd.
      await tester.pumpWidget(_bar(0, 0));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('non-finite amounts from a junk backup do not throw', (
      tester,
    ) async {
      for (final pair in [
        [double.infinity, 100.0],
        [double.nan, 100.0],
        [100.0, double.nan],
      ]) {
        await tester.pumpWidget(_bar(pair[0], pair[1]));
        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason: 'committed=${pair[0]} free=${pair[1]} took the screen down',
        );
      }
    });

    testWidgets('an all-committed split still leaves a visible sliver', (
      tester,
    ) async {
      // A zero-flex Expanded collapses to nothing, and a bar with one segment
      // missing entirely reads as a rendering bug rather than as "all of it is
      // spoken for". Both segments stay at least one unit wide.
      await tester.pumpWidget(_bar(5000, 0));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('₱0'), findsOneWidget);
    });
  });
}
