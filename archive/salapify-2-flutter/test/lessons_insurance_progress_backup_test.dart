// Store-level vectors for the real "Insurance Decoded" course
// (lib/content/lessons_insurance.dart), the same shape as
// lessons_crypto_progress_backup_test.dart: proves the ACTUAL registered
// lessons persist across a simulated restart, round-trip through backup
// export and import, and never touch the core 22 lessons' progress or any
// Grow Your Money course's own progress. This is also the first proof that
// a SECOND expansion path (protect_your_future, separate from
// grow_your_money) keeps its own independent progress end to end.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/content/lessons_grow.dart';
import 'package:salapify/content/lessons_insurance.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/money/lesson_progress.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _pathId = 'protect_your_future';
const _otherPathId = 'grow_your_money';
final _lessonIds = insuranceDecodedLessons.map((l) => l.id).toList();

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
        await store.markExpansionLessonStarted(_pathId, insuranceRefWhatItsFor);
        var progress = store.expansionPathProgress(
          pathId: _pathId,
          lessonIds: _lessonIds,
        );
        expect(progress.total, 6);
        expect(progress.done, 0, reason: 'viewed alone does not count as done');

        await store.markExpansionLessonCompleted(
          _pathId,
          insuranceRefWhatItsFor,
        );
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
        await store.markExpansionLessonCompleted(
          _pathId,
          insuranceRefVerifyCompareDecide,
        );
        await store.markExpansionLessonStarted(
          _pathId,
          insuranceRefVerifyCompareDecide,
        );
        expect(
          store.expansionProgressFor(_pathId)[insuranceRefVerifyCompareDecide],
          LessonState.completed,
          reason: 'starting again must never demote a completed lesson',
        );
        await store.markExpansionLessonApplied(
          _pathId,
          insuranceRefVerifyCompareDecide,
        );
        expect(
          store.expansionProgressFor(_pathId)[insuranceRefVerifyCompareDecide],
          LessonState.applied,
          reason: 'applied outranks completed',
        );
      },
    );
  });

  group('isolation from the core 22 and every Grow Your Money course', () {
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

    test('both paths carry independent progress at the same time', () async {
      final store = await _freshStore();
      await store.markExpansionLessonCompleted(_pathId, insuranceRefWhatItsFor);
      await store.markExpansionLessonStarted(_otherPathId, investRefMoneyJob);

      expect(store.expansionProgressFor(_pathId).keys, [
        insuranceRefWhatItsFor,
      ]);
      expect(store.expansionProgressFor(_otherPathId).keys, [
        investRefMoneyJob,
      ]);
    });
  });

  group('persistence across a simulated restart', () {
    test('real course progress survives a fresh store reading the same disk '
        'state', () async {
      final store = await _freshStore();
      await store.markExpansionLessonCompleted(_pathId, insuranceRefWhatItsFor);
      await store.markExpansionLessonStarted(
        _pathId,
        insuranceRefProtectionNeed,
      );

      final second = SalapifyStore();
      await second.load();
      expect(
        second.expansionProgressFor(_pathId)[insuranceRefWhatItsFor],
        LessonState.completed,
      );
      expect(
        second.expansionProgressFor(_pathId)[insuranceRefProtectionNeed],
        LessonState.viewed,
      );
    });
  });

  group('backup export and restore', () {
    test(
      'real course progress round-trips through export and import',
      () async {
        final store = await _freshStore();
        await store.markExpansionLessonCompleted(
          _pathId,
          insuranceRefWhatItsFor,
        );
        await store.markExpansionLessonCompleted(
          _pathId,
          insuranceRefVerifyCompareDecide,
        );
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
          restored.expansionProgressFor(
            _pathId,
          )[insuranceRefVerifyCompareDecide],
          LessonState.completed,
        );
        // The lesson never started stays unrecorded, exactly as if it were a
        // fresh install, never a false "in progress".
        expect(
          restored.expansionProgressFor(_pathId)[insuranceRefTermAndWholeLife],
          isNull,
        );
      },
    );

    test('a backup with progress across both paths preserves both, '
        'independently', () async {
      final store = await _freshStore();
      await store.markExpansionLessonCompleted(_otherPathId, investRefMoneyJob);
      await store.markExpansionLessonCompleted(_pathId, insuranceRefWhatItsFor);
      final text = store.exportBackupText();

      SharedPreferences.setMockInitialValues({});
      final restored = SalapifyStore();
      await restored.load();
      await restored.importBackupText(text);

      expect(
        restored.expansionProgressFor(_otherPathId)[investRefMoneyJob],
        LessonState.completed,
      );
      expect(
        restored.expansionProgressFor(_pathId)[insuranceRefWhatItsFor],
        LessonState.completed,
      );
    });

    test('a backup with no progress in this course omits it from '
        'expansionProgress', () async {
      final store = await _freshStore();
      final text = store.exportBackupText();
      final decoded = jsonDecode(text) as Map<String, dynamic>;
      final settings = (decoded['data'] as Map)['settings'] as Map;
      expect(settings.containsKey('expansionProgress'), isFalse);
    });
  });
}
