// Pure debt math, ported 1:1 from mobile/lib/analytics.js
// (splitDebtPayment 390-408, debtFreeProjection 451-504) and
// mobile/lib/soa.js (cardForecast 135-161, buildSOA 169-226, dueDateFor
// 82-85). Golden-verified against outputs produced by executing the real RN
// modules.
//
// splitDebtPayment is the bank-officer spec: interest accrues over TIME on
// the diminishing balance, booked by days elapsed since interestThroughISO
// over a 30 day month, which is what stops two payments in one month from
// booking two months of interest. The accrued interest capitalizes into the
// balance, the payment covers interest first, and applied is clamped so you
// never pay or are charged more than you owe.

import 'commitments.dart' show bankDueDate, nextOccurrence;
import 'ledger.dart' show amountOf;

double _jsRound(num x) => (x + 0.5).floorToDouble();

String _iso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Split one debt payment into interest and principal. Returns every part
/// the caller and reports need: { accrued, balance, applied, interest,
/// principal, newRemaining, overpay }.
Map<String, dynamic> splitDebtPayment(dynamic remaining, dynamic monthlyRate,
    dynamic interestThroughISO, dynamic amount, String todayStr) {
  final curRaw = amountOf(remaining);
  final cur = curRaw > 0 ? curRaw : 0.0;
  final rate = amountOf(monthlyRate);
  final amtRaw = amountOf(amount);
  final amt = amtRaw > 0 ? amtRaw : 0.0;
  final fromISO =
      (interestThroughISO is String && interestThroughISO.isNotEmpty)
          ? interestThroughISO
          : todayStr;
  // A bad stamp makes the day diff NaN in JS and accrues 0 instead of
  // poisoning the balance; mirror with tryParse.
  final fromDate = DateTime.tryParse(fromISO);
  final todayDate = DateTime.tryParse(todayStr);
  var days = 0;
  if (fromDate != null && todayDate != null) {
    final raw = _jsRound(
            todayDate.difference(fromDate).inMilliseconds / 86400000)
        .toInt();
    days = raw > 0 ? raw : 0;
  }
  final accrued =
      rate > 0 ? _jsRound(cur * (rate / 100) * (days / 30)) : 0.0;
  final balance = cur + accrued;
  final applied = amt < balance ? amt : balance;
  final interest = applied < accrued ? applied : accrued;
  final principal = applied - interest;
  final newRemaining = balance - applied;
  final overpayRaw = amt - applied;
  final overpay = overpayRaw > 0 ? overpayRaw : 0.0;
  return {
    'accrued': accrued,
    'balance': balance,
    'applied': applied,
    'interest': interest,
    'principal': principal,
    'newRemaining': newRemaining,
    'overpay': overpay,
  };
}

/// Simulate paying down all debts month by month. Returns { months,
/// totalInterest, date (ISO) }, or null when the minimums can never win.
Map<String, dynamic>? debtFreeProjection(dynamic debts,
    [String strategy = 'avalanche', double extra = 0, DateTime? ref]) {
  final refDate = ref ?? DateTime.now();
  final list = <Map<String, double>>[];
  for (final d in (debts is List ? debts : const [])) {
    if (d is! Map) continue;
    final rem = amountOf(d['remaining']);
    if (!(rem > 0)) continue;
    final rate = amountOf(d['monthlyRate']);
    final minPay = amountOf(d['minPayment']);
    list.add({
      'remaining': rem,
      'monthlyRate': rate > 0 ? rate : 0.0,
      'minPayment': minPay > 0 ? minPay : 0.0,
    });
  }
  if (list.isEmpty) {
    return {'months': 0, 'totalInterest': 0.0, 'date': _iso(refDate)};
  }

  // The freed minimum of a finished debt rolls into the focus debt instead
  // of leaving the plan, which is what accelerates the payoff at the end.
  final totalMin =
      list.fold(0.0, (t, d) => t + d['minPayment']!);

  var months = 0;
  var totalInterest = 0.0;
  while (list.any((d) => d['remaining']! > 0.5) && months < 600) {
    months += 1;
    for (final d in list) {
      if (d['remaining']! > 0) {
        final interest = (d['remaining']! * d['monthlyRate']!) / 100;
        d['remaining'] = d['remaining']! + interest;
        totalInterest += interest;
      }
    }
    var budget = totalMin + extra;
    for (final d in list) {
      if (d['remaining']! > 0) {
        var pay = d['minPayment']!;
        if (d['remaining']! < pay) pay = d['remaining']!;
        if (budget < pay) pay = budget;
        d['remaining'] = d['remaining']! - pay;
        budget -= pay;
      }
    }
    // JS sort is stable; mirror with an index tiebreak over live refs.
    final indexed = List.generate(list.length, (i) => (list[i], i));
    indexed.sort((a, b) {
      final c = strategy == 'snowball'
          ? a.$1['remaining']!.compareTo(b.$1['remaining']!)
          : b.$1['monthlyRate']!.compareTo(a.$1['monthlyRate']!);
      return c != 0 ? c : a.$2.compareTo(b.$2);
    });
    for (final e in indexed) {
      if (budget <= 0) break;
      final d = e.$1;
      if (d['remaining']! > 0) {
        final pay = budget < d['remaining']! ? budget : d['remaining']!;
        d['remaining'] = d['remaining']! - pay;
        budget -= pay;
      }
    }
  }
  if (months >= 600) return null;
  final date = DateTime(refDate.year, refDate.month + months, 1);
  return {
    'months': months,
    'totalInterest': _jsRound(totalInterest),
    'date': _iso(date),
  };
}

