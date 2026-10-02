import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/money.dart';
import 'package:salapify/models/models.dart';
import 'package:salapify/state/financial_state.dart';

import '../support/test_clock.dart';

/// Money that leaves an account has to arrive somewhere, to the centavo.
///
/// Every test here failed before the fixes in this file's own commit, and each
/// one is a WRITE PATH walked through the real state rather than through an
/// engine in isolation. That is deliberate: all three defects were correct
/// where they were written and wrong where they were read, which no unit test
/// on either side could see.
void main() {
  Future<FinancialState> seeded() async {
    final FinancialState state = FinancialState(clock: testToday);
    await state.restore();
    addTearDown(state.dispose);
    return state;
  }

  group('a prepayment debits exactly what it credits', () {
    test('paying a plan off early moves one figure, not two', () async {
      // The defect: the caller capped the amount at the principal still owed
      // while the engine capped it at the balance. Settling SPayLater early
      // credited the plan 6,591.20 and moved the account by 5,600.00, so the
      // plan's EXTRA PAYMENTS row and the account's own history disagreed by
      // 991.20 with that much real cash unaccounted for on either side.
      final FinancialState state = await seeded();
      final InstallmentPlan plan = state.installments.firstWhere(
        (InstallmentPlan x) => x.id == 'inst_spaylater',
      );
      final Account from = state.accounts.firstWhere(
        (Account a) => a.id == 'acc_gcash',
      );
      final Money before = from.balance;
      final Money owed = plan.runningBalance;
      expect(owed, const Money.of(6591, 20));

      state.payInstallmentExtra('inst_spaylater', owed, accountId: 'acc_gcash');

      final InstallmentPlan after = state.installments.firstWhere(
        (InstallmentPlan x) => x.id == 'inst_spaylater',
      );
      final Transaction entry = state.transactions.firstWhere(
        (Transaction t) => t.id.startsWith('tx_inst_extra_'),
      );
      final Account fromAfter = state.accounts.firstWhere(
        (Account a) => a.id == 'acc_gcash',
      );

      expect(after.extraPayments.last.amount, owed);
      expect(entry.amount, owed, reason: 'the ledger entry disagreed');
      expect(
        before - fromAfter.balance,
        owed,
        reason: 'the account moved by a different figure from the plan',
      );
      // Directional: something actually happened.
      expect(after.isSettled, isTrue);
      expect(after.runningBalance, Money.zero);
    });

    test('and an ordinary partial prepayment still works', () async {
      // The other half. A fix that simply took the whole balance every time
      // would pass the test above and overcharge everybody else.
      final FinancialState state = await seeded();
      final Account from = state.accounts.firstWhere(
        (Account a) => a.id == 'acc_gcash',
      );
      final Money before = from.balance;

      state.payInstallmentExtra(
        'inst_spaylater',
        const Money.pesos(1000),
        accountId: 'acc_gcash',
      );

      final Transaction entry = state.transactions.firstWhere(
        (Transaction t) => t.id.startsWith('tx_inst_extra_'),
      );
      final Account fromAfter = state.accounts.firstWhere(
        (Account a) => a.id == 'acc_gcash',
      );
      expect(entry.amount, const Money.pesos(1000));
      expect(before - fromAfter.balance, const Money.pesos(1000));
      expect(
        state.installments
            .firstWhere((InstallmentPlan x) => x.id == 'inst_spaylater')
            .isSettled,
        isFalse,
      );
    });
  });

  group('paying a debt cannot change net worth', () {
    test(
      'an amount typed with three decimals moves both sides equally',
      () async {
        // The amount field is a decimal keyboard with no formatter, so this is
        // reachable by typing. The debt took the raw double and the ledger
        // rounded it, so the liability fell by 1500.555 and the asset by
        // 1500.56: net worth moved by half a centavo on a payment that is
        // defined as moving it by nothing.
        final FinancialState state = await seeded();
        final Debt debt = state.debts.firstWhere(
          (Debt d) => d.direction == DebtDirection.iOwe,
        );
        final Account from = state.accounts.firstWhere(
          (Account a) => a.id == 'acc_gcash',
        );

        final Money paidBefore = debt.paidAmount;
        final Money balanceBefore = from.balance;

        state.recordDebtPayment(debt.id, 1500.555, accountId: 'acc_gcash');

        final Debt after = state.debts.firstWhere((Debt d) => d.id == debt.id);
        final Account fromAfter = state.accounts.firstWhere(
          (Account a) => a.id == 'acc_gcash',
        );
        final Transaction entry = state.transactions.firstWhere(
          (Transaction t) => t.id.startsWith('tx_debt_'),
        );

        final Money liabilityFell = after.paidAmount - paidBefore;
        final Money assetFell = balanceBefore - fromAfter.balance;

        expect(entry.amount, const Money.of(1500, 56));
        // EXACT ON BOTH SIDES NOW, with nothing quantised in the assertion
        // itself. Every earlier version of this line ran one side or the
        // other through Money.fromDouble before comparing, which is a half
        // centavo tolerance wearing a different hat: it would have passed on
        // a payment that moved the debt and the account by different figures,
        // which is precisely the defect the test is named after.
        expect(
          liabilityFell,
          assetFell,
          reason: 'net worth moved on a payment that must not move it',
        );
        // Directional: the payment landed rather than being skipped.
        expect(liabilityFell, greaterThan(const Money.pesos(1500)));
      },
    );
  });
}
