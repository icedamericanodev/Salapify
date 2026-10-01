import 'package:salapify/core/money/money.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/models/models.dart';
import 'package:salapify/state/financial_state.dart';

/// Marking a scheduled bill paid, which NOW MOVES MONEY.
///
/// Founder direction, 2026-10-01, choosing between three options: "Yes, with
/// an account picker". Before this the tick only flipped a flag, so somebody
/// could mark Meralco paid and find the balance untouched and nothing in
/// Activity. That is the exact defect shape CLAUDE.md's "a write path is not
/// tested until somebody can SEE what it did" rule exists for, and it was
/// shipped rather than caught because every test asked only whether the flag
/// flipped.
///
/// These are the money half. `bills_journey_test.dart` is the half that walks
/// to the screens a person would check afterwards.
void main() {
  FinancialState store() => FinancialState(clock: DateTime(2026, 9, 18));

  Money balanceOf(FinancialState s, String id) =>
      s.accounts.firstWhere((Account a) => a.id == id).balance;

  double netWorthOf(FinancialState s) => s.accounts.fold<double>(
    0,
    (double sum, Account a) => sum + a.balance.pesos,
  );

  UpcomingItem anExpense(FinancialState s) =>
      s.upcoming.firstWhere((UpcomingItem u) => !u.countsAsIncome && !u.isPaid);

  group('paying a bill', () {
    test('the account falls by exactly the bill, and so does net worth', () {
      final FinancialState s = store();
      final UpcomingItem bill = anExpense(s);
      final Money cashBefore = balanceOf(s, 'acc_cash');
      final double worthBefore = netWorthOf(s);

      final Transaction? tx = s.markUpcomingPaid(
        bill.id,
        accountId: 'acc_cash',
      );

      expect(tx, isNotNull, reason: 'no ledger entry was written at all');
      // Directional, not conservational. "Net worth fell" is the invariant
      // here rather than a conservation, so it CAN fail by inaction, but the
      // per-account figure is what names which money moved.
      expect(
        balanceOf(s, 'acc_cash'),
        cashBefore - Money.fromDouble(bill.amount),
      );
      expect(netWorthOf(s), worthBefore - bill.amount);
    });

    test('the entry is findable, and says what it was for', () {
      final FinancialState s = store();
      final UpcomingItem bill = anExpense(s);

      s.markUpcomingPaid(bill.id, accountId: 'acc_cash');

      final Transaction saved = s.transactions.first;
      expect(saved.merchant, bill.name);
      expect(saved.accountId, 'acc_cash');
      expect(saved.type, TransactionType.expense);
      expect(saved.note, contains(bill.name));
    });

    test('the bill is marked paid', () {
      final FinancialState s = store();
      final UpcomingItem bill = anExpense(s);

      s.markUpcomingPaid(bill.id, accountId: 'acc_cash');

      expect(
        s.upcoming.firstWhere((UpcomingItem u) => u.id == bill.id).isPaid,
        isTrue,
      );
    });

    test('paying the same bill twice does not charge twice', () {
      final FinancialState s = store();
      final UpcomingItem bill = anExpense(s);
      final Money cashBefore = balanceOf(s, 'acc_cash');

      s.markUpcomingPaid(bill.id, accountId: 'acc_cash');
      final Transaction? second = s.markUpcomingPaid(
        bill.id,
        accountId: 'acc_cash',
      );

      expect(second, isNull);
      expect(
        balanceOf(s, 'acc_cash'),
        cashBefore - Money.fromDouble(bill.amount),
      );
    });
  });

  group('the three prototype behaviours NOT carried over', () {
    test('Spotify is NOT filed under electricity', () {
      // The prototype writes subcategory 'Electricity (Meralco)' on EVERY
      // bill it pays. A wrong category is money sitting perfectly in the
      // ledger and missing from every summary that reads it, which is the
      // hardest defect to notice because nothing is ever blank.
      final FinancialState s = store();
      final UpcomingItem spotify = s.upcoming.firstWhere(
        (UpcomingItem u) => u.name.contains('Spotify'),
      );

      s.markUpcomingPaid(spotify.id, accountId: 'acc_cash');

      expect(s.transactions.first.category, 'Entertainment & Leisure');
      expect(s.transactions.first.category, isNot('Electricity (Meralco)'));
    });

    test(
      'the default comes from the TYPE, not one fallback for everything',
      () {
        // This assertion is here because of what the first version of this test
        // found. It looked for a seed bill with a stored category and threw
        // "Bad state: No element": NO seed item has one. So a single
        // 'Bills & Utilities' fallback would have caught every bill in the app,
        // Spotify included, and every one of these tests would still have
        // passed.
        final FinancialState s = store();
        final UpcomingItem meralco = s.upcoming.firstWhere(
          (UpcomingItem u) => u.name.contains('Meralco'),
        );
        final UpcomingItem homeCredit = s.upcoming.firstWhere(
          (UpcomingItem u) => u.name.contains('Home Credit'),
        );

        s.markUpcomingPaid(meralco.id, accountId: 'acc_cash');
        s.markUpcomingPaid(homeCredit.id, accountId: 'acc_cash');

        final Set<String> used = s.transactions
            .where(
              (Transaction t) => (t.note ?? '').startsWith('Paid scheduled'),
            )
            .map((Transaction t) => t.category)
            .toSet();
        expect(used, <String>{
          'Bills & Utilities',
          'Debt & Loan Servicing',
        }, reason: 'two different kinds of bill landed in the same category');
      },
    );

    test('a category the caller passes beats the map', () {
      // The person paying knows better than a type map does, and the pay
      // dialog offers a picker for exactly that.
      final FinancialState s = store();
      final UpcomingItem bill = anExpense(s);

      s.markUpcomingPaid(
        bill.id,
        accountId: 'acc_cash',
        category: 'Business & Freelance Ops',
      );

      expect(s.transactions.first.category, 'Business & Freelance Ops');
    });

    test('a stored category beats both', () {
      final FinancialState s = store();
      s.addUpcoming(
        const UpcomingItem(
          id: 'up_stored',
          name: 'Something',
          amount: 100,
          dueDate: 'Sep 20',
          type: UpcomingItemType.subscription,
          category: 'Groceries',
        ),
      );

      s.markUpcomingPaid('up_stored', accountId: 'acc_cash');

      expect(s.transactions.first.category, 'Groceries');
    });

    test('NO account means NO ledger entry, rather than a silent guess', () {
      // The prototype falls back to accounts[0]?.id, writing a real expense
      // against whichever account happens to be first with no signal. This
      // repository already refused that same fallback in the pasted-receipt
      // parser, and refuses it here.
      final FinancialState s = store();
      final UpcomingItem bill = anExpense(s);
      final double worthBefore = netWorthOf(s);
      final int rowsBefore = s.transactions.length;

      final Transaction? tx = s.markUpcomingPaid(bill.id);

      expect(tx, isNull);
      expect(s.transactions.length, rowsBefore);
      expect(netWorthOf(s), worthBefore);
      // The flag still flips, which is the behaviour the Coming Up card has
      // always had: ticking it off is allowed, charging an account nobody
      // named is not.
      expect(
        s.upcoming.firstWhere((UpcomingItem u) => u.id == bill.id).isPaid,
        isTrue,
      );
    });

    test('an account id that matches nothing writes nothing', () {
      final FinancialState s = store();
      final UpcomingItem bill = anExpense(s);
      final double worthBefore = netWorthOf(s);

      expect(s.markUpcomingPaid(bill.id, accountId: 'acc_nope'), isNull);
      expect(
        netWorthOf(s),
        worthBefore,
        reason: 'money left an account that does not exist',
      );
    });
  });

  group('income rows', () {
    test('ticking a payday moves no money', () {
      // The prototype's own rule: `if (targetAccountId && !item.isIncome)`.
      // The real deposit is logged when it lands, and inventing one here
      // would double count it.
      final FinancialState s = store();
      final UpcomingItem payday = s.upcoming.firstWhere(
        (UpcomingItem u) => u.countsAsIncome,
      );
      final double worthBefore = netWorthOf(s);

      final Transaction? tx = s.markUpcomingPaid(
        payday.id,
        accountId: 'acc_cash',
      );

      expect(tx, isNull);
      expect(netWorthOf(s), worthBefore);
      expect(
        s.upcoming.firstWhere((UpcomingItem u) => u.id == payday.id).isPaid,
        isTrue,
        reason: 'it did not even tick off',
      );
    });
  });

  group('getting back from a mis-tap', () {
    test('undo gives the money back AND un-ticks the bill', () {
      // A tick that moves real money and cannot be untapped is a trap on a
      // screen full of small round targets.
      final FinancialState s = store();
      final UpcomingItem bill = anExpense(s);
      final Money cashBefore = balanceOf(s, 'acc_cash');
      final int rowsBefore = s.transactions.length;

      final Transaction? tx = s.markUpcomingPaid(
        bill.id,
        accountId: 'acc_cash',
      );
      s.undoUpcomingPaid(bill.id, tx);

      expect(balanceOf(s, 'acc_cash'), cashBefore.pesos);
      expect(s.transactions.length, rowsBefore);
      expect(
        s.upcoming.firstWhere((UpcomingItem u) => u.id == bill.id).isPaid,
        isFalse,
      );
    });

    test('undoing twice does not credit the money back twice', () {
      final FinancialState s = store();
      final UpcomingItem bill = anExpense(s);
      final Money cashBefore = balanceOf(s, 'acc_cash');

      final Transaction? tx = s.markUpcomingPaid(
        bill.id,
        accountId: 'acc_cash',
      );
      s.undoUpcomingPaid(bill.id, tx);
      s.undoUpcomingPaid(bill.id, tx);

      expect(
        balanceOf(s, 'acc_cash'),
        cashBefore.pesos,
        reason: 'a second undo paid the money back again',
      );
    });
  });

  group('scheduling and removing', () {
    test('adding a bill schedules it and moves no money', () {
      final FinancialState s = store();
      final double worthBefore = netWorthOf(s);
      final int before = s.upcoming.length;

      s.addUpcoming(
        const UpcomingItem(
          id: 'up_new',
          name: 'Converge Fibre',
          amount: 1699,
          dueDate: 'Sep 25',
          type: UpcomingItemType.bill,
          category: 'Bills & Utilities',
        ),
      );

      expect(s.upcoming.length, before + 1);
      expect(
        netWorthOf(s),
        worthBefore,
        reason: 'scheduling something charged for it',
      );
    });

    test('deleting a bill leaves a payment it already made alone', () {
      // The schedule row and the ledger entry are different records of
      // different things. Deleting the plan must not reach into the ledger
      // and un-spend money that really left the account.
      final FinancialState s = store();
      final UpcomingItem bill = anExpense(s);
      s.markUpcomingPaid(bill.id, accountId: 'acc_cash');
      final Money afterPaying = balanceOf(s, 'acc_cash');
      final int rows = s.transactions.length;

      s.deleteUpcoming(bill.id);

      expect(s.upcoming.any((UpcomingItem u) => u.id == bill.id), isFalse);
      expect(s.transactions.length, rows);
      expect(balanceOf(s, 'acc_cash'), afterPaying.pesos);
    });
  });
}
