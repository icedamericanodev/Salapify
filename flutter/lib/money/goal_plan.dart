// The goal planning engine: everything the redesigned Goals screens say
// about a goal that goalPace (golden-locked to the RN app) does not already
// say. goalPace stays the single source for pct/remaining/perMonth and the
// raw status; this file turns those into user-facing status labels, an
// expected-by-today pace, what-if projections, template suggestions, the
// safe-to-set-aside estimate, and quarter milestones.
//
// House rules held here:
// - Pure functions, clock injected, junk in never throws.
// - A goal's money is a NUMBER the user tracks, not an account balance:
//   nothing in this file (or anywhere in goals) moves a peso in accounts.
// - Suggestions must be explainable or absent. When the data is not there,
//   the answer is null and the screen says so; it never invents a figure.

import 'analytics.dart' show goalPace;
import 'commitments.dart' show safeToSpend;
import 'debtmath.dart' show formatMoneyText;
import 'ledger.dart' show amountOf;
import 'timeline.dart' show variableSpendRate;

Map<String, dynamic> _pace(Map<String, dynamic> goal, DateTime now) =>
    goalPace(goal, now);

DateTime? _parseIso(dynamic s) {
  if (s is! String || s.length < 10) return null;
  final y = int.tryParse(s.substring(0, 4));
  final m = int.tryParse(s.substring(5, 7));
  final d = int.tryParse(s.substring(8, 10));
  if (y == null || m == null || d == null) return null;
  final dt = DateTime(y, m, d);
  if (dt.year != y || dt.month != m || dt.day != d) return null;
  return dt;
}

String _iso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// The user-facing status of a goal, deterministic and explainable:
///   'Completed'        saved reached the target
///   'Paused'           the user paused it; nothing is owed to any pace
///   'Overdue'          the target date passed with money still to go
///   'Needs adjustment' the plan no longer fits (deadline this month with a
///                      gap, or clearly under the expected pace)
///   'Ahead'            clearly past the expected pace
///   'On track'         everything else, including goals with no deadline
///
/// "Expected" is linear and honest: from the day the goal was made
/// (createdAt, with startSaved) to the target date, the plan expects the gap
/// to fill evenly. A goal without createdAt or without a date has no pace to
/// be behind, so it reads On track while active. No score, no confidence
/// percentage, nothing a user could not recompute on paper.
String goalStatusLabel(Map<String, dynamic> goal, DateTime now) {
  if (goal['paused'] == true) return 'Paused';
  final pace = _pace(goal, now);
  switch (pace['status']) {
    case 'done':
      return 'Completed';
    case 'behind':
      return 'Overdue';
    case 'due-soon':
      return 'Needs adjustment';
    case 'active':
      break;
    default:
      // no-date, no-target: nothing to measure against.
      return 'On track';
  }
  final expected = expectedByToday(goal, now);
  if (expected == null) return 'On track';
  final saved = amountOf(goal['saved']);
  final share = expected['monthShare'] as double;
  final delta = saved - (expected['expected'] as double);
  if (share <= 0) return 'On track';
  if (delta >= share) return 'Ahead';
  if (delta <= -share) return 'Needs adjustment';
  return 'On track';
}

/// Where a linear plan expects `saved` to be today, or null when the goal
/// carries no createdAt or no valid future-of-creation date. Returns
/// {expected, monthShare, elapsedDays, totalDays} so the screen can say
/// "by today the plan expected about X".
Map<String, dynamic>? expectedByToday(
  Map<String, dynamic> goal,
  DateTime now,
) {
  final created = _parseIso(goal['createdAt']);
  final deadline = _parseIso(_paddedDate(goal));
  if (created == null || deadline == null) return null;
  final start = DateTime(created.year, created.month, created.day);
  final end = DateTime(deadline.year, deadline.month, deadline.day);
  final today = DateTime(now.year, now.month, now.day);
  final totalDays = end.difference(start).inDays;
  if (totalDays <= 0) return null;
  final elapsedDays = today.difference(start).inDays.clamp(0, totalDays);
  final target = amountOf(goal['target']);
  final startSaved = amountOf(goal['startSaved']);
  final gap = target - startSaved;
  if (gap <= 0) return null;
  return {
    'expected': startSaved + gap * (elapsedDays / totalDays),
    // One month's fair share of the plan, the tolerance band on both sides.
    'monthShare': gap * 30.0 / totalDays,
    'elapsedDays': elapsedDays,
    'totalDays': totalDays,
  };
}

