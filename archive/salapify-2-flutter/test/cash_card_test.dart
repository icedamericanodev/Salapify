// Cash is a compact wallet TILE, not a bank card. The tile is the hero of the
// account DETAIL screen; on the Accounts LIST cash now folds into the "Money
// you can reach now" summary (the mockup's Available card) and shows as an
// openable row, never a per-cash tile in the deck. These tests hold that line:
// the tile widget shows the name, a "Physical cash" subtitle and the balance
// with NO masked number and NO card aspect ratio; the Accounts screen
// summarizes cash in the Available card (never inside the swipe deck), keeps a
// lone bank card as a standalone card, opens a cash row's editor on tap, and
// the detail hero is the same tile, never a card.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/money/account_taxonomy.dart' show AccountStore;
import 'package:salapify/screens/account_detail.dart' show AccountDetailScreen;
import 'package:salapify/screens/accounts.dart';
import 'package:salapify/theme.dart';
import 'package:salapify/widgets/bank_card.dart';
import 'package:salapify/widgets/flip_bank_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens_shot.dart' show loadRealFonts;

Future<SalapifyStore> _load(Map<String, dynamic> blob) async {
  SharedPreferences.setMockInitialValues({storageKey: jsonEncode(blob)});
  final store = SalapifyStore();
  await store.load();
  return store;
}

Map<String, dynamic> _account(
  String id,
  String name,
  String kind,
  num balance, {
  String? institutionId,
  String? subtype,
  String? last4,
}) => {
  'id': id,
  'name': name,
  'kind': kind,
  'balance': balance,
  'institutionId': ?institutionId,
  'subtype': ?subtype,
  'last4': ?last4,
};

Map<String, dynamic> _blob(List<Map<String, dynamic>> accounts) => {
  'schemaVersion': 12,
  'settings': {'onboarded': true, 'flipHintSeen': true},
  'accounts': accounts,
  'debts': <Map<String, dynamic>>[],
  'transactions': <Map<String, dynamic>>[],
  'payments': <Map<String, dynamic>>[],
};

final _cash = _account('cash', 'Cash on hand', 'cash', 3200);
final _bank = _account(
  'bpi',
  'BPI Savings',
  'savings',
  48500,
  institutionId: 'bpi',
  subtype: 'savings_account',
  last4: '1234',
);
final _wallet = _account(
  'gcash',
  'GCash',
  'ewallet',
  1785,
  institutionId: 'gcash',
);

Future<void> _pumpTile(
  WidgetTester tester,
  Widget tile, {
  double w = 360,
}) async {
  Barako.current = Barako.currentTheme.resolve(Brightness.dark);
  await tester.pumpWidget(
    MaterialApp(
      theme: salapifyTheme(Barako.current),
      home: Scaffold(
        body: Center(
          child: SizedBox(width: w, child: tile),
        ),
      ),
    ),
  );
}

