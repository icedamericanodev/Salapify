import 'dart:math' as math;

import 'format.dart';
import 'plan.dart';
import '../../models/models.dart';

/// Five questions about somebody's money, answered only where they can be.
///
/// Founder decision, 2026-09-20: build five indicators rather than the
/// prototype's twelve. The five, their order and most of the reasoning are
/// the financial coach's, checked against the code before any of it was
/// written.
///
/// ## Why not twelve
///
/// With the prototype's invented figures removed, a new user has data for
/// about two of its twelve, so ten cards go grey and the screen reads as a
/// list of things they have failed to do. With the inventions IN, it is
/// worse: seven or eight coloured severity dots computed from numbers nobody
/// entered, which is not a diagnosis, it is an accusation delivered with
/// false precision. Twelve dots also destroy the signal. If three things are
/// red, nothing is urgent.
///
/// ## The order is the product
///
/// It is fixed, and it is the order a planner actually works in: can I get
/// to payday, how much of my pay is already promised, do I have a cushion,
/// am I keeping any of it, am I inside my own limits. A fixed order is what
/// stops an optimisation note ever rendering above a liquidity warning.
///
/// ## Nothing here invents an input
///
/// The prototype's engine stands 28,000 a month in for spending and 65,000
/// for salary when it has neither, and four of its twelve insights are
/// computed off those. Under founder direction D19 every screen has to work
/// for somebody who installed the app ten seconds ago, and that is exactly
/// the person those fallbacks fire for.
///
/// So an indicator with a missing input is UNMEASURED: it names the input,
/// offers the one tap that supplies it, and shows no figure, no colour and
/// no zero. A zero is a measurement, and a progress bar at nought on the
/// first visit reads as something already going wrong rather than as a
/// starting line.

/// The one tap that would let an unmeasured indicator be measured.
enum HealthNeed { setPayday, logSpending, addBill, startCushion, setBudget }

/// How a measured indicator reads. Never colour alone: every tone has words
/// on the card beside it.
enum HealthTone { good, watch, tight }

class HealthIndicator {
  const HealthIndicator._({
    required this.id,
    required this.question,
    this.reading,
    this.detail,
    this.missing,
    this.need,
    this.tone,
  });

  /// A measured answer.
  factory HealthIndicator.measured({
    required String id,
    required String question,
    required String reading,
    required HealthTone tone,
    String? detail,
  }) => HealthIndicator._(
    id: id,
    question: question,
    reading: reading,
    detail: detail,
    tone: tone,
  );

  /// No answer, and what is missing.
  factory HealthIndicator.unmeasured({
    required String id,
    required String question,
    required String missing,
    required HealthNeed need,
  }) => HealthIndicator._(
    id: id,
    question: question,
    missing: missing,
    need: need,
  );

  final String id;

  /// What the card asks, in the person's own words rather than a metric name.
  /// "Will I make it to payday" is a question somebody has; "Cash runway" is
  /// a term they would have to learn first.
  final String question;

  final String? reading;
  final String? detail;
  final String? missing;
  final HealthNeed? need;
  final HealthTone? tone;

  bool get measured => reading != null;
}

class HealthReport {
  const HealthReport(this.indicators);

  /// Always five, always in the same order.
  final List<HealthIndicator> indicators;

  List<HealthIndicator> get measured =>
      indicators.where((HealthIndicator i) => i.measured).toList();

  List<HealthIndicator> get unmeasured =>
      indicators.where((HealthIndicator i) => !i.measured).toList();

  bool get anyMeasured => measured.isNotEmpty;

  /// True when there is nothing recorded at all.
  ///
  /// The screen shows ONE line and a couple of taps in this state rather
  /// than five grey cards, which read as five chores.
  bool get nothingYet => measured.isEmpty;

  /// The tightest measured indicator, or null.
  ///
  /// It is the FIRST one in priority order at the worst tone, not merely the
  /// worst: two indicators at `tight` means the liquidity one is the answer,
  /// because it is the one happening soonest.
  HealthIndicator? get needsAttention {
    for (final HealthTone t in <HealthTone>[
      HealthTone.tight,
      HealthTone.watch,
    ]) {
      for (final HealthIndicator i in indicators) {
        if (i.tone == t) return i;
      }
    }
    return null;
  }
}

