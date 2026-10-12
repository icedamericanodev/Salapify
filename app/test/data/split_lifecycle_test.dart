import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/debt.dart';
import 'package:salapify/core/money/ledger.dart';
import 'package:salapify/core/money/money.dart';
import 'package:salapify/core/money/reports.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/models/models.dart';
import 'package:salapify/state/financial_state.dart';

/// A split across its WHOLE life, from the dinner to every repayment (D32,
/// D34, D35, 2026-10-10).
///
/// The invariant: across the whole life of a split, the person's spending is
/// their own share and nothing else. Measured before: when the person paid,
/// the whole 900 was spending; when a friend paid, the share left the
/// account at the split AND again on repayment, 600 out for a 300 share.
///
/// Each invariant has a directional companion naming what actually moved, so
/// a split that did nothing cannot pass.
void main() {
  final DateTime today = DateTime(2026, 9, 18, 12);

  Future<FinancialState> fresh() async {
    final FinancialState s = FinancialState(
      clock: today,
      store: MemorySnapshotStore(),
    );
    await s.restore();
    s.startWithExampleData();
    return s;
  }

  Money cash(FinancialState s, String id) =>
      s.accounts.firstWhere((Account a) => a.id == id).balance;

  // FULL net worth, with what is owed both ways, as Reports, Position
  // computes it. The accounts-only helper cannot see a receivable, so a
  // split would read as 600 lost.
  Money netWorthOf(FinancialState s) => computePosition(
    s.accounts,
    null,
    debts: s.debts,
    plans: s.installments,
  ).netWorth;

  double spending(FinancialState s) => computeTotals(s.transactions).totalOut;

  double earned(FinancialState s) => computeTotals(s.transactions).totalIn;

  Debt debt(String id, String person, DebtDirection dir, String opening) =>
      Debt(
        id: id,
        person: person,
        direction: dir,
        totalAmount: const Money.pesos(300),
        paidAmount: Money.zero,
        isSettled: false,
        openingTxId: opening,
      );

  group('I paid a 900 dinner for three', () {
    Future<FinancialState> split() async {
      final FinancialState s = await fresh();
      // What the sheet writes, built with the same helpers it uses.
      s.addDebt(
        debt(
          'debt_split_1_0',
          'Ana',
          DebtDirection.owedToMe,
          'tx_split_1_lent',
        ),
      );
      s.addDebt(
        debt(
          'debt_split_1_1',
          'Ben',
          DebtDirection.owedToMe,
          'tx_split_1_lent',
        ),
      );
      s.logTransaction(
        const Transaction(
          id: 'tx_split_1',
          type: TransactionType.expense,
          amount: Money.pesos(300),
          category: 'Food & Dining',
          accountId: 'acc_cash',
          date: '2026-09-18',
          createdAt: 1,
        ),
      );
      s.logTransaction(
        lendingEntry(
          id: 'tx_split_1_lent',
          amount: const Money.pesos(600),
          person: 'Ana, Ben',
          accountId: 'acc_cash',
          today: today,
          createdAt: 1,
        ),
      );
      return s;
    }

    test('spending is my 300 from dinner to the last repayment, and the '
        'cash moves 900 out and 600 back', () async {
      final FinancialState base = await fresh();
      final double spentBefore = spending(base);
      final double earnedBefore = earned(base);
      final Money cashBefore = cash(base, 'acc_cash');
      final Money worthBefore = netWorthOf(base);

      final FinancialState s = await split();
      expect(spending(s) - spentBefore, 300, reason: 'dinner day');
      expect(cash(s, 'acc_cash'), cashBefore - const Money.pesos(900));
      // Net worth: 900 left, 600 is owed back, 300 was eaten.
      expect(netWorthOf(s), worthBefore - const Money.pesos(300));

      s.recordDebtPayment('debt_split_1_0', 300, accountId: 'acc_cash');
      s.recordDebtPayment('debt_split_1_1', 300, accountId: 'acc_cash');

      expect(spending(s) - spentBefore, 300, reason: 'after both repaid');
      expect(
        earned(s),
        earnedBefore,
        reason: 'a friend paying back is not income',
      );
      expect(cash(s, 'acc_cash'), cashBefore - const Money.pesos(300));
      expect(netWorthOf(s), worthBefore - const Money.pesos(300));
      expect(
        s.debts
            .where((Debt d) => d.id.startsWith('debt_split_1_'))
            .every((Debt d) => d.remaining == Money.zero),
        isTrue,
      );
    });

    test('the lent entry cannot be taken back while the debts stand, and '
        'can once they are gone', () async {
      final FinancialState s = await split();
      expect(
        s.takeBackPreview('tx_split_1_lent'),
        TakeBackOutcome.belongsToSplit,
      );
      expect(s.takeBackPreview('tx_split_1'), TakeBackOutcome.belongsToSplit);
      s.deleteDebt('debt_split_1_0');
      s.deleteDebt('debt_split_1_1');
      expect(s.takeBackPreview('tx_split_1_lent'), TakeBackOutcome.done);
    });
  });

  group('Ana paid a 900 dinner for three, I owe her my 300', () {
    test('spending is my 300 on dinner day and stays 300 after I pay her; '
        'cash moves only when I pay', () async {
      final FinancialState s = await fresh();
      final double spentBefore = spending(s);
      final Money cashBefore = cash(s, 'acc_cash');
      final Money worthBefore = netWorthOf(s);

      s.addDebt(
        debt('debt_split_2_0', 'Ana', DebtDirection.iOwe, 'tx_split_2'),
      );
      s.logTransaction(
        paidByOtherEntry(
          id: 'tx_split_2',
          amount: const Money.pesos(300),
          category: 'Food & Dining',
          person: 'Ana',
          today: today,
          createdAt: 1,
        ),
      );

      expect(spending(s) - spentBefore, 300, reason: 'counted as Food today');
      expect(cash(s, 'acc_cash'), cashBefore, reason: 'Ana paid, not me');
      expect(netWorthOf(s), worthBefore - const Money.pesos(300));

      s.recordDebtPayment('debt_split_2_0', 300, accountId: 'acc_cash');

      expect(
        spending(s) - spentBefore,
        300,
        reason: 'paying Ana back counted the dinner a second time',
      );
      expect(cash(s, 'acc_cash'), cashBefore - const Money.pesos(300));
      expect(netWorthOf(s), worthBefore - const Money.pesos(300));
    });
  });

  test('money lent outside a split is held by the stored link alone', () async {
    // The split rows are ALSO caught by the older id-prefix guess, so a test
    // built from them passes with the stored-link check deleted. This one
    // has no prefix to guess from: only openingTxId can refuse it.
    final FinancialState s = await fresh();
    final Money start = cash(s, 'acc_cash');
    s.addDebt(debt('debt_9', 'Kuya Jun', DebtDirection.owedToMe, 'tx_lend_9'));
    s.logTransaction(
      lendingEntry(
        id: 'tx_lend_9',
        amount: const Money.pesos(300),
        person: 'Kuya Jun',
        accountId: 'acc_cash',
        today: today,
        createdAt: 1,
      ),
    );
    expect(cash(s, 'acc_cash'), start - const Money.pesos(300));
    expect(s.takeBackPreview('tx_lend_9'), TakeBackOutcome.belongsToLoan);
    // Deleting the debt, which the refusal points to, takes the money back
    // with it (D32.3): the entry is gone and the 300 is back.
    expect(s.deleteDebt('debt_9'), isTrue);
    expect(s.takeBackPreview('tx_lend_9'), TakeBackOutcome.gone);
    expect(cash(s, 'acc_cash'), start);
  });

  test('a debt with no opening entry is repaid exactly as before', () async {
    // Every debt added by hand and every sample debt (D35): repaying it is
    // still an expense, so nothing already on a phone changes meaning.
    final FinancialState s = await fresh();
    final double spentBefore = spending(s);
    final Debt iOwe = s.debts.firstWhere(
      (Debt d) => d.direction == DebtDirection.iOwe && !d.isSettled,
    );
    expect(iOwe.openingTxId, isNull);
    s.recordDebtPayment(iOwe.id, 500, accountId: 'acc_cash');
    expect(spending(s) - spentBefore, 500);
  });
}
