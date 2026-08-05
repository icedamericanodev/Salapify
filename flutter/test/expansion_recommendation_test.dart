// Phase 16's expansion-path recommendation engine
// (money/expansion_recommendation.dart). Uses fixture paths only, the same
// discipline learning_path_test.dart already follows, so this proves the
// RULE rather than any one real course's current progress state (which
// would rot as content changes).

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/content/learning_path.dart';
import 'package:salapify/money/expansion_recommendation.dart';
import 'package:salapify/money/lesson_progress.dart';

const _paths = [
  LearningPath(
    id: 'grow_your_money',
    title: 'Grow Your Money',
    shortDescription: 'Turn saving into growing.',
    icon: 'growth',
    status: LearningPathStatus.published,
    groups: [
      LearningPathGroup(
        id: 'investing_readiness',
        title: 'Are You Ready to Invest?',
        lessonIds: ['gym-1', 'gym-2'],
      ),
      LearningPathGroup(
        id: 'stocks_and_bonds',
        title: 'Stocks and Bonds Without the Hype',
        lessonIds: ['sb-1', 'sb-2'],
      ),
    ],
  ),
  LearningPath(
    id: 'build_your_business',
    title: 'Build Your Business',
    shortDescription: 'From side hustle to registered business.',
    icon: 'mountain',
    status: LearningPathStatus.published,
    groups: [
      LearningPathGroup(
        id: 'start_a_business_legally',
        title: 'Start Your Business Legally',
        lessonIds: ['br-1', 'br-2'],
      ),
      LearningPathGroup(
        id: 'bir_registration_and_local_permits',
        title: 'BIR Registration and Local Permits',
        lessonIds: ['birl-1', 'birl-2'],
      ),
      LearningPathGroup(
        id: 'bir_registration_tax_setup',
        title: 'BIR Setup for New Businesses',
        lessonIds: ['btax-1', 'btax-2'],
      ),
    ],
  ),
];

Map<String, Map<String, LessonState>> _progress(
  Map<String, Map<String, LessonState>> byPath,
) => byPath;

