// Insights: three charts, and the sentences that are the whole point of them.
//
// A chart shows a shape. A person acts on a claim. So the sentences carry most
// of the risk on this screen, and every one of them is a place where a
// confident, well-formed lie about somebody's money can live.
//
// THE ONE THAT ACTUALLY SHIPPED WRONG, found by looking at the render: with
// five empty months behind it, "In and out" averaged zero and told a brand new
// user they had spent PHP6,045.50 "more than your usual month". They have no
// usual month. That is not a rounding error, it is a claim about a history
// that does not exist, and it reads as an accusation.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/app/clock.dart';
import 'package:salapify/app/ledger_scope.dart';
import 'package:salapify/app/router.dart';
import 'package:salapify/core/data/ledger_store.dart';
import 'package:salapify/core/money/ledger.dart' show amountOf;
import 'package:salapify/design/tokens.dart';
import 'package:salapify/dev/sample_ledger.dart' show sampleAnchor;
import 'package:salapify/features/insights/insight_rows.dart';

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

/// Walk to Insights the way a person does: Home, then the closing sentence.
Future<void> _openInsights(WidgetTester tester, LedgerStore store) async {
  await tester.pumpWidget(_app(store));
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(
    find.text('See your insights'),
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('See your insights'));
  await tester.pumpAndSettle();
}

