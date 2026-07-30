// ADR 0001, PR A: the ledger persistence boundary.
//
// The store now reads and writes through a LedgerRepository instead of touching
// SharedPreferences directly, so the storage engine can be swapped later without
// changing a caller. These tests prove two things the boundary must never break:
//
//   1. The store actually uses the injected engine for both read and write.
//   2. The store's two load-bearing safety invariants survive the boundary:
//      an unreadable ledger disables writes and is never overwritten, and a
//      failed write never lands durably and rolls back memory.
//
// The FakeLedgerRepository here is also the seam PR B's failure-injection suite
// (disk-full, key-access, corruption) will build on: it can be told to throw on
// a read or a write.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// An in-memory ledger engine with switches to simulate an unreadable ledger and
/// a failing write.
class FakeLedgerRepository implements LedgerRepository {
  String? ledger;
  String? undo;
  bool failReads = false;
  bool failWrites = false;
  int writes = 0;

  @override
  Future<String?> readLedger() async {
    if (failReads) throw Exception('simulated unreadable ledger');
    return ledger;
  }

  @override
  Future<void> writeLedger(String json) async {
    if (failWrites) throw Exception('simulated write failure');
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
  // FX cache, reminders, and diagnostics use their own SharedPreferences keys
  // through other paths; a clean mock keeps those as no-ops so these tests only
  // exercise the ledger boundary.
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('the store reads and writes the ledger through the injected engine', () async {
    final fake = FakeLedgerRepository();
    final store = SalapifyStore(repository: fake);
    await store.load();
    expect(store.canWrite, isTrue);

    await store.addEntry({
      'type': 'expense',
      'amount': 250.0,
      'date': '2026-07-30',
      'label': 'lunch',
    });

    // It wrote through the fake, not SharedPreferences.
    expect(fake.ledger, isNotNull);
    expect(fake.ledger, contains('lunch'));
    expect(fake.writes, greaterThan(0));

    // A second store on the SAME engine reads it back.
    final reopened = SalapifyStore(repository: fake);
    await reopened.load();
    final txns = reopened.data['transactions'] as List;
    expect(txns.any((t) => t['label'] == 'lunch'), isTrue);
  });

  test('an unreadable ledger disables writes and is never overwritten', () async {
    final fake = FakeLedgerRepository()
      ..ledger = jsonEncode({
        'schemaVersion': 12,
        'accounts': <dynamic>[],
        'transactions': [
          {
            'id': 't1',
            'type': 'expense',
            'amount': 100.0,
            'date': '2026-07-01',
            'label': 'kept',
          },
        ],
      })
      ..failReads = true;
    final store = SalapifyStore(repository: fake);
    await store.load();

    expect(store.loadError, isNotNull);
    expect(store.canWrite, isFalse);

    // A write is refused, and the on-disk ledger is untouched.
    final before = fake.ledger;
    await expectLater(
      store.addEntry({
        'type': 'expense',
        'amount': 9.0,
        'date': '2026-07-30',
        'label': 'should not land',
      }),
      throwsA(anything),
    );
    expect(fake.ledger, before);
    expect(fake.ledger, contains('kept'));
    expect(fake.ledger, isNot(contains('should not land')));
  });

  test('a failed write never lands durably and rolls back memory', () async {
    final fake = FakeLedgerRepository();
    final store = SalapifyStore(repository: fake);
    await store.load();
    await store.addEntry({
      'type': 'expense',
      'amount': 100.0,
      'date': '2026-07-01',
      'label': 'first',
    });
    final durableAfterFirst = fake.ledger;

    // Now the engine refuses writes.
    fake.failWrites = true;
    await expectLater(
      store.addEntry({
        'type': 'expense',
        'amount': 50.0,
        'date': '2026-07-30',
        'label': 'doomed',
      }),
      throwsA(anything),
    );

    // In-memory rolled back: no phantom entry.
    final txns = store.data['transactions'] as List;
    expect(
      txns.any((t) => t['label'] == 'doomed'),
      isFalse,
      reason: 'a failed write must roll back memory, not leave a phantom entry',
    );
    expect(txns.any((t) => t['label'] == 'first'), isTrue);

    // Durable state did not advance past the last successful write.
    expect(fake.ledger, durableAfterFirst);
    expect(fake.ledger, isNot(contains('doomed')));
  });

  test('the SharedPreferences default engine still uses the salapify_data_v2 key', () async {
    // Behaviour-identical to the old inline code: same key, so every existing
    // backup and every persistence-reopen test still holds.
    SharedPreferences.setMockInitialValues({});
    const repo = SharedPrefsLedgerRepository();
    expect(await repo.readLedger(), isNull);
    await repo.writeLedger('{"schemaVersion":12}');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('salapify_data_v2'), '{"schemaVersion":12}');
    expect(await repo.readLedger(), '{"schemaVersion":12}');
  });
}
