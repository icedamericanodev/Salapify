import '../../models/models.dart';
import 'reports.dart' show validLedgerEntries;
import 'money.dart';

/// The Plan engine, ported from archive/prototype-google-ai-studio/src/components/PlanScreen.tsx.
///
/// Budgets, goals and upcoming bills. Small arithmetic, and all of it feeds
/// numbers a person makes decisions on, so it is vector-locked like every
/// other engine here.
///
/// ONE DELIBERATE DIVERGENCE, and it is a money change the founder approved
/// explicitly on 2026-09-18 rather than something taken quietly. See
/// [computeBudgets] for what changed and why the prototype's version is wrong.

/// One budget line with its spending worked out.
class BudgetStatus {
  const BudgetStatus({
    required this.category,
    required this.emoji,
    required this.limit,
    required this.spent,
    required this.remaining,
    required this.percent,
    required this.entryCount,
  });

  final String category;
  final String emoji;

  // All three in whole centavos, with Budget.limit. A status whose limit was
  // exact and whose spent was a float sum put the two sides of "are you over"
  // on different footings, which is the comparison this card exists to make.
  final Money limit;
  final Money spent;

  /// Can go NEGATIVE, unlike the prototype's display which clamps the bar.
  /// Somebody 1,200 over their food budget needs to see the 1,200.
  final Money remaining;

  /// 0 to 100, capped. The prototype caps it so the progress bar cannot
  /// overflow its track; [isOver] is what actually says you went past.
  final int percent;

  /// How many entries make up [spent]. Without it a surprising total is a
  /// mystery: one big shop and ten small ones look identical.
  final int entryCount;

  bool get isOver => remaining.isNegative;

  /// Close enough to matter but not past it. The prototype's threshold.
  bool get isNear => percent >= 80 && !isOver;

  /// The three states a budget can be in, named once so the screen and any
  /// test agree about which is which.
  BudgetHealth get health => isOver
      ? BudgetHealth.over
      : isNear
      ? BudgetHealth.near
      : BudgetHealth.onTrack;
}

enum BudgetHealth { onTrack, near, over }

/// Every budget, with its spending for the CURRENT MONTH.
///
/// TWO CHANGES FROM THE PROTOTYPE, both approved by the founder on
/// 2026-09-18 when the alternatives were put to them with the figures:
///
/// 1. EXCLUDED AND DUPLICATE ENTRIES ARE IGNORED. The prototype counts every
///    matching expense whatever its status, so the fixture's duplicate Meralco
///    charge, the one marked "charged twice, this one is not mine to pay",
///    pushed Bills & Utilities to 5,680 of 6,500 and into "watch closely"
///    when the truth was 2,840. Everywhere else in this app an excluded entry
///    never reaches a total, so budgets were the single place it did.
///
/// 2. ONLY THIS MONTH COUNTS. The prototype sums all time against a limit
///    that never resets, so every budget creeps past its cap forever once the
///    app has more than a month of data. A monthly limit that only ever goes
///    up is not a limit.
///
/// The category match is case-insensitive, which IS the prototype's, and it
/// is why a category rename drifts silently rather than loudly. The integrity
/// test in test/data is what guards that.
List<BudgetStatus> computeBudgets({
  required List<Budget> budgets,
  required List<Transaction> transactions,
  required DateTime now,
}) {
  final List<Transaction> countable = validLedgerEntries(transactions)
      .where((Transaction t) => t.type == TransactionType.expense)
      .where((Transaction t) {
        final DateTime? d = DateTime.tryParse(t.date);
        // An unparseable date is KEPT, matching how the Reports period filter
        // treats one: a corrupt date should make a total look wrong and get
        // investigated, not quietly shrink it.
        if (d == null) return true;
        return d.year == now.year && d.month == now.month;
      })
      .toList();

  return budgets.map((Budget b) {
    final List<Transaction> mine = countable
        .where(
          (Transaction t) =>
              t.category.toLowerCase() == b.category.toLowerCase(),
        )
        .toList();

    final Money spent = mine.fold<Money>(
      Money.zero,
      (Money s, Transaction t) => s + t.amount,
    );

    // Guard the divide. A zero limit is not reachable through the UI today,
    // and a budget screen is not worth an Infinity on somebody's phone.
    //
    // The percentage divides CENTAVOS by CENTAVOS, which is the same ratio
    // as pesos by pesos and avoids two conversions on the way.
    final int percent = !b.limit.isPositive
        ? 0
        : (spent.centavos / b.limit.centavos * 100).round().clamp(0, 100);

    return BudgetStatus(
      category: b.category,
      emoji: b.emoji,
      limit: b.limit,
      spent: spent,
      remaining: b.limit - spent,
      percent: percent,
      entryCount: mine.length,
    );
  }).toList();
}

