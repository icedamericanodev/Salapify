// Insights: three charts, and the sentence under each one.
//
// 04-screens.md: "Three to five charts, each drawn in border, positive and
// accent under one grammar, each with a sentence under it that contains a
// number. No cards; a section label per chart."
//
// EVERY CHART HAS A SENTENCE, and the sentence is not decoration. A chart
// shows a shape; a person acts on a claim. "Your spending is up" is a shape.
// "You spent PHP2,140 more on food than last month" is something somebody can
// do something about. So no chart ships here without a line of prose carrying
// a number, and each of those numbers comes from the same derivation that drew
// the bars, never from a second pass over the ledger.
//
// WHAT THIS FILE MAY AND MAY NOT DO. It groups, sorts and formats. It does not
// decide money. `monthlySeries` and `netWorthWindow` are golden locked to the
// shipped app and are called rather than reimplemented, and the one derivation
// written fresh here, spending by category, is a sum over stored rows with a
// test pinning it to `budgetSummary`, the engine Plan already trusts. If those
// two ever disagree, Insights and Plan are describing different months.
import '../../core/money/analytics.dart' show monthlySeries;
import '../../core/money/budget.dart' show budgetSummary;
import '../../core/money/format.dart' show formatMoney;
import '../../core/money/ledger.dart' show amountOf;
import '../../core/money/net_worth_history.dart'
    show NetWorthPoint, netWorthHistoryOf, netWorthWindow;
// `isThisMonth` from the golden locked statements.dart, the SAME test the
// budget uses, so Insights and Plan can never disagree about which entries
// belong to this month.
import '../../core/money/statements.dart' show isThisMonth, netWorthParts;
import '../../core/state/visibility.dart' show ownedOnly;

// --------------------------------------------------------------- category

/// One slice of the month's spending.
class CategorySlice {
  const CategorySlice({
    required this.id,
    required this.name,
    required this.icon,
    required this.amount,
    required this.fraction,
  });

  final String id;
  final String name;

  /// The user's own emoji, or empty. Category icons are USER DATA and live in
  /// the backup file, so nothing here restyles them. Only icons Salapify
  /// authors are theme glyphs.
  final String icon;

  final double amount;

  /// Share of the month's total spending, 0 to 1, for the bar length.
  final double fraction;
}

/// Where this month's money actually went, largest first.
///
/// INCLUDES AN UNCATEGORISED BUCKET, and that is the difference between this
/// and the Budget segment's list. `categoryBudgets` deliberately drops a
/// transaction with no `categoryId`, because a category with no id cannot have
/// a cap and cannot earn a budget row. On a chart that claims to show where
/// the month went, dropping those rows makes the bars add up to less than the
/// month and there is nothing on screen to explain the gap. The fast-log sheet
/// can and does write entries with no category, so this is the common case
/// rather than a corner.
List<CategorySlice> spendingByCategory(
  Map<String, dynamic> data,
  DateTime ref,
) {
  final names = <String, String>{};
  final icons = <String, String>{};
  for (final c
      in (data['categories'] is List ? data['categories'] as List : const [])) {
    if (c is! Map) continue;
    final id = c['id'];
    if (id is! String || id.isEmpty) continue;
    names[id] = (c['name'] ?? '').toString();
    icons[id] = (c['icon'] ?? '').toString();
  }

  const uncategorised = '__none__';
  final totals = <String, double>{};
  for (final t
      in (data['transactions'] is List
          ? data['transactions'] as List
          : const [])) {
    if (t is! Map) continue;
    if (t['type'] != 'expense') continue;
    if (!isThisMonth(t['date'], ref)) continue;
    final raw = t['categoryId'];
    // A category id pointing at a category that no longer exists is the same
    // situation as no id at all: there is no name to print. Both fall into the
    // same bucket rather than one of them rendering a blank label.
    final id = (raw is String && names.containsKey(raw)) ? raw : uncategorised;
    totals[id] = (totals[id] ?? 0) + amountOf(t['amount']);
  }

  final total = totals.values.fold(0.0, (a, b) => a + b);
  final ids = totals.keys.toList()
    ..sort((a, b) {
      final byAmount = totals[b]!.compareTo(totals[a]!);
      // Ties break on the id so the order is stable between builds. Without
      // it two equal categories swap places on every rebuild, which on screen
      // looks like the list twitching for no reason.
      return byAmount != 0 ? byAmount : a.compareTo(b);
    });

  return [
    for (final id in ids)
      CategorySlice(
        id: id,
        name: id == uncategorised ? 'Uncategorised' : (names[id] ?? 'Other'),
        icon: id == uncategorised ? '' : (icons[id] ?? ''),
        amount: totals[id]!,
        fraction: total > 0 ? totals[id]! / total : 0.0,
      ),
  ];
}

/// The line under the category chart.
String categorySentence(List<CategorySlice> slices) {
  if (slices.isEmpty) return 'Nothing spent yet this month.';
  final top = slices.first;
  final pct = (top.fraction * 100).round();
  if (slices.length == 1) {
    return 'Everything this month went to ${top.name}, '
        '${formatMoney(top.amount)}.';
  }
  return '${top.name} is your biggest this month at '
      '${formatMoney(top.amount)}, $pct per cent of what you spent.';
}

// -------------------------------------------------------------- in vs out

/// One month of money in and money out.
class MonthBar {
  const MonthBar({
    required this.label,
    required this.income,
    required this.expenses,
  });

