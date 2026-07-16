// The receivables (utang) write engine, ported 1:1 from the money logic in
// mobile/app/receivables.js (postIncome lines 289-300, logPartial 355-381,
// markPaid 322-336, removePayment 387-395, save 122-256, del 262-275) wired
// to the same reducer semantics as mobile/context/AppData.js. Pure: every
// function takes the whole data map and returns a new one; ids and the date
// are injected so tests replay the RN goldens byte for byte.
//
// The two honest collection cases, straight from the RN comments:
// - Tracked utang (cashLeg): the cash left a real account when you lent, so
//   collecting is a TRANSFER back into that account, not income. Net worth
//   is unchanged by the round trip.
// - Legacy utang: no cash leg recorded, so the money returning is a real
//   inflow, posted as income tagged source receivable (savings rate leaves
//   it out of earnings).

import 'ledger.dart' as ledger;

typedef GenId = String Function(String prefix);

List<Map<String, dynamic>> _list(Map<String, dynamic> data, String key) =>
    (data[key] as List? ?? []).cast<Map<String, dynamic>>();

double paidSumOf(Map<String, dynamic> r) =>
    (r['payments'] as List? ?? [])
        .cast<Map<String, dynamic>>()
        .fold(0.0, (t, p) => t + ledger.amountOf(p['amount']));

double remainingOf(Map<String, dynamic> r) {
  final rem = ledger.amountOf(r['amount']) - paidSumOf(r);
  return rem > 0 ? rem : 0;
}

String nameOf(Map<String, dynamic> data, Map<String, dynamic> r) {
  final people = _list(data, 'people');
  for (final p in people) {
    if (p['id'] == r['personId']) {
      final n = p['name'];
      if (n is String && n.isNotEmpty) return n;
      break;
    }
  }
  final person = r['person'];
  if (person is String && person.isNotEmpty) return person;
  return 'Someone';
}

Map<String, dynamic> _updateItem(Map<String, dynamic> data, String collection,
    String id, Map<String, dynamic> patch) {
  return {
    ...data,
    collection: [
      for (final it in _list(data, collection))
        it['id'] == id ? {...it, ...patch} : it,
    ],
  };
}

Map<String, dynamic> _removeItem(
    Map<String, dynamic> data, String collection, String id) {
  return {
    ...data,
    collection: [
      for (final it in _list(data, collection))
        if (it['id'] != id) it,
    ],
  };
}

/// receivables.js postIncome. Returns (newData, txnId).
(Map<String, dynamic>, String) _postIncome(Map<String, dynamic> data,
    Map<String, dynamic> r, double amount, String today, GenId genId) {
  if (amount <= 0) return (data, '');
  final accounts = _list(data, 'accounts');
  if (r['cashLeg'] == true) {
    final rAcct = r['accountId'];
    final acctId = (rAcct is String &&
            rAcct.isNotEmpty &&
            accounts.any((a) => a['id'] == rAcct))
        ? rAcct
        : '';
    final entry = <String, dynamic>{
      'type': 'transfer',
      'flow': 'in',
      'label': '${nameOf(data, r)} paid you back',
      'amount': amount,
      'date': today,
      'source': 'receivable',
      if (acctId.isNotEmpty) 'accountId': acctId,
      'id': genId('transactions'),
    };
    return (ledger.addTransaction(data, entry), entry['id'] as String);
  }
  final def = (data['settings'] as Map?)?['defaultAccountId'];
  final accountId = (def is String &&
          def.isNotEmpty &&
          accounts.any((a) => a['id'] == def))
      ? def
      : '';
  final entry = <String, dynamic>{
    'type': 'income',
    'label': '${nameOf(data, r)} paid you back',
    'amount': amount,
    'date': today,
    'source': 'receivable',
    if (accountId.isNotEmpty) 'accountId': accountId,
    'id': genId('transactions'),
  };
  return (ledger.addTransaction(data, entry), entry['id'] as String);
}

Map<String, dynamic>? _find(Map<String, dynamic> data, String id) {
  for (final r in _list(data, 'receivables')) {
    if (r['id'] == id) return r;
  }
  return null;
}

