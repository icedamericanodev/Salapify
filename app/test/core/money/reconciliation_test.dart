import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/reconciliation.dart';
import 'package:salapify/data/seed_data.dart';
import 'package:salapify/models/models.dart';

/// Reconciliation: the one place the app admits it might be wrong.
///
/// The rules are the prototype's, from the fourth tab of ReportsScreen.tsx
/// and `createAdjustmentTransaction`. The design decision this file mostly
/// exists to protect is that a gap is closed by POSTING AN ENTRY and never by
/// editing a balance.
void main() {
  final DateTime today = DateTime(2026, 9, 18);

  Account account([double balance = 8420.50]) => Account(
    id: 'acc_gcash',
    name: 'GCash Wallet',
    kind: AccountKind.gcash,
    institution: 'GCash',
    balance: balance,
    monogram: 'GC',
    profile: ProfileEntity.personal,
  );

  group('the variance', () {
    test('is the statement minus the book, signed', () {
      expect(varianceOf(8420.50, 8500), closeTo(79.50, 0.001));
      expect(varianceOf(8420.50, 8000), closeTo(-420.50, 0.001));
    });

    test('anything under a centavo is floating point, not a discrepancy', () {
      expect(isBalanced(0), isTrue);
      expect(isBalanced(0.009), isTrue);
      expect(
        isBalanced(0.01),
        isFalse,
        reason:
            'one centavo IS a discrepancy. The tolerance is for float '
            'noise, not for a real difference somebody could find.',
      );
      expect(isBalanced(-0.5), isFalse);
    });
  });

  group('the adjustment entry', () {
    test('more in the bank than the app knew is INCOME, found cash', () {
      final Transaction? t = adjustmentEntry(
        account: account(),
        variance: 79.50,
        today: today,
        id: 'tx_test',
      );

      expect(t!.type, TransactionType.income);
      expect(t.amount, closeTo(79.50, 0.001));
      expect(t.category, foundCashCategory);
      expect(t.subcategory, 'Reconciliation Upward Adjustment');
      expect(t.accountId, 'acc_gcash');
      expect(
        t.status,
        TransactionStatus.reconciled,
        reason:
            'reconciled, not confirmed. That is what tells a later reader '
            'this row came from a reconciliation rather than from something '
            'somebody bought.',
      );
      expect(t.tags, contains('#traceable-adjustment'));
    });

    test('less in the bank is an EXPENSE, a write-off', () {
      final Transaction? t = adjustmentEntry(
        account: account(),
        variance: -420.50,
        today: today,
        id: 'tx_test',
      );
      expect(t!.type, TransactionType.expense);
      expect(t.amount, closeTo(420.50, 0.001));
      expect(t.category, writeOffCategory);
      expect(t.subcategory, 'Reconciliation Discrepancy Write-down');
    });

    test('both categories EXIST in the app category list', () {
      final Iterable<String> names = SeedData.categories.map(
        (CategoryInfo c) => c.name,
      );
      expect(names, contains(foundCashCategory));
      expect(names, contains(writeOffCategory));

      for (final (String category, String sub) in <(String, String)>[
        (foundCashCategory, 'Reconciliation Upward Adjustment'),
        (writeOffCategory, 'Reconciliation Discrepancy Write-down'),
      ]) {
        expect(
          SeedData.categories
              .firstWhere((CategoryInfo c) => c.name == category)
              .subcategories,
          contains(sub),
          reason:
              'An adjustment filed under a name nothing recognises sits '
              'perfectly in the ledger and vanishes from every summary.',
        );
      }
    });

    test('a balanced account produces no entry at all', () {
      expect(
        adjustmentEntry(
          account: account(),
          variance: 0,
          today: today,
          id: 'tx_test',
        ),
        isNull,
        reason:
            'an adjustment of nothing is noise in a history whose whole '
            'value is that every row means something',
      );
      expect(
        adjustmentEntry(
          account: account(),
          variance: 0.005,
          today: today,
          id: 'tx_test',
        ),
        isNull,
      );
    });

    test('the note explains itself, and has a default that still does', () {
      expect(
        adjustmentEntry(
          account: account(),
          variance: 79.50,
          today: today,
          id: 'tx_test',
          note: 'Interest credited',
        )!.note,
        contains('Interest credited'),
      );
      expect(
        adjustmentEntry(
          account: account(),
          variance: 79.50,
          today: today,
          id: 'tx_test',
        )!.note,
        contains('Statement balance alignment'),
      );
    });

    test('it inherits the account\'s own entity', () {
      final Transaction? t = adjustmentEntry(
        account: Account(
          id: 'acc_biz',
          name: 'UnionBank',
          kind: AccountKind.bank,
          institution: 'UnionBank',
          balance: 100,
          monogram: 'UB',
          profile: ProfileEntity.business,
        ),
        variance: 50,
        today: today,
        id: 'tx_test',
      );
      expect(
        t!.profile,
        ProfileEntity.business,
        reason:
            'a business account\'s adjustment belongs to the business, or '
            'it lands in the personal books and both sets are wrong',
      );
    });
  });

  group('duplicate detection', () {
    test('it finds the duplicate Meralco charge already in the fixture', () {
      final List<DuplicatePair> pairs = findDuplicates(SeedData.transactions());
      expect(
        pairs,
        isNotEmpty,
        reason:
            'The fixture carries a deliberate duplicate Meralco charge. '
            'If this finds nothing, the detector is not detecting.',
      );
    });

    test('an entry already marked duplicate is never offered again', () {
      final List<Transaction> flagged = SeedData.transactions()
          .map(
            (Transaction t) => t.status == TransactionStatus.excluded
                ? t.withStatus(TransactionStatus.duplicate)
                : t,
          )
          .toList();

      final List<DuplicatePair> pairs = findDuplicates(flagged);
      for (final DuplicatePair p in pairs) {
        expect(p.first.status, isNot(TransactionStatus.duplicate));
        expect(p.second.status, isNot(TransactionStatus.duplicate));
      }
    });

    test('three days apart is not a duplicate, two is', () {
      Transaction tx(String id, String date) => Transaction(
        id: id,
        type: TransactionType.expense,
        amount: 500,
        category: 'Food & Dining',
        accountId: 'acc_gcash',
        date: date,
        createdAt: 0,
      );

      expect(
        findDuplicates(<Transaction>[
          tx('a', '2026-09-18'),
          tx('b', '2026-09-20'),
        ]),
        hasLength(1),
      );
      expect(
        findDuplicates(<Transaction>[
          tx('a', '2026-09-18'),
          tx('b', '2026-09-21'),
        ]),
        isEmpty,
      );
    });

    test('a different amount, account or type is not a duplicate', () {
      Transaction tx({
        required String id,
        double amount = 500,
        String accountId = 'acc_gcash',
        TransactionType type = TransactionType.expense,
      }) => Transaction(
        id: id,
        type: type,
        amount: amount,
        category: 'Food & Dining',
        accountId: accountId,
        date: '2026-09-18',
        createdAt: 0,
      );

      expect(
        findDuplicates(<Transaction>[tx(id: 'a'), tx(id: 'b', amount: 501)]),
        isEmpty,
      );
      expect(
        findDuplicates(<Transaction>[
          tx(id: 'a'),
          tx(id: 'b', accountId: 'acc_cash'),
        ]),
        isEmpty,
      );
      expect(
        findDuplicates(<Transaction>[
          tx(id: 'a'),
          tx(id: 'b', type: TransactionType.income),
        ]),
        isEmpty,
      );
    });

    test('it suggests and never acts', () {
      final List<Transaction> before = SeedData.transactions();
      final List<Transaction> after = SeedData.transactions();
      findDuplicates(after);
      for (int i = 0; i < before.length; i++) {
        expect(
          after[i].status,
          before[i].status,
          reason:
              'Two identical jeepney fares on one day are two jeepney '
              'fares. Only the person who spent the money knows, so nothing '
              'here may change anything.',
        );
      }
    });
  });

  group('the correction path', () {
    test('marking an entry changes its status and nothing else', () {
      final List<Transaction> before = SeedData.transactions();
      final Transaction target = before.first;

      final List<Transaction> after = applyStatusChange(
        before,
        target.id,
        TransactionStatus.duplicate,
      );
      final Transaction now = after.firstWhere(
        (Transaction t) => t.id == target.id,
      );

      expect(now.status, TransactionStatus.duplicate);
      expect(now.amount, target.amount, reason: 'not a peso may move');
      expect(now.accountId, target.accountId);
      expect(now.date, target.date);
      expect(now.category, target.category);
    });

    test('it changes whether the entry COUNTS, which is the point', () {
      final Transaction t = SeedData.transactions().firstWhere(
        (Transaction x) => x.status == TransactionStatus.confirmed,
      );
      expect(t.countsTowardTotals, isTrue);
      expect(
        t.withStatus(TransactionStatus.duplicate).countsTowardTotals,
        isFalse,
      );
      expect(
        t.withStatus(TransactionStatus.excluded).countsTowardTotals,
        isFalse,
      );
      expect(
        t.withStatus(TransactionStatus.reconciled).countsTowardTotals,
        isTrue,
        reason: 'reconciled money is real money, unlike excluded or duplicate',
      );
    });

    test('no other entry is touched', () {
      final List<Transaction> before = SeedData.transactions();
      final List<Transaction> after = applyStatusChange(
        before,
        before.first.id,
        TransactionStatus.duplicate,
      );
      for (int i = 1; i < before.length; i++) {
        expect(after[i].status, before[i].status);
      }
    });
  });

  group('what the ledger accounts for', () {
    test('it leaves out excluded and duplicate entries', () {
      final List<Transaction> txs = SeedData.transactions();
      // acc_maya, not acc_gcash: the excluded duplicate Meralco charge is on
      // the Maya account. Pointing this at the wrong account made it a test
      // of nothing, which is what its first version was.
      final double withExcluded = ledgerMovementFor(txs, 'acc_maya');

      final List<Transaction> allCounted = txs
          .map(
            (Transaction t) => t.status == TransactionStatus.excluded
                ? t.withStatus(TransactionStatus.confirmed)
                : t,
          )
          .toList();

      expect(
        ledgerMovementFor(allCounted, 'acc_maya'),
        isNot(closeTo(withExcluded, 0.001)),
        reason:
            'the directional check: if counting the excluded entry changes '
            'nothing, the exclusion is not being applied',
      );
    });

    test('a transfer moves out of one account and into the other', () {
      final List<Transaction> txs = <Transaction>[
        Transaction(
          id: 'tx_t',
          type: TransactionType.transfer,
          amount: 5000,
          category: 'Transfer',
          accountId: 'acc_bpi',
          toAccountId: 'acc_gcash',
          date: '2026-09-18',
          createdAt: 0,
        ),
      ];
      expect(ledgerMovementFor(txs, 'acc_bpi'), -5000);
      expect(ledgerMovementFor(txs, 'acc_gcash'), 5000);
    });
  });
}
