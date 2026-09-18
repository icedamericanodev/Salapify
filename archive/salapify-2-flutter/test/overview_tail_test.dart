// The Overview tail stays a quiet band: borderless tinted surfaces, not a
// second stack of bordered cards.
//
// Phase 3 of the 2026-08-07 design audit de-bordered the tail (the lesson
// offer, THIS MONTH, ACCOUNTS, NET WORTH) because four hairline boxes at the
// bottom of Home competed with the money cards above them. A regression here
// is silent: wrapping one of these back in a Card renders perfectly and
// passes every money test, it just quietly re-clutters the front page. So
// the shape is pinned: the tail rows exist (the did-anything-happen half)
// and none of them sits inside a Card (the de-bordered half). The money
// cards above the tail keep their Cards, asserted too, so this can never
// "pass harder" by the whole screen losing its borders.
//
// UPDATED (founder direction, 2026-08-13): Home went dashboard-first. NET WORTH
// GRADUATED out of this quiet tail and became the hero card at the top, and
// THIS MONTH's figures moved into the Quick Overview above. So the tail this
// test pins is now just ACCOUNTS (still de-bordered), and net worth living in a
// Card is the new intent rather than the regression it once was.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _seed() => {
  'schemaVersion': 12,
  'accounts': [
    {'id': 'cash', 'name': 'Cash', 'kind': 'cash', 'balance': 8000},
    {'id': 'bank', 'name': 'BPI', 'kind': 'bank', 'balance': 42000},
  ],
  'transactions': [
    {
      'id': 't1',
      'type': 'expense',
      'label': 'Groceries',
      'amount': 1200,
      'date': '2026-07-20',
      'accountId': 'cash',
    },
    {
      'id': 't2',
      'type': 'income',
      'label': 'Sweldo',
      'amount': 25000,
      'date': '2026-07-15',
      'accountId': 'bank',
    },
  ],
};

void main() {
  testWidgets('the tail rows render de-bordered; the money cards keep theirs', (
    tester,
  ) async {
    // Tall view so the lazy ListView builds all the way to the footer.
    tester.view.physicalSize = const Size(1170, 4800);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({storageKey: jsonEncode(_seed())});
    await tester.pumpWidget(SalapifyApp(store: SalapifyStore()));
    await tester.pumpAndSettle();

    // The did-anything-happen half: the surviving tail row is actually on
    // screen. Without this, the de-bordered assertion below would pass hardest
    // if the tail were simply deleted. ACCOUNTS is the tail now: THIS MONTH's
    // figures moved up into the dashboard-first Quick Overview, and NET WORTH
    // moved up into the hero, on the 2026-08-13 founder direction.
    expect(find.text('ACCOUNTS'), findsOneWidget, reason: 'ACCOUNTS missing');
    expect(
      find.ancestor(of: find.text('ACCOUNTS'), matching: find.byType(Card)),
      findsNothing,
      reason:
          'ACCOUNTS is wrapped in a Card again. The tail is a borderless '
          'tinted band, Phase 3 of the design audit.',
    );

    // NET WORTH, by contrast, is now the dashboard-first HERO: it DOES wear a
    // raised Card and it OPENS the screen rather than closing it. This is the
    // deliberate reversal of the old "net worth is a quiet footer" rule, chosen
    // by the founder after the incremental recolor read as too timid. The guard
    // flips with it: net worth in a Card is now correct, not a regression.
    expect(find.text('NET WORTH'), findsOneWidget, reason: 'NET WORTH missing');
    expect(
      find.ancestor(of: find.text('NET WORTH'), matching: find.byType(Card)),
      findsOneWidget,
      reason: 'Net worth is the hero card now; it belongs inside a Card.',
    );

    // The counter-check: the screen as a whole still uses Cards, so a change
    // that stripped every border from Home cannot read as "the tail is fine".
    expect(find.byType(Card), findsWidgets);
  });
}
