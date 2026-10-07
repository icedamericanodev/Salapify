// The learning-path model itself: immutable, additive, no dependency on any
// real lesson content. Uses fixture ids only, per this phase's own
// instruction not to add real path content or empty path cards yet. The
// three suggested real ids (grow_your_money, protect_your_future,
// build_your_business) are used here as fixtures so the model is proven
// against the shape they will eventually need, without shipping them.

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/content/lessons.dart';
import 'package:salapify/content/learning_path.dart';

void main() {
  group('LearningPath', () {
    test('flattens groups into an ordered lesson id list', () {
      const path = LearningPath(
        id: 'grow_your_money',
        title: 'Grow Your Money',
        shortDescription: 'Turn saving into growing.',
        icon: 'growth',
        groups: [
          LearningPathGroup(
            id: 'foundations',
            title: 'Foundations',
            lessonIds: ['gym-1', 'gym-2'],
          ),
          LearningPathGroup(
            id: 'next-steps',
            title: 'Next steps',
            lessonIds: ['gym-3'],
          ),
        ],
      );
      expect(path.lessonIds, ['gym-1', 'gym-2', 'gym-3']);
    });

    test('a path with no groups yet has an empty lesson id list', () {
      const path = LearningPath(
        id: 'protect_your_future',
        title: 'Protect Your Future',
        shortDescription: 'Insurance and government benefits, plainly.',
        icon: 'shield',
      );
      expect(path.lessonIds, isEmpty);
      expect(path.groups, isEmpty);
    });

    test('comingSoon is the default and is never available', () {
      const path = LearningPath(
        id: 'build_your_business',
        title: 'Build Your Business',
        shortDescription: 'From side hustle to registered business.',
        icon: 'mountain',
      );
      expect(path.status, LearningPathStatus.comingSoon);
      expect(path.isAvailable, isFalse);
    });

    test('published is the only status that is available', () {
      const path = LearningPath(
        id: 'grow_your_money',
        title: 'Grow Your Money',
        shortDescription: 'Turn saving into growing.',
        icon: 'growth',
        status: LearningPathStatus.published,
      );
      expect(path.isAvailable, isTrue);

      const retired = LearningPath(
        id: 'grow_your_money',
        title: 'Grow Your Money',
        shortDescription: 'Turn saving into growing.',
        icon: 'growth',
        status: LearningPathStatus.retired,
      );
      expect(retired.isAvailable, isFalse);
    });

    test('prerequisite lesson ids and a recommended reason are optional', () {
      const withExtras = LearningPath(
        id: 'grow_your_money',
        title: 'Grow Your Money',
        shortDescription: 'Turn saving into growing.',
        icon: 'growth',
        prerequisiteLessonIds: ['cushion-1'],
        recommendedReason: 'You finished your cushion track.',
      );
      expect(withExtras.prerequisiteLessonIds, ['cushion-1']);
      expect(withExtras.recommendedReason, 'You finished your cushion track.');

      const withoutExtras = LearningPath(
        id: 'grow_your_money',
        title: 'Grow Your Money',
        shortDescription: 'Turn saving into growing.',
        icon: 'growth',
      );
      expect(withoutExtras.prerequisiteLessonIds, isEmpty);
      expect(withoutExtras.recommendedReason, isNull);
    });
  });

  group('compatibility: nothing here touches the core catalog', () {
    test('the core 22 lessons and four tracks are exactly what they were', () {
      expect(lessons.length, 22);
      expect(courseTracks.length, 4);
    });

    test('a learning path built from fixture ids never appears in the core '
        'lists', () {
      const path = LearningPath(
        id: 'grow_your_money',
        title: 'Grow Your Money',
        shortDescription: 'Turn saving into growing.',
        icon: 'growth',
        groups: [
          LearningPathGroup(
            id: 'foundations',
            title: 'Foundations',
            lessonIds: ['gym-1'],
          ),
        ],
      );
      final coreIds = lessons.map((l) => l['id']).toSet();
      for (final id in path.lessonIds) {
        expect(coreIds.contains(id), isFalse);
      }
      final coreTrackIds = courseTracks.map((t) => t['key']).toSet();
      expect(coreTrackIds.contains(path.id), isFalse);
    });
  });
}
