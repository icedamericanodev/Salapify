// Delivery B: one Add button, and what the answer to it must actually do.
//
// The risk this batch carries is not that the sheet looks wrong. It is that
// the routing is wrong, and routing failures are silent: a car loan saved into
// `accounts` becomes spendable cash on Home and raises net worth instead of
// lowering it, and nothing on screen says so. So most of this file is about
// where a thing LANDS, not what it looks like.
//
// The second risk is the classification leaking into an edit. This sheet does
// not ask what an existing row is, so writing a seed on save would let opening
// and closing an untouched row silently reclassify it.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/money/account_taxonomy.dart';
import 'package:salapify/screens/accounts.dart';
import 'package:salapify/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<SalapifyStore> _store([Map<String, dynamic>? blob]) async {
  SharedPreferences.setMockInitialValues({
    storageKey: jsonEncode(
      blob ??
          {
            'schemaVersion': 12,
            'settings': {'onboarded': true},
          },
    ),
  });
  final s = SalapifyStore();
  await s.load();
  expect(s.canWrite, isTrue, reason: 'the fixture never loaded');
  return s;
}

Future<void> _open(WidgetTester tester, SalapifyStore store) async {
  Barako.current = Barako.currentTheme.resolve(Brightness.dark);
  await tester.pumpWidget(
    MaterialApp(
      theme: salapifyTheme(Barako.current),
      home: AccountsScreen(store: store),
    ),
  );
  await tester.pumpAndSettle();
}

/// Type into the field carrying this hint or label.
///
/// `.first` on purpose: the account form has TWO fields hinted '0', a balance
/// and an optional target, and widgetWithText matching both throws "Bad state:
/// Too many elements" rather than picking one. The balance is always first.
Future<void> _type(WidgetTester t, String hint, String text) async {
  await t.enterText(find.widgetWithText(TextField, hint).first, text);
  await t.pumpAndSettle();
}

/// Tap something, scrolling it into view first.
///
/// This is not test hygiene, it is a bug this file already hit. Adding the
/// institution row pushed the Save button below the fold, and
/// `tester.tap` on an off-screen widget does NOT throw: it dispatches at
/// coordinates the widget does not occupy, the tap silently does nothing, and
/// the assertion afterwards fails with "expected length 1, actual []" fifty
/// lines from the cause. Twenty minutes went into that.
Future<void> _tap(WidgetTester t, Finder f) async {
  await t.ensureVisible(f.first);
  await t.pumpAndSettle();
  await t.tap(f.first);
  await t.pumpAndSettle();
}

List<Map<String, dynamic>> _rows(SalapifyStore s, String key) => [
  for (final r in (s.data[key] as List? ?? const []))
    if (r is Map) r.cast<String, dynamic>(),
];

