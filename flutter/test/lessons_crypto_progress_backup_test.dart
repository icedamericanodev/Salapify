// Store-level vectors for the real "Crypto Without the Hype" course
// (lib/content/lessons_crypto.dart), the same shape as
// lessons_deposits_pooled_funds_progress_backup_test.dart: proves the ACTUAL
// registered lessons persist across a simulated restart, round-trip through
// backup export and import, and never touch the core 22 lessons' progress
// or any earlier Grow Your Money course's own progress.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/content/lessons_crypto.dart';
import 'package:salapify/content/lessons_deposits_pooled_funds.dart';
import 'package:salapify/content/lessons_grow.dart';
import 'package:salapify/content/lessons_stocks_bonds.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/money/lesson_progress.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _pathId = 'grow_your_money';
final _lessonIds = cryptoWithoutHypeLessons.map((l) => l.id).toList();

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
        await store.markExpansionLessonStarted(_pathId, cryptoRefWhatCryptoIs);
        var progress = store.expansionPathProgress(
          pathId: _pathId,
          lessonIds: _lessonIds,
        );
        expect(progress.total, 6);
        expect(progress.done, 0, reason: 'viewed alone does not count as done');

        await store.markExpansionLessonCompleted(
          _pathId,
          cryptoRefWhatCryptoIs,
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
        await store.markExpansionLessonCompleted(_pathId, cryptoRefDecisionLab);
        await store.markExpansionLessonStarted(_pathId, cryptoRefDecisionLab);
        expect(
          store.expansionProgressFor(_pathId)[cryptoRefDecisionLab],
          LessonState.completed,
          reason: 'starting again must never demote a completed lesson',
        );
        await store.markExpansionLessonApplied(_pathId, cryptoRefDecisionLab);
        expect(
          store.expansionProgressFor(_pathId)[cryptoRefDecisionLab],
          LessonState.applied,
          reason: 'applied outranks completed',
        );
      },
    );
  });

  group('isolation from the core 22 and every earlier course', () {
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

    test('completing this course never touches any earlier course\'s own '
        'progress', () async {
      final store = await _freshStore();
      for (final id in _lessonIds) {
        await store.markExpansionLessonCompleted(_pathId, id);
      }
      final pilotIds = growYourMoneyLessons.map((l) => l.id);
      final sbIds = stocksAndBondsLessons.map((l) => l.id);
      final dpIds = depositsAndPooledFundsLessons.map((l) => l.id);
      for (final id in [...pilotIds, ...sbIds, ...dpIds]) {
        expect(store.expansionProgressFor(_pathId)[id], isNull);
      }
    });
  });

  group('persistence across a simulated restart', () {
    test('real course progress survives a fresh store reading the same disk '
        'state', () async {
      final store = await _freshStore();
      await store.markExpansionLessonCompleted(_pathId, cryptoRefWhatCryptoIs);
      await store.markExpansionLessonStarted(
        _pathId,
        cryptoRefVolatilityTotalLoss,
      );

      final second = SalapifyStore();
      await second.load();
      expect(
        second.expansionProgressFor(_pathId)[cryptoRefWhatCryptoIs],
        LessonState.completed,
      );
      expect(
        second.expansionProgressFor(_pathId)[cryptoRefVolatilityTotalLoss],
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
          cryptoRefWhatCryptoIs,
        );
        await store.markExpansionLessonCompleted(_pathId, cryptoRefDecisionLab);
        final text = store.exportBackupText();

        SharedPreferences.setMockInitialValues({});
        final restored = SalapifyStore();
        await restored.load();
        await restored.importBackupText(text);

        expect(
          restored.expansionProgressFor(_pathId)[cryptoRefWhatCryptoIs],
          LessonState.completed,
        );
        expect(
          restored.expansionProgressFor(_pathId)[cryptoRefDecisionLab],
          LessonState.completed,
        );
        // The lesson never started stays unrecorded, exactly as if it were a
        // fresh install, never a false "in progress".
        expect(
          restored.expansionProgressFor(
            _pathId,
          )[cryptoRefScamsProviderVerification],
          isNull,
        );
      },
    );

    test(
      'a backup with progress across all four courses preserves all of it',
      () async {
        final store = await _freshStore();
        await store.markExpansionLessonCompleted(_pathId, investRefMoneyJob);
        await store.markExpansionLessonCompleted(_pathId, sbOwnerOrLender);
        await store.markExpansionLessonCompleted(
          _pathId,
          dpDepositOrInvestment,
        );
        await store.markExpansionLessonCompleted(
          _pathId,
          cryptoRefWhatCryptoIs,
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
          restored.expansionProgressFor(_pathId)[sbOwnerOrLender],
          LessonState.completed,
        );
        expect(
          restored.expansionProgressFor(_pathId)[dpDepositOrInvestment],
          LessonState.completed,
        );
        expect(
          restored.expansionProgressFor(_pathId)[cryptoRefWhatCryptoIs],
          LessonState.completed,
        );
      },
    );

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
