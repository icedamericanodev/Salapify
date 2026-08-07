// Renders the bank cards and the Accounts carousel to PNGs so they can be
// LOOKED at, dark first (what the founder uses). Named WITHOUT the `_test`
// suffix on purpose, exactly like screens_shot.dart, so `flutter test` never
// collects it and it can never fail a CI run on fonts or a reference image.
//
// Run deliberately, from flutter/:
//   flutter test test/bank_card_shot.dart --update-goldens
// Output lands in test/shots/, which is gitignored.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/money/account_taxonomy.dart' show AccountStore;
import 'package:salapify/money/institutions.dart';
import 'package:salapify/screens/accounts.dart';
import 'package:salapify/theme.dart';
import 'package:salapify/widgets/bank_card.dart';
import 'package:salapify/widgets/flip_bank_card.dart';
import 'package:salapify/widgets/lock_gate.dart' show LockAuthenticator;
import 'package:shared_preferences/shared_preferences.dart';

import 'screens_shot.dart' show loadRealFonts;
import 'support/golden_app.dart';

/// A phone that cannot lock, so a reveal shot needs no platform auth channel
/// (there is none in the sandbox). The owner is never hidden from their own
/// last four when the device has no lock, so this matches the real path.
class _NoLockAuth implements LockAuthenticator {
  @override
  Future<bool> canLock() async => false;
  @override
  Future<bool> authenticate() async => true;
}

Future<SalapifyStore> _store(Map<String, dynamic> blob) async {
  SharedPreferences.setMockInitialValues({storageKey: jsonEncode(blob)});
  final store = SalapifyStore();
  await store.load();
  return store;
}

final Map<String, dynamic> _blob = {
  'schemaVersion': 12,
  'settings': {'onboarded': true},
  'accounts': [
    {
      'id': 'bpi',
      'name': 'BPI Savings',
      'kind': 'savings',
      'balance': 48500.55,
      'subtype': 'savings_account',
      'institutionId': 'bpi',
      'last4': '1234',
    },
    {
      'id': 'gcash',
      'name': 'GCash',
      'kind': 'ewallet',
      'balance': 1785.25,
      'subtype': 'ewallet',
      'institutionId': 'gcash',
      'last4': '8890',
    },
    {
      'id': 'ub',
      'name': 'Salary account',
      'kind': 'checking',
      'balance': 22400,
      'subtype': 'payroll_account',
      'institutionId': 'unionbank',
      'last4': '4021',
    },
    {'id': 'cash', 'name': 'Cash', 'kind': 'cash', 'balance': 2340},
  ],
  'debts': [
    {
      'id': 'card',
      'name': 'BPI Card',
      'type': 'credit card',
      'remaining': 42000,
      'creditLimit': 50000,
      'institutionId': 'bpi',
      'last4': '9012',
      'monthlyRate': 0,
      'minPayment': 0,
      'dueDay': 0,
      'statementDay': 0,
      'graceDays': 0,
    },
  ],
  'transactions': <Map<String, dynamic>>[],
};

Widget _gallery() {
  BankCard card(String bank, String type, String id, double bal, String l4) =>
      BankCard(
        bankName: bank,
        accountType: type,
        brandColor: institutionBrandColor(id),
        last4: l4,
        balance: bal,
      );
  return Scaffold(
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          card('BPI Savings', 'Savings', 'bpi', 48500.55, '1234'),
          const SizedBox(height: 16),
          card('GCash', 'E-wallet', 'gcash', 1785.25, '8890'),
          const SizedBox(height: 16),
          card('UnionBank', 'Checking', 'unionbank', 22400, '4021'),
          const SizedBox(height: 16),
          card('BDO', 'Savings', 'bdo', 91200, '5567'),
          const SizedBox(height: 16),
          BankCard(
            bankName: 'BPI Card',
            accountType: 'Credit',
            brandColor: institutionBrandColor('bpi'),
            last4: '9012',
            balance: 42000,
            creditLimit: 50000,
            variant: BankCardVariant.credit,
          ),
          const SizedBox(height: 16),
          card('Cash', 'Cash', 'none', 2340, ''),
        ],
      ),
    ),
  );
}

Future<void> _shot(
  WidgetTester tester, {
  required String name,
  required Widget home,
  required Brightness brightness,
  Size size = const Size(390, 1500),
}) async {
  await loadRealFonts(tester);
  tester.view.physicalSize = Size(size.width * 3, size.height * 3);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  // Palette before build, the order main.dart uses.
  Barako.current = Barako.currentTheme.resolve(brightness);
  await tester.pumpWidget(goldenApp(home: home));
  await tester.pumpAndSettle();
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('shots/$name.png'),
  );
}