void main() {
  testWidgets('there is ONE add button, not one per collection', (
    tester,
  ) async {
    // The founder-facing point of the batch. Two buttons asked people to know
    // Salapify's internal split before they could record anything, and a car
    // loan had no button at all.
    await _open(tester, await _store());
    expect(find.text('+ Add an account'), findsOneWidget);
    expect(find.text('+ Account'), findsNothing);
    expect(find.text('+ Asset'), findsNothing);
  });

  testWidgets('the sheet offers both sides of net worth', (tester) async {
    await _open(tester, await _store());
    await _tap(tester, find.text('+ Add an account'));
    expect(find.text('What are you adding?'), findsOneWidget);
    expect(find.text('WHAT YOU HAVE'), findsOneWidget);
    expect(find.text('WHAT YOU OWE'), findsOneWidget);
    // Every category is reachable from the first pane. A category nobody can
    // tap is a whole class of thing Salapify silently cannot record.
    for (final c in accountCategories) {
      // Scrolled to, not just looked for. A ListView does not build its
      // off-screen children, so a plain findsOneWidget would report the last
      // categories missing when they are merely below the fold, and would
      // equally report them present after somebody deleted them if they
      // happened to be on screen.
      await tester.scrollUntilVisible(
        find.text(c.label),
        120,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      expect(find.text(c.label), findsOneWidget, reason: c.id);
    }
  });

  testWidgets('an asset subtype lands in assets, not in accounts', (
    tester,
  ) async {
    // The routing failure that matters most, in the direction that breaks
    // Home: an asset in `accounts` becomes spendable cash and inflates the
    // safe-to-spend figure.
    final store = await _store();
    await _open(tester, store);
    await _tap(tester, find.text('+ Add an account'));
    await _tap(tester, find.text('Property and things'));
    await _tap(tester, find.text('Vehicle'));

    expect(
      find.text('Add vehicle'),
      findsOneWidget,
      reason: 'the form did not confirm what was chosen',
    );
    await _type(tester, 'e.g. GCash', 'Car');
    await _type(tester, '0', '250000');
    await _tap(tester, find.text('Save'));

    expect(_rows(store, 'accounts'), isEmpty, reason: 'a car became cash');
    final assets = _rows(store, 'assets');
    expect(assets, hasLength(1));
    expect(assets.first['value'], 250000);
    expect(assets.first['subtype'], 'vehicle');
    expect(
      assets.first['kind'],
      'vehicle',
      reason:
          'the legacy kind has to be written too, or every existing screen '
          'that groups by kind stops seeing this row',
    );
  });

  testWidgets('a payroll account keeps a LEGAL legacy kind', (tester) async {
    // The whole reason for DECISION 2. `kind` is clamped to four values on
    // every load, so a payroll account must store 'checking' and carry
    // 'payroll_account' separately, or its subtype vanishes permanently.
    final store = await _store();
    await _open(tester, store);
    await _tap(tester, find.text('+ Add an account'));
    await _tap(tester, find.text('Cash and e-wallets'));
    await _tap(tester, find.text('Payroll account'));
    await _type(tester, 'e.g. GCash', 'Salary');
    await _type(tester, '0', '5000');
    await _tap(tester, find.text('Save'));

    final accounts = _rows(store, 'accounts');
    expect(accounts, hasLength(1));
    expect(accounts.first['kind'], 'checking');
    expect(accounts.first['subtype'], 'payroll_account');
    expect(accounts.first['balance'], 5000);
  });

  testWidgets('a credit card goes to the debts form, and lands in debts', (
    tester,
  ) async {
    // The other direction of the routing failure, and the worse one: a debt
    // recorded as an account would RAISE net worth by what you owe.
    final store = await _store();
    await _open(tester, store);
    await _tap(tester, find.text('+ Add an account'));
    // One subtype, so it should skip the second pane entirely rather than
    // showing a list of one.
    await _tap(tester, find.text('Credit cards'));
    expect(
      find.text('Add a debt'),
      findsOneWidget,
      reason: 'a one-subtype category showed a list of one, or misrouted',
    );

    await _type(tester, 'Name, like BPI card or a family loan', 'BPI card');
    await _type(tester, 'Remaining balance', '5000');
    await _tap(tester, find.text('Add debt'));

    expect(_rows(store, 'accounts'), isEmpty);
    expect(_rows(store, 'assets'), isEmpty);
    final debts = _rows(store, 'debts');
    expect(debts, hasLength(1));
    expect(debts.first['remaining'], 5000);
    expect(
      debts.first['type'],
      'credit card',
      reason:
          'the payment engine branches on exactly this string, so a statement '
          'day, a credit limit and pending posting all hang off it',
    );
    expect(debts.first['subtype'], 'credit_card');
  });

  testWidgets('a loan is a debt too, and is NOT typed as a card', (
    tester,
  ) async {
    final store = await _store();
    await _open(tester, store);
    await _tap(tester, find.text('+ Add an account'));
    await _tap(tester, find.text('Loans'));
    await _tap(tester, find.text('Car or motorcycle loan'));
    await _type(tester, 'Name, like BPI card or a family loan', 'Car loan');
    await _type(tester, 'Remaining balance', '180000');
    await _tap(tester, find.text('Add debt'));

    final debts = _rows(store, 'debts');
    expect(debts, hasLength(1));
    expect(
      debts.first['type'],
      isNot('credit card'),
      reason:
          'a car loan typed as a credit card would demand a statement day and '
          'post payments as pending',
    );
    expect(debts.first['subtype'], 'auto_loan');
  });

  testWidgets('editing an existing row never reclassifies it', (tester) async {
    // This sheet does not ask what an existing row is. If a seed reached the
    // save path, opening and saving an untouched account would silently give
    // it a classification nobody chose.
    final store = await _store({
      'schemaVersion': 12,
      'settings': {'onboarded': true},
      'accounts': [
        {'id': 'a1', 'name': 'Wallet', 'kind': 'cash', 'balance': 100},
      ],
    });
    await _open(tester, store);
    await _tap(tester, find.text('Wallet'));
    expect(find.text('Edit account'), findsOneWidget);
    await _tap(tester, find.text('Save'));

    final a = _rows(store, 'accounts').first;
    expect(a['kind'], 'cash');
    expect(a.containsKey('subtype'), isFalse, reason: 'an edit classified it');
    expect(a['balance'], 100);
  });

  testWidgets('backing out of the sheet writes nothing', (tester) async {
    final store = await _store();
    await _open(tester, store);
    await _tap(tester, find.text('+ Add an account'));
    await _tap(tester, find.text('Cash and e-wallets'));
    // Back returns to the category list rather than closing, which is what a
    // two-pane sheet should do.
    await _tap(tester, find.byTooltip('Back'));
    // Asserted on the HEADER and on the subtype pane being gone, not on the
    // "WHAT YOU HAVE" kicker. The category list keeps its scroll position when
    // you come back, which is right, so the kicker is legitimately off the top
    // of the list after _tap scrolled to reach a tile. An assertion that fails
    // because of correct behaviour is a worse test than no assertion.
    expect(find.text('What are you adding?'), findsOneWidget);
    expect(
      find.text('Cash on hand'),
      findsNothing,
      reason: 'Back left the subtype list showing',
    );

    Navigator.of(
      tester.element(find.text('What are you adding?')),
    ).pop();
    await tester.pumpAndSettle();
    expect(_rows(store, 'accounts'), isEmpty);
    expect(_rows(store, 'assets'), isEmpty);
    expect(_rows(store, 'debts'), isEmpty);
  });

  testWidgets('the form does not re-ask what was just chosen', (tester) async {
    // Found by LOOKING at the render, not by reading the code: the two rows
    // are two hundred lines apart in the file and read fine separately.
    //
    // Leaving the Kind chips visible was worse than redundant. Picking
    // "Payroll account" and then flipping the chip to Cash stored
    // kind:'cash' next to subtype:'payroll_account', an account that
    // disagrees with its own classification, which no screen would ever
    // explain and no engine would ever notice.
    final store = await _store();
    await _open(tester, store);
    await _tap(tester, find.text('+ Add an account'));
    await _tap(tester, find.text('Cash and e-wallets'));
    await _tap(tester, find.text('Payroll account'));
    expect(find.text('Kind'), findsNothing);
    expect(find.widgetWithText(ChoiceChip, 'Cash'), findsNothing);
  });

  testWidgets('an edit still gets the Kind chips', (tester) async {
    // The other half. Hiding them everywhere would strand every account that
    // predates this flow with no way to correct its kind.
    final store = await _store({
      'schemaVersion': 12,
      'settings': {'onboarded': true},
      'accounts': [
        {'id': 'a1', 'name': 'Wallet', 'kind': 'cash', 'balance': 100},
      ],
    });
    await _open(tester, store);
    await _tap(tester, find.text('Wallet'));
    expect(find.text('Kind'), findsOneWidget);
  });

  testWidgets('the bank question is asked ONCE, not twice', (tester) async {
    // Also found by looking. The new institution picker sat directly above the
    // old free text "Bank or brand" field: the same question, in different
    // words, with two different answers and nothing saying which one counts.
    final store = await _store();
    await _open(tester, store);
    await _tap(tester, find.text('+ Add an account'));
    await _tap(tester, find.text('Cash and e-wallets'));
    await _tap(tester, find.text('E-wallet'));
    expect(find.text('Bank or wallet (optional)'), findsOneWidget);
    expect(find.text('Bank or brand (optional)'), findsNothing);
  });

  testWidgets('cash on hand is not asked which bank it is in', (tester) async {
    final store = await _store();
    await _open(tester, store);
    await _tap(tester, find.text('+ Add an account'));
    await _tap(tester, find.text('Cash and e-wallets'));
    await _tap(tester, find.text('Cash on hand'));
    expect(find.text('Bank or wallet (optional)'), findsNothing);
  });

  testWidgets('an e-wallet IS asked, and the answer is stored', (tester) async {
    final store = await _store();
    await _open(tester, store);
    await _tap(tester, find.text('+ Add an account'));
    await _tap(tester, find.text('Cash and e-wallets'));
    await _tap(tester, find.text('E-wallet'));
    expect(find.text('Bank or wallet (optional)'), findsOneWidget);

    await _tap(tester, find.text('Choose'));
    await _type(tester, 'Search, or type your own', 'gcash');
    await _tap(tester, find.text('GCash').last);

    await _type(tester, 'e.g. GCash', 'My GCash');
    await _type(tester, '0', '1200');
    await _tap(tester, find.text('Save'));

    final a = _rows(store, 'accounts').first;
    expect(a['institutionId'], 'gcash');
    expect(a['subtype'], 'ewallet');
    expect(a['kind'], 'ewallet');
  });
}