/// How many separate days must carry a logged expense before a daily pace is
/// a measurement rather than a guess.
///
/// A pace is a rate over a period, so what it needs is COVERAGE of the
/// period, not a count of entries: five receipts from one Saturday say
/// nothing about a month. Five separate days is a judgement rather than a
/// law, and it is named here so it can be argued with instead of being a
/// number buried in a condition.
const int paceNeedsDays = 5;

/// A buffer is comfortable when it covers this many days of the person's own
/// spending, beyond what is already committed.
///
/// PROPORTIONAL, not a peso figure. The prototype uses 5,000, which cannot
/// mean the same thing on an 18,000 salary and an 80,000 one: at the low end
/// almost nobody ever clears it, so the indicator sits permanently amber and
/// gets ignored, and at the high end it reads green while somebody is
/// genuinely tight.
const int bufferComfortableDays = 3;

/// Where a lender starts to hesitate, as a share of take-home pay.
///
/// These bracket real Philippine consumer underwriting practice rather than
/// any published rule: no regulator fixes a debt service ratio for
/// individuals, and the prototype's "safe banking guidelines" presents a
/// rule of thumb as one. The copy says whose rule it is.
const int debtShareComfortable = 25;
const int debtShareTight = 40;

/// The cushion ladder, in pesos and then in months of spending.
///
/// Zero to three months is too far to feel any progress, which is why people
/// abandon it. The first rung is a figure that covers a tooth, a tyre or a
/// hospital deposit, and is reachable from a single 13th month.
const double cushionFirstRung = 10000;

HealthReport runHealthCheck({
  required List<Transaction> transactions,
  required List<Account> accounts,
  required List<Budget> budgets,
  required List<Goal> goals,
  required List<BillItem> bills,
  required List<InstallmentPlan> installments,
  required PaydayCycle payday,
  required DateTime now,
}) {
  final _Measures m = _Measures(transactions, accounts, installments, now);

  return HealthReport(<HealthIndicator>[
    _payday(m, payday, bills, installments, now),
    _promised(m, payday, installments),
    _cushion(m, goals),
    _keeping(m),
    _limits(budgets, transactions, now),
  ]);
}

/// Everything the five share, worked out once.
class _Measures {
  _Measures(this.transactions, this.accounts, this.installments, this.now);

  final List<Transaction> transactions;
  final List<Account> accounts;
  final List<InstallmentPlan> installments;
  final DateTime now;

  /// Money that can actually be spent. A credit limit is not money you have.
  late final double liquid = accounts
      .where((Account a) => a.isLiquid)
      .fold<double>(0, (double s, Account a) => s + a.balanceInPhp);

  late final List<Transaction> _counted = transactions
      .where((Transaction t) => t.countsTowardTotals)
      .toList();

  late final List<Transaction> _last30 = _counted.where((Transaction t) {
    if (t.type != TransactionType.expense) return false;
    final DateTime? d = DateTime.tryParse(t.date);
    if (d == null) return false;
    final int days = DateTime(
      now.year,
      now.month,
      now.day,
    ).difference(d).inDays;
    return days >= 0 && days < 30;
  }).toList();

  /// How many separate days carry a logged expense in the window.
  late final int _daysCovered = _last30
      .map((Transaction t) => t.date)
      .toSet()
      .length;

  /// True when there is enough to call a daily pace a measurement.
  bool get paceMeasured => _daysCovered >= paceNeedsDays;

  /// Spending a day, from what was actually logged. NEVER a stand-in.
  late final double dailyPace = _last30.isEmpty
      ? 0
      : _last30.fold<double>(0, (double s, Transaction t) => s + t.amount) / 30;

  /// What the active instalment plans take every month. Real schedules, not
  /// a percentage of anything.
  late final double monthlyInstalments = installments
      .where((InstallmentPlan i) => !i.isSettled)
      .fold<double>(
        0,
        (double s, InstallmentPlan i) => s + i.installmentAmount,
      );

  /// The most instalments any single active plan still has to run.
  late final int longestPlanLeft = installments
      .where((InstallmentPlan i) => !i.isSettled)
      .fold<int>(
        0,
        (int worst, InstallmentPlan i) =>
            math.max(worst, i.totalInstallments - i.paidInstallments),
      );