/// receivables.js logPartial: clamp to what is still owed, post the income
/// (or transfer back), remember the txn on the payment, settle when the last
/// peso arrives. Junk, zero, and nothing-owed all record nothing.
Map<String, dynamic> logPartial(Map<String, dynamic> data, String receivableId,
    String payAmt,
    {required String today, required GenId genId}) {
  final r = _find(data, receivableId);
  if (r == null) return data;
  final cleaned = payAmt.replaceAll(RegExp(r'[, ]'), '');
  final amount =
      cleaned.isEmpty ? 0.0 : (double.tryParse(cleaned) ?? double.nan);
  final remaining = remainingOf(r);
  if (!amount.isFinite || amount <= 0) return data;
  final applied = amount < remaining ? amount : remaining;
  if (applied <= 0) return data;
  final (next, txnId) = _postIncome(data, r, applied, today, genId);
  final payment = {
    'id': genId('rpay'),
    'amount': applied,
    'date': today,
    'txnId': txnId,
  };
  final settles = applied >= remaining;
  return _updateItem(next, 'receivables', receivableId, {
    'payments': [...(r['payments'] as List? ?? []), payment],
    'paid': settles,
  });
}

/// receivables.js markPaid: settle whatever is STILL owed after partials in
/// one settled-tagged payment, so reopening knows exactly what to reverse.
Map<String, dynamic> markPaid(Map<String, dynamic> data, String receivableId,
    {required String today, required GenId genId}) {
  final r = _find(data, receivableId);
  if (r == null) return data;
  final remaining = remainingOf(r);
  var next = data;
  var payments = (r['payments'] as List? ?? []).toList();
  if (remaining > 0) {
    final (afterIncome, txnId) = _postIncome(data, r, remaining, today, genId);
    next = afterIncome;
    payments = [
      ...payments,
      {
        'id': genId('rpay'),
        'amount': remaining,
        'date': today,
        'txnId': txnId,
        'settled': true,
      },
    ];
  }
  return _updateItem(next, 'receivables', receivableId, {
    'paid': true,
    'payments': payments,
  });
}

/// receivables.js removePayment: reverse the linked income entry, drop the
/// payment row, reopen the utang unless it is still fully covered.
Map<String, dynamic> removePayment(
    Map<String, dynamic> data, String receivableId, String paymentId) {
  final r = _find(data, receivableId);
  if (r == null) return data;
  final payments = (r['payments'] as List? ?? []).cast<Map<String, dynamic>>();
  Map<String, dynamic>? payment;
  for (final p in payments) {
    if (p['id'] == paymentId) {
      payment = p;
      break;
    }
  }
  if (payment == null) return data;
  var next = data;
  final txnId = payment['txnId'];
  if (txnId is String && txnId.isNotEmpty) {
    next = ledger.removeTransaction(next, txnId);
  }
  final kept = [
    for (final p in payments)
      if (p['id'] != paymentId) p,
  ];
  final newPaidSum =
      kept.fold(0.0, (t, p) => t + ledger.amountOf(p['amount']));
  final stillPaid =
      r['paid'] == true && newPaidSum >= ledger.amountOf(r['amount']);
  return _updateItem(next, 'receivables', receivableId, {
    'payments': kept,
    'paid': stillPaid,
  });
}

/// The outcome of saveReceivable: either an error code the UI explains
/// ('name', 'amount', 'below-paid', 'date') or the new state and the saved
/// receivable's id.
class SaveResult {
  final Map<String, dynamic> data;
  final String? error;
  final String? id;
  const SaveResult(this.data, {this.error, this.id});
}

