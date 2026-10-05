// Bills, in BOTH halves.
//
// `test/data/bill_payment_test.dart` is half one: did the money move, and in
// the right direction. This is half two: can a person FOLLOW it afterwards.
//
// Half two is the half that matters most here, because of what ticking a bill
// used to do. It flipped a flag and nothing else, so somebody could mark
// Meralco paid, open the account, and find the balance untouched with nothing
// in Activity to explain anything. Every test was green the whole time,
// because every test asked whether the flag flipped.

import '../support/net_worth.dart';
import 'package:salapify/core/money/money.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/features/bills/bills_sheet.dart';
import 'package:salapify/models/models.dart';
import 'package:salapify/screens/home/coming_up_card.dart';
import 'package:salapify/screens/home/quick_actions.dart';
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

  Money balanceOf(FinancialState s, String id) =>
      s.accounts.firstWhere((Account a) => a.id == id).balance;

  Future<void> openBills(WidgetTester tester) async {
    await tapIt(
      tester,
      find.descendant(
        of: find.byType(QuickActions),
        matching: find.text('Bills'),
      ),
    );
  }

  /// A control inside whichever dialog is open.
  ///
  /// SCOPED, because a bare find.text('Cancel') threw "Bad state: Too many
  /// elements": the sheet behind the dialog carries its own buttons, and
  /// tester.tap takes the single match or nothing. Scoping is also what keeps
  /// these tests honest about which surface they are driving.
  Finder inDialog(Finder f) =>
      find.descendant(of: find.byType(AlertDialog), matching: f);

  /// One bill row, by the id the sheet keys it with.
  ///
  /// BY KEY, because the row actions are WORDS now and a bare find.text('Mark
  /// paid') matches every unpaid bill on the screen, while
  /// bySemanticsLabel matches none: each action wraps a Text whose own
  /// semantics merge upward and replace the explicit label. The key is the
  /// only handle that names one row and keeps naming it when the layout
  /// changes again.
  Finder billRow(String id) => find.byKey(ValueKey<String>('bill_$id'));

  Finder payTick(String id) =>
      find.descendant(of: billRow(id), matching: find.text('Mark paid'));

  Finder removeTick(String id) =>
      find.descendant(of: billRow(id), matching: find.text('Remove'));

  Finder undoTick(String id) =>
      find.descendant(of: billRow(id), matching: find.text('Undo'));

  /// Works the pay dialog through to the end, picking an account.
  Future<void> payWith(WidgetTester tester, String accountName) async {
    await tapIt(
      tester,
      inDialog(find.byType(DropdownButtonFormField<String>)).first,
    );
    await tester.tap(find.textContaining(accountName).last);
    await tester.pumpAndSettle();
    await tapIt(tester, inDialog(find.text('Mark it paid')));
  }

  testWidgets('the Bills shortcut opens the sheet from Home', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    final Finder door = find.descendant(
      of: find.byType(QuickActions),
      matching: find.text('Bills'),
    );
    expect(door, findsOneWidget, reason: 'the Bills shortcut is not on Home');

    await openBills(tester);
    expect(find.byType(BillsSheet), findsOneWidget);
    // It used to say "Bills is not migrated yet".
    expect(find.textContaining('not migrated'), findsNothing);
  });

  group('paying a bill', () {
    testWidgets('the money leaves the account the person picked', (
      WidgetTester tester,
    ) async {
      final FinancialState state = await pumpApp(tester);
      final UpcomingItem meralco = state.upcoming.firstWhere(
        (UpcomingItem u) => u.name.contains('Meralco'),
      );
      final Money gcashBefore = balanceOf(state, 'acc_gcash');
      final Money worthBefore = netWorthOf(state);

      await openBills(tester);
      await tapIt(tester, payTick(meralco.id));
      await payWith(tester, 'GCash');

      expect(
        balanceOf(state, 'acc_gcash'),
        gcashBefore - meralco.amount,
        reason: 'the chosen account did not fall by the bill',
      );
      expect(netWorthOf(state), worthBefore - meralco.amount);
    });

    testWidgets('cancelling the dialog pays nothing', (
      WidgetTester tester,
    ) async {
      // The alarm has to stay silent too. A pay dialog that charges on cancel
      // is the worst possible version of this feature.
      final FinancialState state = await pumpApp(tester);
      final UpcomingItem meralco = state.upcoming.firstWhere(
        (UpcomingItem u) => u.name.contains('Meralco'),
      );
      final Money worthBefore = netWorthOf(state);
      final int rowsBefore = state.transactions.length;

      await openBills(tester);
      await tapIt(tester, payTick(meralco.id));
      await tapIt(tester, inDialog(find.text('Cancel')));

      expect(netWorthOf(state), worthBefore);
      expect(state.transactions.length, rowsBefore);
      expect(
        state.upcoming
            .firstWhere((UpcomingItem u) => u.id == meralco.id)
            .isPaid,
        isFalse,
        reason: 'cancelling still ticked it off',
      );
    });

    testWidgets('no account picked means the button will not fire', (
      WidgetTester tester,
    ) async {
      // The prototype falls back to accounts[0] and says nothing, writing a
      // real expense against whichever account happens to be first.
      final FinancialState state = await pumpApp(tester);
      final UpcomingItem meralco = state.upcoming.firstWhere(
        (UpcomingItem u) => u.name.contains('Meralco'),
      );
      final int rowsBefore = state.transactions.length;

      await openBills(tester);
      await tapIt(tester, payTick(meralco.id));
      await tapIt(tester, inDialog(find.text('Mark it paid')));

      expect(
        state.transactions.length,
        rowsBefore,
        reason: 'it charged an account nobody chose',
      );
    });
  });

  group('a person can FOLLOW it afterwards', () {
    testWidgets('the payment is on Activity, under the bill name', (
      WidgetTester tester,
    ) async {
      final FinancialState state = await pumpApp(tester);
      final UpcomingItem meralco = state.upcoming.firstWhere(
        (UpcomingItem u) => u.name.contains('Meralco'),
      );

      await openBills(tester);
      await tapIt(tester, payTick(meralco.id));
      await payWith(tester, 'GCash');

      // Close the sheet and walk to the screen an auditor opens.
      await tapIt(tester, find.byIcon(Icons.close).first);
      await tapIt(tester, find.byIcon(Icons.menu_book_outlined).last);

      expect(
        find.text(meralco.name),
        findsWidgets,
        reason:
            'the balance moved and nothing on Activity explains why, which '
            'is the exact defect this whole file exists to catch',
      );
    });

    testWidgets('the bill moves to Settled and cannot be paid twice', (
      WidgetTester tester,
    ) async {
      final FinancialState state = await pumpApp(tester);
      final UpcomingItem meralco = state.upcoming.firstWhere(
        (UpcomingItem u) => u.name.contains('Meralco'),
      );

      await openBills(tester);
      await tapIt(tester, payTick(meralco.id));
      await payWith(tester, 'GCash');

      expect(find.text('Settled'), findsOneWidget);
      expect(
        payTick(meralco.id),
        findsNothing,
        reason: 'a settled bill still offers its pay button',
      );
    });

    testWidgets('Undo on the confirmation gives the money back', (
      WidgetTester tester,
    ) async {
      final FinancialState state = await pumpApp(tester);
      final UpcomingItem meralco = state.upcoming.firstWhere(
        (UpcomingItem u) => u.name.contains('Meralco'),
      );
      final Money gcashBefore = balanceOf(state, 'acc_gcash');

      await openBills(tester);
      await tapIt(tester, payTick(meralco.id));
      await payWith(tester, 'GCash');

      // The undo is ON THE ROW, not in a snack bar. A SnackBar is drawn
      // below a modal bottom sheet, so the first version of this put the
      // action on screen and physically out of reach: the tap landed on the
      // sheet and moved nothing, and a person would have had the same
      // silence.
      await tapIt(
        tester,
        // Found by its TEXT, not its semantics label. The button wraps a Text
        // whose own semantics merge upward and replace the explicit label, so
        // bySemanticsLabel matches nothing. The label still does its job for a
        // screen reader; it is simply not a handle a test can grab. Second
        // time today the same shape caught me, the first being the Split Bill
        // card.
        undoTick(meralco.id),
      );

      expect(
        balanceOf(state, 'acc_gcash'),
        gcashBefore,
        reason: 'Undo did not put the money back',
      );
      expect(
        state.upcoming
            .firstWhere((UpcomingItem u) => u.id == meralco.id)
            .isPaid,
        isFalse,
        reason: 'the money came back but the bill still reads paid',
      );
    });
  });

  group('scheduling and removing', () {
    testWidgets('a scheduled bill appears in the list and charges nothing', (
      WidgetTester tester,
    ) async {
      final FinancialState state = await pumpApp(tester);
      final Money worthBefore = netWorthOf(state);

      await openBills(tester);
      await tapIt(tester, find.text('Schedule a bill'));

      await tester.enterText(
        find.widgetWithText(
          TextField,
          'Converge Fibre, Netflix, the barangay fee',
        ),
        'Converge Fibre',
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, '0.00'), '1699');
      await tester.pumpAndSettle();
      await tapIt(tester, find.text('Schedule it'));

      expect(find.text('Converge Fibre'), findsWidgets);
      expect(
        netWorthOf(state),
        worthBefore,
        reason: 'scheduling something charged for it',
      );
    });

    testWidgets('removing a bill asks first, and keeps a payment it made', (
      WidgetTester tester,
    ) async {
      final FinancialState state = await pumpApp(tester);
      final UpcomingItem meralco = state.upcoming.firstWhere(
        (UpcomingItem u) => u.name.contains('Meralco'),
      );

      await openBills(tester);
      await tapIt(tester, payTick(meralco.id));
      await payWith(tester, 'GCash');
      final Money afterPaying = balanceOf(state, 'acc_gcash');
      final int rows = state.transactions.length;

      await tapIt(tester, removeTick(meralco.id));
      // It says out loud that the payment survives, because that is the
      // opposite of what somebody about to tap Remove is afraid of.
      expect(
        inDialog(find.textContaining('stays in Activity')),
        findsOneWidget,
      );
      await tapIt(tester, inDialog(find.text('Remove')));

      expect(
        state.upcoming.any((UpcomingItem u) => u.id == meralco.id),
        isFalse,
      );
      expect(
        state.transactions.length,
        rows,
        reason: 'removing the schedule row un-spent real money',
      );
      expect(balanceOf(state, 'acc_gcash'), afterPaying);
    });

    testWidgets('Keep it on the remove dialog removes nothing', (
      WidgetTester tester,
    ) async {
      final FinancialState state = await pumpApp(tester);
      final UpcomingItem meralco = state.upcoming.firstWhere(
        (UpcomingItem u) => u.name.contains('Meralco'),
      );
      final int before = state.upcoming.length;

      await openBills(tester);
      await tapIt(tester, removeTick(meralco.id));
      await tapIt(tester, inDialog(find.text('Keep it')));

      expect(state.upcoming.length, before);
    });
  });

  group('the two ticks agree', () {
    testWidgets('Home Coming Up card asks for an account too', (
      WidgetTester tester,
    ) async {
      // The same control with the same label existed in two places doing
      // different things to money: Coming Up flipped a flag and left the
      // ledger alone, by a decision recorded in its own comment. Both now go
      // through one flow. If they ever diverge again, this fails.
      final FinancialState state = await pumpApp(tester);
      final UpcomingItem meralco = state.upcoming.firstWhere(
        (UpcomingItem u) => u.name.contains('Meralco'),
      );
      final Money gcashBefore = balanceOf(state, 'acc_gcash');

      // Home is a lazy list, so the Coming Up card is not BUILT until it is
      // scrolled to. The first version of this tapped straight at it and
      // threw "Bad state: No element", which reads like a missing feature and
      // was a missing scroll.
      await tester.scrollUntilVisible(
        find.byType(ComingUpCard),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      // Scoped to the CARD, not the sheet, which is the entire point of this
      // test. The Bills sheet is never opened here.
      await tapIt(
        tester,
        find.descendant(
          of: find.byType(ComingUpCard),
          matching: find.bySemanticsLabel('Mark ${meralco.name} as paid'),
        ),
      );
      expect(
        inDialog(find.text('Mark it paid')),
        findsOneWidget,
        reason: 'the Coming Up tick did not ask which account to pay from',
      );

      await payWith(tester, 'GCash');
      expect(
        balanceOf(state, 'acc_gcash'),
        gcashBefore - meralco.amount,
        reason: 'the Coming Up tick ticked off without moving money',
      );
    });
  });
}
