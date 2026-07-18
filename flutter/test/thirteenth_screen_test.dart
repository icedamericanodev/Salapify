// 13th month flow: full-year tax-free case, the 90,000 ceiling shared with
// other bonuses splitting the pay into taxed parts, and proration.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> openThirteenth(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(find.text('Tools'), 200,
      scrollable: find.byType(Scrollable).first);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Tools'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('13th month pay'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('a full year at 25,000 is tax free; big bonuses split it',
      (tester) async {
    final store = SalapifyStore();
    await tester.pumpWidget(SalapifyApp(store: store));
    await openThirteenth(tester);

    await tester.enterText(
        find.widgetWithText(TextField, 'e.g. 25,000'), '25,000');
    await tester.pumpAndSettle();
    expect(find.text('₱25,000'), findsOneWidget);
    expect(find.text('TAX FREE'), findsOneWidget);
    expect(find.text('Taxable part'), findsNothing);

    // 80,000 of other bonuses leaves only 10,000 of the ceiling: taxable
    // 15,000 at the 15% bracket is 2,250 tax, net 22,750 (engine figures).
    await tester.enterText(find.widgetWithText(TextField, '0'), '80,000');
    await tester.pumpAndSettle();
    expect(find.text('TAX FREE'), findsNothing);
    await tester.scrollUntilVisible(find.text('Taxable part'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    expect(find.text('₱10,000'), findsOneWidget); // tax free part
    expect(find.text('₱15,000'), findsOneWidget); // taxable part
    expect(find.text('- ₱2,250'), findsOneWidget); // tax on the excess
    expect(find.text('₱22,750'), findsOneWidget); // take home
  });

  testWidgets('months worked prorate the amount', (tester) async {
    final store = SalapifyStore();
    await tester.pumpWidget(SalapifyApp(store: store));
    await openThirteenth(tester);

    await tester.enterText(
        find.widgetWithText(TextField, 'e.g. 25,000'), '25000');
    await tester.enterText(find.widgetWithText(TextField, '12'), '6');
    await tester.pumpAndSettle();
    expect(find.text('₱12,500'), findsOneWidget);
    expect(find.textContaining('Prorated for 6 months'), findsOneWidget);
  });
}
