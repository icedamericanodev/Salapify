// Financial Guides progress: how far a reader got through one short guide.
//
// Guides are the browsable explainers behind the Financial Guides hub. Unlike
// the Money Courses lessons, a guide is short prose with no knowledge check and
// no in-app action, so its progress is a single fraction from 0 to 1 rather
// than the five ranked LessonState rungs (money/lesson_progress.dart). The
// reader raises the fraction as it scrolls, and reaching the end (or tapping
// the finish control) sets it to 1.
//
// This lives in settings.guideProgress, a namespace entirely separate from
// settings.lessonProgress, settings.lessonsRead, and settings.expansionProgress.
// Reading a guide can never move a lesson's progress or the "X of 22" figure,
// and the reverse is just as true. The key is preserved by the backup like any
// other settings field, so no migration is needed.

/// A guide's progress can only ever climb. Rereading a finished guide, or
/// scrolling back up, must never lower what was already reached. So a write
/// takes the MAXIMUM of the stored value and the new one, the same
/// never-go-backwards rule the lesson progress model follows.
const double _minTracked = 0.0;
const double _full = 1.0;

/// A guide counts as read once the reader has reached the end. A tiny slack
/// below 1.0 covers the last pixel of a long scroll that never quite lands on
/// the exact maximum extent, so a reader who scrolled all the way is not left
/// one hair short of done forever.
bool isGuideRead(double fraction) => fraction >= 0.985;

/// A guide counts as meaningfully started only past this much of its length.
/// Below it, a stray flick or an accidental pixel of scroll is not reading, so
/// it never becomes a Continue Learning row that reads "0% read". This is the
/// guide equivalent of the lesson model's rule that merely opening a lesson is
/// not progress.
const double kGuideStartedThreshold = 0.05;

/// True while a guide has been meaningfully started but is not yet read:
/// exactly the set the Continue Learning row shows.
bool isGuideInProgress(double fraction) =>
    fraction >= kGuideStartedThreshold && !isGuideRead(fraction);

/// Clamp a would-be fraction into the tracked range, junk-safe. A NaN or a
/// value outside 0..1 (a corrupt backup, a bad computation) collapses to a
/// safe bound rather than poisoning the map.
double clampGuideFraction(num? value) {
  if (value == null) return _minTracked;
  final d = value.toDouble();
  if (d.isNaN) return _minTracked;
  if (d <= _minTracked) return _minTracked;
  if (d >= _full) return _full;
  return d;
}

/// Read the per-guide progress out of settings, junk-safe.
///
/// Shape: `settings.guideProgress = { '<guideId>': 0.6 }`. A stored value may
/// also arrive as `{ 'p': 0.6 }` from a defensive future writer; both are read,
/// and anything unreadable is skipped rather than thrown on, matching the rest
/// of the store's defensive reads. Entries at 0 are dropped so the map only
/// ever holds guides that were genuinely touched.
Map<String, double> parseGuideProgress(dynamic stored) {
  final out = <String, double>{};
  if (stored is Map) {
    for (final entry in stored.entries) {
      final id = entry.key;
      if (id is! String || id.isEmpty) continue;
      final raw = entry.value;
      final num? n = raw is num
          ? raw
          : (raw is Map && raw['p'] is num ? raw['p'] as num : null);
      if (n == null) continue;
      final f = clampGuideFraction(n);
      if (f > _minTracked) out[id] = f;
    }
  }
  return out;
}

/// Fold one progress change into the existing map and return the new stored
/// form. Progress never goes backwards: the higher of the stored value and the
/// new one wins, so scrolling back up, or reopening a finished guide, cannot
/// lower it. A resulting 0 is omitted rather than stored.
Map<String, dynamic> withGuideProgress(
  dynamic stored,
  String id,
  double fraction,
) {
  final current = parseGuideProgress(stored);
  final next = clampGuideFraction(fraction);
  final existing = current[id] ?? _minTracked;
  final kept = next > existing ? next : existing;
  final out = <String, dynamic>{
    for (final e in current.entries) e.key: e.value,
  };
  if (kept > _minTracked) {
    out[id] = kept;
  } else {
    out.remove(id);
  }
  return out;
}
