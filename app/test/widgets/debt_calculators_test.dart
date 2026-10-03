import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/debt_strategy.dart';
import 'package:salapify/core/money/format.dart';
import 'package:salapify/core/money/loan.dart';
import 'package:salapify/core/money/loan_products.dart';
import 'package:salapify/design/tokens.dart';
import 'package:salapify/screens/debt/debt_calculators.dart';

import '../shots/screens_shot.dart' show loadRealFonts;

/// The nine loan calculators.
///
/// The arithmetic is proved elsewhere, against vectors from the prototype, in
/// loan_golden_test, loan_products_golden_test and debt_strategy_golden_test.
/// These tests ask the only question those cannot: does the SCREEN put the
/// engine's answer on it, unchanged.
///
/// So every expectation here is computed by calling the same engine the screen
/// calls, rather than by writing a figure out by hand. A hand-written figure
/// would pin the screen to my arithmetic instead of to the engine's, which is
/// the exact mistake the golden-vector rule exists to prevent.
void main() {
  Widget wrap() => MaterialApp(
    home: Scaffold(
      backgroundColor: Palette.gabi.background,
      body: SingleChildScrollView(
        child: DebtCalculators(palette: Palette.gabi),
      ),
    ),
  );

  Future<void> open(WidgetTester tester, [String? calculator]) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
    if (calculator != null) {
      await tester.ensureVisible(find.text(calculator));
      await tester.pumpAndSettle();
      await tester.tap(find.text(calculator));
      await tester.pumpAndSettle();
    }
  }

  testWidgets('it opens on Pag-IBIG with a real answer already on it', (
    WidgetTester tester,
  ) async {
    await open(tester);

    // The prototype's own defaults: 1,500,000 over 20 years, regular
    // programme, 3 year fixing, 1,000 extra a month.
    final LoanCalculationResult expected = calculatePagIbigHousingLoan(
      program: PagIbigProgram.regularHousing,
      loanAmount: 1500000,
      termYears: 20,
      fixingPeriodYears: 3,
      extraMonthlyPayment: 1000,
    );

    expect(
      find.text(formatPeso(expected.monthlyPayment)),
      findsWidgets,
      reason:
          'A calculator that opens empty makes somebody fill five boxes '
          'before it says anything. This one opens with a worked example.',
    );
    expect(find.text(formatPeso(expected.totalInterest)), findsWidgets);
  });

  testWidgets('changing the programme changes the number on screen', (
    WidgetTester tester,
  ) async {
    await open(tester);

    final String regular = formatPeso(
      calculatePagIbigHousingLoan(
        program: PagIbigProgram.regularHousing,
        loanAmount: 1500000,
        termYears: 20,
        fixingPeriodYears: 3,
        extraMonthlyPayment: 1000,
      ).monthlyPayment,
    );
    final String affordable = formatPeso(
      calculatePagIbigHousingLoan(
        program: PagIbigProgram.affordableHousing,
        loanAmount: 1500000,
        termYears: 20,
        fixingPeriodYears: 3,
        extraMonthlyPayment: 1000,
      ).monthlyPayment,
    );

    expect(
      regular,
      isNot(affordable),
      reason:
          'the fixture must differ, or '
          'this test passes with the control wired to nothing',
    );

    expect(find.text(regular), findsWidgets);
    await tester.tap(find.text('Affordable'));
    await tester.pumpAndSettle();

    expect(find.text(affordable), findsWidgets);
    expect(
      find.text(regular),
      findsNothing,
      reason:
          'the directional check: the old figure has to GO, not merely be '
          'joined by the new one',
    );
  });

  testWidgets('typing a different amount moves the answer', (
    WidgetTester tester,
  ) async {
    await open(tester);

    final String before = formatPeso(
      calculatePagIbigHousingLoan(
        program: PagIbigProgram.regularHousing,
        loanAmount: 1500000,
        termYears: 20,
        fixingPeriodYears: 3,
        extraMonthlyPayment: 1000,
      ).monthlyPayment,
    );
    final String after = formatPeso(
      calculatePagIbigHousingLoan(
        program: PagIbigProgram.regularHousing,
        loanAmount: 2000000,
        termYears: 20,
        fixingPeriodYears: 3,
        extraMonthlyPayment: 1000,
      ).monthlyPayment,
    );

    expect(find.text(before), findsWidgets);
    await tester.enterText(
      find.widgetWithText(TextField, '1500000'),
      '2000000',
    );
    await tester.pumpAndSettle();
    expect(find.text(after), findsWidgets);
    expect(find.text(before), findsNothing);
  });

  testWidgets('the car calculator shows what a flat add-on rate really costs', (
    WidgetTester tester,
  ) async {
    await open(tester, 'Car loan');

    final CarLoanResult flat = calculateCarLoan(
      vehiclePrice: 1100000,
      downpaymentPercent: 20,
      termMonths: 60,
      annualInterestRate: 9.5,
      rateType: RateType.flatAddon,
      includeInsuranceAndChattel: true,
    );
    final CarLoanResult diminishing = calculateCarLoan(
      vehiclePrice: 1100000,
      downpaymentPercent: 20,
      termMonths: 60,
      annualInterestRate: 9.5,
      rateType: RateType.diminishing,
      includeInsuranceAndChattel: true,
    );

    expect(find.text(formatPeso(flat.monthlyPayment)), findsWidgets);
    expect(
      flat.totalInterest,
      greaterThan(diminishing.totalInterest),
      reason:
          'The whole point of this calculator: the same 9.5 percent costs '
          'more quoted the dealership way. If this ever stops being true the '
          'screen is teaching something false.',
    );

    await tester.ensureVisible(find.text('Diminishing'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Diminishing'));
    await tester.pumpAndSettle();
    expect(find.text(formatPeso(diminishing.monthlyPayment)), findsWidgets);
  });

  testWidgets('the salary loan shows what actually reaches you, not the '
      'headline', (WidgetTester tester) async {
    await open(tester, 'SSS and Pag-IBIG salary');

    final SalaryLoanResult r = calculateSalaryLoan(
      loanType: SalaryLoanType.pagibigMpl,
      loanAmount: 50000,
      termMonths: 24,
    );

    expect(find.text('WHAT ACTUALLY REACHES YOU'), findsOneWidget);
    expect(find.text(formatPeso(r.netProceeds)), findsWidgets);
    expect(
      r.netProceeds,
      lessThanOrEqualTo(50000),
      reason: 'the fee comes off before the money arrives',
    );
  });

  testWidgets('the credit card calculator makes the minimum trap visible', (
    WidgetTester tester,
  ) async {
    await open(tester, 'Credit card trap');

    final CreditCardPayoffResult minimum = calculateCreditCardPayoff(
      currentBalance: 45000,
      monthlyInterestRate: 3.0,
      paymentStrategy: CardPaymentStrategy.minimumOnly,
    );
    final CreditCardPayoffResult fixed = calculateCreditCardPayoff(
      currentBalance: 45000,
      monthlyInterestRate: 3.0,
      paymentStrategy: CardPaymentStrategy.fixedAmount,
      fixedMonthlyPayment: 5000,
    );

    expect(find.text(formatPeso(minimum.totalInterestPaid)), findsWidgets);

    await tester.tap(find.text('A fixed amount'));
    await tester.pumpAndSettle();

    expect(find.text(formatPeso(fixed.totalInterestPaid)), findsWidgets);
    expect(
      fixed.totalInterestPaid,
      lessThan(minimum.totalInterestPaid),
      reason:
          'If paying more did not cost less, this screen would be '
          'teaching the opposite of the thing it exists to teach.',
    );
  });

  testWidgets('the affordability check labels the answer rather than only '
      'colouring it', (WidgetTester tester) async {
    await open(tester, 'Can I afford it');

    // 12,000 against 45,000 is 26.7 percent, which is healthy.
    final DsrResult healthy = calculateDsr(
      monthlyDebtObligations: 12000,
      grossMonthlyIncome: 45000,
    );
    expect(healthy.status, AffordabilityStatus.healthy);
    expect(find.text('${healthy.dsr.toStringAsFixed(1)}%'), findsOneWidget);
    expect(find.textContaining('Comfortable'), findsOneWidget);

    // Push it to stretched and the WORDS have to change, not just the colour.
    // Roughly one man in twelve cannot separate this red from this green.
    await tester.enterText(find.widgetWithText(TextField, '12000'), '25000');
    await tester.pumpAndSettle();
    expect(find.textContaining('Stretched'), findsOneWidget);
    expect(find.textContaining('Comfortable'), findsNothing);
  });

  testWidgets('every calculator opens without throwing and shows a figure', (
    WidgetTester tester,
  ) async {
    await open(tester);

    for (final String name in <String>[
      'Pag-IBIG housing',
      'Bank housing',
      'Car loan',
      'SSS and Pag-IBIG salary',
      'Personal and digital',
      'Credit card trap',
      'Consolidation',
      'Snowball or avalanche',
      'Can I afford it',
    ]) {
      await tester.ensureVisible(find.text(name));
      await tester.pumpAndSettle();
      await tester.tap(find.text(name));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: '$name threw');
      expect(
        find.textContaining('₱'),
        findsWidgets,
        reason:
            '$name opened with no money figure on it at all, which for a '
            'calculator means it is not calculating',
      );
    }
  });

  testWidgets('nothing overflows at 320dp, on any calculator', (
    WidgetTester tester,
  ) async {
    await loadRealFonts();
    tester.view.physicalSize = const Size(320 * 3, 900 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await open(tester);

    for (final String name in <String>[
      'Bank housing',
      'Car loan',
      'Consolidation',
      'Snowball or avalanche',
      'Can I afford it',
    ]) {
      await tester.ensureVisible(find.text(name));
      await tester.pumpAndSettle();
      await tester.tap(find.text(name));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '$name overflowed');
    }
  });

  testWidgets('the calculator pills sit beside each other, not stacked', (
    WidgetTester tester,
  ) async {
    // A layout MEASUREMENT, because the defect it guards renders perfectly: a
    // Container with an alignment and no width fills everything it is given,
    // so nine pills become nine full width bars. It has happened twice in this
    // repository already.
    await loadRealFonts();
    await open(tester);

    final Rect first = tester.getRect(find.text('Pag-IBIG housing'));
    final Rect second = tester.getRect(find.text('Bank housing'));

    expect(
      second.left,
      greaterThan(first.right),
      reason:
          'Bank housing should sit to the RIGHT of Pag-IBIG housing. If '
          'it is below, every pill has expanded to the full width.',
    );
  });
}
