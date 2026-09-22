import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/design/app_theme.dart';
import 'package:salapify/design/tokens.dart';
import 'package:salapify/features/safe_to_spend/safe_to_spend_sheet.dart';
import 'package:salapify/models/models.dart';
import 'package:salapify/state/financial_state.dart';

import '../shots/screens_shot.dart' show loadRealFonts;

/// The Cash Runway card in the Safe to Spend sheet.
///
/// This is the SECOND reader of the same figure the hero card stopped
/// stating. The hero drops the clause; this sheet is where the number is
/// allowed to appear, because it comes with the caption that says which burn
/// rate produced it. Except in one case, where there is no burn rate and no
/// cash either, and "0 days" set in the card's largest type reads as a
/// verdict on somebody who has recorded nothing.
///
/// The third test is the one that matters most. A zero with a MEASURED pace
/// behind it is a true and urgent sentence, and a fix that silenced it would
/// take it away from exactly the person who needs it.
void main() {
  Future<void> pump(WidgetTester tester, FinancialState state) async {
    await tester.runAsync(loadRealFonts);
    tester.view.physicalSize = const Size(1170, 3400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final Palette p = Palette.of(state.theme);
    await tester.pumpWidget(
      MaterialApp(
        theme: salapifyTheme(p, state.theme),
        home: Scaffold(
          backgroundColor: p.background,
          body: SafeToSpendSheet(state: state),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('nothing recorded reads as unknown, not as zero days', (
    WidgetTester tester,
  ) async {
    final FinancialState state = FinancialState(
      clock: DateTime.utc(2026, 9, 18),
    );
    state.removeSampleData();
    await pump(tester, state);

    expect(find.text('Not enough recorded yet'), findsOneWidget);
    expect(
      find.text('0 days'),
      findsNothing,
      reason:
          'nothing divided by an invented burn rate is being presented as a '
          'measured result, in the largest type on the card',
    );
  });

  testWidgets('a lived-in phone still gets the figure and its caption', (
    WidgetTester tester,
  ) async {
    final FinancialState state = FinancialState(
      clock: DateTime.utc(2026, 9, 18),
    );
    await pump(tester, state);

    expect(find.text('116 days'), findsOneWidget);
    expect(
      find.textContaining('at your recent spending'),
      findsOneWidget,
      reason: 'a measured runway lost the caption that says it is measured',
    );
  });

  testWidgets('a real zero, measured, is still said out loud', (
    WidgetTester tester,
  ) async {
    // Somebody who logs their spending and has run their accounts down. The
    // pace is theirs, the cash is genuinely gone, and "0 days" is the most
    // important sentence the app can show them. Silencing on the cash alone
    // would take it away from the one person it is for.
    final FinancialState state = FinancialState(
      clock: DateTime.utc(2026, 9, 18),
    );
    state.removeSampleData();
    state.addAccount(
      const Account(
        id: 'mine',
        name: 'My wallet',
        kind: AccountKind.cash,
        institution: 'Cash',
        // Starts at exactly what gets spent, so the wallet lands on zero.
        balance: 9000,
        monogram: 'C',
      ),
    );
    // Over the engine's 5,000 threshold, so the pace is a measurement.
    state.logTransaction(
      Transaction(
        id: 'tx_spent',
        type: TransactionType.expense,
        amount: 9000,
        category: 'Food & Dining',
        merchant: 'Groceries',
        accountId: 'mine',
        date: '2026-09-10',
        createdAt: DateTime.utc(2026, 9, 10).millisecondsSinceEpoch,
      ),
    );
    await pump(tester, state);

    expect(
      state.safeToSpendAnalysis.runwayFromLoggedSpending,
      isTrue,
      reason: 'the pace is not measured here, so this proves nothing',
    );

    expect(
      find.text('Not enough recorded yet'),
      findsNothing,
      reason:
          'a measured zero was silenced, which hides the one sentence the '
          'person who is actually out of money needs to read',
    );
    expect(find.text('0 days'), findsOneWidget);
  });
}
