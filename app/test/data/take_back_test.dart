import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/money.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/models/models.dart';
import 'package:salapify/state/financial_state.dart';

import '../support/test_clock.dart';
import '../support/take_back.dart';

/// Taking a payment back puts EVERYTHING back, to the centavo.
///
/// ## The two halves, because one of them is always the forgotten one
///
/// Half one: did the money move back correctly. Half two: can a person FOLLOW
/// it afterwards. The second is the one that gets missed, and it is the one
/// that found the original defect, when a founder paid 1,500 off a loan and
/// found nothing in the account's history.
///
/// Every conservation assertion here has a DIRECTIONAL companion beside it,
/// because a reversal that did nothing at all satisfies "returns to the start"
/// perfectly. The companion is what separates working from absent.
void main() {
  Future<FinancialState> seeded() async {
    final FinancialState state = FinancialState(clock: testToday);
    await state.restore();
    addTearDown(state.dispose);
    return state;
  }

  Money balanceOf(FinancialState s, String id) =>
      s.accounts.firstWhere((Account a) => a.id == id).balance;

  Debt debtOf(FinancialState s, String id) =>
      s.debts.firstWhere((Debt d) => d.id == id);

  InstallmentPlan planOf(FinancialState s, String id) =>
      s.installments.firstWhere((InstallmentPlan p) => p.id == id);

  group('a debt payment goes back where it came from', () {
    test('the debt, the account and the ledger all return', () async {
      final FinancialState s = await seeded();

      final Money paidBefore = debtOf(s, 'debt_homecredit').paidAmount;
      final Money cashBefore = balanceOf(s, 'acc_gcash');
      final int rowsBefore = s.transactions.length;

      s.recordDebtPayment('debt_homecredit', 1500, accountId: 'acc_gcash');

      // DIRECTIONAL, before the reversal: the payment actually landed. Without
      // this the round trip below passes hardest when nothing happened at all.
      expect(
        debtOf(s, 'debt_homecredit').paidAmount,
        paidBefore + const Money.pesos(1500),
      );
      expect(balanceOf(s, 'acc_gcash'), cashBefore - const Money.pesos(1500));
      expect(s.transactions.length, rowsBefore + 1);

      expect(takeBackNewestDebtPayment(s, 'debt_homecredit'), isTrue);

      expect(debtOf(s, 'debt_homecredit').paidAmount, paidBefore);
      expect(
        balanceOf(s, 'acc_gcash'),
        cashBefore,
        reason:
            'the account came back NEARLY right, which an undo must never do',
      );
      // THE ENTRY STAYS, MARKED. Founder direction, 2026-10-02: a payment you
      // took back is part of your history, and a gap with no explanation is
      // worse than a line you can read.
      expect(
        s.transactions.length,
        rowsBefore + 1,
        reason:
            'the entry was deleted, so the history has a hole where a payment '
            'and its correction should both be readable',
      );
      final Transaction kept = s.transactions.firstWhere(
        (Transaction t) => t.id.startsWith('tx_debt_'),
      );
      expect(kept.status, TransactionStatus.corrected);
      expect(
        kept.countsTowardTotals,
        isFalse,
        reason:
            'a row left counting while the debt has moved is the half-landed '
            'state this whole batch exists to stop',
      );
      expect(
        kept.amount,
        const Money.pesos(1500),
        reason: 'and it keeps its figure, so the history says what happened',
      );
      expect(debtOf(s, 'debt_homecredit').payments, isEmpty);
    });

    test('a payment with NO account moves the debt and nothing else', () async {
      // A real choice, for somebody settling in cash they never logged. It
      // writes no ledger row, so taking it back must move the debt and must
      // not go hunting for an entry that was never written.
      final FinancialState s = await seeded();
      final Money paidBefore = debtOf(s, 'debt_homecredit').paidAmount;
      final int rowsBefore = s.transactions.length;

      s.recordDebtPayment('debt_homecredit', 800);
      expect(
        debtOf(s, 'debt_homecredit').paidAmount,
        paidBefore + const Money.pesos(800),
      );
      expect(s.transactions.length, rowsBefore, reason: 'it wrote an entry');

      expect(takeBackNewestDebtPayment(s, 'debt_homecredit'), isTrue);
      expect(debtOf(s, 'debt_homecredit').paidAmount, paidBefore);
      expect(s.transactions.length, rowsBefore);
    });

    test('a payment that CAUSED settlement un-settles cleanly', () async {
      final FinancialState s = await seeded();
      final Debt d = debtOf(s, 'debt_homecredit');
      expect(d.isSettled, isFalse);

      s.recordDebtPayment(
        'debt_homecredit',
        d.remaining.pesos,
        accountId: 'acc_gcash',
      );
      expect(debtOf(s, 'debt_homecredit').isSettled, isTrue);
      expect(debtOf(s, 'debt_homecredit').settledDate, isNotNull);

      takeBackNewestDebtPayment(s, 'debt_homecredit');

      expect(debtOf(s, 'debt_homecredit').isSettled, isFalse);
      expect(
        debtOf(s, 'debt_homecredit').settledDate,
        isNull,
        reason:
            'the cleared date the payment stamped is still on a debt that is '
            'open again, so the card says settled on a date and not settled',
      );
    });

    test('with nothing to take back it REFUSES, and changes nothing', () async {
      // Every debt from a restored backup is in this state, and so is every
      // payment made before the register existed. Refusing is the honest
      // answer; guessing which payment it was is what the register exists to
      // stop.
      final FinancialState s = await seeded();
      final Money paidBefore = debtOf(s, 'debt_bpi_loan').paidAmount;

      expect(takeBackNewestDebtPayment(s, 'debt_bpi_loan'), isFalse);
      expect(debtOf(s, 'debt_bpi_loan').paidAmount, paidBefore);
    });

    test('twice does not credit the money back twice', () async {
      final FinancialState s = await seeded();
      final Money cashBefore = balanceOf(s, 'acc_gcash');

      s.recordDebtPayment('debt_homecredit', 1500, accountId: 'acc_gcash');
      expect(takeBackNewestDebtPayment(s, 'debt_homecredit'), isTrue);
      expect(takeBackNewestDebtPayment(s, 'debt_homecredit'), isFalse);

      expect(balanceOf(s, 'acc_gcash'), cashBefore);
    });
  });

  group('a plan payment goes back, split and all', () {
    test('THE 400, which is the whole reason the register exists', () async {
      // Prepay 6,000 against 5,600 principal and 991.20 interest. The split
      // is 5,600 and 400. A reversal that re-derived it from "principal
      // first" would restore 6,000 of principal, and the balance would still
      // foot perfectly while the composition was wrong forever.
      final FinancialState s = await seeded();
      final InstallmentPlan before = planOf(s, 'inst_spaylater');
      expect(before.principalRemaining, const Money.pesos(5600));
      expect(before.interestRemaining, const Money.of(991, 20));

      s.payInstallmentExtra(
        'inst_spaylater',
        const Money.pesos(6000),
        accountId: 'acc_gcash',
      );
      // Directional: it really applied.
      expect(planOf(s, 'inst_spaylater').principalRemaining, Money.zero);

      expect(takeBackNewestPlanPayment(s, 'inst_spaylater'), isTrue);

      final InstallmentPlan after = planOf(s, 'inst_spaylater');
      expect(
        after.principalRemaining,
        const Money.pesos(5600),
        reason: 'principal came back overstated, which every total hides',
      );
      expect(after.interestRemaining, const Money.of(991, 20));
      expect(after.runningBalance, before.runningBalance);
      expect(
        after.extraPayments.length,
        before.extraPayments.length,
        reason: 'the plan still lists a prepayment that no longer exists',
      );
    });

    test('a scheduled instalment puts the counter back', () async {
      final FinancialState s = await seeded();
      final InstallmentPlan before = planOf(s, 'inst_spaylater');
      final Money cashBefore = balanceOf(s, 'acc_gcash');

      s.payInstallment('inst_spaylater', accountId: 'acc_gcash');
      expect(
        planOf(s, 'inst_spaylater').paidInstallments,
        before.paidInstallments + 1,
      );

      takeBackNewestPlanPayment(s, 'inst_spaylater');

      final InstallmentPlan after = planOf(s, 'inst_spaylater');
      expect(after.paidInstallments, before.paidInstallments);
      expect(after.runningBalance, before.runningBalance);
      expect(after.principalRemaining, before.principalRemaining);
      expect(after.interestRemaining, before.interestRemaining);
      expect(balanceOf(s, 'acc_gcash'), cashBefore);
    });

    test('THE STUB, taken back for exactly what it collected', () async {
      // Prepay, then pay the next scheduled instalment, which collects a stub
      // rather than the quoted amount. Re-deriving this one from the schedule
      // credited 1,647.80 against a ledger row holding 591.20.
      final FinancialState s = await seeded();

      s.payInstallmentExtra(
        'inst_spaylater',
        const Money.pesos(6000),
        accountId: 'acc_gcash',
      );

      final InstallmentPlan prepaid = planOf(s, 'inst_spaylater');
      final Money cashAfterPrepay = balanceOf(s, 'acc_gcash');

      s.payInstallment('inst_spaylater', accountId: 'acc_gcash');
      final Money collected = cashAfterPrepay - balanceOf(s, 'acc_gcash');
      expect(
        collected.isPositive,
        isTrue,
        reason: 'the stub collected nothing',
      );

      takeBackNewestPlanPayment(s, 'inst_spaylater');

      expect(balanceOf(s, 'acc_gcash'), cashAfterPrepay);
      expect(
        planOf(s, 'inst_spaylater').principalRemaining,
        prepaid.principalRemaining,
      );
      expect(
        planOf(s, 'inst_spaylater').interestRemaining,
        prepaid.interestRemaining,
      );
      expect(
        planOf(s, 'inst_spaylater').payments.length,
        prepaid.payments.length,
        reason:
            'the prepayment was taken back too, which is not what was '
            'asked for and is the out-of-order case',
      );
    });

    test(
      'and taking the LAST one back leaves the earlier ones alone',
      () async {
        // The ordering rule, from the other side. After taking the instalment
        // back, the prepayment is still there and is now the one on top.
        final FinancialState s = await seeded();

        s.payInstallmentExtra(
          'inst_spaylater',
          const Money.pesos(1000),
          accountId: 'acc_gcash',
        );
        s.payInstallment('inst_spaylater', accountId: 'acc_gcash');
        expect(planOf(s, 'inst_spaylater').payments.length, 2);

        takeBackNewestPlanPayment(s, 'inst_spaylater');

        final InstallmentPlan after = planOf(s, 'inst_spaylater');
        expect(after.payments.length, 1);
        expect(
          after.payments.single.installmentNumber,
          isNull,
          reason:
              'the wrong one was removed: the prepayment went and the '
              'scheduled instalment stayed',
        );
        expect(after.extraPayments.length, 1);
      },
    );
  });

  group('it survives a cold restart', () {
    test('the register is still there, and still exact', () async {
      // A field that encodes and does not decode loses the whole feature on
      // the next launch, silently, with the figures already moved.
      final MemorySnapshotStore store = MemorySnapshotStore();
      final FinancialState first = FinancialState(
        clock: testToday,
        store: store,
      );
      await first.restore();
      first.recordDebtPayment('debt_homecredit', 1500, accountId: 'acc_gcash');
      await first.flushWrites();
      final Money paidAfterPayment = debtOf(
        first,
        'debt_homecredit',
      ).paidAmount;
      first.dispose();

      final FinancialState second = FinancialState(
        clock: testToday,
        store: store,
      );
      await second.restore();
      addTearDown(second.dispose);

      expect(debtOf(second, 'debt_homecredit').paidAmount, paidAfterPayment);
      expect(debtOf(second, 'debt_homecredit').payments, hasLength(1));

      expect(takeBackNewestDebtPayment(second, 'debt_homecredit'), isTrue);
      expect(
        debtOf(second, 'debt_homecredit').paidAmount,
        paidAfterPayment - const Money.pesos(1500),
      );
    });
  });

  group('naming the wrong payment is refused, not redirected', () {
    // THE DEFECT THIS PREVENTS, which does not exist yet and is one commit
    // away at all times from the moment a list of payments is on screen.
    //
    // Both take-backs can only remove `payments.last`. The confirmation
    // dialogs are built from a ROW: they name its date, its figure and the
    // account it came from. While the only control was labelled "take back
    // the last payment" those two could not disagree.
    //
    // A list of rows invites a control on each row. Built the obvious way,
    // the dialog would describe payment 3 and the store would destroy payment
    // 5, with no exception and nothing on screen. The removed row's
    // `paidBefore`, `settledDateBefore` and `installmentCurrentBefore` go with
    // it, so nothing on the device could put it back.
    test('an older payment id does not take back the newest one', () async {
      final FinancialState s = await seeded();

      s.recordDebtPayment('debt_homecredit', 1000, accountId: 'acc_gcash');
      s.recordDebtPayment('debt_homecredit', 2000, accountId: 'acc_gcash');
      final Debt d = debtOf(s, 'debt_homecredit');
      expect(d.payments, hasLength(2));

      final DebtPayment older = d.payments.first;
      final DebtPayment newest = d.payments.last;
      final Money paidBefore = d.paidAmount;
      final Money gcashBefore = balanceOf(s, 'acc_gcash');

      // Name the OLDER row, which is exactly what a per-row control would do.
      expect(
        s.takeBackDebtPayment('debt_homecredit', paymentId: older.id),
        isFalse,
        reason:
            'the store can only remove the last row, so naming an older '
            'one must REFUSE rather than quietly remove a different payment',
      );

      // And nothing moved. Without this the refusal could be returning false
      // after having already done the damage.
      final Debt after = debtOf(s, 'debt_homecredit');
      expect(after.payments, hasLength(2));
      expect(after.payments.last.id, newest.id);
      expect(after.paidAmount, paidBefore);
      expect(balanceOf(s, 'acc_gcash'), gcashBefore);
    });

    // THE DIRECTIONAL HALF, and it is not optional here. Every assertion in
    // the test above is satisfied by a store that refuses every take-back in
    // existence, which would break the feature completely and silently.
    test('the newest id is accepted and removes exactly that row', () async {
      final FinancialState s = await seeded();

      s.recordDebtPayment('debt_homecredit', 1000, accountId: 'acc_gcash');
      s.recordDebtPayment('debt_homecredit', 2000, accountId: 'acc_gcash');
      final Debt d = debtOf(s, 'debt_homecredit');
      final DebtPayment older = d.payments.first;

      expect(
        s.takeBackDebtPayment('debt_homecredit', paymentId: d.payments.last.id),
        isTrue,
      );

      final Debt after = debtOf(s, 'debt_homecredit');
      expect(after.payments, hasLength(1));
      expect(
        after.payments.single.id,
        older.id,
        reason: 'the OLDER row must be the survivor',
      );
    });

    test('a plan refuses an older payment id the same way', () async {
      final FinancialState s = await seeded();

      s.payInstallment('inst_spaylater', accountId: 'acc_gcash');
      s.payInstallment('inst_spaylater', accountId: 'acc_gcash');
      final InstallmentPlan p = s.installments.firstWhere(
        (InstallmentPlan x) => x.id == 'inst_spaylater',
      );
      expect(p.payments.length, greaterThanOrEqualTo(2));

      final PlanPayment older = p.payments.first;
      final int countBefore = p.payments.length;

      expect(
        s.takeBackPlanPayment('inst_spaylater', paymentId: older.id),
        isFalse,
      );
      expect(
        s.installments
            .firstWhere((InstallmentPlan x) => x.id == 'inst_spaylater')
            .payments,
        hasLength(countBefore),
      );
    });
  });
}
