// The transaction engine, ported from the reducer bodies of
// mobile/context/AppData.js (balanceSign, addTransaction, updateTransaction,
// removeTransaction). Pure: every function takes a state map of
// {'accounts': [...], 'transactions': [...]} and returns a NEW state map,
// which is exactly what the RN reducers do inside setData. Golden-verified by
// test/ledger_golden_test.dart replaying a mixed scenario sequence.
//
// JS semantics preserved on purpose:
// - amounts coerce like Number(x) || 0, so junk never moves a balance
// - a linked account moves only when the accountId actually exists
// - editing reverses the old entry then applies the new one, so a changed
//   amount, type, flow, or account can never drift a balance
// - flow 'in' always raises, flow 'out' always lowers; with no flow, income
//   raises and everything else lowers

double amountOf(dynamic x) {
  if (x == null || x == false) return 0;
  if (x == true) return 1;
  if (x is num) return x.isFinite ? x.toDouble() : 0;
  if (x is String) {
    if (x.trim().isEmpty) return 0;
    final p = double.tryParse(x);
    return (p == null || !p.isFinite) ? 0 : p;
  }
  return 0;
}

bool _truthyId(dynamic v) => v is String && v.isNotEmpty;

int balanceSign(Map<String, dynamic>? t) {
  if (t != null && t['flow'] == 'in') return 1;
  if (t != null && t['flow'] == 'out') return -1;
  return (t != null && t['type'] == 'income') ? 1 : -1;
}

List<Map<String, dynamic>> _accounts(Map<String, dynamic> state) =>
    (state['accounts'] as List? ?? []).cast<Map<String, dynamic>>();

List<Map<String, dynamic>> _transactions(Map<String, dynamic> state) =>
    (state['transactions'] as List? ?? []).cast<Map<String, dynamic>>();

List<Map<String, dynamic>> _shiftAccount(
    List<Map<String, dynamic>> accounts, String id, double delta) {
  return accounts
      .map((a) => a['id'] == id
          ? {...a, 'balance': amountOf(a['balance']) + delta}
          : a)
      .toList();
}

/// Add a transaction; when it is linked to a real account, move that
/// account's balance by the signed amount.
Map<String, dynamic> addTransaction(
    Map<String, dynamic> state, Map<String, dynamic> tx) {
  final accounts = _accounts(state);
  final linked =
      _truthyId(tx['accountId']) && accounts.any((a) => a['id'] == tx['accountId']);
  final delta = balanceSign(tx) * amountOf(tx['amount']);
  return {
    ...state,
    'accounts':
        linked ? _shiftAccount(accounts, tx['accountId'] as String, delta) : accounts,
    'transactions': [..._transactions(state), tx],
  };
}

/// Edit a transaction honestly: reverse the old entry's effect, apply the
/// new one's, so no edit can drift a balance.
Map<String, dynamic> updateTransaction(
    Map<String, dynamic> state, String id, Map<String, dynamic> patch) {
  final txs = _transactions(state);
  final idx = txs.indexWhere((t) => t['id'] == id);
  if (idx < 0) return state;
  final tx = txs[idx];
  final next = {...tx, ...patch};

  List<Map<String, dynamic>> shift(
      List<Map<String, dynamic>> accs, Map<String, dynamic> t, int sign) {
    if (!_truthyId(t['accountId']) || !accs.any((a) => a['id'] == t['accountId'])) {
      return accs;
    }
    final delta = sign * balanceSign(t) * amountOf(t['amount']);
    return _shiftAccount(accs, t['accountId'] as String, delta);
  }

  final accounts = shift(shift(_accounts(state), tx, -1), next, 1);
  return {
    ...state,
    'accounts': accounts,
    'transactions': [
      for (final t in txs) t['id'] == id ? next : t,
    ],
  };
}

/// Remove a transaction and undo its effect on the linked account.
Map<String, dynamic> removeTransaction(Map<String, dynamic> state, String id) {
  final txs = _transactions(state);
  final idx = txs.indexWhere((t) => t['id'] == id);
  if (idx < 0) return state;
  final tx = txs[idx];
  final accounts = _accounts(state);
  final linked =
      _truthyId(tx['accountId']) && accounts.any((a) => a['id'] == tx['accountId']);
  final delta = balanceSign(tx) * amountOf(tx['amount']);
  return {
    ...state,
    'accounts': linked
        ? _shiftAccount(accounts, tx['accountId'] as String, -delta)
        : accounts,
    'transactions': [
      for (final t in txs)
        if (t['id'] != id) t,
    ],
  };
}
