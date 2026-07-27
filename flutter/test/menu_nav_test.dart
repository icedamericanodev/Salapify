// The dashboard restructure: Home is a status view and the Menu tab holds the
// moved-off destinations. Insights stays a bottom tab (founder's call). Locks
// the information architecture so a future change does not silently drag the
// clutter back onto the dashboard.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/app_harness.dart';

void main() {
  testWidgets('dashboard is status-only; Menu tab holds the destinations', (
    tester,
  ) async {
    // Seed an account so the populated dashboard (with the net-worth hero)
    // is what we assert, not the first-run welcome card.
    SharedPreferences.setMockInitialValues({
      'salapify_data_v2': jsonEncode({
        'accounts': [
          {'id': 'a1', 'name': 'Cash', 'kind': 'cash', 'balance': 1000.0},
        ],
        // Pin payday to "tomorrow" so the PAYDAY ritual card never renders
        // here; without this, runs on the 15th or month-end (the default
        // schedule) would add a card this layout test does not expect.
        'settings': {
          'paydaySchedule': {
            'mode': 'weekly',
            'weekday': (DateTime.now().weekday % 7 + 1) % 7,
          },
        },
      }),
    });
    await tester.pumpWidget(SalapifyApp(store: SalapifyStore()));
    await tester.pumpAndSettle();

    // Home shows status, not the nav cards that used to clutter it.
    expect(find.text('NET WORTH'), findsOneWidget);
    expect(find.text('Tools'), findsNothing);
    expect(find.text('Accounts'), findsNothing);
    expect(find.text('Goals'), findsNothing);

    // Five destinations, and Menu is NOT one of them. A bottom bar is for
    // places you go often; Menu is a drawer of everything else and it was
    // taking a sixth of the most valuable strip on the screen. The bar's own
    // theme had been shrunk below Material's defaults specifically to fit six.
    //
    // Scoped to the NavigationBar rather than searching the whole tree, because
    // the mounted destinations render their own headers with the same words.
    expect(navDestination('Menu'), findsNothing);
    expect(navDestination('Insights'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.byType(NavigationDestination),
      ),
      findsNWidgets(5),
    );

    // And Menu is still one tap away, from the header.
    await openMenu(tester);

    // The hub holds the moved destinations (some are below the fold). Insights
    // is NOT here; it stayed a bottom tab.
    for (final row in const [
      'Accounts',
      'Debts',
      'Goals',
      'Ask Pan',
      'Tools',
    ]) {
      await tester.scrollUntilVisible(
        find.text(row),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(row), findsOneWidget, reason: 'Menu should hold $row');
    }
  });

  testWidgets('the Insights tab opens the Insights screen', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(SalapifyApp(store: SalapifyStore()));
    await tester.pumpAndSettle();

    await goToTab(tester, 'Insights');
    await tester.pumpAndSettle();
    expect(find.textContaining('What your money is telling'), findsOneWidget);
  });
}
