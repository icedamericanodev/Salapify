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

import '../money/ledger.dart' as ledger;
import '../money/debts.dart' as debts;
import '../money/receivables.dart' as receivables;
import 'backup.dart';

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
    } else {
      result = {
        ...result,
        'payments': followRefs(result['payments'], ['debtId']),
        'transactions': followRefs(result['transactions'], ['debtId']),
      };
    }
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
  bool get hasData => const [
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

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(storageKey);
      if (raw != null && raw.isNotEmpty) {
        data = ensureEntityIds(ensureUniqueTxnIds(sanitizeData(jsonDecode(raw))));
      }
      loadError = null;
    } catch (e) {
      // Never save over data we failed to read; surface the problem instead.
      loadError = e.toString();
    }
    loaded = true;
    notifyListeners();
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

  /// The backup text for the whole store, same wrapper as the RN Backup
  /// screen, so the current app can import it unchanged. Read-only.
  String exportBackupText() => buildBackupText(data,
      exportedAt: DateTime.now().toUtc().toIso8601String());

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
              'Import a backup to recover first.');
        }
        final amount = tx['amount'];
        if (amount is! num || !amount.isFinite) {
          throw ArgumentError('That amount is not a normal number.');
        }
        final previous = data;
        data = ledger.addTransaction(data, tx);
        try {
          await _save();
        } catch (e) {
          data = previous;
          notifyListeners();
          rethrow;
        }
        notifyListeners();
      });

  /// One shared guard-mutate-save-rollback wrapper for engine writes: check
  /// canWrite, apply a pure engine function, persist, roll back and rethrow
  /// if the disk says no. Keeps every receivables write path on exactly the
  /// same discipline as addEntry and removeEntry.
  Future<void> _mutate(
          Map<String, dynamic> Function(Map<String, dynamic>) apply) =>
      _serialized(() async {
        if (!canWrite) {
          throw StateError(
              'Saving is off because your stored data could not be read. '
              'Import a backup to recover first.');
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
  String _genId(String prefix) {
    final ms = DateTime.now().millisecondsSinceEpoch;
    final a = _rand.nextInt(0x1000000).toRadixString(36);
    final b = _rand.nextInt(0x1000000).toRadixString(36);
    return '${prefix}_$ms$a$b';
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
    await _mutate((d) => {
          ...d,
          'notes': [
            ...(d['notes'] as List? ?? const []),
            {'text': '', 'updatedAt': _nowISO(), 'id': id},
          ],
        });
    return id;
  }

  /// Update a note's text, stamping updatedAt like the RN screen does.
  Future<void> updateNote(String id, String text) => _mutate((d) => {
        ...d,
        'notes': [
          for (final n in (d['notes'] as List? ?? const []))
            if (n is Map && n['id'] == id)
              {...n.cast<String, dynamic>(), 'text': text, 'updatedAt': _nowISO()}
            else
              n,
        ],
      });

  /// Delete a note.
  Future<void> deleteNote(String id) => _mutate((d) => {
        ...d,
        'notes': [
          for (final n in (d['notes'] as List? ?? const []))
            if (!(n is Map && n['id'] == id)) n,
        ],
      });

  /// Remember the mood theme (latte, barako, milktea).
  Future<void> setThemeMood(String mood) => _mutate((d) => {
        ...d,
        'settings': {
          ...((d['settings'] as Map?) ?? const {}).cast<String, dynamic>(),
          'themeMood': mood,
        },
      });

  /// Set (or clear, with 0) the monthly budget limit.
  Future<void> setMonthlyLimit(double limit) => _mutate((d) => {
        ...d,
        'settings': {
          ...((d['settings'] as Map?) ?? const {}).cast<String, dynamic>(),
          'monthlyLimit': limit,
        },
      });

  /// Log a partial utang payment through the golden-verified engine.
  Future<void> collectUtangPayment(String receivableId, String amountText) =>
      _mutate((d) => receivables.logPartial(d, receivableId, amountText,
          today: _todayISO(), genId: _genId));

  /// Settle whatever is still owed on one utang.
  Future<void> markUtangPaid(String receivableId) =>
      _mutate((d) => receivables.markPaid(d, receivableId,
          today: _todayISO(), genId: _genId));

  /// Remove one logged payment and reverse its income entry.
  Future<void> removeUtangPayment(String receivableId, String paymentId) =>
      _mutate(
          (d) => receivables.removePayment(d, receivableId, paymentId));

  /// Create a new utang. Throws ArgumentError with a friendly message when
  /// the engine refuses (blank name, bad amount, impossible date).
  Future<void> addUtang({
    required String person,
    required String amountText,
    String dueDate = '',
    String phone = '',
    String note = '',
    String fromAccount = '',
  }) =>
      _mutate((d) {
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
            'date' =>
              'That date does not exist. Type it like 2026-07-15.',
            _ => 'Could not save this utang.',
          });
        }
        return r.data;
      });

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
      String debtId, String amountText, String? payFrom) async {
    late debts.DebtPayResult result;
    await _mutate((d) {
      _requireDebt(d, debtId);
      result = debts.logDebtPayment(d, {'id': debtId}, payFrom, amountText,
          today: _todayISO(), genId: _genId);
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
      String debtId, String? payFrom) async {
    late debts.DebtPayResult result;
    await _mutate((d) {
      _requireDebt(d, debtId);
      result = debts.markDebtPaid(d, {'id': debtId}, payFrom,
          today: _todayISO(), genId: _genId);
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
  Future<Map<String, dynamic>?> removeEntry(String id) =>
      _serialized(() async {
        if (!canWrite) {
          throw StateError(
              'Saving is off because your stored data could not be read. '
              'Import a backup to recover first.');
        }
        final txs =
            (data['transactions'] as List).cast<Map<String, dynamic>>();
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
