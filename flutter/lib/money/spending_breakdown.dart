// Bills and spending breakdown, f4.67. Pure, offline, and it invents no stored
// data: everything here is derived from figures the person already entered.
//
// Two honest lenses:
//   1. spendingSplit: this month's SPENDING split into "committed" (bills you
//      set up, debt payments, card interest) and "everyday" (the rest). The
//      committed test is the EXACT complement of the discretionary set the
//      cash-flow pace already uses (commitments.dart _discretionaryDailyPace:
//      an interest source, a debtId, or a recurringId), so the two can never
//      disagree, and committed + everyday equals budgetSummary's spent for the
//      same month (both sum type == 'expense' this month). No new field, no
//      migration, no classification the user has to maintain.
//   2. recurringBillsMonthly + billsForPeriod: your recurring EXPENSE bills as
//      a monthly figure, projected onto a week or a year so the same commitment
//      reads at whatever cadence a person budgets in. A month is not exactly
//      four weeks, so weekly annualizes then divides by 52.
//
// The due-date list ("what is due next") is not here: it is the golden-locked
// upcomingCommitments in commitments.dart, rendered straight by the screen.

import 'ledger.dart' show amountOf;

bool _jsTruthy(dynamic v) =>
    v != null && v != false && v != 0 && v != '' && !(v is double && v.isNaN);

bool _isThisMonth(dynamic dateStr, DateTime ref) {
  final s = (dateStr ?? '').toString();
  if (s.length < 7) return false;
  final key = '${ref.year}-${ref.month.toString().padLeft(2, '0')}';
  return s.substring(0, 7) == key;
}

/// True when an EXPENSE is a committed cost rather than everyday spending:
/// debt interest, a payment tagged to a debt, or a posted recurring bill. This
/// is the exact complement of the discretionary set the cash-flow pace uses
/// (commitments.dart _discretionaryDailyPace), kept in sync on purpose so the
/// two surfaces never tell a person two different stories about the same peso.
/// The caller has already checked type == 'expense'.
bool isCommittedExpense(Map t) =>
    t['source'] == 'interest' ||
    _jsTruthy(t['debtId']) ||
    _jsTruthy(t['recurringId']);

/// This month's spending, split committed vs everyday.
///
/// Returns { committed, everyday, total, committedPct } where total is committed
/// + everyday and equals budgetSummary's spent for the same month (both fold
/// type == 'expense' entries dated this month), and committedPct is
/// committed / total * 100, or 0 when nothing was spent.
Map<String, dynamic> spendingSplit(Map<String, dynamic> data, DateTime ref) {
  var committed = 0.0;
  var everyday = 0.0;
  for (final raw in (data['transactions'] as List? ?? const [])) {
    if (raw is! Map) continue;
    if (raw['type'] != 'expense') continue;
    if (!_isThisMonth(raw['date'], ref)) continue;
    final amt = amountOf(raw['amount']);
    if (isCommittedExpense(raw)) {
      committed += amt;
    } else {
      everyday += amt;
    }
  }
  final total = committed + everyday;
  // Guard non-finite before the divide: a junk backup can smuggle Infinity or
  // NaN into an amount, and committed/total would then be NaN, which a later
  // round() throws on. A pathological book shows 0% rather than crashing.
  final pctOk = total > 0 && total.isFinite && committed.isFinite;
  return {
    'committed': committed,
    'everyday': everyday,
    'total': total,
    'committedPct': pctOk ? (committed / total) * 100 : 0.0,
  };
}

/// The cadence a bills figure is shown at.
enum BillPeriod { weekly, monthly, annual }

/// The sum of your recurring EXPENSE bills as a MONTHLY figure. Each recurring
/// entry is a monthly commitment (it posts once a month on its day), so this is
/// a straight sum of their amounts. Income recurring is never counted, and a
/// negative amount is floored at zero the same way the poster clamps it.
double recurringBillsMonthly(Map<String, dynamic> data) {
  var total = 0.0;
  for (final raw in (data['recurring'] as List? ?? const [])) {
    if (raw is! Map) continue;
    if (raw['type'] != 'expense') continue;
    total += amountOf(raw['amount']).clamp(0, double.infinity).toDouble();
  }
  return total;
}

/// How many recurring EXPENSE bills there are, so the screen can say "across N
/// bills" honestly and show an empty state when there are none.
int recurringBillsCount(Map<String, dynamic> data) {
  var n = 0;
  for (final raw in (data['recurring'] as List? ?? const [])) {
    if (raw is Map && raw['type'] == 'expense') n += 1;
  }
  return n;
}

/// A monthly bills figure projected onto a period. Weekly annualizes then
/// divides by 52 (a month is not exactly four weeks); annual is twelve months.
/// A pure multiplier with no rounding, so the caller formats the peso once.
double billsForPeriod(double monthly, BillPeriod period) {
  switch (period) {
    case BillPeriod.weekly:
      return monthly * 12.0 / 52.0;
    case BillPeriod.monthly:
      return monthly;
    case BillPeriod.annual:
      return monthly * 12.0;
  }
}
