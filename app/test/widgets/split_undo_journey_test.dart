// Split a bill, then take it back.
//
// `split_bill_journey_test.dart` proves a split WRITES and that every screen
// can show what it wrote. This is the other direction, and it is the half the
// app did not have at all: real money left a real account on one tap, and
// nothing anywhere could put it back. The Debts tab could delete the
// receivables one by one; the expense was permanent.
//
// Both tests below drive the WHOLE app from Home rather than pumping the
// sheet on its own, because the thing under test is not the sheet. The sheet
// hands back what it wrote and Home is what decides to show a confirmation
// and offer the undo, so a test that opens the sheet directly would pass with
// Home still throwing the result away, which is exactly the defect.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/money.dart';
import 'package:salapify/main.dart';
import 'package:salapify/models/models.dart';
import 'package:salapify/screens/home/quick_actions.dart';
import 'package:salapify/state/financial_state.dart';

import '../shots/screens_shot.dart' show loadRealFonts;

void main() {
  /// The whole app, on a tall phone, with the clock pinned.
  ///
  /// Pinned for the same reason every other journey pins it: the seed ledger
  /// is dated September and a real clock has moved past it.
  Future<FinancialState> openApp(WidgetTester tester) async {
    // Real fonts, because this pumps Home and Home measures. Without them a
    // layout judged in Flutter's wider default font is a layout nobody will
    // ever see.
    await tester.runAsync(loadRealFonts);

    tester.view.physicalSize = const Size(1170, 3400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final FinancialState state = FinancialState(clock: DateTime(2026, 9, 18));
    await state.restore();
    addTearDown(state.dispose);

    await tester.pumpWidget(SalapifyApp(state: state));
    await tester.pumpAndSettle();
    return state;
  }

  /// Scroll to it, then tap it.
  ///
  /// Tapping a finder whose centre is off screen does NOT fail in Flutter: it
  /// warns and lands nowhere, and the assertion afterwards then reports a
  /// save path that does not save. The sibling journey learned this the hard
  /// way and the note is repeated here rather than relied on being read.
  Future<void> tapIt(WidgetTester tester, Finder f) async {
    await tester.ensureVisible(f.first);
    await tester.pumpAndSettle();
    await tester.tap(f.first);
    await tester.pumpAndSettle();
  }

  Future<void> type(WidgetTester tester, String label, String value) async {
    await tester.enterText(
      find
          .descendant(
            of: find
                .ancestor(of: find.text(label), matching: find.byType(Column))
                .first,
            matching: find.byType(TextField),
          )
          .first,
      value,
    );
    await tester.pumpAndSettle();
  }

  Money balanceOf(FinancialState s, String id) =>
      s.accounts.firstWhere((Account a) => a.id == id).balance;

  double netWorthOf(FinancialState s) => s.accounts.fold<double>(
    0,
    (double sum, Account a) => sum + a.balance.pesos,
  );

  List<Debt> splitDebts(FinancialState s) => s.debts
      .where((Debt d) => (d.notes ?? '').startsWith('Split:'))
      .toList(growable: false);

  /// Open Split from Home, split 1,200 with one other person, record it.
  ///
  /// Returns the account the expense came out of, so the caller can watch
  /// that one account rather than a total that several things feed.
  Future<String> splitTwelveHundred(
    WidgetTester tester,
    FinancialState state,
  ) async {
    await tapIt(
      tester,
      find.descendant(
        of: find.byType(QuickActions),
        matching: find.text('Split'),
      ),
    );
    expect(find.text('Total bill'), findsOneWidget);

    // The account is never chosen on this sheet: initState picks whichever
    // one sorts first and the expense box starts ticked. That default is the
    // whole reason the caption now names it, so the test reads the same
    // default rather than setting one.
    final String accountId = state.accounts.first.id;

    await type(tester, 'Total bill', '1200');
    await type(tester, 'Add somebody', 'Carla');
    await tapIt(tester, find.bySemanticsLabel('Add this person to the split'));
    await tapIt(tester, find.text('Record it'));

    return accountId;
  }

  testWidgets('a split can be taken straight back out again', (
    WidgetTester tester,
  ) async {
    final FinancialState state = await openApp(tester);

    final String accountId = state.accounts.first.id;
    final Money openingBalance = balanceOf(state, accountId);
    final double openingNetWorth = netWorthOf(state);
    final int openingDebts = state.debts.length;
    final int openingEntries = state.transactions.length;

    await splitTwelveHundred(tester, state);

    // DID ANYTHING ACTUALLY HAPPEN. This half comes first and it is
    // DIRECTIONAL on purpose. The invariant below ("everything returns to
    // where it started") is unfalsifiable by inaction: a split that split
    // nothing, undone, also returns everything to where it started. So the
    // movement is named here, per account and per record, before anything is
    // undone.
    expect(
      balanceOf(state, accountId).pesos,
      closeTo(openingBalance.pesos - 1200, 0.001),
      reason:
          'the whole bill should have left the account the sheet defaulted '
          'to, and it did not move',
    );
    expect(
      splitDebts(state).length,
      1,
      reason: 'one receivable for Carla should exist after the split',
    );
    expect(state.transactions.length, openingEntries + 1);

    // And the person is TOLD, which is the other half of the defect. Before
    // this change Home threw the sheet's result away, so a split saved in
    // total silence while every ordinary logged entry said "Saved to this
    // phone".
    expect(
      find.textContaining('Split recorded.'),
      findsOneWidget,
      reason: 'nothing confirmed the split, so nobody can tell it saved',
    );
    expect(find.text('Undo'), findsOneWidget);

    await tapIt(tester, find.text('Undo'));

    // THE INVARIANT. Taking a split back cannot leave the money anywhere
    // except where it was: the expense is reversed and the receivables are
    // gone, so every total is exactly as it opened.
    expect(
      balanceOf(state, accountId).centavos,
      openingBalance.centavos,
      reason: 'the account did not come back to the centavo',
    );
    expect(netWorthOf(state), closeTo(openingNetWorth, 0.001));
    expect(
      splitDebts(state),
      isEmpty,
      reason:
          'the receivables outlived the undo, which is money back in the '
          'account with a record elsewhere still saying it is owed',
    );
    expect(state.debts.length, openingDebts);
    expect(
      state.transactions.length,
      openingEntries,
      reason: 'the expense row is still in the ledger after the undo',
    );

    // CONFIRMED, rather than silently vanishing. An entry that disappears
    // with no word is indistinguishable from one that failed to save.
    expect(find.textContaining('Taken back out.'), findsOneWidget);
  });

  testWidgets('the undo refuses WHOLE once one of the debts has been paid', (
    WidgetTester tester,
  ) async {
    final FinancialState state = await openApp(tester);

    final String accountId = state.accounts.first.id;
    final Money openingBalance = balanceOf(state, accountId);

    await splitTwelveHundred(tester, state);

    final List<Debt> created = splitDebts(state);
    expect(created, hasLength(1));

    final Money afterSplit = balanceOf(state, accountId);

    // Carla pays 600 of her 600 share. Driven through the store rather than
    // through the Debts tab because what is under test is the undo's
    // refusal, not the payment screen, which debt_journey_test.dart already
    // walks. The payment is real either way: it moves the debt AND writes
    // its own ledger entry.
    state.recordDebtPayment(created.first.id, 600, accountId: accountId);
    await tester.pumpAndSettle();

    final Money afterPayment = balanceOf(state, accountId);
    final int entriesAfterPayment = state.transactions.length;

    await tapIt(tester, find.text('Undo'));

    // REFUSED WHOLE, which is the point. Undoing the expense while Carla's
    // 600 stands would put 1,200 back in the account and leave a repayment
    // in the ledger with nothing left to repay.
    expect(
      balanceOf(state, accountId).centavos,
      afterPayment.centavos,
      reason: 'the refused undo moved the balance anyway',
    );
    expect(
      state.transactions.length,
      entriesAfterPayment,
      reason: 'the refused undo removed a ledger row anyway',
    );
    expect(
      splitDebts(state),
      hasLength(1),
      reason: 'the refused undo deleted the debt anyway',
    );

    // And it is not the success message. A refusal dressed as a success
    // leaves somebody believing their balance went back when it did not.
    expect(find.textContaining('Not taken back.'), findsOneWidget);
    expect(find.textContaining('Taken back out.'), findsNothing);

    // The split itself still stands, in full, which is the state the person
    // is being told to go and tidy by hand from the Debts tab.
    expect(afterSplit.centavos, openingBalance.centavos - 120000);
  });
}
