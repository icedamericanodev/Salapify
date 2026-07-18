// Loan and amortization math, ported 1:1 from mobile/lib/loan.js. The whole
// point is to show a Filipino borrower the TRUE cost of a loan, and to stop
// a lender's low add-on rate from hiding an effective rate roughly double
// it. Two conventions: diminishing balance (banks; interest on the
// remaining balance) and add-on (in-house and informal; interest on the
// original principal for the whole term, which looks cheap and is not).
// This is an estimate tool; real contracts add fees the UI must disclose.
// Golden-verified against the real RN module.

import 'dart:math' as math;

import 'ledger.dart' show amountOf;

double _jsRound(num x) => (x + 0.5).floorToDouble();

double _round2(dynamic x) => _jsRound(amountOf(x) * 100) / 100;

double _round4(dynamic x) => _jsRound(amountOf(x) * 10000) / 10000;

/// A hard ceiling on the term, so the schedule can never grow without
/// bound and freeze the UI.
const int maxMonths = 1200;

int _clampMonths(dynamic months) {
  final rounded = _jsRound(amountOf(months));
  final atLeastOne = rounded > 1 ? rounded : 1.0;
  return (atLeastOne < maxMonths ? atLeastOne : maxMonths.toDouble()).toInt();
}

/// Level monthly payment on a diminishing-balance loan.
/// A = P * r / (1 - (1 + r)^-n), and A = P / n when the rate is zero.
double monthlyPayment(dynamic principal, dynamic monthlyRate, dynamic months) {
  final p = math.max(0.0, amountOf(principal));
  final r = math.max(0.0, amountOf(monthlyRate));
  final n = _clampMonths(months);
  if (p == 0) return 0;
  if (r == 0) return _round2(p / n);
  final factor = r / (1 - math.pow(1 + r, -n));
  return _round2(p * factor);
}

/// Full diminishing-balance schedule. Each row splits the payment into
/// interest on the current balance and principal; the last payment absorbs
/// rounding so the loan closes exactly.
Map<String, dynamic> amortize(
    dynamic principal, dynamic monthlyRate, dynamic months) {
  final p = math.max(0.0, amountOf(principal));
  final r = math.max(0.0, amountOf(monthlyRate));
  final n = _clampMonths(months);
  final payment = monthlyPayment(p, r, n);
  final schedule = <Map<String, dynamic>>[];
  var balance = p;
  var totalInterest = 0.0;
  for (var i = 1; i <= n; i++) {
    final interest = _round2(balance * r);
    var principalPaid = _round2(payment - interest);
    if (i == n || principalPaid > balance) principalPaid = _round2(balance);
    final rowPayment = _round2(principalPaid + interest);
    balance = _round2(balance - principalPaid);
    totalInterest = _round2(totalInterest + interest);
    schedule.add({
      'period': i,
      'payment': rowPayment,
      'interest': interest,
      'principal': principalPaid,
      'balance': balance > 0 ? balance : 0.0,
    });
  }
  return {
    'payment': payment,
    'months': n,
    'totalInterest': _round2(totalInterest),
    'totalPaid': _round2(p + totalInterest),
    'schedule': schedule,
  };
}

/// Add-on loan: interest charged on the ORIGINAL principal for the whole
/// term, then spread evenly.
Map<String, dynamic> addOnLoan(
    dynamic principal, dynamic monthlyAddOnRate, dynamic months) {
  final p = math.max(0.0, amountOf(principal));
  final rate = math.max(0.0, amountOf(monthlyAddOnRate));
  final n = _clampMonths(months);
  final totalInterest = _round2(p * rate * n);
  final totalPaid = _round2(p + totalInterest);
  final payment = _round2(totalPaid / n);
  return {
    'payment': payment,
    'months': n,
    'totalInterest': totalInterest,
    'totalPaid': totalPaid,
  };
}

/// The effective monthly rate a loan really costs, backed out from its
/// principal, level payment, and term by bisection. For an add-on loan
/// this reveals the true rate hiding behind the quoted one.
double effectiveMonthlyRate(dynamic principal, dynamic payment, dynamic months) {
  final p = math.max(0.0, amountOf(principal));
  final a = math.max(0.0, amountOf(payment));
  final n = _clampMonths(months);
  if (p <= 0 || a <= 0) return 0;
  if (a * n <= p) return 0;
  double pv(double r) =>
      r == 0 ? a * n : a * (1 - math.pow(1 + r, -n)) / r;
  var lo = 0.0;
  var hi = 1.0;
  while (pv(hi) > p && hi < 1e6) {
    hi *= 2;
  }
  for (var i = 0; i < 200; i++) {
    final mid = (lo + hi) / 2;
    if (pv(mid) > p) {
      lo = mid;
    } else {
      hi = mid;
    }
  }
  return (lo + hi) / 2;
}

