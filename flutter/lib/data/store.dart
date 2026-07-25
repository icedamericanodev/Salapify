// The on-device store: one sanitized data map, persisted as one JSON string
// under the same key idea as the RN app (salapify_data_v2). Every blob that
// enters, whether loaded from disk or pasted as a backup, passes through
// sanitizeData or parseBackupObject first, so the store can never hold a
// shape the app would crash on. ChangeNotifier keeps the UI in sync without
// any extra state library.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dart:math';

import '../money/lesson_progress.dart';
import '../money/ledger.dart' as ledger;
import '../money/debts.dart' as debts;
import '../money/receivables.dart' as receivables;
import '../money/recurring.dart' as recurring;
import '../money/treats.dart' as treats;
import '../money/paluwagan.dart' as paluwagan;
import '../money/splits.dart' as splits;
import 'backup.dart';
import 'fx_service.dart' show FxService;

const String storageKey = 'salapify_data_v2';

/// The blob being replaced by an import survives here until the next import,
/// one step of on-disk undo for the most destructive action in the app.
const String previousBackupKey = 'salapify_data_v2_prev';

/// Transaction ids must be present and unique before the store accepts a
/// blob: removeTransaction drops every row matching an id but reverses the
/// balance only once, so a duplicated id in a merged or hand-edited backup
/// would let one delete silently swallow money, and a missing id makes a row
/// unfindable. This runs AFTER sanitizeData on purpose: sanitizeData is
/// parity-locked to the RN engine by the backup goldens, so this Flutter-side
/// guard lives at the store boundary instead. Restored ids are deterministic.
Map<String, dynamic> ensureUniqueTxnIds(Map<String, dynamic> data) {
  final txs = (data['transactions'] as List).cast<Map<String, dynamic>>();
  final seen = <String>{};
  final duplicated = <String>{};
  var restored = 0;
  var changed = false;
  final out = txs.map((t) {
    final raw = t['id'];
    var id = raw is String ? raw : '';
    if (id.isEmpty || seen.contains(id)) {
      if (id.isNotEmpty) duplicated.add(id);
      do {
        id = 'tx_restored_$restored';
        restored++;
      } while (seen.contains(id));
      changed = true;
      t = {...t, 'id': id};
    }
    seen.add(id);
    return t;
  }).toList();
  if (!changed) return data;
  var result = {...data, 'transactions': out};
  // A renamed duplicate leaves any payment txnId or lendTxnId that carried
  // the duplicated id pointing at the SURVIVING row, which may be a totally
  // unrelated transaction. Reversing through such a link would delete the
  // wrong entry and move the wrong money, so ambiguous links are cleared;
  // an unlinked payment falls into the honest "nothing linked to reverse"
  // path instead.
  if (duplicated.isNotEmpty) {
    for (final key in ['receivables', 'payables']) {
      final rows = result[key];
      if (rows is! List) continue;
      var rowsChanged = false;
      final newRows = rows.map((row) {
        if (row is! Map) return row;
        var r = row.cast<String, dynamic>();
        var rowChanged = false;
        final lend = r['lendTxnId'];
        if (lend is String && duplicated.contains(lend)) {
          r = {...r, 'lendTxnId': ''};
          rowChanged = true;
        }
        final pays = r['payments'];
        if (pays is List) {
          var paysChanged = false;
          final newPays = pays.map((p) {
            if (p is Map &&
                p['txnId'] is String &&
                duplicated.contains(p['txnId'])) {
              paysChanged = true;
              return {...p.cast<String, dynamic>(), 'txnId': ''};
            }
            return p;
          }).toList();
          if (paysChanged) {
            r = {...r, 'payments': newPays};
            rowChanged = true;
          }
        }
        if (rowChanged) rowsChanged = true;
        return rowChanged ? r : row;
      }).toList();
      if (rowsChanged) result = {...result, key: newRows};
    }
  }
  return result;
}

/// Account and debt ids get the same boundary guard as transaction ids:
/// the Flutter sheets and engine wrappers address rows by string id, so a
/// missing id from a merged or hand-edited backup renders as a card that
/// can never be opened, paid, edited, or deleted, and a numeric id renders
/// but never matches the stringified id the screens pass around. This runs
/// AFTER sanitizeData on purpose, same reasoning as ensureUniqueTxnIds:
/// sanitizeData is parity-locked to the RN engine by the backup goldens.
/// A numeric id keeps its digits so rows that referenced it follow along;
/// a missing or duplicated id gets a fresh deterministic one.
Map<String, dynamic> ensureEntityIds(Map<String, dynamic> data) {
  var result = data;
  for (final (key, prefix) in const [
    ('accounts', 'acct'),
    ('debts', 'debt'),
    ('assets', 'asset'),
  ]) {
    final rows = result[key];
    if (rows is! List) continue;
    // Reserve every good string id first, so a coerced or restored id can
    // never steal an existing row's identity.
    final taken = <String>{
      for (final r in rows)
        if (r is Map && r['id'] is String && (r['id'] as String).isNotEmpty)
          r['id'] as String,
    };
    final seen = <String>{};
    final remap = <Object, String>{};
    var restored = 0;
    var changed = false;
    String fresh() {
      String id;
      do {
        id = '${prefix}_restored_$restored';
        restored++;
      } while (taken.contains(id) || seen.contains(id));
      return id;
    }

    final newRows = rows.map((row) {
      if (row is! Map) return row;
      final raw = row['id'];
      String id;
      if (raw is String && raw.isNotEmpty && !seen.contains(raw)) {
        id = raw;
      } else if ((raw is num || raw is bool) &&
          !seen.contains(raw.toString()) &&
          !taken.contains(raw.toString())) {
        id = raw.toString();
        remap[raw] = id;
      } else {
        id = fresh();
      }
      seen.add(id);
      if (id == raw) return row;
      changed = true;
      return <String, dynamic>{...row.cast<String, dynamic>(), 'id': id};
    }).toList();
    if (!changed) continue;
    result = {...result, key: newRows};
    if (remap.isEmpty) continue;

    // References that carried the same non-string id follow the rename, so
    // rows the RN app treated as linked stay linked here too.
    dynamic followRefs(dynamic list, List<String> fields) {
      if (list is! List) return list;
      var listChanged = false;
      final out = list.map((row) {
        if (row is! Map) return row;
        var r = row;
        for (final f in fields) {
          final v = row[f];
          final mapped = v is String ? null : remap[v];
          if (mapped != null) {
            r = <String, dynamic>{...r.cast<String, dynamic>(), f: mapped};
            listChanged = true;
          }
        }
        return r;
      }).toList();
      return listChanged ? out : list;
    }

    if (key == 'accounts') {
      result = {
        ...result,
        'transactions': followRefs(result['transactions'], ['accountId']),
        'payments': followRefs(result['payments'], ['account']),
        'receivables': followRefs(result['receivables'], ['accountId']),
      };
      final settings = result['settings'];
      if (settings is Map) {
        var s = settings.cast<String, dynamic>();
        var sChanged = false;
        for (final f in ['defaultAccountId', 'salaryAccountId']) {
          final v = s[f];
          final mapped = v is String ? null : remap[v];
          if (mapped != null) {
            s = {...s, f: mapped};
            sChanged = true;
          }
        }
        if (sChanged) result = {...result, 'settings': s};
      }
    } else if (key == 'debts') {
      result = {
        ...result,
        'payments': followRefs(result['payments'], ['debtId']),
        'transactions': followRefs(result['transactions'], ['debtId']),
      };
    }
    // assets have no inbound references, so a renamed asset id needs no follow.
  }
  return result;
}

