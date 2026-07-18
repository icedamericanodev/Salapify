// The store boundary repairs account and debt ids the same way it repairs
// transaction ids: a debt without an id from a hand-edited backup must not
// become an untouchable ghost card, and a numeric id must keep matching the
// rows that reference it once the screens stringify it.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('missing and numeric ids are repaired and references follow', () {
    final repaired = ensureEntityIds({
      'accounts': [
        {'id': 7, 'name': 'GCash', 'balance': 1000},
        {'name': 'No Id Wallet', 'balance': 50},
      ],
      'debts': [
        {'id': 5, 'name': 'Numeric Loan', 'remaining': 900},
        {'name': 'Ghost', 'remaining': 5000},
        {'id': 'debt_ok', 'name': 'Fine', 'remaining': 1},
        {'id': 'debt_ok', 'name': 'Duplicate', 'remaining': 2},
      ],
      'transactions': [
        {'id': 't1', 'accountId': 7, 'debtId': 5, 'amount': 100},
      ],
      'payments': [
        {'id': 'p1', 'debtId': 5, 'account': 7, 'amount': 100},
      ],
      'receivables': [
        {'id': 'r1', 'accountId': 7},
      ],
      'settings': {'defaultAccountId': 7},
    });

    final accounts =
        (repaired['accounts'] as List).cast<Map<String, dynamic>>();
    expect(accounts[0]['id'], '7');
    expect(accounts[1]['id'], 'acct_restored_0');

    final debts = (repaired['debts'] as List).cast<Map<String, dynamic>>();
    expect(debts[0]['id'], '5');
    expect(debts[1]['id'], 'debt_restored_0');
    expect(debts[2]['id'], 'debt_ok');
    expect(debts[3]['id'], isNot('debt_ok'));

    final tx =
        (repaired['transactions'] as List).cast<Map<String, dynamic>>().single;
    expect(tx['accountId'], '7');
    expect(tx['debtId'], '5');
    final pay =
        (repaired['payments'] as List).cast<Map<String, dynamic>>().single;
    expect(pay['debtId'], '5');
    expect(pay['account'], '7');
    expect(
        ((repaired['receivables'] as List).cast<Map<String, dynamic>>())
            .single['accountId'],
        '7');
    expect((repaired['settings'] as Map)['defaultAccountId'], '7');
  });

  test('a numeric id never steals an existing string id', () {
    final repaired = ensureEntityIds({
      'debts': [
        {'id': 5, 'name': 'Numeric', 'remaining': 1},
        {'id': '5', 'name': 'String Five', 'remaining': 2},
      ],
    });
    final debts = (repaired['debts'] as List).cast<Map<String, dynamic>>();
    // The string id was reserved first; the numeric row gets a fresh one
    // and no references are remapped for it.
    expect(debts[0]['id'], 'debt_restored_0');
    expect(debts[1]['id'], '5');
  });

  test('clean data passes through untouched', () {
    final input = {
      'accounts': [
        {'id': 'a1', 'name': 'Cash', 'balance': 1},
      ],
      'debts': [
        {'id': 'd1', 'name': 'Loan', 'remaining': 1},
      ],
    };
    expect(identical(ensureEntityIds(input), input), isTrue);
  });

  test('a ghost debt from an imported blob becomes payable and deletable',
      () async {
    SharedPreferences.setMockInitialValues({
      storageKey: jsonEncode({
        'schemaVersion': 12,
        'accounts': [],
        'debts': [
          {'name': 'Ghost', 'type': 'other', 'remaining': 5000},
        ],
      })
    });
    final store = SalapifyStore();
    await store.load();
    final debt =
        (store.data['debts'] as List).cast<Map<String, dynamic>>().single;
    expect(debt['id'], 'debt_restored_0');
    final r = await store.logDebtPayment('debt_restored_0', '500', null);
    expect(r.newRemaining, 4500.0);
    await store.deleteDebt('debt_restored_0');
    expect((store.data['debts'] as List), isEmpty);
  });
}
