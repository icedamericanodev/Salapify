import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/reconciliation.dart';
import 'package:salapify/data/snapshot.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/design/tokens.dart';
import 'package:salapify/models/models.dart';
import 'package:salapify/state/financial_state.dart';

/// Restoring a backup REPLACES the whole ledger, which makes this the single
/// most destructive thing Salapify can do: no server, no account, no second
/// copy. Everything here exists to prove the way back is real.
void main() {
  Snapshot ledgerOf(List<Account> accounts, {List<Transaction>? txs}) =>
      Snapshot(
        accounts: accounts,
        transactions: txs ?? const <Transaction>[],
        debts: const <Debt>[],
        budgets: const <Budget>[],
        goals: const <Goal>[],
        upcoming: const <UpcomingItem>[],
        incomeStreams: const <IncomeStream>[],
        installments: const <InstallmentPlan>[],
        reconciliations: const <ReconciliationRecord>[],
        bills: const <BillItem>[],
        payday: PaydayCycle.unset,
        theme: ThemeMode2.gabi,
        scenario: DecisionScenario.conservative,
      );

  const Account mine = Account(
    id: 'acc_mine',
    name: 'My GCash',
    kind: AccountKind.gcash,
    institution: 'GCash',
    balance: 52300,
    monogram: 'GC',
  );
  const Account theirs = Account(
    id: 'acc_theirs',
    name: 'Their BPI',
    kind: AccountKind.bank,
    institution: 'BPI',
    balance: 71940,
    monogram: 'BPI',
  );

  Future<FinancialState> loaded(MemorySnapshotStore store) async {
    await store.write(
      ledgerOf(const <Account>[mine]).encode(at: DateTime.utc(2026, 9, 19)),
    );
    final FinancialState s = FinancialState(
      clock: DateTime.utc(2026, 9, 19),
      store: store,
    );
    await s.restore();
    return s;
  }

  group('the copy that makes it reversible', () {
    test('an import keeps the ledger it replaced', () async {
      final MemorySnapshotStore store = MemorySnapshotStore();
      final FinancialState s = await loaded(store);

      expect(await s.importSnapshot(ledgerOf(const <Account>[theirs])), isTrue);

      // The copy holds what was here.
      final Snapshot kept = Snapshot.decode(store.preImport!);
      expect(kept.accounts.single.id, 'acc_mine');
      expect(kept.accounts.single.balance, 52300);

      // DIRECTIONAL COMPANION. Without this the test passes when the import
      // silently did nothing at all.
      expect(s.accounts.single.id, 'acc_theirs');
      expect(store.contents, contains('acc_theirs'));
      expect(store.contents, isNot(contains('acc_mine')));
    });

    test('the copy is written BEFORE the new ledger', () async {
      final MemorySnapshotStore store = MemorySnapshotStore();
      final FinancialState s = await loaded(store);
      store.order.clear();

      await s.importSnapshot(ledgerOf(const <Account>[theirs]));

      expect(
        store.order.first,
        'preimport',
        reason:
            'the new ledger landed first, so a phone that died in between '
            'would have the new ledger and no way back to the old one',
      );
    });

    test('an import that cannot keep a copy does not happen at all', () async {
      final MemorySnapshotStore store = MemorySnapshotStore();
      final FinancialState s = await loaded(store);
      final int before = store.writes;
      store.failPreImportWith = Exception('No space left on device');

      expect(
        await s.importSnapshot(ledgerOf(const <Account>[theirs])),
        isFalse,
      );

      expect(s.accounts.single.id, 'acc_mine');
      expect(store.writes, before, reason: 'something was written anyway');
      expect(s.saveProblem, isNotNull);
    });

    test('import is refused while the data file is unreadable', () async {
      // The state where importing would write over a file that is still
      // recoverable by hand.
      final MemorySnapshotStore store = MemorySnapshotStore('{ not json');
      final FinancialState s = FinancialState(
        clock: DateTime.utc(2026, 9, 19),
        store: store,
      );
      await s.restore();
      expect(s.loadStatus, LoadStatus.unreadable);

      expect(
        await s.importSnapshot(ledgerOf(const <Account>[theirs])),
        isFalse,
      );
      expect(store.writes, 0);
    });
  });

  group('undo', () {
    test('it puts the exact ledger back, field for field', () async {
      final MemorySnapshotStore store = MemorySnapshotStore();
      final FinancialState s = await loaded(store);
      final String before = store.contents!;

      await s.importSnapshot(ledgerOf(const <Account>[theirs]));
      expect(await s.undoLastImport(), isTrue);

      // The whole document, minus the timestamp, which moves on every write.
      Map<String, dynamic> stripped(String raw) {
        final Map<String, dynamic> m = Map<String, dynamic>.from(
          jsonDecode(raw) as Map,
        );
        m.remove('timestamp');
        return m;
      }

      expect(
        stripped(store.contents!),
        stripped(before),
        reason:
            'a field _apply forgot to carry would survive a field by field '
            'assertion and not this one',
      );
    });

    test('it survives the app being killed in between', () async {
      // THE test that proves the undo is a file and not a snackbar.
      final MemorySnapshotStore store = MemorySnapshotStore();
      final FinancialState first = await loaded(store);
      await first.importSnapshot(ledgerOf(const <Account>[theirs]));
      await first.flushWrites();

      // A whole new app, on the same storage.
      final FinancialState second = FinancialState(
        clock: DateTime.utc(2026, 9, 19),
        store: store,
      );
      await second.restore();

      expect(await second.previousLedger(), isNotNull);
      expect(await second.undoLastImport(), isTrue);
      expect(second.accounts.single.id, 'acc_mine');
    });

    test('the undo is itself undoable, so nobody is trapped', () async {
      final MemorySnapshotStore store = MemorySnapshotStore();
      final FinancialState s = await loaded(store);

      await s.importSnapshot(ledgerOf(const <Account>[theirs]));
      await s.undoLastImport();
      expect(s.accounts.single.id, 'acc_mine');

      await s.undoLastImport();
      expect(
        s.accounts.single.id,
        'acc_theirs',
        reason: 'undoing the undo left the person stuck on one side',
      );
    });

    test('there is nothing to put back before the first import', () async {
      final MemorySnapshotStore store = MemorySnapshotStore();
      final FinancialState s = await loaded(store);
      expect(await s.previousLedger(), isNull);
      expect(await s.undoLastImport(), isFalse);
    });
  });

  group('what comes from the file, and what does not', () {
    test(
      'the sample marker comes from the FILE, never from this phone',
      () async {
        // The dangerous case, spelled out: keep this phone's marker, import a
        // ledger with none and no sample rows, and the put-the-samples-back
        // button appears over somebody else's real book. One tap would inject
        // the demo mortgage into it.
        final MemorySnapshotStore store = MemorySnapshotStore();
        final FinancialState s = FinancialState(
          clock: DateTime.utc(2026, 9, 19),
          store: store,
        );
        await s.restore();
        s.removeSampleData();
        await s.flushWrites();
        expect(s.canRestoreSampleData, isTrue);

        await s.importSnapshot(ledgerOf(const <Account>[theirs]));

        expect(
          s.canRestoreSampleData,
          isFalse,
          reason:
              'this phone\'s removal marker survived an import and now offers '
              'to inject demo money into a ledger that never had any',
        );
      },
    );

    test('sample flags in the file are kept, not cleared', () async {
      final MemorySnapshotStore store = MemorySnapshotStore();
      final FinancialState s = await loaded(store);

      const Account sample = Account(
        id: 'acc_demo',
        name: 'Demo',
        kind: AccountKind.cash,
        institution: 'Cash',
        balance: 100,
        monogram: 'D',
        isSample: true,
      );
      await s.importSnapshot(ledgerOf(const <Account>[sample]));

      expect(
        s.hasSampleData,
        isTrue,
        reason:
            'clearing the flags on import permanently adopts demo money as '
            'the person\'s own, with nothing left to identify it by',
      );
    });
  });
}