  final String label;
  final double income;
  final double expenses;

  double get net => income - expenses;
}

/// The last [months] months, oldest first.
///
/// Straight from the golden locked `monthlySeries`, which already knows the
/// one rule that is easy to get wrong here: utang COLLECTED is not income. A
/// friend repaying you is money arriving that was already yours, and counting
/// it as income makes a month you got paid back look like a month you earned.
List<MonthBar> inVersusOut(
  Map<String, dynamic> data,
  DateTime ref, {
  int months = 6,
}) => [
  for (final m in monthlySeries(data['transactions'], months, ref))
    MonthBar(
      label: (m['label'] ?? '').toString(),
      income: amountOf(m['income']),
      expenses: amountOf(m['expenses']),
    ),
];

/// The line under the in-versus-out chart.
///
/// It names THIS MONTH rather than an average across the window, because an
/// average over six months hides the one fact somebody can act on today. The
/// comparison is to the months BEFORE it, so a month that has barely started
/// is not held up against six complete ones without saying so.
String inVersusOutSentence(List<MonthBar> bars) {
  if (bars.isEmpty) return 'Not enough history yet.';
  final now = bars.last;
  if (now.income <= 0 && now.expenses <= 0) {
    return 'Nothing recorded this month yet.';
  }

  final net = now.net;
  if (bars.length == 1) {
    return net >= 0
        ? 'This month you are ${formatMoney(net)} ahead.'
        : 'This month you are ${formatMoney(-net)} behind.';
  }

  // ONLY MONTHS THAT ACTUALLY HAPPENED, and this is the correction the first
  // render forced. `monthlySeries` returns six months whether or not the
  // ledger has anything in them, so a brand new user's five empty months
  // averaged to zero and the screen told them, in the accusing voice of a
  // comparison, that they had spent 6,045.50 "more than your usual month".
  // They have no usual month. An average over months with no data is not a
  // small inaccuracy, it is a claim about a history that does not exist, and
  // the net worth chart three sections down already refuses to make it.
  final earlier = [
    for (final b in bars.sublist(0, bars.length - 1))
      if (b.income > 0 || b.expenses > 0) b,
  ];
  if (earlier.isEmpty) {
    return net >= 0
        ? 'This month you are ${formatMoney(net)} ahead. Once there are a few '
              'months here, this compares them.'
        : 'This month you are ${formatMoney(-net)} behind. Once there are a '
              'few months here, this compares them.';
  }

  final avgOut = earlier.fold(0.0, (t, b) => t + b.expenses) / earlier.length;
  final diff = now.expenses - avgOut;

  // A month in progress compared against completed months is not a like for
  // like comparison, so the sentence says "so far" rather than pretending the
  // month is done.
  if (diff.abs() < 1) {
    return net >= 0
        ? 'So far this month you are ${formatMoney(net)} ahead, and spending '
              'is about the same as usual.'
        : 'So far this month you are ${formatMoney(-net)} behind, and '
              'spending is about the same as usual.';
  }
  return diff > 0
      ? 'So far this month you have spent ${formatMoney(diff)} more than your '
            'usual month.'
      : 'So far this month you have spent ${formatMoney(-diff)} less than '
            'your usual month.';
}

// -------------------------------------------------------------- net worth

/// The net worth points to plot, oldest first.
///
/// The final point is the LIVE figure, not a stored snapshot, so the end of
/// the line always equals the number on the Accounts hero. It is computed off
/// `ownedOnly`, exactly as that hero is, or somebody who marked an account as
/// not theirs would see a chart ending somewhere the rest of the app does not
/// agree with.
List<NetWorthPoint> netWorthPoints(
  Map<String, dynamic> data,
  DateTime ref, {
  int months = 12,
}) {
  final month =
      '${ref.year.toString().padLeft(4, '0')}-'
      '${ref.month.toString().padLeft(2, '0')}';
  final live = amountOf(netWorthParts(ownedOnly(data))['netWorth']);
  return netWorthWindow(netWorthHistoryOf(data), month, live, months: months);
}

/// The line under the net worth chart.
///
/// HONEST ABOUT THIN DATA. Salapify records one snapshot a month, so a new
/// user has exactly one point, and a single point is not a trend. Drawing a
/// flat line through it and calling it stable would be inventing a history
/// they do not have.
String netWorthSentence(List<NetWorthPoint> points) {
  if (points.isEmpty) return 'No net worth recorded yet.';
  if (points.length == 1) {
    return '${formatMoney(points.first.value)} today. Salapify saves one '
        'figure a month, so the line starts filling in next month.';
  }
  final first = points.first.value;
  final last = points.last.value;
  final change = last - first;
  final span = points.length;

  if (change.abs() < 1) {
    return 'About the same as $span months ago, ${formatMoney(last)}.';
  }
  return change > 0
      ? 'Up ${formatMoney(change)} over $span months, now '
            '${formatMoney(last)}.'
      : 'Down ${formatMoney(-change)} over $span months, now '
            '${formatMoney(last)}.';
}

// ------------------------------------------------------------------ total

/// What the whole month's spending came to.
///
/// Read from `budgetSummary`, the golden locked engine the Plan screen already
/// shows, rather than summed here. Two screens quoting one month is exactly
/// the shape that produced the Home versus Plan contradiction, and the fix
/// there was the same one: read the figure, do not re-derive it.
double monthSpend(Map<String, dynamic> data, DateTime ref) =>
    amountOf(budgetSummary(data, ref)['spent']);
