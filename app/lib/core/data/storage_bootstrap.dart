// ADR 0001, PR B2: build the ledger engine the app runs on.
//
// Kept in its own file so the pure-Dart coordinator (encrypted_store_coordinator
// .dart) carries no native imports and stays trivially testable. Only this file
// touches the native encrypted engine and path_provider.

import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'durable_ledger_repository.dart';
import 'encrypted_store_coordinator.dart';
import 'file_ledger_repository.dart';
import 'frozen_plaintext_store.dart';
import 'ledger_repository.dart';
import 'sql_cipher_ledger_repository.dart';

/// The engine the app runs on: the encrypted SQLCipher store as the source of
/// truth, with the old plaintext (SharedPreferences plus the B1 file) kept as a
/// frozen read-only fallback.
///
/// Two failure shapes, kept apart on purpose because they are NOT the same risk:
///
///   - The encrypted database was never created (genuine first run, or a device
///     that cannot do encryption at all). The plaintext is the current, only
///     copy, so run on the B1 durable plaintext store: writable and safe.
///
///   - The encrypted database EXISTS but will not open (a Keystore key-loss
///     case). It is authoritative and may hold newer data than the plaintext,
///     so the plaintext must NOT be written or the two diverge. Return the
///     coordinator over an [_UnavailableEncryptedStore]: it serves the frozen
///     plaintext for reads (the user sees their last safe copy, per the
///     founder's choice) but reports the encrypted store unavailable, which puts
///     the store into read-only mode. Show the data, block new writes.
Future<LedgerRepository> buildLedgerRepository() async {
  try {
    final docs = (await getApplicationDocumentsDirectory()).path;
    final fallback = FrozenPlaintextStore(
      prefs: const SharedPrefsLedgerRepository(),
      file: FileLedgerRepository(directoryPath: docs),
    );
    final dbExisted = await File(
      '$docs/${SqlCipherLedgerRepository.dbName}',
    ).exists();
    try {
      final encrypted = await SqlCipherLedgerRepository.open(
        directoryPath: docs,
      );
      return EncryptedStoreCoordinator(
        encrypted: encrypted,
        fallback: fallback,
      );
    } catch (_) {
      if (dbExisted) {
        // Established but unopenable: read-only over the frozen plaintext, never
        // a writable plaintext that could diverge from the encrypted store.
        return EncryptedStoreCoordinator(
          encrypted: _UnavailableEncryptedStore(),
          fallback: fallback,
        );
      }
      rethrow; // no database yet: fall through to the plaintext store below
    }
  } catch (_) {
    return DurableLedgerRepository.buildDefault();
  }
}

/// A stand-in for an encrypted store that exists on disk but could not be
/// opened. Every method throws, so the coordinator serves the frozen plaintext
/// for reads and marks the encrypted store unavailable (which the store turns
/// into read-only mode), and no write is ever silently sent to the plaintext.
class _UnavailableEncryptedStore implements LedgerRepository {
  Never _fail() => throw StateError('encrypted store is unavailable');

  @override
  Future<String?> readLedger() async => _fail();
  @override
  Future<void> writeLedger(String json) async => _fail();
  @override
  Future<String?> readUndoSnapshot() async => _fail();
  @override
  Future<void> writeUndoSnapshot(String json) async => _fail();
  @override
  Future<void> clearUndoSnapshot() async => _fail();
  @override
  Future<void> clearLedger() async => _fail();
}
