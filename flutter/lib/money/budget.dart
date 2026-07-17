// The budget engine, ported 1:1 from the money logic at the top of
// mobile/app/(tabs)/budget.js (lines 55-101) wired to the already-ported
// previousMonthLeftover. Pure and golden-verified: the monthly limit with
// optional carry over (never negative, an overspent month does not shrink
// this month), spent this month, and the where-it-went category fold where
// a tagged entry groups under its category name, an untagged one under its
// trimmed label, keyed case-insensitively, with Pro caps attached.

import 'analytics.dart' show previousMonthLeftover;
import 'ledger.dart' show amountOf;

double _jsRound(num x) => (x + 0.5).floorToDouble();

bool _isThisMonth(dynamic dateStr, DateTime ref) {
  final s = (dateStr ?? '').toString();
  if (s.isEmpty) return false;
  final key = '${ref.year}-${ref.month.toString().padLeft(2, '0')}';
  return s.length >= 7 && s.substring(0, 7) == key;
}

List<Map<String, dynamic>> _monthExpenses(
    Map<String, dynamic> data, DateTime ref) {
  return [
    for (final t in (data['transactions'] as List? ?? const []))
      if (t is Map && t['type'] == 'expense' && _isThisMonth(t['date'], ref))
        t.cast<String, dynamic>(),
  ];
}

/// { baseLimit, carried, limit, spent, remaining, pct, over }
Map<String, dynamic> budgetSummary(Map<String, dynamic> data, DateTime ref) {
  final settings = data['settings'] is Map ? data['settings'] as Map : const {};
  final baseLimit = amountOf(settings['monthlyLimit']);
  final carryOn = settings['budgetCarryOver'] == true;
  final carried = carryOn && baseLimit > 0
      ? previousMonthLeftover(data['transactions'], baseLimit, ref)
      : 0.0;
  final limit = baseLimit + carried;
  var spent = 0.0;
  for (final e in _monthExpenses(data, ref)) {
    spent += amountOf(e['amount']);
  }
  final remaining = limit - spent;
  // JS Math.min(Math.round(Infinity), 100) is 100; Dart toInt() on a
  // non-finite double throws instead, so clamp the overflow the way the RN
  // reference observably behaves.
  var pct = 0;
  if (limit != 0) {
    final r = _jsRound((spent / limit) * 100);
    final rawPct = r.isFinite ? r.toInt() : 100;
    pct = rawPct < 100 ? rawPct : 100;
  }
  return {
    'baseLimit': baseLimit,
    'carried': carried,
    'limit': limit,
    'spent': spent,
    'remaining': remaining,
    'pct': pct,
    'over': spent > limit,
  };
}

/// This month's top spending groups: { rows: [{label, amount, cap}], max }.
/// Tagged entries group under the category name (Pro cap attached), the
/// rest under their trimmed label or Other, keyed case-insensitively.
Map<String, dynamic> whereItWent(Map<String, dynamic> data, DateTime ref) {
  final expenses = _monthExpenses(data, ref);
  final settings = data['settings'] is Map ? data['settings'] as Map : const {};
  final pro = settings['pro'] == true;
  final catById = <dynamic, Map<String, dynamic>>{};
  for (final c in (data['categories'] as List? ?? const [])) {
    if (c is Map) catById[c['id']] = c.cast<String, dynamic>();
  }
  final spentByCat = <String, Map<String, dynamic>>{};
  for (final t in expenses) {
    final cat = t['categoryId'] != null ? catById[t['categoryId']] : null;
    final catName = cat?['name'];
    String name;
    if (catName is String && catName.isNotEmpty) {
      name = catName;
    } else {
      final rawLabel = t['label'];
      final label = (rawLabel is String && rawLabel.isNotEmpty)
          ? rawLabel
          : 'Other';
      final trimmed = label.trim();
      name = trimmed.isNotEmpty ? trimmed : 'Other';
    }
    final key = name.toLowerCase();
    final row = spentByCat.putIfAbsent(
        key,
        () => {
              'label': name,
              'amount': 0.0,
              'cap': cat != null && pro ? amountOf(cat['monthlyCap']) : 0.0,
            });
    row['amount'] = (row['amount'] as double) + amountOf(t['amount']);
  }
  final rows = spentByCat.values.toList();
  final indexed = List.generate(rows.length, (i) => (rows[i], i));
  indexed.sort((a, b) {
    final c = (b.$1['amount'] as double).compareTo(a.$1['amount'] as double);
    return c != 0 ? c : a.$2.compareTo(b.$2);
  });
  final top = [
    for (final e in indexed.take(4)) e.$1,
  ];
  var max = 1.0;
  for (final w in top) {
    if ((w['amount'] as double) > max) max = w['amount'] as double;
  }
  return {'rows': top, 'max': max};
}
