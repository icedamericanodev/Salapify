// The Sweldo Timeline: a rolling day by day projection of liquid cash that
// crosses month boundaries, so it can answer the question the month-bounded
// cash flow calendar cannot: not just "do I make it to the end of THIS month"
// but "do I make it to payday, and the one after that, and what happens if".
//
// It composes the same locked primitives the calendar uses (liquidKinds,
// bankDueDate, the posted-this-month rule) but generalizes each to a horizon:
// every recurring item contributes EVERY occurrence inside the window, every
// debt contributes every bank-adjusted cycle, and the payday schedule marks
// the sweldo boundaries so the tightest day BEFORE payday can be named.
//
// Two lines, honestly labeled:
//  - The conservative line counts only what is reasonably certain: recurring
//    income, recurring bills, debt minimums, and any scenario events. Same
//    philosophy as the calendar: receivables are never future income.
//  - The variable band is an ESTIMATE of ordinary day-to-day spending, the
//    average of the last four weeks of logged expenses that are not recurring
//    posts, not debt payments, and not sample rows. It is returned separately
//    (bandLow per day) and never mixed into the conservative line, so the
//    screen can draw it as a shaded possibility, not a fact.
//
// Scenarios are pure transforms: a one-time purchase, a monthly extra
// payment, a monthly income change, or a monthly spending cut. Each becomes
// events (or a band adjustment) inside this one function, so "what if" is
// just a second run with a different list. No scenario ever writes to the
// store from here; persistence is the screen's business.
//
// Every number is read from the data or arithmetic on it, never invented.
// Non-finite and junk shapes are guarded, matching the money layer.

import 'commitments.dart' show bankDueDate, liquidKinds;
import 'ledger.dart' show amountOf;
import 'sample_data.dart' show sampleTxIds;
import 'schedule.dart' show hasExplicitPaydaySchedule, nextPayday;

String _iso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String _monthKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';

double _fin(double v) => v.isFinite ? v : 0.0;

List<Map<String, dynamic>> _list(dynamic x) => [
  for (final r in (x is List ? x : const []))
    if (r is Map) r.cast<String, dynamic>(),
];

double _liquidNow(dynamic accounts) {
  var sum = 0.0;
  for (final a in (accounts is List ? accounts : const [])) {
    if (a is Map && liquidKinds.contains(a['kind'])) {
      sum += amountOf(a['balance']);
    }
  }
  return _fin(sum);
}

/// The average daily rate of ordinary variable spending: the last 28 full
/// days of logged expenses, excluding recurring posts (recurringId), debt
/// payments (debtId), and sample rows, divided by the fixed 28. The fixed
/// divisor makes the figure "your average over the last four weeks",
/// literally true even for a sparse logger, rather than an extrapolation.
({double dailyRate, int sampleCount}) variableSpendRate(
  Map<String, dynamic> data,
  DateTime ref,
) {
  final today = DateTime(ref.year, ref.month, ref.day);
  final from = _iso(DateTime(today.year, today.month, today.day - 28));
  final until = _iso(DateTime(today.year, today.month, today.day - 1));
  var total = 0.0;
  var count = 0;
  for (final t in _list(data['transactions'])) {
    if (t['type'] != 'expense') continue;
    if (t['recurringId'] != null) continue;
    if (t['debtId'] != null) continue;
    if (sampleTxIds.contains(t['id'])) continue;
    final d = t['date'];
    if (d is! String || d.compareTo(from) < 0 || d.compareTo(until) > 0) {
      continue;
    }
    final amt = amountOf(t['amount']);
    if (!(amt > 0)) continue;
    total += amt;
    count += 1;
  }
  return (dailyRate: _fin(total / 28.0), sampleCount: count);
}

/// Every payday from the schedule inside (today, end], as ISO dates. Empty
/// when no explicit schedule exists; the timeline never asserts a payday the
/// user did not describe, the same rule the payday reminder follows.
List<String> _paydaysInWindow(
  Map<String, dynamic> data,
  DateTime today,
  DateTime end,
) {
  if (!hasExplicitPaydaySchedule(data)) return const [];
  final settings = data['settings'];
  final schedule = settings is Map ? settings['paydaySchedule'] : null;
  final out = <String>[];
  var cursor = today;
  for (var guard = 0; guard < 12; guard++) {
    final p = nextPayday(cursor, schedule);
    if (p.isAfter(end)) break;
    out.add(_iso(p));
    cursor = DateTime(p.year, p.month, p.day + 1);
  }
  return out;
}

