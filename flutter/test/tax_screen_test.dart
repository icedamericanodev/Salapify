// Income tax flow: the 8% vs graduated comparison renders from the golden
// phtax engine and recommends the cheaper one. 600,000 gross: 8% option
// 28,000, graduated 34,500, so the 8% is our pick, saving 6,500.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> openTax(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(find.text('Tools'), 200,
      scrollable: find.byType(Scrollable).first);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Tools'));
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(find.text('Income tax'), 200,
      scrollable: find.byType(Scrollable).first);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Income tax'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('600k gross recommends the flat 8% and shows the saving',
      (tester) async {
    final store = SalapifyStore();
    await tester.pumpWidget(SalapifyApp(store: store));
    await openTax(tester);

    await tester.enterText(
        find.widgetWithText(TextField, 'e.g. 600,000'), '600,000');
    await tester.pumpAndSettle();

    expect(find.text('Take the flat 8%'), findsOneWidget);
    await tester.scrollUntilVisible(
        find.textContaining('Saves you about ₱6,500'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    expect(find.textContaining('Saves you about ₱6,500'), findsOneWidget);
    expect(find.text('LOWER'), findsOneWidget);
    // Both option totals shown, RN-verified.
    expect(find.text('₱28,000'), findsWidgets);
    expect(find.text('₱34,500'), findsOneWidget);
  });
}
