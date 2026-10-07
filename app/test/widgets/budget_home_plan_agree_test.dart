// Home's Budget Pulse and Plan's budget headline read the same budgets, so
// they must say the same "left this month".
//
// They did not. The Home card ran its own copy of the arithmetic, which had
// drifted: it summed spending from ALL TIME and counted entries marked
// excluded, while Plan counts this month only and skips them. On the seed
// book Home said "Total Remaining 22,585.25" and Plan said "Left to spend
// this month 25,425.25". Found by the UI review of 2026-10-07. A beginner who
// sees two "remaining" figures stops trusting every number in the app, so
// this is checked by putting both screens in front of ONE book.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/format.dart';
import 'package:salapify/core/money/plan.dart';
import 'package:salapify/screens/home/budget_pulse_card.dart';
import 'package:salapify/state/financial_state.dart';

import '../support/pinned_app.dart';

void main() {
  testWidgets('Home and Plan show the same money left this month', (
    WidgetTester tester,
  ) async {
    final FinancialState s = await pumpSalapify(tester);
    final BudgetTotals plan = computeBudgetTotals(
      computeBudgets(
        budgets: s.budgets,
        transactions: s.transactions,
        now: s.now,
      ),
    );
    final String left = formatPeso(plan.leftToSpend.pesos);

    await tester.scrollUntilVisible(
      find.byType(BudgetPulseCard),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(BudgetPulseCard),
        matching: find.text(left),
      ),
      findsOneWidget,
      reason: 'Home\'s budget card disagrees with Plan\'s "left this month"',
    );
    // DIRECTIONAL: a real amount, and the seed really has spending outside
    // this month or excluded, which is what made the two differ.
    expect(plan.leftToSpend.isPositive, isTrue);
  });
}
