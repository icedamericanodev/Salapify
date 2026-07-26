// The Appearance screen, and the palette rule that should have existed before
// it.
//
// The bug that prompted all of this was invisible to 765 passing tests and to
// every screenshot, because it was not a crash or a wrong number. Forest in
// light mode WAS Barako in light mode: thirteen of seventeen tokens within 10
// of each other out of 255, four identical to the byte, backgrounds one apart.
// Everything rendered, everything passed, and a user who picked "Warm orange on
// deep green" in daylight saw cream and concluded the picker was broken.
//
// So the first group here is not about the screen at all. It is the rule that
// no two themes may be indistinguishable, which is the kind of thing a person
// can only check by diffing hex columns and will therefore never check.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/screens/appearance.dart';
import 'package:salapify/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The largest single channel gap between two colors, 0 to 255.
int _channelGap(Color a, Color b) {
  int ch(double v) => (v * 255).round();
  return [
    (ch(a.r) - ch(b.r)).abs(),
    (ch(a.g) - ch(b.g)).abs(),
    (ch(a.b) - ch(b.b)).abs(),
  ].reduce((x, y) => x > y ? x : y);
}

/// How far apart two palettes are, judged on the four tokens a person actually
/// sees: the page, the card on it, the accent, and the win color. A theme only
/// has to win on ONE of them, because Tidal and Voltage legitimately share a
/// near identical pale blue page and are told apart entirely by their accents.
int _distance(BarakoPalette a, BarakoPalette b) => [
  _channelGap(a.background, b.background),
  _channelGap(a.card, b.card),
  _channelGap(a.primary, b.primary),
  _channelGap(a.celebrate, b.celebrate),
].reduce((x, y) => x > y ? x : y);

Future<SalapifyStore> _store([Map<String, dynamic>? settings]) async {
  SharedPreferences.setMockInitialValues({
    storageKey: jsonEncode({
      'schemaVersion': 12,
      'accounts': <Map<String, dynamic>>[],
      'transactions': <Map<String, dynamic>>[],
      'settings': ?settings,
    }),
  });
  final s = SalapifyStore();
  await s.load();
  return s;
}

