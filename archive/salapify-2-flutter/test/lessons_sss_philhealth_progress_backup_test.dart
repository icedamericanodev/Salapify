// Store-level vectors for the real "SSS & PhilHealth Essentials" course
// (lib/content/lessons_sss_philhealth.dart), the same shape as
// lessons_insurance_progress_backup_test.dart: proves the ACTUAL registered
// lessons persist across a simulated restart, round-trip through backup
// export and import, and never touch the core 22 lessons' progress, any
// Grow Your Money course's own progress, or Insurance Decoded's own
// progress, even though both courses share the same 'protect_your_future'
// expansion-progress namespace. This is also the proof that a second course
// under the SAME path keeps its own lessons' progress independent of the
// first course's lessons, since expansion progress is keyed by path id, not
// by course id.

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/content/lessons_grow.dart';
import 'package:salapify/content/lessons_insurance.dart';
import 'package:salapify/content/lessons_sss_philhealth.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/money/lesson_progress.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _pathId = 'protect_your_future';
const _otherPathId = 'grow_your_money';
final _lessonIds = sssPhilhealthBenefitsLessons.map((l) => l.id).toList();
final _insuranceLessonIds = insuranceDecodedLessons.map((l) => l.id).toList();

Future<SalapifyStore> _freshStore() async {
  SharedPreferences.setMockInitialValues({});
  final store = SalapifyStore();
  await store.load();
  return store;
}

