import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/seed_data.dart';
import 'package:salapify/data/snapshot.dart';
import 'package:salapify/models/models.dart';
import 'package:salapify/state/financial_state.dart';

/// Salapify's own demo data, and the one rule that makes it removable.
///
/// The rule is: the sweep deletes where `isSample` is true and NOWHERE ELSE.
/// Everything below exists to prove that holds against a user who has already
/// started using the app, because the failure mode is silent and permanent.
void main() {
  FinancialState seeded() => FinancialState(clock: DateTime.utc(2026, 9, 19));

  group('the seed is marked, all of it', () {
    test('every seeded record carries isSample', () {
      // A new seeded row added without the flag would survive the sweep
      // forever and no other test would notice.
      expect(SeedData.accounts.every((Account a) => a.isSample), isTrue);
      expect(
        SeedData.transactions().every((Transaction t) => t.isSample),
        isTrue,
      );
      expect(SeedData.debts.every((Debt d) => d.isSample), isTrue);
      expect(SeedData.budgets.every((Budget b) => b.isSample), isTrue);
      expect(SeedData.goals.every((Goal g) => g.isSample), isTrue);
      expect(SeedData.upcoming.every((UpcomingItem u) => u.isSample), isTrue);
      expect(
        SeedData.installments.every((InstallmentPlan p) => p.isSample),
        isTrue,
      );
      expect(SeedData.bills.every((BillItem b) => b.isSample), isTrue);
    });

    test('a fresh state reports that it holds sample data', () {
      expect(seeded().hasSampleData, isTrue);
      expect(seeded().sampleSummary.isEmpty, isFalse);
      expect(seeded().sampleSummary.assets, greaterThan(0));
      expect(
        seeded().sampleSummary.liabilities,
        greaterThan(0),
        reason:
            'assets and debts are counted separately on purpose. Adding them '
            'produced "581,170.50 here is sample money", which counted a '
            '385,000 peso demo mortgage as money somebody had.',
      );
    });
  });

  group('what the user makes is never sample', () {
    test('a logged entry is theirs', () {
      final FinancialState s = seeded();
      s.logTransaction(
        Transaction(
          id: 'tx_mine',
          type: TransactionType.expense,
          amount: 250,
          category: 'Food & Dining',
          accountId: SeedData.accounts.first.id,
          date: '2026-09-19',
          createdAt: DateTime.utc(2026, 9, 19).millisecondsSinceEpoch,
        ),
      );
      expect(
        s.transactions
            .firstWhere((Transaction t) => t.id == 'tx_mine')
            .isSample,
        isFalse,
      );
    });

    test('logging against a sample account does NOT adopt the account', () {
      final FinancialState s = seeded();
      final String id = SeedData.accounts.first.id;
      s.logTransaction(
        Transaction(
          id: 'tx_mine',
          type: TransactionType.expense,
          amount: 250,
          category: 'Food & Dining',
          accountId: id,
          date: '2026-09-19',
          createdAt: DateTime.utc(2026, 9, 19).millisecondsSinceEpoch,
        ),
      );
      expect(
        s.accounts.firstWhere((Account a) => a.id == id).isSample,
        isTrue,
        reason:
            'one expense must not turn eleven demo accounts real. The sweep '
            'handles a referenced account properly instead.',
      );
    });
  });

  group('the sweep', () {
    test('it removes the demo data and keeps every single user record', () {
      final FinancialState s = seeded();
      final String sampleAccountId = SeedData.accounts.first.id;

      s.addAccount(
        const Account(
          id: 'acc_mine',
          name: 'My GCash',
          kind: AccountKind.gcash,
          institution: 'GCash',
          balance: 5000,
          monogram: 'GC',
        ),
      );
      s.logTransaction(
        Transaction(
          id: 'tx_mine',
          type: TransactionType.expense,
          amount: 250,
          category: 'Food & Dining',
          accountId: sampleAccountId,
          date: '2026-09-19',
          createdAt: DateTime.utc(2026, 9, 19).millisecondsSinceEpoch,
        ),
      );

      s.removeSampleData();

      // THE SAFETY PROPERTY, stated as a property rather than as examples.
      expect(
        s.accounts.where((Account a) => a.isSample),
        isEmpty,
        reason: 'sample data survived the sweep',
      );
      expect(s.hasSampleData, isFalse);

      expect(s.transactions.map((Transaction t) => t.id), <String>[
        'tx_mine',
      ], reason: 'a transaction the user made was deleted by the sweep');

      final Account mine = s.accounts.firstWhere(
        (Account a) => a.id == 'acc_mine',
      );
      expect(mine.balance, 5000);
      expect(mine.isSample, isFalse);
    });

    test('an account the user entered against is KEPT, not deleted', () {
      final FinancialState s = seeded();
      final Account seededAccount = SeedData.accounts.first;
      s.logTransaction(
        Transaction(
          id: 'tx_mine',
          type: TransactionType.expense,
          amount: 250,
          category: 'Food & Dining',
          accountId: seededAccount.id,
          date: '2026-09-19',
          createdAt: DateTime.utc(2026, 9, 19).millisecondsSinceEpoch,
        ),
      );

      s.removeSampleData();

      final Account kept = s.accounts.firstWhere(
        (Account a) => a.id == seededAccount.id,
        orElse: () => throw StateError(
          'the account the user logged against was deleted, so their entry '
          'now points at nothing and the balance it moved is unexplainable',
        ),
      );
      expect(kept.isSample, isFalse);
      expect(
        kept.balance,
        closeTo(-250, 0.001),
        reason:
            'the seeded opening must come back out, leaving exactly the '
            'movement the user\'s own entry explains',
      );
    });

    test('a ledger with no sample data is not touched', () {
      // The other half of the alarm: a sweep that runs on a foreign ledger
      // would delete somebody else's records.
      final FinancialState s = seeded();
      s.removeSampleData();
      final int accounts = s.accounts.length;
      final int transactions = s.transactions.length;

      s.removeSampleData();

      expect(s.accounts.length, accounts);
      expect(s.transactions.length, transactions);
    });

    test('it clears the seed payday too', () {
      final FinancialState s = seeded();
      expect(s.payday.isSet, isTrue);
      s.removeSampleData();
      expect(
        s.payday.isSet,
        isFalse,
        reason: 'the seed cycle is Salapify\'s, not the person\'s',
      );
    });
  });

  group('putting it back', () {
    test('it is offered only after a removal', () {
      final FinancialState s = seeded();
      expect(s.canRestoreSampleData, isFalse);
      s.removeSampleData();
      expect(s.canRestoreSampleData, isTrue);
      s.restoreSampleData();
      expect(s.canRestoreSampleData, isFalse);
    });

    test('it restores everything and overwrites nothing of the user\'s', () {
      final FinancialState s = seeded();
      s.addAccount(
        const Account(
          id: 'acc_mine',
          name: 'My GCash',
          kind: AccountKind.gcash,
          institution: 'GCash',
          balance: 5000,
          monogram: 'GC',
        ),
      );
      s.removeSampleData();
      s.restoreSampleData();

      expect(s.accounts.length, SeedData.accounts.length + 1);
      expect(
        s.accounts.firstWhere((Account a) => a.id == 'acc_mine').balance,
        5000,
        reason: 'putting the sample data back overwrote a real account',
      );
      expect(s.hasSampleData, isTrue);
    });

    test('putting it back twice does not duplicate anything', () {
      final FinancialState s = seeded();
      s.removeSampleData();
      s.restoreSampleData();
      final int n = s.accounts.length;
      s.restoreSampleData();
      expect(s.accounts.length, n);
    });
  });

  group('across a save and a reload', () {
    test('the flag and the removal marker both survive', () {
      final FinancialState s = seeded();
      final Snapshot back = Snapshot.decode(
        s.snapshot().encode(at: DateTime.utc(2026, 9, 19)),
      );
      expect(back.accounts.every((Account a) => a.isSample), isTrue);
      expect(back.sampleDataRemovedAt, isNull);

      s.removeSampleData();
      final Snapshot after = Snapshot.decode(
        s.snapshot().encode(at: DateTime.utc(2026, 9, 19)),
      );
      expect(after.sampleDataRemovedAt, isNotNull);
      expect(after.accounts.any((Account a) => a.isSample), isFalse);
    });

    test('a file with no flags anywhere offers no put-back button', () {
      // A ledger restored from another phone, or imported from the prototype.
      const String foreign = '''
{
  "schemaVersion": 1,
  "accounts": [
    {"id": "their_1", "name": "Their cash", "kind": "cash",
     "institution": "Cash", "balance": 900, "monogram": "C"}
  ],
  "transactions": [], "debts": [], "budgets": [], "goals": [],
  "upcoming": [], "incomeStreams": [], "installments": [],
  "reconciliations": [], "bills": []
}
''';
      final Snapshot s = Snapshot.decode(foreign);
      expect(s.accounts.single.isSample, isFalse);
      expect(
        s.sampleDataRemovedAt,
        isNull,
        reason:
            'without this the put-back control could inject demo money into '
            'a real book that never had any',
      );
    });
  });
}
