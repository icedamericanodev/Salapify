// Themes and appearance: the picker switches theme and light/dark/system live,
// persists both in settings so they survive a restart, and the legacy themeMood
// still maps on for old installs. system follows the phone brightness.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/screens/menu.dart';
import 'package:salapify/main.dart';
import 'package:salapify/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/app_harness.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(onboardedEmptyStorage());
  });

  test('themeForKey maps keys and falls back to the default', () {
    expect(themeForKey('palawan').key, 'palawan');
    expect(themeForKey('mayon').key, 'mayon');
    expect(themeForKey('obsidian').key, 'obsidian');
    // A retired theme a backup still names, and pure junk, both fall back to
    // the default (Palawan, the first theme), not to a crash.
    expect(themeForKey('tidal').key, 'palawan');
    expect(themeForKey('disco').key, 'palawan');
    expect(themeForKey(null).key, 'palawan');
    expect(themeForKey(42).key, 'palawan');
  });

  test('resolveThemeChoice honors new keys and maps the legacy mood', () {
    expect(resolveThemeChoice(const {}), ('palawan', 'system'));
    expect(resolveThemeChoice(const {'themeMood': 'latte'}), (
      'palawan',
      'light',
    ));
    expect(resolveThemeChoice(const {'themeMood': 'barako'}), (
      'palawan',
      'dark',
    ));
    expect(resolveThemeChoice(const {'themeMood': 'milktea'}), (
      'palawan',
      'dark',
    ));
    expect(
      resolveThemeChoice(const {'themeKey': 'obsidian', 'themeMode': 'dark'}),
      ('obsidian', 'dark'),
    );
    expect(resolveThemeChoice(const {'themeKey': 'obsidian'}), (
      'obsidian',
      'system',
    ));
    expect(resolveThemeChoice(const {'themeMode': 'light'}), (
      'palawan',
      'light',
    ));
  });

  test('effectiveBrightness resolves the mode against the OS', () {
    expect(effectiveBrightness('light', Brightness.dark), Brightness.light);
    expect(effectiveBrightness('dark', Brightness.light), Brightness.dark);
    expect(effectiveBrightness('system', Brightness.dark), Brightness.dark);
    expect(effectiveBrightness('system', Brightness.light), Brightness.light);
  });

  test(
    'setThemeMode/Key survive junk (non-String) stored theme values',
    () async {
      // A hand-edited or future backup could carry numeric theme values. The
      // writers must not throw a cast, and must leave other settings intact.
      SharedPreferences.setMockInitialValues({
        storageKey: jsonEncode({
          'settings': {'themeKey': 42, 'themeMode': true, 'monthlyLimit': 5000},
        }),
      });
      final store = SalapifyStore();
      await store.load();
      await store.setThemeMode('dark');
      await store.setThemeKey('obsidian');
      final s = store.data['settings'] as Map;
      expect(s['themeMode'], 'dark');
      expect(s['themeKey'], 'obsidian');
      expect(s['monthlyLimit'], 5000); // untouched
    },
  );

  testWidgets('picking a theme and a mode repaints the app and persists', (
    tester,
  ) async {
    // Fresh store: system mode, and the test platform is light, so the app
    // opens on the default (Palawan Lagoon) light.
    final store = SalapifyStore();
    await tester.pumpWidget(SalapifyApp(store: store));
    await tester.pumpAndSettle();

    expect(Barako.currentTheme.key, 'palawan');
    expect(Barako.current.brightness, Brightness.light);
    final beforeApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(
      beforeApp.theme!.scaffoldBackgroundColor,
      themeForKey('palawan').light.background,
    );

    // The picker moved off Menu and onto its own screen, so the row is the way
    // in now. Its blurb doubles as the current choice, which is the whole
    // reason the row carries state instead of a description. Assert the blurb
    // before opening, because it is only visible from Menu.
    await openMenu(tester);
    // Appearance lives directly in the SETTINGS card now (menu.dart),
    // reached by a single _navRow, no section to expand first.
    await scrollTo(
      tester,
      find.text('Appearance'),
      scope: find.byType(MenuScreen),
      delta: 100,
    );
    expect(find.text('Palawan Lagoon, System'), findsOneWidget);
    await tester.tap(find.text('Appearance'));
    await tester.pumpAndSettle();

    // Pick the Mayon Sunset theme. scrollUntilVisible can land a tile flush
    // against a fold, so lift it into view before tapping to keep its center
    // tappable.
    await tester.scrollUntilVisible(
      find.text('Mayon Sunset'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 120));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mayon Sunset'));
    await tester.pumpAndSettle();
    expect(Barako.currentTheme.key, 'mayon');
    expect(Barako.current.brightness, Brightness.light);

    // Switch appearance to Dark.
    await tester.scrollUntilVisible(
      find.text('Dark'),
      -100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    expect(Barako.current.brightness, Brightness.dark);
    final afterApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(
      afterApp.theme!.scaffoldBackgroundColor,
      themeForKey('mayon').dark.background,
    );

    // Both choices survive a restart through settings.
    final fresh = SalapifyStore();
    await fresh.load();
    final s = fresh.data['settings'] as Map;
    expect(s['themeKey'], 'mayon');
    expect(s['themeMode'], 'dark');
  });
}