/// goalPace reads targetDate as YYYY-MM or YYYY-MM-DD; for date arithmetic
/// here a month-only value means its last day, same as goalPace's clamp.
String _paddedDate(Map<String, dynamic> goal) {
  final raw = goal['targetDate'];
  final s = raw is String ? raw.trim() : '';
  final m = RegExp(r'^(\d{4})-(\d{2})$').firstMatch(s);
  if (m == null) return s;
  final y = int.parse(m.group(1)!);
  final mo = int.parse(m.group(2)!);
  if (mo < 1 || mo > 12) return s;
  final last = DateTime(y, mo + 1, 0).day;
  return '$s-${last.toString().padLeft(2, '0')}';
}

/// The contribution the plan asks for, at the goal's own frequency.
/// {amount, frequency, hasDeadline} with amount 0 when nothing is owed
/// (done, no target, or already past target). With a deadline the figures
/// are goalPace's own (so the number matches Insights and Pan); without one
/// there is no required amount, only what-if.
Map<String, dynamic> requiredContribution(
  Map<String, dynamic> goal,
  DateTime now,
) {
  final pace = _pace(goal, now);
  final frequency = goal['frequency'] == 'weekly' ? 'weekly' : 'monthly';
  final hasDeadline =
      pace['status'] == 'active' ||
      pace['status'] == 'due-soon' ||
      pace['status'] == 'behind';
  final amount = !hasDeadline
      ? 0.0
      : amountOf(frequency == 'weekly' ? pace['perWeek'] : pace['perMonth']);
  return {
    'amount': amount,
    'frequency': frequency,
    'hasDeadline': hasDeadline,
    'status': pace['status'],
    'remaining': amountOf(pace['remaining']),
  };
}

/// A what-if projection that never touches the stored goal: given a periodic
/// amount (and optionally a one-time top-up), when would this goal finish?
/// Returns {finishDate, periods, frequency, meetsDeadline} or null when the
/// inputs cannot finish it (zero pace with a gap), mirroring goalForecast's
/// honesty. Capped at 520 weeks / 120 months so a tiny pace over a huge gap
/// answers "more than ten years" rather than looping.
Map<String, dynamic>? goalWhatIf(
  Map<String, dynamic> goal,
  DateTime now, {
  required double perPeriod,
  String frequency = 'monthly',
  double oneTime = 0,
}) {
  final target = amountOf(goal['target']);
  if (target <= 0) return null;
  var saved = amountOf(goal['saved']) + (oneTime.isFinite ? oneTime : 0);
  if (saved >= target) {
    return {
      'finishDate': _iso(now),
      'periods': 0,
      'frequency': frequency,
      'meetsDeadline': true,
    };
  }
  if (!(perPeriod > 0) || !perPeriod.isFinite) return null;
  final weekly = frequency == 'weekly';
  final cap = weekly ? 520 : 120;
  final remaining = target - saved;
  var periods = (remaining / perPeriod).ceil();
  if (periods > cap) return null;
  if (periods < 1) periods = 1;
  final finish = weekly
      ? now.add(Duration(days: 7 * periods))
      : DateTime(now.year, now.month + periods, now.day);
  final deadline = _parseIso(_paddedDate(goal));
  return {
    'finishDate': _iso(finish),
    'periods': periods,
    'frequency': frequency,
    'meetsDeadline': deadline == null || !finish.isAfter(deadline),
  };
}

