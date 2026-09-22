// The catalog's thinking: track progress, and which course to recommend.
//
// The recommendation is shown to the user with a reason attached, so the
// reason has to be true and it has to be safe. Two things are pinned here:
// no recommendation ever quotes an amount, and the ordering puts the thing
// with a deadline ahead of the thing without one.

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/money/course_plan.dart';
import 'package:salapify/money/lesson_progress.dart';

final _now = DateTime(2026, 7, 25);

Map<String, dynamic> _income(String date, num amount) => {
  'id': 'i$date$amount',
  'type': 'income',
  'amount': amount,
  'date': date,
};

void main() {
  group('trackProgress', () {
    const ids = ['a', 'b', 'c'];
    const minutes = {'a': 2, 'b': 3, 'c': 4};

    TrackProgress of(Map<String, LessonState> p) => trackProgress(
      trackId: 't',
      lessonIds: ids,
      minutesById: minutes,
      progress: p,
    );

    test('an untouched track offers Start at its first lesson', () {
      final t = of({});
      expect(t.done, 0);
      expect(t.status, 'Not started');
      expect(t.actionLabel, 'Start');
      expect(t.nextLessonId, 'a');
      expect(t.minutesLeft, 9);
      expect(t.fraction, 0);
    });

    test('a part-done track continues at the first UNFINISHED lesson', () {
      final t = of({'a': LessonState.completed, 'b': LessonState.viewed});
      expect(t.done, 1);
      expect(t.status, 'In progress');
      expect(t.actionLabel, 'Continue');
      expect(
        t.nextLessonId,
        'b',
        reason: 'a lesson opened but not finished is still unfinished',
      );
      expect(t.minutesLeft, 7, reason: 'only unfinished lessons count');
    });

    test('a finished track says so and offers a reread', () {
      final t = of({
        'a': LessonState.completed,
        'b': LessonState.completed,
        'c': LessonState.applied,
      });
      expect(t.isComplete, isTrue);
      expect(t.status, 'Completed');
      expect(t.actionLabel, 'Read again');
      expect(t.nextLessonId, isNull);
      expect(t.minutesLeft, 0);
    });

    test('an empty track never divides by zero', () {
      final t = trackProgress(
        trackId: 't',
        lessonIds: const [],
        minutesById: const {},
        progress: const {},
      );
      expect(t.fraction, 0);
      expect(t.isComplete, isFalse);
    });
  });

  group('recommendedTrack', () {
    test('a new or empty store is pointed at the starting track', () {
      final r = recommendedTrack(const {}, _now);
      expect(r.trackId, 'cushion');
      expect(r.reason, isNotEmpty);
    });

    test('junk never throws and still returns a usable recommendation', () {
      for (final junk in [
        null,
        'nope',
        7,
        {'debts': 'not a list'},
      ]) {
        final r = recommendedTrack(junk, _now);
        expect(r.trackId, isNotEmpty);
        expect(r.reason, isNotEmpty);
      }
    });

    test('active debt wins, because it costs money every month', () {
      final r = recommendedTrack({
        'debts': [
          {'id': 'd', 'remaining': 4000},
        ],
      }, _now);
      expect(r.trackId, 'debt');
    });

    test('a settled debt does not count', () {
      final r = recommendedTrack({
        'debts': [
          {'id': 'd', 'remaining': 0},
        ],
      }, _now);
      expect(r.trackId, 'cushion');
    });

    test('a recent unusually large payment beats the swing track', () {
      // Four ordinary payments then one at more than twice the median, inside
      // the window. The lump sum decision has a deadline; learning to smooth
      // income does not.
      final r = recommendedTrack({
        'transactions': [
          _income('2026-07-01', 5000),
          _income('2026-07-05', 5000),
          _income('2026-07-09', 5000),
          _income('2026-07-14', 5000),
          _income('2026-07-20', 30000),
        ],
      }, _now);
      expect(r.trackId, 'moments');
    });

    test('several separate payments suggest the swing track', () {
      final r = recommendedTrack({
        'transactions': [
          _income('2026-07-01', 5000),
          _income('2026-07-06', 4800),
          _income('2026-07-12', 5200),
          _income('2026-07-18', 5100),
        ],
      }, _now);
      expect(r.trackId, 'swing');
    });

    test('one salary a month is not mistaken for swing income', () {
      final r = recommendedTrack({
        'transactions': [
          _income('2026-06-30', 20000),
          _income('2026-07-15', 20000),
        ],
      }, _now);
      expect(r.trackId, 'cushion');
    });

    test('no reason ever quotes an amount', () {
      // These lines sit on a screen someone else might glance at. Knowing a
      // debt exists is enough to pick a track; the balance is not needed and
      // must not leak onto a course card.
      final cases = <dynamic>[
        const {},
        {
          'debts': [
            {'id': 'd', 'remaining': 123456},
          ],
        },
        {
          'transactions': [
            _income('2026-07-01', 5000),
            _income('2026-07-06', 4800),
            _income('2026-07-12', 5200),
            _income('2026-07-18', 99999),
          ],
        },
      ];
      for (final data in cases) {
        final reason = recommendedTrack(data, _now).reason;
        expect(
          RegExp(r'\d').hasMatch(reason),
          isFalse,
          reason: 'a digit leaked into: $reason',
        );
        expect(reason.contains('₱'), isFalse);
      }
    });
  });
}