  /// Net kept in a given month: what came in, less what went out.
  double keptIn(int year, int month) {
    double net = 0;
    for (final Transaction t in _counted) {
      if (t.type == TransactionType.transfer) continue;
      final DateTime? d = DateTime.tryParse(t.date);
      if (d == null || d.year != year || d.month != month) continue;
      net += t.type == TransactionType.income ? t.amount : -t.amount;
    }
    return net;
  }

  /// Whether a month has anything in it at all, so "kept nothing" can be
  /// told apart from "logged nothing".
  bool hasEntriesIn(int year, int month) => _counted.any((Transaction t) {
    final DateTime? d = DateTime.tryParse(t.date);
    return d != null && d.year == year && d.month == month;
  });
}

/// 1. Will I make it to payday.
///
/// The prototype splits this across two insights, the payday crunch and the
/// upcoming bills, which is one question cut in half. What is already
/// committed is the second line of the same card here, because a buffer that
/// ignores Friday's Meralco bill is not a buffer.
HealthIndicator _payday(
  _Measures m,
  PaydayCycle payday,
  List<BillItem> bills,
  List<InstallmentPlan> installments,
  DateTime now,
) {
  const String id = 'payday';
  const String question = 'Will I make it to payday';

  if (!payday.isSet) {
    return HealthIndicator.unmeasured(
      id: id,
      question: question,
      missing: 'Salapify does not know when you get paid yet.',
      need: HealthNeed.setPayday,
    );
  }
  if (!m.paceMeasured) {
    return HealthIndicator.unmeasured(
      id: id,
      question: question,
      missing:
          'There is no spending pace to project yet. Log a few days and '
          'this fills in.',
      need: HealthNeed.logSpending,
    );
  }

  final int days = payday.daysToPayday;

  // Bills falling BEFORE payday, and only those. A bill due next month is
  // not money this cycle has to find.
  final DateTime cutoff = DateTime(
    now.year,
    now.month,
    now.day,
  ).add(Duration(days: days));
  double committed = 0;
  for (final BillItem b in bills) {
    if (b.isPaid) continue;
    final DateTime? due = DateTime.tryParse(b.dueDate);
    if (due == null) continue;
    if (due.isBefore(DateTime(now.year, now.month, now.day))) continue;
    if (due.isAfter(cutoff)) continue;
    committed += b.amount;
  }

  final double needed = m.dailyPace * days + committed;
  final double buffer = m.liquid - needed;
  final double comfortable = m.dailyPace * bufferComfortableDays;

  final HealthTone tone = buffer < 0
      ? HealthTone.tight
      : buffer < comfortable
      ? HealthTone.watch
      : HealthTone.good;

  return HealthIndicator.measured(
    id: id,
    question: question,
    // THE POSITIVE CASE DOES NOT PRINT A PESO FIGURE, and that is a
    // correction made after looking at the rendered screen.
    //
    // It used to read "₱105,303.87 spare over the next 4 days" on the sample
    // ledger, directly under a Home card reading "Safe to spend ₱38,414.00"
    // for the same period. Both were arithmetically right and they differ by
    // sixty seven thousand pesos, because Safe to Spend also reserves debt
    // minimums, instalments and an emergency buffer. Two screens disagreeing
    // about the same month is a defect even when both are defensible, and
    // the one that says the bigger number wins the argument in somebody's
    // head.
    //
    // So this answers its OWN question, which is a yes or a no, and leaves
    // the peso amount of spare money to the one figure that already owns it.
    // A shortfall still carries its size, because how short you are is the
    // whole of that answer and nothing else on any screen reports it.
    reading: buffer < 0
        ? '${formatPeso(buffer.abs())} short, on the pace you are on'
        : 'Covered for the next $days days, on the pace you are on',
    detail: committed > 0
        ? '${formatPeso(committed)} of that is already spoken for by bills '
              'due before then.'
        : null,
    tone: tone,
  );
}

