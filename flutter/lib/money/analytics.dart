// The Insights analytics engine, ported 1:1 from mobile/lib/analytics.js
// (goalPace 201-244, previousMonthLeftover 255-273, monthlySeries 279-296,
// categoryTotals 299-309, categoryMovers 313-325, categoryVsAverage 331-358,
// weekdayPattern 362-380, savingsRate 420-431, forecastMonthEnd 434-444,
// emergencyRunway 517-553, healthScore 559-596). Pure functions over the data
// blob, golden-verified against outputs produced by executing the real RN
// module, so every insight number matches the live app exactly.
//
// JS semantics preserved on purpose:
// - Number(x)||0 coercion via ledger.amountOf, junk rows are shrugged off
// - Math.round is floor(x + 0.5), mirrored by _jsRound
// - month arithmetic goes through the Date constructor's overflow
//   normalization, which DateTime shares
// - sort ties keep insertion order (JS sort is stable; Dart's is not, so an
//   index tiebreak is added)

import 'ledger.dart' show amountOf;

double _jsRound(num x) => (x + 0.5).floorToDouble();

String _monthKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}';

String _iso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

const List<String> _monthsShort = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

List<Map<String, dynamic>> _txs(dynamic transactions) => [
      for (final t in (transactions is List ? transactions : const []))
        if (t is Map) t.cast<String, dynamic>(),
    ];

/// Per-goal progress plus the honest catch-up pace, statuses
/// done | behind | due-soon | active | no-date | no-target.
Map<String, dynamic> goalPace(Map<String, dynamic>? goal, DateTime ref) {
  final target = amountOf(goal?['target']).clamp(0, double.infinity).toDouble();
  final saved = amountOf(goal?['saved']).clamp(0, double.infinity).toDouble();
  final rawDate = goal?['targetDate'];
  final targetDate = rawDate is String ? rawDate.trim() : '';
  if (target <= 0) {
    return {
      'pct': 0, 'saved': saved, 'target': target, 'remaining': 0,
      'done': false, 'status': 'no-target', 'monthsLeft': null,
      'perMonth': 0, 'perWeek': 0, 'targetDate': targetDate,
    };
  }
  final remaining =
      (target - saved) > 0 ? (target - saved) : 0.0;
  final pct = saved / target < 1 ? saved / target : 1.0;
  final base = {
    'pct': pct, 'saved': saved, 'target': target,
    'remaining': remaining, 'targetDate': targetDate,
  };
  if (remaining <= 0) {
    return {
      ...base, 'pct': 1, 'done': true, 'status': 'done',
      'monthsLeft': 0, 'perMonth': 0, 'perWeek': 0,
    };
  }
  final m = RegExp(r'^(\d{4})-(\d{2})(?:-(\d{2}))?$').firstMatch(targetDate);
  final mo = m != null ? int.parse(m.group(2)!) - 1 : -1;
  if (m == null || mo < 0 || mo > 11) {
    return {
      ...base, 'done': false, 'status': 'no-date',
      'monthsLeft': null, 'perMonth': 0, 'perWeek': 0,
    };
  }
  final y = int.parse(m.group(1)!);
  final today = DateTime(ref.year, ref.month, ref.day);
  final lastDay = DateTime(y, mo + 2, 0).day;
  var day = m.group(3) != null ? int.parse(m.group(3)!) : lastDay;
  if (day < 1) day = 1;
  if (day > lastDay) day = lastDay;
  final deadline = DateTime(y, mo + 1, day);
  final monthsLeft = (y - ref.year) * 12 + ((mo + 1) - ref.month);
  if (deadline.isBefore(today)) {
    return {
      ...base, 'done': false, 'status': 'behind', 'monthsLeft': monthsLeft,
      'perMonth': remaining, 'perWeek': remaining,
    };
  }
  if (monthsLeft <= 0) {
    return {
      ...base, 'done': false, 'status': 'due-soon',
      'monthsLeft': monthsLeft > 0 ? monthsLeft : 0,
      'perMonth': remaining, 'perWeek': remaining,
    };
  }
  final perMonth = (remaining / monthsLeft).ceil();
  final perWeek = (remaining / (monthsLeft * (52 / 12))).ceil();
  return {
    ...base, 'done': false, 'status': 'active', 'monthsLeft': monthsLeft,
    'perMonth': perMonth, 'perWeek': perWeek,
  };
}

