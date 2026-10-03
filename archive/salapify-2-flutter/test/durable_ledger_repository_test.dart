// ADR 0001, PR B1: the durable file store as a validated shadow.
//
// These prove the safety-critical behaviours of the shadow design directly,
// composing an in-memory engine (with a failable write) and the real atomic
// FileLedgerRepository so the restart-recovery test exercises genuine on-disk
// atomicity.
//
// The load-bearing property is: SOURCE is the single truth, and the shadow can
// never override or resurrect anything. The last two tests are the two proven
// data-loss findings from the pre-merge review, kept as regressions: a
// stale/newer shadow is ignored, and a half-finished erase does not resurrect.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/durable_ledger_repository.dart';
import 'package:salapify/data/file_ledger_repository.dart';
import 'package:salapify/data/ledger_repository.dart';

/// An in-memory engine with a failable write, for composing into the coordinator.
class MemRepo implements LedgerRepository {
  String? ledger;
  String? undo;
  bool failWrites = false;
  int writes = 0;

  @override
  Future<String?> readLedger() async => ledger;
  @override
  Future<void> writeLedger(String json) async {
    if (failWrites) throw Exception('write failed');
    writes++;
    ledger = json;
  }

  @override
  Future<String?> readUndoSnapshot() async => undo;
  @override
  Future<void> writeUndoSnapshot(String json) async {
    if (failWrites) throw Exception('write failed');
    undo = json;
  }

  @override
  Future<void> clearUndoSnapshot() async => undo = null;
  @override
  Future<void> clearLedger() async {
    ledger = null;
    undo = null;
  }
}

const _ledgerA = '{"schemaVersion":12,"transactions":[{"id":"t1"}]}';
const _ledgerB =
    '{"schemaVersion":12,"transactions":[{"id":"t1"},{"id":"t2"}]}';

