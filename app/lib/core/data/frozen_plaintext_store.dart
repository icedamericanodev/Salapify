// ADR 0001, PR B2: the frozen plaintext store, the migration source and the
// emergency fallback.
//
// After B2 makes the encrypted store authoritative, the OLD plaintext data
// (the B1 world) is not deleted yet. The founder chose to keep it as a
// read-only fallback for one release, so that if the encrypted store cannot be
// opened on a specific phone (a rare Keystore key-loss case), the app reads the
// plaintext copy rather than showing an empty or locked ledger. A later, small,
// separately flagged change deletes it once the encrypted build is confirmed on
// the phone.
//
// "Frozen" means new writes never land here: the coordinator writes only to the
// encrypted store. The one exception is ERASE. clearLedger MUST wipe the
// plaintext too, or a later encrypted-open failure would serve this copy and
// resurrect data the user deliberately erased, which is exactly the B1 Finding 2
// class of bug. So writes are no-ops, but clears are real.
//
// It reads from the B1 world in the order that world was authoritative:
// SharedPreferences first (B1 kept it as the source of truth), then the file
// shadow only if SharedPreferences is somehow empty. This also covers a phone
// that jumped straight from a pre-B1 build to B2 and so only ever had the
// SharedPreferences copy.

import 'ledger_repository.dart';

class FrozenPlaintextStore implements LedgerRepository {
  /// The B1 source of truth (SharedPreferences). Read first.
  final LedgerRepository prefs;

  /// The B1 crash-safe shadow (file). Read only if [prefs] is empty; in a normal
  /// B1 install the two are identical.
  final LedgerRepository file;

  FrozenPlaintextStore({required this.prefs, required this.file});

  @override
  Future<String?> readLedger() async {
    final p = await prefs.readLedger();
    if (p != null && p.isNotEmpty) return p;
    return file.readLedger();
  }

  @override
  Future<String?> readUndoSnapshot() async {
    final p = await prefs.readUndoSnapshot();
    if (p != null && p.isNotEmpty) return p;
    return file.readUndoSnapshot();
  }

  // Frozen: the coordinator never routes a new write here, so these are no-ops.
  // Documented rather than throwing, so an accidental future caller degrades to
  // "the plaintext copy did not advance" (harmless, it is only a fallback)
  // rather than crashing a write path.
  @override
  Future<void> writeLedger(String json) async {}

  @override
  Future<void> writeUndoSnapshot(String json) async {}

  @override
  Future<void> clearUndoSnapshot() async {}

  @override
  Future<void> clearLedger() async {
    // Erase is real and clears BOTH plaintext copies, or an encrypted-open
    // failure could later resurrect erased data from here.
    await prefs.clearLedger();
    await file.clearLedger();
  }
}