/// 2. How much of my pay is already promised.
///
/// MEASURED, from the instalment schedules the person actually entered. The
/// prototype assumes eight percent of every outstanding debt is a monthly
/// minimum, which charges somebody for utang to a relative that has no
/// minimum payment and never did, then bases the advice on the inflated
/// ratio.
HealthIndicator _promised(
  _Measures m,
  PaydayCycle payday,
  List<InstallmentPlan> installments,
) {
  const String id = 'promised';
  const String question = 'How much of my pay is already promised';

  // Monthly take-home, from what the person said they receive each payday.
  final double monthly = payday.isSet && payday.expectedIncome > 0
      ? payday.expectedIncome * (payday.cycleType == '15_30' ? 2 : 1)
      : 0;

  if (monthly <= 0) {
    return HealthIndicator.unmeasured(
      id: id,
      question: question,
      missing:
          'Add what you take home each payday and this shows how much of it '
          'is already promised to lenders.',
      need: HealthNeed.setPayday,
    );
  }

  if (m.monthlyInstalments <= 0) {
    // NOT unmeasured. Owing nothing is a real measurement, unlike a missing
    // credit limit, and telling somebody with no loans that Salapify cannot
    // work something out would be absurd.
    return HealthIndicator.measured(
      id: id,
      question: question,
      reading: 'Nothing recorded that you owe on a schedule',
      tone: HealthTone.good,
    );
  }

  final int share = ((m.monthlyInstalments / monthly) * 100).round();
  final HealthTone tone = share <= debtShareComfortable
      ? HealthTone.good
      : share <= debtShareTight
      ? HealthTone.watch
      : HealthTone.tight;

  return HealthIndicator.measured(
    id: id,
    question: question,
    reading: '$share% of your take-home pay',
    // THE FIGURE THE PROTOTYPE NEVER COMPUTES, and the one that changes
    // behaviour: a percentage is abstract, and "your next six paydays already
    // have this on them" is not.
    detail: m.longestPlanLeft > 0
        ? '${formatPeso(m.monthlyInstalments)} a month, with '
              '${m.longestPlanLeft} more payments to run on the longest plan.'
        : null,
    tone: tone,
  );
}

/// 3. Do I have a cushion.
///
/// NEVER INFERRED. The prototype takes half of whatever is liquid as an
/// emergency fund when no goal exists, which tells somebody who has saved
/// nothing that they are halfway to safe. A cushion exists when the person
/// names it, and not before.
HealthIndicator _cushion(_Measures m, List<Goal> goals) {
  const String id = 'cushion';
  const String question = 'Do I have a cushion';

  final Goal? fund = goals
      .where(
        (Goal g) =>
            g.name.toLowerCase().contains('emergency') ||
            g.name.toLowerCase().contains('cushion') ||
            g.name.toLowerCase().contains('ipon'),
      )
      .firstOrNull;

  if (fund == null) {
    return HealthIndicator.unmeasured(
      id: id,
      question: question,
      missing:
          'You have not set an emergency fund yet. ${formatPeso(cushionFirstRung)} '
          'is the usual first rung: it covers a tooth, a tyre or a hospital '
          'deposit.',
      need: HealthNeed.startCushion,
    );
  }

  final double saved = fund.currentAmount;

  if (!m.paceMeasured) {
    // The AMOUNT is a measurement even when the months are not. Hiding it
    // would throw away the one figure they have.
    return HealthIndicator.measured(
      id: id,
      question: question,
      reading: '${formatPeso(saved)} set aside',
      detail:
          'How many months that covers needs a few more days of logged '
          'spending first.',
      tone: saved >= cushionFirstRung ? HealthTone.good : HealthTone.watch,
    );
  }

  final double monthlySpend = m.dailyPace * 30;
  final double months = monthlySpend > 0 ? saved / monthlySpend : 0;

  final HealthTone tone = months >= 3
      ? HealthTone.good
      : months >= 1
      ? HealthTone.watch
      : HealthTone.tight;

  return HealthIndicator.measured(
    id: id,
    question: question,
    reading: '${months.toStringAsFixed(1)} months of your own spending',
    detail:
        '${formatPeso(saved)} set aside. Three months is the usual '
        'target, six if your work is contractual.',
    tone: tone,
  );
}