/// The totals across every budget.
class BudgetTotals {
  const BudgetTotals({
    required this.totalLimit,
    required this.totalSpent,
    required this.leftToSpend,
    required this.overCount,
    required this.nearCount,
  });

  final Money totalLimit;
  final Money totalSpent;

  /// Floored at zero, which is the prototype's. The headline answers "how
  /// much have I got left", and a negative answer to that question is better
  /// said by the per-budget rows that are actually over.
  final Money leftToSpend;

  final int overCount;
  final int nearCount;

  bool get allOnTrack => overCount == 0 && nearCount == 0;
}

BudgetTotals computeBudgetTotals(List<BudgetStatus> rows) {
  final Money limit = rows.fold<Money>(
    Money.zero,
    (Money s, BudgetStatus b) => s + b.limit,
  );
  final Money spent = rows.fold<Money>(
    Money.zero,
    (Money s, BudgetStatus b) => s + b.spent,
  );
  return BudgetTotals(
    totalLimit: limit,
    totalSpent: spent,
    leftToSpend: (limit - spent).isNegative ? Money.zero : limit - spent,
    overCount: rows.where((BudgetStatus b) => b.isOver).length,
    nearCount: rows.where((BudgetStatus b) => b.isNear).length,
  );
}

/// One goal with its progress worked out.
class GoalStatus {
  const GoalStatus({
    required this.goal,
    required this.percent,
    required this.remaining,
    required this.monthsAtCurrentRate,
  });

  final Goal goal;

  /// 0 to 100, capped, the prototype's.
  final int percent;

  /// Floored at zero: an overfunded goal is finished, not negatively short.
  final Money remaining;

  /// How many months of the goal's own monthly target are still needed, or
  /// null when the target is zero and the question has no answer.
  ///
  /// NOT in the prototype. It is the number somebody actually wants ("when
  /// do I get there") and it costs one division, but it is rounded UP on
  /// purpose: 4.2 months means five payments, and a goal tracker that says
  /// four is a goal tracker that lies about the last one.
  final int? monthsAtCurrentRate;

  bool get isComplete => remaining <= Money.zero;
}

List<GoalStatus> computeGoals(List<Goal> goals) {
  return goals.map((Goal g) {
    final Money remaining = g.targetAmount - g.currentAmount;

    // ratioTo returns null on a zero target rather than an infinity, which is
    // the same guard the old "targetAmount <= 0" branch gave, now stated once
    // in the type instead of at every call site.
    final double? share = g.currentAmount.ratioTo(g.targetAmount);
    final int percent = share == null ? 0 : (share * 100).round().clamp(0, 100);

    int? months;
    if (remaining.isPositive && g.monthlyTarget.isPositive) {
      // Still a division of two centavo counts, which is a ratio and so a
      // double by nature. Rounded UP, unchanged: 4.2 months means five
      // payments, and a goal tracker that says four lies about the last one.
      months = (remaining.centavos / g.monthlyTarget.centavos).ceil();
    }

    return GoalStatus(
      goal: g,
      percent: percent,
      remaining: remaining.isNegative ? Money.zero : remaining,
      monthsAtCurrentRate: months,
    );
  }).toList();
}

/// What the Bills and Payables segment totals.
class UpcomingTotals {
  const UpcomingTotals({
    required this.totalOut,
    required this.totalIn,
    required this.billCount,
  });

  /// Money leaving. Payday and anything flagged income are NOT in here, which
  /// the prototype's own headline gets wrong: it sums every row including the
  /// 32,500 payday, so "Total Scheduled Bills" reads 38,029 when the bills
  /// come to 5,529. Splitting the two is the divergence, and it is a
  /// presentation fix rather than a money one: no stored figure changes and
  /// both numbers are shown.
  final Money totalOut;

  final Money totalIn;
  final int billCount;
}

