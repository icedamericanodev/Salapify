// The DO NEXT decision layer, ported 1:1 from mobile/lib/coach.js. The app
// computes everything about your money; this surfaces the things that need
// a decision, each with a suggested action, ranked by urgency. Pure: reads
// figures the engine produced, invents no numbers, moves no money. One
// source of truth: decisionCandidates builds the full ranked list; the Home
// check-in takes the top item and Insights renders the top few, so the two
// can never contradict each other.
//
// Priority order (desc): crunch 100 > debtdue 92 > utang 90 > overspend 85
// > hot 70 > payday 63 > forecast 60 > logtoday 58 > buffer 55 > goal 50 >
// lesson 45. (payday is a Flutter-only candidate, not in the RN twin.)

import 'analytics.dart';
import 'commitments.dart';
import 'ledger.dart' show amountOf;
import 'statements.dart' show netWorthParts;
import 'utang.dart';

double _jsRound(num x) => (x + 0.5).floorToDouble();

/// RN formatMoney: sign, peso sign, comma-grouped WHOLE pesos (messages
/// always round to the peso, m() in coach.js).
String _m(dynamic n) {
  final v = _jsRound(amountOf(n)).toInt();
  final sign = v < 0 ? '-' : '';
  final digits = v.abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write(',');
    buf.write(digits[i]);
  }
  return '$sign₱$buf';
}

String _iso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

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

/// An ISO date as 'Mon D' for coach messages; falls back to the raw string on
/// anything malformed rather than throwing.
String _md(String iso) {
  final p = iso.split('-');
  if (p.length < 3) return iso;
  final m = int.tryParse(p[1]);
  final d = int.tryParse(p[2]);
  if (m == null || m < 1 || m > 12 || d == null) return iso;
  return '${_mos[m - 1]} $d';
}

/// Essentials the coach must never tell someone to cut. Word-based, not
/// substring, with Filipino/Taglish terms. Over-inclusive is the safe side.
const Set<String> _essentialWords = {
  'food',
  'foods',
  'rent',
  'renta',
  'upa',
  'fare',
  'fares',
  'pamasahe',
  'commute',
  'load',
  'bill',
  'bills',
  'bayarin',
  'water',
  'tubig',
  'meds',
  'gamot',
  'gatas',
  'baon',
  'pagkain',
  'ospital',
  'hospital',
  'meralco',
  'tuition',
  'matrikula',
};
const List<String> _essentialStems = [
  'grocer',
  'utilit',
  'transport',
  'medic',
  'insur',
  'electr',
  'school',
  'health',
  'kuryente',
];

bool isEssentialLabel(dynamic label) {
  final tokens = (label ?? '')
      .toString()
      .toLowerCase()
      .split(RegExp(r'[^a-z]+'))
      .where((t) => t.isNotEmpty);
  return tokens.any(
    (t) =>
        _essentialWords.contains(t) ||
        _essentialStems.any((stem) => t.startsWith(stem)),
  );
}

/// A stable key for the current week (its Monday).
String weekKey(DateTime ref) {
  final d = DateTime(ref.year, ref.month, ref.day);
  final mondayOffset = ((d.weekday % 7) + 6) % 7;
  return _iso(DateTime(d.year, d.month, d.day - mondayOffset));
}

List<Map<String, dynamic>> _list(dynamic v) => [
  for (final x in (v is List ? v : const []))
    if (x is Map) x.cast<String, dynamic>(),
];

Map<String, dynamic> _cand(
  int prio,
  String kind,
  String tone,
  String title,
  String message,
  String actionLabel,
  String route,
) => {
  'prio': prio,
  'kind': kind,
  'tone': tone,
  'title': title,
  'message': message,
  'action': {'label': actionLabel, 'route': route},
};

