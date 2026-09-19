// Guards for money/course_funnel.dart.
//
// The figure that matters here is drop-off, so the tests that matter are
// the ones proving a started-but-unfinished lesson is counted as started and
// NOT as done. A funnel that quietly reports everything as finished is worse
// than no funnel, because it would be used to decide the next phase.

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/money/course_funnel.dart';
import 'package:salapify/money/lesson_progress.dart';

const _ids = ['a', 'b', 'c', 'd', 'e'];

FunnelRow _row(Map<String, LessonState> progress) =>
    funnelFor(label: 'T', lessonIds: _ids, progress: progress);

void main() {
  test('an untouched course is all zeros, never a false completion', () {
    final r = _row(const {});
    expect(r.total, 5);
    expect(r.started, 0);
    expect(r.done, 0);
    expect(r.applied, 0);
    expect(r.droppedOff, 0);
  });

  test('opening counts as started but never as done', () {
    // The drop-off figure exists for exactly this case.
    final r = _row(const {'a': LessonState.viewed, 'b': LessonState.viewed});
    expect(r.started, 2);
    expect(r.understood, 0);
    expect(r.done, 0);
    expect(r.droppedOff, 2);
  });

  test('the counts are cumulative down the funnel', () {
    // An applied lesson is also done, also understood, also started.
    final r = _row(const {'a': LessonState.applied});
    expect(r.started, 1);
    expect(r.understood, 1);
    expect(r.done, 1);
    expect(r.applied, 1);
    expect(r.droppedOff, 0);
  });

  test('completed counts as done but not as applied', () {
    final r = _row(const {'a': LessonState.completed});
    expect(r.done, 1);
    expect(
      r.applied,
      0,
      reason: 'applied means the lesson was acted on, not merely finished',
    );
  });

  test('understood is progress but not completion', () {
    final r = _row(const {'a': LessonState.understood});
    expect(r.started, 1);
    expect(r.understood, 1);
    expect(r.done, 0);
    expect(r.droppedOff, 1);
  });

  test('an id with no progress entry is simply not started', () {
    final r = _row(const {'zzz-not-in-this-course': LessonState.applied});
    expect(r.started, 0, reason: 'another course must not inflate this one');
  });

  test('a mixed course reads honestly', () {
    final r = _row(const {
      'a': LessonState.applied,
      'b': LessonState.completed,
      'c': LessonState.understood,
      'd': LessonState.viewed,
    });
    expect(r.total, 5);
    expect(r.started, 4);
    expect(r.understood, 3);
    expect(r.done, 2);
    expect(r.applied, 1);
    expect(r.droppedOff, 2);
    expect(r.summary, '4 started, 2 done, 1 used in app, of 5');
  });

  test('totals add every row up', () {
    final rows = [
      _row(const {'a': LessonState.completed}),
      _row(const {'a': LessonState.viewed, 'b': LessonState.applied}),
    ];
    final t = totalFunnel(rows);
    expect(t.total, 10);
    expect(t.started, 3);
    expect(t.done, 2);
    expect(t.applied, 1);
  });
}
