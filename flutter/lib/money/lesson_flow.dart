// What finishing a lesson just completed, and what to offer next.
//
// This exists because finishing a lesson used to be a dead end. The reader
// showed one quiet row ("Done. One useful thing.") and the learner had to
// press back, find the hub among seven cards, and re-enter the course to
// read the next lesson. For a thirty lesson path that is thirty hub hunts,
// and the experience audit (docs/money_courses_experience_audit.md, finding
// C2) named it the single biggest per-step leak in the funnel.
//
// Pure Dart, no Flutter import and no clock read, the same discipline the
// rest of lib/money already follows (lesson_progress.dart,
// expansion_progress.dart, interaction_completion.dart). It decides only
// two things, what scope just completed and which lesson comes next; what a
// reader DOES with that (fire a celebration, draw a button) is the widget's
// concern, and the user-visible sentences live with the widgets rather than
// here.
//
// It is deliberately one module serving BOTH readers. The core 22 lessons
// and the expansion paths keep their two separate progress stores, on
// purpose, but "did that finish the course, and what is next" is the same
// question in both, and answering it twice is how the two readers drifted
// apart in the first place (one offers a quiz retry, the other does not).
// The caller supplies an already-ordered sequence, so this file never needs
// to know which store the progress came from.

import 'lesson_progress.dart' show LessonState, isDone;

/// One lesson's place in a reading sequence: the minimum a "what is next"
/// decision needs, so this file never depends on either lesson type (the
/// core authoring maps in lessons.dart or the typed MoneyLesson the
/// expansion paths use).
///
/// [groupId] is the unit a learner would call a course: a track key for the
/// core 22, a LearningPathGroup id for an expansion path.
class FlowLesson {
  final String id;
  final String title;
  final int minutes;
  final String groupId;
  final String groupTitle;

  const FlowLesson({
    required this.id,
    required this.title,
    required this.minutes,
    required this.groupId,
    required this.groupTitle,
  });
}

/// The largest unit that finishing one lesson just completed.
///
/// Ordered smallest to largest, and exactly one is reported per finish: a
/// lesson that completes its course inside a path that is now also finished
/// reports [path], never all three, so a learner sees one celebration rather
/// than a stack of three.
enum FinishScope {
  /// A lesson finished, with more left in its course.
  lesson,

  /// That lesson was the last unfinished one in its course.
  course,

  /// That lesson was the last unfinished one in the whole track or path.
  path,
}

/// What just happened, and where to go next.
class FinishOutcome {
  final FinishScope scope;

  /// The course that just completed, null unless [scope] is
  /// [FinishScope.course].
  final String? completedCourseTitle;

  /// The next lesson to offer, or null when everything in the sequence is
  /// done. Never the lesson that was just finished.
  final FlowLesson? next;

  /// True when [next] belongs to a different course than the lesson just
  /// finished, so a reader can say "Next course" rather than "Next lesson"
  /// and the learner is never surprised by a change of subject.
  final bool nextStartsNewCourse;

  /// Lessons done and total across the WHOLE sequence the caller passed,
  /// for a progress line on the finish screen.
  final int done;
  final int total;

  /// The same counts for just the course the finished lesson sits in.
  ///
  /// Both are offered because they motivate differently: "4 of 6 in Your
  /// first cushion" reads as nearly there, while "4 of 22" reads as barely
  /// started, and the experience audit's small-area finding is that early
  /// progress against a big denominator suppresses starting. A finish
  /// screen should lead with the course figure.
  final int doneInCourse;
  final int totalInCourse;

  const FinishOutcome({
    required this.scope,
    required this.next,
    required this.nextStartsNewCourse,
    required this.done,
    required this.total,
    required this.doneInCourse,
    required this.totalInCourse,
    this.completedCourseTitle,
  });
}

/// One course's standing inside a path, for a catalog screen.
class CourseProgress {
  final String groupId;
  final String groupTitle;
  final int done;
  final int total;

  /// The first unfinished lesson in this course, or null when it is done.
  final String? nextLessonId;

  const CourseProgress({
    required this.groupId,
    required this.groupTitle,
    required this.done,
    required this.total,
    required this.nextLessonId,
  });

  bool get isComplete => total > 0 && done >= total;
  bool get isStarted => done > 0;

  /// What a button on this course should say.
  String get actionLabel => isComplete
      ? 'Read again'
      : isStarted
      ? 'Continue'
      : 'Start';
}

