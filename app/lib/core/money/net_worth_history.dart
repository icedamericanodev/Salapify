import 'money.dart';
import 'reports.dart';

/// One month's balance sheet, kept so that "net worth over time" has a past.
///
/// FOUNDER DECISION, 2026-10-07: "Save from now on". Salapify stores only
/// TODAY's balances, so a net worth line had nothing to draw. Rebuilding the
/// past from entries was rejected: every opening balance, hand edit and
/// unlogged cash withdrawal would turn into false history, drawn with full
/// confidence. Instead the app keeps one small record per calendar month,
/// starting now, and the line grows a point a month.
///
/// WHAT A POINT MEANS. The last position the app saved during that month. It
/// is close to the month end for anybody who opens the app near the end of
/// the month, and it is never a guess: it is what the Position tab said. A
/// later edit to an old entry does NOT rewrite a past point, the same way a
/// bank statement already printed does not change.
///
/// ALL ENTITIES ONLY. The point is the whole book, every profile together,
/// which is what Position shows with no entity picked. The chart hides when
/// one entity is picked rather than show a line that does not match the
/// figure above it.
class NetWorthPoint {
  const NetWorthPoint({
    required this.year,
    required this.month,
    required this.assets,
    required this.liabilities,
  });

  final int year;

  /// 1 to 12.
  final int month;
  final Money assets;
  final Money liabilities;

  /// Exactly assets less liabilities, in centavos, the same identity the
  /// Position headline holds.
  Money get netWorth => assets - liabilities;

  /// 'YYYY-MM', the stored key. One point per month, so this is its identity.
  String get key => '$year-${month.toString().padLeft(2, '0')}';

  bool isSameMonth(DateTime d) => d.year == year && d.month == month;
}

/// [history] with this month's point set from [position], as of [now].
///
/// Called on every save. Earlier months are left exactly as they were; this
/// month's point is replaced each time, so the last save of a month is the
/// one that stays. Sorted oldest first, one point per month. Returns the
/// SAME list instance when nothing changed, so the caller can skip work.
List<NetWorthPoint> recordNetWorth(
  List<NetWorthPoint> history,
  FinancialPosition position,
  DateTime now,
) {
  final NetWorthPoint fresh = NetWorthPoint(
    year: now.year,
    month: now.month,
    assets: position.totalAssets,
    liabilities: position.totalLiabilities,
  );
  final int at = history.indexWhere((NetWorthPoint p) => p.isSameMonth(now));
  // A CLOCK SET BACKWARDS MUST NOT REWRITE A FINISHED MONTH. If a later month
  // is already recorded, "this month" by the phone's clock is in the past,
  // and replacing its stored row with today's balances would draw that month
  // wrong for good once the clock is put right. A month with a later month
  // after it is therefore never overwritten. A NEW row for such a month is
  // still allowed: blocking inserts would freeze recording for months after
  // a clock jumped forward, and losing real months is worse than gaining one
  // stray back-dated row, which netWorthSeries orders correctly anyway.
  if (at >= 0 &&
      history.any((NetWorthPoint p) => p.key.compareTo(fresh.key) > 0)) {
    return history;
  }
  if (at >= 0) {
    final NetWorthPoint old = history[at];
    if (old.assets == fresh.assets && old.liabilities == fresh.liabilities) {
      return history;
    }
  }
  return <NetWorthPoint>[
    for (final NetWorthPoint p in history)
      if (!p.isSameMonth(now)) p,
    fresh,
  ]..sort((NetWorthPoint a, NetWorthPoint b) => a.key.compareTo(b.key));
}

/// The points the chart draws: the stored past plus THIS month taken live
/// from [position], never from storage.
///
/// Live, so the newest point always equals the Position headline beside it,
/// even before anything has been saved this month. At most [max] points,
/// newest kept. Points dated after [now] (a phone whose clock went backwards)
/// are left out rather than drawn as the future.
List<NetWorthPoint> netWorthSeries(
  List<NetWorthPoint> history,
  FinancialPosition position,
  DateTime now, {
  int max = 12,
}) {
  final String today = NetWorthPoint(
    year: now.year,
    month: now.month,
    assets: Money.zero,
    liabilities: Money.zero,
  ).key;
  final List<NetWorthPoint> past = <NetWorthPoint>[
    for (final NetWorthPoint p in history)
      if (p.key.compareTo(today) < 0) p,
  ]..sort((NetWorthPoint a, NetWorthPoint b) => a.key.compareTo(b.key));
  final List<NetWorthPoint> all = <NetWorthPoint>[
    ...past,
    NetWorthPoint(
      year: now.year,
      month: now.month,
      assets: position.totalAssets,
      liabilities: position.totalLiabilities,
    ),
  ];
  return all.length <= max ? all : all.sublist(all.length - max);
}
