// Goals: the rows, the sentences, and the two write paths.
//
// THE ONE THING THIS FILE EXISTS TO PIN. A goal's money is a NUMBER THE USER
// TRACKS, not a balance. The 12,000 saved toward an emergency fund is already
// sitting in BPI, counted once there in net worth and in safe to spend, and
// described a second time as progress. So adding to a goal must move NOTHING:
// no account balance, no net worth, no safe to spend.
//
// That is the failure mode worth a test rather than a comment. Every envelope
// app a Filipino user has touched moves money between pots, so the obvious
// "improvement" to this feature, at any point in its future, is to make Add
// money debit an account. Doing that would subtract the same peso twice, and
// it would look right on the goal screen while quietly lowering net worth.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/app/clock.dart';
import 'package:salapify/app/ledger_scope.dart';
import 'package:salapify/app/router.dart';
import 'package:salapify/core/data/ledger_store.dart';
import 'package:salapify/core/money/ledger.dart' show amountOf;
import 'package:salapify/core/money/statements.dart' show netWorthParts;
import 'package:salapify/core/state/financial_state.dart';
import 'package:salapify/design/kit.dart';
import 'package:salapify/design/tokens.dart';
import 'package:salapify/dev/sample_ledger.dart' show sampleAnchor;
import 'package:salapify/features/plan/goal_rows.dart';

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

