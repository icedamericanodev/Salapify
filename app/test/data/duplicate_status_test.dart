import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/models/models.dart';
import 'package:salapify/state/financial_state.dart';

import '../support/test_clock.dart';

/// P1.2 / F10: marking an entry duplicate moves the balance, and un-marking
/// moves it back.
///
/// ## The defect
///
/// Fix-before-launch 4 in the October expert review. `countsTowardTotals` is
/// false for `excluded` and `duplicate`, and `applyToBalances` returns the
/// accounts untouched for exactly those two. So the moment a status crossed
/// that line the money it once moved was stranded: the totals stopped
/// counting it and the account still carried it.
///
/// A 500 peso entry marked duplicate left the account 500 down with nothing
/// in any total explaining the gap. For somebody reconciling against their
/// bank app, that is not a rounding nit; it is the app being wrong.
///
/// ## Round trips, not one-way checks
///
/// Every test here does the thing and then undoes it, and asserts the balance
/// is back to the centavo. A one-way check passes if the reverse is wrong in
/// the same direction as the apply, which is the easy mistake to make when
/// writing a mirror by hand.
void main() {
  FinancialState store() => FinancialState(clock: testToday);

  double balanceOf(FinancialState s, String id) =>
      s.accounts.firstWhere((Account a) => a.id == id).balance;

  double netWorthOf(FinancialState s) =>
      s.accounts.fold<double>(0, (double sum, Account a) => sum + a.balance);

  /// A counted expense somebody could plausibly mark as a duplicate.
  Transaction anExpense(FinancialState s) => s.transactions.firstWhere(
    (Transaction t) =>
        t.type == TransactionType.expense && t.countsTowardTotals,
  );

  group('marking an entry duplicate', () {
    test('gives the money back to the account it left', () {
      final FinancialState s = store();
      final Transaction tx = anExpense(s);
      final String acc = tx.accountId;
      final double before = balanceOf(s, acc);

      s.setTransactionStatus(tx.id, TransactionStatus.duplicate);

      expect(
        balanceOf(s, acc),
        closeTo(before + tx.amount, 0.0001),
        reason: 'the entry stopped counting and the money stayed gone',
      );
    });

    test('and un-marking takes it away again, to the centavo', () {
      final FinancialState s = store();
      final Transaction tx = anExpense(s);
      final String acc = tx.accountId;
      final double start = balanceOf(s, acc);
      final double worth = netWorthOf(s);

      s.setTransactionStatus(tx.id, TransactionStatus.duplicate);
      s.setTransactionStatus(tx.id, TransactionStatus.confirmed);

      expect(balanceOf(s, acc), closeTo(start, 0.0001));
      expect(netWorthOf(s), closeTo(worth, 0.0001));
    });

    test('the totals and the balance agree afterwards', () {
      // The two halves of the defect, asserted together. Either one alone
      // passes while the other is wrong, which is how this shipped.
      final FinancialState s = store();
      final Transaction tx = anExpense(s);
      final String acc = tx.accountId;
      final double balanceBefore = balanceOf(s, acc);
      final double spentBefore = s.panFacts.monthOut;

      s.setTransactionStatus(tx.id, TransactionStatus.duplicate);

      expect(
        s.panFacts.monthOut,
        closeTo(spentBefore - tx.amount, 0.0001),
        reason: 'it is still being counted as spending',
      );
      expect(
        balanceOf(s, acc),
        closeTo(balanceBefore + tx.amount, 0.0001),
        reason: 'the balance did not follow the total',
      );
    });
  });

  group('excluded behaves the same way, because it is the same line', () {
    test('excluding returns the money and un-excluding takes it back', () {
      final FinancialState s = store();
      final Transaction tx = anExpense(s);
      final String acc = tx.accountId;
      final double start = balanceOf(s, acc);

      s.setTransactionStatus(tx.id, TransactionStatus.excluded);
      expect(balanceOf(s, acc), closeTo(start + tx.amount, 0.0001));

      s.setTransactionStatus(tx.id, TransactionStatus.confirmed);
      expect(balanceOf(s, acc), closeTo(start, 0.0001));
    });

    test('duplicate to excluded moves nothing, because neither counts', () {
      // The case a status-name check would get wrong. Both sides are below
      // the counting line, so the balance must not move at all; reversing
      // again here would pay the money back twice.
      final FinancialState s = store();
      final Transaction tx = anExpense(s);
      final String acc = tx.accountId;

      s.setTransactionStatus(tx.id, TransactionStatus.duplicate);
      final double afterFirst = balanceOf(s, acc);

      s.setTransactionStatus(tx.id, TransactionStatus.excluded);

      expect(
        balanceOf(s, acc),
        closeTo(afterFirst, 0.0001),
        reason: 'the money came back a second time',
      );
    });

    test('confirmed to pending moves nothing, because both count', () {
      final FinancialState s = store();
      final Transaction tx = anExpense(s);
      final String acc = tx.accountId;
      final double start = balanceOf(s, acc);

      s.setTransactionStatus(tx.id, TransactionStatus.pending);

      expect(balanceOf(s, acc), closeTo(start, 0.0001));
    });
  });

  group('the shapes that are easy to get wrong', () {
    test('income reverses the other way', () {
      // An expense marked duplicate RAISES the balance. Income marked
      // duplicate must LOWER it, and a mirror written by hand is exactly
      // where a sign goes missing.
      final FinancialState s = store();
      final Transaction income = s.transactions.firstWhere(
        (Transaction t) =>
            t.type == TransactionType.income && t.countsTowardTotals,
      );
      final String acc = income.accountId;
      final double start = balanceOf(s, acc);

      s.setTransactionStatus(income.id, TransactionStatus.duplicate);
      expect(balanceOf(s, acc), closeTo(start - income.amount, 0.0001));

      s.setTransactionStatus(income.id, TransactionStatus.confirmed);
      expect(balanceOf(s, acc), closeTo(start, 0.0001));
    });

    test('a transfer reverses BOTH ends', () {
      // The one with two accounts in it. Reversing only the source would look
      // right on the screen somebody is staring at and silently invent money
      // at the other end, which net worth would then report.
      final FinancialState s = store();
      final Transaction move = s.transactions.firstWhere(
        (Transaction t) =>
            t.type == TransactionType.transfer &&
            t.countsTowardTotals &&
            t.toAccountId != null,
      );
      final double fromStart = balanceOf(s, move.accountId);
      final double toStart = balanceOf(s, move.toAccountId!);
      final double worth = netWorthOf(s);

      s.setTransactionStatus(move.id, TransactionStatus.duplicate);

      expect(
        balanceOf(s, move.accountId),
        closeTo(fromStart + move.amount, 0.0001),
        reason: 'the source did not get its money back',
      );
      expect(
        balanceOf(s, move.toAccountId!),
        closeTo(toStart - move.amount, 0.0001),
        reason: 'the destination kept money that no longer moved',
      );
      expect(
        netWorthOf(s),
        closeTo(worth, 0.0001),
        reason: 'a transfer never changes net worth, in either direction',
      );
    });

    test('an entry that never counted is not paid out when touched', () {
      // The seed carries an already-excluded entry. Marking it duplicate must
      // not hand anybody money it never took.
      final FinancialState s = store();
      final Transaction already = s.transactions.firstWhere(
        (Transaction t) => t.status == TransactionStatus.excluded,
      );
      final double worth = netWorthOf(s);

      s.setTransactionStatus(already.id, TransactionStatus.duplicate);

      expect(netWorthOf(s), closeTo(worth, 0.0001));
    });
  });
}
