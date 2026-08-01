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
    // Accepting re-anchors the start to the debt's level at TAP time, so a
    // chip left sitting in chat history can never backdate the commitment.
    expect(plan['startLevel'], 12000.0);
    expect(find.text('OUR PLAN'), findsOneWidget);
    expect(find.textContaining('Deal.'), findsOneWidget);
  });

  testWidgets('a junk stored plan never blocks new offers', (tester) async {
    // A hand-edited or zero-amount plan in a restored backup is non-null
    // but fails the shape check: no card renders, so no Drop button exists.
    // If the offer guard read the raw value, that phone could never make a
    // plan again. Junk must read as "no plan" everywhere.
    await pumpPan(
      tester,
      blob(
        settings: {
          'activePlan': {
            'kind': 'debt',
            'targetId': 'card',
            'amount': 0,
            'cadence': 'monthly',
            'startDate': '2026-01-15',
          },
        },
      ),
    );
    expect(find.text('OUR PLAN'), findsNothing);
    await tester.enterText(
      find.byType(TextField),
      'When will I be debt free with 1500 extra?',
    );
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();
    final offer = find.textContaining('Make it a plan');
    await tester.scrollUntilVisible(
      offer,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(offer, findsOneWidget);
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
    // The receipt echoes the amount that was actually written.
    expect(find.textContaining('a month now'), findsOneWidget);
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
    // Dropping confirms first: it erases the start date and start level,
    // which no remake can bring back, and the button sits one mis-tap from
    // Change. Keep it first, to prove the dialog is not a rubber stamp.
    await tester.tap(find.text('Keep it'));
    await tester.pumpAndSettle();
    expect(store.activePlan, isNotNull);
    expect(find.text('OUR PLAN'), findsOneWidget);

    await tester.tap(find.text('Drop the plan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Drop it'));
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
    // TWO, not "some": the card and the reply bubble each carry planLine.
    // findsWidgets here once passed on the card alone while the reply was
    // the fallback "I did not catch that one", which is exactly the bug
    // this test claimed to guard against.
    expect(find.textContaining('ahead of our pace'), findsNWidgets(2));
  });
}
