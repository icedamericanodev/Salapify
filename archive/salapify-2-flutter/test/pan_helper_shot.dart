// Founder specimen for f4.65: Pan's floating helper on the shell, and the
// swipeable tip sheet it opens. NOT a `_test` file. Run with --update-goldens.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
// storageKey is re-exported by store.dart, so importing it here too is an
// unnecessary_import the analyzer (and the preview build) rejects.
import 'package:salapify/data/store.dart';
import 'package:salapify/screens/shell.dart';
import 'package:salapify/theme.dart';

import 'screens_shot.dart' show loadRealFonts, livedInBlob;

void main() {
  testWidgets('the floating Pan helper on the shell, dark', (tester) async {
    await loadRealFonts(tester);
    SharedPreferences.setMockInitialValues({
      storageKey: jsonEncode(livedInBlob),
    });
    Barako.currentTheme = themeForKey('palawan');
    Barako.current = themeForKey('palawan').resolve(Brightness.dark);
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final store = SalapifyStore();
    await store.load();

    await tester.pumpWidget(
      MaterialApp(
        theme: salapifyTheme(Barako.current),
        debugShowCheckedModeBanner: false,
        home: ShellScreen(store: store),
      ),
    );
    await tester.pumpAndSettle();
    // Let Pan's PNG finish decoding before the first capture, or the bubble
    // photographs as a bare disc (the face loads async and is fine on device).
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();

    // Shot 1: Pan sitting on the Home tab.
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('shots/pan-helper-shell-dark.png'),
    );

    // Shot 2: open the tip sheet and photograph it.
    await tester.tap(find.bySemanticsLabel(RegExp('Pan, your money helper')));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('shots/pan-helper-tips-dark.png'),
    );
  });
}
