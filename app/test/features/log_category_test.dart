// The Log sheet asks when it does not know.
//
// The chips were always there and always tappable. What was missing is that
// eight identical unselected chips under a silent "Category" heading read as
// decoration rather than as a question, so an unrecognised word got saved with
// no category at all and nobody noticed until the entry was already in the
// ledger. The founder hit exactly that typing "kain 120" on an emulator.
//
// This is the better answer than chasing the vocabulary forever. No word list
// can cover how everybody writes; a list that ADMITS what it does not know, in
// the one second before saving, can.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/app/ledger_scope.dart';
import 'package:salapify/app/router.dart';
import 'package:salapify/core/data/ledger_store.dart';
import 'package:salapify/design/kit.dart';
import 'package:salapify/design/tokens.dart';

import '../support/memory_store.dart';

Widget _app(LedgerStore store) => LedgerScope(
  store: store,
  child: MaterialApp.router(
    theme: salapifyTheme(gabi),
    routerConfig: buildRouter(),
  ),
);

Future<void> _type(WidgetTester tester, String line) async {
  await tester.tap(
    find.descendant(of: find.byType(NavBar), matching: find.text('Log')),
  );
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField), line);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a word it does not know asks for the category', (tester) async {
    final store = await memoryStore(livedIn());
    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();

    // A word no vocabulary will ever contain.
    await _type(tester, 'zorbtronic 450');

    expect(find.text('Category, tap one'), findsOneWidget);
    expect(find.text('Category'), findsNothing);
  });

  testWidgets('a word it knows just says Category, with the guess on', (
    tester,
  ) async {
    final store = await memoryStore(livedIn());
    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();

    await _type(tester, 'jollibee 250');

    // No nagging when there is nothing to ask. A prompt that is always there
    // is not a prompt.
    expect(find.text('Category'), findsOneWidget);
    expect(find.text('Category, tap one'), findsNothing);
  });

  testWidgets('tapping a chip answers it, and the prompt goes away', (
    tester,
  ) async {
    final store = await memoryStore(livedIn());
    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();

    await _type(tester, 'zorbtronic 450');
    expect(find.text('Category, tap one'), findsOneWidget);

    await tester.tap(find.text('Food'));
    await tester.pumpAndSettle();

    expect(find.text('Category'), findsOneWidget);
    expect(find.text('Category, tap one'), findsNothing);

    // And the pick is what gets SAVED, which is the whole point. A prompt that
    // does not reach the stored row is decoration with extra steps.
    await tester.tap(find.text('Save entry'));
    await tester.pumpAndSettle();

    final saved = (store.data['transactions'] as List).last as Map;
    expect(saved['label'], 'Zorbtronic');
    expect(saved['amount'], 450.0);
    expect(saved['categoryId'], 'cat_food');
  });
}
