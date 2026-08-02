// The learning-path model: optional, separately-published bundles of lessons
// for future Money Courses expansion (Grow Your Money, Protect Your Future,
// Build Your Business, and whatever comes after).
//
// This is deliberately a SEPARATE type from CourseTrack (lesson_model.dart),
// not a generalization of it. The core four tracks are fixed, always
// published, and load-bearing for the "X of 22 lessons" figure on the Learn
// screen; a learning path is optional, starts unpublished, and must never be
// able to satisfy code that pattern-matches on the core type by accident.
// Reusing lessonFromMap/CourseTrack for both would blur exactly the line
// docs/money_courses_expansion_audit.md exists to protect.
//
// No path in this file carries real lesson content yet: the model exists
// before the content does, on purpose, per this phase's own instructions.
// Fixtures for testing live in test/, not here.

/// One named group of lessons inside a learning path, the expansion-path
/// equivalent of a core [CourseTrack] (see lesson_model.dart). A path is
/// built from an ordered list of these rather than one flat lesson list, so
/// a path that spans more than one "course" (e.g. three grouped modules)
/// can still show sub-structure the way the core four tracks do today.
class LearningPathGroup {
  final String id;
  final String title;

  /// This group's lessons, in reading order.
  final List<String> lessonIds;

  const LearningPathGroup({
    required this.id,
    required this.title,
    this.lessonIds = const [],
  });
}

/// Whether a path is ready to show a learner yet. Every path defined before
/// its content exists stays [comingSoon]; nothing in this phase changes that
/// or renders a card for it (see the phase's own compatibility requirements).
enum LearningPathStatus {
  /// Modeled, not yet content-complete. Never shown as an available path.
  comingSoon,

  /// Content complete and safe to list.
  published,

  /// Was published, now withdrawn. Existing learner progress is kept (see
  /// expansion_progress.dart); the path simply stops being offered as new.
  retired,
}

/// An optional, separately-progressed bundle of lessons. Immutable, the same
/// convention [CourseTrack] and [MoneyLesson] already use, so a path is safe
/// to share as a `const` and cannot be mutated out from under a screen that
/// read it.
class LearningPath {
  /// Stable, free-form, unique by convention (same discipline as a lesson
  /// id). Never reused for a different path once a real learner has
  /// progress recorded against it.
  final String id;

  final String title;
  final String shortDescription;

  /// Semantic icon NAME, resolved by widgets/salapify_icon.dart, exactly
  /// like [MoneyLesson.icon] and [CourseTrack.icon]. Not an emoji: this is
  /// Salapify-authored content, not user data.
  final String icon;

  /// This path's courses or lesson groups, in the order they should read.
  final List<LearningPathGroup> groups;

  /// Lesson ids that should be finished (in any path or core track) before
  /// this path is offered. Advisory only: nothing in this model enforces it,
  /// a future screen decides what to do with it.
  final List<String> prerequisiteLessonIds;

  /// A short, user-visible reason this path is suggested right now, in the
  /// same spirit as [CourseRecommendation.reason] in course_plan.dart: a
  /// recommendation without a visible reason is the app being bossy. Null
  /// when the path is not currently being recommended for any reason.
  final String? recommendedReason;

  final LearningPathStatus status;

  const LearningPath({
    required this.id,
    required this.title,
    required this.shortDescription,
    required this.icon,
    this.groups = const [],
    this.prerequisiteLessonIds = const [],
    this.recommendedReason,
    this.status = LearningPathStatus.comingSoon,
  });

  /// This path's lessons, flattened across [groups] in order. Derived rather
  /// than authored separately, so a path can never have its grouped view and
  /// its flat id list disagree.
  List<String> get lessonIds => [for (final g in groups) ...g.lessonIds];

  bool get isAvailable => status == LearningPathStatus.published;
}
