// Every box a person types money into offers back exactly what was stored.
//
// THE DEFECT THIS CLOSES, found by the founder on the emulator on 2026-10-03
// and not by any of the 1,678 tests that passed that morning. They typed a
// budget limit of 3,500.55, saved, reopened the sheet, and the box read 3501.
// The stored money was never wrong. The box pre-filled itself with
// `limit.pesos.toStringAsFixed(0)`, so tapping Save without typing anything
// would have written 3501 over the real figure.
//
// WHY NOTHING CAUGHT IT. The suite had tests for the store, tests for the
// arithmetic, and tests that typed into a sheet and saved. Not one of them
// REOPENED a sheet to read what the box offers back. The write path was
// covered from both ends and the gap was in the middle.
//
// So this file is about the class rather than the instance: one round trip
// per money input in the app, each storing a figure with centavos and
// asserting the box offers it back whole. A new sheet gets a row here, or
// the structural guard below reddens instead.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/money.dart';
import 'package:salapify/core/money/plan.dart';
import 'package:salapify/features/accounts/account_sheet.dart';
import 'package:salapify/features/debt/payment_sheet.dart';
import 'package:salapify/features/payday/payday_sheet.dart';
import 'package:salapify/design/tokens.dart';
import 'package:salapify/models/models.dart';
import 'package:salapify/screens/plan/budget_sheets.dart';
import 'package:salapify/state/financial_state.dart';

import '../support/pinned_app.dart';

void main() {
  /// A figure with centavos that cannot be reached by rounding either way.
  ///
  /// .55 on purpose rather than .50, which rounds up, or .01, which a reader
  /// might believe got lost to a float. Anything that renders as a whole
  /// peso here is the defect.
  const Money withCentavos = Money.of(3500, 55);

  /// The sheet, open, with the app behind it. Returns the live store.
  Future<FinancialState> openOn(
    WidgetTester tester,
    void Function(BuildContext context, FinancialState state) show, {
    void Function(FinancialState state)? arrange,
  }) async {
    final FinancialState state = await pumpSalapify(tester);
    arrange?.call(state);
    await tester.pumpAndSettle();

    show(tester.element(find.byType(Navigator).first), state);
    await tester.pumpAndSettle();
    return state;
  }

  /// Fails with the figure the box ACTUALLY offers, not just "not found".
  ///
  /// `findsOneWidget` on the wanted string says nothing about what is there
  /// instead, and "3501" is the single most useful fact in the failure.
  void boxOffers(String wanted, {required String where}) {
    final Iterable<TextField> fields = find
        .byType(TextField)
        .evaluate()
        .map((Element e) => e.widget as TextField);
    final List<String> actual = <String>[
      for (final TextField f in fields)
        if ((f.controller?.text ?? '').isNotEmpty) f.controller!.text,
    ];
    expect(
      actual,
      contains(wanted),
      reason:
          '$where offered back $actual instead of "$wanted". Saving that box '
          'without typing anything would write the rounded figure over the '
          'real one.',
    );
  }

  _structuralGuard();

  group('a stored figure with centavos comes back whole', () {
    testWidgets('the budget limit box', (WidgetTester tester) async {
      late BudgetStatus row;
      await openOn(
        tester,
        (BuildContext c, FinancialState s) =>
            EditBudgetSheet.show(c, s, row = _budgetRow(s)),
        arrange: (FinancialState s) =>
            s.setBudgetLimit('Food & Dining', withCentavos),
      );

      expect(
        row.limit,
        withCentavos,
        reason: 'the fixture never stored the centavos, so this proves nothing',
      );
      boxOffers('3500.55', where: 'the budget limit box');
    });

    testWidgets('the payday expected income box', (WidgetTester tester) async {
      final FinancialState state = await openOn(
        tester,
        PaydaySheet.show,
        arrange: (FinancialState s) => s.setPaydayRule(
          daysOfMonth: <int>[15, 30],
          expectedIncome: withCentavos,
        ),
      );

      expect(
        state.payday.expectedIncome,
        withCentavos,
        reason: 'the fixture never stored the centavos, so this proves nothing',
      );
      boxOffers('3500.55', where: 'the payday expected income box');
    });

    testWidgets('the account balance box', (WidgetTester tester) async {
      await openOn(tester, (BuildContext c, FinancialState s) {
        final Account a = s.accounts.first;
        AccountSheet.show(
          c,
          palette: Palette.of(s.theme),
          state: s,
          existing: Account(
            id: a.id,
            name: a.name,
            kind: a.kind,
            institution: a.institution,
            balance: withCentavos,
            monogram: a.monogram,
          ),
        );
      });

      boxOffers('3500.55', where: 'the account balance box');
    });

    testWidgets('the credit limit box', (WidgetTester tester) async {
      await openOn(tester, (BuildContext c, FinancialState s) {
        final Account card = s.accounts.firstWhere(
          (Account a) => a.kind == AccountKind.credit,
        );
        AccountSheet.show(
          c,
          palette: Palette.of(s.theme),
          state: s,
          existing: Account(
            id: card.id,
            name: card.name,
            kind: card.kind,
            institution: card.institution,
            balance: card.balance,
            monogram: card.monogram,
            creditLimit: withCentavos,
          ),
        );
      });

      boxOffers('3500.55', where: 'the credit limit box');
    });

    testWidgets('the debt payment box', (WidgetTester tester) async {
      // This one pre-fills with what is LEFT on the debt rather than with a
      // figure somebody typed, which makes it the same risk wearing a
      // different hat: the suggestion is the whole balance, and a rounded
      // suggestion pays the wrong amount by default.
      await openOn(tester, (BuildContext c, FinancialState s) {
        final Debt d = s.debts.first;
        PaymentSheet.show(
          c,
          palette: Palette.of(s.theme),
          state: s,
          debt: Debt(
            id: d.id,
            person: d.person,
            direction: d.direction,
            totalAmount: withCentavos,
            paidAmount: Money.zero,
            isSettled: false,
            dueDate: d.dueDate,
          ),
        );
      });

      boxOffers('3500.55', where: 'the debt payment box');
    });
  });
}

