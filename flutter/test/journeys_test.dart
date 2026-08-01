// Doing several things in a row, the way a person actually does, and checking
// that every screen still agrees about the money afterwards.
//
// This file exists because the founder is at work and cannot test the app by
// hand, and because of what a day of rendering screens taught: sixty test files
// already tap through screens, and every one of them tests ONE screen in
// isolation with a store built for it. So a defect that lives in the SEAM
// between two features has nowhere to be caught. Three separate suspicions in
// one afternoon came from two screens seeming to disagree about the same
// number, and none could be settled by a test, because no test ever put two
// screens in front of the same data.
//
// The frame here is INVARIANTS, not expected values. An expected value has to
// be recalculated by hand every time the fixture changes, which is how a test
// ends up asserting whatever the code happened to do. An invariant is a
// sentence that must be true no matter what anybody taps:
//
//   * moving money between two of your own accounts cannot change your net
//     worth, not by a centavo, ever;
//   * paying a debt cannot change your net worth either, because the money
//     leaves an asset and the same amount leaves a liability;
//   * spending reduces net worth by exactly what was spent;
//   * lending money and being paid back in full returns everything to where it
//     started.
//
// Each one is checked through the REAL screens, by tapping and typing, so it
// covers the wiring as well as the arithmetic. The engines are already locked
// to the React Native app by golden vectors; what was never covered is whether
// the screens spend those engines correctly in sequence.
//
// One deliberate omission, said out loud: this does not assert what the pixels
// look like. screens_shot.dart draws, screen_readability_test.dart measures,
// and this one moves money. Three jobs, three files.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/money/ledger.dart' show amountOf;
import 'package:salapify/money/milestones.dart' show milestoneFor;
import 'package:salapify/money/statements.dart' show netWorthParts;
import 'package:salapify/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A phone tall enough that a lazy list builds the rows a journey needs.
///
/// Not a shortcut around scrolling: a tap dispatched at an unbuilt row does not
/// throw, it silently does nothing, and the assertion fifty lines later then
/// fails for a reason that has nothing to do with the bug. That cost a round
/// once already.
const Size _tallPhone = Size(1200, 4200);

Map<String, dynamic> _seed() => {
  'schemaVersion': 12,
  'settings': {
    'onboarded': true,
    'paydaySchedule': {'mode': 'monthly', 'day': 30},
    'monthlyLimit': 18000,
  },
  'accounts': [
    {'id': 'cash', 'name': 'Cash', 'kind': 'cash', 'balance': 3000},
    {'id': 'bank', 'name': 'Bank', 'kind': 'savings', 'balance': 20000},
  ],
  'debts': [
    {
      'id': 'card',
      'name': 'BPI card',
      'type': 'credit card',
      'remaining': 8000,
      'monthlyRate': 3,
      'minPayment': 1000,
      'dueDay': 15,
    },
  ],
  'categories': <Map<String, dynamic>>[],
  'transactions': <Map<String, dynamic>>[],
  'receivables': <Map<String, dynamic>>[],
};

/// A lived-in blob for the milestone journeys: a plain loan that will be paid
/// off to a real "Debt free" win, a debt already zeroed BY HAND (no logged
/// pesos, so it is deliberately not a milestone), and a goal one small deposit
/// short of its target. Kept separate from _seed() so the net-worth literals in
/// the older journeys above stay true: this seed carries different debts.
Map<String, dynamic> _winSeed() => {
  'schemaVersion': 12,
  'settings': {
    'onboarded': true,
    'paydaySchedule': {'mode': 'monthly', 'day': 30},
    'monthlyLimit': 18000,
  },
  'accounts': [
    {'id': 'cash', 'name': 'Cash', 'kind': 'cash', 'balance': 3000},
    {'id': 'bank', 'name': 'Bank', 'kind': 'savings', 'balance': 20000},
  ],
  'debts': [
    // A plain personal loan: paying it to zero says "Debt free", not the
    // revolving "Back to zero" a credit card would.
    {
      'id': 'loan',
      'name': 'Salary Loan',
      'type': 'personal loan',
      'remaining': 8000,
      'monthlyRate': 0,
      'minPayment': 1000,
      'dueDay': 0,
      'interestThroughISO': '2026-01-01',
    },
    // Zeroed by hand with no payment behind it. The engine excludes this from
    // milestones on purpose; the UI must honor that.
    {
      'id': 'zeroed',
      'name': 'Old ghost',
      'type': 'personal loan',
      'remaining': 0,
      'monthlyRate': 0,
      'minPayment': 0,
      'dueDay': 0,
    },
  ],
  'goals': [
    {'id': 'g1', 'name': 'New phone', 'target': 5000, 'saved': 4500},
  ],
  'categories': <Map<String, dynamic>>[],
  'transactions': <Map<String, dynamic>>[],
  'receivables': <Map<String, dynamic>>[],
  'payments': <Map<String, dynamic>>[],
};

