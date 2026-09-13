// ADR 0001, PR B1: the durable file store as a VALIDATED SHADOW.
//
// This composes two LedgerRepository engines behind the same interface:
//
//   source  the old SharedPreferences store. AUTHORITATIVE. Every read is
//           answered from here, exactly as before this PR, so B1 changes
//           nothing about which bytes the app trusts.
//   shadow  the new durable file store (FileLedgerRepository). A crash-safe
//           COPY that is written alongside source and kept in step, but is
//           NEVER read back as the source of truth in B1.
//
// Why a shadow and not an authority swap. An earlier version of this PR made
// the file store authoritative and dual-wrote to SharedPreferences as a revert
// mirror. A pre-merge review found two ways that lost data, both proven with a
// test: (1) a file that was valid but OLDER than SharedPreferences (after a
// code rollback, or a session where the file store failed to open) was trusted
// over the newer SharedPreferences copy, and the stale copy then overwrote the
// good one; (2) a "start fresh" interrupted partway left the file cleared and
// SharedPreferences intact, which the next launch misread as a first run and
// used to RESURRECT the just-erased ledger. Both turn on the same gap: two
// independently-writable stores with no reliable "which is newer" signal.
//
// The safe answer for an over-the-air step is not to hand-roll that signal, it
// is to not need it: keep the single existing source of truth, and treat the
// file purely as a copy. Reads come from source, so a stale or half-cleared
// shadow can never override or resurrect anything. The file store is still
// built, exercised on real devices, and kept continuously in sync, so PR B2
// (the native encrypted SQLCipher engine, a transactional database that owns
// "which is newer" correctly) can promote it to authority with the data
// already present and validated.
//
// It exposes a little observable state (whether the shadow matches source,
// whether the last shadow write succeeded) for the Data Health primitives.
// None of that is part of the interface.

import 'file_ledger_repository.dart';
import 'ledger_repository.dart';

class DurableLedgerRepository implements LedgerRepository {
  /// The old store. Authoritative: every read is answered from here.
  final LedgerRepository source;

  /// The new durable file store. A crash-safe copy, written alongside source
  /// and kept in step, but never read back as the source of truth in B1.
  final LedgerRepository shadow;

  DurableLedgerRepository({required this.source, required this.shadow});

  /// The engine the app runs on: the old SharedPreferences store as the source
  /// of truth, with the atomic file store shadowing it.
  ///
  /// If the file store cannot even be created (path_provider unavailable, no
  /// writable documents directory), fall back to SharedPreferences ALONE, the
  /// exact behaviour before this PR. That fallback is safe precisely because
  /// source is already authoritative: there is no stale shadow that a later run
  /// could wrongly trust.
  static Future<LedgerRepository> buildDefault() async {
    try {
      final file = await FileLedgerRepository.inAppDocuments();
      return DurableLedgerRepository(
        source: const SharedPrefsLedgerRepository(),
        shadow: file,
      );
    } catch (_) {
      return const SharedPrefsLedgerRepository();
    }
  }

  /// Observable state for Data Health. Not part of the interface.
  /// True when the shadow copy matched source at the last read or write.
  bool shadowInSync = false;

  /// True when the last shadow write succeeded. A false here means the crash-safe
  /// copy is behind; it does NOT mean any data is at risk, because source is the
  /// one the app reads.
  bool lastShadowWriteOk = true;

  @override
  Future<String?> readLedger() async {
    // Source is the truth. Full stop.
    final s = await source.readLedger();
    // Best-effort: keep the shadow current so B2 inherits an up-to-date copy.
    // This NEVER changes what we return, and never lets the shadow win.
    try {
      final sh = await shadow.readLedger();
      final sourceEmpty = s == null || s.isEmpty;
      if (sourceEmpty) {
        shadowInSync = sh == null || sh.isEmpty;
      } else if (sh != s) {
        // The shadow is absent or behind (first run, or it fell behind during a
        // session where it could not be written). Catch it up from source.
        await shadow.writeLedger(s);
        shadowInSync = true;
      } else {
        shadowInSync = true;
      }
    } catch (_) {
      // A shadow that cannot be read or seeded is a degraded copy, not a data
      // risk. Record it and carry on with the authoritative answer.
      shadowInSync = false;
    }
    return s;
  }

  @override
  Future<void> writeLedger(String json) async {
    // Authoritative write first: it MUST land, or the write is not durable and
    // the store rolls back, so let it throw.
    await source.writeLedger(json);
    // Shadow write is best-effort. source already holds the truth, so a shadow
    // failure only leaves the crash-safe copy behind; it must never fail the
    // write.
    try {
      await shadow.writeLedger(json);
      lastShadowWriteOk = true;
      shadowInSync = true;
    } catch (_) {
      lastShadowWriteOk = false;
      shadowInSync = false;
    }
  }

  @override
  Future<String?> readUndoSnapshot() => source.readUndoSnapshot();

  @override
  Future<void> writeUndoSnapshot(String json) async {
    await source.writeUndoSnapshot(json);
    try {
      await shadow.writeUndoSnapshot(json);
    } catch (_) {
      // Best-effort, same as the ledger shadow.
    }
  }

  @override
  Future<void> clearUndoSnapshot() async {
    await source.clearUndoSnapshot();
    try {
      await shadow.clearUndoSnapshot();
    } catch (_) {}
  }

  @override
  Future<void> clearLedger() async {
    // source is authoritative and is what the next read returns, so clearing it
    // is what makes the erase real. A leftover shadow (if its clear fails or the
    // process dies between the two) can never resurrect the data, because the
    // shadow is never read back as truth. That is the whole safety of this
    // design: erase is exactly as durable as the old single-store erase.
    await source.clearLedger();
    try {
      await shadow.clearLedger();
    } catch (_) {}
  }
}
