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
enum LessonState {
  /// Never opened.
  notStarted,

  /// Opened, but the knowledge check has not been answered yet.
  inProgress,

  /// Read through and answered the check. This is what counts as done.
  learned,
}

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
    if (x is String && x.isNotEmpty) out[x] = LessonState.learned;
  }

  if (stored is Map) {
    for (final entry in stored.entries) {
      final id = entry.key;
      final v = entry.value;
      if (id is! String || id.isEmpty || v is! Map) continue;
      final state = switch (v['state']) {
        'learned' => LessonState.learned,
        'inProgress' => LessonState.inProgress,
        _ => null,
      };
      if (state != null) out[id] = state;
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
  final current = switch ((out[id] as Map?)?['state']) {
    'learned' => LessonState.learned,
    'inProgress' => LessonState.inProgress,
    _ => LessonState.notStarted,
  };
  if (current == LessonState.learned && state != LessonState.learned) {
    return out; // never demote
  }
  out[id] = {'state': state.name};
  return out;
}

/// Lessons finished, out of a set of ids. Only `learned` counts, which is the
/// whole point of the change.
int learnedCount(Map<String, LessonState> progress, Iterable<String> ids) {
  var n = 0;
  for (final id in ids) {
    if (progress[id] == LessonState.learned) n++;
  }
  return n;
}

/// The next lesson to offer in a track: the first one not yet learned, or null
/// when the track is finished. This is what turns a Start button into a
/// Continue button that lands somewhere useful.
String? nextLessonId(Map<String, LessonState> progress, List<String> trackIds) {
  for (final id in trackIds) {
    if (progress[id] != LessonState.learned) return id;
  }
  return null;
}
