// Paluwagan: the rotating savings group (ROSCA) that runs on Filipino barkada
// and workplace trust. Every cycle all members contribute the same amount and
// one member takes the whole pot; over a full round everyone pays in and takes
// out exactly once, so it is interest free and zero sum. The ONLY variable is
// timing, and nobody explains it: an early turn is a 0% loan, a late turn is 0%
// forced savings. These pure functions compute your payout date, where you
// stand right now, and that honest read. No network, no dashes. The stored
// contribution also feeds safe-to-spend so your ambag is never mistaken for
// money you can spend.
//
// Convention: we assume you also contribute on your own payout cycle, so the
// gross pot is amount * members and your net take that month is the pot minus
// your own ambag. Some groups run the other rule (the recipient skips their own
// cycle and takes amount * (members - 1)); both are interest free and zero sum,
// they differ only by one contribution, and the setup copy names this so a real
// group is never surprised.
//
// Net-new math with no RN counterpart, so it is covered by Dart unit tests
// rather than a golden replay. Non-finite and bad-date inputs are guarded.

import 'ledger.dart' show amountOf;

const paluwaganCadences = [
  {'key': 'weekly', 'label': 'Weekly'},
  {'key': 'kinsenas', 'label': 'Kinsenas (twice a month)'},
  {'key': 'monthly', 'label': 'Monthly'},
];

const _cadenceKeys = ['weekly', 'kinsenas', 'monthly'];

// JS Number() semantics: a missing value reads as NaN (so clampInt falls back
// to its default), a blank string as 0, junk as NaN. amountOf handles the
// value case; this only exists so clampInt tells "absent" from "zero".
double _jsNum(dynamic x) {
  if (x == null) return double.nan;
  if (x is num) return x.toDouble();
  if (x is bool) return x ? 1 : 0;
  if (x is String) {
    final t = x.trim();
    if (t.isEmpty) return 0;
    return double.tryParse(t) ?? double.nan;
  }
  return double.nan;
}

int _clampInt(dynamic x, int lo, int hi, int dflt) {
  final n = _jsNum(x);
  final v = n.isFinite ? n.round() : dflt;
  return v.clamp(lo, hi);
}

double _nonNeg(double v) => v < 0 ? 0.0 : v;

// Parse 'YYYY-MM-DD' to a local Date, rejecting anything the JS Date grammar
// would silently normalize (2026-02-30). Returns null on junk so the caller
// falls back to the reference day rather than drifting a whole round.
DateTime? _parseIso(dynamic s) {
  final str = (s ?? '').toString();
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(str);
  if (m == null) return null;
  final y = int.parse(m.group(1)!);
  final mo = int.parse(m.group(2)!);
  final d = int.parse(m.group(3)!);
  if (mo < 1 || mo > 12 || d < 1 || d > 31) return null;
  final date = DateTime(y, mo, d);
  // Reject a day that rolled into the next month (Feb 30 becomes Mar 2).
  if (date.month != mo || date.day != d) return null;
  return date;
}