FlipBankCard _flip({
  required SalapifyStore store,
  required Map<String, dynamic> row,
  required AccountStore accountStore,
  required String bank,
  required String type,
  required String brandId,
  required double balance,
  required String last4,
  required bool flipped,
  BankCardVariant variant = BankCardVariant.savings,
  double? creditLimit,
  String? networkMark,
  bool showHint = false,
  LockAuthenticator? authenticator,
}) => FlipBankCard(
  row: row,
  accountStore: accountStore,
  store: store,
  bankName: bank,
  accountType: type,
  brandColor: institutionBrandColor(brandId),
  last4: last4,
  balance: balance,
  variant: variant,
  creditLimit: creditLimit,
  networkMark: networkMark,
  flipped: flipped,
  showHint: showHint,
  authenticator: authenticator,
  onFlip: (_) {},
  onViewFullDetails: () {},
  onEdit: () {},
);

Widget _flipGallery(SalapifyStore store) {
  final savingsRow = {
    'id': 'bpi',
    'name': 'BPI Savings',
    'last4': '1234',
    'target': 10000,
    'qrRef': '',
    'paymentInstructions': 'Send to my BPI account for the paluwagan pot.',
  };
  final creditRow = {
    'id': 'card',
    'name': 'BPI Card',
    'last4': '9012',
    'creditLimit': 50000,
    'dueDay': 15,
    'statementDay': 2,
    'qrRef': '',
  };
  return Scaffold(
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _ShotLabel('Front, with the one-time hint'),
          _flip(
            store: store,
            row: savingsRow,
            accountStore: AccountStore.accounts,
            bank: 'BPI Savings',
            type: 'Savings',
            brandId: 'bpi',
            balance: 48500.55,
            last4: '1234',
            flipped: false,
            showHint: true,
          ),
          const SizedBox(height: 20),
          const _ShotLabel('Back, savings, number masked by default'),
          _flip(
            store: store,
            row: savingsRow,
            accountStore: AccountStore.accounts,
            bank: 'BPI Savings',
            type: 'Savings',
            brandId: 'bpi',
            balance: 48500.55,
            last4: '1234',
            flipped: true,
          ),
          const SizedBox(height: 20),
          const _ShotLabel('Back, credit card, outstanding and limit'),
          _flip(
            store: store,
            row: creditRow,
            accountStore: AccountStore.debts,
            bank: 'BPI Card',
            type: 'Credit',
            brandId: 'bpi',
            balance: 42000,
            last4: '9012',
            variant: BankCardVariant.credit,
            creditLimit: 50000,
            networkMark: 'VISA',
            flipped: true,
          ),
        ],
      ),
    ),
  );
}

class _ShotLabel extends StatelessWidget {
  final String text;
  const _ShotLabel(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: TextStyle(
        color: Barako.muted,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

void main() {
  for (final b in [Brightness.dark, Brightness.light]) {
    final suffix = b == Brightness.dark ? 'dark' : 'light';

    testWidgets('bank card gallery $suffix', (tester) async {
      await _shot(
        tester,
        name: 'bank-cards-$suffix',
        home: _gallery(),
        brightness: b,
      );
    });

    testWidgets('accounts carousel $suffix', (tester) async {
      final store = await _store(_blob);
      await _shot(
        tester,
        name: 'accounts-carousel-$suffix',
        home: AccountsScreen(store: store),
        brightness: b,
        size: const Size(390, 900),
      );
    });

    testWidgets('flip card faces $suffix', (tester) async {
      final store = await _store(_blob);
      await _shot(
        tester,
        name: 'flip-card-faces-$suffix',
        // Reduced motion renders both faces flat, which is exactly what we
        // want to review: the back-face content and colour, not a mid-turn.
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: _flipGallery(store),
        ),
        brightness: b,
        size: const Size(390, 1050),
      );
    });
  }

  // Dark only, matching the founder's phone: the number revealed after auth on
  // the savings back, so the "•••• 1234" state can be reviewed too.
  testWidgets('flip card revealed dark', (tester) async {
    final store = await _store(_blob);
    await loadRealFonts(tester);
    tester.view.physicalSize = const Size(390 * 3, 320 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    Barako.current = Barako.currentTheme.resolve(Brightness.dark);
    await tester.pumpWidget(
      goldenApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(20),
              child: _flip(
                store: store,
                row: {
                  'id': 'bpi',
                  'name': 'BPI Savings',
                  'last4': '1234',
                  'target': 10000,
                  'qrRef': '',
                },
                accountStore: AccountStore.accounts,
                bank: 'BPI Savings',
                type: 'Savings',
                brandId: 'bpi',
                balance: 48500.55,
                last4: '1234',
                flipped: true,
                authenticator: _NoLockAuth(),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // Tap the reveal toggle (the eye), then let the state settle.
    await tester.tap(find.byTooltip('Reveal the last four digits'));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('shots/flip-card-revealed-dark.png'),
    );
  });
}
