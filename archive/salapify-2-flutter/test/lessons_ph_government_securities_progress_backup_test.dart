// Store-level vectors for the real "Philippine Government Securities" course
// (lib/content/lessons_ph_government_securities.dart), the same shape as
// lessons_stocks_bonds_progress_backup_test.dart for that earlier course:
// proves the ACTUAL registered lessons persist across a simulated restart,
// round-trip through backup export and import, and never touch the core 22
// lessons' progress or any earlier expansion course's own progress.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/content/lessons_ph_government_securities.dart';
import 'package:salapify/content/lessons_stocks_bonds.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/money/lesson_progress.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _pathId = 'grow_your_money';
final _lessonIds = phGovernmentSecuritiesLessons.map((l) => l.id).toList();

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
        await store.markExpansionLessonStarted(_pathId, gsLendingToGovernment);
        var progress = store.expansionPathProgress(
          pathId: _pathId,
          lessonIds: _lessonIds,
        );
        expect(progress.total, 6);
        expect(progress.done, 0, reason: 'viewed alone does not count as done');

        await store.markExpansionLessonCompleted(
          _pathId,
          gsLendingToGovernment,
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
        await store.markExpansionLessonCompleted(_pathId, gsDecisionPlan);
        await store.markExpansionLessonStarted(_pathId, gsDecisionPlan);
        expect(
          store.expansionProgressFor(_pathId)[gsDecisionPlan],
          LessonState.completed,
          reason: 'starting again must never demote a completed lesson',
        );
        await store.markExpansionLessonApplied(_pathId, gsDecisionPlan);
        expect(
          store.expansionProgressFor(_pathId)[gsDecisionPlan],
          LessonState.applied,
          reason: 'applied outranks completed',
        );
      },
    );
  });

  group('isolation from the core 22 and from every earlier course', () {
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

    test('completing this course never touches the stocks_and_bonds course\'s '
        'own progress', () async {
      final store = await _freshStore();
      for (final id in _lessonIds) {
        await store.markExpansionLessonCompleted(_pathId, id);
      }
      final stocksBondsIds = stocksAndBondsLessons.map((l) => l.id);
      for (final id in stocksBondsIds) {
        expect(store.expansionProgressFor(_pathId)[id], isNull);
      }
    });

    test('progressing the stocks_and_bonds course never touches this course\'s '
        'own progress', () async {
      final store = await _freshStore();
      for (final l in stocksAndBondsLessons) {
        await store.markExpansionLessonCompleted(_pathId, l.id);
      }
      for (final id in _lessonIds) {
        expect(store.expansionProgressFor(_pathId)[id], isNull);
      }
    });
  });

  group('persistence across a simulated restart', () {
    test('real course progress survives a fresh store reading the same disk '
        'state', () async {
      final store = await _freshStore();
      await store.markExpansionLessonCompleted(_pathId, gsLendingToGovernment);
      await store.markExpansionLessonStarted(_pathId, gsTypesOfSecurities);

      final second = SalapifyStore();
      await second.load();
      expect(
        second.expansionProgressFor(_pathId)[gsLendingToGovernment],
        LessonState.completed,
      );
      expect(
        second.expansionProgressFor(_pathId)[gsTypesOfSecurities],
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
          gsLendingToGovernment,
        );
        await store.markExpansionLessonCompleted(
          _pathId,
          gsHowSecuritiesReachInvestors,
        );
        final text = store.exportBackupText();

        SharedPreferences.setMockInitialValues({});
        final restored = SalapifyStore();
        await restored.load();
        await restored.importBackupText(text);

        expect(
          restored.expansionProgressFor(_pathId)[gsLendingToGovernment],
          LessonState.completed,
        );
        expect(
          restored.expansionProgressFor(_pathId)[gsHowSecuritiesReachInvestors],
          LessonState.completed,
        );
        // The lesson never started stays unrecorded, exactly as if it were a
        // fresh install, never a false "in progress".
        expect(restored.expansionProgressFor(_pathId)[gsDecisionPlan], isNull);
      },
    );

    test('a backup with progress in both stocks_and_bonds and this course '
        'preserves both', () async {
      final store = await _freshStore();
      await store.markExpansionLessonCompleted(_pathId, sbOwnerOrLender);
      await store.markExpansionLessonCompleted(_pathId, gsLendingToGovernment);
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
        restored.expansionProgressFor(_pathId)[gsLendingToGovernment],
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
