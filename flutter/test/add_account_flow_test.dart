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
import 'package:salapify/screens/add_account_flow.dart' show InstitutionAvatar;
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

/// Scroll the account list until [f] is on screen, so a lazy row far below the
/// redesigned hero, Available card and carousel actually builds before a tap or
/// a check reads it. The account list is the first Scrollable; inside a modal
/// sheet use _tap (ensureVisible) instead, its rows are already built.
Future<void> _reveal(WidgetTester t, Finder f) async {
  // Pass the base finder, never f.first: scrollUntilVisible evaluates it while
  // the row is still off-screen and unbuilt, and calling .first on an empty
  // finder throws "No element" instead of scrolling.
  await t.scrollUntilVisible(f, 200, scrollable: find.byType(Scrollable).first);
  await t.pumpAndSettle();
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
    expect(find.text('Add an account'), findsOneWidget);
    expect(find.text('+ Account'), findsNothing);
    expect(find.text('+ Asset'), findsNothing);
  });

  testWidgets('the sheet offers both sides of net worth', (tester) async {
    await _open(tester, await _store());
    await _tap(tester, find.text('Add an account'));
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
    await _tap(tester, find.text('Add an account'));
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
    await _tap(tester, find.text('Add an account'));
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
    await _tap(tester, find.text('Add an account'));
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
    await _tap(tester, find.text('Add an account'));
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
    await _reveal(tester, find.text('Wallet'));
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
    await _tap(tester, find.text('Add an account'));
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

    Navigator.of(tester.element(find.text('What are you adding?'))).pop();
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
    await _tap(tester, find.text('Add an account'));
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
    await _reveal(tester, find.text('Wallet'));
    await _tap(tester, find.text('Wallet'));
    expect(find.text('Kind'), findsOneWidget);
  });

  testWidgets('the bank question is asked ONCE, not twice', (tester) async {
    // Also found by looking. The new institution picker sat directly above the
    // old free text "Bank or brand" field: the same question, in different
    // words, with two different answers and nothing saying which one counts.
    final store = await _store();
    await _open(tester, store);
    await _tap(tester, find.text('Add an account'));
    await _tap(tester, find.text('Cash and e-wallets'));
    await _tap(tester, find.text('E-wallet'));
    expect(find.text('Bank or wallet (optional)'), findsOneWidget);
    expect(find.text('Bank or brand (optional)'), findsNothing);
  });

  testWidgets('a chosen bank leaves the icon empty, so initials can show', (
    tester,
  ) async {
    // The account icon is USER data: it lives in the backup file and CLAUDE.md
    // is explicit that Salapify never replaces one. So the row can only show a
    // bank's initials where the field is genuinely empty, and that means the
    // save path must NOT write the default money emoji over a chosen bank.
    // Writing it would make "left blank" and "picked the money emoji" the same
    // stored value, and the row would have to guess which.
    final store = await _store();
    await _open(tester, store);
    await _tap(tester, find.text('Add an account'));
    await _tap(tester, find.text('Cash and e-wallets'));
    await _tap(tester, find.text('E-wallet'));
    await _tap(tester, find.text('Choose'));
    await _type(tester, 'Search, or type your own', 'gcash');
    await _tap(tester, find.text('GCash').last);
    await _type(tester, 'e.g. GCash', 'My GCash');
    await _type(tester, '0', '1200');
    await _tap(tester, find.text('Save'));

    final a = _rows(store, 'accounts').first;
    expect(a['icon'], '');
    expect(a['institutionId'], 'gcash');
    // And the list actually draws the bank's avatar rather than a blank gap.
    // GCash now ships a bundled logo, so the avatar draws the mark; a bank with
    // no logo still draws initials. Either way the row renders the institution
    // avatar for the chosen bank, which is the "not a blank gap" guarantee this
    // check is really about (the icon-not-overwritten rule is the two asserts
    // above).
    await _reveal(
      tester,
      find.byWidgetPredicate((w) => w is InstitutionAvatar && w.id == 'gcash'),
    );
    expect(
      find.byWidgetPredicate((w) => w is InstitutionAvatar && w.id == 'gcash'),
      findsOneWidget,
    );
  });

  testWidgets('a TYPED icon always wins over the bank initials', (
    tester,
  ) async {
    // The other half, and the one the icon rule is really about. Somebody who
    // picked an emoji keeps it, whatever bank they also chose.
    final store = await _store();
    await _open(tester, store);
    await _tap(tester, find.text('Add an account'));
    await _tap(tester, find.text('Cash and e-wallets'));
    await _tap(tester, find.text('E-wallet'));
    await _tap(tester, find.text('Choose'));
    await _type(tester, 'Search, or type your own', 'gcash');
    await _tap(tester, find.text('GCash').last);
    await _type(tester, 'e.g. GCash', 'My GCash');
    await _type(tester, '0', '1200');
    await _type(tester, '💵', '🐷');
    await _tap(tester, find.text('Save'));

    final a = _rows(store, 'accounts').first;
    expect(a['icon'], '🐷');
    expect(a['institutionId'], 'gcash');
    await _reveal(tester, find.text('🐷'));
    expect(find.text('🐷'), findsOneWidget);
    expect(find.text('GC'), findsNothing, reason: 'the choice was overwritten');
  });

  testWidgets('an account that predates all of this keeps its emoji', (
    tester,
  ) async {
    final store = await _store({
      'schemaVersion': 12,
      'settings': {'onboarded': true},
      'accounts': [
        {
          'id': 'a1',
          'name': 'Old wallet',
          'kind': 'ewallet',
          'icon': '💵',
          'balance': 100,
        },
      ],
    });
    await _open(tester, store);
    await _reveal(tester, find.text('💵'));
    expect(find.text('💵'), findsOneWidget);
  });

  testWidgets('choosing a foreign currency WARNS before it is saved', (
    tester,
  ) async {
    // The consequence is stated at the moment of choosing. Somebody who
    // records a dollar account and is not told it sits outside their peso
    // totals will read a net worth that silently omits it, and a missing
    // feature is visible where a wrong total is not.
    final store = await _store();
    await _open(tester, store);
    await _tap(tester, find.text('Add an account'));
    await _tap(tester, find.text('Cash and e-wallets'));
    await _tap(tester, find.text('Savings account'));
    expect(find.text('Currency'), findsOneWidget);
    expect(
      find.textContaining('will NOT be counted'),
      findsNothing,
      reason: 'a peso account was warned about for no reason',
    );

    await _tap(tester, find.text('PHP  ₱'));
    await _tap(tester, find.textContaining('USD'));
    expect(find.textContaining('will NOT be counted'), findsOneWidget);

    await _type(tester, 'e.g. GCash', 'Chase');
    await _type(tester, '0', '1000');
    await _tap(tester, find.text('Save'));

    final a = _rows(store, 'accounts').first;
    expect(a['currencyCode'], 'USD');
    // And the list says so where the total is, not only in the form. With no
    // rate cached, the sentence is the no-rate branch of the conversion rules
    // and it OFFERS a way out rather than just stating a limit.
    expect(find.textContaining('no rate for USD'), findsOneWidget);
    expect(find.text('Set a USD rate'), findsOneWidget);
    // The row amount sits below the redesigned hero, so scroll it into view.
    await _reveal(tester, find.text('\$1,000.00'));
    expect(find.text('\$1,000.00'), findsOneWidget);
  });

  testWidgets('the base currency is NOT stored as a per-row code', (
    tester,
  ) async {
    // A row that just restates the app setting is noise that would have to be
    // kept in step with it forever. Absent means "the app's currency", which
    // is what every row in every existing backup already means.
    final store = await _store();
    await _open(tester, store);
    await _tap(tester, find.text('Add an account'));
    await _tap(tester, find.text('Cash and e-wallets'));
    await _tap(tester, find.text('Savings account'));
    await _tap(tester, find.text('PHP  ₱'));
    await _tap(tester, find.textContaining('PHP'));
    await _type(tester, 'e.g. GCash', 'BPI');
    await _type(tester, '0', '1000');
    await _tap(tester, find.text('Save'));

    final a = _rows(store, 'accounts').first;
    expect(a.containsKey('currencyCode'), isFalse);
    expect(find.textContaining('not counted'), findsNothing);
  });

  testWidgets('a typed rate converts the total, and the screen says so', (
    tester,
  ) async {
    // The manual rate path, driven end to end. The offer to enter one is
    // useless if the value it stores never reaches a total, and a branch that
    // reads as live code while being unreachable is a defect this session has
    // already found once.
    final store = await _store({
      'schemaVersion': 12,
      'settings': {'onboarded': true},
      'accounts': [
        {'id': 'a', 'name': 'Cash', 'kind': 'cash', 'balance': 5000},
        {
          'id': 'b',
          'name': 'Chase',
          'kind': 'savings',
          'balance': 100,
          'currencyCode': 'USD',
        },
      ],
    });
    await _open(tester, store);
    // No rates cached in a test, so the dollar account starts excluded.
    expect(find.textContaining('no rate for USD'), findsOneWidget);
    // findsWidgets, not findsOneWidget: the same figure legitimately appears
    // as net worth, as total assets, as the section subtotal and on the row.
    // The exact arithmetic is pinned in fx_totals_test; what matters here is
    // that the SCREEN moves when a rate is entered.
    expect(find.text('₱5,000'), findsWidgets);
    expect(find.text('₱10,000'), findsNothing);

    await _tap(tester, find.text('Set a USD rate'));
    expect(find.text('USD to PHP'), findsOneWidget);
    await _type(tester, 'e.g. 56.50', '50');
    await _tap(tester, find.text('Use this rate'));
    // setManualRate writes, THEN rebuilds the rate table from disk. That is
    // two awaits behind the dialog's own pop, and one pumpAndSettle inside
    // _tap only drains the first. Without this the store has the rate and the
    // screen has not been told, which reads exactly like the conversion not
    // working.
    await tester.pumpAndSettle();

    expect(store.data['settings']['manualRates'], {'USD': 50.0});
    // Two accounts here draw the card carousel, which makes the list taller;
    // tapping "Set a USD rate" scrolled the summary off the top. The converted
    // total lives up there, so bring it back into view before reading it. This
    // is a scroll, not a behavior change: net worth is 10,000 either way.
    await tester.scrollUntilVisible(
      find.text('NET WORTH'),
      -200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    // 5000 + 100 * 50 = 10,000, and the sentence names where that came from.
    expect(find.text('₱10,000'), findsWidgets);
    expect(
      find.textContaining('a rate you entered yourself'),
      findsOneWidget,
      reason: 'the total moved and nothing said why',
    );
  });

  testWidgets('removing a typed rate puts the total back', (tester) async {
    final store = await _store({
      'schemaVersion': 12,
      'settings': {
        'onboarded': true,
        'manualRates': {'USD': 50.0},
      },
      'accounts': [
        {'id': 'a', 'name': 'Cash', 'kind': 'cash', 'balance': 5000},
        {
          'id': 'b',
          'name': 'Chase',
          'kind': 'savings',
          'balance': 100,
          'currencyCode': 'USD',
        },
      ],
    });
    await _open(tester, store);
    expect(find.text('₱10,000'), findsWidgets);

    // The offer is gone once a rate exists, so the way back in is the row
    // itself; the notice is what tells somebody a rate is in play.
    expect(find.text('Set a USD rate'), findsNothing);
    expect(find.textContaining('a rate you entered yourself'), findsOneWidget);

    await store.setManualRate('USD', null);
    await tester.pumpAndSettle();
    expect(store.data['settings'].containsKey('manualRates'), isFalse);
    expect(find.text('₱5,000'), findsWidgets);
    expect(find.text('₱10,000'), findsNothing);
  });

  testWidgets('cash on hand is not asked which bank it is in', (tester) async {
    final store = await _store();
    await _open(tester, store);
    await _tap(tester, find.text('Add an account'));
    await _tap(tester, find.text('Cash and e-wallets'));
    await _tap(tester, find.text('Cash on hand'));
    expect(find.text('Bank or wallet (optional)'), findsNothing);
  });

  testWidgets('an e-wallet IS asked, and the answer is stored', (tester) async {
    final store = await _store();
    await _open(tester, store);
    await _tap(tester, find.text('Add an account'));
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
