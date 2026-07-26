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

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/money/pan_mood.dart';
import 'package:salapify/screens/budget.dart';
import 'package:salapify/screens/history.dart';
import 'package:salapify/screens/insights.dart';
import 'package:salapify/screens/learn.dart';
import 'package:salapify/screens/menu.dart';
import 'package:salapify/screens/overview.dart';
import 'package:salapify/screens/utang.dart';
import 'package:salapify/theme.dart';
import 'package:salapify/widgets/pan_mascot.dart';
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

/// Decode Pan's four faces before anything is pumped.
///
/// Same trap as the fonts, and it bit for the same reason: Image.asset decodes
/// ASYNCHRONOUSLY, and testWidgets runs on a fake clock where that never
/// completes. Without this, Pan rendered only when the image cache happened to
/// be warm from an earlier test in the same run, so one shot showed him and
/// the next showed nothing. A harness that renders by luck is worse than no
/// harness, because it makes "I looked at it" mean nothing.
///
/// Resolving the ImageStream primes the same global cache the widget reads,
/// and unlike precacheImage it needs no BuildContext, so it can run before
/// anything is pumped.
Future<void> loadPanFaces(WidgetTester tester) async {
  await tester.runAsync(() async {
    for (final mood in PanMood.values) {
      final provider = AssetImage(panAssetFor(mood));
      final completer = Completer<void>();
      final stream = provider.resolve(ImageConfiguration.empty);
      late ImageStreamListener listener;
      listener = ImageStreamListener(
        (image, sync) {
          if (!completer.isCompleted) completer.complete();
          stream.removeListener(listener);
        },
        onError: (e, st) {
          if (!completer.isCompleted) completer.completeError(e);
          stream.removeListener(listener);
        },
      );
      stream.addListener(listener);
      await completer.future;
    }
  });
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

/// Pump one screen at one brightness and write the PNG.
///
/// Both brightnesses on purpose. The renderer drew only the light palette for
/// its whole life, so every dark-mode contrast question had to go to the
/// founder's phone and come back as a photo. Dark is also the mode the
/// founder actually uses, which made the one palette being checked the one
/// palette nobody was looking at.
Future<void> shoot(
  WidgetTester tester,
  String name,
  Widget Function(SalapifyStore) build, {
  required Brightness brightness,
}) async {
  await loadRealFonts(tester);
    await loadPanFaces(tester);
  SharedPreferences.setMockInitialValues({});
  final store = SalapifyStore();
  await store.load();

  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  // Resolve the palette BEFORE building, the same order main.dart uses, so
  // every Barako.* read below sees the brightness under test.
  Barako.current = Barako.currentTheme.resolve(brightness);

  await tester.pumpWidget(
    MaterialApp(
      theme: salapifyTheme(Barako.current),
      home: build(store),
    ),
  );
  await tester.pumpAndSettle();

  final suffix = brightness == Brightness.dark ? 'dark' : 'light';
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('shots/$name-$suffix.png'),
  );
}