/// receivables.js save(): create or edit an utang. Finds or creates the
/// person (case and spacing insensitive), records the optional lending cash
/// leg for a NEW utang, and reconciles the paid toggle through the same
/// money path as markPaid, so a paid utang always has its income recorded
/// and reopening reverses ONLY settled-tagged entries.
SaveResult saveReceivable(
  Map<String, dynamic> data, {
  String id = '',
  required String person,
  required String amountText,
  String dueDate = '',
  String phone = '',
  String note = '',
  String fromAccount = '',
  bool paid = false,
  required String today,
  required GenId genId,
}) {
  final name = person.trim();
  if (name.isEmpty) return SaveResult(data, error: 'name');
  final trimmedAmt = amountText.trim();
  final amount =
      trimmedAmt.isEmpty ? double.nan : (double.tryParse(trimmedAmt) ?? double.nan);
  if (amountText.isEmpty || !amount.isFinite || amount < 0) {
    return SaveResult(data, error: 'amount');
  }
  final list = _list(data, 'receivables');
  Map<String, dynamic>? existing;
  if (id.isNotEmpty) {
    for (final x in list) {
      if (x['id'] == id) {
        existing = x;
        break;
      }
    }
    final already = existing != null ? paidSumOf(existing) : 0.0;
    if (amount < already) return SaveResult(data, error: 'below-paid');
  }
  final dd = dueDate.trim();
  if (dd.isNotEmpty) {
    final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(dd);
    var real = false;
    if (m != null) {
      final y = int.parse(m.group(1)!);
      final mo = int.parse(m.group(2)!);
      final day = int.parse(m.group(3)!);
      final dt = DateTime(y, mo, day);
      real = dt.month == mo && dt.day == day;
    }
    if (!real) return SaveResult(data, error: 'date');
  }

  var next = data;
  final key = name.toLowerCase();
  String personId = '';
  for (final p in _list(next, 'people')) {
    final pn = p['name'];
    if (pn is String && pn.trim().toLowerCase() == key) {
      personId = (p['id'] ?? '').toString();
      break;
    }
  }
  if (personId.isEmpty) {
    personId = genId('people');
    next = {
      ...next,
      'people': [
        ..._list(next, 'people'),
        {'name': name, 'phone': phone.trim(), 'note': '', 'id': personId},
      ],
    };
  } else if (phone.trim().isNotEmpty) {
    next = _updateItem(next, 'people', personId, {'phone': phone.trim()});
  }

  final wasPaid = existing != null && existing['paid'] == true;
  final lendAcctId = (id.isEmpty &&
          fromAccount.isNotEmpty &&
          _list(next, 'accounts').any((a) => a['id'] == fromAccount))
      ? fromAccount
      : '';
  final payload = {
    'person': name,
    'personId': personId,
    'amount': amount,
    'dueDate': dd,
    'phone': phone.trim(),
    'note': note.trim(),
  };
  var savedId = id;
  if (id.isNotEmpty) {
    next = _updateItem(next, 'receivables', id, payload);
  } else {
    savedId = genId('receivables');
    next = {
      ...next,
      'receivables': [
        ..._list(next, 'receivables'),
        {...payload, 'payments': [], 'paid': false, 'id': savedId},
      ],
    };
  }

  if (lendAcctId.isNotEmpty) {
    final lendTxnId = genId('transactions');
    next = ledger.addTransaction(next, {
      'type': 'transfer',
      'flow': 'out',
      'label': 'Lent to $name',
      'amount': amount,
      'date': today,
      'accountId': lendAcctId,
      'source': 'receivable',
      'id': lendTxnId,
    });
    next = _updateItem(next, 'receivables', savedId, {
      'cashLeg': true,
      'accountId': lendAcctId,
      'lendTxnId': lendTxnId,
    });
  }

  final collectRef = {
    'person': name,
    'personId': personId,
    'cashLeg': lendAcctId.isNotEmpty,
    'accountId': lendAcctId,
  };
  final priorPayments =
      (existing?['payments'] as List? ?? []).cast<Map<String, dynamic>>();
  if (paid) {
    final priorPaid =
        priorPayments.fold(0.0, (t, p) => t + ledger.amountOf(p['amount']));
    final remaining = (amount - priorPaid) > 0 ? (amount - priorPaid) : 0.0;
    var payments = priorPayments.toList();
    if (remaining > 0) {
      final (afterIncome, txnId) =
          _postIncome(next, collectRef, remaining, today, genId);
      next = afterIncome;
      payments = [
        ...priorPayments,
        {
          'id': genId('rpay'),
          'amount': remaining,
          'date': today,
          'txnId': txnId,
          'settled': true,
        },
      ];
    }
    next = _updateItem(
        next, 'receivables', savedId, {'paid': true, 'payments': payments});
  } else if (wasPaid) {
    final settledTagged =
        priorPayments.where((p) => p['settled'] == true).toList();
    var payments = priorPayments.toList();
    if (settledTagged.isNotEmpty) {
      for (final p in settledTagged) {
        final txnId = p['txnId'];
        if (txnId is String && txnId.isNotEmpty) {
          next = ledger.removeTransaction(next, txnId);
        }
      }
      payments = priorPayments.where((p) => p['settled'] != true).toList();
    }
    next = _updateItem(
        next, 'receivables', savedId, {'paid': false, 'payments': payments});
  }
  return SaveResult(next, id: savedId);
}

/// receivables.js del(): reverse every linked income entry and the lending
/// outflow, then remove the utang, so deleting never leaves phantom income
/// or a lend that never returns.
Map<String, dynamic> deleteReceivable(
    Map<String, dynamic> data, String receivableId) {
  final r = _find(data, receivableId);
  if (r == null) return _removeItem(data, 'receivables', receivableId);
  var next = data;
  for (final p
      in (r['payments'] as List? ?? []).cast<Map<String, dynamic>>()) {
    final txnId = p['txnId'];
    if (txnId is String && txnId.isNotEmpty) {
      next = ledger.removeTransaction(next, txnId);
    }
  }
  final lendTxnId = r['lendTxnId'];
  if (lendTxnId is String && lendTxnId.isNotEmpty) {
    next = ledger.removeTransaction(next, lendTxnId);
  }
  return _removeItem(next, 'receivables', receivableId);
}
