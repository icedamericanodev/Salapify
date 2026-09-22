import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/main.dart';
import 'package:salapify/models/models.dart';
import 'package:salapify/screens/debt/debt_screen.dart';
import 'package:salapify/screens/home/debt_beam_card.dart';
import 'package:salapify/state/financial_state.dart';

import '../shots/screens_shot.dart' show loadRealFonts;

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
    await tester.pumpWidget(const SalapifyApp());
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
      find.text('That 1.5% a month is 18.0% a year.'),
      findsOneWidget,
      reason:
          'A rate quoted per month is the most misread number in '
          'Philippine consumer lending, and the lender never prints this line.',
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
    final double gcashBefore = store.accounts
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
      closeTo(gcashBefore - 2409.17, 0.001),
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
    expect(p.principalRemaining, closeTo(9291.67, 0.001));
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
    expect(p.runningBalance, 0);

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
}
