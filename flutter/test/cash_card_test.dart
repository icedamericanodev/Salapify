// Cash is a wallet, not a card. These tests hold that line: the CashCard shows
// the name, a CASH kicker and the balance with NO masked number, chip, or
// network; the accounts carousel renders cash as a CashCard (not the flipping
// bank card) and a tap opens the account instead of flipping; and the account
// detail hero shows the same wallet, never a bank card, for a cash account.

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

Future<SalapifyStore> _load(Map<String, dynamic> blob) async {
  SharedPreferences.setMockInitialValues({storageKey: jsonEncode(blob)});
  final store = SalapifyStore();
  await store.load();
  return store;
}

Map<String, dynamic> _blob() => {
  'schemaVersion': 12,
  'settings': {'onboarded': true, 'flipHintSeen': true},
  'accounts': [
    {'id': 'cash', 'name': 'Cash on hand', 'kind': 'cash', 'balance': 3200},
    {
      'id': 'bpi',
      'name': 'BPI Savings',
      'kind': 'savings',
      'balance': 48500,
      'institutionId': 'bpi',
      'subtype': 'savings_account',
      'last4': '1234',
    },
  ],
  'debts': [],
  'transactions': <Map<String, dynamic>>[],
  'payments': [],
};

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
  testWidgets('the cash wallet shows name, kicker and balance, no card chrome', (
    tester,
  ) async {
    Barako.current = Barako.currentTheme.resolve(Brightness.dark);
    await tester.pumpWidget(
      MaterialApp(
        theme: salapifyTheme(Barako.current),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              child: CashCard(name: 'Cash on hand', balance: 3200),
            ),
          ),
        ),
      ),
    );
    expect(find.text('Cash on hand'), findsOneWidget);
    expect(find.text('CASH'), findsOneWidget);
    expect(find.textContaining('3,200'), findsOneWidget);
    // No masked card number, and it is not the flipping card.
    expect(find.textContaining('••••'), findsNothing);
    expect(find.byType(FlipBankCard), findsNothing);
  });

  testWidgets('a foreign-currency cash amount uses its own symbol', (
    tester,
  ) async {
    Barako.current = Barako.currentTheme.resolve(Brightness.dark);
    await tester.pumpWidget(
      MaterialApp(
        theme: salapifyTheme(Barako.current),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              child: CashCard(
                name: 'Travel cash',
                balance: 1000,
                amountText: r'$1,000.00',
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.text(r'$1,000.00'), findsOneWidget);
  });

  testWidgets('the carousel renders cash as a wallet, banks as flip cards', (
    tester,
  ) async {
    final store = await _load(_blob());
    await _pumpAccounts(tester, store);
    // One wallet (the cash account) and at least one flip card (the bank).
    expect(find.byType(CashCard), findsOneWidget);
    expect(find.byType(FlipBankCard), findsWidgets);
  });

  testWidgets('tapping the cash wallet opens the account, it does not flip', (
    tester,
  ) async {
    final store = await _load(_blob());
    await _pumpAccounts(tester, store);
    // Cash is the first card, so it is the focused, hittable one.
    await tester.tap(find.byType(CashCard).first);
    await tester.pumpAndSettle();
    // A tap opened the detail screen rather than flipping a card in place.
    expect(find.byType(AccountDetailScreen), findsOneWidget);
  });

  testWidgets('the cash detail hero is a wallet, never a bank card', (
    tester,
  ) async {
    final store = await _load(_blob());
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
    expect(find.byType(CashCard), findsOneWidget);
    expect(find.byType(BankCard), findsNothing);
  });
}
