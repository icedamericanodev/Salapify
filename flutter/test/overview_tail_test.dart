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

    // The did-anything-happen half: every tail row is actually on screen.
    // Without this, the de-bordered assertions below would pass hardest if
    // the tail were simply deleted.
    for (final kicker in ['THIS MONTH', 'ACCOUNTS', 'NET WORTH']) {
      expect(find.text(kicker), findsOneWidget, reason: '$kicker missing');
      expect(
        find.ancestor(of: find.text(kicker), matching: find.byType(Card)),
        findsNothing,
        reason:
            '$kicker is wrapped in a Card again. The tail is a borderless '
            'tinted band, Phase 3 of the design audit.',
      );
    }

    // The counter-check: the screen as a whole still uses Cards above the
    // tail (the chain, the treat card, and friends), so a change that
    // stripped every border from Home cannot read as "the tail is fine".
    expect(find.byType(Card), findsWidgets);
  });
}
