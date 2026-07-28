// The layer between the store and the tested string builder.
//
// A retrospective proved this layer was making three decisions nobody was
// checking. The claim in the design was "every decision lives in the pure
// function", and that was true of money/widget_tile.dart and false of
// services/home_tile.dart. Breaking all three left 1026 tests green and
// `flutter analyze` clean.
//
// What each one is on a real phone, which is why they are worth their own
// file: the wrong app lock key means the daily number showing on the home
// screen of a phone somebody deliberately locked; the wrong hide key means a
// privacy switch that does nothing when it is flipped; and the wrong palette
// key means an invisible Log button on the tile whose whole point is that
// button.

import 'dart:convert';

import 'package:flutter/material.dart' show Brightness;
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/services/home_tile.dart';
import 'package:salapify/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _blob({bool lock = false, bool hide = false}) => {
  'schemaVersion': 12,
  'settings': {
    'onboarded': true,
    'paydaySchedule': {'mode': 'monthly', 'day': 20},
    if (lock) 'appLock': true,
    if (hide) 'widgetHideAmount': true,
  },
  'accounts': [
    {'id': 'c', 'name': 'Cash', 'kind': 'cash', 'balance': 10000},
  ],
};

Future<SalapifyStore> _loaded(Map<String, dynamic> blob) async {
  SharedPreferences.setMockInitialValues({storageKey: jsonEncode(blob)});
  final store = SalapifyStore();
  await store.load();
  return store;
}

String _hex(int argb) =>
    '#${argb.toRadixString(16).padLeft(8, '0').toUpperCase()}';

void main() {
  final now = DateTime(2026, 7, 10, 19, 4);

  setUp(() {
    Barako.current = Barako.currentTheme.resolve(Brightness.dark);
  });

  test('the app lock setting actually reaches the tile', () {
    // Breaking this means a locked phone showing the number on its home
    // screen, which is visible before any unlock. It is the single worst
    // outcome this feature has.
    return _loaded(_blob(lock: true)).then((store) {
      final v = HomeTile.buildValues(store, now);
      expect(v['yn_headline'], 'Salapify');
      expect(v.values.join(' '), isNot(contains('₱')));
    });
  });

  test('the hide amount setting actually reaches the tile', () async {
    final store = await _loaded(_blob(hide: true));
    final v = HomeTile.buildValues(store, now);
    expect(v['yn_headline'], '10 days');
    expect(v.values.join(' '), isNot(contains('₱')));
  });

  test('with neither set, the number is shown', () async {
    // The half that proves the two above are guards and not just an off
    // switch stuck on.
    final store = await _loaded(_blob());
    expect(HomeTile.buildValues(store, now)['yn_headline'], '₱1,000');
  });

  test('all three colours are written, as parseable hex', () async {
    // Kotlin calls Color.parseColor on each. A value it cannot parse falls
    // back, so a malformed colour is survivable; a MISSING key is what makes
    // the Log bar invisible against the card.
    final store = await _loaded(_blob());
    final v = HomeTile.buildValues(store, now);
    for (final key in ['yn_text', 'yn_muted', 'yn_accent']) {
      expect(v[key], isNotNull, reason: '$key never written');
      expect(
        RegExp(r'^#[0-9A-F]{8}$').hasMatch(v[key]!),
        isTrue,
        reason: '$key is "${v[key]}", which Color.parseColor cannot read',
      );
    }
  });

  test('each colour is the one it claims to be, not just any colour', () async {
    // The failure this catches: the Log bar taking the muted colour instead
    // of the accent, which on the dark card is close to invisible. Comparing
    // against the live palette rather than a hardcoded hex, so a theme
    // retune cannot make this test wrong.
    final store = await _loaded(_blob());
    final v = HomeTile.buildValues(store, now);
    expect(v['yn_text'], _hex(Barako.text.toARGB32()));
    expect(v['yn_muted'], _hex(Barako.muted.toARGB32()));
    expect(v['yn_accent'], _hex(Barako.primary.toARGB32()));
    expect(
      v['yn_accent'],
      isNot(v['yn_muted']),
      reason: 'the Log bar would be drawn in the same colour as the caption',
    );
  });

  test('the palette follows the theme, it is not frozen at one', () async {
    final store = await _loaded(_blob());
    final dark = HomeTile.buildValues(store, now)['yn_text'];
    Barako.current = Barako.currentTheme.resolve(Brightness.light);
    final light = HomeTile.buildValues(store, now)['yn_text'];
    expect(
      light,
      isNot(dark),
      reason: 'the tile would keep the old palette after a theme switch',
    );
  });

  test(
    'the stamp written is the build stamp, not the whole sentence',
    () async {
      // It is never rendered. It exists so a tile that looks wrong can be
      // traced to the build that wrote it, which only works if it is short.
      final store = await _loaded(_blob());
      final stamp = HomeTile.buildValues(store, now)['yn_stamp']!;
      expect(RegExp(r'^f\d+\.\d+$').hasMatch(stamp), isTrue, reason: stamp);
    },
  );

  test('a store that could not be read shows the safe face', () async {
    // canWrite has to reach the tile too, or a failed read prints a
    // confident number computed from an empty default.
    SharedPreferences.setMockInitialValues({storageKey: '{ not json'});
    final store = SalapifyStore();
    await store.load();
    expect(store.canWrite, isFalse, reason: 'the fixture did not break it');
    final v = HomeTile.buildValues(store, now);
    expect(v['yn_headline'], 'Open Salapify');
    expect(v['yn_bar_tap'], '0');
  });

  test('a widget tap asking to log is taken exactly once', () {
    // Reading clears it, so a rebuild cannot reopen the log sheet behind the
    // person's back after they have dismissed it.
    HomeTile.pendingUri = 'salapify://log';
    expect(HomeTile.takeLogRequest(), isTrue);
    expect(HomeTile.takeLogRequest(), isFalse, reason: 'it fired twice');

    HomeTile.pendingUri = 'salapify://home';
    expect(
      HomeTile.takeLogRequest(),
      isFalse,
      reason: 'the plain tile tap opened the log sheet',
    );
    expect(HomeTile.pendingUri, isNull, reason: 'a stale tap survived');
  });
}
