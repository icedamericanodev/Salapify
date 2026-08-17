// Preview render for the institution-logo work. NOT a test (no `_test` suffix),
// so `flutter test` never collects it. Run deliberately from flutter/:
//   flutter test test/logo_preview.dart --update-goldens
// Output: test/shots/logo-preview-dark.png (gitignored), for LOOKING at.
//
// It renders the five representative institutions (a wide wordmark, a colored
// emblem wallet, a dark wordmark, a bank with a distinct symbol, a digital
// bank) as real BankCards plus the account avatars, so the logo treatment can
// be reviewed on the actual widgets before the full set is wired.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/money/institutions.dart';
import 'package:salapify/screens/add_account_flow.dart' show InstitutionAvatar;
import 'package:salapify/theme.dart';
import 'package:salapify/widgets/bank_card.dart';

import 'screens_shot.dart' show loadRealFonts;

void main() {
  testWidgets('logo preview', (tester) async {
    await loadRealFonts(tester);
    tester.view.physicalSize = const Size(1200, 3400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    Barako.current = Barako.currentTheme.resolve(Brightness.dark);

    Widget card(String id, String name, String type, double bal,
        {BankCardVariant variant = BankCardVariant.savings,
        double? limit,
        String? network,
        bool wallet = false}) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: SizedBox(
          width: 340,
          child: BankCard(
            bankName: name,
            accountType: type,
            balance: bal,
            logoAsset: institutionLogoAsset(id),
            brandColor: institutionBrandColor(id),
            last4: '1234',
            creditLimit: limit,
            networkMark: network,
            isWallet: wallet,
            variant: variant,
          ),
        ),
      );
    }

    Widget avatar(String id) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: InstitutionAvatar(id: id, size: 48),
        );

    const assetPaths = [
      'assets/institutions/bpi.png',
      'assets/institutions/gcash.png',
      'assets/institutions/gcash_symbol.png',
      'assets/institutions/maya.png',
      'assets/institutions/unionbank.png',
      'assets/institutions/unionbank_symbol.png',
      'assets/institutions/gotyme.png',
    ];

    await tester.pumpWidget(
      MaterialApp(
        theme: salapifyTheme(Barako.current),
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Barako.background,
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 40, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Account avatars', style: Barako.kickerStyle),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      avatar('bpi'),
                      avatar('gcash'),
                      avatar('maya'),
                      avatar('unionbank'),
                      avatar('gotyme'),
                      avatar('bdo'), // no logo yet -> initials fallback
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text('Cards', style: Barako.kickerStyle),
                  const SizedBox(height: 12),
                  card('bpi', 'BPI', 'Savings', 24500),
                  card('gcash', 'GCash', 'Wallet', 3120.50, wallet: true),
                  card('maya', 'Maya', 'Wallet', 8890, wallet: true),
                  card('unionbank', 'UnionBank', 'Credit', 12400,
                      variant: BankCardVariant.credit,
                      limit: 50000,
                      network: 'VISA'),
                  card('gotyme', 'GoTyme', 'Savings', 45000),
                  card('bdo', 'BDO', 'Savings', 15000), // fallback: name text
                ],
              ),
            ),
          ),
        ),
      ),
    );
    // Real image decode runs on the true event loop, which testWidgets' fake
    // clock never advances. Precache each asset inside runAsync so the golden
    // captures the decoded logo, not an undecoded blank. Same reason the fonts
    // load inside runAsync.
    final ctx = tester.element(find.byType(Scaffold));
    await tester.runAsync(() async {
      for (final p in assetPaths) {
        await precacheImage(AssetImage(p), ctx);
      }
    });
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('shots/logo-preview-dark.png'),
    );
  });
}
