/// The Philippine banking calendar.
///
/// COPIED FORWARD DELIBERATELY from
/// `archive/salapify-2-flutter/lib/money/phcalendar.dart`, which is itself a
/// port of the frozen RN app's `mobile/lib/holidays.js`. The archive rule says
/// nothing is inherited by accident, so this file was read, re-typed and
/// re-tested here rather than imported, and the two differences from the
/// original are written down below rather than left to be discovered.
///
/// WHY IT EXISTS. Banks do not move money on a weekend or a holiday, so a bill
/// due on Sunday the 12th actually leaves the account on Monday the 13th. A
/// cash projection that ignores that is wrong by a day or three exactly when
/// it matters most, which is the day somebody is about to run short.
///
/// WHAT IT CANNOT KNOW. A proclaimed one-off holiday, which the President may
/// declare with weeks of notice, is not in here and cannot be. Missing one
/// means the projection expects money to leave a day EARLIER than it will,
/// which is the safe direction to be wrong in: the person is told they are
/// tighter than they are, never looser.
library;

/// Easter Sunday for any year, by the Anonymous Gregorian algorithm.
///
/// COMPUTED, NEVER TABLED, and that is the point. Maundy Thursday, Good Friday
/// and Black Saturday are all derived from it, and a table of dates is a
/// thing that silently goes stale the year nobody updates it.
DateTime easterSunday(int year) {
  final int a = year % 19;
  final int b = year ~/ 100;
  final int c = year % 100;
  final int d = b ~/ 4;
  final int e = b % 4;
  final int f = (b + 8) ~/ 25;
  final int g = (b - f + 1) ~/ 3;
  final int h = (19 * a + b - d - g + 15) % 30;
  final int i = c ~/ 4;
  final int k = c % 4;
  final int l = (32 + 2 * e + 2 * i - h - k) % 7;
  final int m = (a + 11 * h + 22 * l) ~/ 451;
  final int month = (h + l - 7 * m + 114) ~/ 31;
  final int day = ((h + l - 7 * m + 114) % 31) + 1;
  return DateTime(year, month, day);
}

/// The regular holidays that fall on the same date every year.
const Map<String, String> _fixedHolidays = <String, String>{
  '01-01': 'New Year\'s Day',
  '04-09': 'Araw ng Kagitingan',
  '05-01': 'Labor Day',
  '06-12': 'Independence Day',
  '08-21': 'Ninoy Aquino Day',
  '11-01': 'All Saints\' Day',
  '11-30': 'Bonifacio Day',
  '12-08': 'Immaculate Conception',
  '12-24': 'Christmas Eve',
  '12-25': 'Christmas Day',
  '12-30': 'Rizal Day',
  '12-31': 'New Year\'s Eve',
};

/// Chinese New Year, which follows a lunar calendar this file does not model.
///
/// A SHORT TABLE THAT RUNS OUT, on purpose and visibly. Deriving it properly
/// means a lunisolar implementation for one holiday a year, and a wrong
/// derivation would be worse than a missing entry. When it runs out the day
/// is simply treated as a banking day, which errs in the safe direction.
const Map<int, String> _chineseNewYear = <int, String>{
  2026: '02-17',
  2027: '02-06',
  2028: '01-26',
  2029: '02-13',
  2030: '02-03',
};

String _monthDay(DateTime d) =>
    '${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// The holiday on this date, or null on an ordinary day.
String? holidayName(DateTime date) {
  final String key = _monthDay(date);
  final String? fixed = _fixedHolidays[key];
  if (fixed != null) return fixed;
  if (_chineseNewYear[date.year] == key) return 'Chinese New Year';

  // The three movable days before Easter.
  final DateTime easter = easterSunday(date.year);
  final int fromEaster = DateTime(
    date.year,
    date.month,
    date.day,
  ).difference(DateTime(easter.year, easter.month, easter.day)).inDays;
  if (fromEaster == -3) return 'Maundy Thursday';
  if (fromEaster == -2) return 'Good Friday';
  if (fromEaster == -1) return 'Black Saturday';

  // National Heroes Day, the LAST Monday of August.
  //
  // REWRITTEN rather than copied, and this is the first of the two deliberate
  // differences from the archive. Its version read `date.day + 7 > 31`, which
  // is correct but says nothing about what it means. "A Monday with no Monday
  // after it this month" is the actual rule.
  if (date.month == DateTime.august &&
      date.weekday == DateTime.monday &&
      date.day + 7 > 31) {
    return 'National Heroes Day';
  }

  return null;
}

/// Why banks are shut on this date, or null when they are open.
String? nonBankingReason(DateTime date) {
  if (date.weekday == DateTime.saturday) return 'a Saturday';
  if (date.weekday == DateTime.sunday) return 'a Sunday';
  return holidayName(date);
}

/// A date moved forward to the day the money can actually leave.
///
/// [reason] names why it moved, in a shape that reads inside a sentence: "due
/// Sunday, so it leaves Monday". Empty when nothing moved.
typedef BankingDay = ({DateTime date, bool moved, String reason});

/// Move a date forward to the next banking day.
///
/// The second deliberate difference from the archive: the loop bound is 21
/// days rather than 14. Fourteen is enough for any real run of holidays, but
/// it is enough only by argument, and the cost of the larger bound is nothing.
/// The bound exists so a bad calendar can never hang the app, not to express a
/// belief about how long Christmas is.
BankingDay nextBankingDay(DateTime date) {
  final DateTime start = DateTime(date.year, date.month, date.day);
  final String? why = nonBankingReason(start);
  if (why == null) {
    return (date: start, moved: false, reason: '');
  }

  DateTime d = start;
  for (int i = 0; i < 21; i++) {
    d = DateTime(d.year, d.month, d.day + 1);
    if (nonBankingReason(d) == null) {
      return (date: d, moved: true, reason: why);
    }
  }
  return (date: d, moved: true, reason: why);
}
