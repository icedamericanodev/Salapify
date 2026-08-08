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
import 'package:salapify/content/lessons_grow.dart';
import 'package:salapify/content/lessons_stocks_bonds.dart';
import 'package:salapify/content/lessons_deposits_pooled_funds.dart';
import 'package:salapify/content/lessons_crypto.dart';
import 'package:salapify/content/lessons_insurance.dart';
import 'package:salapify/content/lessons_sss_philhealth.dart';
import 'package:salapify/content/lessons_pagibig.dart';
import 'package:salapify/content/lessons_bir_local_permits.dart';
import 'package:salapify/content/lessons_bir_tax_setup.dart';
import 'package:salapify/content/lessons_business_registration.dart';
import 'package:salapify/screens/learn.dart';
import 'package:salapify/screens/appearance.dart';
import 'package:salapify/content/lesson_model.dart';
import 'package:salapify/money/lesson_steps.dart';
import 'package:salapify/widgets/paged_lesson_reader.dart';
import 'package:salapify/screens/money.dart';
import 'package:salapify/screens/utang.dart';
import 'package:salapify/screens/quick_add_editor.dart';
import 'package:salapify/widgets/period_selector.dart';
import 'package:salapify/screens/shell.dart';
import 'package:salapify/screens/cashflow.dart';
import 'package:salapify/screens/menu.dart';
import 'package:salapify/screens/overview.dart';
import 'package:salapify/screens/goal_detail.dart';
import 'package:salapify/screens/goals.dart';
import 'package:salapify/screens/pan.dart';
import 'package:salapify/screens/onboarding.dart';
import 'package:salapify/money/account_taxonomy.dart' show AccountStore;
import 'package:salapify/screens/account_detail.dart';
import 'package:salapify/screens/accounts.dart';
import 'package:salapify/screens/categories.dart';
import 'package:salapify/screens/tax_calculator.dart';
import 'package:salapify/screens/tax_deadlines.dart';
import 'package:salapify/screens/diagnostics_screen.dart';
import 'package:salapify/screens/mindset.dart';
import 'package:salapify/screens/milestone_share.dart'
    show showMilestoneCelebration;
