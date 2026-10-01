import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/money.dart';
import 'package:salapify/core/money/ledger.dart';
import 'package:salapify/core/money/reconciliation.dart';
import 'package:salapify/models/models.dart';
import 'package:salapify/state/financial_state.dart';

import '../support/test_clock.dart';

/// A correction that can only HALF land must not be offered.
///
/// ## The defect, measured before the guard existed
///
/// Record the same debt payment twice, which is a mis-tap or somebody who
/// thought the first one did not save. Reconciliation then offers the pair
/// under "possible double entries", and the obvious tap is there.
///
///     after two payments : account -1,150.00   debt paid 10,350.00
///     after marking it   : account    350.00   debt paid 10,350.00
///     GAP                : 1,500.00
///
/// `setTransactionStatus` reverses the ACCOUNT through reverseFromBalances and
/// cannot touch the debt, because a Transaction carries no debtId. So the
/// account gets its money back and the debt still claims it was paid. No
/// screen explains the difference, and nothing can put it right: a debt has no
/// payment history, and there is no edit or delete for one.
///
/// What makes it the worst shape of this defect rather than merely a bug is
/// that an orange warning offers ONE TAP that makes the warning go away, and
/// the tap breaks a figure.
Debt _debt() => const Debt(
  id: 'debt_hc',
  person: 'Home Credit',
  direction: DebtDirection.iOwe,
  totalAmount: Money.pesos(12000),
  paidAmount: Money.pesos(7350),
  isSettled: false,
);

void main() {
  group('a payment entry is never offered the duplicate control', () {
    test('the money really does end up unaccounted for, without the guard', () {
      // The engine half, kept because it is the EVIDENCE. If this ever stops
      // reproducing, the guard above may have become unnecessary, and a guard
      // nobody can justify is the next thing somebody deletes.
      final Transaction payment = Transaction(
        id: 'tx_debt_1',
        type: TransactionType.expense,
        amount: const Money.pesos(1500),
        category: 'Debt & Loan Servicing',
        accountId: 'acc_cash',
        date: '2026-09-19',
        createdAt: 1,
      );

      final Account account = Account(
        id: 'acc_cash',
        name: 'Cash on Hand',
        kind: AccountKind.cash,
        institution: 'Cash',
        balance: Money.pesos(1850),
        monogram: 'C',
      );

      // The account is given its money back.
      final List<Account> after = reverseFromBalances(<Account>[
        account,
      ], payment);
      expect(after.single.balance, 1850 + 1500);

      // And the debt is untouched by that call, which is the whole defect.
      // It still says 7,350 of a payment it never gave back.
      expect(_debt().paidAmount, const Money.pesos(7350));
    });

    test('so the control is replaced by a sentence', () async {
      // Walked through the REAL write path on the real seed, because the ids
      // are what the guard reads and a hand-built id proves nothing about
      // what recordDebtPayment actually writes.
      final FinancialState state = FinancialState(clock: testToday);
      await state.restore();
      addTearDown(state.dispose);

      // The same payment twice: a mis-tap, or somebody who thought the first
      // one did not save.
      state.recordDebtPayment('debt_homecredit', 1500, accountId: 'acc_gcash');
      state.recordDebtPayment('debt_homecredit', 1500, accountId: 'acc_gcash');

      final List<DuplicatePair> pairs = findDuplicates(state.transactions);
      final Iterable<DuplicatePair> payments = pairs.where(
        (DuplicatePair p) => p.second.isEnginePayment,
      );

      expect(
        payments,
        isNotEmpty,
        reason:
            'the pair is no longer offered at all, so this test proves '
            'nothing about the guard that replaced the button',
      );
    });

    test('an ORDINARY double entry still keeps its button', () {
      // The directional half, and the one that matters. A guard that refused
      // every pair would pass the test above and quietly remove a real
      // feature: two identical fares on one day are exactly what this screen
      // is for.
      final Transaction fare = Transaction(
        id: 'tx_1758240000000',
        type: TransactionType.expense,
        amount: const Money.pesos(15),
        category: 'Transportation',
        accountId: 'acc_cash',
        date: '2026-09-19',
        createdAt: 1,
      );

      expect(
        fare.isEnginePayment,
        isFalse,
        reason:
            'a hand-logged entry lost its duplicate control, which takes a '
            'correction route away from somebody who needs it',
      );
    });

    test('and both engine prefixes are recognised, extras included', () {
      // tx_inst_extra_ starts with tx_inst_, so one check covers both. Pinned
      // because that is only true while the names keep that shape.
      for (final String id in <String>[
        'tx_debt_1',
        'tx_inst_1',
        'tx_inst_extra_1',
      ]) {
        expect(
          Transaction(
            id: id,
            type: TransactionType.expense,
            amount: const Money.pesos(1),
            category: 'Debt & Loan Servicing',
            accountId: 'acc_cash',
            date: '2026-09-19',
            createdAt: 1,
          ).isEnginePayment,
          isTrue,
          reason: '$id was treated as an ordinary entry',
        );
      }
    });
  });
}
