// The on-device store: one sanitized data map, persisted as one JSON string
// under the same key idea as the RN app (salapify_data_v2). Every blob that
// enters, whether loaded from disk or pasted as a backup, passes through
// sanitizeData or parseBackupObject first, so the store can never hold a
// shape the app would crash on. ChangeNotifier keeps the UI in sync without
// any extra state library.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../money/ledger.dart' as ledger;
import 'backup.dart';

const String storageKey = 'salapify_data_v2';

class SalapifyStore extends ChangeNotifier {
  Map<String, dynamic> data = sanitizeData({});
  bool loaded = false;
  String? loadError;

  /// True once the user has anything at all in the store.
  bool get hasData =>
      (data['accounts'] as List).isNotEmpty ||
      (data['transactions'] as List).isNotEmpty;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(storageKey);
      if (raw != null && raw.isNotEmpty) {
        data = sanitizeData(jsonDecode(raw));
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
  Future<void> importBackupText(String text) async {
    final parsed = parseBackupObject(jsonDecode(text));
    data = parsed;
    await _save();
    // A successful import IS the recovery the failed-read message promises:
    // disk now equals memory and both are readable, so writing is safe again
    // and the stale read error must not keep the app locked read-only.
    loadError = null;
    loaded = true;
    notifyListeners();
  }

  /// True when writing is safe: the store finished loading and the read did
  /// not fail. After a failed read, saving would overwrite data we could not
  /// read, the one unforgivable data loss, so every write path checks this.
  /// (Importing a backup stays allowed: that is the explicit recovery action,
  /// a whole-blob replace the user chose.)
  bool get canWrite => loaded && loadError == null;

  /// Log a new entry through the golden-verified engine: the linked account
  /// (when one is chosen and really exists) moves by the signed amount, and
  /// the whole state is persisted before listeners repaint. If the save
  /// fails, the in-memory state is rolled back so memory never runs ahead of
  /// disk, and the error is rethrown for the UI to show.
  Future<void> addEntry(Map<String, dynamic> tx) async {
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
  }
}