String _isoOf(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime _addMonths(DateTime start, int k) {
  final target = DateTime(start.year, start.month + k, 1);
  final lastDay = DateTime(target.year, target.month + 1, 0).day;
  final day = start.day < lastDay ? start.day : lastDay;
  return DateTime(target.year, target.month, day);
}

// Kinsenas paydays are the 15th and the last day of each month. Walk months
// from the start and collect paydays on or after it until we have `count`.
List<DateTime> _kinsenaSequence(DateTime start, int count) {
  final out = <DateTime>[];
  var y = start.year;
  var m = start.month;
  final startDay = _dayOnly(start);
  var guard = 0;
  while (out.length < count && guard < 2000) {
    final mid = DateTime(y, m, 15);
    final end = DateTime(y, m + 1, 0);
    for (final d in [mid, end]) {
      if (!d.isBefore(startDay) && out.length < count) out.add(d);
    }
    m += 1;
    if (m > 12) {
      m = 1;
      y += 1;
    }
    guard += 1;
  }
  return out;
}

List<DateTime> _cycleDates(DateTime start, int members, String cadence) {
  if (cadence == 'weekly') {
    return [
      for (var i = 0; i < members; i++)
        DateTime(start.year, start.month, start.day + 7 * i)
    ];
  }
  if (cadence == 'kinsenas') return _kinsenaSequence(start, members);
  return [for (var i = 0; i < members; i++) _addMonths(start, i)];
}

// Normalize a raw add/edit form into a stored paluwagan. The screen can hand in
// partial junk and get back a safe, fully shaped object.
Map<String, dynamic> newPaluwagan(Map form, DateTime ref) {
  final members = _clampInt(form['members'], 2, 60, 5);
  final cadence =
      _cadenceKeys.contains(form['cadence']) ? form['cadence'] as String : 'monthly';
  final amount = _nonNeg(amountOf(form['amount']));
  final rawName = form['name'];
  final name = (rawName is String && rawName.trim().isNotEmpty)
      ? rawName.trim()
      : 'Paluwagan';
  final rawId = form['id'];
  final rawNote = form['note'];
  final note = rawNote is String
      ? rawNote.substring(0, rawNote.length > 200 ? 200 : rawNote.length)
      : '';
  return {
    'id': (rawId is String && rawId.isNotEmpty)
        ? rawId
        : 'paluwagan_${ref.microsecondsSinceEpoch}',
    'name': name,
    'amount': amount,
    'members': members,
    'cadence': cadence,
    'startDate': _parseIso(form['startDate']) != null ? form['startDate'] : _isoOf(ref),
    'myTurn': _clampInt(form['myTurn'], 1, members, 1),
    'paidCycles': _clampInt(form['paidCycles'], 0, members, 0),
    'note': note,
  };
}

// The honest timing read, based on position in the round, not the peso amount.
String _dealType(int myTurn, int members) {
  if (members <= 1) return 'middle';
  final frac = (myTurn - 1) / (members - 1);
  if (frac <= 0.34) return 'early';
  if (frac >= 0.66) return 'late';
  return 'middle';
}

// The one decision object the screen renders. Every peso here comes from these
// functions, never invented in the widget.
Map<String, dynamic> paluwaganStatus(Map p, DateTime ref) {
  final amount = _nonNeg(amountOf(p['amount']));
  // A paluwagan needs at least two people; keep the floor identical to
  // newPaluwagan so a stored or hand-built object cannot become a degenerate
  // self-paluwagan the model would wrongly treat as valid.
  final members = _clampInt(p['members'], 2, 60, 2);
  final myTurn = _clampInt(p['myTurn'], 1, members, 1);
  final paidCycles = _clampInt(p['paidCycles'], 0, members, 0);
  final cadence =
      _cadenceKeys.contains(p['cadence']) ? p['cadence'] as String : 'monthly';

  final dates = _cycleDates(_parseIso(p['startDate']) ?? ref, members, cadence);
  final refDay = _dayOnly(ref);
  var currentCycle = 0;
  for (final d in dates) {
    if (!_dayOnly(d).isAfter(refDay)) currentCycle += 1;
  }

  final payoutDate =
      (myTurn - 1) < dates.length ? _isoOf(dates[myTurn - 1]) : null;
  final payoutAmount = amount * members;
  final contributedSoFar = amount * paidCycles;
  final remainingContribution = _nonNeg(amount * (members - paidCycles));
  final received = currentCycle >= myTurn;
  final behindBy = _nonNeg(amount * (currentCycle - paidCycles));
  final netNow = (received ? payoutAmount : 0.0) - contributedSoFar;

  return {
    'id': p['id'],
    'name': p['name'],
    'amount': amount,
    'members': members,
    'myTurn': myTurn,
    'cadence': cadence,
    'paidCycles': paidCycles,
    'currentCycle': currentCycle,
    'payoutAmount': payoutAmount,
    'payoutDate': payoutDate,
    'totalContribution': amount * members,
    'contributedSoFar': contributedSoFar,
    'remainingContribution': remainingContribution,
    'received': received,
    'cyclesToPayout': (myTurn - currentCycle) < 0 ? 0 : (myTurn - currentCycle),
    'behind': behindBy > 0,
    'behindBy': behindBy,
    'netNow': netNow,
    'done': currentCycle >= members,
    'dealType': _dealType(myTurn, members),
  };
}

// What a paluwagan takes out of a normal month, so safe-to-spend treats your
// ambag as spoken for. Zero once the round is finished or you have prepaid
// every cycle, and never more than you still owe, so a fully-prepaid member or
// a short weekly round does not over-reserve and understate spendable cash.
double paluwaganMonthlyCommitment(Map p, DateTime ref) {
  final s = paluwaganStatus(p, ref);
  final remaining = s['remainingContribution'] as double;
  if (s['done'] == true || remaining <= 0) return 0;
  final amount = s['amount'] as double;
  final cadence = s['cadence'];
  double rate;
  if (cadence == 'weekly') {
    rate = amount * (52 / 12);
  } else if (cadence == 'kinsenas') {
    rate = amount * 2;
  } else {
    rate = amount;
  }
  return rate < remaining ? rate : remaining;
}

// Sum the monthly commitment across every active paluwagan, for safe-to-spend
// and the sweldo plan.
double paluwaganTotalCommitment(dynamic list, DateTime ref) {
  if (list is! List) return 0;
  var total = 0.0;
  for (final p in list) {
    if (p is Map) total += paluwaganMonthlyCommitment(p, ref);
  }
  return total;
}
