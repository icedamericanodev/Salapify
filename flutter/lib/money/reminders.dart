// Reminders planner: given the app data and "now", it returns the exact list
// of on-device reminders to fire. Adapted from mobile/lib/notifications.js
// (rescheduleAll), but kept PURE and separate from the plugin so the
// what-to-fire logic is unit tested and the plugin adapter stays a thin shell.
//
// Four kinds, each behind its own settings toggle (settings.notifications):
//  - daily: an evening log nudge, skipped tonight if you already logged today
//  - payday: 9am on each upcoming payday (your own schedule)
//  - bills: a debt due in 3 days (evening) and the morning it is due
//  - collect: an unpaid utang the day before and the day it is due, then a
//    gentle overdue follow-up
//
// Every peso here is read from the data, never invented. Non-finite and bad
// dates are guarded, matching the rest of the money layer.

import 'commitments.dart' show bankDueDate;
import 'ledger.dart' show amountOf;
import 'schedule.dart' show nextPayday;
import 'statements.dart' show todayISO;

class PlannedReminder {
  final String title;
  final String body;
  final DateTime when;
  const PlannedReminder(this.title, this.body, this.when);
}

// The daily nudge rotates through a small pool so it never goes stale. The
// habit is logging, not being perfect, so none of these judge.
const _dailyLines = [
  'Take 30 seconds to log what you spent today.',
  'Quick check in. What did money do today?',
  'Log today before you forget. Future you says thanks.',
  'Even a zero spend day counts. Log it and stay current.',
  'One tap per expense. That is the whole habit.',
];

// Compact peso formatter matching the app's formatMoney output closely enough
// for a lock-screen line, kept local so the money layer never imports a screen.
String _peso(num value) {
  if (!value.isFinite) return '₱$value';
  final neg = value < 0;
  final scaled = value.abs() * 100;
  if (!scaled.isFinite) return '₱$value';
  final rounded = scaled.round() / 100;
  final whole = rounded.floor();
  final cents = ((rounded - whole) * 100).round();
  final digits = whole.toString();
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write(',');
    buf.write(digits[i]);
  }
  final centsPart = cents > 0 ? '.${cents.toString().padLeft(2, '0')}' : '';
  return '${neg ? '-' : ''}₱$buf$centsPart';
}

// 'YYYY-MM-DD' to a local DateTime at the given hour, or null if the grammar
// rejects it (a made-up 2026-02-31 would otherwise roll into March).
DateTime? _atHour(dynamic dateStr, int hour) {
  final parts = (dateStr ?? '').toString().split('-');
  if (parts.length != 3) return null;
  final nums = parts.map(int.tryParse).toList();
  if (nums.any((n) => n == null)) return null;
  final d = DateTime(nums[0]!, nums[1]!, nums[2]!, hour);
  if (d.year != nums[0] || d.month != nums[1] || d.day != nums[2]) return null;
  return d;
}

List<Map<String, dynamic>> _list(dynamic x) =>
    x is List ? x.whereType<Map<String, dynamic>>().toList() : const [];

// The upcoming paydays on the user's own schedule, from "now" forward.
List<DateTime> _upcomingPaydays(DateTime now, dynamic schedule, int count) {
  final out = <DateTime>[];
  var cursor = DateTime(now.year, now.month, now.day);
  var guard = 0;
  while (out.length < count && guard < 400) {
    final p = nextPayday(cursor, schedule);
    out.add(p);
    cursor = DateTime(p.year, p.month, p.day + 1);
    guard += 1;
  }
  return out;
}

/// The reminders to schedule, honoring each toggle. Only times strictly after
/// [now] are returned, so a reminder never fires "in the past".
List<PlannedReminder> plannedReminders(Map data, DateTime now) {
  final settings = data['settings'];
  final notifs = (settings is Map ? settings['notifications'] : null);
  final on = notifs is Map ? notifs : const {};
  final out = <PlannedReminder>[];
  void add(String title, String body, DateTime when) {
    if (when.isAfter(now)) out.add(PlannedReminder(title, body, when));
  }

  if (on['daily'] == true) {
    final loggedToday = _list(
      data['transactions'],
    ).any((t) => t['date'] == todayISO(now));
    for (var i = 0; i < 14; i++) {
      final d = DateTime(now.year, now.month, now.day + i, 20);
      if (!d.isAfter(now)) continue;
      if (i == 0 && loggedToday) continue;
      add('Quick money check', _dailyLines[d.day % _dailyLines.length], d);
    }
  }

  if (on['payday'] == true) {
    final schedule = settings is Map ? settings['paydaySchedule'] : null;
    for (final p in _upcomingPaydays(now, schedule, 6)) {
      add(
        'Payday!',
        'Open Salapify and the payday plan walks you through it: log it, move savings first, then set the budget.',
        DateTime(p.year, p.month, p.day, 9),
      );
    }
  }

  if (on['bills'] == true) {
    for (final d in _list(data['debts'])) {
      if (!(amountOf(d['remaining']) > 0)) continue;
      final bankDue = bankDueDate(d, now);
      if (bankDue == null) continue;
      final due = bankDue.date;
      final name =
          (d['name'] is String && (d['name'] as String).trim().isNotEmpty)
          ? d['name'] as String
          : 'A debt';
      final min = amountOf(d['minPayment']);
      final remaining = amountOf(d['remaining']);
      final hasMin = min > 0;
      final minTxt = _peso(min < remaining ? min : remaining);
      add(
        '$name is due in 3 days',
        '${hasMin ? 'Pay in full to avoid interest, or at least $minTxt to avoid late fees.' : 'Pay in full to avoid interest, or at least the minimum on your SOA to avoid late fees.'} GCash and over the counter payments can take 1 to 3 days to post, so pay early.',
        DateTime(due.year, due.month, due.day - 3, 18),
      );
      add(
        '$name is due today',
        hasMin
            ? 'Pay at least $minTxt today to avoid penalties.'
            : 'Pay at least the minimum on your SOA today to avoid penalties.',
        DateTime(due.year, due.month, due.day, 9),
      );
    }
  }

  if (on['collect'] == true) {
    for (final r in _list(data['receivables'])) {
      if (r['paid'] == true || r['dueDate'] == null) continue;
      final paidSoFar = _list(
        r['payments'],
      ).fold<double>(0, (s, p) => s + amountOf(p['amount']));
      final remaining = amountOf(r['amount']) - paidSoFar;
      if (remaining <= 0) continue;
      final due = _atHour(r['dueDate'], 9);
      if (due == null) continue;
      final person =
          (r['person'] is String && (r['person'] as String).trim().isNotEmpty)
          ? r['person'] as String
          : 'Someone';
      final amount = _peso(remaining);
      add(
        'Utang due tomorrow',
        "$person's $amount is due tomorrow.",
        DateTime(due.year, due.month, due.day - 1, 9),
      );
      if (due.isAfter(now)) {
        add(
          'Time to collect',
          '$person owes you $amount and it is due today. Send a reminder from the app.',
          due,
        );
      } else {
        add(
          'Still waiting',
          "$person's $amount was due ${r['dueDate']}. A friendly follow up usually works.",
          DateTime(now.year, now.month, now.day + 1, 9),
        );
      }
    }
  }

  // Soonest first (with a stable title tiebreak, since Dart's sort is not
  // stable), so when the scheduler caps how many it queues, it keeps the
  // reminders that fire next rather than whichever happened to be built first.
  out.sort((a, b) {
    final c = a.when.compareTo(b.when);
    return c != 0 ? c : a.title.compareTo(b.title);
  });
  return out;
}
