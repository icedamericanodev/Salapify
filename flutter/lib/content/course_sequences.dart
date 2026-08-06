// The reading order a learner is actually inside, as the flat sequence
// money/lesson_flow.dart needs to answer "what did that finish, and what is
// next".
//
// This is the one place the two content shapes are flattened into the same
// thing. The core 22 lessons live as authoring maps in lessons.dart grouped
// by track; the expansion lessons live as typed MoneyLesson objects grouped
// by LearningPathGroup. Both are a list of lessons inside named courses, and
// building that list at each call site is how the two readers would drift
// apart again.
//
// Pure Dart, no Flutter import: a widget test can build a sequence without a
// pumped widget, and lesson_flow.dart stays free of any content import.
//
// Note the direction of the dependency. This file is content-aware and
// imports money/lesson_flow.dart, never the reverse, so the decision logic
// stays testable against invented fixtures rather than against the real 93
// lessons.

import '../money/course_plan.dart';
import '../money/lesson_flow.dart';
import '../money/lesson_progress.dart';
import '../money/reading_time.dart';
import 'learning_path.dart';
import 'learning_paths.dart';
import 'lessons.dart';

/// Every core lesson, in track order then lesson order, grouped by track.
///
/// All 22 rather than one track's worth, on purpose: finishing the last
/// lesson of a track should hand the learner the first lesson of the next
/// one instead of a dead end, and a sequence that stopped at the track
/// boundary could never offer that. Track completion is still detected,
/// because [FlowLesson.groupId] carries the track key.
List<FlowLesson> coreFlowSequence() => [
  for (final track in courseTracks)
    for (final lesson in lessonsForTrack(track['key'] as String))
      FlowLesson(
        id: lesson['id'] as String,
        title: lesson['title'] as String,
        minutes: lesson['minutes'] is int ? lesson['minutes'] as int : 1,
        groupId: track['key'] as String,
        groupTitle: track['title'] as String,
      ),
];

/// One expansion path's lessons, in course order then lesson order.
///
/// Driven by [LearningPath.groups] rather than by lessonsForPath's flat
/// list, because the group is what names the course a learner just
/// finished. A lesson id listed in a group with no matching content is
/// skipped rather than faked, the same fails-safe convention
/// expansionLessonById follows.
List<FlowLesson> expansionFlowSequence(LearningPath path) {
  final byId = {for (final l in lessonsForPath(path.id)) l.id: l};
  return [
    for (final group in path.groups)
      for (final id in group.lessonIds)
        if (byId[id] case final lesson?)
          FlowLesson(
            id: lesson.id,
            title: lesson.title,
            // The honest figure, so a "Next: ... 5 min" button cannot
            // promise less time than the lesson behind it needs.
            minutes: displayMinutes(lesson),
            groupId: group.id,
            groupTitle: group.title,
          ),
  ];
}

/// The path that owns [pathId], or null when there is no such published
/// path. Lets a reader rebuild its own sequence from just the id it was
/// constructed with.
LearningPath? learningPathById(String pathId) {
  for (final p in publishedLearningPaths) {
    if (p.id == pathId) return p;
  }
  return null;
}

/// The one core lesson worth offering someone right now, or null when every
/// core lesson is finished.
///
/// This exists for the Home screen. Money Courses is reached today through
/// Menu, then Tools, then a row below the currency converter, and the
/// experience audit's blunt finding was that the app's largest content
/// investment sits behind a door most people never open. A lesson offered
/// where the user already is costs them nothing to decline and is the
/// cheapest possible fix for that.
///
/// It defers to the existing recommendation engine rather than inventing a
/// second one: [recommendedTrack] already reads real transaction signals
/// (a debt being paid down, irregular income, a recent windfall) and always
/// answers, so the offer is the same one the Learn screen would make. Only
/// if that track is finished does it fall back to the first unfinished
/// lesson anywhere, so a learner is never offered nothing while unread
/// lessons remain.
FlowLesson? nextCoreLesson({
  required Map<String, dynamic> data,
  required Map<String, LessonState> progress,
  required DateTime now,
}) {
  bool unfinished(FlowLesson l) =>
      !isDone(progress[l.id] ?? LessonState.notStarted);

  final sequence = coreFlowSequence();
  final recommended = recommendedTrack(data, now).trackId;
  for (final l in sequence) {
    if (l.groupId == recommended && unfinished(l)) return l;
  }
  for (final l in sequence) {
    if (unfinished(l)) return l;
  }
  return null;
}
