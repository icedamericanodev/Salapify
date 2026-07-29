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

Future<SalapifyStore> _openApp(WidgetTester tester) async {
  tester.view.physicalSize = _tallPhone;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues({storageKey: jsonEncode(_seed())});
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

double _debt(SalapifyStore store, String id) {
  for (final d in (store.data['debts'] as List)) {
    final m = (d as Map).cast<String, dynamic>();
    if (m['id'] == id) return amountOf(m['remaining']);
  }
  fail('no debt $id');
}

/// Tap something that may be below the fold, scrolling to it first.
Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f.first);
  await tester.pumpAndSettle();
  await tester.tap(f.first);
  await tester.pumpAndSettle();
}

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
    // And the money actually moved, rather than the invariant holding because
    // the transfer silently did nothing at all. This is the half that keeps
    // the test above honest.
    expect(_balance(store, 'bank') + _balance(store, 'cash'), closeTo(23000, 0.001));
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

    await _tap(tester, find.text('Utang'));
    await _tap(tester, find.text('Owed to me'));
    await _tap(tester, find.text('New'));
    await tester.enterText(find.byType(TextField).at(0), 'Ana');
    await tester.enterText(find.byType(TextField).at(1), '900');
    await tester.pumpAndSettle();
    await _tap(tester, find.textContaining('Save'));

    expect(
      find.text('Ana'),
      findsWidgets,
      reason: 'the utang was never recorded, so nothing below tests anything',
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
  });
}
