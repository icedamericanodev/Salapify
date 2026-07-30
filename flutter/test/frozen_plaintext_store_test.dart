// ADR 0001, PR B2: the frozen plaintext fallback reads the B1 world correctly
// and clears both copies on erase.

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/frozen_plaintext_store.dart';
import 'package:salapify/data/ledger_repository.dart';

class MemRepo implements LedgerRepository {
  String? ledger;
  String? undo;
  int writes = 0;
  @override
  Future<String?> readLedger() async => ledger;
  @override
  Future<void> writeLedger(String json) async {
    writes++;
    ledger = json;
  }

  @override
  Future<String?> readUndoSnapshot() async => undo;
  @override
  Future<void> writeUndoSnapshot(String json) async => undo = json;
  @override
  Future<void> clearUndoSnapshot() async => undo = null;
  @override
  Future<void> clearLedger() async {
    ledger = null;
    undo = null;
  }
}

void main() {
  test('reads SharedPreferences (the B1 source of truth) first', () async {
    final prefs = MemRepo()..ledger = 'from-prefs';
    final file = MemRepo()..ledger = 'from-file';
    final store = FrozenPlaintextStore(prefs: prefs, file: file);
    expect(await store.readLedger(), 'from-prefs');
  });

  test('falls back to the file only when SharedPreferences is empty', () async {
    final prefs = MemRepo(); // empty (a phone that never ran B1 would have this too)
    final file = MemRepo()..ledger = 'from-file';
    final store = FrozenPlaintextStore(prefs: prefs, file: file);
    expect(await store.readLedger(), 'from-file');
  });

  test('writes are frozen no-ops, so the coordinator can never advance the fallback', () async {
    final prefs = MemRepo()..ledger = 'x';
    final file = MemRepo()..ledger = 'x';
    final store = FrozenPlaintextStore(prefs: prefs, file: file);
    await store.writeLedger('new');
    expect(prefs.writes, 0);
    expect(file.writes, 0);
    expect(prefs.ledger, 'x', reason: 'unchanged; the fallback is read-only');
  });

  test('erase clears BOTH the prefs and the file copy', () async {
    final prefs = MemRepo()..ledger = 'x';
    final file = MemRepo()..ledger = 'x';
    final store = FrozenPlaintextStore(prefs: prefs, file: file);
    await store.clearLedger();
    expect(prefs.ledger, isNull);
    expect(file.ledger, isNull);
  });
}
