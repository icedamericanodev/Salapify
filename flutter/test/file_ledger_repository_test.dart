// ADR 0001, PR B1: the durable file store's crash-safety.
//
// The point of this engine over SharedPreferences is that a process kill during
// a write can never leave a torn ledger. These tests prove the atomic-write
// contract directly: a leftover temp file (what a crash mid-write leaves behind)
// is never exposed by a read, and the target is always either its previous
// complete contents or the new complete contents.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/file_ledger_repository.dart';

void main() {
  late Directory dir;
  late FileLedgerRepository repo;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('salapify_ledger_test');
    repo = FileLedgerRepository(directoryPath: dir.path);
  });

  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  test('a written ledger reads back', () async {
    expect(await repo.readLedger(), isNull);
    await repo.writeLedger('{"schemaVersion":12,"a":1}');
    expect(await repo.readLedger(), '{"schemaVersion":12,"a":1}');
    // A second write replaces the first, atomically.
    await repo.writeLedger('{"schemaVersion":12,"a":2}');
    expect(await repo.readLedger(), '{"schemaVersion":12,"a":2}');
  });

  test('the undo snapshot is a separate file, round-trips, and clears', () async {
    await repo.writeUndoSnapshot('{"prev":true}');
    expect(await repo.readUndoSnapshot(), '{"prev":true}');
    await repo.clearUndoSnapshot();
    expect(await repo.readUndoSnapshot(), isNull);
  });

  test('a leftover temp file (a crash mid-write) is never exposed by a read', () async {
    // The last COMPLETE write.
    await repo.writeLedger('{"complete":true}');
    // Simulate a crash during the NEXT write: the bytes made it into the temp
    // file but the rename never happened.
    await File('${dir.path}/ledger.json.tmp').writeAsString('{"torn":');
    // The read still returns the last complete ledger, not the torn temp.
    expect(await repo.readLedger(), '{"complete":true}');
  });

  test('a crash before the first write ever completes reads as empty, not torn', () async {
    // Only a temp exists (a kill during the very first write); the target was
    // never created.
    await File('${dir.path}/ledger.json.tmp').writeAsString('{"torn":');
    expect(await repo.readLedger(), isNull);
  });

  test('the next write recovers over a leftover temp', () async {
    await repo.writeLedger('{"v":1}');
    await File('${dir.path}/ledger.json.tmp').writeAsString('{"torn":');
    // A normal write succeeds and leaves a clean, complete ledger.
    await repo.writeLedger('{"v":2}');
    expect(await repo.readLedger(), '{"v":2}');
  });

  test('clearLedger removes the ledger and its snapshot', () async {
    await repo.writeLedger('{"a":1}');
    await repo.writeUndoSnapshot('{"prev":1}');
    await repo.clearLedger();
    expect(await repo.readLedger(), isNull);
    expect(await repo.readUndoSnapshot(), isNull);
  });
}
