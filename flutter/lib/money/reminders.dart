// Reminders planner: given the app data and "now", it returns the exact list
// of on-device reminders to fire. Adapted from mobile/lib/notifications.js
// (rescheduleAll), but kept PURE and separate from the plugin so the
// what-to-fire logic is unit tested and the plugin adapter stays a thin shell.
//
// Six kinds, each behind its own settings toggle (settings.notifications):
//  - daily: an evening log nudge, skipped tonight if you already logged today
//  - payday: 9am on each upcoming payday (your own schedule)
//  - bills: a debt due in 3 days (evening) and the morning it is due
//  - collect: an unpaid utang the day before and the day it is due, then a
//    gentle overdue follow-up
//  - backup: 10am on the 1st of each month, only once there is data worth
//    backing up; offline data has no cloud safety net, so the nudge IS the
//    safety net
//  - comeback: a gentle re-engagement ladder (day 2, 4, 7, 14 from the last
//    app open) so a lapsing user is brought back before every other reminder
//    runs dry; silent for active users because a reopen re-arms it
//  - lookahead: one heads up the evening before the Sweldo Timeline's
//    conservative projection first dips below zero in the next 14 days, so a
//    tight stretch is a plan and not a surprise
//
// Every peso here is read from the data, never invented. Non-finite and bad
// dates are guarded, matching the rest of the money layer.

import 'commitments.dart' show bankDueDate;
import 'ledger.dart' show amountOf;
import 'sample_data.dart' show sampleTxIds;
import 'schedule.dart' show hasExplicitPaydaySchedule, nextPayday;
import 'statements.dart' show todayISO;
import 'timeline.dart' show sweldoTimeline;

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

