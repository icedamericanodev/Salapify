// Can the tile actually be READ?
//
// This is the one thing "look at the screen before shipping a screen" cannot
// do for the widget. The golden harness renders Flutter widgets; a home screen
// tile is RemoteViews drawn by the launcher, so no screenshot in this repo has
// ever shown it, and none can. The rule still applies, so it applies as a
// measurement instead.
//
// What it caught, on the release that would have cost a manual install:
// buildValues sent the CURRENTLY RESOLVED palette, while the card behind it is
// fixed dark on every phone by widget_bg.xml. In light mode that made the
// daily number #241812 on #251A13, a contrast ratio of 1.02 to 1. Not hard to
// read, invisible. The default appearance is 'system' and most Android phones
// ship in light mode, so this was the DEFAULT experience of the feature.
//
// It survived every other check because home_tile_values_test forces dark in
// setUp, the one light-mode test only asserts that light differs from dark,
// and the founder uses dark.

import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart' show Brightness;
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/services/home_tile.dart';
import 'package:salapify/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The literal in res/drawable/widget_bg.xml. Hardcoded on purpose: it is a
/// value frozen in the APK, so a Dart constant that drifted from it would be
/// measuring a colour no phone draws.
const int cardArgb = 0xFF251A13;

/// WCAG relative luminance.
double _luminance(int argb) {
  double channel(int c) {
    final s = c / 255.0;
    return s <= 0.03928
        ? s / 12.92
        : math.pow((s + 0.055) / 1.055, 2.4) as double;
  }

  final r = channel((argb >> 16) & 0xFF);
  final g = channel((argb >> 8) & 0xFF);
  final b = channel(argb & 0xFF);
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

double contrast(int a, int b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

int parseHex(String s) => int.parse(s.substring(1), radix: 16);

void main() {
  final now = DateTime(2026, 7, 10, 19, 4);

  Future<SalapifyStore> loaded() async {
    SharedPreferences.setMockInitialValues({
      storageKey: jsonEncode({
        'schemaVersion': 12,
        'settings': {
          'onboarded': true,
          'paydaySchedule': {'mode': 'monthly', 'day': 20},
        },
        'accounts': [
          {'id': 'c', 'name': 'Cash', 'kind': 'cash', 'balance': 10000},
        ],
      }),
    });
    final store = SalapifyStore();
    await store.load();
    return store;
  }

  test('the contrast maths agrees with the values WCAG defines', () {
    // A guard on the guard. If _luminance were wrong, every assertion below
    // would pass or fail for reasons that have nothing to do with the tile.
    expect(contrast(0xFFFFFFFF, 0xFF000000), closeTo(21.0, 0.01));
    expect(contrast(0xFF251A13, 0xFF251A13), closeTo(1.0, 0.001));
  });

  test('every theme, at BOTH brightnesses, is readable on the fixed card', () {
    // The failure this replaces is not subtle and not rare: it was every
    // light-mode user of every theme, which is the default on most phones.
    //
    // 4.5 is the WCAG AA bar for body text. The headline is 28sp bold, which
    // AA would let off at 3.0, but the sub line and the "as of" line are 12sp
    // and 10sp and take the same colours, so the strict bar is the honest one.
    return loaded().then((store) {
      final failures = <String>[];
      for (final theme in barakoThemes) {
        for (final b in [Brightness.dark, Brightness.light]) {
          Barako.currentTheme = theme;
          Barako.current = theme.resolve(b);
          final v = HomeTile.buildValues(store, now);
          for (final key in ['yn_text', 'yn_muted', 'yn_accent']) {
            final ratio = contrast(parseHex(v[key]!), cardArgb);
            // muted is a caption colour by design and sits lower than body
            // text everywhere in the app; 3.0 is the AA large-text bar and is
            // what the dark palettes already clear.
            final bar = key == 'yn_muted' ? 3.0 : 4.5;
            if (ratio < bar) {
              failures.add(
                '${theme.key} ${b.name} $key ${v[key]} '
                '${ratio.toStringAsFixed(2)} needs $bar',
              );
            }
          }
        }
      }
      expect(
        failures,
        isEmpty,
        reason:
            'these colours are drawn on the fixed #251A13 card and cannot be '
            'read:\n${failures.join('\n')}',
      );
    });
  });

  test('the palette pushed does not change with brightness', () {
    // The positive half. The card is fixed dark, so the tile must ALWAYS take
    // the dark palette; following the app's resolved brightness is precisely
    // the bug. This is the assertion that stops somebody "fixing" the test
    // above by nudging one colour until it scrapes past 4.5 in light mode.
    return loaded().then((store) {
      for (final theme in barakoThemes) {
        Barako.currentTheme = theme;
        Barako.current = theme.resolve(Brightness.dark);
        final dark = HomeTile.buildValues(store, now);
        Barako.current = theme.resolve(Brightness.light);
        final light = HomeTile.buildValues(store, now);
        for (final key in ['yn_text', 'yn_muted', 'yn_accent']) {
          expect(
            light[key],
            dark[key],
            reason: '${theme.key} $key follows app brightness, and must not',
          );
        }
      }
    });
  });

  test('the tile still changes with the chosen THEME', () {
    // The other half again: freezing brightness must not freeze the theme.
    // Without this, returning a hardcoded Barako dark would pass everything
    // above and silently unpick the theme picker.
    return loaded().then((store) {
      final accents = <String>{};
      for (final theme in barakoThemes) {
        Barako.currentTheme = theme;
        Barako.current = theme.resolve(Brightness.light);
        accents.add(HomeTile.buildValues(store, now)['yn_accent']!);
      }
      expect(
        accents.length,
        greaterThan(1),
        reason: 'every theme pushes the same accent, so the picker is dead',
      );
    });
  });
}
