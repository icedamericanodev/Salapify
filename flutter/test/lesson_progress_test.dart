// Course progress: opening is not learning, and nobody loses a tick they
// already earned.
//
// The old model wrote settings.lessonsRead the instant a lesson opened, so the
// progress card counted taps. Tap a lesson, back out, and it read as done
// forever. This file pins the new contract and, just as importantly, the
// migration: old progress must survive, and a backup written here must still
// restore onto a build that only knows the old key.

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/content/lesson_model.dart';
import 'package:salapify/content/lessons.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/money/lesson_progress.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('parseLessonProgress', () {
    test('junk in any position reads as empty, never throws', () {
      expect(parseLessonProgress(null), isEmpty);
      expect(parseLessonProgress('nope'), isEmpty);
      expect(parseLessonProgress({'a': 'not a map'}), isEmpty);
      expect(parseLessonProgress({'': {}}), isEmpty);
      expect(
        parseLessonProgress({
          'x': {'state': 'invented'},
        }),
        isEmpty,
      );
    });

    test('old lessonsRead entries survive as learned', () {
      final p = parseLessonProgress(
        null,
        legacyRead: ['see-it-first', 'needs-wants'],
      );
      expect(p['see-it-first'], LessonState.learned);
      expect(p['needs-wants'], LessonState.learned);
    });

    test('a new entry wins over the legacy list for the same lesson', () {
      final p = parseLessonProgress(
        {
          'see-it-first': {'state': 'inProgress'},
        },
        legacyRead: ['see-it-first'],
      );
      expect(
        p['see-it-first'],
        LessonState.inProgress,
        reason: 'the finer-grained record is the truthful one',
      );
    });
  });

  group('withLessonState', () {
    test('progress never goes backwards', () {
      var stored = withLessonState(null, 'a', LessonState.learned);
      stored = withLessonState(stored, 'a', LessonState.inProgress);
      expect(
        parseLessonProgress(stored)['a'],
        LessonState.learned,
        reason: 'rereading a finished lesson must not un-finish it',
      );
    });

    test('inProgress can still become learned', () {
      var stored = withLessonState(null, 'a', LessonState.inProgress);
      stored = withLessonState(stored, 'a', LessonState.learned);
      expect(parseLessonProgress(stored)['a'], LessonState.learned);
    });

    test('other lessons are untouched by a write', () {
      var stored = withLessonState(null, 'a', LessonState.learned);
      stored = withLessonState(stored, 'b', LessonState.inProgress);
      final p = parseLessonProgress(stored);
      expect(p['a'], LessonState.learned);
      expect(p['b'], LessonState.inProgress);
    });
  });

  group('counting and continuing', () {
    test('only learned counts, so opening a lesson earns nothing', () {
      final p = {
        'a': LessonState.inProgress,
        'b': LessonState.learned,
        'c': LessonState.notStarted,
      };
      expect(learnedCount(p, ['a', 'b', 'c']), 1);
    });

    test('the next lesson is the first unfinished one', () {
      final p = {'a': LessonState.learned, 'b': LessonState.inProgress};
      expect(nextLessonId(p, ['a', 'b', 'c']), 'b');
      expect(nextLessonId({'a': LessonState.learned}, ['a']), isNull);
    });
  });

  group('the store', () {
    test('answering marks learned and keeps the old key in step', () async {
      SharedPreferences.setMockInitialValues({});
      final store = SalapifyStore();
      await store.load();
      await store.setLessonState('see-it-first', LessonState.learned);

      expect(store.lessonProgress['see-it-first'], LessonState.learned);
      final settings = store.data['settings'] as Map;
      expect(
        settings['lessonsRead'],
        contains('see-it-first'),
        reason:
            'a backup from this build must still restore onto a build '
            'that only knows the old key',
      );
    });

    test('merely opening does not join the legacy done list', () async {
      SharedPreferences.setMockInitialValues({});
      final store = SalapifyStore();
      await store.load();
      await store.setLessonState('see-it-first', LessonState.inProgress);

      expect(store.lessonProgress['see-it-first'], LessonState.inProgress);
      final read = (store.data['settings'] as Map)['lessonsRead'];
      expect(
        read == null || (read as List).isEmpty,
        isTrue,
        reason: 'an older build must not show an unfinished lesson as done',
      );
    });

    test('progress survives a restart', () async {
      SharedPreferences.setMockInitialValues({});
      final store = SalapifyStore();
      await store.load();
      await store.setLessonState('needs-wants', LessonState.learned);

      final reopened = SalapifyStore();
      await reopened.load();
      expect(reopened.lessonProgress['needs-wants'], LessonState.learned);
    });

    test('an old backup restores without losing progress', () async {
      SharedPreferences.setMockInitialValues({});
      final store = SalapifyStore();
      await store.load();
      // A backup written by the old build: only lessonsRead, no lessonProgress.
      await store.importBackupText(
        '{"schemaVersion":12,"accounts":[],"transactions":[],'
        '"settings":{"lessonsRead":["see-it-first","needs-wants"]}}',
      );
      expect(store.lessonProgress['see-it-first'], LessonState.learned);
      expect(store.lessonProgress['needs-wants'], LessonState.learned);
    });
  });

  group('the typed content model', () {
    test('every lesson converts, with an id, a track, and sections', () {
      for (final raw in lessons) {
        final l = lessonFromMap(raw);
        expect(l.id, isNotEmpty);
        expect(l.trackId, isNotEmpty);
        expect(l.title, isNotEmpty);
        expect(
          l.sections,
          isNotEmpty,
          reason: '${l.id} would render as a blank lesson',
        );
      }
    });

    test('an old-shape lesson still renders as one concept section', () {
      final l = lessonFromMap({
        'id': 'x',
        'track': 't',
        'title': 'T',
        'body': ['one', 'two'],
      });
      expect(l.sections.length, 1);
      expect(l.sections.first.kind, SectionKind.concept);
      expect(l.sections.first.body.length, 2);
    });

    test('a malformed knowledge check is dropped, never shown', () {
      // A quiz that marks the right answer wrong teaches the opposite of the
      // lesson, so a broken one must not render at all.
      final l = lessonFromMap({
        'id': 'x',
        'track': 't',
        'title': 'T',
        'body': ['b'],
        'check': {
          'question': 'Q',
          'choices': ['a', 'b'],
          'answer': 5,
          'explanation': 'E',
        },
      });
      expect(l.check, isNull);
    });

    test('the PH lessons are the time-sensitive ones', () {
      final ph = lessons
          .map(lessonFromMap)
          .where((l) => l.isPhilippines)
          .toList();
      expect(ph, isNotEmpty);
      for (final l in ph) {
        expect(l.isTimeSensitive, isTrue);
      }
    });
  });
}
