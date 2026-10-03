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
import 'package:salapify/widgets/salapify_icon.dart';
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
/// has to win on ONE of them: two looks can legitimately share a near identical
/// page and be told apart entirely by their accents.
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
  // Tall enough that all four tiles build. A tile that was never built reports
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
      // 15 is chosen against real data, not picked out of the air. The bug that
      // set it: two themes that scored 8 on this metric in light were the same
      // theme to the eye, and a user who switched between them thought the
      // picker was broken. The four shipping looks all clear it comfortably (one
      // light, three dark with distinct accents), so the threshold fails the bug
      // and passes everything that legitimately ships.
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

    test('Palawan is first, because first reads as recommended', () {
      expect(barakoThemes.first.key, 'palawan');
    });

    test('the picker is curated to exactly four looks', () {
      // Founder direction: four distinct moods, not a scroll through near
      // twins. A derived count, so adding or dropping a theme reddens here on
      // purpose and forces the decision back to the founder.
      expect(barakoThemes.length, 4);
      expect(barakoThemes.map((t) => t.key).toList(), [
        'palawan',
        'mayon',
        'obsidian',
        'pearl',
      ]);
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

      await tester.tap(find.text('BGC Obsidian'));
      await tester.pumpAndSettle();
      expect((store.data['settings'] as Map)['themeKey'], 'obsidian');

      final fresh = SalapifyStore();
      await fresh.load();
      expect((fresh.data['settings'] as Map)['themeKey'], 'obsidian');
    });

    testWidgets('selection is never carried by colour alone', (tester) async {
      final store = await _store({'themeKey': 'pearl', 'themeMode': 'light'});
      await _pump(tester, store);

      // Exactly one check badge, and it belongs to the selected theme. A ring
      // in the accent colour is not enough on its own: it is invisible to a
      // colourblind user, and this is a screen made entirely of colour.
      expect(find.byIcon(salapifyIcon('chosen')), findsOneWidget);

      // ThemeTile's own root Semantics, not whichever ancestor happens to be
      // outermost. Semantics is the first thing its build returns.
      final pearlTile = find.ancestor(
        of: find.text('Pearl'),
        matching: find.byType(ThemeTile),
      );
      final selected = tester.widget<Semantics>(
        find.descendant(of: pearlTile, matching: find.byType(Semantics)).first,
      );
      expect(selected.properties.selected, isTrue);

      // And the tile that is NOT selected says so, which is the half that
      // makes the assertion above mean anything.
      final palawanTile = find.ancestor(
        of: find.text('Palawan Lagoon'),
        matching: find.byType(ThemeTile),
      );
      final unselected = tester.widget<Semantics>(
        find
            .descendant(of: palawanTile, matching: find.byType(Semantics))
            .first,
      );
      expect(unselected.properties.selected, isFalse);
    });

    testWidgets(
      'the preview draws the theme it is previewing, not the active one',
      (tester) async {
        // The trap this guards: a preview that reads Barako.* getters shows the
        // CURRENT theme on every tile, so they all look identical and the
        // picker silently becomes useless while still rendering perfectly.
        final store = await _store({
          'themeKey': 'palawan',
          'themeMode': 'dark',
        });
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
        // Four themes, each contributing its own page, card and accent (the win
        // gold is theme-invariant, so it does NOT add four). If the preview read
        // the live palette they would collapse to one palette's handful. Eight
        // cleanly separates "each draws its own" (~12) from "all draw the active
        // one" (~4 or fewer).
        expect(
          seen.length,
          greaterThan(8),
          reason:
              'The four previews are drawing from too few distinct colours, '
              'which is what happens when they read the ACTIVE palette instead '
              'of the one they are meant to be showing.',
        );
      },
    );

    testWidgets('the mode control switches appearance', (tester) async {
      final store = await _store();
      await _pump(tester, store);
      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();
      expect((store.data['settings'] as Map)['themeMode'], 'dark');
    });
  });
}
