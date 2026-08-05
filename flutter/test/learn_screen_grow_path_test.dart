// The "Choose Your Next Path" section on the Learn screen (Money Courses
// Phase 6): shows Grow Your Money below the four core tracks, with its own
// progress, a "Recommended first" prerequisite note, and never a hard lock,
// exactly as this phase's own catalog rules require. The core "X of 22"
// figure and the four-course count must never move because of it.
//
// The path's own lesson total is read from lessonsForPath('grow_your_money')
// rather than hardcoded, on purpose: Phase 7A registered a second course,
// "Stocks and Bonds Without the Hype" (lessons_stocks_bonds.dart), in the
// SAME path, which grew the path's flattened total from 5 to 11 without
// changing a single pilot lesson. A literal "5" here would have made this
// file look like it was asserting something about the pilot when it was
// really asserting a stale total; reading the real total keeps this test
// honest the next time a third course joins the same path.
//
// Phase 9 published a second real path, Protect Your Future, so this file
// no longer asserts that path is absent (see
// test/learn_screen_protect_path_test.dart for its own catalog coverage).
// Phase 13 published a third real path, Build Your Business, so this file
// no longer asserts that one is absent either (see
// test/learn_screen_business_path_test.dart for its own catalog coverage).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/content/learning_paths.dart' show lessonsForPath;
import 'package:salapify/content/lessons.dart' as core;
import 'package:salapify/content/lessons_grow.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/screens/learn.dart';
import 'package:salapify/widgets/expansion_lesson_reader.dart';
import 'package:shared_preferences/shared_preferences.dart';

final int _pathLessonTotal = lessonsForPath('grow_your_money').length;

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
      // Protect Your Future is a second real, published path as of Phase 9,
      // and Build Your Business is a third as of Phase 13; both now render
      // alongside Grow Your Money.
      expect(find.text('Protect Your Future'), findsOneWidget);
      expect(find.text('Build Your Business'), findsOneWidget);
      // Only Grow Your Money and Protect Your Future carry a "Recommended
      // first" prerequisite note; Build Your Business has no
      // prerequisiteLessonIds (see learning_paths.dart), so the count stays
      // 2, not 3. See learn_screen_protect_path_test.dart and
      // learn_screen_business_path_test.dart for each path's own card
      // content.
      expect(find.textContaining('Recommended first:'), findsNWidgets(2));
      expect(
        find.text('0 of $_pathLessonTotal lessons in this path'),
        findsOneWidget,
      );
    },
  );

  testWidgets('Start is never disabled: the path is never hard-locked', (
    tester,
  ) async {
    final store = await _freshStore();
    await _pumpTall(tester, store);

    // Scoped to Grow Your Money's own Card, not '.last': Phase 9 and Phase
    // 13 each added a path card below this one (Protect Your Future, then
    // Build Your Business), so '.last' would now tap a different path's
    // Start button and this test would silently stop testing Grow Your
    // Money, the one thing its own name claims to cover.
    final growCard = find.ancestor(
      of: find.text('Grow Your Money'),
      matching: find.byType(Card),
    );
    final startFinder = find.descendant(
      of: growCard,
      matching: find.widgetWithText(FilledButton, 'Start'),
    );
    expect(startFinder, findsOneWidget);
    final button = tester.widget<FilledButton>(startFinder);
    expect(button.onPressed, isNotNull);

    await tester.tap(startFinder);
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
      // Only the 5 pilot lessons were completed above; the path's total now
      // includes the Phase 7A course's 6 lessons too, so 5 done out of the
      // real path total, not "5 of 5".
      expect(
        find.text('5 of $_pathLessonTotal lessons in this path'),
        findsOneWidget,
      );
    },
  );
}
