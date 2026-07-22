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