/// The round trips above cover the money inputs that exist TODAY. This covers
/// the one somebody adds next year.
///
/// A behavioural test only guards what a human thought to list. The defect
/// was a single unguarded `toStringAsFixed(0)` sitting beside three correct
/// copies of the same rule, so the shape itself is what has to redden.
void _structuralGuard() {
  test('no money box rounds a stored figure to whole pesos', () {
    // Files where rounding to whole pesos is CORRECT, each with the reason.
    // Adding to this list is allowed and is meant to be a deliberate act.
    const Map<String, String> allowed = <String, String>{
      // The preset chips, which hold whole pesos by construction
      // (`bonusQuickAmounts`). The box is never pre-filled from a stored
      // figure here, only from a chip somebody tapped.
      'lib/screens/plan/bonus_allocator_card.dart':
          'quick-amount chips, whole pesos by construction, never a stored '
          'figure',
      // A percentage, not money. "8%" rather than "8.00%".
      'lib/screens/reports/bir_claims_card.dart': 'a tax rate, not an amount',
    };

    // What makes a rounding SAFE: it is inside a test for whether the figure
    // has centavos at all.
    const List<String> wholenessTests = <String>[
      'roundToDouble',
      'isWholePesos',
      '% 100',
    ];

    final List<String> offenders = <String>[];
    for (final FileSystemEntity f in Directory(
      'lib',
    ).listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final String rel = f.path;
      if (allowed.keys.any((String a) => rel.endsWith(a.substring(4)))) {
        continue;
      }

      // COMMENTS STRIPPED. This file's own comments name the banned shape,
      // and a guard its own explanation can satisfy is not a guard.
      final List<String> lines = f
          .readAsLinesSync()
          .map((String l) => l.trimLeft().startsWith('//') ? '' : l)
          .toList();

      for (int i = 0; i < lines.length; i++) {
        if (!lines[i].contains('toStringAsFixed(0)')) continue;
        // The statement can wrap, so look back two lines for the test.
        final String window = lines
            .sublist(i < 2 ? 0 : i - 2, i + 1)
            .join('\n');
        if (wholenessTests.any(window.contains)) continue;
        offenders.add('$rel:${i + 1}');
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'These round a figure to whole pesos with nothing asking whether it '
          'HAS centavos. In a box somebody types into that is how 3,500.55 '
          'becomes 3501 and then gets saved over the real figure, which is '
          'exactly what reached the founder on 2026-10-03. Use Money.plain, '
          'or add the file to `allowed` above with the reason it is not an '
          'amount.',
    );
  });
}

/// The Food and Dining row, read back through the engine the sheet uses.
BudgetStatus _budgetRow(FinancialState s) => computeBudgets(
  budgets: s.budgets,
  transactions: s.transactions,
  now: testToday,
).firstWhere((BudgetStatus b) => b.category == 'Food & Dining');
