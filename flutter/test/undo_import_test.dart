// Undo the last import: proof that the safety copy is now reachable, and that
// the undo itself can never be the thing that loses data.
//
// The store has snapshotted the outgoing blob to salapify_data_v2_prev since
// imports were built, but nothing in the app ever read that key, so the
// confirm dialog had to tell users there was no undo. The copy existed and was
// unreachable, which is the worst shape a safety net can take.
//
// The design choice worth testing: undo SWAPS rather than restores. Undo is
// itself a data-replacing action, so a one-shot restore would make a mistaken
// undo exactly the kind of unrecoverable loss this exists to prevent.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

String backupOf(String accountName, double balance) => jsonEncode({
  'schemaVersion': 12,
  'accounts': [
    {'id': 'a1', 'name': accountName, 'balance': balance},
  ],
  'transactions': <dynamic>[],
});

void main() {
  group('undoLastImport', () {
    test('nothing to undo reads as false and changes nothing', () async {
      SharedPreferences.setMockInitialValues({});
      final store = SalapifyStore();
      await store.load();
      expect(await store.hasPreviousImportCopy(), isFalse);
      expect(await store.undoLastImport(), isFalse);
      expect(store.data['accounts'], isEmpty);
    });

    test('an import can be put back', () async {
      SharedPreferences.setMockInitialValues({
        storageKey: backupOf('Old wallet', 500),
      });
      final store = SalapifyStore();
      await store.load();
      expect((store.data['accounts'] as List).first['name'], 'Old wallet');

      await store.importBackupText(backupOf('Imported wallet', 900));
      expect((store.data['accounts'] as List).first['name'], 'Imported wallet');
      expect(
        await store.hasPreviousImportCopy(),
        isTrue,
        reason: 'the import must leave a copy to go back to',
      );

      expect(await store.undoLastImport(), isTrue);
      expect((store.data['accounts'] as List).first['name'], 'Old wallet');
    });

    test('undo is itself undoable, so a mistaken undo loses nothing', () async {
      SharedPreferences.setMockInitialValues({
        storageKey: backupOf('Old wallet', 500),
      });
      final store = SalapifyStore();
      await store.load();
      await store.importBackupText(backupOf('Imported wallet', 900));

      await store.undoLastImport();
      expect((store.data['accounts'] as List).first['name'], 'Old wallet');

      // The swap means the imported data became the kept copy.
      expect(await store.hasPreviousImportCopy(), isTrue);
      await store.undoLastImport();
      expect(
        (store.data['accounts'] as List).first['name'],
        'Imported wallet',
        reason: 'a user who undid by mistake must be able to get back',
      );
    });

    test(
      'the restored copy survives a reload, so disk really changed',
      () async {
        SharedPreferences.setMockInitialValues({
          storageKey: backupOf('Old wallet', 500),
        });
        final store = SalapifyStore();
        await store.load();
        await store.importBackupText(backupOf('Imported wallet', 900));
        await store.undoLastImport();

        final reopened = SalapifyStore();
        await reopened.load();
        expect(
          (reopened.data['accounts'] as List).first['name'],
          'Old wallet',
          reason: 'undo must persist, not just repaint',
        );
      },
    );

    test(
      'a corrupt copy fails safely, leaving current data untouched',
      () async {
        SharedPreferences.setMockInitialValues({
          storageKey: backupOf('Current wallet', 700),
          previousBackupKey: '{not json at all',
        });
        final store = SalapifyStore();
        await store.load();

        await expectLater(store.undoLastImport(), throwsA(anything));
        expect(
          (store.data['accounts'] as List).first['name'],
          'Current wallet',
          reason: 'parsing happens before anything is replaced',
        );

        final reopened = SalapifyStore();
        await reopened.load();
        expect(
          (reopened.data['accounts'] as List).first['name'],
          'Current wallet',
        );
      },
    );

    test(
      'start fresh clears the copy, so undo cannot resurrect erased data',
      () async {
        SharedPreferences.setMockInitialValues({
          storageKey: backupOf('Old wallet', 500),
        });
        final store = SalapifyStore();
        await store.load();
        await store.importBackupText(backupOf('Imported wallet', 900));
        expect(await store.hasPreviousImportCopy(), isTrue);

        await store.startFresh();
        expect(
          await store.hasPreviousImportCopy(),
          isFalse,
          reason: 'erase everything must mean everything, including the copy',
        );
        expect(await store.undoLastImport(), isFalse);
      },
    );
  });
}
