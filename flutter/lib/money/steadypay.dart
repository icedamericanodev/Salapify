// Steady Pay: pay yourself a salary from swing income. For the gig driver,
// freelancer, or seller whose income has no payday schedule, this computes
// the one decision that makes a swing income livable: the weekly amount you
// can safely treat as YOUR pay, planned on your lean months, never your best
// ones, so a good month becomes runway instead of lifestyle.
//
// Pure and honest by construction: income history comes from the
// golden-locked monthlySeries (utang collections are never income), liquid
// cash from safeToSpend, and with fewer than three real income months the
// suggestion is null. Silence beats a made-up salary. Founder approved
// 2026-07-24, including the one stored field (settings.steadyPay).

import 'analytics.dart' show monthlySeries;
import 'commitments.dart' show safeToSpend;
import 'ledger.dart' show amountOf;

class SteadyPay {
  /// The suggested weekly draw in pesos, or null when history is too thin.
  final double? weeklyDraw;

  /// The monthly lean baseline behind it (mean of the three leanest of the
  /// last six full income months), or null.
  final double? leanBaseline;

  /// Full months with real income in the six-month window; below three the
  /// suggestion stays null.
  final int activeMonths;

  /// How many lean months the current liquid cash could cover, or null when
  /// there is no baseline to divide by.
  final double? runwayMonths;
  const SteadyPay({
    required this.weeklyDraw,
    required this.leanBaseline,
    required this.activeMonths,
    required this.runwayMonths,
  });
}

/// The suggestion, from the last six FULL months (the current partial month
/// never counts; judging a month mid-flight would flatter or slander it).
SteadyPay steadyPaySuggestion(dynamic data, DateTime ref) {
  final d = data is Map ? data.cast<String, dynamic>() : <String, dynamic>{};
  // Seven entries, oldest first, the last being the current month: drop it.
  final series = monthlySeries(d['transactions'], 7, ref);
  final full = series.length > 1
      ? series.sublist(0, series.length - 1)
      : const <Map<String, dynamic>>[];
  final incomes = <double>[];
  for (final m in full) {
    final inc = amountOf(m['income']);
    if (inc > 0 && inc.isFinite) incomes.add(inc);
  }
  if (incomes.length < 3) {
    return SteadyPay(
      weeklyDraw: null,
      leanBaseline: null,
      activeMonths: incomes.length,
      runwayMonths: null,
    );
  }
  incomes.sort();
  final lean = incomes.take(3).toList();
  final baseline = (lean[0] + lean[1] + lean[2]) / 3;
  final weekly = baseline * 12 / 52;
  if (!baseline.isFinite || !weekly.isFinite || !(baseline > 0)) {
    return SteadyPay(
      weeklyDraw: null,
      leanBaseline: null,
      activeMonths: incomes.length,
      runwayMonths: null,
    );
  }
  final liquid = safeToSpend(d, ref)['liquid'] as double;
  final runway = liquid.isFinite && liquid > 0 ? liquid / baseline : 0.0;
  return SteadyPay(
    weeklyDraw: weekly,
    leanBaseline: baseline,
    activeMonths: incomes.length,
    runwayMonths: runway.isFinite ? runway : null,
  );
}

class SteadyWeek {
  /// Discretionary pesos spent so far this week (Monday through today).
  final double spent;
  final double draw;

  /// draw minus spent; negative means the week ran past the pay.
  final double remaining;
  const SteadyWeek({
    required this.spent,
    required this.draw,
    required this.remaining,
  });
}

/// This week's draw status against an accepted weekly amount. Discretionary
/// only, the same exclusions the pace engine uses: interest, debt-linked, and
/// recurring-linked expenses are commitments, not the salary you pay
/// yourself.
SteadyWeek steadyPayWeek(dynamic data, DateTime ref, double draw) {
  final d = data is Map ? data.cast<String, dynamic>() : <String, dynamic>{};
  final today = DateTime(ref.year, ref.month, ref.day);
  final mondayOffset = ((today.weekday % 7) + 6) % 7;
  final monday = DateTime(today.year, today.month, today.day - mondayOffset);
  var spent = 0.0;
  final txns = d['transactions'];
  for (final raw in (txns is List ? txns : const [])) {
    if (raw is! Map) continue;
    if (raw['type'] != 'expense') continue;
    if (raw['source'] == 'interest') continue;
    final debtId = raw['debtId'];
    final recurringId = raw['recurringId'];
    if (debtId != null && debtId != false && debtId != '' && debtId != 0) {
      continue;
    }
    if (recurringId != null &&
        recurringId != false &&
        recurringId != '' &&
        recurringId != 0) {
      continue;
    }
    final ds = (raw['date'] ?? '').toString();
    if (ds.length < 10) continue;
    final p = ds.substring(0, 10).split('-');
    if (p.length != 3) continue;
    final y = int.tryParse(p[0]);
    final m = int.tryParse(p[1]);
    final day = int.tryParse(p[2]);
    if (y == null || m == null || day == null) continue;
    final when = DateTime(y, m, day);
    if (when.isBefore(monday) || when.isAfter(today)) continue;
    final a = amountOf(raw['amount']);
    if (a > 0) spent += a;
  }
  final safeDraw = draw.isFinite && draw > 0 ? draw : 0.0;
  final remaining = safeDraw - spent;
  return SteadyWeek(
    spent: spent,
    draw: safeDraw,
    remaining: remaining.isFinite ? remaining : 0,
  );
}

/// The accepted draw from settings, or null. Sanitized on load, but read
/// defensively anyway.
double? acceptedSteadyPay(dynamic data) {
  final d = data is Map ? data : const {};
  final settings = d['settings'];
  final sp = settings is Map ? settings['steadyPay'] : null;
  if (sp is! Map) return null;
  final amt = amountOf(sp['amount']);
  return amt > 0 && amt.isFinite ? amt : null;
}
