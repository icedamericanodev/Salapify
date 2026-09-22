// The monthly net worth history: a small, append-mostly trail of one figure
// per month so Home's Net Worth hero can honestly say "up (or down) X from
// last month" instead of inventing a change it never measured. Every number
// here comes straight out of the golden-locked netWorthParts, the same helper
// the hero and the Reports already use, so a snapshot is exactly the net worth
// the app was showing the moment it was taken. This file adds NO money math of
// its own; it only remembers and compares what netWorthParts returns.
//
// Shape on disk, under data['settings']['netWorthHistory']:
//   [{ 'month': 'YYYY-MM', 'value': <double, base currency> }, ...]
// sorted oldest to newest, at most maxNetWorthMonths rows. It lives UNDER
// settings, next to the other Flutter-era collections (treats, paluwagans,
// steadyPay, expansionProgress), so it stays a CONDITIONAL key that the RN
// golden fixtures never gain and the golden key-set contract holds. The
// cleaning that keeps it in that shape on every load, save and backup lives in
// backup.dart's sanitizeData, so this file can trust the rows it reads.
import 'fx_totals.dart' show FxTable;
import 'statements.dart' show netWorthParts;

// Two years is enough for a "from last month" line and a small trend, and it
// caps an otherwise unbounded list so a phone kept for years never grows a
// heavy blob from this one feature.
const int maxNetWorthMonths = 24;

/// 'YYYY-MM' for [d], matching the month keys the analytics helpers already use
/// so a snapshot month lines up with a transaction month to the character.
String netWorthMonthKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';

/// The stored history as a clean typed list. Tolerant on read: sanitizeData is
/// the real gate, but callers (and tests) may hand this a raw map, so anything
/// that is not a well-formed row is simply skipped rather than thrown on.
List<Map<String, dynamic>> netWorthHistoryOf(Map<String, dynamic>? data) {
  final settings = data == null ? null : data['settings'];
  final raw = settings is Map ? settings['netWorthHistory'] : null;
  if (raw is! List) return const [];
  final out = <Map<String, dynamic>>[];
  for (final row in raw) {
    if (row is! Map) continue;
    final month = row['month'];
    final value = row['value'];
    if (month is! String || month.isEmpty) continue;
    if (value is! num) continue;
    out.add({'month': month, 'value': value.toDouble()});
  }
  return out;
}

/// Return [history] with [month] set to [value]: replace that month's row if it
/// already exists, otherwise insert it in date order. Result is sorted oldest
/// to newest and trimmed to the most recent [maxNetWorthMonths] rows. Pure: it
/// never mutates the input list.
List<Map<String, dynamic>> upsertNetWorthSnapshot(
  List<Map<String, dynamic>> history,
  String month,
  double value,
) {
  final next = <Map<String, dynamic>>[
    for (final row in history)
      if (row['month'] != month) {'month': row['month'], 'value': row['value']},
    {'month': month, 'value': value},
  ]..sort((a, b) => (a['month'] as String).compareTo(b['month'] as String));
  if (next.length > maxNetWorthMonths) {
    return next.sublist(next.length - maxNetWorthMonths);
  }
  return next;
}

/// The most recent snapshot value from a month STRICTLY BEFORE [currentMonth],
/// or null when no earlier month has been recorded yet (a fresh install, or the
/// very first month of use). This is the "last month" the hero compares against;
/// it is deliberately "most recent prior", not "exactly one month ago", so a
/// gap month with no snapshot still yields a sensible comparison.
double? priorNetWorthValue(
  List<Map<String, dynamic>> history,
  String currentMonth,
) {
  double? best;
  String? bestMonth;
  for (final row in history) {
    final m = row['month'] as String;
    if (m.compareTo(currentMonth) >= 0) continue;
    if (bestMonth == null || m.compareTo(bestMonth) > 0) {
      bestMonth = m;
      best = (row['value'] as num).toDouble();
    }
  }
  return best;
}

/// The change to show in the hero: the LIVE net worth now against the most
/// recent prior month's snapshot. Returns null when there is no prior month to
/// compare against, so the hero can fall back to its honest position-only view.
///
/// - delta is always the peso change (live minus prior).
/// - pct is populated ONLY when the prior value was positive AND the change is
///   within a sane bound. A percentage off a zero or negative base is
///   meaningless or misleading (you cannot be "50% better off" than a debt), and
///   a base so tiny that the change dwarfs it (a first month recorded at a few
///   pesos) produces an absurd figure like "9,999,900%". In both cases the peso
///   change is the honest signal, so pct is left null and the hero shows the
///   amount alone.
Map<String, dynamic>? netWorthTrend(
  List<Map<String, dynamic>> history,
  String currentMonth,
  double liveNetWorth,
) {
  final prior = priorNetWorthValue(history, currentMonth);
  if (prior == null) return null;
  final delta = liveNetWorth - prior;
  // A change beyond ten times the base (>1000%) is not a real monthly move, it
  // means the base was a rounding-level figure; the peso amount reads truer.
  final pctIsMeaningful = prior > 0 && (delta / prior).abs() <= 10;
  return {
    'delta': delta,
    'pct': pctIsMeaningful ? (delta / prior) * 100 : null,
    'prior': prior,
  };
}

