// The greeting name is stored, survives a backup, and can be taken back.
//
// It is a CONDITIONAL settings key, the same contract as steadyPay and
// paluwagans: present only when there is a real name, absent otherwise. That
// matters beyond tidiness, because the RN-generated golden fixtures never
// carry this key and must not gain it. A key that appears from nowhere breaks
// the golden key-set contract, and it does it quietly.
//
// The half most worth pinning is CLEARING. A user who gives a name and
// changes their mind must be able to take it back without deleting anything
// else, and "cleared" has to mean the key is gone rather than set to an empty
// string that every reader then has to remember to treat as absent.

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/backup.dart';
import 'package:salapify/data/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<SalapifyStore> _fresh() async {
  SharedPreferences.setMockInitialValues({});
  final store = SalapifyStore();
  await store.load();
  return store;
}

Map<String, dynamic> _settingsOf(Map<String, dynamic> data) =>
    ((data['settings'] as Map?) ?? const {}).cast<String, dynamic>();

void main() {
  group('storing it', () {
    test('a fresh install has no name and no key', () async {
      final store = await _fresh();
      expect(store.displayName, isNull);
      expect(
        _settingsOf(store.data).containsKey('displayName'),
        isFalse,
        reason:
            'A brand new install invented a name key. Every RN golden fixture '
            'lacks it, so gaining one silently breaks the key-set contract.',
      );
    });

    test('setting a name stores the tidied version', () async {
      final store = await _fresh();
      await store.setDisplayName('  Ana   Maria ');
      expect(store.displayName, 'Ana Maria');
    });

    test('it survives closing and reopening the app', () async {
      final store = await _fresh();
      await store.setDisplayName('Ana');
      final reopened = SalapifyStore();
      await reopened.load();
      expect(reopened.displayName, 'Ana');
    });
  });

  group('taking it back', () {
    test('clearing REMOVES the key rather than emptying it', () async {
      final store = await _fresh();
      await store.setDisplayName('Ana');
      expect(_settingsOf(store.data).containsKey('displayName'), isTrue);

      await store.setDisplayName(null);
      expect(store.displayName, isNull);
      expect(
        _settingsOf(store.data).containsKey('displayName'),
        isFalse,
        reason:
            'Cleared left an empty string behind. Every future reader then '
            'has to remember that "" means absent, and one that forgets '
            'greets the user as nobody.',
      );
    });

    test('a name of only spaces clears it, same as null', () async {
      final store = await _fresh();
      await store.setDisplayName('Ana');
      await store.setDisplayName('    ');
      expect(store.displayName, isNull);
      expect(_settingsOf(store.data).containsKey('displayName'), isFalse);
    });

    test('clearing touches nothing else in settings', () async {
      final store = await _fresh();
      await store.setPro(true);
      await store.setDisplayName('Ana');
      await store.setDisplayName(null);
      expect(
        _settingsOf(store.data)['pro'],
        true,
        reason: 'taking back a name deleted an unrelated setting',
      );
    });
  });

  group('through a backup', () {
    test('a real name makes the round trip', () {
      final out = sanitizeData({
        'settings': {'displayName': 'Ana'},
      });
      expect(_settingsOf(out)['displayName'], 'Ana');
    });

    test('a backup without the key does not gain one', () {
      final out = sanitizeData({'settings': {}});
      expect(
        _settingsOf(out).containsKey('displayName'),
        isFalse,
        reason:
            'RN-generated fixtures never carry this key. Gaining it here is '
            'exactly the silent key-set drift the conditional rule exists to '
            'prevent.',
      );
    });

    test('a hand-edited backup cannot smuggle junk to the top of Home', () {
      // A backup file is the one input a user can edit by hand, so these are
      // the realistic hostile shapes rather than theoretical ones.
      for (final junk in <Object>[
        42,
        ['Ana'],
        {'name': 'Ana'},
        '',
        '   ',
      ]) {
        final out = sanitizeData({
          'settings': {'displayName': junk},
        });
        expect(
          _settingsOf(out).containsKey('displayName'),
          isFalse,
          reason: 'a displayName of $junk survived normalization',
        );
      }
    });

    test('a pasted paragraph is cut to something that fits on a line', () {
      final out = sanitizeData({
        'settings': {'displayName': 'A' * 4000},
      });
      final got = _settingsOf(out)['displayName'] as String;
      expect(got.length, lessThanOrEqualTo(24));
    });
  });
}
