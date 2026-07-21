// Take-home pay flow: the breakdown renders from the golden-locked phtax
// engine, the period toggle rescales the display, and the too-low input
// gets the honest nudge. Expected figures come straight from the engine
// (takeHomePay(25000): contributions 2,075, tax 313.75, net 22,611.25).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> openSalary(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.tap(find.text('Menu'));
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(find.text('Tools'), 200,
      scrollable: find.byType(Scrollable).first);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Tools'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Take-home pay'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('25,000 basic renders the honest breakdown and rescales',
      (tester) async {
    final store = SalapifyStore();
    await tester.pumpWidget(SalapifyApp(store: store));
    await openSalary(tester);

    await tester.enterText(
        find.widgetWithText(TextField, 'e.g. 25,000'), '25,000');
    await tester.pumpAndSettle();

    expect(find.text('- ₱1,250'), findsOneWidget); // SSS
    expect(find.text('- ₱625'), findsOneWidget); // PhilHealth
    expect(find.text('- ₱200'), findsOneWidget); // Pag-IBIG
    expect(find.text('- ₱314'), findsOneWidget); // income tax 313.75
    expect(find.text('₱22,611'), findsOneWidget); // net

    await tester.scrollUntilVisible(
        find.textContaining('15% tax bracket'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    expect(find.textContaining('15% tax bracket'), findsOneWidget);

    // Per year rescales the same engine numbers.
    await tester.scrollUntilVisible(find.text('Per year'), -200,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Per year'));
    await tester.pumpAndSettle();
    expect(find.text('₱271,335'), findsOneWidget);
  });

  testWidgets('a too-low basic gets the honest nudge, not a breakdown',
      (tester) async {
    final store = SalapifyStore();
    await tester.pumpWidget(SalapifyApp(store: store));
    await openSalary(tester);

    await tester.enterText(
        find.widgetWithText(TextField, 'e.g. 25,000'), '300');
    await tester.pumpAndSettle();
    expect(find.textContaining('That looks too low for a monthly salary'),
        findsOneWidget);
    expect(find.text('SHOW RESULTS'), findsNothing);
  });
}
