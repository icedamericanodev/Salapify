// The "Choose Your Next Path" section on the Learn screen, Protect Your
// Future's own coverage (Money Courses Phase 9, extended by Phase 10 and
// Phase 11): shows Protect Your Future below Grow Your Money, with its own
// independent progress, and never a hard lock. Phase 9 shipped this path's
// first course (Insurance Decoded); Phase 10 added its second (SSS &
// PhilHealth Essentials); Phase 11 adds its third (Pag-IBIG Savings &
// Housing), so the path card now lists all three courses' lessons flattened
// together, per screens/learn.dart's own one-card-per-path design (it has no
// per-course sub-card, only a flat "All lessons" list across every group).
// The core "X of 22" figure and Grow Your Money's own path progress must
// never move because of it. Mirrors test/learn_screen_grow_path_test.dart's
// own structure on purpose, the established shape for a Money Courses
// catalog test.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/content/learning_paths.dart' show lessonsForPath;
import 'package:salapify/content/lessons.dart' as core;
import 'package:salapify/content/lessons_grow.dart';
import 'package:salapify/content/lessons_insurance.dart';
import 'package:salapify/content/lessons_pagibig.dart';
import 'package:salapify/content/lessons_sss_philhealth.dart';
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
    'Protect Your Future appears below Grow Your Money, listing both of '
    'its courses\' lessons in one flat path total',
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
      // Six from Insurance Decoded (Phase 9), six from SSS & PhilHealth
      // Essentials (Phase 10), and six from Pag-IBIG Savings & Housing
      // (Phase 11), flattened into one path total per screens/learn.dart's
      // own one-card-per-path design.
      expect(_protectPathTotal, 18);
      expect(
        find.text('0 of $_protectPathTotal lessons in this path'),
        findsOneWidget,
      );
      // Still no stub or empty government-benefit course card: every group
      // under this path carries real, published lessons.
      expect(find.textContaining('Government'), findsNothing);
    },
  );

  testWidgets('Start is never disabled for Protect Your Future', (
    tester,
  ) async {
    final store = await _freshStore();
    await _pumpTall(tester, store);

    // Scoped to Protect Your Future's own Card, not '.last': Phase 13 added
    // a third path card (Build Your Business) below this one, so '.last'
    // would now tap the wrong path's "All lessons" button and this test
    // would silently start asserting something about a different course.
    // Each path renders as one Card (screens/learn.dart's _pathCard), so
    // finding the Card that contains this path's own title text scopes
    // every descendant search to it, however many paths render after it.
    final protectCard = find.ancestor(
      of: find.text('Protect Your Future'),
      matching: find.byType(Card),
    );
    final allLessonsButton = find.descendant(
      of: protectCard,
      matching: find.widgetWithText(TextButton, 'All lessons'),
    );
    expect(allLessonsButton, findsOneWidget);
    await tester.tap(allLessonsButton);
    await tester.pumpAndSettle();
    expect(find.text('What Insurance Is For'), findsOneWidget);
    expect(find.text('Meet Your Two Safety Nets'), findsOneWidget);

    await tester.tap(find.text('What Insurance Is For'));
    await tester.pumpAndSettle();
    expect(find.byType(ExpansionLessonReader), findsOneWidget);
  });

  testWidgets(
    'finishing every lesson in all three Protect Your Future courses never '
    'changes the core "X of 22" figure or Grow Your Money\'s own path '
    'progress',
    (tester) async {
      final store = await _freshStore();
      for (final lesson in [
        ...insuranceDecodedLessons,
        ...sssPhilhealthBenefitsLessons,
        ...pagibigSavingsMp2HousingLessons,
      ]) {
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
