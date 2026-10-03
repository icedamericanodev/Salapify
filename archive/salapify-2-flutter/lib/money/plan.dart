// The standing plan: the one commitment Pan holds and follows up on.
//
// A plan is a small object in settings.activePlan, written only when the
// user taps "make it a plan" and readable in full on the plan card, which
// is the trust rule from the vision spec: rule-based Pan must never sound
// like it remembers more than it stored, so what "memory" means is exactly
// visible, editable, and droppable. One plan at a time, the same
// one-behavior-at-a-time discipline the challenge design settled on.
//
// Shape (settings.activePlan):
//   {kind: 'debt'|'goal', targetId, label, amount, cadence:
//    'weekly'|'monthly', startDate: 'YYYY-MM-DD', startLevel}
//
// startLevel is the target's level the day the plan was made (a debt's
// remaining, a goal's saved), so progress is measured as movement SINCE the
// commitment, not lifetime totals. Goals need this because goal funding
// adjusts a number rather than writing dated transactions; debts get the
// same treatment so a hand adjustment counts the same as a payment, which
// keeps the two kinds honest with each other.
//
// Every figure here derives from the data. Junk shapes return null status
// rather than throwing, matching the money layer.

import 'analytics.dart' show goalPace;
import 'ledger.dart' show amountOf;

Map<String, dynamic>? _asMap(dynamic v) =>
    v is Map ? v.cast<String, dynamic>() : null;

List<Map<String, dynamic>> _rows(dynamic v) => [
  for (final r in (v is List ? v : const []))
    if (r is Map) r.cast<String, dynamic>(),
];

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

/// The stored plan, or null when none exists or the shape is junk. This is
/// the ONLY reader of settings.activePlan, so the shape check lives once.
Map<String, dynamic>? activePlanOf(Map<String, dynamic> data) {
  final settings = _asMap(data['settings']);
  final plan = _asMap(settings?['activePlan']);
  if (plan == null) return null;
  final kind = plan['kind'];
  if (kind != 'debt' && kind != 'goal') return null;
  if (plan['targetId'] is! String || (plan['targetId'] as String).isEmpty) {
    return null;
  }
  final cadence = plan['cadence'];
  if (cadence != 'weekly' && cadence != 'monthly') return null;
  if (!(amountOf(plan['amount']) > 0)) return null;
  if (_parseIso(plan['startDate']) == null) return null;
  return plan;
}

/// Completed periods between [start] and [today], calendar-honest.
///
/// Weekly is floor(days / 7). Monthly counts how many times the start's
/// day-of-month has come around again, the day CLAMPED to each month's real
/// length exactly like recurring items: a plan started Jan 31 completes its
/// first month on Feb 28 (or 29), its second on Mar 31. This is the edge the
/// first test vectors exercise, per the session 28 rule: the clamp is what
/// month arithmetic exists to handle, so it is the first thing proven.
int periodsCompleted(DateTime start, DateTime today, String cadence) {
  final s = DateTime(start.year, start.month, start.day);
  final t = DateTime(today.year, today.month, today.day);
  if (t.isBefore(s)) return 0;
  if (cadence == 'weekly') {
    return t.difference(s).inDays ~/ 7;
  }
  var count = 0;
  for (
    var m = DateTime(s.year, s.month + 1, 1);
    !m.isAfter(DateTime(t.year, t.month, 1));
    m = DateTime(m.year, m.month + 1, 1)
  ) {
    final daysInMonth = DateTime(m.year, m.month + 1, 0).day;
    final occ = DateTime(
      m.year,
      m.month,
      s.day < daysInMonth ? s.day : daysInMonth,
    );
    if (!occ.isAfter(t)) count += 1;
  }
  return count;
}

