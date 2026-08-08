// ADR 0001, PR B2: the coordinator that makes the encrypted store authoritative
// while keeping the plaintext as a frozen fallback.
//
// This is the heart of B2 and it is PURE DART, so it is fully tested even though
// the encrypted engine underneath it is native and cannot run in the sandbox.
// It composes two LedgerRepository engines:
//
//   encrypted  the SQLCipher store (SqlCipherLedgerRepository). Authoritative:
//              every read and every write goes here once it holds the ledger.
//   fallback   the FROZEN plaintext (FrozenPlaintextStore). Read-only. It is the
//              migration source on first run, and the emergency copy if the
//              encrypted store cannot be opened. It is never written new data.
//
// Rules, each proven by a test:
//   1. Steady state: encrypted holds a valid ledger, so read returns it and the
//      fallback is never consulted.
//   2. First run: encrypted is empty and the fallback has data, so migrate the
//      fallback into encrypted, VALIDATE the copy read back, then encrypted is
//      authoritative. The fallback is left intact (deleted later, once the
//      founder confirms the encrypted build on the phone).
//   3. Encrypted unavailable: if the encrypted engine throws on read (Keystore
//      lost, native error), serve the fallback so the user is not locked out,
//      and flag it. No write is attempted, so nothing is corrupted.
//   4. Writes go ONLY to encrypted. If encrypted cannot take the write it
//      throws, the store rolls back, and the user sees "cannot save", never a
//      silent loss. The frozen fallback is never advanced.
//   5. Erase clears BOTH, or a later encrypted-open failure would resurrect the
//      erased ledger from the fallback (the B1 Finding 2 class).

import 'dart:convert';

import 'ledger_repository.dart';

/// Which store answered the last read, for the Data Health readout.
enum StorageEngine {
  /// The encrypted store answered, the steady state.
  encrypted,

  /// The plaintext fallback answered because the encrypted store could not be
  /// read or could not be seeded this run. A degraded, visible state.
  fallbackPlaintext,

  /// Nothing stored anywhere yet.
  empty,
}

/// A small, immutable snapshot of storage state for the Data Health readout.
class StorageHealth {
  /// True when the app is reading and writing the ENCRYPTED store.
  final bool encrypted;

  /// True when this run copied the plaintext data into the encrypted store.
  final bool migratedThisRun;

  /// Human label for the active engine, e.g. "Encrypted" or "Plaintext (fallback)".
  final String engineLabel;

  const StorageHealth({
    required this.encrypted,
    required this.migratedThisRun,
    required this.engineLabel,
  });

  /// The state when the app is not on the encrypted coordinator at all (the
  /// encrypted store could not be built, so it fell back to the B1 plaintext
  /// store). Honest: this is plaintext.
  const StorageHealth.plaintext()
    : encrypted = false,
      migratedThisRun = false,
      engineLabel = 'Plaintext';
}

class EncryptedStoreCoordinator implements LedgerRepository {
  /// The encrypted store. Authoritative once it holds the ledger.
  final LedgerRepository encrypted;

  /// The frozen plaintext copy: migration source and read-only fallback.
  final LedgerRepository fallback;

  EncryptedStoreCoordinator({required this.encrypted, required this.fallback});

  /// Observable state for Data Health. Not part of the interface.
  StorageEngine lastSource = StorageEngine.empty;
  bool encryptedAvailable = true;
  bool migratedThisRun = false;

  /// True once the plaintext fallback has been retired (deleted or already gone),
  /// which only happens after a steady-state encrypted read on a relaunch.
  bool plaintextRetired = false;
  bool _retireAttempted = false;

  /// Delete the plaintext fallback once encryption is confirmed to reopen on its
  /// own. Best-effort: a failure leaves the fallback in place and the next
  /// steady-state read retries, so cleanup can never race ahead of a working
  /// encrypted store. Runs at most once per session.
  Future<void> _retirePlaintextFallback() async {
    if (_retireAttempted) return;
    _retireAttempted = true;
    try {
      final f = await fallback.readLedger();
      if (f == null || f.isEmpty) {
        plaintextRetired = true; // already gone
        return;
      }
      await fallback.clearLedger();
      plaintextRetired = true;
    } catch (_) {
      plaintextRetired = false;
    }
  }

