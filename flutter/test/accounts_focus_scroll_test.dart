// Open 11, investigated and CLOSED as not-a-defect: a searched account far down
// a long list is scrolled ONTO the screen by the existing reveal. The finding
// that opened it assumed a lazy per-row ListView where a far-down row stays
// unbuilt and ensureVisible no-ops. That is not this tree: all
// AccountStore.accounts rows render in a single "Cash and e-wallets" section,
// one EAGER Column, so every row is built and ensureVisible finds it. Proven by
// running this exact test against the code with and without a speculative scroll
// loop: both pass, so the loop was dropped and this stays as the guard.
//
// It asserts VISIBILITY (the row's rect lands on screen), not mere presence,
// because presence cannot tell "scrolled into view" from "built but painted
// below the fold". If the rows are ever moved to a lazy per-row builder, this
// reddens and a real scroll loop becomes necessary.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/screens/accounts.dart';
import 'package:salapify/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('a focused account far down a long list is scrolled into view', (
    tester,
  ) async {
    final accounts = [
      for (var i = 0; i < 40; i++)
        {
          'id': 'a$i',
          'name': 'Account ${i.toString().padLeft(2, '0')}',
          'kind': 'ewallet',
          'balance': 100.0 * (i + 1),
        },
    ];
    SharedPreferences.setMockInitialValues({
      storageKey: jsonEncode({
        'schemaVersion': 12,
        'settings': {'onboarded': true},
        'accounts': accounts,
      }),
    });
    final store = SalapifyStore();
    await store.load();

    await tester.pumpWidget(
      MaterialApp(
        theme: salapifyTheme(Barako.current),
        home: AccountsScreen(store: store, focusAccountId: 'a39'),
      ),
    );
    await tester.pumpAndSettle();

    final target = find.text('Account 39');
    expect(target, findsOneWidget);

    final rect = tester.getRect(target);
    final screen = tester.getSize(find.byType(MaterialApp));
    // On screen vertically: its top is above the bottom edge and its bottom is
    // below the top edge. A row left below the fold has top >= screen height.
    expect(
      rect.top,
      lessThan(screen.height),
      reason:
          'the focused row (top ${rect.top}) was left below the fold '
          '(screen height ${screen.height}); the reveal did not scroll to it',
    );
    expect(rect.bottom, greaterThan(0));
  });
}
