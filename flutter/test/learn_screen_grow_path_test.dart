// The "Choose Your Next Path" section on the Learn screen (Money Courses
// Phase 6): shows Grow Your Money below the four core tracks, with its own
// progress, a "Recommended first" prerequisite note, and never a hard lock,
// exactly as this phase's own catalog rules require. The core "X of 22"
// figure and the four-course count must never move because of it.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/content/lessons.dart' as core;
import 'package:salapify/content/lessons_grow.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/screens/learn.dart';
import 'package:salapify/widgets/expansion_lesson_reader.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<SalapifyStore> _freshStore() async {
  SharedPreferences.setMockInitialValues({});
  final store = SalapifyStore();
  await store.load();
  return store;
}

// Tall enough that the whole catalog (four core tracks plus the Grow Your
// Money path card) renders without the ListView virtualizing any of it
// away, so a plain find.text() works without a scroll-then-tap dance.
Future<void> _pumpTall(WidgetTester tester, SalapifyStore store) async {
  tester.view.physicalSize = const Size(390, 4000) * 3.0;
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: LearnScreen(store: store)));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'Grow Your Money appears below Core Money Skills with its own progress',
    (tester) async {
      final store = await _freshStore();
      await _pumpTall(tester, store);

      expect(find.text('CORE MONEY SKILLS'), findsOneWidget);
      expect(find.text('CHOOSE YOUR NEXT PATH'), findsOneWidget);
      expect(find.text('Grow Your Money'), findsOneWidget);
      // Neither absent path ever renders, even as an empty stub.
      expect(find.textContaining('Protect Your Future'), findsNothing);
      expect(find.textContaining('Build Your Business'), findsNothing);
      expect(find.textContaining('Recommended first:'), findsOneWidget);
      expect(find.text('0 of 5 lessons in this path'), findsOneWidget);
    },
  );

  testWidgets('Start is never disabled: the path is never hard-locked', (
    tester,
  ) async {
    final store = await _freshStore();
    await _pumpTall(tester, store);

    final startFinder = find.widgetWithText(FilledButton, 'Start');
    final button = tester.widget<FilledButton>(startFinder.last);
    expect(button.onPressed, isNotNull);

    await tester.tap(startFinder.last);
    await tester.pumpAndSettle();
    expect(find.byType(ExpansionLessonReader), findsOneWidget);
  });

  testWidgets(
    'finishing every pilot lesson never changes the core "X of 22" figure',
    (tester) async {
      final store = await _freshStore();
      for (final lesson in growYourMoneyLessons) {
        await store.markExpansionLessonCompleted('grow_your_money', lesson.id);
      }
      await _pumpTall(tester, store);

      expect(find.text('0 of ${core.lessons.length} lessons'), findsOneWidget);
      expect(
        find.text('0 of ${core.courseTracks.length} courses'),
        findsOneWidget,
      );
      expect(find.text('5 of 5 lessons in this path'), findsOneWidget);
    },
  );
}
