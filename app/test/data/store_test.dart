import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/snapshot.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/design/tokens.dart';
import 'package:salapify/models/models.dart';
import 'package:salapify/state/financial_state.dart';

/// Saving, loading, and every way both can go wrong.
///
/// The rule these tests exist to hold: an unreadable file is NEVER written
/// over. There is no server, no account and no second copy, so the difference
/// between "we cannot read this today" and "this is gone" is whether some
/// code decided to save seed data on top of it.
void main() {
  FinancialState stateOn(MemorySnapshotStore store) =>
      FinancialState(clock: DateTime(2026, 9, 19, 12), store: store);

  group('a first run', () {
    test('no file means the seed, and saving is ON', () async {
      final MemorySnapshotStore store = MemorySnapshotStore();
      final FinancialState state = stateOn(store);
      await state.restore();

      expect(state.loadStatus, LoadStatus.fresh);
      expect(state.isSaving, isTrue);
      expect(state.loadProblem, isNull);
      expect(state.accounts, isNotEmpty);
    });

    test('the first change creates the file', () async {
      final MemorySnapshotStore store = MemorySnapshotStore();
      final FinancialState state = stateOn(store);
      await state.restore();
      expect(store.writes, 0);

      state.toggleTheme();
      await state.flushWrites();

      expect(store.writes, 1);
      expect(store.contents, isNotNull);
    });
  });

  group('what was entered is still there next time', () {
    test('an account added in one session opens in the next', () async {
      final MemorySnapshotStore store = MemorySnapshotStore();
      final FinancialState first = stateOn(store);
      await first.restore();

      first.addAccount(
        const Account(
          id: 'acc_new',
          name: 'Seabank Savings',
          kind: AccountKind.bank,
          institution: 'Seabank',
          balance: 12500,
          monogram: 'SB',
        ),
      );
      await first.flushWrites();

      // A whole new app, reading the same device.
      final FinancialState second = stateOn(store);
      await second.restore();

      expect(second.loadStatus, LoadStatus.loaded);
      final Account back = second.accounts.firstWhere(
        (Account a) => a.id == 'acc_new',
      );
      expect(back.name, 'Seabank Savings');
      expect(back.balance, 12500);
    });

    test('a logged expense, and the balance it moved, both survive', () async {
      final MemorySnapshotStore store = MemorySnapshotStore();
      final FinancialState first = stateOn(store);
      await first.restore();

      final double before = first.accounts
          .firstWhere((Account a) => a.id == 'acc_cash')
          .balance;
      final int entriesBefore = first.transactions.length;

      first.logTransaction(
        const Transaction(
          id: 'tx_new',
          type: TransactionType.expense,
          amount: 320,
          category: 'Food & Dining',
          accountId: 'acc_cash',
          date: '2026-09-19',
          createdAt: 1758240000000,
          merchant: 'Mang Inasal',
        ),
      );
      await first.flushWrites();

      final FinancialState second = stateOn(store);
      await second.restore();

      expect(second.transactions.length, entriesBefore + 1);
      expect(
        second.accounts.firstWhere((Account a) => a.id == 'acc_cash').balance,
        closeTo(before - 320, 0.001),
        reason:
            'the entry came back but the balance it moved did not, which is '
            'the ledger disagreeing with itself across a restart',
      );
      expect(
        second.transactions.any((Transaction t) => t.merchant == 'Mang Inasal'),
        isTrue,
      );
    });

    test('a debt payment survives, with the entry that explains it', () async {
      final MemorySnapshotStore store = MemorySnapshotStore();
      final FinancialState first = stateOn(store);
      await first.restore();

      final Debt target = first.debts.firstWhere((Debt d) => !d.isSettled);
      final double paidBefore = target.paidAmount;
      final int entriesBefore = first.transactions.length;

      first.recordDebtPayment(target.id, 1500, accountId: 'acc_gcash');
      await first.flushWrites();

      final FinancialState second = stateOn(store);
      await second.restore();

      expect(
        second.debts.firstWhere((Debt d) => d.id == target.id).paidAmount,
        closeTo(paidBefore + 1500, 0.001),
      );
      expect(
        second.transactions.length,
        entriesBefore + 1,
        reason:
            'the balance moved across a restart and nothing in the history '
            'says why, which is the founder\'s own 1,500 peso defect made '
            'permanent',
      );
    });

    test('the theme somebody chose is still chosen', () async {
      final MemorySnapshotStore store = MemorySnapshotStore();
      final FinancialState first = stateOn(store);
      await first.restore();
      final ThemeMode2 before = first.theme;
      first.toggleTheme();
      final ThemeMode2 chosen = first.theme;
      expect(chosen, isNot(before));
      await first.flushWrites();

      final FinancialState second = stateOn(store);
      await second.restore();
      expect(second.theme, chosen);
    });
  });

  group('a file that cannot be read', () {
    test('is NOT written over, and saving stays off', () async {
      const String precious = '{ this is not json';
      final MemorySnapshotStore store = MemorySnapshotStore(precious);
      final FinancialState state = stateOn(store);
      await state.restore();

      expect(state.loadStatus, LoadStatus.unreadable);
      expect(state.isSaving, isFalse);
      expect(state.loadProblem, isNotNull);

      // Now somebody taps something, as they will.
      state.toggleTheme();
      await state.flushWrites();

      expect(
        store.contents,
        precious,
        reason:
            'THE test. Their ledger is unreadable today and might be '
            'recoverable tomorrow, but only if nothing writes over it.',
      );
      expect(store.writes, 0);
    });

    test('an EMPTY file is treated as broken, not as a fresh start', () async {
      final MemorySnapshotStore store = MemorySnapshotStore('   ');
      final FinancialState state = stateOn(store);
      await state.restore();

      expect(
        state.loadStatus,
        LoadStatus.unreadable,
        reason:
            'treating an empty file as a first run hands the person demo '
            'accounts and then saves those over whatever went wrong',
      );
      expect(state.isSaving, isFalse);
    });

    test('a file this build is too old to read is refused, not rewritten',
        () async {
      final String fromTheFuture = jsonEncode(<String, dynamic>{
        'schemaVersion': Snapshot.currentSchemaVersion + 1,
        'accounts': <Map<String, dynamic>>[],
        'transactions': <Map<String, dynamic>>[],
      });
      final MemorySnapshotStore store = MemorySnapshotStore(fromTheFuture);
      final FinancialState state = stateOn(store);
      await state.restore();

      expect(state.loadStatus, LoadStatus.unreadable);
      state.toggleTheme();
      await state.flushWrites();
      expect(
        store.contents,
        fromTheFuture,
        reason:
            'Shorebird can roll a patch back, so an older build opening a '
            'newer file is a real Saturday, not a theoretical one',
      );
    });

    test('the message says what happened, in words a beginner can act on',
        () async {
      final MemorySnapshotStore store = MemorySnapshotStore('{ broken');
      final FinancialState state = stateOn(store);
      await state.restore();

      expect(state.loadProblem, contains('Nothing has been deleted'));
      expect(state.loadProblem, isNot(contains('Exception:')));
    });
  });

  group('the previous generation', () {
    Future<MemorySnapshotStore> storeWithTwoGenerations() async {
      final MemorySnapshotStore store = MemorySnapshotStore();
      final FinancialState state = stateOn(store);
      await state.restore();
      state.addAccount(
        const Account(
          id: 'acc_older',
          name: 'Older Save',
          kind: AccountKind.bank,
          institution: 'BPI',
          balance: 1000,
          monogram: 'BP',
        ),
      );
      await state.flushWrites();
      state.toggleTheme();
      await state.flushWrites();
      return store;
    }

    test('a save keeps the copy it replaced', () async {
      final MemorySnapshotStore store = await storeWithTwoGenerations();
      expect(store.previous, isNotNull);
      expect(store.previous, isNot(store.contents));
    });

    test('an interrupted save falls back to it instead of to the seed',
        () async {
      final MemorySnapshotStore store = await storeWithTwoGenerations();
      // A save that died partway through the write.
      store.contents = '{"accounts": [{"id": "acc_older", "name": "Older';

      final FinancialState state = stateOn(store);
      await state.restore();

      expect(state.loadStatus, LoadStatus.recovered);
      expect(
        state.accounts.any((Account a) => a.id == 'acc_older'),
        isTrue,
        reason:
            'the whole point of two generations: the worst case is losing '
            'the last change, not losing everything',
      );
      expect(state.loadProblem, isNotNull);
      expect(
        state.isSaving,
        isTrue,
        reason:
            'the good copy is open, so the next entry belongs in a file. '
            'Staying read-only here would turn a recovered save into a '
            'second outage.',
      );
    });

    test('only when BOTH generations fail is it read-only', () async {
      final MemorySnapshotStore store = await storeWithTwoGenerations();
      store.contents = 'broken';
      store.previous = 'also broken';

      final FinancialState state = stateOn(store);
      await state.restore();

      expect(state.loadStatus, LoadStatus.unreadable);
      expect(state.isSaving, isFalse);
    });

    test('a read that throws still tries the previous copy', () async {
      final MemorySnapshotStore store = await storeWithTwoGenerations();
      store.failReadWith = const FileSystemExceptionStub();

      final FinancialState state = stateOn(store);
      await state.restore();

      expect(state.loadStatus, LoadStatus.recovered);
      expect(state.accounts.any((Account a) => a.id == 'acc_older'), isTrue);
    });
  });

  group('a save that fails', () {
    test('says so, and does not spin trying again forever', () async {
      final MemorySnapshotStore store = MemorySnapshotStore();
      final FinancialState state = stateOn(store);
      await state.restore();

      store.failWriteWith = const FileSystemExceptionStub();
      state.toggleTheme();
      await state.flushWrites();

      expect(state.saveProblem, isNotNull);
      expect(state.saveProblem, contains('not stored yet'));
      expect(store.writes, 0);

      // The report itself must not schedule another save. A full disk stays
      // full, so a retry loop is an endless one.
      final int notifiesBefore = store.writes;
      await state.flushWrites();
      expect(store.writes, notifiesBefore);
    });

    test('and clears once a later save works', () async {
      final MemorySnapshotStore store = MemorySnapshotStore();
      final FinancialState state = stateOn(store);
      await state.restore();

      store.failWriteWith = const FileSystemExceptionStub();
      state.toggleTheme();
      await state.flushWrites();
      expect(state.saveProblem, isNotNull);

      store.failWriteWith = null;
      state.toggleTheme();
      await state.flushWrites();

      expect(state.saveProblem, isNull);
      expect(store.writes, 1);
    });
  });

  group('one write per change, in order', () {
    test('a mutation that notifies twice still writes once', () async {
      final MemorySnapshotStore store = MemorySnapshotStore();
      final FinancialState state = stateOn(store);
      await state.restore();

      // postReconciliationAdjustment logs a transaction AND records the
      // check, notifying for each. Two writes would mean a moment on disk
      // where the balance had moved and nothing explained why.
      state.postReconciliationAdjustment(
        accountId: 'acc_cash',
        actualBalance: 1950,
        note: 'Found a 100 in my other pocket',
      );
      await state.flushWrites();

      expect(
        store.writes,
        1,
        reason:
            'two saves for one action can publish the halfway state, which '
            'is a balance that moved with no entry beside it',
      );

      final FinancialState second = stateOn(store);
      await second.restore();
      expect(second.reconciliations, hasLength(1));
      expect(
        second.transactions.first.category,
        'Adjustments & Found Cash',
        reason: 'the record and the entry it explains must land together',
      );
    });

    test('several changes in a row all reach the file', () async {
      final MemorySnapshotStore store = MemorySnapshotStore();
      final FinancialState state = stateOn(store);
      await state.restore();

      for (int i = 0; i < 5; i++) {
        state.addGoal(
          Goal(
            id: 'goal_$i',
            name: 'Goal $i',
            emoji: '',
            targetAmount: 1000.0 * i,
            currentAmount: 0,
            targetDate: '2027-01-01',
            monthlyTarget: 100,
          ),
        );
        await state.flushWrites();
      }

      final FinancialState second = stateOn(store);
      await second.restore();
      for (int i = 0; i < 5; i++) {
        expect(
          second.goals.any((Goal g) => g.id == 'goal_$i'),
          isTrue,
          reason: 'goal_$i never reached the file',
        );
      }
    });
  });

  group('nothing is written before restore has decided', () {
    test('a change made before restore does not touch the file', () async {
      final MemorySnapshotStore store = MemorySnapshotStore();
      final FinancialState state = stateOn(store);

      state.toggleTheme();
      await state.flushWrites();

      expect(
        store.writes,
        0,
        reason:
            'saving before the file has been read would write the seed over '
            'a ledger nobody has looked at yet',
      );
    });
  });
}

/// A stand-in for the platform's own failure, so the test does not depend on
/// dart:io being reachable here.
class FileSystemExceptionStub implements Exception {
  const FileSystemExceptionStub();

  @override
  String toString() => 'No space left on device';
}
