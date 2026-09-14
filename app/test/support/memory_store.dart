// An in-memory ledger for widget tests.
//
// Shared rather than copied into each test file, because the alternative is
// five slightly different fakes that drift, and then a test passing because
// its own fake is lenient rather than because the app is right.
//
// ledger_store_test.dart deliberately keeps its OWN fake: it asserts the exact
// order of read, write and notify, so it needs a repository that records what
// happened to it. That is a different job from this one, which is only "hold
// some JSON so a screen has something to draw".
import 'dart:convert';

import 'package:salapify/core/data/ledger_repository.dart';
import 'package:salapify/core/data/ledger_store.dart';
import 'package:salapify/dev/sample_ledger.dart';

class MemoryRepo implements LedgerRepository {
  MemoryRepo([this._ledger]);

  String? _ledger;
  String? _undo;

  @override
  Future<String?> readLedger() async => _ledger;

  @override
  Future<void> writeLedger(String json) async => _ledger = json;

  @override
  Future<String?> readUndoSnapshot() async => _undo;

  @override
  Future<void> writeUndoSnapshot(String json) async => _undo = json;

  @override
  Future<void> clearUndoSnapshot() async => _undo = null;

  @override
  Future<void> clearLedger() async => _ledger = null;

  /// What is actually persisted, for asserting that a save survived.
  Map<String, dynamic>? get stored =>
      _ledger == null ? null : jsonDecode(_ledger!) as Map<String, dynamic>;
}

/// A loaded store over [seed], or over an empty ledger when seed is null.
Future<LedgerStore> memoryStore([Map<String, dynamic>? seed]) async {
  final store = LedgerStore(MemoryRepo(seed == null ? null : jsonEncode(seed)));
  await store.load();
  return store;
}

/// The lived-in ledger, pinned to a fixed date.
///
/// The data itself moved to `lib/dev/sample_ledger.dart` so the APP can reach
/// it too. That is the whole point: the screens the founder reviews in a
/// screenshot and the screens they see on an emulator are now fed by the same
/// thing. Before this they were a rich fixture and a completely empty store,
/// and a defect visible in one and not the other had nowhere to be caught.
///
/// Pinned here and only here. Tests need a fixed clock or they pass only on the
/// days somebody happened to run them; the app passes nothing and gets today.
Map<String, dynamic> livedIn() => sampleLedger(today: sampleAnchor);
