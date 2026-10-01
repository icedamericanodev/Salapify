// Moving money between your own accounts, in BOTH halves.
//
// Half one asks whether the money moved correctly. Half two asks whether a
// person can FOLLOW it afterwards, which is the half this repository keeps
// losing: a debt payment was once written perfectly and was invisible in the
// account's own history, with every money test green the whole time.
//
// A transfer is the WORST case for half one, and that shapes most of this
// file. Its defining property is that net worth does not change, so "net
// worth is unchanged" passes perfectly when the transfer did nothing at all.
// CLAUDE.md names this exactly: a conservation invariant is unfalsifiable by
// inaction, so its companion assertion can never be another conservation
// statement. Every invariant below is paired with a DIRECTIONAL one naming
// which account went down and which went up.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/features/accounts/move_money_sheet.dart';
import 'package:salapify/models/models.dart';
import 'package:salapify/screens/home/quick_actions.dart';
import 'package:salapify/state/financial_state.dart';

import '../shots/screens_shot.dart' show loadRealFonts;

import '../support/pinned_app.dart';

void main() {
  // Pinned for the same reason every other journey here pins: the seed ledger
  // is dated September 2026 and the real clock has moved past it.

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

  double balanceOf(FinancialState s, String id) =>
      s.accounts.firstWhere((Account a) => a.id == id).balance;

  double netWorthOf(FinancialState s) =>
      s.accounts.fold<double>(0, (double sum, Account a) => sum + a.balance);

  Future<void> openMove(WidgetTester tester) async {
    await tapIt(
      tester,
      find.descendant(
        of: find.byType(QuickActions),
        matching: find.text('Move'),
      ),
    );
  }

  /// Types an amount into the sheet's only money field.
  Future<void> typeAmount(WidgetTester tester, String amount) async {
    await tester.enterText(
      find.descendant(
        of: find.byType(MoveMoneySheet),
        matching: find.widgetWithText(TextField, '0.00'),
      ),
      amount,
    );
    await tester.pumpAndSettle();
  }

  /// The two account dropdowns, by position: 0 is where money leaves, 1 is
  /// where it arrives.
  ///
  /// BY POSITION, NOT BY LABEL, and that is not a style preference. The first
  /// version of this helper tapped `find.text('Money leaves')`, the
  /// dropdown's floating label. Flutter warned that the tap did not land on
  /// the finder's own widget (a filled field floats its label into a corner
  /// where the decoration is what receives the pointer), and tap only WARNS
  /// about that, it does not fail. So three tests silently drove a dropdown
  /// nobody had opened, and two of them still passed because the sheet's
  /// defaults happened to be what they wanted.
  Finder dropdown(int index) =>
      find.byType(DropdownButtonFormField<String>).at(index);

  /// Picks an account in one of the two dropdowns.
  ///
  /// The items carry the balance beside the name, so they are matched with
  /// `textContaining` rather than an exact string. `.last` because the closed
  /// field keeps showing its current value while the menu is open, so the
  /// same name is in the tree twice and the menu's copy is the later one.
  ///
  /// PASS ENOUGH OF THE NAME TO BE UNIQUE. 'BPI' matches four seed accounts
  /// (Preferred Payroll, Rewards Card, Gadget Loan, and nothing else only
  /// because the mortgage is Pag-IBIG), so `.last` picked the Gadget Loan and
  /// the test moved money out of a different account than it said. That
  /// accident is what exposed the sheet offering liabilities as transfer
  /// ends, which was a real defect and not a test problem.
  Future<void> pickAccount(
    WidgetTester tester,
    int index,
    String accountName,
  ) async {
    await tapIt(tester, dropdown(index));
    await tester.tap(find.textContaining(accountName).last);
    await tester.pumpAndSettle();
  }

  /// Which end is which, so the tests below read as sentences.
  const int moneyLeaves = 0;
  const int moneyArrives = 1;

  testWidgets('the Move shortcut opens the sheet from Home', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    final Finder door = find.descendant(
      of: find.byType(QuickActions),
      matching: find.text('Move'),
    );
    expect(
      door,
      findsOneWidget,
      reason: 'the Move shortcut is not on Home at all',
    );

    await openMove(tester);
    expect(find.byType(MoveMoneySheet), findsOneWidget);
    expect(find.text('Move money'), findsWidgets);
    // It used to say "Move is not migrated yet". If that sentence is ever
    // back, this is the test that says so.
    expect(find.textContaining('not migrated'), findsNothing);
  });

  group('the money moves, and in the right direction', () {
    testWidgets('net worth holds AND the two accounts really changed', (
      WidgetTester tester,
    ) async {
      final FinancialState state = await pumpApp(tester);

      final double worthBefore = netWorthOf(state);
      final double cashBefore = balanceOf(state, 'acc_cash');
      final double gcashBefore = balanceOf(state, 'acc_gcash');
      final int rowsBefore = state.transactions.length;

      await openMove(tester);
      await pickAccount(tester, moneyLeaves, 'GCash');
      await pickAccount(tester, moneyArrives, 'Cash on Hand');
      await typeAmount(tester, '1200');
      await tapIt(tester, find.text('Move it'));

      // THE INVARIANT. True of every correct transfer, and also true when
      // nothing happened, which is why it is never alone.
      expect(
        netWorthOf(state),
        closeTo(worthBefore, 0.001),
        reason: 'moving your own money cannot change what you are worth',
      );

      // THE DIRECTIONAL COMPANION. These are what fail when the transfer
      // silently did nothing, and they name which way the money went. A
      // second conservation statement here, such as cash + gcash unchanged,
      // would pass with the whole feature deleted.
      expect(
        balanceOf(state, 'acc_gcash'),
        closeTo(gcashBefore - 1200, 0.001),
        reason: 'the source did not fall by the amount moved',
      );
      expect(
        balanceOf(state, 'acc_cash'),
        closeTo(cashBefore + 1200, 0.001),
        reason: 'the destination did not rise by the amount moved',
      );
      expect(state.transactions.length, rowsBefore + 1);
    });

    testWidgets('the swap button really reverses which way it goes', (
      WidgetTester tester,
    ) async {
      // Worth its own test because swapping two ids is exactly the kind of
      // edit that can look right and do nothing, and the invariant cannot
      // tell: net worth holds whichever direction the money went.
      final FinancialState state = await pumpApp(tester);
      final double cashBefore = balanceOf(state, 'acc_cash');

      await openMove(tester);
      await pickAccount(tester, moneyLeaves, 'Cash on Hand');
      await pickAccount(tester, moneyArrives, 'GCash');
      await tapIt(tester, find.bySemanticsLabel('Swap the two accounts'));
      await typeAmount(tester, '300');
      await tapIt(tester, find.text('Move it'));

      // After the swap, cash is the DESTINATION, so it must go UP.
      expect(
        balanceOf(state, 'acc_cash'),
        closeTo(cashBefore + 300, 0.001),
        reason: 'the swap did not actually exchange the two ends',
      );
    });

    testWidgets('a transfer is NOT spending', (WidgetTester tester) async {
      // The whole reason a transfer is its own type. If it ever lands in the
      // month's spending, somebody moving savings around watches their
      // budget collapse for money they still have.
      final FinancialState state = await pumpApp(tester);
      final double spentBefore = state.panFacts.monthOut;

      await openMove(tester);
      await pickAccount(tester, moneyLeaves, 'GCash');
      await pickAccount(tester, moneyArrives, 'Cash on Hand');
      await typeAmount(tester, '2000');
      await tapIt(tester, find.text('Move it'));

      expect(
        state.panFacts.monthOut,
        closeTo(spentBefore, 0.001),
        reason: 'a transfer was counted as money spent',
      );
      // The did-anything-happen half, because "spending did not change" is
      // also true when the transfer never happened.
      expect(
        state.transactions.first.type,
        TransactionType.transfer,
        reason: 'nothing was written at all',
      );
    });
  });

  group('what it refuses, and what it only warns about', () {
    testWidgets('the same account at both ends is refused', (
      WidgetTester tester,
    ) async {
      // This is the defence applyToBalances asks the UI to provide. Its own
      // comment records a preserved quirk: a transfer whose destination
      // matches no account debits the source and credits nobody, so money
      // leaves net worth and arrives nowhere. Same-account is the reachable
      // cousin of that, and it has to be impossible from here.
      final FinancialState state = await pumpApp(tester);
      final double worthBefore = netWorthOf(state);
      final int rowsBefore = state.transactions.length;

      await openMove(tester);
      await pickAccount(tester, moneyLeaves, 'GCash');
      await pickAccount(tester, moneyArrives, 'GCash');
      await typeAmount(tester, '500');
      await tapIt(tester, find.text('Move it'));

      expect(
        find.textContaining('two different accounts'),
        findsOneWidget,
        reason: 'it said nothing about the two ends being the same',
      );
      expect(
        state.transactions.length,
        rowsBefore,
        reason: 'it wrote the row anyway',
      );
      expect(netWorthOf(state), closeTo(worthBefore, 0.001));
      expect(
        find.byType(MoveMoneySheet),
        findsOneWidget,
        reason: 'the sheet closed as though it had saved',
      );
    });

    testWidgets('an empty amount is refused', (WidgetTester tester) async {
      final FinancialState state = await pumpApp(tester);
      final int rowsBefore = state.transactions.length;

      await openMove(tester);
      await tapIt(tester, find.text('Move it'));

      expect(state.transactions.length, rowsBefore);
      expect(find.byType(MoveMoneySheet), findsOneWidget);
    });

    testWidgets('more cash than is in the pitaka is refused', (
      WidgetTester tester,
    ) async {
      // Physical cash cannot go negative. You cannot hand somebody money you
      // are not holding, so this one is a hard stop rather than a warning.
      final FinancialState state = await pumpApp(tester);
      final double cash = balanceOf(state, 'acc_cash');
      final int rowsBefore = state.transactions.length;

      await openMove(tester);
      await pickAccount(tester, moneyLeaves, 'Cash on Hand');
      await pickAccount(tester, moneyArrives, 'GCash');
      await typeAmount(tester, (cash + 1000).toStringAsFixed(2));
      await tapIt(tester, find.text('Move it'));

      expect(find.textContaining('There is only'), findsOneWidget);
      expect(state.transactions.length, rowsBefore);
    });

    testWidgets('a bank going below zero WARNS and still goes through', (
      WidgetTester tester,
    ) async {
      // Deliberately not a refusal. The prototype blocks only cash, and a
      // person whose balance is stale, or who is recording a move that has
      // already happened in the real world, is entitled to record it. The app
      // says what will happen and lets them decide.
      //
      // Both halves of the alarm matter here: it has to speak, and the save
      // has to still work. An alarm that quietly blocks is worse than none.
      final FinancialState state = await pumpApp(tester);
      final double bpi = balanceOf(state, 'acc_bpi');
      final int rowsBefore = state.transactions.length;

      await openMove(tester);
      await pickAccount(tester, moneyLeaves, 'BPI Preferred Payroll');
      await pickAccount(tester, moneyArrives, 'Cash on Hand');
      await typeAmount(tester, (bpi + 500).toStringAsFixed(2));

      expect(
        find.textContaining('below zero'),
        findsOneWidget,
        reason: 'it went quiet about an overdraft',
      );

      await tapIt(tester, find.text('Move it'));
      expect(
        state.transactions.length,
        rowsBefore + 1,
        reason: 'the warning turned into a block, which it must not',
      );
      expect(balanceOf(state, 'acc_bpi'), closeTo(-500, 0.001));
    });

    testWidgets('a normal move says NOTHING, so the warning means something', (
      WidgetTester tester,
    ) async {
      // The half of an alarm that gets skipped. One that cries wolf gets its
      // battery taken out, and then it is not there during the fire.
      await pumpApp(tester);

      await openMove(tester);
      await pickAccount(tester, moneyLeaves, 'GCash');
      await pickAccount(tester, moneyArrives, 'Cash on Hand');
      await typeAmount(tester, '100');

      expect(find.textContaining('below zero'), findsNothing);
      expect(find.textContaining('There is only'), findsNothing);
      expect(find.textContaining('two different accounts'), findsNothing);
    });
  });

  group('a person can FOLLOW it afterwards', () {
    testWidgets('the move is on Activity, naming both ends', (
      WidgetTester tester,
    ) async {
      final FinancialState state = await pumpApp(tester);

      await openMove(tester);
      await pickAccount(tester, moneyLeaves, 'GCash');
      await pickAccount(tester, moneyArrives, 'Cash on Hand');
      await typeAmount(tester, '750');
      await tapIt(tester, find.text('Move it'));

      // The stored row has to name both ends, or the Activity list shows a
      // row that says money went somewhere and will not say where.
      final Transaction saved = state.transactions.first;
      expect(saved.accountId, 'acc_gcash');
      expect(saved.toAccountId, 'acc_cash');

      await tapIt(tester, find.byIcon(Icons.menu_book_outlined).last);
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Transfer:'),
        findsWidgets,
        reason: 'the move is nowhere on the screen that lists what happened',
      );
    });

    testWidgets('a credit card is offered at NEITHER end', (
      WidgetTester tester,
    ) async {
      // A divergence from the prototype, which offers every account in both
      // dropdowns. On a card, `balance` is what is OWED, so "move 5,000 to
      // the credit card" and "pay 5,000 off the card" are the same sentence
      // to a person and opposite instructions to applyToBalances: it would
      // ADD 5,000 to what is owed. Paying a card down belongs on the Debt
      // screen, where the direction is unambiguous.
      final FinancialState state = await pumpApp(tester);
      final Account card = state.accounts.firstWhere(
        (Account a) => a.kind == AccountKind.credit,
      );

      await openMove(tester);
      await tapIt(tester, dropdown(moneyLeaves));

      expect(
        find.textContaining(card.name),
        findsNothing,
        reason: 'a credit card was offered as a place money can move',
      );
    });
  });
}
