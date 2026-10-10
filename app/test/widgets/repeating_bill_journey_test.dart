// A monthly bill, the way a person uses one (D31, 2026-10-10).
//
// Schedule it with "Repeats every month", pay it, and see it come back on
// next month's date on the same row, still in Due, with the money gone from
// the account and the payment in Activity. Then Undo, and see the money and
// the date both come back.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/money.dart';
import 'package:salapify/features/bills/bills_sheet.dart';
import 'package:salapify/models/models.dart';
import 'package:salapify/screens/home/quick_actions.dart';
import 'package:salapify/state/financial_state.dart';

import '../shots/screens_shot.dart' show loadRealFonts;
import '../support/pinned_app.dart';

void main() {
  Future<void> tapIt(WidgetTester tester, Finder f) async {
    await tester.ensureVisible(f.first);
    await tester.pumpAndSettle();
    await tester.tap(f.first);
    await tester.pumpAndSettle();
  }

  Finder inDialog(Finder f) =>
      find.descendant(of: find.byType(AlertDialog), matching: f);

  testWidgets('pay a monthly bill, it moves to next month; undo, it comes '
      'back with the money', (WidgetTester tester) async {
    await tester.runAsync(loadRealFonts);
    tester.view.physicalSize = const Size(1170, 4000);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    final FinancialState state = await pumpSalapify(tester);

    final Account cashAcc = state.accounts.firstWhere(
      (Account a) => a.id == 'acc_cash',
    );
    final Money before = cashAcc.balance;

    await tapIt(
      tester,
      find.descendant(
        of: find.byType(QuickActions),
        matching: find.text('Bills'),
      ),
    );
    await tapIt(tester, find.text('Schedule a bill'));
    await tester.enterText(
      find.widgetWithText(
        TextField,
        'Converge Fibre, Netflix, the barangay fee',
      ),
      'PLDT Fibr',
    );
    await tester.enterText(find.widgetWithText(TextField, '0.00'), '1699');
    await tester.enterText(
      find.widgetWithText(TextField, 'Sep 25, or the 10th'),
      'the 25th',
    );
    await tester.pumpAndSettle();
    await tapIt(tester, find.byKey(const Key('bill-monthly')));
    await tapIt(tester, find.text('Schedule it'));

    final UpcomingItem pldt = state.upcoming.firstWhere(
      (UpcomingItem u) => u.name == 'PLDT Fibr',
    );
    expect(pldt.repeatDay, 25);
    expect(pldt.dueDate, '2026-09-25');
    final Finder row = find.byKey(ValueKey<String>('bill_${pldt.id}'));
    expect(
      find.descendant(of: row, matching: find.textContaining('Every month')),
      findsOneWidget,
    );

    // Pay it from Cash.
    await tapIt(
      tester,
      find.descendant(of: row, matching: find.text('Mark paid')),
    );
    await tapIt(
      tester,
      inDialog(find.byType(DropdownButtonFormField<String>)).first,
    );
    await tester.tap(find.textContaining(cashAcc.name).last);
    await tester.pumpAndSettle();
    await tapIt(tester, inDialog(find.text('Mark it paid')));

    // The money left, and the SAME row is back in Due on Oct 25.
    expect(
      state.accounts.firstWhere((Account a) => a.id == 'acc_cash').balance,
      before - const Money.pesos(1699),
    );
    final UpcomingItem after = state.upcoming.firstWhere(
      (UpcomingItem u) => u.id == pldt.id,
    );
    expect(after.isPaid, isFalse);
    expect(after.dueDate, '2026-10-25');
    expect(
      find.descendant(of: row, matching: find.textContaining('Oct 25')),
      findsOneWidget,
      reason: 'the row does not show the next date',
    );

    // Undo, on the row itself.
    await tapIt(
      tester,
      find.descendant(of: row, matching: find.text('Undo last payment')),
    );
    expect(
      state.accounts.firstWhere((Account a) => a.id == 'acc_cash').balance,
      before,
    );
    expect(
      state.upcoming.firstWhere((UpcomingItem u) => u.id == pldt.id).dueDate,
      '2026-09-25',
    );
    expect(
      find.descendant(of: row, matching: find.text('Undo last payment')),
      findsNothing,
    );
    expect(find.byType(BillsSheet), findsOneWidget);
  });
}