/// The FULL ranked list of things worth a money decision right now, sorted
/// by prio descending. Empty when nothing needs a decision.
List<Map<String, dynamic>> decisionCandidates(
  Map<String, dynamic>? data,
  DateTime ref,
) {
  final d = data ?? const <String, dynamic>{};
  final cands = <Map<String, dynamic>>[];

  final s = safeToSpend(d, ref);
  final liquid = s['liquid'] as double;
  final available = s['available'] as double;
  if (liquid > 0 && available <= 0) {
    cands.add(
      _cand(
        100,
        'crunch',
        'urgent',
        'Money is tight until payday',
        'The bills and minimums due before your next payday already use up your spendable cash. Best to hold off on extras until payday.',
        'See what is committed',
        '/insights',
      ),
    );
  }

  final u = utangAging(d, ref);
  final worst = u['worst'];
  if ((u['overdueCount'] as int) > 0 && worst is Map) {
    final name = worst['name'];
    final days = worst['daysOverdue'] as int;
    cands.add(
      _cand(
        90,
        'utang',
        'watch',
        'Follow up $name',
        '$name is $days ${days == 1 ? 'day' : 'days'} overdue on ${_m(worst['outstanding'])}. A calm reminder keeps both the money and the friendship healthy.',
        'Open utang list',
        '/receivables',
      ),
    );
  }

  final rate = savingsRate(d['transactions'] ?? [], d['payments'] ?? [], ref);
  if (rate != null && rate < 0) {
    cands.add(
      _cand(
        85,
        'overspend',
        'watch',
        'Spending passed income this month',
        'More went out than came in this month. No shame, it happens. The fastest fix is easing the one category running hottest.',
        'See where it went',
        '/insights',
      ),
    );
  }

  final dues = upcomingDues(d['debts'], 7, ref);
  if (dues.isNotEmpty) {
    final debt =
        (dues[0]['debt'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final rawName = debt['name'];
    final name = (rawName is String && rawName.isNotEmpty) ? rawName : 'A debt';
    final revolving = debt['type'] == 'credit card' || debt['type'] == 'bnpl';
    cands.add(
      _cand(
        92,
        'debtdue',
        'watch',
        '$name is due soon',
        revolving
            ? '$name is due within the week. Paying it in full keeps you interest free; at least pay the minimum to dodge a late fee.'
            : '$name is due within the week. Do not miss it, a late payment usually adds a fee on top.',
        'Open debts',
        '/debts',
      ),
    );
  }

  final vs = categoryVsAverage(d['transactions'] ?? [], ref);
  Map<String, dynamic>? hot;
  for (final v in vs) {
    final expected = v['expected'] as double;
    final now = v['now'] as double;
    if (expected > 0 && now > expected * 1.2) {
      hot = v;
      break;
    }
  }
  if (hot != null) {
    final label = hot['label'];
    final essential = isEssentialLabel(label);
    cands.add(
      _cand(
        70,
        'hot',
        'watch',
        '$label is running hot',
        essential
            ? '$label is running higher than your usual pace this month, worth a look.'
            : 'You are about ${_m((hot['now'] as double) - (hot['expected'] as double))} over your usual $label pace for this point in the month. Easing back frees that before payday.',
        'See categories',
        '/insights',
      ),
    );
  }

  final f = forecastMonthEnd(d['transactions'] ?? [], ref);
  final limit = amountOf(
    d['settings'] is Map ? (d['settings'] as Map)['monthlyLimit'] : null,
  );
  if (limit > 0 &&
      (f['dayOfMonth'] as int) >= 7 &&
      (f['projected'] as double) > limit) {
    cands.add(
      _cand(
        60,
        'forecast',
        'watch',
        'On track to go over budget',
        "At today's pace you will spend about ${_m(f['projected'])} by month end, over your ${_m(limit)} limit. Trimming a little each day gets you back under.",
        'Check budget',
        '/budget',
      ),
    );
  }

  // Will you make it to sweldo? A Flutter-only decision (no RN twin), so it is
  // additive to the ported ladder and never fires on the RN golden fixtures.
  // Only speaks when there is spendable cash left (available > 0), which is
  // exactly the case crunch at prio 100 does NOT cover, so the two can never
  // fire together. Silent on thin logging.
  final pp = paydayProjection(d, ref);
  if (pp != null && pp['onTrack'] == false && (pp['daysShort'] as int) >= 1) {
    final short = pp['daysShort'] as int;
    final dayWord = short == 1 ? 'day' : 'days';
    cands.add(
      _cand(
        63,
        'payday',
        'watch',
        '$short $dayWord short before payday',
        'At about ${_m(pp['dailyPace'])} a day you would run thin around ${_md(pp['runOutISO'] as String)}, $short $dayWord before your ${_md(pp['payday'] as String)} payday. Easing about ${_m(pp['easeOff'])} a day gets you all the way there.',
        'See what is running hot',
        '/insights',
      ),
    );
  }

  final todayStr = _iso(ref);
  final accounts = d['accounts'];
  final transactions = d['transactions'];
  final hasStarted =
      (accounts is List && accounts.isNotEmpty) ||
      (transactions is List && transactions.isNotEmpty);
  final loggedToday = _list(transactions).any(
    (t) =>
        (t['type'] == 'income' || t['type'] == 'expense') &&
        t['date'] == todayStr,
  );
  if (hasStarted && !loggedToday) {
    cands.add(
      _cand(
        58,
        'logtoday',
        'nudge',
        'Log today',
        'Two seconds keeps your numbers honest. Add what you spent today.',
        'Add spending',
        '/',
      ),
    );
  }

  final rw = emergencyRunway(d, ref);
  final monthsCovered = rw['monthsCovered'];
  if (monthsCovered != null && (monthsCovered as num) < 1 && available > 0) {
    final shortfall = (rw['firstTarget'] as num) - (rw['buffer'] as num);
    final nudge = shortfall > 0
        ? 'Even ${_m(shortfall)} more toward your first cushion'
        : 'Even a little more toward your first full month';
    cands.add(
      _cand(
        55,
        'buffer',
        'nudge',
        'Your buffer is thin',
        'Your buffer covers under a month. $nudge helps stop a surprise from becoming utang.',
        'Open goals',
        '/goals',
      ),
    );
  }

  for (final g in _list(d['goals'])) {
    if (!(amountOf(g['target']) > 0)) continue;
    final p = goalPace(g, ref);
    if (p['status'] == 'behind') {
      final rawName = g['name'];
      final name = (rawName is String && rawName.isNotEmpty)
          ? rawName
          : 'Your goal';
      final titleName = (rawName is String && rawName.isNotEmpty)
          ? rawName
          : 'A goal';
      cands.add(
        _cand(
          50,
          'goal',
          'nudge',
          '$titleName slipped its date',
          available <= 0
              ? "$name's target date has passed. It is okay to pause this goal for now, bills come first. Come back to it when this cycle eases up."
              : '$name is ${_jsRound((p['pct'] as double) * 100).toInt()}% funded and its target date has passed with ${_m(p['remaining'])} to go. Set a fresh date and I will pace it again.',
          'Open goals',
          '/goals',
        ),
      );
      break;
    }
  }

  final debts = _list(d['debts']);
  final hasCard = debts.any(
    (x) => x['type'] == 'credit card' && amountOf(x['remaining']) > 0,
  );
  final hasBnpl = debts.any(
    (x) => x['type'] == 'bnpl' && amountOf(x['remaining']) > 0,
  );
  final hasReceivables = (u['people'] as List).isNotEmpty;
  final yearEnd = ref.month == 11 || ref.month == 12;
  (int, String, String, String)? lesson;
  if (yearEnd) {
    lesson = (
      45,
      'thirteenth-month',
      'Make your 13th month count',
      '13th month season is here. A short read on making your 13th month pay actually last, so it does not vanish by January.',
    );
  } else if (hasCard) {
    lesson = (
      40,
      'card-interest',
      'Beat the minimum payment trap',
      'You are carrying a card balance. A two minute read on how paying only the minimum quietly grows what you owe, and the one rule that stops it.',
    );
  } else if (hasBnpl) {
    lesson = (
      38,
      'bnpl',
      'Keep BNPL from piling up',
      'You have a buy now pay later balance. A quick read on keeping the installments from stacking past what one paycheck can cover.',
    );
  } else if (hasReceivables) {
    lesson = (
      34,
      'utang-friends',
      'Collect utang the kind way',
      'People owe you. A short read on getting paid back without losing the friendship.',
    );
  }
  if (lesson != null) {
    cands.add(
      _cand(
        lesson.$1,
        'lesson',
        'nudge',
        lesson.$3,
        lesson.$4,
        'Read the lesson',
        '/learn?focus=${lesson.$2}',
      ),
    );
  }

  final indexed = List.generate(cands.length, (i) => (cands[i], i));
  indexed.sort((a, b) {
    final c = (b.$1['prio'] as int).compareTo(a.$1['prio'] as int);
    return c != 0 ? c : a.$2.compareTo(b.$2);
  });
  return [for (final e in indexed) e.$1];
}

/// The single top-ranked decision, or a calm all-clear when nothing needs
/// one. Home excludes the daily habit nudges on purpose.
Map<String, dynamic> weeklyCheckIn(Map<String, dynamic>? data, DateTime ref) {
  final cands = decisionCandidates(data, ref);
  final week = weekKey(ref);
  for (final c in cands) {
    if (c['kind'] != 'logtoday' && c['kind'] != 'buffer') {
      return {
        'kind': c['kind'],
        'tone': c['tone'],
        'title': c['title'],
        'message': c['message'],
        'action': c['action'],
        'week': week,
      };
    }
  }
  return {
    'kind': 'good',
    'tone': 'good',
    'title': 'You are on track this week',
    'message':
        'Nothing needs a money decision right now. Keep logging and enjoy the calm.',
    'action': null,
    'week': week,
  };
}

/// JS Number() semantics where null is 0 and junk is NaN; used only for the
/// nwHistory finite check, which deliberately accepts a null value as 0.
double _jsNumber(dynamic v) {
  if (v == null) return 0;
  if (v == true) return 1;
  if (v == false) return 0;
  if (v is num) return v.toDouble();
  if (v is String) {
    if (v.trim().isEmpty) return 0;
    return double.tryParse(v.trim()) ?? double.nan;
  }
  return double.nan;
}

/// One honest positive, or null. Every branch is a real fact from the
/// engine; nothing positive is ever celebrated on sparse logs.
Map<String, dynamic>? pickWin(Map<String, dynamic>? data, DateTime ref) {
  final d = data ?? const <String, dynamic>{};

  final nw = netWorthParts(d)['netWorth'] as double;
  final rawHist = d['settings'] is Map
      ? (d['settings'] as Map)['nwHistory']
      : null;
  final hist = [
    for (final h in (rawHist is List ? rawHist : const []))
      if (h is Map && h['month'] is String && _jsNumber(h['value']).isFinite)
        h.cast<String, dynamic>(),
  ];
  final curKey = _iso(ref).substring(0, 7);
  final prior =
      hist.where((h) => (h['month'] as String).compareTo(curKey) < 0).toList()
        ..sort(
          (a, b) => (a['month'] as String).compareTo(b['month'] as String),
        );
  final prev = prior.isNotEmpty ? prior.last : null;
  if (prev != null && nw > _jsNumber(prev['value'])) {
    return {
      'text':
          'Your net worth is up ${_m(nw - _jsNumber(prev['value']))} since your last check-in.',
    };
  }

  ({String name, double pct})? best;
  for (final g in _list(d['goals'])) {
    if (!(amountOf(g['target']) > 0)) continue;
    final p = goalPace(g, ref);
    final pct = p['pct'] is num ? (p['pct'] as num).toDouble() : 0.0;
    if (pct >= 0.8 && (best == null || pct > best.pct)) {
      final rawName = g['name'];
      best = (
        name: (rawName is String && rawName.isNotEmpty) ? rawName : 'Your goal',
        pct: pct,
      );
    }
  }
  if (best != null) {
    return best.pct >= 1
        ? {'text': '${best.name} is fully funded. 🎉'}
        : {
            'text':
                'Almost there: ${best.name} is ${_jsRound(best.pct * 100).toInt()}% funded.',
          };
  }

  final logged = <dynamic>{};
  for (final t in _list(d['transactions'])) {
    if (t['type'] == 'income' || t['type'] == 'expense') logged.add(t['date']);
  }
  var daysLogged = 0;
  for (var i = 0; i < 7; i++) {
    final day = DateTime(ref.year, ref.month, ref.day - i);
    if (logged.contains(_iso(day))) daysLogged += 1;
  }
  final loggingHealthy = daysLogged >= 4;

  final rate = savingsRate(d['transactions'] ?? [], d['payments'] ?? [], ref);
  if (loggingHealthy && rate != null && rate > 0) {
    return {
      'text':
          'You kept ${_jsRound(rate * 100).toInt()}% of your income this month. Nice.',
    };
  }

  if (loggingHealthy) {
    return {
      'text':
          'You have logged $daysLogged of the last 7 days. That habit is the win.',
    };
  }

  return null;
}