/// The quarter milestones a goal has crossed, for the detail screen's row:
/// [25, 50, 75, 100] filtered to what `saved` already covers.
List<int> quartersReached(Map<String, dynamic> goal) {
  final target = amountOf(goal['target']);
  if (target <= 0) return const [];
  final saved = amountOf(goal['saved']);
  final pctFloor = (saved / target * 100).floor();
  return [
    for (final q in const [25, 50, 75, 100])
      if (pctFloor >= q) q,
  ];
}

/// The quarter newly crossed by moving saved from [before] to [after], or
/// null. 100 is deliberately excluded: the full-target crossing already has
/// its own celebration through milestoneFor, and firing both would stack two
/// sheets on one tap.
int? quarterCrossed(double before, double after, double target) {
  if (target <= 0) return null;
  for (final q in const [75, 50, 25]) {
    final line = target * q / 100;
    if (before < line && after >= line && after < target) return q;
  }
  return null;
}

/// What the user's essential month costs, from their own data: recurring
/// expense amounts plus the trailing 28-day ordinary daily spend scaled to a
/// month. Null when there is genuinely nothing to read (no recurring
/// expenses AND no spending history), because a made-up essentials figure is
/// worse than none.
Map<String, dynamic>? essentialMonthly(Map<String, dynamic> data, DateTime now) {
  var recurringTotal = 0.0;
  var recurringCount = 0;
  for (final raw
      in (data['recurring'] is List ? data['recurring'] as List : const [])) {
    if (raw is! Map) continue;
    if (raw['type'] != 'expense') continue;
    final amt = amountOf(raw['amount']);
    if (amt <= 0) continue;
    recurringTotal += amt;
    recurringCount += 1;
  }
  final variableDaily = variableSpendRate(data, now).dailyRate;
  final variableMonthly = variableDaily * 30;
  if (recurringCount == 0 && variableMonthly <= 0) return null;
  return {
    'total': recurringTotal + variableMonthly,
    'recurring': recurringTotal,
    'recurringCount': recurringCount,
    'variable': variableMonthly,
  };
}

/// One goal template: everything the create flow prefills, plus the reason
/// a suggestion exists so the screen can show its work. `icon` is a semantic
/// key resolved through salapify_icon.dart, never an emoji: templates are
/// authored by Salapify. A goal the user then saves stores that key, and a
/// goal whose user typed their own emoji keeps the emoji, both forever.
class GoalTemplate {
  final String key;
  final String name;
  final String kind; // 'savings' | 'debt'
  final String blurb;
  final String icon; // semantic icon key
  final String accent; // 'primary' | 'caramel' | 'celebrate'
  final double? suggestedTarget;
  final String? suggestedDeadline; // ISO YYYY-MM-DD
  final String? why; // plain-language basis for the suggestion, or null

  const GoalTemplate({
    required this.key,
    required this.name,
    required this.kind,
    required this.blurb,
    required this.icon,
    this.accent = 'primary',
    this.suggestedTarget,
    this.suggestedDeadline,
    this.why,
  });
}

