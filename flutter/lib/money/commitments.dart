// Upcoming dues and safe to spend, ported 1:1 from mobile/lib/soa.js
// (nextOccurrence 14-24, daysUntil 27-31, prevOccurrence 34-44,
// rawDueCandidates 55-78, bankDueDate 91-101, upcomingDues 108-127) and
// mobile/lib/analytics.js (upcomingCommitments 63-97, safeToSpend 105-124).
// Bank-adjusted dates: weekends and PH holidays push payment to the next
// banking day, and a cycle only stops counting once its ADJUSTED date has
// passed. Dates cross the API as ISO strings so the shapes are
// JSON-friendly and golden-comparable.

import 'ledger.dart' show amountOf;
import 'phcalendar.dart';
import 'schedule.dart';

String _iso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// The next date a given day-of-month occurs, starting from "from".
/// Day 31 clamps to the month's real last day. Null on junk (amountOf
/// coerces non-numbers to 0, which fails the 1..31 test like JS NaN).
DateTime? nextOccurrence(dynamic dayOfMonth, DateTime from) {
  final day = amountOf(dayOfMonth);
  if (day < 1 || day > 31) return null;
  return _occurrence(day, from, forward: true);
}

/// The most recent date a given day-of-month occurred, on or before "from".
DateTime? prevOccurrence(dynamic dayOfMonth, DateTime from) {
  final dayRaw = amountOf(dayOfMonth);
  if (dayRaw < 1 || dayRaw > 31) return null;
  return _occurrence(dayRaw, from, forward: false);
}

DateTime _clampedDate(double day, int y, int m) {
  final lastDay = DateTime(y, m + 1, 0).day;
  final d = day < lastDay ? day : lastDay.toDouble();
  // JS new Date(y, m, 15.5) truncates the fractional day.
  return DateTime(y, m, d.truncate());
}

DateTime _occurrence(double day, DateTime from, {required bool forward}) {
  final y = from.year;
  final m = from.month;
  final todayMid = DateTime(y, m, from.day);
  final candidate = _clampedDate(day, y, m);
  if (forward) {
    if (!candidate.isBefore(todayMid)) return candidate;
    return _clampedDate(day, y, m + 1);
  }
  if (!candidate.isAfter(todayMid)) return candidate;
  return _clampedDate(day, y, m - 1);
}

/// Whole days from "from" until "date"; 0 means today.
int daysUntil(DateTime date, DateTime from) {
  final a = DateTime(from.year, from.month, from.day);
  final b = DateTime(date.year, date.month, date.day);
  return b.difference(a).inDays;
}

bool _jsTruthy(dynamic v) =>
    v != null &&
    v != false &&
    v != 0 &&
    v != '' &&
    !(v is double && v.isNaN);

DateTime _addDays(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);

/// Every raw due date a debt could still owe, oldest first. The PREVIOUS
/// cycle stays in the running: a raw due already past can have a bank
/// adjusted due that is still today or later.
List<DateTime> _rawDueCandidates(Map<String, dynamic> debt, DateTime from) {
  final out = <DateTime>[];
  if (_jsTruthy(debt['dueDay'])) {
    final prev = prevOccurrence(debt['dueDay'], from);
    final next = nextOccurrence(debt['dueDay'], from);
    if (prev != null) out.add(prev);
    if (next != null) out.add(next);
  } else {
    final grace = amountOf(debt['graceDays']).truncate();
    if (_jsTruthy(debt['statementDay']) && grace > 0) {
      final prevStmt = prevOccurrence(debt['statementDay'], from);
      if (prevStmt != null) {
        final prevPrevStmt =
            prevOccurrence(debt['statementDay'], _addDays(prevStmt, -1));
        if (prevPrevStmt != null) out.add(_addDays(prevPrevStmt, grace));
        out.add(_addDays(prevStmt, grace));
      }
      final nextStmt = nextOccurrence(debt['statementDay'], from);
      if (nextStmt != null) out.add(_addDays(nextStmt, grace));
    }
  }
  out.sort();
  return out;
}

/// The next due date the way the BANK sees it, or null with no schedule.
({DateTime date, DateTime raw, bool moved, String reason})? bankDueDate(
    Map<String, dynamic>? debt, DateTime from) {
  if (debt == null) return null;
  final todayMid = DateTime(from.year, from.month, from.day);
  for (final raw in _rawDueCandidates(debt, from)) {
    final adj = bankingAdjust(raw);
    final date = adj.date!;
    if (!date.isBefore(todayMid)) {
      return (date: date, raw: raw, moved: adj.moved, reason: adj.reason);
    }
  }
  return null;
}

