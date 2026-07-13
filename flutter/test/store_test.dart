// The store round trip: import a real backup (the golden v12rich fixture),
// verify the numbers come from the golden-verified engine, verify it
// persisted, and verify a fresh store loads it back. Also the refusal path:
// a newer backup must throw and leave the store untouched.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/backup.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/money/statements.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final goldens = jsonDecode(
          File('test/goldens/backup_goldens.json').readAsStringSync())
      as Map<String, dynamic>;
  final fixture = (goldens['fixtures'] as Map)['v12rich'];

  test('import persists, reloads, and computes the golden net worth', () async {
    SharedPreferences.setMockInitialValues({});
    final store = SalapifyStore();
    await store.load();
    expect(store.hasData, isFalse);

    await store.importBackupText(
        jsonEncode({'app': 'salapify', 'version': 2, 'data': fixture}));
    expect(store.hasData, isTrue);

    // The numbers flow through the golden-verified engine: bank 42500.5 +
    // asset 15000 + tracked utang (2000 - 500) = 59000.5 assets; debts
    // 12400 + 30000 + payable 1200 = 43600 owed.
    final parts = netWorthParts(store.data);
    expect(parts['assets'], closeTo(59000.5, 1e-9));
    expect(parts['liabilities'], closeTo(43600, 1e-9));
    expect(parts['netWorth'], closeTo(15400.5, 1e-9));

    // Persisted: a brand new store loads the same data back.
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(storageKey), isNotNull);
    final second = SalapifyStore();
    await second.load();
    expect(second.hasData, isTrue);
    expect(netWorthParts(second.data)['netWorth'], closeTo(15400.5, 1e-9));
  });

  test('a newer backup is refused and the store keeps what it had', () async {
    SharedPreferences.setMockInitialValues({});
    final store = SalapifyStore();
    await store.load();
    await expectLater(
      store.importBackupText(jsonEncode({
        'app': 'salapify',
        'data': {'schemaVersion': 99, 'accounts': []}
      })),
      throwsA(isA<NewerBackupException>()),
    );
    expect(store.hasData, isFalse);
  });

  test('junk text is refused with a clear error type', () async {
    SharedPreferences.setMockInitialValues({});
    final store = SalapifyStore();
    await expectLater(
        store.importBackupText('not json at all'),
        throwsA(isA<FormatException>()));
    await expectLater(
        store.importBackupText('{"hello":"world"}'),
        throwsA(isA<NotABackupException>()));
  });
}
