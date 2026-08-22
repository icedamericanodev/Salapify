// Founder specimen for the f4.64 Avalanche vs Snowball card. NOT a `_test`
// file. Renders the card at the minimums (both the same) and with an extra
// selected (avalanche pulls ahead). Run with --update-goldens and LOOK.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/money/format.dart' show formatMoney;
import 'package:salapify/theme.dart';
import 'package:salapify/widgets/payoff_compare_card.dart';

import 'screens_shot.dart' show loadRealFonts;

Widget _label(String s) => Padding(
  padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
  child: Text(
    s,
    style: TextStyle(
      fontFamily: 'Jakarta',
      fontSize: 12,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.6,
      color: Barako.muted,
    ),
  ),
);

Future<void> _tapExtra(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

void main() {
  final debts = [
    {
      'id': 'A',
      'name': 'BPI card',
      'remaining': 8000,
      'monthlyRate': 1.0,
      'minPayment': 600,
    },
    {
      'id': 'B',
      'name': 'Maya Credit',
      'remaining': 32000,
      'monthlyRate': 4.5,
      'minPayment': 1600,
    },
  ];

  testWidgets('payoff compare specimen, minimums, dark', (tester) async {
    await loadRealFonts(tester);
    Barako.currentTheme = themeForKey('palawan');
    Barako.current = themeForKey('palawan').resolve(Brightness.dark);
    tester.view.physicalSize = const Size(1080, 1950);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: salapifyTheme(Barako.current),
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Barako.background,
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _label('AT THE MINIMUMS (BOTH THE SAME)'),
                PayoffCompareCard(debts: debts, money: formatMoney),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('shots/payoff-compare-min-dark.png'),
    );
  });

  testWidgets('payoff compare specimen, with extra, dark', (tester) async {
    await loadRealFonts(tester);
    Barako.currentTheme = themeForKey('palawan');
    Barako.current = themeForKey('palawan').resolve(Brightness.dark);
    tester.view.physicalSize = const Size(1080, 1950);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: salapifyTheme(Barako.current),
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Barako.background,
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _label('WITH + P2,000 EXTRA (AVALANCHE PULLS AHEAD)'),
                PayoffCompareCard(debts: debts, money: formatMoney),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _tapExtra(tester, '+ ₱2,000');
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('shots/payoff-compare-extra-dark.png'),
    );
  });
}