void main() {
  group('the real course progresses correctly', () {
    test(
      'opening the first lesson, then finishing it, folds into path progress',
      () async {
        final store = await _freshStore();
        await store.markExpansionLessonStarted(_pathId, sspRefTwoSafetyNets);
        var progress = store.expansionPathProgress(
          pathId: _pathId,
          lessonIds: _lessonIds,
        );
        expect(progress.total, 6);
        expect(progress.done, 0, reason: 'viewed alone does not count as done');

        await store.markExpansionLessonCompleted(_pathId, sspRefTwoSafetyNets);
        progress = store.expansionPathProgress(
          pathId: _pathId,
          lessonIds: _lessonIds,
        );
        expect(progress.done, 1);
        expect(progress.fraction, closeTo(1 / 6, 1e-9));
        expect(progress.isComplete, isFalse);
      },
    );

    test('completing all six real lessons completes the course', () async {
      final store = await _freshStore();
      for (final id in _lessonIds) {
        await store.markExpansionLessonCompleted(_pathId, id);
      }
      final progress = store.expansionPathProgress(
        pathId: _pathId,
        lessonIds: _lessonIds,
      );
      expect(progress.total, 6);
      expect(progress.done, 6);
      expect(progress.isComplete, isTrue);
    });

    test(
      'marking a lesson applied never demotes an already-completed lesson',
      () async {
        final store = await _freshStore();
        await store.markExpansionLessonCompleted(_pathId, sspRefSafetyNetPlan);
        await store.markExpansionLessonStarted(_pathId, sspRefSafetyNetPlan);
        expect(
          store.expansionProgressFor(_pathId)[sspRefSafetyNetPlan],
          LessonState.completed,
          reason: 'starting again must never demote a completed lesson',
        );
        await store.markExpansionLessonApplied(_pathId, sspRefSafetyNetPlan);
        expect(
          store.expansionProgressFor(_pathId)[sspRefSafetyNetPlan],
          LessonState.applied,
          reason: 'applied outranks completed',
        );
      },
    );
  });

  group('isolation from the core 22, every Grow Your Money course, and '
      'Insurance Decoded (same path, different course)', () {
    test('progressing every lesson in this course leaves core lessonProgress '
        'empty', () async {
      final store = await _freshStore();
      for (final id in _lessonIds) {
        await store.markExpansionLessonCompleted(_pathId, id);
      }
      expect(store.lessonProgress, isEmpty);
      expect(
        (store.data['settings'] as Map).containsKey('lessonsRead'),
        isFalse,
      );
    });

    test('completing this course never touches grow_your_money\'s own '
        'progress, and the reverse also holds', () async {
      final store = await _freshStore();
      for (final id in _lessonIds) {
        await store.markExpansionLessonCompleted(_pathId, id);
      }
      final pilotIds = growYourMoneyLessons.map((l) => l.id);
      for (final id in pilotIds) {
        expect(store.expansionProgressFor(_otherPathId)[id], isNull);
      }

      await store.markExpansionLessonCompleted(_otherPathId, investRefMoneyJob);
      for (final id in _lessonIds) {
        expect(
          store.expansionProgressFor(_pathId)[id],
          LessonState.completed,
          reason: 'progressing the other path must not touch this one',
        );
      }
    });

    test(
      'finishing every lesson in this course never marks Insurance '
      'Decoded\'s own lessons complete, even though both courses share '
      'the protect_your_future namespace, and the reverse also holds',
      () async {
        final store = await _freshStore();
        for (final id in _lessonIds) {
          await store.markExpansionLessonCompleted(_pathId, id);
        }
        for (final id in _insuranceLessonIds) {
          expect(
            store.expansionProgressFor(_pathId)[id],
            isNull,
            reason: '$id should not be touched by this course\'s own progress',
          );
        }

        await store.markExpansionLessonCompleted(
          _pathId,
          insuranceRefWhatItsFor,
        );
        for (final id in _lessonIds) {
          expect(
            store.expansionProgressFor(_pathId)[id],
            LessonState.completed,
            reason:
                'Insurance Decoded progress must not demote this course\'s '
                'own already-completed lessons',
          );
        }
      },
    );

    test('both courses under the same path carry independent progress at '
        'the same time', () async {
      final store = await _freshStore();
      await store.markExpansionLessonCompleted(_pathId, sspRefTwoSafetyNets);
      await store.markExpansionLessonStarted(_pathId, insuranceRefWhatItsFor);

      expect(
        store.expansionProgressFor(_pathId)[sspRefTwoSafetyNets],
        LessonState.completed,
      );
      expect(
        store.expansionProgressFor(_pathId)[insuranceRefWhatItsFor],
        LessonState.viewed,
      );
    });
  });

  group('persistence across a simulated restart', () {
    test('real course progress survives a fresh store reading the same disk '
        'state', () async {
      final store = await _freshStore();
      await store.markExpansionLessonCompleted(_pathId, sspRefTwoSafetyNets);
      await store.markExpansionLessonStarted(_pathId, sspRefSssMayHelp);

      final second = SalapifyStore();
      await second.load();
      expect(
        second.expansionProgressFor(_pathId)[sspRefTwoSafetyNets],
        LessonState.completed,
      );
      expect(
        second.expansionProgressFor(_pathId)[sspRefSssMayHelp],
        LessonState.viewed,
      );
    });
  });

  group('backup export and restore', () {
    test(
      'real course progress round-trips through export and import',
      () async {
        final store = await _freshStore();
        await store.markExpansionLessonCompleted(_pathId, sspRefTwoSafetyNets);
        await store.markExpansionLessonCompleted(_pathId, sspRefSafetyNetPlan);
        final text = store.exportBackupText();

        SharedPreferences.setMockInitialValues({});
        final restored = SalapifyStore();
        await restored.load();
        await restored.importBackupText(text);

        expect(
          restored.expansionProgressFor(_pathId)[sspRefTwoSafetyNets],
          LessonState.completed,
        );
        expect(
          restored.expansionProgressFor(_pathId)[sspRefSafetyNetPlan],
          LessonState.completed,
        );
        // The lesson never started stays unrecorded, exactly as if it were a
        // fresh install, never a false "in progress".
        expect(
          restored.expansionProgressFor(_pathId)[sspRefCheckBeforeYouCount],
          isNull,
        );
      },
    );

    test('a backup with progress across both courses in the same path '
        'preserves both, independently', () async {
      final store = await _freshStore();
      await store.markExpansionLessonCompleted(_pathId, insuranceRefWhatItsFor);
      await store.markExpansionLessonCompleted(_pathId, sspRefTwoSafetyNets);
      final text = store.exportBackupText();

      SharedPreferences.setMockInitialValues({});
      final restored = SalapifyStore();
      await restored.load();
      await restored.importBackupText(text);

      expect(
        restored.expansionProgressFor(_pathId)[insuranceRefWhatItsFor],
        LessonState.completed,
      );
      expect(
        restored.expansionProgressFor(_pathId)[sspRefTwoSafetyNets],
        LessonState.completed,
      );
    });
  });
}
