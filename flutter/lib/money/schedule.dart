// Payday schedule math, ported 1:1 from the schedule functions in
// mobile/lib/format.js (normalizeSchedule 160-174, monthPaydays 178-183,
// nextPayday 186-199, prevPayday 202-216). Semimonthly 15/31 is the PH
// default; day 31 always means the month's real last day.

import 'ledger.dart' show amountOf;

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
