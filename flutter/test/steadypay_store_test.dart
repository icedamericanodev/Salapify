// The Steady Pay stored field (settings.steadyPay, founder approved
// 2026-07-24): a CONDITIONAL settings key like paluwagans and treats. The
// golden safety contract: a blob without it never gains the key, junk is
// dropped, a valid accepted draw survives save, reload, export, and import,
// and clearing removes the key entirely.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/backup.dart';
import 'package:salapify/data/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('set, reload, export, import, and clear round-trip', () async {
    SharedPreferences.setMockInitialValues({});
    final store = SalapifyStore();
    await store.load();

    await store.setSteadyPay(2500);
    final sp = (store.data['settings'] as Map)['steadyPay'] as Map;
    expect(sp['amount'], 2500);
    expect((sp['acceptedAt'] as String).length, 10);

    // A fresh store loads it back (survived save + sanitize).
    final second = SalapifyStore();
    await second.load();
    expect(
      ((second.data['settings'] as Map)['steadyPay'] as Map)['amount'],
      2500,
    );

    // Export carries it; import into a clean store reproduces it.
    final text = store.exportBackupText();
    SharedPreferences.setMockInitialValues({});
    final fresh = SalapifyStore();
    await fresh.load();
    await fresh.importBackupText(text);
    expect(
      ((fresh.data['settings'] as Map)['steadyPay'] as Map)['amount'],
      2500,
    );

    // Clearing removes the key entirely, not just the amount.
    await fresh.clearSteadyPay();
    expect((fresh.data['settings'] as Map).containsKey('steadyPay'), isFalse);
  });

  test('the store boundary rejects a bad amount (defense in depth)', () async {
    SharedPreferences.setMockInitialValues({});
    final store = SalapifyStore();
    await store.load();
    expect(() => store.setSteadyPay(0), throwsArgumentError);
    expect(() => store.setSteadyPay(-5), throwsArgumentError);
    expect(() => store.setSteadyPay(double.infinity), throwsArgumentError);
    expect(
      (store.data['settings'] as Map).containsKey('steadyPay'),
      isFalse,
      reason: 'nothing persisted by any rejected call',
    );
  });

  test('a blob without steadyPay never gains the key (golden safety)', () {
    final clean = sanitizeData({'accounts': [], 'settings': {}});
    expect(
      (clean['settings'] as Map).containsKey('steadyPay'),
      isFalse,
      reason:
          'RN-generated fixtures must not gain the key, or the golden '
          'key-set contract breaks',
    );
  });

  test('junk values are dropped, not kept', () {
    for (final junk in [
      'nope',
      42,
      {'amount': 'abc'},
      {'amount': -5},
      {'amount': double.infinity},
    ]) {
      final clean = sanitizeData({
        'accounts': [],
        'settings': {'steadyPay': junk},
      });
      expect(
        (clean['settings'] as Map).containsKey('steadyPay'),
        isFalse,
        reason: 'junk $junk must not survive',
      );
    }
  });

  test('a valid stored draw normalizes to a safe shape', () {
    final clean = sanitizeData({
      'accounts': [],
      'settings': {
        'steadyPay': {
          'amount': '3000',
          'acceptedAt': '2026-07-24',
          'junkKey': 'x',
        },
      },
    });
    final sp = (clean['settings'] as Map)['steadyPay'] as Map;
    expect(sp['amount'], 3000.0, reason: 'string amounts read the JS way');
    expect(sp['acceptedAt'], '2026-07-24');
    expect(
      sp.containsKey('junkKey'),
      isFalse,
      reason: 'only the known fields survive',
    );
  });

  test('the backup wrapper round-trips it through parseBackupObject', () async {
    SharedPreferences.setMockInitialValues({});
    final store = SalapifyStore();
    await store.load();
    await store.setSteadyPay(1800);
    final parsed = parseBackupObject(jsonDecode(store.exportBackupText()));
    expect(((parsed['settings'] as Map)['steadyPay'] as Map)['amount'], 1800);
  });
}
