// The Log sheet in edit mode, on its own (QA findings, 2026-10-11).
//
// Two things the store cannot see, because the sheet decides them before
// the store is asked: a stored date the sheet cannot read must survive an
// edit that never touched it, and a Move money title must follow the
// account it names.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/money.dart';
import 'package:salapify/design/app_theme.dart';
import 'package:salapify/design/tokens.dart';
import 'package:salapify/features/log/log_sheet.dart';
import 'package:salapify/models/models.dart';
import 'package:salapify/state/financial_state.dart';

import '../shots/screens_shot.dart' show loadRealFonts;

void main() {
  Future<Transaction?> editAndSave(
    WidgetTester tester,
    Transaction editing,
    Future<void> Function() change,
  ) async {
    await tester.runAsync(loadRealFonts);
    tester.view.physicalSize = const Size(1170, 3400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final FinancialState state = FinancialState(clock: DateTime(2026, 9, 18));
    state.startWithExampleData();
    addTearDown(state.dispose);

    Transaction? out;
    await tester.pumpWidget(
      MaterialApp(
        theme: salapifyTheme(Palette.of(state.theme), state.theme),
        home: Builder(
          builder: (BuildContext context) => Scaffold(
            body: TextButton(
              onPressed: () async =>
                  out = await LogSheet.show(context, state, editing: editing),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await change();
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    return out;
  }

  testWidgets('a date the sheet cannot read is kept, not turned into '
      'today', (WidgetTester tester) async {
    const Transaction old = Transaction(
      id: 'tx_odd_date',
      type: TransactionType.expense,
      amount: Money.pesos(250),
      category: 'Food & Dining',
      accountId: 'acc_cash',
      date: '17/09/2026',
      createdAt: 1,
    );
    final Transaction? saved = await editAndSave(tester, old, () async {
      await tester.enterText(
        find.descendant(
          of: find.byKey(const Key('log-amount')),
          matching: find.byType(TextField),
        ),
        '300',
      );
      await tester.pumpAndSettle();
    });
    expect(saved, isNotNull);
    // Directional: the edit did happen.
    expect(saved!.amount, const Money.pesos(300));
    expect(saved.date, '17/09/2026');
  });

  testWidgets('a Move money title follows a new destination', (
    WidgetTester tester,
  ) async {
    const Transaction move = Transaction(
      id: 'tx_move_1',
      type: TransactionType.transfer,
      amount: Money.pesos(1000),
      category: 'Transfer',
      accountId: 'acc_gcash',
      toAccountId: 'acc_cash',
      date: '2026-09-17',
      createdAt: 1,
      merchant: 'Transfer: GCash Wallet to Cash on Hand (Pitaka)',
    );
    final Transaction? saved = await editAndSave(tester, move, () async {
      final Finder maya = find.descendant(
        of: find.byKey(const Key('log-destination-picker')),
        matching: find.text('Maya Savings'),
      );
      await tester.ensureVisible(maya);
      await tester.pumpAndSettle();
      await tester.tap(maya);
      await tester.pumpAndSettle();
    });
    expect(saved, isNotNull);
    expect(saved!.toAccountId, 'acc_maya');
    expect(saved.merchant, 'Transfer: GCash Wallet to Maya Savings');
  });

  testWidgets('a title the person wrote is left alone', (
    WidgetTester tester,
  ) async {
    const Transaction move = Transaction(
      id: 'tx_2',
      type: TransactionType.transfer,
      amount: Money.pesos(1000),
      category: 'Transfer',
      accountId: 'acc_gcash',
      toAccountId: 'acc_cash',
      date: '2026-09-17',
      createdAt: 1,
      merchant: 'Pocket money',
    );
    final Transaction? saved = await editAndSave(tester, move, () async {
      final Finder maya = find.descendant(
        of: find.byKey(const Key('log-destination-picker')),
        matching: find.text('Maya Savings'),
      );
      await tester.ensureVisible(maya);
      await tester.pumpAndSettle();
      await tester.tap(maya);
      await tester.pumpAndSettle();
    });
    expect(saved!.toAccountId, 'acc_maya');
    expect(saved.merchant, 'Pocket money');
  });

  testWidgets('a card payment opens with the card chosen and saves with a '
      'new amount', (WidgetTester tester) async {
    const Transaction pay = Transaction(
      id: 'tx_move_card',
      type: TransactionType.transfer,
      amount: Money.pesos(500),
      category: 'Transfer',
      accountId: 'acc_cash',
      toAccountId: 'acc_bpi_cc',
      date: '2026-09-17',
      createdAt: 1,
    );
    final Transaction? saved = await editAndSave(tester, pay, () async {
      // The card is offered where the money went, which the everyday-only
      // list could not do, so Save was dead.
      expect(
        find.descendant(
          of: find.byKey(const Key('log-destination-picker')),
          matching: find.text('BPI Rewards Card'),
        ),
        findsOneWidget,
      );
      await tester.enterText(
        find.descendant(
          of: find.byKey(const Key('log-amount')),
          matching: find.byType(TextField),
        ),
        '700',
      );
      await tester.pumpAndSettle();
    });
    expect(saved, isNotNull, reason: 'Save never unlocked');
    expect(saved!.amount, const Money.pesos(700));
    expect(saved.toAccountId, 'acc_bpi_cc');
    expect(saved.accountId, 'acc_cash');
  });

  testWidgets('a new entry still offers everyday accounts only', (
    WidgetTester tester,
  ) async {
    await tester.runAsync(loadRealFonts);
    tester.view.physicalSize = const Size(1170, 3400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    final FinancialState state = FinancialState(clock: DateTime(2026, 9, 18));
    state.startWithExampleData();
    addTearDown(state.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: salapifyTheme(Palette.of(state.theme), state.theme),
        home: Builder(
          builder: (BuildContext context) => Scaffold(
            body: TextButton(
              onPressed: () => LogSheet.show(context, state),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const Key('log-source-picker')),
        matching: find.text('BPI Rewards Card'),
      ),
      findsNothing,
      reason: 'paying a card is Move money\'s job; a new log is unchanged',
    );
  });
}
