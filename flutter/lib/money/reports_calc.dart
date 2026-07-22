// Derived read-only figures for the Reports screen, kept out of the widget so
// the arithmetic is tested, not eyeballed. Each composes already golden-locked
// statement outputs; these are net-new (no RN engine counterpart, the RN screen
// computes them inline too), so they are covered by unit tests rather than a
// golden replay. Non-finite guarded, matching the formatMoney "stay alive"
// contract.

import 'ledger.dart' show amountOf;

double _fin(double v) => v.isFinite ? v : 0;

/// Spendable position: what you own minus utang owed to you minus what you owe.
/// The conservative net worth if every receivable never lands.
double spendablePosition(Map<String, dynamic> parts) => _fin(amountOf(parts['assets']) -
    amountOf(parts['receivables']) -
    amountOf(parts['liabilities']));

/// Percent of income kept this month. Zero when there is no income to divide by.
int savingsRatePct(double netIncome, double income) {
  if (!(income > 0)) return 0;
  final r = netIncome / income * 100;
  return r.isFinite ? r.round() : 0;
}

/// Cash and near-cash (cash, banks, receivables) minus short-term obligations.
double liquidGap(Map<String, dynamic> bs) =>
    _fin(amountOf(bs['currentAssets']) - amountOf(bs['currentLiabilities']));

/// How much more interest snowball costs than avalanche. Mirrors the RN operand
/// order (snowball minus avalanche) so the two apps never disagree.
double interestSaved(num snowballInterest, num avalancheInterest) =>
    _fin(snowballInterest.toDouble() - avalancheInterest.toDouble());

/// This month's spending measured against the user's usual month. Built on the
/// golden-locked monthlySeries (oldest-first, the last entry is the focus
/// month). "usual" averages expenses over the PRIOR months that actually had
/// spending, so one month of history is not diluted into a fake "below usual"
/// verdict. "expected" paces that usual to how far into the month we are, so a
/// partial current month is compared fairly. Net-new presentation math with no
/// RN counterpart, covered by unit tests and non-finite guarded.
class SpendCompare {
  /// Expenses logged in the focus month so far.
  final double current;

  /// Average full-month expenses of the prior active months.
  final double usual;

  /// usual scaled by how far into the month we are (1.0 for a complete month).
  final double expected;

  /// How many prior months fed the average. Zero means no basis to compare.
  final int priorMonths;

  const SpendCompare(this.current, this.usual, this.expected, this.priorMonths);

  bool get hasHistory => priorMonths > 0;

  /// Percent above (positive) or below (negative) the pace-adjusted expected
  /// spend. Zero when there is nothing to compare against.
  int get pctVsExpected {
    if (!(expected > 0)) return 0;
    final r = (current / expected - 1) * 100;
    return r.isFinite ? r.round() : 0;
  }
}

/// [series] is monthlySeries output (oldest first, last = focus month). [frac]
/// is how far into the focus month we are: pass the day fraction for the
/// current month, or 1.0 for a complete past month.
SpendCompare spendingVsUsual(List<Map<String, dynamic>> series, double frac) {
  if (series.isEmpty) return const SpendCompare(0, 0, 0, 0);
  // Floor at 0 so a net-negative month (refunds entered as negative expenses)
  // reads as zero spent, matching the bar, instead of a nonsensical "below".
  final raw = _fin(amountOf(series.last['expenses']));
  final current = raw > 0 ? raw : 0.0;
  var sum = 0.0;
  var active = 0;
  for (var i = 0; i < series.length - 1; i++) {
    final e = _fin(amountOf(series[i]['expenses']));
    if (e > 0) {
      sum += e;
      active += 1;
    }
  }
  final usual = active > 0 ? sum / active : 0.0;
  final f = frac.isFinite ? frac.clamp(0.0, 1.0) : 1.0;
  return SpendCompare(current, usual, usual * f, active);
}
