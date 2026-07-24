// Your Number: the one figure a user carries through the payday cycle, "how
// much can I spend a day and still reach payday". This module computes NO new
// money math. It composes the golden-locked safeToSpend (perDay is the
// number) and paydayProjection (the pace read), and derives only calendar
// facts (days since the last log), so every peso on the Home card comes from
// an engine that is already tested.
//
// One card state on purpose: the card shows ONLY when there is a positive
// number to show. Crunch (committed cash eats everything) is owned by the
// coach's prio-100 check-in card that sits right above; rendering a second
// scary card for the same fact would stack warnings, the exact thing
// paydayProjection's own silence rule exists to avoid.

import 'commitments.dart' show paydayProjection, safeToSpend;

class CycleStatus {
  /// True only for the 'ok' reason: Home renders the card solely then.
  final bool show;

  /// 'ok' | 'fresh' (nothing logged yet) | 'quiet' (no liquid cash) |
  /// 'committed' (bills eat it, coach crunch owns the message) |
  /// 'nonfinite' (junk backup values, stay silent rather than lie)
  final String reason;
  final double perDay;
  final int daysLeft;
  final String payday; // ISO date of the next payday
  final double available;

  /// Null when paydayProjection stays silent (thin logging); otherwise
  /// whether the recent discretionary pace fits the number.
  final bool? onTrack;
  final double dailyPace;
  final double easeOff;

  /// Whole days since the last logged income or expense, -1 when none exist.
  final int gapDays;

  /// A lapse worth greeting kindly (3+ quiet days), never scolding.
  final bool comeback;

  const CycleStatus({
    required this.show,
    required this.reason,
    this.perDay = 0,
    this.daysLeft = 0,
    this.payday = '',
    this.available = 0,
    this.onTrack,
    this.dailyPace = 0,
    this.easeOff = 0,
    this.gapDays = -1,
    this.comeback = false,
  });
}

int _gapDays(dynamic transactions, DateTime ref) {
  // ISO date strings compare chronologically, so track the max as a string.
  String latest = '';
  for (final raw in (transactions is List ? transactions : const [])) {
    if (raw is! Map) continue;
    if (raw['type'] != 'income' && raw['type'] != 'expense') continue;
    final ds = (raw['date'] ?? '').toString();
    if (ds.length < 10) continue;
    final day = ds.substring(0, 10);
    if (day.compareTo(latest) > 0) latest = day;
  }
  if (latest.isEmpty) return -1;
  final p = latest.split('-');
  final y = int.tryParse(p[0]);
  final m = p.length > 1 ? int.tryParse(p[1]) : null;
  final d = p.length > 2 ? int.tryParse(p[2]) : null;
  if (y == null || m == null || d == null) return -1;
  final today = DateTime(ref.year, ref.month, ref.day);
  final gap = today.difference(DateTime(y, m, d)).inDays;
  // A future-dated log reads as zero gap, never a negative streak of quiet.
  return gap < 0 ? 0 : gap;
}

/// The Home card's whole state, composed from tested engines. Junk never
/// throws; anything unreadable resolves to a silent state.
CycleStatus cycleStatus(dynamic data, DateTime ref) {
  final d = data is Map ? data.cast<String, dynamic>() : <String, dynamic>{};
  final accounts = d['accounts'];
  final transactions = d['transactions'];
  final hasStarted =
      (accounts is List && accounts.isNotEmpty) ||
      (transactions is List && transactions.isNotEmpty);
  if (!hasStarted) return const CycleStatus(show: false, reason: 'fresh');

  final s = safeToSpend(d, ref);
  final liquid = s['liquid'] as double;
  final available = s['available'] as double;
  final perDay = s['perDay'] as double;
  if (!liquid.isFinite || !available.isFinite || !perDay.isFinite) {
    return const CycleStatus(show: false, reason: 'nonfinite');
  }
  if (available <= 0) {
    return CycleStatus(show: false, reason: liquid > 0 ? 'committed' : 'quiet');
  }

  final pp = paydayProjection(d, ref);
  final gap = _gapDays(transactions, ref);
  return CycleStatus(
    show: true,
    reason: 'ok',
    perDay: perDay,
    daysLeft: s['daysLeft'] as int,
    payday: (s['payday'] ?? '').toString(),
    available: available,
    onTrack: pp == null ? null : pp['onTrack'] as bool,
    dailyPace: pp == null ? 0 : pp['dailyPace'] as double,
    easeOff: pp == null ? 0 : pp['easeOff'] as double,
    gapDays: gap,
    comeback: gap >= 3,
  );
}
