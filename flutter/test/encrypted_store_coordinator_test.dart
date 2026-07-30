// ADR 0001, PR B2: the encrypted-store coordinator's safety-critical logic.
//
// The SQLCipher engine and the Keystore are native and cannot run here, but ALL
// the decision logic (migrate vs read vs fall back, writes encrypted-only, erase
// clears both) lives in this pure-Dart coordinator and is proven directly with
// in-memory fakes. The two load-bearing safety properties are: the plaintext
// fallback can never override the encrypted truth, and a half-finished erase can
// never resurrect from the fallback.

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/encrypted_store_coordinator.dart';
import 'package:salapify/data/ledger_repository.dart';

/// In-memory engine with failable read and write, for composing the coordinator.
class MemRepo implements LedgerRepository {
  String? ledger;
  String? undo;
  bool failReads = false;
  bool failWrites = false;
  bool failClears = false;
  int writes = 0;

  @override
  Future<String?> readLedger() async {
    if (failReads) throw Exception('cannot open');
    return ledger;
  }

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
    if (failClears) throw Exception('clear failed');
    ledger = null;
    undo = null;
  }
}

const _a = '{"schemaVersion":12,"transactions":[{"id":"t1"}]}';
const _b = '{"schemaVersion":12,"transactions":[{"id":"t1"},{"id":"t2"}]}';

