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
import 'package:salapify/money/course_plan.dart';
import 'package:salapify/screens/learn.dart';
import 'package:salapify/screens/path_screen.dart';
import 'package:salapify/widgets/paged_lesson_reader.dart';
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
    expect(find.byType(PagedLessonReader), findsOneWidget);
  });

  testWidgets(
    'finishing every pilot lesson never touches the core progress store',
    (tester) async {
      // This used to assert the on-screen "0 of 22 lessons" figure. That was
      // a PROXY for the invariant, and the founder has since chosen to make
      // the headline count the whole catalog (audit finding H2), so the
      // proxy is gone. The invariant it stood for is unchanged and is now
      // asserted directly: an expansion write must never reach
      // settings.lessonProgress or the legacy lessonsRead list, and must
      // never move a core track's own progress. Checking the store rather
      // than a rendered string is also strictly stronger, since a screen can
      // render the right number for the wrong reason.
      final store = await _freshStore();
      for (final lesson in growYourMoneyLessons) {
        await store.markExpansionLessonCompleted('grow_your_money', lesson.id);
      }
      await _pumpTall(tester, store);

      expect(
        store.lessonProgress,
        isEmpty,
        reason: 'an expansion write leaked into the core progress store',
      );
      for (final t in core.courseTracks) {
        final key = t['key'] as String;
        expect(
          trackProgress(
            trackId: key,
            lessonIds: [
              for (final l in core.lessonsForTrack(key)) l['id'] as String,
            ],
            minutesById: {
              for (final l in core.lessons)
                l['id'] as String: l['minutes'] as int,
            },
            progress: store.lessonProgress,
          ).done,
          0,
          reason: 'core track $key moved because of an expansion write',
        );
      }
      // Only the 5 pilot lessons were completed above; the path's total now
      // includes the Phase 7A course's 6 lessons too, so 5 done out of the
      // real path total, not "5 of 5".
      expect(
        find.text('5 of $_pathLessonTotal lessons in this path'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'All lessons groups the flat list under each course\'s own title, not '
    'one continuous list',
    (tester) async {
      // Phase 16 specialist review: a recommendation reason names a specific
      // course ("Finish Investment Readiness before..."), but the expanded
      // list used to be one flat, ungrouped run of lessons with no way to
      // see what that course actually contains. Grow Your Money has five
      // real courses, so this is a real, reachable case, not a fixture.
      final store = await _freshStore();
      await _pumpTall(tester, store);

      final growCard = find.ancestor(
        of: find.text('Grow Your Money'),
        matching: find.byType(Card),
      );
      await tester.tap(
        find.descendant(
          of: growCard,
          matching: find.widgetWithText(TextButton, 'All courses'),
        ),
      );
      await tester.pumpAndSettle();

      // Since Phase 4 the courses are cards on their own PathScreen rather
      // than kicker headings inside an expanded hub card, so each is a real
      // destination a learner can open directly. That was the whole point:
      // "Crypto Without the Hype" was previously unreachable on its own.
      // Batch C1B tucks the two technical courses behind a "Go deeper"
      // disclosure, so the mainstream three show first and the advanced two
      // are one tap away, still their own cards, never a separate category.
      for (final title in const [
        'Are You Ready to Invest?',
        'Stocks and Bonds Without the Hype',
        'Deposits and Pooled Funds',
      ]) {
        expect(
          find.text(title),
          findsOneWidget,
          reason: 'mainstream course "$title" should be its own card',
        );
      }
      expect(find.text('GO DEEPER'), findsOneWidget);
      for (final title in const [
        'Crypto Without the Hype',
        'Philippine Government Securities',
      ]) {
        expect(
          find.text(title),
          findsNothing,
          reason: 'advanced course "$title" is hidden until Go deeper opens',
        );
      }

      await tester.ensureVisible(find.text('GO DEEPER'));
      await tester.tap(find.text('GO DEEPER'));
      await tester.pumpAndSettle();
      for (final title in const [
        'Crypto Without the Hype',
        'Philippine Government Securities',
      ]) {
        expect(
          find.text(title),
          findsOneWidget,
          reason: 'course "$title" is its own card once Go deeper opens',
        );
      }

      await tester.tap(find.text('Crypto Without the Hype'));
      await tester.pumpAndSettle();
      expect(find.byType(CourseScreen), findsOneWidget);
    },
  );
}
