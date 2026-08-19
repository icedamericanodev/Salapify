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
    expect(find.text('83% owned'), findsOneWidget);
    expect(find.text('17% owed'), findsOneWidget);
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
    expect(find.text('0% owned'), findsOneWidget);
    expect(find.text('100% owed'), findsOneWidget);
  });

  testWidgets('a tiny-but-real owned side never rounds away to 0%', (
    tester,
  ) async {
    // Assets 1, owed 999999: the owned share rounds toward 0, but a side with
    // real money must not read "0% owned" beside a "Total assets" figure.
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
    expect(find.text('1% owned'), findsOneWidget);
    expect(find.text('99% owed'), findsOneWidget);
  });

  testWidgets('a category tab filters the list to its own accounts', (
    tester,
  ) async {
    // One bank account plus one investment asset. The Investments row shows only
    // under the Investments tab, not under the default Bank tab.
    final store = await _storeWith({
      'accounts': [
        {'id': 'a1', 'name': 'BPI', 'kind': 'savings', 'balance': 48000},
      ],
      'assets': [
        {'id': 'x1', 'name': 'Bitcoin', 'kind': 'crypto', 'value': 5000},
      ],
    });
    await _pump(tester, store);

    // Bank is the default tab: the bank account row shows, the investment does
    // not (it lives in a tab that is not built until selected).
    expect(find.text('BPI'), findsWidgets);
    expect(find.text('Bitcoin'), findsNothing);

    // Switch to Investments: the investment and its subtotal appear.
    await tester.tap(find.text('Investments'));
    await tester.pumpAndSettle();
    expect(find.text('Bitcoin'), findsOneWidget);
    expect(find.text('INVESTMENTS TOTAL'), findsOneWidget);
    expect(find.text('₱5,000'), findsWidgets);
  });

  testWidgets('a tab subtotal totals the accounts in that tab', (tester) async {
    final store = await _storeWith({
      'accounts': [
        {'id': 'a1', 'name': 'BPI', 'kind': 'savings', 'balance': 48000},
        {'id': 'a2', 'name': 'GCash', 'kind': 'ewallet', 'balance': 2000},
      ],
    });
    await _pump(tester, store);
    // Bank tab: the deposit account's subtotal.
    expect(find.text('BANK TOTAL'), findsOneWidget);
    expect(find.text('₱48,000'), findsWidgets);
    // E-Wallets tab: GCash and its own subtotal, a different number.
    await tester.tap(find.text('E-Wallets'));
    await tester.pumpAndSettle();
    expect(find.text('E-WALLETS TOTAL'), findsOneWidget);
    expect(find.text('₱2,000'), findsWidgets);
  });

  testWidgets('the ownership ratio is hidden on an empty book', (tester) async {
    final store = await _storeWith({});
    await _pump(tester, store);

    // Nothing on the book: no ratio to draw, and the quick-actions row is
    // hidden in favour of the empty state's own Add button.
    expect(find.textContaining('% owned'), findsNothing);
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
