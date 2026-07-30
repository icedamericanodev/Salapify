// ADR 0001, PR B2: the encrypted-at-rest ledger engine and its key.
//
// This is NATIVE. It uses SQLCipher (an encrypted SQLite build, via
// sqflite_sqlcipher) for the store and the Android Keystore (via
// flutter_secure_storage) for the database key, so neither the plugin code nor
// the .so libraries can travel over the air; PR B2 ships as a fresh base APK.
//
// Because it needs a device, a plugin, and native libraries, it cannot run in
// `flutter test` on the headless sandbox. So this file is kept THIN and does
// nothing clever: it is a plain key-value table holding the same raw ledger
// JSON string the other engines deal in, behind the same LedgerRepository
// interface. All the branching logic that decides migrate-vs-read-vs-fallback
// lives in EncryptedStoreCoordinator, which IS pure Dart and fully tested. This
// file's one job is durable, encrypted bytes.

import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import 'ledger_repository.dart';

/// Holds the SQLCipher database key. The key is a random 256-bit value created
/// once and kept in the Android Keystore (flutter_secure_storage wraps it with
/// a Keystore-held AES key). Any run can read it back, so there is no biometric
/// gate on the DATA, matching ADR 0001's decision that App Lock stays the UI
/// gate and a sensor reset never costs data. App Lock is unchanged and separate.
class SecureKeyStore {
  static const _keyName = 'salapify_db_key_v1';

  final FlutterSecureStorage _storage;

  SecureKeyStore([FlutterSecureStorage? storage])
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  /// The database passphrase, created on first use and stable thereafter.
  Future<String> getOrCreatePassphrase() async {
    final existing = await _storage.read(key: _keyName);
    if (existing != null && existing.isNotEmpty) return existing;
    final rnd = Random.secure();
    final bytes = List<int>.generate(32, (_) => rnd.nextInt(256));
    final key = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    await _storage.write(key: _keyName, value: key);
    return key;
  }
}

/// A [LedgerRepository] backed by an encrypted SQLite (SQLCipher) database: one
/// small key-value table holding the ledger JSON and its undo snapshot.
class SqlCipherLedgerRepository implements LedgerRepository {
  final Database _db;

  SqlCipherLedgerRepository._(this._db);

  /// The database file name, public so the bootstrap can tell "never created"
  /// from "exists but will not open" and pick the safe fallback for each.
  static const dbName = 'salapify_secure.db';
  static const _table = 'ledger_kv';
  static const _ledgerKey = 'ledger';
  static const _undoKey = 'undo';

  /// Open (creating on first run) the encrypted database, resolving the key
  /// from the Keystore. Throws if the database or key cannot be opened; the
  /// caller (EncryptedStoreCoordinator.buildDefault) treats a throw as "run on
  /// the plaintext fallback" so the user is never locked out.
  static Future<SqlCipherLedgerRepository> open({
    String? directoryPath,
    SecureKeyStore? keyStore,
  }) async {
    final dir =
        directoryPath ?? (await getApplicationDocumentsDirectory()).path;
    final passphrase =
        await (keyStore ?? SecureKeyStore()).getOrCreatePassphrase();
    final db = await openDatabase(
      '$dir/$dbName',
      password: passphrase,
      version: 1,
      onCreate: (db, _) async {
        await db.execute(
          'CREATE TABLE $_table (k TEXT PRIMARY KEY, v TEXT NOT NULL)',
        );
      },
    );
    return SqlCipherLedgerRepository._(db);
  }

  Future<String?> _get(String k) async {
    final rows = await _db.query(
      _table,
      columns: ['v'],
      where: 'k = ?',
      whereArgs: [k],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['v'] as String?;
  }

  Future<void> _put(String k, String v) async {
    await _db.insert(
      _table,
      {'k': k, 'v': v},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> _del(String k) async {
    await _db.delete(_table, where: 'k = ?', whereArgs: [k]);
  }

  @override
  Future<String?> readLedger() => _get(_ledgerKey);

  @override
  Future<void> writeLedger(String json) => _put(_ledgerKey, json);

  @override
  Future<String?> readUndoSnapshot() => _get(_undoKey);

  @override
  Future<void> writeUndoSnapshot(String json) => _put(_undoKey, json);

  @override
  Future<void> clearUndoSnapshot() => _del(_undoKey);

  @override
  Future<void> clearLedger() async {
    await _del(_ledgerKey);
    await _del(_undoKey);
  }
}
