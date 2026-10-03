// Phase 16's recommendation engine for the expansion learning paths (Grow
// Your Money, Protect Your Future, Build Your Business, and any future
// path). Deliberately reuses the existing architecture rather than adding a
// new one: [LearningPath]/[LearningPathGroup] (content/learning_path.dart)
// for the ordered course sequence, and [PathProgress]/[pathProgressFor]
// (money/expansion_progress.dart) for folding stored progress, the same
// building blocks course_plan.dart's own recommendedTrack() and
// expansion_progress.dart already use. No AI, no remote signal, no analytics,
// no new profile model: this reads only real, on-device lesson progress.
//
// The rule, in order:
// 1. A path with NO progress at all is not a reliable signal (per this
//    phase's own "no reliable signal, no invented reason" instruction), so it
//    is never the source of a recommendation on its own.
// 2. A path that is fully complete never stays the primary recommendation,
//    per this phase's own instruction; a finished course is not suggested
//    again.
// 3. Among paths with real, incomplete progress, the first one in catalog
//    order (learningPaths' own declared order) wins. This mirrors
//    recommendedTrack()'s own "first match in a fixed priority order wins"
//    determinism, just over paths instead of urgency signals.
// 4. Within that path, the first group (course) NOT yet complete, in the
//    path's own declared group order, is the one named. Group order already
//    encodes the sequencing every group's own recommendedPriorGroupIds
//    describes (investing_readiness before any asset-specific course in Grow
//    Your Money; start_a_business_legally before the later BIR and permits
//    courses in Build Your Business), so following array order alone is
//    enough to respect that sequencing without re-deriving it here.
//
// Exactly one recommendation is ever returned, or none. A null result is the
// neutral discovery state: nothing here invents a reason when no reliable
// signal exists.

import '../content/learning_path.dart';
import 'expansion_progress.dart';
import 'lesson_progress.dart';

class ExpansionRecommendation {
  final String pathId;
  final String groupId;

  /// Shown to the user, always. The same "a recommendation without a visible
  /// reason is the app being bossy" rule course_plan.dart's own
  /// CourseRecommendation follows. Never quotes a balance, a debt, an
  /// income amount, or any other sensitive figure, and never tells the
  /// reader to buy, invest, borrow, register, or choose a business
  /// structure: this recommends EDUCATION, not a financial or legal choice.
  final String reason;

  const ExpansionRecommendation({
    required this.pathId,
    required this.groupId,
    required this.reason,
  });
}

String _reasonFor(String pathId, String groupId, String groupTitle) {
  // Named wording for the two sequencing rules this phase calls out
  // explicitly. Both stay generic: no product, no amount, no instruction to
  // act financially or legally, only "keep learning in this order".
  if (pathId == 'grow_your_money' && groupId == 'investing_readiness') {
    return 'Finish Are You Ready to Invest? before exploring specific '
        'investment topics.';
  }
  if (pathId == 'build_your_business') {
    return 'Continue with the next incomplete business course.';
  }
  return 'Continue with $groupTitle, the next course in this path.';
}

/// The one course (learning-path group) to recommend right now, or null for
/// the neutral discovery state. [paths] should be [publishedLearningPaths]
/// (learning_paths.dart); [progressByPathId] should have one entry per path
/// id from [SalapifyStore.expansionProgressFor], the same shape
/// [parseExpansionProgress] already returns. A path id with no entry, or an
/// entry that parses to nothing, is read as "not started", never "unknown",
/// matching parseExpansionProgress's own convention.
ExpansionRecommendation? recommendedExpansionCourse(
  List<LearningPath> paths,
  Map<String, Map<String, LessonState>> progressByPathId,
) {
  for (final path in paths) {
    if (!path.isAvailable) continue;
    final progress = progressByPathId[path.id] ?? const {};
    final pathProgress = pathProgressFor(
      pathId: path.id,
      lessonIds: path.lessonIds,
      progress: progress,
    );
    // No signal, or already finished: neither makes this path the primary
    // recommendation. Move on to the next path in catalog order.
    if (!pathProgress.isStarted || pathProgress.isComplete) continue;

    for (final group in path.groups) {
      final groupProgress = pathProgressFor(
        pathId: path.id,
        lessonIds: group.lessonIds,
        progress: progress,
      );
      if (groupProgress.isComplete) continue;
      return ExpansionRecommendation(
        pathId: path.id,
        groupId: group.id,
        reason: _reasonFor(path.id, group.id, group.title),
      );
    }
    // Every group complete but pathProgress said incomplete cannot happen
    // (PathProgress folds the same flattened lessonIds), so this loop always
    // returns above once pathProgress.isStarted && !pathProgress.isComplete.
  }
  return null;
}
