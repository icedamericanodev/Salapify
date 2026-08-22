// Widget behaviour for the Avalanche vs Snowball card (f4.64). The comparison
// math is proven in payoff_compare_golden_test.dart; this proves the card is
// honest: at the minimums it says the two are the same, and picking an extra
// amount surfaces avalanche's interest saving.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/theme.dart';
import 'package:salapify/widgets/payoff_compare_card.dart';

void main() {
  String money(num v) => '₱${v.round()}';

  Future<void> pump(WidgetTester tester, List<Map<String, dynamic>> debts) {
    return tester.pumpWidget(
      MaterialApp(
        theme: salapifyTheme(Barako.current),
        home: Scaffold(
          body: SingleChildScrollView(
            child: PayoffCompareCard(debts: debts, money: money),
          ),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> spread() => [
    {'id': 'A', 'remaining': 5000, 'monthlyRate': 1.0, 'minPayment': 500},
    {'id': 'B', 'remaining': 20000, 'monthlyRate': 5.0, 'minPayment': 1000},
  ];

  testWidgets('at the minimums the card says both cost the same', (
    tester,
  ) async {
    await pump(tester, spread());
    expect(find.textContaining('both orders cost the same'), findsOneWidget);
    // Both columns are present.
    expect(find.text('Avalanche'), findsOneWidget);
    expect(find.text('Snowball'), findsOneWidget);
  });

  testWidgets('picking an extra amount surfaces avalanche saving the interest', (
    tester,
  ) async {
    await pump(tester, spread());
    // Tap the +1000 chip.
    await tester.tap(find.text('+ ₱1000'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Avalanche pays'), findsOneWidget);
    expect(find.textContaining('less in interest'), findsOneWidget);
    // Snowball's honest upside is named too, so the choice stays the person's.
    expect(find.textContaining('some people find easier'), findsOneWidget);
  });

  testWidgets('a single debt says the order does not matter', (tester) async {
    await pump(tester, [
      {'id': 'A', 'remaining': 12000, 'monthlyRate': 3.0, 'minPayment': 1500},
    ]);
    expect(find.textContaining('the payoff order does not change'), findsOneWidget);
  });
}