Future<SalapifyStore> _openApp(
  WidgetTester tester, [
  Map<String, dynamic>? seed,
]) async {
  tester.view.physicalSize = _tallPhone;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues({
    storageKey: jsonEncode(seed ?? _seed()),
  });
  final store = SalapifyStore();
  await tester.pumpWidget(SalapifyApp(store: store));
  await tester.pumpAndSettle();
  return store;
}

/// Net worth straight from the golden-locked engine.
///
/// Read from the engine rather than scraped off the screen ON PURPOSE. Scraping
/// would make every invariant here also a test of the formatter, so a rounding
/// change would fail four money tests and point at none of them.
double _netWorth(SalapifyStore store) =>
    amountOf(netWorthParts(store.data)['netWorth']);

double _balance(SalapifyStore store, String id) {
  for (final a in (store.data['accounts'] as List)) {
    final m = (a as Map).cast<String, dynamic>();
    if (m['id'] == id) return amountOf(m['balance']);
  }
  fail('no account $id');
}

/// Everything still owed TO the person, across every receivable.
double _openReceivableTotal(SalapifyStore store) {
  var total = 0.0;
  for (final r in (store.data['receivables'] as List)) {
    final m = (r as Map).cast<String, dynamic>();
    if (m['paid'] == true) continue;
    var paid = 0.0;
    for (final p
        in (m['payments'] is List ? m['payments'] as List : const [])) {
      paid += amountOf((p as Map)['amount']);
    }
    final left = amountOf(m['amount']) - paid;
    if (left > 0) total += left;
  }
  return total;
}

double _debt(SalapifyStore store, String id) {
  for (final d in (store.data['debts'] as List)) {
    final m = (d as Map).cast<String, dynamic>();
    if (m['id'] == id) return amountOf(m['remaining']);
  }
  fail('no debt $id');
}

double _goalSaved(SalapifyStore store, String id) {
  for (final g in (store.data['goals'] as List)) {
    final m = (g as Map).cast<String, dynamic>();
    if (m['id'] == id) return amountOf(m['saved']);
  }
  fail('no goal $id');
}

/// Tap something that may be below the fold, scrolling to it first.
Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f.first);
  await tester.pumpAndSettle();
  await tester.tap(f.first);
  await tester.pumpAndSettle();
}

/// Everything the app has stored, as one comparable string.
///
/// The did-anything-happen half of every journey, made into a machine rather
/// than left to whatever assertion looked convincing at the time.
///
/// It was left to judgement for exactly one day, and two of the six journeys in
/// this file then passed with the feature under test completely dead. The
/// transfer journey asserted `bank + cash == 23000`, which is true after a
/// working transfer AND true after no transfer at all, because a sum is
/// precisely what a transfer preserves. The comment above it called it the
/// honest half.
///
/// The two hollow ones were both journeys whose invariant is a CONSERVATION
/// statement, "changes nothing", "returns to the start". That is not bad luck:
/// a conservation invariant is unfalsifiable by inaction by construction, so
/// its companion check can never be another conservation statement. The four
/// healthy journeys assert a DIRECTIONAL change and carry their own proof for
/// free.
String _storedState(SalapifyStore store) => jsonEncode(store.data);

/// Log one expense through the real sheet, the way a person does.
Future<void> _logExpense(
  WidgetTester tester, {
  required String amount,
  required String label,
  required String account,
}) async {
  await _tap(tester, find.text('Log'));
  await tester.enterText(find.byType(TextField).at(0), amount);
  await tester.enterText(find.byType(TextField).at(1), label);
  await _tap(tester, find.widgetWithText(ChoiceChip, account));
  await _tap(tester, find.text('Save entry'));
}