/// 4. Am I keeping any of it.
///
/// DIRECTIONAL, not a percentage. On an 18,000 to 25,000 Metro Manila salary
/// a twenty percent savings rate after rent is frequently arithmetically
/// impossible, so an absolute target turns the indicator into a monthly
/// notice that somebody doing their best is failing. Whether this month beat
/// last month is a question anybody can act on.
HealthIndicator _keeping(_Measures m) {
  const String id = 'keeping';
  const String question = 'Am I keeping any of it';

  final DateTime now = m.now;
  final DateTime prev = DateTime(now.year, now.month - 1, 1);

  final bool hasThis = m.hasEntriesIn(now.year, now.month);
  final bool hasPrev = m.hasEntriesIn(prev.year, prev.month);

  if (!hasThis && !hasPrev) {
    return HealthIndicator.unmeasured(
      id: id,
      question: question,
      missing:
          'Nothing logged yet, so there is nothing to compare. A few weeks '
          'of entries and this starts working.',
      need: HealthNeed.logSpending,
    );
  }

  final double thisMonth = m.keptIn(now.year, now.month);

  if (!hasPrev) {
    return HealthIndicator.measured(
      id: id,
      question: question,
      reading: thisMonth >= 0
          ? '${formatPeso(thisMonth)} kept so far this month'
          : '${formatPeso(thisMonth.abs())} more out than in so far',
      detail: 'Next month this compares the two.',
      // TIGHT, not watch, and the difference was a real inconsistency the
      // tests caught. Spending more than came in reads `tight` in the
      // two-month branch below, and read `watch` here, so the same month
      // changed severity purely because a previous month existed to compare
      // it against. The fact does not depend on the comparison.
      tone: thisMonth < 0 ? HealthTone.tight : HealthTone.good,
    );
  }

  final double lastMonth = m.keptIn(prev.year, prev.month);
  final double change = thisMonth - lastMonth;

  return HealthIndicator.measured(
    id: id,
    question: question,
    reading: thisMonth >= 0
        ? '${formatPeso(thisMonth)} kept this month'
        : '${formatPeso(thisMonth.abs())} more out than in',
    detail: change >= 0
        ? '${formatPeso(change)} better than last month.'
        : '${formatPeso(change.abs())} worse than last month.',
    tone: thisMonth < 0
        ? HealthTone.tight
        : change >= 0
        ? HealthTone.good
        : HealthTone.watch,
  );
}

/// 5. Is my spending inside the limits I set.
///
/// Reuses computeBudgets, which already windows to the current month. The
/// prototype sums EVERY transaction ever in a category against a monthly
/// limit with no window at all, so a six month old ledger shows every budget
/// permanently breached.
HealthIndicator _limits(
  List<Budget> budgets,
  List<Transaction> transactions,
  DateTime now,
) {
  const String id = 'limits';
  const String question = 'Am I inside the limits I set';

  final List<Budget> real = budgets.where((Budget b) => b.limit > 0).toList();

  if (real.isEmpty) {
    return HealthIndicator.unmeasured(
      id: id,
      question: question,
      // ONE category, not all of them. A new user asked to budget twelve
      // categories sets none.
      missing:
          'No limits set yet. Pick the one category you overspend on and put '
          'a limit on that.',
      need: HealthNeed.setBudget,
    );
  }

  final List<BudgetStatus> status = computeBudgets(
    budgets: real,
    transactions: transactions,
    now: now,
  );

  BudgetStatus? worst;
  for (final BudgetStatus b in status) {
    if (worst == null || b.spent / b.limit > worst.spent / worst.limit) {
      worst = b;
    }
  }
  if (worst == null) {
    return HealthIndicator.unmeasured(
      id: id,
      question: question,
      missing: 'No limits set yet.',
      need: HealthNeed.setBudget,
    );
  }

  final int percent = ((worst.spent / worst.limit) * 100).round();
  final HealthTone tone = percent > 100
      ? HealthTone.tight
      : percent >= 80
      ? HealthTone.watch
      : HealthTone.good;

  return HealthIndicator.measured(
    id: id,
    question: question,
    reading: percent > 100
        ? '${worst.category} is over by ${formatPeso(worst.spent - worst.limit)}'
        : 'Closest is ${worst.category}, at $percent% of its limit',
    detail: '${status.length} ${status.length == 1 ? 'limit' : 'limits'} set.',
    tone: tone,
  );
}
