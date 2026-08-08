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
import 'package:salapify/money/commitments.dart' show liquidKinds;
import 'package:salapify/money/debtmath.dart' show formatMoneyText;
import 'package:salapify/money/format.dart' show formatMoney;
import 'package:salapify/money/goal_plan.dart' show debtGoalFigures;
import 'package:salapify/money/ledger.dart' show amountOf;
import 'package:salapify/money/milestones.dart' show milestoneFor;
import 'package:salapify/money/pan/respond.dart' show planLine;
import 'package:salapify/money/plan.dart' show activePlanOf, planStatus;
import 'package:salapify/money/statements.dart' show netWorthParts;
import 'package:salapify/main.dart';
import 'package:salapify/screens/pan.dart' show PanScreen;
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

String _isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// A store the Sweldo Timeline can project from: spendable cash, a savings pot
/// the timeline must NOT count, and one recurring bill so the projection has
/// something to stand on. The Cash flow screen is reached through the real app
/// (Menu tile or the Home road-ahead card), which passes NO fixed reference
/// date, so this seed has to be stable under the REAL clock: the bill is
/// stamped as already posted this month on purpose, because store.load() posts
/// due recurring items with DateTime.now() and an unstamped bill would debit
/// the seeded balances on some days of the month and not on others, making
/// every figure below depend on when the suite runs.
Map<String, dynamic> _timelineSeed({bool pro = false}) {
  return {
    'schemaVersion': 12,
    'settings': {
      'onboarded': true,
      if (pro) 'pro': true,
      'paydaySchedule': {'mode': 'monthly', 'day': 30},
    },
    'accounts': [
      // Liquid 5,000 against a total of 55,000: the ten-to-one gap is the
      // fixture's whole point. A NOW figure that quietly counted savings as
      // spendable would print a number ten times too rich, and the seam under
      // test could not hide behind two figures that happen to be close.
      {'id': 'cash', 'name': 'Cash', 'kind': 'cash', 'balance': 5000},
      {'id': 'bank', 'name': 'Savings', 'kind': 'savings', 'balance': 50000},
    ],
    'recurring': [
      {
        'id': 'rent',
        'type': 'expense',
        'label': 'Rent',
        'amount': 2000,
        'dayOfMonth': 1,
        // The current month key, so postDueRecurring on load skips it.
        'lastPosted': _isoDate(DateTime.now()).substring(0, 7),
      },
    ],
    'debts': <Map<String, dynamic>>[],
    'categories': <Map<String, dynamic>>[],
    'transactions': <Map<String, dynamic>>[],
    'receivables': <Map<String, dynamic>>[],
  };
}

/// Every real-money blob the app stores, as one comparable string. The what-if
/// journeys assert this is IDENTICAL across a save or a toggle: a scenario is
/// a plan, and a plan that reaches accounts, transactions, debts, receivables,
/// or goals has crossed into the books. Deliberately narrower than
/// _storedState, which the scenario write is SUPPOSED to change (it lives in
/// settings); asserting the whole blob unchanged would fail a working save.
String _realMoney(SalapifyStore store) => jsonEncode({
  'accounts': store.data['accounts'],
  'transactions': store.data['transactions'],
  'debts': store.data['debts'],
  'receivables': store.data['receivables'],
  'goals': store.data['goals'],
});

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

Map<String, dynamic> _goalRow(SalapifyStore store, String id) {
  for (final g in (store.data['goals'] as List)) {
    final m = (g as Map).cast<String, dynamic>();
    if (m['id'] == id) return m;
  }
  fail('no goal $id');
}

/// A goal's contribution history, the rows the detail screen's HISTORY card
/// draws. Read from the store so the assertions stay money checks, not
/// formatter checks.
List<Map<String, dynamic>> _contributions(SalapifyStore store, String id) => [
  for (final c in (_goalRow(store, id)['contributions'] as List? ?? const []))
    (c as Map).cast<String, dynamic>(),
];