void main() {
  group('no reliable signal', () {
    // Required test 7 (fallback half): if no reliable signal exists, show a
    // neutral discovery state instead of inventing a reason.
    test('an empty store recommends nothing at all', () {
      final rec = recommendedExpansionCourse(_paths, const {});
      expect(rec, isNull);
    });

    test('every path fully complete recommends nothing (nothing left to '
        'suggest, and a finished course is never re-suggested)', () {
      final rec = recommendedExpansionCourse(_paths, {
        'grow_your_money': {
          'gym-1': LessonState.completed,
          'gym-2': LessonState.completed,
          'sb-1': LessonState.completed,
          'sb-2': LessonState.completed,
        },
      });
      expect(rec, isNull);
    });
  });

  group('sequencing', () {
    // Required test 6: Investment Readiness comes before asset-specific
    // education.
    test('investment readiness is recommended over a started but unrelated '
        'asset-specific course in the same path', () {
      final rec = recommendedExpansionCourse(
        _paths,
        _progress({
          // gym-1 completed is the real signal (isStarted needs a DONE
          // lesson, the same rule course_plan.dart's TrackProgress already
          // uses); sb-1 merely opened shows a learner who peeked ahead, and
          // sequencing must still recommend the unfinished earlier course.
          'grow_your_money': {
            'gym-1': LessonState.completed,
            'sb-1': LessonState.viewed,
          },
        }),
      );
      expect(rec?.pathId, 'grow_your_money');
      expect(rec?.groupId, 'investing_readiness');
    });

    test('once investing readiness is complete, the recommendation moves to '
        'the next course, never back to a completed one', () {
      final rec = recommendedExpansionCourse(
        _paths,
        _progress({
          'grow_your_money': {
            'gym-1': LessonState.completed,
            'gym-2': LessonState.completed,
            'sb-1': LessonState.viewed,
          },
        }),
      );
      expect(rec?.pathId, 'grow_your_money');
      expect(rec?.groupId, 'stocks_and_bonds');
    });

    // Required test 5: business-course sequencing is correct (course 1, then
    // course 2, then course 3, in that order, never skipping ahead).
    test('business path recommends the first course before any other has '
        'started', () {
      final rec = recommendedExpansionCourse(
        _paths,
        _progress({
          'build_your_business': {'br-1': LessonState.completed},
        }),
      );
      expect(rec?.groupId, 'start_a_business_legally');
    });

    test('business path recommends the SECOND course once the first is '
        'done, even if the learner has already dipped into the third', () {
      final rec = recommendedExpansionCourse(
        _paths,
        _progress({
          'build_your_business': {
            'br-1': LessonState.completed,
            'br-2': LessonState.completed,
            // Progress exists on the third course too, but sequencing still
            // recommends the second (declared order), never skipping ahead.
            'btax-1': LessonState.viewed,
          },
        }),
      );
      expect(rec?.groupId, 'bir_registration_and_local_permits');
    });

    test('business path recommends the third course once the first two are '
        'done', () {
      final rec = recommendedExpansionCourse(
        _paths,
        _progress({
          'build_your_business': {
            'br-1': LessonState.completed,
            'br-2': LessonState.completed,
            'birl-1': LessonState.completed,
            'birl-2': LessonState.completed,
          },
        }),
      );
      expect(rec?.groupId, 'bir_registration_tax_setup');
    });
  });

  group('one primary recommendation at a time', () {
    // Required test 4: recommendation order is deterministic.
    test('two paths both started: the earlier path in catalog order wins, '
        'and only one recommendation is ever returned', () {
      final rec = recommendedExpansionCourse(
        _paths,
        _progress({
          'grow_your_money': {'gym-1': LessonState.completed},
          'build_your_business': {'br-1': LessonState.completed},
        }),
      );
      expect(rec?.pathId, 'grow_your_money');
    });

    test('calling twice with the same input returns the same recommendation '
        '(deterministic, no clock or randomness)', () {
      final progress = _progress({
        'build_your_business': {'br-1': LessonState.completed},
      });
      final first = recommendedExpansionCourse(_paths, progress);
      final second = recommendedExpansionCourse(_paths, progress);
      expect(first?.pathId, second?.pathId);
      expect(first?.groupId, second?.groupId);
      expect(first?.reason, second?.reason);
    });
  });

  group('safe, plain-language reasons', () {
    // Required test 8: recommendation reasons contain no sensitive amounts.
    // Required test 9: no recommendation tells the user to buy, invest,
    // borrow, or select a structure.
    const bannedWords = [
      'buy',
      'invest ',
      'invest.',
      'invest,',
      'borrow',
      'register',
      'select a',
      'choose a structure',
    ];

    test('every reachable reason is non-empty, has no digits or peso signs, '
        'and never instructs a financial or legal action', () {
      final fixtures = <Map<String, Map<String, LessonState>>>[
        _progress({
          'grow_your_money': {'gym-1': LessonState.completed},
        }),
        _progress({
          'grow_your_money': {
            'gym-1': LessonState.completed,
            'gym-2': LessonState.completed,
            'sb-1': LessonState.viewed,
          },
        }),
        _progress({
          'build_your_business': {'br-1': LessonState.completed},
        }),
        _progress({
          'build_your_business': {
            'br-1': LessonState.completed,
            'br-2': LessonState.completed,
            'btax-1': LessonState.viewed,
          },
        }),
      ];
      for (final progress in fixtures) {
        final rec = recommendedExpansionCourse(_paths, progress);
        expect(rec, isNotNull);
        final reason = rec!.reason;
        expect(reason.trim(), isNotEmpty);
        expect(RegExp(r'\d').hasMatch(reason), isFalse, reason: reason);
        expect(reason.contains('₱'), isFalse, reason: reason);
        final lower = reason.toLowerCase();
        for (final w in bannedWords) {
          expect(
            lower.contains(w),
            isFalse,
            reason: 'reason "$reason" contains banned word "$w"',
          );
        }
      }
    });
  });
}
