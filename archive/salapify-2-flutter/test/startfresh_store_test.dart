// Start fresh (erase everything): the most destructive action in the app,
// founder approved before it was built. The invariants: every key Salapify
// owns is removed from disk (the data, the previous-import safety copy, the
// cached exchange rates, and the Privacy receipt's fetch log), the in-memory
// store resets to the empty default and stays writable, a reload comes back
// empty, and it also recovers a store whose data could not be read.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/fx_service.dart';
import 'package:salapify/data/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _seedData() => {
  'accounts': [
    {'id': 'a1', 'name': 'GCash', 'kind': 'ewallet', 'balance': 5000},
  ],
  'transactions': [
    {
      'id': 't1',
      'type': 'expense',
      'label': 'Food',
      'amount': 200,
      'date': '2026-07-01',
      'accountId': 'a1',
    },
  ],
};

void main() {
  test(
    'erases the data, the safety copy, the fx cache, and the fetch log',
    () async {
      SharedPreferences.setMockInitialValues({
        FxService.cacheKey: '{"base":"PHP"}',
        // The receipt log is a behavioral trace (when the app was used, which
        // currency); a wipe that promises "erase everything" must take it too.
        FxService.logKey: '[{"at":1000,"base":"PHP","ok":true}]',
      });
      final store = SalapifyStore();
      await store.load();
      // First import writes the data; second import snapshots it into the
      // previous-backup safety copy, so all three keys exist before the wipe.
      final text = jsonEncode({
        'app': 'salapify',
        'version': 2,
        'data': _seedData(),
      });
      await store.importBackupText(text);
      await store.importBackupText(text);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(storageKey), isNotNull);
      expect(prefs.getString(previousBackupKey), isNotNull);
      expect(prefs.getString(FxService.cacheKey), isNotNull);
      expect(prefs.getString(FxService.logKey), isNotNull);
      expect(store.hasData, isTrue);

      await store.startFresh();

      expect(prefs.getString(storageKey), isNull);
      expect(prefs.getString(previousBackupKey), isNull);
      expect(prefs.getString(FxService.cacheKey), isNull);
      expect(prefs.getString(FxService.logKey), isNull);
      expect(
        await FxService().fetchLog(),
        isEmpty,
        reason: 'the receipt itself must read empty after a wipe',
      );
      expect(store.hasData, isFalse);
      expect(
        store.canWrite,
        isTrue,
        reason: 'a fresh store must accept writes',
      );

      // A brand new store loads back empty, not the old data.
      final second = SalapifyStore();
      await second.load();
      expect(second.hasData, isFalse);
    },
  );

  test('recovers a store whose data could not be read', () async {
    // Corrupt bytes on disk: load fails, writing locks. Start fresh is the
    // documented recovery, so it must clear the error and restore writability.
    SharedPreferences.setMockInitialValues({storageKey: '{not json'});
    final store = SalapifyStore();
    await store.load();
    expect(store.loadError, isNotNull);
    expect(store.canWrite, isFalse);

    await store.startFresh();

    expect(store.loadError, isNull);
    expect(store.canWrite, isTrue);
    expect(store.hasData, isFalse);
    // And the app is genuinely usable again: a write goes through.
    await store.addNote();
    expect((store.data['notes'] as List).length, 1);
  });

  test('erasing an already empty store is a safe no-op', () async {
    SharedPreferences.setMockInitialValues({});
    final store = SalapifyStore();
    await store.load();
    await store.startFresh();
    expect(store.hasData, isFalse);
    expect(store.canWrite, isTrue);
  });
}
