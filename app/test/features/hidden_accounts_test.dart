// Hiding an account, and getting it back.
//
// Half one of every write path, "did the money move correctly", lives in
// test/core/visibility_test.dart. This is half two, the one that gets
// forgotten: CAN A PERSON FOLLOW IT AFTERWARDS. The founder found the last
// defect of this shape in under a minute, by paying a debt and then opening
// the account it came out of, because that is where somebody who keeps books
// looks. A helper test could not see it by construction.
//
// So this file taps. It hides an account the way a person does, walks back to
// the screen that changed, and asserts the account is still findable there.
// The invariant it defends is one sentence: NOTHING IS BOTH INVISIBLE AND
// UNREACHABLE. An account that cannot be found again cannot be un-hidden, and
// a one way door on somebody's own money is not a view preference.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/app/clock.dart';
import 'package:salapify/app/ledger_scope.dart';
import 'package:salapify/app/router.dart';
import 'package:salapify/core/data/ledger_store.dart';
import 'package:salapify/core/money/format.dart';
import 'package:salapify/core/money/ledger.dart' show amountOf;
import 'package:salapify/core/state/financial_state.dart';
import 'package:salapify/core/state/visibility.dart';
import 'package:salapify/design/kit.dart';
import 'package:salapify/features/home/home_screen.dart'
    show spendableExcludedSentence;
import 'package:salapify/features/plan/upcoming_rows.dart' show upcomingFrom;
import 'package:salapify/design/tokens.dart';
import 'package:salapify/dev/sample_ledger.dart' show sampleAnchor;
import 'package:salapify/features/accounts/accounts_screen.dart';

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

/// Open the Accounts tab.
Future<void> _openAccounts(WidgetTester tester, LedgerStore store) async {
  await tester.pumpWidget(_app(store));
  await tester.pumpAndSettle();
  await tester.tap(
    find.descendant(
      of: find.byType(NavBar),
      matching: find.byIcon(Icons.account_balance_wallet_outlined),
    ),
  );
  await tester.pumpAndSettle();
}

