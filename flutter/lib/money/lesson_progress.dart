// Course progress: what "done" actually means.
//
// The old model was a single list, settings.lessonsRead, written the instant a
// lesson opened. So the progress card counted TAPS. Open a lesson, back out
// immediately, and it read as learned forever. "12 of 22 lessons read" was not
// a measure of learning, and a learner returning to find everything already
// ticked has no way to tell what they actually know.
//
// The new model keeps three states and, importantly, keeps writing the old key
// alongside the new one. Old backups restore into a sensible state, and a
// backup made on this build still restores correctly onto an older build,
// which matters because the two exist side by side during a staged rollout.

/// How far a learner got with one lesson.
///
/// Four states rather than done or not done, because "completed 9 of 22" says
/// nothing about whether anything was understood or used. These are ordered:
/// progress climbs and never falls, so rereading a finished lesson cannot
/// un-finish it.
enum LessonState {
  /// Never opened.
  notStarted,

  /// Opened and read. The lowest rung, and honest about it.
  viewed,

  /// Engaged with the thinking: revealed a discovery answer or answered the
  /// check. This is the first rung that means anything.
  understood,

  /// Reached the end of the lesson having understood it.
  completed,

  /// Took the lesson's action into the app. The TOP rung, not a step below
  /// completed: acting on a lesson is a stronger signal of learning than
  /// tapping a finish button, so someone who read a lesson and went and did
  /// the thing has done more, not less. Ranking it lower meant they were not
  /// counted as done at all, which was simply wrong.
  applied,
}

/// Rank for the never-go-backwards rule. Ordered by how much the learner did,
/// so a lesson someone applied is never quietly demoted by a later reread.
int _rank(LessonState s) => switch (s) {
  LessonState.notStarted => 0,
  LessonState.viewed => 1,
  LessonState.understood => 2,
  LessonState.completed => 3,
  LessonState.applied => 4,
};

/// Completed or applied counts as done for the progress figure. Viewing and
/// understanding are real progress but not a finished lesson.
bool isDone(LessonState s) => _rank(s) >= _rank(LessonState.completed);

/// Read the per-lesson progress map out of settings, junk-safe.
///
/// Shape: `settings.lessonProgress = { '<lessonId>': {'state': 'learned'} }`.
/// Anything unreadable is skipped rather than thrown on,
/// matching the rest of the store's defensive reads.
Map<String, LessonState> parseLessonProgress(
  dynamic stored, {
  dynamic legacyRead,
}) {
  final out = <String, LessonState>{};

  // Legacy FIRST, so an explicit new-model entry always wins over it.
  //
  // Every id in the old lessonsRead list becomes `learned`. That is a
  // deliberate over-count: those entries may only mean "opened once", but
  // demoting them would wipe visible progress the user believes they earned,
  // and taking away a completed tick is a worse wrong than leaving one that
  // was generously granted. New reads earn the state honestly.
  for (final x in (legacyRead is List ? legacyRead : const [])) {
    if (x is String && x.isNotEmpty) out[x] = LessonState.completed;
  }

  if (stored is Map) {
    for (final entry in stored.entries) {
      final id = entry.key;
      final v = entry.value;
      if (id is! String || id.isEmpty || v is! Map) continue;
      final state = switch (v['state']) {
        'completed' => LessonState.completed,
        'applied' => LessonState.applied,
        'understood' => LessonState.understood,
        'viewed' => LessonState.viewed,
        // The three-state names this file shipped with, kept readable so a
        // phone that recorded progress under them keeps it.
        'learned' => LessonState.completed,
        'inProgress' => LessonState.viewed,
        _ => null,
      };
      // Take the HIGHER of the two, never simply the newer one.
      //
      // This was a straight overwrite, and it quietly took ticks away. A
      // lesson finished under the old build lives only in lessonsRead. Open
      // it again on this build and the reader records `viewed`, which then
      // shadowed the legacy `completed` and the lesson went from done back to
      // unfinished on screen. Someone rereading a lesson they had completed
      // was punished for it.
      //
      // Reading the maximum also repairs phones that already stored the lower
      // value: the legacy entry was never deleted, only hidden, so it comes
      // back the moment this runs.
      if (state != null) {
        final legacy = out[id];
        out[id] = (legacy != null && _rank(legacy) > _rank(state))
            ? legacy
            : state;
      }
    }
  }
  return out;
}

/// The stored form of one progress change, folded into the existing map.
/// Progress never goes backwards: re-opening a finished lesson to reread it
/// must not demote it from learned to inProgress.
Map<String, dynamic> withLessonState(
  dynamic existing,
  String id,
  LessonState state, {

  /// The state the app currently believes this lesson is in, INCLUDING any
  /// legacy lessonsRead entry. Without it the never-demote rule only saw the
  /// new-model map and happily wrote a lower state over a lesson whose only
  /// record of being finished lived in the old list.
  LessonState effectiveCurrent = LessonState.notStarted,
}) {
  final out = <String, dynamic>{};
  if (existing is Map) {
    for (final e in existing.entries) {
      if (e.key is String && e.value is Map) {
        out[e.key as String] = (e.value as Map).cast<String, dynamic>();
      }
    }
  }
  final current = switch ((out[id] as Map?)?['state']) {
    'completed' => LessonState.completed,
    'applied' => LessonState.applied,
    'understood' => LessonState.understood,
    'viewed' => LessonState.viewed,
    'learned' => LessonState.completed,
    'inProgress' => LessonState.viewed,
    _ => LessonState.notStarted,
  };
  final floor = _rank(current) > _rank(effectiveCurrent)
      ? current
      : effectiveCurrent;
  if (_rank(state) <= _rank(floor)) return out; // never demote
  out[id] = {'state': state.name};
  return out;
}

/// Lessons finished, out of a set of ids. Only `learned` counts, which is the
/// whole point of the change.
int learnedCount(Map<String, LessonState> progress, Iterable<String> ids) {
  var n = 0;
  for (final id in ids) {
    if (isDone(progress[id] ?? LessonState.notStarted)) n++;
  }
  return n;
}

/// The next lesson to offer in a track: the first one not yet learned, or null
/// when the track is finished. This is what turns a Start button into a
/// Continue button that lands somewhere useful.
String? nextLessonId(Map<String, LessonState> progress, List<String> trackIds) {
  for (final id in trackIds) {
    if (!isDone(progress[id] ?? LessonState.notStarted)) return id;
  }
  return null;
}
