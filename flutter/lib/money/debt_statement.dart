// The consolidated debt statement, f4.66. One honest place that gathers every
// debt a person has entered, cards, BNPL and loans, into a single overview they
// can read on screen and export to PDF.
//
// It is NOT a bank statement and never claims to be one. Every number is
// composed from the SAME golden-locked engines the rest of the app trusts, from
// the figures the person entered themselves, offline:
//   - total owed is the sum of each debt's remaining,
//   - total minimum due is the sum of each minimum (capped at what is owed),
//   - the estimated monthly interest is the sum of monthlyInterest,
//   - overall card utilization is creditUtilization's overall ratio,
//   - each due date is bankDueDate (weekend and PH holiday adjusted),
//   - the "on the minimums" payoff line is debtFreeProjection at extra 0.
// It invents no number of its own, so it can never disagree with the Debts
// screen, and it carries no fabricated badge (no "verified", no "encrypted
// ledger", no regulator registration): those would be claims Salapify cannot
// make.

import 'commitments.dart' show bankDueDate;
import 'credit_utilization.dart' show creditUtilization, UtilizationBand;
import 'debtmath.dart' show debtFreeProjection, monthlyInterest;
import 'ledger.dart' show amountOf;

/// The stored machine type as words a person reads. Public so the statement
/// screen and PDF share one mapping.
String debtTypeLabel(dynamic type) {
  final t = (type ?? '').toString();
  const map = {
    'credit card': 'Credit card',
    'bnpl': 'BNPL (pay later)',
    'personal loan': 'Personal loan',
    'mortgage': 'Mortgage',
    'auto': 'Auto loan',
    'short term': 'Short-term loan',
    'long term': 'Long-term loan',
    'insurance': 'Insurance',
    'other': 'Other',
  };
  if (map.containsKey(t)) return map[t]!;
  return t.isEmpty ? 'Debt' : '${t[0].toUpperCase()}${t.substring(1)}';
}

String _iso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// A safe display name for a debt: an ordinary label ("BDO Titanium") is left
/// alone, but a name a person typed as a card NUMBER ("1234 5678 9012 3456") is
/// masked to its last four before it ever reaches a screen or a shared PDF. The
/// stored name is never changed; this only affects rendering, and it is the
/// legal-review guardrail against a full PAN leaking through a debt name.
String maskDebtName(String name) {
  final digits = name.replaceAll(RegExp(r'\D'), '');
  if (digits.length < 7) return name;
  final last4 = digits.substring(digits.length - 4);
  final label = name.replaceAll(RegExp(r'[\d]'), ' ').replaceAll(
    RegExp(r'\s+'),
    ' ',
  ).trim();
  final prefix = label.isEmpty ? 'Card' : label;
  // Plain ASCII "ending 4291", not a bullet run: the PDF's bundled font cannot
  // draw a U+2022 dot and would print a box, and "ending 4291" reads clearly on
  // both the screen and the PDF while dropping every digit but the last four.
  return '$prefix ending $last4';
}

/// One row of the statement: a single debt, read straight from the stored blob.
class DebtStatementRow {
  final String name;
  final String typeLabel;
  final double balance;

  /// The minimum due this cycle: the entered minimum capped at what is owed,
  /// or null when no minimum was saved (shown as a dash, never a fake zero).
  final double? minDue;

  /// The next bank-adjusted due date as ISO, or null with no schedule.
  final String? dueISO;

  /// Nominal annual rate, monthlyRate x 12, or null when no rate was entered.
  /// NOT an APR/EIR: it does not compound and excludes fees. The presentation
  /// layer must never label it "APR" (legal review, 2026-08-22).
  final double? aprAnnual;

  /// The same rate WITH monthly compounding, ((1 + m/100)^12 - 1) x 100, shown
  /// beside the nominal one so a person sees the honestly-higher yearly cost.
  /// Still excludes fees, so it is not the bank's official EIR either.
  final double? aprEffective;

