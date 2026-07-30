// ADR 0001, PR B1: the store driven through the real durable engine.
//
// The coordinator's own unit tests (durable_ledger_repository_test.dart) prove
// migration, dual-write and self-heal in isolation. This proves the SAME thing
// the app actually does: a full SalapifyStore, with no code change of its own,
// running on a DurableLedgerRepository(primary: real atomic file, legacy: the
// old SharedPreferences store). Every user-visible write path (import, log,
// start fresh) must persist to the durable file, reload from it after a
// restart, AND keep the legacy SharedPreferences copy current so a plain revert
// of this PR loses nothing.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/durable_ledger_repository.dart';
import 'package:salapify/data/file_ledger_repository.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/money/statements.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final goldens = jsonDecode(
    File('test/goldens/backup_goldens.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final fixture = (goldens['fixtures'] as Map)['v12rich'];
  final backupText =
      jsonEncode({'app': 'salapify', 'version': 2, 'data': fixture});

  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('store_durable');
  });
  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  DurableLedgerRepository durable() => DurableLedgerRepository(
        primary: FileLedgerRepository(directoryPath: dir.path),
        legacy: const SharedPrefsLedgerRepository(),
      );

  test('import through the durable engine persists to the file and reloads', () async {
    SharedPreferences.setMockInitialValues({});
    final store = SalapifyStore(repository: durable());
    await store.load();
    expect(store.hasData, isFalse);

    await store.importBackupText(backupText);
    expect(store.hasData, isTrue);
    expect(netWorthParts(store.data)['netWorth'], closeTo(15400.5, 1e-9));

    // The authoritative copy is the real file, not SharedPreferences.
    expect(
      await FileLedgerRepository(directoryPath: dir.path).readLedger(),
      isNotNull,
      reason: 'the durable primary holds the data',
    );

    // A brand new store over the same directory reloads it, a restart.
    final restarted = SalapifyStore(repository: durable());
    await restarted.load();
    expect(restarted.hasData, isTrue);
    expect(netWorthParts(restarted.data)['netWorth'], closeTo(15400.5, 1e-9));
  });

  int txCount(SalapifyStore s) => (s.data['transactions'] as List).length;

  test('a logged entry persists to the durable file and survives a restart', () async {
    SharedPreferences.setMockInitialValues({});
    final store = SalapifyStore(repository: durable());
    await store.load();
    await store.importBackupText(backupText);
    final before = txCount(store);

    await store.addEntry(
        {'amount': -100.0, 'note': 'coffee', 'type': 'expense', 'accountId': 'acc_bank'});
    expect(txCount(store), before + 1, reason: 'the entry landed in memory');

    final restarted = SalapifyStore(repository: durable());
    await restarted.load();
    expect(txCount(restarted), before + 1,
        reason: 'the logged entry came back from the durable file');
    expect(restarted.data['transactions'].last['note'], 'coffee');
  });

  test('legacy SharedPreferences stays current, so a plain revert loses nothing', () async {
    SharedPreferences.setMockInitialValues({});
    final store = SalapifyStore(repository: durable());
    await store.load();
    await store.importBackupText(backupText);
    final imported = txCount(store);
    await store.addEntry(
        {'amount': -100.0, 'note': 'coffee', 'type': 'expense', 'accountId': 'acc_bank'});

    // Reverting this PR means the store talks to SharedPreferences alone again.
    // That store must load the SAME up-to-date data with no migration.
    final reverted = SalapifyStore(repository: const SharedPrefsLedgerRepository());
    await reverted.load();
    expect(reverted.hasData, isTrue);
    expect(txCount(reverted), imported + 1,
        reason: 'the mirror carried the import AND the logged entry');
    expect(reverted.data['transactions'].last['note'], 'coffee');
  });

  test('first run migrates an existing SharedPreferences ledger into the file', () async {
    // Seed ONLY the legacy store, the state of a phone updating into this build:
    // SharedPreferences holds the ledger, the durable file does not exist yet.
    final seed = SalapifyStore(repository: const SharedPrefsLedgerRepository());
    SharedPreferences.setMockInitialValues({});
    await seed.load();
    await seed.importBackupText(backupText);
    final storedBlob = (await SharedPreferences.getInstance()).getString(storageKey);
    expect(storedBlob, isNotNull);
    expect(await FileLedgerRepository(directoryPath: dir.path).readLedger(), isNull,
        reason: 'the durable file does not exist before the first durable load');

    // First load on the durable engine migrates legacy into the file.
    final store = SalapifyStore(repository: durable());
    await store.load();
    expect(store.hasData, isTrue);
    expect(netWorthParts(store.data)['netWorth'], closeTo(15400.5, 1e-9));
    expect(await FileLedgerRepository(directoryPath: dir.path).readLedger(), isNotNull,
        reason: 'migration built the durable primary from legacy');
  });

  test('start fresh clears both the durable file and the legacy store', () async {
    SharedPreferences.setMockInitialValues({});
    final store = SalapifyStore(repository: durable());
    await store.load();
    await store.importBackupText(backupText);

    await store.startFresh();
    expect(store.hasData, isFalse);
    expect(await FileLedgerRepository(directoryPath: dir.path).readLedger(), isNull);
    expect((await SharedPreferences.getInstance()).getString(storageKey), isNull,
        reason: 'erase wipes both stores or a revert would resurrect erased data');
  });
}
