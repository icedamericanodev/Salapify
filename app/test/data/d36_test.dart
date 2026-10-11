import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/money.dart';
import 'package:salapify/core/money/plan.dart';
import 'package:salapify/core/money/reports.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/models/models.dart';
import 'package:salapify/state/financial_state.dart';

/// D36, 2026-10-10: borrowing and lending on their own cash-flow line, and
/// "Going out" counting only what is due by payday.
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

  test('borrowing 10,000 shows on its own line and in the cash change; '
      'your own transfers stay your own', () async {
    final FinancialState s = await fresh();
    final CashFlow before = computeCashFlow(s.transactions);
    s.addDebtWithMoney(
      const Debt(
        id: 'debt_tita',
        person: 'Tita',
        direction: DebtDirection.iOwe,
        totalAmount: Money.pesos(10000),
        paidAmount: Money.zero,
        isSettled: false,
      ),
      accountId: 'acc_gcash',
    );
    final CashFlow after = computeCashFlow(s.transactions);
    expect(after.borrowLendInflows - before.borrowLendInflows, 10000);
    expect(after.netCashChange - before.netCashChange, 10000);
    expect(
      after.transfersCount,
      before.transfersCount,
      reason: 'a loan from Tita is not a move between your own accounts',
    );
    // Spending and income untouched (D35).
    expect(after.operatingInflows, before.operatingInflows);

    s.recordDebtPayment('debt_tita', 4000, accountId: 'acc_gcash');
    final CashFlow repaid = computeCashFlow(s.transactions);
    expect(repaid.borrowLendOutflows - after.borrowLendOutflows, 4000);
    expect(repaid.operatingOutflows, after.operatingOutflows);
  });

  test('"Going out" drops when a monthly bill is paid', () async {
    final FinancialState s = await fresh();
    s.addUpcoming(
      const UpcomingItem(
        id: 'up_pldt',
        name: 'PLDT Fibr',
        amount: Money.pesos(1699),
        dueDate: '2026-09-25',
        type: UpcomingItemType.bill,
        repeatDay: 25,
      ),
    );
    final Money before = computeUpcomingTotals(s.upcomingThisCycle).totalOut;
    s.markUpcomingPaid('up_pldt', accountId: 'acc_cash');
    final Money after = computeUpcomingTotals(s.upcomingThisCycle).totalOut;
    expect(before - after, const Money.pesos(1699));
    // Still listed, on its next date.
    expect(s.upcoming.any((UpcomingItem u) => u.id == 'up_pldt'), isTrue);
  });
}
