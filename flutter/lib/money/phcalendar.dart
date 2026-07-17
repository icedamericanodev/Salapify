// The Philippine banking calendar, ported 1:1 from mobile/lib/holidays.js.
// Banks do not process payments on weekends or holidays, so a due date
// landing on one moves to the next banking day. Covered: weekends, the
// fixed holidays, computed Easter (no table to go stale), National Heroes
// Day (last Monday of August), and Chinese New Year for known years.
// Missing a proclaimed one-off holiday only skips an adjustment the bank
// would have made in the user's favor, never the other way around.

const Map<String, String> _fixed = {
  '01-01': 'New Year’s Day',
  '04-09': 'Araw ng Kagitingan',
  '05-01': 'Labor Day',
  '06-12': 'Independence Day',
  '08-21': 'Ninoy Aquino Day',
  '11-01': 'All Saints’ Day',
  '11-30': 'Bonifacio Day',
  '12-08': 'Immaculate Conception',
  '12-24': 'Christmas Eve',
  '12-25': 'Christmas Day',
  '12-30': 'Rizal Day',
  '12-31': 'New Year’s Eve',
};

const Map<int, String> _cny = {
  2026: '02-17',
  2027: '02-06',
  2028: '01-26',
};

/// Easter Sunday for any year (Anonymous Gregorian algorithm).
DateTime easterSunday(int year) {
  final a = year % 19;
  final b = year ~/ 100;
  final c = year % 100;
  final d = b ~/ 4;
  final e = b % 4;
  final f = (b + 8) ~/ 25;
  final g = (b - f + 1) ~/ 3;
  final h = (19 * a + b - d - g + 15) % 30;
  final i = c ~/ 4;
  final k = c % 4;
  final l = (32 + 2 * e + 2 * i - h - k) % 7;
  final m = (a + 11 * h + 22 * l) ~/ 451;
  final month = (h + l - 7 * m + 114) ~/ 31;
  final day = ((h + l - 7 * m + 114) % 31) + 1;
  return DateTime(year, month, day);
}

String _mmdd(DateTime d) =>
    '${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// JS getDay: 0 is Sunday.
int _jsDay(DateTime d) => d.weekday % 7;

/// The holiday name on this date, or null on a working day.
String? holidayName(DateTime date) {
  final y = date.year;
  final key = _mmdd(date);
  if (_fixed.containsKey(key)) return _fixed[key];
  if (_cny[y] == key) return 'Chinese New Year';

  final easter = easterSunday(y);
  final days = DateTime(y, date.month, date.day)
          .difference(DateTime(y, easter.month, easter.day))
          .inDays;
  if (days == -3) return 'Maundy Thursday';
  if (days == -2) return 'Good Friday';
  if (days == -1) return 'Black Saturday';

  if (date.month == 8 && _jsDay(date) == 1 && date.day + 7 > 31) {
    return 'National Heroes Day';
  }
  return null;
}

/// Why this date is not a banking day, or null when banks are open.
String? nonBankingReason(DateTime date) {
  if (_jsDay(date) == 6) return 'a Saturday';
  if (_jsDay(date) == 0) return 'a Sunday';
  return holidayName(date);
}

/// Move a date forward to the next banking day.
/// Returns (date, moved, reason).
({DateTime? date, bool moved, String reason}) bankingAdjust(DateTime? date) {
  if (date == null) return (date: null, moved: false, reason: '');
  final first = nonBankingReason(date);
  if (first == null) return (date: date, moved: false, reason: '');
  var d = DateTime(date.year, date.month, date.day);
  for (var i = 0; i < 14; i++) {
    d = DateTime(d.year, d.month, d.day + 1);
    if (nonBankingReason(d) == null) {
      return (date: d, moved: true, reason: first);
    }
  }
  return (date: d, moved: true, reason: first);
}
