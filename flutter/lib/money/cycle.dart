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
import 'ledger.dart' show amountOf;
import 'schedule.dart'
    show daysUntilPayday, hasExplicitPaydaySchedule, prevPayday;

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
  // Validate each candidate BEFORE taking the max: a junk date that sorts
  // lexicographically above the real ones (an imported "corrupted!" row)
  // must not win the max and mute the comeback greeting for valid logs.
  DateTime? latest;
  for (final raw in (transactions is List ? transactions : const [])) {
    if (raw is! Map) continue;
    if (raw['type'] != 'income' && raw['type'] != 'expense') continue;
    final ds = (raw['date'] ?? '').toString();
    if (ds.length < 10) continue;
    final p = ds.substring(0, 10).split('-');
    if (p.length != 3) continue;
    final y = int.tryParse(p[0]);
    final m = int.tryParse(p[1]);
    final d = int.tryParse(p[2]);
    if (y == null || m == null || d == null) continue;
    final when = DateTime(y, m, d);
    if (latest == null || when.isAfter(latest)) latest = when;
  }
  if (latest == null) return -1;
  final today = DateTime(ref.year, ref.month, ref.day);
  final gap = today.difference(latest).inDays;
  // A future-dated log reads as zero gap, never a negative streak of quiet.
  return gap < 0 ? 0 : gap;
}

class PaydayRitual {
  /// Today is a payday on the user's own schedule, and there is data to act
  /// on, so the payday card shows.
  final bool isPayday;

  /// A real salary-like income was logged today (receivable collections do
  /// not count; getting paid back is not a salary). Flips the card from the
  /// invitation to the done state.
  final bool salaryLogged;
  const PaydayRitual({required this.isPayday, required this.salaryLogged});
}

/// The payday-morning ritual state, fully derived: no stored flag anywhere,
/// so the card can never disagree with the ledger. Junk never throws.
PaydayRitual paydayRitual(dynamic data, DateTime ref) {
  final d = data is Map ? data.cast<String, dynamic>() : <String, dynamic>{};
  final accounts = d['accounts'];
  final transactions = d['transactions'];
  final hasStarted =
      (accounts is List && accounts.isNotEmpty) ||
      (transactions is List && transactions.isNotEmpty);
  if (!hasStarted) {
    return const PaydayRitual(isPayday: false, salaryLogged: false);
  }
  // Never CLAIM it is payday from a guess. Until the user sets their payday,
  // the schedule is only normalizeSchedule's 15/31 fallback, and telling a
  // monthly-on-the-30th earner "it is payday" on the 15th is simply false.
  // Forecasts may keep using the default; an assertion may not.
  if (!hasExplicitPaydaySchedule(d)) {
    return const PaydayRitual(isPayday: false, salaryLogged: false);
  }
  final settings = d['settings'];
  final schedule = settings is Map ? settings['paydaySchedule'] : null;
  final isPayday = daysUntilPayday(ref, schedule) == 0;
  if (!isPayday) {
    return const PaydayRitual(isPayday: false, salaryLogged: false);
  }
  final today =
      '${ref.year.toString().padLeft(4, '0')}-${ref.month.toString().padLeft(2, '0')}-${ref.day.toString().padLeft(2, '0')}';
  var logged = false;
  for (final raw in (transactions is List ? transactions : const [])) {
    if (raw is! Map) continue;
    if (raw['type'] != 'income') continue;
    if (raw['source'] == 'receivable') continue;
    final ds = (raw['date'] ?? '').toString();
    if (ds.length >= 10 && ds.substring(0, 10) == today) {
      logged = true;
      break;
    }
  }
  return PaydayRitual(isPayday: true, salaryLogged: logged);
}

