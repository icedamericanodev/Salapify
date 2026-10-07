import 'money.dart';
import 'reports.dart';
import '../../models/models.dart';

/// Reports over TIME: the last few months side by side, and this month's
/// spending day by day against last month's.
///
/// NO NEW MONEY MATHS. Every month here is the existing Reports engine run
/// over an earlier window: the same profile filter, the same "does this
/// entry count" rule, the same calendar-month filter and the same
/// [computePerformance]. So the current month's bar is, by construction, the
/// "This month" figure the Performance tab already prints, and a trend can
/// never tell a person a different story about the same peso than the screen
/// beside it does.
///
/// ONE DELIBERATE DIFFERENCE, and it is the reason this file has its own entry
/// point. `filterByPeriod` KEEPS an entry whose date cannot be read, so that a
/// corrupt date makes a total look wrong rather than quietly shrink it. That
/// is right for one period and wrong for six: the same entry would be counted
/// in EVERY month, six times over. So trends leave undated entries out
/// entirely and report how many they left out, in [TrendSet.undated], so the
/// gap is stated rather than hidden.

/// One calendar month's money in and money out.
class MonthTotals {
  const MonthTotals({
    required this.year,
    required this.month,
    required this.income,
    required this.expenses,
    required this.keptRate,
    required this.cashChange,
  });

  final int year;

  /// 1 to 12.
  final int month;
  final double income;
  final double expenses;

  /// [FinancialPerformance.keptRate] for the month, the same figure the
  /// "You kept" card prints, or null when nothing came in and a rate would
  /// be a division by zero dressed up as a percentage.
  final double? keptRate;

  /// [CashFlow.netCashChange] for the month: the figure the Cash flow tab's
  /// headline prints, from the same call. It is NOT income less expenses:
  /// it leaves out nothing those count, but it sorts them, and the tab's
  /// headline is this figure, so the trend must be too.
  final double cashChange;

  bool get isEmpty => income == 0 && expenses == 0 && cashChange == 0;
}

/// This month's spending to date, day by day, against last month's.
class SpendingPace {
  const SpendingPace({
    required this.thisMonth,
    required this.lastMonth,
    required this.daysInThisMonth,
    this.scheduledLater = 0,
  });

  /// Running total of spending, one value per day from day 1 to TODAY.
  /// Entries dated later this month are scheduled, not spent, and are not on
  /// the line: it answers "how much so far", which is the decision it serves.
  final List<double> thisMonth;

  /// Running total for the WHOLE of last month, one value per day. Drawn in
  /// full behind this month's line, so a person sees where last month ended
  /// up as well as where it stood on the same day.
  final List<double> lastMonth;

  final int daysInThisMonth;

  /// Spending dated LATER this month than today, which the monthly filter,
  /// and so "Money out" and this month's bar, already count and the line
  /// deliberately does not. Named so the screen can say why the line ends
  /// below "Money out" when somebody logs the rent in advance, rather than
  /// leave two figures disagreeing in silence.
  final double scheduledLater;

  /// Today's day of the month.
  int get day => thisMonth.length;

  double get spentSoFar => thisMonth.isEmpty ? 0 : thisMonth.last;

  /// Last month's running total on the same day of the month, or on its last
  /// day when last month was shorter (31 March against a 28 day February).
  double get lastMonthSameDay {
    if (lastMonth.isEmpty) return 0;
    final int i = day < lastMonth.length ? day : lastMonth.length;
    return lastMonth[i - 1];
  }

  /// Positive when spending is AHEAD of last month at the same day.
  double get difference => spentSoFar - lastMonthSameDay;

  /// Whether last month has anything to compare against. A first month of
  /// use has no last month, and "0 more than last month" would be false
  /// comfort rather than a comparison.
  bool get hasLastMonth => lastMonth.isNotEmpty && lastMonth.last > 0;
}

class TrendSet {
  const TrendSet({
    required this.months,
    required this.pace,
    required this.undated,
  });

