// Taking an entry back from Activity, by tapping.
//
// `test/data/take_back_routing_test.dart` is the first half: it proves the
// router sends every kind of entry to the right answer. This is the half this
// repository keeps losing, and the rule is written in CLAUDE.md because it
// was learned from a real complaint: a write path is not tested until
// somebody can SEE what it did.
//
// So this walks the screens. Open Activity, open an entry, take it back, and
// then check the two places a person would actually look: the account, and
// the row itself. A take-back that moved the money and left no visible trace
// would be the same defect in the other direction.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/money.dart';
import 'package:salapify/main.dart';
import 'package:salapify/models/models.dart';
import 'package:salapify/state/financial_state.dart';

import '../shots/screens_shot.dart' show loadRealFonts;

void main() {
  Future<FinancialState> openApp(WidgetTester tester) async {
    // Real fonts, because this pumps whole screens and they measure.
    await tester.runAsync(loadRealFonts);

    tester.view.physicalSize = const Size(1170, 3400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    // Pinned, like every other journey: the seed ledger is dated September
    // and a real clock has moved past it.
    final FinancialState state = FinancialState(clock: DateTime(2026, 9, 18));
    await state.restore();
    // The app opens on the welcome when nothing has been onboarded. This
    // fixture is the seeded ledger, which is what the "look around with
    // example data" path leaves behind, so it says so.
    state.startWithExampleData();
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

  Money balanceOf(FinancialState s, String id) =>
      s.accounts.firstWhere((Account a) => a.id == id).balance;

  Transaction entry(FinancialState s, String id) =>
      s.transactions.firstWhere((Transaction t) => t.id == id);

  /// Walk to Activity and open the entry whose merchant reads [merchant].
  ///
  /// `scrollUntilVisible` with a negative delta, because Activity is a long
  /// lazily built list: a row outside the built range is genuinely absent
  /// from the element tree, not merely off screen, so a plain finder reports
  /// "not found" for a row that is perfectly fine. That cost a near false
  /// alarm on the split journey and the note is repeated rather than relied
  /// on being remembered.
  Future<void> openEntry(WidgetTester tester, String merchant) async {
    await tapIt(tester, find.text('Activity'));
    await tester.scrollUntilVisible(
      find.text(merchant).first,
      -200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tapIt(tester, find.text(merchant));
  }

  testWidgets('an ordinary entry can be taken back, and it shows', (
    WidgetTester tester,
  ) async {
    final FinancialState state = await openApp(tester);

    // Jollibee, 285.00 out of GCash, from the lived-in seed.
    final Money before = balanceOf(state, 'acc_gcash');
    expect(entry(state, 'tx_jollibee').countsTowardTotals, isTrue);

    await openEntry(tester, 'Jollibee');

    expect(
      find.text('Take this back'),
      findsOneWidget,
      reason: 'the control is not on the sheet at all',
    );
    await tapIt(tester, find.text('Take this back'));

    // THE CONFIRMATION NAMES THE DIRECTION AND THE ACCOUNT. An expense taken
    // back puts money IN, and getting that backwards is the whole worry.
    expect(find.textContaining('goes back into'), findsOneWidget);
    expect(find.textContaining('285.00'), findsWidgets);
    await tapIt(tester, find.text('Take it back'));

    // DID ANYTHING HAPPEN, directional and per account. The invariant below
    // ("it stops counting") would hold just as well if nothing moved.
    expect(
      balanceOf(state, 'acc_gcash').centavos,
      before.centavos + 28500,
      reason: 'the 285.00 did not come back to the account',
    );

    // AND IT IS STILL THERE. This is the founder's ruling: the row stays so
    // the history shows the correction, which is the difference between a
    // take-back and a delete.
    final Transaction after = entry(state, 'tx_jollibee');
    expect(after.status, TransactionStatus.corrected);
    expect(after.countsTowardTotals, isFalse);

    expect(find.textContaining('Taken back.'), findsOneWidget);

    // Walk back to the row and read what a person would read.
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Jollibee').first,
      -200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Jollibee'),
      findsWidgets,
      reason: 'the entry vanished from Activity instead of being marked',
    );
  });

  testWidgets('the sheet refuses a debt payment, and says where to go', (
    WidgetTester tester,
  ) async {
    final FinancialState state = await openApp(tester);

    // A real payment, through the real write path, so the entry it creates
    // is the genuine article rather than a hand-built lookalike.
    final Debt debt = state.debts.firstWhere(
      (Debt d) => d.direction == DebtDirection.iOwe && !d.isSettled,
    );
    state.recordDebtPayment(debt.id, 500, accountId: 'acc_gcash');
    await tester.pumpAndSettle();

    final Transaction payment = state.transactions.firstWhere(
      (Transaction t) => t.id.startsWith('tx_debt_'),
    );
    final Money before = balanceOf(state, 'acc_gcash');

    // The merchant line the engine writes, not the bare name. Reading it off
    // the real entry rather than retyping it, so a reworded engine renames
    // the row and this test follows instead of silently missing it.
    await openEntry(tester, payment.merchant!);

    // NO BUTTON, and a sentence instead. A dead end is not an answer to
    // somebody looking at their own money, so the refusal names the screen
    // that owns the real take-back.
    expect(
      find.text('Take this back'),
      findsNothing,
      reason:
          'the sheet offered to reverse a debt payment, which would put the '
          'money back and leave the debt still saying it was paid',
    );
    expect(find.textContaining('Take back the last payment'), findsOneWidget);

    // And nothing moved just by looking at it.
    expect(balanceOf(state, 'acc_gcash').centavos, before.centavos);
    expect(
      entry(state, payment.id).countsTowardTotals,
      isTrue,
      reason: 'the entry stopped counting without anybody tapping anything',
    );
  });
}