/// Last month's unspent budget, floored at 0; nothing when last month had no
/// logged expenses (an unknown month must never double this month's budget).
double previousMonthLeftover(
    dynamic transactions, dynamic monthlyLimit, DateTime ref) {
  final limit = amountOf(monthlyLimit);
  if (limit <= 0) return 0;
  final prevKey = _monthKey(DateTime(ref.year, ref.month - 1, 1));
  var spent = 0.0;
  var count = 0;
  for (final x in _txs(transactions)) {
    if (x['type'] == 'expense' &&
        (x['date'] ?? '').toString().length >= 7 &&
        (x['date'] ?? '').toString().substring(0, 7) == prevKey) {
      spent += amountOf(x['amount']);
      count += 1;
    }
  }
  if (count == 0) return 0;
  final left = limit - spent;
  return left > 0 ? left : 0;
}

String _month7(dynamic date) {
  final s = (date ?? '').toString();
  return s.length >= 7 ? s.substring(0, 7) : s;
}

/// Income, expenses, and net for each of the last n months, oldest first.
/// Utang collected (source receivable) is not income.
List<Map<String, dynamic>> monthlySeries(
    dynamic transactions, int n, DateTime ref) {
  final out = <Map<String, dynamic>>[];
  final txs = _txs(transactions);
  for (var i = n - 1; i >= 0; i--) {
    final d = DateTime(ref.year, ref.month - i, 1);
    final key = _monthKey(d);
    var income = 0.0;
    var expenses = 0.0;
    for (final t in txs) {
      if (_month7(t['date']) != key) continue;
      if (t['type'] == 'income' && t['source'] != 'receivable') {
        income += amountOf(t['amount']);
      } else if (t['type'] == 'expense') {
        expenses += amountOf(t['amount']);
      }
    }
    out.add({
      'key': key,
      'label': _monthsShort[d.month - 1],
      'income': income,
      'expenses': expenses,
      'net': income - expenses,
    });
  }
  return out;
}

Map<String, double> _categoryTotals(
    List<Map<String, dynamic>> txs, int offset, DateTime ref) {
  final key = _monthKey(DateTime(ref.year, ref.month - offset, 1));
  final totals = <String, double>{};
  for (final t in txs) {
    if (t['type'] != 'expense' || _month7(t['date']) != key) continue;
    final raw = t['label'];
    final label =
        (raw is String && raw.trim().isNotEmpty) ? raw.trim() : 'Other';
    totals[label] = (totals[label] ?? 0) + amountOf(t['amount']);
  }
  return totals;
}

List<T> _stableSorted<T>(List<T> list, int Function(T, T) compare) {
  final indexed = List.generate(list.length, (i) => (list[i], i));
  indexed.sort((a, b) {
    final c = compare(a.$1, b.$1);
    return c != 0 ? c : a.$2.compareTo(b.$2);
  });
  return [for (final e in indexed) e.$1];
}

/// The biggest category changes vs last month, largest absolute move first.
List<Map<String, dynamic>> categoryMovers(dynamic transactions, DateTime ref,
    [int limit = 5]) {
  final txs = _txs(transactions);
  final now = _categoryTotals(txs, 0, ref);
  final before = _categoryTotals(txs, 1, ref);
  final labels = <String>{...now.keys, ...before.keys};
  final moves = <Map<String, dynamic>>[];
  for (final label in labels) {
    final a = now[label] ?? 0.0;
    final b = before[label] ?? 0.0;
    if (a == 0 && b == 0) continue;
    moves.add({'label': label, 'now': a, 'before': b, 'change': a - b});
  }
  final sorted = _stableSorted(moves, (x, y) {
    final xa = (x['change'] as double).abs();
    final ya = (y['change'] as double).abs();
    return ya.compareTo(xa);
  });
  return sorted.length > limit ? sorted.sublist(0, limit) : sorted;
}

