// D32, 2026-10-09: a bill the person adds on the Bills screen is held back by
// Safe to Spend.
//
// Before D32 it was held back by nothing. The Bills screen listed it, the
// runway chart dipped for it, Pan said "Bills you add are held back from Safe
// to Spend", and the figure on Home did not move by a centavo. Each screen was
// right about its own register and wrong about the other one, so this journey
// adds a bill the way a person does and then walks to every place that should
// now agree about it.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/format.dart';
import 'package:salapify/core/money/money.dart';
import 'package:salapify/design/settle_figure.dart';
import 'package:salapify/features/bills/bills_sheet.dart';
import 'package:salapify/features/safe_to_spend/safe_to_spend_sheet.dart';
import 'package:salapify/models/models.dart';
import 'package:salapify/screens/home/hero_panel.dart';
import 'package:salapify/screens/home/quick_actions.dart';
import 'package:salapify/state/financial_state.dart';

import '../shots/screens_shot.dart' show loadRealFonts;
import '../support/pinned_app.dart';

void main() {
  Future<void> tapIt(WidgetTester tester, Finder f) async {
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  String digits(Money m) => formatPeso(m.pesos).replaceAll('₱', '');

  testWidgets('a bill added on the Bills screen lowers Safe to Spend, shows '
      'in its breakdown, and removing it gives the money back', (
    WidgetTester tester,
  ) async {
    await tester.runAsync(loadRealFonts);
    tester.view.physicalSize = const Size(1170, 3400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    final FinancialState state = await pumpSalapify(tester);

    final Money before = state.safeToSpend;
    final Money heldBefore = state.safeToSpendAnalysis.reservedBills;
    expect(find.textContaining(digits(before)), findsWidgets);

    // Add it the way a person does: Bills, Schedule a bill, type, Schedule it.
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
      'Sep 25',
    );
    await tester.pumpAndSettle();
    await tapIt(tester, find.text('Schedule it'));

    // 1. The money is right, and something actually happened: the figure
    //    went DOWN and the reserve went UP, not merely "changed".
    final Money after = state.safeToSpend;
    expect(after < before, isTrue, reason: 'the new bill was not held back');
    final Money heldAfter = state.safeToSpendAnalysis.reservedBills;
    expect(
      heldAfter - heldBefore,
      // The example ledger runs the careful scenario, which pads bills by a
      // tenth: 1,699 becomes 1,868.90, shown to the whole peso.
      const Money.pesos(1869),
      reason: 'held back a different amount than the bill',
    );
    expect(
      state.billsHeldBack.where((BillItem b) => b.name == 'PLDT Fibr'),
      hasLength(1),
    );

    // 2. A person can SEE it. Home shows the new figure, not the old one.
    Navigator.of(tester.element(find.byType(BillsSheet))).pop();
    await tester.pumpAndSettle();
    // Back to the top: reaching the Bills shortcut scrolled the hero away,
    // and Home is a lazy list, so it is not even built down there.
    await tester.scrollUntilVisible(
      find.byKey(heroFigureKey),
      -300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    // READ FROM THE FIGURE WIDGET, not by text: a figure that changed rolls
    // digit by digit, so "22,519.00" is a row of single characters on
    // screen and only the widget (and its screen reader label) holds it whole.
    final Iterable<String> shown = tester
        .widgetList<SettleFigure>(find.byType(SettleFigure))
        .map((SettleFigure f) => f.text);
    expect(shown.any((String t) => t.contains(digits(after))), isTrue);
    expect(shown.any((String t) => t.contains(digits(before))), isFalse);

    // The breakdown behind the figure names the larger reserve.
    await tapIt(tester, find.byKey(heroFigureKey));
    expect(find.byType(SafeToSpendSheet), findsOneWidget);
    expect(find.text(formatPeso(heldAfter.pesos)), findsWidgets);
    Navigator.of(tester.element(find.byType(SafeToSpendSheet))).pop();
    await tester.pumpAndSettle();

    // 3. The way back. Removing the bill returns exactly the money it held.
    final UpcomingItem added = state.upcoming.firstWhere(
      (UpcomingItem u) => u.name == 'PLDT Fibr',
    );
    await tapIt(
      tester,
      find.descendant(
        of: find.byType(QuickActions),
        matching: find.text('Bills'),
      ),
    );
    await tapIt(
      tester,
      find.descendant(
        of: find.byKey(ValueKey<String>('bill_${added.id}')),
        matching: find.text('Remove'),
      ),
    );
    await tapIt(
      tester,
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Remove'),
      ),
    );
    expect(state.upcoming.any((UpcomingItem u) => u.id == added.id), isFalse);
    expect(state.safeToSpend, before);
  });

  testWidgets('a bill due after payday waits, and a paid one is let go', (
    WidgetTester tester,
  ) async {
    final FinancialState state = await pumpSalapify(tester);
    final Money before = state.safeToSpend;

    // Payday in the example is the 30th, twelve days out.
    state.addUpcoming(
      const UpcomingItem(
        id: 'up_october',
        name: 'Car registration',
        amount: Money.pesos(4000),
        dueDate: '2026-10-20',
        type: UpcomingItemType.government,
      ),
    );
    expect(state.safeToSpend, before, reason: 'next cycle was held back now');

    state.addUpcoming(
      const UpcomingItem(
        id: 'up_soon',
        name: 'Barangay clearance',
        amount: Money.pesos(4000),
        dueDate: '2026-09-22',
        type: UpcomingItemType.government,
      ),
    );
    final Money held = state.safeToSpend;
    expect(held < before, isTrue, reason: 'a bill due Tuesday was not held');

    // Ticked off with no account, which moves no money: the hold lifts.
    state.markUpcomingPaid('up_soon');
    expect(state.safeToSpend, before);
  });
}
