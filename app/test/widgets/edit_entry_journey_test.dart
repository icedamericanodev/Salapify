// Editing an entry, by tapping (Batch 2, 2026-10-11).
//
// The money half is test/data/edit_entry_test.dart. This is the half the
// repository keeps losing: after the edit, can a person FOLLOW it. Activity
// has to show both versions, the old one has to say it was edited rather
// than taken back, and the account has to read the corrected figure.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/format.dart';
import 'package:salapify/core/money/money.dart';
import 'package:salapify/main.dart';
import 'package:salapify/models/models.dart';
import 'package:salapify/state/financial_state.dart';

import '../shots/screens_shot.dart' show loadRealFonts;

void main() {
  const Transaction lunch = Transaction(
    id: 'tx_900',
    type: TransactionType.expense,
    amount: Money.pesos(250),
    category: 'Food & Dining',
    accountId: 'acc_gcash',
    date: '2026-09-18',
    createdAt: 900,
    merchant: 'Mang Inasal',
  );

  Future<FinancialState> openApp(WidgetTester tester) async {
    await tester.runAsync(loadRealFonts);
    tester.view.physicalSize = const Size(1170, 3400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final FinancialState state = FinancialState(clock: DateTime(2026, 9, 18));
    await state.restore();
    state.startWithExampleData();
    // The person's own entry. Example entries cannot be edited.
    state.logTransaction(lunch);
    addTearDown(state.dispose);

    await tester.pumpWidget(SalapifyApp(state: state));
    await tester.pumpAndSettle();
    return state;
  }

  Future<void> tapIt(WidgetTester tester, Finder f) async {
    await tester.ensureVisible(f.first);
    await tester.pumpAndSettle();
    await tester.tap(f.first);
    await tester.pumpAndSettle();
  }

  Money gcash(FinancialState s) =>
      s.accounts.firstWhere((Account a) => a.id == 'acc_gcash').balance;

  Future<void> editAmountTo(WidgetTester tester, String amount) async {
    await tapIt(tester, find.text('Activity'));
    await tapIt(tester, find.text('Mang Inasal'));
    await tapIt(tester, find.byKey(const Key('entry-edit')));
    expect(find.text('Edit entry'), findsOneWidget);
    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('log-amount')),
        matching: find.byType(TextField),
      ),
      amount,
    );
    await tester.pumpAndSettle();
    await tapIt(tester, find.text('Save changes'));
  }

  testWidgets('an edited amount shows on Activity twice, says which is '
      'which, and the account follows', (WidgetTester tester) async {
    final FinancialState state = await openApp(tester);
    final Money before = gcash(state);

    await editAmountTo(tester, '320');

    // Directional: 70 more left GCash.
    expect(gcash(state), before - const Money.pesos(70));
    expect(find.textContaining('Edited.'), findsOneWidget);

    // Activity: both versions, by name and by figure.
    expect(
      find.text('Mang Inasal'),
      findsNWidgets(2),
      reason: 'the old version vanished, so the history lost the correction',
    );
    expect(find.textContaining('320.00'), findsWidgets);
    expect(find.textContaining('250.00'), findsWidgets);

    // The old one says it was EDITED, not taken back. Open the struck row.
    await tester.pumpAndSettle(const Duration(seconds: 6));
    final Finder rows = find.text('Mang Inasal');
    bool sawEdited = false;
    for (int i = 0; i < 2; i++) {
      await tapIt(tester, rows.at(i));
      if (find.textContaining('You edited this entry').evaluate().isNotEmpty) {
        sawEdited = true;
      }
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();
    }
    expect(sawEdited, isTrue);

    // Accounts: GCash reads the corrected balance on screen.
    await tapIt(
      tester,
      find.byIcon(Icons.account_balance_wallet_outlined).last,
    );
    expect(find.text(formatPeso(gcash(state).pesos)), findsWidgets);
  });

  testWidgets('Undo puts it back as it was, with one row', (
    WidgetTester tester,
  ) async {
    final FinancialState state = await openApp(tester);
    final Money before = gcash(state);

    await editAmountTo(tester, '999');
    expect(gcash(state), isNot(before));

    await tapIt(tester, find.text('Undo'));
    expect(gcash(state), before);
    expect(find.textContaining('Put back as it was.'), findsOneWidget);
    expect(find.text('Mang Inasal'), findsOneWidget);
    expect(
      state.transactions
          .firstWhere((Transaction t) => t.id == 'tx_900')
          .countsTowardTotals,
      isTrue,
    );
  });

  testWidgets('an account checked against a statement since says so '
      'before Save, and only when its money would move', (
    WidgetTester tester,
  ) async {
    final FinancialState state = await openApp(tester);
    state.recordReconciliation(
      accountId: 'acc_gcash',
      bookBalance: 100,
      actualBalance: 100,
    );
    await tester.pumpAndSettle();
    await tapIt(tester, find.text('Activity'));
    await tapIt(tester, find.text('Mang Inasal'));
    await tapIt(tester, find.byKey(const Key('entry-edit')));

    // Same amount: nothing moves, so nothing to warn about.
    expect(find.byKey(const Key('log-checked-warning')), findsNothing);

    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('log-amount')),
        matching: find.byType(TextField),
      ),
      '320',
    );
    await tester.pumpAndSettle();
    expect(
      find.text(
        'GCash Wallet matched your statement today. Saving this moves '
        'GCash Wallet by ₱70.00 from that check.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('the two versions of an edit are not offered on Check as a '
      'possible double entry', (WidgetTester tester) async {
    final FinancialState state = await openApp(tester);

    // Same amount, same account, same day: only the category changes, which
    // is the shape the double entry finder pairs.
    await tapIt(tester, find.text('Activity'));
    await tapIt(tester, find.text('Mang Inasal'));
    await tapIt(tester, find.byKey(const Key('entry-edit')));
    await tapIt(
      tester,
      find.descendant(
        of: find.byKey(const Key('log-category-picker')),
        matching: find.text('Groceries'),
      ),
    );
    await tapIt(tester, find.text('Save changes'));
    // Directional: the edit happened.
    expect(
      state.transactions.where(
        (Transaction t) =>
            t.merchant == 'Mang Inasal' && t.category == 'Groceries',
      ),
      hasLength(1),
    );

    await tester.pumpAndSettle(const Duration(seconds: 6));
    await tapIt(tester, find.byIcon(Icons.insert_chart_outlined));
    await tapIt(tester, find.text('Check'));
    await tester.scrollUntilVisible(
      find.text('POSSIBLE DOUBLE ENTRIES'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Mang Inasal'),
      findsNothing,
      reason: 'an edit and its own old version were offered as a double entry',
    );
  });
}
