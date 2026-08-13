// The Money courses journey hero, added in Phase 6B Batch B.
//
// The screen used to open on four track cards with no single answer to "what
// do I do next": a first visitor had to choose among 22 lessons, and a
// returning one had to hunt for their active lesson. The hero answers that in
// one card, before anything else, reusing nextCoreLesson (the same
// deterministic pick Home makes) so it is a surface for that decision, never a
// second recommendation engine.
//
// Two states matter and are guarded here: START HERE names the first lesson to
// a blank slate, and CONTINUE names the next unfinished lesson once anything
// has been opened. A third guard holds the one content addition this batch
// makes: lesson one now teaches financial position (net worth) in plain words.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/content/lessons.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/money/lesson_progress.dart';
import 'package:salapify/screens/learn.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/app_harness.dart';

Future<SalapifyStore> _store() async {
  SharedPreferences.setMockInitialValues(onboardedEmptyStorage());
  final s = SalapifyStore();
  await s.load();
  return s;
}

Future<void> _pump(WidgetTester tester, SalapifyStore store) async {
  await tester.pumpWidget(MaterialApp(home: LearnScreen(store: store)));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a blank slate is told exactly where to START HERE', (
    tester,
  ) async {
    final store = await _store();
    await _pump(tester, store);

    expect(find.text('START HERE'), findsOneWidget);
    expect(find.text('CONTINUE'), findsNothing);
    // The hero names the first lesson of the recommended starting track, so
    // the reader never has to choose it out of a list. The title also appears
    // in the auto-opened track below, so the hero is identified by its own
    // spoken label rather than by the bare title.
    expect(
      find.bySemanticsLabel(
        RegExp(r'START HERE\. See where your money stands\.'),
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'once a lesson is done the hero says CONTINUE with the next one',
    (tester) async {
      final store = await _store();
      // Finish the first lesson; the deterministic next core lesson is the
      // second one in the cushion track.
      store.setLessonState('see-it-first', LessonState.completed);
      await _pump(tester, store);

      expect(find.text('CONTINUE'), findsOneWidget);
      expect(find.text('START HERE'), findsNothing);
      expect(
        find.bySemanticsLabel(
          RegExp(r'CONTINUE\. Needs, wants, and the 24-hour rule\.'),
        ),
        findsOneWidget,
      );
    },
  );

  test('lesson one teaches net worth in plain words, once', () {
    final first = lessons.firstWhere((l) => l['id'] == 'see-it-first');
    final blob = first.toString();
    // The plain-words financial-position frame this batch added: what you own
    // minus what you owe is your net worth, said without accounting jargon.
    expect(blob.contains('net worth'), isTrue);
    expect(blob.contains('What is left is your net worth'), isTrue);
    // It stays connected to the two Salapify screens that already show it,
    // rather than being an abstract definition.
    expect(blob.contains('Accounts'), isTrue);
    expect(blob.contains('Overview'), isTrue);
  });
}
