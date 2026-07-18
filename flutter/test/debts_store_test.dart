// Debt writes through the real store: save with the exact RN validation,
// payments that debit the account and write the payment and record rows,
// mark paid off celebrating a cleared debt, delete keeping history, and the
// guard against paying a debt that no longer exists.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> blob() => {
      'schemaVersion': 12,
      'accounts': [
        {'id': 'acct1', 'name': 'GCash', 'kind': 'ewallet', 'balance': 10000},
      ],
      'transactions': [],
      'debts': [
        {
          'id': 'debt1',
          'name': 'Loan',
          'type': 'personal loan',
          'remaining': 5000,
          'monthlyRate': 0,
          'minPayment': 500,
          'dueDay': 0,
          'statementDay': 0,
          'graceDays': 0,
          'creditLimit': 0,
          'interestThroughISO': '2026-01-01',
        },
      ],
      'payments': [],
    };

Future<SalapifyStore> loaded() async {
  final store = SalapifyStore();
  await store.load();
  return store;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({storageKey: jsonEncode(blob())});
  });

  test('saveDebt creates, validates, and follows the interest clock rule',
      () async {
    final store = await loaded();
    final id = await store.saveDebt({
      'id': null,
      'name': ' BPI Card ',
      'type': 'credit card',
      'remaining': '12,000',
      'monthlyRate': '3',
      'minPayment': '600',
      'dueDay': '25',
      'statementDay': '5',
      'graceDays': '',
      'creditLimit': '50,000',
    });
    final debts = (store.data['debts'] as List).cast<Map<String, dynamic>>();
    expect(debts.length, 2);
    final d = debts.firstWhere((x) => x['id'] == id);
    expect(d['name'], 'BPI Card');
    expect(d['remaining'], 12000.0);
    expect(d['creditLimit'], 50000.0);
    final stamp = (d['interestThroughISO'] ?? '').toString();
    expect(stamp, isNotEmpty);

    // Editing without touching the balance keeps the interest clock.
    await store.saveDebt({
      'id': id,
      'name': 'BPI Card Gold',
      'type': 'credit card',
      'remaining': '12,000',
      'monthlyRate': '3.4',
      'minPayment': '650',
      'dueDay': '25',
      'statementDay': '5',
      'graceDays': '',
      'creditLimit': '50,000',
    });
    final edited = (store.data['debts'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((x) => x['id'] == id);
    expect(edited['name'], 'BPI Card Gold');
    expect(edited['interestThroughISO'], stamp);

    // A refusal throws the exact RN sentence and writes nothing.
    await expectLater(
        store.saveDebt({
          'id': null,
          'name': 'X',
          'type': 'credit card',
          'remaining': '100',
          'monthlyRate': '',
          'minPayment': '',
          'dueDay': '',
          'statementDay': '3',
          'graceDays': '',
          'creditLimit': '',
        }),
        throwsA(isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('Add the days after statement until due'))));
    expect((store.data['debts'] as List).length, 2);

    // Persisted for a fresh store.
    final fresh = await loaded();
    expect((fresh.data['debts'] as List).length, 2);
  });

  test('payment flow: debit, payment row, record rows, payoff, delete',
      () async {
    final store = await loaded();
    final r = await store.logDebtPayment('debt1', '1,000', 'acct1');
    expect(r.newRemaining, 4000.0);
    expect(r.msg, 'Logged ₱1,000 from GCash. New balance ₱4,000.');
    expect(r.celebrated, isFalse);

    final acct =
        (store.data['accounts'] as List).cast<Map<String, dynamic>>().single;
    expect(acct['balance'], 9000.0);
    final pays =
        (store.data['payments'] as List).cast<Map<String, dynamic>>();
    expect(pays.length, 1);
    expect(pays.single['status'], 'posted');
    expect(pays.single['amount'], 1000.0);
    final txs =
        (store.data['transactions'] as List).cast<Map<String, dynamic>>();
    expect(txs.length, 1);
    expect(txs.single['type'], 'debt');
    expect(txs.single['label'], 'Debt payment: Loan');
    // The record row carries no accountId: the debit already happened.
    expect(txs.single.containsKey('accountId'), isFalse);

    // Junk text records nothing at all.
    final junk = await store.logDebtPayment('debt1', 'abc', 'acct1');
    expect(junk.newRemaining, isNull);
    expect((store.data['payments'] as List).length, 1);

    // Mark paid clears the rest as a real payment and celebrates.
    final done = await store.markDebtPaid('debt1', 'acct1');
    expect(done.celebrated, isTrue);
    final after =
        (store.data['debts'] as List).cast<Map<String, dynamic>>().single;
    expect(after['remaining'], 0.0);
    expect(
        ((store.data['accounts'] as List).cast<Map<String, dynamic>>())
            .single['balance'],
        5000.0);

    // Marking paid again reports already at zero and changes nothing.
    final again = await store.markDebtPaid('debt1', 'acct1');
    expect(again.msg, 'Already at zero.');
    expect((store.data['payments'] as List).length, 2);

    // Delete keeps the payment history and record rows.
    await store.deleteDebt('debt1');
    expect((store.data['debts'] as List), isEmpty);
    expect((store.data['payments'] as List).length, 2);
    expect((store.data['transactions'] as List).length, 2);

    // Paying a gone debt refuses instead of recording against nothing.
    await expectLater(store.logDebtPayment('debt1', '100', 'acct1'),
        throwsA(isA<ArgumentError>()));

    // Everything above persisted.
    final fresh = await loaded();
    expect((fresh.data['debts'] as List), isEmpty);
    expect((fresh.data['payments'] as List).length, 2);
  });
}
