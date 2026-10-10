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

import '../support/net_worth.dart';
import 'package:salapify/core/money/money.dart';
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

  Money balanceOf(FinancialState s, String id) =>
      s.accounts.firstWhere((Account a) => a.id == id).balance;

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

      final Money worthBefore = netWorthOf(state);
      final Money cashBefore = balanceOf(state, 'acc_cash');
      final Money gcashBefore = balanceOf(state, 'acc_gcash');
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
        worthBefore,
        reason: 'moving your own money cannot change what you are worth',
      );

      // THE DIRECTIONAL COMPANION. These are what fail when the transfer
      // silently did nothing, and they name which way the money went. A
      // second conservation statement here, such as cash + gcash unchanged,
      // would pass with the whole feature deleted.
      expect(
        balanceOf(state, 'acc_gcash'),
        gcashBefore - const Money.pesos(1200),
        reason: 'the source did not fall by the amount moved',
      );
      expect(
        balanceOf(state, 'acc_cash'),
        cashBefore + const Money.pesos(1200),
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
      final Money cashBefore = balanceOf(state, 'acc_cash');

      await openMove(tester);
      await pickAccount(tester, moneyLeaves, 'Cash on Hand');
      await pickAccount(tester, moneyArrives, 'GCash');
      await tapIt(tester, find.bySemanticsLabel('Swap the two accounts'));
      await typeAmount(tester, '300');
      await tapIt(tester, find.text('Move it'));

      // After the swap, cash is the DESTINATION, so it must go UP.
      expect(
        balanceOf(state, 'acc_cash'),
        cashBefore + const Money.pesos(300),
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
        spentBefore,
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
      final Money worthBefore = netWorthOf(state);
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
      expect(netWorthOf(state), worthBefore);
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
      final Money cash = balanceOf(state, 'acc_cash');
      final int rowsBefore = state.transactions.length;

      await openMove(tester);
      await pickAccount(tester, moneyLeaves, 'Cash on Hand');
      await pickAccount(tester, moneyArrives, 'GCash');
      await typeAmount(
        tester,
        (cash + const Money.pesos(1000)).pesos.toStringAsFixed(2),
      );
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
      final Money bpi = balanceOf(state, 'acc_bpi');
      final int rowsBefore = state.transactions.length;

      await openMove(tester);
      await pickAccount(tester, moneyLeaves, 'BPI Preferred Payroll');
      await pickAccount(tester, moneyArrives, 'Cash on Hand');
      await typeAmount(
        tester,
        (bpi + const Money.pesos(500)).pesos.toStringAsFixed(2),
      );

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
      expect(balanceOf(state, 'acc_bpi'), const Money.pesos(-500));
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

  group('paying a credit card', () {
    // THE DOOR THAT DID NOT EXIST UNTIL 2026-10-05. Both pickers filtered to
    // things you own, so a card balance could only ever go UP: every charge
    // raised it and nothing in the app could bring it down. The engine was
    // ready first, in the batch that fixed the sign, and this is the sheet
    // catching up.

    testWidgets('a card is offered as a destination and never as a source', (
      WidgetTester tester,
    ) async {
      await pumpApp(tester);
      await openMove(tester);

      // The SOURCE list must not have gained it. Taking money OUT of a card
      // is a cash advance, which carries its own fee and its own interest
      // clock, and recording one as a plain transfer would understate it.
      await tapIt(tester, dropdown(moneyLeaves));
      expect(
        find.textContaining('Rewards Card'),
        findsNothing,
        reason: 'a credit card appeared as somewhere money can leave FROM',
      );
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      await tapIt(tester, dropdown(moneyArrives));
      expect(
        find.textContaining('Rewards Card'),
        findsWidgets,
        reason: 'a credit card is not offered as somewhere money can go',
      );
    });

    testWidgets('net worth holds, AND the card and the bank both really '
        'moved', (WidgetTester tester) async {
      final FinancialState state = await pumpApp(tester);

      final Money worthBefore = netWorthOf(state);
      final Money cardBefore = balanceOf(state, 'acc_bpi_cc');
      final Money bankBefore = balanceOf(state, 'acc_bpi');
      final int rowsBefore = state.transactions.length;

      await openMove(tester);
      await pickAccount(tester, moneyLeaves, 'Preferred Payroll');
      await pickAccount(tester, moneyArrives, 'Rewards Card');
      await typeAmount(tester, '1500');
      await tapIt(tester, find.text('Pay it'));

      // THE INVARIANT. Paying a debt cannot change what you are worth: an
      // asset falls and a liability falls by the same amount. Exact, in
      // centavos, because both sides are integers.
      expect(
        netWorthOf(state),
        worthBefore,
        reason:
            'paying a card changed net worth. An asset fell and a liability '
            'fell by the same amount, so it cannot',
      );

      // THE DIRECTIONAL COMPANION, and it is mandatory rather than thorough.
      // The assertion above is a conservation statement, so it passes
      // perfectly when the payment did nothing at all. These three are the
      // only shape inaction cannot satisfy.
      expect(
        balanceOf(state, 'acc_bpi'),
        bankBefore - const Money.pesos(1500),
        reason: 'the bank account did not fall',
      );
      expect(
        balanceOf(state, 'acc_bpi_cc'),
        cardBefore - const Money.pesos(1500),
        reason:
            'what is owed on the card did not fall. If this rose instead, '
            'the destination leg is reading the account kind backwards',
      );
      expect(state.transactions.length, rowsBefore + 1);
    });

    testWidgets('and a person can FOLLOW it afterwards', (
      WidgetTester tester,
    ) async {
      // THE HALF THIS REPOSITORY KEEPS LOSING. A debt payment was once
      // written perfectly and was invisible in the account's own history,
      // with every money test green the whole time. The money being right is
      // half the job; the other half is that somebody who goes looking can
      // find it.
      final FinancialState state = await pumpApp(tester);

      await openMove(tester);
      await pickAccount(tester, moneyLeaves, 'Preferred Payroll');
      await pickAccount(tester, moneyArrives, 'Rewards Card');
      await typeAmount(tester, '1500');
      await tapIt(tester, find.text('Pay it'));

      // Screen one: Activity. The entry exists and names both ends.
      await tapIt(tester, find.byIcon(Icons.menu_book_outlined));
      expect(
        find.textContaining('Rewards Card'),
        findsWidgets,
        reason: 'the payment is not in Activity at all',
      );

      // Screen two: Accounts. The card itself shows the lower figure, which
      // is where somebody actually checks whether a payment landed.
      await tapIt(tester, find.byIcon(Icons.account_balance_wallet_outlined));
      expect(
        balanceOf(state, 'acc_bpi_cc'),
        const Money.pesos(2700),
        reason: '4,200 owed less a 1,500 payment',
      );
      // SCROLLED TO, not merely searched for. The card sits well down a list
      // of eleven accounts, and Flutter does not BUILD an off-screen row, so
      // `find.text` matches nothing whether the figure is right or wrong. A
      // finder that cannot fail for the reason it claims is not a check.
      await tester.scrollUntilVisible(
        find.text('₱2,700.00'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('₱2,700.00'), findsWidgets);
    });

    testWidgets('overpaying warns, and still lets you record it', (
      WidgetTester tester,
    ) async {
      // A WARNING AND NEVER A REFUSAL, the rule this sheet already applies to
      // an overdraft. Somebody whose stored balance is stale, or who is
      // recording a payment that already left their bank, has every right to
      // record it. The extra is real money the bank is holding for them.
      final FinancialState state = await pumpApp(tester);

      await openMove(tester);
      await pickAccount(tester, moneyLeaves, 'Preferred Payroll');
      await pickAccount(tester, moneyArrives, 'Rewards Card');
      await typeAmount(tester, '5000');

      expect(
        find.textContaining('more than you owe'),
        findsOneWidget,
        reason: 'paying 5,000 against 4,200 owed said nothing',
      );

      await tapIt(tester, find.text('Pay it'));
      expect(
        balanceOf(state, 'acc_bpi_cc'),
        const Money.pesos(-800),
        reason:
            'the card should go INTO credit by 800, not clamp at zero. '
            'Rounding the extra away would lose money the bank is holding',
      );
    });

    testWidgets('the words change, because the act is different', (
      WidgetTester tester,
    ) async {
      await pumpApp(tester);
      await openMove(tester);

      // Between two of your own pockets.
      await pickAccount(tester, moneyLeaves, 'Preferred Payroll');
      await pickAccount(tester, moneyArrives, 'GCash');
      expect(find.text('Move it'), findsOneWidget);
      expect(find.text('Money arrives'), findsOneWidget);

      // Against something you owe. Nothing "arrives" anywhere: a debt gets
      // smaller.
      await pickAccount(tester, moneyArrives, 'Rewards Card');
      expect(find.text('Pay it'), findsOneWidget);
      expect(find.text('Pays down'), findsOneWidget);
      // AN AMOUNT FIRST. The caption under the button carries the unfinished
      // reason while there is one, and "enter how much to move" is an
      // unfinished reason, so the sentence below only exists once the form
      // has nothing left to ask for.
      await typeAmount(tester, '1500');
      expect(
        find.textContaining('Less cash, and less owed'),
        findsOneWidget,
        reason:
            'the one sentence that stops somebody concluding they are poorer '
            'after paying a card',
      );
    });
  });
}