/// The one course a learner should be nudged into next, or null when the
/// whole path is finished.
///
/// A screen listing five courses can only have ONE loud button. The first
/// draft of the courses screen gave every card the same filled accent
/// button, and the render showed five identical orange slabs down the page
/// with nothing for the eye to follow, which is the same "everything is
/// emphasised so nothing is" note the experience audit made about the hub.
///
/// A started-but-unfinished course wins over an untouched one even if the
/// untouched one comes first, because resuming something half-read is a
/// smaller ask than starting a new subject. Otherwise it is simply the
/// first unfinished course in order.
String? focusCourseId(List<CourseProgress> courses) {
  for (final c in courses) {
    if (c.isStarted && !c.isComplete) return c.groupId;
  }
  for (final c in courses) {
    if (!c.isComplete) return c.groupId;
  }
  return null;
}

/// Every course in [sequence], in order, with its own counts.
///
/// Derived from the sequence rather than from the path's groups directly, so
/// a course whose lessons are missing content simply does not appear instead
/// of showing as an empty card. Courses keep the order they first appear in.
List<CourseProgress> courseProgress(
  List<FlowLesson> sequence,
  Map<String, LessonState> progress,
) {
  final order = <String>[];
  final byGroup = <String, List<FlowLesson>>{};
  for (final l in sequence) {
    if (!byGroup.containsKey(l.groupId)) order.add(l.groupId);
    byGroup.putIfAbsent(l.groupId, () => []).add(l);
  }
  return [
    for (final id in order)
      () {
        final lessons = byGroup[id]!;
        bool done(String x) => isDone(progress[x] ?? LessonState.notStarted);
        return CourseProgress(
          groupId: id,
          groupTitle: lessons.first.groupTitle,
          done: lessons.where((l) => done(l.id)).length,
          total: lessons.length,
          nextLessonId: lessons
              .where((l) => !done(l.id))
              .map((l) => l.id)
              .firstOrNull,
        );
      }(),
  ];
}

/// What finishing [finishedId] completed, and what to read next.
///
/// [sequence] is the full ordered reading order the learner is inside: all
/// 22 core lessons for a core track reader, or one path's lessons for an
/// expansion reader. [progress] must be the state AFTER the finish was
/// recorded, which is what both readers have by the time they draw the
/// finish row; passing the pre-finish map would report the just-finished
/// lesson as the next one to read.
///
/// The next lesson is the first unfinished lesson AFTER [finishedId], and
/// only if there is none does it fall back to the first unfinished lesson
/// anywhere in [sequence]. The fallback is what serves a learner who
/// skipped around instead of reading in order: without it, finishing the
/// last lesson of a path with an unread lesson in the middle would offer
/// nothing at all and look like the path was complete.
///
/// An unknown [finishedId] (not in [sequence]) is treated as a plain lesson
/// finish and still offers the first unfinished lesson, the same fails-safe
/// convention lessonById and expansionLessonById already follow: an id this
/// file does not recognise is never a crash.
FinishOutcome finishOutcome({
  required String finishedId,
  required List<FlowLesson> sequence,
  required Map<String, LessonState> progress,
}) {
  bool done(String id) => isDone(progress[id] ?? LessonState.notStarted);

  final index = sequence.indexWhere((l) => l.id == finishedId);
  final doneCount = sequence.where((l) => done(l.id)).length;

  FlowLesson? next;
  if (index >= 0) {
    for (var i = index + 1; i < sequence.length; i++) {
      if (!done(sequence[i].id)) {
        next = sequence[i];
        break;
      }
    }
  }
  if (next == null) {
    for (final l in sequence) {
      if (l.id != finishedId && !done(l.id)) {
        next = l;
        break;
      }
    }
  }

  // Scope, largest first. "Everything done" wins over "this course done",
  // so the last lesson of a path celebrates the path and not the course it
  // happened to sit in.
  final everythingDone = sequence.isNotEmpty && doneCount >= sequence.length;
  final finished = index >= 0 ? sequence[index] : null;
  final courseLessons = finished == null
      ? const <FlowLesson>[]
      : sequence.where((l) => l.groupId == finished.groupId).toList();
  final courseDoneCount = courseLessons.where((l) => done(l.id)).length;
  final courseDone =
      courseLessons.isNotEmpty && courseDoneCount >= courseLessons.length;

  final scope = everythingDone
      ? FinishScope.path
      : courseDone
      ? FinishScope.course
      : FinishScope.lesson;

  return FinishOutcome(
    scope: scope,
    completedCourseTitle: scope == FinishScope.course
        ? finished?.groupTitle
        : null,
    next: next,
    nextStartsNewCourse:
        next != null && finished != null && next.groupId != finished.groupId,
    done: doneCount,
    total: sequence.length,
    doneInCourse: courseDoneCount,
    totalInCourse: courseLessons.length,
  );
}