/// Project liquid cash day by day for [horizonDays] from [ref], crossing
/// month boundaries. [scenarios] is a list of maps, each one of:
///   {kind: 'purchase',     label, amount, date: 'YYYY-MM-DD'}
///   {kind: 'extraMonthly', label, amount, dayOfMonth}
///   {kind: 'incomeChange', label, amount, dayOfMonth}   amount may be < 0
///   {kind: 'cutSpending',  label, amountPerMonth}       reduces the band
/// Unknown kinds and junk amounts are ignored, never thrown on.
Map<String, dynamic> sweldoTimeline(
  Map<String, dynamic> data,
  DateTime ref, {
  int horizonDays = 30,
  List<Map<String, dynamic>> scenarios = const [],
}) {
  final today = DateTime(ref.year, ref.month, ref.day);
  final span = horizonDays < 0 ? 0 : horizonDays;
  final end = DateTime(today.year, today.month, today.day + span);

  final start = _liquidNow(data['accounts']);

  final byDate = <String, Map<String, dynamic>>{};
  void add(String dateIso, String label, double amount, String kind) {
    if (!(amount > 0)) return;
    final day = byDate.putIfAbsent(
      dateIso,
      () => {'in': 0.0, 'out': 0.0, 'events': <Map<String, dynamic>>[]},
    );
    final isIn = kind == 'income' || kind == 'scenarioIn';
    if (isIn) {
      day['in'] = (day['in'] as double) + amount;
    } else {
      day['out'] = (day['out'] as double) + amount;
    }
    (day['events'] as List).add({
      'label': label,
      'amount': amount,
      'kind': kind,
    });
  }

  // Recurring income and bills: EVERY occurrence in the window, one per
  // month, the day clamped to each month's real length. An occurrence is
  // skipped when that month is already posted (lastPosted at or past its
  // month key), which generalizes the calendar's posted-this-month rule: a
  // bill already paid this cycle is never double counted, and future months
  // cannot have been posted yet so they always project.
  var recurringCount = 0;
  for (final r in _list(data['recurring'])) {
    final amt = amountOf(r['amount']);
    if (!(amt > 0)) continue;
    final dayRaw = amountOf(r['dayOfMonth']);
    if (dayRaw < 1 || dayRaw > 31) continue;
    final day = dayRaw.truncate();
    final isIncome = r['type'] == 'income';
    final label =
        (r['label'] is String && (r['label'] as String).trim().isNotEmpty)
        ? (r['label'] as String).trim()
        : (isIncome ? 'Income' : 'Bill');
    final lastPosted = r['lastPosted'];
    recurringCount += 1;
    for (
      var m = DateTime(today.year, today.month, 1);
      !m.isAfter(end);
      m = DateTime(m.year, m.month + 1, 1)
    ) {
      final daysInMonth = DateTime(m.year, m.month + 1, 0).day;
      final occ = DateTime(
        m.year,
        m.month,
        day < daysInMonth ? day : daysInMonth,
      );
      if (occ.isBefore(today) || occ.isAfter(end)) continue;
      if (lastPosted is String && lastPosted.compareTo(_monthKey(occ)) >= 0) {
        continue;
      }
      add(_iso(occ), label, amt, isIncome ? 'income' : 'bill');
    }
  }

  // Debt minimums: every bank-adjusted cycle in the window, not just the
  // next one. Advance a cursor past each raw due to find the next cycle; the
  // seen-set guards a schedule that stops advancing.
  var debtCount = 0;
  for (final d in _list(data['debts'])) {
    if (!(amountOf(d['remaining']) > 0)) continue;
    final minPay = amountOf(d['minPayment']);
    final remaining = amountOf(d['remaining']);
    final minOfBoth = minPay < remaining ? minPay : remaining;
    final amount = minOfBoth != 0 ? minOfBoth : remaining;
    if (!(amount > 0)) continue;
    final name = (d['name'] is String && (d['name'] as String).isNotEmpty)
        ? d['name'] as String
        : 'Debt';
    var counted = false;
    final seen = <String>{};
    var cursor = today;
    for (var guard = 0; guard < 6; guard++) {
      final due = bankDueDate(d, cursor);
      if (due == null || due.date.isAfter(end)) break;
      final key = _iso(due.date);
      if (!seen.add(key)) break;
      add(key, name, amount, 'debt');
      counted = true;
      cursor = DateTime(due.raw.year, due.raw.month, due.raw.day + 1);
      if (!cursor.isAfter(today)) {
        cursor = DateTime(today.year, today.month, today.day + 1);
      }
    }
    if (counted) debtCount += 1;
  }

  // Scenario events and the band adjustment.
  var scenarioCount = 0;
  var bandCutPerDay = 0.0;
  for (final s in scenarios) {
    final kind = s['kind'];
    final label = (s['label'] is String && (s['label'] as String).isNotEmpty)
        ? s['label'] as String
        : 'What if';
    if (kind == 'purchase') {
      final amt = amountOf(s['amount']);
      final dateStr = (s['date'] ?? '').toString();
      final parsed = DateTime.tryParse(dateStr);
      if (amt > 0 && parsed != null) {
        final p = DateTime(parsed.year, parsed.month, parsed.day);
        if (!p.isBefore(today) && !p.isAfter(end)) {
          add(_iso(p), label, amt, 'scenarioOut');
          scenarioCount += 1;
        }
      }
    } else if (kind == 'extraMonthly' || kind == 'incomeChange') {
      final amt = amountOf(s['amount']);
      final dayRaw = amountOf(s['dayOfMonth']);
      if (amt.abs() > 0 && dayRaw >= 1 && dayRaw <= 31) {
        final day = dayRaw.truncate();
        final outKind = (kind == 'extraMonthly' || amt < 0)
            ? 'scenarioOut'
            : 'scenarioIn';
        for (
          var m = DateTime(today.year, today.month, 1);
          !m.isAfter(end);
          m = DateTime(m.year, m.month + 1, 1)
        ) {
          final daysInMonth = DateTime(m.year, m.month + 1, 0).day;
          final occ = DateTime(
            m.year,
            m.month,
            day < daysInMonth ? day : daysInMonth,
          );
          if (occ.isBefore(today) || occ.isAfter(end)) continue;
          add(_iso(occ), label, amt.abs(), outKind);
        }
        scenarioCount += 1;
      }
    } else if (kind == 'cutSpending') {
      final perMonth = amountOf(s['amountPerMonth']);
      if (perMonth > 0) {
        bandCutPerDay += perMonth / 30.0;
        scenarioCount += 1;
      }
    }
  }

  final band = variableSpendRate(data, today);
  final bandRate = (band.dailyRate - bandCutPerDay).clamp(0.0, double.infinity);

  final paydays = _paydaysInWindow(data, today, end);
  final firstPayday = paydays.isNotEmpty ? paydays.first : null;

  // The day walk: conservative balance from events, band as a separate
  // cumulative drain starting tomorrow (today is already half spent and the
  // trailing average already includes days like it).
  final outDays = <Map<String, dynamic>>[];
  var balance = start;
  var bandCum = 0.0;
  var lowest = start;
  var lowestDate = _iso(today);
  var anyNegative = start < 0;
  String? firstNegativeDate = start < 0 ? _iso(today) : null;
  double? lowestBeforePayday;
  String? lowestBeforePaydayDate;
  for (var i = 0; i <= span; i++) {
    final d = DateTime(today.year, today.month, today.day + i);
    final key = _iso(d);
    final day = byDate[key];
    final moneyIn = day != null ? day['in'] as double : 0.0;
    final moneyOut = day != null ? day['out'] as double : 0.0;
    final events = <Map<String, dynamic>>[];
    if (day != null) {
      var running = balance;
      for (final e in (day['events'] as List)) {
        final ev = (e as Map).cast<String, dynamic>();
        final amt = amountOf(ev['amount']);
        final isIn = ev['kind'] == 'income' || ev['kind'] == 'scenarioIn';
        running = _fin(running + (isIn ? amt : -amt));
        events.add({...ev, 'balanceAfter': running});
      }
    }
    balance = _fin(balance + moneyIn - moneyOut);
    if (i > 0) bandCum = _fin(bandCum + bandRate);
    final bandLow = _fin(balance - bandCum);
    if (balance < lowest) {
      lowest = balance;
      lowestDate = key;
    }
    if (balance < 0) {
      anyNegative = true;
      firstNegativeDate ??= key;
    }
    if (firstPayday != null && key.compareTo(firstPayday) < 0) {
      if (lowestBeforePayday == null || balance < lowestBeforePayday) {
        lowestBeforePayday = balance;
        lowestBeforePaydayDate = key;
      }
    }
    outDays.add({
      'date': key,
      'moneyIn': moneyIn,
      'moneyOut': moneyOut,
      'balance': balance,
      'bandLow': bandLow,
      'events': events,
      'isPayday': paydays.contains(key),
    });
  }

  return {
    'startBalance': start,
    'days': outDays,
    'endBalance': balance,
    'lowest': {'date': lowestDate, 'balance': lowest},
    'anyNegative': anyNegative,
    'firstNegativeDate': firstNegativeDate,
    'paydays': paydays,
    'lowestBeforePayday': lowestBeforePayday == null
        ? null
        : {'date': lowestBeforePaydayDate, 'balance': lowestBeforePayday},
    'band': {
      'dailyRate': bandRate,
      'basisDays': 28,
      'sampleCount': band.sampleCount,
    },
    'assumptions': {
      'recurringCount': recurringCount,
      'debtCount': debtCount,
      'hasSchedule': paydays.isNotEmpty || hasExplicitPaydaySchedule(data),
      'scenarioCount': scenarioCount,
    },
  };
}

/// Days from [ref] to the NEXT payday on the schedule, for the free horizon
/// ("to payday"). Falls back to the end of the current month when no explicit
/// schedule exists, which is the calendar screen's existing free window.
int freeHorizonDays(Map<String, dynamic> data, DateTime ref) {
  final today = DateTime(ref.year, ref.month, ref.day);
  if (hasExplicitPaydaySchedule(data)) {
    final settings = data['settings'];
    final schedule = settings is Map ? settings['paydaySchedule'] : null;
    final p = nextPayday(today, schedule);
    final d = DateTime(p.year, p.month, p.day).difference(today).inDays;
    if (d >= 1) return d;
  }
  return DateTime(today.year, today.month + 1, 0).difference(today).inDays;
}
