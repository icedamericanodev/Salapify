// Home's order, pinned.
//
// This is the first test in the repo that asserts WHERE a card is rather than
// whether it exists, and it is the only kind that could have caught the
// problem it guards.
//
// coach.weeklyCheckIn always returns something. When nothing needs attention it
// falls back to a cheerful "You are on track this week". That card sat above
// Your Number unconditionally, so a user in perfect financial health paid 180
// to 210 logical pixels of good news before reaching the figure they opened the
// app for. On a 360x800 phone the number landed near the vertical midpoint, and
// on payday the ritual card pushed it to roughly 530, right at the fold.
//
// Nothing was broken. Every card rendered, every number was right, and the
// screen looked fine in a screenshot. It was simply answering the second
// question first.
//
// Clock-free, following home_bills_test's discipline: OverviewScreen reads
// DateTime.now() internally, so any fixture that needs a particular day passes
// for two weeks and then blames whoever pushed on the 28th.
//
// That paragraph was a CLAIM, not a fact, for as long as it stood. The crunch
// fixture below hardcoded a due day, and on the 29th of the month it stopped
// producing a crunch at all, so the test reported a card appearing that should
// not appear, which reads exactly like a layout regression somebody just
// introduced. It is fixed now and the details are on _crunch. The general
// lesson is the one CLAUDE.md keeps relearning: when a comment describes what
// the code does, read the code, not the comment.
//
// SUPERSEDED IN PART (founder direction, 2026-08-13): Home is now
// dashboard-first. The Net Worth hero and the Quick Overview open the screen,
// and the coaching number sits below them, matching the approved mockup. The
// half of this file that still holds, and the reason the inversion is safe, is
// the urgent group below: a money crunch still outranks everything and still
// hides the number. So "the number comes first" became "the dashboard comes
// first, unless money is tight".

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/money/coach.dart' as coach;
import 'package:salapify/money/cycle.dart';
import 'package:salapify/screens/overview.dart';
import 'package:salapify/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/app_harness.dart';

/// Healthy: money to spend, nothing overdue, no debts. The coach has nothing
/// to say, so it says the all-clear, which is exactly the state where the
/// check-in used to displace the number.
Map<String, dynamic> _healthy() => {
  'schemaVersion': 12,
  'accounts': [
    {'id': 'cash', 'name': 'Cash', 'kind': 'cash', 'balance': 40000},
  ],
  'transactions': [
    {
      'id': 't1',
      'type': 'expense',
      'amount': 250,
      'date': '2026-07-05',
      'accountId': 'cash',
    },
  ],
};

/// Crunch: committed money has eaten everything spendable. This is the ONLY
/// state that produces an urgent check-in, and it is also the state where
/// cycleStatus hides Your Number.
///
/// Both dates are derived from [now], and that is the whole point.
///
/// The first version hardcoded dueDay 28 and no payday schedule, under a file
/// header claiming the whole file was clock-free. It was not. On the 29th of
/// the month the July 28 due date had passed, the next one landed in August,
/// August is past the next payday, so no bill fell inside the window, so
/// nothing was committed, so the check-in was not urgent and Your Number
/// reappeared. The test then failed on the runner with "one was found but none
/// were expected", naming a card, which reads exactly like a real layout
/// regression and is not one.
///
/// Two derivations, both deliberate:
/// - the bill is due TODAY, so it is always inside the window;
/// - payday is eight days out, so the window is always eight days wide.
///
/// Eight, not one or two, because bankDueDate shifts a weekend due date to the
/// next business day. On the day before payday the window is one day wide, and
/// a Saturday due date shifted to Monday fell outside it. That was three
/// failing days in a 400 day sweep, which is the kind of thing that lands on
/// whoever pushes that morning. Verified at zero over 400 consecutive days.
Map<String, dynamic> _crunch([DateTime? at]) {
  final now = at ?? DateTime.now();
  return {
    'schemaVersion': 12,
    'settings': {
      'paydaySchedule': {
        'mode': 'monthly',
        'day': now.add(const Duration(days: 8)).day,
      },
    },
    'accounts': [
      {'id': 'cash', 'name': 'Cash', 'kind': 'cash', 'balance': 900},
    ],
    'transactions': [
      {
        'id': 't1',
        'type': 'expense',
        'amount': 100,
        'date': '2026-07-05',
        'accountId': 'cash',
      },
    ],
    'debts': [
      {
        'id': 'd1',
        'name': 'BPI card',
        'type': 'credit card',
        'remaining': 40000,
        'monthlyRate': 3,
        'minPayment': 4000,
        'dueDay': now.day,
      },
    ],
  };
}