/// The series the hero's sparkline plots: every recorded month STRICTLY BEFORE
/// the current one (frozen snapshots), then today's LIVE net worth as the final
/// point. The current month's stored snapshot, if any, is deliberately left out
/// and replaced by the live figure, so the last point on the chart always
/// matches the big number above it, never a value recorded earlier in the month.
/// Returns fewer than two points when there is not enough history to draw a
/// trend; the hero hides the chart in that case.
List<double> netWorthSeries(
  List<Map<String, dynamic>> history,
  String currentMonth,
  double liveNetWorth,
) {
  final out = <double>[
    for (final row in history)
      if ((row['month'] as String).compareTo(currentMonth) < 0)
        (row['value'] as num).toDouble(),
  ];
  out.add(liveNetWorth);
  return out;
}

/// One plotted point on the net worth trend: the month it belongs to and the
/// value recorded (or, for the final point, the live figure).
typedef NetWorthPoint = ({String month, double value});

/// The net worth points to plot for the trend screen, month-labelled so the
/// chart can print an axis. Same shape as [netWorthSeries]: every recorded
/// snapshot STRICTLY BEFORE the current month, then today's LIVE net worth as
/// the final point carrying [currentMonth], so the last point always matches
/// the big number the hero shows rather than a value recorded earlier.
///
/// [months] is the period window the selector picks: keep only the most recent
/// [months] points (1M is 1, 3M is 3, and so on), or ALL points when null. The
/// window is applied AFTER the live point is appended, so "last 3 months"
/// always includes today. History is assumed sorted ascending by month, which
/// is how [upsertNetWorthSnapshot] keeps it; this does not re-sort.
///
/// Honest about thin data: Salapify records ONE snapshot per month, so a 1M
/// window is one or two points and the screen must show a not-enough-history
/// state rather than fake a line. This returns exactly what exists, never an
/// interpolated or invented point.
List<NetWorthPoint> netWorthWindow(
  List<Map<String, dynamic>> history,
  String currentMonth,
  double liveNetWorth, {
  int? months,
}) {
  final out = <NetWorthPoint>[
    for (final row in history)
      if ((row['month'] as String).compareTo(currentMonth) < 0)
        (month: row['month'] as String, value: (row['value'] as num).toDouble()),
  ];
  out.add((month: currentMonth, value: liveNetWorth));
  if (months == null || out.length <= months) return out;
  return out.sublist(out.length - months);
}

/// Highest, lowest and average net worth across a window's points, the mockup's
/// three summary stats. Presentation over already golden net worth values (a
/// min, a max and a mean), not a new money methodology: no rounding, sign or
/// currency policy is decided here. Null when there are no points, so the
/// caller shows nothing rather than dividing by zero.
({double high, double low, double avg})? netWorthStats(
  List<NetWorthPoint> points,
) {
  if (points.isEmpty) return null;
  final values = [for (final p in points) p.value];
  final sum = values.reduce((a, b) => a + b);
  return (
    high: values.reduce((a, b) => a > b ? a : b),
    low: values.reduce((a, b) => a < b ? a : b),
    avg: sum / values.length,
  );
}

/// Record the current month's net worth into data['netWorthHistory], using the
/// SAME netWorthParts (and fx conversion) the hero displays, so the stored
/// figure is exactly the number the user saw. Returns the SAME map instance
/// (identical) when nothing needs to change, so the store can skip a redundant
/// write, exactly like postDueRecurring's no-op probe. Never mutates [data].
Map<String, dynamic> recordNetWorthSnapshot(
  Map<String, dynamic> data,
  DateTime when, {
  FxTable? fx,
}) {
  final month = netWorthMonthKey(when);
  final value = netWorthParts(data, fx: fx)['netWorth'] as double;
  final history = netWorthHistoryOf(data);
  // Skip the write when this month's snapshot already equals the live figure to
  // the centavo. Opening the app repeatedly in the same month with no change
  // must not churn a save every time.
  for (final row in history) {
    if (row['month'] == month) {
      if (((row['value'] as double) - value).abs() < 0.005) return data;
      break;
    }
  }
  final settings = data['settings'];
  final settingsMap = settings is Map
      ? Map<String, dynamic>.from(settings)
      : <String, dynamic>{};
  settingsMap['netWorthHistory'] = upsertNetWorthSnapshot(history, month, value);
  return {...data, 'settings': settingsMap};
}
