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
double spendablePosition(Map<String, dynamic> parts) => _fin(
  amountOf(parts['assets']) -
      amountOf(parts['receivables']) -
      amountOf(parts['liabilities']),
);

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

/// How regular each spending category is across the prior months, so the
/// "Where it went" flag only judges categories you spend on most months. This
/// counts month presence, never pesos, so it stays out of the golden-locked
/// engine: a lump-sum category paid once (rent) or an irregular one (tuition,
/// hospital) is not accused of being "over usual" on the month it naturally
/// lands. Mirrors categoryVsAverage's month window (prior months 1..months),
/// its expense filter, and its label normalization, so the two agree on which
/// label is which.
class CategoryHistory {
  /// label -> how many of the prior months had any spend under it.
  final Map<String, int> monthsSeen;

  /// How many of the prior months had any spending at all (the denominator
  /// categoryVsAverage divides its average by).
  final int activeMonths;

  const CategoryHistory(this.monthsSeen, this.activeMonths);

  /// A category counts as regular when it shows up in at least half the months
  /// that had any activity.
  bool isRegular(String label) {
    if (activeMonths <= 0) return false;
    return (monthsSeen[label] ?? 0) * 2 >= activeMonths;
  }
}

String _monthKeyOf(int year, int month) {
  final d = DateTime(year, month, 1);
  return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';
}

CategoryHistory priorCategoryHistory(
  dynamic transactions,
  DateTime ref, [
  int months = 6,
]) {
  final txs = transactions is List ? transactions : const [];
  final monthsSeen = <String, int>{};
  var activeMonths = 0;
  for (var i = 1; i <= months; i++) {
    final key = _monthKeyOf(ref.year, ref.month - i);
    final seen = <String>{};
    for (final t in txs) {
      if (t is! Map) continue;
      if (t['type'] != 'expense') continue;
      final date = (t['date'] ?? '').toString();
      if (date.length < 7 || date.substring(0, 7) != key) continue;
      final raw = t['label'];
      final label = (raw is String && raw.trim().isNotEmpty)
          ? raw.trim()
          : 'Other';
      seen.add(label);
    }
    if (seen.isNotEmpty) activeMonths += 1;
    for (final l in seen) {
      monthsSeen[l] = (monthsSeen[l] ?? 0) + 1;
    }
  }
  return CategoryHistory(monthsSeen, activeMonths);
}

/// The month-by-month "are you saving or bleeding" read, built on the
/// golden-locked monthlySeries (each entry carries income, expenses, and net).
/// This is polarity over time: how many months you ended ahead, the running
/// total, and the largest swing (so the diverging bars share one scale). Pure
/// presentation math, non-finite guarded.
class NetFlowSummary {
  /// Months that ended net positive (kept more than you spent).
  final int saverMonths;

  /// Months with any income or expense at all (the honest denominator).
  final int activeMonths;

  /// Sum of net across the window: positive means you built up, negative means
  /// you drew down.
  final double totalNet;

  /// Largest absolute monthly net, so every bar scales to the same axis.
  final double maxAbs;

  const NetFlowSummary(
    this.saverMonths,
    this.activeMonths,
    this.totalNet,
    this.maxAbs,
  );
}

NetFlowSummary netFlowSummary(List<Map<String, dynamic>> series) {
  var saver = 0;
  var active = 0;
  var total = 0.0;
  var maxAbs = 0.0;
  for (final m in series) {
    final income = _fin(amountOf(m['income']));
    final expenses = _fin(amountOf(m['expenses']));
    final net = _fin(amountOf(m['net']));
    if (income > 0 || expenses > 0) active += 1;
    if (net > 0) saver += 1;
    total += net;
    final a = net.abs();
    if (a > maxAbs) maxAbs = a;
  }
  return NetFlowSummary(saver, active, _fin(total), maxAbs);
}

/// The busiest and quietest spending weekday, from the golden-locked
/// weekdayPattern (a list of {day: 0=Sun..6=Sat, avg}). Names the peak day so
/// the card gives a decision ("ease up on Fridays"), and the lightest only when
/// at least two days actually carry spend, so a single active day is never
/// dressed up as a pattern. maxAvg scales the bars. Non-finite guarded.
class WeekdayPeak {
  /// 0=Sun..6=Sat for the highest-average day, or -1 when nothing was spent.
  final int peakDay;
  final double peakAvg;

  /// The lightest active day, or -1 when fewer than two days had any spend.
  final int lightDay;
  final double lightAvg;

  /// Largest daily average, so every bar scales to one axis.
  final double maxAvg;

  /// How many weekdays carried any spend at all.
  final int activeDays;

  const WeekdayPeak(
    this.peakDay,
    this.peakAvg,
    this.lightDay,
    this.lightAvg,
    this.maxAvg,
    this.activeDays,
  );
}

WeekdayPeak weekdayPeak(List<Map<String, dynamic>> pattern) {
  var peakDay = -1;
  var peakAvg = 0.0;
  var maxAvg = 0.0;
  var lightDay = -1;
  var lightAvg = double.infinity;
  var active = 0;
  for (final p in pattern) {
    final day = (p['day'] as num?)?.toInt() ?? -1;
    final avg = _fin(amountOf(p['avg']));
    if (avg > maxAvg) maxAvg = avg;
    if (avg > 0) {
      active += 1;
      if (avg > peakAvg) {
        peakAvg = avg;
        peakDay = day;
      }
      if (avg < lightAvg) {
        lightAvg = avg;
        lightDay = day;
      }
    }
  }
  // A lightest day is only meaningful with something to contrast against.
  if (active < 2) {
    lightDay = -1;
    lightAvg = 0.0;
  }
  return WeekdayPeak(peakDay, peakAvg, lightDay, lightAvg, maxAvg, active);
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
