// How far people actually get through a course, counted on the device.
//
// The experience audit's flattest statement was that completion is currently
// a feeling rather than a number: the app is offline with no analytics
// backend, so nobody can say whether a course is finished or abandoned. But
// the data has been on every phone the whole time. The store already records
// five states per lesson (notStarted, viewed, understood, completed,
// applied) and no screen has ever shown the distribution.
//
// This folds that into counts a founder can screenshot, so the phases after
// this one are decided on evidence instead of taste. It is pure arithmetic
// over ids and states, with no content import and no Flutter import, so the
// caller decides which lessons make up a row and this file never has an
// opinion about the catalog.
//
// Counts only, deliberately. No lesson is named, no date is recorded, and
// nothing here reads a transaction, an account, or a peso. The diagnostics
// screen this feeds is guarded by a privacy test that fails if store
// contents ever reach it (test/diagnostics_screen_test.dart), and a funnel
// made of counts cannot violate it.

import 'lesson_progress.dart';

/// One row of the funnel: a track or a path, and how far its lessons got.
///
/// The counts are CUMULATIVE down the funnel, which is what makes it read as
/// a funnel rather than five unrelated tallies: a lesson someone applied is
/// also counted as done, understood, and started. Reporting them as disjoint
/// buckets would make a healthy course look like five broken ones.
class FunnelRow {
  final String label;
  final int total;

  /// Opened at all.
  final int started;

  /// Engaged with the thinking, by revealing a discovery answer or
  /// answering the check.
  final int understood;

  /// Reached the end. This is the completion figure.
  final int done;

  /// Took the lesson's action into the app, the top rung.
  final int applied;

  const FunnelRow({
    required this.label,
    required this.total,
    required this.started,
    required this.understood,
    required this.done,
    required this.applied,
  });

  /// Started but never finished: the abandonment figure, and the whole
  /// reason this exists.
  int get droppedOff => started - done;

  /// A compact, screenshot-friendly line. Kept here rather than in the
  /// widget so the wording is testable and cannot drift between surfaces.
  String get summary =>
      '$started started, $done done, $applied used in app, of $total';
}

/// Fold one group of lessons into a row.
FunnelRow funnelFor({
  required String label,
  required List<String> lessonIds,
  required Map<String, LessonState> progress,
}) {
  var started = 0;
  var understood = 0;
  var done = 0;
  var applied = 0;
  for (final id in lessonIds) {
    final s = progress[id] ?? LessonState.notStarted;
    if (s == LessonState.notStarted) continue;
    started++;
    if (s == LessonState.understood ||
        s == LessonState.completed ||
        s == LessonState.applied) {
      understood++;
    }
    if (isDone(s)) done++;
    if (s == LessonState.applied) applied++;
  }
  return FunnelRow(
    label: label,
    total: lessonIds.length,
    started: started,
    understood: understood,
    done: done,
    applied: applied,
  );
}

/// The whole catalog's totals, for one line at the top of the section.
FunnelRow totalFunnel(List<FunnelRow> rows) => FunnelRow(
  label: 'All courses',
  total: rows.fold<int>(0, (a, r) => a + r.total),
  started: rows.fold<int>(0, (a, r) => a + r.started),
  understood: rows.fold<int>(0, (a, r) => a + r.understood),
  done: rows.fold<int>(0, (a, r) => a + r.done),
  applied: rows.fold<int>(0, (a, r) => a + r.applied),
);
