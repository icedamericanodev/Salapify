// The Search flow: open from the Overview header, type a query, and see the
// grouped results. The matching itself is locked in search_golden_test; this
// covers the screen, the hint/no-match states, and result rendering.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('search finds an entry and shows its group', (tester) async {
    SharedPreferences.setMockInitialValues({
      'salapify_data_v2': jsonEncode({
        'transactions': [
          {
            'id': 't1',
            'label': 'Jollibee lunch',
            'amount': 150.0,
            'type': 'expense',
            'date': '2026-07-03',
          },
        ],
        'goals': [
          {'id': 'g1', 'name': 'Travel fund', 'target': 15000.0, 'saved': 0.0},
        ],
      }),
    });
    await tester.pumpWidget(SalapifyApp(store: SalapifyStore()));
    await tester.pumpAndSettle();

    // byTooltip, not byIcon: the glyph is resolved through salapify_icon.dart
    // and may change; the tooltip is the control's stable name, and it is
    // what a screen reader gets, so this seam breaking would mean a real
    // accessibility regression too. Same reasoning as openMenu in the
    // harness.
    await tester.tap(find.byTooltip('Search'));
    await tester.pumpAndSettle();

    // Empty query shows the hint.
    expect(find.text('Find anything, fast'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'jollibee');
    await tester.pumpAndSettle();
    expect(find.text('ENTRIES'), findsOneWidget);
    expect(find.text('Jollibee lunch'), findsOneWidget);

    // A query that matches nothing shows the no-match state.
    await tester.enterText(find.byType(TextField), 'zzzznope');
    await tester.pumpAndSettle();
    expect(find.text('No matches'), findsOneWidget);
  });
}
