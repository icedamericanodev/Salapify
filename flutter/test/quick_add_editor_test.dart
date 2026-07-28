// The quick add editor as a screen, and the Budget card it opens from.
//
// The engine is golden locked in quickadd_golden_test. What is guarded here is
// the thing a golden file cannot see: that an edit STICKS. The card used to
// fall back to four defaults whenever the stored list was empty, which was
// right when there was no way to edit and becomes a bug the moment there is.
// Deleting the last button has to leave it deleted, or the app reads as
// refusing to be changed.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/screens/budget.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _blob({List<Map<String, dynamic>>? quickAdds}) => {
  'schemaVersion': 12,
  'settings': {
    'onboarded': true,
    'monthlyLimit': 10000,
    'quickAdds': ?quickAdds,
  },
  'accounts': [
    {'id': 'cash', 'name': 'Cash', 'kind': 'cash', 'balance': 5000},
  ],
};

Future<SalapifyStore> _open(
  WidgetTester tester, {
  Map<String, dynamic>? blob,
}) async {
  SharedPreferences.setMockInitialValues({
    storageKey: jsonEncode(blob ?? _blob()),
  });
  final store = SalapifyStore();
  await store.load();
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        // Wrapped in a ListenableBuilder, which is how the real app mounts
        // this tab (main.dart wraps the whole shell in one). Mounting the
        // screen bare made it never rebuild after a save, so the first version
        // of these tests reported the CARD as stale when the store was
        // actually correct. The harness has to carry the chrome the tab really
        // has, or it tests a screen the app does not ship.
        //
        // Tall, so the whole card is laid out. A ListView never builds what is
        // off screen, and an assertion on an unbuilt row asserts on nothing.
        body: SizedBox(
          height: 3000,
          child: ListenableBuilder(
            listenable: store,
            builder: (_, _) => BudgetScreen(store: store),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return store;
}

Future<void> _openEditor(WidgetTester tester) async {
  await tester.tap(find.text('Edit'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the card shows the four defaults before anything is edited', (
    tester,
  ) async {
    await _open(tester);
    expect(find.textContaining('Food'), findsWidgets);
    expect(find.textContaining('Transport'), findsWidgets);
    expect(find.textContaining('Coffee'), findsWidgets);
    expect(find.textContaining('Load'), findsWidgets);
  });

  testWidgets('a new button appears on the card and survives', (tester) async {
    final store = await _open(tester);
    await _openEditor(tester);
    await tester.enterText(find.byType(TextField).first, 'Jeep');
    await tester.enterText(find.byType(TextField).last, '13.50');
    await tester.tap(find.text('Add button'));
    await tester.pumpAndSettle();

    expect(store.quickAdds.any((q) => q.label == 'Jeep'), isTrue);
    expect(store.quickAdds.firstWhere((q) => q.label == 'Jeep').amount, 13.50);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Jeep'), findsWidgets);
  });

  testWidgets('deleting the LAST button leaves it deleted', (tester) async {
    // The bug the editor would otherwise create. An empty stored list used to
    // mean "never set", so the card refilled with four defaults. Deleting all
    // four would have made four different ones reappear, which reads as the
    // app refusing to be changed.
    final store = await _open(tester);
    await _openEditor(tester);
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.byIcon(Icons.close).first);
      await tester.pumpAndSettle();
    }
    expect(store.quickAdds, isEmpty, reason: 'the defaults came back');
    expect(find.textContaining('No buttons right now'), findsOneWidget);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    // And the card agrees, rather than quietly refilling behind the sheet.
    expect(find.textContaining('Coffee'), findsNothing);
    expect(find.text('+ Custom'), findsOneWidget);
  });

  testWidgets('removing one button removes THAT one', (tester) async {
    // An off by one here deletes a preset the person did not point at, and
    // there is no undo on this sheet.
    final store = await _open(tester);
    await _openEditor(tester);
    await tester.tap(find.byTooltip('Remove Transport'));
    await tester.pumpAndSettle();
    expect(store.quickAdds.map((q) => q.label).toList(), [
      'Food',
      'Coffee',
      'Load',
    ]);
  });

  testWidgets('a refused add says why, and RN said nothing at all', (
    tester,
  ) async {
    final store = await _open(tester);
    await _openEditor(tester);
    await tester.enterText(find.byType(TextField).first, 'Food');
    await tester.enterText(find.byType(TextField).last, '99');
    await tester.tap(find.text('Add button'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('You already have a button called Food'),
      findsOneWidget,
    );
    expect(store.quickAdds, hasLength(4), reason: 'nothing was added');
  });

  testWidgets('a junk amount is refused with a sentence, not silence', (
    tester,
  ) async {
    await _open(tester);
    await _openEditor(tester);
    await tester.enterText(find.byType(TextField).first, 'Whatever');
    await tester.enterText(find.byType(TextField).last, 'abc');
    await tester.tap(find.text('Add button'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Enter an amount above zero'), findsOneWidget);
  });

  testWidgets('a successful add clears the fields, a refused one does not', (
    tester,
  ) async {
    // Losing what you typed because the amount had a typo means retyping the
    // name too, which is the difference between a two second fix and giving up.
    await _open(tester);
    await _openEditor(tester);
    await tester.enterText(find.byType(TextField).first, 'Jeep');
    await tester.enterText(find.byType(TextField).last, 'abc');
    await tester.tap(find.text('Add button'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      'Jeep',
      reason: 'a refusal must not throw away what was typed',
    );

    await tester.enterText(find.byType(TextField).last, '13');
    await tester.tap(find.text('Add button'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      '',
      reason: 'a success clears, so the next one can be typed straight in',
    );
  });

  testWidgets('a stored list is shown as stored, not topped up', (
    tester,
  ) async {
    final store = await _open(
      tester,
      blob: _blob(
        quickAdds: [
          {'label': 'Sili', 'amount': 20},
        ],
      ),
    );
    expect(store.quickAdds, hasLength(1));
    expect(find.textContaining('Sili'), findsWidgets);
    expect(find.textContaining('Coffee'), findsNothing);
  });
}
