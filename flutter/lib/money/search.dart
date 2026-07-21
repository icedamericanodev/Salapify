// Global search across everything on the device: transactions, utang, debts,
// goals, notes, and accounts. Ported 1:1 from mobile/lib/search.js. Pure string
// work over the stored blob, no network, no engine money math, golden-verified
// against the real RN module so results match the live app.
//
// One idea drives relevance: an item matches when its searchable text contains
// every word in the query (AND). Amounts are searchable as raw digits and as
// the formatted peso string, so "2300" and "2,300" both land.

import 'debtmath.dart' show formatMoneyText;

String _lower(dynamic s) => (s == null ? '' : s.toString()).toLowerCase();

List _arr(dynamic x) => x is List ? x : const [];

/// Every searchable value for an item, lowercased and joined, blanks dropped.
String _hay(List<dynamic> parts) =>
    parts.map(_lower).where((s) => s.isNotEmpty).join(' ');

bool _matches(String haystack, List<String> tokens) {
  for (final t in tokens) {
    if (!haystack.contains(t)) return false;
  }
  return true;
}

/// JS Number() coercion: a number stays itself, "" and whitespace are 0, a
/// numeric string parses, a comma string or junk is NaN, null is 0.
double _jsNumber(dynamic n) {
  if (n is num) return n.toDouble();
  if (n == null) return 0;
  if (n is String) {
    final t = n.trim();
    if (t.isEmpty) return 0;
    return double.tryParse(t) ?? double.nan;
  }
  return double.nan;
}

/// JS `${v}` for a finite number: integers print without a decimal, others use
/// the shortest round-trip form (Dart's toString matches V8 for real amounts).
String _jsNumStr(double v) {
  if (v == v.roundToDouble() && v.abs() < 1e21) return v.toInt().toString();
  return v.toString();
}

double _jsRound(double x) => (x + 0.5).floorToDouble();

/// Amount searchable as "2300", "2300" (rounded), and the peso string digits.
/// Zero and non-finite contribute nothing (matches RN, and keeps a bare "2"
/// from matching every row by its amount).
String _amountHay(dynamic n) {
  final v = _jsNumber(n);
  if (!v.isFinite || v == 0) return '';
  final pesoDigits =
      formatMoneyText(v).replaceAll(RegExp(r'[^\d.,]'), '');
  return '${_jsNumStr(v)} ${_jsNumStr(_jsRound(v))} $pesoDigits';
}

class _NameMaps {
  final Map<String, String> cat;
  final Map<String, String> acct;
  _NameMaps(this.cat, this.acct);
}

_NameMaps _buildNameMaps(Map<String, dynamic> d) {
  final cat = <String, String>{};
  for (final c in _arr(d['categories'])) {
    if (c is Map && c['id'] != null) {
      cat[c['id'].toString()] = (c['name'] ?? '').toString();
    }
  }
  final acct = <String, String>{};
  for (final a in _arr(d['accounts'])) {
    if (a is Map && a['id'] != null) {
      acct[a['id'].toString()] = (a['name'] ?? '').toString();
    }
  }
  return _NameMaps(cat, acct);
}

/// The transaction haystack, shared with History's own filter so a result
/// never disappears when you drill into it.
String txHaystack(
    Map t, Map<String, String> catName, Map<String, String> acctName) {
  final cat = t['categoryId'] != null
      ? (catName[t['categoryId'].toString()] ?? '')
      : '';
  final acct = t['accountId'] != null
      ? (acctName[t['accountId'].toString()] ?? '')
      : '';
  final type = t['type'];
  final kind = type == 'income'
      ? 'income'
      : type == 'transfer'
          ? 'transfer'
          : type == 'debt'
              ? 'debt payment'
              : type == 'adjustment'
                  ? 'balance adjustment'
                  : 'expense';
  return _hay([t['label'], cat, acct, _amountHay(t['amount']), kind]);
}

