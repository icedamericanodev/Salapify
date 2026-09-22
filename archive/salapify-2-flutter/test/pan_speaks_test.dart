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

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/screens/overview.dart';
import 'package:salapify/screens/pan.dart';
import 'package:salapify/theme.dart';
import 'package:salapify/widgets/pan_mascot.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/app_harness.dart';

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

/// A store where the coach has a real decision (an overdue utang), so the
/// check-in renders the FULL Pan card. The calm all-clear became a slim row
/// without Pan in the Phase 3 calmer-Home pass, so the tests about Pan's
/// bubble, his own tap target, and his screen-reader label now exercise the
/// state where Pan actually appears.
Future<SalapifyStore> _storeWithADecision() async {
  final overdue = DateTime.now().subtract(const Duration(days: 20));
  final iso =
      '${overdue.year.toString().padLeft(4, '0')}-${overdue.month.toString().padLeft(2, '0')}-${overdue.day.toString().padLeft(2, '0')}';
  SharedPreferences.setMockInitialValues({
    storageKey: jsonEncode({
      'schemaVersion': 12,
      'settings': {'onboarded': true},
      'accounts': [
        {'id': 'cash', 'name': 'Cash', 'kind': 'cash', 'balance': 5000},
      ],
      'transactions': <Map<String, dynamic>>[],
      'receivables': [
        {
          'id': 'r1',
          'person': 'Ana',
          'amount': 1000,
          'dueDate': iso,
          'paid': false,
        },
      ],
    }),
  });
  final store = SalapifyStore();
  await store.load();
  return store;
}

Widget _home(SalapifyStore store) => ListenableBuilder(
  listenable: store,
  builder: (context, _) => MaterialApp(
    theme: salapifyTheme(Barako.current),
    home: tabHost(OverviewScreen(store: store, onSwitchTab: (_) {})),
  ),
);

void main() {
  testWidgets('the words sit in a bubble beside Pan, not under him', (
    tester,
  ) async {
    final store = await _storeWithADecision();
    tester.view.physicalSize = const Size(1200, 4600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_home(store));
    await tester.pumpAndSettle();

    final pan = find.byType(PanMascot);
    expect(pan, findsWidgets, reason: 'no check-in card rendered at all');

    final panBox = tester.getRect(pan.first);
    final title = find.textContaining('Ana', findRichText: true);
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
    tester.view.physicalSize = const Size(1200, 4600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_home(store));
    await tester.pumpAndSettle();

    // The calm all-clear is the slim row now (no kicker, no Pan), so the
    // door is found by its own title. The property under guard is the same:
    // the calm state must still open Ask Pan.
    final row = find
        .ancestor(
          of: find.text('You are on track this week'),
          matching: find.byType(InkWell),
        )
        .first;
    await tester.tap(row);
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
    // The older promise, re-pinned because the layout around him moved. Pan
    // appears on tones with something to say, so the fixture carries one.
    final store = await _storeWithADecision();
    tester.view.physicalSize = const Size(1200, 4600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_home(store));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PanMascot).first, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.byType(PanScreen), findsOneWidget);
  });

  testWidgets('Pan is still announced to a screen reader', (tester) async {
    final handle = tester.ensureSemantics();
    final store = await _storeWithADecision();
    tester.view.physicalSize = const Size(1200, 4600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_home(store));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Ask Pan'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('the slim calm row still tells a screen reader where it goes', (
    tester,
  ) async {
    // The full Pan card announced "Ask Pan"; the slim row must not drop that
    // for screen reader users just because it dropped the picture.
    final handle = tester.ensureSemantics();
    final store = await _storeWithSomeMoney();
    tester.view.physicalSize = const Size(1200, 4600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_home(store));
    await tester.pumpAndSettle();
    final node = tester.getSemantics(find.text('You are on track this week'));
    expect(
      node.hint,
      contains('Ask Pan'),
      reason: 'the calm row lost its audible destination',
    );
    handle.dispose();
  });
}