/// Walk to Plan and switch to the Goals segment, by tapping.
Future<void> _openGoals(WidgetTester tester, LedgerStore store) async {
  await tester.pumpWidget(_app(store));
  await tester.pumpAndSettle();
  await tester.tap(
    find.descendant(of: find.byType(NavBar), matching: find.text('Plan')),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Goals'));
  await tester.pumpAndSettle();
}

/// Scroll the tab screen until [what] is on screen AND tappable.
///
/// `Screen` leaves 130 of bottom padding for the nav bar, and the test
/// viewport is 600 tall, so a control near the end of Plan sits underneath the
/// bar: found by the finder, and refused by the hit test with "derived an
/// Offset that would not hit test on the specified widget". That warning is
/// easy to read as the control being broken when it is only out of reach.
Future<void> _scrollTo(WidgetTester tester, Finder what) async {
  await tester.scrollUntilVisible(
    what,
    120,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

double _netWorth(Map<String, dynamic> d) =>
    amountOf(netWorthParts(d)['netWorth']);

Map<String, dynamic> _goal(Map<String, dynamic> d, String id) =>
    (d['goals'] as List).firstWhere((g) => g['id'] == id)
        as Map<String, dynamic>;

void main() {
  group('the rows say what the engine says, and nothing more', () {
    test('every fixture goal comes through with its own state', () {
      // Three goals, three DIFFERENT states, because a fixture of three
      // healthy goals photographs one row three times and proves nothing
      // about the two states the screen actually has to handle.
      final rows = goalRows(livedIn(), sampleAnchor);
      expect(rows, hasLength(3));

      final reached = rows.firstWhere((r) => r.id == 'g_phone');
      expect(reached.reached, isTrue);
      expect(reached.fraction, 1.0);
      expect(reached.remaining, 0);

      final open = rows.firstWhere((r) => r.id == 'g_emergency');
      expect(open.reached, isFalse);
      expect(open.remaining, greaterThan(0));
      expect(
        open.perPeriod,
        greaterThan(0),
        reason:
            'a goal with a future date and a gap asks for nothing a month, '
            'so the row has no pace to show',
      );
    });

    test('the bar and the caption cannot tell different stories', () {
      // Both come from goalPace's own pct and remaining. If a screen ever
      // derives one of them itself, this is what goes red.
      for (final r in goalRows(livedIn(), sampleAnchor)) {
        expect(r.fraction, inInclusiveRange(0.0, 1.0));
        if (r.reached) expect(r.fraction, 1.0);
        if (r.fraction < 1.0) expect(r.remaining, greaterThan(0));
      }
    });
  });

  group('the caption, which is where a wrong sentence hides', () {
    test('a reached goal says what was SAVED, never the remaining zero', () {
      // The settled debt row shipped showing PHP0 for exactly this reason:
      // remaining is zero by definition once it is done, so a caption built
      // on it reads as an empty goal rather than a finished one.
      final reached = goalRows(
        livedIn(),
        sampleAnchor,
      ).firstWhere((r) => r.id == 'g_phone');
      final caption = goalRowCaption(reached);

      expect(caption, contains('Reached'));
      expect(
        caption,
        isNot(contains('0.00')),
        reason: 'a finished goal reports zero, which reads as an empty one',
      );
    });

    test('a paused goal is not quoted a monthly figure', () {
      // Quoting a pace at somebody who deliberately stopped is a scold
      // dressed as information.
      final d = livedIn();
      _goal(d, 'g_emergency')['paused'] = true;
      final row = goalRows(d, sampleAnchor).firstWhere(
        (r) => r.id == 'g_emergency',
      );

      expect(row.paused, isTrue);
      expect(goalRowCaption(row), contains('Paused'));
      expect(goalRowCaption(row), isNot(contains('a month')));
    });

    test('a goal with NO date says so instead of inventing a pace', () {
      final d = livedIn();
      _goal(d, 'g_emergency')['targetDate'] = '';
      final row = goalRows(d, sampleAnchor).firstWhere(
        (r) => r.id == 'g_emergency',
      );

      expect(row.hasDeadline, isFalse);
      expect(goalRowCaption(row), contains('no date set'));
      expect(
        goalRowCaption(row),
        isNot(contains('a month')),
        reason:
            'a goal with no deadline is quoted a monthly amount, which is a '
            'figure the engine did not produce',
      );
    });

    test('a stored date is never shown the way it is stored', () {
      // screen_readability's rule, seen from the other side. "2027-06-30" on
      // a savings screen is a database field, not a date somebody reads.
      expect(prettyTargetDate('2027-06-30'), 'Jun 30, 2027');

      // A MONTH-ONLY value stays month-only. goalPace clamps it to the last
      // day for ARITHMETIC, and printing that day back would invent a
      // deadline the user never picked.
      expect(prettyTargetDate('2027-06'), 'Jun 2027');
      expect(prettyTargetDate(''), '');
      expect(prettyTargetDate('garbage'), '');
    });

    test('the summary counts only what is actually being asked for', () {
      final rows = goalRows(livedIn(), sampleAnchor);
      final summary = goalsSummary(rows);
      expect(summary, contains('a month'));

      // Reached and paused goals ask for nothing, so folding either into the
      // total would overstate what the user has committed to.
      final d = livedIn();
      for (final g in (d['goals'] as List)) {
        (g as Map)['paused'] = true;
      }
      expect(
        goalsSummary(goalRows(d, sampleAnchor)),
        'Nothing to put aside this month.',
      );

      expect(goalsSummary(const []), '');
    });
  });

  group('a goal moves no money, which is the whole contract', () {
    testWidgets('adding to a goal changes NOTHING about your accounts', (
      tester,
    ) async {
      final store = await memoryStore(livedIn());
      final worthBefore = _netWorth(store.data);
      final liquidBefore = FinancialState.of(store.data, sampleAnchor).liquid;
      final savedBefore = amountOf(_goal(store.data, 'g_emergency')['saved']);

      await _openGoals(tester, store);
      await tester.tap(find.text('Emergency fund'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(PillButton, 'Add money'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '2500');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(PillButton, 'Add it'));
      await tester.pumpAndSettle();

      // DID ANYTHING HAPPEN. Without this the three invariants below all hold
      // perfectly when the button does nothing at all, which is the failure
      // mode that passes hardest when the feature is most broken.
      expect(
        amountOf(_goal(store.data, 'g_emergency')['saved']),
        savedBefore + 2500,
        reason: 'the money was not added to the goal',
      );

      // THE CONTRACT. A goal is an intention about money you already have.
      expect(
        _netWorth(store.data),
        worthBefore,
        reason:
            'saving toward a goal changed net worth, so the same peso is now '
            'counted as a bank balance AND as a goal',
      );
      expect(
        FinancialState.of(store.data, sampleAnchor).liquid,
        liquidBefore,
        reason:
            'saving toward a goal took money out of safe to spend, so the '
            'app has quietly debited an account that never moved',
      );
      expect(
        (store.data['accounts'] as List).map((a) => amountOf(a['balance'])),
        (livedIn()['accounts'] as List).map((a) => amountOf(a['balance'])),
        reason: 'an account balance moved because of a goal',
      );
    });

    testWidgets('and it leaves a dated record of what was put in', (
      tester,
    ) async {
      // A write path is not tested until somebody can follow it. The
      // contribution row is the only thing that can ever answer "when did I
      // put that in", and the shipped app writes one for the same reason.
      final store = await memoryStore(livedIn());
      await _openGoals(tester, store);
      await tester.tap(find.text('Emergency fund'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(PillButton, 'Add money'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '1000');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(PillButton, 'Add it'));
      await tester.pumpAndSettle();

      final contributions =
          _goal(store.data, 'g_emergency')['contributions'] as List;
      expect(contributions, hasLength(1));
      expect(amountOf(contributions.first['amount']), 1000);
      expect(
        contributions.first['date'],
        '2026-09-11',
        reason: 'the contribution carries no usable date',
      );
    });

    testWidgets('the sheet SAYS it does not move money', (tester) async {
      // Somebody who has used any envelope app expects this to debit an
      // account. Discovering later, from a balance that did not change, that
      // it never did reads as the app being broken.
      final store = await memoryStore(livedIn());
      await _openGoals(tester, store);
      await tester.tap(find.text('Emergency fund'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(PillButton, 'Add money'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('does not move money between your accounts'),
        findsOneWidget,
        reason:
            'nothing tells the user their balances will not change, so the '
            'first thing they do is check an account and find it untouched',
      );
    });
  });

  group('you can make one, and find it afterwards', () {
    testWidgets('a new goal is on the screen when the sheet closes', (
      tester,
    ) async {
      final store = await memoryStore(livedIn());
      await _openGoals(tester, store);

      await _scrollTo(tester, find.widgetWithText(PillButton, 'Add a goal'));
      await tester.tap(find.widgetWithText(PillButton, 'Add a goal'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Trip home');
      await tester.enterText(find.byType(TextField).at(1), '18000');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(PillButton, 'Save goal'));
      await tester.pumpAndSettle();

      expect(
        find.text('Trip home'),
        findsOneWidget,
        reason: 'the goal saved and the list did not show it',
      );
      expect((store.data['goals'] as List), hasLength(4));
    });

    testWidgets('Save is refused until the goal can actually be paced', (
      tester,
    ) async {
      // A goal with no target has status 'no-target' in the engine, which
      // means no bar, no pace and no sentence: a row that can never say
      // anything. Better to not let it exist than to list it as a puzzle.
      final store = await memoryStore(livedIn());
      await _openGoals(tester, store);
      await _scrollTo(tester, find.widgetWithText(PillButton, 'Add a goal'));
      await tester.tap(find.widgetWithText(PillButton, 'Add a goal'));
      await tester.pumpAndSettle();

      final save = tester.widget<PillButton>(
        find.widgetWithText(PillButton, 'Save goal'),
      );
      expect(
        save.onTap,
        isNull,
        reason: 'an empty form can be saved, producing a goal with no target',
      );

      await tester.enterText(find.byType(TextField).first, 'Something');
      await tester.enterText(find.byType(TextField).at(1), '0');
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<PillButton>(find.widgetWithText(PillButton, 'Save goal'))
            .onTap,
        isNull,
        reason: 'a target of zero is accepted, and it can never be paced',
      );
    });

    testWidgets('editing a goal keeps the money already put into it', (
      tester,
    ) async {
      // SPREAD, never replace. A stored goal carries fields the sheet does not
      // edit, `contributions` above all, and rebuilding the map from the form
      // would delete the user's whole funding history on a rename.
      final d = livedIn();
      _goal(d, 'g_laptop')['contributions'] = [
        {'id': 'c1', 'amount': 41000.0, 'date': '2026-08-01'},
      ];
      final store = await memoryStore(d);

      await _openGoals(tester, store);
      await tester.tap(find.text('New laptop'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit this goal'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Work laptop');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(PillButton, 'Save goal'));
      await tester.pumpAndSettle();

      final goal = _goal(store.data, 'g_laptop');
      expect(goal['name'], 'Work laptop');
      expect(
        amountOf(goal['saved']),
        41000,
        reason: 'a rename wiped the money already saved',
      );
      expect(
        goal['contributions'],
        hasLength(1),
        reason: 'a rename wiped the funding history, which has no undo',
      );
    });

    testWidgets('pausing is reachable and reversible from the same place', (
      tester,
    ) async {
      final store = await memoryStore(livedIn());
      await _openGoals(tester, store);

      await tester.tap(find.text('Emergency fund'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pause this goal'));
      await tester.pumpAndSettle();
      expect(_goal(store.data, 'g_emergency')['paused'], isTrue);

      await tester.tap(find.text('Emergency fund'));
      await tester.pumpAndSettle();
      expect(
        find.text('Resume this goal'),
        findsOneWidget,
        reason:
            'a paused goal offers no way back, so pausing is a one way door',
      );
      await tester.tap(find.text('Resume this goal'));
      await tester.pumpAndSettle();
      expect(_goal(store.data, 'g_emergency')['paused'], isFalse);
    });
  });

  group('the empty state can be acted on', () {
    testWidgets('a ledger with no goals offers a way to make one', (
      tester,
    ) async {
      // An empty state whose instruction cannot be followed is the defect this
      // app has already shipped twice, on Accounts and on Budget.
      final d = livedIn();
      d.remove('goals');
      await _openGoals(tester, await memoryStore(d));

      expect(find.text('Nothing saved for yet'), findsOneWidget);
      expect(
        find.widgetWithText(PillButton, 'Add your first goal'),
        findsOneWidget,
      );
    });
  });
}
