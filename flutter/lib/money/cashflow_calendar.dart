// The Cash Flow Calendar: a day by day map of the month built around the sweldo
// cycle. It projects money in (recurring income like your sweldo) and money out
// (recurring bills and card, loan, and BNPL minimums) onto a per day timeline
// with a running balance, and flags the days your cash runs tight. It answers
// the one question a kinsenas and katapusan earner actually asks: can I spend
// today, or do I wait for the next sweldo?
//
// This composes engines already locked to the RN app to the centavo: the liquid
// balance rule from safe-to-spend (liquidKinds), the future recurring occurrence
// and posted this month check from upcomingCommitments, and the bank adjusted
// debt due dates from upcomingDues (weekends and PH holidays push a due to the
// next banking day). Only the day by day assembly and the running balance are
// net new, so they are covered by Dart unit tests with hard invariants, not a
// golden replay. Non-finite guarded so a junk backup never throws.
//
// Deliberately conservative: it projects only the flows that are reasonably
// certain, recurring income, recurring bills, and debt minimums. It does NOT
// count receivables owed to you as future income, because money someone MIGHT
// pay you is not money you can plan to spend. Utang stays on the utang screen.

import 'ledger.dart' show amountOf;
import 'commitments.dart' show nextOccurrence, upcomingDues, liquidKinds;

String _iso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String _monthKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';

double _fin(double v) => v.isFinite ? v : 0.0;

/// The current spendable cash: the same liquid accounts (cash, e-wallets,
/// checking) safe-to-spend protects, never savings.
double _liquidNow(dynamic accounts) {
  var sum = 0.0;
  for (final a in (accounts is List ? accounts : const [])) {
    if (a is Map && liquidKinds.contains(a['kind'])) {
      sum += amountOf(a['balance']);
    }
  }
  return _fin(sum);
}

/// Project the month (or a fixed window) day by day. [ref] is "today". By
/// default the window runs from today through the end of the current month; pass
/// [days] to run a fixed number of days forward instead (for a look-ahead view).
///
/// Returns:
///   { startBalance, days: [ {date, moneyIn, moneyOut, balance, events:
///     [{label, amount, kind}] } ... ], endBalance, lowest: {date, balance},
///     anyNegative, tightestDrop }
/// where `balance` is the projected end-of-day cash, `lowest` is the tightest
/// day in the window, and `anyNegative` is true if cash is projected to run out.
Map<String, dynamic> cashFlowCalendar(
  Map<String, dynamic> data,
  DateTime ref, {
  int? days,
}) {
  final today = DateTime(ref.year, ref.month, ref.day);
  final end = days != null
      ? DateTime(today.year, today.month, today.day + (days < 0 ? 0 : days))
      : DateTime(today.year, today.month + 1, 0); // last day of this month
  final windowDays = end.difference(today).inDays;
  final monthKey = _monthKey(today);

  final start = _liquidNow(data['accounts']);

  // Events keyed by ISO date. Each day holds its in, out, and the labeled rows.
  final byDate = <String, Map<String, dynamic>>{};
  void add(String dateIso, String label, double amount, String kind) {
    if (!(amount > 0)) return;
    final day = byDate.putIfAbsent(
      dateIso,
      () => {'in': 0.0, 'out': 0.0, 'events': <Map<String, dynamic>>[]},
    );
    if (kind == 'income') {
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

  // Recurring income and bills: the next occurrence on or after today, but only
  // when it has not already been posted this month (same rule as safe-to-spend,
  // so a bill already paid this cycle is never double counted).
  for (final raw
      in (data['recurring'] is List ? data['recurring'] as List : const [])) {
    if (raw is! Map) continue;
    final r = raw.cast<String, dynamic>();
    final lastPosted = r['lastPosted'];
    final posted = lastPosted is String && lastPosted.compareTo(monthKey) >= 0;
    if (posted) continue;
    final occ = nextOccurrence(r['dayOfMonth'], today);
    if (occ == null || occ.isAfter(end)) continue;
    final amt = amountOf(r['amount']);
    if (!(amt > 0)) continue;
    final isIncome = r['type'] == 'income';
    final label =
        (r['label'] is String && (r['label'] as String).trim().isNotEmpty)
        ? (r['label'] as String).trim()
        : (isIncome ? 'Income' : 'Bill');
    add(_iso(occ), label, amt, isIncome ? 'income' : 'bill');
  }

  // Debt, card, and BNPL minimums, bank adjusted, within the window.
  for (final due in upcomingDues(data['debts'], windowDays, today)) {
    final amt = amountOf(due['amount']);
    if (!(amt > 0)) continue;
    final debt = due['debt'];
    final name =
        (debt is Map &&
            debt['name'] is String &&
            (debt['name'] as String).isNotEmpty)
        ? debt['name'] as String
        : 'Debt';
    add((due['dueISO'] ?? '').toString(), name, amt, 'debt');
  }

  // Walk the window day by day, carrying the running balance.
  final outDays = <Map<String, dynamic>>[];
  var balance = start;
  var lowest = start;
  var lowestDate = _iso(today);
  var anyNegative = start < 0;
  for (var i = 0; i <= windowDays; i++) {
    final d = DateTime(today.year, today.month, today.day + i);
    final key = _iso(d);
    final day = byDate[key];
    final moneyIn = day != null ? day['in'] as double : 0.0;
    final moneyOut = day != null ? day['out'] as double : 0.0;
    balance = _fin(balance + moneyIn - moneyOut);
    if (balance < lowest) {
      lowest = balance;
      lowestDate = key;
    }
    if (balance < 0) anyNegative = true;
    outDays.add({
      'date': key,
      'moneyIn': moneyIn,
      'moneyOut': moneyOut,
      'balance': balance,
      'events': day != null ? day['events'] : const [],
    });
  }

  return {
    'startBalance': start,
    'days': outDays,
    'endBalance': balance,
    'lowest': {'date': lowestDate, 'balance': lowest},
    'anyNegative': anyNegative,
    // How far the tightest day dips below where you started, so the card can say
    // "your cash dips to X around the 27th" honestly.
    'tightestDrop': _fin(start - lowest),
  };
}
