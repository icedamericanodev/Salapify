// The Accounts overview: the enhanced net worth card (owned-versus-owed ratio)
// and the quick-actions row (Transfer / Add / Pay / More). These guard the
// presentation only; every peso number still comes from netWorthParts, which
// is locked by statement_golden_test, and every action routes to a flow the
// screen already had.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/screens/accounts.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<SalapifyStore> _storeWith(Map<String, dynamic> data) async {
  SharedPreferences.setMockInitialValues({
    'salapify_data_v2': jsonEncode(data),
  });
  final store = SalapifyStore();
  await store.load();
  return store;
}

Future<void> _pump(
  WidgetTester tester,
  SalapifyStore store, {
  VoidCallback? onOpenPayables,
}) async {
  // A real phone surface, not the 800x600 test default. The accounts list is a
  // lazy ListView, so a group below the viewport plus cache extent never builds
  // and a find.text for its name returns zero. On the short default the taller
  // hero pushed the Investments group off the bottom; a realistic tall surface
  // builds it, exactly as a phone does. One test below sets its own taller size
  // for a 40-row list and still works, since this is the same shape.
  tester.view.physicalSize = const Size(1170, 6000);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: AccountsScreen(store: store, onOpenPayables: onOpenPayables),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('net worth card shows the owned-versus-owed split in words', (
    tester,
  ) async {
    // assets = 48000 + 2000 = 50000, owed = 10000, gross = 60000.
    // owned = 50000 / 60000 = 83.33 -> 83 percent; owed = 17 percent.
    final store = await _storeWith({
      'accounts': [
        {'id': 'a1', 'name': 'BPI', 'kind': 'savings', 'balance': 48000},
        {'id': 'a2', 'name': 'GCash', 'kind': 'ewallet', 'balance': 2000},
      ],
      'debts': [
        {'id': 'd1', 'name': 'Visa', 'type': 'credit card', 'remaining': 10000},
      ],
    });
    await _pump(tester, store);

    // The ratio is spelled out, so the meaning never rides on colour alone.
    expect(find.text('83% assets'), findsOneWidget);
    expect(find.text('17% liabilities'), findsOneWidget);
  });

  testWidgets('an underwater book reads 0% owned, never a positive share', (
    tester,
  ) async {
    // An overdrawn account can drive the assets total negative. Counting that
    // negative money as "owned" would announce a positive owned share over
    // money the reader does not have. Assets -5000, owed 10000 => 0% owned.
    final store = await _storeWith({
      'accounts': [
        {'id': 'a1', 'name': 'Overdrawn', 'kind': 'cash', 'balance': -5000},
      ],
      'debts': [
        {'id': 'd1', 'name': 'Visa', 'type': 'credit card', 'remaining': 10000},
      ],
    });
    await _pump(tester, store);
    expect(find.text('0% assets'), findsOneWidget);
    expect(find.text('100% liabilities'), findsOneWidget);
  });

  testWidgets('a tiny-but-real owned side never rounds away to 0%', (
    tester,
  ) async {
    // Assets 1, owed 999999: the owned share rounds toward 0, but a side with
    // real money must not read "0% assets" beside a "You own" figure.
    final store = await _storeWith({
      'accounts': [
        {'id': 'a1', 'name': 'Peso', 'kind': 'cash', 'balance': 1},
      ],
      'debts': [
        {
          'id': 'd1',
          'name': 'Loan',
          'type': 'personal loan',
          'remaining': 999999,
        },
      ],
    });
    await _pump(tester, store);
    expect(find.text('1% assets'), findsOneWidget);
    expect(find.text('99% liabilities'), findsOneWidget);
  });

  testWidgets('an expandable group reveals only its own accounts', (
    tester,
  ) async {
    // One bank account plus one investment asset. Cash & Bank is the first
    // non-empty group, so it opens by default and shows the bank row. The
    // investment sits in a COLLAPSED group, so its row is offstage until the
    // person taps that group's header to expand it.
    final store = await _storeWith({
      'accounts': [
        {'id': 'a1', 'name': 'BPI', 'kind': 'savings', 'balance': 48000},
      ],
      'assets': [
        {'id': 'x1', 'name': 'Bitcoin', 'kind': 'crypto', 'value': 5000},
      ],
    });
    await _pump(tester, store);

    // Cash & Bank opens by default: the bank row shows. Investments is
    // collapsed, so its Bitcoin row is not visible yet.
    expect(find.text('BPI'), findsWidgets);
    expect(find.text('Bitcoin'), findsNothing);

    // Expand Investments: the row appears. The group total was already in the
    // header, collapsed or not.
    await tester.tap(find.text('Investments'));
    await tester.pumpAndSettle();
    expect(find.text('Bitcoin'), findsOneWidget);
    expect(find.text('₱5,000'), findsWidgets);

    // Collapsing it again hides the row.
    await tester.tap(find.text('Investments'));
    await tester.pumpAndSettle();
    expect(find.text('Bitcoin'), findsNothing);
  });

  testWidgets('each category header carries its own total', (tester) async {
    final store = await _storeWith({
      'accounts': [
        {'id': 'a1', 'name': 'BPI', 'kind': 'savings', 'balance': 48000},
        {'id': 'a2', 'name': 'GCash', 'kind': 'ewallet', 'balance': 2000},
      ],
    });
    await _pump(tester, store);
    // Both category headers render their own subtotal, whether open or not: the
    // bank total (48,000) sits under Cash & Bank, the wallet total (2,000) under
    // E-Wallets. Neither equals the assets hero (50,000), so they are the
    // groups' own numbers.
    expect(find.text('Cash & Bank'), findsOneWidget);
    expect(find.text('₱48,000'), findsWidgets);
    expect(find.text('E-Wallets'), findsOneWidget);
    expect(find.text('₱2,000'), findsWidgets);
    // Expanding E-Wallets reveals the wallet account itself.
    await tester.tap(find.text('E-Wallets'));
    await tester.pumpAndSettle();
    expect(find.text('GCash'), findsOneWidget);
  });

  testWidgets('the hide-balances eye masks every figure, including Pan and a '
      'savings goal', (tester) async {
    // A savings account with a distinctive goal (77,777, which appears ONLY in
    // its progress sub-line) plus a prior-month snapshot so Pan's insight names
    // a peso move. Toggling the eye must hide all of them: the net worth, the
    // goal figure, and the peso amount in Pan's line.
    final store = await _storeWith({
      'accounts': [
        {
          'id': 'a1',
          'name': 'House fund',
          'kind': 'savings',
          'balance': 30000,
          'target': 77777,
        },
      ],
      'settings': {
        'onboarded': true,
        'netWorthHistory': [
          {'month': '2020-01', 'value': 22455},
        ],
      },
    });
    await _pump(tester, store);

    // Before hiding: the goal figure and Pan's peso move are visible.
    expect(find.textContaining('77,777'), findsWidgets);
    expect(find.textContaining('grew by'), findsOneWidget);
    expect(find.text('₱30,000'), findsWidgets);

    // Tap the eye. It is an icon control labelled for a screen reader.
    await tester.tap(find.bySemanticsLabel('Hide balances'));
    await tester.pumpAndSettle();

    // Nothing leaks: the net worth, the goal, and Pan's peso are all gone, and
    // the masked placeholder appears in their place.
    expect(find.textContaining('77,777'), findsNothing);
    expect(find.textContaining('30,000'), findsNothing);
    expect(find.textContaining('grew by'), findsNothing);
    expect(find.text('Savings goal'), findsWidgets);
    expect(find.textContaining('grew this month'), findsOneWidget);
    expect(find.textContaining('••••'), findsWidgets);
  });

  testWidgets('the ownership ratio is hidden on an empty book', (tester) async {
    final store = await _storeWith({});
    await _pump(tester, store);

    // Nothing on the book: no ratio to draw, and the quick-actions row is
    // hidden in favour of the empty state's own Add button.
    expect(find.textContaining('% assets'), findsNothing);
    expect(find.text('Transfer'), findsNothing);
    expect(find.text('Add an account'), findsOneWidget);
  });

  testWidgets(
    'the quick-actions row offers Transfer, Add Account, Pay and More',
    (tester) async {
      final store = await _storeWith({
        'accounts': [
          {'id': 'a1', 'name': 'BPI', 'kind': 'savings', 'balance': 48000},
        ],
      });
      await _pump(tester, store);

      expect(find.text('Transfer'), findsOneWidget);
      expect(find.text('Add Account'), findsOneWidget);
      expect(find.text('Pay'), findsOneWidget);
      expect(find.text('More'), findsOneWidget);
    },
  );

  testWidgets('Transfer with a single account explains why it cannot run yet', (
    tester,
  ) async {
    final store = await _storeWith({
      'accounts': [
        {'id': 'a1', 'name': 'BPI', 'kind': 'savings', 'balance': 48000},
      ],
    });
    await _pump(tester, store);

    await tester.tap(find.text('Transfer'));
    await tester.pump(); // let the snackbar appear
    expect(
      find.text('Add a second account, then you can move money between them.'),
      findsOneWidget,
    );
  });

  testWidgets('Transfer with two accounts opens the move-money sheet', (
    tester,
  ) async {
    final store = await _storeWith({
      'accounts': [
        {'id': 'a1', 'name': 'BPI', 'kind': 'savings', 'balance': 48000},
        {'id': 'a2', 'name': 'GCash', 'kind': 'ewallet', 'balance': 2000},
      ],
    });
    await _pump(tester, store);

    await tester.tap(find.text('Transfer'));
    await tester.pumpAndSettle();
    // The sheet opened rather than the single-account snackbar.
    expect(
      find.text('Add a second account, then you can move money between them.'),
      findsNothing,
    );
    expect(find.textContaining('Move money'), findsWidgets);
  });

  testWidgets('More opens the account-actions sheet', (tester) async {
    final store = await _storeWith({
      'accounts': [
        {'id': 'a1', 'name': 'BPI', 'kind': 'savings', 'balance': 48000},
      ],
    });
    await _pump(tester, store);

    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    expect(find.text('Account actions'), findsOneWidget);
    expect(find.text('Add account'), findsOneWidget);
    expect(find.text('Record payment'), findsOneWidget);
  });

  testWidgets('Pay routes to the payables tab when the jump is wired', (
    tester,
  ) async {
    var jumped = false;
    final store = await _storeWith({
      'accounts': [
        {'id': 'a1', 'name': 'BPI', 'kind': 'savings', 'balance': 48000},
      ],
    });
    await _pump(tester, store, onOpenPayables: () => jumped = true);

    await tester.tap(find.text('Pay'));
    await tester.pumpAndSettle();
    expect(jumped, isTrue);
  });
}