/// The template registry, computed against the user's own data so every
/// suggested number can say where it came from. Rules:
/// - Emergency fund: three months of essentials when essentials are
///   readable, else no number ("Not enough data for a suggestion").
/// - Pasko fund: a December 1 deadline (this year until September, else
///   next year), no invented target.
/// - Debt payoff: exists only when a debt with a balance exists; the create
///   flow links it, the target is the debt's own outstanding balance, never
///   a copy typed here.
/// - Everything else: named, iconed, explained, and free of invented pesos.
List<GoalTemplate> goalTemplates(Map<String, dynamic> data, DateTime now) {
  final ess = essentialMonthly(data, now);
  double? emergencyTarget;
  String? emergencyWhy;
  if (ess != null) {
    final monthly = (ess['total'] as double);
    // Whole hundreds: an essentials estimate with centavos would claim a
    // precision the trailing-28-day read does not have.
    emergencyTarget = (monthly * 3 / 100).ceilToDouble() * 100;
    emergencyWhy =
        'Three months of your usual bills and spending, about '
        '${formatMoneyText(monthly)} a month from your own data.';
  }
  final paskoYear = now.month >= 10 ? now.year + 1 : now.year;
  final hasDebt = (data['debts'] is List ? data['debts'] as List : const [])
      .whereType<Map>()
      .any((d) => amountOf(d['remaining']) > 0);
  return [
    GoalTemplate(
      key: 'emergency',
      name: 'Emergency fund',
      kind: 'savings',
      blurb: 'Cash for the month life does not warn you about.',
      icon: 'emergency',
      suggestedTarget: emergencyTarget,
      why: emergencyWhy,
    ),
    GoalTemplate(
      key: 'pasko',
      name: 'Pasko fund',
      kind: 'savings',
      blurb: 'December, paid for before December.',
      icon: 'pasko',
      accent: 'celebrate',
      suggestedDeadline: '$paskoYear-12-01',
      why: 'December 1 gives the fund a natural deadline. Change it anytime.',
    ),
    if (hasDebt)
      const GoalTemplate(
        key: 'debtPayoff',
        name: 'Debt payoff',
        kind: 'debt',
        blurb: 'Follow one of your own debts down to zero.',
        icon: 'debtPayoff',
        why:
            'Linked to a debt you already track, so the target is its real '
            'balance and payments you log move this goal by themselves.',
      ),
    const GoalTemplate(
      key: 'tuition',
      name: 'Tuition fund',
      kind: 'savings',
      blurb: 'Enrollment, without the last-minute scramble.',
      icon: 'education',
    ),
    const GoalTemplate(
      key: 'padala',
      name: 'Family padala fund',
      kind: 'savings',
      blurb: 'Regular support for family, planned instead of squeezed.',
      icon: 'familySupport',
      accent: 'caramel',
    ),
    const GoalTemplate(
      key: 'health',
      name: 'Health fund',
      kind: 'savings',
      blurb: 'Checkups and medicine money that is already there.',
      icon: 'health',
    ),
    const GoalTemplate(
      key: 'travel',
      name: 'Travel fund',
      kind: 'savings',
      blurb: 'The trip, saved for before it is booked.',
      icon: 'travel',
    ),
    const GoalTemplate(
      key: 'gadget',
      name: 'Gadget fund',
      kind: 'savings',
      blurb: 'The upgrade, bought in cash.',
      icon: 'gadget',
    ),
    const GoalTemplate(
      key: 'wedding',
      name: 'Wedding fund',
      kind: 'savings',
      blurb: 'The day, without starting married life in debt.',
      icon: 'wedding',
      accent: 'caramel',
    ),
    const GoalTemplate(
      key: 'house',
      name: 'House fund',
      kind: 'savings',
      blurb: 'The downpayment, one payday at a time.',
      icon: 'house',
    ),
    const GoalTemplate(
      key: 'custom',
      name: 'Your own goal',
      kind: 'savings',
      blurb: 'Name it and set your own numbers.',
      icon: 'goal',
    ),
  ];
}

