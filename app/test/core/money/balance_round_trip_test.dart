import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/ledger.dart';
import 'package:salapify/core/money/money.dart';
import 'package:salapify/models/models.dart';

/// Apply a transaction, take it back, and the balance must be EXACTLY what it
/// was. Not nearly.
///
/// ## Why "nearly" is not good enough here
///
/// `reverseFromBalances` is how an undo gives somebody their money back, and
/// the function's own documentation already calls the round trip its defining
/// property. The existing guard in `ledger_golden_test.dart` asserts it with
/// `closeTo(.., 0.0001)`, and its fixture round-trips exactly, so the
/// tolerance was never exercised and was hiding an unexercised failure.
///
/// Measured on plain peso figures, before the migration:
///
///     balance 129,425.77, payment 19,861.93
///     (b - x) + x = 129,425.76999999999
///
/// Sampling 200,000 random pairs at two decimals, 5.4% leave a residue. The
/// screen rounds it away, so nothing looks wrong, and it accumulates.
///
/// This matters now rather than in the abstract because "take back a payment"
/// is being built on top of it. A button that says your balance is back where
/// it was has to be exactly true, or it is a lie in one case in twenty. The
/// honest fix is whole centavos, not a wider tolerance: a tolerance on a
/// reversal test is the test agreeing not to look.
Account _account(Money balance) => Account(
  id: 'acc_1',
  name: 'Cash on Hand',
  kind: AccountKind.cash,
  institution: 'Cash',
  balance: balance,
  monogram: 'C',
);

Transaction _expense(Money amount) => Transaction(
  id: 'tx_1',
  type: TransactionType.expense,
  amount: amount,
  category: 'Food & Dining',
  accountId: 'acc_1',
  date: '2026-09-19',
  createdAt: 1,
);

void main() {
  group('a balance survives apply then reverse, to the centavo', () {
    test('the pair that did not survive a double', () {
      // Both are ordinary figures somebody could really hold and really spend.
      const Money start = Money.of(129425, 77);
      const Money spend = Money.of(19861, 93);

      final List<Account> after = applyToBalances(<Account>[
        _account(start),
      ], _expense(spend));
      final List<Account> back = reverseFromBalances(after, _expense(spend));

      expect(
        back.single.balance,
        start,
        reason:
            'the balance came back NEARLY right, which is what an undo must '
            'never do: it is the function telling somebody their money is '
            'where it was when it is not',
      );

      // Directional. Conservation alone is unfalsifiable by inaction: delete
      // both halves and the assertion above still passes.
      expect(
        after.single.balance,
        start - spend,
        reason: 'the spend did not actually move the balance',
      );
    });

    test('and a hundred awkward pairs in a row', () {
      // One pair proves one pair. The defect was a 5.4% rate, so a sweep is
      // what shows it is gone rather than merely dodged by one fixture.
      Money balance = const Money.of(100000, 01);
      for (int i = 1; i <= 100; i++) {
        final Money spend = Money(i * 1237 % 99991 + 1);
        final List<Account> after = applyToBalances(<Account>[
          _account(balance),
        ], _expense(spend));
        final List<Account> back = reverseFromBalances(after, _expense(spend));

        expect(back.single.balance, balance, reason: 'pair $i, spend $spend');
        balance = balance + const Money(97);
      }
    });

    test('a transfer round trips on BOTH legs', () {
      // The second leg reads a different field, which is why reverse is
      // written as a mirror rather than derived. A residue on either side
      // leaves two accounts wrong from one undo.
      const Money fromStart = Money.of(50000, 33);
      const Money toStart = Money.of(12345, 67);
      const Money moved = Money.of(7777, 77);

      final Transaction move = Transaction(
        id: 'tx_t',
        type: TransactionType.transfer,
        amount: moved,
        category: 'Transfer',
        accountId: 'acc_1',
        toAccountId: 'acc_2',
        date: '2026-09-19',
        createdAt: 1,
      );

      final List<Account> start = <Account>[
        _account(fromStart),
        Account(
          id: 'acc_2',
          name: 'BPI',
          kind: AccountKind.bank,
          institution: 'BPI',
          balance: toStart,
          monogram: 'B',
        ),
      ];

      final List<Account> after = applyToBalances(start, move);
      expect(after[0].balance, fromStart - moved);
      expect(after[1].balance, toStart + moved);

      final List<Account> back = reverseFromBalances(after, move);
      expect(back[0].balance, fromStart);
      expect(back[1].balance, toStart);
    });
  });
}
