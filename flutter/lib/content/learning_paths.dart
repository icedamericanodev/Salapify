// The concrete learning-path registry: real LearningPath instances
// (content/learning_path.dart's types), as distinct from that file's own
// type definitions. Money Courses Phase 6 is the first path to carry real
// content, "Grow Your Money" with its pilot course "Are You Ready to
// Invest?" (lib/content/lessons_grow.dart).
//
// "Protect Your Future" and "Build Your Business" are deliberately ABSENT
// here, not present as comingSoon stubs. This phase's own catalog rule is
// "do not display empty Protect or Business paths", and the smallest way to
// guarantee that is to never construct them at all: publishedLearningPaths
// below only has to filter on status, but there is nothing here for a
// future bug to accidentally un-filter.

import 'learning_path.dart';
import 'lesson_model.dart' show MoneyLesson;
import 'lessons_grow.dart';

const List<LearningPath> learningPaths = [
  LearningPath(
    id: 'grow_your_money',
    title: 'Grow Your Money',
    shortDescription:
        'Start with whether your foundation, and your money, are ready for '
        'investing.',
    icon: 'growth',
    groups: [
      LearningPathGroup(
        id: 'investing_readiness',
        title: 'Are You Ready to Invest?',
        lessonIds: [
          investRefMoneyJob,
          investRefProtectBase,
          investRefGoalTimeAccess,
          investRefRiskComfortCapacity,
          investRefCard,
        ],
      ),
    ],
    // Advisory only, per LearningPath.prerequisiteLessonIds's own contract:
    // nothing here blocks the path, a catalog screen just shows these as
    // "Recommended first". Both point at core lessons this course directly
    // builds on (the emergency-fund lesson and the card-interest lesson).
    prerequisiteLessonIds: ['emergency-fund', 'card-interest'],
    status: LearningPathStatus.published,
  ),
];

/// Paths safe to list in a catalog: published only. A comingSoon or
/// retired path (neither exists yet in [learningPaths]) would never reach
/// here even if one were added later without checking this first.
List<LearningPath> get publishedLearningPaths => [
  for (final p in learningPaths)
    if (p.isAvailable) p,
];

/// A lesson paired with the path id that owns it, since expansion progress
/// is written per path (settings.expansionProgress) and a bare lesson id is
/// not enough to know which path's progress to touch.
class MoneyLessonWithPath {
  final String pathId;
  final MoneyLesson lesson;
  const MoneyLessonWithPath({required this.pathId, required this.lesson});
}

/// This path's lessons, in reading order, or an empty list for a path id
/// this file does not know content for yet. The one closed switch a second
/// path's content file adds a branch to, the same pattern
/// screens/learn.dart's own `_resolveAction` and
/// widgets/expansion_lesson_reader.dart's `_resolveGrowAction` already use
/// for "a small, explicit, growable set of known cases".
List<MoneyLesson> lessonsForPath(String pathId) => switch (pathId) {
  'grow_your_money' => growYourMoneyLessons,
  _ => const [],
};

/// Finds an expansion lesson (and its owning path id) by lesson id, across
/// every published path's own content. Null when not found, the same
/// fails-safe convention lessons.dart's own `lessonById` follows: an
/// unknown id is a safe no-op, never a crash. Only 'grow_your_money' has
/// content today; a second path's content file gets a matching branch here
/// when it ships.
MoneyLessonWithPath? expansionLessonById(String id) {
  for (final lesson in growYourMoneyLessons) {
    if (lesson.id == id) {
      return MoneyLessonWithPath(pathId: 'grow_your_money', lesson: lesson);
    }
  }
  return null;
}
