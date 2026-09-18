// Pure-logic vectors for the expansion learning-path progress model: a
// namespace kept deliberately separate from the core lessonProgress model in
// lesson_progress_test.dart. Every test here proves either isolation (a
// write to one path, or to the core model, cannot leak into another) or
// junk-safety (an unknown or malformed id is skipped, never thrown on).

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/money/expansion_progress.dart';
import 'package:salapify/money/lesson_progress.dart';

void main() {
  group('parseExpansionProgress', () {
    test('junk in any position reads as empty, never throws', () {
      expect(parseExpansionProgress(null), isEmpty);
      expect(parseExpansionProgress('nope'), isEmpty);
      expect(parseExpansionProgress(42), isEmpty);
      expect(parseExpansionProgress({'grow_your_money': 'not a map'}), isEmpty);
      expect(parseExpansionProgress({'': {}}), isEmpty);
      expect(
        parseExpansionProgress({
          'grow_your_money': {'gym-1': 'not a map'},
        }),
        isEmpty,
      );
      expect(
        parseExpansionProgress({
          'grow_your_money': {
            'gym-1': {'state': 'invented'},
          },
        }),
        isEmpty,
      );
      expect(
        parseExpansionProgress({
          'grow_your_money': {
            '': {'state': 'completed'},
          },
        }),
        isEmpty,
      );
    });

    test('a real entry parses to the right state', () {
      final p = parseExpansionProgress({
        'grow_your_money': {
          'gym-1': {'state': 'completed'},
          'gym-2': {'state': 'viewed'},
        },
      });
      expect(p['grow_your_money']?['gym-1'], LessonState.completed);
      expect(p['grow_your_money']?['gym-2'], LessonState.viewed);
    });

    test('paths stay isolated from each other', () {
      final p = parseExpansionProgress({
        'grow_your_money': {
          'gym-1': {'state': 'completed'},
        },
        'protect_your_future': {
          'pyf-1': {'state': 'viewed'},
        },
      });
      expect(p['grow_your_money']?.keys, ['gym-1']);
      expect(p['protect_your_future']?.keys, ['pyf-1']);
      expect(p['grow_your_money']?['pyf-1'], isNull);
    });

    test(
      'a path with only malformed lessons is omitted, not present-empty',
      () {
        final p = parseExpansionProgress({
          'grow_your_money': {
            'gym-1': {'state': 'invented'},
          },
        });
        expect(p.containsKey('grow_your_money'), isFalse);
      },
    );
  });

  group('withExpansionLessonState', () {
    test('writes a new lesson under a new path', () {
      final out = withExpansionLessonState(
        null,
        'grow_your_money',
        'gym-1',
        LessonState.viewed,
      );
      expect(out['grow_your_money'], {
        'gym-1': {'state': 'viewed'},
      });
    });

    test('never demotes a lesson within its own path', () {
      final existing = {
        'grow_your_money': {
          'gym-1': {'state': 'completed'},
        },
      };
      final out = withExpansionLessonState(
        existing,
        'grow_your_money',
        'gym-1',
        LessonState.viewed,
      );
      expect(
        (out['grow_your_money'] as Map)['gym-1'],
        {'state': 'completed'},
        reason: 'a lower state must never overwrite a higher one',
      );
    });

    test('promotes when the new state is genuinely higher', () {
      final existing = {
        'grow_your_money': {
          'gym-1': {'state': 'viewed'},
        },
      };
      final out = withExpansionLessonState(
        existing,
        'grow_your_money',
        'gym-1',
        LessonState.completed,
      );
      expect((out['grow_your_money'] as Map)['gym-1'], {'state': 'completed'});
    });

    test('a write to one path never touches another path\'s entries', () {
      final existing = {
        'protect_your_future': {
          'pyf-1': {'state': 'completed'},
        },
      };
      final out = withExpansionLessonState(
        existing,
        'grow_your_money',
        'gym-1',
        LessonState.viewed,
      );
      expect((out['protect_your_future'] as Map)['pyf-1'], {
        'state': 'completed',
      });
      expect((out['grow_your_money'] as Map)['gym-1'], {'state': 'viewed'});
    });

    test('a write to one lesson never touches a sibling lesson in the same '
        'path', () {
      final existing = {
        'grow_your_money': {
          'gym-1': {'state': 'completed'},
        },
      };
      final out = withExpansionLessonState(
        existing,
        'grow_your_money',
        'gym-2',
        LessonState.viewed,
      );
      final path = out['grow_your_money'] as Map;
      expect(path['gym-1'], {'state': 'completed'});
      expect(path['gym-2'], {'state': 'viewed'});
    });
  });

  group('withExpansionPathCleared', () {
    test('drops exactly one path, others untouched', () {
      final existing = {
        'grow_your_money': {
          'gym-1': {'state': 'completed'},
        },
        'protect_your_future': {
          'pyf-1': {'state': 'viewed'},
        },
      };
      final out = withExpansionPathCleared(existing, 'grow_your_money');
      expect(out.containsKey('grow_your_money'), isFalse);
      expect(out['protect_your_future'], {
        'pyf-1': {'state': 'viewed'},
      });
    });

    test('clearing an unknown path id is a safe no-op', () {
      final existing = {
        'grow_your_money': {
          'gym-1': {'state': 'completed'},
        },
      };
      final out = withExpansionPathCleared(existing, 'never_heard_of_it');
      expect(out, existing);
    });
  });

  group('pathProgressFor', () {
    test('counts done lessons against the path\'s own lesson list only', () {
      final progress = parseExpansionProgress({
        'grow_your_money': {
          'gym-1': {'state': 'completed'},
          'gym-2': {'state': 'viewed'},
        },
        'protect_your_future': {
          'pyf-1': {'state': 'completed'},
        },
      });
      final pp = pathProgressFor(
        pathId: 'grow_your_money',
        lessonIds: ['gym-1', 'gym-2', 'gym-3'],
        progress: progress['grow_your_money'] ?? const {},
      );
      expect(pp.total, 3);
      expect(pp.done, 1, reason: 'only gym-1 reached completed/applied');
      expect(pp.fraction, closeTo(1 / 3, 1e-9));
      expect(pp.isStarted, isTrue);
      expect(pp.isComplete, isFalse);
    });

    test('a path with no lessons yet never divides by zero', () {
      final pp = pathProgressFor(
        pathId: 'build_your_business',
        lessonIds: const [],
        progress: const {},
      );
      expect(pp.total, 0);
      expect(pp.done, 0);
      expect(pp.fraction, 0);
      expect(pp.isComplete, isFalse);
      expect(pp.isStarted, isFalse);
    });

    test(
      'an id in progress that is not in the path\'s own list is ignored',
      () {
        final pp = pathProgressFor(
          pathId: 'grow_your_money',
          lessonIds: ['gym-1'],
          progress: {
            'gym-1': LessonState.completed,
            'unrelated-id': LessonState.completed,
          },
        );
        expect(pp.total, 1);
        expect(pp.done, 1);
      },
    );
  });
}
