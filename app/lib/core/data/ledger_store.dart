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
  Future<void> mutate(void Function(Map<String, dynamic> draft) change) =>
      _enqueue(() async {
        final draft = jsonDecode(jsonEncode(_data)) as Map<String, dynamic>;
        change(draft);
        await _commit(sanitizeData(draft));
      });

  /// Change the ledger with a PURE function, and persist the result.
  ///
  /// This is the one features should reach for, because it is the shape the
  /// money engine already speaks. Every function in core/money takes a state
  /// and returns a new one:
  ///
  ///     store.apply((s) => addTransaction(s, tx));
  ///
  /// That line is the whole of saving an entry. `addTransaction` appends the
  /// transaction AND moves the linked account's balance by the signed amount,
  /// and it is golden locked to the centavo, so no screen ever computes a
  /// balance for itself. A feature that reaches past this to adjust a balance
  /// by hand is a bug, however small the adjustment looks.
  ///
  /// [change] receives a deep COPY, so a half-finished change that throws
  /// cannot leave the live ledger in a state nobody designed, and the result
  /// only becomes live after sanitizeData has accepted it and the write has
  /// returned. Same order as [mutate], for the same reason.
  Future<void> apply(
    Map<String, dynamic> Function(Map<String, dynamic> state) change,
  ) => _enqueue(() async {
    final copy = jsonDecode(jsonEncode(_data)) as Map<String, dynamic>;
    await _commit(sanitizeData(change(copy)));
  });

  /// Persist, then swap, then notify. Shared by [mutate] and [apply] so the
  /// two can never drift into different guarantees.
  ///
  /// The order is the opposite of convenient and that is the point: a UI that
  /// updates before the write lands tells the founder their money is saved
  /// when it may not be.
  Future<void> _commit(Map<String, dynamic> next) async {
    await _repo.writeLedger(jsonEncode(next));
    _data = next;
    notifyListeners();
  }

  /// ONE WRITER AT A TIME, and this is a correctness fix rather than a tidy-up.
  ///
  /// Both [mutate] and [apply] take a deep COPY of the ledger and then await a
  /// write that takes a real tenth of a second on a phone, because the
  /// repository is a platform channel round trip. Two writers that overlap
  /// inside that window both branch from the SAME copy, and the second write to
  /// land silently discards the first one's work. Nothing throws. Nothing is
  /// logged. The user is told both saves succeeded and one of them did not
  /// happen.
  ///
  /// This is not theoretical here. A guard test written for the editor sheets
  /// asserted "one account exists" after a double tap and PASSED with its guard
  /// deleted, because two overlapping saves produced two writes and one
  /// account: the second simply overwrote the first with an identical result.
  /// It only looks harmless while the two writers happen to be writing the same
  /// thing.
  ///
  /// The per-sheet `_saving` flags stay, and they are not made redundant by
  /// this: they stop one sheet popping the root navigator twice, which is a
  /// different bug. They are per-widget state, so they can say nothing at all
  /// about two DIFFERENT writers, and two of those are coming (recurring
  /// auto-posting and the net worth snapshot), both firing at launch with no
  /// sheet and no guard anywhere.
  ///
  /// The snapshot is taken INSIDE the queued callback on purpose. Taking it
  /// outside would queue the writes and leave the stale-copy problem exactly as
  /// it was, which is the shape of fix that looks right and changes nothing.
  Future<void> _enqueue(Future<void> Function() op) {
    final next = _queue.then((_) => op());
    // A failed write must not poison the queue for every write after it, and
    // the caller still gets the real error through `next`.
    _queue = next.catchError((_) {});
    return next;
  }

  Future<void> _queue = Future<void>.value();
}
