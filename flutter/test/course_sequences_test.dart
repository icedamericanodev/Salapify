// Guards for content/course_sequences.dart: the real reading order both
// readers hand to money/lesson_flow.dart.
//
// These run against the SHIPPED content, not fixtures, because the thing
// most likely to break here is a content edit (a lesson added to a group,
// a group reordered) rather than the flattening itself.

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/content/course_sequences.dart';
import 'package:salapify/content/learning_paths.dart';
import 'package:salapify/content/lessons.dart';

void main() {
  group('coreFlowSequence', () {
    test('carries every core lesson exactly once', () {
      final seq = coreFlowSequence();
      expect(seq.length, lessons.length);
      expect(seq.map((l) => l.id).toSet().length, seq.length);
    });

    test('groups by track, and every lesson names its track', () {
      final seq = coreFlowSequence();
      final trackKeys = {for (final t in courseTracks) t['key'] as String};
      for (final l in seq) {
        expect(
          trackKeys.contains(l.groupId),
          isTrue,
          reason: '${l.id} claims track ${l.groupId}, which does not exist',
        );
        expect(l.groupTitle, isNotEmpty);
      }
    });

    test('keeps each track contiguous, so a course cannot be interleaved', () {
      // finishOutcome decides "course complete" from groupId, which survives
      // interleaving, but a Next button that jumped between tracks and back
      // would read as random to a learner.
      final seen = <String>{};
      String? current;
      for (final l in coreFlowSequence()) {
        if (l.groupId != current) {
          expect(
            seen.contains(l.groupId),
            isFalse,
            reason: 'track ${l.groupId} resumes after another track',
          );
          if (current != null) seen.add(current);
          current = l.groupId;
        }
      }
    });

    test('every lesson has a positive minute figure', () {
      for (final l in coreFlowSequence()) {
        expect(l.minutes, greaterThan(0), reason: l.id);
      }
    });
  });

  group('expansionFlowSequence', () {
    test('every published path flattens to its own lesson count', () {
      for (final path in publishedLearningPaths) {
        final seq = expansionFlowSequence(path);
        expect(
          seq.length,
          path.lessonIds.length,
          reason: '${path.id} lost or gained a lesson when flattened',
        );
        expect(seq.map((l) => l.id).toSet().length, seq.length);
      }
    });

    test('lesson order matches the path own group order', () {
      for (final path in publishedLearningPaths) {
        expect(
          expansionFlowSequence(path).map((l) => l.id).toList(),
          path.lessonIds,
          reason: '${path.id} reordered its lessons',
        );
      }
    });

    test('every lesson names the course it belongs to', () {
      for (final path in publishedLearningPaths) {
        final groupIds = {for (final g in path.groups) g.id};
        for (final l in expansionFlowSequence(path)) {
          expect(groupIds.contains(l.groupId), isTrue, reason: l.id);
          expect(l.groupTitle, isNotEmpty, reason: l.id);
        }
      }
    });
  });

  group('learningPathById', () {
    test('finds every published path', () {
      for (final path in publishedLearningPaths) {
        expect(learningPathById(path.id)?.id, path.id);
      }
    });

    test('an unknown id is null rather than a crash', () {
      expect(learningPathById('no-such-path'), isNull);
    });
  });
}
