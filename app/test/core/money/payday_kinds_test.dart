import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/money.dart';
import 'package:salapify/core/money/payday_schedule.dart';
import 'package:salapify/data/json_codec.dart';
import 'package:salapify/models/models.dart';

/// Weekly, every-two-weeks and no-fixed-payday rules (D37, 2026-10-12).
///
/// Dates are chosen by weekday on purpose: 2026-10-12 is a Monday, 2026-10-16
/// a Friday.
void main() {
  final DateTime monday = DateTime(2026, 10, 12, 9);
  final DateTime friday = DateTime(2026, 10, 16, 9);

  group('every week', () {
    final PaydaySchedule fridays = PaydaySchedule.weekly(DateTime.friday);

    test('from a Monday, payday is Friday, four days away, and the last one '
        'was the Friday before', () {
      final PaydayPoints p = fridays.pointsFrom(monday)!;
      expect(p.next, DateTime(2026, 10, 16));
      expect(p.last, DateTime(2026, 10, 9));
      expect(p.daysToNext, 4);
      expect(p.cycleDays, 7);
    });

    test('ON payday the countdown is a full week, never zero', () {
      final PaydayPoints p = fridays.pointsFrom(friday)!;
      expect(p.last, DateTime(2026, 10, 16));
      expect(p.daysToNext, 7);
    });

    test('a weekday outside 1 to 7 is unusable, not a throw', () {
      expect(PaydaySchedule.weekly(0).isUsable, isFalse);
      expect(PaydaySchedule.weekly(8).pointsFrom(monday), isNull);
    });
  });

  group('every two weeks', () {
    test('counted from a past payday', () {
      final PaydayPoints p = PaydaySchedule.everyTwoWeeks(
        DateTime(2026, 10, 2),
      ).pointsFrom(monday)!;
      expect(p.last, DateTime(2026, 10, 2));
      expect(p.next, DateTime(2026, 10, 16));
      expect(p.daysToNext, 4);
      expect(p.cycleDays, 14);
    });

    test('an anchor in the future still finds the payday before today', () {
      final PaydayPoints p = PaydaySchedule.everyTwoWeeks(
        DateTime(2026, 10, 30),
      ).pointsFrom(monday)!;
      expect(p.last, DateTime(2026, 10, 2));
      expect(p.next, DateTime(2026, 10, 16));
    });

    test('across a month end and a year end', () {
      final PaydayPoints p = PaydaySchedule.everyTwoWeeks(
        DateTime(2026, 12, 25),
      ).pointsFrom(DateTime(2027, 1, 3))!;
      expect(p.next, DateTime(2027, 1, 8));
      expect(p.daysToNext, 5);
    });
  });

  group('no fixed payday', () {
    test('divides by the days left until the date', () {
      final PaydayPoints p = PaydaySchedule.lastUntil(
        DateTime(2026, 10, 20),
      ).pointsFrom(monday)!;
      expect(p.daysToNext, 8);
      expect(p.next, DateTime(2026, 10, 20));
    });

    test('on or after the date there is no countdown at all', () {
      final PaydaySchedule s = PaydaySchedule.lastUntil(DateTime(2026, 10, 12));
      expect(s.pointsFrom(monday), isNull, reason: 'the date is today');
      expect(s.pointsFrom(friday), isNull, reason: 'the date has passed');
      expect(s.repeats, isFalse);
    });
  });

  test('paydays per month and the bill window floor', () {
    expect(PaydaySchedule(<int>[15, 30]).paydaysPerMonth, 2);
    expect(PaydaySchedule(<int>[25]).paydaysPerMonth, 1);
    expect(PaydaySchedule.weekly(5).paydaysPerMonth, closeTo(4.333, 0.001));
    expect(
      PaydaySchedule.everyTwoWeeks(DateTime(2026, 10, 2)).paydaysPerMonth,
      closeTo(2.167, 0.001),
    );
    expect(
      PaydaySchedule.lastUntil(DateTime(2026, 10, 20)).paydaysPerMonth,
      isNull,
    );
    expect(PaydaySchedule.weekly(5).billWindowFloor, 30);
    expect(
      PaydaySchedule.everyTwoWeeks(DateTime(2026, 10, 2)).billWindowFloor,
      30,
    );
    expect(PaydaySchedule(<int>[15, 30]).billWindowFloor, 0);
    // D37.5: no income is promised on a last-until date.
    expect(
      PaydaySchedule.lastUntil(DateTime(2026, 10, 20)).billWindowFloor,
      30,
    );
  });

  group('stored and read back', () {
    PaydayCycle cycle({
      List<int> days = const <int>[],
      int? weekday,
      String? anchor,
      String? until,
    }) => PaydayCycle(
      cycleType: 'x',
      lastPayday: '',
      nextPayday: '',
      daysToPayday: 0,
      expectedIncome: Money.zero,
      paydayDays: days,
      paydayWeekday: weekday,
      paydayAnchor: anchor,
      lastUntil: until,
    );

    test('each kind survives a backup round trip and reads as its kind', () {
      for (final (PaydayCycle c, PaydayKind kind)
          in <(PaydayCycle, PaydayKind)>[
            (cycle(days: <int>[10, 25]), PaydayKind.daysOfMonth),
            (cycle(weekday: 5), PaydayKind.weekly),
            (cycle(anchor: '2026-10-02'), PaydayKind.everyTwoWeeks),
            (cycle(until: '2026-10-20'), PaydayKind.lastUntil),
          ]) {
        final PaydayCycle back = paydayFromJson(paydayToJson(c));
        expect(back.paydayWeekday, c.paydayWeekday);
        expect(back.paydayAnchor, c.paydayAnchor);
        expect(back.lastUntil, c.lastUntil);
        expect(PaydaySchedule.fromCycle(back)!.kind, kind);
      }
    });

    test('a twice-a-month backup writes none of the new keys', () {
      final Map<String, dynamic> json = paydayToJson(
        cycle(days: <int>[15, 30]),
      );
      expect(json.containsKey('paydayWeekday'), isFalse);
      expect(json.containsKey('paydayAnchor'), isFalse);
      expect(json.containsKey('lastUntil'), isFalse);
    });

    test('nonsense in a backup reads as "not set", never a throw', () {
      final PaydayCycle c = paydayFromJson(<String, dynamic>{
        'paydayWeekday': 9,
        'paydayAnchor': '2026-02-30',
        'lastUntil': 'next week',
      });
      expect(c.paydayWeekday, isNull);
      expect(c.paydayAnchor, isNull);
      expect(c.lastUntil, isNull);
      expect(PaydaySchedule.fromCycle(c), isNull);
    });
  });
}
