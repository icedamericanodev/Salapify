// The lesson offer on Home.
//
// Money Courses lives behind Menu, Tools, and a row under the currency
// converter, which the experience audit called the single biggest cap on
// completion: the best lesson in the world finishes at zero percent behind a
// door nobody opens. This is the guard on the door being open.
//
// Proven to fail before being trusted; failure lines are in the commit
// message.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/content/course_sequences.dart';
import 'package:salapify/content/lessons.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/money/lesson_progress.dart';
import 'package:salapify/screens/learn.dart';
import 'package:salapify/screens/overview.dart';
import 'package:salapify/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/app_harness.dart';

final _now = DateTime(2026, 8, 6);

Map<String, LessonState> _done(Iterable<String> ids) => {
  for (final id in ids) id: LessonState.completed,
};

Future<SalapifyStore> _store() async {
  SharedPreferences.setMockInitialValues(onboardedEmptyStorage());
  final store = SalapifyStore();
  await store.load();
  return store;
}

void main() {
  group('nextCoreLesson', () {
    test('offers a real lesson to someone brand new', () async {
      final store = await _store();
      final l = nextCoreLesson(data: store.data, progress: const {}, now: _now);
      expect(l, isNotNull);
      expect(lessonById(l!.id), isNotNull, reason: 'must be a real lesson');
      expect(l.minutes, greaterThan(0));
    });

    test('never offers a lesson already finished', () async {
      final store = await _store();
      final first = nextCoreLesson(
        data: store.data,
        progress: const {},
        now: _now,
      )!;
      final second = nextCoreLesson(
        data: store.data,
        progress: _done([first.id]),
        now: _now,
      );
      expect(second, isNotNull);
      expect(second!.id, isNot(first.id));
    });

    test('an applied lesson counts as finished too', () async {
      final store = await _store();
      final first = nextCoreLesson(
        data: store.data,
        progress: const {},
        now: _now,
      )!;
      final second = nextCoreLesson(
        data: store.data,
        progress: {first.id: LessonState.applied},
        now: _now,
      );
      expect(second!.id, isNot(first.id));
    });

    test('offers nothing once every core lesson is done', () async {
      final store = await _store();
      final all = _done([for (final l in lessons) l['id'] as String]);
      expect(
        nextCoreLesson(data: store.data, progress: all, now: _now),
        isNull,
        reason: 'the card must disappear, never congratulate itself forever',
      );
    });

    test('falls back across tracks when the recommended one is done', () async {
      // A learner who finished the whole recommended track must still be
      // offered something, not nothing.
      final store = await _store();
      final rec = nextCoreLesson(
        data: store.data,
        progress: const {},
        now: _now,
      )!;
      final trackDone = _done([
        for (final l in lessonsForTrack(rec.groupId)) l['id'] as String,
      ]);
      final next = nextCoreLesson(
        data: store.data,
        progress: trackDone,
        now: _now,
      );
      expect(next, isNotNull);
      expect(next!.groupId, isNot(rec.groupId));
    });
  });

  group('on the Home screen', () {
    testWidgets('the card is there and names a lesson', (tester) async {
      final store = await _store();
      Barako.current = Barako.currentTheme.resolve(Brightness.dark);
      tester.view.physicalSize = const Size(390, 4000) * 3.0;
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: salapifyTheme(Barako.current),
          home: OverviewScreen(store: store, clock: () => _now),
        ),
      );
      await tester.pumpAndSettle();

      final expected = nextCoreLesson(
        data: store.data,
        progress: store.lessonProgress,
        now: _now,
      )!;
      expect(find.textContaining('MIN LESSON'), findsOneWidget);
      expect(find.text(expected.title), findsOneWidget);
    });

    testWidgets('tapping it opens Money courses on that lesson', (
      tester,
    ) async {
      final store = await _store();
      Barako.current = Barako.currentTheme.resolve(Brightness.dark);
      tester.view.physicalSize = const Size(390, 4000) * 3.0;
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: salapifyTheme(Barako.current),
          home: OverviewScreen(store: store, clock: () => _now),
        ),
      );
      await tester.pumpAndSettle();

      final expected = nextCoreLesson(
        data: store.data,
        progress: store.lessonProgress,
        now: _now,
      )!;
      await tester.tap(find.text(expected.title));
      await tester.pumpAndSettle();

      // skipOffstage: false because focusId immediately pushes the lesson
      // reader on top, which puts the catalog underneath it offstage. The
      // default finder would report the screen missing when it is simply
      // behind the thing it opened.
      expect(find.byType(LearnScreen, skipOffstage: false), findsOneWidget);
      // And the reader really is showing THAT lesson: the app bar position
      // label names its course.
      expect(find.textContaining(' of '), findsWidgets);
      expect(find.text(expected.title), findsWidgets);
    });
  });
}
