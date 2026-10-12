/// When the next payday falls, worked out fresh every time it is asked.
///
/// This file exists because `PaydayCycle` stores a COUNTDOWN, and a stored
/// countdown is wrong the day after it is written. `json_codec.dart` already
/// says so in its own comment: the cycle "said 4 days to payday, Sep 15 on a
/// ledger with nothing in it, and it would have said the same in December,
/// because nothing ever recomputed or stored it".
///
/// So the person records the RULE, which does not go stale, and the countdown
/// is derived from the rule and today. Founder direction, 2026-09-20, on
/// which rules to support: "give them options since it differs per company.
/// Sometime 15th and 30th, sometimes 10th and 25th". The days are therefore
/// the person's to choose, never fixed at 15 and 30.
///
/// Nothing here touches the money engine. `computeSafeToSpend` still divides
/// by whatever `daysToPayday` it is handed, and its golden vectors still pass
/// the cycle in directly. The derivation happens above the engine, where the
/// app reads the stored cycle, so the arithmetic that was locked stays
/// locked.
library;

import '../../models/models.dart';

/// The four shapes a payday rule can take (D37, 2026-10-12).
enum PaydayKind {
  /// Days of the month: twice a month (the 15th and 30th, the 10th and
  /// 25th) or once a month.
  daysOfMonth,

  /// The same weekday every week, "every Friday".
  weekly,

  /// Every fourteen days, counted from a payday the person names. Stored as
  /// that DATE, never as a countdown, for the reason this file opens with.
  everyTwoWeeks,

  /// No fixed payday. The person picks the date the money has to last
  /// until (a payout, a padala), and it does not repeat: once it passes, the
  /// app asks again rather than guessing the next one.
  lastUntil,
}

/// A payday rule. Which days the money lands on, or for somebody with no
/// fixed payday, the day it has to last until.
///
/// One day of the month means paid once a month. Two means the usual
/// Philippine semi-monthly sweldo. Weekly, every two weeks and "last until"
/// were added by D37 for earners the first version could not describe at
/// all: a weekly wage, a two-weekly payroll, and the freelancers, riders,
/// sellers and remittance households with no payday of their own.
class PaydaySchedule {
  PaydaySchedule(Iterable<int> daysOfMonth)
    : kind = PaydayKind.daysOfMonth,
      weekday = null,
      date = null,
      daysOfMonth = List<int>.unmodifiable(
        (daysOfMonth.where((int d) => d >= 1 && d <= 31).toSet().toList()
          ..sort()),
      );

  /// Paid every week on [weekday], Monday 1 to Sunday 7 as `DateTime` counts
  /// them. Anything else is unusable rather than a throw, for the same
  /// stored-data reason the days of the month are filtered.
  PaydaySchedule.weekly(int weekday)
    : kind = PaydayKind.weekly,
      weekday = weekday >= 1 && weekday <= 7 ? weekday : null,
      date = null,
      daysOfMonth = const <int>[];

  /// Paid every fourteen days, [anchor] being any one real payday.
  PaydaySchedule.everyTwoWeeks(DateTime anchor)
    : kind = PaydayKind.everyTwoWeeks,
      weekday = null,
      date = DateTime(anchor.year, anchor.month, anchor.day),
      daysOfMonth = const <int>[];

  /// No fixed payday: the money has to last until [until].
  PaydaySchedule.lastUntil(DateTime until)
    : kind = PaydayKind.lastUntil,
      weekday = null,
      date = DateTime(until.year, until.month, until.day),
      daysOfMonth = const <int>[];

  /// The rule a stored cycle carries, or null when it carries none: a cycle
  /// from before the editor existed, or a prototype import, which keep the
  /// countdown they stored.
  ///
  /// ONE PLACE reads the stored fields into a rule. The Home bar, the runway
  /// chart and the Health Check each used to rebuild it from `paydayDays`
  /// themselves, which is exactly how a weekly rule would have been read as
  /// "no rule" by three screens at once (ledger-reconciler, 2026-10-12).
  static PaydaySchedule? fromCycle(PaydayCycle c) {
    if (c.paydayDays.isNotEmpty) return PaydaySchedule(c.paydayDays);
    if (c.paydayWeekday != null) return PaydaySchedule.weekly(c.paydayWeekday!);
    final DateTime? anchor = readIsoDate(c.paydayAnchor);
    if (anchor != null) return PaydaySchedule.everyTwoWeeks(anchor);
    final DateTime? until = readIsoDate(c.lastUntil);
    if (until != null) return PaydaySchedule.lastUntil(until);
    return null;
  }

