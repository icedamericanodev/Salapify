// Goals, as a list. What you are saving for, and whether you will make it.
//
// 04-screens.md: "One row per goal: name, saved of target on the right,
// ThinBar under the label, caption 'PHP X a month to make it by <date>'. A
// reached goal clears like a settled debt."
//
// THE ONE THING TO UNDERSTAND ABOUT GOALS, and it is not obvious.
//
// A goal's money is a NUMBER THE USER TRACKS, never an account balance. That
// rule is the engine's own, stated at the top of core/money/goal_plan.dart,
// and every screen has to hold it or the app starts double counting. The
// 12,000 saved toward an emergency fund IS the money already sitting in BPI.
// It is counted once, as a bank balance, in net worth and in safe to spend,
// and described a second time here as progress toward a target. Nothing on
// this screen is an asset, nothing here is subtracted from anything, and
// adding to a goal moves no peso between accounts.
//
// That is why there is no "which account did this come from" picker, which is
// the thing a debt payment needs and a goal deliberately does not. A goal is
// an intention about money you already have.
//
// This file derives and invents nothing. `goalPace` is golden locked to the
// shipped app and owns pct, remaining, perMonth and perWeek;
// `goalStatusLabel` and `requiredContribution` sit on top of it in
// goal_plan.dart. Everything below composes those three and formats.
import '../../core/money/analytics.dart' show goalPace;
import '../../core/money/format.dart' show formatMoney;
import '../../core/money/goal_plan.dart'
    show goalStatusLabel, requiredContribution;
import '../../core/money/ledger.dart' show amountOf;

/// One goal, as the screen draws it.
class GoalRow {
  const GoalRow({
    required this.id,
    required this.name,
    required this.saved,
    required this.target,
    required this.remaining,
    required this.fraction,
    required this.reached,
    required this.paused,
    required this.status,
    required this.perPeriod,
    required this.frequency,
    required this.hasDeadline,
    required this.targetDate,
  });

  final String id;
  final String name;
  final double saved;
  final double target;

  /// What is left to save, never below zero.
  final double remaining;

  /// 0 to 1, from the engine's own `pct`, so the bar and the caption can never
  /// tell different stories about the same goal.
  final double fraction;

  /// Saved has reached the target.
  final bool reached;
  final bool paused;

  /// The user-facing word: Completed, Paused, Overdue, Needs adjustment,
  /// Ahead, On track. Owned by goal_plan.dart, not re-derived here.
  final String status;

  /// What the plan asks for each period, or zero when nothing is owed.
  final double perPeriod;

  /// 'monthly' or 'weekly', the goal's own.
  final String frequency;

  /// Whether there is a date to be paced against at all.
  final bool hasDeadline;

  /// The stored target date, possibly empty and possibly month-only.
  final String targetDate;
}

/// Every goal, in stored order.
///
/// Stored order rather than sorted, deliberately. A list that reorders itself
/// as figures change means the row somebody was about to tap moves under their
/// finger, and there is no ordering here that is obviously right: by deadline
/// punishes the goal with no date, by progress buries the one that needs
/// attention. The user made this list; it stays in their order.
List<GoalRow> goalRows(Map<String, dynamic> state, DateTime now) {
  final out = <GoalRow>[];
  for (final g in (state['goals'] as List? ?? const [])) {
    if (g is! Map) continue;
    final goal = g.cast<String, dynamic>();

    final pace = goalPace(goal, now);
    final need = requiredContribution(goal, now);

    out.add(
      GoalRow(
        id: (goal['id'] ?? '').toString(),
        name: (goal['name'] ?? 'Goal').toString(),
        saved: amountOf(pace['saved']),
        target: amountOf(pace['target']),
        remaining: amountOf(pace['remaining']),
        fraction: amountOf(pace['pct']).clamp(0.0, 1.0),
        reached: pace['done'] == true,
        paused: goal['paused'] == true,
        status: goalStatusLabel(goal, now),
        perPeriod: amountOf(need['amount']),
        frequency: (need['frequency'] ?? 'monthly').toString(),
        hasDeadline: need['hasDeadline'] == true,
        targetDate: (pace['targetDate'] ?? '').toString(),
      ),
    );
  }
  return out;
}

