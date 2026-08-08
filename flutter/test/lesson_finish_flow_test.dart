// The end of a lesson: what it says, what it offers next, and what it looks
// like when you come back to a lesson you already finished.
//
// This file exists because the finish moment used to be a dead end (one
// quiet row and a back button) and because an already-finished expansion
// lesson reopened showing zero progress over a disabled Finish button. Both
// were filed by the experience audit, C2 and C6.
//
// Every test here was proven to fail against the old behaviour before it was
// trusted; the failure lines are in the commit message.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/content/lessons_grow.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/main.dart';
import 'package:salapify/money/lesson_progress.dart';
import 'package:salapify/screens/learn.dart';
import 'package:salapify/theme.dart';
import 'package:salapify/widgets/expansion_lesson_reader.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens_shot.dart' show loadRealFonts;
import 'support/app_harness.dart';

Future<void> _openCourses(WidgetTester tester) async {
  await openFromMenu(tester, 'Calculators');
  await tester.scrollUntilVisible(
    find.text('Money courses'),
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(find.text('Money courses'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('finishing a lesson offers the next one by name', (tester) async {
    SharedPreferences.setMockInitialValues(onboardedEmptyStorage());
    final store = SalapifyStore();
    await tester.pumpWidget(SalapifyApp(store: store));
    await tester.pumpAndSettle();
    await _openCourses(tester);

    await tester.tap(find.text('Start').first);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Finish this lesson'), 250);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Finish this lesson'));
    await tester.pumpAndSettle();

    // The whole point: the lesson hands over the next one instead of
    // stranding the reader on a back button.
    expect(
      find.textContaining('Next:'),
      findsOneWidget,
      reason: 'a finished lesson must offer the next lesson',
    );
    expect(find.text('Back to courses'), findsOneWidget);
  });

  testWidgets('the next button actually moves to the next lesson', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(onboardedEmptyStorage());
    final store = SalapifyStore();
    await tester.pumpWidget(SalapifyApp(store: store));
    await tester.pumpAndSettle();
    await _openCourses(tester);

    await tester.tap(find.text('Start').first);
    await tester.pumpAndSettle();
    // The position label in the app bar is the one piece of state that is
    // always on screen without scrolling, which makes it the honest way to
    // assert navigation actually happened.
    expect(find.textContaining('1 of 6 ·'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Finish this lesson'), 250);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Finish this lesson'));
    await tester.pumpAndSettle();
    // The finish card grows taller than the button it replaced, so the Next
    // button can sit below the fold. Scroll to it, or the tap silently
    // misses and only warns.
    await tester.scrollUntilVisible(find.textContaining('Next:'), 250);
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Next:'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('2 of 6 ·'),
      findsOneWidget,
      reason: 'tapping Next must land on the following lesson',
    );
    expect(find.textContaining('1 of 6 ·'), findsNothing);
  });

  testWidgets('a finished core lesson reopens finished, not blank', (
    tester,
  ) async {
    // Seeded as already finished, then opened straight to that lesson via
    // focusId, so this tests the reopen path itself rather than a hub
    // navigation that could fail for unrelated reasons.
    SharedPreferences.setMockInitialValues(onboardedEmptyStorage());
    final store = SalapifyStore();
    await store.load();
    await store.setLessonState('see-it-first', LessonState.completed);

    await tester.pumpWidget(
      MaterialApp(
        theme: salapifyTheme(Barako.current),
        home: LearnScreen(store: store, focusId: 'see-it-first'),
      ),
    );
    await tester.pumpAndSettle();

    // Throws if the finish card never appears, which is the real assertion.
    await tester.scrollUntilVisible(find.text('Back to courses'), 250);
    await tester.pumpAndSettle();
    expect(
      find.text('Finish this lesson'),
      findsNothing,
      reason: 'a lesson already finished must not ask to be finished again',
    );
    expect(find.text('Done. One useful thing.'), findsOneWidget);
  });

  group('expansion reader', () {
    testWidgets('a completed lesson reopens done, with no interaction gate', (
      tester,
    ) async {
      // The C6 regression guard. Completion lived only in the reader's own
      // widget state, so reopening a finished lesson showed
      // "0 of N required interactions completed" over a disabled Finish
      // button while the hub showed its tick.
      SharedPreferences.setMockInitialValues({});
      final store = SalapifyStore();
      await store.load();
      final lesson = growYourMoneyLessons.firstWhere(
        (l) => l.id == investRefMoneyJob,
      );
      await store.markExpansionLessonCompleted('grow_your_money', lesson.id);
      expect(
        isDone(store.expansionProgressFor('grow_your_money')[lesson.id]!),
        isTrue,
        reason: 'fixture must actually record the lesson as done',
      );

      await loadRealFonts(tester);
      tester.view.physicalSize = const Size(390, 6000) * 3.0;
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      Barako.current = Barako.currentTheme.resolve(Brightness.dark);
      await tester.pumpWidget(
        MaterialApp(
          theme: salapifyTheme(Barako.current),
          home: ExpansionLessonReader(
            pathId: 'grow_your_money',
            lesson: lesson,
            store: store,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('required interactions completed'),
        findsNothing,
        reason: 'earned progress must never be shown back as zero',
      );
      expect(find.text('Finish this lesson'), findsNothing);
      expect(find.textContaining('Done.'), findsOneWidget);
    });

    testWidgets('an unfinished lesson still gates finishing', (tester) async {
      // The other half of the alarm: the fix must not hand out completion to
      // a lesson nobody has done. A guard that only ever says yes is not a
      // guard.
      SharedPreferences.setMockInitialValues({});
      final store = SalapifyStore();
      await store.load();
      final lesson = growYourMoneyLessons.firstWhere(
        (l) => l.id == investRefMoneyJob,
      );

      await loadRealFonts(tester);
      tester.view.physicalSize = const Size(390, 6000) * 3.0;
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      Barako.current = Barako.currentTheme.resolve(Brightness.dark);
      await tester.pumpWidget(
        MaterialApp(
          theme: salapifyTheme(Barako.current),
          home: ExpansionLessonReader(
            pathId: 'grow_your_money',
            lesson: lesson,
            store: store,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('required interactions completed'),
        findsOneWidget,
        reason: 'an untouched lesson must still show its gate',
      );
      final button = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Finish this lesson'),
      );
      expect(button.onPressed, isNull, reason: 'the gate must still be shut');
    });
  });
}
