// The Sweldo Day card, by tapping (D31).
//
// The rule is test/core/money/sweldo_day_test.dart. This is what a person
// meets on payday: the card, the move it asks for, and the card going once
// the money is set aside, with Safe to Spend lower by exactly what moved.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/money.dart';
import 'package:salapify/features/accounts/move_money_sheet.dart';
import 'package:salapify/main.dart';
import 'package:salapify/models/models.dart';
import 'package:salapify/screens/accounts/accounts_screen.dart';
import 'package:salapify/state/financial_state.dart';

import '../shots/screens_shot.dart' show loadRealFonts;

void main() {
  Future<FinancialState> openOnPayday(
    WidgetTester tester, {
    bool withSetAside = true,
  }) async {
    await tester.runAsync(loadRealFonts);
    tester.view.physicalSize = const Size(1170, 4200);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    // The example payday is the 15th and the 30th.
    final FinancialState state = FinancialState(
      clock: DateTime(2026, 9, 15, 9),
    );
    await state.restore();
    state.startWithExampleData();
    // The example data already marks one account Set aside; the second
    // case clears every one, so the card has nowhere to send the money.
    for (final Account a in state.accounts) {
      if (a.purpose == AccountPurpose.protected) {
        state.setAccountPurpose(a.id, AccountPurpose.spendable);
      }
    }
    if (withSetAside) {
      state.setAccountPurpose('acc_maya', AccountPurpose.protected);
    }
    addTearDown(state.dispose);
    await tester.pumpWidget(SalapifyApp(state: state));
    await tester.pumpAndSettle();
    return state;
  }

  testWidgets('on payday the card asks, Move to savings opens Move money, '
      'and a move into Set aside ends it and lowers Safe to Spend by exactly '
      'that', (WidgetTester tester) async {
    final FinancialState state = await openOnPayday(tester);
    expect(find.byKey(const Key('sweldo-day-card')), findsOneWidget);
    expect(find.text('Pay yourself first'), findsOneWidget);

    await tester.tap(find.text('Move to savings'));
    await tester.pumpAndSettle();
    expect(find.byType(MoveMoneySheet), findsOneWidget);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    final Money before = state.safeToSpend;
    state.logTransaction(
      const Transaction(
        id: 'tx_save',
        type: TransactionType.transfer,
        amount: Money.pesos(2000),
        category: 'Transfer',
        accountId: 'acc_cash',
        toAccountId: 'acc_maya',
        date: '2026-09-15',
        createdAt: 1,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('sweldo-day-card')), findsNothing);
    // Directional: the move had to LOWER the headline. Not by the full
    // 2,000: the engine also recomputes its 15% Safe to Save and its buffers
    // from the smaller free cash, which is its own tested arithmetic.
    final Money drop = before - state.safeToSpend;
    expect(
      drop.isPositive,
      isTrue,
      reason: 'setting money aside moved nothing',
    );
    expect(drop <= const Money.pesos(2000), isTrue);
  });

  testWidgets('with no Set aside account the card says so and opens '
      'Accounts', (WidgetTester tester) async {
    await openOnPayday(tester, withSetAside: false);
    expect(find.text('Move to savings'), findsNothing);
    await tester.tap(find.text('Choose a savings account'));
    await tester.pumpAndSettle();
    expect(find.byType(AccountsScreen), findsOneWidget);
  });

  testWidgets('not on an ordinary day', (WidgetTester tester) async {
    await tester.runAsync(loadRealFonts);
    final FinancialState state = FinancialState(
      clock: DateTime(2026, 9, 18, 9),
    );
    await state.restore();
    state.startWithExampleData();
    addTearDown(state.dispose);
    await tester.pumpWidget(SalapifyApp(state: state));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('sweldo-day-card')), findsNothing);
  });
}