  const DebtStatementRow({
    required this.name,
    required this.typeLabel,
    required this.balance,
    required this.minDue,
    required this.dueISO,
    required this.aprAnnual,
    required this.aprEffective,
  });
}

/// The whole statement, or null when there is nothing owed to report.
///
/// Returns { rows, totalDebt, totalMinDue, estMonthlyInterest, utilization,
/// utilizationBand, avgApr, payoff } where payoff is the debtFreeProjection map
/// { months, totalInterest, date } at extra 0 (on the minimums), or null when
/// the minimums never win against the interest.
Map<String, dynamic>? consolidatedDebtStatement(
  Map<String, dynamic> data,
  DateTime ref,
) {
  final rawDebts = data['debts'] is List ? data['debts'] as List : const [];
  final owed = <Map<String, dynamic>>[];
  for (final raw in rawDebts) {
    if (raw is! Map) continue;
    final d = raw.cast<String, dynamic>();
    if (amountOf(d['remaining']) > 0) owed.add(d);
  }
  if (owed.isEmpty) return null;

  final rows = <DebtStatementRow>[];
  var totalDebt = 0.0;
  var totalMinDue = 0.0;
  var estMonthlyInterest = 0.0;
  var aprSum = 0.0;
  var aprCount = 0;
  var minsUnset = 0;

  for (final d in owed) {
    final balance = amountOf(d['remaining']);
    totalDebt += balance;
    estMonthlyInterest += monthlyInterest(d);

    final minRaw = amountOf(d['minPayment']);
    double? minDue;
    if (minRaw > 0) {
      minDue = minRaw < balance ? minRaw : balance;
      totalMinDue += minDue;
    } else {
      minsUnset += 1;
    }

    final rate = amountOf(d['monthlyRate']);
    double? apr;
    double? aprEff;
    if (rate > 0) {
      apr = rate * 12;
      // Monthly compounding, so a 3%/month card reads ~42.6% a year, not 36%.
      aprEff = ((_pow1p(rate / 100, 12)) - 1) * 100;
      aprSum += apr;
      aprCount += 1;
    }

    final bd = bankDueDate(d, ref);
    final name = (d['name'] is String && (d['name'] as String).trim().isNotEmpty)
        ? (d['name'] as String).trim()
        : 'Debt';

    rows.add(
      DebtStatementRow(
        name: name,
        typeLabel: debtTypeLabel(d['type']),
        balance: balance,
        minDue: minDue,
        dueISO: bd != null ? _iso(bd.date) : null,
        aprAnnual: apr,
        aprEffective: aprEff,
      ),
    );
  }

  // Worst balance first, so the biggest obligation reads at the top.
  rows.sort((a, b) => b.balance.compareTo(a.balance));

  final radar = creditUtilization(data['debts']);
  final utilization = radar?['overall'] as double?;
  final utilizationBand =
      (radar?['overallBand'] as UtilizationBand?) ?? UtilizationBand.none;

  // "On the minimums" payoff, the honest version of the statement warning: the
  // golden-locked projection at no extra payment.
  final payoff = debtFreeProjection(owed, 'avalanche', 0, ref);

  return {
    'rows': rows,
    'totalDebt': totalDebt,
    'totalMinDue': totalMinDue,
    'estMonthlyInterest': estMonthlyInterest,
    'utilization': utilization,
    'utilizationBand': utilizationBand,
    'avgApr': aprCount > 0 ? aprSum / aprCount : null,
    'payoff': payoff,
    'debtCount': rows.length,
    // How many owed debts have no minimum saved, so the total can say "N not
    // set" instead of reading a missing minimum as zero due (bank-officer
    // review, 2026-08-22).
    'minsUnset': minsUnset,
  };
}

/// (1 + x)^n for a small non-negative x and a small integer n, without dart:math
/// so this file stays a pure money module. n is 12 here.
double _pow1p(double x, int n) {
  var v = 1.0;
  for (var i = 0; i < n; i++) {
    v *= (1 + x);
  }
  return v;
}