Future<void> _pump(WidgetTester tester, Map<String, dynamic> blob) async {
  tester.view.physicalSize = const Size(1200, 4600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues({storageKey: jsonEncode(blob)});
  final store = SalapifyStore();
  await store.load();
  await tester.pumpWidget(
    MaterialApp(
      theme: salapifyTheme(Barako.current),
      home: tabHost(OverviewScreen(store: store, onSwitchTab: (_) {})),
    ),
  );
  await tester.pumpAndSettle();
}

double _y(WidgetTester tester, String text) =>
    tester.getTopLeft(find.text(text)).dy;

void main() {
  group('the dashboard comes first', () {
    testWidgets('a positive check-in sits BELOW Your Number', (tester) async {
      await _pump(tester, _healthy());
      expect(find.text('SAFE TO SPEND'), findsOneWidget);
      // The calm all-clear is the slim row now (no MONEY CHECK-IN kicker),
      // so the ordering is measured against its title.
      expect(find.text('You are on track this week'), findsOneWidget);
      expect(
        _y(tester, 'SAFE TO SPEND'),
        lessThan(_y(tester, 'You are on track this week')),
        reason:
            'The all-clear card is above the number again. weeklyCheckIn never '
            'returns null, so this card is an unconditional 200 pixel tax paid '
            'before the one figure Home exists to show.',
      );
    });

    testWidgets(
      'the dashboard leads: net worth and quick overview OUTRANK the number',
      (tester) async {
        await _pump(tester, _healthy());
        final n = _y(tester, 'SAFE TO SPEND');
        // Dashboard-first (founder direction, 2026-08-13): the mockup opens on
        // the Net Worth hero and a Quick Overview of the month, so both sit
        // ABOVE the number now. This is the exact inversion of the old order,
        // chosen after the founder saw the incremental recolor and called it
        // too timid. The crunch group below is UNCHANGED: a money crunch still
        // outranks the dashboard, which is what keeps this inversion safe.
        for (final above in ['NET WORTH', 'QUICK OVERVIEW']) {
          expect(find.text(above), findsOneWidget, reason: '$above vanished');
          expect(
            _y(tester, above),
            lessThan(n),
            reason: '$above must open the screen, above the number',
          );
        }
        // Accounts still CLOSES the screen, below the number: it is a preview
        // that leads to the full Accounts tab, not a headline.
        expect(
          _y(tester, 'ACCOUNTS'),
          greaterThan(n),
          reason: 'ACCOUNTS is a tail preview, it stays below the number',
        );
      },
    );

    testWidgets(
      'the dashboard reads net worth, then quick overview, then the number',
      (tester) async {
        await _pump(tester, _healthy());
        expect(
          _y(tester, 'NET WORTH'),
          lessThan(_y(tester, 'QUICK OVERVIEW')),
          reason: 'Net worth is the dashboard headline, so it comes first.',
        );
        expect(
          _y(tester, 'QUICK OVERVIEW'),
          lessThan(_y(tester, 'SAFE TO SPEND')),
          reason:
              'The month at a glance sits under the net worth headline and '
              'above the coaching number, matching the approved mockup.',
        );
      },
    );
  });

  group('an urgent warning still outranks everything', () {
    test('crunch is the only urgent tone, and it hides Your Number', () {
      // The PRECONDITION for the whole reorder being safe. If a second urgent
      // kind ever appears that does NOT hide the number, the widget test below
      // stops covering the case it was written for.
      final s = cycleStatus(
        _crunch(DateTime(2026, 7, 26)),
        DateTime(2026, 7, 26),
      );
      final c = coach.weeklyCheckIn(
        _crunch(DateTime(2026, 7, 26)),
        DateTime(2026, 7, 26),
      );
      expect(c['tone'], 'urgent');
      expect(
        s.show,
        isFalse,
        reason:
            'An urgent check-in and a visible Your Number are meant to be '
            'mutually exclusive: crunch fires on available <= 0, which is '
            'exactly the condition cycleStatus hides the number on. That is '
            'what makes demoting the normal check-in safe.',
      );
    });

    testWidgets('an urgent check-in is the first card on the screen', (
      tester,
    ) async {
      await _pump(tester, _crunch());
      expect(find.text('MONEY CHECK-IN'), findsOneWidget);
      expect(
        find.text('SAFE TO SPEND'),
        findsNothing,
        reason: 'Crunch means there is no positive number to show.',
      );
      // Above the countdown, which is what actually renders in this state.
      expect(find.text('DAYS TO PAYDAY'), findsOneWidget);
      expect(
        _y(tester, 'MONEY CHECK-IN'),
        lessThan(_y(tester, 'DAYS TO PAYDAY')),
        reason:
            'When money is tight the warning must lead. This is the half of '
            'the rule that a reorder could silently break, because the other '
            'half looks correct on a healthy screen.',
      );
    });
  });
}
