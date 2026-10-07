// Net-new behaviour with no RN counterpart (the RN app has no per-account
// currency), so this is a Dart unit test, not a golden replay. The golden
// replay in transfer_golden_test.dart still covers the same-currency path and
// must stay green: this guard is additive and touches nothing those vectors do.
//
// The load-bearing invariant: a transfer between your own accounts conserves
// net worth. A cross-currency 1:1 move would break it, so it must be refused,
// and on refusal the balances must be left exactly as they were.

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/money/transfers.dart';

void main() {
  Map<String, dynamic> acct(String id, String name, num balance, String? code) {
    final m = <String, dynamic>{'id': id, 'name': name, 'balance': balance};
    if (code != null) m['currencyCode'] = code;
    return m;
  }

  Map<String, dynamic> book({String? fromCode, String? toCode, String base = 'PHP'}) => {
    'settings': {'currencyCode': base},
    'accounts': [acct('a', 'Cash', 5000, fromCode), acct('b', 'Bank', 1000, toCode)],
    'transactions': <dynamic>[],
  };

  TransferOutcome move(Map<String, dynamic> data) => applyTransfer(
    data,
    fromId: 'a',
    toId: 'b',
    amountText: '500',
    today: '2026-08-26',
    genId: () => 'tx1',
  );

  double bal(Map<String, dynamic> data, String id) => (data['accounts'] as List)
      .cast<Map<String, dynamic>>()
      .firstWhere((a) => a['id'] == id)['balance']
      .toDouble();

  test('same currency (both absent = base) still moves and conserves the sum', () {
    final before = book();
    final r = move(before);
    expect(r.ok, isTrue);
    // a: 5000 - 500, b: 1000 + 500, sum unchanged.
    expect(bal(r.data!, 'a'), 4500.0);
    expect(bal(r.data!, 'b'), 1500.0);
    expect(bal(r.data!, 'a') + bal(r.data!, 'b'), 6000.0);
  });

  test('an explicit code equal to base counts as same currency', () {
    final r = move(book(fromCode: 'PHP', toCode: 'PHP'));
    expect(r.ok, isTrue);
  });

  test('absent vs the base code are the same currency', () {
    // from has no code (= base PHP), to is explicitly PHP.
    final r = move(book(toCode: 'PHP'));
    expect(r.ok, isTrue);
  });

  test('a cross-currency move is REFUSED, not converted', () {
    final r = move(book(fromCode: 'USD'));
    expect(r.ok, isFalse);
    expect(r.refusal, TransferRefusal.currency);
    expect(r.error, contains('same currency'));
    expect(r.data, isNull);
  });

  test('a refused cross-currency move leaves both balances untouched', () {
    final data = book(fromCode: 'USD', toCode: 'PHP');
    final r = move(data);
    expect(r.ok, isFalse);
    // The engine returns no data on refusal; the original book is unchanged, so
    // net worth cannot have moved.
    expect(bal(data, 'a'), 5000.0);
    expect(bal(data, 'b'), 1000.0);
  });

  test('two matching non-base currencies may move between themselves', () {
    // Two USD accounts: same currency, so the 1:1 move is correct.
    final r = move(book(fromCode: 'USD', toCode: 'USD'));
    expect(r.ok, isTrue);
  });
}
