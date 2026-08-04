// The "Choose Your Next Path" section on the Learn screen, Protect Your
// Future's own coverage (Money Courses Phase 9): shows Protect Your Future
// below Grow Your Money, showing only its one available course (Insurance
// Decoded), with its own independent progress, and never a hard lock. The
// core "X of 22" figure and Grow Your Money's own path progress must never
// move because of it. Mirrors test/learn_screen_grow_path_test.dart's own
// structure on purpose, the established shape for a Money Courses catalog
// test.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/content/learning_paths.dart' show lessonsForPath;
import 'package:salapify/content/lessons.dart' as core;
import 'package:salapify/content/lessons_grow.dart';
import 'package:salapify/content/lessons_insurance.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/screens/learn.dart';
import 'package:salapify/widgets/expansion_lesson_reader.dart';
import 'package:shared_preferences/shared_preferences.dart';

final int _protectPathTotal = lessonsForPath('protect_your_future').length;
final int _growPathTotal = lessonsForPath('grow_your_money').length;

Future<SalapifyStore> _freshStore() async {
  SharedPreferences.setMockInitialValues({});
  final store = SalapifyStore();
  await store.load();
  return store;
}

// Tall enough that the whole catalog (four core tracks plus both path
// cards) renders without the ListView virtualizing any of it away, so a
// plain find.text() works without a scroll-then-tap dance.
Future<void> _pumpTall(WidgetTester tester, SalapifyStore store) async {
  tester.view.physicalSize = const Size(390, 4400) * 3.0;
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: LearnScreen(store: store)));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'Protect Your Future appears below Grow Your Money, showing only its '
    'one available course',
    (tester) async {
      final store = await _freshStore();
      await _pumpTall(tester, store);

      expect(find.text('Protect Your Future'), findsOneWidget);
      expect(
        find.textContaining(
          'Understand your protection needs and compare policy types',
        ),
        findsOneWidget,
      );
      expect(_protectPathTotal, 6);
      expect(
        find.text('0 of $_protectPathTotal lessons in this path'),
        findsOneWidget,
      );
      // No stub or empty government-benefit course card renders alongside
      // it: exactly six lessons, one course, per the task's own catalog
      // rule.
      expect(find.textContaining('Government'), findsNothing);
    },
  );

  testWidgets('Start is never disabled for Protect Your Future', (
    tester,
  ) async {
    final store = await _freshStore();
    await _pumpTall(tester, store);

    // "All lessons" for Protect Your Future's own card expands its list,
    // proving the six real lessons are reachable and every Start/Continue
    // row opens a real reader, never a dead tap.
    final allLessonsButtons = find.widgetWithText(TextButton, 'All lessons');
    expect(allLessonsButtons, findsWidgets);
    await tester.tap(allLessonsButtons.last);
    await tester.pumpAndSettle();
    expect(find.text('What Insurance Is For'), findsOneWidget);

    await tester.tap(find.text('What Insurance Is For'));
    await tester.pumpAndSettle();
    expect(find.byType(ExpansionLessonReader), findsOneWidget);
  });

  testWidgets(
    'finishing every Insurance Decoded lesson never changes the core "X of '
    '22" figure or Grow Your Money\'s own path progress',
    (tester) async {
      final store = await _freshStore();
      for (final lesson in insuranceDecodedLessons) {
        await store.markExpansionLessonCompleted(
          'protect_your_future',
          lesson.id,
        );
      }
      await _pumpTall(tester, store);

      expect(find.text('0 of ${core.lessons.length} lessons'), findsOneWidget);
      expect(
        find.text('0 of ${core.courseTracks.length} courses'),
        findsOneWidget,
      );
      expect(
        find.text(
          '$_protectPathTotal of $_protectPathTotal lessons in this '
          'path',
        ),
        findsOneWidget,
      );
      // Grow Your Money's own path progress stays untouched.
      expect(
        find.text('0 of $_growPathTotal lessons in this path'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'progressing Grow Your Money never changes Protect Your Future\'s own '
    'path progress',
    (tester) async {
      final store = await _freshStore();
      for (final lesson in growYourMoneyLessons) {
        await store.markExpansionLessonCompleted('grow_your_money', lesson.id);
      }
      await _pumpTall(tester, store);

      expect(
        find.text('0 of $_protectPathTotal lessons in this path'),
        findsOneWidget,
      );
    },
  );
}