/// Effective annual rate from a monthly rate, with compounding.
double effectiveAnnualRate(dynamic monthlyRate) {
  final r = math.max(0.0, amountOf(monthlyRate));
  return math.pow(1 + r, 12) - 1.0;
}

/// One object the screen renders directly. method 'diminishing' (default)
/// or 'addon'; rateBasis 'monthly' (default) or 'annual'. Returns the
/// payment, totals, the schedule, and BOTH the nominal and the true
/// effective annual rate so the real cost is never hidden.
Map<String, dynamic> loanSummary(
    dynamic principal, dynamic ratePercent, dynamic months,
    {String method = 'diminishing', String rateBasis = 'monthly'}) {
  final p = math.max(0.0, amountOf(principal));
  final n = _clampMonths(months);
  final chosenMethod = method == 'addon' ? 'addon' : 'diminishing';
  final chosenBasis = rateBasis == 'annual' ? 'annual' : 'monthly';
  final quotedMonthly = chosenBasis == 'annual'
      ? amountOf(ratePercent) / 100 / 12
      : amountOf(ratePercent) / 100;

  double payment, totalInterest, totalPaid;
  List<Map<String, dynamic>> schedule;
  if (chosenMethod == 'addon') {
    final a = addOnLoan(p, quotedMonthly, n);
    payment = a['payment'] as double;
    totalInterest = a['totalInterest'] as double;
    totalPaid = a['totalPaid'] as double;
    // Rebuild a diminishing schedule at the loan's TRUE rate so the row
    // split is honest; the last row absorbs the rounding drift so the
    // interest column reconciles to the add-on headline.
    final eff = effectiveMonthlyRate(p, payment, n);
    schedule = (amortize(p, eff, n)['schedule'] as List)
        .cast<Map<String, dynamic>>();
    final sumInterest = _round2(
        schedule.fold(0.0, (s, row) => s + (row['interest'] as double)));
    final drift = _round2(totalInterest - sumInterest);
    if (schedule.isNotEmpty && drift != 0) {
      final last = schedule.last;
      last['interest'] = _round2((last['interest'] as double) + drift);
      last['payment'] = _round2((last['payment'] as double) + drift);
    }
  } else {
    final am = amortize(p, quotedMonthly, n);
    payment = am['payment'] as double;
    totalInterest = am['totalInterest'] as double;
    totalPaid = am['totalPaid'] as double;
    schedule = (am['schedule'] as List).cast<Map<String, dynamic>>();
  }

  final effMonthly = effectiveMonthlyRate(p, payment, n);
  final effAnnual = effectiveAnnualRate(effMonthly);

  return {
    'principal': p,
    'months': n,
    'method': chosenMethod,
    'payment': payment,
    'totalInterest': totalInterest,
    'totalPaid': totalPaid,
    'quotedMonthlyRate': _round4(quotedMonthly),
    'nominalAnnualRate': _round4(quotedMonthly * 12),
    'effectiveMonthlyRate': _round4(effMonthly),
    'effectiveAnnualRate': _round4(effAnnual),
    'schedule': schedule,
  };
}

/// Interest saved by paying off after `paidMonths` payments, on a
/// diminishing-balance loan (the only kind where early payoff cuts
/// interest).
Map<String, dynamic> payoffSaving(
    dynamic principal, dynamic monthlyRate, dynamic months, dynamic paidMonths) {
  final full = amortize(principal, monthlyRate, months);
  final fullMonths = full['months'] as int;
  final rounded = _jsRound(amountOf(paidMonths));
  final k = math.max(0, math.min(rounded.toInt(), fullMonths));
  if (k >= fullMonths) return {'interestSaved': 0.0, 'balanceCleared': 0.0};
  final schedule = (full['schedule'] as List).cast<Map<String, dynamic>>();
  var interestPaidSoFar = 0.0;
  for (final row in schedule.take(k)) {
    interestPaidSoFar += row['interest'] as double;
  }
  final balanceCleared =
      k > 0 ? schedule[k - 1]['balance'] as double : amountOf(principal);
  return {
    'interestSaved': _round2((full['totalInterest'] as double) - interestPaidSoFar),
    'balanceCleared': _round2(balanceCleared),
  };
}