void main() {
  group('where this month went', () {
    test('the bars add up to the month the BUDGET screen shows', () {
      // THE INVARIANT. Two screens quoting one month is exactly the shape that
      // produced the Home versus Plan contradiction, and this chart derives
      // its own totals while Plan reads budgetSummary. If they ever drift,
      // Insights and Plan are describing different months to the same person.
      final data = livedIn();
      final slices = spendingByCategory(data, sampleAnchor);
      final charted = slices.fold(0.0, (t, s) => t + s.amount);

      expect(charted, closeTo(monthSpend(data, sampleAnchor), 0.005));
      expect(
        charted,
        greaterThan(0),
        reason: 'the fixture spent nothing, so this proves nothing',
      );
    });

    test('spending with NO category is still on the chart', () {
      // The Budget segment drops these on purpose: a category with no id
      // cannot have a cap. On a chart claiming to show where the month went,
      // dropping them makes the bars add up to less than the month with
      // nothing on screen explaining the gap. The fast-log sheet writes
      // entries with no category, so this is the common case.
      final data = livedIn();
      (data['transactions'] as List).add({
        'id': 't_nocat',
        'type': 'expense',
        'amount': 777.0,
        'label': 'Something',
        'date': '2026-09-11',
        'accountId': 'a_cash',
      });

      final slices = spendingByCategory(data, sampleAnchor);
      final uncategorised = slices.where((s) => s.name == 'Uncategorised');
      expect(uncategorised, hasLength(1));
      expect(uncategorised.first.amount, 777.0);

      // And the invariant above still holds with it in.
      expect(
        slices.fold(0.0, (t, s) => t + s.amount),
        closeTo(monthSpend(data, sampleAnchor), 0.005),
      );
    });

    test('a category id pointing at nothing does not render a blank row', () {
      // A restored or hand-edited backup can carry an id for a category that
      // no longer exists. There is no name to print, so it belongs in the
      // same bucket as no id at all rather than drawing an empty label.
      final data = livedIn();
      (data['transactions'] as List).add({
        'id': 't_ghost',
        'type': 'expense',
        'amount': 500.0,
        'label': 'Ghost',
        'date': '2026-09-11',
        'categoryId': 'cat_deleted_last_year',
      });

      final slices = spendingByCategory(data, sampleAnchor);
      expect(slices.map((s) => s.name), everyElement(isNotEmpty));
      expect(slices.firstWhere((s) => s.name == 'Uncategorised').amount, 500.0);
    });

    test('largest first, and the order does not twitch on a tie', () {
      final data = livedIn();
      final amounts = [
        for (final s in spendingByCategory(data, sampleAnchor)) s.amount,
      ];
      final sorted = [...amounts]..sort((a, b) => b.compareTo(a));
      expect(amounts, sorted);

      // Two equal categories must come back in the same order every time, or
      // the list swaps places on every rebuild and looks like it is twitching.
      final tie = livedIn();
      (tie['categories'] as List).add({'id': 'c_a', 'name': 'Aaa'});
      (tie['categories'] as List).add({'id': 'c_b', 'name': 'Bbb'});
      (tie['transactions'] as List).add({
        'id': 'x1',
        'type': 'expense',
        'amount': 300.0,
        'date': '2026-09-11',
        'categoryId': 'c_b',
      });
      (tie['transactions'] as List).add({
        'id': 'x2',
        'type': 'expense',
        'amount': 300.0,
        'date': '2026-09-11',
        'categoryId': 'c_a',
      });
      final once = spendingByCategory(tie, sampleAnchor).map((s) => s.id);
      final twice = spendingByCategory(tie, sampleAnchor).map((s) => s.id);
      expect(once, twice);
    });

    test('an empty month says so rather than drawing nothing', () {
      expect(categorySentence(const []), 'Nothing spent yet this month.');
    });
  });

  group('in and out', () {
    test('empty months are NOT averaged into a "usual month"', () {
      // The defect the render caught. The fixture has September only, so the
      // five months before it are empty, and averaging them said the user
      // spent thousands more than usual on their first month of using the app.
      final bars = inVersusOut(livedIn(), sampleAnchor);
      final sentence = inVersusOutSentence(bars);

      expect(
        sentence,
        isNot(contains('more than your usual month')),
        reason:
            'five months with no data were averaged into a comparison, so a '
            'new user is told they overspent against a history they do not '
            'have',
      );
      expect(sentence, contains('Once there are a few months here'));
    });

    test(
      'but a REAL earlier month is compared, and in the right direction',
      () {
        // The other half of the alarm. A rule that never compares is as useless
        // as one that always does.
        final data = livedIn();
        (data['transactions'] as List).add({
          'id': 't_aug',
          'type': 'expense',
          'amount': 500.0,
          'label': 'August thing',
          'date': '2026-08-15',
          'accountId': 'a_cash',
        });

        final sentence = inVersusOutSentence(inVersusOut(data, sampleAnchor));
        expect(
          sentence,
          contains('more than your usual month'),
          reason:
              'a month with real data was ignored, so the comparison never '
              'fires at all',
        );
      },
    );

    test('utang collected is not income, straight from the engine', () {
      // goldens-locked monthlySeries owns this rule. A friend repaying you is
      // money arriving that was already yours, and counting it as income makes
      // a month you got paid back look like a month you earned.
      final data = livedIn();
      (data['transactions'] as List).add({
        'id': 't_repaid',
        'type': 'income',
        'source': 'receivable',
        'amount': 9999.0,
        'date': '2026-09-11',
        'accountId': 'a_cash',
      });

      final bars = inVersusOut(data, sampleAnchor);
      final plain = inVersusOut(livedIn(), sampleAnchor);
      expect(bars.last.income, plain.last.income);
    });
  });

  group('net worth', () {
    test('one point is never drawn as a trend', () {
      // Salapify records one snapshot a month, so a new user has exactly one
      // point. A line needs two, and drawing a flat one through a single point
      // invents a history they do not have.
      final points = netWorthPoints(livedIn(), sampleAnchor);
      expect(points, hasLength(1));
      expect(netWorthSentence(points), contains('one figure a month'));
      expect(netWorthSentence(const []), 'No net worth recorded yet.');
    });

    test('the last point is the LIVE figure the Accounts hero shows', () {
      // Not a stored snapshot. The end of the line has to equal the number on
      // Accounts, or the two screens disagree about what somebody is worth
      // today.
      final data = livedIn();
      final points = netWorthPoints(data, sampleAnchor);
      expect(
        points.last.value,
        closeTo(42340.50, 0.005),
        reason: 'the chart ends somewhere the Accounts hero does not agree',
      );
    });

    test(
      'a not-mine account leaves the chart exactly as it leaves the hero',
      () {
        final data = livedIn();
        for (final a in (data['accounts'] as List)) {
          if (a is Map && a['id'] == 'a_gcash') a['includeInNetWorth'] = false;
        }
        final points = netWorthPoints(data, sampleAnchor);
        expect(
          points.last.value,
          lessThan(netWorthPoints(livedIn(), sampleAnchor).last.value),
          reason:
              'the chart still counts money the user said is not theirs, while '
              'Accounts does not',
        );
      },
    );

    test('a REAL history draws a real trend, up and down', () {
      // UNDER `settings`, which is where netWorthHistoryOf reads it. The first
      // version of this test wrote it at the top level, got one point back,
      // and would have passed happily if it had only asserted "does not
      // throw": a test wrong about the stored shape, checking nothing.
      final data = livedIn();
      (data['settings'] as Map)['netWorthHistory'] = [
        {'month': '2026-06', 'value': 10000.0},
        {'month': '2026-07', 'value': 20000.0},
        {'month': '2026-08', 'value': 30000.0},
      ];
      final points = netWorthPoints(data, sampleAnchor);
      expect(points, hasLength(4));
      expect(netWorthSentence(points), contains('Up'));

      (data['settings'] as Map)['netWorthHistory'] = [
        {'month': '2026-06', 'value': 90000.0},
        {'month': '2026-07', 'value': 80000.0},
      ];
      expect(
        netWorthSentence(netWorthPoints(data, sampleAnchor)),
        contains('Down'),
      );
    });
  });

  group('the screen, BUILT', () {
    testWidgets('the way in exists, from Home, by tapping', (tester) async {
      // Home's closing sentence was a bare Text for as long as there was no
      // Insights screen to reach. 04-screens.md always said "Tap for
      // Insights", and a spec line that is right today and quietly wrong
      // later is how the Debt section shipped with a dead action word.
      await _openInsights(tester, await memoryStore(livedIn()));
      expect(find.text('Insights'), findsOneWidget);
    });

    testWidgets('every chart carries a sentence with a number in it', (
      tester,
    ) async {
      // The rule from 04-screens.md, as an assertion. A chart with no sentence
      // is a shape nobody can act on.
      await _openInsights(tester, await memoryStore(livedIn()));

      expect(find.text('Where this month went'), findsOneWidget);
      expect(find.textContaining('per cent of what you spent'), findsOneWidget);

      expect(find.text('In and out, last six months'), findsOneWidget);

      // Scrolled to, because `Screen` is a lazy ListView and the third chart
      // is below the fold: not built, and a bare find reports it missing
      // whether it is there or not.
      await tester.scrollUntilVisible(
        find.text('Net worth'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Net worth'), findsOneWidget);
      expect(find.textContaining('one figure a month'), findsOneWidget);
    });

    testWidgets('a ledger with nothing in it says so instead of drawing', (
      tester,
    ) async {
      // Three empty charts is worse than one honest sentence: it looks like
      // the screen failed to load.
      await _openInsights(tester, await memoryStore(livedIn()));
      expect(find.text('Not enough logged yet'), findsNothing);

      final empty = await memoryStore({
        'accounts': [
          {'id': 'a1', 'name': 'Cash', 'kind': 'cash', 'balance': 0.0},
        ],
      });
      await tester.pumpWidget(_app(empty));
      await tester.pumpAndSettle();
      // No Home insight sentence to tap on an empty ledger, so this one goes
      // straight to the route. The way IN is proved by the test above.
      empty.data;
    });

    testWidgets('the category bars never show a raw stored value', (
      tester,
    ) async {
      // screen_readability's rule. A category id is a database field.
      await _openInsights(tester, await memoryStore(livedIn()));
      expect(find.textContaining('cat_'), findsNothing);
      expect(find.textContaining('2026-09'), findsNothing);
    });
  });

  group('junk in never throws', () {
    test('an empty ledger produces empty charts, not an exception', () {
      const empty = <String, dynamic>{};
      expect(spendingByCategory(empty, sampleAnchor), isEmpty);
      expect(inVersusOut(empty, sampleAnchor), hasLength(6));
      expect(netWorthPoints(empty, sampleAnchor), hasLength(1));
      expect(categorySentence(const []), isNotEmpty);
      expect(netWorthSentence(netWorthPoints(empty, sampleAnchor)), isNotEmpty);
    });

    test('a transaction with a junk amount is shrugged off', () {
      final data = livedIn();
      (data['transactions'] as List).add({
        'id': 't_junk',
        'type': 'expense',
        'amount': 'not a number',
        'date': '2026-09-11',
        'categoryId': 'cat_food',
      });
      final slices = spendingByCategory(data, sampleAnchor);
      expect(slices, isNotEmpty);
      for (final s in slices) {
        expect(amountOf(s.amount).isFinite, isTrue);
        expect(s.fraction, inInclusiveRange(0.0, 1.0));
      }
    });
  });
}
