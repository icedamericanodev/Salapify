// The monthly recap, ported 1:1 from mobile/lib/recap.js (monthRecap 21-119,
// recapText 124-147). One plain map summarizing the month: money in and out,
// what was kept, top categories, days logged, debt principal paid, utang
// collected, and one honest verdict sentence. Golden-verified against the
// real RN module.

import 'ledger.dart' show amountOf;

const List<String> _monthsLong = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

String _monthKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}';

double _jsRound(num x) => (x + 0.5).floorToDouble();

Map<String, dynamic> monthRecap(dynamic data, DateTime ref) {
  final d = data is Map ? data : const {};
  final key = _monthKey(ref);
  final label = '${_monthsLong[ref.month - 1]} ${ref.year}';
  final txns = d['transactions'] is List ? d['transactions'] as List : const [];
  final cats = d['categories'] is List ? d['categories'] as List : const [];
  final catNames = <dynamic, dynamic>{
    for (final c in cats) if (c is Map) c['id']: c['name'],
  };

  var moneyIn = 0.0;
  var moneyOut = 0.0;
  final byCat = <String, Map<String, dynamic>>{};
  final byCatOrder = <String>[]; // JS object keys keep insertion order here
  final days = <String>{};
  Map<String, dynamic>? biggest;
  for (final t in txns) {
    if (t is! Map) continue;
    final date = (t['date'] ?? '').toString();
    if ((date.length >= 7 ? date.substring(0, 7) : date) != key) continue;
    if (t['type'] == 'income') {
      days.add(date.length >= 10 ? date.substring(0, 10) : date);
      if (t['source'] != 'receivable') moneyIn += amountOf(t['amount']);
    } else if (t['type'] == 'expense') {
      days.add(date.length >= 10 ? date.substring(0, 10) : date);
      final amt = amountOf(t['amount']);
      moneyOut += amt;
      // String() everywhere: a numeric label from a hand edited backup must
      // never crash the recap.
      final catId = t['categoryId'];
      final catName = (catId != null && catId != false && catId != '' && catId != 0)
          ? catNames[catId]
          : null;
      var name = (catName ?? '').toString().trim();
      if (name.isEmpty) name = (t['label'] ?? '').toString().trim();
      if (name.isEmpty) name = 'Other';
      final k = name.toLowerCase();
      var bucket = byCat[k];
      if (bucket == null) {
        bucket = {'label': name, 'amount': 0.0};
        byCat[k] = bucket;
        byCatOrder.add(k);
      }
      bucket['amount'] = (bucket['amount'] as double) + amt;
      if (biggest == null || amt > (biggest['amount'] as double)) {
        biggest = {'label': name, 'amount': amt};
      }
    }
  }

  // JS sort is stable; mirror with the insertion-order tiebreak.
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

  // Debt paid counts principal only; legacy payments fall back to amount.
  final payments = d['payments'] is List ? d['payments'] as List : const [];
  var debtPaid = 0.0;
  for (final p in payments) {
    if (p is! Map) continue;
    final date = (p['date'] ?? '').toString();
    if ((date.length >= 7 ? date.substring(0, 7) : date) != key) continue;
    final part = amountOf(p['principal'] ?? p['amount']);
    debtPaid += part > 0 ? part : 0;
  }

  var utangCollected = 0.0;
  final receivables =
      d['receivables'] is List ? d['receivables'] as List : const [];
  for (final r in receivables) {
    if (r is! Map) continue;
    for (final p in (r['payments'] is List ? r['payments'] as List : const [])) {
      if (p is! Map) continue;
      final date = (p['date'] ?? '').toString();
      if ((date.length >= 7 ? date.substring(0, 7) : date) == key) {
        final a = amountOf(p['amount']);
        utangCollected += a > 0 ? a : 0;
      }
    }
  }

  final kept = moneyIn - moneyOut;
  final double? keptRate = moneyIn > 0 ? kept / moneyIn : null;

  String verdict;
  if (moneyIn == 0 &&
      moneyOut == 0 &&
      days.isEmpty &&
      debtPaid == 0 &&
      utangCollected == 0) {
    verdict = 'A quiet month. Log your money and next month tells a story.';
  } else if (keptRate != null && keptRate >= 0.2) {
    verdict =
        'You kept ${_jsRound(keptRate * 100).toInt()}% of your income. Solid month.';
  } else if (keptRate != null && keptRate > 0) {
    verdict =
        'You kept ${_jsRound(keptRate * 100).toInt()}% of your income. Every peso kept counts.';
  } else if (keptRate != null) {
    verdict = 'Spending passed income this month. Next month is a fresh start.';
  } else {
    verdict =
        'You tracked ${_monthsLong[ref.month - 1]} honestly. That is the habit that changes things.';
  }

  return {
    'label': label,
    'monthKey': key,
    'moneyIn': moneyIn,
    'moneyOut': moneyOut,
    'kept': kept,
    'keptRate': keptRate,
    'topCats': topCats,
    'biggest': biggest,
    'daysLogged': days.length,
    'debtPaid': debtPaid,
    'utangCollected': utangCollected,
    'verdict': verdict,
  };
}

/// The plain text recap for the share-as-text fallback. hideAmounts swaps
/// peso values for percentages so nothing sensitive leaves the phone unless
/// chosen.
String recapText(Map<String, dynamic> recap, String Function(num) formatMoney,
    [bool hideAmounts = false]) {
  final lines = <String>['My ${recap['label']} with Salapify:'];
  final keptRate = recap['keptRate'];
  if (keptRate != null) {
    if (hideAmounts) {
      lines.add((recap['kept'] as double) >= 0
          ? 'Kept ${_jsRound((keptRate as double) * 100).toInt()}% of my income.'
          : 'Spending passed my income this month.');
    } else {
      lines.add(
          'Money in ${formatMoney(recap['moneyIn'] as double)}, out ${formatMoney(recap['moneyOut'] as double)}, kept ${formatMoney(recap['kept'] as double)}.');
    }
  }
  final topCats = recap['topCats'] as List;
  if (topCats.isNotEmpty) {
    final top = topCats.first as Map;
    lines.add(
        'Top spending: ${top['label']} (${(top['pct'] as num).toInt()}%).');
  }
  final daysLogged = recap['daysLogged'] as int;
  if (daysLogged > 0) {
    lines.add('Logged $daysLogged ${daysLogged == 1 ? 'day' : 'days'}.');
  }
  lines.add(recap['verdict'] as String);
  lines.add("Tracked with Salapify, on your money's side. ☕");
  return lines.join('\n');
}