/// Forecast for one credit card: next statement cut, bank-adjusted due,
/// forecast balance, minimum due, utilization, and what paying late costs.
/// Dates cross the API as ISO strings.
Map<String, dynamic>? cardForecast(
    Map<String, dynamic>? debt, dynamic payments, DateTime from) {
  if (debt == null) return null;
  final stmtDay = debt['statementDay'];
  final statement = (stmtDay != null && stmtDay != 0 && stmtDay != '')
      ? nextOccurrence(stmtDay, from)
      : null;
  final bankDue = bankDueDate(debt, from);
  var pending = 0.0;
  for (final p in (payments is List ? payments : const [])) {
    if (p is Map && p['debtId'] == debt['id'] && p['status'] == 'pending') {
      pending += amountOf(p['amount']);
    }
  }
  final balRaw = amountOf(debt['remaining']);
  final balance = balRaw > 0 ? balRaw : 0.0;
  final limit = amountOf(debt['creditLimit']);
  final rateRaw = amountOf(debt['monthlyRate']);
  final rate = rateRaw > 0 ? rateRaw : 0.0;
  final minPay = amountOf(debt['minPayment']);
  final minOfBoth = minPay < balance ? minPay : balance;
  final minDue = minOfBoth != 0 ? minOfBoth : balance;
  return {
    'statement': statement != null ? _iso(statement) : null,
    'due': bankDue != null ? _iso(bankDue.date) : null,
    'dueRaw': bankDue != null ? _iso(bankDue.raw) : null,
    'dueMoved': bankDue != null && bankDue.moved,
    'dueMovedReason': bankDue != null ? bankDue.reason : '',
    'pending': pending,
    'forecastBalance': balance,
    'minDue': minDue,
    'creditLimit': limit,
    'utilization': limit > 0 ? balance / limit : null,
    'monthlyRate': rate,
    'lateInterest': _jsRound((balance * rate) / 100),
  };
}

/// The next raw (unadjusted) due date as ISO, or null with no schedule.
String? dueDateFor(Map<String, dynamic>? debt, DateTime from) {
  final bd = debt != null ? bankDueDate(debt, from) : null;
  return bd != null ? _iso(bd.raw) : null;
}

const List<String> _monthsShort = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _longDate(String? isoDate) {
  if (isoDate == null || isoDate.isEmpty) return '';
  final p = isoDate.split('-').map(int.parse).toList();
  return '${_monthsShort[p[1] - 1]} ${p[2]}, ${p[0]}';
}

/// RN formatMoney: sign, peso sign, comma-grouped whole pesos.
String _m(num n) {
  final v = _jsRound(amountOf(n)).toInt();
  final sign = v < 0 ? '-' : '';
  final digits = v.abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write(',');
    buf.write(digits[i]);
  }
  return '$sign₱$buf';
}

/// A shareable text SOA forecast, byte-identical to the RN buildSOA. Honest
/// by design: it says clearly that it is a forecast from logged data.
String buildSOA(Map<String, dynamic>? debt, dynamic payments, DateTime from) {
  final f = cardForecast(debt, payments, from);
  if (f == null) return '';
  final lines = <String>[];
  lines.add('SALAPIFY SOA FORECAST');
  lines.add('${debt!['name']}');

  lines.add('');
  lines.add('THIS CYCLE');
  if (f['statement'] != null) {
    lines.add('Next statement cut: ${_longDate(f['statement'] as String)}');
  }
  lines.add(
      'Forecast statement balance: ${_m(f['forecastBalance'] as double)}');
  if ((f['creditLimit'] as double) > 0) {
    final utilPct =
        _jsRound(((f['utilization'] as double?) ?? 0) * 100).toInt();
    final capped = utilPct < 999 ? utilPct : 999;
    lines.add(
        'Credit used: $capped% of ${_m(f['creditLimit'] as double)}');
  }
  if ((f['pending'] as double) > 0) {
    lines.add(
        'Payments sent but not yet posted: ${_m(f['pending'] as double)}');
  }

  lines.add('');
  lines.add('WHAT TO PAY');
  lines.add(
      'Pay in full: ${_m(f['forecastBalance'] as double)} and new purchases stay interest free (cash advances and balances already revolving keep charging interest until fully cleared)');
  lines.add(
      'Or at least the minimum: ${_m(f['minDue'] as double)} to avoid late fees');
  if (f['due'] != null) {
    if (f['dueMoved'] as bool) {
      lines.add(
          'Due date: ${_longDate(f['due'] as String)} (moved from ${_longDate(f['dueRaw'] as String)}, which is ${f['dueMovedReason']}; banks accept payment on the next banking day)');
    } else {
      lines.add('Due date: ${_longDate(f['due'] as String)}');
    }
  }

  if ((f['lateInterest'] as double) > 0) {
    lines.add('');
    lines.add('IF YOU PAY LATE OR ONLY THE MINIMUM');
    lines.add(
        'About ${_m(f['lateInterest'] as double)} interest gets added next month (${_numText(f['monthlyRate'] as double)}% monthly on the unpaid balance)');
    lines.add(
        'Missing the due date also adds your bank’s late fee, check your card terms for the exact amount');
  } else if ((f['forecastBalance'] as double) > 0) {
    lines.add('');
    lines.add('INTEREST RATE NOT SET');
    lines.add(
        'This card has no monthly interest rate saved, so the forecast shows zero interest. Check your SOA for the real rate (PH cards are capped at 3% monthly) and add it in Salapify.');
  }

  lines.add('');
  lines.add(
      'This is not a bank document. It is a forecast from your logged data in Salapify; your bank’s official SOA may differ if there are swipes or fees not logged here.');
  return lines.join('\n');
}

/// JS template interpolation prints 3 as "3" and 3.5 as "3.5".
String _numText(double v) =>
    v % 1 == 0 ? v.toInt().toString() : v.toString();