void main() {
  test('steady state reads the encrypted store (not the fallback) and retires the redundant plaintext', () async {
    final enc = MemRepo()..ledger = _a;
    final fb = MemRepo()..ledger = 'stale plaintext';
    final repo = EncryptedStoreCoordinator(encrypted: enc, fallback: fb);

    expect(await repo.readLedger(), _a, reason: 'the answer comes from encrypted');
    expect(repo.lastSource, StorageEngine.encrypted);
    expect(repo.health.encrypted, isTrue);
    // A steady-state encrypted read (a relaunch, not the migration run) is the
    // confirm-then-delete signal: the proven-redundant plaintext is retired.
    expect(fb.ledger, isNull, reason: 'the redundant plaintext was retired');
    expect(repo.plaintextRetired, isTrue);
  });

  test('the migration run keeps the plaintext fallback, retiring it only on a later relaunch', () async {
    final enc = MemRepo(); // empty: first run
    final fb = MemRepo()..ledger = _a;
    final repo = EncryptedStoreCoordinator(encrypted: enc, fallback: fb);

    // Run 1: migrate. The fallback is kept (encryption not yet proven to reopen).
    expect(await repo.readLedger(), _a);
    expect(repo.migratedThisRun, isTrue);
    expect(repo.plaintextRetired, isFalse);
    expect(fb.ledger, _a, reason: 'safety copy kept until a confirmed relaunch');

    // Run 2 ("relaunch"): a fresh coordinator over the now-populated encrypted
    // store reads steady-state and retires the fallback.
    final run2 = EncryptedStoreCoordinator(encrypted: enc, fallback: fb);
    expect(await run2.readLedger(), _a);
    expect(run2.migratedThisRun, isFalse);
    expect(run2.plaintextRetired, isTrue);
    expect(fb.ledger, isNull, reason: 'retired after encryption survived a restart');
  });

  test('an unopenable encrypted store never retires the plaintext fallback', () async {
    final enc = MemRepo()..failReads = true;
    final fb = MemRepo()..ledger = _a;
    final repo = EncryptedStoreCoordinator(encrypted: enc, fallback: fb);

    await repo.readLedger();
    expect(repo.plaintextRetired, isFalse);
    expect(fb.ledger, _a, reason: 'the fallback is exactly what we might still need');
  });

  test('first run migrates the plaintext into the encrypted store, validated', () async {
    final enc = MemRepo(); // empty
    final fb = MemRepo()..ledger = _a;
    final repo = EncryptedStoreCoordinator(encrypted: enc, fallback: fb);

    expect(await repo.readLedger(), _a);
    expect(enc.ledger, _a, reason: 'encrypted was seeded from the plaintext');
    expect(fb.ledger, _a, reason: 'the plaintext fallback is left intact for now');
    expect(repo.migratedThisRun, isTrue);
    expect(repo.lastSource, StorageEngine.encrypted);
    expect(repo.health.encrypted, isTrue);
  });

  test('nothing anywhere reads as empty', () async {
    final repo = EncryptedStoreCoordinator(encrypted: MemRepo(), fallback: MemRepo());
    expect(await repo.readLedger(), isNull);
    expect(repo.lastSource, StorageEngine.empty);
  });

  test('a migration whose write fails serves the plaintext and does not claim encrypted', () async {
    final enc = MemRepo()..failWrites = true;
    final fb = MemRepo()..ledger = _a;
    final repo = EncryptedStoreCoordinator(encrypted: enc, fallback: fb);

    expect(await repo.readLedger(), _a, reason: 'the plaintext still answers');
    expect(repo.migratedThisRun, isFalse);
    expect(repo.lastSource, StorageEngine.fallbackPlaintext);
    expect(repo.health.encrypted, isFalse);
  });

  test('an encrypted store that cannot open serves the plaintext and attempts no write', () async {
    final enc = MemRepo()..failReads = true;
    final fb = MemRepo()..ledger = _a;
    final repo = EncryptedStoreCoordinator(encrypted: enc, fallback: fb);

    expect(await repo.readLedger(), _a, reason: 'the user is not locked out');
    expect(repo.encryptedAvailable, isFalse);
    expect(repo.lastSource, StorageEngine.fallbackPlaintext);
    expect(enc.writes, 0, reason: 'no write is attempted against a store that could not open');
  });

  test('every write goes to the encrypted store only, never the frozen fallback', () async {
    final enc = MemRepo()..ledger = _a;
    final fb = MemRepo()..ledger = _a;
    final repo = EncryptedStoreCoordinator(encrypted: enc, fallback: fb);

    await repo.writeLedger(_b);
    expect(enc.ledger, _b);
    expect(fb.ledger, _a, reason: 'the fallback is frozen, never advanced');
  });

  test('a write that the encrypted store rejects throws and is not durable', () async {
    final enc = MemRepo()
      ..ledger = _a
      ..failWrites = true;
    final fb = MemRepo()..ledger = _a;
    final repo = EncryptedStoreCoordinator(encrypted: enc, fallback: fb);

    await expectLater(repo.writeLedger(_b), throwsA(anything));
    expect(fb.ledger, _a, reason: 'nothing half-committed to the fallback');
  });

  test('erase clears BOTH stores', () async {
    final enc = MemRepo()..ledger = _a;
    final fb = MemRepo()..ledger = _a;
    final repo = EncryptedStoreCoordinator(encrypted: enc, fallback: fb);

    await repo.clearLedger();
    expect(enc.ledger, isNull);
    expect(fb.ledger, isNull);
  });

  test('SAFETY regression: an encrypted clear that fails does not resurrect the plaintext (order matters)', () async {
    // The fallback (the resurrection source) is cleared FIRST, then encrypted.
    // So if the encrypted clear throws, encrypted still holds the ledger and the
    // next read serves it, rather than migrating a stale plaintext back in.
    final enc = MemRepo()
      ..ledger = _a
      ..failClears = true;
    final fb = MemRepo()..ledger = _a;
    final repo = EncryptedStoreCoordinator(encrypted: enc, fallback: fb);

    await expectLater(repo.clearLedger(), throwsA(anything));
    expect(fb.ledger, isNull, reason: 'the resurrection source was cleared first');
    // Encrypted still has the data, so the read shows it (erase incomplete,
    // retry), and does NOT migrate the now-empty fallback.
    expect(await repo.readLedger(), _a);
    expect(repo.lastSource, StorageEngine.encrypted);
  });

  test('the undo snapshot is scoped to the encrypted era, never the frozen fallback', () async {
    // A stale B1-era undo snapshot in the fallback must NOT surface as a live
    // "undo last import" offer after upgrading.
    final enc = MemRepo()..ledger = _a; // encrypted has no undo
    final fb = MemRepo()
      ..ledger = _a
      ..undo = 'stale-b1-undo';
    final repo = EncryptedStoreCoordinator(encrypted: enc, fallback: fb);

    expect(await repo.readUndoSnapshot(), isNull,
        reason: 'the frozen fallback undo must not leak through');
  });

  test('SAFETY regression: after erase, an encrypted-open failure does not resurrect from the fallback', () async {
    final enc = MemRepo()..ledger = _a;
    final fb = MemRepo()..ledger = _a;
    final repo = EncryptedStoreCoordinator(encrypted: enc, fallback: fb);

    // The user erases everything.
    await repo.clearLedger();
    // Now the encrypted store cannot open on the next launch.
    enc.failReads = true;
    // The read must NOT bring the erased ledger back from the fallback.
    expect(await repo.readLedger(), isNull, reason: 'erased stays erased');
  });
}
