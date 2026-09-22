// The split wiring in the store: taking a logged expense you fronted and
// turning the other people's shares into utang. The money invariants that must
// hold: exactly the fronted total ever leaves the account (splitting only
// reclassifies part of it from spent to lent), the source expense shrinks to
// your own share, each other share becomes a cash-leg receivable tagged to one
// activity, and net worth rises by what is genuinely coming back.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/money/statements.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<SalapifyStore> _seed(Map<String, dynamic> data) async {
  SharedPreferences.setMockInitialValues({});
  final store = SalapifyStore();
  await store.load();
  await store.importBackupText(
    jsonEncode({'app': 'salapify', 'version': 2, 'data': data}),
  );
  return store;
}

double _balance(SalapifyStore s, String acctId) {
  for (final a in (s.data['accounts'] as List)) {
    if (a is Map && a['id'] == acctId) return (a['balance'] as num).toDouble();
  }
  return double.nan;
}

List<Map<String, dynamic>> _receivables(SalapifyStore s) => [
  for (final r in (s.data['receivables'] as List? ?? const []))
    if (r is Map) r.cast<String, dynamic>(),
];

void main() {
  // A GCash account holding 5000 after a 3000 dinner already posted, and that
  // dinner as an expense of 3000 out of GCash.
  Map<String, dynamic> baseData() => {
    'accounts': [
      {'id': 'a1', 'name': 'GCash', 'kind': 'ewallet', 'balance': 5000},
    ],
    'transactions': [
      {
        'id': 't1',
        'type': 'expense',
        'label': 'Dinner',
        'amount': 3000,
        'date': '2026-07-01',
        'accountId': 'a1',
      },
    ],
  };

  test('splitting a fronted expense keeps the account outflow exact', () async {
    final store = await _seed(baseData());
    final before = netWorthParts(store.data)['netWorth'] as double;

    final created = await store.splitExpense(
      txnId: 't1',
      participants: [
        {'name': 'You', 'isYou': true},
        {'name': 'Juan'},
        {'name': 'Maria'},
      ],
    );
    expect(created, 2);

    // The source expense shrank to your own 1000 share.
    final t1 = (store.data['transactions'] as List).firstWhere(
      (t) => t['id'] == 't1',
    );
    expect((t1['amount'] as num).toDouble(), 1000);
    expect(t1['splitActivityId'], isNotNull);

    // The account is unchanged: the same 3000 left it, now split into 1000
    // spent plus 2000 lent (two 1000 transfers out).
    expect(_balance(store, 'a1'), 5000);

    // Two cash-leg receivables of 1000 each, tagged to one activity.
    final recs = _receivables(store);
    expect(recs.length, 2);
    final ids = <String>{};
    for (final r in recs) {
      expect((r['amount'] as num).toDouble(), 1000);
      expect(r['cashLeg'], true);
      expect(r['accountId'], 'a1');
      expect(r['note'], 'Dinner');
      expect(r['activityLabel'], 'Dinner');
      ids.add(r['activityId'].toString());
    }
    expect(ids.length, 1, reason: 'all shares share one activity id');

    // Net worth rose by the 2000 that is genuinely coming back: before the
    // split the whole 3000 read as spent; now only 1000 is.
    final after = netWorthParts(store.data)['netWorth'] as double;
    expect(after - before, closeTo(2000, 1e-9));

    // Persisted and reloads.
    final second = SalapifyStore();
    await second.load();
    expect(_receivables(second).length, 2);
  });

  test('an uneven split still balances the account to the centavo', () async {
    final store = await _seed({
      'accounts': [
        {'id': 'a1', 'name': 'GCash', 'kind': 'ewallet', 'balance': 5000},
      ],
      'transactions': [
        {
          'id': 't1',
          'type': 'expense',
          'label': 'Lunch',
          'amount': 1000,
          'date': '2026-07-01',
          'accountId': 'a1',
        },
      ],
    });
    await store.splitExpense(
      txnId: 't1',
      participants: [
        {'name': 'You', 'isYou': true},
        {'name': 'Juan'},
        {'name': 'Maria'},
      ],
    );
    // 1000 / 3 = 333.34 (you) + 333.33 + 333.33; account outflow still 1000.
    final t1 = (store.data['transactions'] as List).firstWhere(
      (t) => t['id'] == 't1',
    );
    expect((t1['amount'] as num).toDouble(), 333.34);
    expect(_balance(store, 'a1'), closeTo(5000, 1e-9));
    final total = _receivables(
      store,
    ).fold<double>(0, (s, r) => s + (r['amount'] as num).toDouble());
    expect(total, closeTo(666.66, 1e-9));
  });

  test('a cash expense with no account makes legacy receivables', () async {
    final store = await _seed({
      'accounts': [],
      'transactions': [
        {
          'id': 't1',
          'type': 'expense',
          'label': 'Snacks',
          'amount': 600,
          'date': '2026-07-01',
        },
      ],
    });
    await store.splitExpense(
      txnId: 't1',
      participants: [
        {'name': 'You', 'isYou': true},
        {'name': 'Juan'},
        {'name': 'Maria'},
      ],
    );
    final recs = _receivables(store);
    expect(recs.length, 2);
    for (final r in recs) {
      expect(r['amount'], 200);
      expect(
        r['cashLeg'] == true,
        isFalse,
        reason: 'no account means a legacy receivable, not a cash leg',
      );
    }
  });

  test('a missing source transaction is a safe no-op', () async {
    final store = await _seed(baseData());
    final created = await store.splitExpense(
      txnId: 'nope',
      participants: [
        {'name': 'You', 'isYou': true},
        {'name': 'Juan'},
      ],
    );
    expect(created, 0);
    expect(_receivables(store), isEmpty);
  });

  test('a debt-interest expense (source stamp) refuses to split', () async {
    final store = await _seed({
      'accounts': [
        {'id': 'a1', 'name': 'GCash', 'kind': 'ewallet', 'balance': 5000},
      ],
      'transactions': [
        {
          'id': 'ti',
          'type': 'expense',
          'label': 'Card interest',
          'amount': 300,
          'date': '2026-07-01',
          'accountId': 'a1',
          'source': 'interest',
          'debtId': 'd1',
        },
      ],
    });
    final created = await store.splitExpense(
      txnId: 'ti',
      participants: [
        {'name': 'You', 'isYou': true},
        {'name': 'Juan'},
      ],
    );
    expect(
      created,
      0,
      reason: 'a sourced/debt-linked expense is not splittable',
    );
    expect(_receivables(store), isEmpty);
    final ti = (store.data['transactions'] as List).firstWhere(
      (t) => t['id'] == 'ti',
    );
    expect((ti['amount'] as num).toDouble(), 300, reason: 'source untouched');
  });

  test('an expense a payable payment points at refuses to split', () async {
    final store = await _seed({
      'accounts': [
        {'id': 'a1', 'name': 'GCash', 'kind': 'ewallet', 'balance': 5000},
      ],
      'transactions': [
        {
          'id': 'tp',
          'type': 'expense',
          'label': 'Paid Store',
          'amount': 1000,
          'date': '2026-07-01',
          'accountId': 'a1',
        },
      ],
      'payables': [
        {
          'id': 'pay1',
          'person': 'Store',
          'amount': 1000,
          'paid': true,
          'payments': [
            {'id': 'pp1', 'amount': 1000, 'date': '2026-07-01', 'txnId': 'tp'},
          ],
        },
      ],
    });
    final created = await store.splitExpense(
      txnId: 'tp',
      participants: [
        {'name': 'You', 'isYou': true},
        {'name': 'Juan'},
      ],
    );
    expect(created, 0, reason: 'a ledger-linked expense is not splittable');
    expect(_receivables(store), isEmpty);
    final tp = (store.data['transactions'] as List).firstWhere(
      (t) => t['id'] == 'tp',
    );
    expect((tp['amount'] as num).toDouble(), 1000, reason: 'source untouched');
  });
}