/// All payments coming due in the next windowDays across every debt with a
/// schedule and money still owed, bank adjusted, soonest first. Each entry:
/// { debt, dueISO, inDays, moved, amount } where amount is the minimum due.
List<Map<String, dynamic>> upcomingDues(
    dynamic debts, int windowDays, DateTime from) {
  final list = <Map<String, dynamic>>[];
  for (final raw in (debts is List ? debts : const [])) {
    if (raw is! Map) continue;
    final d = raw.cast<String, dynamic>();
    if (!(amountOf(d['remaining']) > 0)) continue;
    final bankDue = bankDueDate(d, from);
    if (bankDue == null) continue;
    final inDays = daysUntil(bankDue.date, from);
    if (inDays > windowDays) continue;
    final minPay = amountOf(d['minPayment']);
    final remaining = amountOf(d['remaining']);
    final minOfBoth = minPay < remaining ? minPay : remaining;
    final amount =
        minOfBoth != 0 ? minOfBoth : (remaining != 0 ? remaining : 0.0);
    list.add({
      'debt': d,
      'dueISO': _iso(bankDue.date),
      'inDays': inDays,
      'moved': bankDue.moved,
      'amount': amount,
    });
  }
  final indexed = List.generate(list.length, (i) => (list[i], i));
  indexed.sort((a, b) {
    final c = (a.$1['dueISO'] as String).compareTo(b.$1['dueISO'] as String);
    return c != 0 ? c : a.$2.compareTo(b.$2);
  });
  return [for (final e in indexed) e.$1];
}

/// The bills that land before the next sweldo, oldest first, with the
/// total: card and loan minimums plus recurring bills not already posted
/// this cycle. Returns { payday (ISO), daysLeft, bills, total }.
Map<String, dynamic> upcomingCommitments(
    Map<String, dynamic> data, DateTime ref) {
  final today = DateTime(ref.year, ref.month, ref.day);
  final schedule =
      data['settings'] is Map ? (data['settings'] as Map)['paydaySchedule'] : null;

  var payday = nextPayday(today, schedule);
  if (payday == today) {
    payday =
        nextPayday(DateTime(today.year, today.month, today.day + 1), schedule);
  }
  final rawDaysLeft = daysUntil(payday, today);
  final daysLeft = rawDaysLeft > 1 ? rawDaysLeft : 1;

  final monthKey =
      '${today.year}-${today.month.toString().padLeft(2, '0')}';
  final bills = <Map<String, dynamic>>[];
  for (final d in upcomingDues(data['debts'], daysLeft, today)) {
    if (amountOf(d['amount']) > 0) {
      final debt = d['debt'] as Map<String, dynamic>;
      final name = debt['name'];
      bills.add({
        'name': (name is String && name.isNotEmpty) ? name : 'Debt',
        'kind': 'minimum',
        'date': d['dueISO'],
        'amount': amountOf(d['amount']),
      });
    }
  }
  for (final raw
      in (data['recurring'] is List ? data['recurring'] as List : const [])) {
    if (raw is! Map) continue;
    final r = raw.cast<String, dynamic>();
    if (r['type'] != 'expense') continue;
    final lastPosted = r['lastPosted'];
    final posted =
        lastPosted is String && lastPosted.compareTo(monthKey) >= 0;
    if (posted) continue;
    final amt = amountOf(r['amount']).clamp(0, double.infinity).toDouble();
    final due = nextOccurrence(r['dayOfMonth'], today);
    if (due != null && !due.isAfter(payday) && amt > 0) {
      final label = r['label'];
      bills.add({
        'name': (label is String && label.isNotEmpty) ? label : 'Recurring',
        'kind': 'bill',
        'date': _iso(due),
        'amount': amt,
      });
    }
  }
  final indexed = List.generate(bills.length, (i) => (bills[i], i));
  indexed.sort((a, b) {
    final c = (a.$1['date'] as String).compareTo(b.$1['date'] as String);
    return c != 0 ? c : a.$2.compareTo(b.$2);
  });
  final sorted = [for (final e in indexed) e.$1];
  final total = sorted.fold(0.0, (t, b) => t + amountOf(b['amount']));
  return {
    'payday': _iso(payday),
    'daysLeft': daysLeft,
    'bills': sorted,
    'total': total,
  };
}

/// Spendable right now: cash, e-wallets, checking. Never savings; the whole
/// point of safe to spend is to protect them.
const List<String> liquidKinds = ['cash', 'ewallet', 'checking'];