  final PaydayKind kind;

  /// Sorted, de-duplicated, and every entry between 1 and 31. Empty unless
  /// [kind] is [PaydayKind.daysOfMonth].
  ///
  /// Filtered in the constructor rather than asserted, because this is built
  /// from stored data as well as from a picker. A backup carrying day 0 or
  /// day 45 must not be able to throw: an unreadable ledger is a far worse
  /// outcome than a payday rule that quietly drops a nonsense entry, and
  /// [isUsable] is what the caller checks.
  final List<int> daysOfMonth;

  /// The weekday for [PaydayKind.weekly], 1 (Monday) to 7 (Sunday).
  final int? weekday;

  /// The anchor payday for [PaydayKind.everyTwoWeeks], or the last-until date
  /// for [PaydayKind.lastUntil], at midnight.
  final DateTime? date;

  /// True when there is enough to work from.
  bool get isUsable => switch (kind) {
    PaydayKind.daysOfMonth => daysOfMonth.isNotEmpty,
    PaydayKind.weekly => weekday != null,
    PaydayKind.everyTwoWeeks || PaydayKind.lastUntil => date != null,
  };

  /// Whether the paydays come round again. A last-until date does not: it is
  /// one date, and after it the person is asked for the next.
  bool get repeats => kind != PaydayKind.lastUntil;

  /// How many paydays fall in an average month, for anything that turns
  /// "each payday" into "each month" (the Health Check's take-home). Null
  /// when the question has no answer: with no fixed payday there is no
  /// monthly pay to speak of.
  double? get paydaysPerMonth => switch (kind) {
    PaydayKind.daysOfMonth => daysOfMonth.length.toDouble(),
    PaydayKind.weekly => 52 / 12,
    PaydayKind.everyTwoWeeks => 26 / 12,
    PaydayKind.lastUntil => null,
  };

  /// The fewest days of bills Safe to Spend holds back, whatever the
  /// countdown says (D37.3). A weekly or two-weekly payday comes round
  /// before rent does, so "bills due by payday" would offer the rent as
  /// spending money until the week it fell due. Monthly cycles keep D33's
  /// "due by payday", which a floor of zero leaves exactly as it was.
  int get billWindowFloor => switch (kind) {
    PaydayKind.weekly || PaydayKind.everyTwoWeeks => 30,
    PaydayKind.daysOfMonth || PaydayKind.lastUntil => 0,
  };

  /// Every payday in a given month, as real dates, shortest month included.
  ///
  /// THE CLAMP IS THE POINT. `DateTime(2026, 2, 31)` does not throw and does
  /// not give you 31 February: it silently returns 3 March. A person paid on
  /// the 30th would have had their February payday land in March, and a
  /// person paid on the 31st would have lost it in four months of the year.
  /// Both would have been off by days in the divisor of the figure on Home.
  ///
  /// Clamping to the last day of the month is also what payroll actually
  /// does: an end-of-month sweldo in February is paid on the 28th.
  List<DateTime> _inMonth(int year, int month) {
    final int last = _daysInMonth(year, month);
    final Set<DateTime> dates = <DateTime>{
      for (final int d in daysOfMonth)
        DateTime(year, month, d < last ? d : last),
    };
    return dates.toList()..sort();
  }

