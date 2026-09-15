// Upcoming, and the one thing that must never be true about it.
//
// Home already answers "what is due before THIS payday" from
// `upcomingCommitments`. Upcoming answers "what is coming out to the payday
// AFTER next" from `sweldoTimeline`. Two engines, two windows, one ledger.
//
// That is precisely the shape of the defect this app has already had to fix
// once: Home said 1,566.63 a day and Plan said 697.73 a day, both correct on
// their own terms, neither wrong, and no test caught it because no test had
// ever put the two screens in front of the same store. So the first test in
// this file is not about Upcoming at all. It is about the two screens agreeing.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/app/clock.dart';
import 'package:salapify/app/ledger_scope.dart';
import 'package:salapify/app/router.dart';
import 'package:salapify/core/data/ledger_store.dart';
import 'package:salapify/core/money/commitments.dart' show upcomingCommitments;
import 'package:salapify/core/money/ledger.dart' show amountOf;
import 'package:salapify/design/kit.dart';
import 'package:salapify/design/tokens.dart';
import 'package:salapify/dev/sample_ledger.dart';
import 'package:salapify/features/plan/upcoming_rows.dart';

import '../support/memory_store.dart';

Widget _app(LedgerStore store) => LedgerScope(
  store: store,
  child: AppClock(
    now: sampleAnchor,
    child: MaterialApp.router(
      theme: salapifyTheme(gabi),
      routerConfig: buildRouter(),
    ),
  ),
);

