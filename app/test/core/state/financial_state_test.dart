// One financial truth, and the cross-screen test that proves it.
//
// The defect this guards against is not a wrong number. It is TWO numbers, each
// correct on its own terms, answering the same question differently on two
// screens. On 2026-09-14 Home said "₱1,566.63 a day until payday" and Plan said
// "₱697.73 a day for the 20 days left this month", from the same ledger at the
// same moment. Home divided by days to the next PAYDAY, Plan by days to
// CALENDAR MONTH END.
//
// No unit test could catch that, because there was nothing wrong to catch in
// either file. The only test that can see it is one that puts BOTH screens in
// front of the SAME store and reads what they say, which is what the second
// group below does. The founder's brief calls this out in its section 5 and it
// was already true in our own screenshots.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/app/clock.dart';
import 'package:salapify/app/ledger_scope.dart';
import 'package:salapify/app/router.dart';
import 'package:salapify/core/data/ledger_store.dart';
import 'package:salapify/core/state/financial_state.dart';
import 'package:salapify/design/kit.dart';
import 'package:salapify/design/tokens.dart';

import '../../support/memory_store.dart';

final _now = DateTime(2026, 9, 11, 9, 30);

Widget _app(LedgerStore store, DateTime now) => LedgerScope(
  store: store,
  child: AppClock(
    now: now,
    child: MaterialApp.router(
      theme: salapifyTheme(gabi),
      routerConfig: buildRouter(),
    ),
  ),
);

/// Every peso-per-day phrase anywhere in the widget tree.
List<String> _paceSentences(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((t) => t.data ?? '')
    .where((s) => s.contains('a day'))
    .toList();

void main() {
  group('the cycle is defined once', () {
    test('it comes from the ENGINE, not from a second derivation', () {
      final s = FinancialState.of(livedIn(), _now);

      // Sep 11, semimonthly on the 15th and 30th.
      expect(s.cycle.end, DateTime(2026, 9, 15));
      expect(s.cycle.start, DateTime(2026, 8, 30));
      expect(s.cycle.daysLeft, 4);
      expect(s.cycle.explicit, isTrue);
    });

    test('on payday itself the cycle has begun, not ended', () {
      // `nextPayday` returns TODAY when today is a payday, while the engine's
      // daysLeft has already skipped to the next one. Re-deriving the end date
      // instead of reading the engine's put "payday on Tuesday" above "15 days
      // to payday" on one panel, over a rail claiming a cycle from Sep 15 to
      // Sep 15.
      final s = FinancialState.of(livedIn(), DateTime(2026, 9, 15, 9));

      expect(s.cycle.end, DateTime(2026, 9, 30));
      expect(
        s.cycle.elapsedFraction(DateTime(2026, 9, 15, 9)),
        0.0,
        reason: 'a cycle that has just begun cannot be spent',
      );
    });

    test('a guessed payday is never reported as a set one', () {
      final data = livedIn()..remove('settings');
      expect(FinancialState.of(data, _now).cycle.explicit, isFalse);
    });

    test('it never divides by zero, whatever the schedule', () {
      for (final mode in [
        {'mode': 'weekly', 'weekday': 5},
        {'mode': 'monthly', 'day': 30},
        {
          'mode': 'semimonthly',
          'days': [15, 30],
        },
      ]) {
        for (var day = 1; day <= 28; day++) {
          final data = livedIn()..['settings'] = {'paydaySchedule': mode};
          final s = FinancialState.of(data, DateTime(2026, 9, day, 9));
          expect(s.cycle.span, greaterThan(0));
          expect(s.cycle.daysLeft, greaterThan(0));
          final f = s.cycle.elapsedFraction(DateTime(2026, 9, day, 9));
          expect(f, inInclusiveRange(0.0, 1.0));
        }
      }
    });
  });

  group('two screens, one store, no contradiction', () {
    testWidgets('the app states exactly ONE daily pace, anywhere', (
      tester,
    ) async {
      final store = await memoryStore(livedIn());
      await tester.pumpWidget(_app(store, _now));
      await tester.pumpAndSettle();

      // Home.
      final onHome = _paceSentences(tester);
      expect(onHome, hasLength(1));
      expect(onHome.single, contains('until payday'));

      // Plan, same store, same moment.
      await tester.tap(
        find.descendant(of: find.byType(NavBar), matching: find.text('Plan')),
      );
      await tester.pumpAndSettle();

      expect(
        _paceSentences(tester),
        isEmpty,
        reason:
            'Plan is stating a daily pace again. The app has exactly one, on '
            'Home, over the payday cycle. A second one computed over the '
            'calendar month can never agree with it, and both will look '
            'correct in their own file.',
      );
    });

    testWidgets('both screens name the same payday', (tester) async {
      final store = await memoryStore(livedIn());
      await tester.pumpWidget(_app(store, _now));
      await tester.pumpAndSettle();

      expect(
        tester
            .widgetList<Text>(find.byType(Text))
            .map((t) => t.data ?? '')
            .join(' | '),
        contains('Aug 30 to Sep 15'),
      );

      await tester.tap(
        find.descendant(of: find.byType(NavBar), matching: find.text('Plan')),
      );
      await tester.pumpAndSettle();

      // Plan answers a different QUESTION (am I within my monthly limit) but it
      // must describe the same PERIOD, or the two screens are again describing
      // two different months to the same person.
      expect(
        tester
            .widgetList<Text>(find.byType(Text))
            .map((t) => t.data ?? '')
            .join(' | '),
        contains('payday on Sep 15'),
      );
    });
  });
}