  /// The most recent payday on or before today, and the next one after it.
  ///
  /// "After it" is STRICT, and that is a decision rather than an accident.
  /// On payday itself the money has arrived and a new cutoff begins, so the
  /// countdown points at the following payday. It also keeps the countdown
  /// at one or more, which matters beyond the wording: `PaydayCycle.isSet`
  /// is `daysToPayday > 0`, so a zero would make an app with a perfectly
  /// good payday rule announce "Payday not set" on the one day the person is
  /// most likely to open it.
  PaydayPoints? pointsFrom(DateTime now) {
    if (!isUsable) return null;

    final DateTime today = DateTime(now.year, now.month, now.day);

    switch (kind) {
      case PaydayKind.weekly:
        // How many days back the last one was: 0 on payday itself, which
        // keeps "next" strictly after today, as below.
        final int back = (today.weekday - weekday! + 7) % 7;
        final DateTime last = _plusDays(today, -back);
        return _points(last, _plusDays(last, 7), today);
      case PaydayKind.everyTwoWeeks:
        // Whole fortnights from the anchor, rounded DOWN, so an anchor in the
        // future still finds the payday on or before today.
        final int since = _daysBetween(date!, today);
        final int fortnights = (since / 14).floor();
        final DateTime last = _plusDays(date!, fortnights * 14);
        return _points(last, _plusDays(last, 14), today);
      case PaydayKind.lastUntil:
        // THE DATE HAS PASSED, OR IS TODAY: no countdown at all. A zero would
        // reach the engine as a divisor of one and offer every free peso as
        // today's allowance (financial-coach, 2026-10-12). The screens ask
        // for the next date instead.
        if (!date!.isAfter(today)) return null;
        return _points(today, date!, today);
      case PaydayKind.daysOfMonth:
        break;
    }

    // Three months of candidates: the previous one for `last` when today is
    // before this month's first payday, and the next one for `next` when
    // today is on or after this month's last.
    final List<DateTime> candidates = <DateTime>[
      ..._inMonth(today.year, today.month - 1),
      ..._inMonth(today.year, today.month),
      ..._inMonth(today.year, today.month + 1),
    ]..sort();

    DateTime? last;
    DateTime? next;
    for (final DateTime d in candidates) {
      if (!d.isAfter(today)) {
        last = d;
      } else {
        next ??= d;
      }
    }

    // Both are guaranteed by the three month window: the previous month
    // always contributes at least one date at or before today, and the next
    // month always contributes at least one after it.
    return PaydayPoints(
      last: last!,
      next: next!,
      daysToNext: next.difference(today).inDays,
    );
  }

  static PaydayPoints _points(DateTime last, DateTime next, DateTime today) =>
      PaydayPoints(
        last: last,
        next: next,
        daysToNext: _daysBetween(today, next),
      );

  /// Calendar arithmetic by the date's own fields, so a day is always a day
  /// whatever the clock does in a zone with daylight saving.
  static DateTime _plusDays(DateTime d, int n) =>
      DateTime(d.year, d.month, d.day + n);

  static int _daysBetween(DateTime a, DateTime b) => DateTime.utc(
    b.year,
    b.month,
    b.day,
  ).difference(DateTime.utc(a.year, a.month, a.day)).inDays;

  /// Day 0 of the following month is the last day of this one, and Dart
  /// rolls month 13 into January of the next year on its own.
  static int _daysInMonth(int year, int month) =>
      DateTime(year, month + 1, 0).day;
}

/// Where the cycle stands today.
class PaydayPoints {
  const PaydayPoints({
    required this.last,
    required this.next,
    required this.daysToNext,
  });

  /// The most recent payday, today included.
  final DateTime last;

  /// The next payday, strictly after today, so this is never today.
  final DateTime next;

  /// Whole days from today to [next]. One or more, never zero.
  final int daysToNext;

  /// Whole days from the last payday to the next: about 15 for the 15th and
  /// 30th, about 30 for once a month. Rounded from hours so a clock change
  /// in a zone that has one cannot make it 29.96 and floor it to 29.
  int get cycleDays => (next.difference(last).inHours / 24).round();
}

/// "Sep 15", the format the stored cycle has always used.
///
/// Deliberately NOT an ISO date. `nextPayday` and `lastPayday` are printed
/// straight onto three screens, and `screen_readability_test.dart` fails a
/// build that shows a stored date raw. Keeping the derived value in the
/// existing display format means every reader of those two fields carries on
/// working with no change at all, and the new rule is the only thing that is
/// really stored.
String formatPaydayLabel(DateTime d) => '${_months[d.month - 1]} ${d.day}';

const List<String> _months = <String>[
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// A stored YYYY-MM-DD date, or null when it is not one. Strict, because
/// DateTime.tryParse quietly turns 2026-02-30 into March, and a payday rule
/// read from a backup must not land on a date nobody chose.
DateTime? readIsoDate(String? s) {
  if (s == null) return null;
  final RegExpMatch? m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(s);
  if (m == null) return null;
  final int y = int.parse(m.group(1)!);
  final int mo = int.parse(m.group(2)!);
  final int d = int.parse(m.group(3)!);
  final DateTime out = DateTime(y, mo, d);
  if (out.year != y || out.month != mo || out.day != d) return null;
  return out;
}

/// The stored form of a date: YYYY-MM-DD.
String isoDateOf(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';
