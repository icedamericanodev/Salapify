// Debt, both ways, and the things that must never be true about it.
//
// The first group is not about the Debt screen at all. It is about the Debt
// screen and Home agreeing, because the founder taps a card on Home that names
// a figure and lands here expecting to see the same one. Two screens
// describing one ledger differently is a defect this app has already had to
// fix twice, and no test caught either one because no test had put two
// surfaces in front of the same store.
//
// The second group is the money. Paying a debt moves an asset down and a
// liability down by the same amount, so it CANNOT change net worth. That
// invariant is what caught the real defect in this batch: the first version of
// the payment path passed a null account to `applyDebtPayment`, which debits
// an account only when an id matches and silently debits nothing when none
// does, so the debt fell, no money left, and net worth rose by the size of the
// payment. Every invariant here carries a DIRECTIONAL companion check beside
// it, because "net worth is unchanged" is also perfectly true when the button
// did nothing at all.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/app/clock.dart';
import 'package:salapify/app/ledger_scope.dart';
import 'package:salapify/app/router.dart';
import 'package:salapify/core/data/ledger_store.dart';
import 'package:salapify/core/money/debts.dart' show logDebtPayment;
import 'package:salapify/core/money/ledger.dart' show amountOf;
import 'package:salapify/core/money/statements.dart' show netWorthParts;
import 'package:salapify/design/tokens.dart';
import 'package:salapify/dev/sample_ledger.dart';
import 'package:salapify/features/accounts/accounts_screen.dart'
    show debtTotals;
import 'package:salapify/features/debt/debt_rows.dart';

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

double _netWorth(Map<String, dynamic> d) =>
    netWorthParts(d)['netWorth'] as double;

double _balanceOf(Map<String, dynamic> d, String id) {
  for (final a in (d['accounts'] as List)) {
    if (a is Map && a['id'] == id) return amountOf(a['balance']);
  }
  return double.nan;
}

double _remainingOf(Map<String, dynamic> d, String id) {
  for (final x in (d['debts'] as List)) {
    if (x is Map && x['id'] == id) return amountOf(x['remaining']);
  }
  return double.nan;
}

