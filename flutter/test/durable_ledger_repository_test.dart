// ADR 0001, PR B1: the migration + dual-write coordinator.
//
// These prove the safety-critical behaviours directly, composing an in-memory
// engine (with a failable write) and the real atomic FileLedgerRepository so the
// restart-recovery test exercises genuine on-disk atomicity.

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
const _ledgerB = '{"schemaVersion":12,"transactions":[{"id":"t1"},{"id":"t2"}]}';

void main() {
  test('first run migrates legacy into primary without touching legacy', () async {
    final primary = MemRepo();
    final legacy = MemRepo()..ledger = _ledgerA;
    final repo = DurableLedgerRepository(primary: primary, legacy: legacy);

    final read = await repo.readLedger();
    expect(read, _ledgerA);
    expect(repo.lastSource, LedgerSource.migratedFromLegacy);
    expect(primary.ledger, _ledgerA, reason: 'primary was built from legacy');
    expect(legacy.ledger, _ledgerA, reason: 'legacy is never modified');
  });

  test('steady state reads straight from primary and leaves legacy alone', () async {
    final primary = MemRepo()..ledger = _ledgerA;
    final legacy = MemRepo()..ledger = 'stale';
    final repo = DurableLedgerRepository(primary: primary, legacy: legacy);

    expect(await repo.readLedger(), _ledgerA);
    expect(repo.lastSource, LedgerSource.primary);
    expect(legacy.ledger, 'stale', reason: 'a primary read does not touch legacy');
  });

  test('every write lands in primary and mirrors to legacy', () async {
    final primary = MemRepo();
    final legacy = MemRepo();
    final repo = DurableLedgerRepository(primary: primary, legacy: legacy);

    await repo.writeLedger(_ledgerB);
    expect(primary.ledger, _ledgerB);
    expect(legacy.ledger, _ledgerB, reason: 'legacy mirror keeps the revert path current');
    expect(repo.lastMirrorOk, isTrue);
  });

  test('a primary write failure throws (the write is not durable)', () async {
    final primary = MemRepo()..failWrites = true;
    final legacy = MemRepo();
    final repo = DurableLedgerRepository(primary: primary, legacy: legacy);

    await expectLater(repo.writeLedger(_ledgerB), throwsA(anything));
    // Legacy was never written, so there is no half-committed dual-write.
    expect(legacy.ledger, isNull);
  });

  test('a legacy mirror failure keeps the write durable and never throws', () async {
    final primary = MemRepo();
    final legacy = MemRepo()..failWrites = true;
    final repo = DurableLedgerRepository(primary: primary, legacy: legacy);

    await repo.writeLedger(_ledgerB); // must not throw
    expect(primary.ledger, _ledgerB, reason: 'primary is durable');
    expect(repo.lastMirrorOk, isFalse, reason: 'the degraded revert path is flagged');
    expect(await repo.readLedger(), _ledgerB);
  });

  test('a corrupt primary self-heals from the intact legacy copy', () async {
    final primary = MemRepo()..ledger = 'not json at all';
    final legacy = MemRepo()..ledger = _ledgerA;
    final repo = DurableLedgerRepository(primary: primary, legacy: legacy);

    final read = await repo.readLedger();
    expect(read, _ledgerA, reason: 'a good copy sits in legacy, so use it');
    expect(repo.primaryWasCorrupt, isTrue);
    expect(repo.lastSource, LedgerSource.legacyFallback);
    expect(primary.ledger, _ledgerA, reason: 'primary was repaired from legacy');

    // The next read is clean primary.
    expect(await repo.readLedger(), _ledgerA);
    expect(repo.lastSource, LedgerSource.primary);
  });

  test('clearLedger wipes both stores', () async {
    final primary = MemRepo()..ledger = _ledgerA;
    final legacy = MemRepo()..ledger = _ledgerA;
    final repo = DurableLedgerRepository(primary: primary, legacy: legacy);
    await repo.clearLedger();
    expect(primary.ledger, isNull);
    expect(legacy.ledger, isNull);
  });

  test('nothing stored anywhere reads as empty', () async {
    final repo = DurableLedgerRepository(primary: MemRepo(), legacy: MemRepo());
    expect(await repo.readLedger(), isNull);
    expect(repo.lastSource, LedgerSource.empty);
  });

  group('restart recovery with the real atomic file store', () {
    late Directory dir;
    late MemRepo legacy;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('durable_recovery');
      legacy = MemRepo()..ledger = _ledgerA;
    });
    tearDown(() async {
      if (await dir.exists()) await dir.delete(recursive: true);
    });

    test('a restart finds either the old complete store or the new complete store', () async {
      // Run 1: migrate legacy -> primary (a real file, atomic).
      final run1 = DurableLedgerRepository(
        primary: FileLedgerRepository(directoryPath: dir.path),
        legacy: legacy,
      );
      expect(await run1.readLedger(), _ledgerA);

      // "Restart": a brand new coordinator over the same directory. Primary is
      // a complete file now, so it is read directly, no re-migration.
      final run2 = DurableLedgerRepository(
        primary: FileLedgerRepository(directoryPath: dir.path),
        legacy: legacy,
      );
      expect(await run2.readLedger(), _ledgerA);
      expect(run2.lastSource, LedgerSource.primary);

      // A write after restart is durable in the real file and mirrored.
      await run2.writeLedger(_ledgerB);
      final run3 = DurableLedgerRepository(
        primary: FileLedgerRepository(directoryPath: dir.path),
        legacy: legacy,
      );
      expect(await run3.readLedger(), _ledgerB);
      expect(legacy.ledger, _ledgerB, reason: 'legacy mirror stayed current across the restart');
    });

    test('a crash before primary was ever written re-migrates cleanly on restart', () async {
      // No read happened in "run 1" (primary file never created). Restart: the
      // coordinator sees an absent primary and migrates fresh from legacy.
      final restart = DurableLedgerRepository(
        primary: FileLedgerRepository(directoryPath: dir.path),
        legacy: legacy,
      );
      expect(await restart.readLedger(), _ledgerA);
      expect(restart.lastSource, LedgerSource.migratedFromLegacy);
      expect(
        await FileLedgerRepository(directoryPath: dir.path).readLedger(),
        _ledgerA,
        reason: 'primary is now a complete file',
      );
    });
  });
}
