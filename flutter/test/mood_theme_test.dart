// Themes and appearance: the picker switches theme and light/dark/system live,
// persists both in settings so they survive a restart, and the legacy themeMood
// still maps on for old installs. system follows the phone brightness.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/main.dart';
import 'package:salapify/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('themeForKey maps keys and falls back to Barako', () {
    expect(themeForKey('barako').key, 'barako');
    expect(themeForKey('tidal').key, 'tidal');
    expect(themeForKey('mint').key, 'mint');
    expect(themeForKey('disco').key, 'barako');
    expect(themeForKey(null).key, 'barako');
    expect(themeForKey(42).key, 'barako');
  });

  test('resolveThemeChoice honors new keys and maps the legacy mood', () {
    expect(resolveThemeChoice(const {}), ('barako', 'system'));
    expect(resolveThemeChoice(const {'themeMood': 'latte'}), ('barako', 'light'));
    expect(resolveThemeChoice(const {'themeMood': 'barako'}), ('barako', 'dark'));
    expect(
        resolveThemeChoice(const {'themeMood': 'milktea'}), ('barako', 'dark'));
    expect(resolveThemeChoice(const {'themeKey': 'tidal', 'themeMode': 'dark'}),
        ('tidal', 'dark'));
    expect(resolveThemeChoice(const {'themeKey': 'tidal'}), ('tidal', 'system'));
    expect(resolveThemeChoice(const {'themeMode': 'light'}), ('barako', 'light'));
  });

  test('effectiveBrightness resolves the mode against the OS', () {
    expect(effectiveBrightness('light', Brightness.dark), Brightness.light);
    expect(effectiveBrightness('dark', Brightness.light), Brightness.dark);
    expect(effectiveBrightness('system', Brightness.dark), Brightness.dark);
    expect(effectiveBrightness('system', Brightness.light), Brightness.light);
  });

  test('setThemeMode/Key survive junk (non-String) stored theme values', () async {
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
    await store.setThemeKey('mint');
    final s = store.data['settings'] as Map;
    expect(s['themeMode'], 'dark');
    expect(s['themeKey'], 'mint');
    expect(s['monthlyLimit'], 5000); // untouched
  });

  testWidgets('picking a theme and a mode repaints the app and persists',
      (tester) async {
    // Fresh store: system mode, and the test platform is light, so the app
    // opens on Barako light.
    final store = SalapifyStore();
    await tester.pumpWidget(SalapifyApp(store: store));
    await tester.pumpAndSettle();

    expect(Barako.currentTheme.key, 'barako');
    expect(Barako.current.brightness, Brightness.light);
    final beforeApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(beforeApp.theme!.scaffoldBackgroundColor,
        themeForKey('barako').light.background);

    await tester.tap(find.text('Menu'));
    await tester.pumpAndSettle();

    // Pick the Tidal theme. scrollUntilVisible can land a chip flush against a
    // fold, so lift it into view before tapping to keep its center tappable.
    await tester.scrollUntilVisible(find.text('🌊 Tidal'), 100,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 120));
    await tester.pumpAndSettle();
    await tester.tap(find.text('🌊 Tidal'));
    await tester.pumpAndSettle();
    expect(Barako.currentTheme.key, 'tidal');
    expect(Barako.current.brightness, Brightness.light);

    // Switch appearance to Dark.
    await tester.scrollUntilVisible(find.text('Dark'), 100,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 120));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    expect(Barako.current.brightness, Brightness.dark);
    final afterApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(afterApp.theme!.scaffoldBackgroundColor,
        themeForKey('tidal').dark.background);

    // Both choices survive a restart through settings.
    final fresh = SalapifyStore();
    await fresh.load();
    final s = fresh.data['settings'] as Map;
    expect(s['themeKey'], 'tidal');
    expect(s['themeMode'], 'dark');
  });
}
