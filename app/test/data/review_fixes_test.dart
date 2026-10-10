import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/debt.dart';
import 'package:salapify/core/money/format.dart';
import 'package:salapify/core/money/health_check.dart';
import 'package:salapify/core/money/money.dart';
import 'package:salapify/core/money/reconciliation.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/models/models.dart';
import 'package:salapify/state/financial_state.dart';

/// Findings from the ledger-reconciler's review of lending and repeating
/// bills, 2026-10-10. Each test names the gap it closes.
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

  Money cash(FinancialState s) =>
      s.accounts.firstWhere((Account a) => a.id == 'acc_cash').balance;

  test('the health check counts what Safe to Spend holds back, overdue '
      'included (gap 12,000)', () async {
    final FinancialState s = await fresh();
    s.addUpcoming(
      const UpcomingItem(
        id: 'up_rent',
        name: 'Condo Rent',
        amount: Money.pesos(12000),
        dueDate: '2026-09-10',
        type: UpcomingItemType.rent,
        repeatDay: 10,
      ),
    );
    // What Safe to Spend holds back for bills, before the careful padding.
    final Money held = sumMoney(<Money>[
      for (final BillItem b in s.billsHeldBack)
        if (!b.isPaid) b.amount,
    ]);
    final String detail = s.healthReport.indicators
        .map((HealthIndicator i) => i.detail ?? '')
        .firstWhere((String d) => d.contains('spoken for'));
    expect(
      detail,
      startsWith(formatPeso(held.pesos)),
      reason: 'the dot and the hero disagree about the bills',
    );
    // Directional: the overdue rent is in there.
    expect(s.billsHeldBack.any((BillItem b) => b.name == 'Condo Rent'), isTrue);
  });

  test('a ticked one-off is still protected when a monthly bill shares '
      'its name (gap 3,500)', () async {
    final FinancialState s = await fresh();
    s.addUpcoming(
      const UpcomingItem(
        id: 'up_dent_once',
        name: 'Dentist',
        amount: Money.pesos(3500),
        dueDate: '2026-09-18',
        type: UpcomingItemType.bill,
      ),
    );
    s.addUpcoming(
      const UpcomingItem(
        id: 'up_dent_monthly',
        name: 'Dentist',
        amount: Money.pesos(1200),
        dueDate: '2026-09-25',
        type: UpcomingItemType.bill,
        repeatDay: 25,
      ),
    );
    final Transaction tx = s.markUpcomingPaid(
      'up_dent_once',
      accountId: 'acc_cash',
    )!;
    expect(s.takeBackPreview(tx.id), TakeBackOutcome.belongsToBill);
  });

  test('taking back an older monthly payment moves the bill back a month '
      '(gap 1,699)', () async {
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
    final Money start = cash(s);
    final Transaction first = s.markUpcomingPaid(
      'up_pldt',
      accountId: 'acc_cash',
    )!;
    s.markUpcomingPaid('up_pldt', accountId: 'acc_cash');
    String due() =>
        s.upcoming.firstWhere((UpcomingItem u) => u.id == 'up_pldt').dueDate;
    expect(due(), '2026-11-25');

    expect(s.takeBackEntry(first.id), TakeBackOutcome.done);
    // One payment counts, so the bill is due one month after the first.
    expect(due(), '2026-10-25');
    expect(cash(s), start - const Money.pesos(1699));
  });

  test('money lent and collected the same day is not a double entry', () {
    final Transaction lent = lendingEntry(
      id: 'tx_lend_1',
      amount: const Money.pesos(2000),
      person: 'Joel',
      accountId: 'acc_gcash',
      today: today,
      createdAt: 1,
    );
    final Transaction collected = Transaction(
      id: 'tx_debt_1',
      type: TransactionType.transfer,
      amount: const Money.pesos(2000),
      category: 'Receivables & Repayments',
      accountId: outsideAccountId,
      toAccountId: 'acc_gcash',
      date: lent.date,
      createdAt: 2,
    );
    expect(findDuplicates(<Transaction>[lent, collected]), isEmpty);
  });
}
