// Contribution checker flow: the SSS, PhilHealth, and Pag-IBIG table
// renders from the golden phtax engine. 25,000 salary: SSS 1,250/2,530,
// PhilHealth 625/625, Pag-IBIG 200/200; you total 2,075, employer 3,355,
// grand 5,430 (rounded-line sums, RN-verified).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> openContrib(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.tap(find.text('Menu'));
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(find.text('Tools'), 200,
      scrollable: find.byType(Scrollable).first);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Tools'));
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(find.text('Contribution checker'), 200,
      scrollable: find.byType(Scrollable).first);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Contribution checker'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('25,000 salary shows the contributions and totals',
      (tester) async {
    final store = SalapifyStore();
    await tester.pumpWidget(SalapifyApp(store: store));
    await openContrib(tester);

    await tester.enterText(
        find.widgetWithText(TextField, 'e.g. 25,000'), '25,000');
    await tester.pumpAndSettle();

    expect(find.text('SSS'), findsOneWidget);
    expect(find.text('₱1,250'), findsWidgets); // SSS you
    expect(find.text('₱2,530'), findsOneWidget); // SSS employer
    await tester.scrollUntilVisible(find.text('Total credited to you'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    expect(find.text('₱5,430'), findsOneWidget); // grand total
    expect(find.textContaining('Monthly Salary Credit of ₱25,000'),
        findsOneWidget);
  });
}