/// This month per category vs the average of active past months, with the
/// pace-adjusted expected value. Biggest current spender first.
List<Map<String, dynamic>> categoryVsAverage(dynamic transactions, DateTime ref,
    [int months = 6, int limit = 5]) {
  final txs = _txs(transactions);
  final sums = <String, double>{};
  var active = 0;
  for (var i = 1; i <= months; i++) {
    final t = _categoryTotals(txs, i, ref);
    if (t.isNotEmpty) active += 1;
    for (final k in t.keys) {
      sums[k] = (sums[k] ?? 0) + t[k]!;
    }
  }
  final denom = active > 1 ? active : 1;
  final daysInMonth = DateTime(ref.year, ref.month + 1, 0).day;
  final frac =
      (ref.day / daysInMonth) < 1 ? (ref.day / daysInMonth) : 1.0;
  final now = _categoryTotals(txs, 0, ref);
  final labels = <String>{...sums.keys, ...now.keys};
  final out = <Map<String, dynamic>>[];
  for (final label in labels) {
    final avg = (sums[label] ?? 0) / denom;
    final cur = now[label] ?? 0.0;
    if (avg == 0 && cur == 0) continue;
    out.add({'label': label, 'now': cur, 'avg': avg, 'expected': avg * frac});
  }
  final sorted = _stableSorted(out,
      (x, y) => (y['now'] as double).compareTo(x['now'] as double));
  return sorted.length > limit ? sorted.sublist(0, limit) : sorted;
}

/// Average spend per weekday over the trailing 56 days; index 0 is Sunday,
/// matching JavaScript's getDay.
List<Map<String, dynamic>> weekdayPattern(dynamic transactions, DateTime ref) {
  final totals = List<double>.filled(7, 0);
  final counts = List<int>.filled(7, 0);
  final start = DateTime(ref.year, ref.month, ref.day - 55);
  for (var i = 0; i < 56; i++) {
    final d = DateTime(start.year, start.month, start.day + i);
    counts[d.weekday % 7] += 1;
  }
  for (final t in _txs(transactions)) {
    if (t['type'] != 'expense' || t['date'] == null) continue;
    final parts = (t['date']).toString().split('-');
    if (parts.length != 3) continue;
    final nums = parts.map(int.tryParse).toList();
    if (nums.any((x) => x == null)) continue;
    final d = DateTime(nums[0]!, nums[1]!, nums[2]!);
    if (d.isBefore(start) || d.isAfter(ref)) continue;
    totals[d.weekday % 7] += amountOf(t['amount']);
  }
  return [
    for (var i = 0; i < 7; i++)
      {'day': i, 'avg': counts[i] > 0 ? totals[i] / counts[i] : 0},
  ];
}

/// This month's savings rate (0..1), null with no income. Interest counts as
/// spending, principal does not, repaid utang is not income.
double? savingsRate(dynamic transactions, dynamic payments, DateTime ref) {
  final key = _monthKey(ref);
  var income = 0.0;
  var expenses = 0.0;
  for (final t in _txs(transactions)) {
    if (_month7(t['date']) != key) continue;
    if (t['type'] == 'income' && t['source'] != 'receivable') {
      income += amountOf(t['amount']);
    } else if (t['type'] == 'expense') {
      expenses += amountOf(t['amount']);
    }
  }
  if (income <= 0) return null;
  return (income - expenses) / income;
}

/// Straight-line month-end spend projection at the current daily pace.
Map<String, dynamic> forecastMonthEnd(dynamic transactions, DateTime ref) {
  final key = _monthKey(ref);
  var spent = 0.0;
  for (final t in _txs(transactions)) {
    if (t['type'] == 'expense' && _month7(t['date']) == key) {
      spent += amountOf(t['amount']);
    }
  }
  final dayOfMonth = ref.day;
  final daysInMonth = DateTime(ref.year, ref.month + 1, 0).day;
  final projected =
      dayOfMonth > 0 ? (spent / dayOfMonth) * daysInMonth : spent;
  return {
    'spent': spent,
    'projected': _jsRound(projected),
    'daysInMonth': daysInMonth,
    'dayOfMonth': dayOfMonth,
  };
}

