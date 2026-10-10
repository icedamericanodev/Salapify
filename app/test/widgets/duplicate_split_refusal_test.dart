import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/money.dart';
import 'package:salapify/models/models.dart';
import 'package:salapify/state/financial_state.dart';

import '../support/pinned_app.dart';

/// The duplicate button on Reports, Check follows the take-back rule.
///
/// Found by the ledger-reconciler on 2026-10-10. Marking a duplicate reverses
/// the second entry exactly as Take this back does, but the button only ever
/// refused debt and plan payments. Two 900 split bills on one day were paired,
/// the button was offered, and one tap put 900 back into the account while
/// both friends' debts for that bill were still standing.
void main() {
  Future<void> tapAndSettle(WidgetTester tester, Finder f) async {
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  Transaction splitEntry(String stamp) => Transaction(
    id: 'tx_split_$stamp',
    type: TransactionType.expense,
    amount: const Money.pesos(900),
    category: 'Food & Dining',
    accountId: 'acc_cash',
    date: '2026-09-18',
    createdAt: 1,
    merchant: 'Barkada dinner',
  );

  Debt splitDebt(String stamp) => Debt(
    id: 'debt_split_${stamp}_0',
    person: 'Ana',
    direction: DebtDirection.owedToMe,
    totalAmount: const Money.pesos(300),
    paidAmount: Money.zero,
    isSettled: false,
    notes: 'Split: Barkada dinner',
  );

  testWidgets('a split entry is not offered as a duplicate while its debts '
      'stand, and says where to go instead', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1170, 4000);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final FinancialState state = await pumpSalapify(tester);
    for (final String stamp in <String>['111', '222']) {
      state.logTransaction(splitEntry(stamp));
      state.addDebt(splitDebt(stamp));
    }
    final Money cash = state.accounts
        .firstWhere((Account a) => a.id == 'acc_cash')
        .balance;

    await tapAndSettle(tester, find.byIcon(Icons.insert_chart_outlined));
    await tapAndSettle(tester, find.text('Check'));
    final Finder refusal = find.textContaining('A split bill wrote this entry');
    await tester.scrollUntilVisible(
      refusal,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    // Directional: the pair WAS found, and what it shows is the way out.
    expect(refusal, findsOneWidget);
    // And it carries no button. The refusal sits where the button would be,
    // so the button nearest it belongs to a different pair or none.
    final Finder row = find
        .ancestor(of: refusal, matching: find.byType(Column))
        .first;
    expect(
      find.descendant(
        of: row,
        matching: find.text('Mark the second one a duplicate'),
      ),
      findsNothing,
    );
    expect(
      state.accounts.firstWhere((Account a) => a.id == 'acc_cash').balance,
      cash,
    );
  });
}
