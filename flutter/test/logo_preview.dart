// Preview render for the institution-logo work. NOT a test (no `_test` suffix),
// so `flutter test` never collects it. Run deliberately from flutter/:
//   flutter test test/logo_preview.dart --update-goldens
// Output: test/shots/logo-preview-dark.png (gitignored), for LOOKING at.
//
// It renders every institution avatar that carries a logo plus a spread of
// real BankCards, so the full logo set can be reviewed on the actual widgets.

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
    tester.view.physicalSize = const Size(1200, 4200);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    Barako.current = Barako.currentTheme.resolve(Brightness.dark);

    // Anything with an avatar mark, wordmark or standalone symbol, so the
    // symbol-only institutions (RCBC, COL, CIMB, OwnBank) show up here too.
    final withLogo = [
      for (final i in institutions)
        if (institutionSymbolAsset(i.id) != null) i,
    ];

    Widget card(
      String id,
      String name,
      String type,
      double bal, {
      BankCardVariant variant = BankCardVariant.savings,
      double? limit,
      String? network,
      bool wallet = false,
    }) {
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
                  Text(
                    'All account avatars (${withLogo.length})',
                    style: Barako.kickerStyle,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final i in withLogo)
                        InstitutionAvatar(id: i.id, size: 46),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Text('Cards', style: Barako.kickerStyle),
                  const SizedBox(height: 12),
                  card('bdo', 'BDO', 'Savings', 24500),
                  card('metrobank', 'Metrobank', 'Savings', 61000),
                  card(
                    'securitybank',
                    'Security Bank',
                    'Credit',
                    12400,
                    variant: BankCardVariant.credit,
                    limit: 60000,
                    network: 'Mastercard',
                  ),
                  card('seabank', 'SeaBank', 'Savings', 8200),
                  card(
                    'homecredit',
                    'Home Credit',
                    'Credit',
                    5400,
                    variant: BankCardVariant.credit,
                    limit: 15000,
                  ),
                  card('grabpay', 'GrabPay', 'Wallet', 1750, wallet: true),
                  card('pnb', 'PNB', 'Savings', 33000),
                  card('gsis', 'GSIS', 'Savings', 12000),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    // Real image decode runs on the true event loop, which testWidgets' fake
    // clock never advances. Precache every logo/symbol asset inside runAsync so
    // the golden captures decoded logos, not undecoded blanks.
    final ctx = tester.element(find.byType(Scaffold));
    final paths = <String>{};
    for (final i in institutions) {
      final l = institutionLogoAsset(i.id);
      final s = institutionSymbolAsset(i.id);
      if (l != null) paths.add(l);
      if (s != null) paths.add(s);
    }
    await tester.runAsync(() async {
      for (final p in paths) {
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
