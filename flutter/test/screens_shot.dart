// Renders real screens to PNG files so they can be LOOKED at.
//
// Named without the `_test` suffix ON PURPOSE. `flutter test` only ever
// collects files matching `*_test.dart`, so this can never join a CI run and
// fail there on font differences or a missing reference image. A tag would
// NOT have been enough: tags only filter when you pass --tags, so a
// `*_test.dart` file would have run everywhere by default.
//
// It does live under test/ though, because that is what it is: the analyzer
// only permits test-only helpers like SharedPreferences.setMockInitialValues
// inside test code, and parking it in tool/ turned that into a hard analyze
// failure on the branch check.
//
// Run deliberately, from flutter/:
//   flutter test test/screens_shot.dart --update-goldens
//
// Output lands in test/shots/, which is gitignored: these are working images
// for looking at, not a check anything should depend on.
//
// The gotcha that cost two rounds of founder screenshots: testWidgets runs in
// a FAKE async zone, so awaiting real file I/O (loading the shipped fonts)
// inside it never completes and the test just hangs. Real I/O has to run
// inside tester.runAsync. Without the real fonts every glyph renders as a box,
// which is worse than no screenshot at all because it looks like a bug.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/screens/learn.dart';
import 'package:salapify/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _fonts = {
  'Fraunces': ['assets/fonts/Fraunces-Bold.ttf'],
  'Jakarta': [
    'assets/fonts/PlusJakartaSans-Regular.ttf',
    'assets/fonts/PlusJakartaSans-SemiBold.ttf',
    'assets/fonts/PlusJakartaSans-Bold.ttf',
    'assets/fonts/PlusJakartaSans-ExtraBold.ttf',
  ],
};

/// The Material icon font, loaded separately because it lives in the SDK
/// rather than in this repo.
///
/// Without it every Icon in the app draws as an empty box, which is how the
/// note "some icons draw as boxes in the render but are fine on the phone"
/// came about. That note was true and also a trap: once the icons ARE the
/// thing being reviewed, a screenshot full of boxes proves nothing, and the
/// habit of dismissing boxes is exactly how a genuinely broken icon would
/// slip through. Load the real font and there is nothing left to excuse.
String? _materialIconFont() {
  // FLUTTER_ROOT is set by the flutter tool. Falling back to walking up from
  // the running Dart binary keeps this working if it ever is not: the exact
  // shape of the SDK layout is not something to hardcode.
  final roots = <String>{
    ?Platform.environment['FLUTTER_ROOT'],
    _walkUpToFlutterRoot(Platform.resolvedExecutable) ?? '',
  }..remove('');
  for (final root in roots) {
    final f = File('$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
    if (f.existsSync()) return f.path;
  }
  return null;
}

/// `.../<root>/bin/cache/dart-sdk/bin/dart`, walked back up to the root.
String? _walkUpToFlutterRoot(String exe) {
  var dir = File(exe).parent;
  for (var i = 0; i < 8; i++) {
    if (Directory('${dir.path}/bin/cache/artifacts').existsSync()) {
      return dir.path;
    }
    if (dir.parent.path == dir.path) break;
    dir = dir.parent;
  }
  return null;
}

Future<void> loadRealFonts(WidgetTester tester) async {
  // runAsync is the whole trick: real file reads cannot complete in the fake
  // async zone testWidgets installs.
  await tester.runAsync(() async {
    for (final entry in _fonts.entries) {
      final loader = FontLoader(entry.key);
      for (final path in entry.value) {
        final bytes = await File(path).readAsBytes();
        loader.addFont(Future.value(ByteData.view(bytes.buffer)));
      }
      await loader.load();
    }
    final icons = _materialIconFont();
    if (icons == null) {
      // Say so rather than silently rendering boxes. A quiet fallback here
      // would put the reviewer right back to guessing.
      // ignore: avoid_print
      print('WARNING: Material icon font not found, icons will render as boxes');
      return;
    }
    final iconLoader = FontLoader('MaterialIcons')
      ..addFont(
        File(icons).readAsBytes().then((b) => ByteData.view(b.buffer)),
      );
    await iconLoader.load();
  });
}

void main() {
  testWidgets('the money courses catalog', (tester) async {
    await loadRealFonts(tester);
    SharedPreferences.setMockInitialValues({});
    final store = SalapifyStore();
    await store.load();

    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: salapifyTheme(Barako.current),
        home: LearnScreen(store: store),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('shots/catalog.png'),
    );
  });

  testWidgets('a lesson, opened the way a reader opens it', (tester) async {
    // Navigated into rather than constructed, because the reader is private
    // and, more usefully, because tapping is what a person actually does. A
    // screen built directly in a test can look right while the route into it
    // is broken.
    await loadRealFonts(tester);
    SharedPreferences.setMockInitialValues({});
    final store = SalapifyStore();
    await store.load();

    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: salapifyTheme(Barako.current),
        home: LearnScreen(store: store),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Your first shield: the emergency fund'));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('shots/lesson.png'),
    );
  });
}
