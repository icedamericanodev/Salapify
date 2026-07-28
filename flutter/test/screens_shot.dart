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

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/money/pan_mood.dart';
import 'package:salapify/screens/budget.dart';
import 'package:salapify/screens/history.dart';
import 'package:salapify/screens/insights.dart';
import 'package:salapify/screens/learn.dart';
import 'package:salapify/screens/appearance.dart';
import 'package:salapify/screens/money.dart';
import 'package:salapify/screens/shell.dart';
import 'package:salapify/screens/menu.dart';
import 'package:salapify/screens/overview.dart';
import 'package:salapify/screens/onboarding.dart';
import 'package:salapify/screens/accounts.dart';
import 'package:salapify/screens/categories.dart';
import 'package:salapify/theme.dart';
import 'package:salapify/widgets/pan_mascot.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/app_harness.dart';

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
    final f = File(
      '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    );
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
      print(
        'WARNING: Material icon font not found, icons will render as boxes',
      );
      return;
    }
    final iconLoader = FontLoader('MaterialIcons')
      ..addFont(File(icons).readAsBytes().then((b) => ByteData.view(b.buffer)));
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
      // A destination is a body now, not a Scaffold. The shell supplies the
      // Scaffold in the app, so the harness has to here, or every screen with
      // a Material widget in it asserts before it can be photographed.
      home: Scaffold(body: build(store)),
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
  // onMenu is wired on every tab, as the shell wires it. It was omitted once
  // and every per-tab shot then rendered WITHOUT the Menu button, so the
  // founder was looking at a header on the phone that no render had ever
  // shown. A shot of a tab must carry the chrome the tab really has.
  final screens = <String, Widget Function(SalapifyStore)>{
    'overview': (s) =>
        OverviewScreen(store: s, onSwitchTab: (_) {}, onMenu: () {}),
    'budget': (s) => BudgetScreen(store: s, onMenu: () {}),
    'history': (s) => HistoryScreen(store: s, onMenu: () {}),
    'utang': (s) => MoneyScreen(store: s, onMenu: () {}),
    'insights': (s) =>
        InsightsScreen(store: s, onSwitchTab: (_) {}, onMenu: () {}),
    'menu': (s) => MenuScreen(store: s, onSwitchTab: (_) {}),
    'courses': (s) => LearnScreen(store: s),
    'appearance': (s) => AppearanceScreen(store: s),
  };

  for (final entry in screens.entries) {
    for (final b in [Brightness.light, Brightness.dark]) {
      final mode = b == Brightness.dark ? 'dark' : 'light';
      testWidgets('${entry.key}, $mode', (tester) async {
        await shoot(tester, entry.key, entry.value, brightness: b);
      });
    }
  }

  testWidgets('the shell, which is the app as the user meets it', (
    tester,
  ) async {
    // The per-screen shots wrap a destination in a bare Scaffold, so they show
    // the content and nothing else. This is the only frame with the bottom bar
    // and the Log button in it, which means it is the only one that can show
    // whether the last card clears that button.
    await loadRealFonts(tester);
    await loadPanFaces(tester);
    SharedPreferences.setMockInitialValues({
      storageKey: jsonEncode({
        'schemaVersion': 12,
        'accounts': [
          {'id': 'cash', 'name': 'Cash', 'kind': 'cash', 'balance': 12450},
        ],
        'transactions': [
          {
            'id': 'e1',
            'type': 'expense',
            'label': 'Groceries',
            'amount': 1200,
            'date': '2026-07-20',
            'accountId': 'cash',
          },
        ],
      }),
    });
    final store = SalapifyStore();
    await store.load();

    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    Barako.current = Barako.currentTheme.resolve(Brightness.dark);
    await tester.pumpWidget(
      MaterialApp(
        theme: salapifyTheme(Barako.current),
        home: ShellScreen(store: store),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('shots/shell-dark.png'),
    );
  });

  testWidgets('the Money tab, both segments', (tester) async {
    // The merge's two faces: I owe (the debts picture) and Owed to me (the
    // receivables list), one frame each, dark, seeded with both kinds of
    // owing so neither renders its empty state.
    await loadRealFonts(tester);
    SharedPreferences.setMockInitialValues({
      storageKey: jsonEncode({
        'schemaVersion': 12,
        'accounts': [
          {'id': 'cash', 'name': 'Cash', 'kind': 'cash', 'balance': 30000},
        ],
        'debts': [
          {
            'id': 'd1',
            'name': 'BPI card',
            'type': 'credit card',
            'remaining': 12000,
            'monthlyRate': 3,
            'minPayment': 500,
            'dueDay': 28,
          },
        ],
        'people': [
          {'id': 'p1', 'name': 'Migs'},
        ],
        'receivables': [
          {
            'id': 'r1',
            'personId': 'p1',
            'person': 'Migs',
            'amount': 1500,
            'payments': <Map<String, dynamic>>[],
            'paid': false,
            'dueDate': '2026-08-15',
          },
        ],
      }),
    });
    final store = SalapifyStore();
    await store.load();

    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    Barako.current = Barako.currentTheme.resolve(Brightness.dark);
    await tester.pumpWidget(
      MaterialApp(
        theme: salapifyTheme(Barako.current),
        home: Scaffold(
          body: MoneyScreen(store: store, onMenu: () {}),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('shots/money-owe-dark.png'),
    );

    await tester.tap(find.text('Owed to me'));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('shots/money-owed-dark.png'),
    );
  });

  testWidgets('the two write sheets, dark', (tester) async {
    // The Log sheet (with its date chips) and the New utang sheet (with its
    // tap-to-pick due date). Both are write paths whose UI changed in Phase
    // 2 batch 3, and neither had a render before, which is exactly how the
    // header chrome gap happened.
    await loadRealFonts(tester);
    SharedPreferences.setMockInitialValues({
      storageKey: jsonEncode({
        'schemaVersion': 12,
        'accounts': [
          {'id': 'cash', 'name': 'Cash', 'kind': 'cash', 'balance': 30000},
        ],
        'transactions': [
          {
            'id': 't1',
            'type': 'expense',
            'label': 'Groceries',
            'amount': 250,
            'date': '2026-07-20',
            'accountId': 'cash',
          },
        ],
      }),
    });
    final store = SalapifyStore();
    await store.load();

    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    Barako.current = Barako.currentTheme.resolve(Brightness.dark);
    await tester.pumpWidget(
      MaterialApp(
        theme: salapifyTheme(Barako.current),
        home: ShellScreen(store: store),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log'));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('shots/log-sheet-dark.png'),
    );
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    await tester.tap(navDestination('Utang'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Owed to me'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'New'));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('shots/utang-new-sheet-dark.png'),
    );
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    // The edit sheet, opened from a real Activity row, prefilled.
    await tester.tap(navDestination('Activity'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Groceries'));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('shots/edit-sheet-dark.png'),
    );
  });

  testWidgets('Activity and Budget with real data, dark', (tester) async {
    // The empty-seed per-tab shots cannot show the batch 6 polish: the human
    // date headers, the account and category context line on rows, and the
    // TODAY card on Budget all need data to exist.
    await loadRealFonts(tester);
    final today = DateTime.now().toIso8601String().substring(0, 10);
    SharedPreferences.setMockInitialValues({
      storageKey: jsonEncode({
        'schemaVersion': 12,
        'accounts': [
          {'id': 'cash', 'name': 'Cash', 'kind': 'cash', 'balance': 12450},
        ],
        'categories': [
          {'id': 'c-food', 'name': 'Food'},
        ],
        'transactions': [
          {
            'id': 't1',
            'type': 'expense',
            'label': 'Jollibee',
            'amount': 150,
            'date': today,
            'accountId': 'cash',
            'categoryId': 'c-food',
          },
          {
            'id': 't2',
            'type': 'expense',
            'label': 'Groceries',
            'amount': 480,
            'date': '2026-07-12',
            'accountId': 'cash',
          },
        ],
      }),
    });
    final store = SalapifyStore();
    await store.load();

    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    Barako.current = Barako.currentTheme.resolve(Brightness.dark);
    await tester.pumpWidget(
      MaterialApp(
        theme: salapifyTheme(Barako.current),
        home: ShellScreen(store: store),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(navDestination('Activity'));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('shots/activity-rows-dark.png'),
    );
    await tester.tap(navDestination('Budget'));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('shots/budget-today-dark.png'),
    );
  });

  testWidgets('Insights with real data, banded, dark', (tester) async {
    // The per-tab insights shot seeds an empty store, so it renders the
    // empty-state invitation and the BANDS are invisible to it. This frame
    // seeds enough data that DO NEXT, TOOLS (folded launchers), and THE
    // BIGGER PICTURE all render; without it the batch 5 restructure would
    // have shipped with no render showing it, the session 7 lesson again.
    await loadRealFonts(tester);
    SharedPreferences.setMockInitialValues({
      storageKey: jsonEncode({
        'schemaVersion': 12,
        'accounts': [
          {'id': 'cash', 'name': 'Cash', 'kind': 'cash', 'balance': 20000},
        ],
        'transactions': [
          {
            'id': 't1',
            'type': 'expense',
            'label': 'Groceries',
            'amount': 500,
            'date': '2026-07-10',
            'accountId': 'cash',
          },
        ],
        'debts': [
          {
            'id': 'd1',
            'name': 'BPI card',
            'type': 'credit card',
            'remaining': 12000,
            'monthlyRate': 3,
            'minPayment': 500,
          },
        ],
      }),
    });
    final store = SalapifyStore();
    await store.load();

    // Tall frame so the whole banded column fits in one look.
    tester.view.physicalSize = const Size(1170, 4200);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    Barako.current = Barako.currentTheme.resolve(Brightness.dark);
    await tester.pumpWidget(
      MaterialApp(
        theme: salapifyTheme(Barako.current),
        home: Scaffold(
          body: InsightsScreen(
            store: store,
            onSwitchTab: (_) {},
            onMenu: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('shots/insights-full-dark.png'),
    );
  });

  testWidgets('appearance at 1.4x system font on a narrow phone', (
    tester,
  ) async {
    // The one screen in the app whose content is mostly long text in narrow
    // columns, so it is the one most likely to clip when someone turns the
    // system font up. This frame caught a real defect on its first run: at
    // 1.4x on a 320dp phone the theme NAME truncated to "Orchid G...", which
    // no amount of passing tests would have shown, because nothing was
    // overflowing. It was merely unreadable.
    await loadRealFonts(tester);
    SharedPreferences.setMockInitialValues({});
    final store = SalapifyStore();
    await store.load();

    tester.view.physicalSize = const Size(960, 3600);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    Barako.current = Barako.currentTheme.resolve(Brightness.dark);
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.4)),
        child: MaterialApp(
          theme: salapifyTheme(Barako.current),
          home: AppearanceScreen(store: store),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('shots/appearance-large-font-dark.png'),
    );
  });

  testWidgets('appearance, with a non-Barako theme selected, dark', (
    tester,
  ) async {
    // The default shots open on Barako, where the selected tile, the ring and
    // the check badge are all the same orange as the rest of the app, so they
    // prove almost nothing. This one picks Voltage: the ring and badge become
    // electric blue against seven other palettes, which is the only frame that
    // actually shows selection reading as selection.
    await loadRealFonts(tester);
    SharedPreferences.setMockInitialValues({
      storageKey: jsonEncode({
        'schemaVersion': 12,
        'accounts': <Map<String, dynamic>>[],
        'transactions': <Map<String, dynamic>>[],
        'settings': {'themeKey': 'voltage', 'themeMode': 'dark'},
      }),
    });
    final store = SalapifyStore();
    await store.load();

    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    Barako.currentTheme = themeForKey('voltage');
    Barako.current = Barako.currentTheme.resolve(Brightness.dark);
    await tester.pumpWidget(
      MaterialApp(
        theme: salapifyTheme(Barako.current),
        home: AppearanceScreen(store: store),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('shots/appearance-voltage-dark.png'),
    );
    Barako.currentTheme = themeForKey('barako');
    Barako.current = themeForKey('barako').resolve(Brightness.dark);
  });

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
        home: Scaffold(
          body: MenuScreen(store: store, onSwitchTab: (_) {}),
        ),
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
        home: Scaffold(
          body: MenuScreen(store: store, onSwitchTab: (_) {}),
        ),
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

  testWidgets('Pan speaking on Home, which needs data to appear at all', (
    tester,
  ) async {
    // The default Home shot renders a BRAND NEW store, so it never shows the
    // check-in card, and the card is where Pan actually talks. Changing his
    // layout and reviewing only the empty screen would be reviewing the one
    // state the change does not touch.
    await loadRealFonts(tester);
    await loadPanFaces(tester);
    SharedPreferences.setMockInitialValues({});
    final store = SalapifyStore();
    await store.load();
    await store.addEntry({
      'type': 'expense',
      'amount': 250.0,
      'category': 'Food',
      'date': DateTime.now().toIso8601String(),
    });

    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    Barako.current = Barako.currentTheme.resolve(Brightness.dark);
    await tester.pumpWidget(
      MaterialApp(
        theme: salapifyTheme(Barako.current),
        home: Scaffold(
          body: OverviewScreen(
            store: store,
            onSwitchTab: (_) {},
            onMenu: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('shots/home-pan-speaking-dark.png'),
    );
  });

  testWidgets('Pan is the same colour on every theme', (tester) async {
    // The visual half of the signature rule. pan_signature_test.dart proves
    // the mechanism (no filter, baked fallback palette); this proves the
    // RESULT, which is the thing a person would actually notice.
    //
    // Eight identical cups is the passing picture here. That reads as a
    // boring shot and it is the entire point: Pan is meant to be the one
    // fixed thing on a screen the user can repaint. If a future change
    // reintroduces theming, this strip turns into a rainbow and says so at a
    // glance.
    await loadRealFonts(tester);
    await loadPanFaces(tester);
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
                  Builder(
                    builder: (context) {
                      // The palette IS set per cell, deliberately, so the shot
                      // would expose a Pan that reacts to it.
                      Barako.currentTheme = theme;
                      Barako.current = theme.resolve(Brightness.dark);
                      return Image.asset(
                        panAssetFor(PanMood.calm),
                        width: 72,
                        height: 72,
                        filterQuality: FilterQuality.medium,
                      );
                    },
                  ),
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

  testWidgets('the onboarding flow, walked step by step', (tester) async {
    // Walked, not constructed per step: tapping through is what a new user
    // does, and a step reachable only by construction is a step the flow
    // lost. Both brightnesses for the welcome (the first frame anyone ever
    // sees of the app), dark for the rest, since dark is what the founder
    // uses.
    for (final b in [Brightness.dark, Brightness.light]) {
      await loadRealFonts(tester);
      await loadPanFaces(tester);
      SharedPreferences.setMockInitialValues({});
      final store = SalapifyStore();
      await store.load();

      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      Barako.current = Barako.currentTheme.resolve(b);
      // Keyed per brightness. Without this the second pump reuses the first
      // iteration's State (same widget type, same slot), so the "welcome"
      // shot silently rendered whatever step the previous walk ended on.
      // The first light render proved it by photographing step 2.
      await tester.pumpWidget(
        MaterialApp(
          theme: salapifyTheme(Barako.current),
          // showNudge forced on: the harness runs on a desktop VM where
          // reminders are unsupported, so the real device check would hide
          // the step and this walk would photograph a flow the phone does
          // not have.
          home: OnboardingScreen(
            key: ValueKey(b.name),
            store: store,
            showNudge: true,
            askPermission: () async => true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final mode = b == Brightness.dark ? 'dark' : 'light';
      expect(find.text('Get started'), findsOneWidget);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('shots/onboarding-welcome-$mode.png'),
      );
      if (b == Brightness.light) break;

      await tester.tap(find.text('Get started'));
      await tester.pumpAndSettle();
      expect(find.text('The basics'), findsOneWidget);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('shots/onboarding-basics-dark.png'),
      );

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      // Assert the frame BEFORE photographing it. A shot named for one step
      // that renders another is the exact failure this walk already had
      // once, and a name is not evidence.
      expect(find.text('A 30 second nudge at night?'), findsOneWidget);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('shots/onboarding-nudge-dark.png'),
      );

      // The YES branch on purpose: it is the path that runs the injected
      // permission seam, so the walk exercises it rather than photographing
      // only the answer that touches nothing.
      await tester.tap(find.text('Yes, remind me at night'));
      await tester.pumpAndSettle();
      expect(find.text('How do you want to start?'), findsOneWidget);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('shots/onboarding-start-dark.png'),
      );
    }
  });

  testWidgets('Home wearing the sample-data banner, dark', (tester) async {
    // The state the "Explore the sample data first" choice lands on: the
    // banner must read as a flag over borrowed data, not as another money
    // card, and the one-tap removal must be visible without scrolling.
    await loadRealFonts(tester);
    await loadPanFaces(tester);
    SharedPreferences.setMockInitialValues({});
    final store = SalapifyStore();
    await store.load();
    await store.completeOnboarding(
      currencyCode: 'PHP',
      currencySymbol: '₱',
      monthlyLimit: 20000,
      withSampleData: true,
    );

    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    Barako.current = Barako.currentTheme.resolve(Brightness.dark);
    await tester.pumpWidget(
      MaterialApp(
        theme: salapifyTheme(Barako.current),
        home: Scaffold(
          body: OverviewScreen(
            store: store,
            onSwitchTab: (_) {},
            onMenu: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('shots/home-sample-banner-dark.png'),
    );
  });

  testWidgets('the transfer sheet, dark', (tester) async {
    // A write path with money in it, so it gets looked at before it ships.
    await loadRealFonts(tester);
    SharedPreferences.setMockInitialValues({
      storageKey: jsonEncode({
        'schemaVersion': 12,
        'settings': {'onboarded': true},
        'accounts': [
          {'id': 'cash', 'name': 'Cash', 'kind': 'cash', 'balance': 3200},
          {
            'id': 'bpi',
            'name': 'BPI Savings',
            'kind': 'savings',
            'balance': 48500.55,
          },
          {'id': 'gcash', 'name': 'GCash', 'kind': 'ewallet', 'balance': 1750},
        ],
      }),
    });
    final store = SalapifyStore();
    await store.load();

    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    Barako.current = Barako.currentTheme.resolve(Brightness.dark);
    await tester.pumpWidget(
      MaterialApp(
        theme: salapifyTheme(Barako.current),
        home: AccountsScreen(store: store),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Move money between accounts'));
    await tester.pumpAndSettle();
    expect(find.text('Move money'), findsOneWidget);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('shots/transfer-sheet-dark.png'),
    );
  });

  testWidgets('categories, and the delete question, dark', (tester) async {
    // Two frames: the list with a cap being blown, and the sheet that asks
    // where a deleted category's entries should go. The second one is a
    // founder decision rendered, so it gets looked at before it ships.
    await loadRealFonts(tester);
    final today = DateTime.now().toIso8601String().substring(0, 10);
    SharedPreferences.setMockInitialValues({
      storageKey: jsonEncode({
        'schemaVersion': 12,
        'settings': {'onboarded': true, 'pro': true},
        'categories': [
          {'id': 'food', 'name': 'Food', 'icon': '🍚', 'monthlyCap': 3000},
          {
            'id': 'grocery',
            'name': 'Groceries',
            'icon': '🛒',
            'monthlyCap': 0,
            'parentId': 'food',
          },
          {'id': 'bills', 'name': 'Bills', 'icon': '💡', 'monthlyCap': 5000},
          {'id': 'transpo', 'name': 'Transport', 'icon': '🚌', 'monthlyCap': 0},
        ],
        'transactions': [
          {
            'id': 't1',
            'type': 'expense',
            'label': 'Jollibee',
            'amount': 3400,
            'date': today,
            'categoryId': 'food',
          },
          {
            'id': 't2',
            'type': 'expense',
            'label': 'Meralco',
            'amount': 1800,
            'date': today,
            'categoryId': 'bills',
          },
          {
            'id': 't3',
            'type': 'expense',
            'label': 'Grab',
            'amount': 240,
            'date': today,
            'categoryId': 'transpo',
          },
        ],
      }),
    });
    final store = SalapifyStore();
    await store.load();

    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    Barako.current = Barako.currentTheme.resolve(Brightness.dark);
    await tester.pumpWidget(
      MaterialApp(
        theme: salapifyTheme(Barako.current),
        home: CategoriesScreen(store: store),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('YOUR CATEGORIES'), findsOneWidget);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('shots/categories-dark.png'),
    );

    await tester.tap(find.text('Food'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.textContaining('entry is tagged'), findsOneWidget);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('shots/category-delete-dark.png'),
    );
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