const List<String> _monthsShort = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// A stored target date as a person writes it: "Jun 2027", "Dec 31 2026".
///
/// NEVER the raw stored string. `screen_readability` has a rule about showing
/// a stored value as it sits on disk, and "2027-06-30" on a savings screen is
/// exactly that. A month-only value stays month-only rather than gaining a day
/// the user never picked: goalPace clamps it to the month's last day for
/// ARITHMETIC, and printing that day back would invent a deadline.
String prettyTargetDate(String iso) {
  if (iso.length < 7) return '';
  final y = int.tryParse(iso.substring(0, 4));
  final m = int.tryParse(iso.substring(5, 7));
  if (y == null || m == null || m < 1 || m > 12) return '';
  final month = _monthsShort[m - 1];
  if (iso.length < 10) return '$month $y';
  final d = int.tryParse(iso.substring(8, 10));
  if (d == null || d < 1 || d > 31) return '$month $y';
  return '$month $d, $y';
}

/// The line under a goal's name.
///
/// Every branch here is a state the app can genuinely be in, and the ones that
/// LOOK redundant are the ones that were missing from the first draft:
///
/// - REACHED clears like a settled debt, and says what was saved rather than
///   the remaining zero. The settled debt row shipped showing PHP0 for exactly
///   this reason, because remaining is zero by definition once it is done.
/// - PAUSED owes nothing to any pace, so quoting a monthly figure at somebody
///   who deliberately stopped is a scold dressed as information.
/// - NO DEADLINE has no required amount that can honestly be stated. The
///   engine returns zero and the screen says what is left, not "PHP0 a month",
///   which would read as "you are done".
/// - OVERDUE is the case a linear pace cannot describe: the date has passed,
///   so there are no periods left to divide by and any figure would be a
///   division by a number that is not there.
String goalRowCaption(GoalRow row) {
  if (row.reached) return 'Reached, ${formatMoney(row.saved)} saved';
  if (row.paused) return 'Paused, ${formatMoney(row.remaining)} to go';

  final by = prettyTargetDate(row.targetDate);

  if (row.status == 'Overdue') {
    return by.isEmpty
        ? '${formatMoney(row.remaining)} to go, past its date'
        : '${formatMoney(row.remaining)} to go, was due $by';
  }
  if (!row.hasDeadline || row.perPeriod <= 0 || by.isEmpty) {
    return '${formatMoney(row.remaining)} to go, no date set';
  }

  final period = row.frequency == 'weekly' ? 'a week' : 'a month';
  return '${formatMoney(row.perPeriod)} $period to make it by $by';
}

/// What the Goals segment says above the list.
///
/// One sentence about the whole set, because a list of five bars with no
/// summary makes somebody add up five numbers to answer "am I saving enough".
/// It counts ACTIVE goals only: a reached goal asks for nothing and a paused
/// one is deliberately asking for nothing, so folding either into a monthly
/// figure would overstate what the user has actually committed to.
String goalsSummary(List<GoalRow> rows) {
  final active = rows.where((r) => !r.reached && !r.paused).toList();
  if (rows.isEmpty) return '';
  if (active.isEmpty) {
    // Every goal is reached or paused, so the honest answer is that this
    // month asks for nothing. Saying "PHP0 a month" instead would read as a
    // figure rather than as an absence.
    return 'Nothing to put aside this month.';
  }

  final monthly = active
      .where((r) => r.hasDeadline && r.frequency != 'weekly')
      .fold(0.0, (t, r) => t + r.perPeriod);
  final weekly = active
      .where((r) => r.hasDeadline && r.frequency == 'weekly')
      .fold(0.0, (t, r) => t + r.perPeriod);

  // Weekly goals are converted to NOTHING. Folding a weekly pace into a
  // monthly total needs a weeks-per-month constant, and there is no honest
  // one: four understates by a month a year and 4.33 is a number nobody can
  // check on paper. Two figures that are both true beat one that is neither.
  final parts = <String>[];
  if (monthly > 0) parts.add('${formatMoney(monthly)} a month');
  if (weekly > 0) parts.add('${formatMoney(weekly)} a week');

  if (parts.isEmpty) {
    return active.length == 1
        ? '1 goal, no date set on it yet.'
        : '${active.length} goals, no dates set on them yet.';
  }
  return 'Keeping to your dates takes ${parts.join(' and ')}.';
}
