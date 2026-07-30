// ADR 0001, PR B1: a durable, crash-safe file store for the ledger.
//
// This is one implementation of the PR A LedgerRepository interface. It writes
// the ledger JSON to a real file with an ATOMIC write: the bytes go to a
// sibling ".tmp" file, are flushed to disk, and only then is that file renamed
// over the target. rename() is atomic on a single filesystem, so a PROCESS KILL
// (the OS killing the app) at any moment leaves the target either untouched
// (the previous complete ledger) or fully replaced (the new complete ledger).
// It can never leave a half-written, torn file, which is the failure a plain
// "write in place" over SharedPreferences' single string value cannot rule out.
//
// One honest limit: flush:true fsyncs the temp file's BYTES, but dart:io has no
// API to fsync the directory entry the rename creates. On a hard power loss or
// kernel panic in the instant after rename() returns, the directory update can
// be lost and the file rolls back to its previous complete contents. That is
// still not corruption, only the loss of the very last write, which is
// acceptable for a phone app; a fully transactional engine (PR B2's SQLCipher)
// is the upgrade that closes even that window.
//
// It deals in the raw JSON STRING, exactly like the SharedPreferences engine:
// the store still owns sanitize, migrate, id-repair, and every money rule, and
// still treats an unreadable or invalid blob as a load error. This engine's one
// job is durable bytes, atomically.
//
// No new dependency and no native code: dart:io plus path_provider, which the
// app already ships. Encryption at rest and the Android Keystore are PR B2, a
// separate, separately-approved, native step; this engine is plaintext, the
// same posture as the SharedPreferences store it will run alongside.

import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'ledger_repository.dart';

/// A [LedgerRepository] backed by two files in a directory: the ledger and its
/// one-step undo snapshot. Every write is atomic (temp + flush + rename).
class FileLedgerRepository implements LedgerRepository {
  /// The directory the files live in. Injectable so a test can point at a temp
  /// directory; the app resolves the application documents directory through
  /// [inAppDocuments].
  final String directoryPath;

  /// The ledger and its undo snapshot. Kept as distinct files so a corrupt
  /// ledger can never take the snapshot with it.
  static const _ledgerName = 'ledger.json';
  static const _undoName = 'ledger.prev.json';

  const FileLedgerRepository({required this.directoryPath});

  /// The app's engine, rooted at the application documents directory. Native
  /// (path_provider), so it is used only on a device; tests construct the plain
  /// constructor against a temp directory instead.
  static Future<FileLedgerRepository> inAppDocuments() async {
    final dir = await getApplicationDocumentsDirectory();
    return FileLedgerRepository(directoryPath: dir.path);
  }

  File get _ledger => File('$directoryPath/$_ledgerName');
  File get _undo => File('$directoryPath/$_undoName');

  @override
  Future<String?> readLedger() => _readOrNull(_ledger);

  @override
  Future<void> writeLedger(String json) => _atomicWrite(_ledger, json);

  @override
  Future<String?> readUndoSnapshot() => _readOrNull(_undo);

  @override
  Future<void> writeUndoSnapshot(String json) => _atomicWrite(_undo, json);

  @override
  Future<void> clearUndoSnapshot() => _deleteQuietly(_undo);

  @override
  Future<void> clearLedger() async {
    await _deleteQuietly(_ledger);
    await _deleteQuietly(_undo);
  }

  Future<String?> _readOrNull(File f) async {
    // readAsString throws if the file is absent; treat absent as "nothing
    // stored" (null), the same as SharedPreferences.getString on a missing key.
    // A present-but-garbage file returns its bytes; validating them is the
    // store's job (sanitize/jsonDecode), unchanged, so a corrupt file surfaces
    // as the store's existing loadError rather than a crash here.
    if (!await f.exists()) return null;
    return f.readAsString();
  }

  /// Write [content] so that a crash leaves [target] either its previous
  /// complete contents or the new complete contents, never a torn file.
  ///
  /// flush: true fsyncs the temp file's bytes to the disk before the rename, so
  /// the rename cannot expose a file whose contents are still only in the OS
  /// page cache. The temp file sits in the SAME directory as the target so the
  /// rename stays within one filesystem, where POSIX guarantees it is atomic.
  Future<void> _atomicWrite(File target, String content) async {
    await Directory(directoryPath).create(recursive: true);
    final tmp = File('${target.path}.tmp');
    await tmp.writeAsString(content, flush: true);
    await tmp.rename(target.path);
  }

  Future<void> _deleteQuietly(File f) async {
    try {
      if (await f.exists()) await f.delete();
      final tmp = File('${f.path}.tmp');
      if (await tmp.exists()) await tmp.delete();
    } catch (_) {
      // A missing file is already the desired state; never let cleanup throw.
    }
  }
}
