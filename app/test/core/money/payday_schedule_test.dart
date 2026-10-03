import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/payday_schedule.dart';

/// The date arithmetic behind the payday countdown.
///
/// Every case here is one that silently produced a wrong DIVISOR, because
/// `daysToPayday` divides the Safe to Spend figure on Home. An off-by-three
/// in February is not a calendar curiosity, it is a daily allowance that is
/// wrong by a fifth.
void main() {
  PaydayPoints points(List<int> days, DateTime now) =>
      PaydaySchedule(days).pointsFrom(now)!;

  group('the ordinary semi-monthly cycle', () {
    test('mid-month points at the 15th', () {
      final PaydayPoints p = points(<int>[15, 30], DateTime(2026, 9, 11));
      expect(p.next, DateTime(2026, 9, 15));
      expect(p.last, DateTime(2026, 8, 30));
      expect(p.daysToNext, 4);
    });

    test('after the 15th points at the 30th', () {
      final PaydayPoints p = points(<int>[15, 30], DateTime(2026, 9, 20));
      expect(p.next, DateTime(2026, 9, 30));
      expect(p.last, DateTime(2026, 9, 15));
      expect(p.daysToNext, 10);
    });

    test('the founder\'s other example, the 10th and the 25th', () {
      // "give them options since it differs per company. Sometime 15th and
      // 30th, sometimes 10th and 25th". A rule hardcoded to 15 and 30 would
      // be wrong by five days for everybody on this one.
      final PaydayPoints p = points(<int>[10, 25], DateTime(2026, 9, 20));
      expect(p.next, DateTime(2026, 9, 25));
      expect(p.last, DateTime(2026, 9, 10));
      expect(p.daysToNext, 5);
    });
  });

  group('the month boundary', () {
    test('before the first payday of the month looks back a month', () {
      final PaydayPoints p = points(<int>[15, 30], DateTime(2026, 9, 3));
      expect(p.last, DateTime(2026, 8, 30));
      expect(p.next, DateTime(2026, 9, 15));
      expect(p.daysToNext, 12);
    });

    test('on the last payday of the month looks forward a month', () {
      final PaydayPoints p = points(<int>[15, 30], DateTime(2026, 9, 30));
      expect(p.last, DateTime(2026, 9, 30));
      expect(p.next, DateTime(2026, 10, 15));
      expect(p.daysToNext, 15);
    });

    test('December rolls into January of the next year', () {
      final PaydayPoints p = points(<int>[15, 30], DateTime(2026, 12, 30));
      expect(
        p.next,
        DateTime(2027, 1, 15),
        reason: 'the year did not advance, so the countdown went negative',
      );
      expect(p.daysToNext, 16);
    });

    test('January looks back into December of the previous year', () {
      final PaydayPoints p = points(<int>[15, 30], DateTime(2027, 1, 4));
      expect(p.last, DateTime(2026, 12, 30));
      expect(p.next, DateTime(2027, 1, 15));
    });
  });

  group('short months, where the naive version is silently wrong', () {
    test('the 30th in February is the 28th, not the 2nd of March', () {
      // DateTime(2026, 2, 30) does not throw and is not 30 February. It is
      // 2 March. Somebody paid at the end of the month would have had their
      // February payday land in the wrong month every single year.
      final PaydayPoints p = points(<int>[15, 30], DateTime(2026, 2, 20));
      expect(p.next, DateTime(2026, 2, 28));
      expect(p.daysToNext, 8);
    });

    test('a leap February gets the 29th', () {
      final PaydayPoints p = points(<int>[15, 30], DateTime(2028, 2, 20));
      expect(p.next, DateTime(2028, 2, 29));
      expect(p.daysToNext, 9);
    });

    test('the 31st in a 30 day month is the 30th', () {
      final PaydayPoints p = points(<int>[31], DateTime(2026, 4, 10));
      expect(p.next, DateTime(2026, 4, 30));
    });

    test('two days that collide in February do not double up', () {
      // Paid on the 29th and the 30th is unusual, but clamping both to the
      // 28th in a common year must not produce the same date twice, or the
      // month has a payday that the ordering logic sees as two.
      final PaydayPoints p = points(<int>[29, 30], DateTime(2026, 2, 10));
      expect(p.next, DateTime(2026, 2, 28));
      expect(p.last, DateTime(2026, 1, 30));
    });
  });

  group('payday itself', () {
    test('on payday the countdown points at the NEXT one, never zero', () {
      // Not cosmetic. PaydayCycle.isSet is `daysToPayday > 0`, so a zero
      // here would make an app with a perfectly good payday rule announce
      // "Payday not set" on the one day the person is most likely to look.
      final PaydayPoints p = points(<int>[15, 30], DateTime(2026, 9, 15));
      expect(p.last, DateTime(2026, 9, 15));
      expect(p.next, DateTime(2026, 9, 30));
      expect(p.daysToNext, 15);
    });

    test('the countdown is never zero on any day of a whole year', () {
      // The sweep, rather than three hand picked dates. A single day of the
      // year where this returns zero is a day the app claims no payday is
      // set, and hand picked cases are exactly how such a day survives.
      final PaydaySchedule s = PaydaySchedule(<int>[15, 30]);
      for (
        DateTime d = DateTime(2026, 1, 1);
        d.isBefore(DateTime(2027, 1, 1));
        d = d.add(const Duration(days: 1))
      ) {
        final PaydayPoints p = s.pointsFrom(d)!;
        expect(
          p.daysToNext,
          greaterThan(0),
          reason: 'the countdown hit zero on ${d.toIso8601String()}',
        );
        expect(
          p.next.isAfter(DateTime(d.year, d.month, d.day)),
          isTrue,
          reason: 'the next payday was not in the future on $d',
        );
        expect(
          p.last.isAfter(p.next),
          isFalse,
          reason: 'the last payday came after the next one on $d',
        );
      }
    });

    test('a time of day on the clock does not move the count', () {
      // state.now carries a time. Without normalising to the date, an
      // afternoon reading would be a fraction shorter and `inDays` would
      // truncate it to one day less.
      final PaydayPoints morning = points(<int>[
        15,
        30,
      ], DateTime(2026, 9, 11, 1, 5));
      final PaydayPoints evening = points(<int>[
        15,
        30,
      ], DateTime(2026, 9, 11, 23, 55));
      expect(morning.daysToNext, evening.daysToNext);
      expect(morning.daysToNext, 4);
    });
  });

  group('rubbish in the stored rule', () {
    test('an empty rule is unusable rather than a crash', () {
      expect(PaydaySchedule(<int>[]).isUsable, isFalse);
      expect(PaydaySchedule(<int>[]).pointsFrom(DateTime(2026, 9, 11)), isNull);
    });

    test('out of range days are dropped, never thrown', () {
      // This is built from a backup file as well as from a picker. A throw
      // makes the whole ledger unreadable, which is a far worse outcome than
      // a payday rule that ignores a nonsense entry.
      expect(PaydaySchedule(<int>[0, 45, -3, 15]).daysOfMonth, <int>[15]);
      expect(PaydaySchedule(<int>[0, 45]).isUsable, isFalse);
    });

    test('the days come back sorted and de-duplicated', () {
      expect(PaydaySchedule(<int>[30, 15, 30]).daysOfMonth, <int>[15, 30]);
    });
  });

  group('the label', () {
    test('is the display format the stored cycle already used', () {
      // NOT an ISO date. These strings are printed straight onto three
      // screens and screen_readability_test.dart fails a build that shows a
      // stored date raw.
      expect(formatPaydayLabel(DateTime(2026, 9, 15)), 'Sep 15');
      expect(formatPaydayLabel(DateTime(2026, 1, 1)), 'Jan 1');
      expect(formatPaydayLabel(DateTime(2026, 12, 31)), 'Dec 31');
    });
  });
}
