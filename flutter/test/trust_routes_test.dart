// The empty-Home routes people are sent down the moment they first open the
// app, and the "manage debts" note on Accounts. All three used to point at the
// wrong place, quietly:
//
//   "See who owes me" switched to the Utang tab on its DEFAULT segment, "I
//   owe", a screen with none of their receivables on it.
//   "Pay off a debt" PUSHED a standalone Debts screen over the shell, a bare
//   copy of the tab with none of the segment control around it.
//   Accounts told people to "Manage debts on the Debts screen", a screen that
//   is only a fallback, not the canonical home.
//
// Utang left the bottom bar (founder direction, matching the mockup) and is a
// pushed screen now, so these assert the landing SEGMENT, the visible create
// action, the header Back arrow, and that the canonical MoneyScreen (with both
// segments) opened rather than a bare DebtsScreen, so a future segment
// reshuffle cannot send a first-run tap somewhere wrong again in silence.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/main.dart';
import 'package:salapify/screens/accounts.dart';
import 'package:salapify/screens/debts.dart';
import 'package:salapify/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/app_harness.dart';

Future<SalapifyStore> _bootEmptyHome(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues(onboardedEmptyStorage());
  final store = SalapifyStore();
  await tester.pumpWidget(SalapifyApp(store: store));
  await tester.pumpAndSettle();
  return store;
}

void main() {
  testWidgets('empty Home "See who owes me" opens the Owed to me segment', (
    tester,
  ) async {
    await _bootEmptyHome(tester);
    final lane = find.text('See who owes me');
    expect(lane, findsOneWidget);
    await tester.ensureVisible(lane);
    await tester.tap(lane);
    await tester.pumpAndSettle();

    // The Owed to me segment, named by its own subtitle. Landing on the "I
    // owe" default here was the whole defect.
    expect(find.text('Money owed to you, oldest first'), findsOneWidget);
    expect(find.text('What you owe, and the plan to zero'), findsNothing);
    // Its create action is there,
    expect(find.widgetWithText(FilledButton, 'New'), findsOneWidget);
    // and the pushed screen carries its own way back where a bottom bar can't.
    expect(find.byTooltip('Back'), findsOneWidget);
  });

  testWidgets('empty Home "Pay off a debt" opens the I owe segment', (
    tester,
  ) async {
    await _bootEmptyHome(tester);
    final lane = find.text('Pay off a debt, formal or between friends');
    expect(lane, findsOneWidget);
    await tester.ensureVisible(lane);
    await tester.tap(lane);
    await tester.pumpAndSettle();

    // The canonical Utang surface (its segment control exists) on the "I owe"
    // half, not a bare DebtsScreen copy.
    expect(find.text('Owed to me'), findsOneWidget);
    expect(find.text('What you owe, and the plan to zero'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'New'), findsOneWidget);
    // The pushed screen carries its own Back arrow,
    expect(find.byTooltip('Back'), findsOneWidget);
    // and no standalone Debts screen was pushed over the shell.
    expect(find.byType(DebtsScreen), findsNothing);
  });

  testWidgets('Accounts routes debt management to the I owe tab', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      storageKey: jsonEncode({
        'schemaVersion': 12,
        'settings': {'onboarded': true},
        // One debt so the debts section, and its note, render.
        'debts': [
          {
            'id': 'd1',
            'name': 'Credit Card',
            'type': 'card',
            'remaining': 5000,
          },
        ],
      }),
    });
    final store = SalapifyStore();
    await store.load();
    var opened = false;
    // A real phone surface: the accounts list is lazy, and on the short 800x600
    // test default the debt note at the bottom sat below the built range, so the
    // tap missed it. A phone builds it.
    tester.view.physicalSize = const Size(1170, 6000);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: salapifyTheme(Barako.current),
        home: AccountsScreen(store: store, onOpenPayables: () => opened = true),
      ),
    );
    await tester.pumpAndSettle();

    // The stale copy is gone; the new note points at the "I owe" tab and works.
    expect(find.text('Manage debts on the Debts screen.'), findsNothing);
    final note = find.text('Manage debts under the "I owe" tab.');
    expect(note, findsOneWidget);
    await tester.ensureVisible(note);
    await tester.tap(note);
    await tester.pumpAndSettle();
    expect(opened, isTrue);
  });
}
