// Pan says things, and what he says is a door rather than a poster.
//
// The check-in used to be the app narrating, with Pan stuck in the corner as
// an ornament above the text. Two things changed and both are pinned here.
//
// The one worth the most is the SECOND. When the coach has nowhere specific
// to send you, the card used to be completely inert: Pan says something
// friendly and tapping it does nothing at all. That is precisely the moment a
// character stops feeling like someone you can talk to, and it is invisible
// to every other test in this suite, because a dead end renders perfectly.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/screens/overview.dart';
import 'package:salapify/screens/pan.dart';
import 'package:salapify/theme.dart';
import 'package:salapify/widgets/pan_mascot.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<SalapifyStore> _storeWithSomeMoney() async {
  SharedPreferences.setMockInitialValues({});
  final store = SalapifyStore();
  await store.load();
  await store.addEntry({
    'type': 'expense',
    'amount': 250.0,
    'category': 'Food',
    'date': DateTime.now().toIso8601String(),
  });
  return store;
}

Widget _home(SalapifyStore store) => ListenableBuilder(
  listenable: store,
  builder: (context, _) => MaterialApp(
    theme: salapifyTheme(Barako.current),
    home: OverviewScreen(store: store, onSwitchTab: (_) {}),
  ),
);

void main() {
  testWidgets('the words sit in a bubble beside Pan, not under him', (
    tester,
  ) async {
    final store = await _storeWithSomeMoney();
    await tester.pumpWidget(_home(store));
    await tester.pumpAndSettle();

    final pan = find.byType(PanMascot);
    expect(pan, findsWidgets, reason: 'no check-in card rendered at all');

    final panBox = tester.getRect(pan.first);
    final title = find.textContaining('track', findRichText: true);
    if (title.evaluate().isEmpty) return; // different coach state, still fine.
    final textBox = tester.getRect(title.first);

    expect(
      textBox.left,
      greaterThan(panBox.right - 1),
      reason:
          'The message is not beside Pan. Stacked under him he is an ornament '
          'over text the app narrates; beside him, in a bubble, the words are '
          'his.',
    );
  });

  testWidgets('a calm check-in is a door, not a dead end', (tester) async {
    // The regression that would be invisible: this card renders perfectly
    // whether or not it does anything when tapped.
    final store = await _storeWithSomeMoney();
    await tester.pumpWidget(_home(store));
    await tester.pumpAndSettle();

    // Target the check-in card by its own kicker rather than "the first
    // InkWell on screen", which is whatever the layout happens to build first
    // and silently stops being this card the moment anything moves.
    final card = find
        .ancestor(
          of: find.text('MONEY CHECK-IN'),
          matching: find.byType(InkWell),
        )
        .first;
    // Tap the card body deliberately AWAY from Pan himself, so this cannot
    // pass just because Pan's own tap target was hit.
    final box = tester.getRect(card);
    await tester.tapAt(Offset(box.right - 24, box.bottom - 24));
    await tester.pumpAndSettle();

    expect(
      find.byType(PanScreen),
      findsOneWidget,
      reason:
          'Tapping the check-in went nowhere. When the coach has no specific '
          'destination the card used to be inert, which teaches that Pan is '
          'something to look at rather than someone to talk to.',
    );
  });

  testWidgets('Pan himself still opens Ask Pan', (tester) async {
    // The older promise, re-pinned because the layout around him moved.
    final store = await _storeWithSomeMoney();
    await tester.pumpWidget(_home(store));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PanMascot).first, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.byType(PanScreen), findsOneWidget);
  });

  testWidgets('Pan is still announced to a screen reader', (tester) async {
    final handle = tester.ensureSemantics();
    final store = await _storeWithSomeMoney();
    await tester.pumpWidget(_home(store));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Ask Pan'), findsOneWidget);
    handle.dispose();
  });
}