Future<void> _pump(WidgetTester tester, SalapifyStore store) async {
  // Tall enough that all eight tiles build. A tile that was never built reports
  // "not found" for the wrong reason.
  tester.view.physicalSize = const Size(1100, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ListenableBuilder(
      listenable: store,
      builder: (context, _) => MaterialApp(
        theme: salapifyTheme(Barako.current),
        home: AppearanceScreen(store: store),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('no two themes may be the same theme', () {
    test('every pair is distinguishable in both brightnesses', () {
      // 15 is chosen against the real data, not picked out of the air. Before
      // the fix, Barako and Forest in light scored 8, which is invisible. After
      // it, the tightest pair in the whole system is Barako and Ember in light
      // at 19. So this threshold sits in the gap: it fails the bug and passes
      // everything that legitimately ships.
      const floor = 15;
      for (final b in [Brightness.light, Brightness.dark]) {
        for (var i = 0; i < barakoThemes.length; i++) {
          for (var j = i + 1; j < barakoThemes.length; j++) {
            final a = barakoThemes[i];
            final c = barakoThemes[j];
            expect(
              _distance(a.resolve(b), c.resolve(b)),
              greaterThanOrEqualTo(floor),
              reason:
                  '${a.key} and ${c.key} are the same theme in ${b.name}. A '
                  'user who switches between them sees nothing change and '
                  'reasonably concludes the picker is broken. Give one of them '
                  'a different page, card, accent or win color.',
            );
          }
        }
      }
    });

    test('a theme claiming green is green in BOTH brightnesses', () {
      // Forest specifically, because its hint promises green and for a long
      // time it only delivered in the dark. Green means the green channel leads
      // in the surfaces, which is exactly what a cream page fails.
      for (final b in [Brightness.light, Brightness.dark]) {
        final p = themeForKey('forest').resolve(b);
        int ch(double v) => (v * 255).round();
        expect(
          ch(p.background.g),
          greaterThan(ch(p.background.r)),
          reason:
              'Forest promises deep green and its ${b.name} page is not green. '
              'That is the exact shape of the original bug: the theme was only '
              'green in the dark, and its own hint was false in the light.',
        );
      }
    });
  });

  group('the registry stays ours', () {
    test('no theme label carries an emoji', () {
      // Emoji are for icons the USER picked. A theme name is Salapify chrome,
      // and an emoji there cannot be recolored by the palette, so on the
      // SELECTED tile the label flips to onPrimary while the emoji keeps its
      // own colors and the tile reads half broken. It also renders as a box in
      // the review harness, which means this row could never be looked at.
      for (final t in barakoThemes) {
        for (final r in t.label.runes) {
          expect(
            r,
            lessThan(0x2190),
            reason:
                'The ${t.key} label "${t.label}" contains a non-text character. '
                'Salapify authors this name, so it is drawn, not stickered.',
          );
        }
      }
    });

    test('Barako is still first, because first reads as recommended', () {
      expect(barakoThemes.first.key, 'barako');
    });

    test('every hint is short enough to sit in a tile', () {
      // The tile column is about 110dp on a 320dp phone. A 54 character hint
      // wrapped to four ragged lines there.
      for (final t in barakoThemes) {
        expect(
          t.hint.length,
          lessThanOrEqualTo(36),
          reason: '${t.key}: "${t.hint}" is too long for a tile column.',
        );
      }
    });
  });

  group('the screen', () {
    testWidgets('every theme is present, and picking one applies and persists', (
      tester,
    ) async {
      final store = await _store();
      await _pump(tester, store);

      for (final t in barakoThemes) {
        expect(
          find.text(t.label),
          findsOneWidget,
          reason:
              '${t.key} vanished from the picker. A grid that silently drops a '
              'destination renders perfectly.',
        );
      }

      await tester.tap(find.text('Voltage'));
      await tester.pumpAndSettle();
      expect((store.data['settings'] as Map)['themeKey'], 'voltage');

      final fresh = SalapifyStore();
      await fresh.load();
      expect((fresh.data['settings'] as Map)['themeKey'], 'voltage');
    });

    testWidgets('selection is never carried by colour alone', (tester) async {
      final store = await _store({'themeKey': 'mint', 'themeMode': 'light'});
      await _pump(tester, store);

      // Exactly one check badge, and it belongs to the selected theme. A ring
      // in the accent colour is not enough on its own: it is invisible to a
      // colourblind user, and this is a screen made entirely of colour.
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);

      // ThemeTile's own root Semantics, not whichever ancestor happens to be
      // outermost. Semantics is the first thing its build returns.
      final mintTile = find.ancestor(
        of: find.text('Mint'),
        matching: find.byType(ThemeTile),
      );
      final selected = tester.widget<Semantics>(
        find.descendant(of: mintTile, matching: find.byType(Semantics)).first,
      );
      expect(selected.properties.selected, isTrue);

      // And the tile that is NOT selected says so, which is the half that
      // makes the assertion above mean anything.
      final barakoTile = find.ancestor(
        of: find.text('Barako'),
        matching: find.byType(ThemeTile),
      );
      final unselected = tester.widget<Semantics>(
        find.descendant(of: barakoTile, matching: find.byType(Semantics)).first,
      );
      expect(unselected.properties.selected, isFalse);
    });

    testWidgets('the preview draws the theme it is previewing, not the active one', (
      tester,
    ) async {
      // The trap this guards: a preview that reads Barako.* getters shows the
      // CURRENT theme eight times, so every tile looks identical and the
      // picker silently becomes useless while still rendering perfectly.
      final store = await _store({'themeKey': 'barako', 'themeMode': 'dark'});
      await _pump(tester, store);

      final seen = <Color>{};
      for (final t in barakoThemes) {
        final tile = find.ancestor(
          of: find.text(t.label),
          matching: find.byType(ThemeTile),
        );
        expect(tile, findsOneWidget);
        final boxes = tester.widgetList<Container>(
          find.descendant(of: tile, matching: find.byType(Container)),
        );
        for (final b in boxes) {
          final d = b.decoration;
          if (d is BoxDecoration && d.color != null) seen.add(d.color!);
        }
      }
      // Eight themes, each contributing its own page, card, accent and win
      // colour. If the preview read the live palette they would collapse into
      // a handful of repeats.
      expect(
        seen.length,
        greaterThan(16),
        reason:
            'The eight previews are drawing from too few distinct colours, '
            'which is what happens when they read the ACTIVE palette instead '
            'of the one they are meant to be showing.',
      );
    });

    testWidgets('the mode control switches appearance', (tester) async {
      final store = await _store();
      await _pump(tester, store);
      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();
      expect((store.data['settings'] as Map)['themeMode'], 'dark');
    });
  });
}
