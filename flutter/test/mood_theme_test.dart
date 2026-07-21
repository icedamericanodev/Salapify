// Mood themes: the picker switches the palette live, persists the mood in
// settings so it survives a restart, and unknown moods fall back to Latte.

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

  test('paletteForMood maps moods and falls back to latte', () {
    expect(paletteForMood('barako').mood, 'barako');
    expect(paletteForMood('milktea').mood, 'milktea');
    expect(paletteForMood('latte').mood, 'latte');
    expect(paletteForMood(null).mood, 'latte');
    expect(paletteForMood('disco').mood, 'latte');
    expect(paletteForMood(42).mood, 'latte');
  });

  testWidgets('switching the mood repaints the app and persists',
      (tester) async {
    final store = SalapifyStore();
    await tester.pumpWidget(SalapifyApp(store: store));
    await tester.pumpAndSettle();

    expect(Barako.current.mood, 'latte');
    final beforeApp =
        tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(beforeApp.theme!.scaffoldBackgroundColor,
        lattePalette.background);

    await tester.tap(find.text('Menu'));

    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('🌙 Barako'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('🌙 Barako'));
    await tester.pumpAndSettle();

    expect(Barako.current.mood, 'barako');
    final afterApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(afterApp.theme!.scaffoldBackgroundColor,
        barakoPalette.background);

    // The mood survives a restart through settings.
    final fresh = SalapifyStore();
    await fresh.load();
    expect((fresh.data['settings'] as Map)['themeMood'], 'barako');
  });
}