UpcomingTotals computeUpcomingTotals(List<UpcomingItem> items) {
  final Iterable<UpcomingItem> unpaid = items.where(
    (UpcomingItem u) => !u.isPaid,
  );
  final Iterable<UpcomingItem> out = unpaid.where(
    (UpcomingItem u) => !u.countsAsIncome,
  );

  return UpcomingTotals(
    totalOut: out.fold<Money>(
      Money.zero,
      (Money s, UpcomingItem u) => s + u.amount,
    ),
    totalIn: unpaid
        .where((UpcomingItem u) => u.countsAsIncome)
        .fold<Money>(Money.zero, (Money s, UpcomingItem u) => s + u.amount),
    billCount: out.length,
  );
}

/// Applies a contribution to a goal, returning the new list.
///
/// Clamps at the target rather than letting a goal read 120% funded. Money
/// beyond the target is not lost anywhere, because a goal's currentAmount is
/// a record of intent rather than an account balance, but a progress bar past
/// its own end is a display nobody trusts again.
List<Goal> applyGoalContribution(
  List<Goal> goals,
  String goalId,
  Money amount,
) {
  if (!amount.isPositive) return goals;
  return goals.map((Goal g) {
    if (g.id != goalId) return g;
    final Money next = g.currentAmount + amount;
    return Goal(
      id: g.id,
      name: g.name,
      emoji: g.emoji,
      targetAmount: g.targetAmount,
      currentAmount: next > g.targetAmount ? g.targetAmount : next,
      targetDate: g.targetDate,
      monthlyTarget: g.monthlyTarget,
    );
  }).toList();
}

/// Replaces one budget's limit, returning the new list.
///
/// A limit of zero or less is REFUSED rather than stored. It would make every
/// percentage meaningless and reads as "I have no budget for this", which is
/// deleting the budget, a different action with different consequences.
///
/// The `isFinite` guard that used to stand here is GONE, and that is not a
/// loosening: [Money] cannot hold a NaN or an Infinity at all, because
/// `Money.fromDouble` refuses one at the boundary where a typed figure or a
/// backup becomes money. The check moved rather than disappeared.
List<Budget> applyBudgetLimit(
  List<Budget> budgets,
  String category,
  Money limit,
) {
  if (!limit.isPositive) return budgets;
  return budgets.map((Budget b) {
    if (b.category != category) return b;
    return Budget(category: b.category, limit: limit, emoji: b.emoji);
  }).toList();
}

/// Adds a budget for one category, returning the new list.
///
/// Until 2026-10-08 the app could not do this at all: budgets arrived with
/// the example data, and once that was cleared there was no way back to
/// having one, though D19 calls per category budgets free and core.
///
/// Refused, by returning the SAME list, for the same reasons a limit edit is
/// refused, plus one of its own:
///   - a limit of zero or less, which means "no budget", not a budget;
///   - an empty category name;
///   - a category that already has a budget. Two budgets for one category
///     would each count the same spending, and Plan's "left to spend"
///     would subtract it twice.
///
/// New budgets go at the END, so the existing order does not shuffle under
/// somebody's thumb. Plan sorts by health for display anyway.
List<Budget> applyNewBudget(
  List<Budget> budgets, {
  required String category,
  required String emoji,
  required Money limit,
}) {
  if (!limit.isPositive) return budgets;
  if (category.trim().isEmpty) return budgets;
  if (budgets.any((Budget b) => b.category == category)) return budgets;
  return <Budget>[
    ...budgets,
    Budget(category: category, limit: limit, emoji: emoji),
  ];
}

/// The categories a new budget can be set for: spending categories that do
/// not already have one. Income categories are left out, because a cap on
/// money coming IN is not a budget.
List<CategoryInfo> budgetableCategories(
  List<CategoryInfo> categories,
  List<Budget> budgets,
) {
  final Set<String> taken = <String>{
    for (final Budget b in budgets) b.category,
  };
  return <CategoryInfo>[
    for (final CategoryInfo c in categories)
      if (c.kind != CategoryKind.income && !taken.contains(c.name)) c,
  ];
}

/// Parses a typed amount the way every other input in the app does.
///
/// Shared with the Log sheet's rule rather than reimplemented: commas allowed,
/// NaN and infinity refused, zero and negatives refused.
double? parsePlanAmount(String raw) {
  final double? v = double.tryParse(raw.replaceAll(',', '').trim());
  if (v == null || !v.isFinite || v <= 0) return null;
  return v;
}
