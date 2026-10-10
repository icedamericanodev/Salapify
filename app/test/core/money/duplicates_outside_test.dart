import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/money.dart';
import 'package:salapify/core/money/reconciliation.dart';
import 'package:salapify/models/models.dart';

/// The duplicate finder compares the person's OWN account (D35). Two friends
/// repaying 300 on one day both carry outsideAccountId as their stored
/// account, so comparing that paired a repayment into GCash with one into
/// BPI as "the same account" and offered to cancel one of them.
void main() {
  Transaction collected(String id, String into) => Transaction(
    id: id,
    type: TransactionType.transfer,
    amount: const Money.pesos(300),
    category: 'Receivables & Repayments',
    accountId: outsideAccountId,
    toAccountId: into,
    date: '2026-09-18',
    createdAt: 1,
  );

  test('repayments into two different accounts are not a pair', () {
    expect(
      findDuplicates(<Transaction>[
        collected('a', 'acc_gcash'),
        collected('b', 'acc_bpi'),
      ]),
      isEmpty,
    );
  });

  test('two identical repayments into ONE account still are', () {
    // The positive control: without it, a finder that never pairs anything
    // would pass the test above.
    expect(
      findDuplicates(<Transaction>[
        collected('a', 'acc_gcash'),
        collected('b', 'acc_gcash'),
      ]),
      hasLength(1),
    );
  });
}
