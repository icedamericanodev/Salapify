// The home screen tile's privacy switch, end to end: the toggle in Menu, the
// setting it writes, and the strings the tile then shows.
//
// This ships in the SAME release as the tile, never later, and that ordering
// is the point of the first test here. The founder installs the APK, drags the
// tile onto their home screen, and their daily number is sitting in public
// BEFORE any follow up patch could offer an off switch. Shipping the switch
// afterwards does not undo the salary that was already on display.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/main.dart';
import 'package:salapify/money/widget_tile.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/app_harness.dart';

Map<String, dynamic> _blob({bool hide = false, bool lock = false}) => {
  'schemaVersion': 12,
  'settings': {
    'onboarded': true,
    'paydaySchedule': {'mode': 'monthly', 'day': 20},
    if (hide) 'widgetHideAmount': true,
    if (lock) 'appLock': true,
  },
  'accounts': [
    {'id': 'c', 'name': 'Cash', 'kind': 'cash', 'balance': 10000},
  ],
};

/// Loads a real store, rather than assigning to `data`. Assigning leaves
/// `loaded` false, which makes `canWrite` false, which makes the tile show
/// the failed-read face for every case, which quietly passes a "no money on
/// the tile" assertion for entirely the wrong reason.
Future<SalapifyStore> _loaded(Map<String, dynamic> blob) async {
  SharedPreferences.setMockInitialValues({storageKey: jsonEncode(blob)});
  final store = SalapifyStore();
  await store.load();
  return store;
}

Map<String, String> _tile(SalapifyStore store) {
  final settings = (store.data['settings'] as Map?) ?? const {};
  return widgetTileStrings(
    store.data,
    DateTime(2026, 7, 10, 19, 4),
    canWrite: store.canWrite,
    appLock: settings['appLock'] == true,
    hideAmounts: settings['widgetHideAmount'] == true,
    stamp: 'f0.00',
  );
}

void main() {
  testWidgets('the switch is in Menu, off by default, and turns on', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({storageKey: jsonEncode(_blob())});
    final store = SalapifyStore();
    await tester.pumpWidget(SalapifyApp(store: store));
    await tester.pumpAndSettle();
    await openMenu(tester);

    final row = find.text('Hide the amount on the home screen');
    await tester.scrollUntilVisible(row, 300);
    await tester.pumpAndSettle();
    expect(row, findsOneWidget);

    // Off by default: the tile is opt in by nature (somebody has to place it),
    // so defaulting the amount to hidden would make the feature pointless for
    // the people who wanted it.
    expect(_tile(store)['yn_headline'], '₱1,000');

    await tester.tap(
      find.descendant(
        of: find.ancestor(of: row, matching: find.byType(Card)),
        matching: find.byType(Switch),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      (store.data['settings'] as Map)['widgetHideAmount'],
      isTrue,
      reason: 'the switch did not write the setting',
    );
    expect(_tile(store)['yn_headline'], '10 days');
  });

  test(
    'with the switch on, no peso figure exists anywhere on the tile',
    () async {
      // The assertion that matters. Not "the headline changed", but that no
      // rendered string carries money at all, because a person who turns this on
      // is asking for exactly that.
      final store = await _loaded(_blob(hide: true));
      expect(store.canWrite, isTrue, reason: 'a failed read would pass this');
      final t = _tile(store);
      for (final e in t.entries) {
        if (const {
          'yn_stamp',
          'yn_headline_sp',
          'yn_bar_tap',
        }.contains(e.key)) {
          continue;
        }
        expect(
          e.value,
          isNot(contains('₱')),
          reason: 'money still on the tile in ${e.key}',
        );
      }
      expect(t['yn_bar_tap'], '1', reason: 'hiding must not disable logging');
    },
  );

  test('app lock hides the amount on its own, with the switch off', () async {
    // Somebody who locked the whole app has already answered this question.
    // Making them find a second switch to stop their money appearing on the
    // home screen would be a hole in a control they deliberately turned on.
    final store = await _loaded(_blob(lock: true));
    final t = _tile(store);
    expect(t['yn_headline'], 'Salapify');
    expect(t.values.join(' '), isNot(contains('₱')));
  });

  test('the setting survives a backup round trip', () async {
    // An unknown settings key that normalizeSettings dropped would turn the
    // switch back off on every restore, silently, and put the amount back on
    // the home screen of somebody who had turned it off.
    final store = await _loaded(_blob(hide: true));
    final text = store.exportBackupText();
    // The backup wraps the store under a 'data' key alongside app, version
    // and exportedAt. Checked by printing the real shape rather than assumed;
    // the first version of this test read the top level and got null.
    final parsed = jsonDecode(text) as Map<String, dynamic>;
    final settings = (parsed['data'] as Map)['settings'] as Map;
    expect(
      settings['widgetHideAmount'],
      isTrue,
      reason: 'the switch would silently turn itself back on after a restore',
    );
  });
}
