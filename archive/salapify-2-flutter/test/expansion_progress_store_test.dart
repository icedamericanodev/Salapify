// Store-level vectors for the expansion learning-path progress API
// (settings.expansionProgress): a CONDITIONAL settings key like paluwagans
// and steadyPay. Proves the golden safety contract, persistence across a
// simulated restart, backup round-trip, and, most importantly, that this
// entire feature can never move the core 22 lessons' progress or count.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/money/lesson_progress.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<SalapifyStore> _freshStore() async {
  SharedPreferences.setMockInitialValues({});
  final store = SalapifyStore();
  await store.load();
  return store;
}

void main() {
  group('marking lessons started and completed', () {
    test('starting a lesson records viewed, never higher on its own', () async {
      final store = await _freshStore();
      await store.markExpansionLessonStarted('grow_your_money', 'gym-1');
      expect(
        store.expansionProgressFor('grow_your_money')['gym-1'],
        LessonState.viewed,
      );
    });

    test('completing a lesson records completed', () async {
      final store = await _freshStore();
      await store.markExpansionLessonCompleted('grow_your_money', 'gym-1');
      expect(
        store.expansionProgressFor('grow_your_money')['gym-1'],
        LessonState.completed,
      );
    });

    test('opening a lesson never marks it completed by itself', () async {
      final store = await _freshStore();
      await store.markExpansionLessonStarted('grow_your_money', 'gym-1');
      expect(
        store.expansionProgressFor('grow_your_money')['gym-1'],
        isNot(LessonState.completed),
      );
    });

    test('starting an already-completed lesson never demotes it', () async {
      final store = await _freshStore();
      await store.markExpansionLessonCompleted('grow_your_money', 'gym-1');
      await store.markExpansionLessonStarted('grow_your_money', 'gym-1');
      expect(
        store.expansionProgressFor('grow_your_money')['gym-1'],
        LessonState.completed,
      );
    });
  });

  group('isolation by path id', () {
    test('two paths never see each other\'s progress', () async {
      final store = await _freshStore();
      await store.markExpansionLessonCompleted('grow_your_money', 'gym-1');
      await store.markExpansionLessonCompleted('protect_your_future', 'pyf-1');
      expect(store.expansionProgressFor('grow_your_money').keys, ['gym-1']);
      expect(store.expansionProgressFor('protect_your_future').keys, ['pyf-1']);
    });

    test('an unknown path id simply reads as empty, never throws', () async {
      final store = await _freshStore();
      expect(store.expansionProgressFor('never_heard_of_it'), isEmpty);
    });

    test('resetting one path leaves every other path untouched', () async {
      final store = await _freshStore();
      await store.markExpansionLessonCompleted('grow_your_money', 'gym-1');
      await store.markExpansionLessonCompleted('protect_your_future', 'pyf-1');
      await store.resetExpansionPath('grow_your_money');
      expect(store.expansionProgressFor('grow_your_money'), isEmpty);
      expect(
        store.expansionProgressFor('protect_your_future')['pyf-1'],
        LessonState.completed,
      );
    });

    test('resetting an unknown path id is a safe no-op', () async {
      final store = await _freshStore();
      await store.markExpansionLessonCompleted('grow_your_money', 'gym-1');
      await store.resetExpansionPath('never_heard_of_it');
      expect(
        store.expansionProgressFor('grow_your_money')['gym-1'],
        LessonState.completed,
      );
    });
  });

  group('path progress calculation', () {
    test('completed and total fold correctly for one path', () async {
      final store = await _freshStore();
      await store.markExpansionLessonCompleted('grow_your_money', 'gym-1');
      await store.markExpansionLessonStarted('grow_your_money', 'gym-2');
      final pp = store.expansionPathProgress(
        pathId: 'grow_your_money',
        lessonIds: ['gym-1', 'gym-2', 'gym-3'],
      );
      expect(pp.total, 3);
      expect(pp.done, 1);
    });
  });

  group('the core 22 lessons are never affected', () {
    test('expansion writes never touch settings.lessonProgress', () async {
      final store = await _freshStore();
      final before = Map<String, LessonState>.from(store.lessonProgress);
      await store.markExpansionLessonCompleted('grow_your_money', 'gym-1');
      await store.markExpansionLessonStarted('protect_your_future', 'pyf-1');
      expect(store.lessonProgress, before);
      expect(
        (store.data['settings'] as Map).containsKey('lessonsRead'),
        isFalse,
      );
    });

    test('core lesson writes never touch settings.expansionProgress', () async {
      final store = await _freshStore();
      await store.setLessonState('needs-wants', LessonState.completed);
      expect(
        (store.data['settings'] as Map).containsKey('expansionProgress'),
        isFalse,
      );
    });
  });

  group('missing/malformed data defaults safely', () {
    test('a brand-new store has no expansion progress at all', () async {
      final store = await _freshStore();
      expect(store.expansionProgressFor('grow_your_money'), isEmpty);
      expect(
        (store.data['settings'] as Map?)?.containsKey('expansionProgress') ??
            false,
        isFalse,
      );
    });

    test('a stored blob with junk expansionProgress reads as empty', () async {
      SharedPreferences.setMockInitialValues({
        storageKey: jsonEncode({
          'settings': {
            'expansionProgress': {
              'grow_your_money': 'not a map',
              '': {
                'gym-1': {'state': 'completed'},
              },
            },
          },
        }),
      });
      final store = SalapifyStore();
      await store.load();
      expect(store.expansionProgressFor('grow_your_money'), isEmpty);
    });
  });

  group('persistence across a simulated restart', () {
    test(
      'progress survives a fresh store reading the same disk state',
      () async {
        final store = await _freshStore();
        await store.markExpansionLessonCompleted('grow_your_money', 'gym-1');

        final second = SalapifyStore();
        await second.load();
        expect(
          second.expansionProgressFor('grow_your_money')['gym-1'],
          LessonState.completed,
        );
      },
    );
  });

  group('backup export and restore', () {
    test('empty expansion progress is omitted from a fresh backup', () async {
      final store = await _freshStore();
      final text = store.exportBackupText();
      final decoded = jsonDecode(text) as Map<String, dynamic>;
      final settings = (decoded['data'] as Map)['settings'] as Map;
      expect(settings.containsKey('expansionProgress'), isFalse);
    });

    test(
      'non-empty expansion progress round-trips through export/import',
      () async {
        final store = await _freshStore();
        await store.markExpansionLessonCompleted('grow_your_money', 'gym-1');
        await store.markExpansionLessonStarted('protect_your_future', 'pyf-1');
        final text = store.exportBackupText();

        SharedPreferences.setMockInitialValues({});
        final fresh = SalapifyStore();
        await fresh.load();
        await fresh.importBackupText(text);

        expect(
          fresh.expansionProgressFor('grow_your_money')['gym-1'],
          LessonState.completed,
        );
        expect(
          fresh.expansionProgressFor('protect_your_future')['pyf-1'],
          LessonState.viewed,
        );
      },
    );

    test(
      'a v12 backup with no expansionProgress key restores as empty',
      () async {
        const oldBackup = '''
      {"app":"salapify","data":{"schemaVersion":12,"accounts":[],
      "transactions":[],"settings":{}}}
      ''';
        SharedPreferences.setMockInitialValues({});
        final store = SalapifyStore();
        await store.load();
        await store.importBackupText(oldBackup);
        expect(store.expansionProgressFor('grow_your_money'), isEmpty);
        expect(
          (store.data['settings'] as Map).containsKey('expansionProgress'),
          isFalse,
        );
      },
    );

    test(
      'a malformed entry in an imported backup is dropped, not restored',
      () async {
        final junkBackup = jsonEncode({
          'app': 'salapify',
          'data': {
            'schemaVersion': 12,
            'accounts': [],
            'transactions': [],
            'settings': {
              'expansionProgress': {
                'grow_your_money': {
                  'gym-1': {'state': 'invented'},
                  'gym-2': {'state': 'completed'},
                },
              },
            },
          },
        });
        SharedPreferences.setMockInitialValues({});
        final store = SalapifyStore();
        await store.load();
        await store.importBackupText(junkBackup);
        final p = store.expansionProgressFor('grow_your_money');
        expect(
          p.containsKey('gym-1'),
          isFalse,
          reason: 'invented state dropped',
        );
        expect(p['gym-2'], LessonState.completed);
      },
    );
  });
}
