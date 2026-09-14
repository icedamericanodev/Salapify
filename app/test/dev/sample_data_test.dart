// The sample data action, and the three things that keep it out of a shipped
// app and away from real money.
//
// The release gate is the one that has to be PROVEN rather than assumed, and
// it is also the one a test cannot reach directly: tests run in debug, so
// `kDebugMode` is always true here and the release path would never execute.
// That is why the widget takes the flag as a parameter defaulting to
// kDebugMode. A default nobody can exercise is a default nobody has checked.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/app/clock.dart';
import 'package:salapify/app/ledger_scope.dart';
import 'package:salapify/core/data/ledger_store.dart';
import 'package:salapify/design/tokens.dart';
import 'package:salapify/dev/sample_data_action.dart';
import 'package:salapify/dev/sample_ledger.dart';
import 'package:salapify/features/home/home_screen.dart';

import '../support/memory_store.dart';

Widget _app(LedgerStore store, Widget child) => LedgerScope(
  store: store,
  child: AppClock(
    now: sampleAnchor,
    child: MaterialApp(
      theme: salapifyTheme(gabi),
      home: Scaffold(body: child),
    ),
  ),
);

void main() {
  group('when it is allowed to appear', () {
    testWidgets('never in a release build', (tester) async {
      // The whole "gone at launch" promise rests on this one line. In a release
      // build kDebugMode is a compile time false, the branch is dead, and the
      // compiler drops the button and the sample ledger with it. Nobody has to
      // remember to delete anything before the store listing, which matters
      // because a step somebody has to remember is a step that gets missed.
      final store = await memoryStore();
      await tester.pumpWidget(
        _app(store, const SampleDataAction(enabled: false)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Load sample data'), findsNothing);
    });

    testWidgets('not once there is anything to overwrite', (tester) async {
      // It can never destroy a ledger, because it is not there when one
      // exists. That takes the whole data loss class off the table rather than
      // guarding it with a dialog somebody can tap through.
      final store = await memoryStore(livedIn());
      await tester.pumpWidget(
        _app(store, const SampleDataAction(enabled: true)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Load sample data'), findsNothing);
    });

    testWidgets('in a debug build, on an empty ledger', (tester) async {
      final store = await memoryStore();
      await tester.pumpWidget(
        _app(store, const SampleDataAction(enabled: true)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Load sample data'), findsOneWidget);
    });
  });

  testWidgets('it fills an empty app with a ledger worth looking at', (
    tester,
  ) async {
    // The point of the whole thing: a first run on an emulator shows the same
    // screen the founder reviews in a screenshot. Before this they were a rich
    // fixture and a completely empty store, and a defect visible in one and not
    // the other had nowhere to be caught. One did reach the emulator that way.
    // The clock AND the data are pinned to the same day. In the app both are
    // the real today and agree by construction; a test that pinned only the
    // clock would compare a September ledger against a real today and fail for
    // a reason that has nothing to do with the code. That is exactly what the
    // first version of this test did.
    final store = await memoryStore();
    await tester.pumpWidget(_app(store, const HomeScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Nothing logged yet'), findsOneWidget);

    await tester.tap(find.text('Load sample data'));
    await tester.pumpAndSettle();

    // The empty state is gone and the real Home is there, with the figure the
    // screenshots show.
    expect(find.text('Nothing logged yet'), findsNothing);
    final said = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .join(' | ');
    expect(said, contains('6,266'));
    expect(said, contains('SAFE TO SPEND'));

    // And it PERSISTED, rather than only living in the widget tree. A sample
    // that vanishes on restart would send somebody hunting for a bug that is
    // not there.
    expect((store.data['accounts'] as List).length, 3);
    expect((store.data['transactions'] as List).length, 7);
  });

  group('the ledger itself', () {
    test('the app gets today, the tests get a fixed day', () {
      // Two callers with genuinely different needs, one definition. A test
      // pinned to a real date passes only on the days somebody ran it; a demo
      // dated last September looks broken on a phone.
      final pinned = sampleLedger(today: sampleAnchor);
      final first = (pinned['transactions'] as List).first as Map;
      expect(first['date'], '2026-09-11');

      final now = DateTime.now();
      final live = sampleLedger();
      final liveFirst = (live['transactions'] as List).first as Map;
      final expected =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-'
          '${now.day.toString().padLeft(2, '0')}';
      expect(liveFirst['date'], expected);
    });

    test('a recurring bill never lands on a day that does not exist', () {
      // A recurring bill is a DAY OF THE MONTH, so taking today + 2 near a
      // month end would put it past 31 and the row becomes unreachable. Checked
      // across a whole year rather than on one convenient date.
      for (var month = 1; month <= 12; month++) {
        final last = DateTime(2026, month + 1, 0).day;
        for (final day in [1, 15, 27, 28, last - 1, last]) {
          final data = sampleLedger(today: DateTime(2026, month, day));
          for (final r in (data['recurring'] as List)) {
            final d = (r as Map)['dayOfMonth'] as int;
            expect(
              d,
              inInclusiveRange(1, 28),
              reason:
                  'a bill on day $d cannot happen in every month, from '
                  '2026-$month-$day',
            );
          }
        }
      }
    });
  });
}
