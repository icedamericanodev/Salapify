// Store-level vectors for the real "Stocks and Bonds Without the Hype"
// course (lib/content/lessons_stocks_bonds.dart), the same shape as
// lessons_grow_progress_backup_test.dart for the pilot: proves the ACTUAL
// registered lessons persist across a simulated restart, round-trip
// through backup export and import, and never touch the core 22 lessons'
// progress or the pilot's own progress.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/content/lessons_grow.dart';
import 'package:salapify/content/lessons_stocks_bonds.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/money/lesson_progress.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _pathId = 'grow_your_money';
final _lessonIds = stocksAndBondsLessons.map((l) => l.id).toList();

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
        await store.markExpansionLessonStarted(_pathId, sbOwnerOrLender);
        var progress = store.expansionPathProgress(
          pathId: _pathId,
          lessonIds: _lessonIds,
        );
        expect(progress.total, 6);
        expect(progress.done, 0, reason: 'viewed alone does not count as done');

        await store.markExpansionLessonCompleted(_pathId, sbOwnerOrLender);
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
          sbVerifyBeforeYouInvest,
        );
        await store.markExpansionLessonStarted(
          _pathId,
          sbVerifyBeforeYouInvest,
        );
        expect(
          store.expansionProgressFor(_pathId)[sbVerifyBeforeYouInvest],
          LessonState.completed,
          reason: 'starting again must never demote a completed lesson',
        );
        await store.markExpansionLessonApplied(
          _pathId,
          sbVerifyBeforeYouInvest,
        );
        expect(
          store.expansionProgressFor(_pathId)[sbVerifyBeforeYouInvest],
          LessonState.applied,
          reason: 'applied outranks completed',
        );
      },
    );
  });

  group('isolation from the core 22 and from the pilot', () {
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

    test(
      'completing this course never touches the pilot\'s own progress',
      () async {
        final store = await _freshStore();
        for (final id in _lessonIds) {
          await store.markExpansionLessonCompleted(_pathId, id);
        }
        final pilotIds = growYourMoneyLessons.map((l) => l.id);
        for (final id in pilotIds) {
          expect(store.expansionProgressFor(_pathId)[id], isNull);
        }
      },
    );
  });

  group('persistence across a simulated restart', () {
    test('real course progress survives a fresh store reading the same disk '
        'state', () async {
      final store = await _freshStore();
      await store.markExpansionLessonCompleted(_pathId, sbOwnerOrLender);
      await store.markExpansionLessonStarted(_pathId, sbStockReturnsAndLosses);

      final second = SalapifyStore();
      await second.load();
      expect(
        second.expansionProgressFor(_pathId)[sbOwnerOrLender],
        LessonState.completed,
      );
      expect(
        second.expansionProgressFor(_pathId)[sbStockReturnsAndLosses],
        LessonState.viewed,
      );
    });
  });

  group('backup export and restore', () {
    test(
      'real course progress round-trips through export and import',
      () async {
        final store = await _freshStore();
        await store.markExpansionLessonCompleted(_pathId, sbOwnerOrLender);
        await store.markExpansionLessonCompleted(_pathId, sbHowBondsWork);
        final text = store.exportBackupText();

        SharedPreferences.setMockInitialValues({});
        final restored = SalapifyStore();
        await restored.load();
        await restored.importBackupText(text);

        expect(
          restored.expansionProgressFor(_pathId)[sbOwnerOrLender],
          LessonState.completed,
        );
        expect(
          restored.expansionProgressFor(_pathId)[sbHowBondsWork],
          LessonState.completed,
        );
        // The lesson never started stays unrecorded, exactly as if it were a
        // fresh install, never a false "in progress".
        expect(
          restored.expansionProgressFor(_pathId)[sbVerifyBeforeYouInvest],
          isNull,
        );
      },
    );

    test('a backup with progress in both the pilot and this course preserves '
        'both', () async {
      final store = await _freshStore();
      await store.markExpansionLessonCompleted(_pathId, investRefMoneyJob);
      await store.markExpansionLessonCompleted(_pathId, sbOwnerOrLender);
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
        restored.expansionProgressFor(_pathId)[sbOwnerOrLender],
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
