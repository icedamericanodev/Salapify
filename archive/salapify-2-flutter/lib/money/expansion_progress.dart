// Progress for the expansion learning paths (Grow Your Money, Protect Your
// Future, Build Your Business, and any future path), kept in a namespace
// completely separate from the core 22 lessons' settings.lessonProgress.
//
// Shape: settings.expansionProgress = {
//   '<pathId>': { '<lessonId>': {'state': 'completed'} }
// }
//
// Unlike lessonProgress there is no legacy list to fold in: this key never
// existed before this phase, so an absent key, an absent path entry, or an
// absent lesson entry all mean exactly the same thing, "not started", never
// "unknown". That is simpler than the core model on purpose; the core
// model's legacy merge exists only because settings.lessonsRead predates it.
//
// Reuses LessonState (lesson_progress.dart) rather than inventing a second
// enum, per the audit's own smallest-safe-extension-points: the five rungs
// (notStarted, viewed, understood, completed, applied) mean the same thing
// for an expansion lesson as for a core one. LessonState.values is declared
// in rank order, so comparing by enum index gives the same never-demote
// ordering lesson_progress.dart's private _rank does, without needing to
// export or duplicate that ranking.

import 'lesson_progress.dart' show LessonState, isDone;

int _index(LessonState s) => LessonState.values.indexOf(s);

LessonState? _stateFromName(dynamic raw) => switch (raw) {
  'notStarted' => LessonState.notStarted,
  'viewed' => LessonState.viewed,
  'understood' => LessonState.understood,
  'completed' => LessonState.completed,
  'applied' => LessonState.applied,
  _ => null,
};

/// Read the whole expansion-progress map out of settings, junk-safe: any
/// path id, lesson id, or state name that does not parse is skipped rather
/// than thrown on, matching the rest of the store's defensive reads. A path
/// that ends up with no valid lessons is omitted entirely rather than kept
/// as an empty map, so callers never need to special-case "present but
/// empty" versus "absent".
Map<String, Map<String, LessonState>> parseExpansionProgress(dynamic stored) {
  final out = <String, Map<String, LessonState>>{};
  if (stored is! Map) return out;
  for (final pathEntry in stored.entries) {
    final pathId = pathEntry.key;
    final pathValue = pathEntry.value;
    if (pathId is! String || pathId.isEmpty || pathValue is! Map) continue;
    final lessons = <String, LessonState>{};
    for (final lessonEntry in pathValue.entries) {
      final lessonId = lessonEntry.key;
      final lessonValue = lessonEntry.value;
      if (lessonId is! String || lessonId.isEmpty || lessonValue is! Map) {
        continue;
      }
      final state = _stateFromName(lessonValue['state']);
      if (state != null) lessons[lessonId] = state;
    }
    if (lessons.isNotEmpty) out[pathId] = lessons;
  }
  return out;
}

/// The stored form of one expansion-progress change, folded into the
/// existing stored value. Never demotes a lesson within its own path, the
/// same rule withLessonState enforces for the core model; a path's lessons
/// are otherwise untouched and every OTHER path's entry passes through
/// unchanged.
Map<String, dynamic> withExpansionLessonState(
  dynamic existing,
  String pathId,
  String lessonId,
  LessonState state,
) {
  final out = <String, dynamic>{};
  if (existing is Map) {
    for (final e in existing.entries) {
      if (e.key is String && e.value is Map) {
        out[e.key as String] = (e.value as Map).cast<String, dynamic>();
      }
    }
  }
  final pathMap = <String, dynamic>{
    if (out[pathId] is Map) ...(out[pathId] as Map).cast<String, dynamic>(),
  };
  final current =
      _stateFromName((pathMap[lessonId] as Map?)?['state']) ??
      LessonState.notStarted;
  if (_index(state) <= _index(current)) {
    // Never demote. The path map is still written back unchanged so an
    // existing entry for a DIFFERENT lesson in this path is preserved.
    out[pathId] = pathMap;
    return out;
  }
  pathMap[lessonId] = {'state': state.name};
  out[pathId] = pathMap;
  return out;
}

/// Drop one path's progress entirely, leaving every other path (and the
/// core lessonProgress key, which this function never touches) untouched.
/// Not a global reset: callers name exactly one path.
Map<String, dynamic> withExpansionPathCleared(dynamic existing, String pathId) {
  final out = <String, dynamic>{};
  if (existing is Map) {
    for (final e in existing.entries) {
      if (e.key is String && e.key != pathId && e.value is Map) {
        out[e.key as String] = (e.value as Map).cast<String, dynamic>();
      }
    }
  }
  return out;
}

/// Completed and total lesson counts for one path, folded against real
/// progress. The path-scoped equivalent of course_plan.dart's TrackProgress,
/// kept as its own small type rather than reusing TrackProgress so a future
/// change to the core type can never accidentally change expansion-path
/// behavior, or vice versa.
class PathProgress {
  final String pathId;
  final int total;
  final int done;

  const PathProgress({
    required this.pathId,
    required this.total,
    required this.done,
  });

  bool get isComplete => total > 0 && done >= total;
  bool get isStarted => done > 0;

  /// 0..1, and never NaN on a path with no lessons yet.
  double get fraction => total == 0 ? 0 : done / total;
}

/// Fold one path's lessons against its stored progress. [lessonIds] comes
/// from the content (a [LearningPath.lessonIds]) so this file never needs to
/// import the path catalog, the same separation course_plan.dart keeps from
/// lessons.dart.
PathProgress pathProgressFor({
  required String pathId,
  required List<String> lessonIds,
  required Map<String, LessonState> progress,
}) {
  var done = 0;
  for (final id in lessonIds) {
    if (isDone(progress[id] ?? LessonState.notStarted)) done++;
  }
  return PathProgress(pathId: pathId, total: lessonIds.length, done: done);
}