/// How much is genuinely free to spend each day between now and the next
/// payday, after setting aside the bills that land before then.
Map<String, dynamic> safeToSpend(Map<String, dynamic> data, DateTime ref) {
  final c = upcomingCommitments(data, ref);
  var liquid = 0.0;
  for (final raw
      in (data['accounts'] is List ? data['accounts'] as List : const [])) {
    if (raw is Map && liquidKinds.contains(raw['kind'])) {
      liquid += amountOf(raw['balance']);
    }
  }
  final committed = c['total'] as double;
  final available = liquid - committed;
  final daysLeft = c['daysLeft'] as int;
  final perDay = available > 0 ? available / daysLeft : 0.0;
  return {
    'liquid': liquid,
    'committed': committed,
    'available': available,
    'perDay': perDay,
    'daysLeft': daysLeft,
    'payday': c['payday'],
    'billCount': (c['bills'] as List).length,
  };
}

/// Your recent DISCRETIONARY spend per day, averaged over the trailing 14
/// days. Deliberately excludes anything safeToSpend already sets aside in
/// `committed`: transfers, debt principal, and adjustments are not expenses;
/// a debt interest expense (source 'interest') and anything tagged with a
/// debtId or recurringId is a committed cost, so counting it here would double
/// count against the runway. `daysSeen` collects the distinct days that had
/// discretionary spend, so the caller can refuse to read a pace off too few.
double _discretionaryDailyPace(
    dynamic transactions, DateTime ref, Set<String> daysSeen) {
  final today = DateTime(ref.year, ref.month, ref.day);
  final start = DateTime(today.year, today.month, today.day - 13);
  var total = 0.0;
  for (final raw in (transactions is List ? transactions : const [])) {
    if (raw is! Map) continue;
    final t = raw.cast<String, dynamic>();
    if (t['type'] != 'expense') continue;
    if (t['source'] == 'interest') continue;
    if (_jsTruthy(t['debtId']) || _jsTruthy(t['recurringId'])) continue;
    final ds = (t['date'] ?? '').toString();
    if (ds.length < 10) continue;
    final p = ds.split('-');
    final y = int.tryParse(p[0]);
    final m = p.length > 1 ? int.tryParse(p[1]) : null;
    final d = p.length > 2 ? int.tryParse(p[2]) : null;
    if (y == null || m == null || d == null) continue;
    final when = DateTime(y, m, d);
    if (when.isBefore(start) || when.isAfter(today)) continue;
    total += amountOf(t['amount']);
    daysSeen.add(ds.substring(0, 10));
  }
  return total / 14;
}

/// Cash flow to the next sweldo: compares your recent discretionary daily pace
/// against the spendable cash safeToSpend already computed, and reports whether
/// you are on track to reach payday or on pace to run short first, with the
/// small daily easing that closes the gap. Pure and offline.
///
/// Returns null (the card stays silent) when available <= 0 (that is the
/// crunch case, owned by the coach's crunch decision, so this never stacks a
/// second scary card), when there is too little recent logging to read a pace
/// honestly, or when the recent pace is zero. Silence beats a made-up number.
Map<String, dynamic>? paydayProjection(Map<String, dynamic> data, DateTime ref) {
  final s = safeToSpend(data, ref);
  final available = s['available'] as double;
  // A junk backup can smuggle a huge or non-finite balance. floor() throws on
  // a non-finite double, so refuse anything that is not a real positive amount
  // before any division, rather than crash the whole coach.
  if (!(available > 0) || !available.isFinite) return null;
  final daysSeen = <String>{};
  final dailyPace =
      _discretionaryDailyPace(data['transactions'], ref, daysSeen);
  const minLoggedDays = 6;
  if (daysSeen.length < minLoggedDays ||
      !(dailyPace > 0) ||
      !dailyPace.isFinite) {
    return null;
  }

  final perDay = s['perDay'] as double;
  final daysLeft = s['daysLeft'] as int;
  final onTrack = dailyPace <= perDay;
  final leftover = available - dailyPace * daysLeft;
  final ratio = available / dailyPace;
  // A very large available over a tiny pace overflows to Infinity; floor()
  // would throw. If the runway is effectively unbounded, there is no shortfall
  // to warn about, so stay silent.
  if (!ratio.isFinite) return null;
  final daysToRunOut = ratio.floor();
  final rawShort = daysLeft - daysToRunOut;
  final today = DateTime(ref.year, ref.month, ref.day);
  final runOut = DateTime(today.year, today.month, today.day + daysToRunOut);
  return {
    'available': available,
    'perDay': perDay,
    'daysLeft': daysLeft,
    'payday': s['payday'],
    'dailyPace': dailyPace,
    'onTrack': onTrack,
    'leftover': leftover,
    'daysShort': rawShort > 0 ? rawShort : 0,
    'easeOff': dailyPace > perDay ? dailyPace - perDay : 0.0,
    'runOutISO': _iso(runOut),
  };
}
