// The dashboard restructure: Home is a status view and the Menu tab holds the
// moved-off destinations. Locks the new information architecture so a future
// change does not silently drag the clutter back onto the dashboard.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('dashboard is status-only; Menu tab holds the destinations',
      (tester) async {
    // Seed an account so the populated dashboard (with the net-worth hero)
    // is what we assert, not the first-run welcome card.
    SharedPreferences.setMockInitialValues({
      'salapify_data_v2': jsonEncode({
        'accounts': [
          {'id': 'a1', 'name': 'Cash', 'kind': 'cash', 'balance': 1000.0},
        ],
      }),
    });
    await tester.pumpWidget(SalapifyApp(store: SalapifyStore()));
    await tester.pumpAndSettle();

    // Home shows status, not the nav cards that used to clutter it.
    expect(find.text('NET WORTH'), findsOneWidget);
    expect(find.text('Tools'), findsNothing);
    expect(find.text('Accounts'), findsNothing);
    expect(find.text('Goals'), findsNothing);

    // The Menu tab exists (Insights was demoted into it).
    expect(find.text('Menu'), findsOneWidget);
    expect(find.text('Insights'), findsNothing); // no longer a bottom tab

    await tester.tap(find.text('Menu'));
    await tester.pumpAndSettle();

    // The hub holds the moved destinations (some are below the fold).
    for (final row in const [
      'Accounts',
      'Debts',
      'Goals',
      'Insights',
      'Ask Pan',
      'Tools',
    ]) {
      await tester.scrollUntilVisible(find.text(row), 200,
          scrollable: find.byType(Scrollable).first);
      expect(find.text(row), findsOneWidget, reason: 'Menu should hold $row');
    }
  });

  testWidgets('Insights opens from Menu with a working back button',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(SalapifyApp(store: SalapifyStore()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Menu'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Insights'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Insights'));
    await tester.pumpAndSettle();

    // Pushed Insights must have a back affordance (it used to be a tab).
    final back = find.byTooltip('Back');
    expect(back, findsOneWidget);
    await tester.tap(back);
    await tester.pumpAndSettle();
    // Insights is closed (its subtitle is gone) and the Menu hub is showing.
    expect(find.textContaining('What your money is telling'), findsNothing);
    expect(find.text('Insights'), findsOneWidget); // the Menu row, not a screen
  });
}