/// The plan's live status against the data, or null when no valid plan is
/// stored. States:
///   'done'     the target itself is finished (debt at zero, goal at target)
///   'orphaned' the debt or goal the plan points at no longer exists
///   'ahead'    at least one full period's amount past the expected pace
///   'behind'   at least one full period's amount short of the expected pace
///   'started'  no period has completed yet, nothing owed to the pace
///   'onTrack'  everything else
Map<String, dynamic>? planStatus(Map<String, dynamic> data, DateTime now) {
  final plan = activePlanOf(data);
  if (plan == null) return null;
  final start = _parseIso(plan['startDate'])!;
  final amount = amountOf(plan['amount']);
  final cadence = plan['cadence'] as String;
  final kind = plan['kind'] as String;
  final targetId = plan['targetId'] as String;
  final startLevel = amountOf(plan['startLevel']);

  Map<String, dynamic>? target;
  for (final row in _rows(data[kind == 'debt' ? 'debts' : 'goals'])) {
    if (row['id'] == targetId) {
      target = row;
      break;
    }
  }

  final label =
      (plan['label'] is String && (plan['label'] as String).isNotEmpty)
      ? plan['label'] as String
      : (kind == 'debt' ? 'The debt plan' : 'The goal plan');

  if (target == null) {
    return {
      'kind': kind,
      'label': label,
      'amount': amount,
      'cadence': cadence,
      'state': 'orphaned',
      'expected': 0.0,
      'actual': 0.0,
      'delta': 0.0,
      'periods': 0,
      'remaining': 0.0,
      'progress': 0.0,
    };
  }

  final periods = periodsCompleted(start, now, cadence);
  final expected = amount * periods;

  double actual;
  double remaining;
  bool done;
  if (kind == 'debt') {
    final cur = amountOf(target['remaining']);
    actual = startLevel - cur;
    remaining = cur;
    done = cur <= 0;
  } else {
    final cur = amountOf(target['saved']);
    final goalTarget = amountOf(target['target']);
    actual = cur - startLevel;
    remaining = goalTarget - cur > 0 ? goalTarget - cur : 0.0;
    done = goalTarget > 0 && cur >= goalTarget;
  }
  final delta = actual - expected;

  final String state;
  if (done) {
    state = 'done';
  } else if (periods == 0) {
    state = 'started';
  } else if (delta >= amount) {
    state = 'ahead';
  } else if (delta <= -amount) {
    state = 'behind';
  } else {
    state = 'onTrack';
  }

  return {
    'kind': kind,
    'label': label,
    'amount': amount,
    'cadence': cadence,
    'state': state,
    'expected': expected,
    'actual': actual,
    'delta': delta,
    'periods': periods,
    'remaining': remaining,
    // Whole periods of lead or lag, for "two weeks ahead" phrasing. Rounded
    // toward zero so a half-period lead never overclaims.
    'leadPeriods': amount > 0 ? (delta / amount).truncate() : 0,
    // The card's bar, computed HERE and not on the screen: a debt that grows
    // (interest posted after the plan started) makes actual negative, and
    // the clamp that hides that is a money decision, not a layout one.
    'progress': (actual + remaining) > 0
        ? (actual / (actual + remaining)).clamp(0.0, 1.0).toDouble()
        : 0.0,
  };
}

/// The edit sheet's ceiling, applied here too so a chip can never offer an
/// amount the sheet itself would refuse to save.
const double maxPlanAmount = 100000000;

