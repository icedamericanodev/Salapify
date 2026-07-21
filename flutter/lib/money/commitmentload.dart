// "Spoken-For Sweldo": how much of a typical month's income is already
// committed to recurring bills and debt minimums before a peso is spent on
// anything else. It answers the question that decides whether someone sinks,
// "how much room do I actually have every month," so a new subscription or a
// BNPL installment can be weighed against the room it eats. Pure and offline;
// it composes the golden-locked monthlySeries for the typical-income median,
// and the composition is locked in commitmentload_golden_test.dart against the
// executed RN engine. A mirror, not a promise.

import 'analytics.dart' show monthlySeries;
import 'ledger.dart' show amountOf;

/// Debt types that carry a real monthly minimum; a debt of one of these with
/// money owed but no minimum saved understates the load, so it is flagged
/// rather than counted as zero. Matches surplus.dart's interest-bearing set.
const Set<String> _interestBearingTypes = {
  'credit card',
  'bnpl',
  'personal loan',
  'mortgage',
  'auto',
  'short term',
  'long term',
};

/// At least this many completed months with income before a share is quoted,
/// so one lump (a 13th month, a reimbursement) never sets a fake baseline.
const int _minIncomeMonths = 2;

/// The monthly commitment load. Returns the peso total and its parts, the
/// typical income and the share it eats (null until there are two income
/// months), the money left over, and honesty flags. `applicable` is false
/// when there are no commitments to speak of, so the card stays hidden.
Map<String, dynamic> commitmentLoad(Map<String, dynamic> data, DateTime ref) {
  // Recurring monthly expenses (this app's recurring rows are monthly).
  var recurringTotal = 0.0;
  var recurringCount = 0;
  for (final raw
      in (data['recurring'] is List ? data['recurring'] as List : const [])) {
    if (raw is! Map) continue;
    final r = raw.cast<String, dynamic>();
    if (r['type'] != 'expense') continue;
    final amt = amountOf(r['amount']);
    if (amt > 0) {
      recurringTotal += amt;
      recurringCount += 1;
    }
  }

  // Debt minimums, each capped at what is still owed (min-of-both, matching
  // upcomingDues). A missing minimum on an interest-bearing debt is flagged.
  var minimumsTotal = 0.0;
  var minimumsCount = 0;
  var minimumUnfilled = false;
  for (final raw
      in (data['debts'] is List ? data['debts'] as List : const [])) {
    if (raw is! Map) continue;
    final d = raw.cast<String, dynamic>();
    final remaining = amountOf(d['remaining']);
    if (!(remaining > 0.5)) continue;
    final minPay = amountOf(d['minPayment']);
    if (minPay > 0) {
      minimumsTotal += minPay < remaining ? minPay : remaining;
      minimumsCount += 1;
    } else if (_interestBearingTypes.contains(d['type'])) {
      minimumUnfilled = true;
    }
  }

  final monthlyCommitted = recurringTotal + minimumsTotal;

  // Typical income: median of completed months with income over the last 6,
  // the same discipline emergencyRunway uses for expenses.
  final series = monthlySeries(data['transactions'], 7, ref);
  final incomes = <double>[
    for (final m in series.take(6))
      if ((m['income'] as double) > 0) m['income'] as double,
  ]..sort();
  var typicalIncome = 0.0;
  if (incomes.length >= _minIncomeMonths) {
    final mid = incomes.length ~/ 2;
    typicalIncome = incomes.length.isOdd
        ? incomes[mid]
        : (incomes[mid - 1] + incomes[mid]) / 2;
  }
  final hasIncomeBase = typicalIncome > 0;
  final committedShare =
      hasIncomeBase ? monthlyCommitted / typicalIncome : null;
  final free = hasIncomeBase ? typicalIncome - monthlyCommitted : null;

  return {
    'monthlyCommitted': monthlyCommitted,
    'recurringTotal': recurringTotal,
    'recurringCount': recurringCount,
    'minimumsTotal': minimumsTotal,
    'minimumsCount': minimumsCount,
    'minimumUnfilled': minimumUnfilled,
    'typicalIncome': typicalIncome,
    'hasIncomeBase': hasIncomeBase,
    'committedShare': committedShare,
    'free': free,
    'applicable': monthlyCommitted > 0,
  };
}
