import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/money.dart';
import 'package:salapify/data/json_codec.dart';
import 'package:salapify/models/models.dart';

/// THE PROMISE THAT KEEPS THE MONEY MIGRATION SAFE.
///
/// P2.1 moves the app's internal money representation to whole centavos. It
/// deliberately does NOT move the file on disk, because a stored-format change
/// is a migration, a migration can lose somebody's records, and that decision
/// belongs to P2.2 where it is founder gated and will have a pre-migration
/// backup behind it.
///
/// So the promise is: a file written by this version opens in the version
/// before it, and the other way round. A promise nobody tests is a comment, so
/// this asserts the stored shape directly, on the raw JSON, rather than
/// round-tripping through the codec and proving only that it agrees with
/// itself.
///
/// It will fail the moment somebody writes centavos to disk. That is the
/// point: when P2.2 deliberately changes the stored format, this test is the
/// thing that has to be changed on purpose, with the founder's answer in hand.
void main() {
  group('a goal is still stored in pesos, not centavos', () {
    const Goal goal = Goal(
      id: 'g1',
      name: 'Emergency fund',
      emoji: 'x',
      targetAmount: Money.pesos(60000),
      currentAmount: Money.of(42500, 75),
      targetDate: 'Dec 2026',
      monthlyTarget: Money.pesos(5000),
    );

    test('the written JSON holds plain peso numbers', () {
      final Map<String, dynamic> wire = goalToJson(goal);

      // The exact figures an older build wrote, and would still read.
      expect(wire['targetAmount'], 60000.0);
      expect(wire['currentAmount'], 42500.75);
      expect(wire['monthlyTarget'], 5000.0);

      // And nothing in there is a centavo count. 6000000 in a file an older
      // build opens is sixty times the goal, which is the shape of mistake
      // this test exists to make impossible to ship quietly.
      for (final String field in <String>[
        'targetAmount',
        'currentAmount',
        'monthlyTarget',
      ]) {
        expect(
          wire[field],
          isA<num>(),
          reason: '$field stopped being a plain number',
        );
        expect(
          (wire[field]! as num) < 1000000,
          isTrue,
          reason:
              '$field looks like centavos, not pesos. If that is deliberate, '
              'it is a stored-format change and belongs to P2.2 with the '
              'founder decision and the pre-migration backup.',
        );
      }
    });

    test('and a file written by the OLD build still reads correctly', () {
      // Hand-written the way a previous version would have serialised it, so
      // this is not the codec agreeing with itself.
      final Map<String, dynamic> old =
          jsonDecode('''
        {
          "id": "g1",
          "name": "Emergency fund",
          "emoji": "x",
          "targetAmount": 60000,
          "currentAmount": 42500.75,
          "targetDate": "Dec 2026",
          "monthlyTarget": 5000
        }
      ''')
              as Map<String, dynamic>;

      final Goal read = goalFromJson(old);
      expect(read.targetAmount, const Money.pesos(60000));
      expect(read.currentAmount, const Money.of(42500, 75));
      expect(read.monthlyTarget, const Money.pesos(5000));
    });

    test(
      'a round trip returns the same centavos, not merely something close',
      () {
        final Goal back = goalFromJson(goalToJson(goal));
        expect(back.targetAmount, goal.targetAmount);
        expect(back.currentAmount, goal.currentAmount);
        expect(back.monthlyTarget, goal.monthlyTarget);
        expect(back.currentAmount.centavos, 4250075);
      },
    );

    test('an integer in the file is read as pesos, not as centavos', () {
      // JSON has one number type and a whole peso figure is usually written
      // without a decimal point. Reading 5000 as fifty pesos would be the
      // single easiest way to be out by a hundred, in the direction nobody
      // notices until a goal says it is 1% funded.
      final Goal read = goalFromJson(<String, dynamic>{
        'id': 'g',
        'name': 'g',
        'emoji': 'x',
        'targetAmount': 5000,
        'currentAmount': 0,
        'targetDate': 'Dec 2026',
        'monthlyTarget': 100,
      });
      expect(read.targetAmount.centavos, 500000);
      expect(read.targetAmount.pesos, 5000.0);
    });
  });

  group('a transaction amount is still stored in pesos', () {
    // The ledger is the biggest thing in the file: every entry carries an
    // amount, so if any single field were going to be written as centavos by
    // accident it is this one, and a backup multiplied by a hundred would be
    // unrecoverable by hand.
    const Transaction tx = Transaction(
      id: 't1',
      type: TransactionType.expense,
      amount: Money.of(1053, 50),
      category: 'Food & Dining',
      accountId: 'a1',
      date: '2026-09-18',
      createdAt: 0,
    );

    test('the written JSON holds a plain peso number', () {
      final Map<String, dynamic> wire = transactionToJson(tx);
      expect(wire['amount'], 1053.5);
      expect(wire['amount'], isA<num>());
    });

    test('a file written by the OLD build still reads correctly', () {
      final Transaction read = transactionFromJson(<String, dynamic>{
        'id': 't1',
        'type': 'expense',
        'amount': 1053.5,
        'category': 'Food & Dining',
        'accountId': 'a1',
        'date': '2026-09-18',
        'createdAt': 0,
      });
      expect(read.amount, const Money.of(1053, 50));
      expect(read.amount.centavos, 105350);
    });

    test('a whole-peso integer is read as pesos, not as centavos', () {
      final Transaction read = transactionFromJson(<String, dynamic>{
        'id': 't2',
        'type': 'expense',
        'amount': 500,
        'category': 'Food & Dining',
        'accountId': 'a1',
        'date': '2026-09-18',
        'createdAt': 0,
      });
      expect(read.amount, const Money.pesos(500));
    });
  });

  group('the payment register is additive, and nothing resurrects', () {
    const Debt plain = Debt(
      id: 'd1',
      person: 'Home Credit',
      direction: DebtDirection.iOwe,
      totalAmount: Money.pesos(14700),
      paidAmount: Money.pesos(7350),
      isSettled: false,
    );

    test('a record with no payments gains NO key', () {
      // Every debt and plan on a phone today has an empty register. An empty
      // array written onto every row would be a change to the stored shape
      // for no gain at all.
      expect(debtToJson(plain).containsKey('payments'), isFalse);
    });

    test('and a file from the OLD build still opens, with an empty one', () {
      final Map<String, dynamic> old = debtToJson(plain)..remove('payments');
      final Debt read = debtFromJson(old);
      expect(read.payments, isEmpty);
      expect(
        read.paidAmount,
        const Money.pesos(7350),
        reason:
            'the figure moved while reading a file this build did not '
            'write, which is every backup the founder already has',
      );
    });

    test('a register row round trips through the file, split intact', () {
      final Debt withRow = plain.copyWith(
        payments: <DebtPayment>[
          const DebtPayment(
            id: 'dp_1',
            date: '2026-10-01',
            amount: Money.pesos(1500),
            paidBefore: Money.pesos(7350),
            settledBefore: false,
            accountId: 'acc_gcash',
          ),
        ],
      );

      final Map<String, dynamic> wire = debtToJson(withRow);
      expect(
        (wire['payments'] as List<dynamic>).first,
        containsPair('amount', 1500.0),
        reason: 'centavos reached the file',
      );

      final DebtPayment back = debtFromJson(wire).payments.single;
      expect(back.amount, const Money.pesos(1500));
      expect(back.paidBefore, const Money.pesos(7350));
      expect(back.accountId, 'acc_gcash');
    });

    test('a CLEARED field does not come back from the unknown-key sidecar', () {
      // ## The defect this exists to stop, which was live for one commit
      //
      // Snapshot copies any key a build does not MODEL into a sidecar, so a
      // file from a newer build survives a round trip through an older one.
      // On the way out the merge is `{...kept, ...own}`, so our own value
      // wins a clash.
      //
      // A CLEARED field has no own value to win with. `paidBeforeSettle` was
      // missing from `debtKeys`, so: settle a debt (written), reload (captured
      // as a stranger's field), un-settle (the codec stops writing it), and
      // the sidecar put it back. A later un-settle would then wind the debt
      // back to a figure from a settle that had already been undone, which is
      // the exact loss the field exists to prevent, by the back door.
      for (final String key in <String>['paidBeforeSettle', 'payments']) {
        expect(
          debtKeys,
          contains(key),
          reason:
              '$key is not declared as a field this build models, so once it '
              'is cleared the sidecar resurrects the old value',
        );
      }
      expect(
        installmentKeys,
        contains('payments'),
        reason: 'the same hole, on the plan side',
      );
    });
  });

  group('an account balance is still stored in pesos', () {
    const Account acc = Account(
      id: 'a1',
      name: 'GCash Wallet',
      kind: AccountKind.gcash,
      institution: 'GCash',
      balance: Money.of(8420, 50),
      monogram: 'GC',
    );

    test('the written JSON holds a plain peso number', () {
      // This group exists because the account codec was MISSED on the first
      // pass of the centavo migration and wrote the Money object itself. The
      // whole app stopped saving with "Converting object to an encodable
      // object failed", which the journeys caught and this file, covering
      // only transactions at the time, did not.
      expect(accountToJson(acc)['balance'], 8420.50);
      expect(
        accountToJson(acc)['balance'],
        isA<num>(),
        reason: 'a Money object reached the file, so nothing can be saved',
      );
    });

    test('and it round trips through the decoder', () {
      expect(
        accountFromJson(accountToJson(acc)).balance,
        const Money.of(8420, 50),
      );
    });

    test('a whole-peso integer is read as pesos, not as centavos', () {
      final Account read = accountFromJson(<String, dynamic>{
        'id': 'a1',
        'name': 'BPI',
        'kind': 'bank',
        'institution': 'BPI',
        'balance': 23000,
        'monogram': 'B',
      });
      expect(
        read.balance,
        const Money.pesos(23000),
        reason: 'every balance in every existing backup divided by a hundred',
      );
    });
  });

  group('a debt is still stored in pesos, and so is the settle memory', () {
    Map<String, dynamic> wire(Debt d) => debtToJson(d);

    const Debt plain = Debt(
      id: 'd1',
      person: 'Home Credit',
      direction: DebtDirection.iOwe,
      totalAmount: Money.of(14700, 50),
      paidAmount: Money.of(7350, 25),
      isSettled: false,
    );

    test('the written JSON holds plain peso numbers', () {
      final Map<String, dynamic> m = wire(plain);
      expect(m['totalAmount'], 14700.50);
      expect(m['paidAmount'], 7350.25);
      expect(
        m['totalAmount'],
        isNot(1470050),
        reason:
            'centavos reached the file, so every older build reading this '
            'backup multiplies every debt by a hundred',
      );
    });

    test('an ordinary debt gains NO new key', () {
      // The new field must be invisible on a debt that was never filled by
      // the Mark settled button, which is almost all of them. A key that
      // appears on every row is a stored-shape change by another name.
      expect(wire(plain).containsKey('paidBeforeSettle'), isFalse);
    });

    test('and it round trips through the file when it IS set', () {
      final Debt filled = plain.copyWith(
        isSettled: true,
        paidAmount: plain.totalAmount,
        paidBeforeSettle: plain.paidAmount,
      );

      final Map<String, dynamic> m = wire(filled);
      expect(m['paidBeforeSettle'], 7350.25);

      // Through the real decoder, because a value that survives encoding and
      // not decoding loses the figure on the next cold start, which is the
      // whole point of storing it.
      expect(debtFromJson(m).paidBeforeSettle, const Money.of(7350, 25));
    });

    test('a debt written by the OLD build still reads, with no memory', () {
      final Map<String, dynamic> old = wire(plain)..remove('paidBeforeSettle');

      final Debt read = debtFromJson(old);
      expect(read.paidBeforeSettle, isNull);
      expect(read.paidAmount, const Money.of(7350, 25));
    });
  });
}
