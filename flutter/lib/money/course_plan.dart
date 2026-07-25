// The course catalog's thinking: how far each track has got, and which one to
// suggest starting.
//
// Kept pure and out of the screen so both can be tested without pumping a
// widget, and so the recommendation is a single place to reason about rather
// than a condition buried in a build method.
//
// The recommendation rule that matters most: it must be EXPLAINABLE. A
// suggestion the user cannot see the reason for is just the app being bossy,
// so every recommendation carries the sentence that justifies it, and that
// sentence never quotes a balance or an amount. Knowing you have debt is
// enough to pick a track; putting the figure on a course card is not needed
// and would leak a number onto a screen someone else might be looking at.

import 'lesson_progress.dart';

class TrackProgress {
  final String trackId;
  final int total;
  final int done;

  /// Reading minutes left across the unfinished lessons.
  final int minutesLeft;

  /// The lesson to open when the user taps Start or Continue, or null when
  /// the track is finished.
  final String? nextLessonId;

  const TrackProgress({
    required this.trackId,
    required this.total,
    required this.done,
    required this.minutesLeft,
    required this.nextLessonId,
  });

  bool get isComplete => total > 0 && done >= total;
  bool get isStarted => done > 0;

  /// 0..1, and never NaN on an empty track.
  double get fraction => total == 0 ? 0 : done / total;

  String get status => isComplete
      ? 'Completed'
      : isStarted
      ? 'In progress'
      : 'Not started';

  /// Start for an untouched track, Continue once there is progress.
  String get actionLabel => isComplete
      ? 'Read again'
      : isStarted
      ? 'Continue'
      : 'Start';
}

/// Fold one track's lessons against the stored progress.
///
/// [lessonIds] and [minutesById] come from the content so this file never
/// imports the lesson list, which keeps it testable with tiny fixtures.
TrackProgress trackProgress({
  required String trackId,
  required List<String> lessonIds,
  required Map<String, int> minutesById,
  required Map<String, LessonState> progress,
}) {
  var done = 0;
  var minutesLeft = 0;
  String? next;
  for (final id in lessonIds) {
    final state = progress[id] ?? LessonState.notStarted;
    if (isDone(state)) {
      done++;
    } else {
      next ??= id;
      minutesLeft += minutesById[id] ?? 0;
    }
  }
  return TrackProgress(
    trackId: trackId,
    total: lessonIds.length,
    done: done,
    minutesLeft: minutesLeft,
    nextLessonId: next,
  );
}

class CourseRecommendation {
  final String trackId;

  /// Shown to the user, always. A recommendation without a visible reason is
  /// the app being bossy.
  final String reason;

  const CourseRecommendation(this.trackId, this.reason);
}

num _amount(dynamic v) {
  if (v is num) return v.isFinite ? v : 0;
  if (v is String) {
    return double.tryParse(v.replaceAll(RegExp(r'[, ]'), '')) ?? 0;
  }
  return 0;
}

List<Map> _rows(dynamic raw) => [
  for (final x in (raw is List ? raw : const []))
    if (x is Map) x,
];

/// Which track to suggest, and why.
///
/// Ordered by urgency rather than by curriculum order: expensive debt beats
/// everything, then a recent lump sum (because that decision has a deadline
/// the others do not), then irregular income, then the default starting
/// track. Nothing is ever LOCKED by this; it only decides what gets a
/// "recommended" mark.
CourseRecommendation recommendedTrack(dynamic data, DateTime now) {
  final d = data is Map ? data : const {};

  final hasDebt = _rows(d['debts']).any((x) => _amount(x['remaining']) > 0);
  if (hasDebt) {
    return const CourseRecommendation(
      'debt',
      'Recommended because you have a debt still being paid down.',
    );
  }

  // A lump sum in the last 30 days: the decision about it is live right now,
  // which no other track can say.
  final cutoff = DateTime(now.year, now.month, now.day - 30);
  var recentBig = false;
  var incomeCount = 0;
  final amounts = <num>[];
  for (final t in _rows(d['transactions'])) {
    if (t['type'] != 'income') continue;
    final s = (t['date'] ?? '').toString();
    if (s.length < 10) continue;
    final p = s.substring(0, 10).split('-');
    if (p.length != 3) continue;
    final y = int.tryParse(p[0]);
    final m = int.tryParse(p[1]);
    final day = int.tryParse(p[2]);
    if (y == null || m == null || day == null) continue;
    final when = DateTime(y, m, day);
    if (when.year != y || when.month != m || when.day != day) continue;
    incomeCount++;
    final amt = _amount(t['amount']);
    amounts.add(amt);
    // "Big" is relative to this person, never an absolute peso figure: twice
    // their own median income entry, with enough entries to have a median.
    if (!when.isBefore(cutoff)) {
      final sorted = [...amounts]..sort();
      final median = sorted.isEmpty ? 0 : sorted[sorted.length ~/ 2];
      if (sorted.length >= 4 && median > 0 && amt >= median * 2) {
        recentBig = true;
      }
    }
  }
  if (recentBig) {
    return const CourseRecommendation(
      'moments',
      'Recommended because a larger than usual payment landed recently.',
    );
  }

  if (incomeCount >= 4) {
    // Irregular means the gaps between income entries vary a lot. Counting
    // entries alone would flag a normal salaried month.
    return const CourseRecommendation(
      'swing',
      'Recommended because your income arrives in several separate payments.',
    );
  }

  return const CourseRecommendation(
    'cushion',
    'Recommended as the place to start.',
  );
}