void main() {
  final screens = <String, Widget Function(SalapifyStore)>{
    'overview': (s) => OverviewScreen(store: s, onSwitchTab: (_) {}),
    'budget': (s) => BudgetScreen(store: s),
    'history': (s) => HistoryScreen(store: s),
    'utang': (s) => UtangScreen(store: s),
    'insights': (s) => InsightsScreen(store: s, onSwitchTab: (_) {}),
    'menu': (s) => MenuScreen(store: s, onSwitchTab: (_) {}),
    'courses': (s) => LearnScreen(store: s),
  };

  for (final entry in screens.entries) {
    for (final b in [Brightness.light, Brightness.dark]) {
      final mode = b == Brightness.dark ? 'dark' : 'light';
      testWidgets('${entry.key}, $mode', (tester) async {
        await shoot(tester, entry.key, entry.value, brightness: b);
      });
    }
  }

  testWidgets('the diagnostics dialog, before anything is copied', (
    tester,
  ) async {
    // Worth its own shot: this is the one screen that shows data leaving the
    // phone, so what it says has to be readable and honest at a glance.
    await loadRealFonts(tester);
    await loadPanFaces(tester);
    SharedPreferences.setMockInitialValues({});
    final store = SalapifyStore();
    await store.load();

    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    Barako.current = Barako.currentTheme.resolve(Brightness.dark);
    await tester.pumpWidget(
      MaterialApp(
        theme: salapifyTheme(Barako.current),
        home: MenuScreen(store: store, onSwitchTab: (_) {}),
      ),
    );
    await tester.pumpAndSettle();

    final button = find.text('Copy diagnostics');
    await tester.scrollUntilVisible(button, 300);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('shots/diagnostics-dark.png'),
    );
  });

  testWidgets('the name row in Menu, with a name set', (tester) async {
    // The Menu shot above only reaches the top of a long list, so this row
    // would otherwise ship having never been looked at. It is rendered with a
    // name SET because that is the state carrying the most to get wrong: two
    // text buttons competing for room beside a value, on a row that also has
    // to explain itself.
    await loadRealFonts(tester);
    await loadPanFaces(tester);
    SharedPreferences.setMockInitialValues({});
    final store = SalapifyStore();
    await store.load();
    await store.setDisplayName('Ana');

    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    Barako.current = Barako.currentTheme.resolve(Brightness.dark);
    await tester.pumpWidget(
      MaterialApp(
        theme: salapifyTheme(Barako.current),
        home: MenuScreen(store: store, onSwitchTab: (_) {}),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('YOUR NAME'), 300);
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('shots/menu-name-dark.png'),
    );
  });

  testWidgets('Pan, all four moods, through the real widget', (tester) async {
    // Not the PNGs on disk: the actual PanMascot widget, so this proves the
    // asset wiring AND that the errorBuilder fallback is not silently
    // standing in for a face that failed to load.
    await loadRealFonts(tester);
    await loadPanFaces(tester);
    tester.view.physicalSize = const Size(900, 300);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    Barako.current = Barako.currentTheme.resolve(Brightness.dark);
    await tester.pumpWidget(
      MaterialApp(
        theme: salapifyTheme(Barako.current),
        home: Scaffold(
          backgroundColor: Barako.background,
          body: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (final m in PanMood.values) PanMascot(mood: m, size: 64),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('shots/pan-moods-dark.png'),
    );
  });

  testWidgets('Pan wearing each theme, through the real colour filter', (
    tester,
  ) async {
    // The tint maths was modelled in a script first, and a script cannot
    // answer the question that matters: whether the ENGINE agrees. A colour
    // matrix meets premultiplied alpha somewhere between the widget and the
    // GPU, so the only honest proof is a real render of the real widget.
    //
    // Barako is deliberately first and is the control: it takes no filter at
    // all, so if it ever stops looking like the artwork on disk, the tint has
    // started touching something it promised to leave alone.
    //
    // This strip drives ColorFiltered directly rather than through PanMascot,
    // and that is a limitation of the HARNESS rather than a shortcut. Barako.
    // current is a mutable static, so eight themes cannot coexist in one tree:
    // the first version of this shot set the palette inside eight sibling
    // Builders and rendered eight IDENTICAL green cups, because PanMascot's
    // bob animation rebuilds each mascot on every tick, long after all eight
    // Builders have run, leaving every one of them reading the last theme set.
    // It looked like a tint bug and was a test bug. PanMascot's own wiring is
    // covered by pan-moods-dark.png and by pan_tint_test.dart; what this shot
    // is for is the one question a script cannot answer, whether the ENGINE
    // applies the matrix the way the maths predicts once premultiplied alpha
    // is in play.
    await loadRealFonts(tester);
    await loadPanFaces(tester);
    // Eight cups at 72 logical px need 576 plus breathing room, so the width
    // is set from the row rather than guessed at.
    tester.view.physicalSize = const Size(2100, 300);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: const Color(0xFF15100C),
          body: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (final theme in barakoThemes)
                  () {
                    // Resolved eagerly, per theme, so nothing depends on what
                    // a mutable static happens to hold at paint time.
                    final tint = panTintMatrix(theme.dark.primary);
                    final face = Image.asset(
                      panAssetFor(PanMood.calm),
                      width: 72,
                      height: 72,
                      filterQuality: FilterQuality.medium,
                    );
                    return tint == null
                        ? face
                        : ColorFiltered(
                            colorFilter: ColorFilter.matrix(tint),
                            child: face,
                          );
                  }(),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('shots/pan-themes-dark.png'),
    );
    Barako.currentTheme = themeForKey('barako');
    Barako.current = themeForKey('barako').resolve(Brightness.dark);
  });

  testWidgets('a lesson, opened the way a reader opens it', (tester) async {
    // Navigated into rather than constructed, because the reader is private
    // and, more usefully, because tapping is what a person actually does. A
    // screen built directly in a test can look right while the route into it
    // is broken.
    await loadRealFonts(tester);
    await loadPanFaces(tester);
    SharedPreferences.setMockInitialValues({});
    final store = SalapifyStore();
    await store.load();

    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    Barako.current = Barako.currentTheme.resolve(Brightness.dark);
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
      matchesGoldenFile('shots/lesson-dark.png'),
    );
  });
}