const List<String> _mos = [
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

double _jsRound(num x) => (x + 0.5).floorToDouble();

DateTime? _parseDay(dynamic raw) {
  final ds = (raw ?? '').toString();
  if (ds.length < 10) return null;
  final p = ds.substring(0, 10).split('-');
  if (p.length != 3) return null;
  final y = int.tryParse(p[0]);
  final m = int.tryParse(p[1]);
  final d = int.tryParse(p[2]);
  if (y == null || m == null || d == null) return null;
  return DateTime(y, m, d);
}

/// The payday-cycle recap: the month recap's honest story re-windowed to
/// [prevPayday .. today], so the share card can end each sweldo cycle on a
/// summary instead of a fade-out. Same shape as the golden-locked monthRecap
/// (the card widget reads it unchanged) but a separate, unit-tested
/// implementation; the golden file is never touched. Verdicts celebrate the
/// behavior, never shame: a rough cycle that was tracked honestly is still a
/// card worth sharing.
Map<String, dynamic> cycleRecap(dynamic data, DateTime ref) {
  final d = data is Map ? data.cast<String, dynamic>() : <String, dynamic>{};
  final settings = d['settings'];
  final schedule = settings is Map ? settings['paydaySchedule'] : null;
  final today = DateTime(ref.year, ref.month, ref.day);
  // On payday itself prevPayday returns today, which would collapse the
  // window to hours and brag "kept 100%" about a cycle just born. Payday is
  // exactly when the FINISHED cycle is worth sharing, so on a payday the
  // window becomes the completed cycle: from the payday before, through
  // yesterday, keeping today's fresh salary out of the finished story.
  var start = prevPayday(ref, schedule);
  var end = today;
  if (!start.isBefore(today)) {
    end = DateTime(today.year, today.month, today.day - 1);
    start = prevPayday(end, schedule);
  }
  bool inWindow(DateTime? when) =>
      when != null && !when.isBefore(start) && !when.isAfter(end);

  // Category naming must match the golden monthRecap exactly (categoryId
  // resolves through the categories list first, then the label, then Other,
  // with the same falsy folding), or the two windows on one screen would
  // name a different top category for the same rows. categoryId is alive:
  // imported RN backups and the Flutter budget quick-add both write it.
  final cats = d['categories'] is List ? d['categories'] as List : const [];
  final catNames = <dynamic, dynamic>{
    for (final c in cats)
      if (c is Map) c['id']: c['name'],
  };
  String jsStr(dynamic v) =>
      (v == null || v == false || v == 0 || v == '' || (v is double && v.isNaN))
      ? ''
      : v.toString();

  var moneyIn = 0.0;
  var moneyOut = 0.0;
  final byCat = <String, Map<String, dynamic>>{};
  final byCatOrder = <String>[];
  final days = <String>{};
  final txns = d['transactions'];
  for (final raw in (txns is List ? txns : const [])) {
    if (raw is! Map) continue;
    final when = _parseDay(raw['date']);
    if (!inWindow(when)) continue;
    final ds = raw['date'].toString().substring(0, 10);
    if (raw['type'] == 'income') {
      days.add(ds);
      if (raw['source'] != 'receivable') moneyIn += amountOf(raw['amount']);
    } else if (raw['type'] == 'expense') {
      days.add(ds);
      final amt = amountOf(raw['amount']);
      moneyOut += amt;
      final catId = raw['categoryId'];
      final catName =
          (catId != null && catId != false && catId != '' && catId != 0)
          ? catNames[catId]
          : null;
      var name = jsStr(catName).trim();
      if (name.isEmpty) name = jsStr(raw['label']).trim();
      if (name.isEmpty) name = 'Other';
      final k = name.toLowerCase();
      var bucket = byCat[k];
      if (bucket == null) {
        bucket = {'label': name, 'amount': 0.0};
        byCat[k] = bucket;
        byCatOrder.add(k);
      }
      bucket['amount'] = (bucket['amount'] as double) + amt;
    }
  }

  final indexed = [
    for (var i = 0; i < byCatOrder.length; i++) (byCat[byCatOrder[i]]!, i),
  ];
  indexed.sort((a, b) {
    final c = (b.$1['amount'] as double).compareTo(a.$1['amount'] as double);
    return c != 0 ? c : a.$2.compareTo(b.$2);
  });
  final topCats = [
    for (final e in indexed.take(3))
      {
        ...e.$1,
        'pct': moneyOut > 0
            ? _jsRound((e.$1['amount'] as double) / moneyOut * 100)
            : 0.0,
      },
  ];

  var debtPaid = 0.0;
  final payments = d['payments'];
  for (final p in (payments is List ? payments : const [])) {
    if (p is! Map) continue;
    if (!inWindow(_parseDay(p['date']))) continue;
    final part = amountOf(p['principal'] ?? p['amount']);
    if (part > 0) debtPaid += part;
  }

  var utangCollected = 0.0;
  final receivables = d['receivables'];
  for (final r in (receivables is List ? receivables : const [])) {
    if (r is! Map) continue;
    final pays = r['payments'];
    for (final p in (pays is List ? pays : const [])) {
      if (p is! Map) continue;
      if (!inWindow(_parseDay(p['date']))) continue;
      final a = amountOf(p['amount']);
      if (a > 0) utangCollected += a;
    }
  }

  final kept = moneyIn - moneyOut;
  final rawRate = moneyIn > 0 ? kept / moneyIn : null;
  final double? keptRate = (rawRate != null && rawRate.isFinite)
      ? rawRate
      : null;

  final startLabel = '${_mos[start.month - 1]} ${start.day}';
  String verdict;
  if (moneyIn == 0 &&
      moneyOut == 0 &&
      days.isEmpty &&
      debtPaid == 0 &&
      utangCollected == 0) {
    verdict = 'A quiet cycle so far. Log your money and payday tells a story.';
  } else if (keptRate != null && keptRate >= 0.2) {
    verdict =
        "You kept ${_jsRound(keptRate * 100).toInt()}% of this cycle's income. Reaching payday with money left is the whole game.";
  } else if (keptRate != null && keptRate > 0) {
    verdict =
        "You kept ${_jsRound(keptRate * 100).toInt()}% of this cycle's income. Every peso that survives to payday counts.";
  } else if (keptRate != null) {
    verdict =
        'Spending passed income this cycle, and you tracked every day of it honestly. The next payday is a fresh start.';
  } else {
    verdict =
        'You tracked this cycle honestly. That habit is what changes things.';
  }

  return {
    'label': 'payday cycle since $startLabel',
    'kicker': 'MY CYCLE SINCE ${startLabel.toUpperCase()}',
    // The card's hide-amounts lines say "of my income this <noun>"; the
    // month map has no noun and falls back to 'month'.
    'windowNoun': 'cycle',
    'monthKey':
        'cycle-${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}',
    'moneyIn': moneyIn,
    'moneyOut': moneyOut,
    'kept': kept,
    'keptRate': keptRate,
    'topCats': topCats,
    'biggest': null,
    'daysLogged': days.length,
    'debtPaid': debtPaid,
    'utangCollected': utangCollected,
    'verdict': verdict,
  };
}

/// The share-as-text fallback for the cycle window, mirroring the golden
/// recapText line for line but saying "cycle" where it says "month" (the
/// golden file stays untouched).
String cycleRecapText(
  Map<String, dynamic> recap,
  String Function(num) formatMoney, [
  bool hideAmounts = false,
]) {
  final lines = <String>['My ${recap['label']} with Salapify:'];
  final keptRate = recap['keptRate'];
  if (keptRate != null) {
    if (hideAmounts) {
      lines.add(
        (recap['kept'] as double) >= 0
            ? 'Kept ${_jsRound((keptRate as double) * 100).toInt()}% of my income this cycle.'
            : 'Spending passed my income this cycle.',
      );
    } else {
      lines.add(
        'Money in ${formatMoney(recap['moneyIn'] as double)}, out ${formatMoney(recap['moneyOut'] as double)}, kept ${formatMoney(recap['kept'] as double)}.',
      );
    }
  }
  final topCats = recap['topCats'] as List;
  if (topCats.isNotEmpty) {
    final top = topCats.first as Map;
    lines.add(
      'Top spending: ${top['label']} (${(top['pct'] as num).toInt()}%).',
    );
  }
  final daysLogged = recap['daysLogged'] as int;
  if (daysLogged > 0) {
    lines.add('Logged $daysLogged ${daysLogged == 1 ? 'day' : 'days'}.');
  }
  lines.add(recap['verdict'] as String);
  lines.add("Tracked with Salapify, on your money's side. ☕");
  return lines.join('\n');
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