Future<void> _pumpAccounts(WidgetTester tester, SalapifyStore store) async {
  Barako.current = Barako.currentTheme.resolve(Brightness.dark);
  tester.view.physicalSize = const Size(1200, 3200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: salapifyTheme(Barako.current),
      home: AccountsScreen(store: store),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the tile shows name, subtitle and balance, no card chrome', (
    tester,
  ) async {
    await _pumpTile(
      tester,
      CashBalanceTile(name: 'Cash on hand', balance: 3200),
    );
    expect(find.text('Cash on hand'), findsOneWidget);
    expect(find.text('Physical cash'), findsOneWidget);
    expect(find.text('AVAILABLE CASH'), findsOneWidget);
    expect(find.textContaining('3,200'), findsOneWidget);
    // No masked card number, and it is not the flipping card.
    expect(find.textContaining('••••'), findsNothing);
    expect(find.byType(FlipBankCard), findsNothing);
  });

  testWidgets('the tile is NOT a card: no aspect ratio, and it is compact', (
    tester,
  ) async {
    await loadRealFonts(tester);
    await _pumpTile(
      tester,
      CashBalanceTile(name: 'Cash on hand', balance: 3200),
    );
    // The whole bug class was a 1.586 card. The tile must carry no AspectRatio,
    // and must be far shorter than a card (a card at 360 wide is ~227dp).
    expect(
      find.descendant(
        of: find.byType(CashBalanceTile),
        matching: find.byType(AspectRatio),
      ),
      findsNothing,
    );
    // A card at 360 wide is ~227dp; the tile is far shorter (about 129dp).
    final h = tester.getSize(find.byType(CashBalanceTile)).height;
    expect(h, lessThan(160));
  });

  testWidgets('a seven-digit balance does not overflow at 320dp', (
    tester,
  ) async {
    await loadRealFonts(tester);
    await _pumpTile(
      tester,
      CashBalanceTile(name: 'Jar', balance: 1234567.89),
      w: 320,
    );
    expect(tester.takeException(), isNull);
    expect(find.textContaining('1,234,5'), findsOneWidget);
  });

  testWidgets('a foreign-currency amount uses its own symbol', (tester) async {
    await _pumpTile(
      tester,
      CashBalanceTile(
        name: 'Travel cash',
        balance: 1000,
        amountText: r'$1,000.00',
      ),
    );
    expect(find.text(r'$1,000.00'), findsOneWidget);
  });

  // --- Placement and the gate, driven through the real Accounts screen ------

  testWidgets('cash folds into the Available card, banks in the category group', (
    tester,
  ) async {
    // 1 cash + 1 bank + 1 wallet. Cash no longer draws its own tile: it folds
    // into the "Money you can reach now" summary and appears as a list row. The
    // bank and wallet live in the Accounts Overview category groups, not a
    // carousel: the first non-empty group (Cash & Bank) opens by default, so
    // its accounts show without a tap.
    await _pumpAccounts(tester, await _load(_blob([_cash, _bank, _wallet])));
    expect(find.byType(CashBalanceTile), findsNothing);
    expect(find.text('MONEY YOU CAN REACH NOW'), findsOneWidget);
    // No carousel any more: no PageView and no flip card on the list.
    expect(find.byType(PageView), findsNothing);
    expect(find.byType(FlipBankCard), findsNothing);
    // The Cash & Bank group is present and, being the first non-empty group,
    // opens by default, so the bank account shows as a row inside it.
    expect(find.text('Cash & Bank'), findsOneWidget);
    expect(find.text('BPI Savings'), findsWidgets);
    // Cash still has a home: an openable row in the same group.
    expect(find.text('Cash on hand'), findsWidgets);
    // The wallet's own group header exists too (its rows sit behind a tap).
    expect(find.text('E-Wallets'), findsOneWidget);
  });

  testWidgets('a lone bank plus cash shows the bank as a row, no deck', (
    tester,
  ) async {
    // Folding cash into the summary and dropping the carousel must not cost the
    // 1-bank user their account: the bank shows as a row inside the default-open
    // Cash & Bank group, with the Available card above and no carousel.
    await _pumpAccounts(tester, await _load(_blob([_cash, _bank])));
    expect(find.byType(CashBalanceTile), findsNothing);
    expect(find.byType(FlipBankCard), findsNothing);
    expect(find.byType(PageView), findsNothing);
    expect(find.text('MONEY YOU CAN REACH NOW'), findsOneWidget);
    expect(find.text('Cash & Bank'), findsOneWidget);
    expect(find.text('BPI Savings'), findsWidgets);
  });

  testWidgets('only cash: the Available card, no card deck at all', (
    tester,
  ) async {
    final cash2 = _account('cash2', 'Envelope', 'cash', 500);
    await _pumpAccounts(tester, await _load(_blob([_cash, cash2])));
    expect(find.byType(CashBalanceTile), findsNothing);
    expect(find.byType(FlipBankCard), findsNothing);
    expect(find.byType(PageView), findsNothing);
    expect(find.text('MONEY YOU CAN REACH NOW'), findsOneWidget);
    // Both cash accounts appear as rows in the list below.
    expect(find.text('Cash on hand'), findsWidgets);
    expect(find.text('Envelope'), findsWidgets);
  });

  testWidgets('a single account shows no card hero, cash in the summary', (
    tester,
  ) async {
    // One account: no carousel and no cash tile. Cash shows in the Available
    // summary and as its list row, which is the single-account behavior now.
    await _pumpAccounts(tester, await _load(_blob([_cash])));
    expect(find.byType(CashBalanceTile), findsNothing);
    expect(find.byType(FlipBankCard), findsNothing);
    expect(find.text('MONEY YOU CAN REACH NOW'), findsOneWidget);
  });

  testWidgets('tapping the cash row opens its editor', (tester) async {
    await _pumpAccounts(tester, await _load(_blob([_cash, _bank])));
    // The name and the "Cash on hand" subtype label both render, so target the
    // first; both sit inside the one row GestureDetector.
    await tester.tap(find.text('Cash on hand').first);
    await tester.pumpAndSettle();
    // Cash opens like any account row now: its manage-and-edit sheet, which
    // carries a Save action.
    expect(find.text('Save'), findsOneWidget);
  });

  testWidgets('the cash detail hero is the tile, never a bank card', (
    tester,
  ) async {
    final store = await _load(_blob([_cash, _bank]));
    Barako.current = Barako.currentTheme.resolve(Brightness.dark);
    tester.view.physicalSize = const Size(1200, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: salapifyTheme(Barako.current),
        home: AccountDetailScreen(
          store: store,
          id: 'cash',
          accountStore: AccountStore.accounts,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(CashBalanceTile), findsOneWidget);
    expect(find.byType(BankCard), findsNothing);
  });
}