/// A debt-payoff goal's DERIVED saved figure, through the same engine call
/// both the Goals list and the goal detail use. Nothing on the goal row
/// stores this number; that is the design under test.
double _debtGoalSaved(SalapifyStore store, String id) => amountOf(
  debtGoalFigures(
    _goalRow(store, id),
    store.data.cast<String, dynamic>(),
  )?['saved'],
);

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

      // The detail screen's Add money sheet. 500 crosses 4,500 to the 5,000
      // target.
      await _tap(tester, find.text('Add money'));
      await tester.enterText(find.widgetWithText(TextField, 'Amount'), '500');
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
      await _tap(tester, find.text('Add money'));
      await tester.enterText(find.widgetWithText(TextField, 'Amount'), '500');
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

  // The Sweldo Timeline journeys. The invariant they all defend: a what if is
  // a PLAN. The card on the screen promises "Only the line changes, never your
  // real money", and these hold the app to that sentence through the real
  // sheet, the real switch, and the real store, while the directional halves
  // prove the plan itself genuinely lands, overlays, and lifts.

  testWidgets('saving a what if changes the plan and not one peso of money', (
    tester,
  ) async {
    final store = await _openApp(tester, _timelineSeed(pro: true));
    final before = _netWorth(store);
    final booksBefore = _realMoney(store);
    expect(
      store.timelineScenarios,
      isEmpty,
      reason: 'seed sanity: the scenario below must be the save under test',
    );

    await _tap(tester, find.byTooltip('Menu'));
    await _tap(tester, find.text('Cash flow'));
    // The 30 day horizon first (a Pro chip, and the seed is Pro). The sheet
    // defaults the purchase date to a week out, which the free month window
    // EXCLUDES whenever the suite runs in the last week of a month; 30 days
    // contains a-week-from-today on every date the calendar has.
    await _tap(tester, find.text('30 days'));
    await _tap(tester, find.text('Add a what if'));
    // Prefilled defaults on purpose, the way a person taps through: the kind
    // stays "A big buy", the date stays a week out, and the name stays empty
    // so the app's own fallback has to label it. Only the amount is typed,
    // because the sheet refuses to save without one.
    await tester.enterText(find.widgetWithText(TextField, 'Amount'), '2500');
    await tester.pumpAndSettle();
    await _tap(tester, find.text('Save'));

    // The invariant, exactly as the card words it: net worth to the centavo,
    // and every account, transaction, debt, receivable, and goal byte for
    // byte. A what if that moved any of them is a transaction wearing a
    // costume.
    expect(
      _netWorth(store),
      closeTo(before, 0.001),
      reason: 'saving a what if moved net worth; a plan spent real money',
    );
    expect(
      _realMoney(store),
      booksBefore,
      reason:
          'saving a what if wrote into the real books, not just the plan '
          'in settings',
    );

    // The did-anything-happen half, directional: the scenario reached
    // settings carrying the 2,500 that was typed two taps ago (the literal is
    // the round trip: entered up there, read back here), and the screen
    // overlays it as an event honestly labeled a what if.
    expect(
      store.timelineScenarios,
      hasLength(1),
      reason:
          'the save never reached the store, so the invariant above held '
          'by doing nothing',
    );
    expect(
      amountOf(store.timelineScenarios.single['amount']),
      closeTo(2500, 0.001),
      reason: 'the scenario arrived with a different amount than was typed',
    );
    expect(
      find.text('A big buy (what if)'),
      findsOneWidget,
      reason: 'the saved what if never overlaid the event list',
    );

    // And the plan survives the disk, like any other write in this file: a
    // scenario that evaporates on restart looks like the app eating the plan.
    final reopened = SalapifyStore();
    await reopened.load();
    expect(
      reopened.timelineScenarios,
      hasLength(1),
      reason: 'the what if was never persisted, so a restart loses it',
    );
    expect(
      amountOf(reopened.timelineScenarios.single['amount']),
      closeTo(2500, 0.001),
    );
  });

  testWidgets('the timeline NOW figure is the spendable cash the store holds', (
    tester,
  ) async {
    // The cross-screen agreement check: the figure the Cash flow screen calls
    // NOW must be the same money the rest of the app calls spendable, the
    // liquid accounts only. Savings sit one field away in the same list, so
    // the plausible wrong number is the total, and a person who keeps their
    // ipon untouched would read that as the app inviting them to spend it.
    final store = await _openApp(tester, _timelineSeed());

    // Both sums from the store through the app's own liquidKinds rule, not
    // hand-copied from the seed, so a fixture edit cannot silently detune the
    // check. The seed guarantees they differ tenfold.
    var liquid = 0.0;
    var total = 0.0;
    for (final a in (store.data['accounts'] as List)) {
      final m = (a as Map).cast<String, dynamic>();
      total += amountOf(m['balance']);
      if (liquidKinds.contains(m['kind'])) liquid += amountOf(m['balance']);
    }
    expect(liquid, closeTo(5000, 0.001), reason: 'seed sanity: the cash');
    expect(
      total,
      closeTo(55000, 0.001),
      reason: 'seed sanity: cash plus the savings the timeline must not touch',
    );

    // In through the front door a person actually uses: the road-ahead card
    // on Home, which only renders because the seed has something projectable.
    await _tap(tester, find.text('CASH AHEAD'));
    expect(find.text('NOW'), findsOneWidget);
    // Rendered through the same formatMoneyText the screen uses, so this
    // stays a money test and never becomes a formatter test: a grouping or
    // rounding change moves both sides at once.
    expect(
      find.text(formatMoneyText(liquid)),
      findsWidgets,
      reason: 'the NOW figure disagrees with the liquid sum the store holds',
    );
    expect(
      find.text(formatMoneyText(total)),
      findsNothing,
      reason:
          'the savings-inflated total appears on the timeline; the projection '
          'is counting money the person is protecting',
    );
  });

  testWidgets('flipping a what if off lifts the overlay and touches nothing', (
    tester,
  ) async {
    // The scenario arrives from PERSISTED settings, the shape a backup or a
    // previous session leaves behind, so this also covers the read seam the
    // save journey cannot: written by one session, obeyed by the next.
    final seed = _timelineSeed(pro: true);
    final now = DateTime.now();
    (seed['settings'] as Map)['timelineScenarios'] = [
      {
        'kind': 'purchase',
        'label': 'Beach trip',
        // 3,000 a week out: like the sheet's own default, always inside the
        // 30 day window the journey selects, whatever today's real date is.
        'amount': 3000,
        'date': _isoDate(DateTime(now.year, now.month, now.day + 7)),
        'on': true,
      },
    ];
    final store = await _openApp(tester, seed);
    final before = _netWorth(store);
    final booksBefore = _realMoney(store);

    await _tap(tester, find.byTooltip('Menu'));
    await _tap(tester, find.text('Cash flow'));
    await _tap(tester, find.text('30 days'));
    expect(
      find.text('Beach trip (what if)'),
      findsOneWidget,
      reason:
          'the persisted scenario never overlaid, so the toggle below has '
          'nothing to prove',
    );

    // Off. The overlay must lift AND the off state must reach the store;
    // either alone is the switch lying in one direction.
    await _tap(tester, find.byType(Switch));
    expect(
      find.text('Beach trip (what if)'),
      findsNothing,
      reason: 'switched off, but the what if still shapes the event list',
    );
    expect(
      store.timelineScenarios.single['on'],
      isFalse,
      reason:
          'the row disappeared but the store still says on; a reopen would '
          'bring the overlay back',
    );
    expect(
      find.text('Beach trip'),
      findsOneWidget,
      reason: 'off must silence the scenario, not delete it from the card',
    );

    // And back on, so the switch is proven directional both ways rather than
    // a one-way trapdoor.
    await _tap(tester, find.byType(Switch));
    expect(
      find.text('Beach trip (what if)'),
      findsOneWidget,
      reason: 'switched back on, but the overlay never returned',
    );
    expect(store.timelineScenarios.single['on'], isTrue);

    // Toggling a plan is bookkeeping about a hypothetical: no direction of it
    // may move real money.
    expect(
      _netWorth(store),
      closeTo(before, 0.001),
      reason: 'toggling a what if moved net worth',
    );
    expect(
      _realMoney(store),
      booksBefore,
      reason: 'toggling a what if wrote into the real books',
    );
  });

  // The Pan With a Plan journeys. The invariant they defend: a plan is a
  // PROMISE, not a transaction. Making one, keeping score on one, and dropping
  // one may never move a peso. The money only ever moves through the real pay
  // flow on the debts screen, and the plan must then agree with the debt about
  // exactly how much moved, because Pan's card, Pan's chat reply, and the
  // debts screen all read the same store and none of them is told about the
  // others.

  testWidgets(
    'a plan made in Pan keeps score against a payment made on the debts screen',
    (tester) async {
      final store = await _openApp(tester);
      final worthAtStart = _netWorth(store);
      final booksBefore = _realMoney(store);

      // Pan lives behind the Menu's Ask Pan banner.
      await _tap(tester, find.byTooltip('Menu'));
      await _tap(tester, find.text('Ask Pan'));

      // Ask the debt-free question with an extra amount, the way the offer is
      // born. 1500 is a round-trip literal: typed into the question here, read
      // back out of the stored plan below, so it justifies itself.
      await tester.enterText(
        find.byType(TextField),
        'When will I be debt free with 1500 extra?',
      );
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pumpAndSettle();
      await _tap(tester, find.textContaining('Make it a plan'));

      final plan = activePlanOf(store.data.cast<String, dynamic>());
      expect(
        plan,
        isNotNull,
        reason: 'the offer chip wrote no plan, so nothing below tests anything',
      );
      expect(
        amountOf(plan!['amount']),
        closeTo(1500, 0.001),
        reason: 'the plan arrived with a different amount than was asked',
      );
      expect(
        plan['targetId'],
        'card',
        reason: 'the offer must follow the only open debt in the seed',
      );
      expect(
        amountOf(plan['startLevel']),
        closeTo(_debt(store, 'card'), 0.001),
        reason:
            'startLevel is the debt the day the plan was made; every peso of '
            'progress below is measured from here',
      );
      expect(find.text('OUR PLAN'), findsOneWidget);

      // The promise half of the invariant: making a plan moved nothing.
      expect(
        _netWorth(store),
        closeTo(worthAtStart, 0.001),
        reason: 'making a plan moved net worth; a promise spent real money',
      );
      expect(
        _realMoney(store),
        booksBefore,
        reason: 'making a plan wrote into the real books, not just settings',
      );

      // Time passes: age the plan by one monthly period so the score line
      // below speaks in numbers instead of the just-started greeting. Test
      // scaffolding, said out loud: the app has no control that moves time,
      // and only startDate is touched, the one field the calendar owns. 32
      // days is always exactly one completed monthly period and never two,
      // because the second anniversary is at least 59 days out.
      await store.setActivePlan({
        ...plan,
        'startDate': _isoDate(
          DateTime.now().subtract(const Duration(days: 32)),
        ),
      });

      // Back out of Pan and Menu the way a person does, then pay the debt
      // through the real pay flow on the Utang tab.
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();

      final owedBefore = _debt(store, 'card');
      final cashBefore = _balance(store, 'cash');
      await _tap(tester, find.text('Utang'));
      await _tap(tester, find.text('BPI card'));
      // The prefilled minimum, 1000 in this seed, paid from Cash: the default
      // a real person taps straight through, same as the older debt journey.
      expect(find.text('LOG A PAYMENT'), findsOneWidget);
      await _tap(tester, find.text('Cash'));
      await _tap(tester, find.text('Log payment'));
      // The payment sheet stays open for another entry; close it the way a
      // person does, tapping outside it, or the Menu tap below lands on the
      // sheet's barrier and silently does nothing.
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      // The invariant: paying a debt cannot change net worth.
      expect(
        _netWorth(store),
        closeTo(worthAtStart, 0.001),
        reason:
            'paying the debt moved net worth. An asset fell and a liability '
            'fell by the same amount, so the total cannot have changed.',
      );
      // Directional: the debt fell by the prefilled minimum, the cash left,
      // and the plan scored exactly the amount paid. The last line is the seam
      // under test: the payment happened on the debts screen and the plan saw
      // it without either feature knowing about the other.
      expect(_debt(store, 'card'), closeTo(owedBefore - 1000, 0.001));
      expect(_balance(store, 'cash'), closeTo(cashBefore - 1000, 0.001));
      final status = planStatus(
        store.data.cast<String, dynamic>(),
        DateTime.now(),
      );
      expect(status, isNotNull);
      expect(
        amountOf(status!['actual']),
        closeTo(owedBefore - _debt(store, 'card'), 0.001),
        reason:
            "the plan's actual must be exactly the movement of the debt it "
            'points at',
      );
      expect(
        amountOf(status['actual']),
        closeTo(1000, 0.001),
        reason: 'the plan scored a different amount than was paid',
      );

      // Back into Pan. The card's progress bar must draw the engine's own
      // fraction, computed here from the same status rather than a literal so
      // a fixture edit cannot detune it. Scoped to PanScreen because Home
      // keeps its own progress bars alive in the tree behind the route.
      await _tap(tester, find.byTooltip('Menu'));
      await _tap(tester, find.text('Ask Pan'));
      final actual = amountOf(status['actual']);
      final remaining = amountOf(status['remaining']);
      final bar = tester.widget<LinearProgressIndicator>(
        find.descendant(
          of: find.byType(PanScreen),
          matching: find.byType(LinearProgressIndicator),
        ),
      );
      expect(
        bar.value,
        closeTo(actual / (actual + remaining), 0.001),
        reason: "the plan card's progress bar disagrees with the engine",
      );

      // Ask, and demand ONE story: the chat reply and the plan card must both
      // render the exact planLine the engine computes over this store, which
      // after one period and one payment speaks the paid amount out loud.
      await tester.enterText(find.byType(TextField), 'how is my plan');
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pumpAndSettle();
      final line = planLine(
        planStatus(store.data.cast<String, dynamic>(), DateTime.now())!,
      );
      // The question Pan owns must never draw the not-understood fallback
      // while a plan stands. Asserted by name because that is exactly how
      // this journey first failed for real: the resolver's facts spread let
      // the plan's own kind overwrite the facts kind, respond() missed its
      // 'plan' case, and only the card behind the chat kept the single-screen
      // test green.
      expect(
        find.text('I did not catch that one.'),
        findsNothing,
        reason:
            "Pan answered 'how is my plan' with the fallback while a plan "
            'stands',
      );
      expect(
        line,
        contains(formatMoneyText(1000)),
        reason:
            'sanity: after one period the plan line must speak the paid '
            'amount, or the agreement check below compares empty sentences',
      );
      expect(
        find.text(line),
        findsNWidgets(2),
        reason:
            'the plan card and the chat reply must tell the same story the '
            'engine tells; a count of one means two surfaces disagree about '
            'the same plan',
      );

      // And the whole thing survives the disk, like every write in this file:
      // a plan that never reaches storage is a promise the app forgets on
      // restart, which reads exactly like Pan eating the commitment.
      final reopened = SalapifyStore();
      await reopened.load();
      final planOnDisk = activePlanOf(reopened.data.cast<String, dynamic>());
      expect(
        planOnDisk,
        isNotNull,
        reason: 'the plan never reached storage, so a restart forgets it',
      );
      expect(amountOf(planOnDisk!['amount']), closeTo(1500, 0.001));
      expect(
        amountOf(
          planStatus(
            reopened.data.cast<String, dynamic>(),
            DateTime.now(),
          )!['actual'],
        ),
        closeTo(1000, 0.001),
        reason: 'reloaded from disk, the plan must still score the payment',
      );
    },
  );

  testWidgets('dropping the plan in Pan forgets the promise, not the money', (
    tester,
  ) async {
    // The plan arrives from PERSISTED settings, the shape a previous session
    // leaves behind, so this also covers the read seam the journey above
    // cannot: written by one session, obeyed and then dropped by the next.
    final seed = _seed();
    ((seed['settings'] as Map).cast<String, dynamic>())['activePlan'] = {
      'kind': 'debt',
      'targetId': 'card',
      'label': 'Extra to BPI card',
      // The same pace the offer chip writes in the journey above, one monthly
      // period old, started level with the debt as the chip would have written
      // it. All of it is inert for a drop; it only makes this a real
      // mid-flight plan rather than an empty one.
      'amount': 1500,
      'cadence': 'monthly',
      'startDate': _isoDate(DateTime.now().subtract(const Duration(days: 32))),
      'startLevel': 8000,
    };
    final store = await _openApp(tester, seed);
    final before = _netWorth(store);
    final booksBefore = _realMoney(store);
    final owedBefore = _debt(store, 'card');
    expect(
      activePlanOf(store.data.cast<String, dynamic>()),
      isNotNull,
      reason: 'seed sanity: the plan to drop must exist and be valid',
    );

    await _tap(tester, find.byTooltip('Menu'));
    await _tap(tester, find.text('Ask Pan'));
    expect(find.text('OUR PLAN'), findsOneWidget);
    await _tap(tester, find.text('Drop the plan'));
    // Dropping asks first, because the start date and level cannot come back.
    // Confirm, through the dialog's own button.
    await _tap(tester, find.text('Drop it'));

    // Directional: the plan is genuinely gone, from the store and the card,
    // and Pan hands over a receipt in chat.
    expect(
      activePlanOf(store.data.cast<String, dynamic>()),
      isNull,
      reason: 'Drop did not clear the stored plan',
    );
    expect(find.text('OUR PLAN'), findsNothing);
    expect(
      find.textContaining('Plan dropped.'),
      findsOneWidget,
      reason: 'the drop left no receipt in chat',
    );

    // Ask, on the same screen, and Pan must not claim memory it no longer
    // holds: the same question the journey above got a score line for now has
    // to say there is no plan.
    await tester.enterText(find.byType(TextField), 'how is my plan');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();
    expect(
      find.textContaining('We do not have a standing plan yet'),
      findsOneWidget,
      reason: 'asked after the drop, Pan still spoke about a dropped plan',
    );

    // The invariant: dropping a plan never moves money.
    expect(
      _netWorth(store),
      closeTo(before, 0.001),
      reason: 'dropping the plan moved net worth',
    );
    expect(
      _realMoney(store),
      booksBefore,
      reason: 'dropping the plan wrote into the real books',
    );

    // And the debts screen agrees, on the screen a person would go check: the
    // debt the plan pointed at still owes exactly what it owed.
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await _tap(tester, find.text('Utang'));
    expect(_debt(store, 'card'), closeTo(owedBefore, 0.001));
    expect(
      find.text(formatMoney(owedBefore)),
      findsWidgets,
      reason:
          'the debts screen does not show the untouched remaining through the '
          "same formatter the screen uses, so it disagrees with the store",
    );

    // A drop that evaporates on restart resurrects the plan.
    final reopened = SalapifyStore();
    await reopened.load();
    expect(
      activePlanOf(reopened.data.cast<String, dynamic>()),
      isNull,
      reason: 'the drop never reached storage, so a restart brings it back',
    );
  });

  // The Goals redesign journeys. The invariants they defend: a goal tracks a
  // NUMBER, so nothing done on a goal screen may move a peso of real money,
  // and a debt-payoff goal is a VIEW of its debt, so the debt screens move it
  // without Goals ever writing. Both are conservation-shaped, so every one of
  // them carries directional companions: the per-goal movement by name, the
  // history rows the movement leaves behind, or the stored blob proven
  // unchanged where unchanged is the feature.

  testWidgets(
    'moving money between two goals is bookkeeping both cards can retell',
    (tester) async {
      // Two savings goals in the seed; the money to move is added first
      // through the real Add money sheet, so the whole story (add, then
      // move) went through screens a person actually touches.
      final seed = _seed();
      seed['goals'] = [
        {'id': 'fund', 'name': 'Emergency fund', 'target': 30000, 'saved': 0},
        {'id': 'trip', 'name': 'Palawan trip', 'target': 20000, 'saved': 500},
      ];
      final store = await _openApp(tester, seed);
      final worthAtStart = _netWorth(store);

      await _tap(tester, find.byTooltip('Menu'));
      await _tap(tester, find.text('Goals'));
      await _tap(tester, find.text('Emergency fund'));

      // Add 2,000 through the sheet. A round-trip literal: typed here, read
      // back out of the store two lines down. Well short of the 30,000
      // target on purpose, so no milestone sheet interrupts the journey.
      await _tap(tester, find.text('Add money'));
      await tester.enterText(find.widgetWithText(TextField, 'Amount'), '2000');
      await tester.pumpAndSettle();
      await _tap(tester, find.text('Add'));
      expect(
        _goalSaved(store, 'fund'),
        closeTo(2000, 0.001),
        reason: 'the add never landed, so the move below has nothing to move',
      );

      final sumBefore = _goalSaved(store, 'fund') + _goalSaved(store, 'trip');
      final fundRowsBefore = _contributions(store, 'fund').length;
      final tripRowsBefore = _contributions(store, 'trip').length;

      // Move part of it through the real sheet. The destination stays the
      // prefilled default on purpose (the only other goal is preselected);
      // a test that re-picks it would never notice the default breaking.
      // 750.25 rather than a round number, so a leg that rounds or floors
      // centavos cannot pass.
      await _tap(tester, find.text('Move money to another goal'));
      await tester.enterText(
        find.widgetWithText(TextField, 'Amount to move'),
        '750.25',
      );
      await tester.pumpAndSettle();
      await _tap(tester, find.text('Move'));

      // The invariants: net worth to the centavo, and the two goals' sum,
      // because a move between two tracked numbers cannot create or destroy
      // a peso.
      expect(
        _netWorth(store),
        closeTo(worthAtStart, 0.001),
        reason:
            'goal bookkeeping moved net worth; a tracked number crossed into '
            'the real books',
      );
      expect(
        _goalSaved(store, 'fund') + _goalSaved(store, 'trip'),
        closeTo(sumBefore, 0.001),
        reason: 'the move minted or ate money between the two goals',
      );
      // Directional, per goal, because both invariants above also hold when
      // the move silently does nothing: the source fell by exactly the
      // amount and the destination rose by exactly the amount.
      expect(
        _goalSaved(store, 'fund'),
        closeTo(2000 - 750.25, 0.001),
        reason: 'the source goal did not fall by exactly what was moved',
      );
      expect(
        _goalSaved(store, 'trip'),
        closeTo(500 + 750.25, 0.001),
        reason: 'the destination goal did not rise by exactly what was moved',
      );
      // And both sides carry the story as a new history row: negative on the
      // source, positive on the destination, each saying which way it went.
      final outRows = _contributions(store, 'fund');
      final inRows = _contributions(store, 'trip');
      expect(outRows.length, fundRowsBefore + 1);
      expect(inRows.length, tripRowsBefore + 1);
      expect(amountOf(outRows.last['amount']), closeTo(-750.25, 0.001));
      expect(outRows.last['note'], 'moved to another goal');
      expect(amountOf(inRows.last['amount']), closeTo(750.25, 0.001));
      expect(inRows.last['note'], 'moved from another goal');
      // The detail screen's own HISTORY card retells it where the person
      // stands.
      expect(
        find.text('moved to another goal'),
        findsOneWidget,
        reason: 'the source history card does not show the move',
      );

      // Back on the list, the headline total agrees with the engine sum,
      // through the same formatMoney the screen uses.
      await tester.pageBack();
      await tester.pumpAndSettle();
      final total = _goalSaved(store, 'fund') + _goalSaved(store, 'trip');
      expect(
        find.text(
          '${formatMoney(total)} put toward 2 active goals. '
          'This money stays in your accounts; goals just earmark it.',
        ),
        findsOneWidget,
        reason: 'the Goals list total disagrees with the store after the move',
      );

      // And it all survives the disk: a move that lives only in memory is
      // half the money gone on restart.
      final reopened = SalapifyStore();
      await reopened.load();
      expect(_goalSaved(reopened, 'fund'), closeTo(2000 - 750.25, 0.001));
      expect(_goalSaved(reopened, 'trip'), closeTo(500 + 750.25, 0.001));
      expect(
        _contributions(reopened, 'fund').last['note'],
        'moved to another goal',
        reason: 'the source history row never reached storage',
      );
      expect(
        _contributions(reopened, 'trip').last['note'],
        'moved from another goal',
        reason: 'the destination history row never reached storage',
      );
    },
  );

  testWidgets(
    'a debt payoff goal follows payments logged on the debts screen',
    (tester) async {
      // The goal row is seeded in exactly the shape the create screen's Debt
      // payoff template writes (goal_create.dart: kind debt, linkedDebtId,
      // startLevel = the balance at creation, target stored 0). Seeded rather
      // than driven through the create screen because the seam under test is
      // DOWNSTREAM of creation: a payment logged on the debts screen must
      // move the goal without Goals writing anything.
      final seed = _seed();
      seed['goals'] = [
        {
          'id': 'gdebt',
          'name': 'Goodbye BPI',
          'kind': 'debt',
          'linkedDebtId': 'card',
          'target': 0,
          'saved': 0,
          'startLevel': 8000,
        },
      ];
      final store = await _openApp(tester, seed);
      final worthAtStart = _netWorth(store);
      final owedBefore = _debt(store, 'card');
      final cashBefore = _balance(store, 'cash');
      final goalsBlobBefore = jsonEncode(store.data['goals']);
      expect(
        _debtGoalSaved(store, 'gdebt'),
        closeTo(0, 0.001),
        reason:
            'seed sanity: nothing paid yet, so the derived progress below is '
            'entirely the payment under test',
      );

      // Pay through the real debts screen, the prefilled minimum (1000 in
      // this seed) from Cash: the default a person taps straight through.
      await _tap(tester, find.text('Utang'));
      await _tap(tester, find.text('BPI card'));
      expect(find.text('LOG A PAYMENT'), findsOneWidget);
      await _tap(tester, find.text('Cash'));
      await _tap(tester, find.text('Log payment'));
      // The payment sheet stays open for another entry; close it the way a
      // person does, tapping outside it.
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      // The invariant: paying a debt cannot change net worth. An asset fell
      // by 1,000 and a liability fell by 1,000.
      expect(
        _netWorth(store),
        closeTo(worthAtStart, 0.001),
        reason: 'paying the debt moved net worth',
      );
      // Directional: the debt fell by exactly the payment, the cash left,
      // and the goal's DERIVED saved rose by the same amount.
      expect(_debt(store, 'card'), closeTo(owedBefore - 1000, 0.001));
      expect(_balance(store, 'cash'), closeTo(cashBefore - 1000, 0.001));
      expect(
        _debtGoalSaved(store, 'gdebt'),
        closeTo(1000, 0.001),
        reason:
            'the payment on the debts screen did not move the linked goal '
            'forward',
      );
      // WITHOUT any goal write: the goal is a view of the debt, and a write
      // here would be the same peso stored twice. Byte for byte on purpose;
      // unchanged is the feature.
      expect(
        jsonEncode(store.data['goals']),
        goalsBlobBefore,
        reason:
            'the goal moved because something wrote to it; a debt goal must '
            'derive, never copy',
      );

      // The Goals list retells the payment, through the same engine call and
      // the same formatMoney the card uses.
      await _tap(tester, find.byTooltip('Menu'));
      await _tap(tester, find.text('Goals'));
      final figures = debtGoalFigures(
        _goalRow(store, 'gdebt'),
        store.data.cast<String, dynamic>(),
      )!;
      final figure =
          '${formatMoney(amountOf(figures['saved']))} of '
          '${formatMoney(amountOf(figures['target']))}';
      expect(
        find.text(figure),
        findsOneWidget,
        reason: 'the Goals card does not show the payment as progress',
      );
      expect(
        find.text('Moves with the payments you log on the debt.'),
        findsOneWidget,
        reason: 'the card no longer says where a debt goal moves from',
      );

      // The detail screen tells the same story, and offers no Add money of
      // its own: a debt goal that could be funded by hand would count the
      // same peso twice.
      await _tap(tester, find.text('Goodbye BPI'));
      expect(
        find.text(figure),
        findsOneWidget,
        reason: 'the goal detail disagrees with the list about the progress',
      );
      expect(find.text('LINKED TO YOUR DEBT'), findsOneWidget);
      expect(
        find.text('Add money'),
        findsNothing,
        reason:
            'a debt goal offered its own Add money; its add is the debt '
            'payment flow, or a peso gets counted twice',
      );

      // And the progress survives the disk, because what persists is the
      // DEBT: the derived figure must come back identical on reload.
      final reopened = SalapifyStore();
      await reopened.load();
      expect(
        _debtGoalSaved(reopened, 'gdebt'),
        closeTo(1000, 0.001),
        reason:
            'reloaded from disk, the goal no longer shows the payment; the '
            'debt write never persisted',
      );
    },
  );
}