// A readable date for a reminder body ("Jul 15"), kept local so the money layer
// never imports a screen. Never a raw stored ISO string: the project rule is
// that a stored date is never shown to the user unformatted.
const _monthAbbrev = [
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
String _niceDate(DateTime d) => '${_monthAbbrev[d.month - 1]} ${d.day}';

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

// Whether the store holds anything worth keeping or coming back to. Used by the
// backup nudge (nothing to back up on an empty phone) and the comeback ladder
// (no "come back" ping to someone who never put anything in). Deliberately
// wider than accounts and transactions: Salapify is an utang tracker first, so
// a user who only recorded debts or receivables, and never opened an account or
// logged a spend, still has real data. The narrow accounts-or-transactions gate
// silently skipped both nudges for exactly that user, who is the core audience.
bool _hasAnyData(Map data) {
  for (final key in const [
    'accounts',
    'transactions',
    'debts',
    'receivables',
  ]) {
    final v = data[key];
    if (v is List && v.isNotEmpty) return true;
  }
  return false;
}

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
///
/// [detailed] controls whether a name or amount ever appears in the text. It is
/// OFF by default, which is the privacy contract: a locked phone must reveal no
/// name, amount, account, or debt detail. Two rules make that hold on any OEM:
///  1. Titles are ALWAYS generic (no name, no amount), because the title is the
///     one line Android can still show on the lock screen even under
///     VISIBILITY_PRIVATE.
///  2. Names and amounts live only in the BODY, and only when [detailed] is on.
///     When [detailed] is on the service uses a SECRET channel, which Android
///     keeps off a secure lock screen entirely, so the detail appears only in
///     the shade after unlock. That is the founder-approved "unlocked shade
///     only" posture: opting in reveals detail in the unlocked shade, never on
///     the lock screen.
List<PlannedReminder> plannedReminders(
  Map data,
  DateTime now, {
  bool detailed = false,
}) {
  final settings = data['settings'];
  final notifs = (settings is Map ? settings['notifications'] : null);
  final on = notifs is Map ? notifs : const {};
  final out = <PlannedReminder>[];
  void add(String title, String body, DateTime when) {
    if (when.isAfter(now)) out.add(PlannedReminder(title, body, when));
  }

  if (on['daily'] == true) {
    // Sample rows never count as logging. This is the fourth reader of the
    // habit signal (chain, coach, quick-add are the others) and it was the
    // one that missed the rule sample_data.dart writes down. It mattered:
    // the seed clamps its dates to today, so someone who said yes to the
    // nightly nudge and then chose "explore the sample data" had tonight's
    // reminder cancelled by a transaction they did not make, on any install
    // day from the 1st to the 10th.
    final loggedToday = _list(
      data['transactions'],
    ).any((t) => !sampleTxIds.contains(t['id']) && t['date'] == todayISO(now));
    for (var i = 0; i < 14; i++) {
      final d = DateTime(now.year, now.month, now.day + i, 20);
      if (!d.isAfter(now)) continue;
      if (i == 0 && loggedToday) continue;
      add('Quick money check', _dailyLines[d.day % _dailyLines.length], d);
    }
  }

  // Same rule as the payday card: never assert "Payday!" unless the user told
  // us when payday is. A 9am push on the wrong day is the most annoying
  // possible way to be wrong.
  if (on['payday'] == true && hasExplicitPaydaySchedule(data)) {
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
      // Generic title in both modes; the debt name goes in the body and only
      // when detailed is on. See the plannedReminders doc comment.
      add(
        'A bill is due in 3 days',
        detailed
            ? '$name is due in 3 days. ${hasMin ? 'Pay in full to avoid interest, or at least $minTxt to avoid late fees.' : 'Pay in full to avoid interest, or at least the minimum on your SOA to avoid late fees.'} GCash and over the counter payments can take 1 to 3 days to post, so pay early.'
            : 'One of your bills is due in 3 days. Open Salapify to see which and how much. GCash and over the counter payments can take 1 to 3 days to post, so pay early.',
        DateTime(due.year, due.month, due.day - 3, 18),
      );
      add(
        'A bill is due today',
        detailed
            ? (hasMin
                  ? '$name is due today. Pay at least $minTxt today to avoid penalties.'
                  : '$name is due today. Pay at least the minimum on your SOA today to avoid penalties.')
            : 'A bill is due today. Open Salapify to pay at least the minimum and avoid penalties.',
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
      // Generic titles; the person's name, the amount, and the raw due date go
      // in the body and only when detailed is on.
      add(
        'Money to collect tomorrow',
        detailed
            ? "$person's $amount is due tomorrow."
            : 'Someone owes you and it is due tomorrow. Open Salapify to see who.',
        DateTime(due.year, due.month, due.day - 1, 9),
      );
      if (due.isAfter(now)) {
        add(
          'Time to collect',
          detailed
              ? '$person owes you $amount and it is due today. Send a reminder from the app.'
              : 'You have money to collect due today. Open Salapify to send a reminder.',
          due,
        );
      } else {
        add(
          'Still waiting',
          detailed
              ? "$person's $amount was due ${_niceDate(due)}. A friendly follow up usually works."
              : 'You have money that was due. Open Salapify, a friendly follow up usually works.',
          DateTime(now.year, now.month, now.day + 1, 9),
        );
      }
    }
  }

  if (on['backup'] == true) {
    // Only nag once there is something to lose. Debts and receivables count:
    // an utang-only user has data worth a backup file too.
    if (_hasAnyData(data)) {
      for (var i = 0; i < 3; i++) {
        final d = DateTime(now.year, now.month + i, 1, 10);
        add(
          'Monthly backup',
          'Your data lives only on this phone, which is the whole point. '
              'Two taps in Menu saves a fresh backup file to a place you '
              'choose.',
          d,
        );
      }
    }
  }

  if (on['goals'] == true) {
    // A gentle monthly check-in for the goals the user is actively saving
    // toward: dated (deadline set), not paused, not finished. Up to TWO
    // goals so a collector of goals is not spammed, on the 1st at 10:00 for
    // the next two months (the same shape as the backup nudge, and equally
    // cap-friendly). The generic title carries no goal name or amount, per
    // the lock-screen rule; the detailed body may.
    final activeDated = <Map<String, dynamic>>[];
    for (final raw in (data['goals'] is List ? data['goals'] as List : const [])) {
      if (raw is! Map) continue;
      final g = raw.cast<String, dynamic>();
      if (g['paused'] == true) continue;
      final target = amountOf(g['target']);
      final saved = amountOf(g['saved']);
      if (!(target > 0) || saved >= target) continue;
      if ((g['targetDate'] ?? '').toString().isEmpty) continue;
      activeDated.add(g);
    }
    for (final g in activeDated.take(2)) {
      final name = (g['name'] ?? 'a goal').toString();
      // The 1st of the NEXT two months: this month's 1st is already behind
      // us for most of the month, and add() would drop it anyway.
      for (var i = 1; i <= 2; i++) {
        final d = DateTime(now.year, now.month + i, 1, 10);
        add(
          'Goal check-in',
          detailed
              ? 'A small add to $name this month keeps the plan honest. '
                    'Whatever fits is enough.'
              : 'One of your goals could use a small add this month. '
                    'Whatever fits is enough.',
          d,
        );
      }
    }
  }

  if (on['lookahead'] == true) {
    // One heads up, the evening before the conservative projection first
    // dips below zero in the next 14 days. Conservative line only, never the
    // band: an alarm built on an estimate cries wolf, and a wolf-crying
    // alarm gets its battery taken out. One ping per reschedule by
    // construction (there is exactly one first negative day), and a dip
    // that is already today schedules nothing because add() drops the past;
    // the timeline screen still shows it.
    final tl = sweldoTimeline(
      data is Map<String, dynamic> ? data : <String, dynamic>{...data},
      now,
      horizonDays: 14,
    );
    final firstNegative = tl['firstNegativeDate'];
    if (firstNegative is String) {
      final dip = _atHour(firstNegative, 18);
      if (dip != null) {
        add(
          'Cash flow heads up',
          detailed
              ? 'Your projected cash dips below zero around ${_niceDate(dip)}. A small move today beats a scramble later.'
              : 'The plan for the days ahead looks tight. Open Salapify to see which day and adjust early.',
          DateTime(dip.year, dip.month, dip.day - 1, 18),
        );
      }
    }
  }

  if (on['comeback'] == true) {
    // The re-engagement ladder for a user who stops opening the app. Every
    // other reminder is armed relative to the LAST time the app was opened,
    // and the schedule is only rebuilt on open, so a user who lapses eventually
    // runs dry and nothing brings them back. These pings, armed from `now` on
    // every open, are the safety net.
    //
    // They stay SILENT for an active user for free: the service wipes and
    // rebuilds the whole schedule on every open, so each open cancels the old
    // "day 2" ping and re-arms it two days past the NEW open. Only a genuinely
    // lapsed user (no reopen) ever lets one fire. So "day 2" means "two days
    // after you last opened Salapify", never a fixed calendar date.
    //
    // Only for a phone with something to come back to (the same gate backup
    // uses): a first-run user who bounced is onboarding's job, not a reminder
    // that says we miss you. "Something" includes debts and receivables, so an
    // utang-only user, the core audience, is not silently skipped.
    if (_hasAnyData(data)) {
      // A lapsed daily-nudge user is ALREADY getting a 20:00 log nudge every
      // evening for 14 days, so firing the early comeback pings on top would be
      // pure redundancy and the fatigue that gets a whole channel muted. So
      // when daily is on, comeback fires ONLY the day 14 catch, the morning
      // after daily's last evening nudge (day 13) and right before the shared
      // silence cliff. When daily is off (the majority this exists for) the
      // full ladder runs. Either way there is never a double-ping day.
      //
      // One asymmetry worth naming: the daily-on catch is a single ping at
      // now+14, the farthest-future item in the whole plan, so it is the first
      // thing the service's soonest-first 60-notification cap would drop. That
      // only bites a user with dozens of debts (each debt is two reminders);
      // realistic plans stay well under the cap, and the daily-off ladder sorts
      // near the front and always survives.
      //
      // The messages carry no name, amount, or date, so they are lock-screen
      // safe as-is and read the same whether or not detail is opted in.
      const dawn = <(int, String, String)>[
        (
          2,
          'Still here when you are',
          'No rush and no catch up needed. Open Salapify and pick up right where you left off.',
        ),
        (
          4,
          'No catching up needed',
          'Life gets busy. Two minutes in Salapify and you are back in the loop with your money.',
        ),
        (
          7,
          'A fresh start this week',
          'New week, clean slate. Just log one thing and you are current again. Nothing to catch up on.',
        ),
        (
          14,
          'Whenever you are ready',
          'Your numbers are safe on this phone, exactly as you left them. Open Salapify anytime to pick back up.',
        ),
      ];
      const lastOnly = <(int, String, String)>[
        (
          14,
          'Whenever you are ready',
          'Your numbers are safe on this phone, exactly as you left them. Open Salapify anytime to pick back up.',
        ),
      ];
      final steps = on['daily'] == true ? lastOnly : dawn;
      for (final (days, title, body) in steps) {
        add(title, body, DateTime(now.year, now.month, now.day + days, 11));
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
