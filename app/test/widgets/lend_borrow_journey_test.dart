// Lending moves real cash, and borrowing mirrors it (D31, D32.3, D35).
//
// Until now, "Pinsan Joel owes me 2,000" was a record and nothing more: the
// 2,000 never left GCash, so the account read 2,000 higher than the money in
// it. The money half and the "can you see it" half are both walked here.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/ledger.dart';
import 'package:salapify/core/money/money.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/main.dart';
import 'package:salapify/models/models.dart';
import 'package:salapify/state/financial_state.dart';

import '../shots/screens_shot.dart' show loadRealFonts;

void main() {
  Future<void> tapIt(WidgetTester tester, Finder f) async {
    await tester.ensureVisible(f.first);
    await tester.pumpAndSettle();
    await tester.tap(f.first);
    await tester.pumpAndSettle();
  }

  Money cash(FinancialState s, String id) =>
      s.accounts.firstWhere((Account a) => a.id == id).balance;

  testWidgets('lending 2,000 from GCash: it leaves now, shows in Activity, '
      'and comes back as neither spending nor income', (
    WidgetTester tester,
  ) async {
    await tester.runAsync(loadRealFonts);
    tester.view.physicalSize = const Size(1170, 3400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final FinancialState state = FinancialState(clock: DateTime(2026, 9, 18));
    await state.restore();
    state.startWithExampleData();
    addTearDown(state.dispose);
    await tester.pumpWidget(SalapifyApp(state: state));
    await tester.pumpAndSettle();

    final Account gcash = state.accounts.firstWhere(
      (Account a) => a.id == 'acc_gcash',
    );
    final Money before = gcash.balance;
    final LedgerTotals totalsBefore = computeTotals(state.transactions);

    await tapIt(tester, find.text('Debt'));
    await tapIt(tester, find.byKey(const Key('debt-add')));
    await tapIt(tester, find.text('They owe me'));
    final Finder fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Pinsan Joel');
    await tester.enterText(fields.at(1), '2000');
    await tester.pumpAndSettle();
    await tapIt(tester, find.byKey(const Key('debt-money')));
    await tapIt(tester, find.text(gcash.name).last);
    // The caption says what Save will do before it does it.
    expect(find.textContaining('leaves ${gcash.name} now'), findsOneWidget);
    await tapIt(tester, find.text('Save debt'));

    // 1. The money moved, and only the cash: no spending, no income.
    expect(cash(state, 'acc_gcash'), before - const Money.pesos(2000));
    final LedgerTotals after = computeTotals(state.transactions);
    expect(
      after.totalOut,
      totalsBefore.totalOut,
      reason: 'lending is spending',
    );
    expect(after.totalIn, totalsBefore.totalIn);
    final Debt mark = state.debts.firstWhere(
      (Debt d) => d.person == 'Pinsan Joel',
    );
    expect(mark.openingTxId, startsWith('tx_lend_'));

    // 2. A person can see where it went: on the Debts list it was saved
    // from, then in Activity.
    await tapIt(tester, find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    await tapIt(tester, find.text('Activity'));
    expect(find.textContaining('${gcash.name} → Pinsan Joel'), findsOneWidget);

    // 3. Paid back in full: the cash returns, still no spending or income.
    state.recordDebtPayment(mark.id, 2000, accountId: 'acc_gcash');
    await tester.pumpAndSettle();
    expect(cash(state, 'acc_gcash'), before);
    final LedgerTotals end = computeTotals(state.transactions);
    expect(end.totalOut, totalsBefore.totalOut);
    expect(end.totalIn, totalsBefore.totalIn, reason: 'repaid is income');
    expect(find.textContaining('Pinsan Joel → ${gcash.name}'), findsOneWidget);
  });

  test('borrowing 5,000 into Cash: it arrives now, is never income, and '
      'paying it back is not spending', () async {
    final FinancialState s = FinancialState(
      clock: DateTime(2026, 9, 18, 12),
      store: MemorySnapshotStore(),
    );
    await s.restore();
    s.startWithExampleData();
    final Money start = cash(s, 'acc_cash');
    final LedgerTotals t0 = computeTotals(s.transactions);

    s.addDebtWithMoney(
      const Debt(
        id: 'debt_tita',
        person: 'Tita Baby',
        direction: DebtDirection.iOwe,
        totalAmount: Money.pesos(5000),
        paidAmount: Money.zero,
        isSettled: false,
      ),
      accountId: 'acc_cash',
    );
    expect(cash(s, 'acc_cash'), start + const Money.pesos(5000));
    expect(computeTotals(s.transactions).totalIn, t0.totalIn);
    final Debt tita = s.debts.firstWhere((Debt d) => d.id == 'debt_tita');
    expect(tita.openingTxId, startsWith('tx_borrow_'));

    s.recordDebtPayment('debt_tita', 5000, accountId: 'acc_cash');
    expect(cash(s, 'acc_cash'), start);
    expect(computeTotals(s.transactions).totalOut, t0.totalOut);
  });

  test('"no money moved" adds the debt and touches no account', () async {
    final FinancialState s = FinancialState(
      clock: DateTime(2026, 9, 18, 12),
      store: MemorySnapshotStore(),
    );
    await s.restore();
    s.startWithExampleData();
    final List<Money> before = <Money>[
      for (final Account a in s.accounts) a.balance,
    ];
    final int entries = s.transactions.length;
    s.addDebtWithMoney(
      const Debt(
        id: 'debt_old',
        person: 'Mom',
        direction: DebtDirection.iOwe,
        totalAmount: Money.pesos(3000),
        paidAmount: Money.zero,
        isSettled: false,
      ),
    );
    expect(s.debts.any((Debt d) => d.id == 'debt_old'), isTrue);
    expect(<Money>[for (final Account a in s.accounts) a.balance], before);
    expect(s.transactions.length, entries);
    expect(
      s.debts.firstWhere((Debt d) => d.id == 'debt_old').openingTxId,
      isNull,
    );
  });
}
