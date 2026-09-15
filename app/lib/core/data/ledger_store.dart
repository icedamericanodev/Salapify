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
  ///
  /// QUEUED like every write, and that is not belt-and-braces. It REPLACES
  /// `_data` wholesale, so a load that lands while a save is queued leaves the
  /// queued operation to deep-copy whatever the load just installed. Today the
  /// only caller runs before `runApp`, so nothing can race it, but restore and
  /// unlock are both loads that happen with the app alive and a sheet possibly
  /// mid-save. The class's whole promise is one writer at a time, and a
  /// wholesale replacement that skipped the queue would be the one exception
  /// nobody remembered.
  Future<void> load() => _enqueue(() async {
    final raw = await _repo.readLedger();
    if (raw == null || raw.isEmpty) {
      _data = sanitizeData(const <String, dynamic>{});
      _unreadable = null;
      _loaded = true;
      notifyListeners();
      return;
    }
    try {
      _data = sanitizeData(jsonDecode(raw));
      _unreadable = null;
    } catch (e) {
      // A STORED LEDGER THAT WILL NOT DECODE MUST NOT TAKE THE APP DOWN, AND
      // MUST NOT BE OVERWRITTEN.
      //
      // Before this, `jsonDecode` ran unguarded here and `main.dart` awaits
      // `load()` BEFORE `runApp`. So one unreadable blob threw on launch, every
      // launch, with no UI ever built: no screen to explain it, no button to
      // recover from, and on an offline-first app with no server that is the
      // whole ledger gone with no way back in. The window is small and real
      // (a write interrupted by a kill or a dying battery, a failing disk, a
      // bad restore) and the cost is total.
      //
      // Two things happen instead, and the second matters more than the first.
      // The app boots, with an EMPTY ledger in memory so every screen renders.
      // And nothing is written: the original bytes stay exactly where they are,
      // so whatever is still in them can be recovered later.
      //
      // The empty in-memory ledger is itself a hazard, which is what
      // [unreadable] and the write guard below exist for. A user who logs an
      // entry into that empty ledger would persist it OVER the damaged blob and
      // finish the job the corruption started. So while this is set, writes are
      // refused rather than allowed to look like they worked.
      _unreadable = e.toString();
      _data = sanitizeData(const <String, dynamic>{});
    }
    _loaded = true;
    notifyListeners();
  });

  String? _unreadable;

  /// Why the stored ledger could not be read, or null when it was fine.
  ///
  /// When this is set the in-memory ledger is EMPTY but the stored one is not:
  /// it is damaged and still on disk, untouched. The app is readable but must
  /// not be written to until somebody decides what to do, so [mutate] and
  /// [apply] both refuse.
  String? get unreadable => _unreadable;

  /// Whether the stored ledger failed to decode on the last [load].
  bool get isUnreadable => _unreadable != null;

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
        _refuseIfUnreadable();
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
    _refuseIfUnreadable();
    final copy = jsonDecode(jsonEncode(_data)) as Map<String, dynamic>;
    await _commit(sanitizeData(change(copy)));
  });

  /// Refuse to write while the stored ledger is damaged.
  ///
  /// Loudly, by throwing, and never by quietly doing nothing. A silent no-op
  /// would tell the user their entry saved when it did not, which is the exact
  /// failure the whole persist-then-swap-then-notify order exists to prevent.
  ///
  /// Thrown INSIDE the queued callback, so the failure reaches the awaiting
  /// caller the same way a failed disk write does and every caller that already
  /// handles one handles this too.
  void _refuseIfUnreadable() {
    if (_unreadable == null) return;
    throw StateError(
      'The saved ledger on this device could not be read, so writing now '
      'would replace it with an empty one. Restore from a backup first.',
    );
  }

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
  /// Set this to hear about a write that failed with nobody awaiting it.
  ///
  /// Chaining `catchError` onto the returned future to keep the queue alive has
  /// a side effect that is easy to miss: it marks the error HANDLED, so a
  /// fire-and-forget caller that used to produce a loud unhandled async error
  /// now gets total silence. An awaiting caller is unaffected and still throws.
  ///
  /// Today the only fire-and-forget writer is the debug sample-data button, so
  /// the blast radius is small. The two writers coming next, recurring
  /// auto-posting and the net worth snapshot, both fire at launch with nobody
  /// awaiting them, and both would have failed invisibly.
  void Function(Object error)? onUnawaitedWriteError;

  Future<void> _enqueue(Future<void> Function() op) {
    final next = _queue.then((_) => op());
    // A failed write must not poison the queue for every write after it, and
    // the caller still gets the real error through `next`.
    _queue = next.catchError((Object e) {
      onUnawaitedWriteError?.call(e);
    });
    return next;
  }

  Future<void> _queue = Future<void>.value();
}