import 'package:salapify/money/milestones.dart' show Milestone;
import 'package:salapify/screens/privacy_receipt.dart';
import 'package:salapify/services/diagnostics.dart';
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
  // Dates are RELATIVE to today, and that is the whole point.
  //
  // They were once pinned to a constant `y = 2026, m = 7` so two shots a month
  // apart matched. That protected a comparison that cannot happen (test/shots/
  // is gitignored and CI only runs the harness with `--update-goldens`, which
  // writes and never compares), and it cost a fuse: on the first of the next
  // month every expense fell into LAST month and every screen reverted to its
  // empty first-run state, silently, by the calendar. That is session 17 on a
  // timer.
  //
  // The fix after that was `d(n)`, "the nth of the current month, capped at
  // today". It rotted a DIFFERENT way, found on 2026-08-01 (session 26): on the
  // 1st and 2nd of a month the cap collapses every entry onto today, so the
  // weekday-spending pattern has one active day and does not render, and no
  // receivable is dated before today so the Overdue branch is unreachable. A cap
  // to today cannot express "earlier this week" at the start of a month, because
  // earlier this week is last month.
  //
  // `ago(k)` is k days before today: always in the past, never future, and a
  // spread of k values lands on many weekdays across several weeks, crossing the
  // month boundary exactly as a real phone's recent spending does. `ago(0)` is
  // today, so there is ALWAYS spending in the current month. This cannot collapse
  // at a month boundary. fixture_still_lived_in_test.dart asserts every state
  // this must present, so a regression is a red build and not a quiet one.
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  String iso(DateTime t) =>
      '${t.year.toString().padLeft(4, '0')}-'
      '${t.month.toString().padLeft(2, '0')}-'
      '${t.day.toString().padLeft(2, '0')}';
  // k days before today. Past, never future, and calendar-boundary proof.
  String ago(int k) => iso(today.subtract(Duration(days: k)));
  // Genuinely ahead of today, allowed to cross into next month, which is what a
  // real "they still have time to pay" utang looks like.
  String ahead(int days) => iso(today.add(Duration(days: days)));
  return <String, dynamic>{
    'schemaVersion': 12,
    'settings': {
      'onboarded': true,
      'name': 'Carla',
      'paydaySchedule': {'mode': 'monthly', 'day': 30},
      'monthlyLimit': 18000,
      // A rate the person typed themselves, so every screen renders the
      // CONVERTED state and the sentence that owns up to where the rate came
      // from, rather than only the excluded one.
      'manualRates': {'USD': 56.5},
      // A standing plan Pan holds, so the Pan screen renders the plan card
      // and not only the first-ask state. Relative start on purpose: 75 days
      // back is always exactly two completed monthly periods (a third needs
      // about 90), so with the card at 12480.40 the actual is 4019.60 against
      // an expected 3000, inside one period of pace, onTrack every day of
      // the year. An absolute date here would drift through ahead, onTrack
      // and behind as the calendar moved.
      'activePlan': {
        'kind': 'debt',
        'targetId': 'card',
        'label': 'Extra to BPI card',
        'amount': 1500,
        'cadence': 'monthly',
        'startDate': ago(75),
        'startLevel': 16500,
      },
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
        'last4': '4821',
        'accountHolderName': 'Carla Dimaguila',
        'branchDetails': 'BPI Ayala Makati',
        'sensitiveDataProtectionVersion': 1,
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
      // A FOREIGN account, in the fixture every screen shares.
      //
      // Per-account currency is the newest and, by the design document's own
      // ranking, the most dangerous money code in the app: it is the one place
      // that can produce a WRONG total rather than a missing one. It was
      // rendered on exactly one screen, from a fixture built for that screen,
      // so the conversion notice and the exclusion rule were never once seen
      // on Home, Budget or Insights, which are the screens that would actually
      // carry a wrong number to somebody.
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
      {'id': 'mp2', 'name': 'Pag-IBIG MP2', 'kind': 'mp2', 'value': 61200},
      // A thing you own that is not spendable, so the Accounts screen shows
      // more than one category and net worth stops being a synonym for cash.
      {'id': 'car', 'name': 'Motorcycle', 'kind': 'vehicle', 'value': 85000},
    ],
    // A salary and two bills, so the Sweldo Timeline (Cash flow) and the Home
    // road-ahead card project a lived-in month instead of the set-up prompt.
    // Day-of-month items cannot rot at a calendar boundary: the engine clamps
    // and iterates months. The salary day matches the payday schedule above.
    //
    // lastPosted is stamped to the CURRENT month, and that stamp is
    // load-bearing: store.load() runs postDueRecurring with the REAL clock,
    // so without it every consumer of this fixture (the render harness, the
    // readability sweep, the pixel baseline) would gain extra posted
    // transactions on any run on or after each item's day of month, and the
    // fixture's content would depend on the calendar day the suite runs.
    // That is the session 26 rot class wearing a new coat. The cost is that
    // the timeline shows next month's occurrences instead of this month's,
    // which the 60-day shot covers fine.
    'recurring': [
      {
        'id': 'rec-sweldo',
        'type': 'income',
        'label': 'Sweldo',
        'amount': 32000,
        'dayOfMonth': 30,
        'lastPosted':
            '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}',
      },
      {
        'id': 'rec-rent',
        'type': 'expense',
        'label': 'Rent',
        'amount': 9500,
        'dayOfMonth': 5,
        'lastPosted':
            '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}',
      },
      {
        'id': 'rec-net',
        'type': 'expense',
        'label': 'Internet',
        'amount': 1699,
        'dayOfMonth': 18,
        'lastPosted':
            '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}',
      },
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
        'subtype': 'credit_card',
        'institutionId': 'bpi',
        'cardNetwork': 'mastercard',
        'cardProductId': 'platinum',
        'last4': '7702',
        'annualFee': 2500,
        'accountHolderName': 'Carla Dimaguila',
        'sensitiveDataProtectionVersion': 1,
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
        'dueDate': ago(20),
        'payments': [
          {'id': 'p1', 'amount': 500, 'date': ago(15)},
        ],
      },
      {'id': 'r2', 'person': 'Ben', 'amount': 2200, 'dueDate': ago(6)},
      // A receivable that is NOT yet overdue, and the reason it had to exist.
      //
      // Both rows above are past their due date, so the Owed to me list only
      // ever rendered "Overdue N days" and the OTHER branch of that sub line,
      // the one that prints the due date, was unreachable from this fixture. It
      // was printing "Due 2026-08-15", a stored machine date in a sentence
      // about asking a friend for money, and no render could show it because
      // no render had anybody who still had time to pay.
      //
      // A fixture where every case is the same case is a fixture that proves
      // one case.
      {'id': 'r3', 'person': 'Migs', 'amount': 1500, 'dueDate': ahead(17)},
    ],
    'payables': [
      {'id': 'y1', 'person': 'Mama', 'amount': 3000, 'dueDate': ahead(9)},
    ],
    'goals': [
      {
        'id': 'g1',
        'name': 'Emergency fund',
        'target': 60000,
        'saved': 21500,
        'targetDate': iso(DateTime(today.year, 12, 31)),
        // The redesigned fields, relative dates only: a goal made four
        // months back with history, so the detail screen renders a real
        // plan, pace, and dated contributions instead of blank sections.
        'kind': 'savings',
        'iconKey': 'emergency',
        'accent': 'primary',
        'frequency': 'monthly',
        'createdAt': ago(120),
        'startSaved': 5000,
        'contributions': [
          {'id': 'gc1', 'amount': 6500, 'date': ago(75)},
          {'id': 'gc2', 'amount': 10000, 'date': ago(40)},
        ],
      },
      // A second goal so FOCUS has something to choose between and the
      // reorder affordance appears.
      {
        'id': 'g2',
        'name': 'Pasko fund',
        'target': 12000,
        'saved': 3500,
        'targetDate':
            '${(today.month >= 10 ? today.year + 1 : today.year)}-12-01',
        'kind': 'savings',
        'iconKey': 'pasko',
        'accent': 'celebrate',
        'frequency': 'monthly',
        'createdAt': ago(30),
        'startSaved': 0,
      },
    ],
    'categories': defaultCategories.map((c) => {...c}).toList(),
    'transactions': [
      {
        'id': 't1',
        'type': 'income',
        'label': 'Salary',
        'amount': 32000,
        // ago(0) is today: the only offset guaranteed to be in the CURRENT month
        // on the 1st, so Reports and Insights always have this-month income to
        // show (the old day-of-month date kept income in-month every day; this
        // preserves that). Without it, on the 1st the income falls into last
        // month and Reports renders its "No income logged yet" empty state.
        'date': ago(0),
        'accountId': 'pay',
      },
      // categoryId, NOT a plain 'category' string. The first version of this
      // fixture used the latter, which the engine does not read, so every
      // expense fell through to its LABEL and the WHERE IT WENT card grouped
      // by label instead of category. It looked plausible. Checking the engine
      // rather than the screenshot is what caught it, and it is a small
      // example of the same lesson this whole fixture exists for: a render
      // that exercises the wrong path proves the wrong thing.
      // The fourth field is DAYS AGO, not a day of the month. The first is 0, so
      // there is always at least one expense dated today (in the current month,
      // whatever the calendar day), and the rest fan out across the last four
      // weeks so the weekday-spending pattern always has a spread to draw. This
      // is what stops the month-boundary collapse the old day-of-month dates had.
      for (final (i, e) in const [
        ('Groceries', 'cat_groceries', 2450.75, 0),
        ('Jeep and bus', 'cat_transport', 620, 3),
        ('Coffee', 'cat_food', 185, 5),
        ('Electricity', 'cat_bills', 3120.50, 7),
        ('Load', 'cat_load', 300, 10),
        ('Lunch out', 'cat_food', 480, 12),
        ('Grab', 'cat_transport', 265, 14),
        ('Medicine', 'cat_health', 890.25, 18),
        ('Groceries', 'cat_groceries', 1980, 20),
        ('Water', 'cat_bills', 410, 24),
        ('Movie', 'cat_fun', 700, 27),
        ('Groceries', 'cat_groceries', 2210.40, 31),
      ].indexed)
        {
          'id': 'e$i',
          'type': 'expense',
          'label': e.$1,
          'categoryId': e.$2,
          'amount': e.$3,
          'date': ago(e.$4),
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
      debugShowCheckedModeBanner: false,
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

/// The step holding a lesson's first EXERCISE, which is what these lesson
/// shots exist to look at.
///
/// Every lesson shot in this file was written against the scrolling reader,
/// where the whole lesson was one column and the novel widget was somewhere
/// down it. The app stopped opening that reader at f3.57 and nobody moved the
/// shots, so seventeen pictures pointed at a widget a learner could no longer
/// reach (session 37, docs/lunch-and-learn.md; shot_reachability_test.dart is
/// now the machine that catches this).
///
/// A paged reader opens on prose, so pointing these shots at it without a
/// step index would produce seventeen pictures of first screens: technically
/// the real reader, and useless for reviewing a bond timeline or a loss
/// simulator. That is the "tidy shot of an empty screen" the render rule
/// already warns about.
///
/// Throws rather than falling back to step zero. A lesson that loses its
/// exercises should fail loudly here, not quietly start photographing its
/// opening paragraph while the shot name still promises a fact sheet.
int firstExerciseStep(MoneyLesson lesson) {
  final steps = stepsForLesson(lesson);
  for (var i = 0; i < steps.length; i++) {
    if (steps[i] is InteractionStep) return i;
  }
  throw StateError(
    'no exercise step in "${lesson.title}", so this shot would photograph '
    'the opening paragraph while claiming to show an activity',
  );
}

/// One lesson shot, opened on its first exercise in the reader the app really
/// uses.
///
/// Deliberately takes the same named arguments the old ExpansionLessonReader
/// shots took, so migrating all seventeen was one mechanical rename rather
/// than seventeen hand edits, each of which could have quietly pointed at the
/// wrong lesson.
Widget lessonShot({
  required String pathId,
  required MoneyLesson lesson,
  required SalapifyStore store,
}) => PagedLessonReader(
  pathId: pathId,
  lesson: lesson,
  store: store,
  initialStep: firstExerciseStep(lesson),
);

void main() {
  // A missed tap must fail LOUDLY, at the tap, for every tap in this file at
  // once. This harness taps by finder (e.g. "Move money between accounts") and
  // then screenshots or asserts the result; if a layout change pushes the
  // target below the fold in the fixed viewport, a bare tap silently misses and
  // the failure surfaces several steps later and illegibly ("Found 0 widgets
  // with text ..."), which is exactly how the Cash on hand section broke the
  // transfer-sheet shot on the f3.65 runner while 2729 local tests stayed green
  // (docs/lunch-and-learn.md session 38). With this on, a missed tap throws at
  // the tap site with a clear message, so the next taller-list regression is a
  // one-line error here, not a wasted round trip through CI. CI runs this file
  // as its own step, so the guard is enforced there unconditionally.
  WidgetController.hitTestWarningShouldBeFatal = true;
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
    // The wallet detail screens, one for a deposit account (secure info, holder,
    // branch) and one for a credit card (network, limit, statement and due).
    'account-detail': (s) => AccountDetailScreen(
      store: s,
      id: 'bpi',
      accountStore: AccountStore.accounts,
    ),
    'card-detail': (s) => AccountDetailScreen(
      store: s,
      id: 'card',
      accountStore: AccountStore.debts,
    ),
    // Money Courses Phase 6 pilot: the readiness card, the most novel new
    // widget this course adds (content/interaction_blocks.dart's
    // ReadinessCardBlock plus the Salapify actions menu underneath it).
    'grow-readiness-card': (s) => lessonShot(
      pathId: 'grow_your_money',
      lesson: growYourMoneyLessons.firstWhere((l) => l.id == investRefCard),
      store: s,
    ),
    // The paged reader (Phase 3), which is what a learner now actually
    // opens. Rendered beside the scrolling shot above rather than replacing
    // it, so the two shapes can be compared directly while the scrolling
    // reader is still the fallback.
    'paged-lesson-first-screen': (s) => PagedLessonReader(
      pathId: 'grow_your_money',
      lesson: growYourMoneyLessons.firstWhere((l) => l.id == investRefMoneyJob),
      store: s,
    ),
    // Money Courses Phase 7A: "How Bonds Work", the first production lesson
    // to render SortingBlock (the bond timeline) and a five-bucket
    // CategorizeBlock (risk matching) together.
    'stocks-bonds-how-bonds-work': (s) => lessonShot(
      pathId: 'grow_your_money',
      lesson: stocksAndBondsLessons.firstWhere((l) => l.id == sbHowBondsWork),
      store: s,
    ),
    // Money Courses Phase 7A: "Verify Before You Invest", closing the
    // course with a scam red-flag CategorizeBlock, two ScenarioChoiceBlocks,
    // an offline ChecklistBlock, and the Salapify actions menu carrying the
    // two new routes this phase added (mindset, accounts).
    'stocks-bonds-verify-before-you-invest': (s) => lessonShot(
      pathId: 'grow_your_money',
      lesson: stocksAndBondsLessons.firstWhere(
        (l) => l.id == sbVerifyBeforeYouInvest,
      ),
      store: s,
    ),
    // Founder feedback (f3.36 era): "fictional" was repeated on nearly
    // every sentence across the Grow Your Money courses; this lesson's
    // fund fact sheet was the worst of it, saying it on almost every line.
    // Trimmed to one clear disclaimer (the educational-boundary card at
    // the bottom now carries a fixed extra sentence) plus the single
    // instance next to the one named example a compliance test checks for.
    // This is the lesson to look at to confirm the trim actually reads
    // better, not just measures shorter.
    'deposits-read-a-fact-sheet': (s) => lessonShot(
      pathId: 'grow_your_money',
      lesson: depositsAndPooledFundsLessons.firstWhere(
        (l) => l.id == dpReadAFactSheet,
      ),
      store: s,
    ),
    // Money Courses Phase 8: "Volatility and Possible Total Loss", the
    // lesson carrying the loss-impact simulator (LossImpactSimulatorBlock),
    // the most novel new widget this course adds: a user-chosen fictional
    // amount, a 30/60/100 percent loss scenario, transparent arithmetic,
    // never a forecast.
    'crypto-volatility-total-loss': (s) => lessonShot(
      pathId: 'grow_your_money',
      lesson: cryptoWithoutHypeLessons.firstWhere(
        (l) => l.id == cryptoRefVolatilityTotalLoss,
      ),
      store: s,
    ),
    // Money Courses Phase 9: "Protect Your Future", the first new learning
    // path since Grow Your Money, and its first course, "Insurance
    // Decoded". "VUL Without the Sales Pitch" carries this course's most
    // novel content: the simplified premium-allocation diagram, the
    // guaranteed-versus-illustrated sorting activity, and the fictional
    // VUL policy summary checklist, the lesson most likely to read as a
    // sales pitch if the tone slipped anywhere.
    'insurance-vul-no-sales-pitch': (s) => lessonShot(
      pathId: 'protect_your_future',
      lesson: insuranceDecodedLessons.firstWhere(
        (l) => l.id == insuranceRefVulNoSalesPitch,
      ),
      store: s,
    ),
    // "Verify, Compare and Decide", the course's closing lesson: the
    // agent-verification checklist, the pressure-selling red-flag
    // challenge, three "what would you ask next" scenarios, and the final
    // protection review with its three result strings, never an approval.
    'insurance-verify-compare-decide': (s) => lessonShot(
      pathId: 'protect_your_future',
      lesson: insuranceDecodedLessons.firstWhere(
        (l) => l.id == insuranceRefVerifyCompareDecide,
      ),
      store: s,
    ),
    // Money Courses Phase 10: "SSS & PhilHealth Essentials", this path's
    // second course. "Check Before You Count on It" carries the
    // RiskReviewChecklistBlock readiness checklist with the task's own
    // three result strings, the lesson most likely to read as an
    // eligibility verdict if the tone slipped anywhere.
    'sss-philhealth-check-before-you-count': (s) => lessonShot(
      pathId: 'protect_your_future',
      lesson: sssPhilhealthBenefitsLessons.firstWhere(
        (l) => l.id == sspRefCheckBeforeYouCount,
      ),
      store: s,
    ),
    // The course's closing lesson: the checklist action plan and the
    // Salapify actions menu, the lesson most likely to read as a promise
    // or an automatic write if the tone or the action descriptions slipped.
    'sss-philhealth-safety-net-plan': (s) => lessonShot(
      pathId: 'protect_your_future',
      lesson: sssPhilhealthBenefitsLessons.firstWhere(
        (l) => l.id == sspRefSafetyNetPlan,
      ),
      store: s,
    ),
    // Money Courses Phase 11: "Pag-IBIG Savings & Housing", this path's
    // third course. "MP2 Without the Hype" carries the myth-or-fact block
    // and the dividend-rate framing, the lesson most likely to read as a
    // guaranteed-return promise if the tone slipped anywhere.
    'pagibig-mp2-without-hype': (s) => lessonShot(
      pathId: 'protect_your_future',
      lesson: pagibigSavingsMp2HousingLessons.firstWhere(
        (l) => l.id == pagibigRefMp2WithoutHype,
      ),
      store: s,
    ),
    // The course's closing lesson: the action-plan checklist and the
    // Salapify actions menu, the lesson most likely to read as a promise
    // or an automatic write if the tone or the action descriptions slipped.
    'pagibig-make-your-plan': (s) => lessonShot(
      pathId: 'protect_your_future',
      lesson: pagibigSavingsMp2HousingLessons.firstWhere(
        (l) => l.id == pagibigRefMakeYourPlan,
      ),
      store: s,
    ),
    // Money Courses Phase 13: "Start Your Business Legally", the new "Build
    // Your Business" path's first course. "Compare Business Structures"
    // carries the ComparisonBlock across five structures, the lesson most
    // likely to read as ranking one as best if the tone slipped anywhere.
    'business-compare-structures': (s) => lessonShot(
      pathId: 'build_your_business',
      lesson: startABusinessLegallyLessons.firstWhere(
        (l) => l.id == brCompareBusinessStructures,
      ),
      store: s,
    ),
    // The course's closing lesson: the roadmap checklist and the Salapify
    // actions menu, the lesson most likely to read as a promise or an
    // automatic write if the tone or the action descriptions slipped.
    'business-registration-roadmap': (s) => lessonShot(
      pathId: 'build_your_business',
      lesson: startABusinessLegallyLessons.firstWhere(
        (l) => l.id == brBuildRegistrationRoadmap,
      ),
      store: s,
    ),
    // Money Courses Phase 14: "BIR Registration and Local Permits", this
    // path's second course. "Get Your TIN and Certificate of Registration"
    // states real current national figures (the abolished annual fee), the
    // lesson most likely to read as stale or wrong if a figure slipped.
    'bir-local-get-your-tin': (s) => lessonShot(
      pathId: 'build_your_business',
      lesson: birRegistrationAndLocalPermitsLessons.firstWhere(
        (l) => l.id == birlGetYourTin,
      ),
      store: s,
    ),
    // The most safety-critical lesson in this course: the one place it
    // deliberately never states a peso figure, since local permit fees
    // vary by city and municipality. Most likely to read as evasive or
    // incomplete if the tone slipped, rather than deliberately careful.
    'bir-local-barangay-and-mayor': (s) => lessonShot(
      pathId: 'build_your_business',
      lesson: birRegistrationAndLocalPermitsLessons.firstWhere(
        (l) => l.id == birlBarangayAndMayor,
      ),
      store: s,
    ),
    // "BIR Setup for New Businesses", the same path's third course.
    // "Know What You Registered For" carries the tax-type awareness
    // checklist, the lesson most likely to read as determining a real
    // reader's own obligations if the tone slipped anywhere.
    'bir-tax-know-what-you-registered-for': (s) => lessonShot(
      pathId: 'build_your_business',
      lesson: birRegistrationTaxSetupLessons.firstWhere(
        (l) => l.id == btaxKnowWhatYouRegisteredFor,
      ),
      store: s,
    ),
    // The course's closing lesson: the tax-money-system checklist and the
    // Salapify actions menu, the lesson most likely to read as a promise
    // or an automatic write if the tone or the action descriptions slipped.
    'bir-tax-create-your-tax-money-system': (s) => lessonShot(
      pathId: 'build_your_business',
      lesson: birRegistrationTaxSetupLessons.firstWhere(
        (l) => l.id == btaxMoneySystem,
      ),
      store: s,
    ),
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
        debugShowCheckedModeBanner: false,
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
        debugShowCheckedModeBanner: false,
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
        debugShowCheckedModeBanner: false,
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
        debugShowCheckedModeBanner: false,
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
        debugShowCheckedModeBanner: false,
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
        debugShowCheckedModeBanner: false,
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
        debugShowCheckedModeBanner: false,
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
        debugShowCheckedModeBanner: false,
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
          debugShowCheckedModeBanner: false,
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
        debugShowCheckedModeBanner: false,
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
        debugShowCheckedModeBanner: false,
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

  testWidgets('the your name edit dialog, with a name set', (tester) async {
    // "Your name" is a single row in Menu's SETTINGS card now, the same
    // shape as Appearance and Currency; the state carrying the most to get
    // wrong moved into the dialog it opens, which now carries THREE actions
    // (Remove, Cancel, Save) instead of the row's old two, since Remove
    // moved off the row and into here. Rendered with a name SET, since that
    // is the state where Remove exists at all.
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
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: MenuScreen(store: store, onSwitchTab: (_) {}),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Your name'), 300);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Your name'));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('shots/menu-name-dark.png'),
    );
  });

  testWidgets('the notifications card in Menu, comeback on, dark', (
    tester,
  ) async {
    // The new Come back toggle sits low in a tall card, so it would otherwise
    // ship never looked at. Rendered in its shipped-on state (a user who
    // accepted the nightly nudge gets daily and comeback on), so the new row
    // reads the way the founder will actually see it.
    await loadRealFonts(tester);
    await loadPanFaces(tester);
    SharedPreferences.setMockInitialValues({});
    final store = SalapifyStore();
    await store.load();
    await store.setNotifPref('daily', true);
    await store.setNotifPref('comeback', true);

    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    Barako.current = Barako.currentTheme.resolve(Brightness.dark);
    await tester.pumpWidget(
      MaterialApp(
        theme: salapifyTheme(Barako.current),
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Barako.background,
          body: MenuScreen(store: store, onSwitchTab: (_) {}),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // Reminders live on their own screen now
    // (notifications_security.dart), reached from Menu's "Notifications
    // and security" row.
    await tester.scrollUntilVisible(
      find.text('Notifications and security'),
      300,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Notifications and security'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Come back'), 300);
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('shots/menu-notifications-dark.png'),
    );
  });

  testWidgets(
    'the Waiting section on Money mindset, one due and one not, dark',
    (tester) async {
      // Money Mindset Phase 3: two paused items layered onto the lived-in
      // fixture's settings, one already due (reads "Ready to revisit") and
      // one not (reads "Revisit in Nh"), so both row states render at once,
      // plus a long-ish amount to check the row does not overflow.
      await loadRealFonts(tester);
      final now = DateTime.now();
      final blob = {
        ...livedInBlob,
        'settings': {
          ...(livedInBlob['settings'] as Map).cast<String, dynamic>(),
          'mindsetWaiting': [
            {
              'id': 'w1',
              'itemName': 'New running shoes',
              'amount': 3499.0,
              'essential': false,
              'affordableWithoutReserved': true,
              'waited24h': false,
              'result': 'pause24h',
              'createdAt': now
                  .subtract(const Duration(hours: 25))
                  .toIso8601String(),
              'revisitAt': now
                  .subtract(const Duration(hours: 1))
                  .toIso8601String(),
              'status': 'waiting',
            },
            {
              'id': 'w2',
              'itemName': 'A new phone case',
              'amount': 899.0,
              'essential': false,
              'affordableWithoutReserved': true,
              'waited24h': false,
              'result': 'pause24h',
              'createdAt': now.toIso8601String(),
              'revisitAt': now.add(const Duration(hours: 20)).toIso8601String(),
              'status': 'waiting',
            },
          ],
        },
      };
      SharedPreferences.setMockInitialValues({storageKey: jsonEncode(blob)});
      final store = SalapifyStore();
      await store.load();

      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      Barako.current = Barako.currentTheme.resolve(Brightness.dark);
      await tester.pumpWidget(
        MaterialApp(
          theme: salapifyTheme(Barako.current),
          debugShowCheckedModeBanner: false,
          home: MindsetScreen(store: store),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('WAITING'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('WAITING'), findsOneWidget);
      expect(find.text('New running shoes'), findsOneWidget);
      expect(find.text('Ready to revisit'), findsOneWidget);
      expect(find.textContaining('Revisit in'), findsOneWidget);

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('shots/mindset-waiting-dark.png'),
      );

      // The Revisit in 24 hours button itself: answer to a Pause for 24
      // hours verdict (essential No, affordable Yes, waited No).
      await tester.scrollUntilVisible(
        find.text('Is this essential right now?'),
        -400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('No').at(0)); // essential
      await tester.pumpAndSettle();
      await tester.tap(find.text('Yes').at(1)); // affordable without reserved
      await tester.pumpAndSettle();
      await tester.tap(find.text('No').at(2)); // waited 24h
      await tester.pumpAndSettle();
      expect(find.text('Pause for 24 hours'), findsOneWidget);
      expect(find.text('Revisit in 24 hours'), findsOneWidget);
      await tester.ensureVisible(find.text('Revisit in 24 hours'));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('shots/mindset-revisit-button-dark.png'),
      );

      // The Do you still want this? sheet, opened from the due row.
      await tester.scrollUntilVisible(
        find.text('Ready to revisit'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ready to revisit'));
      await tester.pumpAndSettle();
      expect(find.text('Do you still want this?'), findsOneWidget);
      expect(find.text('Yes, review again'), findsOneWidget);
      expect(find.text('No, skip it'), findsOneWidget);
      expect(find.text('Not sure, wait another 24 hours'), findsOneWidget);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('shots/mindset-revisit-prompt-dark.png'),
      );
    },
  );

  testWidgets('Small Wins and the 30-day snapshot on Money mindset, dark', (
    tester,
  ) async {
    // Money Mindset Phase 4: a small win with an amount and a reflection,
    // a plain manual-entry win, and three skipped waiting items, layered
    // onto the lived-in fixture so the snapshot's four counts, the
    // spending-avoided total, and the rule-based insight all render
    // together against real history rather than an empty store.
    await loadRealFonts(tester);
    final now = DateTime.now();
    final today = now.toIso8601String().substring(0, 10);
    Map<String, dynamic> skipped(String id) => {
      'id': id,
      'itemName': 'Item $id',
      'essential': false,
      'affordableWithoutReserved': true,
      'waited24h': false,
      'result': 'pause24h',
      'createdAt': now.subtract(const Duration(days: 1)).toIso8601String(),
      'revisitAt': now.subtract(const Duration(hours: 1)).toIso8601String(),
      'status': 'skipped',
    };
    final blob = {
      ...livedInBlob,
      'wins': [
        {
          'id': 'win1',
          'text': 'New running shoes',
          'amount': 3499.0,
          'note': 'Already have three pairs',
          'date': today,
        },
        {'id': 'win2', 'text': 'Packed lunch all week', 'date': today},
      ],
      'settings': {
        ...(livedInBlob['settings'] as Map).cast<String, dynamic>(),
        'mindsetChecks': [
          {'id': 'c1', 'verdict': 'pause24h', 'date': today},
        ],
        'mindsetWaiting': [skipped('s1'), skipped('s2'), skipped('s3')],
      },
    };
    SharedPreferences.setMockInitialValues({storageKey: jsonEncode(blob)});
    final store = SalapifyStore();
    await store.load();

    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    Barako.current = Barako.currentTheme.resolve(Brightness.dark);
    await tester.pumpWidget(
      MaterialApp(
        theme: salapifyTheme(Barako.current),
        debugShowCheckedModeBanner: false,
        home: MindsetScreen(store: store),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('30-DAY SNAPSHOT'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('30-DAY SNAPSHOT'), findsOneWidget);
    expect(
      find.text('Waiting 24 hours helped you skip 3 purchases this month.'),
      findsOneWidget,
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('shots/mindset-snapshot-dark.png'),
    );

    await tester.scrollUntilVisible(
      find.text('New running shoes'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Spending avoided: ₱3,499'), findsOneWidget);
    expect(find.text('Already have three pairs'), findsOneWidget);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('shots/mindset-small-wins-dark.png'),
    );
  });

  testWidgets(
    'the purchase-type picker on Money mindset, all three types, dark '
    '(Phase 5)',
    (tester) async {
      // Money Mindset Phase 5: subscription equivalents, a credit or BNPL
      // plan's total repayment against the lived-in fixture's own BPI card
      // minimum, and a goal trade-off against the fixture's real Emergency
      // fund goal (which already carries a deadline and history, so the
      // delay estimate has something real to compute from).
      await loadRealFonts(tester);
      SharedPreferences.setMockInitialValues({
        storageKey: jsonEncode(livedInBlob),
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
          debugShowCheckedModeBanner: false,
          home: MindsetScreen(store: store),
        ),
      );
      await tester.pumpAndSettle();

      // Subscription.
      await tester.tap(find.text('Subscription'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('mindsetSubAmount')), '149');
      await tester.pumpAndSettle();
      expect(find.text('Monthly equivalent'), findsOneWidget);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('shots/mindset-subscription-dark.png'),
      );

      // Credit or BNPL, with the fixture's own BPI card minimum showing
      // alongside it.
      await tester.tap(find.text('Credit or BNPL'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('mindsetCreditCash')),
        '15000',
      );
      await tester.enterText(
        find.byKey(const Key('mindsetCreditDown')),
        '3000',
      );
      await tester.enterText(
        find.byKey(const Key('mindsetCreditInstallment')),
        '1200',
      );
      await tester.enterText(
        find.byKey(const Key('mindsetCreditInstallmentsCount')),
        '10',
      );
      await tester.enterText(find.byKey(const Key('mindsetCreditFees')), '299');
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Total repayment'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Total repayment'), findsOneWidget);
      expect(find.text('Debt minimums'), findsOneWidget);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('shots/mindset-credit-dark.png'),
      );

      // Goal trade-off against the fixture's real Emergency fund goal.
      await tester.scrollUntilVisible(
        find.text('COMPARE TO A GOAL (OPTIONAL)'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Emergency fund'));
      await tester.pumpAndSettle();
      expect(find.text('Purchase amount'), findsOneWidget);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('shots/mindset-goal-tradeoff-dark.png'),
      );
    },
  );

  testWidgets('the sample data card in Menu, both states, dark', (
    tester,
  ) async {
    // A new card, so it gets looked at before it ships. Both states in one
    // frame is not possible, so this shoots the OFFER and then the loaded state
    // after a real tap, which also proves the label and the copy swap over
    // rather than only the behaviour behind them.
    await loadRealFonts(tester);
    SharedPreferences.setMockInitialValues({
      storageKey: jsonEncode(livedInBlob),
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
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Barako.background,
          body: MenuScreen(store: store, onSwitchTab: (_) {}),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('TRY IT WITH SAMPLE DATA'), 300);
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('shots/menu-sample-offer-dark.png'),
    );

    await tester.tap(find.text('Load sample data'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('SAMPLE DATA IS LOADED'), 300);
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('shots/menu-sample-loaded-dark.png'),
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
        debugShowCheckedModeBanner: false,
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

  testWidgets('Goals, lived in and empty, and the detail, dark', (
    tester,
  ) async {
    // The redesigned Goals surfaces, each asserting the view it claims to
    // show before capturing (session 28 rule: a shot must prove itself).
    await loadRealFonts(tester);
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    Barako.current = Barako.currentTheme.resolve(Brightness.dark);

    // The lived-in list: focus card, statuses, paces.
    SharedPreferences.setMockInitialValues({
      storageKey: jsonEncode(livedInBlob),
    });
    var store = SalapifyStore();
    await store.load();
    await tester.pumpWidget(
      MaterialApp(
        theme: salapifyTheme(Barako.current),
        debugShowCheckedModeBanner: false,
        home: GoalsScreen(store: store),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('FOCUS'), findsOneWidget);
    expect(find.text('Emergency fund'), findsOneWidget);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('shots/goals-list-dark.png'),
    );

    // The detail of the lived-in goal: plan, estimate, what-if, history.
    await tester.pumpWidget(
      MaterialApp(
        theme: salapifyTheme(Barako.current),
        debugShowCheckedModeBanner: false,
        home: GoalDetailScreen(store: store, goalId: 'g1'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('THE PLAN'), findsOneWidget);
    expect(find.text('HISTORY'), findsOneWidget);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('shots/goal-detail-dark.png'),
    );

    // The empty state with templates, from a fresh store.
    SharedPreferences.setMockInitialValues({});
    store = SalapifyStore();
    await store.load();
    await tester.pumpWidget(
      MaterialApp(
        theme: salapifyTheme(Barako.current),
        debugShowCheckedModeBanner: false,
        home: GoalsScreen(store: store),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('What are you saving for?'), findsOneWidget);
    expect(find.text('POPULAR GOAL TEMPLATES'), findsOneWidget);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('shots/goals-empty-dark.png'),
    );
  });

  testWidgets('Pan with a standing plan, dark', (tester) async {
    // The plan card is the trust surface of Pan With a Plan: everything Pan
    // "remembers" must be on it. The lived-in fixture carries a standing
    // debt plan, and the shot ASSERTS the card is in view before capturing,
    // per the session 28 lesson: a shot that does not prove it shows what it
    // claims can silently photograph the wrong state.
    await loadRealFonts(tester);
    await loadPanFaces(tester);
    SharedPreferences.setMockInitialValues({
      storageKey: jsonEncode(livedInBlob),
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
        debugShowCheckedModeBanner: false,
        home: PanScreen(store: store),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('OUR PLAN'),
      findsOneWidget,
      reason: 'the plan card must be in the frame this shot claims to show',
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('shots/pan-plan-dark.png'),
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
        debugShowCheckedModeBanner: false,
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
          debugShowCheckedModeBanner: false,
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
        debugShowCheckedModeBanner: false,
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
    // The SAME person every other screen renders. This shot used to seed its
    // own near-copy of the lived-in fixture, close enough to look identical
    // and different enough that Accounts and Utang disagreed about the total
    // debt by 80 pesos and 40 centavos. Chasing that gap ate an investigation
    // and the answer was that neither screen was wrong, they were rendering
    // two different people. Cross-screen comparison is the most valuable kind
    // of looking there is, and a private fixture per shot makes it impossible.
    SharedPreferences.setMockInitialValues({
      storageKey: jsonEncode(livedInBlob),
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
        debugShowCheckedModeBanner: false,
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
    // Scroll the button into view before tapping: the Cash on hand section
    // above the carousel makes the list taller, so the button can sit below the
    // fold and a bare tap would miss it. ensureVisible actually brings it on
    // screen (scrollUntilVisible only guarantees it is built).
    await tester.ensureVisible(find.text('Move money between accounts'));
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
        debugShowCheckedModeBanner: false,
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
        debugShowCheckedModeBanner: false,
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
        debugShowCheckedModeBanner: false,
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
        debugShowCheckedModeBanner: false,
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

  testWidgets('the Income tax calculator with a result, dark', (tester) async {
    // The heaviest tax screen and the only one that was in no render harness.
    // Entering a gross figure reveals OUR PICK, both option cards (the
    // graduated breakdown folded behind "Show the calculation"), the set-aside,
    // the forms, and the disclaimer.
    await loadRealFonts(tester);
    SharedPreferences.setMockInitialValues({});

    tester.view.physicalSize = const Size(1170, 4200);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    Barako.current = Barako.currentTheme.resolve(Brightness.dark);
    await tester.pumpWidget(
      MaterialApp(
        theme: salapifyTheme(Barako.current),
        debugShowCheckedModeBanner: false,
        home: const TaxCalculatorScreen(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '600000');
    await tester.pumpAndSettle();
    expect(find.text('OUR PICK'), findsOneWidget);
    expect(find.text('Show the calculation'), findsOneWidget);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('shots/tax-income-dark.png'),
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
        debugShowCheckedModeBanner: false,
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

  testWidgets('the finish card, the moment a lesson ends', (tester) async {
    // The centre of the Phase 1 quick wins, and the one screen the audit's
    // C2 finding was about: what a reader sees the instant they finish. It
    // used to be a single quiet row and a back button. Rendered here so the
    // founder can look at the replacement rather than take a diff's word
    // for it.
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
        debugShowCheckedModeBanner: false,
        home: LearnScreen(store: store, focusId: 'see-it-first'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Finish this lesson'), 250);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Finish this lesson'));
    await tester.pumpAndSettle();
    // Scrolled so the card, not the prose above it, is what the shot shows.
    await tester.scrollUntilVisible(find.text('Back to courses'), 250);
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('shots/lesson-finish-card-dark.png'),
    );
  });

  testWidgets(
    'Phase 16: the CONTINUE THIS PATH recommendation badge on Grow Your '
    'Money, dark',
    (tester) async {
      // Nothing in screens_shot.dart rendered this feature before it shipped
      // (f3.52): the badge only ever appears once real expansion progress
      // exists, and every existing shot of the Learn screen used either an
      // empty store or the lived-in fixture, which carries no expansion
      // progress at all. A screenshot against a fixture that cannot show a
      // feature proves nothing, the exact gap CLAUDE.md's own "lived-in
      // phone" lesson warns about, so this uses a dedicated fixture instead.
      await loadRealFonts(tester);
      await loadPanFaces(tester);
      SharedPreferences.setMockInitialValues({});
      final store = SalapifyStore();
      await store.load();
      await store.markExpansionLessonCompleted(
        'grow_your_money',
        growYourMoneyLessons.first.id,
      );

      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      Barako.current = Barako.currentTheme.resolve(Brightness.dark);
      await tester.pumpWidget(
        MaterialApp(
          theme: salapifyTheme(Barako.current),
          debugShowCheckedModeBanner: false,
          home: LearnScreen(store: store),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Grow Your Money'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.text('CONTINUE THIS PATH'), findsOneWidget);

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('shots/learn-recommendation-badge-dark.png'),
      );
    },
  );

  testWidgets(
    'Phase 16: All lessons on Grow Your Money, grouped by course title, '
    'dark',
    (tester) async {
      // The other Phase 16 specialist fix: the expanded list used to be one
      // flat, ungrouped run of lessons, so a recommendation reason that
      // names a specific course ("Finish Investment Readiness before...")
      // pointed at nothing a reader could actually find in the list below
      // it. Same fixture as the badge shot above, tapped open, so both real
      // findings from that review are visible in the same screenshot.
      await loadRealFonts(tester);
      await loadPanFaces(tester);
      SharedPreferences.setMockInitialValues({});
      final store = SalapifyStore();
      await store.load();
      await store.markExpansionLessonCompleted(
        'grow_your_money',
        growYourMoneyLessons.first.id,
      );

      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      Barako.current = Barako.currentTheme.resolve(Brightness.dark);
      await tester.pumpWidget(
        MaterialApp(
          theme: salapifyTheme(Barako.current),
          debugShowCheckedModeBanner: false,
          home: LearnScreen(store: store),
        ),
      );
      await tester.pumpAndSettle();

      final growCard = find.ancestor(
        of: find.text('Grow Your Money'),
        matching: find.byType(Card),
      );
      // Since Phase 4 this pushes a real PathScreen: the courses are cards a
      // learner can open directly, not kicker headings inside an expanded hub
      // card. The shot is renamed to match what it now shows.
      await tester.scrollUntilVisible(
        find.descendant(
          of: growCard,
          matching: find.widgetWithText(TextButton, 'All courses'),
        ),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: growCard,
          matching: find.widgetWithText(TextButton, 'All courses'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Are You Ready to Invest?'), findsOneWidget);

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('shots/learn-path-courses-dark.png'),
      );

      // And one level deeper, because the courses screen is only half the
      // change: tapping a course card is what a learner does next, and the
      // lesson list behind it is where the minutes, the state and the
      // ordering actually show up. Shooting only the parent would leave the
      // screen this phase exists to create unlooked at.
      await tester.tap(find.text('Are You Ready to Invest?'));
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('shots/learn-course-lessons-dark.png'),
      );
    },
  );

  testWidgets('the Privacy receipt, dark', (tester) async {
    // A launch trust surface, so look at it whole. It provides its own
    // Scaffold and AppBar, so render it as home directly rather than through
    // shoot() (which wraps a bare destination in a Scaffold). Empty prefs, so
    // the fetch log shows its honest "No rate fetches yet" state; the point of
    // this shot is the copy and the new on-device protections card.
    await loadRealFonts(tester);
    SharedPreferences.setMockInitialValues({});

    // Tall viewport on purpose: this is a trust surface and the whole page is
    // worth seeing in one frame, not just the fold. A ListView only paints its
    // viewport, so the height has to be enough to hold the whole receipt.
    tester.view.physicalSize = const Size(1080, 4600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    Barako.current = Barako.currentTheme.resolve(Brightness.dark);
    await tester.pumpWidget(
      MaterialApp(
        theme: salapifyTheme(Barako.current),
        debugShowCheckedModeBanner: false,
        home: PrivacyReceiptScreen(),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('shots/privacy-receipt-dark.png'),
    );
  });

  testWidgets('the Diagnostics tester screen, dark', (tester) async {
    // A lived-in shot: a couple of counts and one recorded error, so the screen
    // shows both cards rather than an all-empty page. The store carries only
    // ids, because the screen renders counts, never contents (proven by
    // diagnostics_screen_test.dart), so there is no PII to show here anyway.
    await loadRealFonts(tester);
    SharedPreferences.setMockInitialValues({});
    await Diagnostics.clear();
    Diagnostics.record(
      'RangeError (index): invalid value',
      'package:salapify/screens/foo.dart 12:3',
    );
    final store = SalapifyStore();
    store.data = {
      'transactions': [
        {'id': 't1'},
        {'id': 't2'},
      ],
      'accounts': [
        {'id': 'a1'},
      ],
      'debts': [],
      'goals': [],
      'utang': [],
      'recurring': [],
      'categories': [
        {'id': 'c1'},
      ],
    };

    tester.view.physicalSize = const Size(1080, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    Barako.current = Barako.currentTheme.resolve(Brightness.dark);
    await tester.pumpWidget(
      MaterialApp(
        theme: salapifyTheme(Barako.current),
        debugShowCheckedModeBanner: false,
        home: DiagnosticsScreen(store: store),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('shots/diagnostics-dark.png'),
    );
  });

  testWidgets('the milestone celebration sheet, dark', (tester) async {
    await loadRealFonts(tester);
    tester.view.physicalSize = const Size(1170, 2200);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    Barako.current = Barako.currentTheme.resolve(Brightness.dark);
    const win = Milestone(
      kind: 'goal',
      id: 'g1',
      name: 'Emergency fund',
      amount: 60000,
      headline: 'Goal reached',
      sub: 'Emergency fund, fully funded',
      amountLabel: 'Saved up',
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: salapifyTheme(Barako.current),
        debugShowCheckedModeBanner: false,
        home: Builder(
          builder: (context) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              showMilestoneCelebration(context, win);
            });
            return const Scaffold(body: SizedBox.expand());
          },
        ),
      ),
    );
    // Let the sheet open and the celebration overlay fully retire (its entry
    // removes itself on a timer; capturing before that leaves an undisposed
    // OverlayEntry and the tree will not finalize).
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('shots/milestone-celebration-dark.png'),
    );

    // Close the sheet so nothing is left on the navigator at teardown.
    await tester.tap(find.text('Maybe later'));
    await tester.pumpAndSettle();
  });

  testWidgets('the Sweldo Timeline, Pro 60 day view with a what if, dark', (
    tester,
  ) async {
    // The fullest state the screen has: a rolling Pro horizon crossing a
    // month boundary, the variable-spend band from the fixture's logged
    // spending, payday dots, and one saved what-if overlaying the line. The
    // free month view is already covered by the readability sweep; this shot
    // is the part only Pro sees, looked at before it ships.
    await loadRealFonts(tester);
    final today = DateTime.now();
    final buyDate = today.add(const Duration(days: 12));
    String iso(DateTime t) =>
        '${t.year.toString().padLeft(4, '0')}-'
        '${t.month.toString().padLeft(2, '0')}-'
        '${t.day.toString().padLeft(2, '0')}';
    final blob = {
      ...livedInBlob,
      'settings': {
        ...(livedInBlob['settings'] as Map).cast<String, dynamic>(),
        'pro': true,
        'timelineScenarios': [
          {
            'kind': 'purchase',
            'label': 'New phone',
            'amount': 18000,
            'date': iso(buyDate),
            'on': true,
          },
        ],
      },
    };
    SharedPreferences.setMockInitialValues({storageKey: jsonEncode(blob)});
    final store = SalapifyStore();
    await store.load();

    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    Barako.current = Barako.currentTheme.resolve(Brightness.dark);
    await tester.pumpWidget(
      MaterialApp(
        theme: salapifyTheme(Barako.current),
        debugShowCheckedModeBanner: false,
        home: CashFlowScreen(store: store),
      ),
    );
    await tester.pumpAndSettle();

    // The 60 day chip sits past the right edge of the chip row; bring it on
    // screen first or the tap lands on nothing and the shot quietly shows
    // the month view instead (which is exactly what happened on the first
    // render of this shot).
    await tester.ensureVisible(find.text('60 days'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('60 days'));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('shots/cashflow-timeline-dark.png'),
    );
  });
}