void main() {
  test(
    'reads come from source, and the first read seeds the shadow from it',
    () async {
      final source = MemRepo()..ledger = _ledgerA;
      final shadow = MemRepo(); // empty: first run
      final repo = DurableLedgerRepository(source: source, shadow: shadow);

      expect(
        await repo.readLedger(),
        _ledgerA,
        reason: 'the answer is always source',
      );
      expect(
        shadow.ledger,
        _ledgerA,
        reason: 'the shadow was seeded from source',
      );
      expect(repo.shadowInSync, isTrue);
    },
  );

  test(
    'a steady-state read does not rewrite an already-current shadow',
    () async {
      final source = MemRepo()..ledger = _ledgerA;
      final shadow = MemRepo()..ledger = _ledgerA;
      final repo = DurableLedgerRepository(source: source, shadow: shadow);

      await repo.readLedger();
      expect(shadow.writes, 0, reason: 'nothing to catch up, so no write');
      expect(repo.shadowInSync, isTrue);
    },
  );

  test('every write lands in source and mirrors to the shadow', () async {
    final source = MemRepo();
    final shadow = MemRepo();
    final repo = DurableLedgerRepository(source: source, shadow: shadow);

    await repo.writeLedger(_ledgerB);
    expect(source.ledger, _ledgerB);
    expect(shadow.ledger, _ledgerB, reason: 'the crash-safe copy keeps up');
    expect(repo.lastShadowWriteOk, isTrue);
  });

  test('a source write failure throws (the write is not durable)', () async {
    final source = MemRepo()..failWrites = true;
    final shadow = MemRepo();
    final repo = DurableLedgerRepository(source: source, shadow: shadow);

    await expectLater(repo.writeLedger(_ledgerB), throwsA(anything));
  });

  test(
    'a shadow write failure keeps the write durable and never throws',
    () async {
      final source = MemRepo();
      final shadow = MemRepo()..failWrites = true;
      final repo = DurableLedgerRepository(source: source, shadow: shadow);

      await repo.writeLedger(_ledgerB); // must not throw
      expect(source.ledger, _ledgerB, reason: 'source is durable');
      expect(
        repo.lastShadowWriteOk,
        isFalse,
        reason: 'the degraded copy is flagged',
      );
      expect(
        await repo.readLedger(),
        _ledgerB,
        reason: 'reads still come from source',
      );
    },
  );

  test('clearLedger wipes both stores', () async {
    final source = MemRepo()..ledger = _ledgerA;
    final shadow = MemRepo()..ledger = _ledgerA;
    final repo = DurableLedgerRepository(source: source, shadow: shadow);
    await repo.clearLedger();
    expect(source.ledger, isNull);
    expect(shadow.ledger, isNull);
  });

  test('nothing stored anywhere reads as empty', () async {
    final repo = DurableLedgerRepository(source: MemRepo(), shadow: MemRepo());
    expect(await repo.readLedger(), isNull);
    expect(repo.shadowInSync, isTrue);
  });

  // The two proven pre-merge findings, kept as regressions.

  test(
    'FINDING 1 regression: a shadow that disagrees with source never overrides source',
    () async {
      // If the shadow ever holds different bytes (older OR newer), source still
      // wins and the shadow is brought back in line with source.
      final source = MemRepo()..ledger = _ledgerA;
      final shadow = MemRepo()..ledger = _ledgerB; // disagrees with source
      final repo = DurableLedgerRepository(source: source, shadow: shadow);

      expect(
        await repo.readLedger(),
        _ledgerA,
        reason: 'source is the only truth',
      );
      expect(
        shadow.ledger,
        _ledgerA,
        reason: 'the shadow is re-synced to source, not the reverse',
      );
    },
  );

  test(
    'FINDING 2 regression: a half-finished erase does not resurrect from the shadow',
    () async {
      // "Start fresh" cleared source, then was killed before the shadow cleared,
      // so the shadow still holds the erased ledger. The next read must NOT bring
      // it back.
      final source = MemRepo(); // cleared
      final shadow = MemRepo()..ledger = _ledgerA; // stale leftover
      final repo = DurableLedgerRepository(source: source, shadow: shadow);

      expect(await repo.readLedger(), isNull, reason: 'erased stays erased');
    },
  );

  group('restart recovery with the real atomic file store', () {
    late Directory dir;
    late MemRepo source;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('durable_recovery');
      source = MemRepo()..ledger = _ledgerA;
    });
    tearDown(() async {
      if (await dir.exists()) await dir.delete(recursive: true);
    });

    test(
      'the shadow is seeded and then kept in sync across a restart',
      () async {
        // Run 1: first read seeds the real file shadow from source.
        final run1 = DurableLedgerRepository(
          source: source,
          shadow: FileLedgerRepository(directoryPath: dir.path),
        );
        expect(await run1.readLedger(), _ledgerA);
        expect(
          await FileLedgerRepository(directoryPath: dir.path).readLedger(),
          _ledgerA,
          reason: 'the shadow file is now a complete copy',
        );

        // A write after "restart" lands in source and updates the shadow file.
        final run2 = DurableLedgerRepository(
          source: source,
          shadow: FileLedgerRepository(directoryPath: dir.path),
        );
        await run2.writeLedger(_ledgerB);
        expect(source.ledger, _ledgerB);
        expect(
          await FileLedgerRepository(directoryPath: dir.path).readLedger(),
          _ledgerB,
          reason: 'the shadow file caught the write',
        );
      },
    );

    test(
      'a revert to source-only after this PR reads the exact same data',
      () async {
        final run1 = DurableLedgerRepository(
          source: source,
          shadow: FileLedgerRepository(directoryPath: dir.path),
        );
        await run1.readLedger();
        await run1.writeLedger(_ledgerB);

        // Reverting this PR means the store talks to source alone again. Because
        // source was always authoritative, it reads the current data unchanged,
        // unconditionally, with nothing to reconcile.
        expect(await source.readLedger(), _ledgerB);
      },
    );
  });
}
