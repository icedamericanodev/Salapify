// The Insights empty state's one button. It reads "Start logging", and it used
// to switch to the Home tab and stop, leaving the person to find the Log button
// themselves: a call to action that named the action and did not do it. Now it
// opens the Log sheet where it stands.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/screens/insights.dart';
import 'package:salapify/screens/log_sheet.dart' show LogSheet;
import 'package:salapify/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/app_harness.dart';

void main() {
  testWidgets('the empty Insights CTA opens the Log sheet directly', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = SalapifyStore();
    await store.load();
    await tester.pumpWidget(
      MaterialApp(
        theme: salapifyTheme(Barako.current),
        home: tabHost(InsightsScreen(store: store)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Start logging'), findsOneWidget);
    // Nothing open yet: the old behavior switched tabs and never opened this.
    expect(find.byType(LogSheet), findsNothing);

    await tester.tap(find.text('Start logging'));
    await tester.pumpAndSettle();

    expect(find.byType(LogSheet), findsOneWidget);
  });
}
