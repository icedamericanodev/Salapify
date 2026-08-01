// Pan With a Plan, end to end on the real screen: the make-it-a-plan offer
// appears on a debt-free answer and writes the plan through the store, the
// plan card shows exactly what Pan remembers, Change repaces it, and Drop
// clears it with a receipt. The trust rule under test: everything Pan
// "remembers" is visible on the card and editable by the user.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/screens/pan.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> blob({Map<String, dynamic>? settings}) => {
  'schemaVersion': 12,
  'accounts': [
    {'id': 'cash', 'name': 'Cash', 'kind': 'cash', 'balance': 8000},
  ],
  'debts': [
    {
      'id': 'card',
      'name': 'BPI card',
      'remaining': 12000,
      'monthlyRate': 3,
      'minPayment': 1250,
      'dueDay': 15,
    },
  ],
  'settings': ?settings,
};

Future<SalapifyStore> pumpPan(
  WidgetTester tester,
  Map<String, dynamic> data,
) async {
  tester.view.physicalSize = const Size(1100, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({storageKey: jsonEncode(data)});
  final store = SalapifyStore();
  await store.load();
  await tester.pumpWidget(MaterialApp(home: PanScreen(store: store)));
  await tester.pumpAndSettle();
  return store;
}

void main() {
  testWidgets('a debt-free answer offers the plan, and Deal sets it', (
    tester,
  ) async {
    final store = await pumpPan(tester, blob());
    expect(find.text('OUR PLAN'), findsNothing, reason: 'no plan yet');

    await tester.enterText(
      find.byType(TextField),
      'When will I be debt free with 1500 extra?',
    );
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();

    // The offer chip carries the asked amount.
    final offer = find.textContaining('Make it a plan');
    await tester.scrollUntilVisible(
      offer,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(offer, findsOneWidget);
    await tester.tap(offer);
    await tester.pumpAndSettle();

    // Written through the store, visible on the card, confirmed in chat.
    final plan = store.activePlan!;
    expect(plan['kind'], 'debt');
    expect(plan['targetId'], 'card');
    expect(plan['amount'], 1500.0);
    expect(find.text('OUR PLAN'), findsOneWidget);
    expect(find.textContaining('Deal.'), findsOneWidget);
  });

  testWidgets('the card shows the standing plan and Change repaces it', (
    tester,
  ) async {
    final store = await pumpPan(
      tester,
      blob(
        settings: {
          'activePlan': {
            'kind': 'debt',
            'targetId': 'card',
            'label': 'Extra to BPI card',
            'amount': 1000,
            'cadence': 'monthly',
            'startDate': '2020-01-15',
            'startLevel': 20000,
          },
        },
      ),
    );
    expect(find.text('OUR PLAN'), findsOneWidget);
    await tester.tap(find.text('Change'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Amount per month'),
      '2000',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(store.activePlan!['amount'], 2000.0);
    expect(find.textContaining('Noted.'), findsOneWidget);
    // The rest of the plan survives a repace untouched.
    expect(store.activePlan!['targetId'], 'card');
    expect(store.activePlan!['startLevel'], 20000);
  });

  testWidgets('Drop clears the plan, gently, and the card leaves', (
    tester,
  ) async {
    final store = await pumpPan(
      tester,
      blob(
        settings: {
          'activePlan': {
            'kind': 'debt',
            'targetId': 'card',
            'label': 'Extra to BPI card',
            'amount': 1000,
            'cadence': 'monthly',
            'startDate': '2020-01-15',
            'startLevel': 20000,
          },
        },
      ),
    );
    await tester.tap(find.text('Drop the plan'));
    await tester.pumpAndSettle();
    expect(store.activePlan, isNull);
    expect(find.text('OUR PLAN'), findsNothing);
    expect(find.textContaining('Plan dropped.'), findsOneWidget);
    // The debt itself is untouched: dropping a plan never moves money.
    expect(((store.data['debts'] as List).first as Map)['remaining'], 12000);
  });

  testWidgets('asking about the plan answers from the same status', (
    tester,
  ) async {
    // Relative start date so the vector cannot rot: about three monthly
    // periods ago. 20000 down to 12000 is 8000 in against a 3000 pace,
    // which is ahead, and the reply and the card must tell the same story
    // because both read planLine over the same status.
    final start = DateTime.now().subtract(const Duration(days: 92));
    final startDate =
        '${start.year}-'
        '${start.month.toString().padLeft(2, '0')}-'
        '${start.day.toString().padLeft(2, '0')}';
    await pumpPan(
      tester,
      blob(
        settings: {
          'activePlan': {
            'kind': 'debt',
            'targetId': 'card',
            'label': 'Extra to BPI card',
            'amount': 1000,
            'cadence': 'monthly',
            'startDate': startDate,
            'startLevel': 20000,
          },
        },
      ),
    );
    await tester.enterText(find.byType(TextField), 'how is my plan');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();
    expect(find.textContaining('ahead of our pace'), findsWidgets);
  });
}
