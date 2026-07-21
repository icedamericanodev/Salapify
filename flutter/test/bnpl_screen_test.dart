// The Installment true cost flow: a genuinely free plan reassures, a fee
// unmasks a fake 0%, and impossible numbers get the honest check-your-
// numbers state instead of reassurance.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> openBnpl(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.tap(find.text('Menu'));
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(find.text('Tools'), 200,
      scrollable: find.byType(Scrollable).first);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Tools'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Installment true cost'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('a real 0% reassures and a fee unmasks it', (tester) async {
    final store = SalapifyStore();
    await tester.pumpWidget(SalapifyApp(store: store));
    await openBnpl(tester);

    await tester.enterText(
        find.widgetWithText(TextField, 'e.g. 12,000'), '12,000');
    await tester.enterText(find.widgetWithText(TextField, 'e.g. 6'), '6');
    await tester.enterText(
        find.widgetWithText(TextField, 'e.g. 2,100'), '2000');
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
        find.textContaining('costs the same as paying cash today'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    expect(find.textContaining('costs the same as paying cash today'),
        findsOneWidget);

    // Add the sneaky processing fee: the golden fake-0% case, 8.6% real.
    await tester.scrollUntilVisible(find.text('UPFRONT FEE (OPTIONAL)'), -200,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    final feeField = find.widgetWithText(TextField, '0').last;
    await tester.enterText(feeField, '480');
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
        find.textContaining('more than paying cash'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    expect(find.textContaining('₱480 more than paying cash'),
        findsOneWidget);
    expect(find.text('Real interest per year'), findsOneWidget);
  });

  testWidgets('the sub-peso band never prints self-contradictions',
      (tester) async {
    final store = SalapifyStore();
    await tester.pumpWidget(SalapifyApp(store: store));
    await openBnpl(tester);

    // Underpays by 48 centavos: both figures would round to ₱12,000, so
    // the sentence must show centavos instead of "12,000 less than 12,000".
    await tester.enterText(
        find.widgetWithText(TextField, 'e.g. 12,000'), '12000');
    await tester.enterText(find.widgetWithText(TextField, 'e.g. 6'), '6');
    await tester.enterText(
        find.widgetWithText(TextField, 'e.g. 2,100'), '1999.92');
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('CHECK YOUR NUMBERS'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    expect(find.textContaining('₱11,999.52'), findsOneWidget);

    // Over by 30 centavos: every printable figure says same-as-cash, so
    // the screen reassures instead of warning about "₱0 more" at "0.0%".
    await tester.scrollUntilVisible(
        find.widgetWithText(TextField, 'e.g. 2,100'), -200,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextField, 'e.g. 2,100'), '2000.05');
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
        find.textContaining('costs the same as paying cash today'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    expect(find.textContaining('costs the same as paying cash today'),
        findsOneWidget);
    expect(find.textContaining('₱0 more than paying cash'), findsNothing);
  });

  testWidgets('underpaying numbers get the honest check state',
      (tester) async {
    final store = SalapifyStore();
    await tester.pumpWidget(SalapifyApp(store: store));
    await openBnpl(tester);

    await tester.enterText(
        find.widgetWithText(TextField, 'e.g. 12,000'), '12000');
    await tester.enterText(find.widgetWithText(TextField, 'e.g. 6'), '6');
    await tester.enterText(
        find.widgetWithText(TextField, 'e.g. 2,100'), '1500');
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('CHECK YOUR NUMBERS'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    expect(find.textContaining('which is less than the ₱12,000 cash price'),
        findsOneWidget);
    expect(find.text('TRUE COST'), findsNothing);
  });
}
