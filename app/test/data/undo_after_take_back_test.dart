import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/money.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/models/models.dart';
import 'package:salapify/state/financial_state.dart';

/// Undo reverses the STORED row, not the copy the snackbar kept.
///
/// Found by the ledger-reconciler on 2026-10-09: log 500, Take it back
/// within the snackbar's five seconds, then tap Undo. Take it back had
/// already returned the 500; Undo reversed its old copy and returned it
/// again, so the account read 500 higher than the money in it.
void main() {
  Future<FinancialState> fresh() async {
    final FinancialState s = FinancialState(
      clock: DateTime(2026, 9, 18, 12),
      store: MemorySnapshotStore(),
    );
    await s.restore();
    s.startWithExampleData();
    return s;
  }

  Money cash(FinancialState s) =>
      s.accounts.firstWhere((Account a) => a.id == 'acc_cash').balance;

  const Transaction spend = Transaction(
    id: 'tx_test_500',
    type: TransactionType.expense,
    amount: Money.pesos(500),
    category: 'Food & Dining',
    accountId: 'acc_cash',
    date: '2026-09-18',
    createdAt: 1,
  );

  test(
    'log, take it back, then Undo: the account ends where it began',
    () async {
      final FinancialState s = await fresh();
      final Money start = cash(s);

      s.logTransaction(spend);
      expect(
        cash(s),
        start - const Money.pesos(500),
        reason: 'log did nothing',
      );
      expect(s.takeBackEntry(spend.id), TakeBackOutcome.done);
      expect(cash(s), start, reason: 'take it back did not return the money');

      s.undoLoggedTransaction(spend);
      expect(cash(s), start, reason: 'Undo credited the 500 a second time');
      expect(s.transactions.any((Transaction t) => t.id == spend.id), isFalse);
    },
  );

  test('an ordinary Undo still reverses the spend exactly', () async {
    final FinancialState s = await fresh();
    final Money start = cash(s);
    s.logTransaction(spend);
    s.undoLoggedTransaction(spend);
    expect(cash(s), start);
    // Twice is still once.
    s.undoLoggedTransaction(spend);
    expect(cash(s), start);
  });
}