void main() {
  group('Home and Upcoming cannot disagree about a bill', () {
    test('every bill Home names appears in Upcoming, same date, same peso', () {
      final data = livedIn();
      final home = upcomingCommitments(data, sampleAnchor);
      final up = upcomingFrom(data, sampleAnchor);

      final bills = [
        for (final b in (home['bills'] as List)) (b as Map).cast<String, dynamic>(),
      ];

      // Did anything happen at all. An agreement test over two empty lists
      // agrees perfectly and proves nothing, which is the failure mode the
      // journey rules call out by name.
      expect(
        bills,
        isNotEmpty,
        reason:
            'the fixture has no bills before payday, so this test would pass '
            'with both screens broken',
      );

      for (final b in bills) {
        final date = (b['date'] ?? '').toString();
        final name = (b['name'] ?? '').toString();
        final amount = amountOf(b['amount']);

        final day = up.days.where((d) => d.date == date);
        expect(
          day,
          isNotEmpty,
          reason:
              'Home says "$name" is due on $date and Upcoming has no such day '
              'at all, so the two screens describe different months',
        );

        final match = day.first.events.where(
          (e) => e.label == name && (e.amount - amount).abs() < 0.005,
        );
        expect(
          match,
          isNotEmpty,
          reason:
              'Home says "$name" costs $amount on $date. Upcoming has that day '
              'but not that figure: '
              '${day.first.events.map((e) => '${e.label} ${e.amount}').toList()}',
        );
      }
    });

    test('and Upcoming reaches FURTHER than Home, which is its whole job', () {
      final data = livedIn();
      final home = upcomingCommitments(data, sampleAnchor);
      final up = upcomingFrom(data, sampleAnchor);

      final homePayday = (home['payday'] ?? '').toString();
      expect(homePayday, isNotEmpty);

      // The horizon must cross the next payday, or this screen is Home with a
      // different title.
      final last = up.days.isEmpty ? '' : up.days.last.date;
      expect(
        up.horizonDays,
        greaterThan(amountOf(home['daysLeft']).toInt()),
        reason:
            'Upcoming stopped at the same payday Home does, so it answers the '
            'question Home already answered (last day it holds: $last)',
      );
    });
  });

  group('the list itself', () {
    test('a day with nothing on it is not a row', () {
      final up = upcomingFrom(livedIn(), sampleAnchor);
      for (final d in up.days) {
        expect(
          d.events.isNotEmpty || d.isPayday,
          isTrue,
          reason:
              'an empty day earned a row, which turns the screen into a '
              'calendar of blanks',
        );
      }
    });

    test('payday is marked, and it is money coming IN', () {
      final up = upcomingFrom(livedIn(), sampleAnchor);
      final paydays = up.days.where((d) => d.isPayday);
      expect(
        paydays,
        isNotEmpty,
        reason: 'the window did not contain a single payday, so the horizon '
            'is wrong',
      );
      expect(
        paydays.any((d) => d.moneyIn > 0),
        isTrue,
        reason:
            'every payday in the window showed no money arriving, which would '
            'draw a green row with nothing green about it',
      );
    });

    test('the day you RUN OUT is not the day you are lowest', () {
      // The sentence a person actually acts on named the wrong day. Dip under
      // on the 13th, keep sinking to the minimum on the 25th, and the first
      // version said "your money runs out around the 25th": twelve days late,
      // and "around" does not cover twelve days. The right value was sitting
      // unread in the engine's own return map the whole time.
      //
      // A ledger built to make the two dates differ: thin cash, a bill that
      // takes it under, then a bigger bill that takes it lower still.
      final data = livedIn();
      data['accounts'] = [
        {'id': 'a_cash', 'name': 'Cash', 'kind': 'cash', 'balance': 1000.0},
      ];
      data['debts'] = const [];
      data['recurring'] = [
        {
          'id': 'rc_small',
          'type': 'expense',
          'label': 'Small bill',
          'amount': 1500.0,
          'dayOfMonth': 12,
        },
        {
          'id': 'rc_big',
          'type': 'expense',
          'label': 'Big bill',
          'amount': 9000.0,
          'dayOfMonth': 20,
        },
      ];

      final up = upcomingFrom(data, sampleAnchor);

      expect(up.goesNegative, isTrue);
      expect(
        up.firstNegativeDate,
        '2026-09-12',
        reason: 'the day the balance first went under was not reported',
      );
      expect(
        up.lowestDate,
        isNot(up.firstNegativeDate),
        reason:
            'this fixture was built so the two dates differ; if they are the '
            'same the test can no longer tell a fix from the bug',
      );
      expect(
        up.lowestDate.compareTo(up.firstNegativeDate),
        greaterThan(0),
        reason: 'the lowest day should fall AFTER the first negative day here',
      );
    });

    test('no schedule falls back to a window, never to nothing', () {
      // An empty ledger has no payday set. Returning zero days would render
      // "nothing is coming", which is a different statement from "we do not
      // know when you get paid" and is the more dangerous of the two.
      final horizon = upcomingHorizonDays(<String, dynamic>{}, sampleAnchor);
      expect(horizon, greaterThan(0));
    });

    test('and that window is NOT measured from a guessed payday', () {
      // `normalizeSchedule` invents {semimonthly, [15, 31]} when handed null,
      // so calling nextPayday without checking produces a horizon derived from
      // a payday the user never described. The kicker then says "NEXT 19 DAYS"
      // where the 19 came from an invention, and `_paydaysInWindow` correctly
      // refuses to draw any payday row that would explain it.
      final noSchedule = upcomingHorizonDays(<String, dynamic>{}, sampleAnchor);
      expect(
        noSchedule,
        30,
        reason:
            'the window length came from a payday Salapify made up, which is '
            'the one thing Home goes out of its way never to do',
      );

      // And a real schedule still drives a real horizon, or the guard above
      // would pass by making the feature do nothing.
      final withSchedule = upcomingHorizonDays(livedIn(), sampleAnchor);
      expect(withSchedule, isNot(30));
      expect(withSchedule, greaterThan(0));
    });
  });

  group('on the screen', () {
    testWidgets('the Upcoming segment shows the bills, not a promise', (
      tester,
    ) async {
      final store = await memoryStore(livedIn());
      await tester.pumpWidget(_app(store));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(of: find.byType(NavBar), matching: find.text('Plan')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Upcoming'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Upcoming is next'),
        findsNothing,
        reason: 'the placeholder is still there, so nothing was built',
      );

      // Something from the real ledger, reached by tapping rather than by
      // calling the derivation: a test that only checks the function can pass
      // while the segment renders nothing at all.
      final up = upcomingFrom(store.data, sampleAnchor);
      expect(up.days, isNotEmpty);
      final firstLabel = up.days
          .firstWhere((d) => d.events.isNotEmpty)
          .events
          .first
          .label;
      expect(
        find.text(firstLabel),
        findsWidgets,
        reason:
            'the derivation has rows and the screen drew none of them, so the '
            'segment is wired to nothing',
      );
    });
  });
}
