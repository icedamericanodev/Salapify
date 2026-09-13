// The one place the decoded ledger lives, and deliberately almost nothing else.
//
// The app this replaces has data/store.dart at 3,196 lines: the blob, every
// mutation for every feature, and the notifying, all in one class that every
// screen reached into. docs/revamp/02-architecture.md names it as the mistake
// to avoid, so it is not ported. This file is the part of its job that was
// always sound.
//
// What belongs here: loading, holding, saving, and telling listeners. What does
// NOT: anything that knows what a debt is. A feature that needs to change money
// owns a view model that reads from here and writes back through [mutate], and
// when that view model grows it grows in its own file rather than in this one.
// That single rule is what keeps the 3,196 lines from reassembling themselves.
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'backup.dart';
import 'ledger_repository.dart';

/// Where the money is, in memory, decoded.
///
/// Every read is a plain map because that is what the engine in core/money
/// takes: 66 files of pure functions over `Map<String, dynamic>`, golden locked
/// to the centavo. Typing the ledger into classes here would mean converting
/// back at every call site, so the maps stay and the types live at the edges.
class LedgerStore extends ChangeNotifier {
  LedgerStore(this._repo);

  final LedgerRepository _repo;

  Map<String, dynamic> _data = const {};
  bool _loaded = false;

  /// The ledger. Read only by convention, because Dart cannot enforce it on a
  /// nested map: a caller that mutates this in place will not notify anyone and
  /// will not persist. Go through [mutate].
  Map<String, dynamic> get data => _data;

  /// False until [load] finishes. A screen that renders before this is true is
  /// rendering an empty ledger, which looks exactly like a wiped one.
  bool get loaded => _loaded;

  /// Read what is on disk and make it usable.
  ///
  /// Everything goes through sanitizeData, the same choke point the shipped app
  /// uses: it applies the forward-only migrations, fills defaults, and refuses
  /// a blob from a NEWER schema loudly rather than silently dropping the fields
  /// it does not understand.
  ///
  /// A missing or empty store is a first run, not an error.
  Future<void> load() async {
    final raw = await _repo.readLedger();
    _data = (raw == null || raw.isEmpty)
        ? sanitizeData(const <String, dynamic>{})
        : sanitizeData(jsonDecode(raw));
    _loaded = true;
    notifyListeners();
  }

  /// Change the ledger and persist the result.
  ///
  /// [change] is handed a COPY, so a half-finished mutation that throws cannot
  /// leave the in-memory ledger in a state nobody designed. The new blob only
  /// becomes the live one after sanitizeData has accepted it and the write has
  /// returned.
  ///
  /// The order matters and is the opposite of what is convenient: persist
  /// first, then swap, then notify. A UI that updates before the write lands
  /// tells the founder their money is saved when it may not be.
  Future<void> mutate(void Function(Map<String, dynamic> draft) change) async {
    final draft = jsonDecode(jsonEncode(_data)) as Map<String, dynamic>;
    change(draft);
    final next = sanitizeData(draft);
    await _repo.writeLedger(jsonEncode(next));
    _data = next;
    notifyListeners();
  }
}
