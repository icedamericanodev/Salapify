// Entering what a debt costs each month, and what it does to Safe to Spend.
//
// Both halves, per CLAUDE.md. Half one is whether the money behaves: the
// reservation moves by exactly what was typed. Half two is whether a person
// can SEE it, which here means the Safe to Spend sheet's own working, because
// that screen prints the reservation as a line item and used to print a guess.
//
// The invariant is "typing nothing changes nothing", which is unfalsifiable by
// inaction: it passes perfectly if the whole feature is missing. So every one
// of those is paired with a DIRECTIONAL assertion naming the figure that had
// to move when something WAS typed.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/money.dart';
import 'package:salapify/features/debt/add_debt_sheet.dart';
import 'package:salapify/models/models.dart';
import 'package:salapify/state/financial_state.dart';

import '../shots/screens_shot.dart' show loadRealFonts;
import '../support/pinned_app.dart';

void main() {
  Future<FinancialState> pumpApp(WidgetTester tester) async {
    await tester.runAsync(loadRealFonts);
    tester.view.physicalSize = const Size(1170, 3400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    return pumpSalapify(tester);
  }

  Future<void> tapIt(WidgetTester tester, Finder f) async {
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  Future<void> openAddDebt(WidgetTester tester) async {
    // The Debt shortcut opens the LIST (D31); adding is one tap from there.
    await tapIt(tester, find.text('Debt'));
    await tapIt(tester, find.byKey(const Key('debt-add')));
    expect(find.byType(AddDebtSheet), findsOneWidget);
    // The money question (D31) is answered "no money moved", because these
    // tests are about the minimum and must not move an account balance.
    await tapIt(tester, find.byKey(const Key('debt-money')));
    await tapIt(tester, find.text('No money moved now').last);
  }

  group('the field appears only where the answer does something', () {
    testWidgets('money you OWE, paid flexibly, is asked', (
      WidgetTester tester,
    ) async {
      await pumpApp(tester);
      await openAddDebt(tester);

      expect(find.byKey(const Key('debt-minimum')), findsOneWidget);
      expect(
        find.textContaining('Leave it empty for money you owe family'),
        findsOneWidget,
        reason:
            'without this line somebody types a number for utang to their '
            'mother, which is the obligation this whole change removed',
      );
    });

    testWidgets('an INSTALMENT debt is not asked, because the months already '
        'answer it', (WidgetTester tester) async {
      await pumpApp(tester);
      await openAddDebt(tester);

      await tapIt(tester, find.text('Installments'));

      expect(
        find.byKey(const Key('debt-minimum')),
        findsNothing,
        reason:
            'Debt.monthlyMinimum already divides what is left by the '
            'instalments left, so asking again invites two answers that '
            'disagree',
      );
    });

    testWidgets('money owed TO you is not asked at all', (
      WidgetTester tester,
    ) async {
      await pumpApp(tester);
      await openAddDebt(tester);

      await tapIt(tester, find.text('They owe me'));

      expect(
        find.byKey(const Key('debt-minimum')),
        findsNothing,
        reason: 'a debt owed to you is not money you have to find every month',
      );
    });
  });

  group('what it does to the money', () {
    testWidgets('a typed minimum reserves exactly that, and Safe to Spend '
        'falls by it', (WidgetTester tester) async {
      final FinancialState s = await pumpApp(tester);
      final Money reservedBefore = s.safeToSpendAnalysis.reservedDebtMinimums;
      final Money spendBefore = s.safeToSpendAnalysis.safeToSpendUntilPayday;

      await openAddDebt(tester);
      await tester.enterText(find.byType(TextField).first, 'BPI Card');
      await tester.enterText(find.byType(TextField).at(1), '18000');
      await tester.enterText(find.byKey(const Key('debt-minimum')), '1500');
      await tester.pumpAndSettle();
      await tapIt(tester, find.text('Save debt'));

      // DIRECTIONAL, and by the exact amount, so this cannot pass on a
      // feature that reserves something arbitrary.
      expect(
        s.safeToSpendAnalysis.reservedDebtMinimums - reservedBefore,
        const Money.pesos(1500),
        reason: 'the typed minimum did not reach the engine',
      );
      expect(
        s.safeToSpendAnalysis.safeToSpendUntilPayday,
        lessThan(spendBefore),
        reason: 'reserving more money left the same amount free to spend',
      );

      // And it is stored, not just held in memory.
      final Debt saved = s.debts.firstWhere((Debt d) => d.person == 'BPI Card');
      expect(saved.minimumPayment, const Money.pesos(1500));
      expect(saved.monthlyMinimum, const Money.pesos(1500));
    });

    testWidgets('family utang reserves NOTHING, which is the decision', (
      WidgetTester tester,
    ) async {
      final FinancialState s = await pumpApp(tester);
      final Money reservedBefore = s.safeToSpendAnalysis.reservedDebtMinimums;
      final Money spendBefore = s.safeToSpendAnalysis.safeToSpendUntilPayday;

      await openAddDebt(tester);
      await tester.enterText(find.byType(TextField).first, 'Nanay');
      await tester.enterText(find.byType(TextField).at(1), '20000');
      // The minimum box is left EMPTY on purpose. That is the whole case.
      await tester.pumpAndSettle();
      await tapIt(tester, find.text('Save debt'));

      // The did-anything-happen half, FIRST, because the invariant below
      // passes perfectly if the debt was never saved.
      final Debt saved = s.debts.firstWhere((Debt d) => d.person == 'Nanay');
      expect(saved.remaining, const Money.pesos(20000));
      expect(saved.minimumPayment, isNull);

      // THE INVARIANT. Under the old rule this debt alone would have held
      // back 1,600 a cycle, for an obligation that does not exist.
      expect(
        s.safeToSpendAnalysis.reservedDebtMinimums,
        reservedBefore,
        reason:
            'utang to a relative has no monthly minimum, and reserving '
            'against it invents an obligation the person never agreed to',
      );
      expect(s.safeToSpendAnalysis.safeToSpendUntilPayday, spendBefore);
    });
  });

  testWidgets('and the Safe to Spend sheet shows the real figure in its '
      'working', (WidgetTester tester) async {
    // Half two. The sheet prints this reservation as a line item, so a person
    // checking the app's arithmetic reads it there. It used to print a guess.
    final FinancialState s = await pumpApp(tester);
    expect(
      s.safeToSpendAnalysis.reservedDebtMinimums,
      const Money.pesos(4950),
      reason:
          'the seed two loans really cost 4,950 a month, against 1,388 for '
          'the old eight percent of their balance',
    );

    await tapIt(tester, find.byIcon(Icons.info_outline).first);
    await tapIt(tester, find.text('Audit & Math'));

    for (int i = 0; i < 12; i++) {
      if (find.textContaining('4,950').evaluate().isNotEmpty) break;
      await tester.drag(
        find.byType(Scrollable).last,
        const Offset(0, -300),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();
    }

    expect(
      find.textContaining('4,950'),
      findsWidgets,
      reason:
          'the sheet shows its own working, so the figure it prints has to be '
          'the one the engine used',
    );
  });

  group('a figure the app cannot read is never saved as nothing', () {
    testWidgets('an unreadable minimum blocks Save and says why', (
      WidgetTester tester,
    ) async {
      final FinancialState s = await pumpApp(tester);
      await openAddDebt(tester);

      await tester.enterText(find.byType(TextField).first, 'BPI Card');
      await tester.enterText(find.byType(TextField).at(1), '18000');
      await tester.enterText(find.byKey(const Key('debt-minimum')), '1.5.0');
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('debt-minimum-problem')),
        findsOneWidget,
        reason:
            'this used to save as NO minimum, with no error, under a caption '
            'promising Salapify would hold nothing back. The person believes '
            'they entered a figure and Salapify reserves zero, forever',
      );

      await tapIt(tester, find.text('Save debt'));
      expect(
        s.debts.where((Debt d) => d.person == 'BPI Card'),
        isEmpty,
        reason: 'Save must be refused while the box holds something unreadable',
      );

      // DIRECTIONAL companion, because "nothing was saved" also passes when
      // the whole sheet is broken: writing the same figure in a shape the
      // app can read clears the message and saves, with the minimum on it.
      await tester.enterText(find.byKey(const Key('debt-minimum')), '150');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('debt-minimum-problem')), findsNothing);
      await tapIt(tester, find.text('Save debt'));
      expect(
        s.debts.firstWhere((Debt d) => d.person == 'BPI Card').minimumPayment,
        const Money.pesos(150),
      );
    });

    testWidgets('the money keypad cannot type a figure that throws', (
      WidgetTester tester,
    ) async {
      await pumpApp(tester);
      await openAddDebt(tester);

      // Fourteen nines is one slip of a thumb, and Money.fromDouble throws
      // above about ninety trillion pesos. The throw escaped the Save
      // button's onTap, so the sheet stayed open with no message at all and
      // tapping Save again did nothing, forever.
      await tester.enterText(
        find.byKey(const Key('debt-minimum')),
        '99999999999999',
      );
      await tester.pumpAndSettle();

      final TextField box = tester.widget<TextField>(
        find.descendant(
          of: find.byKey(const Key('debt-minimum')),
          matching: find.byType(TextField),
        ),
      );
      expect(
        box.controller!.text,
        '9999999999999',
        reason:
            'the length cap is what keeps the figure inside what a double '
            'can still count in centavos',
      );
    });

    testWidgets('a minus sign cannot be typed into a money box', (
      WidgetTester tester,
    ) async {
      await pumpApp(tester);
      await openAddDebt(tester);

      await tester.enterText(find.byKey(const Key('debt-minimum')), '-5000');
      await tester.pumpAndSettle();

      final TextField box = tester.widget<TextField>(
        find.descendant(
          of: find.byKey(const Key('debt-minimum')),
          matching: find.byType(TextField),
        ),
      );
      expect(
        box.controller!.text,
        '5000',
        reason:
            'a negative minimum netted off every OTHER debt real minimum, '
            'because the total is summed and only the total is clamped',
      );
    });
  });
}
