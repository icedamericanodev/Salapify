// The persistence boundary for the ledger (ADR 0001, PR A).
//
// Everything above this line, the store and the UI, depends on the
// LedgerRepository interface and never on SharedPreferences or any concrete
// storage engine. That is the whole point: the engine can later be swapped for
// the encrypted, durable store the ADR describes without touching a single
// caller, because callers only know this interface.
//
// The boundary deals in the raw ledger JSON STRING, not a decoded map, on
// purpose. The store owns sanitize, migrate, id-repair, and every money rule,
// all golden-locked to the React Native engine; moving any of that behind the
// boundary would change behaviour. This interface's only job is durable bytes
// in and out, plus the one-step undo snapshot that the import safety net needs.
//
// This PR adds ONLY the interface and a SharedPreferences implementation that
// does exactly what the store did inline before, so there is no behaviour
// change. The encrypted implementation is a later, separately-approved PR.

import 'package:shared_preferences/shared_preferences.dart';

/// The SharedPreferences key the ledger blob lives under.
///
/// Canonical home moved here from store.dart when the repository boundary was
/// introduced; store.dart re-exports it, so every existing importer is
/// unchanged.
const String storageKey = 'salapify_data_v2';

/// The blob being replaced by an import survives here until the next import,
/// one step of on-disk undo for the most destructive action in the app.
const String previousBackupKey = 'salapify_data_v2_prev';

/// The persistence boundary. Callers depend on this, never on a concrete engine.
///
/// Every method is the unit of durability it names: a caller that awaits
/// [writeLedger] without it throwing may treat the write as committed, and a
/// caller that catches a throw must treat the write as NOT committed. That
/// contract is what lets the store keep its "never report a save that did not
/// land, never overwrite an unreadable ledger" invariants across any engine.
abstract interface class LedgerRepository {
  /// The persisted ledger JSON, or null when nothing is stored yet.
  Future<String?> readLedger();

  /// Persist the ledger JSON. Throws if the write did not durably land.
  Future<void> writeLedger(String json);

  /// The pre-import undo snapshot JSON, or null when there is none.
  Future<String?> readUndoSnapshot();

  /// Persist the pre-import undo snapshot.
  Future<void> writeUndoSnapshot(String json);

  /// Remove the pre-import undo snapshot.
  Future<void> clearUndoSnapshot();

  /// Remove the ledger AND its undo snapshot, the "start fresh" ledger reset.
  /// Other subsystems (the FX cache, the diagnostics log) clear themselves;
  /// this is the ledger's two keys only, exactly as before.
  Future<void> clearLedger();
}

/// The default engine: the same SharedPreferences reads and writes the store
/// did inline before the boundary existed. Behaviour-identical on purpose.
class SharedPrefsLedgerRepository implements LedgerRepository {
  const SharedPrefsLedgerRepository();

  @override
  Future<String?> readLedger() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(storageKey);
  }

  @override
  Future<void> writeLedger(String json) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(storageKey, json);
  }

  @override
  Future<String?> readUndoSnapshot() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(previousBackupKey);
  }

  @override
  Future<void> writeUndoSnapshot(String json) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(previousBackupKey, json);
  }

  @override
  Future<void> clearUndoSnapshot() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(previousBackupKey);
  }

  @override
  Future<void> clearLedger() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(storageKey);
    await prefs.remove(previousBackupKey);
  }
}
