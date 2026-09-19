// Founder specimen for the f4.62 Safe-to-Spend card. NOT a `_test` file, so
// `flutter test` never collects it; run with --update-goldens and LOOK at the
// PNG, then surface it in the chat (SendUserFile) so the founder reviews the
// same picture.
//
// Shows the three states that matter, in the dark palette the founder uses: a
// healthy positive buffer, an overcommitted (negative) buffer, and the net
// worth lens the toggle flips to.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/money/format.dart' show formatMoney;
import 'package:salapify/theme.dart';
import 'package:salapify/widgets/safe_to_spend_card.dart';

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
  testWidgets('safe to spend card specimen, dark', (tester) async {
    await loadRealFonts(tester);
    Barako.currentTheme = themeForKey('palawan');
    Barako.current = themeForKey('palawan').resolve(Brightness.dark);
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    String money(double v) => formatMoney(v);

    Map<String, dynamic> healthy() => {
      'liquid': 38000.0,
      'cardDue': 7300.0,
      'billsDue': 12000.0,
      'committed': 19300.0,
      'buffer': 18700.0,
      'dueCount': 4,
      'minsUnset': 0,
      'windowDays': 14,
    };

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
                _label('HEALTHY BUFFER'),
                SafeToSpendCard(
                  view: SafeToSpendView.buffer,
                  onView: (_) {},
                  buffer: healthy(),
                  netWorth: 228545,
                  money: money,
                  hideBalances: false,
                  onOpenTrend: () {},
                ),
                _label('OVERCOMMITTED (NEGATIVE)'),
                SafeToSpendCard(
                  view: SafeToSpendView.buffer,
                  onView: (_) {},
                  buffer: {
                    ...healthy(),
                    'liquid': 8000.0,
                    'buffer': 8000.0 - 19300.0,
                  },
                  netWorth: 228545,
                  money: money,
                  hideBalances: false,
                  onOpenTrend: () {},
                ),
                _label('NET WORTH LENS'),
                SafeToSpendCard(
                  view: SafeToSpendView.netWorth,
                  onView: (_) {},
                  buffer: healthy(),
                  netWorth: 228545,
                  money: money,
                  hideBalances: false,
                  onOpenTrend: () {},
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('shots/safe-to-spend-dark.png'),
    );
  });
}