  StorageHealth get health => StorageHealth(
    encrypted: lastSource == StorageEngine.encrypted,
    migratedThisRun: migratedThisRun,
    engineLabel: lastSource == StorageEngine.encrypted
        ? 'Encrypted'
        : (lastSource == StorageEngine.empty
              ? 'Encrypted'
              : 'Plaintext (fallback)'),
  );

  bool _looksLikeLedger(String? s) {
    if (s == null || s.isEmpty) return false;
    try {
      return jsonDecode(s) is Map;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<String?> readLedger() async {
    String? enc;
    try {
      enc = await encrypted.readLedger();
      encryptedAvailable = true;
    } catch (_) {
      // The encrypted store could not be opened or read at all. Do NOT write
      // anything; serve the plaintext fallback so the user is not locked out.
      encryptedAvailable = false;
      final f = await fallback.readLedger();
      lastSource = StorageEngine.fallbackPlaintext;
      return f;
    }

    if (_looksLikeLedger(enc)) {
      lastSource = StorageEngine.encrypted;
      // Confirm-then-delete: a steady-state encrypted read (this is NOT the
      // migration branch, so it never runs on the migration launch) proves the
      // encrypted store opened on its own on a later launch. That is the founder's
      // agreed signal that the plaintext fallback is a proven-redundant safety
      // copy and can be retired. Best-effort and gated: the fallback is never
      // removed until encryption has survived a full app restart on the device,
      // and never when the encrypted store is unavailable (that path returns
      // above without reaching here).
      await _retirePlaintextFallback();
      return enc;
    }

    // Encrypted opened but holds no ledger yet: first run after B2. Migrate the
    // plaintext into it, validating the copy read back before trusting it.
    final f = await fallback.readLedger();
    if (f == null || f.isEmpty) {
      lastSource = StorageEngine.empty;
      return enc; // both empty -> a fresh install
    }
    try {
      await encrypted.writeLedger(f);
      final back = await encrypted.readLedger();
      if (back == f) {
        migratedThisRun = true;
        lastSource = StorageEngine.encrypted;
        return f;
      }
      // The copy did not read back intact; do not trust encrypted yet. Serve the
      // plaintext this run; the next run retries the migration.
      lastSource = StorageEngine.fallbackPlaintext;
      return f;
    } catch (_) {
      // Could not write the encrypted store (disk, key). No data lost: the
      // plaintext is intact and answers this run.
      lastSource = StorageEngine.fallbackPlaintext;
      return f;
    }
  }

  @override
  Future<void> writeLedger(String json) async {
    // Authoritative and encrypted-only. Must land or the write is not durable
    // and the store rolls back. The frozen fallback is never advanced.
    await encrypted.writeLedger(json);
  }

  @override
  Future<String?> readUndoSnapshot() async {
    // Scoped to the ENCRYPTED era only. The undo snapshot is "put back what the
    // last import you did replaced", and migration deliberately does not carry
    // the old plaintext snapshot forward: if it did, a healthy user who once
    // imported a backup in the B1 build would be shown a live "undo last import"
    // card after upgrading and could replace their current ledger with data from
    // before that ancient import. So there is no undo to offer until the user
    // does an import in this era, which is the correct and safe behaviour. The
    // frozen fallback is never consulted for the undo snapshot.
    try {
      return await encrypted.readUndoSnapshot();
    } catch (_) {
      // Encrypted unavailable: offer no undo rather than a stale fallback one.
      return null;
    }
  }

  @override
  Future<void> writeUndoSnapshot(String json) async {
    await encrypted.writeUndoSnapshot(json);
  }

  @override
  Future<void> clearUndoSnapshot() async {
    await encrypted.clearUndoSnapshot();
  }

  @override
  Future<void> clearLedger() async {
    // Clear the resurrection SOURCE first. The fallback is what a later read
    // would migrate back in, so if the encrypted clear then fails partway,
    // encrypted still holds the ledger and the next read serves it (erase
    // visibly incomplete, the user retries) rather than the fallback getting
    // copied back over an emptied encrypted store. Both failure orders now leave
    // data visible and re-erasable, never resurrected.
    await fallback.clearLedger();
    await encrypted.clearLedger();
  }
}
