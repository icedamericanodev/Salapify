// ADR 0001, PR B1: the migration + dual-write coordinator.
//
// This composes two LedgerRepository engines behind the same interface:
//
//   primary  the new durable file store (FileLedgerRepository). Authoritative.
//   legacy   the old SharedPreferences store. Kept as a lossless revert mirror.
//
// It does three safety-critical things, and each is here rather than in the
// store so the store's load/save logic is unchanged:
//
//   1. Non-destructive migration. On the first run after this ships, primary is
//      absent and legacy holds the user's data. The first read copies legacy
//      into primary (atomically, via FileLedgerRepository) and VALIDATES the
//      copy read back byte-for-byte before trusting it. Legacy is never touched.
//
//   2. Dual-write. Every write lands in primary FIRST (authoritative, and it
//      must succeed or the write is not durable and the caller rolls back), then
//      is mirrored into legacy best-effort. Because legacy stays current, simply
//      reverting this PR, so the store talks to SharedPreferences again, loses
//      nothing. That is the recovery path each PR in this phase must preserve.
//
//   3. Self-heal on corruption. If primary is ever present but not a readable
//      ledger, the read falls back to the intact legacy copy and repairs primary
//      from it, rather than surfacing a corrupt primary as a load error while a
//      good copy sits in legacy. Corruption fails closed without losing data.
//
// It exposes a little observable state (the last read's source, whether the
// mirror is current, whether primary was found corrupt) for the Data Health
// primitives to report. None of that is part of the interface.

import 'dart:convert';

import 'file_ledger_repository.dart';
import 'ledger_repository.dart';

/// Where the last [DurableLedgerRepository.readLedger] got its answer.
enum LedgerSource {
  /// Read straight from the new durable store, the steady state.
  primary,

  /// First run: legacy was copied into primary this read.
  migratedFromLegacy,

  /// Primary could not be trusted this read (absent-then-unwritable, or
  /// corrupt), so legacy answered and primary repair was attempted.
  legacyFallback,

  /// Nothing stored anywhere yet (a fresh install).
  empty,
}

class DurableLedgerRepository implements LedgerRepository {
  /// The new durable store. Authoritative once it holds a valid ledger.
  final LedgerRepository primary;

  /// The old store, kept current as a lossless revert path.
  final LedgerRepository legacy;

  DurableLedgerRepository({required this.primary, required this.legacy});

  /// The engine the app runs on: the atomic file store in front of the old
  /// SharedPreferences store, so a plain revert of this PR loses nothing.
  ///
  /// If the file store cannot even be created (path_provider unavailable, no
  /// writable documents directory), fall back to SharedPreferences ALONE, the
  /// exact behaviour before this PR. Nobody is worse off than the old build,
  /// and startup never fails on persistence setup.
  static Future<LedgerRepository> buildDefault() async {
    try {
      final file = await FileLedgerRepository.inAppDocuments();
      return DurableLedgerRepository(
        primary: file,
        legacy: const SharedPrefsLedgerRepository(),
      );
    } catch (_) {
      return const SharedPrefsLedgerRepository();
    }
  }

  /// Observable state for Data Health. Not part of the interface.
  LedgerSource lastSource = LedgerSource.empty;
  bool lastMirrorOk = true;
  bool primaryWasCorrupt = false;

  /// A light gate to decide primary-vs-legacy: does this look like a ledger
  /// blob at all (a non-empty JSON object)? The store still does the real
  /// sanitize/migrate/id-repair; this only picks which copy to hand it.
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
    final p = await primary.readLedger();
    if (_looksLikeLedger(p)) {
      lastSource = LedgerSource.primary;
      primaryWasCorrupt = false;
      return p;
    }
    // Primary is absent or corrupt. Remember which, then answer from legacy and
    // try to (re)build primary from it. Legacy is never modified.
    primaryWasCorrupt = p != null;
    final l = await legacy.readLedger();
    if (l == null || l.isEmpty) {
      // Nothing to migrate. A corrupt primary with an empty legacy is not
      // expected in normal use; leave primary as-is (the store's own loadError
      // guard still protects the user) rather than wiping either side.
      lastSource = LedgerSource.empty;
      return l;
    }
    try {
      await primary.writeLedger(l);
      final back = await primary.readLedger();
      lastSource = (back == l && !primaryWasCorrupt)
          ? LedgerSource.migratedFromLegacy
          : LedgerSource.legacyFallback;
    } catch (_) {
      // Could not build primary (disk full, key access, etc.). No data is lost:
      // legacy is intact and answers this run; the next run retries.
      lastSource = LedgerSource.legacyFallback;
    }
    return l;
  }

  @override
  Future<void> writeLedger(String json) async {
    // Authoritative write first: it MUST land, or the write is not durable and
    // the store must roll back, so let it throw.
    await primary.writeLedger(json);
    // Mirror best-effort. Primary is already durable, so a mirror failure must
    // never fail the write; it only degrades the revert path, which Data Health
    // surfaces.
    try {
      await legacy.writeLedger(json);
      lastMirrorOk = true;
    } catch (_) {
      lastMirrorOk = false;
    }
  }

  @override
  Future<String?> readUndoSnapshot() async {
    final p = await primary.readUndoSnapshot();
    if (p != null && p.isNotEmpty) return p;
    return legacy.readUndoSnapshot();
  }

  @override
  Future<void> writeUndoSnapshot(String json) async {
    await primary.writeUndoSnapshot(json);
    try {
      await legacy.writeUndoSnapshot(json);
    } catch (_) {
      // Best-effort, same as the ledger mirror.
    }
  }

  @override
  Future<void> clearUndoSnapshot() async {
    await primary.clearUndoSnapshot();
    try {
      await legacy.clearUndoSnapshot();
    } catch (_) {}
  }

  @override
  Future<void> clearLedger() async {
    // Start fresh wipes everything, both stores, or a later revert would
    // resurrect data the user chose to erase.
    await primary.clearLedger();
    await legacy.clearLedger();
  }
}
