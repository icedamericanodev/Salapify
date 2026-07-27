// The Insights bands: DO NEXT, TOOLS, THE BIGGER PICTURE.
//
// The tools used to render fully open, two permanent screenfuls of input
// fields whether or not anyone came to use them. Folded to one line each,
// the screen answers "what should I do next" in one screenful. Nothing
// about the numbers changed, only which pixels are open by default, and
// these tests pin exactly that.

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
    {'id': 'cash', 'name': 'Cash', 'kind': 'cash', 'balance': 20000},
  ],
  'transactions': [
    {
      'id': 't1',
      'type': 'expense',
      'label': 'Groceries',
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
    },
  ],
  'settings': <String, dynamic>{},
};

Future<void> _boot(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1200, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({storageKey: jsonEncode(_blob())});
  await tester.pumpWidget(SalapifyApp(store: SalapifyStore()));
  await tester.pumpAndSettle();
  await goToTab(tester, 'Insights');
}

void main() {
  testWidgets('the tools are folded by default, one line each', (tester) async {
    await _boot(tester);
    await tester.scrollUntilVisible(
      find.text('Can you afford it?'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('TOOLS'), findsOneWidget);
    expect(
      find.text('CAN YOU AFFORD IT?'),
      findsNothing,
      reason:
          'The afford card rendered open. The tools band exists so the two '
          'always-on tools stop costing two screenfuls of scroll by default.',
    );
    expect(find.text('A lump sum is landing?'), findsOneWidget);
  });

  testWidgets('expanding a tool shows the same card it always was', (
    tester,
  ) async {
    await _boot(tester);
    await openInsightsTool(tester, 'Can you afford it?');
    expect(
      find.text('CAN YOU AFFORD IT?'),
      findsOneWidget,
      reason: 'The launcher must open the exact card that used to render '
          'inline, values untouched.',
    );
  });

  testWidgets('an opened tool stays open across a tab flip', (tester) async {
    await _boot(tester);
    await openInsightsTool(tester, 'Can you afford it?');
    await goToTab(tester, 'Home');
    await goToTab(tester, 'Insights');
    expect(
      find.text('CAN YOU AFFORD IT?'),
      findsOneWidget,
      reason:
          'The open state must live in State that survives the IndexedStack '
          'flip, same contract as the payoff strategy switch.',
    );
  });
}
