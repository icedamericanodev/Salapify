// The paluwagan collection lives under settings, like treats, so it never
// touches the top-level golden backup contract. This suite proves: the store
// creates, edits, and deletes a paluwagan; it survives a save and reload
// through sanitizeData; it round-trips through export and import; and the
// golden key-set promise holds, a blob without paluwagans must NOT gain the
// key, and a junk value is dropped.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/backup.dart';
import 'package:salapify/data/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const form = {
    'name': 'Office paluwagan',
    'amount': 1000,
    'members': 5,
    'cadence': 'monthly',
    'startDate': '2026-05-10',
    'myTurn': 3,
    'paidCycles': 2,
    'note': 'Kada 15',
  };

  test('add, edit, and delete a paluwagan, persisting each step', () async {
    SharedPreferences.setMockInitialValues({});
    final store = SalapifyStore();
    await store.load();
    expect(store.paluwagans, isEmpty);

    final id = await store.addPaluwagan(form);
    expect(store.paluwagans.length, 1);
    final p = store.paluwagans.single;
    expect(p['id'], id);
    expect(p['name'], 'Office paluwagan');
    expect(p['amount'], 1000);
    expect(p['members'], 5);
    expect(p['myTurn'], 3);
    expect(p['note'], 'Kada 15');

    // A fresh store loads the same paluwagan back (survived save + sanitize).
    final second = SalapifyStore();
    await second.load();
    expect(second.paluwagans.length, 1);
    expect(second.paluwagans.single['name'], 'Office paluwagan');

    await store.updatePaluwagan(id, {...form, 'name': 'Barkada paluwagan'});
    expect(store.paluwagans.single['name'], 'Barkada paluwagan');
    expect(store.paluwagans.single['id'], id, reason: 'id is stable on edit');

    await store.deletePaluwagan(id);
    expect(store.paluwagans, isEmpty);
  });

  test('the engine clamps a bad members count on add', () async {
    SharedPreferences.setMockInitialValues({});
    final store = SalapifyStore();
    await store.load();
    await store.addPaluwagan({...form, 'members': 999, 'myTurn': 999});
    final p = store.paluwagans.single;
    expect(p['members'], 60);
    expect(p['myTurn'], 60);
  });

  test('hasData ignores a settings-only paluwagan (matches treats)', () async {
    // hasData gates the export button and the wipe warning on the top-level
    // collections only; a paluwagan under settings is like a treat, it does
    // not by itself flip hasData. This just pins the current contract.
    SharedPreferences.setMockInitialValues({});
    final store = SalapifyStore();
    await store.load();
    await store.addPaluwagan(form);
    expect(store.hasData, isFalse);
  });

  test('a paluwagan round-trips through export and import', () async {
    SharedPreferences.setMockInitialValues({});
    final store = SalapifyStore();
    await store.load();
    await store.addPaluwagan(form);

    final text = store.exportBackupText();
    final parsed = parseBackupObject(jsonDecode(text));
    final pal = (parsed['settings'] as Map)['paluwagans'] as List;
    expect(pal.length, 1);
    expect((pal.single as Map)['name'], 'Office paluwagan');

    // Import into a clean store reproduces it.
    SharedPreferences.setMockInitialValues({});
    final fresh = SalapifyStore();
    await fresh.load();
    await fresh.importBackupText(text);
    expect(fresh.paluwagans.single['name'], 'Office paluwagan');
  });

  test('sanitize omits the key when there are no paluwagans (golden safety)',
      () {
    final clean = sanitizeData({'accounts': [], 'settings': {}});
    final settings = clean['settings'] as Map;
    expect(settings.containsKey('paluwagans'), isFalse,
        reason:
            'a blob without paluwagans must not gain the key, or the RN key-set '
            'golden breaks');
  });

  test('sanitize drops a junk paluwagans value instead of keeping it', () {
    final clean = sanitizeData({
      'accounts': [],
      'settings': {'paluwagans': 'not a list'},
    });
    final settings = clean['settings'] as Map;
    expect(settings.containsKey('paluwagans'), isFalse);
  });

  test('sanitize normalizes a stored paluwagan to a safe shape', () {
    final clean = sanitizeData({
      'accounts': [],
      'settings': {
        'paluwagans': [
          {
            'id': 'p1',
            // name omitted: a non-string (here absent) triggers the fallback,
            // matching how the accounts and debts sanitizers behave.
            'amount': -5,
            'members': 999,
            'cadence': 'bogus',
            'myTurn': 50,
            'paidCycles': 999,
          },
          'junk',
        ],
      },
    });
    final pal = (clean['settings'] as Map)['paluwagans'] as List;
    expect(pal.length, 1, reason: 'the non-map junk entry is dropped');
    final p = pal.single as Map;
    expect(p['name'], 'Paluwagan');
    expect(p['amount'], 0.0, reason: 'a negative ambag floors at zero');
    expect(p['members'], 60, reason: 'members clamps to 60');
    expect(p['cadence'], 'monthly', reason: 'a bogus cadence falls back');
    expect(p['myTurn'], 50, reason: 'turn 50 is within the clamped 1..60');
    expect(p['paidCycles'], 60, reason: 'paidCycles clamps to members');
  });
}