void main() {
  group('Home and Debt cannot disagree about what you owe', () {
    test('both headlines come from the same figure, both directions', () {
      final data = livedIn();
      final home = debtTotals(data);
      final board = debtBoardFrom(data, sampleAnchor);

      // Did anything happen. An agreement test over two zeroes agrees
      // perfectly and proves nothing, which is the failure mode the journey
      // rules call out by name.
      expect(
        home.owed,
        greaterThan(0),
        reason:
            'the fixture owes nothing, so this test would pass with both '
            'screens broken',
      );
      expect(home.due, greaterThan(0), reason: 'the fixture is owed nothing');

      expect(board.iOwe.total, home.owed);
      expect(board.owedToMe.total, home.due);
    });

    test('the credit card is NOT counted here as well as in Accounts', () {
      // A card lives under Credit on the Accounts screen. Listing it here too
      // would show the founder the same card twice with nothing on either
      // screen saying it was one card.
      final board = debtBoardFrom(livedIn(), sampleAnchor);
      final names = [
        for (final r in [...board.iOwe.open, ...board.iOwe.settled]) r.name,
      ];

      expect(
        names,
        isNot(contains('UnionBank Rewards')),
        reason:
            'the credit card appeared in the Debt list while also appearing '
            'under Credit in Accounts, so the founder reads it twice',
      );
      // And the loan that SHOULD be here is, or the assertion above passes by
      // the list being empty.
      expect(names, contains('Lola'));
    });
  });

  group('paying a debt cannot change net worth', () {
    test('an asset falls and a liability falls by the same amount', () {
      final before = livedIn();
      final nwBefore = _netWorth(before);
      final cashBefore = _balanceOf(before, 'a_bpi');
      final owedBefore = _remainingOf(before, 'd_lola');

      final after = logDebtPayment(
        before,
        {'id': 'd_lola'},
        'a_bpi',
        '1500',
        today: '2026-09-11',
        genId: (p) => '${p}_test',
      ).data;

      // THE INVARIANT.
      expect(
        _netWorth(after),
        closeTo(nwBefore, 0.005),
        reason:
            'paying a debt changed net worth, which means the money left one '
            'side of the books and did not arrive on the other',
      );

      // THE DIRECTIONAL COMPANION, and this is the half that matters. The
      // invariant above holds perfectly when the payment does nothing at all,
      // so without these two the test passes hardest when the feature is most
      // broken. This pair is what fails when `payFrom` is null: the debt falls
      // and the account does not.
      expect(
        _balanceOf(after, 'a_bpi'),
        closeTo(cashBefore - 1500, 0.005),
        reason: 'no money actually left the account the payment came from',
      );
      expect(
        _remainingOf(after, 'd_lola'),
        lessThan(owedBefore),
        reason: 'the debt did not go down, so nothing was paid',
      );
    });

    test('and a payment with NO account named is the bug, not the feature', () {
      // Characterising the hazard the UI must never hand the engine. This is
      // the engine's real behaviour and it is golden locked, so it is pinned
      // here rather than changed: `applyDebtPayment` debits the account whose
      // id matches `payFrom` and debits nothing when none matches. The guard
      // therefore has to live in the sheet, and the widget test below proves
      // it does.
      final before = livedIn();
      final nwBefore = _netWorth(before);

      final after = logDebtPayment(
        before,
        {'id': 'd_lola'},
        null,
        '1500',
        today: '2026-09-11',
        genId: (p) => '${p}_test',
      ).data;

      expect(
        _netWorth(after),
        greaterThan(nwBefore + 1000),
        reason:
            'this test exists to pin the hazard. If it fails, the engine now '
            'refuses a payment with no account and the sheet guard can be '
            'reconsidered',
      );
    });
  });

  group('rows that do not count are listed, never hidden', () {
    test('an utang with no cash leg is shown and explained', () {
      // `trackedRemaining` counts a receivable only when `cashLeg` is true,
      // meaning real money left a real account. A legacy utang recorded
      // without one is a real debt the ledger has no movement for. Dropping it
      // from the list would make a debt the founder recorded disappear.
      final data = livedIn();
      data['receivables'] = [
        {'id': 'r_marco', 'name': 'Marco', 'amount': 1800.0, 'cashLeg': true},
        {'id': 'r_ana', 'name': 'Ana', 'amount': 900.0, 'cashLeg': false},
      ];

      final board = debtBoardFrom(data, sampleAnchor);
      final names = [for (final r in board.owedToMe.open) r.name];

      expect(
        names,
        containsAll(<String>['Marco', 'Ana']),
        reason: 'a recorded utang vanished from the list entirely',
      );
      expect(
        board.owedToMe.total,
        1800.0,
        reason:
            'the untracked row was added to the headline, which would make '
            'this screen disagree with Home and with net worth',
      );
      expect(
        board.owedToMe.uncountedRows,
        1,
        reason:
            'the screen has no way to know it must explain the difference '
            'between its list and its headline',
      );
    });

    test('a settled row leaves Open and lands in Settled', () {
      final data = livedIn();
      data['receivables'] = [
        {
          'id': 'r_done',
          'name': 'Bea',
          'amount': 500.0,
          'cashLeg': true,
          'paid': true,
          'payments': [
            {'id': 'p1', 'amount': 500.0, 'date': '2026-09-01'},
          ],
        },
      ];

      final board = debtBoardFrom(data, sampleAnchor);
      expect(board.owedToMe.open, isEmpty);
      expect(board.owedToMe.settled.map((r) => r.name), contains('Bea'));
      expect(board.owedToMe.settled.first.settled, isTrue);
    });

    test('the soonest due row sorts first, and undated rows sort last', () {
      final data = livedIn();
      data['receivables'] = [
        {
          'id': 'r_late',
          'name': 'Later',
          'amount': 100.0,
          'cashLeg': true,
          'dueDate': '2026-12-01',
        },
        {'id': 'r_none', 'name': 'Someday', 'amount': 100.0, 'cashLeg': true},
        {
          'id': 'r_soon',
          'name': 'Sooner',
          'amount': 100.0,
          'cashLeg': true,
          'dueDate': '2026-09-20',
        },
      ];

      final board = debtBoardFrom(data, sampleAnchor);
      expect(
        board.owedToMe.open.map((r) => r.name).toList(),
        ['Sooner', 'Later', 'Someday'],
        reason:
            'the only rows on this screen with a deadline were not at the top, '
            'or the undated row was put above a dated one',
      );
    });
  });

  group('on the screen', () {
    testWidgets('the Debt button on Home is no longer a dead control', (
      tester,
    ) async {
      final store = await memoryStore(livedIn());
      await tester.pumpWidget(_app(store));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Debt'));
      await tester.pumpAndSettle();

      expect(
        find.text('Both ways: what you owe, and what is owed to you.'),
        findsOneWidget,
        reason:
            'tapping Debt on Home went nowhere, which is exactly the dead '
            'control this step existed to fix',
      );
      // And the real ledger reached the screen, rather than an empty one.
      expect(find.text('Lola'), findsWidgets);
    });

    testWidgets('a loan payment cannot be saved without naming an account', (
      tester,
    ) async {
      // THE GUARD. The engine will happily take a null account and clear the
      // debt with no money leaving, so the only thing standing between the
      // founder and invented money is this button staying dark.
      final store = await memoryStore(livedIn());
      await tester.pumpWidget(_app(store));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Debt'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lola'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Record a payment'));
      await tester.pumpAndSettle();

      // Type a perfectly good amount and nothing else.
      await tester.enterText(find.byType(TextField), '1500');
      await tester.pumpAndSettle();

      final nwBefore = _netWorth(store.data);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(
        _netWorth(store.data),
        closeTo(nwBefore, 0.005),
        reason:
            'the payment saved with no account chosen, so the debt fell, no '
            'money left, and the founder is richer than they were',
      );
      expect(
        find.text('Paid from'),
        findsOneWidget,
        reason: 'the sheet closed, so the save went through',
      );
    });

    testWidgets('and it CAN be saved once an account is picked', (
      tester,
    ) async {
      // The other half. A guard that never lets anything through is not a
      // guard, it is a broken feature, and this is the assertion that tells
      // the two apart.
      final store = await memoryStore(livedIn());
      await tester.pumpWidget(_app(store));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Debt'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lola'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Record a payment'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '1500');
      await tester.pumpAndSettle();

      final nwBefore = _netWorth(store.data);
      final cashBefore = _balanceOf(store.data, 'a_bpi');
      final owedBefore = _remainingOf(store.data, 'd_lola');

      await tester.tap(find.text('BPI').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(
        _netWorth(store.data),
        closeTo(nwBefore, 0.005),
        reason: 'paying a debt through the sheet changed net worth',
      );
      expect(
        _balanceOf(store.data, 'a_bpi'),
        closeTo(cashBefore - 1500, 0.005),
        reason: 'the money did not leave the account that was picked',
      );
      expect(
        _remainingOf(store.data, 'd_lola'),
        lessThan(owedBefore),
        reason: 'the debt did not go down, so the save did nothing',
      );

      // AND THE HISTORY APPEARS. The first version of this screen returned an
      // empty payment list for a loan, because a `debts` row keeps no payments
      // array of its own: `applyDebtPayment` appends to a TOP LEVEL `payments`
      // collection tagged with `debtId`. So the screen said "No payments yet.
      // Every payment you record shows here, newest first" and would have gone
      // on saying it after ten payments. Caught by looking at the render, not
      // by any of the nine tests above it.
      await tester.pumpAndSettle();
      expect(
        find.text('No payments yet'),
        findsNothing,
        reason:
            'a payment was just recorded and the screen still claims there '
            'are none, so the loan history is wired to the wrong collection',
      );
    });
  });
}
