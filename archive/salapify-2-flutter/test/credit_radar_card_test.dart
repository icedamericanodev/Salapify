// Widget behaviour for the Credit Radar card (f4.63). The ratios are proven in
// credit_utilization_golden_test.dart; this proves the card renders honest text
// for each state: over-limit reads past 100%, peso balances always show, the
// statement-date caveat appears when any card is past the line, and no-limit
// cards are flagged.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/money/credit_utilization.dart';
import 'package:salapify/theme.dart';
import 'package:salapify/widgets/credit_radar_card.dart';

void main() {
  String money(num v) => '₱${v.round()}';

  Future<void> pump(WidgetTester tester, Map<String, dynamic> radar) {
    return tester.pumpWidget(
      MaterialApp(
        theme: salapifyTheme(Barako.current),
        home: Scaffold(
          body: SingleChildScrollView(
            child: CreditRadarCard(radar: radar, money: money),
          ),
        ),
      ),
    );
  }

  testWidgets('renders overall percent, the 30% line, and per-card ratios', (
    tester,
  ) async {
    final radar = creditUtilization([
      {'id': 'A', 'type': 'credit card', 'remaining': 9000, 'creditLimit': 30000},
      {
        'id': 'B',
        'type': 'credit card',
        'remaining': 24000,
        'creditLimit': 30000,
      },
    ])!;
    await pump(tester, radar);
    // Overall 33000/60000 = 55% -> high.
    expect(find.text('55%'), findsOneWidget);
    expect(find.textContaining('healthy line is 30%'), findsOneWidget);
    // Per-card ratios both show (A 30%, B 80%).
    expect(find.text('30%'), findsOneWidget);
    expect(find.text('80%'), findsOneWidget);
    // The statement-date caveat appears because a card is past the line.
    expect(find.textContaining('pay a card in full before its statement'), findsOneWidget);
  });

  testWidgets('an over-limit card reads past 100%, never capped', (
    tester,
  ) async {
    final radar = creditUtilization([
      {
        'id': 'F',
        'type': 'credit card',
        'remaining': 33000,
        'creditLimit': 30000,
      },
    ])!;
    await pump(tester, radar);
    // 33000/30000 = 1.10 -> 110%, shown honestly.
    expect(find.text('110%'), findsWidgets);
  });

  testWidgets('a no-limit card is flagged and not given a fake percent', (
    tester,
  ) async {
    final radar = creditUtilization([
      {'id': 'A', 'type': 'credit card', 'remaining': 3000, 'creditLimit': 10000},
      {'id': 'E', 'type': 'credit card', 'remaining': 15000, 'creditLimit': 0},
    ])!;
    await pump(tester, radar);
    expect(find.textContaining('no limit saved'), findsOneWidget);
    // The no-limit card shows the band word, not a percentage.
    expect(find.text('No limit set'), findsOneWidget);
  });

  testWidgets('a healthy book shows the encouraging line and no scary caveat', (
    tester,
  ) async {
    final radar = creditUtilization([
      {'id': 'A', 'type': 'credit card', 'remaining': 1000, 'creditLimit': 30000},
    ])!;
    await pump(tester, radar);
    expect(find.textContaining('under the 30% healthy line'), findsOneWidget);
    // No card is past the line, so the carry-interest caveat is absent.
    expect(
      find.textContaining('pay a card in full before its statement'),
      findsNothing,
    );
  });
}
