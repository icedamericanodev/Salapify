// Payday schedule math, ported 1:1 from the schedule functions in
// mobile/lib/format.js (normalizeSchedule 160-174, monthPaydays 178-183,
// nextPayday 186-199, prevPayday 202-216). Semimonthly 15/31 is the PH
// default; day 31 always means the month's real last day.

import 'ledger.dart' show amountOf;

/// True when the user has actually TOLD us their payday, as opposed to
/// normalizeSchedule quietly falling back to the 15/31 default.
///
/// This distinction matters because the two uses are not equally forgiving.
/// Guessing 15/31 for a FORECAST is harmless: it says "your next payday is
/// probably around then". Guessing it for a CLAIM is not, because "it is
/// payday today" is either true or a lie, and it was a lie for every user who
/// never migrated a schedule from the old app. Anything that asserts today is
/// payday, or pushes a notification about it, must check this first.
bool hasExplicitPaydaySchedule(dynamic data) {
  final settings = data is Map ? data['settings'] : null;
  final s = settings is Map ? settings['paydaySchedule'] : null;
  if (s is! Map) return false;
  final mode = s['mode'];
  if (mode == 'monthly') return s['day'] != null;
  if (mode == 'weekly') return s['weekday'] != null;
  if (mode == 'semimonthly') return s['days'] is List;
  return false;
}

Map<String, dynamic> normalizeSchedule(dynamic s) {
  int clampDay(dynamic d, int fallback) {
    final n = amountOf(d).truncate();
    // amountOf coerces junk to 0, which fails the 1..31 test like JS NaN.
    return (n >= 1 && n <= 31) ? n : fallback;
  }

  if (s is Map && s['mode'] == 'monthly') {
    return {'mode': 'monthly', 'day': clampDay(s['day'], 30)};
  }
  if (s is Map && s['mode'] == 'weekly') {
    final w = amountOf(s['weekday']).truncate();
    return {'mode': 'weekly', 'weekday': (w >= 0 && w <= 6) ? w : 5};
  }
  if (s is Map && s['mode'] == 'semimonthly' && s['days'] is List) {
    final days = s['days'] as List;
    return {
      'mode': 'semimonthly',
      'days': [
        clampDay(days.isNotEmpty ? days[0] : null, 15),
        clampDay(days.length > 1 ? days[1] : null, 31),
      ],
    };
  }
  return {
    'mode': 'semimonthly',
    'days': [15, 31],
  };
}

List<DateTime> _monthPaydays(int y, int m, Map<String, dynamic> schedule) {
  final lastDay = DateTime(y, m + 1, 0).day;
  final days = schedule['mode'] == 'monthly'
      ? [schedule['day'] as int]
      : (schedule['days'] as List).cast<int>();
  final clamped = {for (final d in days) d < lastDay ? d : lastDay}.toList()
    ..sort();
  return [for (final d in clamped) DateTime(y, m, d)];
}

int _jsDay(DateTime d) => d.weekday % 7;

/// The next payday on or after "today" (whole days, time ignored).
DateTime nextPayday(DateTime today, dynamic schedule) {
  final sch = normalizeSchedule(schedule);
  final startToday = DateTime(today.year, today.month, today.day);
  if (sch['mode'] == 'weekly') {
    final ahead = ((sch['weekday'] as int) - _jsDay(startToday) + 7) % 7;
    return DateTime(startToday.year, startToday.month, startToday.day + ahead);
  }
  for (var i = 0; i <= 1; i++) {
    for (final c in _monthPaydays(today.year, today.month + i, sch)) {
      if (!c.isBefore(startToday)) return c;
    }
  }
  return startToday;
}

/// Whole days from "today" to the next payday (format.js daysUntilPayday
/// 233-236).
int daysUntilPayday(DateTime today, dynamic schedule) {
  final startToday = DateTime(today.year, today.month, today.day);
  return (nextPayday(today, schedule).difference(startToday).inMilliseconds /
          86400000)
      .round();
}

/// A short human line describing the schedule (format.js scheduleLabel
/// 240-253), for the payday card and Pan's sweldo answer.
String scheduleLabel(dynamic schedule) {
  final sch = normalizeSchedule(schedule);
  String dayWord(int d) {
    if (d >= 31) return 'end of month';
    final suffix = (d == 1 || d == 21)
        ? 'st'
        : (d == 2 || d == 22)
            ? 'nd'
            : (d == 3 || d == 23)
                ? 'rd'
                : 'th';
    return 'the $d$suffix';
  }

  if (sch['mode'] == 'weekly') {
    const names = [
      'Sunday', 'Monday', 'Tuesday', 'Wednesday',
      'Thursday', 'Friday', 'Saturday',
    ];
    return 'every ${names[sch['weekday'] as int]}';
  }
  if (sch['mode'] == 'monthly') return dayWord(sch['day'] as int);
  final days = (sch['days'] as List).cast<int>().toList()..sort();
  final a = days[0];
  final b = days[1];
  return a == b ? dayWord(a) : '${dayWord(a)} and ${dayWord(b)}';
}

/// The most recent payday on or before "today".
DateTime prevPayday(DateTime today, dynamic schedule) {
  final sch = normalizeSchedule(schedule);
  final startToday = DateTime(today.year, today.month, today.day);
  if (sch['mode'] == 'weekly') {
    final back = (_jsDay(startToday) - (sch['weekday'] as int) + 7) % 7;
    return DateTime(startToday.year, startToday.month, startToday.day - back);
  }
  for (var i = 0; i >= -1; i--) {
    final list =
        _monthPaydays(today.year, today.month + i, sch).reversed.toList();
    for (final c in list) {
      if (!c.isAfter(startToday)) return c;
    }
  }
  return startToday;
}
