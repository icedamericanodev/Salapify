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

import 'package:salapify/core/data/backup.dart';
import 'package:salapify/core/data/ledger_repository.dart';
import 'package:salapify/core/data/ledger_store.dart';

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

/// A LIVED-IN ledger: two accounts with real balances, the default categories,
/// and a few days of entries.
///
/// Deliberately not empty, and deliberately not tidy. The shipped app's render
/// harness spent most of its life shooting an EMPTY store, so sixteen images
/// at two brightnesses were all first-run welcome screens and not one of them
/// ever contained a peso figure; a crossed-out peso sign survived dozens of
/// renders and reached the founder's phone. A fixture that cannot show the
/// defect makes "look at the screen" a ritual.
Map<String, dynamic> livedIn() => {
  'schemaVersion': 12,
  // The eight defaults, present because a REAL ledger has them and because
  // leaving them out quietly disabled every category guess: the parser checks
  // a guessed id against the live list before using it, so an empty list means
  // no category is ever suggested. The journey test caught that, and the rule
  // was working exactly as written; the fixture was the thing that was wrong.
  'categories': defaultCategories.map((c) => {...c}).toList(),
  'accounts': [
    {'id': 'a_gcash', 'name': 'GCash', 'kind': 'ewallet', 'balance': 8410.50},
    {'id': 'a_bpi', 'name': 'BPI', 'kind': 'bank', 'balance': 42300.00},
    {'id': 'a_cash', 'name': 'Cash', 'kind': 'cash', 'balance': 1250.00},
  ],
  'transactions': [
    {
      'id': 't1',
      'type': 'income',
      'amount': 18500.00,
      'label': 'Sweldo',
      'date': '2026-09-11',
      'accountId': 'a_bpi',
    },
    {
      'id': 't2',
      'type': 'expense',
      'amount': 3200.00,
      'label': 'Meralco',
      'date': '2026-09-11',
      'accountId': 'a_bpi',
      'categoryId': 'cat_bills',
    },
    {
      'id': 't3',
      'type': 'expense',
      'amount': 250.00,
      'label': 'Jollibee',
      'date': '2026-09-12',
      'accountId': 'a_gcash',
      'categoryId': 'cat_food',
    },
    {
      'id': 't4',
      'type': 'expense',
      'amount': 45.00,
      'label': 'Pamasahe',
      'date': '2026-09-12',
      'accountId': 'a_cash',
      'categoryId': 'cat_transport',
    },
    {
      'id': 't5',
      'type': 'expense',
      'amount': 2450.50,
      'label': 'Groceries',
      'date': '2026-09-12',
      'accountId': 'a_gcash',
      'categoryId': 'cat_groceries',
    },
    {
      'id': 't6',
      'type': 'expense',
      'amount': 100.00,
      'label': 'Load',
      'date': '2026-09-13',
      'accountId': 'a_gcash',
      'categoryId': 'cat_load',
    },
    {
      'id': 't7',
      'type': 'transfer',
      'amount': 5000.00,
      'label': 'To GCash',
      'date': '2026-09-13',
      'accountId': 'a_bpi',
      'flow': 'out',
    },
  ],
};
