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
import 'package:salapify/data/backup.dart' show defaultCategories;
import 'package:salapify/data/store.dart';
import 'package:salapify/money/pan_mood.dart';
import 'package:salapify/screens/budget.dart';
import 'package:salapify/screens/history.dart';
import 'package:salapify/screens/insights.dart';
import 'package:salapify/screens/learn.dart';
import 'package:salapify/screens/appearance.dart';
import 'package:salapify/screens/money.dart';
import 'package:salapify/screens/utang.dart';
import 'package:salapify/screens/quick_add_editor.dart';
import 'package:salapify/widgets/period_selector.dart';
import 'package:salapify/screens/shell.dart';
import 'package:salapify/screens/menu.dart';
import 'package:salapify/screens/overview.dart';
import 'package:salapify/screens/onboarding.dart';
import 'package:salapify/screens/accounts.dart';
import 'package:salapify/screens/categories.dart';
import 'package:salapify/screens/tax_deadlines.dart';
import 'package:salapify/screens/year_end_tax.dart';
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

/// A phone that has been USED, and the reason this exists.
///
/// Every per-tab shot ran against an EMPTY store for the whole life of this
/// harness. Sixteen images, both brightnesses, and not one of them ever
/// contained a peso figure: they were all first-run welcome states. So every
/// time this file's own rule said "look at the screen before shipping a
/// screen", what was looked at was a screen with no money on it.
///
/// That is exactly how the crossed-out peso reached the founder's phone. The
/// display serif drew ₱ with a long crossbar that ran into the minus sign, so
/// every negative amount read as struck through. It was on Home. It had been
/// rendered dozens of times. It was never once visible, because Home had no
/// amounts in it.
///
/// So the fixture below is a lived-in phone: money in several accounts, a
/// month of spending across categories, income, a card and a loan, somebody
/// who owes money and somebody who is owed, a goal part way there, and a
/// logging streak. Enough that every tab has something real to draw.
///
/// Two rules for changing it. Keep the numbers ODD and specific (48,500.55 not
/// 50,000), because round numbers hide grouping and decimal bugs. And never
/// shrink it to make a shot tidier: a tidy shot of an empty screen is what
/// this replaces.
final Map<String, dynamic> livedInBlob = () {
  // Dates are relative to a FIXED day, so a shot taken today and a shot taken
  // next month contain the same entries. Golden images that change with the
  // calendar are noise nobody reads.
  const y = 2026, m = 7;
  String d(int day) =>
      '$y-${m.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
  return <String, dynamic>{
    'schemaVersion': 12,
    'settings': {
      'onboarded': true,
      'name': 'Carla',
      'paydaySchedule': {'mode': 'monthly', 'day': 30},
      'monthlyLimit': 18000,
    },
    'accounts': [
      {'id': 'cash', 'name': 'Cash', 'kind': 'cash', 'balance': 2340},
      {
        'id': 'bpi',
        'name': 'BPI Savings',
        'kind': 'savings',
        'balance': 48500.55,
        'subtype': 'savings_account',
        'institutionId': 'bpi',
        'target': 100000,
      },
      {
        'id': 'gcash',
        'name': 'GCash',
        'kind': 'ewallet',
        'balance': 1785.25,
        'subtype': 'ewallet',
        'institutionId': 'gcash',
      },
      {
        'id': 'pay',
        'name': 'Salary account',
        'kind': 'checking',
        'balance': 22400,
        'subtype': 'payroll_account',
        'institutionId': 'unionbank',
      },
    ],
    'assets': [
      {'id': 'mp2', 'name': 'Pag-IBIG MP2', 'kind': 'mp2', 'value': 61200},
    ],
    'debts': [
      {
        'id': 'card',
        'name': 'BPI card',
        'type': 'credit card',
        'remaining': 12480.40,
        'monthlyRate': 3,
        'minPayment': 1250,
        'dueDay': 15,
        'statementDay': 25,
        'creditLimit': 50000,
      },
      {
        'id': 'moto',
        'name': 'Motorcycle loan',
        'type': 'auto',
        'remaining': 48000,
        'monthlyRate': 1.5,
        'minPayment': 3200,
        'dueDay': 5,
        'subtype': 'auto_loan',
      },
    ],
    'receivables': [
      {
        'id': 'r1',
        'person': 'Ana',
        'amount': 1500,
        'dueDate': d(12),
        'payments': [
          {'id': 'p1', 'amount': 500, 'date': d(18)},
        ],
      },
      {'id': 'r2', 'person': 'Ben', 'amount': 2200, 'dueDate': d(2)},
    ],
    'payables': [
      {'id': 'y1', 'person': 'Mama', 'amount': 3000, 'dueDate': d(28)},
    ],
    'goals': [
      {
        'id': 'g1',
        'name': 'Emergency fund',
        'target': 60000,
        'saved': 21500,
        'targetDate': '$y-12-31',
      },
    ],
    'categories': defaultCategories.map((c) => {...c}).toList(),
    'transactions': [
      {
        'id': 't1',
        'type': 'income',
        'label': 'Salary',
        'amount': 32000,
        'date': d(15),
        'accountId': 'pay',
      },
      // categoryId, NOT a plain 'category' string. The first version of this
      // fixture used the latter, which the engine does not read, so every
      // expense fell through to its LABEL and the WHERE IT WENT card grouped
      // by label instead of category. It looked plausible. Checking the engine
      // rather than the screenshot is what caught it, and it is a small
      // example of the same lesson this whole fixture exists for: a render
      // that exercises the wrong path proves the wrong thing.
      for (final (i, e) in const [
        ('Groceries', 'cat_groceries', 2450.75, 3),
        ('Jeep and bus', 'cat_transport', 620, 4),
        ('Coffee', 'cat_food', 185, 5),
        ('Electricity', 'cat_bills', 3120.50, 8),
        ('Load', 'cat_load', 300, 9),
        ('Lunch out', 'cat_food', 480, 11),
        ('Grab', 'cat_transport', 265, 12),
        ('Medicine', 'cat_health', 890.25, 14),
        ('Groceries', 'cat_groceries', 1980, 17),
        ('Water', 'cat_bills', 410, 19),
        ('Movie', 'cat_fun', 700, 21),
        ('Groceries', 'cat_groceries', 2210.40, 24),
      ].indexed)
        {
          'id': 'e$i',
          'type': 'expense',
          'label': e.$1,
          'categoryId': e.$2,
          'amount': e.$3,
          'date': d(e.$4),
          'accountId': 'gcash',
        },
    ],
  };
}();

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
  SharedPreferences.setMockInitialValues({storageKey: jsonEncode(livedInBlob)});
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

  testWidgets('the quick add editor, dark', (tester) async {
    // A new write sheet, and the one that decides whether the app's most
    // frequent action feels like the user's own. Never rendered before.
    await loadRealFonts(tester);
    SharedPreferences.setMockInitialValues({
      storageKey: jsonEncode({
        'schemaVersion': 12,
        'settings': {'onboarded': true, 'monthlyLimit': 12000},
        'accounts': [
          {'id': 'cash', 'name': 'Cash', 'kind': 'cash', 'balance': 8400},
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
          backgroundColor: Barako.background,
          body: SingleChildScrollView(child: QuickAddEditor(store: store)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('shots/quick-add-editor-dark.png'),
    );
  });

  testWidgets('Activity with the new period selector, dark', (tester) async {
    // The existing history shot has no entries, so it could not show the
    // selector sitting above a real list. This one has entries in three
    // different months and opens the custom range, which is the tallest the
    // filter stack ever gets.
    await loadRealFonts(tester);
    SharedPreferences.setMockInitialValues({
      storageKey: jsonEncode({
        'schemaVersion': 12,
        'settings': {'onboarded': true},
        'transactions': [
          {
            'id': 't1',
            'type': 'expense',
            'label': 'Groceries',
            'amount': 1250,
            'date': '2026-07-20',
          },
          {
            'id': 't2',
            'type': 'income',
            'label': 'Sweldo',
            'amount': 28000,
            'date': '2026-07-15',
          },
          {
            'id': 't3',
            'type': 'expense',
            'label': 'Jeep',
            'amount': 26,
            'date': '2026-06-28',
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
          // Pinned, like the widget tests. Left on the real clock these
          // three shots silently become an empty month the moment the
          // calendar rolls past July, so the review artifact stops proving
          // what it was added to prove. Session 15 found this one still live.
          body: HistoryScreen(
            store: store,
            onMenu: () {},
            clock: () => DateTime(2026, 7, 28),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('shots/history-period-dark.png'),
    );

    await tester.tap(
      find.descendant(
        of: find.byType(PeriodSelector),
        matching: find.text('Custom'),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('shots/history-period-custom-dark.png'),
    );

    // The stepper row, which is the other piece of new UI. Stepped back once
    // so the forward arrow is live and the label names a real month.
    await tester.tap(
      find.descendant(
        of: find.byType(PeriodSelector),
        matching: find.text('Month'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithIcon(IconButton, Icons.chevron_left));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('shots/history-period-month-dark.png'),
    );
  });

  testWidgets('the person sheet, now that it is a statement too', (
    tester,
  ) async {
    // The sheet grew a statement, a reminder, a settled list and a payment
    // history in one batch. Four new blocks stacked into a bottom sheet is
    // exactly the shape that reads fine in code and looks like a wall on a
    // phone, so it gets looked at before it ships.
    await loadRealFonts(tester);
    SharedPreferences.setMockInitialValues({
      storageKey: jsonEncode({
        'schemaVersion': 12,
        'settings': {'onboarded': true},
        'people': [
          {'id': 'p1', 'name': 'Migs'},
        ],
        'receivables': [
          {
            'id': 'r1',
            'personId': 'p1',
            'person': 'Migs',
            'amount': 5000,
            'note': 'Emergency',
            'dueDate': '2026-06-30',
            'payments': [
              {'id': 'pay1', 'amount': 1500, 'date': '2026-07-10'},
            ],
          },
          {
            'id': 'r2',
            'personId': 'p1',
            'person': 'Migs',
            'amount': 800,
            'note': 'Load',
            'paid': true,
            'payments': [
              {'id': 'pay2', 'amount': 800, 'date': '2026-05-20'},
            ],
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
          backgroundColor: Barako.background,
          body: SingleChildScrollView(
            child: PersonSheet(store: store, name: 'Migs'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('shots/person-sheet-dark.png'),
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
    //
    // It used to seed a bespoke three-row store of its own: one cash account,
    // one grocery expense, one credit card. Enough to make every band appear,
    // which was all it was ever asked to do, and NOT enough to be a person.
    // f2.84 gave shoot() a lived-in fixture and the shots that build their own
    // store, this one included, quietly kept their thin ones. So the fullest
    // render of Insights in this project showed "Money health 10 of 100" and
    // "Spoken for: from 1 minimum", figures produced by a store with no income
    // in it at all, and nobody could tell whether that was the app judging a
    // real person harshly or an artefact of the fixture. A screen that reasons
    // about somebody's money has to be looked at with somebody's money in it.
    await loadRealFonts(tester);
    SharedPreferences.setMockInitialValues({
      storageKey: jsonEncode(livedInBlob),
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
        'settings': {
          'onboarded': true,
          // A rate the person typed, so the shot shows the CONVERTED state
          // and its label rather than only the excluded one.
          'manualRates': {'USD': 56.5},
        },
        'accounts': [
          {'id': 'cash', 'name': 'Cash', 'kind': 'cash', 'balance': 3200},
          {
            'id': 'bpi',
            'name': 'BPI Savings',
            'kind': 'savings',
            'balance': 48500.55,
            'subtype': 'savings_account',
            'institutionId': 'bpi',
          },
          {
            'id': 'gcash',
            'name': 'GCash',
            'kind': 'ewallet',
            'balance': 1750,
            'subtype': 'ewallet',
            'institutionId': 'gcash',
          },
          {
            'id': 'pay',
            'name': 'Salary account',
            'kind': 'checking',
            'balance': 22400,
            'subtype': 'payroll_account',
            'institutionId': 'unionbank',
          },
          {
            'id': 'usd',
            'name': 'Freelance USD',
            'kind': 'savings',
            'balance': 1200,
            'subtype': 'savings_account',
            'currencyCode': 'USD',
          },
        ],
        'assets': [
          {'id': 'mp2', 'name': 'Pag-IBIG MP2', 'kind': 'mp2', 'value': 60000},
          {'id': 'car', 'name': 'Motorcycle', 'kind': 'vehicle', 'value': 85000},
        ],
        'debts': [
          {
            'id': 'card',
            'name': 'BPI card',
            'type': 'credit card',
            'remaining': 12400,
            'minPayment': 1200,
            'dueDay': 15,
            'statementDay': 25,
          },
          {
            'id': 'moto',
            'name': 'Motorcycle loan',
            'type': 'auto',
            'remaining': 48000,
            'minPayment': 3200,
            'dueDay': 5,
            'subtype': 'auto_loan',
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
        home: AccountsScreen(store: store),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('shots/accounts-grouped-dark.png'),
    );
    // The bottom half, because the debt sections are new and the top of the
    // list is not where they are. A screen is only "looked at" if the part
    // that changed was on screen.
    await tester.drag(find.byType(ListView).first, const Offset(0, -1400));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('shots/accounts-grouped-tail-dark.png'),
    );
    await tester.drag(find.byType(ListView).first, const Offset(0, 1400));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Move money between accounts'));
    await tester.pumpAndSettle();
    expect(find.text('Move money'), findsOneWidget);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('shots/transfer-sheet-dark.png'),
    );
  });

  testWidgets('the add account sheet, both panes, dark', (tester) async {
    // The one button that replaced two, and what it asks. Rendered because a
    // list of categories is exactly the kind of screen that reads fine in code
    // and turns out to be a wall of near identical rows on a phone.
    await loadRealFonts(tester);
    SharedPreferences.setMockInitialValues({
      storageKey: jsonEncode({
        'schemaVersion': 12,
        'settings': {'onboarded': true},
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
    await tester.tap(find.text('+ Add an account'));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('shots/add-account-dark.png'),
    );

    // The second pane, which is where the subtype hints have to earn their
    // space or be cut.
    await tester.tap(find.text('Cash and e-wallets'));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('shots/add-account-subtypes-dark.png'),
    );

    // And the form it lands in, with the institution row that only some
    // subtypes show.
    await tester.tap(find.text('E-wallet'));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('shots/add-account-form-dark.png'),
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

  testWidgets('the two tax screens, dark', (tester) async {
    await loadRealFonts(tester);
    SharedPreferences.setMockInitialValues({
      storageKey: jsonEncode({
        'schemaVersion': 12,
        'settings': {'onboarded': true},
      }),
    });
    final store = SalapifyStore();
    await store.load();

    tester.view.physicalSize = const Size(1170, 3600);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    Barako.current = Barako.currentTheme.resolve(Brightness.dark);
    await tester.pumpWidget(
      MaterialApp(
        theme: salapifyTheme(Barako.current),
        home: TaxDeadlinesScreen(
          store: store,
          clock: () => DateTime(2026, 4, 10),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('WHAT IS NEXT'), findsOneWidget);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('shots/bir-dates-dark.png'),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: salapifyTheme(Barako.current),
        home: YearEndTaxScreen(store: store),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), '25000');
    await tester.enterText(find.byType(TextField).at(3), '25000');
    await tester.enterText(find.byType(TextField).at(4), '30000');
    await tester.pumpAndSettle();
    expect(find.textContaining('LIKELY'), findsOneWidget);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('shots/year-end-tax-dark.png'),
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