/// The category and account id -> name maps for a data blob, so History's
/// filter can find a transaction by its category or account name, not only its
/// own label. Returns two maps: category names and account names.
({Map<String, String> cat, Map<String, String> acct}) transactionNameMaps(
    dynamic data) {
  final m =
      _buildNameMaps(data is Map ? data.cast<String, dynamic>() : const {});
  return (cat: m.cat, acct: m.acct);
}

/// True when a transaction matches every word in the query (AND). A blank
/// query matches everything, so History can use this as its live filter.
/// Ported from the RN txMatches so a result never disappears on drill-in.
bool txMatches(Map t, String query, Map<String, String> catName,
    Map<String, String> acctName) {
  final tokens =
      query.trim().toLowerCase().split(RegExp(r'\s+')).where((x) => x.isNotEmpty).toList();
  if (tokens.isEmpty) return true;
  return _matches(txHaystack(t, catName, acctName), tokens);
}

const int _perGroup = 8;

/// Search the stored blob for a query, returning grouped results in the same
/// shape and order as the RN app: Entries, Utang, Debts, Goals, Notes,
/// Accounts. A blank query returns empty.
Map<String, dynamic> search(dynamic data, String rawQuery) {
  final d = data is Map ? data.cast<String, dynamic>() : <String, dynamic>{};
  final q = rawQuery.trim().toLowerCase();
  final tokens = q.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
  if (tokens.isEmpty) {
    return {'query': '', 'empty': true, 'total': 0, 'groups': <dynamic>[]};
  }

  final maps = _buildNameMaps(d);
  final groups = <Map<String, dynamic>>[];
  void add(String kind, String title, String route,
      List<Map<String, dynamic>> all) {
    if (all.isEmpty) return;
    groups.add({
      'kind': kind,
      'title': title,
      'route': route,
      'count': all.length,
      'items': all.take(_perGroup).toList(),
      'more': all.length - _perGroup > 0 ? all.length - _perGroup : 0,
    });
  }

  // Transactions, newest first. Stable order on equal dates via an index
  // tiebreak (JS sort is stable; Dart's is not).
  final tx = <Map<String, dynamic>>[];
  var idx = 0;
  final txIndexed = <(int, Map<String, dynamic>)>[];
  for (final t in _arr(d['transactions'])) {
    if (t is! Map) continue;
    if (!_matches(txHaystack(t, maps.cat, maps.acct), tokens)) continue;
    final cat =
        t['categoryId'] != null ? (maps.cat[t['categoryId'].toString()] ?? '') : '';
    final acct = t['accountId'] != null
        ? (maps.acct[t['accountId'].toString()] ?? '')
        : '';
    final date = (t['date'] ?? '').toString();
    final type = t['type'];
    final sign = type == 'income'
        ? '+'
        : type == 'transfer'
            ? '⇄'
            : type == 'debt'
                ? ''
                : type == 'adjustment'
                    ? (t['flow'] == 'in' ? '+' : '-')
                    : '-';
    final sub = '$date${acct.isNotEmpty ? ' · $acct' : cat.isNotEmpty ? ' · $cat' : ''}'
        .trim();
    txIndexed.add((
      idx++,
      {
        'id': t['id'],
        'title': (t['label'] ?? '').toString().isEmpty ? 'Entry' : t['label'],
        'subtitle': sub,
        'amount': _jsNumberOrZero(t['amount']),
        'sign': sign,
        'date': date,
      }
    ));
  }
  txIndexed.sort((a, b) {
    final c = (b.$2['date'] as String).compareTo(a.$2['date'] as String);
    if (c != 0) return c;
    return a.$1.compareTo(b.$1);
  });
  for (final e in txIndexed) {
    tx.add(e.$2);
  }
  add('transactions', 'Entries', '/history', tx);

  // Utang: who owes you.
  final utang = <Map<String, dynamic>>[];
  for (final r in _arr(d['receivables'])) {
    if (r is! Map) continue;
    var paid = 0.0;
    for (final p in _arr(r['payments'])) {
      paid += _jsNumberOrZero(p is Map ? p['amount'] : null);
    }
    final amt = _jsNumberOrZero(r['amount']);
    final outstanding = (amt - paid) > 0 ? amt - paid : 0.0;
    final h = _hay([
      r['person'], r['note'], r['phone'],
      _amountHay(r['amount']), _amountHay(outstanding), 'utang owes',
    ]);
    if (!_matches(h, tokens)) continue;
    utang.add({
      'id': r['id'],
      'title': (r['person'] ?? '').toString().isEmpty ? 'Someone' : r['person'],
      'subtitle': (r['note'] != null && r['note'].toString().isNotEmpty)
          ? r['note'].toString()
          : outstanding > 0
              ? 'still owes you'
              : 'settled',
      'amount': outstanding,
      'sign': '',
    });
  }
  add('utang', 'Utang', '/receivables', utang);

  // Debts you owe.
  final debts = <Map<String, dynamic>>[];
  for (final dd in _arr(d['debts'])) {
    if (dd is! Map) continue;
    final h = _hay(
        [dd['name'], dd['type'], _amountHay(dd['remaining']), 'debt loan card']);
    if (!_matches(h, tokens)) continue;
    debts.add({
      'id': dd['id'],
      'title': (dd['name'] ?? '').toString().isEmpty ? 'Debt' : dd['name'],
      'subtitle':
          (dd['type'] != null && dd['type'].toString().isNotEmpty) ? dd['type'].toString() : 'debt',
      'amount': _jsNumberOrZero(dd['remaining']),
      'sign': '',
    });
  }
  add('debts', 'Debts', '/debts', debts);

  // Goals.
  final goals = <Map<String, dynamic>>[];
  for (final g in _arr(d['goals'])) {
    if (g is! Map) continue;
    final h = _hay(
        [g['name'], _amountHay(g['target']), _amountHay(g['saved']), 'goal save']);
    if (!_matches(h, tokens)) continue;
    goals.add({
      'id': g['id'],
      'title': (g['name'] ?? '').toString().isEmpty ? 'Goal' : g['name'],
      'subtitle':
          '${formatMoneyText(_jsNumberOrZero(g['saved']))} of ${formatMoneyText(_jsNumberOrZero(g['target']))}',
      'amount': _jsNumberOrZero(g['target']),
      'sign': '',
    });
  }
  add('goals', 'Goals', '/goals', goals);

  // Notes.
  final notes = <Map<String, dynamic>>[];
  for (final n in _arr(d['notes'])) {
    if (n is! Map) continue;
    final text = (n['text'] ?? '').toString();
    if (!_matches(text.toLowerCase(), tokens)) continue;
    final first = text.split('\n').first.trim();
    notes.add({
      'id': n['id'],
      'title': first.isEmpty ? 'Note' : first,
      'subtitle': text.trim().contains('\n') ? 'note' : '',
      'amount': null,
      'sign': '',
    });
  }
  add('notes', 'Notes', '/notes', notes);

  // Accounts by name.
  final accts = <Map<String, dynamic>>[];
  for (final a in _arr(d['accounts'])) {
    if (a is! Map) continue;
    final h = _hay([a['name'], a['kind'], 'account wallet']);
    if (!_matches(h, tokens)) continue;
    accts.add({
      'id': a['id'],
      'title': (a['name'] ?? '').toString().isEmpty ? 'Account' : a['name'],
      'subtitle':
          (a['kind'] != null && a['kind'].toString().isNotEmpty) ? a['kind'].toString() : 'account',
      'amount': _jsNumberOrZero(a['balance']),
      'sign': '',
    });
  }
  add('accounts', 'Accounts', '/accounts', accts);

  var total = 0;
  for (final g in groups) {
    total += g['count'] as int;
  }
  return {'query': q, 'empty': false, 'total': total, 'groups': groups};
}

/// Number(x) || 0, the RN coercion for the echoed amount fields (a non-finite
/// or zero result becomes 0, negatives pass through).
double _jsNumberOrZero(dynamic n) {
  final v = _jsNumber(n);
  return (v.isFinite && v != 0) ? v : 0;
}
