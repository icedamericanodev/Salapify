// Guards for money/lesson_flow.dart: what finishing a lesson completed, and
// what to read next.
//
// Every test here was proven to fail before it was trusted, per the house
// rule. The failure lines are in the commit message that introduced this
// file.

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/money/lesson_flow.dart';
import 'package:salapify/money/lesson_progress.dart';

// Two courses inside one sequence, the shape both readers pass: the core
// reader passes all 22 core lessons grouped by track, the expansion reader
// passes one path's lessons grouped by course.
const _sequence = <FlowLesson>[
  FlowLesson(
    id: 'a1',
    title: 'First of A',
    minutes: 2,
    groupId: 'a',
    groupTitle: 'Course A',
  ),
  FlowLesson(
    id: 'a2',
    title: 'Second of A',
    minutes: 3,
    groupId: 'a',
    groupTitle: 'Course A',
  ),
  FlowLesson(
    id: 'b1',
    title: 'First of B',
    minutes: 4,
    groupId: 'b',
    groupTitle: 'Course B',
  ),
];

Map<String, LessonState> _doneAll(List<String> ids) => {
  for (final id in ids) id: LessonState.completed,
};

void main() {
  group('finishOutcome next lesson', () {
    test('offers the following lesson in the same course', () {
      final out = finishOutcome(
        finishedId: 'a1',
        sequence: _sequence,
        progress: _doneAll(['a1']),
      );
      expect(out.next?.id, 'a2');
      expect(out.next?.minutes, 3);
      expect(out.nextStartsNewCourse, isFalse);
      expect(out.scope, FinishScope.lesson);
    });

    test('crossing into the next course is flagged, not hidden', () {
      final out = finishOutcome(
        finishedId: 'a2',
        sequence: _sequence,
        progress: _doneAll(['a1', 'a2']),
      );
      expect(out.next?.id, 'b1');
      expect(out.nextStartsNewCourse, isTrue);
    });

    test('sends a learner backwards to an earlier gap', () {
      // Finished the LAST lesson while an earlier one is still unread: the
      // fallback has to look before the finished lesson, not only after it.
      final out = finishOutcome(
        finishedId: 'b1',
        sequence: _sequence,
        progress: _doneAll(['a1', 'b1']),
      );
      expect(out.next?.id, 'a2');
    });

    test('never re-offers the finished lesson when the write never landed', () {
      // The one case that actually reaches the fallback guard, and it is
      // real: both readers skip recording progress when the store is read
      // only (see SalapifyStore.canWrite), so a lesson can be finished on
      // screen while `progress` still says notStarted.
      //
      // It has to be the LAST lesson with everything before it done. Any
      // earlier position and the forward scan finds a later unfinished
      // lesson first, so the fallback never runs and the guard is never
      // exercised. An earlier draft of this test used position one, passed
      // with the guard deleted, and proved nothing.
      final out = finishOutcome(
        finishedId: 'b1',
        sequence: _sequence,
        progress: _doneAll(['a1', 'a2']),
      );
      expect(out.next?.id, isNot('b1'));
      expect(out.next, isNull);
    });

    test('offers nothing once every lesson is done', () {
      final out = finishOutcome(
        finishedId: 'b1',
        sequence: _sequence,
        progress: _doneAll(['a1', 'a2', 'b1']),
      );
      expect(out.next, isNull);
    });

    test('an unknown id still points somewhere instead of crashing', () {
      final out = finishOutcome(
        finishedId: 'not-a-lesson',
        sequence: _sequence,
        progress: const {},
      );
      expect(out.next?.id, 'a1');
      expect(out.scope, FinishScope.lesson);
    });

    test(
      'applied counts as done, so an applied lesson is never re-offered',
      () {
        // applied is the TOP rung of LessonState, above completed. Treating it
        // as unfinished would send a learner who acted on a lesson straight
        // back into it.
        final out = finishOutcome(
          finishedId: 'a1',
          sequence: _sequence,
          progress: const {
            'a1': LessonState.completed,
            'a2': LessonState.applied,
          },
        );
        expect(out.next?.id, 'b1');
      },
    );

    test('a merely viewed lesson is still unfinished and gets offered', () {
      final out = finishOutcome(
        finishedId: 'a1',
        sequence: _sequence,
        progress: const {'a1': LessonState.completed, 'a2': LessonState.viewed},
      );
      expect(out.next?.id, 'a2');
    });
  });

  group('finishOutcome scope', () {
    test('finishing a course reports the course and names it', () {
      final out = finishOutcome(
        finishedId: 'a2',
        sequence: _sequence,
        progress: _doneAll(['a1', 'a2']),
      );
      expect(out.scope, FinishScope.course);
      expect(out.completedCourseTitle, 'Course A');
    });

    test('finishing everything reports the path, not the course', () {
      // The last lesson of the path also completes course B. One
      // celebration, the biggest one, never a stack of two.
      final out = finishOutcome(
        finishedId: 'b1',
        sequence: _sequence,
        progress: _doneAll(['a1', 'a2', 'b1']),
      );
      expect(out.scope, FinishScope.path);
      expect(out.completedCourseTitle, isNull);
    });

    test('a mid-course finish is only a lesson', () {
      final out = finishOutcome(
        finishedId: 'a1',
        sequence: _sequence,
        progress: _doneAll(['a1']),
      );
      expect(out.scope, FinishScope.lesson);
      expect(out.completedCourseTitle, isNull);
    });

    test('a course is not complete while an earlier lesson is unread', () {
      // Reading out of order must not fire a course celebration early.
      final out = finishOutcome(
        finishedId: 'a2',
        sequence: _sequence,
        progress: _doneAll(['a2']),
      );
      expect(out.scope, FinishScope.lesson);
      expect(out.completedCourseTitle, isNull);
    });
  });

  group('finishOutcome counts', () {
    test('counts across the whole sequence, not the course', () {
      final out = finishOutcome(
        finishedId: 'a2',
        sequence: _sequence,
        progress: _doneAll(['a1', 'a2']),
      );
      expect(out.done, 2);
      expect(out.total, 3);
    });

    test('course counts cover only the finished lesson own course', () {
      // The motivating figure: 2 of 2 in Course A, not 2 of 3 overall.
      final out = finishOutcome(
        finishedId: 'a2',
        sequence: _sequence,
        progress: _doneAll(['a1', 'a2']),
      );
      expect(out.doneInCourse, 2);
      expect(out.totalInCourse, 2);
    });

    test('course counts ignore progress in a sibling course', () {
      // b1 being done must not inflate Course A's figure.
      final out = finishOutcome(
        finishedId: 'a1',
        sequence: _sequence,
        progress: _doneAll(['a1', 'b1']),
      );
      expect(out.doneInCourse, 1);
      expect(out.totalInCourse, 2);
    });

    test('an empty sequence is safe and never reports a finished path', () {
      final out = finishOutcome(
        finishedId: 'a1',
        sequence: const [],
        progress: const {},
      );
      expect(out.total, 0);
      expect(out.next, isNull);
      expect(out.scope, FinishScope.lesson);
    });
  });
}
