// ADR 0001, PR B2: when the encrypted store cannot be opened, the store shows
// the frozen plaintext fallback but goes READ-ONLY, so it can never write to a
// stale copy and diverge from the (unreadable) encrypted store.

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/encrypted_store_coordinator.dart';
import 'package:salapify/data/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MemRepo implements LedgerRepository {
  String? ledger;
  String? undo;
  bool failReads = false;
  @override
  Future<String?> readLedger() async {
    if (failReads) throw Exception('cannot open');
    return ledger;
  }

  @override
  Future<void> writeLedger(String json) async => ledger = json;
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

const _ledger =
    '{"schemaVersion":12,"accounts":[{"id":"a1","name":"Cash","type":"cash","balance":1000}],"transactions":[]}';

void main() {
  test('an unopenable encrypted store shows the fallback data but blocks writes', () async {
    SharedPreferences.setMockInitialValues({});
    // encrypted throws on read (Keystore lost); the frozen fallback holds data.
    final encrypted = MemRepo()..failReads = true;
    final fallback = MemRepo()..ledger = _ledger;
    final store = SalapifyStore(
      repository: EncryptedStoreCoordinator(encrypted: encrypted, fallback: fallback),
    );

    await store.load();

    // The user is not locked out: their last safe copy is shown.
    expect(store.hasData, isTrue);
    // But the app is read-only, so it can never write to the stale fallback and
    // diverge from the encrypted store.
    expect(store.storageDegraded, isTrue);
    expect(store.canWrite, isFalse);
    // Data safety readout reflects it.
    expect(store.storageHealth().encrypted, isFalse);
  });

  test('a healthy encrypted store is writable and not degraded', () async {
    SharedPreferences.setMockInitialValues({});
    final encrypted = MemRepo()..ledger = _ledger;
    final fallback = MemRepo();
    final store = SalapifyStore(
      repository: EncryptedStoreCoordinator(encrypted: encrypted, fallback: fallback),
    );

    await store.load();
    expect(store.hasData, isTrue);
    expect(store.storageDegraded, isFalse);
    expect(store.canWrite, isTrue);
    expect(store.storageHealth().encrypted, isTrue);
  });
}
