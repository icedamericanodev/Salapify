// Store-level vectors for the real "Are You Ready to Invest?" pilot content
// (lib/content/lessons_grow.dart), as distinct from
// test/expansion_progress_store_test.dart's generic fixture ids: this file
// proves the ACTUAL registered pilot lessons persist across a simulated
// restart, round-trip through backup export and import, and never touch
// the core 22 lessons' progress, using the real ids a change to
// lessons_grow.dart could actually break.
//
// Progress is computed against the pilot's OWN five ids
// (growYourMoneyLessons), not against learningPaths.first.lessonIds: Phase
// 7A registered a second course, "Stocks and Bonds Without the Hype", in
// the SAME path, so the path's flattened id list now has 11 entries. This
// file is about the pilot specifically, so it scopes to the pilot's own
// list rather than the whole path's, keeping every assertion below exactly
// what it always was.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/content/lessons_grow.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/money/lesson_progress.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _pathId = 'grow_your_money';
final _pilotLessonIds = growYourMoneyLessons.map((l) => l.id).toList();

Future<SalapifyStore> _freshStore() async {
  SharedPreferences.setMockInitialValues({});
  final store = SalapifyStore();
  await store.load();
  return store;
}

void main() {
  group('the real pilot path progresses correctly', () {
    test(
      'opening the first lesson, then finishing it, folds into path progress',
      () async {
        final store = await _freshStore();
        await store.markExpansionLessonStarted(_pathId, investRefMoneyJob);
        var progress = store.expansionPathProgress(
          pathId: _pathId,
          lessonIds: _pilotLessonIds,
        );
        expect(progress.total, 5);
        expect(progress.done, 0, reason: 'viewed alone does not count as done');

        await store.markExpansionLessonCompleted(_pathId, investRefMoneyJob);
        progress = store.expansionPathProgress(
          pathId: _pathId,
          lessonIds: _pilotLessonIds,
        );
        expect(progress.done, 1);
        expect(progress.fraction, closeTo(1 / 5, 1e-9));
        expect(progress.isComplete, isFalse);
      },
    );

    test('completing all five real lessons completes the path', () async {
      final store = await _freshStore();
      for (final id in _pilotLessonIds) {
        await store.markExpansionLessonCompleted(_pathId, id);
      }
      final progress = store.expansionPathProgress(
        pathId: _pathId,
        lessonIds: _pilotLessonIds,
      );
      expect(progress.total, 5);
      expect(progress.done, 5);
      expect(progress.isComplete, isTrue);
    });

    test(
      'marking a lesson applied never demotes an already-completed lesson',
      () async {
        final store = await _freshStore();
        await store.markExpansionLessonCompleted(_pathId, investRefCard);
        await store.markExpansionLessonStarted(_pathId, investRefCard);
        expect(
          store.expansionProgressFor(_pathId)[investRefCard],
          LessonState.completed,
          reason: 'starting again must never demote a completed lesson',
        );
        await store.markExpansionLessonApplied(_pathId, investRefCard);
        expect(
          store.expansionProgressFor(_pathId)[investRefCard],
          LessonState.applied,
          reason: 'applied outranks completed',
        );
      },
    );
  });

  group('the core 22 are never touched by the real pilot content', () {
    test(
      'progressing every pilot lesson leaves core lessonProgress empty',
      () async {
        final store = await _freshStore();
        for (final id in _pilotLessonIds) {
          await store.markExpansionLessonCompleted(_pathId, id);
        }
        expect(store.lessonProgress, isEmpty);
        expect(
          (store.data['settings'] as Map).containsKey('lessonsRead'),
          isFalse,
        );
      },
    );
  });

  group('persistence across a simulated restart', () {
    test(
      'real pilot progress survives a fresh store reading the same disk state',
      () async {
        final store = await _freshStore();
        await store.markExpansionLessonCompleted(_pathId, investRefMoneyJob);
        await store.markExpansionLessonStarted(_pathId, investRefProtectBase);

        final second = SalapifyStore();
        await second.load();
        expect(
          second.expansionProgressFor(_pathId)[investRefMoneyJob],
          LessonState.completed,
        );
        expect(
          second.expansionProgressFor(_pathId)[investRefProtectBase],
          LessonState.viewed,
        );
      },
    );
  });

  group('backup export and restore', () {
    test('real pilot progress round-trips through export and import', () async {
      final store = await _freshStore();
      await store.markExpansionLessonCompleted(_pathId, investRefMoneyJob);
      await store.markExpansionLessonCompleted(
        _pathId,
        investRefGoalTimeAccess,
      );
      final text = store.exportBackupText();

      SharedPreferences.setMockInitialValues({});
      final restored = SalapifyStore();
      await restored.load();
      await restored.importBackupText(text);

      expect(
        restored.expansionProgressFor(_pathId)[investRefMoneyJob],
        LessonState.completed,
      );
      expect(
        restored.expansionProgressFor(_pathId)[investRefGoalTimeAccess],
        LessonState.completed,
      );
      // The lesson never started stays unrecorded, exactly as if it were a
      // fresh install, never a false "in progress".
      expect(
        restored.expansionProgressFor(_pathId)[investRefRiskComfortCapacity],
        isNull,
      );
    });

    test(
      'a backup with no pilot progress omits the expansionProgress key',
      () async {
        final store = await _freshStore();
        final text = store.exportBackupText();
        final decoded = jsonDecode(text) as Map<String, dynamic>;
        final settings = (decoded['data'] as Map)['settings'] as Map;
        expect(settings.containsKey('expansionProgress'), isFalse);
      },
    );
  });
}