class SalapifyStore extends ChangeNotifier {
  Map<String, dynamic> data = sanitizeData({});
  bool loaded = false;
  String? loadError;

  /// True once the user has anything at all in the store, across every
  /// collection a backup carries. Utang-only or goals-only data counts: this
  /// gates the export button and the replace-everything warning, and hiding
  /// either because only receivables exist would invite a silent wipe.
  ///
  /// Settings-era data counts too: paluwagans, treats, quick adds, and an
  /// accepted Steady Pay all live under settings, and a user whose only data
  /// is a paluwagan setup deserves the same replace-everything warning and
  /// backup buttons as one with transactions.
  bool get hasData {
    final collections = const [
      'accounts',
      'transactions',
      'receivables',
      'payables',
      'people',
      'debts',
      'goals',
      'assets',
      'wins',
      'notes',
      'recurring',
    ].any((k) => (data[k] as List? ?? const []).isNotEmpty);
    if (collections) return true;
    final s = data['settings'];
    if (s is Map) {
      for (final k in const ['paluwagans', 'treats', 'quickAdds']) {
        final v = s[k];
        if (v is List && v.isNotEmpty) return true;
      }
      if (s['steadyPay'] is Map) return true;
    }
    return false;
  }

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(storageKey);
      if (raw != null && raw.isNotEmpty) {
        // keepAppLock: true on a normal load so App lock survives a restart.
        // The import/restore path keeps the default (false), forcing the lock
        // off when a backup lands on a phone whose biometrics differ.
        data = ensureEntityIds(
          ensureUniqueTxnIds(sanitizeData(jsonDecode(raw), keepAppLock: true)),
        );
      }
      loadError = null;
    } catch (e) {
      // Never save over data we failed to read; surface the problem instead.
      loadError = e.toString();
    }
    loaded = true;
    notifyListeners();
    // Post any recurring bills and income that have come due while the app was
    // closed. Runs after load so canWrite is settled; a failed read skips it.
    await postDueRecurring();
  }

  /// Post recurring items that have come due, into the transactions list and
  /// their linked accounts, through the golden-locked engine. Idempotent within
  /// a month via each item's lastPosted marker, so calling it on every open and
  /// resume can never double post. A no-op when nothing is due or writing is
  /// off. Call on load and whenever the app returns to the foreground.
  Future<void> postDueRecurring() async {
    if (!canWrite) return;
    // Cheap probe (no ids minted) to skip a redundant write when nothing is
    // due; the engine returns the SAME map instance in that case.
    if (identical(
      recurring.postDueRecurring(data, DateTime.now(), () => ''),
      data,
    )) {
      return;
    }
    // Compute the real post INSIDE the queue so it folds onto the latest
    // committed state, never overwriting a concurrent write. Matches RN's
    // setData(prev => ...). A no-op result keeps the previous map (no churn).
    await _mutate((prev) {
      final next = recurring.postDueRecurring(
        prev,
        DateTime.now(),
        () => _genId('txn'),
      );
      return identical(next, prev) ? prev : next;
    });
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(storageKey, jsonEncode(data));
  }

  /// Import a pasted Salapify backup (the same text the RN Backup screen
  /// shows). Throws NotABackupException, NewerBackupException, or
  /// FormatException for the UI to explain; on success the store is
  /// replaced and persisted.
  Future<void> importBackupText(String text) => _serialized(() async {
    final parsed = parseBackupObject(jsonDecode(text));
    // A restore must never invent money: stamp recurring items whose day
    // this month already passed as posted, so the posting engine does not
    // re-post a bill the backup already recorded. Items still to come keep
    // their marker. Must run before the blob is adopted.
    parsed['recurring'] = recurring.stampRecurringOnRestore(
      parsed['recurring'],
      DateTime.now(),
    );
    // Snapshot BEFORE anything is replaced, and snapshot the RAW stored
    // blob, not what memory holds: after a failed or refused read
    // (newer version, corrupt bytes) memory is the empty default while
    // disk still holds the ONLY copy of the user's data, and this
    // import is the documented recovery action about to overwrite it.
    // If this write fails the import aborts with memory and disk
    // untouched; replacing data without the net would be the one
    // unforgivable loss.
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKey);
    if (raw != null && raw.isNotEmpty) {
      await prefs.setString(previousBackupKey, raw);
    }
    final previous = data;
    data = ensureEntityIds(ensureUniqueTxnIds(parsed));
    try {
      await _save();
    } catch (e) {
      data = previous;
      notifyListeners();
      rethrow;
    }
    // A successful import IS the recovery the failed-read message
    // promises: disk now equals memory and both are readable, so writing
    // is safe again and the stale read error must not keep the app
    // locked read-only.
    loadError = null;
    loaded = true;
    notifyListeners();
  });

  /// Is there a pre-import copy to go back to? The snapshot has existed on
  /// disk since imports were built, but nothing could read it, so the safety
  /// net was real and unreachable. Never throws; a missing key reads as false.
  Future<bool> hasPreviousImportCopy() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(previousBackupKey);
      return raw != null && raw.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Put back the data that the last import replaced.
  ///
  /// This SWAPS rather than restores: what is on screen now becomes the new
  /// safety copy. That matters because undo is itself a data-replacing action,
  /// and a one-shot restore would make a mistaken undo the very kind of
  /// unrecoverable loss this exists to prevent. Swapping means nothing is
  /// ever destroyed, only exchanged, and a second undo puts you back.
  ///
  /// The restored blob goes through the SAME pipeline as load(): it was
  /// written by an older run of this app and may predate a migration, so it
  /// is never adopted raw. Returns false when there is nothing to undo.
  /// Runs on the serialized write queue so it cannot interleave with a save.
  Future<bool> undoLastImport() => _serialized(() async {
    final prefs = await SharedPreferences.getInstance();
    final prev = prefs.getString(previousBackupKey);
    if (prev == null || prev.isEmpty) return false;
    // Parse and migrate BEFORE touching anything. A corrupt or newer-schema
    // snapshot must fail here, with the current data still intact, rather
    // than half way through the swap.
    final restored = ensureEntityIds(
      ensureUniqueTxnIds(sanitizeData(jsonDecode(prev), keepAppLock: true)),
    );
    final outgoing = prefs.getString(storageKey);
    final memoryBefore = data;
    data = restored;
    try {
      await _save();
    } catch (e) {
      data = memoryBefore;
      notifyListeners();
      rethrow;
    }
    // Only now is the swap safe to complete on disk. If this write fails the
    // user still has their restored data; they simply lose the ability to
    // swap back, which is the mild half of the failure.
    if (outgoing != null && outgoing.isNotEmpty) {
      await prefs.setString(previousBackupKey, outgoing);
    } else {
      await prefs.remove(previousBackupKey);
    }
    loadError = null;
    loaded = true;
    notifyListeners();
    return true;
  });

  /// Start fresh: erase EVERYTHING Salapify keeps on this phone. The stored
  /// data, the previous-import safety copy, the cached exchange rates, and
  /// the Privacy receipt's fetch log all go; the in-memory store resets to
  /// the empty default. This is the most destructive action in the app and it
  /// was founder approved before being built; the screen gates it behind an
  /// explicit double confirmation and offers an export first.
  ///
  /// Deliberately allowed even after a failed read (like importBackupText):
  /// wiping unreadable data is the other documented recovery action, so it
  /// also clears loadError and restores writability. Runs on the serialized
  /// write queue so it can never interleave with an in-flight save.
  Future<void> startFresh() => _serialized(() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(storageKey);
    await prefs.remove(previousBackupKey);
    await prefs.remove(FxService.cacheKey);
    await prefs.remove(FxService.logKey);
    data = sanitizeData({});
    loadError = null;
    loaded = true;
    notifyListeners();
  });

  /// The backup text for the whole store, same wrapper as the RN Backup
  /// screen, so the current app can import it unchanged. Read-only.
  String exportBackupText() => buildBackupText(
    data,
    exportedAt: DateTime.now().toUtc().toIso8601String(),
  );

  /// True when writing is safe: the store finished loading and the read did
  /// not fail. After a failed read, saving would overwrite data we could not
  /// read, the one unforgivable data loss, so every write path checks this.
  /// (Importing a backup stays allowed: that is the explicit recovery action,
  /// a whole-blob replace the user chose.)
  bool get canWrite => loaded && loadError == null;

  /// Mutating writes run one at a time through this queue. Two in-flight
  /// writes each snapshot `data` for rollback at their own start; without the
  /// queue, a failed first save would restore a snapshot that silently undoes
  /// the second write. Serializing them makes every snapshot current.
  Future<void> _writes = Future.value();

  Future<T> _serialized<T>(Future<T> Function() action) {
    final run = _writes.then((_) => action());
    _writes = run.then((_) {}, onError: (_) {});
    return run;
  }

  /// Log a new entry through the golden-verified engine: the linked account
  /// (when one is chosen and really exists) moves by the signed amount, and
  /// the whole state is persisted before listeners repaint. If the save
  /// fails, the in-memory state is rolled back so memory never runs ahead of
  /// disk, and the error is rethrown for the UI to show.
  Future<void> addEntry(Map<String, dynamic> tx) => _serialized(() async {
    if (!canWrite) {
      throw StateError(
        'Saving is off because your stored data could not be read. '
        'Import a backup to recover first.',
      );
    }
    final amount = tx['amount'];
    if (amount is! num || !amount.isFinite) {
      throw ArgumentError('That amount is not a normal number.');
    }
    // Every entry needs a stable id, or it cannot be deleted or undone from
    // History and duplicate null-id rows crash the list. RN's addTransaction
    // guarantees one; mirror that here so no caller can post an id-less
    // entry (the balance-adjustment path did).
    final withId = (tx['id'] is String && (tx['id'] as String).isNotEmpty)
        ? tx
        : {...tx, 'id': _genId('txn')};
    final previous = data;
    data = ledger.addTransaction(data, withId);
    try {
      await _save();
    } catch (e) {
      data = previous;
      notifyListeners();
      rethrow;
    }
    notifyListeners();
  });

  /// Append imported transactions in one atomic save. Each gets a fresh id and
  /// flows through the same golden-verified engine as a manual log, so nothing
  /// bypasses validation. Additive only: it never removes or replaces existing
  /// entries, and by default carries no accountId so it does not move an account
  /// balance (the caller can set one to opt into that). Returns the count added.
  Future<int> importTransactions(List<Map<String, dynamic>> txns) async {
    var added = 0;
    await _mutate((prev) {
      var d = prev;
      for (final t in txns) {
        final amount = t['amount'];
        // Defense in depth: the importer already stores a positive amount and
        // drops zero rows, but skip anything non finite or not above zero here
        // too, so no path can post a garbage or balance moving entry.
        if (amount is! num || !amount.isFinite || amount <= 0) continue;
        d = ledger.addTransaction(d, {...t, 'id': _genId('txn')});
        added += 1;
      }
      return d;
    });
    return added;
  }

  /// One shared guard-mutate-save-rollback wrapper for engine writes: check
  /// canWrite, apply a pure engine function, persist, roll back and rethrow
  /// if the disk says no. Keeps every receivables write path on exactly the
  /// same discipline as addEntry and removeEntry.
  Future<void> _mutate(
    Map<String, dynamic> Function(Map<String, dynamic>) apply,
  ) => _serialized(() async {
    if (!canWrite) {
      throw StateError(
        'Saving is off because your stored data could not be read. '
        'Import a backup to recover first.',
      );
    }
    final previous = data;
    data = apply(previous);
    try {
      await _save();
    } catch (e) {
      data = previous;
      notifyListeners();
      rethrow;
    }
    notifyListeners();
  });

  final _rand = Random();

  /// Unique id for engine writes: timestamp plus 48 random bits, the same
  /// recipe as newEntryId, prefixed per collection like the RN genId.
  int _idSeq = 0;

  String _genId(String prefix) {
    final ms = DateTime.now().millisecondsSinceEpoch;
    final a = _rand.nextInt(0x1000000).toRadixString(36);
    final b = _rand.nextInt(0x1000000).toRadixString(36);
    // A monotonic counter guarantees uniqueness even inside a tight batch loop
    // (a bulk CSV import) where every id shares the same millisecond timestamp.
    final n = (_idSeq++).toRadixString(36);
    return '${prefix}_$ms$a${b}_$n';
  }

  String _todayISO() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  String _nowISO() => DateTime.now().toUtc().toIso8601String();

  /// Create an empty note and return its id (the editor opens on it; an
  /// abandoned empty note is discarded on close, matching the RN screen).
  Future<String> addNote() async {
    final id = _genId('notes');
    await _mutate(
      (d) => {
        ...d,
        'notes': [
          ...(d['notes'] as List? ?? const []),
          {'text': '', 'updatedAt': _nowISO(), 'id': id},
        ],
      },
    );
    return id;
  }

  /// Update a note's text, stamping updatedAt like the RN screen does.
  Future<void> updateNote(String id, String text) => _mutate(
    (d) => {
      ...d,
      'notes': [
        for (final n in (d['notes'] as List? ?? const []))
          if (n is Map && n['id'] == id)
            {...n.cast<String, dynamic>(), 'text': text, 'updatedAt': _nowISO()}
          else
            n,
      ],
    },
  );

  /// Delete a note.
  Future<void> deleteNote(String id) => _mutate(
    (d) => {
      ...d,
      'notes': [
        for (final n in (d['notes'] as List? ?? const []))
          if (!(n is Map && n['id'] == id)) n,
      ],
    },
  );

  /// Create a savings goal, matching the RN Goals screen. Values are already
  /// parsed and clamped by the screen (target and saved never negative). Goals
  /// is an existing backup collection, so this is additive with no migration.
  Future<void> addGoal({
    required String name,
    required double target,
    required double saved,
    required String targetDate,
  }) => _mutate(
    (d) => {
      ...d,
      'goals': [
        ...(d['goals'] as List? ?? const []),
        {
          'name': name,
          'target': target,
          'saved': saved,
          'targetDate': targetDate,
          'id': _genId('goals'),
        },
      ],
    },
  );

  /// Update a goal's editable fields, preserving any others (unknown keys and
  /// a legacy shape survive the spread).
  Future<void> updateGoal(
    String id, {
    required String name,
    required double target,
    required double saved,
    required String targetDate,
  }) => _mutate(
    (d) => {
      ...d,
      'goals': [
        for (final g in (d['goals'] as List? ?? const []))
          if (g is Map && g['id'] == id)
            {
              ...g.cast<String, dynamic>(),
              'name': name,
              'target': target,
              'saved': saved,
              'targetDate': targetDate,
            }
          else
            g,
      ],
    },
  );

  /// Add money to a goal's saved total. Adds on top of the STORED saved, never
  /// the editable form field, and floors at zero, matching the RN applyFunds
  /// so clearing the field first can never wipe the real saved amount.
  Future<void> addGoalFunds(String id, double amount) => _mutate(
    (d) => {
      ...d,
      'goals': [
        for (final g in (d['goals'] as List? ?? const []))
          if (g is Map && g['id'] == id)
            {
              ...g.cast<String, dynamic>(),
              'saved': () {
                final cur = g['saved'];
                final base = cur is num
                    ? cur.toDouble()
                    : (cur is String ? (double.tryParse(cur) ?? 0) : 0);
                final next = base + amount;
                return next > 0 ? next : 0.0;
              }(),
            }
          else
            g,
      ],
    },
  );

  /// Delete a goal.
  Future<void> deleteGoal(String id) => _mutate(
    (d) => {
      ...d,
      'goals': [
        for (final g in (d['goals'] as List? ?? const []))
          if (!(g is Map && g['id'] == id)) g,
      ],
    },
  );

  /// Create an account with an opening balance. Accounts is an existing backup
  /// collection, so this is additive with no migration. Balance changes to an
  /// existing account go through a recorded adjustment via addEntry, never a
  /// silent overwrite, so this only sets the opening number on a NEW account.
  Future<void> addAccount({
    required String name,
    required String kind,
    required String brand,
    required String icon,
    required double target,
    required double balance,
  }) => _mutate(
    (d) => {
      ...d,
      'accounts': [
        ...(d['accounts'] as List? ?? const []),
        {
          'name': name,
          'kind': kind,
          'brand': brand,
          'icon': icon,
          'target': target,
          'balance': balance,
          'id': _genId('acct'),
        },
      ],
    },
  );

  /// Update an account's DETAILS only (never its balance, which moves through a
  /// recorded adjustment). Unknown keys survive the spread.
  Future<void> updateAccountDetails(
    String id, {
    required String name,
    required String kind,
    required String brand,
    required String icon,
    required double target,
  }) => _mutate(
    (d) => {
      ...d,
      'accounts': [
        for (final a in (d['accounts'] as List? ?? const []))
          if (a is Map && a['id'] == id)
            {
              ...a.cast<String, dynamic>(),
              'name': name,
              'kind': kind,
              'brand': brand,
              'icon': icon,
              'target': target,
            }
          else
            a,
      ],
    },
  );

  /// Delete an account. Entries stay (their accountId simply stops resolving,
  /// matching the RN screen, so no logged money is ever lost), and settings
  /// that pointed at it are cleared so they never point at a ghost.
  Future<void> deleteAccount(String id) => _mutate((d) {
    final s = ((d['settings'] as Map?) ?? const {}).cast<String, dynamic>();
    final cleared = {
      ...s,
      if (s['defaultAccountId'] == id) 'defaultAccountId': '',
      if (s['salaryAccountId'] == id) 'salaryAccountId': '',
    };
    return {
      ...d,
      'accounts': [
        for (final a in (d['accounts'] as List? ?? const []))
          if (!(a is Map && a['id'] == id)) a,
      ],
      'settings': cleared,
    };
  });

  /// Create an investment or other asset.
  Future<void> addAsset({
    required String name,
    required String kind,
    required double value,
  }) => _mutate(
    (d) => {
      ...d,
      'assets': [
        ...(d['assets'] as List? ?? const []),
        {'name': name, 'kind': kind, 'value': value, 'id': _genId('asset')},
      ],
    },
  );

  /// Update an asset's fields.
  Future<void> updateAsset(
    String id, {
    required String name,
    required String kind,
    required double value,
  }) => _mutate(
    (d) => {
      ...d,
      'assets': [
        for (final a in (d['assets'] as List? ?? const []))
          if (a is Map && a['id'] == id)
            {
              ...a.cast<String, dynamic>(),
              'name': name,
              'kind': kind,
              'value': value,
            }
          else
            a,
      ],
    },
  );

  /// Delete an asset.
  Future<void> deleteAsset(String id) => _mutate(
    (d) => {
      ...d,
      'assets': [
        for (final a in (d['assets'] as List? ?? const []))
          if (!(a is Map && a['id'] == id)) a,
      ],
    },
  );

  /// Add a small win, stamped with today's date, matching the RN Mindset
  /// screen (addItem('wins', { text, date })). Kept in data.wins so the
  /// backup already carries it.
  Future<void> addWin(String text) => _mutate(
    (d) => {
      ...d,
      'wins': [
        ...(d['wins'] as List? ?? const []),
        {'text': text, 'date': _todayISO(), 'id': _genId('wins')},
      ],
    },
  );

  /// Delete a small win.
  Future<void> deleteWin(String id) => _mutate(
    (d) => {
      ...d,
      'wins': [
        for (final w in (d['wins'] as List? ?? const []))
          if (!(w is Map && w['id'] == id)) w,
      ],
    },
  );

  /// Best-effort collapse of a (themeKey, appearanceMode) choice back to the one
  /// legacy mood string, so an older build or an old backup reopened elsewhere
  /// still themes sensibly. Only Barako had a light (latte) and dark (barako)
  /// mood; everything else maps to the nearest of the three.
  static String _legacyMood(String key, String mode) =>
      mode == 'light' ? 'latte' : 'barako';

  /// Remember the appearance mode (system, light, dark). Kept alongside the
  /// legacy themeMood so a rollback still looks right; unknown settings keys are
  /// preserved by the backup, so this needs no migration.
  Future<void> setThemeMode(String mode) => _mutate((d) {
    final s = ((d['settings'] as Map?) ?? const {}).cast<String, dynamic>();
    // is String, not a hard cast: a hand-edited or future backup could
    // carry a non-string themeKey, and a cast would throw on tap.
    final key = s['themeKey'] is String ? s['themeKey'] as String : 'barako';
    return {
      ...d,
      'settings': {
        ...s,
        'themeMode': mode,
        'themeMood': _legacyMood(key, mode),
      },
    };
  });

  /// Remember the chosen theme (barako, tidal, ...). Kept alongside the legacy
  /// themeMood for the same rollback reason.
  Future<void> setThemeKey(String key) => _mutate((d) {
    final s = ((d['settings'] as Map?) ?? const {}).cast<String, dynamic>();
    final mode = s['themeMode'] is String ? s['themeMode'] as String : 'system';
    return {
      ...d,
      'settings': {...s, 'themeKey': key, 'themeMood': _legacyMood(key, mode)},
    };
  });

  /// Whether a reminder kind (daily, payday, bills, collect) is switched on.
  bool notifOn(String key) {
    final s = data['settings'];
    final n = s is Map ? s['notifications'] : null;
    return n is Map && n[key] == true;
  }

  /// Turn a reminder kind on or off, stored in settings.notifications. The
  /// backup preserves unknown settings keys, so this needs no migration. The
  /// screen reschedules the OS notifications after; the store stays free of any
  /// platform dependency so it remains unit testable.
  Future<void> setNotifPref(String key, bool value) => _mutate((d) {
    final s = ((d['settings'] as Map?) ?? const {}).cast<String, dynamic>();
    final notifs = (s['notifications'] is Map)
        ? (s['notifications'] as Map).cast<String, dynamic>()
        : <String, dynamic>{};
    return {
      ...d,
      'settings': {
        ...s,
        'notifications': {...notifs, key: value},
      },
    };
  });

  /// Remember the mood theme (legacy latte/barako/milktea). Kept for the old
  /// mood card and tests; new UI uses setThemeKey/setThemeMode.
  Future<void> setThemeMood(String mood) => _mutate(
    (d) => {
      ...d,
      'settings': {
        ...((d['settings'] as Map?) ?? const {}).cast<String, dynamic>(),
        'themeMood': mood,
      },
    },
  );

  /// The user's own payday schedule, kept in settings.paydaySchedule. Until
  /// this is set, everything that would ASSERT "today is payday" stays quiet
  /// rather than guessing (see hasExplicitPaydaySchedule); forecasts fall back
  /// to the 15/31 default. Shapes match the RN app exactly so an imported
  /// backup keeps working: {'mode':'semimonthly','days':[a,b]},
  /// {'mode':'monthly','day':n}, {'mode':'weekly','weekday':0..6}.
  /// The backup preserves unknown settings keys, so this needs no migration.
  Future<void> setPaydaySchedule(Map<String, dynamic> schedule) => _mutate(
    (d) => {
      ...d,
      'settings': {
        ...((d['settings'] as Map?) ?? const {}).cast<String, dynamic>(),
        'paydaySchedule': schedule,
      },
    },
  );

  /// Forget the payday schedule, for the user whose pay has no fixed date.
  /// Removing the key (rather than storing a marker) is what keeps the rest of
  /// the money layer unchanged: it reads exactly like a user who never set one.
  Future<void> clearPaydaySchedule() => _mutate((d) {
    final s = ((d['settings'] as Map?) ?? const {}).cast<String, dynamic>()
      ..remove('paydaySchedule');
    return {...d, 'settings': s};
  });

  /// Record how far a learner got with one lesson.
  ///
  /// Writes settings.lessonProgress, and ALSO keeps settings.lessonsRead in
  /// step for learned lessons. The duplication is deliberate and temporary:
  /// a backup made here must still restore correctly onto a build that only
  /// knows the old key, because during a staged rollout both versions exist
  /// and a user may move a file between them. The backup preserves unknown
  /// settings keys, so neither direction loses anything.
  Future<void> setLessonState(String id, LessonState state) => _mutate((d) {
    final s = ((d['settings'] as Map?) ?? const {}).cast<String, dynamic>();
    final progress = withLessonState(s['lessonProgress'], id, state);
    // Only a learned lesson joins the legacy list, since that list is read by
    // older builds as "done" with no finer grain available.
    final read = <String>{
      for (final x
          in (s['lessonsRead'] is List ? s['lessonsRead'] as List : const []))
        if (x is String) x,
      if (state == LessonState.learned) id,
    };
    return {
      ...d,
      'settings': {
        ...s,
        'lessonProgress': progress,
        'lessonsRead': read.toList(),
      },
    };
  });

  /// The per-lesson progress, with old lessonsRead entries folded in.
  Map<String, LessonState> get lessonProgress {
    final s = data['settings'];
    return parseLessonProgress(
      s is Map ? s['lessonProgress'] : null,
      legacyRead: s is Map ? s['lessonsRead'] : null,
    );
  }

  /// Mark a Learn lesson read, deduped, kept in settings.lessonsRead. The
  /// backup preserves unknown settings keys, so this needs no migration.
  Future<void> markLessonRead(String id) => _mutate((d) {
    final s = ((d['settings'] as Map?) ?? const {}).cast<String, dynamic>();
    final read = <String>{
      for (final x
          in (s['lessonsRead'] is List ? s['lessonsRead'] as List : const []))
        if (x is String) x,
      id,
    };
    return {
      ...d,
      'settings': {...s, 'lessonsRead': read.toList()},
    };
  });

  /// Earn-your-treats rules, kept in settings.treats. Every write goes through
  /// the golden-locked treats engine so check-in windows and lifetime match the
  /// RN app. The backup preserves unknown settings keys, so this needs no
  /// migration.
  List<Map<String, dynamic>> get treatRules {
    final s = (data['settings'] as Map?) ?? const {};
    final list = s['treats'];
    if (list is! List) return const [];
    return [
      for (final t in list)
        if (t is Map) t.cast<String, dynamic>(),
    ];
  }

  List<Map<String, dynamic>> _settingsTreats(Map<String, dynamic> d) {
    final s = (d['settings'] as Map?) ?? const {};
    final list = s['treats'];
    if (list is! List) return [];
    return [
      for (final t in list)
        if (t is Map) t.cast<String, dynamic>(),
    ];
  }

  Map<String, dynamic> _withTreats(
    Map<String, dynamic> d,
    List<Map<String, dynamic>> next,
  ) => {
    ...d,
    'settings': {
      ...((d['settings'] as Map?) ?? const {}).cast<String, dynamic>(),
      'treats': next,
    },
  };

  /// Create a treat rule from form fields and return its id.
  Future<String> addTreat(Map<String, dynamic> fields) async {
    final id = _genId('treat');
    await _mutate((d) {
      final rule = treats.newTreat(fields, DateTime.now(), id: id);
      return _withTreats(d, [..._settingsTreats(d), rule]);
    });
    return id;
  }

  /// Edit a treat rule's user fields, keeping its check-ins and lifetime. The
  /// engine renormalizes target/window/emoji.
  Future<void> updateTreat(String id, Map<String, dynamic> fields) =>
      _mutate((d) {
        final next = _settingsTreats(d).map((t) {
          if (t['id'] != id) return t;
          final base = treats.newTreat(fields, DateTime.now(), id: id);
          return {
            ...base,
            'checkIns': t['checkIns'] is List ? t['checkIns'] : const [],
            'lifetime': t['lifetime'],
            'createdAt': t['createdAt'] ?? base['createdAt'],
          };
        }).toList();
        return _withTreats(d, next);
      });

  /// Toggle today's check-in on one treat through the golden-locked engine.
  Future<void> toggleTreatCheckIn(String id) => _mutate((d) {
    final next = _settingsTreats(d)
        .map((t) => t['id'] == id ? treats.toggleCheckIn(t, DateTime.now()) : t)
        .toList();
    return _withTreats(d, next);
  });

  /// Remove a treat rule.
  Future<void> deleteTreat(String id) => _mutate(
    (d) =>
        _withTreats(d, _settingsTreats(d).where((t) => t['id'] != id).toList()),
  );

  /// The user's paluwagan groups. Like treats, this is a Flutter-era
  /// collection nested under settings, not a top-level RN backup key, so it is
  /// additive and never breaks the golden backup contract.
  List<Map<String, dynamic>> get paluwagans => _settingsPaluwagans(data);

  List<Map<String, dynamic>> _settingsPaluwagans(Map<String, dynamic> d) {
    final s = (d['settings'] as Map?) ?? const {};
    final list = s['paluwagans'];
    if (list is! List) return [];
    return [
      for (final p in list)
        if (p is Map) p.cast<String, dynamic>(),
    ];
  }

  Map<String, dynamic> _withPaluwagans(
    Map<String, dynamic> d,
    List<Map<String, dynamic>> next,
  ) => {
    ...d,
    'settings': {
      ...((d['settings'] as Map?) ?? const {}).cast<String, dynamic>(),
      'paluwagans': next,
    },
  };

  /// Create a paluwagan from raw form fields through the engine, which clamps
  /// members and turn, reads the amount the JS way, and mints a stable id.
  /// Returns the new id so the screen can open straight onto it.
  Future<String> addPaluwagan(Map<String, dynamic> fields) async {
    final id = _genId('paluwagan');
    await _mutate((d) {
      final p = paluwagan.newPaluwagan({...fields, 'id': id}, DateTime.now());
      return _withPaluwagans(d, [..._settingsPaluwagans(d), p]);
    });
    return id;
  }

  /// Edit a paluwagan's fields, keeping its id. The engine renormalizes every
  /// value, so a bad members count can never desync myTurn or paidCycles.
  Future<void> updatePaluwagan(String id, Map<String, dynamic> fields) =>
      _mutate((d) {
        final next = _settingsPaluwagans(d).map((p) {
          if (p['id'] != id) return p;
          return paluwagan.newPaluwagan({...fields, 'id': id}, DateTime.now());
        }).toList();
        return _withPaluwagans(d, next);
      });

  /// Remove a paluwagan group.
  Future<void> deletePaluwagan(String id) => _mutate(
    (d) => _withPaluwagans(
      d,
      _settingsPaluwagans(d).where((p) => p['id'] != id).toList(),
    ),
  );

  /// Recurring bills and income (top-level collection).
  List<Map<String, dynamic>> get recurringList {
    final v = data['recurring'];
    return [
      for (final r in (v is List ? v : const []))
        if (r is Map) r.cast<String, dynamic>(),
    ];
  }

  List<Map<String, dynamic>> _recurring(Map<String, dynamic> d) {
    final v = d['recurring'];
    return [
      for (final r in (v is List ? v : const []))
        if (r is Map) r.cast<String, dynamic>(),
    ];
  }

  /// Add a recurring item. lastPosted is stamped through the golden-locked
  /// engine so a day already past this month waits for next month instead of
  /// posting a back dated expense.
  Future<String> addRecurring({
    required String type,
    required String label,
    required double amount,
    required int dayOfMonth,
    String accountId = '',
  }) async {
    final id = _genId('recurring');
    await _mutate((d) {
      final item = {
        'id': id,
        'type': type == 'income' ? 'income' : 'expense',
        'label': label,
        'amount': amount,
        'dayOfMonth': dayOfMonth,
        'accountId': accountId,
        'lastPosted': recurring.recurringSaveLastPosted(
          dayOfMonth: dayOfMonth,
          existingLastPosted: '',
          now: DateTime.now(),
          isEdit: false,
        ),
      };
      return {
        ...d,
        'recurring': [..._recurring(d), item],
      };
    });
    return id;
  }

  /// Edit a recurring item, preserving its lastPosted unless a day that already
  /// passed newly requires stamping this month (never posts retroactively).
  Future<void> updateRecurring(
    String id, {
    required String type,
    required String label,
    required double amount,
    required int dayOfMonth,
    String accountId = '',
  }) => _mutate((d) {
    final next = _recurring(d).map((r) {
      if (r['id'] != id) return r;
      final kept = r['lastPosted'] is String ? r['lastPosted'] as String : '';
      return {
        ...r,
        'type': type == 'income' ? 'income' : 'expense',
        'label': label,
        'amount': amount,
        'dayOfMonth': dayOfMonth,
        'accountId': accountId,
        'lastPosted': recurring.recurringSaveLastPosted(
          dayOfMonth: dayOfMonth,
          existingLastPosted: kept,
          now: DateTime.now(),
          isEdit: true,
        ),
      };
    }).toList();
    return {...d, 'recurring': next};
  });

  /// Remove a recurring item. Transactions it already posted stay; only the
  /// rule stops, matching RN.
  Future<void> deleteRecurring(String id) => _mutate(
    (d) => {
      ...d,
      'recurring': _recurring(d).where((r) => r['id'] != id).toList(),
    },
  );

  /// Turn App lock on or off (settings.appLock). Biometric-only; the LockGate
  /// disables it automatically if the phone has no biometrics enrolled, so this
  /// can never lock the owner out.
  Future<void> setAppLock(bool value) => _mutate(
    (d) => {
      ...d,
      'settings': {
        ...((d['settings'] as Map?) ?? const {}).cast<String, dynamic>(),
        'appLock': value,
      },
    },
  );

  /// Accept a Steady Pay weekly draw (founder-approved stored field,
  /// 2026-07-24). A conditional settings key: setting writes it, clearing
  /// removes it entirely so a backup without it never gains the key. The
  /// guard mirrors addEntry: the store boundary rejects a bad amount even
  /// though today's only caller validates, so no future caller can persist
  /// a key the readers treat as absent.
  Future<void> setSteadyPay(double amount) {
    if (!amount.isFinite || amount <= 0) {
      throw ArgumentError('Steady Pay amount must be a positive finite peso');
    }
    return _mutate(
      (d) => {
        ...d,
        'settings': {
          ...((d['settings'] as Map?) ?? const {}).cast<String, dynamic>(),
          'steadyPay': {
            'amount': amount,
            'acceptedAt': DateTime.now().toIso8601String().substring(0, 10),
          },
        },
      },
    );
  }

  Future<void> clearSteadyPay() => _mutate((d) {
    final settings = ((d['settings'] as Map?) ?? const {})
        .cast<String, dynamic>();
    final next = {...settings}..remove('steadyPay');
    return {...d, 'settings': next};
  });

  /// Unlock Pro. During early access Pro is free and early users keep it free,
  /// so this is the honest "unlock" the recurring cap offers. A plain settings
  /// write, preserved by backup like every other settings key.
  Future<void> setPro(bool value) => _mutate(
    (d) => {
      ...d,
      'settings': {
        ...((d['settings'] as Map?) ?? const {}).cast<String, dynamic>(),
        'pro': value,
      },
    },
  );

  /// Set (or clear, with 0) the monthly budget limit.
  Future<void> setMonthlyLimit(double limit) => _mutate(
    (d) => {
      ...d,
      'settings': {
        ...((d['settings'] as Map?) ?? const {}).cast<String, dynamic>(),
        'monthlyLimit': limit,
      },
    },
  );

  /// Log a partial utang payment through the golden-verified engine.
  Future<void> collectUtangPayment(String receivableId, String amountText) =>
      _mutate(
        (d) => receivables.logPartial(
          d,
          receivableId,
          amountText,
          today: _todayISO(),
          genId: _genId,
        ),
      );

  /// Settle whatever is still owed on one utang.
  Future<void> markUtangPaid(String receivableId) => _mutate(
    (d) => receivables.markPaid(
      d,
      receivableId,
      today: _todayISO(),
      genId: _genId,
    ),
  );

  /// Remove one logged payment and reverse its income entry.
  Future<void> removeUtangPayment(String receivableId, String paymentId) =>
      _mutate((d) => receivables.removePayment(d, receivableId, paymentId));

  /// Create a new utang. Throws ArgumentError with a friendly message when
  /// the engine refuses (blank name, bad amount, impossible date).
  Future<void> addUtang({
    required String person,
    required String amountText,
    String dueDate = '',
    String phone = '',
    String note = '',
    String fromAccount = '',
  }) => _mutate((d) {
    final r = receivables.saveReceivable(
      d,
      person: person,
      amountText: amountText,
      dueDate: dueDate,
      phone: phone,
      note: note,
      fromAccount: fromAccount,
      today: _todayISO(),
      genId: _genId,
    );
    if (r.error != null) {
      throw ArgumentError(switch (r.error) {
        'name' => 'Please enter a name.',
        'amount' => 'Enter a valid amount.',
        'date' => 'That date does not exist. Type it like 2026-07-15.',
        _ => 'Could not save this entry.',
      });
    }
    return r.data;
  });

  /// Split an already logged expense you fronted (Hatian). Reduces the source
  /// transaction to YOUR share, and turns each other person's share into a
  /// receivable through the golden-locked engine, all tied to one activity so
  /// the utang screen can group them. When the source expense came from a real
  /// account, each share also posts a cash-leg transfer out of that account, so
  /// exactly the fronted total ever leaves it and your net worth drops only by
  /// your own share. Pass the split plan the screen already validated with
  /// splits.splitExpense; a bad plan or a missing source is a safe no-op.
  ///
  /// Returns the number of receivables created, so the screen can confirm.
  Future<int> splitExpense({
    required String txnId,
    required List<Map<String, dynamic>> participants,
    String activityLabel = '',
  }) async {
    var created = 0;
    await _mutate((d) {
      final txns = (d['transactions'] as List? ?? const []);
      Map<String, dynamic>? src;
      for (final t in txns) {
        if (t is Map && t['id'] == txnId) {
          src = t.cast<String, dynamic>();
          break;
        }
      }
      if (src == null) return d;

      // Only a plain, unlinked expense may be split. A flow leg, a source
      // stamp, a debt link, or a payable/receivable payment pointing at this
      // txn all mean shrinking it would desync a locked contract or invent
      // money (a linked payment would later reverse a now-smaller txn). This
      // enforces at the store the same gate the History affordance uses, so the
      // money invariant holds no matter who calls this.
      if (src['type'] != 'expense' ||
          src['flow'] != null ||
          src['source'] != null ||
          src['debtId'] != null) {
        return d;
      }
      for (final key in const ['payables', 'receivables']) {
        final list = d[key];
        if (list is! List) continue;
        for (final item in list) {
          if (item is! Map) continue;
          final pays = item['payments'];
          if (pays is! List) continue;
          for (final p in pays) {
            if (p is Map && p['txnId'] == txnId) return d;
          }
        }
      }

      final total = ledger.amountOf(src['amount']);
      final plan = splits.splitExpense(total, participants);
      if (plan['ok'] != true) return d;

      final accountId = src['accountId'] is String
          ? src['accountId'] as String
          : '';
      final label = activityLabel.trim().isNotEmpty
          ? activityLabel.trim()
          : (src['label']?.toString().trim().isNotEmpty == true
                ? src['label'].toString().trim()
                : 'Split');
      final activityId = _genId('activity');

      // 1. The source expense shrinks to your own share, and carries the
      //    activity id so the screen can show it was split and never re-split.
      final yourShare = (plan['yourShare'] as num).toDouble();
      var next = ledger.updateTransaction(d, txnId, {
        'amount': yourShare,
        'splitActivityId': activityId,
      });

      // 2. Each other person's share becomes a receivable, tagged to the
      //    activity. A cash-leg (fromAccount) is recorded only when the source
      //    expense had a real account, matching the engine's honest utang cases.
      var madeCount = 0;
      for (final s in plan['shares'] as List) {
        if (s is! Map || s['isYou'] == true) continue;
        final share = (s['share'] as num?)?.toDouble() ?? 0;
        if (share <= 0) continue;
        final res = receivables.saveReceivable(
          next,
          person: s['name']?.toString() ?? 'Someone',
          amountText: share.toStringAsFixed(2),
          note: label,
          fromAccount: accountId,
          today: _todayISO(),
          genId: _genId,
        );
        // All or nothing: the source expense is already reduced, so a share
        // that failed to become a receivable would leave money that left the
        // account with nothing recording it. Abort the whole split instead;
        // _mutate discards this and the store is untouched.
        if (res.error != null || res.id == null) {
          created = 0;
          return d;
        }
        final newId = res.id;
        next = {
          ...res.data,
          'receivables': [
            for (final r in (res.data['receivables'] as List))
              (r is Map && r['id'] == newId)
                  ? {
                      ...r.cast<String, dynamic>(),
                      'activityId': activityId,
                      'activityLabel': label,
                    }
                  : r,
          ],
        };
        madeCount += 1;
      }
      created = madeCount;
      return next;
    });
    return created;
  }

  /// Save (create or edit) a debt through the golden-verified engine. The
  /// form map carries the same text fields as the RN screen. Throws
  /// ArgumentError with the exact RN validation sentence when refused.
  /// Returns the saved debt's id.
  Future<String?> saveDebt(Map<String, dynamic> form) async {
    String? savedId;
    await _mutate((d) {
      final r = debts.saveDebt(d, form, today: _todayISO(), genId: _genId);
      if (r.error.isNotEmpty) throw ArgumentError(r.error);
      savedId = r.id;
      return r.data;
    });
    return savedId;
  }

  /// Log a debt payment from the typed amount text ("2,500" works), out of
  /// the chosen account or from outside the app (null). Returns the engine
  /// result so the screen can show the logged message and celebrate a debt
  /// cleared to zero.
  Future<debts.DebtPayResult> logDebtPayment(
    String debtId,
    String amountText,
    String? payFrom,
  ) async {
    late debts.DebtPayResult result;
    await _mutate((d) {
      _requireDebt(d, debtId);
      result = debts.logDebtPayment(
        d,
        {'id': debtId},
        payFrom,
        amountText,
        today: _todayISO(),
        genId: _genId,
      );
      return result.data;
    });
    return result;
  }

  /// The RN screen always pays from a form built off a live debt; the store
  /// exposes this to any caller, so a debt deleted mid-edit must refuse
  /// instead of recording a ghost payment row against nothing.
  void _requireDebt(Map<String, dynamic> d, String debtId) {
    final list = d['debts'] as List? ?? const [];
    if (!list.any((x) => x is Map && x['id'] == debtId)) {
      throw ArgumentError('This debt no longer exists.');
    }
  }

  /// Pay off everything still owed on one debt, including interest accrued
  /// since the last payment, as a real payment through the same path.
  Future<debts.DebtPayResult> markDebtPaid(
    String debtId,
    String? payFrom,
  ) async {
    late debts.DebtPayResult result;
    await _mutate((d) {
      _requireDebt(d, debtId);
      result = debts.markDebtPaid(
        d,
        {'id': debtId},
        payFrom,
        today: _todayISO(),
        genId: _genId,
      );
      return result.data;
    });
    return result;
  }

  /// Remove a debt. Its payment history and record rows stay on purpose.
  Future<void> deleteDebt(String debtId) =>
      _mutate((d) => debts.deleteDebt(d, debtId));

  /// Remove an entry through the engine (the linked account gets its money
  /// back), with the same write guard and rollback discipline as addEntry.
  /// Returns the removed transaction map so the caller can offer undo by
  /// re-adding the exact same entry.
  Future<Map<String, dynamic>?> removeEntry(String id) => _serialized(() async {
    if (!canWrite) {
      throw StateError(
        'Saving is off because your stored data could not be read. '
        'Import a backup to recover first.',
      );
    }
    final txs = (data['transactions'] as List).cast<Map<String, dynamic>>();
    final idx = txs.indexWhere((t) => t['id'] == id);
    if (idx < 0) return null;
    final removed = txs[idx];
    final previous = data;
    data = ledger.removeTransaction(data, id);
    try {
      await _save();
    } catch (e) {
      data = previous;
      notifyListeners();
      rethrow;
    }
    notifyListeners();
    return removed;
  });
}
