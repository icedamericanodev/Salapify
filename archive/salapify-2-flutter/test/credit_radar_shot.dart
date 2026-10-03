// Founder specimen for the f4.63 Credit Radar. NOT a `_test` file. Run with
// --update-goldens and LOOK at the PNG, then surface it in the chat.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/money/credit_utilization.dart';
import 'package:salapify/money/format.dart' show formatMoney;
import 'package:salapify/theme.dart';
import 'package:salapify/widgets/credit_radar_card.dart';

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

void main() {
  testWidgets('credit radar specimen, dark', (tester) async {
    await loadRealFonts(tester);
    Barako.currentTheme = themeForKey('palawan');
    Barako.current = themeForKey('palawan').resolve(Brightness.dark);
    tester.view.physicalSize = const Size(1080, 2600);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final mixed = creditUtilization([
      {
        'id': 'A',
        'type': 'credit card',
        'name': 'BPI Rewards',
        'remaining': 27500,
        'creditLimit': 30000,
      },
      {
        'id': 'B',
        'type': 'credit card',
        'name': 'UnionBank',
        'remaining': 12000,
        'creditLimit': 40000,
      },
      {
        'id': 'C',
        'type': 'credit card',
        'name': 'Maya Credit',
        'remaining': 2400,
        'creditLimit': 25000,
      },
      {
        'id': 'E',
        'type': 'credit card',
        'name': 'Metrobank',
        'remaining': 8000,
        'creditLimit': 0,
      },
    ])!;
    final healthy = creditUtilization([
      {
        'id': 'H',
        'type': 'credit card',
        'name': 'BPI Rewards',
        'remaining': 3000,
        'creditLimit': 50000,
      },
    ])!;

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
                _label('MIXED CARDS (ONE STRETCHED, ONE NO LIMIT)'),
                CreditRadarCard(radar: mixed, money: formatMoney),
                _label('HEALTHY'),
                CreditRadarCard(radar: healthy, money: formatMoney),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('shots/credit-radar-dark.png'),
    );
  });
}
