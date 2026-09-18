// The merged Utang tab: what you owe, and what is owed to you, in one place.
//
// The founder's call, with the reasoning on record: the Debts screen (strategy
// switch, debt-free projection, interest cost) is the richer and more pressing
// half, and it was buried behind Menu while the smaller who-owes-you list
// owned a bottom tab. So one tab, two segments, "I owe" first.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/app_harness.dart';

Map<String, dynamic> _blob() => {
  'schemaVersion': 12,
  'accounts': [
    {'id': 'cash', 'name': 'Cash', 'kind': 'cash', 'balance': 30000},
  ],
  'transactions': [
    {
      'id': 't1',
      'type': 'expense',
      'amount': 500,
      'date': '2026-07-10',
      'accountId': 'cash',
    },
  ],
  'debts': [
    {
      'id': 'd1',
      'name': 'BPI card',
      'type': 'credit card',
      'remaining': 12000,
      'monthlyRate': 3,
      'minPayment': 500,
      'dueDay': 28,
    },
    {
      'id': 'd2',
      'name': 'Car loan',
      'type': 'auto',
      'remaining': 90000,
      'monthlyRate': 1,
      'minPayment': 4000,
      'dueDay': 5,
    },
  ],
  'people': [
    {'id': 'p1', 'name': 'Migs'},
  ],
  'receivables': [
    {
      'id': 'r1',
      'personId': 'p1',
      'person': 'Migs',
      'amount': 1500,
      'payments': <Map<String, dynamic>>[],
      'paid': false,
      'dueDate': '2020-01-01',
    },
  ],
};

Future<void> _boot(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1200, 2600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues({storageKey: jsonEncode(_blob())});
  await tester.pumpWidget(SalapifyApp(store: SalapifyStore()));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the tab opens on I owe, with the debts content', (tester) async {
    await _boot(tester);
    await goToTab(tester, 'Utang');
    expect(
      find.text('TOTAL DEBT'),
      findsOneWidget,
      reason:
          'The default segment must be what you owe. That is the pressing '
          'half, and it is the reason the merge happened at all.',
    );
    expect(find.text('STILL UNPAID'), findsNothing);
  });

  testWidgets('Owed to me holds the receivables, and the header follows', (
    tester,
  ) async {
    await _boot(tester);
    await goToOwedToMe(tester);
    expect(find.text('STILL UNPAID'), findsOneWidget);
    expect(find.text('Migs'), findsOneWidget);
    expect(find.text('TOTAL DEBT'), findsNothing);
    expect(find.text('Money owed to you, oldest first'), findsOneWidget);
  });

  testWidgets('the strategy choice survives a segment flip', (tester) async {
    // The reason the two views live in an inner IndexedStack inside MoneyScreen:
    // flipping "I owe" to "Owed to me" and back must not rebuild the debts view
    // and reset this exploration toggle to snowball.
    //
    // This used to also assert survival across a TAB flip, back when Utang was a
    // resident bottom-bar tab kept alive by the shell's outer IndexedStack.
    // Utang left the bar (founder direction, matching the mockup) and is a
    // pushed screen now, so closing and reopening it builds a fresh MoneyScreen
    // and the transient strategy resets to its default, exactly like every
    // other pushed screen. What an inner IndexedStack still guarantees, and what
    // this guards, is that a SEGMENT flip within one open Utang keeps the pick.
    await _boot(tester);
    await goToTab(tester, 'Utang');
    // Tap the PAYOFF PLAN strategy chip specifically. "Avalanche" also appears
    // now as a column header in the Avalanche vs Snowball comparison card, so a
    // bare text finder is ambiguous; the chip is what this test is about.
    await tester.tap(find.widgetWithText(ChoiceChip, 'Avalanche'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Owed to me'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('I owe'));
    await tester.pumpAndSettle();

    final chip = tester.widget<ChoiceChip>(
      find.widgetWithText(ChoiceChip, 'Avalanche'),
    );
    expect(
      chip.selected,
      isTrue,
      reason:
          'The strategy switch reset on a segment flip. Its State must live '
          'inside the inner IndexedStack so a flip does not unmount it.',
    );
  });

  testWidgets('each segment carries its own create action', (tester) async {
    await _boot(tester);
    await goToTab(tester, 'Utang');
    // I owe: the New button opens the debt form (a wizard, titled by type and
    // opening on "The basics").
    await tester.tap(find.widgetWithText(FilledButton, 'New'));
    await tester.pumpAndSettle();
    expect(find.text('The basics'), findsOneWidget);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    // Owed to me: the same spot opens the utang sheet instead.
    await tester.tap(find.text('Owed to me'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'New'));
    await tester.pumpAndSettle();
    expect(find.text('Who borrowed? e.g. Juan'), findsOneWidget);
  });

  testWidgets('a receivables jump lands on Owed to me, not on I owe', (
    tester,
  ) async {
    // The check-in card on Home says "Follow up Migs". Migs is money owed TO
    // the user, and landing that tap on the default segment would show a
    // screen with no Migs anywhere on it.
    //
    // Seeded WITHOUT debts: a card due within days is a debtdue decision at
    // prio 92, which outranks the utang follow-up at 90 and steals the
    // check-in slot. The shared blob keeps its debts for the other tests.
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final blob = _blob()..remove('debts');
    SharedPreferences.setMockInitialValues({storageKey: jsonEncode(blob)});
    await tester.pumpWidget(SalapifyApp(store: SalapifyStore()));
    await tester.pumpAndSettle();
    expect(find.text('Follow up Migs'), findsOneWidget);
    await tester.tap(find.text('Follow up Migs'));
    await tester.pumpAndSettle();
    expect(find.text('STILL UNPAID'), findsOneWidget);
    expect(find.text('Migs'), findsOneWidget);
  });
}
