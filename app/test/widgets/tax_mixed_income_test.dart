import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/format.dart';
import 'package:salapify/core/money/ph_tax.dart';
import 'package:salapify/design/tokens.dart';
import 'package:salapify/features/tax/tax_calculator_sheet.dart';
import 'package:salapify/shell/app_shell.dart';
import 'package:salapify/state/financial_state.dart';

import '../support/pinned_app.dart';

/// P1.4: the tax sheet asks whether you also have a salary, and whether you
/// are registered for VAT.
///
/// ## The defect
///
/// Money copy error 1 in the October expert review, confirmed in code:
/// `calculateFreelanceTax` was called with NEITHER `compensationIncome` nor
/// `vatRegistered`. The engine has always handled both. It was the sheet that
/// never asked, so every person using it was treated as a pure freelancer who
/// had never registered for VAT.
///
/// Both defaults are the expensive ones to be wrong about:
///
/// - `compensationIncome: 0` hands the 250,000 zero-rated allowance on the 8%
///   route to somebody with a salary, who is not entitled to it. The review
///   sizes that at 20,000 a year understated, and the 8% election cannot be
///   undone for twelve months.
/// - `vatRegistered: false` offers the 8% option to somebody who may not elect
///   it at all, at any income.
///
/// ## Engine first, then screen
///
/// The first group pins the arithmetic, so the figures below are stated rather
/// than implied by a widget. The second proves the SHEET passes what it asks
/// for, which is the half that was actually broken: the engine was right the
/// whole time.
void main() {
  group('the engine, so the numbers in this file are not folklore', () {
    test('a pure freelancer keeps the 250,000 allowance', () {
      final FreelanceTaxCalculation c = calculateFreelanceTax(
        annualGrossIncome: 1000000,
      );
      expect(c.taxFreeAllowance, 250000);
      expect(c.taxableBase, 750000);
      expect(c.estimatedTaxDue, closeTo(60000, 0.01));
    });

    test('an employee with a sideline does NOT', () {
      final FreelanceTaxCalculation c = calculateFreelanceTax(
        annualGrossIncome: 1000000,
        compensationIncome: 600000,
      );
      expect(
        c.taxFreeAllowance,
        0,
        reason: 'mixed income gets no zero-rated band on the 8% route',
      );
      expect(c.taxableBase, 1000000);
      expect(
        c.estimatedTaxDue,
        closeTo(80000, 0.01),
        reason:
            '20,000 a year more than the pure freelancer, which is '
            'exactly the gap the review measured',
      );
    });

    test('a VAT registered taxpayer cannot elect the 8% at all', () {
      final FreelanceTaxCalculation c = calculateFreelanceTax(
        annualGrossIncome: 500000,
        taxOption: FreelanceTaxOption.graduatedRates,
        vatRegistered: true,
      );
      expect(c.eightPercentAvailable, isFalse);
      expect(c.unavailableReason, contains('VAT'));
    });
  });

  group('the sheet passes what it asks for', () {
    Future<void> openFreelance(WidgetTester tester) async {
      final FinancialState state = await pumpSalapify(tester);
      // AppShell, not MaterialApp. A MaterialApp's own element sits ABOVE
      // the Localizations it provides, so showing a dialog from it throws
      // "No MaterialLocalizations found".
      TaxCalculatorSheet.show(
        tester.element(find.byType(AppShell)),
        Palette.of(state.theme),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Freelance'));
      await tester.pumpAndSettle();
    }

    Future<void> type(WidgetTester tester, String label, String value) async {
      await tester.enterText(
        find.descendant(
          of: find
              .ancestor(of: find.text(label), matching: find.byType(Column))
              .first,
          matching: find.byType(TextField),
        ),
        value,
      );
      await tester.pumpAndSettle();
    }

    testWidgets('a salary typed in removes the 250,000 allowance', (
      WidgetTester tester,
    ) async {
      // The whole point of the task. Before this, there was nowhere on the
      // screen to say you have a job, so the answer was always "no".
      await openFreelance(tester);

      expect(
        find.textContaining('Salary from a job'),
        findsOneWidget,
        reason: 'the sheet still cannot be told about mixed income',
      );

      // ON THE PESO FIGURES, not on the copy beside them. The first version
      // of this test asserted the words "Mixed income" appeared, and dropping
      // the two parameters from the engine call PASSED it: that caption is
      // driven by the widget reading its own text field, so it was right
      // while the tax underneath it was wrong. That is the exact hollow shape
      // this repository keeps catching, and only the deliberate break found
      // it.
      //
      // Gross is 1,200,000 by default.
      //   no salary: allowance 250,000, tax (1,200,000 - 250,000) x 8% = 76,000
      //   600,000 salary: allowance 0, tax 1,200,000 x 8% = 96,000
      expect(find.text(formatPeso(250000)), findsWidgets);
      expect(find.text(formatPeso(76000)), findsWidgets);

      await type(tester, 'Salary from a job, if you also have one', '600000');

      expect(
        find.text(formatPeso(0)),
        findsWidgets,
        reason: 'the 250,000 allowance survived a salary being declared',
      );
      expect(
        find.text(formatPeso(96000)),
        findsWidgets,
        reason: 'the tax did not rise by the 20,000 the review measured',
      );
      expect(
        find.text(formatPeso(76000)),
        findsNothing,
        reason: 'it is still charging the pure freelancer figure',
      );
      expect(find.textContaining('Mixed income'), findsOneWidget);
    });

    testWidgets('left at zero, a pure freelancer sees no mixed income note', (
      WidgetTester tester,
    ) async {
      // The silent half. A note that always shows teaches people to ignore it.
      await openFreelance(tester);
      expect(find.textContaining('Mixed income'), findsNothing);
      expect(find.textContaining('only income'), findsOneWidget);
    });

    testWidgets('ticking VAT registered closes the 8% option on screen', (
      WidgetTester tester,
    ) async {
      await openFreelance(tester);
      expect(find.textContaining('not open to you'), findsNothing);

      await tester.tap(find.text('I am registered for VAT'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('not open to you'),
        findsOneWidget,
        reason: 'the sheet offered an election the taxpayer may not make',
      );
    });
  });
}
