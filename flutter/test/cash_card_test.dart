// Cash is a compact wallet TILE, not a bank card, and it lives in its own
// section, not the card carousel. These tests hold that line: the tile shows
// the name, a "Physical cash" subtitle and the balance with NO masked number
// and NO card aspect ratio; the Accounts screen renders cash in its own section
// (never inside the swipe deck) and keeps a lone bank card as a standalone card;
// a tap opens the account; and the detail hero is the same tile, never a card.

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

  testWidgets('cash sits in its own section, banks in the swipe deck', (
    tester,
  ) async {
    // 1 cash + 2 banks: one tile, and a PageView carousel for the two cards.
    await _pumpAccounts(tester, await _load(_blob([_cash, _bank, _wallet])));
    expect(find.byType(CashBalanceTile), findsOneWidget);
    expect(find.text('CASH ON HAND'), findsOneWidget);
    expect(find.byType(PageView), findsOneWidget); // the carousel
    // The tile is NOT inside the carousel's PageView.
    expect(
      find.descendant(
        of: find.byType(PageView),
        matching: find.byType(CashBalanceTile),
      ),
      findsNothing,
    );
  });

  testWidgets('a lone bank card plus cash keeps the card, standalone no deck', (
    tester,
  ) async {
    // The regression guard: pulling cash out must not cost the 1-bank user
    // their card. 1 cash + 1 bank -> a tile AND a standalone flip card, no
    // PageView (a lone card is not a swipe deck).
    await _pumpAccounts(tester, await _load(_blob([_cash, _bank])));
    expect(find.byType(CashBalanceTile), findsOneWidget);
    expect(find.byType(FlipBankCard), findsOneWidget);
    expect(find.byType(PageView), findsNothing);
  });

  testWidgets('only cash: tiles, no card deck at all', (tester) async {
    final cash2 = _account('cash2', 'Envelope', 'cash', 500);
    await _pumpAccounts(tester, await _load(_blob([_cash, cash2])));
    expect(find.byType(CashBalanceTile), findsNWidgets(2));
    expect(find.byType(FlipBankCard), findsNothing);
    expect(find.byType(PageView), findsNothing);
  });

  testWidgets('a single account shows no hero zone, same as before', (
    tester,
  ) async {
    // Total of one account: no hero tile or card, cash appears only in the
    // list below, exactly the shipped single-account behavior.
    await _pumpAccounts(tester, await _load(_blob([_cash])));
    expect(find.byType(CashBalanceTile), findsNothing);
    expect(find.byType(FlipBankCard), findsNothing);
  });

  testWidgets('tapping the cash tile opens the account, it does not flip', (
    tester,
  ) async {
    await _pumpAccounts(tester, await _load(_blob([_cash, _bank])));
    await tester.tap(find.byType(CashBalanceTile));
    await tester.pumpAndSettle();
    expect(find.byType(AccountDetailScreen), findsOneWidget);
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