/// The prefilled plan an intent reply can OFFER, derived from the data at
/// the moment of asking, never carried inside the golden-locked reply
/// itself. Returns null when a plan already exists (one at a time), when
/// the intent has no plannable target, or when the amount would round to
/// zero or exceed [maxPlanAmount]. A zero-amount offer once created a plan
/// that activePlanOf rejects: invisible on the card, undroppable, and
/// blocking every future offer, which is the exact trap this guard closes.
///
/// For 'debt_free' the offer follows the avalanche order's top debt with
/// the asked extra amount (or the debt's own minimum when none was asked).
/// For 'goal_pace' it follows the SAME goal the resolver focuses on (named
/// in the message, else first behind, else lowest pct) at the per-month
/// pace goalPace computes, so the button can never commit a number that
/// contradicts the sentence above it. goalPace reads targetDate, the field
/// goals actually store, including month-only YYYY-MM values.
Map<String, dynamic>? planOfferFor(
  Map<String, dynamic> data,
  String intentId,
  DateTime now, {
  double? askedAmount,
  String raw = '',
}) {
  if (activePlanOf(data) != null) return null;
  String iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  bool sane(double a) => a > 0 && a <= maxPlanAmount;

  if (intentId == 'debt_free') {
    Map<String, dynamic>? top;
    var topRate = -1.0;
    for (final d in _rows(data['debts'])) {
      final remaining = amountOf(d['remaining']);
      if (!(remaining > 0)) continue;
      final rate = amountOf(d['monthlyRate']);
      if (rate > topRate) {
        topRate = rate;
        top = d;
      }
    }
    if (top == null) return null;
    final amount = (askedAmount != null && sane(askedAmount))
        ? askedAmount
        : amountOf(top['minPayment']);
    if (!sane(amount)) return null;
    final name = (top['name'] is String && (top['name'] as String).isNotEmpty)
        ? top['name'] as String
        : 'the costliest debt';
    return {
      'kind': 'debt',
      'targetId': top['id'],
      'label': 'Extra to $name',
      'amount': amount,
      'cadence': 'monthly',
      'startDate': iso(now),
      'startLevel': amountOf(top['remaining']),
    };
  }

  if (intentId == 'goal_pace') {
    final goals = [
      for (final g in _rows(data['goals']))
        if (amountOf(g['target']) > 0 &&
            amountOf(g['saved']) < amountOf(g['target']))
          g,
    ];
    if (goals.isEmpty) return null;
    // Mirror the resolver's focus, in its exact order, so the offered goal
    // is the one the reply is talking about: named in the message, else the
    // first behind its deadline, else the lowest percentage.
    Map<String, dynamic>? focus;
    final rawLower = raw.toLowerCase();
    if (rawLower.isNotEmpty) {
      for (final g in goals) {
        final n = g['name'];
        final name = (n is String && n.isNotEmpty) ? n.toLowerCase() : '';
        if (name.isNotEmpty && rawLower.contains(name)) {
          focus = g;
          break;
        }
      }
    }
    if (focus == null) {
      for (final g in goals) {
        if (goalPace(g, now)['status'] == 'behind') {
          focus = g;
          break;
        }
      }
    }
    if (focus == null) {
      focus = goals.first;
      var lowest = amountOf(goalPace(focus, now)['pct']);
      for (final g in goals.skip(1)) {
        final pct = amountOf(goalPace(g, now)['pct']);
        if (pct < lowest) {
          lowest = pct;
          focus = g;
        }
      }
    }
    final g0 = focus!;
    final pace = goalPace(g0, now);
    final gap = amountOf(pace['remaining']);
    // The deadline pace the reply quotes when a date exists; a no-date goal
    // gets a year-long default pace, honest and adjustable on the card.
    final perMonth = amountOf(pace['perMonth']);
    final amount = double.parse(
      (perMonth > 0 ? perMonth : gap / 12).toStringAsFixed(0),
    );
    // Rounded FIRST, then bounded: a 0.42 pace rounds to zero, and a zero
    // must kill the offer, never survive into a stored plan.
    if (!sane(amount)) return null;
    final name = (g0['name'] is String && (g0['name'] as String).isNotEmpty)
        ? g0['name'] as String
        : 'the goal';
    return {
      'kind': 'goal',
      'targetId': g0['id'],
      'label': 'Save for $name',
      'amount': amount,
      'cadence': 'monthly',
      'startDate': iso(now),
      'startLevel': amountOf(g0['saved']),
    };
  }

  return null;
}