  /// Oldest first, ending with the current month. Months before the first
  /// one with any entry are left off, so a new user sees two bars rather
  /// than four empty slots and two bars.
  final List<MonthTotals> months;
  final SpendingPace pace;

  /// Entries left out of every trend because their date could not be read.
  final int undated;
}

/// The trends for [profile] as of [now], over the last [monthCount] months.
TrendSet buildTrends({
  required List<Transaction> transactions,
  required DateTime now,
  ProfileEntity? profile,
  int monthCount = 6,
}) {
  // Entity, then validity: the order `buildReports` uses, so the two cannot
  // disagree about which entries exist.
  final List<Transaction> valid = validLedgerEntries(
    filterByProfile(transactions, profile),
  );
  final List<Transaction> dated = <Transaction>[];
  int undated = 0;
  for (final Transaction t in valid) {
    if (DateTime.tryParse(t.date) == null) {
      undated++;
    } else {
      dated.add(t);
    }
  }

  final List<MonthTotals> months = <MonthTotals>[];
  for (int back = monthCount - 1; back >= 0; back--) {
    // The CURRENT month is anchored on [now] itself, exactly as the
    // Performance tab anchors it, so the two run the identical call. A past
    // month is anchored on its own last day, which keeps the engine's run
    // rate (days so far against days in the month) a full month.
    final DateTime anchor = back == 0
        ? now
        : DateTime(now.year, now.month - back + 1, 0);
    // ONE window, read by both engines, the same way `buildReports` feeds
    // Performance and Cash flow from one scoped list.
    final List<Transaction> window = filterByPeriod(
      dated,
      ReportPeriod.monthly,
      anchor,
    );
    final FinancialPerformance f = computePerformance(window, anchor);
    months.add(
      MonthTotals(
        year: anchor.year,
        month: anchor.month,
        income: f.totalIncome,
        expenses: f.totalExpenses,
        keptRate: f.totalIncome > 0 ? f.keptRate : null,
        cashChange: computeCashFlow(window).netCashChange,
      ),
    );
  }
  final int first = months.indexWhere((MonthTotals m) => !m.isEmpty);
  final List<MonthTotals> trimmed = first < 0
      ? <MonthTotals>[]
      : months.sublist(first);

  return TrendSet(months: trimmed, pace: _pace(dated, now), undated: undated);
}

SpendingPace _pace(List<Transaction> dated, DateTime now) {
  final DateTime lastMonthEnd = DateTime(now.year, now.month, 0);
  final int daysThis = DateTime(now.year, now.month + 1, 0).day;

  // Summed in CENTAVOS and only then turned into pesos, so a running total of
  // thirty days cannot drift off the month's figure by a float crumb.
  List<double> running(int year, int month, int days) {
    final List<Money> perDay = List<Money>.filled(days, Money.zero);
    for (final Transaction t in dated) {
      if (t.type != TransactionType.expense) continue;
      final DateTime d = DateTime.parse(t.date);
      if (d.year != year || d.month != month || d.day > days) continue;
      perDay[d.day - 1] = perDay[d.day - 1] + t.amount;
    }
    Money sum = Money.zero;
    return <double>[for (final Money m in perDay) (sum = sum + m).pesos];
  }

  // Everything this month dated after today, summed the same way. With it,
  // the line's end plus this is the month's whole spending figure.
  Money later = Money.zero;
  for (final Transaction t in dated) {
    if (t.type != TransactionType.expense) continue;
    final DateTime d = DateTime.parse(t.date);
    if (d.year == now.year && d.month == now.month && d.day > now.day) {
      later = later + t.amount;
    }
  }

  return SpendingPace(
    thisMonth: running(now.year, now.month, now.day),
    lastMonth: running(lastMonthEnd.year, lastMonthEnd.month, lastMonthEnd.day),
    daysInThisMonth: daysThis,
    scheduledLater: later.pesos,
  );
}