/// The estimated amount safe to move toward goals right now, or null when
/// the data cannot support an estimate. Built from safeToSpend (liquid
/// accounts minus bills due before payday) minus the user's buffer
/// (settings.goalBuffer, default 1000). An ESTIMATE by construction; the
/// screen labels it so and shows the parts.
///
/// Sufficiency, stated rather than guessed: there must be at least one
/// liquid account, and either a payday schedule or at least one upcoming
/// bill, otherwise "available until payday" is a number about nothing and
/// the honest answer is to ask for bills or income dates.
Map<String, dynamic>? safeToSetAside(Map<String, dynamic> data, DateTime now) {
  final hasLiquid = (data['accounts'] is List ? data['accounts'] as List : const [])
      .whereType<Map>()
      .any((a) => const ['cash', 'ewallet', 'checking'].contains(a['kind']));
  if (!hasLiquid) return null;
  final s = safeToSpend(data, now);
  final settings = data['settings'];
  final schedule = settings is Map ? settings['paydaySchedule'] : null;
  final hasSchedule =
      schedule != null && schedule != false && schedule != '' && schedule != 0;
  final billCount = (s['billCount'] as int?) ?? 0;
  if (!hasSchedule && billCount == 0) return null;
  final rawBuffer = settings is Map ? amountOf(settings['goalBuffer']) : 0.0;
  final buffer = rawBuffer > 0 ? rawBuffer : 1000.0;
  final available = amountOf(s['available']);
  final amount = available - buffer;
  return {
    'amount': amount > 0 ? amount : 0.0,
    'available': available,
    'liquid': amountOf(s['liquid']),
    'committed': amountOf(s['committed']),
    'buffer': buffer,
    'daysLeft': s['daysLeft'],
    'payday': s['payday'],
  };
}

/// Which active goal deserves focus, by transparent rules in order:
/// 1. The user's own priority order (lowest 'priority' number first).
/// 2. Overdue or deadline-crunched goals before comfortable ones.
/// 3. Soonest target date.
/// A suggestion for the top of the screen, never an instruction; ties keep
/// list order so the answer is stable.
Map<String, dynamic>? focusGoal(List<Map<String, dynamic>> goals, DateTime now) {
  final active = [
    for (final g in goals)
      if (g['paused'] != true &&
          amountOf(g['target']) > 0 &&
          amountOf(g['saved']) < amountOf(g['target']))
        g,
  ];
  if (active.isEmpty) return null;
  int statusRank(Map<String, dynamic> g) {
    switch (_pace(g, now)['status']) {
      case 'behind':
        return 0;
      case 'due-soon':
        return 1;
      case 'active':
        return 2;
      default:
        return 3;
    }
  }

  final indexed = List.generate(active.length, (i) => (active[i], i));
  indexed.sort((a, b) {
    final pa = a.$1['priority'];
    final pb = b.$1['priority'];
    if ((pa is num) != (pb is num)) return pa is num ? -1 : 1;
    if (pa is num && pb is num && pa != pb) return pa.compareTo(pb);
    final c = statusRank(a.$1).compareTo(statusRank(b.$1));
    if (c != 0) return c;
    final da = (a.$1['targetDate'] ?? '').toString();
    final db = (b.$1['targetDate'] ?? '').toString();
    if (da.isNotEmpty && db.isNotEmpty && da != db) return da.compareTo(db);
    if (da.isEmpty != db.isEmpty) return da.isEmpty ? 1 : -1;
    return a.$2.compareTo(b.$2);
  });
  return indexed.first.$1;
}

/// A debt-payoff goal's live figures, derived from the linked debt so the
/// balance is never copied: target is the balance when the goal was made
/// (startLevel), saved is how far it has fallen since. Payments logged in
/// the debt screens move this without Goals writing anything. Returns null
/// when the linked debt is gone (the card says so instead of guessing).
Map<String, dynamic>? debtGoalFigures(
  Map<String, dynamic> goal,
  Map<String, dynamic> data,
) {
  if (goal['kind'] != 'debt') return null;
  final id = goal['linkedDebtId'];
  if (id is! String || id.isEmpty) return null;
  for (final raw in (data['debts'] is List ? data['debts'] as List : const [])) {
    if (raw is Map && raw['id'] == id) {
      final remaining = amountOf(raw['remaining']);
      final startLevel = amountOf(goal['startLevel']);
      final target = startLevel > 0 ? startLevel : remaining;
      final paid = target - remaining;
      return {
        'name': (raw['name'] ?? 'Debt').toString(),
        'target': target,
        'saved': paid > 0 ? paid : 0.0,
        'remaining': remaining,
        'done': remaining <= 0,
      };
    }
  }
  return null;
}
