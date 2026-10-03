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

/// A payday rule: which days of the month the money lands on.
///
/// One day means paid once a month. Two means the usual Philippine
/// semi-monthly sweldo. The list is the whole rule, which is why there is no
/// enum: "twice a month on the 10th and the 25th" and "once a month on the
/// 25th" are the same idea with a different number of entries, and an enum
/// would have to carry the days beside it anyway.
class PaydaySchedule {
  PaydaySchedule(Iterable<int> daysOfMonth)
    : daysOfMonth = List<int>.unmodifiable(
        (daysOfMonth.where((int d) => d >= 1 && d <= 31).toSet().toList()
          ..sort()),
      );

  /// Sorted, de-duplicated, and every entry between 1 and 31.
  ///
  /// Filtered in the constructor rather than asserted, because this is built
  /// from stored data as well as from a picker. A backup carrying day 0 or
  /// day 45 must not be able to throw: an unreadable ledger is a far worse
  /// outcome than a payday rule that quietly drops a nonsense entry, and
  /// [isUsable] is what the caller checks.
  final List<int> daysOfMonth;

  /// True when there is at least one day to work from.
  bool get isUsable => daysOfMonth.isNotEmpty;

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
