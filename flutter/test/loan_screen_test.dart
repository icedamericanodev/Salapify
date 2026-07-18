// The Loan calculator flow: open from Tools, type a loan, see the payment
// and the TRUE cost card, and watch an add-on quote get exposed.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('an add-on quote shows its true effective rate',
      (tester) async {
    final store = SalapifyStore();
    await tester.pumpWidget(SalapifyApp(store: store));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Tools'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tools'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Loan calculator'));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextField, 'e.g. 100,000'), '120,000');
    await tester.enterText(find.widgetWithText(TextField, 'e.g. 12'), '24');
    await tester.enterText(find.widgetWithText(TextField, 'e.g. 1.5'), '1.5');
    await tester.pumpAndSettle();

    // Diminishing at 1.5% monthly on 120k for 24 months, RN-verified.
    expect(find.text('₱5,991'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('TRUE COST'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    expect(find.text('TRUE COST'), findsOneWidget);

    // Switch to add-on: same quoted rate, the true rate roughly doubles.
    await tester.scrollUntilVisible(find.text('Add-on'), -200,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add-on'));
    await tester.pumpAndSettle();
    expect(find.text('₱6,800'), findsOneWidget); // the golden add-on payment
    await tester.scrollUntilVisible(
        find.textContaining('really works out to about'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    expect(find.textContaining('really works out to about'), findsOneWidget);
    expect(find.text('36.42%'), findsOneWidget); // effective annual, golden
  });

  testWidgets('a one month loan never claims month zero payoff savings',
      (tester) async {
    final store = SalapifyStore();
    await tester.pumpWidget(SalapifyApp(store: store));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Tools'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tools'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Loan calculator'));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextField, 'e.g. 100,000'), '120000');
    await tester.enterText(find.widgetWithText(TextField, 'e.g. 12'), '1');
    await tester.enterText(find.widgetWithText(TextField, 'e.g. 1.5'), '1.5');
    await tester.pumpAndSettle();

    // The bank officer's must-fix: no "pay off at month 0" false claim.
    expect(find.textContaining('pre-termination fee'), findsNothing);
    expect(find.text('₱121,800'), findsWidgets); // the real 1-month payment
  });

  testWidgets('incomplete and bad inputs nudge instead of breaking',
      (tester) async {
    final store = SalapifyStore();
    await tester.pumpWidget(SalapifyApp(store: store));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Tools'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tools'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Loan calculator'));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextField, 'e.g. 100,000'), '50000');
    await tester.pumpAndSettle();
    expect(find.text('Enter the term and the numbers appear.'),
        findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'e.g. 12'), '-3');
    await tester.pumpAndSettle();
    expect(find.text('Amounts and rates cannot be negative.'),
        findsOneWidget);
  });
}