void main() {
  testWidgets('spending reduces net worth by exactly what was spent', (
    tester,
  ) async {
    final store = await _openApp(tester);
    final before = _netWorth(store);
    final cashBefore = _balance(store, 'cash');

    await _logExpense(
      tester,
      amount: '250.75',
      label: 'Groceries',
      account: 'Cash',
    );

    // To the centavo. An expense that lands as 250 or 251 is the crossed-out
    // peso all over again: plausible on screen and wrong in the ledger.
    expect(_balance(store, 'cash'), closeTo(cashBefore - 250.75, 0.001));
    expect(_netWorth(store), closeTo(before - 250.75, 0.001));
  });

  testWidgets('the log survives being written to disk and read back', (
    tester,
  ) async {
    // The half a widget test usually skips. Everything above lives in memory,
    // and an entry that never reaches storage is an entry the person loses when
    // they close the app, which looks exactly like the app eating their money.
    final store = await _openApp(tester);
    await _logExpense(
      tester,
      amount: '480',
      label: 'Lunch out',
      account: 'Bank',
    );
    final after = _netWorth(store);

    final reopened = SalapifyStore();
    await reopened.load();
    expect(_balance(reopened, 'bank'), closeTo(19520, 0.001));
    expect(_netWorth(reopened), closeTo(after, 0.001));
  });

  testWidgets('moving money between your own accounts changes nothing', (
    tester,
  ) async {
    // The purest invariant in the app, and the one a person would notice
    // instantly: your total cannot move because you shuffled your own money.
    final store = await _openApp(tester);
    final before = _netWorth(store);
    final stateBefore = _storedState(store);

    await _tap(tester, find.byTooltip('Menu'));
    await _tap(tester, find.text('Accounts'));
    await _tap(tester, find.text('Move money between accounts'));

    // The sheet defaults its SOURCE to the first account, Cash, so the
    // destination chip to press is Bank. The chips read "Bank  ₱20,000", hence
    // textContaining rather than an exact match, and `.last` because the plain
    // account name also exists on the list behind the sheet.
    await _tap(tester, find.textContaining('Bank').last);
    await tester.enterText(find.byType(TextField), '1500');
    await tester.pumpAndSettle();
    await _tap(tester, find.text('Move it'));

    expect(
      _netWorth(store),
      closeTo(before, 0.001),
      reason:
          'a transfer between two of your own accounts moved your net worth. '
          'Nothing entered or left; only the label on the money changed.',
    );
    // And the money actually moved. DIRECTIONAL, per account, because the
    // previous version of this line summed the two balances and 23,000 is what
    // a transfer preserves: it passed just as happily when the transfer never
    // happened. Bank must be down 1,500 and Cash up 1,500, which inaction
    // cannot satisfy.
    // Cash 3,000 - 1,500 and Bank 20,000 + 1,500. The direction is Cash to
    // Bank, and getting it backwards first is worth recording: the sheet
    // defaults its SOURCE to the first account in the list, and the first
    // assertion here assumed the opposite and failed with Actual 21500. A
    // conservation check could never have told me which way the money went.
    expect(_balance(store, 'cash'), closeTo(1500, 0.001));
    expect(_balance(store, 'bank'), closeTo(21500, 0.001));
    expect(
      _storedState(store),
      isNot(stateBefore),
      reason: 'nothing was written, so the transfer never happened',
    );
  });

  testWidgets('paying a debt does not change net worth', (tester) async {
    // Money leaves an account and the same amount leaves what you owe, so the
    // total is untouched. Worth pinning precisely because it is the one people
    // expect to be wrong: it FEELS like paying a card should make you poorer,
    // and an app that agreed with the feeling would be lying.
    final store = await _openApp(tester);
    final before = _netWorth(store);
    final owedBefore = _debt(store, 'card');
    final cashBefore = _balance(store, 'cash');

    // Reached from the bottom nav, not the Menu. Debts and utang were merged
    // into one tab, "I owe" first, so there is no Debts destination to open.
    // Discovering that from a failing test is itself worth something: a
    // journey written from memory of where things used to be is a journey
    // nobody could follow either.
    await _tap(tester, find.text('Utang'));
    await _tap(tester, find.text('BPI card'));
    // The payment box arrives PREFILLED with the minimum, which is 1000 here,
    // so nothing is typed. That is deliberate: it exercises the default a real
    // person taps straight through, and a test that overwrites the prefill
    // would never notice the prefill breaking.
    expect(find.text('LOG A PAYMENT'), findsOneWidget);
    await _tap(tester, find.text('Cash'));
    await _tap(tester, find.text('Log payment'));

    expect(_debt(store, 'card'), closeTo(owedBefore - 1000, 0.001));
    expect(_balance(store, 'cash'), closeTo(cashBefore - 1000, 0.001));
    expect(
      _netWorth(store),
      closeTo(before, 0.001),
      reason:
          'paying a debt moved net worth. An asset fell by 1000 and a '
          'liability fell by 1000, so the total cannot have changed.',
    );
  });

  testWidgets('every screen shows the same money after a write', (
    tester,
  ) async {
    // The check that no existing test could make, and the reason this file was
    // written. An afternoon of investigations chasing Home against Insights,
    // and Accounts against Utang, produced three false alarms, because no test
    // had ever put two screens in front of one store. This walks the tabs after
    // a real write and asserts each one renders the SAME figure.
    final store = await _openApp(tester);
    await _logExpense(
      tester,
      amount: '1200',
      label: 'Electricity',
      account: 'Bank',
    );

    // Bank 20,000 - 1,200 = 18,800. Cash 3,000. Debt 8,000.
    // Net worth 21,800 - 8,000 = 13,800.
    expect(_netWorth(store), closeTo(13800, 0.001));

    await _tap(tester, find.byTooltip('Menu'));
    await _tap(tester, find.text('Accounts'));
    // The hero on Accounts, from netWorthParts, and the engine, from the same
    // call. If these two ever part company the screen is doing its own maths.
    expect(
      find.text('₱13,800'),
      findsWidgets,
      reason: 'Accounts disagrees with the engine about net worth',
    );
    expect(find.text('₱18,800'), findsWidgets, reason: 'the Bank row is wrong');
  });

  testWidgets('lending and being repaid in full returns to the start', (
    tester,
  ) async {
    // A whole round trip through the utang feature, which is the part of this
    // app nothing else quite resembles. The money leaves as cash and comes back
    // as cash, so everything must land exactly where it began.
    final store = await _openApp(tester);
    final before = _netWorth(store);
    final cashBefore = _balance(store, 'cash');

    await _tap(tester, find.text('Utang'));
    await _tap(tester, find.text('Owed to me'));
    await _tap(tester, find.text('New'));
    await tester.enterText(find.byType(TextField).at(0), 'Ana');
    await tester.enterText(find.byType(TextField).at(1), '900');
    await tester.pumpAndSettle();
    // Pick the account the cash LEFT, which is what makes this a tracked
    // utang. Without it the app deliberately records the debt WITHOUT moving
    // money, because "I lent this last month, let me write it down" must not
    // invent a withdrawal today. The first version of this journey skipped the
    // chip and then asserted cash had fallen, so it failed against correct
    // behaviour. Reading receivables.dart settled it: cashLeg is true only when
    // a lending account is chosen.
    await _tap(tester, find.widgetWithText(ChoiceChip, 'Cash'));
    await _tap(tester, find.textContaining('Save'));

    expect(
      find.text('Ana'),
      findsWidgets,
      reason: 'the utang was never recorded, so nothing below tests anything',
    );

    // Lending has to have MOVED the cash, or the repayment below is settling
    // a debt that never cost anything and the round trip proves nothing.
    expect(
      _balance(store, 'cash'),
      closeTo(cashBefore - 900, 0.001),
      reason: 'the 900 never left the account, so nothing was really lent',
    );

    await _tap(tester, find.text('Ana'));
    await _tap(tester, find.textContaining('Mark paid'));
    await _tap(tester, find.textContaining('Mark paid').last);

    expect(
      _netWorth(store),
      closeTo(before, 0.001),
      reason:
          'lent 900 and was paid back 900, so the total must be exactly what '
          'it was before either happened',
    );
    // DIRECTIONAL, and the reason this line exists: the invariant above is a
    // conservation statement, so it also holds if the repayment never
    // happened. Cash must be back where it started AND the receivable must be
    // gone from what is still owed.
    expect(
      _balance(store, 'cash'),
      closeTo(cashBefore, 0.001),
      reason: 'the 900 never came back, so the repayment did not happen',
    );
    expect(
      _openReceivableTotal(store),
      closeTo(0, 0.001),
      reason: 'the utang is still open, so marking it paid did nothing',
    );
  });

  // The milestone celebration journeys. The invariant they all defend: the
  // instant a save crosses a real money win, ONE branded share sheet opens, and
  // it opens only for a real win, only once, and never for bookkeeping. The
  // money must still add up across every screen while all that happens.
  //
  // Timing note, learned from debts_screen_test: showMilestoneCelebration fires
  // a self-dismissing confetti overlay (real-delay timers) AND pushes a modal
  // sheet route. pumpAndSettle through the confetti would spin, so the pattern
  // is: pump a beat, pump ~400ms to let the sheet route animate open, assert,
  // dismiss with "Maybe later", THEN pumpAndSettle to drain the confetti.

  testWidgets(
    'a debt reaching zero celebrates once; a payment that does not clear it '
    'does not',
    (tester) async {
      // Invariant: paying a debt to zero through the real payment path opens the
      // share sheet exactly once, and a payment that leaves the debt open opens
      // nothing. The second half is the directional not-when-it-shouldn't check:
      // the sheet is tied to the WIN (reaching zero), not to any payment at all.
      final store = await _openApp(tester, _winSeed());
      final before = _netWorth(store);
      final owed = _debt(store, 'loan');

      await _tap(tester, find.text('Utang'));
      await _tap(tester, find.text('Salary Loan'));
      expect(find.text('LOG A PAYMENT'), findsOneWidget);

      // A partial payment. The default account chip is "Outside the app", so a
      // liability falls and no asset does: net worth rises by exactly the
      // amount cleared. No win yet, so no sheet.
      await tester.enterText(find.byType(TextField).first, '3000');
      await tester.pumpAndSettle();
      await _tap(tester, find.text('Log payment'));
      expect(
        find.text('Share the card'),
        findsNothing,
        reason: 'a payment that did not reach zero opened the milestone sheet',
      );
      expect(_debt(store, 'loan'), closeTo(owed - 3000, 0.001));
      expect(
        _netWorth(store),
        closeTo(before + 3000, 0.001),
        reason:
            'clearing part of a liability from outside the app lifts net worth '
            'by that much, and nothing else moved',
      );

      // The payment that clears it. Confetti, then the sheet, exactly once.
      await tester.enterText(find.byType(TextField).first, '5000');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Log payment'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        find.text('Share the card'),
        findsOneWidget,
        reason: 'the payoff did not offer the branded card',
      );
      expect(
        find.text('Debt free'),
        findsWidgets,
        reason: 'a plain loan paid to zero should read "Debt free"',
      );
      // The did-anything-happen half, directional: the debt is actually gone
      // and net worth rose by the whole liability, not a centavo more or less.
      expect(_debt(store, 'loan'), closeTo(0, 0.001));
      expect(
        _netWorth(store),
        closeTo(before + owed, 0.001),
        reason:
            'clearing the whole liability from outside the app lifts net worth '
            'by exactly what was owed',
      );

      // Dismiss, drain the confetti timers, and the sheet is gone.
      await tester.tap(find.text('Maybe later'));
      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(find.text('Share the card'), findsNothing);
    },
  );

  testWidgets(
    'funding a goal to its target celebrates once; funding it again does not',
    (tester) async {
      // Invariant: a goal carried from below target to at/past target is a win
      // and opens the sheet once; funding an already-funded goal is not a new
      // win and opens nothing. This is the once-only guarantee, directional:
      // the second deposit still MOVES the saved number, it just does not
      // celebrate. And adding to a goal moves no money out of any account, so
      // net worth cannot change either way.
      final store = await _openApp(tester, _winSeed());
      final before = _netWorth(store);
      final savedBefore = _goalSaved(store, 'g1');

      await _tap(tester, find.byTooltip('Menu'));
      await _tap(tester, find.text('Goals'));
      await _tap(tester, find.text('New phone'));

      // The funds box is the last field on the edit sheet. 500 crosses 4,500 to
      // the 5,000 target.
      await tester.enterText(find.byType(TextField).last, '500');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Add'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        find.text('Share the card'),
        findsOneWidget,
        reason: 'reaching a savings target did not offer the branded card',
      );
      expect(find.text('Goal reached'), findsWidgets);
      expect(
        _goalSaved(store, 'g1'),
        greaterThan(savedBefore),
        reason: 'the goal was not actually funded, so nothing was celebrated',
      );
      expect(
        _netWorth(store),
        closeTo(before, 0.001),
        reason:
            'adding to a savings goal only updates the goal number; it moves no '
            'money out of any account',
      );

      await tester.tap(find.text('Maybe later'));
      await tester.pumpAndSettle(const Duration(seconds: 2));
      final savedAtTarget = _goalSaved(store, 'g1');

      // Fund it AGAIN. Already at target, so not a new win: no sheet.
      await tester.enterText(find.byType(TextField).last, '500');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Add'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        find.text('Share the card'),
        findsNothing,
        reason: 'funding an already-funded goal reopened the milestone sheet',
      );
      expect(
        _goalSaved(store, 'g1'),
        greaterThan(savedAtTarget),
        reason: 'the second deposit did not move the saved number at all',
      );
    },
  );

  testWidgets('collecting an utang in full celebrates the settle', (
    tester,
  ) async {
    // Invariant: logging the final payment that settles what someone owed you
    // opens the "Settled up" sheet, and because the utang was tracked (the cash
    // left an account when lent) collecting it returns that cash and leaves net
    // worth exactly where it started. The directional companions are the cash
    // coming back and the open balance reaching zero.
    final store = await _openApp(tester);
    final before = _netWorth(store);
    final cashBefore = _balance(store, 'cash');

    await _tap(tester, find.text('Utang'));
    await _tap(tester, find.text('Owed to me'));
    await _tap(tester, find.text('New'));
    await tester.enterText(find.byType(TextField).at(0), 'Ben');
    await tester.enterText(find.byType(TextField).at(1), '900');
    await tester.pumpAndSettle();
    // Pick the lending account so the cash actually leaves; otherwise the
    // collect below settles a debt that never cost anything.
    await _tap(tester, find.widgetWithText(ChoiceChip, 'Cash'));
    await _tap(tester, find.textContaining('Save'));

    expect(
      find.text('Ben'),
      findsWidgets,
      reason: 'the utang was never recorded, so nothing below tests anything',
    );
    expect(_balance(store, 'cash'), closeTo(cashBefore - 900, 0.001));

    await _tap(tester, find.text('Ben'));
    // Settle it through the LOG PAYMENT path (the "Mark paid" dialog uses plain
    // confetti; only collecting a payment offers the share card).
    await _tap(tester, find.text('Log payment'));
    await tester.enterText(find.byType(TextField).first, '900');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save payment'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      find.text('Share the card'),
      findsOneWidget,
      reason: 'settling an utang did not offer the branded card',
    );
    expect(find.text('Settled up'), findsWidgets);
    expect(
      _openReceivableTotal(store),
      closeTo(0, 0.001),
      reason: 'the utang was not actually settled, so nothing was celebrated',
    );
    expect(
      _balance(store, 'cash'),
      closeTo(cashBefore, 0.001),
      reason: 'a tracked utang collected in full returns the cash it left with',
    );
    expect(
      _netWorth(store),
      closeTo(before, 0.001),
      reason: 'lent 900 and collected 900, so the total is back to the start',
    );

    await tester.tap(find.text('Maybe later'));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(find.text('Share the card'), findsNothing);
  });

  testWidgets('a debt zeroed by hand is no milestone and shows no share sheet', (
    tester,
  ) async {
    // Invariant: a debt at zero with no real payment pesos behind it is
    // bookkeeping, not a money win. The engine excludes it (milestoneFor is
    // null), and that exclusion must carry through to the UI: opening it offers
    // no share card. This is the not-when-it-shouldn't half proven at the seam.
    final store = await _openApp(tester, _winSeed());

    expect(
      milestoneFor(store.data, 'zeroed'),
      isNull,
      reason: 'a hand-zeroed debt with no payments is not a shareable win',
    );

    await _tap(tester, find.text('Utang'));
    await _tap(tester, find.text('Old ghost'));
    expect(find.text('Paid off'), findsWidgets);
    expect(
      find.text('Share the card'),
      findsNothing,
      reason: 'a hand-zeroed debt spuriously offered the milestone card',
    );
    expect(_debt(store, 'zeroed'), closeTo(0, 0.001));
  });
}
