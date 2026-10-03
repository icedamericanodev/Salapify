import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/models/models.dart';
import 'package:salapify/screens/debt/debt_screen.dart';
import 'package:salapify/screens/home/debt_beam_card.dart';
import 'package:salapify/state/financial_state.dart';

import '../shots/screens_shot.dart' show loadRealFonts;

import '../support/pinned_app.dart';
import 'package:salapify/core/money/money.dart';

/// The instalment write path, in BOTH halves.
///
/// Half one lives in core/money/installments_test.dart, against vectors from
/// the prototype's own reducers. This is half two: after paying, can a person
/// FOLLOW it, on every screen that should now mention it.
void main() {
  Future<void> tapAndSettle(WidgetTester tester, Finder f) async {
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  Future<void> reach(WidgetTester tester, Finder f) async {
    await tester.scrollUntilVisible(
      f,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  Future<void> openPlans(WidgetTester tester) async {
    await pumpSalapify(tester);
    await tester.pumpAndSettle();
    await reach(tester, find.byType(DebtBeamCard));
    await tapAndSettle(
      tester,
      find.descendant(
        of: find.byType(DebtBeamCard),
        matching: find.text('See all'),
      ),
    );
    await tapAndSettle(tester, find.text('Plans'));
  }

  FinancialState storeOf(WidgetTester tester) =>
      tester.widget<DebtScreen>(find.byType(DebtScreen)).state;

  testWidgets('the plans open with their real contracts, not stubs', (
    WidgetTester tester,
  ) async {
    await openPlans(tester);

    expect(find.text('Inverter Refrigerator (Abenson)'), findsOneWidget);
    expect(
      find.text('Home Credit · 1.5% a month'),
      findsOneWidget,
      reason:
          'This class held a name and an amount until this batch. The '
          'provider, the rate and the way the rate is quoted are the whole '
          'point of the screen.',
    );
    expect(
      find.text('Quoted as 1.5% a month, 18.0% a year.'),
      findsOneWidget,
      reason:
          'The quoted rate stays visible. It is not wrong and nobody is '
          'hiding it; it just answers a different question.',
    );
    expect(
      // THE LINE THIS WHOLE FEATURE EXISTS FOR. The screen used to print the
      // 18% alone and call it "the comparison the lender does not put on the
      // poster". It is the poster: multiplying a quoted monthly rate by
      // twelve is the lender's own arithmetic. On the money still owed this
      // plan costs nearer 2.6% a month.
      find.text(
        'On what you still owe each month it works out to 2.6%, or '
        '31.7% a year.',
      ),
      findsOneWidget,
      reason: 'the true cost of an add-on plan is not on the card',
    );
    expect(
      // And the genuine 0% plan is NOT accused of anything. A line saying
      // "really 0%" about a lender who charged nothing reads as an
      // accusation, and teaches people to distrust the one that matters.
      find.textContaining('On what you still owe'),
      findsNWidgets(2),
      reason:
          'the interest-free BPI plan must carry no correction, so only the '
          'two interest-bearing plans do',
    );
    expect(find.text('Payment 5 of 12, 7 to go.'), findsOneWidget);
  });

  testWidgets('a real 0 percent promo says so rather than showing 0.0%', (
    WidgetTester tester,
  ) async {
    await openPlans(tester);
    await reach(tester, find.text('MacBook Air M2 Work Setup'));
    expect(
      find.text('BPI Special Installment Plan (SIP) · No interest'),
      findsOneWidget,
    );
    // And its existing prepayment survived the port.
    expect(find.textContaining('Mid-year bonus prepayment'), findsOneWidget);
  });

  testWidgets('paying an instalment moves the plan, the account AND leaves a '
      'trail', (WidgetTester tester) async {
    await openPlans(tester);
    final FinancialState store = storeOf(tester);
    final Money gcashBefore = store.accounts
        .firstWhere((Account a) => a.id == 'acc_gcash')
        .balance;
    final int entriesBefore = store.transactions.length;

    await tapAndSettle(tester, find.text('Pay this month').first);

    // The amount is NOT editable, and the sheet says why.
    expect(
      find.textContaining('The amount is set by the plan'),
      findsOneWidget,
    );
    await tapAndSettle(tester, find.text('GCash Wallet'));
    expect(
      find.textContaining('You will be on payment 6 of 12'),
      findsOneWidget,
    );
    await tapAndSettle(tester, find.text('Record the payment'));

    // Half one, directional on both sides.
    final InstallmentPlan p = store.installments.firstWhere(
      (InstallmentPlan x) => x.id == 'inst_home_credit',
    );
    expect(p.paidInstallments, 6);
    expect(
      store.accounts.firstWhere((Account a) => a.id == 'acc_gcash').balance,
      gcashBefore - Money.fromDouble(2409.17),
    );
    expect(store.transactions.length, entriesBefore + 1);

    // Half two, screen by screen.
    expect(find.text('Payment 6 of 12, 6 to go.'), findsOneWidget);

    await tapAndSettle(tester, find.byIcon(Icons.arrow_back));
    await tapAndSettle(tester, find.byIcon(Icons.menu_book_outlined));
    await reach(
      tester,
      find.text('Home Credit, Inverter Refrigerator (Abenson)'),
    );
    expect(
      find.text('Home Credit, Inverter Refrigerator (Abenson)'),
      findsOneWidget,
      reason: 'the balance moved, so Activity has to say why',
    );
  });

  testWidgets('an extra payment comes off the principal and is kept in the '
      'plan history', (WidgetTester tester) async {
    await openPlans(tester);
    final FinancialState store = storeOf(tester);

    await tapAndSettle(tester, find.text('Pay extra').first);
    await tester.enterText(find.widgetWithText(TextField, '0.00'), '5000');
    await tester.pumpAndSettle();
    await tapAndSettle(tester, find.text('GCash Wallet'));
    expect(
      find.textContaining('comes straight off the principal'),
      findsOneWidget,
    );
    await tapAndSettle(tester, find.text('Record the extra payment'));

    final InstallmentPlan p = store.installments.firstWhere(
      (InstallmentPlan x) => x.id == 'inst_home_credit',
    );
    // 9,291.65 and exact. It was 9,291.67 with a tolerance, because the
    // seeded principal was computed from the rounded instalment rather
    // than from the contract. Centavos need no tolerance.
    expect(p.principalRemaining, const Money.of(9291, 65));
    expect(
      p.paidInstallments,
      5,
      reason:
          'an extra payment is NOT an instalment. The counter tracks the '
          'contract, and paying early does not make it month six.',
    );
    expect(p.extraPayments.length, 1);

    // And it is visible on the plan afterwards, not merely stored.
    //
    // TWO headings now, which is correct and worth naming: the refrigerator
    // just got its first extra payment, and the MacBook plan came seeded with
    // one. `.first` because scrollUntilVisible needs a single target.
    await reach(tester, find.text('EXTRA PAYMENTS').first);
    expect(find.text('EXTRA PAYMENTS'), findsNWidgets(2));
    expect(find.textContaining('Principal prepayment'), findsOneWidget);
    expect(
      find.textContaining('Mid-year bonus prepayment'),
      findsOneWidget,
      reason: 'the seeded one must not be trampled by the new one',
    );
  });

  testWidgets('paying a plan out marks it paid off and keeps it visible', (
    WidgetTester tester,
  ) async {
    await openPlans(tester);
    final FinancialState store = storeOf(tester);

    // SPayLater is 2 of 6, so four payments finish it.
    for (int i = 0; i < 4; i++) {
      await reach(tester, find.text('Ergonomic Desk & Chair'));
      final Finder card = find.ancestor(
        of: find.text('Ergonomic Desk & Chair'),
        matching: find.byType(Container),
      );
      await tapAndSettle(
        tester,
        find.descendant(of: card.first, matching: find.text('Pay this month')),
      );
      await tapAndSettle(tester, find.text('Record the payment'));
    }

    final InstallmentPlan p = store.installments.firstWhere(
      (InstallmentPlan x) => x.id == 'inst_spaylater',
    );
    expect(p.isSettled, isTrue);
    expect(p.runningBalance, Money.zero);

    await reach(tester, find.text('PAID OFF'));
    expect(
      find.text('PAID OFF'),
      findsOneWidget,
      reason:
          'A finished plan is the only record that it was finished. It '
          'stays on the screen rather than vanishing.',
    );
    expect(find.text('All 6 payments made.'), findsOneWidget);
  });

  testWidgets('the monthly total drops when a plan finishes', (
    WidgetTester tester,
  ) async {
    await openPlans(tester);

    // 2,409.17 + 2,291.25 + 1,647.80
    expect(find.text('₱6,348.22'), findsOneWidget);

    for (int i = 0; i < 4; i++) {
      await reach(tester, find.text('Ergonomic Desk & Chair'));
      final Finder card = find.ancestor(
        of: find.text('Ergonomic Desk & Chair'),
        matching: find.byType(Container),
      );
      await tapAndSettle(
        tester,
        find.descendant(of: card.first, matching: find.text('Pay this month')),
      );
      await tapAndSettle(tester, find.text('Record the payment'));
    }

    await tester.scrollUntilVisible(
      find.text('EVERY MONTH, ALL PLANS'),
      -200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(
      find.text('₱4,700.42'),
      findsOneWidget,
      reason:
          'the finished plan takes nothing out of next month, so the '
          'headline has to drop by its 1,647.80',
    );
  });

  testWidgets('nothing on the plans view overflows at 320dp', (
    WidgetTester tester,
  ) async {
    await loadRealFonts();
    tester.view.physicalSize = const Size(320 * 3, 900 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await openPlans(tester);
    expect(tester.takeException(), isNull);
    await reach(tester, find.text('Ergonomic Desk & Chair'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a plan that was never paid can be DELETED, by tapping', (
    WidgetTester tester,
  ) async {
    // The exit the Plans tab never had. Until this batch a plan could not be
    // removed by ANY route, so a plan restored from a backup that had been
    // cancelled or paid off elsewhere stayed in Safe to Spend's reserve for
    // good.
    await openPlans(tester);
    final FinancialState store = storeOf(tester);

    final int before = store.installments.length;
    expect(before, greaterThan(0), reason: 'no plans, so this proves nothing');

    await reach(tester, find.text('Delete this plan').first);
    await tapAndSettle(tester, find.text('Delete this plan').first);

    // The confirmation names the figure it frees up, not just the deletion.
    expect(
      find.textContaining('Safe to Spend on Home goes up'),
      findsOneWidget,
    );
    expect(find.textContaining('There is no undo'), findsOneWidget);
    await tapAndSettle(tester, find.text('Delete'));

    expect(
      store.installments,
      hasLength(before - 1),
      reason: 'the delete did nothing, so the assertions below are hollow',
    );
  });

  testWidgets('a plan paid into offers no delete, and says nothing silly', (
    WidgetTester tester,
  ) async {
    await openPlans(tester);
    final FinancialState store = storeOf(tester);

    // Pay one, which is the tap that used to adopt a demo plan for ever.
    // ANY plan: every seeded one already carries a counter and an empty
    // register, which is exactly the state that made the first version of
    // the delete gate useless.
    final String id = store.installments.first.id;
    final int countBefore = store.installments.first.paidInstallments;
    store.payInstallment(id);
    await tester.pumpAndSettle();

    final InstallmentPlan paid = store.installments.firstWhere(
      (InstallmentPlan p) => p.id == id,
    );
    expect(paid.paidInstallments, countBefore + 1);
    expect(
      paid.payments,
      isNotEmpty,
      reason: 'no register row, so the take-back route does not exist either',
    );

    // And the way out is still open: take the payment back, then delete.
    expect(store.takeBackPlanPayment(id), isTrue);
    await tester.pumpAndSettle();
    expect(
      store.deletePlan(id),
      isTrue,
      reason:
          'the plan was paid and then un-paid, and it still cannot be '
          'removed, which is the trap this feature exists to open',
    );
  });

  testWidgets('ARCHIVE a paid off plan, then PUT IT BACK, both by tapping', (
    WidgetTester tester,
  ) async {
    await openPlans(tester);
    final FinancialState store = storeOf(tester);

    // Clear a plan by paying it out, so the archive gate is satisfied the way
    // a person would satisfy it rather than by a fixture.
    final InstallmentPlan target = store.installments.first;
    for (
      int i = store.installments.first.paidInstallments;
      i < target.totalInstallments;
      i++
    ) {
      store.payInstallment(target.id);
    }
    await tester.pumpAndSettle();
    expect(
      store.installments
          .firstWhere((InstallmentPlan p) => p.id == target.id)
          .isSettled,
      isTrue,
      reason: 'paying it out did not settle it, so there is nothing to archive',
    );

    final Money safeBefore = store.safeToSpend;
    final int liveBefore = store.installments.length;

    await reach(tester, find.text('Archive it').first);
    await tapAndSettle(tester, find.text('Archive it').first);
    // The dialog's confirm carries the same words, so take the LAST match.
    await tapAndSettle(tester, find.text('Archive it').last);

    // THE MIDPOINT, asserted before the round trip.
    expect(
      store.archivedInstallments,
      hasLength(1),
      reason: 'nothing was archived, so the round trip below proves nothing',
    );
    expect(store.installments, hasLength(liveBefore - 1));
    expect(
      store.safeToSpend,
      safeBefore,
      reason:
          'archiving moved Safe to Spend, which the settled only gate exists '
          'to make impossible',
    );

    // The way back has to be REACHABLE, not merely implemented.
    await reach(tester, find.text('ARCHIVED'));
    await reach(tester, find.text('Put it back'));
    await tapAndSettle(tester, find.text('Put it back'));

    expect(store.archivedInstallments, isEmpty);
    expect(store.installments, hasLength(liveBefore));
    expect(find.text('ARCHIVED'), findsNothing);
  });
}