/// Never claim more than this many months of runway; a sparse logging month
/// would otherwise divide a real balance into a nonsense figure.
const int runwayCap = 12;

/// Months of median completed-month spending the accessible buffer covers.
/// Needs at least two completed months with expenses, else monthsCovered is
/// null instead of a made-up number.
Map<String, dynamic> emergencyRunway(Map<String, dynamic>? data, DateTime ref) {
  final d = data ?? const {};
  var accountSum = 0.0;
  for (final a in (d['accounts'] is List ? d['accounts'] as List : const [])) {
    accountSum += amountOf(a is Map ? a['balance'] : null);
  }
  final buffer = accountSum > 0 ? accountSum : 0.0;
  final series = monthlySeries(
      d['transactions'] is List ? d['transactions'] : const [], 7, ref);
  final completed = series
      .sublist(0, 6)
      .map((mo) => mo['expenses'] as double)
      .where((x) => x > 0)
      .toList()
    ..sort();
  var typical = 0.0;
  const runwayMinMonths = 2;
  if (completed.length >= runwayMinMonths) {
    final mid = completed.length ~/ 2;
    typical = completed.length.isOdd
        ? completed[mid]
        : (completed[mid - 1] + completed[mid]) / 2;
  }
  final rawMonths =
      typical > 0 ? _jsRound((buffer / typical) * 10) / 10 : null;
  final capped = rawMonths != null && rawMonths > runwayCap;
  final monthsCovered = capped ? runwayCap : rawMonths;
  return {
    'buffer': _jsRound(buffer),
    'avgMonthlyExpense': _jsRound(typical),
    'monthsCovered': monthsCovered,
    'capped': capped,
    'firstTarget': 10000,
    'oneMonthTarget': _jsRound(typical),
  };
}

/// The 0-100 health score: savings 35, budget 25, debt vs assets 25,
/// logging consistency over 14 days 15. Returns the parts so the screen can
/// explain itself.
Map<String, dynamic> healthScore(Map<String, dynamic> data, DateTime ref) {
  final rate = savingsRate(data['transactions'], data['payments'], ref);
  final ratePts = rate == null
      ? 0.0
      : _jsRound(((rate / 0.3).clamp(0, 1)) * 35);

  final spent = forecastMonthEnd(data['transactions'], ref)['spent'] as double;
  final limit =
      amountOf(data['settings'] is Map ? (data['settings'] as Map)['monthlyLimit'] : null);
  var budgetPts = 0.0;
  if (limit > 0) {
    budgetPts = spent <= limit
        ? 25.0
        : _jsRound(((1 - (spent - limit) / limit).clamp(0, double.infinity)) * 25);
  }

  double sum(dynamic arr, String key) {
    var t = 0.0;
    for (final x in (arr is List ? arr : const [])) {
      t += amountOf(x is Map ? x[key] : null);
    }
    return t;
  }

  final assets = sum(data['accounts'], 'balance') + sum(data['assets'], 'value');
  final debt = sum(data['debts'], 'remaining');
  var debtPts = 25.0;
  if (debt > 0) {
    debtPts = assets > 0
        ? _jsRound(((1 - debt / assets).clamp(0, double.infinity)) * 25)
        : 0.0;
  }

  final logged = <dynamic>{};
  for (final t in _txs(data['transactions'])) {
    if (t['type'] == 'income' || t['type'] == 'expense') logged.add(t['date']);
  }
  var daysLogged = 0;
  for (var i = 0; i < 14; i++) {
    final d = DateTime(ref.year, ref.month, ref.day - i);
    if (logged.contains(_iso(d))) daysLogged += 1;
  }
  final logPts = _jsRound((daysLogged / 14) * 15);

  return {
    'total': ratePts + budgetPts + debtPts + logPts,
    'parts': {
      'savings': ratePts,
      'budget': budgetPts,
      'debt': debtPts,
      'logging': logPts,
    },
  };
}