/// Scroll the current screen until [what] is built.
///
/// `Screen` is a lazy ListView, so anything below the fold is NOT BUILT and a
/// bare `find` reports it missing whether it is there or not. The Hidden
/// section sits near the bottom of a long screen on purpose, so every check on
/// it has to come through here.
Future<void> _scrollTo(
  WidgetTester tester,
  Finder what, {
  double by = 200,
}) async {
  await tester.scrollUntilVisible(
    what,
    by,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

/// Drag the screen to its end, so everything on it has been built.
///
/// Used before an assertion that something IS or IS NOT on the page, where
/// `scrollUntilVisible` is the wrong tool: when the thing is missing it throws
/// "Bad state: No element" out of the scroll helper, and a reader of that
/// failure learns nothing about what the test was checking. Scrolling to the
/// bottom first means a missing widget fails on the `expect`, with its reason.
Future<void> _scrollToEnd(WidgetTester tester) async {
  final list = find.byType(Scrollable).first;
  for (var i = 0; i < 12; i++) {
    await tester.drag(list, const Offset(0, -400));
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

/// Tap an account row, flip one switch in its Options sheet, and come back.
Future<void> _setSwitch(
  WidgetTester tester,
  String account,
  String toggle,
) async {
  await _scrollTo(tester, find.text(account));
  await tester.tap(find.text(account));
  await tester.pumpAndSettle();

  await tester.tap(find.text('Options'));
  await tester.pumpAndSettle();

  // BY NAME, not by position. The sheet holds two switches and one of them
  // changes net worth, so "the first one" is exactly the kind of locator that
  // starts testing the wrong control the day a third toggle appears above it.
  await tester.tap(find.byKey(ValueKey(toggle)));
  await tester.pumpAndSettle();

  // Close the sheet, then the detail screen, landing back on Accounts.
  Navigator.of(tester.element(find.text(toggle)), rootNavigator: true).pop();
  await tester.pumpAndSettle();

  // The app's own chevron, not `pageBack`. BackBar is a plain icon in a
  // GestureDetector, so there is no Material or Cupertino back button on the
  // screen for that helper to find.
  await tester.tap(
    find.descendant(
      of: find.byType(BackBar),
      matching: find.byIcon(Icons.arrow_back_rounded),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('the list splits, and nothing falls out of both halves', () {
    test('groupAccounts(hidden: true) returns ONLY what was hidden', () {
      final data = livedIn();
      for (final a in (data['accounts'] as List)) {
        if (a is Map && a['id'] == 'a_gcash') a['isArchived'] = true;
      }

      final everyday = groupAccounts(data);
      final hidden = groupAccounts(data, hidden: true);

      expect(
        everyday.expand((g) => g.accounts).map((a) => a['name']),
        isNot(contains('GCash')),
        reason: 'a hidden account is still in the everyday list',
      );
      expect(
        hidden.expand((g) => g.accounts).map((a) => a['name']),
        ['GCash'],
        reason:
            'the hidden list is empty or carries rows that were never hidden, '
            'so the only route back to this account is gone',
      );
    });

    test('a hidden LOAN is in the hidden list, not in neither list', () {
      // The second way an account could disappear entirely, found by the
      // recovery pass and confirmed by running it.
      //
      // `rollsIntoDebtSummary` keeps loans out of the everyday list because
      // the Debt summary already counts them, which is right. Applied to the
      // hidden list as well, the two filters together left a hidden loan in
      // NEITHER, and since the only un-hide switch is on account detail, and
      // the only route there is a row, the flag was stuck on forever.
      //
      // It arrives for real: the shipped app's own "Hide account" button
      // writes `isArchived` on debt rows, so any restored backup can carry one.
      final data = livedIn();
      for (final d in (data['debts'] as List)) {
        if (d is Map && d['id'] == 'd_lola') d['isArchived'] = true;
      }

      expect(
        groupAccounts(
          data,
          hidden: true,
        ).expand((g) => g.accounts).map((a) => a['name']),
        contains('Lola'),
        reason:
            'a hidden loan is in neither list, so nothing in the app can ever '
            'un-hide it again',
      );
      expect(
        groupAccounts(data).expand((g) => g.accounts).map((a) => a['name']),
        isNot(contains('Lola')),
        reason: 'the everyday list changed, which was not the fix',
      );
    });

    test('every row lands in exactly one of the two lists', () {
      // THE INVARIANT, as arithmetic. A filter with an off by one reading of
      // the flag could drop a row from both lists at once, and an account in
      // neither list is an account that no longer exists as far as anybody
      // tapping the screen is concerned.
      //
      // THE FIXTURE IS A LOAN, DELIBERATELY. With `a_gcash` this arithmetic
      // was 4 + 0 == 4 and stayed green through the entire hidden-loan defect
      // above, because the loan is absent from the baseline too: both sides
      // dropped the same category and the subtraction hid it perfectly.
      final data = livedIn();
      for (final d in (data['debts'] as List)) {
        if (d is Map && d['id'] == 'd_lola') d['isArchived'] = true;
      }

      int rows(List<AccountGroup> gs) =>
          gs.fold(0, (t, g) => t + g.accounts.length);

      expect(
        rows(groupAccounts(data)) + rows(groupAccounts(data, hidden: true)),
        rows(groupAccounts(livedIn())) + 1,
        reason:
            'hiding a loan removed it from the screen entirely. The +1 is the '
            'loan itself, which the everyday list never showed and the hidden '
            'list now must',
      );
    });

    test('an untouched ledger has no hidden list at all', () {
      // The other half of the alarm. A heading that appears for everybody is
      // a feature nobody asked for sitting on the main screen.
      expect(groupAccounts(livedIn(), hidden: true), isEmpty);
    });
  });

  group('what the screen SAYS about each of the three states', () {
    // Sentences, not layout, and pure so they can be checked one at a time.
    // Every wrong version of these read as a confident, true-looking statement
    // about somebody's money, which is the only reason they are worth a test.

    AccountGroup one(Map<String, dynamic> row) =>
        AccountGroup('cash_equivalents', 'Cash', [row]);

    test('hidden says still counted; CLOSED must not', () {
      expect(
        hiddenCaption([
          one({'name': 'A', 'isArchived': true}),
        ]),
        contains('Still counted in your net worth'),
      );

      // The third state. With both flags the row is out of net worth, and the
      // screen used to claim the opposite at the bottom while the hero
      // correctly said it was excluded at the top: two contradictory sentences
      // about one account, in one pump.
      final closed = hiddenCaption([
        one({'name': 'A', 'isArchived': true, 'includeInNetWorth': false}),
      ]);
      expect(
        closed,
        isNot(contains('Still counted in your net worth')),
        reason:
            'the screen says a closed account is still in net worth while the '
            'hero says it is not, on the same screen',
      );
      expect(closed, contains('out of your net worth'));
    });

    test('a mixed hidden list claims neither thing about all of it', () {
      final mixed = hiddenCaption([
        AccountGroup('cash_equivalents', 'Cash', [
          {'name': 'A', 'isArchived': true},
          {'name': 'B', 'isArchived': true, 'includeInNetWorth': false},
        ]),
      ]);
      expect(mixed, contains('The ones still counted as yours'));
    });

    test('safe to spend is only ever claimed as a MAYBE', () {
      // `liquidKinds` is cash, e-wallet and checking, so hiding a savings pot
      // or an investment changes safe to spend by nothing. The first version
      // said "left out of what is safe to spend" in every case, which is a
      // small lie about money on the one screen whose job is explaining a gap.
      expect(
        hiddenCaption([
          one({'name': 'A', 'isArchived': true}),
        ]),
        contains('Any spending money in here'),
      );
    });

    test('the hero never prints a figure that is not the one that moved', () {
      // `fromNetWorth` is SIGNED. Disown one account and one credit card of
      // the same size and it nets to exactly zero, which rendered as
      // "₱0.00 across 2 accounts is not counted": a sentence that reads as a
      // bug report. Disown a debt alone and it is negative, and printing the
      // absolute value said money LEFT when net worth actually went up.
      const assetOnly = Excluded(
        fromNetWorth: 8410.50,
        notMineCount: 1,
        fromSpendable: 0,
        spendableCount: 0,
        hiddenCount: 0,
      );
      expect(notMineSentence(assetOnly), contains('is not counted'));
      expect(notMineSentence(assetOnly), contains('8,410.50'));

      const debtOnly = Excluded(
        fromNetWorth: -6000,
        notMineCount: 1,
        fromSpendable: 0,
        spendableCount: 0,
        hiddenCount: 0,
      );
      expect(
        notMineSentence(debtOnly),
        contains('higher'),
        reason:
            'disowning a debt was reported as money leaving, so the sentence '
            'says the net worth went down when it went up',
      );

      const netsToZero = Excluded(
        fromNetWorth: 0,
        notMineCount: 2,
        fromSpendable: 0,
        spendableCount: 0,
        hiddenCount: 0,
      );
      expect(
        notMineSentence(netsToZero),
        isNot(contains('₱0')),
        reason:
            'the hero offers "₱0.00 across 2 accounts is not counted", which '
            'reads as a bug rather than as a fact about money',
      );
      expect(notMineSentence(netsToZero), contains('2 accounts'));
    });
  });

  group('by hand, the way a person does it', () {
    testWidgets('hide GCash, and it moves to Hidden instead of vanishing', (
      tester,
    ) async {
      final store = await memoryStore(livedIn());
      await _openAccounts(tester, store);

      // Before: it is an ordinary row and there is no Hidden heading.
      expect(find.text('GCash'), findsOneWidget);
      expect(find.text('Hidden'), findsNothing);

      await _setSwitch(tester, 'GCash', 'Hide from my lists');

      // It really was written, not just repainted.
      expect(
        (store.data['accounts'] as List).firstWhere(
          (a) => a['id'] == 'a_gcash',
        )['isArchived'],
        isTrue,
        reason: 'the switch moved and nothing was saved',
      );

      // And it is STILL ON THE SCREEN, under its own heading.
      await _scrollToEnd(tester);
      expect(
        find.text('Hidden'),
        findsOneWidget,
        reason: 'there is no Hidden section for the account to have gone to',
      );
      expect(
        find.text('GCash'),
        findsOneWidget,
        reason:
            'the account is gone from the Accounts screen, so there is no way '
            'left to open it and un-hide it',
      );
    });

    testWidgets('and the way back out works from the same place', (
      tester,
    ) async {
      // A door that only opens one way is the defect. This is the return trip,
      // done entirely by tapping, starting from a ledger where the account is
      // already hidden.
      final data = livedIn();
      for (final a in (data['accounts'] as List)) {
        if (a is Map && a['id'] == 'a_gcash') a['isArchived'] = true;
      }
      final store = await memoryStore(data);
      await _openAccounts(tester, store);

      await _setSwitch(tester, 'GCash', 'Hide from my lists');

      // `isHiddenFromLists`, not `== false`. The golden locked `taxonomyKeys`
      // keeps `isArchived` only when it is TRUE and drops the key otherwise,
      // so un-hiding removes the field rather than writing false. Asserting on
      // the literal false was the first version of this line and it failed
      // with "Expected: false / Actual: <null>", which is the storage layer
      // being right and the test being wrong about the shape.
      expect(
        isHiddenFromLists(
          (store.data['accounts'] as List).firstWhere(
            (a) => a['id'] == 'a_gcash',
          ),
        ),
        isFalse,
        reason: 'the switch moved and the account is still hidden',
      );
      await tester.pumpAndSettle();
      expect(find.text('Hidden'), findsNothing);

      // UPWARDS. The screen is still parked where the Hidden section used to
      // be, and the account has just moved back up into the cash section, so
      // scrolling further down would never reach it. This is the lazy list
      // again: off screen is not built, and not built reads as not there.
      await _scrollTo(tester, find.text('GCash'), by: -200);
      expect(
        find.text('GCash'),
        findsOneWidget,
        reason: 'the account came out of Hidden and did not come back',
      );
    });

    testWidgets('the screen SAYS what hiding did to the totals', (
      tester,
    ) async {
      // Money that silently leaves a total is indistinguishable from money the
      // app lost, and on an offline app with no support channel there is
      // nobody to ask. Safe to spend falls when an account is hidden, so the
      // screen that did it has to say so.
      final data = livedIn();
      for (final a in (data['accounts'] as List)) {
        if (a is Map && a['id'] == 'a_gcash') a['isArchived'] = true;
      }
      await _openAccounts(tester, await memoryStore(data));

      await _scrollToEnd(tester);
      expect(
        find.textContaining('Still counted in your net worth'),
        findsOneWidget,
        reason:
            'nothing on the screen explains why the rows no longer add up to '
            'the number at the top of it',
      );
      expect(find.textContaining('safe to spend'), findsOneWidget);
    });

    testWidgets('"not mine" money is named in the hero, with the amount', (
      tester,
    ) async {
      // The other flag, and the one that genuinely lowers net worth. The hero
      // must never just be smaller than the rows under it with no explanation.
      final data = livedIn();
      var balance = 0.0;
      for (final a in (data['accounts'] as List)) {
        if (a is Map && a['id'] == 'a_gcash') {
          a['includeInNetWorth'] = false;
          balance = amountOf(a['balance']);
        }
      }
      await _openAccounts(tester, await memoryStore(data));

      expect(
        find.textContaining(
          'is not counted, because you said it is not '
          'yours',
        ),
        findsOneWidget,
      );
      // The AMOUNT, not just the fact. "Something is excluded" is not a
      // sentence anybody can reconcile a balance against.
      //
      // Read from the fixture and formatted, never typed in. The first version
      // of this line carried a made up figure and failed against the real one,
      // which is the cheap version of a test asserting a number the app does
      // not produce.
      expect(balance, greaterThan(0));
      expect(find.textContaining(formatMoney(balance)), findsWidgets);

      // AND THE ROW SAYS SO TOO. The hero's sentence names an amount; the list
      // is what somebody actually adds up. Without a mark on the row there is
      // no way to tell which of three accounts the sentence was about.
      expect(
        find.textContaining('Not counted'),
        findsOneWidget,
        reason:
            'the excluded account is an ordinary looking row, so the list and '
            'the hero disagree with nothing on screen joining them up',
      );
    });

    testWidgets('hide your ONLY account and it is still on the screen', (
      tester,
    ) async {
      // THE WORST CASE THE FIRST BUILD HAD, and the one a brand new user is
      // most likely to reach. Install, add one account because the empty
      // state's own button says to, hide it. No debts, because they installed
      // ten seconds ago.
      //
      // `groups` is the NON-hidden list, so the empty-state early return fired
      // and the screen said "No accounts yet" over a ledger with their money
      // in it. The account was on disk, still in net worth, and no widget in
      // the app could draw it. Worse: that branch carries no Settings action
      // and the "Your data" row is below the return, so they also lost Backup
      // and Restore, which is the last recovery an offline app has.
      final store = await memoryStore({
        'accounts': [
          {'id': 'a_only', 'name': 'Wallet', 'kind': 'cash', 'balance': 5000.0},
        ],
      });
      await _openAccounts(tester, store);
      await _setSwitch(tester, 'Wallet', 'Hide from my lists');

      expect(
        find.text('No accounts yet'),
        findsNothing,
        reason:
            'the screen claims there are no accounts while holding one, so '
            'the obvious next move is to add it again and count it twice',
      );
      await _scrollToEnd(tester);
      expect(find.text('Hidden'), findsOneWidget);
      expect(
        find.text('Wallet'),
        findsOneWidget,
        reason: 'the only account is unreachable, and so is the un-hide switch',
      );
      expect(
        find.text('Backup and settings'),
        findsOneWidget,
        reason:
            'hiding the last account also took away Restore, which is the '
            'only way back from anything on a phone with no server',
      );
    });
  });

  group('every screen agrees, which is the whole reason FinancialState exists', () {
    test('Home and Plan cannot give opposite answers to "do I make it"', () {
      // The contradiction this feature reintroduced within a day of being
      // written, and the exact shape financial_state.dart's header says the
      // file exists to make impossible.
      //
      // Home reads FinancialState, which filters. Plan's timeline called
      // `sweldoTimeline` on the RAW ledger, so its opening balance included
      // the money Home had just taken out. Measured before the fix, with one
      // e-wallet marked not mine: Home said MINUS 2,144 and "your bills come
      // to more than this", Plan said the lowest point was 6,266.50 and "this
      // is as low as it gets". One ledger, one moment, and a paluwagan pot
      // doing the talking.
      final data = livedIn();
      for (final a in (data['accounts'] as List)) {
        if (a is Map && a['id'] == 'a_gcash') a['includeInNetWorth'] = false;
      }

      final home = FinancialState.of(data, sampleAnchor);
      final plan = upcomingFrom(data, sampleAnchor);

      // Plan's projection starts from today's liquid money, so its first day
      // can never be built on more cash than Home says exists.
      expect(
        plan.lowest,
        lessThanOrEqualTo(home.liquid + 0.005),
        reason:
            'Plan is projecting from money Home does not count, so the two '
            'screens disagree about whether the user makes it to payday',
      );

      // DIRECTIONAL. Without this, a filter that removed every account would
      // also pass the line above.
      final unfiltered = upcomingFrom(livedIn(), sampleAnchor);
      expect(
        unfiltered.lowest,
        greaterThan(plan.lowest),
        reason: 'the filter changed nothing, so this proves nothing about it',
      );
    });

    test('a debt that is not yours leaves BOTH net worth and "You owe"', () {
      // ownedOnly took a disowned debt out of net worth while debtTotals kept
      // counting it, so the Accounts hero, the Home beam and the Debt screen
      // gave two answers with nothing saying why. A co-signed loan you are not
      // paying is exactly the row this flag is for, and it arrives out of a
      // restored backup.
      final data = livedIn();
      for (final d in (data['debts'] as List)) {
        if (d is Map && d['id'] == 'd_lola') d['includeInNetWorth'] = false;
      }

      expect(
        debtTotals(data).owed,
        lessThan(debtTotals(livedIn()).owed),
        reason:
            '"You owe" still counts a debt the user said is not theirs, while '
            'net worth does not',
      );
    });

    test('Home SAYS what it left out', () {
      // visibility.dart states the rule: every screen that subtracts one of
      // these figures also renders the matching sentence. Home broke it on the
      // day the rule was written. The data for the sentence was already being
      // computed and thrown away.
      final data = livedIn();
      for (final a in (data['accounts'] as List)) {
        if (a is Map && a['id'] == 'a_gcash') a['isArchived'] = true;
      }

      final e = FinancialState.of(data, sampleAnchor).excluded;
      expect(e.anySpendable, isTrue);
      expect(spendableExcludedSentence(e), contains('1 account'));
      expect(spendableExcludedSentence(e), contains('Accounts'));

      // And it counts SPENDING accounts, not hidden ones. A hidden savings pot
      // is hidden and was never in safe to spend, so a sentence built on
      // hiddenCount would name an account that had nothing to do with the
      // figure it is explaining.
      final withPot = livedIn();
      (withPot['accounts'] as List).add({
        'id': 'a_pot',
        'name': 'Time deposit',
        'kind': 'savings',
        'balance': 50000.0,
        'isArchived': true,
      });
      final potOnly = FinancialState.of(withPot, sampleAnchor).excluded;
      expect(potOnly.hiddenCount, 1);
      expect(
        potOnly.anySpendable,
        isFalse,
        reason:
            'Home offers to explain a drop in safe to spend that never '
            'happened, naming an account that was never in it',
      );
    });
  });
}
